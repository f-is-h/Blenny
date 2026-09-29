import Testing
@testable import BlennyCore

@Suite("Revealable policy planning")
struct RevealablePolicyTests {
    private let visible = "com.example.Visible"
    private let revealable = "com.example.Revealable"
    private let hidden = "com.example.Hidden"
    private let unmanaged = "com.example.Unmanaged"
    private let blenny = "xyz.fi5h.blenny"

    @Test("Visible is present at baseline and during reveal")
    func visibleIsAlwaysPresent() throws {
        let plans = try makePlans()
        #expect(plans.baseline.allowedBundleIdentifiers.contains(visible))
        #expect(plans.revealed.allowedBundleIdentifiers.contains(visible))
    }

    @Test("Revealable is present only during an ordinary reveal session")
    func revealableIsSessionBound() throws {
        let plans = try makePlans()
        #expect(!plans.baseline.allowedBundleIdentifiers.contains(revealable))
        #expect(plans.revealed.allowedBundleIdentifiers.contains(revealable))
    }

    @Test("Hidden remains excluded from an ordinary reveal session")
    func hiddenNeverJoinsOrdinaryReveal() throws {
        let plans = try makePlans()
        #expect(!plans.baseline.allowedBundleIdentifiers.contains(hidden))
        #expect(!plans.revealed.allowedBundleIdentifiers.contains(hidden))
    }

    @Test("Unmanaged running bundles and Blenny stay allowed")
    func safetyAllowancesRemainPresent() throws {
        let plans = try makePlans()
        for plan in [plans.baseline, plans.revealed] {
            #expect(plan.allowedBundleIdentifiers.contains(unmanaged))
            #expect(plan.allowedBundleIdentifiers.contains(blenny))
            #expect(plan.allowedSystemItems == Array(0 ..< 9))
        }
    }

    @Test("Bluetooth follows Visible, Revealable and Hidden intent")
    func bluetoothPolicyPlanning() throws {
        let assignments = try BundlePolicyAssignments(
            visible: [visible], revealable: [revealable], hidden: [hidden]
        )
        func plan(
            _ presentation: RevealSessionPresentation,
            _ policy: MenuBarBundlePolicy
        ) throws -> RevealAllowlistPlan {
            try RevealAllowlistPlanner.plan(
                presentation: presentation,
                assignments: assignments,
                observedRunningBundleIdentifiers: [visible, revealable, hidden],
                blennyBundleIdentifier: blenny,
                bluetoothPolicy: policy
            )
        }

        #expect(try plan(.baseline, .visible).allowedSystemItems.contains(1))
        #expect(try plan(.revealed, .visible).allowedSystemItems.contains(1))
        #expect(!((try plan(.baseline, .revealable)).allowedSystemItems.contains(1)))
        #expect(try plan(.revealed, .revealable).allowedSystemItems.contains(1))
        #expect(!((try plan(.baseline, .hidden)).allowedSystemItems.contains(1)))
        #expect(!((try plan(.revealed, .hidden)).allowedSystemItems.contains(1)))
        for protected in [0, 2, 6, 8] {
            #expect(try plan(.baseline, .hidden).allowedSystemItems.contains(protected))
        }
    }

