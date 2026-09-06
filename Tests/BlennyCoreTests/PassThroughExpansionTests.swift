import Testing
@testable import BlennyCore

@Suite("Additions-only pass-through expansion")
struct PassThroughExpansionTests {
    private let blenny = "xyz.fi5h.blenny"
    private let visible = "com.example.Visible"
    private let revealable = "com.example.Revealable"
    private let hidden = "com.example.Hidden"

    @Test("Adds only unaccepted launched bundles to both plans")
    func preparesAdditionsOnlyExpansion() throws {
        let expansion = try #require(try PassThroughExpansion.prepare(
            baseline: baseline(),
            reveal: reveal(),
            acceptedBundleIdentifiers: [blenny, visible, revealable, hidden],
            launchedBundleIdentifiers: ["com.example.Zulu", "com.example.Alpha"]
        ))

        #expect(expansion.addedBundleIdentifiers == ["com.example.Alpha", "com.example.Zulu"])
        #expect(expansion.baseline.presentation == .baseline)
        #expect(expansion.reveal.presentation == .revealed)
        #expect(expansion.baseline.allowedSystemItems == [0, 2, 3])
        #expect(expansion.reveal.allowedSystemItems == [0, 1, 2, 3])
        #expect(expansion.baseline.allowedBundleIdentifiers == [
            blenny, visible, "com.example.Existing", "com.example.Alpha", "com.example.Zulu",
        ])
        #expect(expansion.reveal.allowedBundleIdentifiers == [
            blenny, visible, revealable, "com.example.Existing", "com.example.Alpha", "com.example.Zulu",
        ])
        try PassThroughExpansion.validateReplacement(
            from: baseline(), to: expansion.baseline,
            addedBundleIdentifiers: Set(expansion.addedBundleIdentifiers)
        )
        try PassThroughExpansion.validateReplacement(
            from: reveal(), to: expansion.reveal,
            addedBundleIdentifiers: Set(expansion.addedBundleIdentifiers)
        )
    }

    @Test("Accepted and already allowlisted launches do not expand policy")
    func skipsAcceptedAndExistingBundles() throws {
        #expect(try PassThroughExpansion.prepare(
            baseline: baseline(),
            reveal: reveal(),
            acceptedBundleIdentifiers: [blenny, visible, revealable, hidden],
            launchedBundleIdentifiers: [hidden, revealable, "com.example.Existing"]
        ) == nil)
    }

    @Test("Rejects an unaccepted identifier present in only one plan")
    func rejectsUnacceptedOnePlanOnlyIdentifier() {
        let invalidReveal = RevealAllowlistPlan(
            presentation: .revealed,
            allowedSystemItems: [0, 1, 2, 3],
            allowedBundleIdentifiers: [blenny, visible, revealable, "com.example.Existing", "com.example.Leak"]
        )

        #expect(throws: PassThroughExpansionError.inconsistentUnacceptedBundleIdentifier("com.example.Leak")) {
            try PassThroughExpansion.prepare(
                baseline: baseline(), reveal: invalidReveal,
                acceptedBundleIdentifiers: [blenny, visible, revealable, hidden],
                launchedBundleIdentifiers: ["com.example.New"]
            )
        }
    }

    @Test("Rejects malformed and canonical-duplicate inputs")
    func rejectsMalformedAndDuplicateInputs() {
        #expect(throws: PassThroughExpansionError.invalidBundleIdentifier("not a bundle")) {
            try PassThroughExpansion.prepare(
                baseline: baseline(), reveal: reveal(),
                acceptedBundleIdentifiers: [], launchedBundleIdentifiers: ["not a bundle"]
            )
        }
        #expect(throws: PassThroughExpansionError.duplicateBundleIdentifier("com.example.new")) {
            try PassThroughExpansion.prepare(
                baseline: baseline(), reveal: reveal(),
                acceptedBundleIdentifiers: [],
                launchedBundleIdentifiers: ["com.example.New", "COM.EXAMPLE.NEW"]
            )
        }
    }

    @Test("A burst of duplicate launches produces one addition and no further expansion")
    func burstIsDeduplicated() throws {
        let launches = Set(Array(repeating: "com.example.New", count: 100))
        let expansion = try #require(try PassThroughExpansion.prepare(
            baseline: baseline(), reveal: reveal(),
            acceptedBundleIdentifiers: [blenny, visible, revealable, hidden],
            launchedBundleIdentifiers: launches
        ))
        #expect(expansion.addedBundleIdentifiers == ["com.example.New"])
        #expect(try PassThroughExpansion.prepare(
            baseline: expansion.baseline, reveal: expansion.reveal,
            acceptedBundleIdentifiers: [blenny, visible, revealable, hidden],
            launchedBundleIdentifiers: launches
        ) == nil)
    }

    @Test("Pass-through expansion preserves persistent system-item state exactly")
    func preservesPersistentSystemItems() throws {
        let identifier = SharedSystemItemTrialTarget.timeMachine.observationIdentifier
        let baseline = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 2, 3],
            allowedBundleIdentifiers: self.baseline().allowedBundleIdentifiers,
            persistentSystemItems: [identifier: .hidden]
        )
        let reveal = RevealAllowlistPlan(
            presentation: .revealed,
            allowedSystemItems: [0, 1, 2, 3],
            allowedBundleIdentifiers: self.reveal().allowedBundleIdentifiers,
            persistentSystemItems: [identifier: .revealed]
        )
        let expansion = try #require(try PassThroughExpansion.prepare(
            baseline: baseline,
            reveal: reveal,
            acceptedBundleIdentifiers: [blenny, visible, revealable, hidden],
            launchedBundleIdentifiers: ["com.example.New"]
        ))
        #expect(expansion.baseline.persistentSystemItems == [identifier: .hidden])
        #expect(expansion.reveal.persistentSystemItems == [identifier: .revealed])

        let changed = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: expansion.baseline.allowedSystemItems,
            allowedBundleIdentifiers: expansion.baseline.allowedBundleIdentifiers,
            persistentSystemItems: [identifier: .restored]
        )
        #expect(throws: PassThroughExpansionError.replacementPersistentSystemItemsChanged) {
            try PassThroughExpansion.validateReplacement(
                from: baseline,
                to: changed,
                addedBundleIdentifiers: Set(expansion.addedBundleIdentifiers)
            )
        }
    }

    @Test("Rejects incorrectly labeled plans")
    func rejectsIncorrectPresentations() {
        let wrongBaseline = RevealAllowlistPlan(
            presentation: .revealed,
            allowedSystemItems: [0, 2, 3],
            allowedBundleIdentifiers: baseline().allowedBundleIdentifiers
        )
        #expect(throws: PassThroughExpansionError.invalidBaselinePresentation) {
            try PassThroughExpansion.prepare(
                baseline: wrongBaseline, reveal: reveal(),
                acceptedBundleIdentifiers: [], launchedBundleIdentifiers: ["com.example.New"]
            )
        }
    }

    @Test("Replacement validator rejects every non-additive change")
    func replacementValidatorRejectsNonAdditiveChange() throws {
        let expansion = try #require(try PassThroughExpansion.prepare(
            baseline: baseline(), reveal: reveal(),
            acceptedBundleIdentifiers: [blenny, visible, revealable, hidden],
            launchedBundleIdentifiers: ["com.example.New"]
        ))
        let additions = Set(expansion.addedBundleIdentifiers)
        let removed = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 2, 3],
            allowedBundleIdentifiers: [blenny, visible, "com.example.New"]
        )
        let extra = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 2, 3],
            allowedBundleIdentifiers: expansion.baseline.allowedBundleIdentifiers + ["com.example.Extra"]
        )
        let changedSystemItems = RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 2],
            allowedBundleIdentifiers: expansion.baseline.allowedBundleIdentifiers
        )

        #expect(throws: PassThroughExpansionError.replacementBundleIdentifiersChanged) {
            try PassThroughExpansion.validateReplacement(
                from: baseline(), to: removed, addedBundleIdentifiers: additions
            )
        }
        #expect(throws: PassThroughExpansionError.replacementBundleIdentifiersChanged) {
            try PassThroughExpansion.validateReplacement(
                from: baseline(), to: extra, addedBundleIdentifiers: additions
            )
        }
        #expect(throws: PassThroughExpansionError.replacementSystemItemsChanged) {
            try PassThroughExpansion.validateReplacement(
                from: baseline(), to: changedSystemItems, addedBundleIdentifiers: additions
            )
        }
        #expect(throws: PassThroughExpansionError.emptyReplacementAdditions) {
            try PassThroughExpansion.validateReplacement(
                from: baseline(), to: baseline(), addedBundleIdentifiers: []
            )
        }
        #expect(throws: PassThroughExpansionError.replacementBundleIdentifiersChanged) {
            try PassThroughExpansion.validateReplacement(
                from: baseline(), to: baseline(), addedBundleIdentifiers: [blenny]
            )
        }
    }

    private func baseline() -> RevealAllowlistPlan {
        RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: [0, 2, 3],
            allowedBundleIdentifiers: [blenny, visible, "com.example.Existing"]
        )
    }

    private func reveal() -> RevealAllowlistPlan {
        RevealAllowlistPlan(
            presentation: .revealed,
            allowedSystemItems: [0, 1, 2, 3],
            allowedBundleIdentifiers: [blenny, visible, revealable, "com.example.Existing"]
        )
    }
}
