import Testing
@testable import BlennyCore

@Suite("Revealable policy planning")
struct RevealablePolicyTests {
    private let pinned = "com.example.Pinned"
    private let revealable = "com.example.Revealable"
    private let hidden = "com.example.Hidden"
    private let unmanaged = "com.example.Unmanaged"
    private let blenny = "com.example.BlennyProbe"

    @Test("Pinned is present at baseline and during reveal")
    func pinnedIsAlwaysPresent() throws {
        let plans = try makePlans()
        #expect(plans.baseline.allowedBundleIdentifiers.contains(pinned))
        #expect(plans.revealed.allowedBundleIdentifiers.contains(pinned))
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

    @Test("Overlapping bundle policies fail closed")
    func overlappingPoliciesAreRejected() {
        #expect(throws: BundlePolicyAssignmentsError.self) {
            _ = try BundlePolicyAssignments(
                pinned: [pinned],
                revealable: [pinned],
                hidden: []
            )
        }
    }

    @Test("Hidden stays excluded through both ordinary reveal entries")
    func hiddenIsExcludedForBothEntries() throws {
        let assignments = try BundlePolicyAssignments(
            pinned: [pinned],
            revealable: [revealable],
            hidden: [hidden]
        )
        let observed = Set([pinned, revealable, hidden, unmanaged])

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
            #expect(plan.allowedBundleIdentifiers.contains(pinned))
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
            allowedBundleIdentifiers: [hidden, pinned, revealable]
        )
        let reordered = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [1, 2, 0],
            allowedBundleIdentifiers: [revealable, hidden, pinned]
        )
        #expect(first.fingerprint == reordered.fingerprint)
    }

    @Test("Any exact plan change produces a different fingerprint")
    func planFingerprintDetectsChange() {
        let baseline = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 1, 2],
            allowedBundleIdentifiers: [pinned]
        )
        let revealed = RevealAllowlistPlan(
            presentation: .revealed,
            allowedSystemItems: [0, 1, 2],
            allowedBundleIdentifiers: [pinned, revealable]
        )
        #expect(baseline.fingerprint != revealed.fingerprint)
    }

    @Test("Managed policy fingerprint ignores unrelated running bundles")
    func managedPolicyFingerprintIgnoresUnrelatedBundles() throws {
        let assignments = try BundlePolicyAssignments(
            pinned: [pinned],
            revealable: [revealable],
            hidden: [hidden]
        )
        let first = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 1, 2],
            allowedBundleIdentifiers: [pinned, "com.example.Unrelated"]
        )
        let changedSnapshot = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [2, 1, 0],
            allowedBundleIdentifiers: [
                pinned,
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
            pinned: [pinned],
            revealable: [revealable],
            hidden: [hidden]
        )
        let baseline = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 1, 2],
            allowedBundleIdentifiers: [pinned]
        )
        let revealableIncorrectlyAllowed = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 1, 2],
            allowedBundleIdentifiers: [pinned, revealable]
        )
        let changedSystemItems = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 1],
            allowedBundleIdentifiers: [pinned]
        )
        let revealed = RevealAllowlistPlan(
            presentation: .revealed,
            allowedSystemItems: [0, 1, 2],
            allowedBundleIdentifiers: [pinned, revealable]
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
            pinned: [pinned],
            revealable: [revealable],
            hidden: [hidden]
        )
        let observed = Set([pinned, revealable, hidden, unmanaged])
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
