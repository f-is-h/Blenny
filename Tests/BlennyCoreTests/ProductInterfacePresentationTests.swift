import Foundation
import Testing
@testable import BlennyCore

@Suite("Product interface presentation")
struct ProductInterfacePresentationTests {
    @Test("Normal navigation contains only Organize, Settings and Support")
    func topLevelNavigation() {
        var state = ProductInterfaceNavigationState()
        #expect(state.section == .organize)
        state.navigate(to: .settings)
        #expect(state.section == .settings)
        state.navigate(to: .support)
        #expect(state.section == .support)
        state.navigate(to: .organize)
        #expect(state.section == .organize)
        #expect(ProductInterfaceSection.allCases == [.organize, .settings, .support])
    }

    @Test("Fish placement guidance requires one usable native overflow control")
    func fishPlacementGuidance() {
        let identifier = UUID()
        let collapsed = NativeOverflowObservationSnapshot.observed(
            states: [.collapsed], controlIdentifier: identifier
        )
        let expanded = NativeOverflowObservationSnapshot.observed(
            states: [.expanded], controlIdentifier: identifier
        )
        let ambiguous = NativeOverflowObservationSnapshot.observed(
            states: [.collapsed, .expanded], controlIdentifier: nil
        )

        #expect(BlennyFishPlacement.autosaveName == "Blenny.Fish")
        #expect(BlennyFishPlacement.guideAvailable(for: collapsed))
        #expect(BlennyFishPlacement.guideAvailable(for: expanded))
        #expect(!BlennyFishPlacement.guideAvailable(for: ambiguous))
        #expect(!BlennyFishPlacement.guideAvailable(for: .unavailable))
    }

    @Test("Stopped management enables only its valid recovery controls")
    func stoppedManagementControls() {
        let state = ProductInterfaceControlState(
            hasModel: true,
            managementEnabled: false,
            managementRuntimeState: .stopped,
            recoveryAvailable: true,
            hasDraftChanges: false,
            isRefreshing: false,
            accessibilityTrusted: true,
            accessibilityPromptRequested: true
        )

        #expect(state.permission == .granted)
        #expect(state.refreshEnabled)
        #expect(!state.discardDraftEnabled)
        #expect(state.applyEnabled)
        #expect(state.resumeEnabled)
        #expect(!state.stopEnabled)
        #expect(state.restoreEnabled)
    }

    @Test("Failed startup keeps Resume reachable after permission grant despite persisted enabled intent")
    func resumeAfterFailedStartup() {
        for trusted in [false, true] {
            for dirty in [false, true] {
                for busy in [false, true] {
                    let controls = ProductInterfaceControlState(
                        hasModel: true, managementEnabled: true,
                        managementRuntimeState: .failClosedUnrestricted("startup failed"),
                        recoveryAvailable: true, hasDraftChanges: dirty,
                        isRefreshing: false, isApplying: busy,
                        accessibilityTrusted: trusted, accessibilityPromptRequested: true
                    )
                    #expect(controls.resumeEnabled == (trusted && !dirty && !busy))
                    #expect(controls.stopEnabled == !busy)
                }
            }
        }
        #expect(!ManagementLoopState.active("baseline").canResume)
        #expect(!ManagementLoopState.ordinaryRevealSession("reveal").canResume)
        #expect(!ManagementLoopState.terminating.canResume)
        #expect(!ManagementLoopState.unknown.canResume)
    }

    @Test("A draft protects refresh and exposes discard")
    func draftControls() {
        let state = ProductInterfaceControlState(
            hasModel: true,
            managementEnabled: true,
            managementRuntimeState: .active("baseline"),
            recoveryAvailable: false,
            hasDraftChanges: true,
            isRefreshing: false,
            accessibilityTrusted: false,
            accessibilityPromptRequested: true
        )

        #expect(state.permission == .requestedButNotGranted)
        #expect(!state.refreshEnabled)
        #expect(state.discardDraftEnabled)
        #expect(state.applyEnabled)
        #expect(!state.resumeEnabled)
        #expect(state.stopEnabled)
        #expect(!state.restoreEnabled)
    }

