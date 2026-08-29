import Foundation
import Testing
@testable import BlennyCore

@Suite("Minimal product interface view model")
struct PolicyEditorViewModelTests {
    private let blenny = "xyz.fi5h.blenny"
    private let revealable = "com.example.Revealable"
    private let hidden = "com.example.Hidden"
    private let newCandidate = "com.example.NewCandidate"

    @Test("Current bounded observations are the only editable candidates")
    func observationsDefineCandidates() throws {
        let report = report(items: [
            item(bundleIdentifier: blenny, pid: 10),
            item(bundleIdentifier: revealable, pid: 20),
            item(bundleIdentifier: revealable, pid: 20),
            item(bundleIdentifier: "com.apple.systemuiserver", pid: 25),
            item(bundleIdentifier: hidden, pid: 30, classification: .systemOwnedPresentation),
            systemItem(identifier: "com.apple.menuextra.wifi", description: "Wi-Fi"),
            systemItem(identifier: "com.apple.menuextra.bluetooth", description: "Bluetooth"),
            systemItem(identifier: "com.apple.menuextra.wifi", description: "Wi-Fi"),
            systemItem(
                identifier: nil,
                description: "Siri",
                ownerBundleIdentifier: "com.apple.systemuiserver",
                stableIdentityLabel: "siri"
            ),
        ])

        let snapshot = MenuBarOwnershipSnapshotBuilder.make(from: report)
        let inventory = PolicyCandidateInventory(observations: snapshot.observations)

        #expect(snapshot.isComplete)
        #expect(inventory.bundleIdentifiers == [revealable, blenny])
        #expect(
            inventory.candidates.first { $0.bundleIdentifier == revealable }?.menuBarItemCount == 2
        )
        #expect(snapshot.systemItems.map(\.displayName) == ["Bluetooth", "Siri", "Wi-Fi"])
        #expect(snapshot.systemItems.first { $0.displayName == "Wi-Fi" }?.observationCount == 2)
        #expect(
            snapshot.systemItems.first { $0.displayName == "Siri" }?.ownerBundleIdentifier
                == "com.apple.systemuiserver"
        )
    }

    @Test("A truncated or unauthorized scan is explicit and incomplete")
    func incompleteObservationFailsClosed() {
        let unauthorized = MenuBarOwnershipSnapshotBuilder.make(
            from: report(accessibilityTrusted: false)
        )
        let truncated = MenuBarOwnershipSnapshotBuilder.make(
            from: report(elementLimitReached: true, timeLimitReached: true)
        )

        #expect(unauthorized.issues == [.accessibilityNotGranted])
        #expect(truncated.issues == [.elementLimitReached, .timeLimitReached])
        #expect(!unauthorized.isComplete)
        #expect(!truncated.isComplete)
    }

    @Test("Draft edits stay local and Blenny cannot leave Visible")
    func localDraftEditing() throws {
        let accepted = try policy()
        let inventory = PolicyCandidateInventory(observations: [
            observation(blenny, pid: 10),
            observation(revealable, pid: 20),
            observation(hidden, pid: 30),
            observation(newCandidate, pid: 40),
        ])
        var model = try PolicyEditorViewModel(
            acceptedPolicy: accepted,
            candidateInventory: inventory,
            blennyBundleIdentifier: blenny
        )

        #expect(model.candidates(in: .revealable).map(\.bundleIdentifier) == [revealable])
        #expect(model.implicitVisibleCandidates.map(\.bundleIdentifier) == [newCandidate])
        #expect(model.assign(bundleIdentifier: revealable, to: .hidden) == .changed)
        #expect(model.hasDraftChanges)
        #expect(accepted.policies.first(where: { $0.bundleIdentifier == revealable })?.policy == .revealable)
        #expect(model.assign(bundleIdentifier: blenny, to: .hidden) == .rejectedBlennyMustRemainVisible)
        #expect(model.candidates(in: .visible).map(\.bundleIdentifier) == [blenny])
    }

    @Test("An implicitly Visible bundle enters validation scope only after explicit assignment")
    func implicitVisibleCandidateStaging() throws {
        let accepted = try policy()
        let inventory = PolicyCandidateInventory(observations: [
            observation(blenny, pid: 10),
            observation(revealable, pid: 20),
            observation(hidden, pid: 30),
            observation(newCandidate, pid: 40),
        ])
        var model = try PolicyEditorViewModel(
            acceptedPolicy: accepted,
            candidateInventory: inventory,
            blennyBundleIdentifier: blenny
        )

        #expect(!model.hasDraftChanges)
        #expect(model.implicitVisibleCandidates.map(\.bundleIdentifier) == [newCandidate])
        #expect(model.validationScope.approvedBundleIdentifiers == [
            hidden,
            revealable,
            blenny,
        ])

        #expect(model.assign(bundleIdentifier: newCandidate, to: .revealable) == .changed)
        #expect(model.implicitVisibleCandidates.isEmpty)
        #expect(model.validationScope.approvedBundleIdentifiers == [
            hidden,
            newCandidate,
            revealable,
            blenny,
        ])

        #expect(model.assign(bundleIdentifier: newCandidate, to: .visible) == .changed)
        #expect(model.candidates(in: .visible).map(\.bundleIdentifier) == [
            newCandidate,
            blenny,
        ])
        #expect(model.assign(bundleIdentifier: blenny, to: .hidden) == .rejectedBlennyMustRemainVisible)
    }

    @Test("Discard restores the accepted policy and implicit Visible observations")
    func discardDraft() throws {
        let accepted = try policy()
        let inventory = PolicyCandidateInventory(observations: [
            observation(blenny, pid: 10),
            observation(revealable, pid: 20),
            observation(hidden, pid: 30),
            observation(newCandidate, pid: 40),
        ])
        var model = try PolicyEditorViewModel(
            acceptedPolicy: accepted,
            candidateInventory: inventory,
            blennyBundleIdentifier: blenny
        )
        _ = model.assign(bundleIdentifier: revealable, to: .hidden)

        model.discardDraft(using: BundlePolicyDraft(acceptedPolicy: accepted))

        #expect(!model.hasDraftChanges)
        #expect(model.candidates(in: .revealable).map(\.bundleIdentifier) == [revealable])
        #expect(model.implicitVisibleCandidates.map(\.bundleIdentifier) == [newCandidate])
        #expect(model.validationScope.approvedBundleIdentifiers == [
            hidden,
            revealable,
            blenny,
        ])
        #expect(model.acceptedPolicyScope.approvedBundleIdentifiers == [
            hidden,
            revealable,
            blenny,
        ])
    }

    @Test("Accessibility system prompt is requested at most once")
    func onboardingPromptPolicy() {
        #expect(
            AccessibilityOnboardingPolicy.action(
                isTrusted: true,
                hasRequestedSystemPrompt: false
            ) == .alreadyGranted
        )
        #expect(
            AccessibilityOnboardingPolicy.action(
                isTrusted: false,
                hasRequestedSystemPrompt: false
            ) == .requestSystemPrompt
        )
        #expect(
            AccessibilityOnboardingPolicy.action(
                isTrusted: false,
                hasRequestedSystemPrompt: true
            ) == .openSystemSettings
        )
    }

    @Test("Accessibility grant refreshes once only on a safe trust transition")
    func accessibilityGrantRefreshPolicy() {
        #expect(
            AccessibilityPermissionRefreshPolicy.shouldRefresh(
                previouslyTrusted: false,
                isTrusted: true,
                isRefreshing: false,
                hasDraftChanges: false
            )
        )
        #expect(
            !AccessibilityPermissionRefreshPolicy.shouldRefresh(
                previouslyTrusted: nil,
                isTrusted: true,
                isRefreshing: false,
                hasDraftChanges: false
            )
        )
        #expect(
            !AccessibilityPermissionRefreshPolicy.shouldRefresh(
                previouslyTrusted: true,
                isTrusted: true,
                isRefreshing: false,
                hasDraftChanges: false
            )
        )
        #expect(
            !AccessibilityPermissionRefreshPolicy.shouldRefresh(
                previouslyTrusted: false,
                isTrusted: true,
                isRefreshing: true,
                hasDraftChanges: false
            )
        )
        #expect(
            !AccessibilityPermissionRefreshPolicy.shouldRefresh(
                previouslyTrusted: false,
                isTrusted: true,
                isRefreshing: false,
                hasDraftChanges: true
            )
        )
    }

    private func policy() throws -> PersistentBundlePolicyDocument {
        try PersistentBundlePolicyDocument(
            managementEnabled: false,
            policies: [
                .init(bundleIdentifier: blenny, policy: .visible),
                .init(bundleIdentifier: revealable, policy: .revealable),
                .init(bundleIdentifier: hidden, policy: .hidden),
            ]
        )
    }

    private func observation(_ identifier: String, pid: Int32) -> MenuBarPolicyOwnershipObservation {
        MenuBarPolicyOwnershipObservation(
            bundleIdentifier: identifier,
            processIdentifier: pid,
            menuBarItemCount: 1
        )
    }

    private func report(
        accessibilityTrusted: Bool = true,
        elementLimitReached: Bool = false,
        timeLimitReached: Bool = false,
        items: [MenuBarItemRecord] = []
    ) -> DiagnosticReport {
        DiagnosticReport(
            generatedAt: Date(timeIntervalSince1970: 0),
            environment: RuntimeEnvironment(
                macOSVersion: "27.0.0",
                buildVersion: "test",
                architecture: "arm64"
            ),
            accessibilityTrusted: accessibilityTrusted,
            durationMilliseconds: 1,
            runningApplicationsChecked: 4,
            extrasMenuBarTreesFound: 4,
            menuBarAgentProcessesFound: 1,
            elementLimitReached: elementLimitReached,
            timeLimitReached: timeLimitReached,
            aggregateErrors: [:],
            notes: [],
            items: items
        )
    }

    private func item(
        bundleIdentifier: String,
        pid: Int32,
        classification: MenuBarElementClassification = .manageableCandidate
    ) -> MenuBarItemRecord {
        MenuBarItemRecord(
            source: .applicationExtrasMenuBar,
            ownerPID: pid,
            ownerBundleIdentifier: bundleIdentifier,
            depth: 1,
            role: "AXMenuBarItem",
            subrole: "AXMenuExtra",
            title: nil,
            itemDescription: nil,
            accessibilityIdentifier: nil,
            frame: nil,
            actions: [],
            hiddenAttribute: .init(
                value: nil,
                readResult: "success",
                isSettable: false,
                settableResult: "success"
            ),
            positionAttribute: .init(
                value: nil,
                readResult: "success",
                isSettable: false,
                settableResult: "success"
            ),
            sizeAttribute: .init(
                value: nil,
                readResult: "success",
                isSettable: false,
                settableResult: "success"
            ),
            classification: classification,
            classificationReason: "test"
        )
    }

    private func systemItem(
        identifier: String?,
        description: String,
        ownerBundleIdentifier: String = "com.apple.MenuBarAgent",
        stableIdentityLabel: String? = nil
    ) -> MenuBarItemRecord {
        MenuBarItemRecord(
            source: .menuBarAgent,
            ownerPID: 99,
            ownerBundleIdentifier: ownerBundleIdentifier,
            depth: 2,
            role: "AXMenuBarItem",
            subrole: "AXMenuExtra",
            title: nil,
            itemDescription: description,
            accessibilityIdentifier: identifier,
            frame: nil,
            actions: [],
            hiddenAttribute: .init(
                value: nil,
                readResult: "success",
                isSettable: false,
                settableResult: "success"
            ),
            positionAttribute: .init(
                value: nil,
                readResult: "success",
                isSettable: false,
                settableResult: "success"
            ),
            sizeAttribute: .init(
                value: nil,
                readResult: "success",
                isSettable: false,
                settableResult: "success"
            ),
            classification: .systemOwnedPresentation,
            classificationReason: "test system presentation",
            identity: stableIdentityLabel.map {
                MenuBarItemIdentity(
                    ownerBundleIdentifier: ownerBundleIdentifier.lowercased(),
                    accessibilityIdentifier: nil,
                    semanticLabel: $0,
                    role: "axmenubaritem",
                    subrole: "axmenuextra",
                    instanceOrdinal: 0,
                    confidence: .moderate
                )
            }
        )
    }
}
