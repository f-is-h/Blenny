import Foundation

#if BLENNY_PRODUCT || DEBUG
extension CoordinatedPolicyWriter {
    /// Follow an explicit successful Apply/Undo only after the owner has enabled
    /// persistent placement. This is not a timer or a reveal reconciliation loop.
    /// The final mutation reacquires the shared gate and repeats fresh preflight.
    public func updateAcceptedControlBoundary(
        policy: PersistentBundlePolicyDocument
    ) async throws -> OrderingSnapshot? {
        guard let recovery = fallbackRecovery, let receipt = try await recovery.load() else { return nil }
        guard !receipt.isPendingRestoration, receipt.phase == .applied,
              receipt.persistsAfterQuit == true,
              let backend = orderingBackend as? any FallbackPositionWriting else {
            throw OrderingTransactionError.recoveryRequired
        }
        let snapshot = try await backend.capture()
        let candidate: FallbackBoundaryCandidate
        do {
            candidate = try FallbackBoundaryCandidate.make(snapshot: snapshot, policy: policy,
                includeFish: receipt.delta.fishOriginal != nil)
        } catch FallbackPositionDelta.Failure.unchangedPosition {
            return nil
        } catch FallbackBoundaryCandidate.Failure.noRevealableItems {
            return nil
        }
        let identity = try await backend.fallbackIdentity()
        return try await applyFallbackPosition(candidate.delta, baseline: snapshot,
            identity: identity, persistsAfterQuit: true)
    }

    private func requireNoFallbackExperiment() async throws {
        if let fallbackRecovery, try await fallbackRecovery.load()?.isPendingRestoration == true {
            throw OrderingTransactionError.recoveryRequired
        }
    }

    /// Explicit placement shares the existing writer and retains an independent
    /// Undo. Legacy temporary experiments still require restoration on cleanup.
    public func applyFallbackPosition(
        _ delta: FallbackPositionDelta, baseline: OrderingSnapshot,
        identity: FallbackNativeIdentity, persistsAfterQuit: Bool = false,
        reviewedPreviousReceipt: FallbackPositionReceipt? = nil
    ) async throws -> OrderingSnapshot {
        await acquireOperation()
        defer { releaseOperation() }
        guard !stopped, let backend = orderingBackend as? any FallbackPositionWriting,
              let recovery = fallbackRecovery, let orderingRecovery else {
            throw OrderingTransactionError.unavailable
        }
        var receipt = try FallbackPositionReceipt(delta: delta, baseline: baseline,
                                                  persistsAfterQuit: persistsAfterQuit)
        try await orderingRecovery.acquireLease()
        do {
            guard try await orderingRecovery.load()?.isPendingRestoration != true else {
                throw OrderingTransactionError.recoveryRequired
            }
            try await recovery.acquireLease()
            let previousReceipt = try await recovery.load()
            if let previousReceipt {
                guard persistsAfterQuit, !previousReceipt.isPendingRestoration,
                      previousReceipt.phase == .applied else {
                    throw OrderingTransactionError.recoveryRequired
                }
                guard previousReceipt.delta.canBeReplaced(by: delta)
                        || reviewedPreviousReceipt == previousReceipt else {
                    throw FallbackPositionDelta.Failure.targetDrift
                }
            }
            let current = try await backend.capture()
            guard !stopped, current.group == baseline.group,
                  current.policyFingerprint == baseline.policyFingerprint,
                  current.lifecycleGeneration == baseline.lifecycleGeneration,
                  current.displaySignature == baseline.displaySignature,
                  current.afterProcesses == baseline.afterProcesses,
                  Date().timeIntervalSince(baseline.capturedAt) >= 0,
                  Date().timeIntervalSince(baseline.capturedAt) <= 60,
                  try await backend.fallbackIdentity() == identity else {
                throw OrderingTransactionError.contextInvalidated
            }
            // Save failure may be ambiguous. Once attempted, keep both leases
            // and let the explicit recovery path inspect the durable record.
            if let previousReceipt {
                try await recovery.supersedeCommitted(previousReceipt, with: receipt,
                    reviewedDrift: reviewedPreviousReceipt == previousReceipt)
            } else {
                try await recovery.save(receipt)
            }
            do {
                guard !stopped else { throw OrderingTransactionError.contextInvalidated }
                let proposed = try delta.applying(to: current.table())
                try await backend.writeFallbackPosition(proposed, expecting: current, identity: identity)
                let observed = try await backend.capture()
                guard try observed.table() == proposed,
                      try await backend.fallbackIdentity() == identity, !stopped else {
                    throw OrderingTransactionError.movementNotVerified
                }
                receipt.phase = .applied
                try await recovery.save(receipt)
                if persistsAfterQuit {
                    await recovery.releaseLease()
                    await orderingRecovery.releaseLease()
                }
                return observed
            } catch {
                let failure = error
                _ = try await restoreFallbackPositionLocked()
                throw failure
            }
        } catch {
            // Do not release an uncertain intent. A failed read also retains it.
            if (try? await recovery.load()?.isPendingRestoration != true) == true {
                await recovery.releaseLease()
                await orderingRecovery.releaseLease()
            }
            throw error
        }
    }

    public func restoreFallbackPosition() async throws -> OrderingSnapshot? {
        await acquireOperation()
        defer { releaseOperation() }
        return try await restoreFallbackPositionLocked()
    }