    @Test("Persistent system items map all three policies across reveal sessions")
    func persistentSystemItemPolicyPlanning() throws {
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        let assignments = try BundlePolicyAssignments(
            visible: [visible], revealable: [revealable], hidden: [hidden]
        )
        let policies: [String: MenuBarBundlePolicy] = [
            SharedSystemItemTrialTarget.siri.observationIdentifier: .visible,
            SharedSystemItemTrialTarget.timeMachine.observationIdentifier: .revealable,
            SharedSystemItemTrialTarget.nowPlaying.observationIdentifier: .hidden,
        ]
        let baseline = try RevealAllowlistPlanner.plan(
            presentation: .baseline,
            assignments: assignments,
            observedRunningBundleIdentifiers: [],
            blennyBundleIdentifier: blenny,
            systemItemPolicies: policies
        )
        let revealed = try RevealAllowlistPlanner.plan(
            presentation: .revealed,
            assignments: assignments,
            observedRunningBundleIdentifiers: [],
            blennyBundleIdentifier: blenny,
            systemItemPolicies: policies
        )

        #expect(baseline.persistentSystemItems == [
            SharedSystemItemTrialTarget.siri.observationIdentifier: .restored,
            SharedSystemItemTrialTarget.timeMachine.observationIdentifier: .hidden,
            SharedSystemItemTrialTarget.nowPlaying.observationIdentifier: .restored,
        ])
        #expect(revealed.persistentSystemItems == [
            SharedSystemItemTrialTarget.siri.observationIdentifier: .restored,
            SharedSystemItemTrialTarget.timeMachine.observationIdentifier: .revealed,
            SharedSystemItemTrialTarget.nowPlaying.observationIdentifier: .restored,
        ])
        #endif
    }

    @Test("Overlapping bundle policies fail closed")
    func overlappingPoliciesAreRejected() {
        #expect(throws: BundlePolicyAssignmentsError.self) {
            _ = try BundlePolicyAssignments(
                visible: [visible],
                revealable: [visible],
                hidden: []
            )
        }
    }

    @Test("Hidden stays excluded through both ordinary reveal entries")
    func hiddenIsExcludedForBothEntries() throws {
        let assignments = try BundlePolicyAssignments(
            visible: [visible],
            revealable: [revealable],
            hidden: [hidden]
        )
        let observed = Set([visible, revealable, hidden, unmanaged])

        for entryPoint in [RevealEntryPoint.nativeOverflow, .blennyFallback] {
            var reducer = RevealSessionReducer(entryPoint: entryPoint)
            let disposition: RevealSessionEventDisposition
            switch entryPoint {
            case .nativeOverflow:
                disposition = reducer.reduce(
                    .nativeOverflowChanged(expanded: true, sequence: 1)
                )
            case .blennyFallback:
                disposition = reducer.reduce(.blennyFallbackToggled(sequence: 1))
            }
            #expect(disposition == .transitionRequired(.revealed))

            let plan = try RevealAllowlistPlanner.plan(
                presentation: reducer.presentation,
                assignments: assignments,
                observedRunningBundleIdentifiers: observed,
                blennyBundleIdentifier: blenny
            )
            #expect(plan.allowedBundleIdentifiers.contains(visible))
            #expect(plan.allowedBundleIdentifiers.contains(revealable))
            #expect(!plan.allowedBundleIdentifiers.contains(hidden))
        }
    }

    @Test("Native overflow is preferred when present")
    func nativeEntrySelection() throws {
        #expect(
            try RevealEntryPointSelector.select(
                nativeOverflowPresent: true,
                blennyFallbackInstalled: true
            ) == .nativeOverflow
        )
    }

    @Test("Installed Blenny is the fallback when native overflow is absent")
    func fallbackEntrySelection() throws {
        #expect(
            try RevealEntryPointSelector.select(
                nativeOverflowPresent: false,
                blennyFallbackInstalled: true
            ) == .blennyFallback
        )
    }

    @Test("No usable reveal entry fails closed")
    func missingEntryFailsClosed() {
        #expect(throws: RevealEntryPointSelectionError.self) {
            _ = try RevealEntryPointSelector.select(
                nativeOverflowPresent: false,
                blennyFallbackInstalled: false
            )
        }
    }

    @Test("Availability changes never pass through an entryless state")
    func availabilityChangesKeepAnEntry() {
        var reducer = RevealSessionReducer(entryPoint: .nativeOverflow)
        #expect(
            reducer.reduce(
                .entryAvailabilityChanged(
                    nativeOverflowPresent: false,
                    blennyFallbackInstalled: true,
                    sequence: 1
                )
            ) == .entryPointChanged(.blennyFallback)
        )
        #expect(reducer.entryPoint == .blennyFallback)

        #expect(
            reducer.reduce(
                .entryAvailabilityChanged(
                    nativeOverflowPresent: true,
                    blennyFallbackInstalled: true,
                    sequence: 2
                )
            ) == .entryPointChanged(.nativeOverflow)
        )
        #expect(reducer.entryPoint == .nativeOverflow)
    }

    @Test("Duplicate and out-of-order AX events cannot create a write loop")
    func duplicateAndOutOfOrderEventsAreIgnored() {
        var reducer = RevealSessionReducer(entryPoint: .nativeOverflow)
        #expect(
            reducer.reduce(.nativeOverflowChanged(expanded: true, sequence: 10))
                == .transitionRequired(.revealed)
        )
        #expect(
            reducer.reduce(.nativeOverflowChanged(expanded: true, sequence: 10))
                == .ignoredDuplicateOrOutOfOrder
        )
        #expect(
            reducer.reduce(.nativeOverflowChanged(expanded: false, sequence: 9))
                == .ignoredDuplicateOrOutOfOrder
        )
        #expect(
            reducer.reduce(.nativeOverflowChanged(expanded: true, sequence: 11))
                == .noChange
        )
        #expect(reducer.presentation == .revealed)
    }

    @Test("Inactive entry events never trigger assertion writes")
    func inactiveEntryIsIgnored() {
        var reducer = RevealSessionReducer(entryPoint: .nativeOverflow)
        #expect(
            reducer.reduce(.blennyFallbackToggled(sequence: 1))
                == .ignoredInactiveEntryPoint
        )
        #expect(reducer.presentation == .baseline)
    }

    @Test("Timeout conceals a revealed session exactly once")
    func timeoutReturnsToBaseline() {
        var reducer = RevealSessionReducer(
            presentation: .revealed,
            entryPoint: .blennyFallback
        )
        #expect(
            reducer.reduce(.sessionTimedOut(sequence: 1))
                == .transitionRequired(.baseline)
        )
        #expect(reducer.reduce(.sessionTimedOut(sequence: 2)) == .noChange)
    }

    @Test("Fallback remains usable if revealing creates native overflow")
    func fallbackSessionHasNoEntryGap() {
        var reducer = RevealSessionReducer(
            presentation: .revealed,
            entryPoint: .blennyFallback
        )
        #expect(
            reducer.reduce(
                .entryAvailabilityChanged(
                    nativeOverflowPresent: true,
                    blennyFallbackInstalled: true,
                    sequence: 1
                )
            ) == .noChange
        )
        #expect(reducer.entryPoint == .blennyFallback)
        #expect(
            reducer.reduce(.nativeOverflowChanged(expanded: true, sequence: 2))
                == .ignoredInactiveEntryPoint
        )
        #expect(
            reducer.reduce(.blennyFallbackToggled(sequence: 3))
                == .transitionRequired(.baseline)
        )
        #expect(reducer.entryPoint == .nativeOverflow)
    }

    @Test("Connection invalidation requests restoration")
    func connectionInvalidationRestores() {
        var reducer = RevealSessionReducer(
            presentation: .revealed,
            entryPoint: .blennyFallback
        )
        #expect(
            reducer.reduce(.connectionInvalidated(sequence: 1))
                == .restoreRequired
        )
        #expect(reducer.presentation == .baseline)
    }

    @Test("Plan fingerprint is stable across input ordering")
    func planFingerprintIsDeterministic() {
        let first = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [2, 0, 1],
            allowedBundleIdentifiers: [hidden, visible, revealable]
        )
        let reordered = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [1, 2, 0],
            allowedBundleIdentifiers: [revealable, hidden, visible]
        )
        #expect(first.fingerprint == reordered.fingerprint)
    }

    @Test("Any exact plan change produces a different fingerprint")
    func planFingerprintDetectsChange() {
        let baseline = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 1, 2],
            allowedBundleIdentifiers: [visible]
        )
        let revealed = RevealAllowlistPlan(
            presentation: .revealed,
            allowedSystemItems: [0, 1, 2],
            allowedBundleIdentifiers: [visible, revealable]
        )
        #expect(baseline.fingerprint != revealed.fingerprint)
    }

    @Test("Persistent system-item state participates in every plan fingerprint")
    func persistentStateChangesFingerprint() {
        let identifier = SharedSystemItemTrialTarget.nowPlaying.observationIdentifier
        let visiblePlan = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 1, 2],
            allowedBundleIdentifiers: [visible],
            persistentSystemItems: [identifier: .restored]
        )
        let hiddenPlan = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 1, 2],
            allowedBundleIdentifiers: [visible],
            persistentSystemItems: [identifier: .hidden]
        )
        #expect(visiblePlan.fingerprint != hiddenPlan.fingerprint)
        #expect(visiblePlan.authorizationFingerprint(for: [])
            != hiddenPlan.authorizationFingerprint(for: []))
        let assignments = try? BundlePolicyAssignments(
            visible: [visible], revealable: [], hidden: []
        )
        #expect(assignments != nil)
        if let assignments {
            #expect(visiblePlan.managedPolicyFingerprint(assignments: assignments)
                != hiddenPlan.managedPolicyFingerprint(assignments: assignments))
        }
    }

    @Test("Managed policy fingerprint ignores unrelated running bundles")
    func managedPolicyFingerprintIgnoresUnrelatedBundles() throws {
        let assignments = try BundlePolicyAssignments(
            visible: [visible],
            revealable: [revealable],
            hidden: [hidden]
        )
        let first = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 1, 2],
            allowedBundleIdentifiers: [visible, "com.example.Unrelated"]
        )
        let changedSnapshot = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [2, 1, 0],
            allowedBundleIdentifiers: [
                visible,
                "com.example.DifferentHelper",
                "com.example.Unrelated",
            ]
        )

        #expect(
            first.managedPolicyFingerprint(assignments: assignments)
                == changedSnapshot.managedPolicyFingerprint(assignments: assignments)
        )
        #expect(first.fingerprint != changedSnapshot.fingerprint)
    }

    @Test("Managed policy fingerprint detects effective managed changes")
    func managedPolicyFingerprintDetectsManagedChanges() throws {
        let assignments = try BundlePolicyAssignments(
            visible: [visible],
            revealable: [revealable],
            hidden: [hidden]
        )
        let baseline = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 1, 2],
            allowedBundleIdentifiers: [visible]
        )
        let revealableIncorrectlyAllowed = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 1, 2],
            allowedBundleIdentifiers: [visible, revealable]
        )
        let changedSystemItems = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 1],
            allowedBundleIdentifiers: [visible]
        )
        let revealed = RevealAllowlistPlan(
            presentation: .revealed,
            allowedSystemItems: [0, 1, 2],
            allowedBundleIdentifiers: [visible, revealable]
        )

        let authorized = baseline.managedPolicyFingerprint(assignments: assignments)
        #expect(
            authorized
                != revealableIncorrectlyAllowed.managedPolicyFingerprint(
                    assignments: assignments
                )
        )
        #expect(
            authorized
                != changedSystemItems.managedPolicyFingerprint(assignments: assignments)
        )
        #expect(
            authorized
                != revealed.managedPolicyFingerprint(assignments: assignments)
        )
    }

    @Test("Whole experiment timeout requests complete restoration")
    func experimentTimeoutRestores() {
        var reducer = RevealSessionReducer(
            presentation: .revealed,
            entryPoint: .nativeOverflow
        )
        #expect(
            reducer.reduce(.experimentTimedOut(sequence: 1))
                == .restoreRequired
        )
        #expect(reducer.presentation == .baseline)
    }

    private func makePlans() throws -> (
        baseline: RevealAllowlistPlan,
        revealed: RevealAllowlistPlan
    ) {
        let assignments = try BundlePolicyAssignments(
            visible: [visible],
            revealable: [revealable],
            hidden: [hidden]
        )
        let observed = Set([visible, revealable, hidden, unmanaged])
        return (
            try RevealAllowlistPlanner.plan(
                presentation: .baseline,
                assignments: assignments,
                observedRunningBundleIdentifiers: observed,
                blennyBundleIdentifier: blenny
            ),
            try RevealAllowlistPlanner.plan(
                presentation: .revealed,
                assignments: assignments,
                observedRunningBundleIdentifiers: observed,
                blennyBundleIdentifier: blenny
            )
        )
    }
}
