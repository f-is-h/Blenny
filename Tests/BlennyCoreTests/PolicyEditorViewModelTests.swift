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
                identifier: "com.apple.menuextra.TimeMachine",
                description: "Localized Time Machine"
            ),
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
        #expect(snapshot.systemItems.map(\.displayName) == [
            "Bluetooth", "Siri", "Time Machine", "Wi-Fi",
        ])
        #expect(snapshot.systemItems.first { $0.displayName == "Wi-Fi" }?.observationCount == 2)
        #expect(
            snapshot.systemItems.first { $0.displayName == "Siri" }?.ownerBundleIdentifier
                == "com.apple.systemuiserver"
        )
    }

    @Test("Unbundled menu items are shown without entering policy validation")
    func unbundledMenuItemIsReadOnly() throws {
        let snapshot = MenuBarOwnershipSnapshotBuilder.make(from: report(items: [
            item(bundleIdentifier: nil, pid: 1972, itemHelp: "战网"),
        ]))
        let inventory = PolicyCandidateInventory(observations: snapshot.observations)
        let model = try PolicyEditorViewModel(
            acceptedPolicy: policy(),
            candidateInventory: inventory,
            unattributedItems: snapshot.unattributedItems,
            blennyBundleIdentifier: blenny
        )

        #expect(snapshot.observations.isEmpty)
        #expect(snapshot.unattributedItems == [
            .init(processIdentifier: 1972, observationCount: 1, itemHelp: "战网"),
        ])
        #expect(snapshot.isComplete)
        #expect(snapshot.observedMenuBarItemCount(forProcessIdentifier: 1972) == 1)
        #expect(snapshot.observedMenuBarItemCount(forProcessIdentifier: 10) == 0)
        let discovery = ApplicationMenuBarDiscovery(
            application: .init(processIdentifier: 1972, bundleIdentifier: nil),
            rootReadResult: 0,
            hasValidRoot: true,
            observationCount: 1
        )
        let launchAssessment = ManagementLifecyclePolicy.assessApplicationLaunch(
            discovery: discovery,
            observedMenuBarItemCount: snapshot.observedMenuBarItemCount(
                forProcessIdentifier: 1972
            ),
            captureComplete: true
        )
        #expect(ManagementLifecyclePolicy.invalidates(
            applicationLaunchAssessment: launchAssessment
        ))
        #expect(inventory.candidates.isEmpty && inventory.issues.isEmpty)
        #expect(model.unattributedItems == snapshot.unattributedItems)
        #expect(model.validationScope.approvedBundleIdentifiers
            .allSatisfy { $0 != "unknown.bundle" })
    }

    @Test("A known Time Machine identifier does not require localized AX text")
    func timeMachineIdentifierWithoutTextIsVisible() {
        let snapshot = MenuBarOwnershipSnapshotBuilder.make(from: report(items: [
            systemItem(
                identifier: "com.apple.menuextra.TimeMachine",
                description: nil
            ),
        ]))

        #expect(snapshot.systemItems == [
            SystemMenuBarItemObservation(
                observationIdentifier: "com.apple.menuextra.TimeMachine",
                ownerBundleIdentifier: "com.apple.MenuBarAgent",
                displayName: "Time Machine",
                observationCount: 1
            ),
        ])
    }

    @Test("Spotlight composite identity has a real name even without AX description")
    func spotlightWithoutObservedText() {
        let snapshot = MenuBarOwnershipSnapshotBuilder.make(from: report(items: [
            systemItem(
                identifier: nil,
                description: nil,
                ownerBundleIdentifier: "com.apple.campo",
                stableIdentityLabel: "spotlight"
            ),
        ]))
        #expect(snapshot.systemItems.count == 1)
        #expect(snapshot.systemItems.first?.displayName == "Spotlight")
        #expect(snapshot.systemItems.first?.ownerBundleIdentifier == "com.apple.campo")
    }

    @Test("Only exact Debug Apple owner candidates leave the read-only system group")
    func debugAppleOwnerCandidatesAreNarrow() {
        let weather = "com.apple.weather.menu"
        let inputMenu = "com.apple.TextInputMenuAgent"
        let unrelatedApple = "com.apple.systemuiserver"
        let snapshot = MenuBarOwnershipSnapshotBuilder.make(from: report(items: [
            item(bundleIdentifier: weather, pid: 41),
            item(bundleIdentifier: inputMenu, pid: 42),
            item(bundleIdentifier: unrelatedApple, pid: 43),
        ]))

        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        #expect(snapshot.observations.compactMap(\.bundleIdentifier) == [
            inputMenu, weather,
        ])
        #expect(snapshot.systemItems.isEmpty)
        #expect(ExperimentalAppleBundlePolicyCatalog.contains(weather))
        #expect(ExperimentalAppleBundlePolicyCatalog.contains(inputMenu))
        #else
        #expect(snapshot.observations.isEmpty)
        #expect(snapshot.systemItems.isEmpty)
        #expect(!ExperimentalAppleBundlePolicyCatalog.contains(weather))
        #expect(!ExperimentalAppleBundlePolicyCatalog.contains(inputMenu))
        #endif
        #expect(!ExperimentalAppleBundlePolicyCatalog.contains(unrelatedApple))
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

    @Test("Bluetooth is editable and remains recoverable while hidden")
    func bluetoothDraftAndHiddenRetention() throws {
        let bluetooth = SystemMenuBarItemObservation(
            observationIdentifier: SystemMenuBarItemObservation.bluetoothIdentifier,
            ownerBundleIdentifier: "com.apple.MenuBarAgent",
            displayName: "Bluetooth",
            observationCount: 1
        )
        var model = try PolicyEditorViewModel(
            acceptedPolicy: try policy(),
            candidateInventory: PolicyCandidateInventory(observations: [
                observation(blenny, pid: 10), observation(revealable, pid: 20),
                observation(hidden, pid: 30),
            ]),
            systemItems: [bluetooth],
            blennyBundleIdentifier: blenny
        )
        #expect(model.effectiveSystemItemPolicy(
            for: SystemMenuBarItemObservation.bluetoothIdentifier
        ) == .visible)
        #expect(model.assignBluetooth(to: .hidden) == .changed)
        #expect(model.hasDraftChanges)
        #expect(model.draft.bluetoothPolicy == .hidden)

        let persistedHidden = try PersistentBundlePolicyDocument(
            managementEnabled: true,
            policies: model.acceptedPolicy.policies,
            bluetoothPolicy: .hidden
        )
        let relaunched = try PolicyEditorViewModel(
            acceptedPolicy: persistedHidden,
            candidateInventory: model.candidateInventory,
            systemItems: [],
            blennyBundleIdentifier: blenny
        )
        #expect(relaunched.systemItems.map(\.observationIdentifier) == [
            SystemMenuBarItemObservation.bluetoothIdentifier,
        ])
        #expect(relaunched.systemItems.first?.observationCount == 0)
        #expect(relaunched.effectiveSystemItemPolicy(
            for: SystemMenuBarItemObservation.bluetoothIdentifier
        ) == .hidden)
    }

    @Test("A Debug catalog identity moves by exact AX identifier and retains a missing recovery row")
    func systemItemDraftAndRecoveryRetention() throws {
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        let wifi = "com.apple.menuextra.wifi"
        let observedWiFi = SystemMenuBarItemObservation(
            observationIdentifier: wifi,
            ownerBundleIdentifier: "com.apple.MenuBarAgent",
            displayName: "Wi-Fi",
            observationCount: 1
        )
        var model = try PolicyEditorViewModel(
            acceptedPolicy: try policy(),
            candidateInventory: PolicyCandidateInventory(observations: [
                observation(blenny, pid: 10), observation(revealable, pid: 20),
            ]),
            systemItems: [observedWiFi],
            blennyBundleIdentifier: blenny
        )

        #expect(model.assignSystemItem(identifier: wifi, to: .hidden) == .changed)
        #expect(model.effectiveSystemItemPolicy(for: wifi) == .hidden)
        #expect(model.draft.systemItemPolicies == [wifi: .hidden])

        let accepted = try PersistentBundlePolicyDocument(
            managementEnabled: false,
            policies: model.acceptedPolicy.policies,
            systemItemPolicies: [wifi: .hidden]
        )
        let relaunched = try PolicyEditorViewModel(
            acceptedPolicy: accepted,
            candidateInventory: model.candidateInventory,
            systemItems: [],
            blennyBundleIdentifier: blenny
        )
        #expect(relaunched.systemItems.map(\.observationIdentifier) == [wifi])
        #expect(relaunched.systemItems.first?.observationCount == 0)
        #expect(relaunched.effectiveSystemItemPolicy(for: wifi) == .hidden)
        #endif
    }

    @Test("Persistent system items expose all three policies without a live AX row")
    func persistentSystemItemsAreThreeStateCandidates() throws {
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        var model = try PolicyEditorViewModel(
            acceptedPolicy: try policy(),
            candidateInventory: PolicyCandidateInventory(observations: [
                observation(blenny, pid: 10), observation(revealable, pid: 20),
            ]),
            systemItems: [],
            blennyBundleIdentifier: blenny
        )

        for target in SharedSystemItemTrialTarget.allCases where target != .nowPlaying {
            let identifier = target.observationIdentifier
            #expect(model.effectiveSystemItemPolicy(for: identifier) == .visible)
            #expect(model.assignSystemItem(identifier: identifier, to: .revealable) == .changed)
            #expect(model.effectiveSystemItemPolicy(for: identifier) == .revealable)
            #expect(model.assignSystemItem(identifier: identifier, to: .hidden) == .changed)
            #expect(model.effectiveSystemItemPolicy(for: identifier) == .hidden)
            #expect(model.assignSystemItem(identifier: identifier, to: .visible) == .changed)
            #expect(model.effectiveSystemItemPolicy(for: identifier) == .visible)
        }
        #endif
    }

    @Test("Composite persistent observations resolve to three-state policy identifiers")
    func compositePersistentObservationsUseThreeStatePolicy() throws {
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        var model = try PolicyEditorViewModel(
            acceptedPolicy: try policy(),
            candidateInventory: PolicyCandidateInventory(observations: [
                observation(blenny, pid: 10), observation(revealable, pid: 20),
            ]),
            systemItems: [],
            blennyBundleIdentifier: blenny
        )
        let composites = [
            "com.apple.systemuiserver|:siri|axmenubaritem",
            "com.apple.systemuiserver|:time machine|axmenubaritem",
            "18:blenny-identity-v2|15:com.apple.campo|0:|9:spotlight|13:axmenubaritem|11:axmenuextra|1:0",
        ]
        for composite in composites {
            let canonical = try #require(
                PersistentSystemItemPolicyCatalog.controllableItem(
                    forObservationIdentifier: composite
                )?.identifier
            )
            #expect(model.assignSystemItem(identifier: canonical, to: .revealable) == .changed)
            #expect(model.effectiveSystemItemPolicy(for: canonical) == .revealable)
        }
        #endif
    }

    @Test("Now Playing legacy intent survives while new policy assignments are rejected")
    func nowPlayingIsRecoveryOnly() throws {
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        let id = SharedSystemItemTrialTarget.nowPlaying.observationIdentifier
        for saved in MenuBarBundlePolicy.allCases {
            let accepted = try PersistentBundlePolicyDocument(
                managementEnabled: false,
                policies: [.init(bundleIdentifier: blenny, policy: .visible)],
                systemItemPolicies: [id: saved]
            )
            var model = try PolicyEditorViewModel(
                acceptedPolicy: accepted,
                candidateInventory: PolicyCandidateInventory(observations: []),
                systemItems: [], blennyBundleIdentifier: blenny
            )
            #expect(model.effectiveSystemItemPolicy(for: id) == nil)
            for destination in MenuBarBundlePolicy.allCases {
                #expect(model.assignSystemItem(identifier: id, to: destination) == .unknownCandidate)
            }
            #expect(model.draft.systemItemPolicies[id] == saved)
            for presentation in [RevealSessionPresentation.baseline, .revealed] {
                let plan = try RevealAllowlistPlanner.plan(
                    presentation: presentation,
                    assignments: BundlePolicyAssignments(visible: [blenny], revealable: [], hidden: []),
                    observedRunningBundleIdentifiers: [], blennyBundleIdentifier: blenny,
                    systemItemPolicies: [id: saved]
                )
                #expect(plan.persistentSystemItems[id] == .restored)
            }
        }
        #endif
    }

    @Test("Fixed and unknown Apple observations never acquire a policy control")
    func fixedAndUnknownSystemItemsStayReadOnly() throws {
        let clock = SystemMenuBarItemObservation(
            observationIdentifier: SystemMenuBarItemObservation.clockIdentifier,
            ownerBundleIdentifier: "com.apple.MenuBarAgent",
            displayName: "Clock",
            observationCount: 1
        )
        let siri = SystemMenuBarItemObservation(
            observationIdentifier: "siri",
            ownerBundleIdentifier: "com.apple.systemuiserver",
            displayName: "Siri",
            observationCount: 1
        )
        var model = try PolicyEditorViewModel(
            acceptedPolicy: try policy(),
            candidateInventory: PolicyCandidateInventory(observations: [
                observation(blenny, pid: 10), observation(revealable, pid: 20),
            ]),
            systemItems: [clock, siri],
            blennyBundleIdentifier: blenny
        )
        #expect(model.effectiveSystemItemPolicy(
            for: SystemMenuBarItemObservation.clockIdentifier
        ) == nil)
        #expect(model.effectiveSystemItemPolicy(for: "siri") == nil)
        #expect(model.assignSystemItem(
            identifier: SystemMenuBarItemObservation.clockIdentifier,
            to: .hidden
        ) == .unknownCandidate)
        #expect(model.assignSystemItem(identifier: "siri", to: .hidden) == .unknownCandidate)
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

    @Test("Stop synchronizes accepted policy without discarding unapplied assignments")
    func stopPreservesDraft() throws {
        let accepted = try policy().settingManagementEnabled(true)
        var model = try PolicyEditorViewModel(
            acceptedPolicy: accepted,
            candidateInventory: PolicyCandidateInventory(observations: [
                observation(blenny, pid: 10), observation(revealable, pid: 20),
                observation(hidden, pid: 30)
            ]),
            blennyBundleIdentifier: blenny
        )
        _ = model.assign(bundleIdentifier: revealable, to: .hidden)
        let stopped = try accepted.settingManagementEnabled(false)
        let synchronized = try model.synchronizingAcceptedPolicy(stopped, preservingDraft: true)
        #expect(synchronized.acceptedPolicy == stopped)
        #expect(synchronized.draft == model.draft)
        #expect(synchronized.hasDraftChanges)
        let reset = try model.synchronizingAcceptedPolicy(stopped, preservingDraft: false)
        #expect(!reset.hasDraftChanges)
    }

    @Test("Accessibility prompt repeats only after a new process lifetime")
    func onboardingPromptPolicy() {
        var state = AccessibilityOnboardingState()
        #expect(
            state.nextAction(isTrusted: true) == .alreadyGranted
        )
        #expect(
            state.nextAction(isTrusted: false) == .requestSystemPrompt
        )
        #expect(
            state.nextAction(isTrusted: false) == .openSystemSettings
        )

        var reopenedApp = AccessibilityOnboardingState()
        #expect(reopenedApp.nextAction(isTrusted: false) == .requestSystemPrompt)
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
        bundleIdentifier: String?,
        pid: Int32,
        itemHelp: String? = nil,
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
            itemHelp: itemHelp,
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
        description: String?,
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
