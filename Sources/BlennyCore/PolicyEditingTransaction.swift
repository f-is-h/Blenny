import Foundation

public protocol PersistentBundlePolicyStoring: Sendable {
    func load() async throws -> PersistentBundlePolicyDocument?
    func loadBackup() async throws -> PersistentBundlePolicyBackup?
    func save(_ document: PersistentBundlePolicyDocument) async throws
    func restoreBackup() async throws -> PersistentBundlePolicyDocument?
    func restoreSnapshot(
        document: PersistentBundlePolicyDocument,
        backup: PersistentBundlePolicyBackup?,
        expecting: PersistentBundlePolicyDocument
    ) async throws
}

public extension PersistentBundlePolicyStoring {
    func restoreSnapshot(
        document: PersistentBundlePolicyDocument,
        backup: PersistentBundlePolicyBackup?,
        expecting: PersistentBundlePolicyDocument
    ) async throws {
        // A store without exact snapshot restoration must not rotate away the
        // user's earlier backup while compensating for a combined operation.
        throw PersistentBundlePolicyStoreError.interruptedTransactionStateMismatch
    }
}

extension PersistentBundlePolicyStore: PersistentBundlePolicyStoring {}

public protocol PolicyAssertionWriting: Sendable {
    func applyBaselineReplacement(with plan: RevealAllowlistPlan) async throws
    func applySessionTransition(with plan: RevealAllowlistPlan) async throws
    func verifyActivePlan(_ expected: RevealAllowlistPlan) async throws -> Bool
    func restoreAndStop() async
    func connectionInvalidated() async
    func activePlanSnapshot() async -> RevealAllowlistPlan?
    func hasPendingRestoration() async -> Bool
    func finalizeCommittedPlan(_ plan: RevealAllowlistPlan) async
}

public extension PolicyAssertionWriting {
    func applyBaselineReplacement(with plan: RevealAllowlistPlan) async throws {
        try await applySessionTransition(with: plan)
    }

    func verifyActivePlan(_ expected: RevealAllowlistPlan) async throws -> Bool {
        await activePlanSnapshot() == expected
    }

    func hasPendingRestoration() async -> Bool { await activePlanSnapshot() != nil }

    func finalizeCommittedPlan(_ plan: RevealAllowlistPlan) async {}
}

extension RevealAssertionWriter: PolicyAssertionWriting {}

public enum PolicyEditingTransactionStage: String, Equatable, Sendable {
    case staleAcceptedPolicy
    case writerCreation
    case activation
    case verification
    case persistence
    case rollback
}

public enum PolicyEditingSystemState: String, Equatable, Sendable {
    case previousPolicyActive
    case acceptedPolicyActive
    case unrestricted
}

public struct PolicyEditingTransactionFailure: Error, Equatable, Sendable {
    public let stage: PolicyEditingTransactionStage
    public let systemState: PolicyEditingSystemState
    public let detail: String

    public init(
        stage: PolicyEditingTransactionStage,
        systemState: PolicyEditingSystemState,
        detail: String
    ) {
        self.stage = stage
        self.systemState = systemState
        self.detail = detail
    }
}

public enum PolicyEditingTransactionResult: Equatable, Sendable {
    case noChange
    case committed(PersistentBundlePolicyDocument)
    case reactivated(PersistentBundlePolicyDocument)
}

public struct PolicyEditingCommitOutcome: Equatable, Sendable {
    public let result: PolicyEditingTransactionResult
    public let effectivePrepared: PreparedPolicyEdit

    public init(
        result: PolicyEditingTransactionResult,
        effectivePrepared: PreparedPolicyEdit
    ) {
        self.result = result
        self.effectivePrepared = effectivePrepared
    }
}