    @Test("Refreshing disables every mutating presentation control")
    func refreshingControls() {
        let state = ProductInterfaceControlState(
            hasModel: true,
            managementEnabled: true,
            managementRuntimeState: .active("baseline"),
            recoveryAvailable: true,
            hasDraftChanges: true,
            isRefreshing: true,
            accessibilityTrusted: false,
            accessibilityPromptRequested: false
        )

        #expect(state.permission == .notRequested)
        #expect(!state.refreshEnabled)
        #expect(!state.discardDraftEnabled)
        #expect(!state.applyEnabled)
        #expect(!state.resumeEnabled)
        #expect(!state.stopEnabled)
        #expect(!state.restoreEnabled)
    }

    @Test("Missing Accessibility keeps idle manual refresh available for rechecking")
    func missingAccessibilityKeepsRefreshAvailable() {
        let state = ProductInterfaceControlState(
            hasModel: false,
            managementEnabled: nil,
            managementRuntimeState: .unknown,
            recoveryAvailable: false,
            hasDraftChanges: false,
            isRefreshing: false,
            accessibilityTrusted: false,
            accessibilityPromptRequested: false
        )

        #expect(state.permission == .notRequested)
        #expect(state.refreshEnabled)
        #expect(!state.applyEnabled)
    }

    @Test("Launch at Login presentation follows system availability")
    func launchAtLoginAvailability() {
        let disabled = LaunchAtLoginPresentationState(availability: .disabled)
        let enabled = LaunchAtLoginPresentationState(availability: .enabled)
        let approval = LaunchAtLoginPresentationState(availability: .requiresApproval)
        let notFound = LaunchAtLoginPresentationState(availability: .notFound)

        #expect(!disabled.isEnabled)
        #expect(enabled.isEnabled)
        #expect(!approval.isEnabled)
        #expect(approval.isToggleOn)
        #expect(approval.requiresApproval)
        #expect(!notFound.isEnabled)
        #expect(notFound.statusDescription.contains("not registered"))
    }

    @Test("Launch at Login failures replace optimistic status copy")
    func launchAtLoginFailurePresentation() {
        let state = LaunchAtLoginPresentationState(
            availability: .disabled,
            failureMessage: "registration was denied"
        )

        #expect(!state.isEnabled)
        #expect(
            state.statusDescription
                == "Could not update this setting: registration was denied"
        )
    }

    @Test("Support links preserve ordered app and About attribution metadata")
    func supportLinks() {
        #expect(ProductSupportLinks.projectWebsite == "https://blenny.fi5h.xyz")
        #expect(
            ProductSupportLinks.monthlySponsor
                == "https://github.com/sponsors/f-is-h?frequency=recurring&metadata_project=blenny&metadata_source=app&metadata_placement=about"
        )
        #expect(
            ProductSupportLinks.oneTimeSponsor
                == "https://github.com/sponsors/f-is-h?frequency=one-time&metadata_project=blenny&metadata_source=app&metadata_placement=about"
        )
        for link in [ProductSupportLinks.monthlySponsor, ProductSupportLinks.oneTimeSponsor, ProductSupportLinks.menuSponsor] {
            let components = URLComponents(string: link)
            let query = components?.queryItems ?? []
            #expect(components?.scheme == "https")
            #expect(components?.host == "github.com")
            #expect(components?.path == "/sponsors/f-is-h")
            #expect(query.filter { $0.name == "metadata_project" }.map(\.value) == ["blenny"])
            #expect(query.filter { $0.name == "metadata_source" }.map(\.value) == ["app"])
            #expect(query.filter { $0.name == "metadata_placement" }.map(\.value)
                == [link == ProductSupportLinks.menuSponsor ? "menu" : "about"])
        }
        #expect(ProductSupportLinks.koFi == "https://ko-fi.com/blenny")
    }
}
