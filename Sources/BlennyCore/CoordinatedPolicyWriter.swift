import Foundation

public enum CoordinatedPolicyWriterError: Error, Equatable, Sendable {
    case restorationFailed
}

public protocol PersistentSystemItemPlanWriting: Sendable {
    func applyManagedPlan(
        _ plan: [String: PersistentSystemItemPresentation]
    ) async throws
    func verifyManagedPlan(
        _ plan: [String: PersistentSystemItemPresentation]
    ) async throws -> Bool
    func finalizeCommittedPlan(
        _ plan: [String: PersistentSystemItemPresentation]
    ) async
    func restoreAllManagedItems() async -> Bool
}

/// The sole policy mutation coordinator. Assertion replacement and durable
/// system-item preference changes are serialized as one logical transition.
public actor CoordinatedPolicyWriter: PolicyAssertionWriting {
    private let assertionWriter: any PolicyAssertionWriting
    private let persistentWriter: any PersistentSystemItemPlanWriting
    private var activePlan: RevealAllowlistPlan?
    private var stopped = false

    public init(
        assertionWriter: any PolicyAssertionWriting,
        persistentWriter: any PersistentSystemItemPlanWriting
    ) {
        self.assertionWriter = assertionWriter
        self.persistentWriter = persistentWriter
    }

    public func applyBaselineReplacement(
        with plan: RevealAllowlistPlan
    ) async throws {
        guard !stopped, plan.presentation == .baseline else {
            throw RevealAssertionWriterError.invalidBaselineReplacement
        }
        try await transition(to: plan, baselineReplacement: true)
    }

    public func applySessionTransition(
        with plan: RevealAllowlistPlan
    ) async throws {
        guard !stopped else { throw RevealAssertionWriterError.writerStopped }
        try await transition(to: plan, baselineReplacement: false)
    }

    public func verifyActivePlan(
        _ expected: RevealAllowlistPlan
    ) async throws -> Bool {
        guard !stopped, activePlan == expected,
              try await assertionWriter.verifyActivePlan(expected) else {
            return false
        }
        return try await persistentWriter.verifyManagedPlan(
            expected.persistentSystemItems
        )
    }

    public func finalizeCommittedPlan(_ plan: RevealAllowlistPlan) async {
        guard activePlan == plan else { return }
        await persistentWriter.finalizeCommittedPlan(plan.persistentSystemItems)
    }

    public func restoreAndStop() async {
        stopped = true
        await assertionWriter.restoreAndStop()
        if await persistentWriter.restoreAllManagedItems() {
            activePlan = nil
        }
    }

    public func connectionInvalidated() async {
        stopped = true
        await assertionWriter.connectionInvalidated()
        if await persistentWriter.restoreAllManagedItems() {
            activePlan = nil
        }
    }

    public func activePlanSnapshot() -> RevealAllowlistPlan? {
        activePlan
    }

    private func transition(
        to plan: RevealAllowlistPlan,
        baselineReplacement: Bool
    ) async throws {
        if activePlan == plan { return }
        let previous = activePlan
        try await persistentWriter.applyManagedPlan(plan.persistentSystemItems)
        do {
            if baselineReplacement {
                try await assertionWriter.applyBaselineReplacement(with: plan)
            } else {
                try await assertionWriter.applySessionTransition(with: plan)
            }
            activePlan = plan
        } catch {
            if !baselineReplacement, plan.presentation == .baseline {
                stopped = true
                await assertionWriter.restoreAndStop()
                _ = await persistentWriter.restoreAllManagedItems()
                activePlan = nil
            } else if let previous {
                do {
                    try await persistentWriter.applyManagedPlan(
                        previous.persistentSystemItems
                    )
                    await persistentWriter.finalizeCommittedPlan(
                        previous.persistentSystemItems
                    )
                    activePlan = previous
                } catch {
                    stopped = true
                    await assertionWriter.restoreAndStop()
                    _ = await persistentWriter.restoreAllManagedItems()
                    activePlan = nil
                    throw CoordinatedPolicyWriterError.restorationFailed
                }
            } else {
                stopped = true
                await assertionWriter.restoreAndStop()
                _ = await persistentWriter.restoreAllManagedItems()
                activePlan = nil
            }
            throw error
        }
    }
}
