import Testing
@testable import BlennyCore

@Suite("Coordinated assertion and persistent system-item writer")
struct CoordinatedPolicyWriterTests {
    private let item = "com.apple.menuextra.now-playing"

    @Test("Reveal and conceal serialize both backend capability families")
    func threeStateSessionLifecycle() async throws {
        let assertion = FakeAssertionWriter()
        let persistent = FakePersistentSystemItemWriter()
        let writer = CoordinatedPolicyWriter(
            assertionWriter: assertion, persistentWriter: persistent
        )
        let baseline = plan(.baseline, state: .hidden)
        let revealed = plan(.revealed, state: .revealed)

        try await writer.applyBaselineReplacement(with: baseline)
        #expect(try await writer.verifyActivePlan(baseline))
        try await writer.applySessionTransition(with: revealed)
        #expect(try await writer.verifyActivePlan(revealed))
        try await writer.applySessionTransition(with: baseline)
        #expect(try await writer.verifyActivePlan(baseline))
        await writer.restoreAndStop()

        #expect(await assertion.operations() == [
            "baseline:baseline", "session:revealed", "session:baseline", "stop",
        ])
        #expect(await persistent.appliedPlans() == [
            [item: .hidden], [item: .revealed], [item: .hidden],
        ])
        #expect(await persistent.restoreCount() == 1)
        #expect(await writer.activePlanSnapshot() == nil)
    }

    @Test("Failed reveal restores the previous persistent state")
    func failedRevealRollsBackPersistentState() async throws {
        let assertion = FakeAssertionWriter()
        let persistent = FakePersistentSystemItemWriter()
        let writer = CoordinatedPolicyWriter(
            assertionWriter: assertion, persistentWriter: persistent
        )
        let baseline = plan(.baseline, state: .hidden)
        let revealed = plan(.revealed, state: .revealed)
        try await writer.applyBaselineReplacement(with: baseline)
        await assertion.failNextSessionTransition()

        await #expect(throws: FakeWriterError.injected) {
            try await writer.applySessionTransition(with: revealed)
        }
        #expect(await writer.activePlanSnapshot() == baseline)
        #expect(await persistent.currentPlan() == [item: .hidden])
        #expect(await persistent.appliedPlans() == [
            [item: .hidden], [item: .revealed], [item: .hidden],
        ])
        #expect(await persistent.finalizedPlans() == [[item: .hidden]])
    }

    @Test("Failed conceal stops management and restores every persistent receipt")
    func failedConcealStopsAndRestores() async throws {
        let assertion = FakeAssertionWriter()
        let persistent = FakePersistentSystemItemWriter()
        let writer = CoordinatedPolicyWriter(
            assertionWriter: assertion, persistentWriter: persistent
        )
        let baseline = plan(.baseline, state: .hidden)
        let revealed = plan(.revealed, state: .revealed)
        try await writer.applyBaselineReplacement(with: baseline)
        try await writer.applySessionTransition(with: revealed)
        await assertion.failNextSessionTransition()

        await #expect(throws: FakeWriterError.injected) {
            try await writer.applySessionTransition(with: baseline)
        }
        #expect(await assertion.operations().last == "stop")
        #expect(await persistent.restoreCount() == 1)
        #expect(await persistent.currentPlan() == nil)
        #expect(await writer.activePlanSnapshot() == nil)
        await #expect(throws: RevealAssertionWriterError.writerStopped) {
            try await writer.applySessionTransition(with: revealed)
        }
    }

    @Test("Verification requires assertion and persistent states to match")
    func combinedVerification() async throws {
        let assertion = FakeAssertionWriter()
        let persistent = FakePersistentSystemItemWriter()
        let writer = CoordinatedPolicyWriter(
            assertionWriter: assertion, persistentWriter: persistent
        )
        let baseline = plan(.baseline, state: .hidden)
        try await writer.applyBaselineReplacement(with: baseline)
        #expect(try await writer.verifyActivePlan(baseline))
        await persistent.forceVerificationFailure()
        #expect(try await !writer.verifyActivePlan(baseline))
    }

    private func plan(
        _ presentation: RevealSessionPresentation,
        state: PersistentSystemItemPresentation
    ) -> RevealAllowlistPlan {
        RevealAllowlistPlan(
            presentation: presentation,
            allowedSystemItems: [0, 1, 2],
            allowedBundleIdentifiers: ["xyz.fi5h.blenny"],
            persistentSystemItems: [item: state]
        )
    }
}

private enum FakeWriterError: Error, Equatable {
    case injected
}

private actor FakeAssertionWriter: PolicyAssertionWriting {
    private var active: RevealAllowlistPlan?
    private var log: [String] = []
    private var failSession = false

    func applyBaselineReplacement(with plan: RevealAllowlistPlan) async throws {
        log.append("baseline:\(plan.presentation.rawValue)")
        active = plan
    }

    func applySessionTransition(with plan: RevealAllowlistPlan) async throws {
        log.append("session:\(plan.presentation.rawValue)")
        if failSession {
            failSession = false
            throw FakeWriterError.injected
        }
        active = plan
    }

    func restoreAndStop() async {
        log.append("stop")
        active = nil
    }

    func connectionInvalidated() async {
        log.append("invalidated")
        active = nil
    }

    func activePlanSnapshot() async -> RevealAllowlistPlan? { active }

    func failNextSessionTransition() { failSession = true }
    func operations() -> [String] { log }
}

private actor FakePersistentSystemItemWriter: PersistentSystemItemPlanWriting {
    private var current: [String: PersistentSystemItemPresentation]?
    private var applied: [[String: PersistentSystemItemPresentation]] = []
    private var finalized: [[String: PersistentSystemItemPresentation]] = []
    private var restores = 0
    private var verificationFails = false

    func applyManagedPlan(
        _ plan: [String: PersistentSystemItemPresentation]
    ) async throws {
        applied.append(plan)
        current = plan
    }

    func verifyManagedPlan(
        _ plan: [String: PersistentSystemItemPresentation]
    ) async throws -> Bool {
        !verificationFails && current == plan
    }

    func finalizeCommittedPlan(
        _ plan: [String: PersistentSystemItemPresentation]
    ) async {
        finalized.append(plan)
    }

    func restoreAllManagedItems() async -> Bool {
        restores += 1
        current = nil
        return true
    }

    func forceVerificationFailure() { verificationFails = true }
    func currentPlan() -> [String: PersistentSystemItemPresentation]? { current }
    func appliedPlans() -> [[String: PersistentSystemItemPresentation]] { applied }
    func finalizedPlans() -> [[String: PersistentSystemItemPresentation]] { finalized }
    func restoreCount() -> Int { restores }
}
