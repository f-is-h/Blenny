#if BLENNY_PRODUCT || DEBUG
import Foundation
import Testing
@testable import BlennyCore

@Suite("Board insertion transactions")
struct OrderingInsertionTransactionTests {
    @Test("Combined policy persistence failure restores numeric and accepted policy state")
    func combinedPolicyPersistenceFailure() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let initialPrepared = try preparedPolicyChange()
        let originalBackup = PersistentBundlePolicyBackup(previousPolicy: initialPrepared.oldPolicy)
        let prepared = try preparedPolicyChange(
            recoveryBackupFingerprint: originalBackup.backupFingerprint
        )
        let policyStore = MemoryPolicyStore(document: prepared.oldPolicy, backup: originalBackup)
        await policyStore.setFailure(.save)
        let writer = makeWriter(backend, recovery)
        let plan = try configurationPlan(fixture.baseline)

        await #expect(throws: MemoryPolicyStoreFailure.save) {
            _ = try await writer.applyConfigurationOrdering(
                plan, confirmedFingerprint: plan.fingerprint,
                policyChange: prepared, policyStore: policyStore
            )
        }
        #expect(await backend.current.group == fixture.baseline.group)
        #expect(await policyStore.document == prepared.oldPolicy)
        #expect(await policyStore.backup == originalBackup)
        #expect(await recovery.receipt?.isPendingRestoration == false)
        #expect(await recovery.receipt?.originalPolicy == nil)
    }

    @Test(
        "Final receipt failure rolls back unless the exact committed record is durable",
        arguments: [false, true]
    )
    func finalReceiptFailureRollsBackCombinedCommit(persistBeforeFailure: Bool) async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery(
            failingSaveNumbers: [2], persistBeforeFailure: persistBeforeFailure
        )
        let initialPrepared = try preparedPolicyChange()
        let originalBackup = PersistentBundlePolicyBackup(previousPolicy: initialPrepared.oldPolicy)
        let prepared = try preparedPolicyChange(
            recoveryBackupFingerprint: originalBackup.backupFingerprint
        )
        let policyStore = MemoryPolicyStore(document: prepared.oldPolicy, backup: originalBackup)
        let writer = makeWriter(backend, recovery)
        let plan = try configurationPlan(fixture.baseline)

        if persistBeforeFailure {
            _ = try await writer.applyConfigurationOrdering(
                plan, confirmedFingerprint: plan.fingerprint,
                policyChange: prepared, policyStore: policyStore)
            #expect(await policyStore.document == prepared.newPolicy)
            #expect(await recovery.receipt?.isPendingRestoration == false)
            #expect(await recovery.receipt?.undoPolicy?.before == prepared.oldPolicy)
            return
        }
        await #expect(throws: OrderingTransactionError.receiptStorageUnavailable) {
            _ = try await writer.applyConfigurationOrdering(
                plan, confirmedFingerprint: plan.fingerprint,
                policyChange: prepared, policyStore: policyStore
            )
        }
        #expect(await backend.current.group == fixture.baseline.group)
        #expect(await policyStore.document == prepared.oldPolicy)
        #expect(await policyStore.backup == originalBackup)
        #expect(await recovery.receipt?.isPendingRestoration == false)
        #expect(await recovery.receipt?.originalPolicy == nil)
    }

    @Test("Stop during intent persistence prevents the configuration write")
    func stopDuringIntent() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let barrier = ConfigurationTransactionBarrier()
        let recovery = InsertionTransactionRecovery(saveBarrier: barrier)
        let writer = makeWriter(backend, recovery)
        let plan = try configurationPlan(fixture.baseline)
        let apply = Task {
            try await writer.applyConfigurationOrdering(plan, confirmedFingerprint: plan.fingerprint)
        }
        await barrier.waitUntilEntered()
        let stop = Task { await writer.restoreAndStop() }
        await Task.yield()
        await barrier.release()

        await #expect(throws: OrderingTransactionError.contextInvalidated) { _ = try await apply.value }
        await stop.value
        #expect(await backend.writeCount == 0)
        #expect(await backend.current.group == fixture.baseline.group)
    }

    @Test("Stop during a configuration write rolls the write back before cleanup")
    func stopDuringWrite() async throws {
        let fixture = try InsertionTransactionFixture()
        let barrier = ConfigurationTransactionBarrier()
        let backend = InsertionTransactionBackend(fixture: fixture, writeBarrier: barrier)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        let plan = try configurationPlan(fixture.baseline)
        let apply = Task {
            try await writer.applyConfigurationOrdering(plan, confirmedFingerprint: plan.fingerprint)
        }
        await barrier.waitUntilEntered()
        let stop = Task { await writer.restoreAndStop() }
        await Task.yield()
        await barrier.release()

        await #expect(throws: OrderingTransactionError.contextInvalidated) { _ = try await apply.value }
        await stop.value
        #expect(await backend.current.group == fixture.baseline.group)
        #expect(await backend.writeCount == 2)
        #expect(await recovery.receipt?.isPendingRestoration == false)
    }

    @Test("A clean externally changed ledger requires review before starting a new Undo session")
    func reviewedExternalLedgerChange() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        let first = try configurationPlan(fixture.baseline)
        _ = try await writer.applyConfigurationOrdering(first, confirmedFingerprint: first.fingerprint)
        try await backend.changeTarget("status:com.example.owner0::item", to: .integer(777))
        let drifted = await backend.current
        let second = try OrderingPlan.makeConfigurationOrdering(
            snapshot: drifted,
            orderedBundleIdentifiers: [
                "com.example.owner1", "com.example.owner2", "com.example.owner0"
            ]
        )

        let retained = try #require(await recovery.receipt)
        let review = try #require(try retained.undoLedgerRebaseReview(in: drifted))
        #expect(review.changedKeys == ["status:com.example.owner0::item"])
        #expect(review.missingKeys.isEmpty)

        await #expect(throws: OrderingTransactionError.confirmationMismatch) {
            _ = try await writer.applyConfigurationOrdering(second, confirmedFingerprint: second.fingerprint)
        }
        #expect(await backend.writeCount == 1)
        #expect(await recovery.receipt?.committedValues == first.configurationAfterValues)

        let result = try await writer.applyConfigurationOrdering(
            second, confirmedFingerprint: second.fingerprint,
            confirmedUndoRebaseToken: review.token
        )
        #expect(result.revision == 1)
        #expect(await recovery.archivedReceipt == retained)
        #expect(await recovery.receipt?.sessionIdentifier != retained.sessionIdentifier)
    }

    @Test("Undo rebase review token survives receipt serialization")
    func undoRebaseTokenStableAcrossReceiptDecodes() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        let first = try configurationPlan(fixture.baseline)
        _ = try await writer.applyConfigurationOrdering(first, confirmedFingerprint: first.fingerprint)
        try await backend.changeTarget("status:com.example.owner0::item", to: .integer(777))
        let current = await backend.current
        let retained = try #require(await recovery.receipt)
        let data = try JSONEncoder().encode(retained)
        let expected = try #require(try retained.undoLedgerRebaseReview(in: current)).token
        for _ in 0..<100 {
            let decoded = try JSONDecoder().decode(OrderingRecoveryReceipt.self, from: data)
            #expect(try decoded.undoLedgerRebaseReview(in: current)?.token == expected)
        }
    }

    @Test("A rebase token refuses later drift anywhere in the retained ledger")
    func undoRebaseReviewBecomesStale() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        let first = try configurationPlan(fixture.baseline)
        _ = try await writer.applyConfigurationOrdering(first, confirmedFingerprint: first.fingerprint)
        try await backend.changeTarget("status:com.example.owner0::item", to: .integer(777))
        let firstDrift = await backend.current
        let retained = try #require(await recovery.receipt)
        let reviewed = try #require(try retained.undoLedgerRebaseReview(in: firstDrift))

        try await backend.changeTarget("status:com.example.owner1::item", to: .integer(778))
        let laterDrift = await backend.current
        let freshPlan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: laterDrift,
            orderedBundleIdentifiers: ["com.example.owner2", "com.example.owner0"]
        )
        await #expect(throws: OrderingTransactionError.confirmationMismatch) {
            _ = try await writer.applyConfigurationOrdering(
                freshPlan, confirmedFingerprint: freshPlan.fingerprint,
                confirmedUndoRebaseToken: reviewed.token
            )
        }
        #expect(await backend.writeCount == 1)
        #expect(await recovery.receipt == retained)
        #expect(await recovery.archivedReceipt == nil)
    }

    @Test("Undo after a reviewed rebase restores the fresh selected baseline and preserves external values")
    func rebasedUndoUsesCurrentSelectedBaseline() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        let first = try configurationPlan(fixture.baseline)
        _ = try await writer.applyConfigurationOrdering(first, confirmedFingerprint: first.fingerprint)
        try await backend.changeTarget("status:com.example.owner1::item", to: .integer(777))
        let externalBaseline = await backend.current
        let retained = try #require(await recovery.receipt)
        let review = try #require(try retained.undoLedgerRebaseReview(in: externalBaseline))
        let second = try OrderingPlan.makeConfigurationOrdering(
            snapshot: externalBaseline,
            orderedBundleIdentifiers: ["com.example.owner0", "com.example.owner2"]
        )

        _ = try await writer.applyConfigurationOrdering(
            second, confirmedFingerprint: second.fingerprint,
            confirmedUndoRebaseToken: review.token
        )
        let rebased = try #require(await recovery.receipt)
        #expect(Set(try #require(rebased.originalValues).keys) == Set([
            "status:com.example.owner0::item", "status:com.example.owner2::item",
        ]))
        _ = try await writer.restoreOrdering()
        let restored = try await backend.current.table()
        let expected = try externalBaseline.table()
        #expect(restored["status:com.example.owner0::item"] == expected["status:com.example.owner0::item"])
        #expect(restored["status:com.example.owner2::item"] == expected["status:com.example.owner2::item"])
        #expect(restored["status:com.example.owner1::item"] == .integer(777))
    }

    @Test("A missing dormant prior owner is relinquished by a reviewed new session")
    func missingDormantPriorOwnerCanRebase() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        let first = try configurationPlan(fixture.baseline)
        _ = try await writer.applyConfigurationOrdering(first, confirmedFingerprint: first.fingerprint)
        try await backend.removeOwner("com.example.owner1")
        let withoutOwner = await backend.current
        let retained = try #require(await recovery.receipt)
        let review = try #require(try retained.undoLedgerRebaseReview(in: withoutOwner))
        #expect(review.missingKeys == ["status:com.example.owner1::item"])
        let second = try OrderingPlan.makeConfigurationOrdering(
            snapshot: withoutOwner,
            orderedBundleIdentifiers: ["com.example.owner0", "com.example.owner2"]
        )

        _ = try await writer.applyConfigurationOrdering(
            second, confirmedFingerprint: second.fingerprint,
            confirmedUndoRebaseToken: review.token
        )
        #expect(await recovery.archivedReceipt == retained)
        #expect(await recovery.receipt?.originalValues?.keys.contains(
            "status:com.example.owner1::item"
        ) == false)
    }

    @Test("An unfinished receipt remains a recovery hard block")
    func pendingReceiptStillBlocksRebase() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        let first = try configurationPlan(fixture.baseline)
        _ = try await writer.applyConfigurationOrdering(first, confirmedFingerprint: first.fingerprint)
        var pending = try #require(await recovery.receipt)
        pending.phase = .applyIntent
        pending.pendingValues = pending.committedValues
        pending.configurationVerified = false
        try await recovery.replaceForTesting(pending)
        let current = await backend.current
        let second = try OrderingPlan.makeConfigurationOrdering(
            snapshot: current,
            orderedBundleIdentifiers: ["com.example.owner0", "com.example.owner2"]
        )

        await #expect(throws: OrderingTransactionError.recoveryRequired) {
            _ = try await writer.applyConfigurationOrdering(
                second, confirmedFingerprint: second.fingerprint,
                confirmedUndoRebaseToken: "untrusted"
            )
        }
        #expect(await backend.writeCount == 1)
        #expect(await recovery.archivedReceipt == nil)
    }

    @Test(
        "Supersede persistence failures preserve either the clean ledger or the recoverable intent",
        arguments: [SupersedeFailureMode.beforeReplacement, .afterReplacement]
    )
    func supersedePersistenceFailure(mode: SupersedeFailureMode) async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery(supersedeFailureMode: mode)
        let writer = makeWriter(backend, recovery)
        let first = try configurationPlan(fixture.baseline)
        _ = try await writer.applyConfigurationOrdering(first, confirmedFingerprint: first.fingerprint)
        let clean = try #require(await recovery.receipt)
        try await backend.changeTarget("status:com.example.owner0::item", to: .integer(777))
        let current = await backend.current
        let review = try #require(try clean.undoLedgerRebaseReview(in: current))
        let second = try OrderingPlan.makeConfigurationOrdering(
            snapshot: current,
            orderedBundleIdentifiers: ["com.example.owner0", "com.example.owner2"]
        )

        await #expect(throws: OrderingTransactionError.receiptStorageUnavailable) {
            _ = try await writer.applyConfigurationOrdering(
                second, confirmedFingerprint: second.fingerprint,
                confirmedUndoRebaseToken: review.token
            )
        }
        #expect(await backend.writeCount == 1)
        if mode == .beforeReplacement {
            #expect(await recovery.receipt == clean)
            #expect(await recovery.archivedReceipt == nil)
            #expect(await writer.hasPendingRestoration() == false)
        } else {
            #expect(await recovery.receipt?.isPendingRestoration == true)
            #expect(await recovery.archivedReceipt == clean)
            #expect(await writer.hasPendingRestoration() == true)
        }
    }

    @Test("A fresh configuration commit and Undo preserve unrelated preflight drift")
    func unrelatedPreflightDriftIsPreserved() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        let plan = try configurationPlan(fixture.baseline)
        try await backend.addExternalChange()
        try await backend.addUnrelatedTableChange()

        _ = try await writer.applyConfigurationOrdering(
            plan, confirmedFingerprint: plan.fingerprint
        )
        #expect(await backend.current.group["unrelated"] == .string("external"))
        #expect(try await backend.current.table()["status:Unrelated::item"] == .integer(77))

        _ = try await writer.restoreOrdering()
        #expect(await backend.current.group["unrelated"] == .string("external"))
        #expect(try await backend.current.table()["status:Unrelated::item"] == .integer(77))
    }

    @Test("Final write and Undo carry every reviewed owner, including unchanged slots")
    func unchangedReviewedOwnerRemainsInFinalScope() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        let plan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: fixture.baseline,
            orderedBundleIdentifiers: ["com.example.owner0", "com.example.owner2", "com.example.owner1"]
        )
        let before = try #require(plan.configurationBeforeValues)
        let after = try #require(plan.configurationAfterValues)
        #expect(before["status:com.example.owner0::item"] == after["status:com.example.owner0::item"])
        let completeScope = Set(before.keys)
        let missingUnchangedOwner = fixture.baseline.afterProcesses.filter {
            $0.bundleIdentifier != "com.example.owner0"
        }
        #expect(throws: OrderingError.self) {
            try fixture.baseline.validateConfigurationProcessScope(
                for: completeScope, against: missingUnchangedOwner
            )
        }
        _ = try await writer.applyConfigurationOrdering(plan, confirmedFingerprint: plan.fingerprint)
        #expect(await backend.configurationWriteScope == completeScope)
        _ = try await writer.restoreOrdering()
        #expect(await backend.configurationRestoreScope == completeScope)
    }

    @Test("Foreign accepted policy prevents a combined write before journaling")
    func foreignPolicyPreflight() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let prepared = try preparedPolicyChange()
        let foreign = try prepared.newPolicy.settingManagementEnabled(false)
        let policyStore = MemoryPolicyStore(document: foreign)
        let writer = makeWriter(backend, recovery)
        let plan = try configurationPlan(fixture.baseline)

        await #expect(throws: OrderingTransactionError.contextInvalidated) {
            _ = try await writer.applyConfigurationOrdering(
                plan, confirmedFingerprint: plan.fingerprint,
                policyChange: prepared, policyStore: policyStore
            )
        }
        #expect(await backend.writeCount == 0)
        #expect(await recovery.receipt == nil)
    }

    @Test("Foreign accepted policy during persistence retains the unfinished journal")
    func foreignPolicyDuringPersistence() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let prepared = try preparedPolicyChange()
        let foreign = try prepared.newPolicy.settingManagementEnabled(false)
        let policyStore = InsertionForeignPolicyStore(
            document: prepared.oldPolicy, foreign: foreign
        )
        let writer = makeWriter(backend, recovery)
        let plan = try configurationPlan(fixture.baseline)

        await #expect(throws: OrderingTransactionError.policyRecoveryRequired) {
            _ = try await writer.applyConfigurationOrdering(
                plan, confirmedFingerprint: plan.fingerprint,
                policyChange: prepared, policyStore: policyStore
            )
        }
        #expect(await policyStore.document == foreign)
        #expect(await backend.current.group != fixture.baseline.group)
        #expect(await recovery.receipt?.phase == .applyIntent)
        #expect(await recovery.receipt?.isPendingRestoration == true)
        #expect(await recovery.receipt?.originalPolicy == prepared.oldPolicy)
    }

    @Test("Changed recovery backup prevents a combined write before journaling")
    func recoveryBackupPreflight() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let initialPrepared = try preparedPolicyChange()
        let reviewedBackup = PersistentBundlePolicyBackup(
            previousPolicy: initialPrepared.oldPolicy
        )
        let prepared = try preparedPolicyChange(
            recoveryBackupFingerprint: reviewedBackup.backupFingerprint
        )
        let changedBackup = PersistentBundlePolicyBackup(previousPolicy: prepared.newPolicy)
        let policyStore = MemoryPolicyStore(
            document: prepared.oldPolicy, backup: changedBackup
        )
        let writer = makeWriter(backend, recovery)
        let plan = try configurationPlan(fixture.baseline)

        await #expect(throws: OrderingTransactionError.contextInvalidated) {
            _ = try await writer.applyConfigurationOrdering(
                plan, confirmedFingerprint: plan.fingerprint,
                policyChange: prepared, policyStore: policyStore
            )
        }
        #expect(await backend.writeCount == 0)
        #expect(await recovery.receipt == nil)
    }

    @Test("Real recovery store round-trips and expands a revision scope")
    func realRecoveryStoreRevisionRoundTrip() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("blenny-ordering-schema2-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let recovery = OrderingRecoveryStore(directory: directory)
        let writer = CoordinatedPolicyWriter(
            assertionWriter: InsertionAssertionWriter(),
            persistentWriter: InsertionPersistentWriter(),
            orderingBackend: backend, orderingRecovery: recovery
        )
        let first = try OrderingPlan.makeConfigurationOrdering(
            snapshot: fixture.baseline,
            orderedBundleIdentifiers: ["com.example.owner2", "com.example.owner0"]
        )
        _ = try await writer.applyConfigurationOrdering(first, confirmedFingerprint: first.fingerprint)
        let secondBaseline = await backend.current
        let second = try OrderingPlan.makeConfigurationOrdering(
            snapshot: secondBaseline,
            orderedBundleIdentifiers: [
                "com.example.owner1", "com.example.owner2", "com.example.owner0"
            ]
        )
        _ = try await writer.applyConfigurationOrdering(second, confirmedFingerprint: second.fingerprint)

        let loaded = try await OrderingRecoveryStore(directory: directory).load()
        #expect(loaded?.revision == 2)
        #expect(loaded?.originalValues?.count == 3)
        #expect(loaded?.ownerBindings?.count == 3)
        try loaded?.validate()
        _ = try await writer.restoreOrdering()
        #expect(await backend.current.group == secondBaseline.group)
        #expect(try await OrderingRecoveryStore(directory: directory).load() == nil)
    }

    @Test("Configuration commits do not require physical movement and survive Stop until explicit Undo")
    func configurationCommitSurvivesStop() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture, freezeGeometry: true)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        let plan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: fixture.baseline,
            orderedBundleIdentifiers: [
                "com.example.owner2", "com.example.owner0", "com.example.owner1"
            ]
        )

        let result = try await writer.applyConfigurationOrdering(
            plan, confirmedFingerprint: plan.fingerprint
        )
        #expect(result.configurationVerified)
        #expect(result.physicalVerificationStatus == .mismatch)
        #expect(await recovery.receipt?.schemaVersion == 2)
        #expect(await recovery.receipt?.hasConfigurationUndo == true)
        let applied = await backend.current.group

        await writer.restoreAndStop()
        #expect(await backend.current.group == applied)
        #expect(await writer.hasPendingRestoration() == false)

        let restored = try await writer.restoreOrdering()
        #expect(restored.preferencesRestored)
        #expect(await backend.current.group == fixture.baseline.group)
        #expect(await recovery.receipt == nil)
    }

    @Test("Exact bundle code identity supports configuration Apply and Undo without owner preferences")
    func exactBundleCodeIdentityApplyAndUndo() async throws {
        let fixture = try InsertionTransactionFixture(usesExactCodeIdentity: true)
        let backend = InsertionTransactionBackend(fixture: fixture, freezeGeometry: true)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        let plan = try configurationPlan(fixture.baseline)

        #expect(plan.configurationTargets?.allSatisfy {
            $0.exactBundleCodeIdentity != nil && $0.ownerSavedPositions.isEmpty
        } == true)
        _ = try await writer.applyConfigurationOrdering(
            plan, confirmedFingerprint: plan.fingerprint
        )
        #expect(await recovery.receipt?.configurationVerified == true)
        #expect(await recovery.receipt?.ownerBindings?.allSatisfy {
            $0.exactBundleCodeIdentity != nil
        } == true)

        let restored = try await writer.restoreOrdering()
        #expect(restored.preferencesRestored)
        #expect(await backend.current.group == fixture.baseline.group)
        #expect(await recovery.receipt == nil)
    }

    @Test("Exact bundle recovery refuses a changed code identity before writing")
    func exactBundleRecoveryRejectsCodeIdentityDrift() async throws {
        let fixture = try InsertionTransactionFixture(usesExactCodeIdentity: true)
        let backend = InsertionTransactionBackend(fixture: fixture, freezeGeometry: true)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        let plan = try configurationPlan(fixture.baseline)
        _ = try await writer.applyConfigurationOrdering(
            plan, confirmedFingerprint: plan.fingerprint
        )
        try await backend.changeCodeIdentityDigest(String(repeating: "b", count: 64))

        await #expect(throws: OrderingTransactionError.recoveryIdentityConflict) {
            _ = try await writer.restoreOrdering()
        }
        #expect(await backend.writeCount == 1)
        #expect(await recovery.receipt?.hasConfigurationUndo == true)
    }

    @Test("Undo reverses only the latest successful configuration commit")
    func repeatedConfigurationCommits() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        let first = try OrderingPlan.makeConfigurationOrdering(
            snapshot: fixture.baseline,
            orderedBundleIdentifiers: ["com.example.owner2", "com.example.owner0"]
        )
        _ = try await writer.applyConfigurationOrdering(
            first, confirmedFingerprint: first.fingerprint
        )
        let secondBaseline = await backend.current
        let second = try OrderingPlan.makeConfigurationOrdering(
            snapshot: secondBaseline,
            orderedBundleIdentifiers: [
                "com.example.owner1", "com.example.owner2", "com.example.owner0"
            ]
        )
        let result = try await writer.applyConfigurationOrdering(
            second, confirmedFingerprint: second.fingerprint
        )

        #expect(result.revision == 2)
        #expect(await recovery.receipt?.originalValues?.count == 3)
        #expect(await recovery.receipt?.ownerBindings?.count == 3)
        #expect(await recovery.receipt?.isPendingRestoration == false)
        _ = try await writer.restoreOrdering()
        #expect(await backend.current.group == secondBaseline.group)
    }

    @Test("Partial configuration failure performs one journaled rollback")
    func partialConfigurationFailure() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture, partialFailure: true)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        let plan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: fixture.baseline,
            orderedBundleIdentifiers: [
                "com.example.owner2", "com.example.owner0", "com.example.owner1"
            ]
        )

        await #expect(throws: OrderingTransactionError.receiptStorageUnavailable) {
            _ = try await writer.applyConfigurationOrdering(
                plan, confirmedFingerprint: plan.fingerprint
            )
        }
        #expect(await backend.current.group == fixture.baseline.group)
        #expect(await recovery.receipt?.phase == .applied)
        #expect(await recovery.receipt?.isPendingRestoration == false)
        #expect(await backend.writeCount == 2)
    }

    @Test("Interrupted revision rollback is inspected without undoing an earlier policy", arguments: [false, true])
    func interruptedRollbackInspection(hasEarlierPolicyUndo: Bool) async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let first = try OrderingPlan.makeConfigurationOrdering(
            snapshot: fixture.baseline,
            orderedBundleIdentifiers: [
                "com.example.owner2", "com.example.owner0", "com.example.owner1"
            ]
        )
        let firstGroup = try first.applying(to: fixture.baseline.group)
        let firstTable = try #require({
            if case let .dictionary(table)? = firstGroup[OrderingSnapshot.tableKey] { return table }
            return nil
        }())
        try await backend.writeConfigurationTable(
            firstTable, expecting: fixture.baseline,
            ownerKeys: Set(first.configurationBeforeValues!.keys)
        )
        let committedSnapshot = await backend.current
        let second = try OrderingPlan.makeConfigurationOrdering(
            snapshot: committedSnapshot,
            orderedBundleIdentifiers: [
                "com.example.owner1", "com.example.owner2", "com.example.owner0"
            ]
        )
        var receipt = OrderingRecoveryReceipt(
            configurationPlan: second,
            originalValues: try #require(first.configurationBeforeValues),
            committedValues: try #require(first.configurationAfterValues),
            pendingValues: try #require(first.configurationAfterValues)
        )
        receipt.phase = .restoreIntent
        if hasEarlierPolicyUndo {
            let earlierPolicy = try preparedPolicyChange()
            receipt.schemaVersion = 4
            receipt.undoPolicy = OrderingPolicyUndo(
                before: earlierPolicy.oldPolicy, after: earlierPolicy.newPolicy,
                backup: nil
            )
        }
        #expect(receipt.hasPendingRevisionRollback)
        try await recovery.save(receipt)
        let writer = makeWriter(backend, recovery)

        let result = try await writer.restoreOrdering()
        #expect(result.preferencesRestored)
        #expect(await backend.writeCount == 1)
        #expect(await recovery.receipt?.phase == .applied)
        #expect(await recovery.receipt?.hasConfigurationUndo == true)
        #expect(await recovery.receipt?.hasPendingRevisionRollback == false)
        #expect(await recovery.receipt?.originalPolicy == nil)
        #expect((await recovery.receipt?.undoPolicy != nil) == hasEarlierPolicyUndo)
    }

    @Test("A multi-owner insertion uses one write and one exact inverse")
    func insertionAndRestore() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        let observed = try await writer.applyOrdering(
            fixture.plan, confirmedFingerprint: fixture.plan.fingerprint
        )
        try fixture.plan.verifyRelativeOrder(in: observed, phase: .applied)
        #expect(await backend.writeCount == 1)
        #expect(await recovery.receipt?.phase == .applied)
        let restored = try await writer.restoreOrdering()
        #expect(restored.preferencesRestored && restored.relativeOrderVerified)
        #expect(await backend.current.group == fixture.baseline.group)
        #expect(await backend.writeCount == 2)
        #expect(await recovery.receipt == nil)
    }

    @Test("Partial insertion failure restores all affected owners with one inverse")
    func partialFailure() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture, partialFailure: true)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        await #expect(throws: OrderingTransactionError.receiptStorageUnavailable) {
            _ = try await writer.applyOrdering(
                fixture.plan, confirmedFingerprint: fixture.plan.fingerprint
            )
        }
        #expect(await backend.current.group == fixture.baseline.group)
        #expect(await backend.writeCount == 2)
        #expect(await recovery.receipt == nil)
    }

    @Test("Unverified insertion rolls back instead of displaying a successful board order")
    func failedGeometry() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture, freezeGeometry: true)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        await #expect(throws: OrderingTransactionError.movementNotVerified) {
            _ = try await writer.applyOrdering(
                fixture.plan, confirmedFingerprint: fixture.plan.fingerprint
            )
        }
        #expect(await backend.current.group == fixture.baseline.group)
        #expect(await backend.writeCount == 2)
        #expect(await recovery.receipt == nil)
    }

    @Test("Insertion recovery preserves external changes outside its owner scope")
    func externalChanges() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let writer = makeWriter(backend, recovery)
        _ = try await writer.applyOrdering(
            fixture.plan, confirmedFingerprint: fixture.plan.fingerprint
        )
        try await backend.addExternalChange()
        let restored = try await writer.restoreOrdering()
        #expect(restored.relativeOrderVerified)
        #expect(await backend.current.group["unrelated"] == .string("external"))
        #expect(try await backend.current.table() == fixture.baseline.table())
        #expect(await backend.writeCount == 2)
    }

    private func makeWriter(
        _ backend: InsertionTransactionBackend, _ recovery: InsertionTransactionRecovery
    ) -> CoordinatedPolicyWriter {
        CoordinatedPolicyWriter(
            assertionWriter: InsertionAssertionWriter(),
            persistentWriter: InsertionPersistentWriter(),
            orderingBackend: backend, orderingRecovery: recovery
        )
    }

    @Test("Unified Undo restores visibility and order, including a policy-only Apply", arguments: [false, true], [false, true])
    func unifiedUndo(policyOnly: Bool, siri: Bool) async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("unified-undo-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let recovery = OrderingRecoveryStore(directory: directory)
        let forward = try preparedPolicyChange(siri: siri)
        let store = MemoryPolicyStore(document: forward.oldPolicy)
        let writer = CoordinatedPolicyWriter(assertionWriter: InsertionAssertionWriter(),
            persistentWriter: InsertionPersistentWriter(), orderingBackend: backend,
            orderingRecovery: recovery)
        let plan = policyOnly
            ? try OrderingPlan.makeConfigurationOrdering(snapshot: fixture.baseline, orderedSubjects: [])
            : try configurationPlan(fixture.baseline)
        _ = try await writer.applyConfigurationOrdering(plan, confirmedFingerprint: plan.fingerprint,
            policyChange: forward, policyStore: store)
        #expect(try await recovery.load()?.hasConfigurationUndo == true)
        #expect(try await recovery.load()?.isPendingRestoration == false)
        #expect(await store.document == forward.newPolicy)
        let inverse = try preparedPolicyChange(inverse: true, siri: siri)
        _ = try await writer.restoreOrdering(policyStore: store, policyUndo: inverse)
        #expect(await store.document == forward.oldPolicy)
        #expect(await backend.current.group == fixture.baseline.group)
        #expect(try await recovery.load() == nil)
        #expect(await writer.activePlanSnapshot() == inverse.report.newBaselinePlan)
    }

    @Test("Unified Undo after Stop restores policy and order without resuming management")
    func unifiedUndoAfterStop() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let forward = try preparedPolicyChange()
        let store = MemoryPolicyStore(document: forward.oldPolicy)
        let writer = CoordinatedPolicyWriter(
            assertionWriter: InsertionAssertionWriter(),
            persistentWriter: InsertionPersistentWriter(),
            orderingBackend: backend,
            orderingRecovery: recovery
        )
        let plan = try configurationPlan(fixture.baseline)

        _ = try await writer.applyConfigurationOrdering(
            plan, confirmedFingerprint: plan.fingerprint,
            policyChange: forward, policyStore: store
        )
        await writer.restoreAndStop()
        let stoppedAfter = try forward.newPolicy.settingManagementEnabled(false)
        try await store.save(stoppedAfter)
        let inverse = try preparedPolicyChange(
            inverse: true, inverseManagementEnabled: false
        )
        let stoppedBefore = try forward.oldPolicy.settingManagementEnabled(false)

        _ = try await writer.restoreOrdering(policyStore: store, policyUndo: inverse)

        #expect(await store.document == stoppedBefore)
        #expect(await backend.current.group == fixture.baseline.group)
        #expect(await recovery.receipt == nil)
        #expect(await writer.activePlanSnapshot() == nil)
    }

    @Test("Unified Undo after reopening while stopped uses an inactive recovery writer")
    func unifiedUndoAfterStoppedReopen() async throws {
        let fixture = try InsertionTransactionFixture()
        let backend = InsertionTransactionBackend(fixture: fixture)
        let recovery = InsertionTransactionRecovery()
        let forward = try preparedPolicyChange()
        let store = MemoryPolicyStore(document: forward.oldPolicy)
        let applyingWriter = CoordinatedPolicyWriter(
            assertionWriter: InsertionAssertionWriter(),
            persistentWriter: InsertionPersistentWriter(),
            orderingBackend: backend,
            orderingRecovery: recovery
        )
        let plan = try configurationPlan(fixture.baseline)

        _ = try await applyingWriter.applyConfigurationOrdering(
            plan, confirmedFingerprint: plan.fingerprint,
            policyChange: forward, policyStore: store
        )
        await applyingWriter.restoreAndStop()
        let stoppedAfter = try forward.newPolicy.settingManagementEnabled(false)
        try await store.save(stoppedAfter)

        // A reopened app creates a new coordinator. It has no active plan, but
        // it has not received the old process's restoreAndStop() call.
        let recoveryWriter = CoordinatedPolicyWriter(
            assertionWriter: InsertionAssertionWriter(),
            persistentWriter: InsertionPersistentWriter(),
            orderingBackend: backend,
            orderingRecovery: recovery
        )
        let inverse = try preparedPolicyChange(
            inverse: true, inverseManagementEnabled: false
        )
        let stoppedBefore = try forward.oldPolicy.settingManagementEnabled(false)

        _ = try await recoveryWriter.restoreOrdering(
            policyStore: store, policyUndo: inverse
        )

        #expect(await store.document == stoppedBefore)
        #expect(await backend.current.group == fixture.baseline.group)
        #expect(await recovery.load() == nil)
        #expect(await recoveryWriter.activePlanSnapshot() == nil)
    }

    private func configurationPlan(_ snapshot: OrderingSnapshot) throws -> OrderingPlan {
        try OrderingPlan.makeConfigurationOrdering(
            snapshot: snapshot,
            orderedBundleIdentifiers: [
                "com.example.owner2", "com.example.owner0", "com.example.owner1"
            ]
        )
    }

    private func preparedPolicyChange(
        recoveryBackupFingerprint: String? = nil, inverse: Bool = false,
        siri: Bool = false, inverseManagementEnabled: Bool = true
    ) throws -> PreparedPolicyEdit {
        let blenny = "xyz.fi5h.blenny"
        let owners = (0..<3).map { "com.example.owner\($0)" }
        let old = try PersistentBundlePolicyDocument(
            managementEnabled: true,
            policies: [
                .init(bundleIdentifier: blenny, policy: .visible),
                .init(bundleIdentifier: owners[0], policy: .visible),
                .init(bundleIdentifier: owners[1], policy: .revealable),
                .init(bundleIdentifier: owners[2], policy: .hidden),
            ]
        )
        let inventory = PolicyCandidateInventory(observations: [
            .init(bundleIdentifier: blenny, processIdentifier: 10, menuBarItemCount: 1),
            .init(bundleIdentifier: owners[0], processIdentifier: 100, menuBarItemCount: 1),
            .init(bundleIdentifier: owners[1], processIdentifier: 101, menuBarItemCount: 1),
            .init(bundleIdentifier: owners[2], processIdentifier: 102, menuBarItemCount: 1),
        ])
        let prepared = try PolicyDryRunner.prepare(
            oldPolicy: old,
            draft: BundlePolicyDraft(
                visible: [blenny, owners[2]],
                revealable: [owners[1]],
                hidden: [owners[0]],
                systemItemPolicies: siri ? [ExactSystemOrderingItem.siri.observationIdentifier: .revealable] : [:]
            ),
            managementEnabled: true,
            candidates: inventory,
            observedRunningBundleIdentifiers: Set([blenny] + owners),
            scope: PolicyValidationScope(approvedBundleIdentifiers: [blenny] + owners),
            blennyBundleIdentifier: blenny,
            recoveryBackupFingerprint: recoveryBackupFingerprint
        )
        let forward = try #require(prepared.prepared)
        guard inverse else { return forward }
        let inverseOld = try forward.newPolicy.settingManagementEnabled(
            inverseManagementEnabled
        )
        let inverseTarget = try old.settingManagementEnabled(
            inverseManagementEnabled
        )
        return try #require(PolicyDryRunner.prepare(
            oldPolicy: inverseOld,
            draft: BundlePolicyDraft(acceptedPolicy: inverseTarget),
            managementEnabled: inverseManagementEnabled, candidates: inventory,
            observedRunningBundleIdentifiers: Set([blenny] + owners),
            scope: PolicyValidationScope(approvedBundleIdentifiers: [blenny] + owners),
            blennyBundleIdentifier: blenny,
            recoveryBackupFingerprint: recoveryBackupFingerprint
        ).prepared)
    }
}