    private func restoreFallbackPositionLocked() async throws -> OrderingSnapshot? {
        guard let backend = orderingBackend as? any FallbackPositionWriting,
              let recovery = fallbackRecovery, let orderingRecovery else {
            throw OrderingTransactionError.unavailable
        }
        try await orderingRecovery.acquireLease()
        try await recovery.acquireLease()
        guard var receipt = try await recovery.load() else {
            await recovery.releaseLease()
            await orderingRecovery.releaseLease()
            return nil
        }
        try receipt.validate()
        let current = try await backend.capture()
        let identity = try await backend.fallbackIdentity()
        let restored = try receipt.delta.restoring(in: current.table())
        if try current.table() != restored {
            // A crash after restoreIntent must not cause another blind write.
            guard receipt.phase != .restoreIntent && receipt.phase != .restored else {
                throw OrderingTransactionError.restorationAlreadyAttempted
            }
            receipt.phase = .restoreIntent
            try await recovery.save(receipt)
            try await backend.writeFallbackPosition(restored, expecting: current, identity: identity)
        } else if receipt.phase != .restoreIntent && receipt.phase != .restored {
            receipt.phase = .restoreIntent
            try await recovery.save(receipt)
        }
        let verified = try await backend.capture()
        guard try verified.table() == restored else {
            throw OrderingTransactionError.restorationNotVerified
        }
        receipt.phase = .restored
        try await recovery.save(receipt)
        try await recovery.complete(receipt)
        await recovery.releaseLease()
        await orderingRecovery.releaseLease()
        return verified
    }
}
#endif

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
    private var cleanupAttempted = false
    private var restorationPending = false
    private var operationInProgress = false
    private var operationWaiters: [CheckedContinuation<Void, Never>] = []
    #if BLENNY_PRODUCT || DEBUG
    private var orderingBackend: (any MenuBarOrderingBackend)?
    private var orderingRecovery: (any OrderingRecoveryStoring)?
    private var orderingPolicyStore: (any PersistentBundlePolicyStoring)?
    private var consumedOrderingPlans = Set<UUID>()
    private var orderingRecoveryPending = false
    private var fallbackRecovery: (any FallbackPositionRecoveryStoring)?
    #endif

    public init(
        assertionWriter: any PolicyAssertionWriting,
        persistentWriter: any PersistentSystemItemPlanWriting
    ) {
        self.assertionWriter = assertionWriter
        self.persistentWriter = persistentWriter
    }

    #if BLENNY_PRODUCT || DEBUG
    public init(
        assertionWriter: any PolicyAssertionWriting,
        persistentWriter: any PersistentSystemItemPlanWriting,
        orderingBackend: any MenuBarOrderingBackend,
        orderingRecovery: any OrderingRecoveryStoring,
        orderingPolicyStore: (any PersistentBundlePolicyStoring)? = nil,
        fallbackRecovery: (any FallbackPositionRecoveryStoring)? = nil
    ) {
        self.assertionWriter = assertionWriter
        self.persistentWriter = persistentWriter
        self.orderingBackend = orderingBackend
        self.orderingRecovery = orderingRecovery
        self.orderingPolicyStore = orderingPolicyStore
        self.fallbackRecovery = fallbackRecovery
    }
    #endif

    // An actor alone does not serialize work across awaits. Every capability
    // transition, verification and cleanup holds this one FIFO operation gate.
    private func acquireOperation() async {
        if operationInProgress {
            await withCheckedContinuation { operationWaiters.append($0) }
        } else {
            operationInProgress = true
        }
    }

    private func releaseOperation() {
        if operationWaiters.isEmpty { operationInProgress = false }
        else { operationWaiters.removeFirst().resume() }
    }

    public func applyBaselineReplacement(
        with plan: RevealAllowlistPlan
    ) async throws {
        await acquireOperation()
        defer { releaseOperation() }
        guard !stopped, plan.presentation == .baseline else {
            throw RevealAssertionWriterError.invalidBaselineReplacement
        }
        try await transition(to: plan, baselineReplacement: true)
    }

    public func applySessionTransition(
        with plan: RevealAllowlistPlan
    ) async throws {
        await acquireOperation()
        defer { releaseOperation() }
        guard !stopped else { throw RevealAssertionWriterError.writerStopped }
        try await transition(to: plan, baselineReplacement: false)
    }

    public func verifyActivePlan(
        _ expected: RevealAllowlistPlan
    ) async throws -> Bool {
        await acquireOperation()
        defer { releaseOperation() }
        guard !stopped, activePlan == expected,
              try await assertionWriter.verifyActivePlan(expected) else {
            return false
        }
        let verified = try await persistentWriter.verifyManagedPlan(
            expected.persistentSystemItems
        )
        return !stopped && verified
    }

    public func finalizeCommittedPlan(_ plan: RevealAllowlistPlan) async {
        await acquireOperation()
        defer { releaseOperation() }
        guard !stopped, activePlan == plan else { return }
        await persistentWriter.finalizeCommittedPlan(plan.persistentSystemItems)
    }

    public func restoreAndStop() async {
        stopped = true
        await acquireOperation()
        defer { releaseOperation() }
        await cleanupLocked(connectionLost: false)
    }

    public func connectionInvalidated() async {
        stopped = true
        await acquireOperation()
        defer { releaseOperation() }
        await cleanupLocked(connectionLost: true)
    }

    private func cleanupLocked(connectionLost: Bool) async {
        guard !cleanupAttempted else { return }
        cleanupAttempted = true
        #if BLENNY_PRODUCT || DEBUG
        if let fallbackRecovery {
            do {
                if try await fallbackRecovery.load()?.isPendingRestoration == true {
                    _ = try await restoreFallbackPositionLocked()
                }
            } catch {
                // The independent journal remains pending and visible through
                // hasPendingRestoration. Visibility cleanup must still proceed.
            }
        }
        #endif
        if connectionLost { await assertionWriter.connectionInvalidated() }
        else { await assertionWriter.restoreAndStop() }
        let persistentRestored = await persistentWriter.restoreAllManagedItems()
        restorationPending = !persistentRestored
        if persistentRestored { activePlan = nil }
        #if BLENNY_PRODUCT || DEBUG
        if orderingRecovery != nil {
            do {
                if let receipt = try await orderingRecovery?.load(), receipt.isPendingRestoration {
                    _ = try await restoreOrderingLocked()
                } else {
                    orderingRecoveryPending = false
                }
            } catch { orderingRecoveryPending = true }
        }
        #endif
    }

    public func activePlanSnapshot() -> RevealAllowlistPlan? { activePlan }

    public func hasPendingRestoration() async -> Bool {
        #if BLENNY_PRODUCT || DEBUG
        if let fallbackRecovery {
            do { if try await fallbackRecovery.load()?.isPendingRestoration == true { return true } }
            catch { return true }
        }
        if orderingRecoveryPending { return true }
        #endif
        return restorationPending || activePlan != nil
    }

    private func transition(
        to plan: RevealAllowlistPlan,
        baselineReplacement: Bool
    ) async throws {
        if activePlan == plan { return }
        let previous = activePlan
        do {
            try await persistentWriter.applyManagedPlan(plan.persistentSystemItems)
            guard !stopped else { throw RevealAssertionWriterError.writerStopped }
            if baselineReplacement {
                try await assertionWriter.applyBaselineReplacement(with: plan)
            } else {
                try await assertionWriter.applySessionTransition(with: plan)
            }
            guard !stopped else { throw RevealAssertionWriterError.writerStopped }
            activePlan = plan
        } catch {
            if stopped {
                await cleanupLocked(connectionLost: false)
            } else if !baselineReplacement, plan.presentation == .baseline {
                stopped = true
                await cleanupLocked(connectionLost: false)
            } else if let previous {
                do {
                    try await persistentWriter.applyManagedPlan(
                        previous.persistentSystemItems
                    )
                    guard !stopped else { throw RevealAssertionWriterError.writerStopped }
                    await persistentWriter.finalizeCommittedPlan(
                        previous.persistentSystemItems
                    )
                    guard !stopped else { throw RevealAssertionWriterError.writerStopped }
                    activePlan = previous
                } catch {
                    stopped = true
                    await cleanupLocked(connectionLost: false)
                    throw CoordinatedPolicyWriterError.restorationFailed
                }
            } else {
                stopped = true
                await cleanupLocked(connectionLost: false)
            }
            throw error
        }
    }
}

#if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
extension CoordinatedPolicyWriter {
    public func hideManualSystemItem(
        _ target: SharedSystemItemTrialTarget
    ) async throws -> SharedSystemItemTrialReceipt {
        await acquireOperation()
        defer { releaseOperation() }
        guard !stopped else { throw RevealAssertionWriterError.writerStopped }
        guard let manualWriter = persistentWriter as? any ManualSystemItemTrialWriting else {
            throw SharedSystemItemTrialError.unsupportedRuntime
        }
        #if BLENNY_PRODUCT || DEBUG
        if orderingRecovery != nil {
            let recovery = try await restoreOrderingLocked()
            guard recovery.preferencesRestored, recovery.relativeOrderVerified else {
                throw OrderingTransactionError.restorationNotVerified
            }
        }
        guard !stopped else { throw RevealAssertionWriterError.writerStopped }
        #endif
        let receipt = try await manualWriter.hide(target)
        guard !stopped else { throw RevealAssertionWriterError.writerStopped }
        return receipt
    }

