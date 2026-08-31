import Testing
@testable import BlennyCore

@Suite("Read-only native observation lifetime")
struct NativeOverflowObservationPolicyTests {
    @Test("Observation depends on trust and process lifetime, not management or backend", arguments: [
        (true, false, false, true), (false, false, false, false),
        (true, true, false, false), (true, false, true, false)
    ])
    func lifetime(_ values: (Bool, Bool, Bool, Bool)) {
        #expect(NativeOverflowObservationPolicy.shouldObserve(
            accessibilityTrusted: values.0, isTerminating: values.1, restartRequired: values.2
        ) == values.3)
    }

    @Test("Read recovery permits one later event, then requires explicit Refresh")
    func boundedRecovery() {
        var recovery = NativeOverflowReadRecovery()
        #expect(recovery.allowsEventRead)
        recovery.failed()
        #expect(recovery.allowsEventRead)
        recovery.failed()
        for _ in 0..<10 {
            #expect(!recovery.allowsEventRead)
            recovery.failed()
        }
        #expect(recovery.consecutiveFailures == 2)
        recovery.explicitRefresh()
        #expect(recovery.allowsEventRead)
        #expect(recovery.consecutiveFailures == 0)
    }

    @Test("A successful event-driven read ends the failure episode")
    func successfulRecovery() {
        var recovery = NativeOverflowReadRecovery()
        recovery.failed()
        recovery.succeeded()
        #expect(recovery.consecutiveFailures == 0)
        recovery.failed()
        #expect(recovery.allowsEventRead)
    }
}