private struct InsertionTransactionFixture: Sendable {
    let baseline: OrderingSnapshot
    let plan: OrderingPlan

    init(usesExactCodeIdentity: Bool = false) throws {
        let now = Date()
        let processes = (0..<3).map { index in
            OrderingProcess(
                bundleIdentifier: "com.example.owner\(index)", executableName: "Owner\(index)",
                pid: Int32(100 + index), launchTime: now.addingTimeInterval(-30), isSystem: false
            )
        }
        var table: [String: OrderingValue] = [:]
        var observations: [Int32: OrderingOwnerObservation] = [:]
        for (index, process) in processes.enumerated() {
            let value = OrderingValue.integer(Int64(1_000 - index * 200))
            table["status:\(process.bundleIdentifier!)::item"] = value
            observations[process.pid] = OrderingOwnerObservation(
                process: process, displayName: "Owner\(index)",
                axComplete: true,
                itemFrames: [RectSnapshot(x: Double(30 + index * 50), y: 0, width: 20, height: 22)],
                ownerPreferencesComplete: !usesExactCodeIdentity,
                ownerSavedPositions: usesExactCodeIdentity ? [:] : ["item": value],
                ownerPreferenceNamespace: usesExactCodeIdentity ? .unknown : .currentUserAnyHost,
                applicationCodeIdentity: usesExactCodeIdentity ? OrderingApplicationCodeIdentity(
                    signingIdentifier: process.bundleIdentifier!, teamIdentifier: "TEAM123456",
                    designatedRequirementDigest: String(repeating: "a", count: 64)
                ) : nil
            )
        }
        baseline = try OrderingSnapshot(
            group: [OrderingSnapshot.tableKey: .dictionary(table)],
            beforeProcesses: processes, afterProcesses: processes, observationsByPID: observations,
            osBuild: OrderingSnapshot.supportedBuild, architecture: OrderingSnapshot.supportedArchitecture,
            runtimeContractVerified: true, displaySignature: "insertion-display", displayCount: 1,
            displayFrame: RectSnapshot(x: 0, y: 0, width: 1_000, height: 24),
            lifecycleGeneration: 1, policyFingerprint: "insertion-policy",
            orderingAllowedBundleIdentifiers: Set(processes.compactMap(\.bundleIdentifier)), capturedAt: now
        )
        let order = [processes[2], processes[0], processes[1]].compactMap(\.bundleIdentifier)
        plan = usesExactCodeIdentity
            ? try OrderingPlan.makeConfigurationOrdering(
                snapshot: baseline, orderedBundleIdentifiers: order
            )
            : try OrderingPlan.makeReordering(
                snapshot: baseline, orderedBundleIdentifiers: order
            )
    }