    /// Explicit restoration remains available after Stop and never depends on
    /// ordering recovery; both operations still share the one serial gate.
    public func restoreManualSystemItem(
        _ target: SharedSystemItemTrialTarget
    ) async throws {
        await acquireOperation()
        defer { releaseOperation() }
        guard let manualWriter = persistentWriter as? any ManualSystemItemTrialWriting else {
            throw SharedSystemItemTrialError.unsupportedRuntime
        }
        try await manualWriter.restore(target)
    }
}
#endif

#if BLENNY_PRODUCT || DEBUG
extension CoordinatedPolicyWriter {
    public func orderingReceipt() async throws -> OrderingRecoveryReceipt? {
        guard let orderingRecovery else { throw OrderingTransactionError.unavailable }
        return try await orderingRecovery.load()
    }

    public func orderingUndoAvailable() async throws -> Bool {
        guard let orderingRecovery else { throw OrderingTransactionError.unavailable }
        return try await orderingRecovery.load()?.hasConfigurationUndo == true
    }

    /// Commits a configuration-first order and retains one durable Undo baseline.
    /// A clean configuration receipt may be advanced by later user-reviewed commits;
    /// Stop and Quit leave that committed configuration in place.
    public func applyConfigurationOrdering(
        _ plan: OrderingPlan, confirmedFingerprint: String,
        policyChange: PreparedPolicyEdit? = nil,
        policyStore: (any PersistentBundlePolicyStoring)? = nil,
        confirmedUndoRebaseToken: String? = nil
    ) async throws -> OrderingConfigurationCommitResult {
        await acquireOperation()
        defer { releaseOperation() }
        try await requireNoFallbackExperiment()
        guard !stopped, (plan.schemaVersion == 3 || plan.schemaVersion == 4),
              let backend = orderingBackend,
              let recovery = orderingRecovery else { throw OrderingTransactionError.unavailable }
        try plan.validate()
        guard confirmedFingerprint == plan.fingerprint else {
            throw OrderingTransactionError.confirmationMismatch
        }
        guard !plan.configurationKeyTargets.isEmpty || policyChange != nil else {
            throw OrderingTransactionError.invalidReceipt
        }
        var policyBackup: PersistentBundlePolicyBackup?
        if let policyChange {
            guard policyChange.persistenceMode == .saveAcceptedPolicy,
                  policyChange.newPolicy.managementEnabled,
                  policyChange.newPolicy != policyChange.oldPolicy,
                  policyChange.report.newBaselinePlan != nil,
                  policyChange.report.oldBaselinePlan != nil,
                  let policyStore,
                  try await policyStore.load() == policyChange.oldPolicy else {
                throw OrderingTransactionError.contextInvalidated
            }
            policyBackup = try await policyStore.loadBackup()
            guard policyBackup?.backupFingerprint
                    == policyChange.reviewBinding.recoveryBackupFingerprint else {
                throw OrderingTransactionError.contextInvalidated
            }
        }
        guard !consumedOrderingPlans.contains(plan.id) else {
            throw OrderingTransactionError.alreadyConsumed
        }
        try await recovery.acquireLease()
        let existing = try await recovery.load()
        if let existing {
            guard (existing.schemaVersion == 2 || existing.schemaVersion == 3 || existing.schemaVersion == 4),
                  !existing.isPendingRestoration,
                  existing.phase == .applied else {
                orderingRecoveryPending = true
                throw OrderingTransactionError.recoveryRequired
            }
            orderingRecoveryPending = false
        }

        let current = try await backend.capture()
        try plan.validateFresh(equivalentTo: current, now: Date())
        guard !stopped else { throw OrderingTransactionError.contextInvalidated }
        guard let before = plan.configurationBeforeValues,
              let after = plan.configurationAfterValues else {
            throw OrderingTransactionError.invalidReceipt
        }
        let currentTable = try current.table()
        let undoRebaseReview = try existing?.undoLedgerRebaseReview(in: current)
        guard undoRebaseReview?.token == confirmedUndoRebaseToken else {
            throw OrderingTransactionError.confirmationMismatch
        }
        consumedOrderingPlans.insert(plan.id)

        var receipt: OrderingRecoveryReceipt
        if let existing, undoRebaseReview == nil {
            guard var original = existing.originalValues,
                  var committed = existing.committedValues,
                  let sessionIdentifier = existing.sessionIdentifier else {
                throw OrderingTransactionError.invalidReceipt
            }
            // A nil rebase review proves every retained committed value still
            // equals this fresh capture. Continue the same Undo session.
            guard committed.allSatisfy({ currentTable[$0.key] == $0.value }) else {
                throw OrderingTransactionError.confirmationMismatch
            }
            for (key, value) in before {
                if let prior = committed[key] {
                    guard prior == value else { throw OrderingTransactionError.recoveryRequired }
                } else {
                    original[key] = value
                    committed[key] = value
                }
            }
            var subjectBindings: [OrderingConfigurationSubjectTarget] = existing.subjectBindings
                ?? (existing.ownerBindings ?? []).map {
                    OrderingConfigurationSubjectTarget.application($0)
                }
            let incomingBindings: [OrderingConfigurationSubjectTarget] = plan.configurationSubjectTargets
                ?? (plan.configurationTargets ?? []).map {
                    OrderingConfigurationSubjectTarget.application($0)
                }
            for incoming in incomingBindings {
                if let index = subjectBindings.firstIndex(where: {
                    $0.subjectID == incoming.subjectID
                }) {
                    subjectBindings[index] = mergeConfigurationBinding(
                        subjectBindings[index], incoming
                    )
                } else {
                    subjectBindings.append(incoming)
                }
            }
            var pending = committed
            for (key, value) in after { pending[key] = value }
            if plan.schemaVersion == 3 {
                guard subjectBindings.allSatisfy({
                    if case .application = $0 { return true }
                    return false
                }) else { throw OrderingTransactionError.recoveryRequired }
            }
            receipt = OrderingRecoveryReceipt(
                configurationPlan: plan,
                sessionIdentifier: sessionIdentifier,
                revision: (existing.revision ?? 0) + 1,
                originalValues: original,
                committedValues: committed,
                pendingValues: pending,
                detail: "Configuration revision is about to be written."
            )
            if plan.schemaVersion == 4 {
                receipt.subjectBindings = subjectBindings.sorted {
                    $0.subjectID.boardID < $1.subjectID.boardID
                }
            } else {
                receipt.ownerBindings = subjectBindings.compactMap {
                    if case let .application(owner) = $0 { return owner }
                    return nil
                }.sorted { $0.bundleIdentifier < $1.bundleIdentifier }
            }
        } else {
            receipt = OrderingRecoveryReceipt(
                configurationPlan: plan,
                originalValues: before,
                committedValues: before, pendingValues: after,
                detail: undoRebaseReview == nil
                    ? "Configuration revision is about to be written."
                    : "A reviewed external configuration change superseded the previous clean Undo ledger; this new session is about to be written."
            )
        }
        if plan.schemaVersion == 4 || policyChange != nil || existing?.schemaVersion == 4 {
            receipt.schemaVersion = 4
            receipt.undoPolicy = existing?.undoPolicy
        }
        if let policyChange {
            receipt.originalPolicy = policyChange.oldPolicy
            receipt.originalPolicyBackup = policyBackup
            receipt.proposedPolicy = policyChange.newPolicy
            receipt.policyPersistenceCommitted = false
        }
        if let existing, undoRebaseReview != nil {
            do {
                try await recovery.supersedeClean(existing, with: receipt)
            } catch {
                // A durable replacement may have been installed even if the
                // final persistence acknowledgement failed. Inspect once so a
                // clean old ledger does not poison state, while an ambiguous
                // apply intent remains recoverable.
                do {
                    guard let retained = try await recovery.load() else {
                        orderingRecoveryPending = true
                        throw error
                    }
                    orderingRecoveryPending = retained.isPendingRestoration
                } catch {
                    orderingRecoveryPending = true
                }
                throw error
            }
        } else {
            try await recovery.save(receipt)
        }
        orderingRecoveryPending = true

        do {
            let proposed = try plan.applying(to: current.group)
            guard case let .dictionary(table)? = proposed[OrderingSnapshot.tableKey] else {
                throw OrderingTransactionError.invalidReceipt
            }
            guard !stopped else { throw OrderingTransactionError.contextInvalidated }
            if before != after {
                try await backend.writeConfigurationTable(
                    table, expecting: current, ownerKeys: Set(before.keys)
                )
            }
            let observed = before == after ? current : try await backend
                .captureConfigurationTransition(from: current, to: table)
            guard !stopped else { throw OrderingTransactionError.contextInvalidated }
            try validateConfiguredOrdering(plan, observed: observed, expectedGroup: proposed)
            var finalObserved = observed
            var physical = plan.physicalVerificationStatus(in: observed)
            if let policyChange, let policyStore,
               let newBaseline = policyChange.report.newBaselinePlan,
               let oldBaseline = policyChange.report.oldBaselinePlan {
                do {
                    try await transition(to: newBaseline, baselineReplacement: true)
                    guard !stopped,
                          try await assertionWriter.verifyActivePlan(newBaseline),
                          try await persistentWriter.verifyManagedPlan(newBaseline.persistentSystemItems) else {
                        throw OrderingTransactionError.contextInvalidated
                    }
                    try await policyStore.save(policyChange.newPolicy)
                    await persistentWriter.finalizeCommittedPlan(newBaseline.persistentSystemItems)
                    guard !stopped else { throw OrderingTransactionError.contextInvalidated }
                    receipt.policyPersistenceCommitted = true
                    if plan.schemaVersion == 4 {
                        let postPolicy = try await backend.captureConfigurationTransition(
                            from: current, to: table
                        )
                        guard !stopped else {
                            throw OrderingTransactionError.contextInvalidated
                        }
                        try validateConfiguredOrdering(
                            plan, observed: postPolicy, expectedGroup: proposed
                        )
                        finalObserved = postPolicy
                        physical = plan.physicalVerificationStatus(in: postPolicy)
                    }
                } catch {
                    let policyFailure = error
                    do {
                        if policyChange.oldPolicy.managementEnabled {
                            try await transition(to: oldBaseline, baselineReplacement: true)
                            guard try await assertionWriter.verifyActivePlan(oldBaseline),
                                  try await persistentWriter.verifyManagedPlan(oldBaseline.persistentSystemItems) else {
                                throw CoordinatedPolicyWriterError.restorationFailed
                            }
                        } else {
                            await assertionWriter.restoreAndStop()
                            guard await persistentWriter.restoreAllManagedItems() else {
                                throw CoordinatedPolicyWriterError.restorationFailed
                            }
                            activePlan = nil
                        }
                        let policyState = try await policyStore.load()
                        if policyState == policyChange.newPolicy {
                            try await policyStore.restoreSnapshot(
                                document: policyChange.oldPolicy,
                                backup: receipt.originalPolicyBackup,
                                expecting: policyChange.newPolicy
                            )
                        } else if policyState != policyChange.oldPolicy {
                            throw OrderingTransactionError.policyRecoveryRequired
                        }
                        receipt.policyPersistenceCommitted = false
                        try await recovery.save(receipt)
                    } catch {
                        receipt.detail = "Policy commit and rollback were not both verified."
                        try? await recovery.save(receipt)
                        orderingRecoveryPending = true
                        throw OrderingTransactionError.policyRecoveryRequired
                    }
                    throw policyFailure
                }
            }
            var committedReceipt = receipt
            committedReceipt.phase = .applied
            committedReceipt.detail = physical == .verified
                ? "Exact configuration and observed physical order verified."
                : "Exact configuration verified; physical order remains \(physical.rawValue)."
            // Advance the single-level Undo baseline only after verification.
            // Until this point the previous Undo survives a failed revision.
            if before != after || policyChange != nil {
                committedReceipt.originalValues = receipt.committedValues
            }
            if before != after || policyChange != nil {
                committedReceipt.undoPolicy = policyChange.map {
                    OrderingPolicyUndo(before: $0.oldPolicy, after: $0.newPolicy, backup: policyBackup)
                }
            }
            committedReceipt.committedValues = receipt.pendingValues
            committedReceipt.pendingValues = nil
            committedReceipt.configurationVerified = true
            committedReceipt.physicalVerificationStatus = physical
            // Policy rollback metadata is needed only while the combined commit
            // is unfinished. A clean Undo restores preferred positions only.
            committedReceipt.originalPolicy = nil
            committedReceipt.originalPolicyBackup = nil
            committedReceipt.proposedPolicy = nil
            committedReceipt.policyPersistenceCommitted = nil
            do {
                try await recovery.save(committedReceipt)
            } catch {
                // A lost acknowledgement is not a failed commit when the exact
                // verified record can be read back. Do not roll back past it.
                guard (try? await recovery.load()) == committedReceipt else { throw error }
            }
            orderingRecoveryPending = false
            return OrderingConfigurationCommitResult(
                snapshot: finalObserved, configurationVerified: true,
                physicalVerificationStatus: physical,
                revision: receipt.revision ?? 1
            )
        } catch {
            let originalFailure = error
            OrderingPreferenceDiagnostics.record("configuration-commit-failed", detail: error.localizedDescription)
            if let orderingError = originalFailure as? OrderingTransactionError,
               orderingError == .policyRecoveryRequired {
                orderingRecoveryPending = true
                throw originalFailure
            }
            do {
                if receipt.policyPersistenceCommitted == true,
                   let policyChange, let policyStore,
                   let oldBaseline = policyChange.report.oldBaselinePlan {
                    if policyChange.oldPolicy.managementEnabled {
                        try await transition(to: oldBaseline, baselineReplacement: true)
                        guard try await assertionWriter.verifyActivePlan(oldBaseline),
                              try await persistentWriter.verifyManagedPlan(oldBaseline.persistentSystemItems) else {
                            throw CoordinatedPolicyWriterError.restorationFailed
                        }
                    } else {
                        await assertionWriter.restoreAndStop()
                        guard await persistentWriter.restoreAllManagedItems() else {
                            throw CoordinatedPolicyWriterError.restorationFailed
                        }
                        activePlan = nil
                    }
                    guard try await policyStore.load() == policyChange.newPolicy else {
                        throw OrderingTransactionError.contextInvalidated
                    }
                    try await policyStore.restoreSnapshot(
                        document: policyChange.oldPolicy,
                        backup: receipt.originalPolicyBackup,
                        expecting: policyChange.newPolicy
                    )
                    receipt.policyPersistenceCommitted = false
                    try await recovery.save(receipt)
                }
                try await rollbackConfigurationCommitLocked(receipt, backend: backend, recovery: recovery)
                orderingRecoveryPending = false
            } catch {
                OrderingPreferenceDiagnostics.record("configuration-rollback-failed", detail: error.localizedDescription)
                orderingRecoveryPending = true
                throw error
            }
            throw originalFailure
        }
    }

