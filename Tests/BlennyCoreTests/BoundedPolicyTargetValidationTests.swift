import Testing

@testable import BlennyCore

@Suite("Bounded real policy target validation")
struct BoundedPolicyTargetValidationTests {
    private let pinned = "com.example.BlennyProbe"
    private let revealable = "xyz.fi5h.Usage4Claude"
    private let hidden = "pl.maketheweb.cleanshotx"

    @Test("Distinct running bundles with menu extras pass")
    func validTargetsPass() throws {
        try validate(observations: validObservations)
    }

    @Test("Revealable and Hidden cannot be the same bundle")
    func identicalTargetsFailClosed() {
        #expect(throws: BundlePolicyAssignmentsError.self) {
            _ = try BundlePolicyAssignments(
                pinned: [pinned],
                revealable: [revealable],
                hidden: [revealable]
            )
        }
    }

    @Test("Role assignments must match the approved bounded targets")
    func assignmentMismatchFailsClosed() throws {
        let assignments = try BundlePolicyAssignments(
            pinned: [pinned],
            revealable: [revealable],
            hidden: [hidden]
        )
        #expect(
            throws: BoundedPolicyTargetValidationError.assignmentMismatch
        ) {
            try BoundedPolicyTargetValidator.validate(
                assignments: assignments,
                pinnedBundleIdentifier: pinned,
                revealableBundleIdentifier: hidden,
                hiddenBundleIdentifier: revealable,
                observations: validObservations
            )
        }
    }

    @Test("A missing target observation fails closed")
    func missingTargetFailsClosed() {
        #expect(
            throws: BoundedPolicyTargetValidationError.missingObservation(
                bundleIdentifier: hidden
            )
        ) {
            try validate(observations: [validObservations[0]])
        }
    }

    @Test("Multiple observations for one bundle are ambiguous")
    func duplicateTargetFailsClosed() {
        #expect(
            throws: BoundedPolicyTargetValidationError.duplicateObservation(
                bundleIdentifier: revealable
            )
        ) {
            try validate(observations: validObservations + [validObservations[0]])
        }
    }

    @Test("Multiple owner processes for one bundle fail closed")
    func ambiguousProcessFailsClosed() {
        let observations = [
            MenuBarPolicyTargetObservation(
                bundleIdentifier: revealable,
                processIdentifiers: [101, 102],
                menuBarItemCount: 1
            ),
            validObservations[1],
        ]
        #expect(
            throws: BoundedPolicyTargetValidationError.ambiguousProcessOwnership(
                bundleIdentifier: revealable,
                processCount: 2
            )
        ) {
            try validate(observations: observations)
        }
    }

    @Test("A running app without an attributable menu extra fails closed")
    func missingMenuBarOwnershipFailsClosed() {
        let observations = [
            validObservations[0],
            MenuBarPolicyTargetObservation(
                bundleIdentifier: hidden,
                processIdentifiers: [202],
                menuBarItemCount: 0
            ),
        ]
        #expect(
            throws: BoundedPolicyTargetValidationError.missingMenuBarOwnership(
                bundleIdentifier: hidden
            )
        ) {
            try validate(observations: observations)
        }
    }

    private var validObservations: [MenuBarPolicyTargetObservation] {
        [
            MenuBarPolicyTargetObservation(
                bundleIdentifier: revealable,
                processIdentifiers: [101],
                menuBarItemCount: 1
            ),
            MenuBarPolicyTargetObservation(
                bundleIdentifier: hidden,
                processIdentifiers: [202],
                menuBarItemCount: 1
            ),
        ]
    }

    private func validate(
        observations: [MenuBarPolicyTargetObservation]
    ) throws {
        let assignments = try BundlePolicyAssignments(
            pinned: [pinned],
            revealable: [revealable],
            hidden: [hidden]
        )
        try BoundedPolicyTargetValidator.validate(
            assignments: assignments,
            pinnedBundleIdentifier: pinned,
            revealableBundleIdentifier: revealable,
            hiddenBundleIdentifier: hidden,
            observations: observations
        )
    }
}