    func snapshot(
        group: [String: OrderingValue], freezeGeometry: Bool = false,
        excludingBundleIdentifiers excluded: Set<String> = [],
        codeIdentityDigest: String? = nil
    ) throws -> OrderingSnapshot {
        guard case let .dictionary(table)? = group[OrderingSnapshot.tableKey] else {
            throw OrderingTransactionError.invalidReceipt
        }
        let processes = baseline.afterProcesses.filter {
            guard let bundleIdentifier = $0.bundleIdentifier else { return true }
            return !excluded.contains(bundleIdentifier)
        }
        var observations = baseline.observationsByPID.filter {
            guard let bundleIdentifier = $0.value.process.bundleIdentifier else { return true }
            return !excluded.contains(bundleIdentifier)
        }
        for (pid, original) in observations {
            let key = "status:\(original.process.bundleIdentifier!)::item"
            let value = table[key]
            let slot = baseline.observationsByPID.values.first { $0.ownerSavedPositions["item"] == value }
            observations[pid] = OrderingOwnerObservation(
                process: original.process, displayName: original.displayName, axComplete: true,
                itemFrames: freezeGeometry ? original.itemFrames : (slot?.itemFrames ?? original.itemFrames),
                ownerPreferencesComplete: original.ownerPreferencesComplete,
                ownerSavedPositions: original.ownerSavedPositions,
                ownerPreferenceNamespace: original.ownerPreferenceNamespace,
                ownerPreferenceSourceIdentity: original.ownerPreferenceSourceIdentity,
                applicationCodeIdentity: original.applicationCodeIdentity.map { identity in
                    OrderingApplicationCodeIdentity(
                        signingIdentifier: identity.signingIdentifier,
                        teamIdentifier: identity.teamIdentifier,
                        designatedRequirementDigest: codeIdentityDigest
                            ?? identity.designatedRequirementDigest
                    )
                }
            )
        }
        return try OrderingSnapshot(
            group: group, beforeProcesses: processes, afterProcesses: processes,
            observationsByPID: observations, osBuild: baseline.osBuild, architecture: baseline.architecture,
            runtimeContractVerified: true, displaySignature: baseline.displaySignature, displayCount: 1,
            displayFrame: baseline.displayFrame, lifecycleGeneration: 1, policyFingerprint: baseline.policyFingerprint,
            orderingAllowedBundleIdentifiers: baseline.orderingAllowedBundleIdentifiers, capturedAt: baseline.capturedAt
        )
    }
}