    /// A user-reviewed position transaction shares the visibility writer's gate.
    /// No implicit approval, target selection or position retry is performed here.
    public func applyOrdering(
        _ plan: OrderingPlan, confirmedFingerprint: String
    ) async throws -> OrderingSnapshot {
        await acquireOperation()
        defer { releaseOperation() }
        try await requireNoFallbackExperiment()
        guard !stopped, let backend = orderingBackend,
              let recovery = orderingRecovery else { throw OrderingTransactionError.unavailable }
        try plan.validate()
        guard confirmedFingerprint == plan.fingerprint else {
            throw OrderingTransactionError.confirmationMismatch
        }
        guard !consumedOrderingPlans.contains(plan.id) else {
            throw OrderingTransactionError.alreadyConsumed
        }
        try await recovery.acquireLease()
        guard try await recovery.load() == nil else {
            orderingRecoveryPending = true
            throw OrderingTransactionError.recoveryRequired
        }
        let current: OrderingSnapshot
        do {
            current = try await backend.capture()
            try plan.validateFresh(equivalentTo: current, now: Date())
            guard !stopped else { throw OrderingTransactionError.contextInvalidated }
        } catch {
            await recovery.releaseLease()
            throw error
        }
        consumedOrderingPlans.insert(plan.id)
        let proposed = try plan.applying(to: current.group)
        var receipt = OrderingRecoveryReceipt(plan: plan, phase: .applyIntent)
        do {
            try await recovery.save(receipt)
        } catch {
            // Even an ambiguous journal write is conservatively retained.
            orderingRecoveryPending = true
            throw error
        }
        orderingRecoveryPending = true
        do {
            guard !stopped else { throw OrderingTransactionError.contextInvalidated }
            guard case let .dictionary(table)? = proposed["TrailingItemPreferredPositions"] else {
                throw OrderingTransactionError.invalidReceipt
            }
            try await backend.writeTable(table, expecting: current)
            let observed = try await backend.capture()
            guard !stopped else { throw OrderingTransactionError.contextInvalidated }
            try validateAppliedOrdering(plan, observed: observed, expectedGroup: proposed)
            receipt.phase = .applied
            receipt.detail = "The reviewed relative order was verified by an independent AX capture."
            try await recovery.save(receipt)
            return observed
        } catch {
            let originalFailure = error
            do {
                let restored = try await restoreOrderingLocked()
                guard restored.relativeOrderVerified else {
                    throw OrderingTransactionError.restorationNotVerified
                }
            } catch {
                orderingRecoveryPending = true
                throw error
            }
            throw originalFailure
        }
    }

