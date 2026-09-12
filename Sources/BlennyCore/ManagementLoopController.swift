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
    case restorationFailed(String)

    public var canResume: Bool {
        switch self {
        case .stopped, .acceptedPolicyLoadedInactive, .failClosedUnrestricted, .unsupportedRuntimeContract:
            true
        default:
            false
        }
    }
}

public enum ManagementLoopError: Error, Equatable, Sendable {
    case acceptedPolicyRequiresBaseline
    case activationCouldNotBeVerified
    case managementIsNotActive
    case restartRequired
    case staleLifecycleGeneration
}

/// Status severity describes the remaining risk, not how cautious the stop was.
/// Confirmed cleanup is a recoverable pause; unconfirmed cleanup is an error.
public struct ManagementStatusNotice: Equatable, Sendable {
    public let message: String
    public let isError: Bool
}

extension ManagementLoopState {
    public var requiresImmediateProcessExit: Bool {
        if case .restorationFailed = self { return true }
        return false
    }

    public func statusNotice(persistedManagementEnabled: Bool) -> ManagementStatusNotice? {
        switch self {
        case .active:
            ManagementStatusNotice(
                message: "Management is active for the verified policy baseline.", isError: false
            )
        case .stopped:
            ManagementStatusNotice(
                message: "Management is stopped. Draft changes remain local until Apply.", isError: false
            )
        case .unsupportedRuntimeContract:
            ManagementStatusNotice(
                message: "This macOS build is not supported for management. No restrictions were applied.",
                isError: false
            )
        case let .failClosedUnrestricted(detail) where persistedManagementEnabled:
            ManagementStatusNotice(
                message: "Management is paused. Your policy is saved and Blenny's restrictions are removed. \(detail)",
                isError: false
            )
        case let .restorationFailed(detail):
            ManagementStatusNotice(
                message: "Cleanup could not be confirmed. Blenny will quit to release its connection. \(detail)",
                isError: true
            )
        default:
            nil
        }
    }
}

extension ManagementLoopError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .acceptedPolicyRequiresBaseline:
            "The accepted policy has no verified baseline. Management remains inactive."
        case .activationCouldNotBeVerified:
            "Management activation could not be verified. Try Resume again after checking the managed apps."
        case .managementIsNotActive:
            "Management is inactive. Choose Resume to check and activate it."
        case .restartRequired:
            "The system connection ended. Quit and reopen Blenny before resuming management."
        case .staleLifecycleGeneration:
            "The system context changed. Choose Resume after checking the managed apps."
        }
    }
}

