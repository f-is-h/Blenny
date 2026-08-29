import Testing
@testable import BlennyCore

@Suite("Product interface presentation")
struct ProductInterfacePresentationTests {
    @Test("Top-level navigation always dismisses review")
    func topLevelNavigationDismissesReview() {
        var state = ProductInterfaceNavigationState()

        state.presentReview()
        #expect(state.section == .organize)
        #expect(state.isReviewPresented)

        state.navigate(to: .settings)
        #expect(state.section == .settings)
        #expect(!state.isReviewPresented)

        state.navigate(to: .support)
        #expect(state.section == .support)
        #expect(!state.isReviewPresented)
    }

    @Test("Review is an Organize route")
    func reviewIsAnOrganizeRoute() {
        var state = ProductInterfaceNavigationState(section: .support)

        state.presentReview()

        #expect(state.section == .organize)
        #expect(state.isReviewPresented)
        state.dismissReview()
        #expect(!state.isReviewPresented)
    }

    @Test("Stopped management enables only its valid recovery controls")
    func stoppedManagementControls() {
        let state = ProductInterfaceControlState(
            hasModel: true,
            managementEnabled: false,
            recoveryAvailable: true,
            hasDraftChanges: false,
            isRefreshing: false,
            accessibilityTrusted: true,
            accessibilityPromptRequested: true
        )

        #expect(state.permission == .granted)
        #expect(state.refreshEnabled)
        #expect(!state.discardDraftEnabled)
        #expect(state.reviewEnabled)
        #expect(state.resumeEnabled)
        #expect(!state.stopEnabled)
        #expect(state.restoreEnabled)
    }

    @Test("A draft protects refresh and exposes discard")
    func draftControls() {
        let state = ProductInterfaceControlState(
            hasModel: true,
            managementEnabled: true,
            recoveryAvailable: false,
            hasDraftChanges: true,
            isRefreshing: false,
            accessibilityTrusted: false,
            accessibilityPromptRequested: true
        )

        #expect(state.permission == .requestedButNotGranted)
        #expect(!state.refreshEnabled)
        #expect(state.discardDraftEnabled)
        #expect(state.reviewEnabled)
        #expect(!state.resumeEnabled)
        #expect(state.stopEnabled)
        #expect(!state.restoreEnabled)
    }

    @Test("Refreshing disables every mutating presentation control")
    func refreshingControls() {
        let state = ProductInterfaceControlState(
            hasModel: true,
            managementEnabled: true,
            recoveryAvailable: true,
            hasDraftChanges: true,
            isRefreshing: true,
            accessibilityTrusted: false,
            accessibilityPromptRequested: false
        )

        #expect(state.permission == .notRequested)
        #expect(!state.refreshEnabled)
        #expect(!state.discardDraftEnabled)
        #expect(!state.reviewEnabled)
        #expect(!state.resumeEnabled)
        #expect(!state.stopEnabled)
        #expect(!state.restoreEnabled)
    }

    @Test("Missing Accessibility keeps idle manual refresh available for rechecking")
    func missingAccessibilityKeepsRefreshAvailable() {
        let state = ProductInterfaceControlState(
            hasModel: false,
            managementEnabled: nil,
            recoveryAvailable: false,
            hasDraftChanges: false,
            isRefreshing: false,
            accessibilityTrusted: false,
            accessibilityPromptRequested: false
        )

        #expect(state.permission == .notRequested)
        #expect(state.refreshEnabled)
        #expect(!state.reviewEnabled)
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
        #expect(ProductSupportLinks.koFi == "https://ko-fi.com/1atte")
    }
}