    public func restoreOrdering(
        policyStore: (any PersistentBundlePolicyStoring)? = nil,
        policyUndo: PreparedPolicyEdit? = nil
    ) async throws -> OrderingRestoreResult {
        await acquireOperation()
        defer { releaseOperation() }
        try await requireNoFallbackExperiment()
        // Explicit recovery is permitted on a stopped coordinator. It can never
        // re-enable that coordinator's assertion or ordering Apply path.
        return try await restoreOrderingLocked(policyStore: policyStore, policyUndo: policyUndo)
    }

    private func restoreOrderingLocked(
        policyStore: (any PersistentBundlePolicyStoring)? = nil,
        policyUndo: PreparedPolicyEdit? = nil
    ) async throws -> OrderingRestoreResult {
        guard let backend = orderingBackend, let recovery = orderingRecovery else {
            throw OrderingTransactionError.unavailable
        }
        guard try await recovery.load() != nil else {
            orderingRecoveryPending = false
            await recovery.releaseLease()
            return OrderingRestoreResult(preferencesRestored: true, relativeOrderVerified: true)
        }
        try await recovery.acquireLease()
        guard var receipt = try await recovery.load() else {
            orderingRecoveryPending = false
            await recovery.releaseLease()
            return OrderingRestoreResult(preferencesRestored: true, relativeOrderVerified: true)
        }
        orderingRecoveryPending = true
        try receipt.validate()
        if receipt.schemaVersion == 2 || receipt.schemaVersion == 3 || receipt.schemaVersion == 4 {
            return try await restoreConfigurationReceiptLocked(
                &receipt, backend: backend, recovery: recovery,
                policyStore: policyStore ?? orderingPolicyStore, policyUndo: policyUndo
            )
        }
        let current = try await backend.capture()
        try validateRecoveryIdentity(receipt.plan, current: current)
        let restoredGroup = try receipt.plan.restoring(current: current.group)
        var observed = current
        if restoredGroup != current.group {
            guard receipt.phase == .applyIntent || receipt.phase == .applied else {
                throw OrderingTransactionError.restorationAlreadyAttempted
            }
            receipt.phase = .restoreIntent
            receipt.detail = "One inverse is about to be attempted; never replay blindly."
            try await recovery.save(receipt)
            guard case let .dictionary(table)? = restoredGroup["TrailingItemPreferredPositions"] else {
                throw OrderingTransactionError.invalidReceipt
            }
            // A failed synchronization may still have written. Exactly one read
            // determines the outcome; an inverse is never automatically repeated.
            do { try await backend.restoreTable(table, expecting: current) }
            catch { receipt.detail = "Inverse returned an error: \(error.localizedDescription)" }
            observed = try await backend.capture()
            guard observed.group == restoredGroup else {
                try? await recovery.save(receipt)
                throw OrderingTransactionError.restorationAlreadyAttempted
            }
        }
        receipt.phase = .preferencesRestored
        let relativeVerified = orderingRelativeVerified(receipt.plan, observed: observed, phase: .baseline)
            && ownerPreferencesUnchanged(receipt.plan, observed: observed)
        receipt.detail = relativeVerified
            ? "Exact target preferences and original relative order verified; unrelated state preserved."
            : "Exact target preferences restored. Relative order or owner preferences remain unverified."
        try await recovery.save(receipt)
        if relativeVerified {
            try await recovery.complete(receipt)
            orderingRecoveryPending = false
            await recovery.releaseLease()
        }
        return OrderingRestoreResult(preferencesRestored: true, relativeOrderVerified: relativeVerified)
    }

    private func validateAppliedOrdering(
        _ plan: OrderingPlan, observed: OrderingSnapshot,
        expectedGroup: [String: OrderingValue]
    ) throws {
        try observed.validate()
        let baseline = plan.baseline
        guard observed.group == expectedGroup,
              observed.osBuild == baseline.osBuild,
              observed.architecture == baseline.architecture,
              observed.displaySignature == baseline.displaySignature,
              observed.lifecycleGeneration == baseline.lifecycleGeneration,
              observed.policyFingerprint == baseline.policyFingerprint,
              observed.orderingAllowedBundleIdentifiers == baseline.orderingAllowedBundleIdentifiers,
              ownerPreferencesUnchanged(plan, observed: observed),
              orderingRelativeVerified(plan, observed: observed, phase: .applied) else {
            throw OrderingTransactionError.movementNotVerified
        }
        let candidates = try OrderingIdentityResolver.resolve(snapshot: observed)
        for target in plan.targets {
            guard let candidate = candidates.first(where: { $0.bundleIdentifier == target.bundleIdentifier }),
                  candidate.eligible, candidate.process == target.process,
                  candidate.key == target.key, candidate.configuredValue == target.after else {
                throw OrderingTransactionError.movementNotVerified
            }
        }
    }

