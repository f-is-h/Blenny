import Foundation

public protocol PersistentBundlePolicyStoring: Sendable {
    func load() async throws -> PersistentBundlePolicyDocument?
    func loadBackup() async throws -> PersistentBundlePolicyBackup?
    func save(_ document: PersistentBundlePolicyDocument) async throws
    func restoreBackup() async throws -> PersistentBundlePolicyDocument?
}

extension PersistentBundlePolicyStore: PersistentBundlePolicyStoring {}

public protocol PolicyAssertionWriting: Sendable {
    func applySessionTransition(with plan: RevealAllowlistPlan) async throws
    func restoreAndStop() async
    func connectionInvalidated() async
    func activePlanSnapshot() async -> RevealAllowlistPlan?
}

extension RevealAssertionWriter: PolicyAssertionWriting {}

public enum PolicyEditingTransactionStage: String, Equatable, Sendable {
    case staleAcceptedPolicy
    case writerCreation
    case activation
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

        do {
            try await writer.applySessionTransition(with: newBaseline)
            guard await writer.activePlanSnapshot() == newBaseline else {
                await writer.restoreAndStop()
                throw PolicyEditingTransactionFailure(
                    stage: .activation,
                    systemState: .unrestricted,
                    detail: "writer disconnected before the accepted policy could be persisted"
                )
            }
        } catch {
            await writer.restoreAndStop()
            if let failure = error as? PolicyEditingTransactionFailure {
                throw failure
            }
            throw PolicyEditingTransactionFailure(
                stage: .activation,
                systemState: .unrestricted,
                detail: "new baseline activation failed and all owned assertions were restored: \(error)"
            )
        }

        do {
            try await persist(prepared)
            return .committed(prepared.newPolicy)
        } catch {
            if prepared.oldPolicy.managementEnabled {
                do {
                    try await writer.applySessionTransition(with: oldBaseline)
                    guard await writer.activePlanSnapshot() == oldBaseline else {
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

    private func persist(_ prepared: PreparedPolicyEdit) async throws {
        switch prepared.persistenceMode {
        case .saveAcceptedPolicy:
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
        observedRunningBundleIdentifiers: Set<String>
    ) async throws -> (PolicyDryRunImpactReport, PreparedPolicyEdit?) {
        guard let accepted = try await store.load() else { return try missingPolicy() }
        return try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: draft,
            managementEnabled: accepted.managementEnabled,
            candidates: candidates,
            observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
            scope: scope,
            blennyBundleIdentifier: blennyBundleIdentifier
        )
    }

    public func previewResumeManaging(
        candidates: PolicyCandidateInventory,
        observedRunningBundleIdentifiers: Set<String>
    ) async throws -> (PolicyDryRunImpactReport, PreparedPolicyEdit?) {
        guard let accepted = try await store.load() else { return try missingPolicy() }
        return try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: BundlePolicyDraft(acceptedPolicy: accepted),
            managementEnabled: true,
            candidates: candidates,
            observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
            scope: scope,
            blennyBundleIdentifier: blennyBundleIdentifier
        )
    }

    public func previewRestorePreviousPolicy(
        candidates: PolicyCandidateInventory,
        observedRunningBundleIdentifiers: Set<String>
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
            scope: scope,
            blennyBundleIdentifier: blennyBundleIdentifier,
            persistenceMode: .restorePreviousPolicy
        )
    }

    public func commit(
        _ prepared: PreparedPolicyEdit
    ) async throws -> PolicyEditingTransactionResult {
        try await transaction.commit(prepared)
    }

    private func missingPolicy<T>() throws -> T {
        throw PolicyEditingCoreError.acceptedPolicyMissing
    }
}

public enum PolicyEditingCoreError: Error, Equatable, Sendable {
    case acceptedPolicyMissing
    case previousPolicyBackupMissing
}