public actor ManagementLoopController {
    public typealias WriterProvider = @Sendable () async throws -> any PolicyAssertionWriting

    private struct PendingWriterCreation: Sendable {
        let id: UUID
        let generation: UInt64
        let task: Task<any PolicyAssertionWriting, Error>
    }

    private let writerProvider: WriterProvider
    private var writer: (any PolicyAssertionWriting)?
    private var writerCreation: PendingWriterCreation?
    private var lifecycleGeneration: UInt64 = 0
    private var restartRequired = false
    private var terminationCleanupAttempted = false
    private var passThroughUpdateInProgress = false
    public private(set) var state: ManagementLoopState = .unknown

    public init(writerProvider: @escaping WriterProvider) {
        self.writerProvider = writerProvider
    }

    public func recover(
        acceptedPolicy: PersistentBundlePolicyDocument,
        baseline: RevealAllowlistPlan?
    ) async -> ManagementLoopState {
        guard !restartRequired else { return state }
        guard acceptedPolicy.managementEnabled else {
            if await restoreAndStop(detail: "persisted management is stopped") { state = .stopped }
            return state
        }
        guard let baseline else {
            await restoreAndStop(detail: "accepted policy has no valid baseline")
            return state
        }

        state = .acceptedPolicyLoadedInactive
        let generation = lifecycleGeneration
        do {
            let writer = try await writerForTransaction()
            guard generation == lifecycleGeneration else { return state }
            state = .writerActivating
            try await writer.applyBaselineReplacement(with: baseline)
            guard generation == lifecycleGeneration else { return state }
            guard try await writer.verifyActivePlan(baseline) else {
                throw ManagementLoopError.activationCouldNotBeVerified
            }
            guard generation == lifecycleGeneration else { return state }
            state = .baselineVerified(baseline.fingerprint)
            state = .active(baseline.fingerprint)
        } catch {
            guard generation == lifecycleGeneration else { return state }
            await restoreAndStop(detail: "startup recovery failed: \(error)")
        }
        return state
    }

    public func writerForTransaction() async throws -> any PolicyAssertionWriting {
        if case .restorationFailed = state { throw ManagementLoopError.restartRequired }
        if let writer { return writer }
        switch state {
        case .failClosedUnrestricted, .unsupportedRuntimeContract, .connectionInvalidated:
            return UnrestrictedPolicyAssertionWriter()
        default:
            break
        }
        do {
            let creation: PendingWriterCreation
            if let pending = writerCreation { creation = pending }
            else {
                let provider = writerProvider
                creation = PendingWriterCreation(
                    id: UUID(), generation: lifecycleGeneration,
                    task: Task { try await provider() }
                )
                writerCreation = creation
            }
            let created: any PolicyAssertionWriting
            do { created = try await creation.task.value }
            catch {
                if writerCreation?.id == creation.id { writerCreation = nil }
                guard creation.generation == lifecycleGeneration else {
                    throw ManagementLoopError.staleLifecycleGeneration
                }
                throw error
            }
            if let writer { return writer }
            guard writerCreation?.id == creation.id else {
                throw ManagementLoopError.staleLifecycleGeneration
            }
            writerCreation = nil
            guard creation.generation == lifecycleGeneration else {
                await created.restoreAndStop()
                throw ManagementLoopError.staleLifecycleGeneration
            }
            writer = created
            return created
        } catch {
            if let loopError = error as? ManagementLoopError,
               loopError == .staleLifecycleGeneration { throw error }
            state = .unsupportedRuntimeContract(String(describing: error))
            throw error
        }
    }

    /// Call only after an explicit action has passed fresh policy/runtime checks.
    /// A failed startup may retry; connection loss and termination need a restart.
    public func writerForReviewedActivation(
        expectedGeneration: UInt64? = nil
    ) async throws -> any PolicyAssertionWriting {
        if let expectedGeneration, expectedGeneration != lifecycleGeneration {
            throw ManagementLoopError.staleLifecycleGeneration
        }
        guard !restartRequired else { throw ManagementLoopError.restartRequired }
        if state.canResume { state = .acceptedPolicyLoadedInactive }
        return try await writerForTransaction()
    }

    public func generationSnapshot() -> UInt64 { lifecycleGeneration }

    /// Recovery may reuse the one retained coordinator after management has
    /// stopped. This accessor never creates, resumes or changes loop state.
    public func existingWriterForRecovery() -> (any PolicyAssertionWriting)? { writer }

    public func synchronizeCommittedPolicy(
        _ policy: PersistentBundlePolicyDocument,
        baseline: RevealAllowlistPlan?
    ) async throws {
        guard policy.managementEnabled else {
            guard await restoreAndStop(detail: "management stopped by committed policy") else {
                throw ManagementLoopError.restartRequired
            }
            state = .stopped
            return
        }
        guard let baseline, let writer else {
            await restoreAndStop(detail: "committed policy has no active baseline")
            throw ManagementLoopError.acceptedPolicyRequiresBaseline
        }
        let generation = lifecycleGeneration
        guard try await writer.verifyActivePlan(baseline) else {
            await restoreAndStop(detail: "committed baseline verification failed")
            throw ManagementLoopError.activationCouldNotBeVerified
        }
        guard generation == lifecycleGeneration else {
            throw ManagementLoopError.managementIsNotActive
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

    /// Owner-authorized lifecycle maintenance: only widen the current allowance.
    /// Reuse the existing writer; never acquire one, resume stopped management,
    /// change presentation, or retry. On failure remove restrictions instead of
    /// retaining a plan that could conceal the newly launched application.
    public func expandPassThrough(
        from expected: RevealAllowlistPlan,
        to replacement: RevealAllowlistPlan,
        addedBundleIdentifiers: Set<String>
    ) async throws {
        guard !restartRequired, !passThroughUpdateInProgress, let writer else {
            throw ManagementLoopError.managementIsNotActive
        }
        let currentFingerprint: String
        switch state {
        case let .active(fingerprint), let .ordinaryRevealSession(fingerprint):
            currentFingerprint = fingerprint
        default:
            throw ManagementLoopError.managementIsNotActive
        }
        guard currentFingerprint == expected.fingerprint else {
            throw ManagementLoopError.staleLifecycleGeneration
        }
        try PassThroughExpansion.validateReplacement(
            from: expected, to: replacement,
            addedBundleIdentifiers: addedBundleIdentifiers
        )
        passThroughUpdateInProgress = true
        defer { passThroughUpdateInProgress = false }
        let generation = lifecycleGeneration
        do {
            let snapshot = await writer.activePlanSnapshot()
            guard generation == lifecycleGeneration, snapshot == expected else {
                throw ManagementLoopError.staleLifecycleGeneration
            }
            try await writer.applySessionTransition(with: replacement)
            guard generation == lifecycleGeneration else {
                throw ManagementLoopError.staleLifecycleGeneration
            }
            guard try await writer.verifyActivePlan(replacement) else {
                throw ManagementLoopError.activationCouldNotBeVerified
            }
            guard generation == lifecycleGeneration else {
                throw ManagementLoopError.staleLifecycleGeneration
            }
            state = replacement.presentation == .baseline
                ? .active(replacement.fingerprint)
                : .ordinaryRevealSession(replacement.fingerprint)
        } catch {
            // Preserve a concurrent Stop/termination/connection-loss result.
            if generation == lifecycleGeneration {
                await restoreAndStop(detail: "A new application's visibility could not be verified. Choose Resume to recheck.")
            }
            throw error
        }
    }

    public func beginOrdinaryReveal(_ plan: RevealAllowlistPlan) async throws {
        guard !passThroughUpdateInProgress, case .active = state, let writer else {
            throw ManagementLoopError.managementIsNotActive
        }
        let generation = lifecycleGeneration
        let baseline = await writer.activePlanSnapshot()
        guard generation == lifecycleGeneration else { throw ManagementLoopError.managementIsNotActive }
        do {
            try await writer.applySessionTransition(with: plan)
        } catch {
            // One bounded verification distinguishes a retained baseline from
            // a stopped/disconnected writer. Never publish stale active state.
            if generation == lifecycleGeneration,
               let baseline, (try? await writer.verifyActivePlan(baseline)) == true {
                throw error
            }
            await restoreAndStop(detail: "ordinary reveal activation lost its safe baseline")
            throw error
        }
        do {
            guard try await writer.verifyActivePlan(plan), generation == lifecycleGeneration else {
                throw ManagementLoopError.activationCouldNotBeVerified
            }
        } catch {
            await restoreAndStop(detail: "ordinary reveal verification failed")
            throw error
        }
        state = .ordinaryRevealSession(plan.fingerprint)
    }

    public func endOrdinaryReveal(_ baseline: RevealAllowlistPlan) async throws {
        guard !passThroughUpdateInProgress, case .ordinaryRevealSession = state, let writer else {
            throw ManagementLoopError.managementIsNotActive
        }
        let generation = lifecycleGeneration
        do {
            try await writer.applySessionTransition(with: baseline)
            guard try await writer.verifyActivePlan(baseline), generation == lifecycleGeneration else {
                throw ManagementLoopError.activationCouldNotBeVerified
            }
            state = .active(baseline.fingerprint)
        } catch {
            await restoreAndStop(detail: "ordinary reveal could not restore baseline")
            throw error
        }
    }

    public func stop() async {
        if case .restorationFailed = state { return }
        state = .stopping
        if await restoreAndStop(detail: "management stopped") { state = .stopped }
    }

    public func failClosed(_ detail: String) async {
        await restoreAndStop(detail: detail)
    }

    public func connectionInvalidated() async {
        if case .restorationFailed = state { return }
        restartRequired = true
        lifecycleGeneration &+= 1
        state = .connectionInvalidated
        if let writer {
            await writer.connectionInvalidated()
        }
        _ = await confirmCleanup(detail: "writer connection invalidated")
    }

    public func terminate() async {
        guard !terminationCleanupAttempted else { return }
        terminationCleanupAttempted = true
        restartRequired = true
        lifecycleGeneration &+= 1
        state = .terminating
        if let writer {
            await writer.restoreAndStop()
        }
        _ = await confirmCleanup(detail: "application termination restored assertions")
    }

    public func activePlanSnapshot() async -> RevealAllowlistPlan? {
        await writer?.activePlanSnapshot()
    }

    @discardableResult
    private func restoreAndStop(detail: String) async -> Bool {
        if case .restorationFailed = state { return false }
        lifecycleGeneration &+= 1
        if let writer {
            await writer.restoreAndStop()
        }
        return await confirmCleanup(detail: detail)
    }

    private func confirmCleanup(detail: String) async -> Bool {
        guard await writer?.hasPendingRestoration() != true else {
            restartRequired = true
            state = .restorationFailed(detail)
            return false
        }
        writer = nil
        state = .failClosedUnrestricted(detail)
        return true
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