    private func validateConfiguredOrdering(
        _ plan: OrderingPlan, observed: OrderingSnapshot,
        expectedGroup: [String: OrderingValue]
    ) throws {
        try observed.validate()
        guard plan.schemaVersion == 3 || plan.schemaVersion == 4,
              let expected = plan.configurationAfterValues,
              observed.osBuild == plan.baseline.osBuild,
              observed.architecture == plan.baseline.architecture,
              observed.runtimeContractVerified == plan.baseline.runtimeContractVerified,
              observed.displaySignature == plan.baseline.displaySignature,
              observed.displayCount == plan.baseline.displayCount,
              observed.displayFrame == plan.baseline.displayFrame,
              observed.lifecycleGeneration == plan.baseline.lifecycleGeneration,
              observed.policyFingerprint == plan.baseline.policyFingerprint,
              observed.runtimeContractVerified,
              observed.group == expectedGroup else {
            throw OrderingTransactionError.movementNotVerified
        }
        let table = try observed.table()
        guard expected.allSatisfy({ table[$0.key] == $0.value }) else {
            throw OrderingTransactionError.movementNotVerified
        }
        if !plan.configurationKeyTargets.isEmpty {
            try plan.baseline.validateConfigurationProcessScope(
                for: Set(plan.configurationKeyTargets.map(\.key)), against: observed)
        }
        let resolved = try OrderingConfigurationIdentityResolver.resolve(snapshot: observed)
        let applicationTargets: [OrderingConfigurationOwnerTarget] =
            plan.configurationTargets
            ?? (plan.configurationSubjectTargets ?? []).compactMap {
                if case let .application(owner) = $0 { return owner }
                return nil
            }
        for target in applicationTargets {
            guard let candidate = resolved.first(where: { $0.bundleIdentifier == target.bundleIdentifier }),
                  candidate.eligible, candidate.process == target.process,
                  Set(candidate.keys.map(\.key)) == Set(target.keys.map(\.key)),
                  let beforeObservation = plan.baseline.observationsByPID[target.process.pid],
                  let afterObservation = observed.observationsByPID[target.process.pid] else {
                throw OrderingTransactionError.movementNotVerified
            }
            if let identity = target.exactBundleCodeIdentity {
                guard candidate.exactBundleCodeIdentity == identity,
                      beforeObservation.applicationCodeIdentity == identity,
                      afterObservation.applicationCodeIdentity == identity else {
                    throw OrderingTransactionError.movementNotVerified
                }
            } else {
                guard afterObservation.ownerPreferencesComplete,
                      afterObservation.ownerSavedPositions == beforeObservation.ownerSavedPositions,
                      afterObservation.ownerPreferenceNamespace == beforeObservation.ownerPreferenceNamespace,
                      afterObservation.ownerPreferenceSourceIdentity == beforeObservation.ownerPreferenceSourceIdentity else {
                    throw OrderingTransactionError.movementNotVerified
                }
            }
        }
        let resolvedSystems = try OrderingSystemConfigurationIdentityResolver.resolve(
            snapshot: observed
        )
        for target in (plan.configurationSubjectTargets ?? []).compactMap({
            if case let .systemItem(system) = $0 { return system }
            return nil
        }) {
            guard let candidate = resolvedSystems.first(where: { $0.item == target.item }),
                  candidate.eligible,
                  candidate.hostBinding == target.hostBinding,
                  candidate.key == target.key.key,
                  candidate.value == target.key.after else {
                throw OrderingTransactionError.movementNotVerified
            }
        }
    }

    private func mergeConfigurationBinding(
        _ existing: OrderingConfigurationOwnerTarget,
        _ incoming: OrderingConfigurationOwnerTarget
    ) -> OrderingConfigurationOwnerTarget {
        var byKey = Dictionary(uniqueKeysWithValues: existing.keys.map { ($0.key, $0) })
        for key in incoming.keys { byKey[key.key] = key }
        return OrderingConfigurationOwnerTarget(
            bundleIdentifier: incoming.bundleIdentifier,
            displayName: incoming.displayName,
            process: incoming.process,
            keys: byKey.values.sorted { $0.key < $1.key },
            ownerSavedPositions: incoming.ownerSavedPositions,
            ownerPreferenceNamespace: incoming.ownerPreferenceNamespace,
            ownerPreferenceSourceIdentity: incoming.ownerPreferenceSourceIdentity,
            exactBundleCodeIdentity: incoming.exactBundleCodeIdentity
        )
    }

    private func mergeConfigurationBinding(
        _ existing: OrderingConfigurationSubjectTarget,
        _ incoming: OrderingConfigurationSubjectTarget
    ) -> OrderingConfigurationSubjectTarget {
        switch (existing, incoming) {
        case let (.application(existingOwner), .application(incomingOwner)):
            return .application(mergeConfigurationBinding(existingOwner, incomingOwner))
        case let (.systemItem(existingSystem), .systemItem(incomingSystem)):
            // The same exact item has one key. A changed host binding is retained
            // in the current revision only after ordinary freshness validates it;
            // prior originals remain protected by recovery validation.
            guard existingSystem.key.key == incomingSystem.key.key else { return existing }
            return .systemItem(incomingSystem)
        default:
            return existing
        }
    }

    private func rollbackConfigurationCommitLocked(
        _ originalReceipt: OrderingRecoveryReceipt,
        backend: any MenuBarOrderingBackend,
        recovery: any OrderingRecoveryStoring
    ) async throws {
        var receipt = originalReceipt
        guard let committed = receipt.committedValues,
              let pending = receipt.pendingValues else {
            throw OrderingTransactionError.invalidReceipt
        }
        let current = try await backend.capture()
        guard let bindings = configurationBindings(receipt) else {
            throw OrderingTransactionError.invalidReceipt
        }
        try validateConfigurationRecoveryIdentity(bindings, current: current)
        let table = try current.table()
        for key in committed.keys {
            guard let value = table[key], value == committed[key] || value == pending[key] else {
                throw OrderingTransactionError.recoveryRequired
            }
        }
        var restoredTable = table
        for (key, value) in committed { restoredTable[key] = value }
        if restoredTable != table {
            receipt.phase = .restoreIntent
            receipt.detail = "The failed revision is about to be restored once to the last committed configuration."
            receipt.pendingValues = committed
            receipt.configurationVerified = false
            try await recovery.save(receipt)
            try await backend.restoreConfigurationTable(
                restoredTable, expecting: current,
                ownerKeys: Set(bindings.flatMap(\.keys).map(\.key))
            )
        }
        let observed = restoredTable == table ? current : try await backend
            .captureConfigurationTransition(from: current, to: restoredTable)
        let observedTable = try observed.table()
        guard committed.allSatisfy({ observedTable[$0.key] == $0.value }) else {
            try? await recovery.save(receipt)
            throw OrderingTransactionError.restorationNotVerified
        }
        if receipt.schemaVersion == 3 || receipt.schemaVersion == 4 {
            var expectedGroup = current.group
            expectedGroup[OrderingSnapshot.tableKey] = .dictionary(restoredTable)
            guard observed.group == expectedGroup else {
                try? await recovery.save(receipt)
                throw OrderingTransactionError.restorationNotVerified
            }
            try validateConfigurationRecoveryIdentity(bindings, current: observed)
        }
        receipt.phase = .applied
        receipt.detail = "The failed configuration revision was rolled back to the last committed values."
        receipt.pendingValues = nil
        receipt.configurationVerified = true
        receipt.physicalVerificationStatus = .unavailable
        if receipt.policyPersistenceCommitted == false {
            receipt.originalPolicy = nil
            receipt.originalPolicyBackup = nil
            receipt.proposedPolicy = nil
            receipt.policyPersistenceCommitted = nil
        }
        try await recovery.save(receipt)
    }

