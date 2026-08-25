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
            reducer.reduce(.blennyFallbackToggled(sequence: 2))
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