public actor PolicyEditingTransactionCoordinator {
    public typealias WriterProvider = @Sendable () async throws -> any PolicyAssertionWriting

    private let store: any PersistentBundlePolicyStoring
    private let writerProvider: WriterProvider

    public init(
        store: any PersistentBundlePolicyStoring,
        writerProvider: @escaping WriterProvider
    ) {
        self.store = store
        self.writerProvider = writerProvider
    }

    public func commit(
        _ prepared: PreparedPolicyEdit
    ) async throws -> PolicyEditingTransactionResult {
        let current: PersistentBundlePolicyDocument?
        do {
            current = try await store.load()
        } catch {
            throw PolicyEditingTransactionFailure(
                stage: .staleAcceptedPolicy,
                systemState: prepared.oldPolicy.managementEnabled
                    ? .previousPolicyActive : .unrestricted,
                detail: "accepted policy could not be reloaded: \(error)"
            )
        }
        guard current == prepared.oldPolicy else {
            throw PolicyEditingTransactionFailure(
                stage: .staleAcceptedPolicy,
                systemState: prepared.oldPolicy.managementEnabled
                    ? .previousPolicyActive : .unrestricted,
                detail: "accepted policy changed after dry-run"
            )
        }
        guard prepared.newPolicy != prepared.oldPolicy else {
            if prepared.persistenceMode == .resumeManagement && prepared.newPolicy.managementEnabled {
                return try await resumeUnchangedPolicy(prepared)
            }
            return .noChange
        }
        guard let newBaseline = prepared.report.newBaselinePlan,
              let oldBaseline = prepared.report.oldBaselinePlan else {
            throw PolicyEditingTransactionFailure(
                stage: .activation,
                systemState: prepared.oldPolicy.managementEnabled
                    ? .previousPolicyActive : .unrestricted,
                detail: "prepared edit has no deterministic baseline plan"
            )
        }

        if !prepared.newPolicy.managementEnabled {
            let writer: (any PolicyAssertionWriting)?
            if prepared.oldPolicy.managementEnabled {
                do {
                    writer = try await writerProvider()
                } catch {
                    throw PolicyEditingTransactionFailure(
                        stage: .writerCreation,
                        systemState: .previousPolicyActive,
                        detail: "writer acquisition failed before disabling management: \(error)"
                    )
                }
            } else {
                writer = nil
            }
            do {
                try await persist(prepared)
            } catch {
                throw PolicyEditingTransactionFailure(
                    stage: .persistence,
                    systemState: prepared.oldPolicy.managementEnabled
                        ? .previousPolicyActive : .unrestricted,
                    detail: "disabled policy persistence failed: \(error)"
                )
            }
            if let writer {
                await writer.restoreAndStop()
                guard await writer.activePlanSnapshot() == nil else {
                    throw PolicyEditingTransactionFailure(
                        stage: .rollback,
                        systemState: .unrestricted,
                        detail: "disabled policy persisted but writer did not confirm restoration"
                    )
                }
            }
            return .committed(prepared.newPolicy)
        }

        let writer: any PolicyAssertionWriting
        do {
            writer = try await writerProvider()
        } catch {
            throw PolicyEditingTransactionFailure(
                stage: .writerCreation,
                systemState: prepared.oldPolicy.managementEnabled
                    ? .previousPolicyActive : .unrestricted,
                detail: "writer creation failed: \(error)"
            )
        }

        try await activateAndVerify(
            writer: writer,
            newBaseline: newBaseline,
            oldBaseline: oldBaseline,
            oldManagementEnabled: prepared.oldPolicy.managementEnabled
        )

        do {
            try await persist(prepared)
            await writer.finalizeCommittedPlan(newBaseline)
            return .committed(prepared.newPolicy)
        } catch {
            if prepared.oldPolicy.managementEnabled {
                do {
                    try await writer.applyBaselineReplacement(with: oldBaseline)
                    guard try await writer.verifyActivePlan(oldBaseline) else {
                        await writer.restoreAndStop()
                        throw PolicyEditingTransactionFailure(
                            stage: .rollback,
                            systemState: .unrestricted,
                            detail: "persistence failed and the previous baseline was not retained"
                        )
                    }
                    throw PolicyEditingTransactionFailure(
                        stage: .persistence,
                        systemState: .previousPolicyActive,
                        detail: "persistence failed; previous baseline reactivated: \(error)"
                    )
                } catch let failure as PolicyEditingTransactionFailure {
                    throw failure
                } catch {
                    await writer.restoreAndStop()
                    throw PolicyEditingTransactionFailure(
                        stage: .rollback,
                        systemState: .unrestricted,
                        detail: "persistence and previous-baseline rollback failed; all assertions restored: \(error)"
                    )
                }
            }
            await writer.restoreAndStop()
            throw PolicyEditingTransactionFailure(
                stage: .persistence,
                systemState: .unrestricted,
                detail: "persistence failed; newly activated assertion was restored: \(error)"
            )
        }
    }

    private func resumeUnchangedPolicy(
        _ prepared: PreparedPolicyEdit
    ) async throws -> PolicyEditingTransactionResult {
        guard let backupFingerprint = prepared.reviewBinding.recoveryBackupFingerprint,
              try await store.loadBackup()?.backupFingerprint == backupFingerprint else {
            throw PolicyEditingTransactionFailure(
                stage: .staleAcceptedPolicy, systemState: .unrestricted,
                detail: "resume recovery backup is missing or changed after preparation"
            )
        }
        guard let baseline = prepared.report.newBaselinePlan else {
            throw PolicyEditingTransactionFailure(
                stage: .activation, systemState: .unrestricted,
                detail: "resume has no validated baseline"
            )
        }
        let writer: any PolicyAssertionWriting
        do {
            writer = try await writerProvider()
        } catch {
            throw PolicyEditingTransactionFailure(
                stage: .writerCreation, systemState: .unrestricted,
                detail: "resume writer unavailable: \(error)"
            )
        }
        if let existing = await writer.activePlanSnapshot() {
            // A repeated Resume never replaces an already verified exact plan.
            if existing == baseline, (try? await writer.verifyActivePlan(existing)) == true {
                return .noChange
            }
            await writer.restoreAndStop()
            throw PolicyEditingTransactionFailure(
                stage: .verification, systemState: .unrestricted,
                detail: "resume found an unexpected or unverifiable active assertion"
            )
        }
        // Persisted enabled intent is not evidence of a previous active writer.
        // This is first activation from unrestricted, including its rollback rule.
        try await activateAndVerify(
            writer: writer, newBaseline: baseline, oldBaseline: baseline,
            oldManagementEnabled: false
        )
        return .reactivated(prepared.newPolicy)
    }

    private func activateAndVerify(
        writer: any PolicyAssertionWriting,
        newBaseline: RevealAllowlistPlan,
        oldBaseline: RevealAllowlistPlan,
        oldManagementEnabled: Bool
    ) async throws {
        let expectedPrevious: RevealAllowlistPlan? = oldManagementEnabled ? oldBaseline : nil
        var attempt = 0
        while attempt < 2 {
            attempt += 1
            do {
                try await writer.applyBaselineReplacement(with: newBaseline)
            } catch {
                let observed = await writer.activePlanSnapshot()
                let previousStateProven = observed == expectedPrevious
                if attempt == 1, previousStateProven {
                    continue
                }
                if previousStateProven {
                    if !oldManagementEnabled {
                        await writer.restoreAndStop()
                    }
                    throw PolicyEditingTransactionFailure(
                        stage: .activation,
                        systemState: oldManagementEnabled
                            ? .previousPolicyActive : .unrestricted,
                        detail: "new baseline activation failed after \(attempt) attempt(s): \(error)"
                    )
                }
                try await restorePreviousBaselineAfterFailure(
                    writer: writer,
                    oldBaseline: oldBaseline,
                    oldManagementEnabled: oldManagementEnabled,
                    originalStage: .activation,
                    detail: "new baseline activation failed after \(attempt) attempt(s): \(error)"
                )
            }

            do {
                guard try await writer.verifyActivePlan(newBaseline) else {
                    try await restorePreviousBaselineAfterFailure(
                        writer: writer,
                        oldBaseline: oldBaseline,
                        oldManagementEnabled: oldManagementEnabled,
                        originalStage: .verification,
                        detail: "new baseline activation could not be verified"
                    )
                }
                return
            } catch let failure as PolicyEditingTransactionFailure {
                throw failure
            } catch {
                try await restorePreviousBaselineAfterFailure(
                    writer: writer,
                    oldBaseline: oldBaseline,
                    oldManagementEnabled: oldManagementEnabled,
                    originalStage: .verification,
                    detail: "new baseline verification failed: \(error)"
                )
            }
        }
    }

    private func restorePreviousBaselineAfterFailure(
        writer: any PolicyAssertionWriting,
        oldBaseline: RevealAllowlistPlan,
        oldManagementEnabled: Bool,
        originalStage: PolicyEditingTransactionStage,
        detail: String
    ) async throws -> Never {
        guard oldManagementEnabled else {
            await writer.restoreAndStop()
            throw PolicyEditingTransactionFailure(
                stage: originalStage,
                systemState: .unrestricted,
                detail: "\(detail); all owned assertions were restored"
            )
        }
        do {
            try await writer.applyBaselineReplacement(with: oldBaseline)
            guard try await writer.verifyActivePlan(oldBaseline) else {
                throw PolicyEditingTransactionFailure(
                    stage: .rollback,
                    systemState: .unrestricted,
                    detail: "\(detail); the previous baseline could not be verified"
                )
            }
            throw PolicyEditingTransactionFailure(
                stage: originalStage,
                systemState: .previousPolicyActive,
                detail: "\(detail); the previous baseline was restored"
            )
        } catch let failure as PolicyEditingTransactionFailure {
            if failure.systemState == .previousPolicyActive {
                throw failure
            }
            await writer.restoreAndStop()
            throw failure
        } catch {
            await writer.restoreAndStop()
            throw PolicyEditingTransactionFailure(
                stage: .rollback,
                systemState: .unrestricted,
                detail: "\(detail); previous-baseline rollback failed: \(error)"
            )
        }
    }

    private func persist(_ prepared: PreparedPolicyEdit) async throws {
        switch prepared.persistenceMode {
        case .saveAcceptedPolicy, .resumeManagement:
            try await store.save(prepared.newPolicy)
        case .restorePreviousPolicy:
            let restored = try await store.restoreBackup()
            guard restored == prepared.newPolicy else {
                throw PolicyEditingTransactionFailure(
                    stage: .persistence,
                    systemState: .acceptedPolicyActive,
                    detail: "previous-policy backup changed after dry-run"
                )
            }
        }
    }
}

