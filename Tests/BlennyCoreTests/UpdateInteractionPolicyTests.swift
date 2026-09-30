import Testing
@testable import BlennyCore

struct UpdateInteractionPolicyTests {
    @Test func unfinishedWorkBlocksAutomaticAndManualUpdates() {
        for draft in [false, true] {
            for busy in [false, true] {
                for recovery in [false, true] {
                    #expect(UpdateInteractionPolicy.allowsCheck(
                        hasDraft: draft, isBusy: busy, recoveryPending: recovery
                    ) == (!draft && !busy && !recovery))
                }
            }
        }
    }
}