    private func restoreConfigurationReceiptLocked(
        _ receipt: inout OrderingRecoveryReceipt,
        backend: any MenuBarOrderingBackend,
        recovery: any OrderingRecoveryStoring,
        policyStore: (any PersistentBundlePolicyStoring)?,
        policyUndo: PreparedPolicyEdit?
    ) async throws -> OrderingRestoreResult {
        guard let original = receipt.originalValues,
              let committed = receipt.committedValues,
              let bindings = configurationBindings(receipt) else {
            throw OrderingTransactionError.invalidReceipt
        }
        let current = try await backend.capture()
        try validateConfigurationRecoveryIdentity(bindings, current: current)
        let table = try current.table()
        let pending = receipt.pendingValues ?? committed
        if receipt.phase == .restoreIntent {
            if pending.allSatisfy({ table[$0.key] == $0.value }) {
                if pending != original {
                    receipt.phase = .applied
                    receipt.detail = "The interrupted revision rollback is confirmed at the last committed configuration."
                    receipt.committedValues = pending
                    receipt.pendingValues = nil
                    receipt.configurationVerified = true
                    receipt.physicalVerificationStatus = .unavailable
                    try await recovery.save(receipt)
                    orderingRecoveryPending = false
                    return OrderingRestoreResult(preferencesRestored: true, relativeOrderVerified: false)
                }
            } else if pending == original,
                      (receipt.configurationRestoreRetryCount ?? 0) == 0,
                      committed.allSatisfy({ table[$0.key] == $0.value }) {
                // The complete independent capture proves the preceding inverse
                // attempt changed none of the controlled values. A new explicit
                // Recover action may make one bounded retry; it is never retried
                // inside the failed action and a second failure remains terminal.
                receipt.phase = .applied
                receipt.detail = "The previous configuration Undo changed no controlled values; one explicit retry is being attempted."
                receipt.pendingValues = nil
                receipt.configurationVerified = true
                receipt.physicalVerificationStatus = .unavailable
                receipt.configurationRestoreRetryCount = 1
                try await recovery.save(receipt)
            } else {
                throw OrderingTransactionError.restorationAlreadyAttempted
            }
        }
        if receipt.phase == .applied,
           let undo = receipt.undoPolicy, receipt.originalPolicy == nil {
            guard let policyStore, let policyUndo,
                  let currentPolicy = try await policyStore.load() else {
                throw OrderingTransactionError.contextInvalidated
            }
            let expectedCurrent = try undo.after.settingManagementEnabled(
                currentPolicy.managementEnabled
            )
            let restoreTarget = try undo.before.settingManagementEnabled(
                currentPolicy.managementEnabled
            )
            let recoveryCoordinatorMatchesManagementState = currentPolicy.managementEnabled
                ? !stopped
                : activePlan == nil
            guard recoveryCoordinatorMatchesManagementState,
                  currentPolicy == expectedCurrent,
                  policyUndo.oldPolicy == expectedCurrent,
                  policyUndo.newPolicy == restoreTarget,
                  policyUndo.report.newBaselinePlan != nil else {
                throw OrderingTransactionError.contextInvalidated
            }
            // Persist policy recovery metadata before either inverse mutation.
            receipt.undoPolicyRestoreIntent = true
            receipt.originalPolicy = restoreTarget
            receipt.originalPolicyBackup = undo.backup
            receipt.proposedPolicy = expectedCurrent
            receipt.policyPersistenceCommitted = true
            try await recovery.save(receipt)
        }
        for key in original.keys {
            guard let value = table[key],
                  value == original[key] || value == committed[key] || value == pending[key] else {
                throw OrderingTransactionError.recoveryRequired
            }
        }
        var restoredTable = table
        for (key, value) in original { restoredTable[key] = value }
        if restoredTable != table {
            receipt.phase = .restoreIntent
            receipt.detail = "Exact configuration Undo is about to be attempted once."
            receipt.pendingValues = original
            receipt.configurationVerified = false
            try await recovery.save(receipt)
            do {
                try await backend.restoreConfigurationTable(
                    restoredTable, expecting: current,
                    ownerKeys: Set(bindings.flatMap(\.keys).map(\.key))
                )
            }
            catch { receipt.detail = "Configuration Undo returned an error: \(error.localizedDescription)" }
        }
        let observed = restoredTable == table ? current : try await backend
            .captureConfigurationTransition(from: current, to: restoredTable)
        let observedTable = try observed.table()
        guard original.allSatisfy({ observedTable[$0.key] == $0.value }) else {
            try? await recovery.save(receipt)
            throw OrderingTransactionError.restorationAlreadyAttempted
        }
        if receipt.schemaVersion == 3 || receipt.schemaVersion == 4 {
            var expectedGroup = current.group
            expectedGroup[OrderingSnapshot.tableKey] = .dictionary(restoredTable)
            guard observed.group == expectedGroup else {
                try? await recovery.save(receipt)
                throw OrderingTransactionError.restorationAlreadyAttempted
            }
            try validateConfigurationRecoveryIdentity(bindings, current: observed)
        }
        if let originalPolicy = receipt.originalPolicy,
           let proposedPolicy = receipt.proposedPolicy {
            guard let policyStore else {
                receipt.detail = "Exact configuration was restored, but policy recovery still needs its store."
                try? await recovery.save(receipt)
                throw OrderingTransactionError.restorationNotVerified
            }
            let currentPolicy = try await policyStore.load()
            guard currentPolicy == originalPolicy || currentPolicy == proposedPolicy else {
                receipt.detail = "Accepted policy changed outside the recorded ordering transaction."
                try? await recovery.save(receipt)
                throw OrderingTransactionError.contextInvalidated
            }
            if currentPolicy == proposedPolicy {
                if receipt.undoPolicyRestoreIntent == true {
                    if proposedPolicy.managementEnabled {
                        guard let baseline = policyUndo?.report.newBaselinePlan, !stopped else {
                            throw OrderingTransactionError.contextInvalidated
                        }
                        if receipt.undoPolicyWriteAttempted != true {
                            receipt.undoPolicyWriteAttempted = true
                            try await recovery.save(receipt)
                            try await transition(to: baseline, baselineReplacement: true)
                        }
                        // An interrupted inverse may be verified, never replayed blindly.
                        guard try await assertionWriter.verifyActivePlan(baseline),
                              try await persistentWriter.verifyManagedPlan(baseline.persistentSystemItems) else {
                            throw OrderingTransactionError.restorationNotVerified
                        }
                    } else {
                        // Explicit Undo is allowed after Stop. The policy store and
                        // order are restored without a visibility transition. A
                        // freshly reopened app owns an inactive recovery writer,
                        // while a same-process Stop owns a stopped writer; both
                        // have no active plan and remain unrestricted.
                        guard activePlan == nil,
                              policyUndo?.oldPolicy == proposedPolicy,
                              policyUndo?.newPolicy == originalPolicy else {
                            throw OrderingTransactionError.contextInvalidated
                        }
                    }
                }
                try await policyStore.restoreSnapshot(
                    document: originalPolicy,
                    backup: receipt.originalPolicyBackup,
                    expecting: proposedPolicy
                )
                if proposedPolicy.managementEnabled,
                   let baseline = policyUndo?.report.newBaselinePlan {
                    await persistentWriter.finalizeCommittedPlan(baseline.persistentSystemItems)
                }
            }
            receipt.policyPersistenceCommitted = false
        }
        let physical = receipt.plan.physicalVerificationStatus(in: observed, phase: .baseline)
        receipt.undoPolicy = nil
        receipt.undoPolicyRestoreIntent = nil
        receipt.undoPolicyWriteAttempted = nil
        receipt.phase = .preferencesRestored
        receipt.detail = physical == .verified
            ? "Exact original configuration and observed physical order restored."
            : "Exact original configuration restored; physical order remains \(physical.rawValue)."
        receipt.committedValues = original
        receipt.pendingValues = nil
        receipt.configurationVerified = true
        receipt.physicalVerificationStatus = physical
        receipt.originalPolicy = nil
        receipt.originalPolicyBackup = nil
        receipt.proposedPolicy = nil
        receipt.policyPersistenceCommitted = nil
        try await recovery.save(receipt)
        try await recovery.complete(receipt)
        orderingRecoveryPending = false
        await recovery.releaseLease()
        return OrderingRestoreResult(
            preferencesRestored: true,
            relativeOrderVerified: physical == .verified
        )
    }