private actor InsertionTransactionBackend: MenuBarOrderingBackend {
    let fixture: InsertionTransactionFixture
    var current: OrderingSnapshot
    var writeCount = 0
    var configurationWriteScope: Set<String>?
    var configurationRestoreScope: Set<String>?
    var partialFailure: Bool
    let freezeGeometry: Bool
    var writeBarrier: ConfigurationTransactionBarrier?
    var excludedBundleIdentifiers: Set<String> = []

    init(
        fixture: InsertionTransactionFixture, partialFailure: Bool = false,
        freezeGeometry: Bool = false,
        writeBarrier: ConfigurationTransactionBarrier? = nil
    ) {
        self.fixture = fixture
        current = fixture.baseline
        self.partialFailure = partialFailure
        self.freezeGeometry = freezeGeometry
        self.writeBarrier = writeBarrier
    }

    func capture() -> OrderingSnapshot { current }
    func writeConfigurationTable(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot,
        ownerKeys: Set<String>
    ) async throws {
        try snapshot.validateConfigurationProcessScope(for: ownerKeys, against: current.afterProcesses)
        configurationWriteScope = ownerKeys
        try await writeTable(table, expecting: snapshot)
    }
    func restoreConfigurationTable(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot,
        ownerKeys: Set<String>
    ) async throws {
        try snapshot.validateConfigurationProcessScope(for: ownerKeys, against: current.afterProcesses)
        configurationRestoreScope = ownerKeys
        try await writeTable(table, expecting: snapshot)
    }
    func writeTable(_ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot) async throws {
        #expect(snapshot == current)
        writeCount += 1
        if let writeBarrier {
            self.writeBarrier = nil
            await writeBarrier.enter()
        }
        var group = current.group
        if partialFailure {
            partialFailure = false
            var partial = try current.table()
            let changed = try #require(table.keys.sorted().first { partial[$0] != table[$0] })
            partial[changed] = table[changed]
            group[OrderingSnapshot.tableKey] = .dictionary(partial)
            current = try fixture.snapshot(
                group: group, excludingBundleIdentifiers: excludedBundleIdentifiers
            )
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        group[OrderingSnapshot.tableKey] = .dictionary(table)
        current = try fixture.snapshot(
            group: group, freezeGeometry: freezeGeometry,
            excludingBundleIdentifiers: excludedBundleIdentifiers
        )
    }

    func addExternalChange() throws {
        var group = current.group
        group["unrelated"] = .string("external")
        current = try fixture.snapshot(
            group: group, excludingBundleIdentifiers: excludedBundleIdentifiers
        )
    }

    func addUnrelatedTableChange() throws {
        var group = current.group
        var table = try current.table()
        table["status:Unrelated::item"] = .integer(77)
        group[OrderingSnapshot.tableKey] = .dictionary(table)
        current = try fixture.snapshot(
            group: group, excludingBundleIdentifiers: excludedBundleIdentifiers
        )
    }

    func changeTarget(_ key: String, to value: OrderingValue) throws {
        var group = current.group
        var table = try current.table()
        table[key] = value
        group[OrderingSnapshot.tableKey] = .dictionary(table)
        current = try fixture.snapshot(
            group: group, excludingBundleIdentifiers: excludedBundleIdentifiers
        )
    }

    func changeCodeIdentityDigest(_ digest: String) throws {
        current = try fixture.snapshot(
            group: current.group,
            excludingBundleIdentifiers: excludedBundleIdentifiers,
            codeIdentityDigest: digest
        )
    }

    func removeOwner(_ bundleIdentifier: String) throws {
        excludedBundleIdentifiers.insert(bundleIdentifier)
        var group = current.group
        var table = try current.table()
        table.removeValue(forKey: "status:\(bundleIdentifier)::item")
        group[OrderingSnapshot.tableKey] = .dictionary(table)
        current = try fixture.snapshot(
            group: group, excludingBundleIdentifiers: excludedBundleIdentifiers
        )
    }
}

enum SupersedeFailureMode: Equatable, Sendable {
    case beforeReplacement
    case afterReplacement
}

private actor InsertionTransactionRecovery: OrderingRecoveryStoring {
    var receipt: OrderingRecoveryReceipt?
    var archivedReceipt: OrderingRecoveryReceipt?
    private var saveCount = 0
    private let failingSaveNumbers: Set<Int>
    private let persistBeforeFailure: Bool
    private let supersedeFailureMode: SupersedeFailureMode?
    private var saveBarrier: ConfigurationTransactionBarrier?

    init(
        failingSaveNumbers: Set<Int> = [],
        persistBeforeFailure: Bool = false,
        saveBarrier: ConfigurationTransactionBarrier? = nil,
        supersedeFailureMode: SupersedeFailureMode? = nil
    ) {
        self.failingSaveNumbers = failingSaveNumbers
        self.persistBeforeFailure = persistBeforeFailure
        self.saveBarrier = saveBarrier
        self.supersedeFailureMode = supersedeFailureMode
    }

    func acquireLease() {}
    func releaseLease() {}
    func load() -> OrderingRecoveryReceipt? { receipt }
    func save(_ value: OrderingRecoveryReceipt) async throws {
        saveCount += 1
        if let saveBarrier {
            self.saveBarrier = nil
            await saveBarrier.enter()
        }
        if failingSaveNumbers.contains(saveCount) {
            if persistBeforeFailure {
                try value.validate()
                receipt = value
            }
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        try value.validate()
        receipt = value
    }
    func supersedeClean(
        _ existing: OrderingRecoveryReceipt,
        with replacement: OrderingRecoveryReceipt
    ) async throws {
        guard receipt == existing, !existing.isPendingRestoration else {
            throw OrderingTransactionError.recoveryRequired
        }
        if supersedeFailureMode == .beforeReplacement {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        try replacement.validate()
        archivedReceipt = existing
        receipt = replacement
        if supersedeFailureMode == .afterReplacement {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
    }
    func replaceForTesting(_ value: OrderingRecoveryReceipt) throws {
        try value.validate()
        receipt = value
    }
    func complete(_ value: OrderingRecoveryReceipt) throws {
        #expect(value.phase == .preferencesRestored)
        receipt = nil
    }
}

private actor InsertionAssertionWriter: PolicyAssertionWriting {
    private var active: RevealAllowlistPlan?
    func applySessionTransition(with plan: RevealAllowlistPlan) { active = plan }
    func restoreAndStop() { active = nil }
    func connectionInvalidated() { active = nil }
    func activePlanSnapshot() -> RevealAllowlistPlan? { active }
}

private actor InsertionPersistentWriter: PersistentSystemItemPlanWriting {
    func applyManagedPlan(_ plan: [String: PersistentSystemItemPresentation]) {}
    func verifyManagedPlan(_ plan: [String: PersistentSystemItemPresentation]) -> Bool { true }
    func finalizeCommittedPlan(_ plan: [String: PersistentSystemItemPresentation]) {}
    func restoreAllManagedItems() -> Bool { true }
}

private actor ConfigurationTransactionBarrier {
    private var entered = false
    private var enteredWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func enter() async {
        entered = true
        enteredWaiter?.resume()
        enteredWaiter = nil
        await withCheckedContinuation { releaseWaiter = $0 }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { enteredWaiter = $0 }
    }

    func release() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

private actor InsertionForeignPolicyStore: PersistentBundlePolicyStoring {
    private(set) var document: PersistentBundlePolicyDocument
    private let foreign: PersistentBundlePolicyDocument

    init(
        document: PersistentBundlePolicyDocument,
        foreign: PersistentBundlePolicyDocument
    ) {
        self.document = document
        self.foreign = foreign
    }

    func load() -> PersistentBundlePolicyDocument? { document }
    func loadBackup() -> PersistentBundlePolicyBackup? { nil }

    func save(_ document: PersistentBundlePolicyDocument) throws {
        self.document = foreign
        throw MemoryPolicyStoreFailure.save
    }

    func restoreBackup() -> PersistentBundlePolicyDocument? { nil }
}
#endif