public actor PolicyEditingCore {
    private let store: any PersistentBundlePolicyStoring
    private let transaction: PolicyEditingTransactionCoordinator
    private let blennyBundleIdentifier: String
    private let scope: PolicyValidationScope
    private var consumedReviewIdentifiers = Set<UUID>()

    public init(
        store: any PersistentBundlePolicyStoring,
        blennyBundleIdentifier: String,
        scope: PolicyValidationScope,
        writerProvider: @escaping PolicyEditingTransactionCoordinator.WriterProvider
    ) {
        self.store = store
        self.blennyBundleIdentifier = blennyBundleIdentifier
        self.scope = scope
        self.transaction = PolicyEditingTransactionCoordinator(
            store: store,
            writerProvider: writerProvider
        )
    }

    public func makeDraft() async throws -> BundlePolicyDraft? {
        try await store.load().map(BundlePolicyDraft.init)
    }

    public func discardDraft() async throws -> BundlePolicyDraft? {
        try await makeDraft()
    }

    public func preview(
        draft: BundlePolicyDraft,
        candidates: PolicyCandidateInventory,
        observedRunningBundleIdentifiers: Set<String>,
        candidateGeneration: UUID = PolicyReviewBinding.unversionedCandidateGeneration,
        runtimeContractFingerprint: String = "deterministic-core"
    ) async throws -> (PolicyDryRunImpactReport, PreparedPolicyEdit?) {
        guard let accepted = try await store.load() else { return try missingPolicy() }
        return try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: draft,
            managementEnabled: true,
            candidates: candidates,
            observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
            scope: scope,
            blennyBundleIdentifier: blennyBundleIdentifier,
            candidateGeneration: candidateGeneration,
            runtimeContractFingerprint: runtimeContractFingerprint,
            recoveryBackupFingerprint: try await backupFingerprint()
        )
    }

    /// Prepares the policy half of unified Undo without changing whether
    /// management is currently running. Stop and Quit deliberately leave an
    /// accepted order in place, so a later Undo must restore the prior policy
    /// assignments while preserving the stopped state.
    public func previewUndoKeepingManagementState(
        targetPolicy: PersistentBundlePolicyDocument,
        candidates: PolicyCandidateInventory,
        observedRunningBundleIdentifiers: Set<String>,
        candidateGeneration: UUID = PolicyReviewBinding.unversionedCandidateGeneration,
        runtimeContractFingerprint: String = "deterministic-core"
    ) async throws -> (PolicyDryRunImpactReport, PreparedPolicyEdit?) {
        guard let accepted = try await store.load() else { return try missingPolicy() }
        return try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: BundlePolicyDraft(acceptedPolicy: targetPolicy),
            managementEnabled: accepted.managementEnabled,
            candidates: candidates,
            observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
            scope: restorationScope(for: targetPolicy),
            blennyBundleIdentifier: blennyBundleIdentifier,
            candidateGeneration: candidateGeneration,
            runtimeContractFingerprint: runtimeContractFingerprint,
            recoveryBackupFingerprint: try await backupFingerprint()
        )
    }

    public func previewResumeManaging(
        candidates: PolicyCandidateInventory,
        observedRunningBundleIdentifiers: Set<String>,
        candidateGeneration: UUID = PolicyReviewBinding.unversionedCandidateGeneration,
        runtimeContractFingerprint: String = "deterministic-core"
    ) async throws -> (PolicyDryRunImpactReport, PreparedPolicyEdit?) {
        guard let accepted = try await store.load() else { return try missingPolicy() }
        return try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: BundlePolicyDraft(acceptedPolicy: accepted),
            managementEnabled: true,
            candidates: candidates,
            observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
            scope: scope,
            blennyBundleIdentifier: blennyBundleIdentifier,
            persistenceMode: .resumeManagement,
            candidateGeneration: candidateGeneration,
            runtimeContractFingerprint: runtimeContractFingerprint,
            recoveryBackupFingerprint: try await resumeBackupFingerprint(accepted: accepted)
        )
    }

    public func previewStopManaging(
        candidates: PolicyCandidateInventory,
        observedRunningBundleIdentifiers: Set<String>,
        candidateGeneration: UUID = PolicyReviewBinding.unversionedCandidateGeneration,
        runtimeContractFingerprint: String = "deterministic-core"
    ) async throws -> (PolicyDryRunImpactReport, PreparedPolicyEdit?) {
        guard let accepted = try await store.load() else { return try missingPolicy() }
        return try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: BundlePolicyDraft(acceptedPolicy: accepted),
            managementEnabled: false,
            candidates: candidates,
            observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
            scope: scope,
            blennyBundleIdentifier: blennyBundleIdentifier,
            candidateGeneration: candidateGeneration,
            runtimeContractFingerprint: runtimeContractFingerprint,
            recoveryBackupFingerprint: try await backupFingerprint()
        )
    }

    public func previewRestorePreviousPolicy(
        candidates: PolicyCandidateInventory,
        observedRunningBundleIdentifiers: Set<String>,
        candidateGeneration: UUID = PolicyReviewBinding.unversionedCandidateGeneration,
        runtimeContractFingerprint: String = "deterministic-core"
    ) async throws -> (PolicyDryRunImpactReport, PreparedPolicyEdit?) {
        guard let accepted = try await store.load() else { return try missingPolicy() }
        guard let backup = try await store.loadBackup() else {
            throw PolicyEditingCoreError.previousPolicyBackupMissing
        }
        return try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: BundlePolicyDraft(acceptedPolicy: backup.previousPolicy),
            managementEnabled: backup.previousPolicy.managementEnabled,
            candidates: candidates,
            observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
            scope: restorationScope(for: backup.previousPolicy),
            blennyBundleIdentifier: blennyBundleIdentifier,
            persistenceMode: .restorePreviousPolicy,
            candidateGeneration: candidateGeneration,
            runtimeContractFingerprint: runtimeContractFingerprint,
            recoveryBackupFingerprint: backup.backupFingerprint
        )
    }

    public func commit(
        _ prepared: PreparedPolicyEdit,
        currentDraft: BundlePolicyDraft,
        candidates: PolicyCandidateInventory,
        observedRunningBundleIdentifiers: Set<String>,
        candidateGeneration: UUID,
        runtimeContractFingerprint: String
    ) async throws -> PolicyEditingCommitOutcome {
        guard !consumedReviewIdentifiers.contains(prepared.reviewIdentifier) else {
            throw PolicyEditingCoreError.reviewAlreadyConsumed
        }
        guard let accepted = try await store.load() else { return try missingPolicy() }
        let currentBackupFingerprint = prepared.persistenceMode == .resumeManagement
            ? try await resumeBackupFingerprint(accepted: accepted)
            : try await backupFingerprint()
        let refreshed = try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: currentDraft,
            managementEnabled: prepared.newPolicy.managementEnabled,
            candidates: candidates,
            observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
            scope: prepared.persistenceMode == .restorePreviousPolicy
                ? restorationScope(for: prepared.newPolicy) : scope,
            blennyBundleIdentifier: blennyBundleIdentifier,
            persistenceMode: prepared.persistenceMode,
            candidateGeneration: candidateGeneration,
            runtimeContractFingerprint: runtimeContractFingerprint,
            recoveryBackupFingerprint: currentBackupFingerprint,
            reviewIdentifier: prepared.reviewIdentifier
        )
        guard let effectivePrepared = refreshed.prepared,
              effectivePrepared.newPolicy == prepared.newPolicy,
              effectivePrepared.reviewBinding == prepared.reviewBinding else {
            throw PolicyEditingCoreError.staleReviewedPlan
        }
        consumedReviewIdentifiers.insert(prepared.reviewIdentifier)
        return PolicyEditingCommitOutcome(
            result: try await transaction.commit(effectivePrepared),
            effectivePrepared: effectivePrepared
        )
    }

    public func commit(
        _ prepared: PreparedPolicyEdit
    ) async throws -> PolicyEditingTransactionResult {
        guard prepared.reviewBinding.candidateGeneration
            == PolicyReviewBinding.unversionedCandidateGeneration else {
            throw PolicyEditingCoreError.currentReviewBindingRequired
        }
        guard !consumedReviewIdentifiers.contains(prepared.reviewIdentifier) else {
            throw PolicyEditingCoreError.reviewAlreadyConsumed
        }
        consumedReviewIdentifiers.insert(prepared.reviewIdentifier)
        return try await transaction.commit(prepared)
    }

    private func backupFingerprint() async throws -> String? {
        try await store.loadBackup()?.backupFingerprint
    }

    private func restorationScope(for target: PersistentBundlePolicyDocument) -> PolicyValidationScope {
        // A prior sparse policy can omit owners first assigned by this Apply.
        // Restoring that exact document returns omitted owners to implicit
        // Visible intent. Keep only its already-approved entries; this never
        // grants an owner outside the current validation scope.
        let targetOwners = Set(target.policies.compactMap {
            BundlePolicyIdentity.canonicalKey(for: $0.bundleIdentifier)
        })
        return PolicyValidationScope(approvedBundleIdentifiers: scope.approvedBundleIdentifiers.filter {
            BundlePolicyIdentity.canonicalKey(for: $0).map(targetOwners.contains) == true
        })
    }

    private func resumeBackupFingerprint(accepted: PersistentBundlePolicyDocument) async throws -> String? {
        guard accepted.managementEnabled else { return try await backupFingerprint() }
        guard let backup = try await store.loadBackup() else {
            if accepted.isInitialVisiblePolicy(forBlennyBundleIdentifier: blennyBundleIdentifier) {
                return nil
            }
            throw PolicyEditingCoreError.previousPolicyBackupMissing
        }
        guard (try? backup.previousPolicy.validated(forBlennyBundleIdentifier: blennyBundleIdentifier)) != nil,
              !backup.previousPolicy.policies.contains(where: {
                  $0.bundleIdentifier.lowercased().hasPrefix("com.apple.")
                      && !ExperimentalAppleBundlePolicyCatalog.contains(
                          $0.bundleIdentifier
                      )
              }) else {
            throw PolicyEditingCoreError.previousPolicyBackupIncompatible
        }
        return backup.backupFingerprint
    }

    private func missingPolicy<T>() throws -> T {
        throw PolicyEditingCoreError.acceptedPolicyMissing
    }
}

public enum PolicyEditingCoreError: Error, Equatable, Sendable {
    case acceptedPolicyMissing
    case previousPolicyBackupMissing
    case previousPolicyBackupIncompatible
    case currentReviewBindingRequired
    case staleReviewedPlan
    case reviewAlreadyConsumed
}

extension PolicyEditingCoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .acceptedPolicyMissing:
            return "The accepted policy is missing. Refresh and apply again."
        case .previousPolicyBackupMissing:
            return "The previous-policy backup is missing."
        case .previousPolicyBackupIncompatible:
            return "The previous-policy backup is incompatible. Management remains unrestricted."
        case .currentReviewBindingRequired:
            return "The prepared changes are missing a current safety check. Apply again."
        case .staleReviewedPlan:
            return "A managed app, your changes, or the recovery state changed during preparation. Apply again."
        case .reviewAlreadyConsumed:
            return "These changes were already applied."
        }
    }
}

public extension PersistentBundlePolicyBackup {
    var backupFingerprint: String {
        "schema=\(schemaVersion)|policy=\(previousPolicy.policyFingerprint)"
    }
}