    private func validateConfigurationRecoveryIdentity(
        _ bindings: [OrderingConfigurationSubjectTarget], current: OrderingSnapshot
    ) throws {
        try current.validate()
        let inventory = (current.beforeProcesses + current.afterProcesses).reduce(into: [OrderingProcess]()) {
            if !$0.contains($1) { $0.append($1) }
        }
        for binding in bindings {
            switch binding {
            case let .systemItem(system):
                let currentBindings = current.systemHostBindings?.filter {
                    $0.item == system.item
                } ?? []
                guard currentBindings.count == 1,
                      let currentBinding = currentBindings.first else {
                    throw OrderingTransactionError.recoveryIdentityConflict
                }
                let recordedHost = system.hostBinding.hostProcess
                let currentHost = currentBinding.hostProcess
                guard system.key.key == system.item.configurationKey,
                      system.hostBinding.item == system.item,
                      system.hostBinding.configurationKey == system.key.key,
                      system.hostBinding.codeIdentityVerified,
                      currentBinding.configurationKey == system.key.key,
                      currentBinding.codeIdentityVerified,
                      recordedHost.bundleIdentifier == system.item.hostBundleIdentifier,
                      currentHost.bundleIdentifier == recordedHost.bundleIdentifier,
                      currentHost.executableName == recordedHost.executableName,
                      currentHost.isSystem,
                      inventory.filter({
                          $0.bundleIdentifier == system.item.hostBundleIdentifier
                      }) == [currentHost] else {
                    throw OrderingTransactionError.recoveryIdentityConflict
                }
                if system.key.key.hasPrefix("status:") {
                    let token = String(
                        system.key.key.dropFirst("status:".count)
                            .components(separatedBy: "::")[0]
                    )
                    guard inventory.filter({
                        $0.bundleIdentifier == token || $0.executableName == token
                    }) == [currentHost] else {
                        throw OrderingTransactionError.recoveryIdentityConflict
                    }
                }
                continue
            case let .application(owner):
            let currentOwners = inventory.filter { $0.bundleIdentifier == owner.bundleIdentifier }
            if currentOwners.count == 1, let currentOwner = currentOwners.first {
                guard let observation = current.observationsByPID[currentOwner.pid] else {
                    throw OrderingTransactionError.recoveryIdentityConflict
                }
                if let identity = owner.exactBundleCodeIdentity {
                    guard owner.keys.contains(where: { target in
                        target.key.hasPrefix("status:\(owner.bundleIdentifier)::")
                    }), observation.applicationCodeIdentity == identity else {
                        throw OrderingTransactionError.recoveryIdentityConflict
                    }
                } else {
                    guard observation.ownerPreferencesComplete,
                          observation.ownerSavedPositions == owner.ownerSavedPositions,
                          observation.ownerPreferenceNamespace == owner.ownerPreferenceNamespace,
                          observation.ownerPreferenceSourceIdentity == owner.ownerPreferenceSourceIdentity else {
                        throw OrderingTransactionError.recoveryIdentityConflict
                    }
                }
            }
            for target in owner.keys {
                let token = String(target.key.dropFirst("status:".count).components(separatedBy: "::")[0])
                let matches = inventory.filter {
                    $0.bundleIdentifier == token || $0.executableName == token
                }
                guard matches.count <= 1, matches.allSatisfy({
                    $0.bundleIdentifier == owner.process.bundleIdentifier
                        && $0.executableName == owner.process.executableName
                        && (!$0.isSystem || ExperimentalAppleBundlePolicyCatalog.contains($0.bundleIdentifier))
                }) else { throw OrderingTransactionError.recoveryIdentityConflict }
            }
            }
        }
    }

    private func configurationBindings(
        _ receipt: OrderingRecoveryReceipt
    ) -> [OrderingConfigurationSubjectTarget]? {
        if let subjectBindings = receipt.subjectBindings { return subjectBindings }
        return receipt.ownerBindings?.map { .application($0) }
    }

    private func orderingRelativeVerified(
        _ plan: OrderingPlan, observed: OrderingSnapshot, phase: OrderingPhase
    ) -> Bool {
        guard observed.displaySignature == plan.baseline.displaySignature,
              observed.beforeProcesses == observed.afterProcesses,
              plan.targets.allSatisfy({ target in
                  guard let frame = observed.observationsByPID[target.process.pid]?.itemFrames.first else {
                      return false
                  }
                  return frame.width == target.frame.width && frame.height == target.frame.height
              }) else { return false }
        do { try plan.verifyRelativeOrder(in: observed, phase: phase); return true }
        catch { return false }
    }

    private func ownerPreferencesUnchanged(_ plan: OrderingPlan, observed: OrderingSnapshot) -> Bool {
        plan.targets.allSatisfy { target in
            guard let before = plan.baseline.observationsByPID[target.process.pid],
                  let after = observed.observationsByPID[target.process.pid] else { return false }
            return after.process == target.process && after.ownerPreferencesComplete
                && after.ownerSavedPositions == before.ownerSavedPositions
                && after.ownerPreferenceNamespace == before.ownerPreferenceNamespace
                && after.ownerPreferenceSourceIdentity == before.ownerPreferenceSourceIdentity
        }
    }

    private func validateRecoveryIdentity(_ plan: OrderingPlan, current: OrderingSnapshot) throws {
        try current.validate()
        for target in plan.targets {
            let token = String(target.key.dropFirst("status:".count).components(separatedBy: "::")[0])
            let inventory = (current.beforeProcesses + current.afterProcesses).reduce(
                into: [OrderingProcess]()
            ) { result, process in
                if !result.contains(process) { result.append(process) }
            }
            let matches = inventory.filter {
                $0.bundleIdentifier == token || $0.executableName == token
            }
            // An absent former owner does not make its stored key somebody else's.
            // A new/colliding owner or changed executable must never be overwritten.
            guard matches.count <= 1, matches.allSatisfy({
                $0.bundleIdentifier == target.process.bundleIdentifier
                    && $0.executableName == target.process.executableName && !$0.isSystem
            }) else { throw OrderingTransactionError.recoveryIdentityConflict }
        }
    }
}
#endif
