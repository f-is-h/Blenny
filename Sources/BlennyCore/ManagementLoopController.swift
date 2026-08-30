import Foundation

public enum ManagementLoopState: Equatable, Sendable {
    case unknown
    case stopped
    case acceptedPolicyLoadedInactive
    case writerActivating
    case baselineVerified(String)
    case active(String)
    case ordinaryRevealSession(String)
    case applying
    case stopping
    case restoring
    case terminating
    case connectionInvalidated
    case unsupportedRuntimeContract(String)
    case failClosedUnrestricted(String)
}

public enum ManagementLoopError: Error, Equatable, Sendable {
    case acceptedPolicyRequiresBaseline
    case activationCouldNotBeVerified
    case managementIsNotActive
}

public actor ManagementLoopController {
    public typealias WriterProvider = @Sendable () async throws -> any PolicyAssertionWriting

    private let writerProvider: WriterProvider
    private var writer: (any PolicyAssertionWriting)?
    public private(set) var state: ManagementLoopState = .unknown

    public init(writerProvider: @escaping WriterProvider) {
        self.writerProvider = writerProvider
    }

    public func recover(
        acceptedPolicy: PersistentBundlePolicyDocument,
        baseline: RevealAllowlistPlan?
    ) async -> ManagementLoopState {
        guard acceptedPolicy.managementEnabled else {
            await restoreAndStop(detail: "persisted management is stopped")
            state = .stopped
            return state
        }
        guard let baseline else {
            await restoreAndStop(detail: "accepted policy has no valid baseline")
            return state
        }

        state = .acceptedPolicyLoadedInactive
        do {
            let writer = try await writerForTransaction()
            state = .writerActivating
            try await writer.applyBaselineReplacement(with: baseline)
            guard try await writer.verifyActivePlan(baseline) else {
                throw ManagementLoopError.activationCouldNotBeVerified
            }
            state = .baselineVerified(baseline.fingerprint)
            state = .active(baseline.fingerprint)
        } catch {
            await restoreAndStop(detail: "startup recovery failed: \(error)")
        }
        return state
    }

    public func writerForTransaction() async throws -> any PolicyAssertionWriting {
        if let writer { return writer }
        switch state {
        case .failClosedUnrestricted, .unsupportedRuntimeContract, .connectionInvalidated:
            return UnrestrictedPolicyAssertionWriter()
        default:
            break
        }
        do {
            let created = try await writerProvider()
            writer = created
            return created
        } catch {
            state = .unsupportedRuntimeContract(String(describing: error))
            throw error
        }
    }

    public func synchronizeCommittedPolicy(
        _ policy: PersistentBundlePolicyDocument,
        baseline: RevealAllowlistPlan?
    ) async throws {
        guard policy.managementEnabled else {
            await restoreAndStop(detail: "management stopped by committed policy")
            state = .stopped
            return
        }
        guard let baseline, let writer else {
            await restoreAndStop(detail: "committed policy has no active baseline")
            throw ManagementLoopError.acceptedPolicyRequiresBaseline
        }
        guard try await writer.verifyActivePlan(baseline) else {
            await restoreAndStop(detail: "committed baseline verification failed")
            throw ManagementLoopError.activationCouldNotBeVerified
        }
        state = .active(baseline.fingerprint)
    }

    public func beginTransaction() {
        switch state {
        case .active, .stopped:
            state = .applying
        default:
            break
        }
    }

    public func beginOrdinaryReveal(_ plan: RevealAllowlistPlan) async throws {
        guard case .active = state, let writer else {
            throw ManagementLoopError.managementIsNotActive
        }
        try await writer.applySessionTransition(with: plan)
        guard try await writer.verifyActivePlan(plan) else {
            await restoreAndStop(detail: "ordinary reveal verification failed")
            throw ManagementLoopError.activationCouldNotBeVerified
        }
        state = .ordinaryRevealSession(plan.fingerprint)
    }

    public func endOrdinaryReveal(_ baseline: RevealAllowlistPlan) async throws {
        guard case .ordinaryRevealSession = state, let writer else {
            throw ManagementLoopError.managementIsNotActive
        }
        do {
            try await writer.applySessionTransition(with: baseline)
            guard try await writer.verifyActivePlan(baseline) else {
                throw ManagementLoopError.activationCouldNotBeVerified
            }
            state = .active(baseline.fingerprint)
        } catch {
            await restoreAndStop(detail: "ordinary reveal could not restore baseline")
            throw error
        }
    }

    public func stop() async {
        state = .stopping
        await restoreAndStop(detail: "management stopped")
        state = .stopped
    }

    public func failClosed(_ detail: String) async {
        await restoreAndStop(detail: detail)
    }

    public func connectionInvalidated() async {
        state = .connectionInvalidated
        if let writer {
            await writer.connectionInvalidated()
        }
        writer = nil
        state = .failClosedUnrestricted("writer connection invalidated")
    }

    public func terminate() async {
        state = .terminating
        if let writer {
            await writer.restoreAndStop()
        }
        writer = nil
        state = .failClosedUnrestricted("application termination restored assertions")
    }

    public func activePlanSnapshot() async -> RevealAllowlistPlan? {
        await writer?.activePlanSnapshot()
    }

    private func restoreAndStop(detail: String) async {
        if let writer {
            await writer.restoreAndStop()
        }
        writer = nil
        state = .failClosedUnrestricted(detail)
    }
}

private actor UnrestrictedPolicyAssertionWriter: PolicyAssertionWriting {
    func applyBaselineReplacement(with plan: RevealAllowlistPlan) async throws {
        throw ManagementLoopError.managementIsNotActive
    }

    func applySessionTransition(with plan: RevealAllowlistPlan) async throws {
        throw ManagementLoopError.managementIsNotActive
    }

    func verifyActivePlan(_ expected: RevealAllowlistPlan) async throws -> Bool {
        false
    }

    func restoreAndStop() async {}

    func connectionInvalidated() async {}

    func activePlanSnapshot() async -> RevealAllowlistPlan? {
        nil
    }
}
