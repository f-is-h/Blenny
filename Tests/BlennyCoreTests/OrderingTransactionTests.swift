#if BLENNY_PRODUCT || DEBUG
import Foundation
import Testing

@testable import BlennyCore

@Suite("Debug ordering transactions")
struct OrderingTransactionTests {
    @Test("A reviewed exchange verifies and restores its original relative order")
    func verifiedExchangeAndRestore() async throws {
        let fixture = try OrderingFixture()
        let backend = MemoryOrderingBackend(snapshot: fixture.baseline)
        let recovery = MemoryOrderingRecovery()
        let writer = coordinator(backend: backend, recovery: recovery)

        let observed = try await writer.applyOrdering(
            fixture.plan, confirmedFingerprint: fixture.plan.fingerprint
        )
        #expect(observed.group == fixture.proposed.group)
        try fixture.plan.verifyRelativeOrder(in: observed, phase: .applied)
        #expect(await recovery.receipt()?.phase == .applied)

        let restored = try await writer.restoreOrdering()
        #expect(restored == OrderingRestoreResult(
            preferencesRestored: true, relativeOrderVerified: true
        ))
        #expect(await backend.snapshot() == fixture.baseline)
        #expect(await recovery.receipt() == nil)
        #expect(await recovery.completed().count == 1)
    }

    @Test("Wrong confirmation and stale group fail before a journal or backend write")
    func confirmationAndStalenessFailBeforeWrite() async throws {
        let fixture = try OrderingFixture()
        let wrongBackend = MemoryOrderingBackend(snapshot: fixture.baseline)
        let wrongRecovery = MemoryOrderingRecovery()
        let wrongWriter = coordinator(backend: wrongBackend, recovery: wrongRecovery)

        await expectError(.confirmationMismatch) {
            _ = try await wrongWriter.applyOrdering(fixture.plan, confirmedFingerprint: "wrong")
        }
        #expect(await wrongBackend.writeCount() == 0)
        #expect(await wrongRecovery.saveCount() == 0)

        let stale = try fixture.snapshot(
            table: fixture.baselineTable.merging([fixture.alphaKey: .integer(999)]) { _, new in new }
        )
        let staleBackend = MemoryOrderingBackend(snapshot: stale)
        let staleRecovery = MemoryOrderingRecovery()
        let staleWriter = coordinator(backend: staleBackend, recovery: staleRecovery)
        await expectOrderingError {
            _ = try await staleWriter.applyOrdering(
                fixture.plan, confirmedFingerprint: fixture.plan.fingerprint
            )
        }
        #expect(await staleBackend.writeCount() == 0)
        #expect(await staleRecovery.saveCount() == 0)
    }

    @Test("A journal failure prevents every ordering write")
    func journalFailurePreventsWrite() async throws {
        let fixture = try OrderingFixture()
        let backend = MemoryOrderingBackend(snapshot: fixture.baseline)
        let recovery = MemoryOrderingRecovery()
        await recovery.failNextSave()
        let writer = coordinator(backend: backend, recovery: recovery)

        await expectError(.receiptStorageUnavailable) {
            _ = try await writer.applyOrdering(
                fixture.plan, confirmedFingerprint: fixture.plan.fingerprint
            )
        }
        #expect(await backend.writeCount() == 0)
        #expect(await recovery.receipt() == nil)
    }

    @Test("A partial apply failure performs one bounded inverse")
    func partialApplyRollsBack() async throws {
        let fixture = try OrderingFixture()
        let backend = MemoryOrderingBackend(snapshot: fixture.baseline)
        await backend.failNextWrite(afterMutation: true)
        let recovery = MemoryOrderingRecovery()
        let writer = coordinator(backend: backend, recovery: recovery)

        await expectError(.receiptStorageUnavailable) {
            _ = try await writer.applyOrdering(
                fixture.plan, confirmedFingerprint: fixture.plan.fingerprint
            )
        }
        #expect(await backend.snapshot() == fixture.baseline)
        #expect(await backend.writeCount() == 2)
        #expect(await recovery.receipt() == nil)
    }

    @Test("A failed relative-order observation rolls target values back")
    func failedRelativeVerificationRollsBack() async throws {
        let fixture = try OrderingFixture()
        let backend = MemoryOrderingBackend(snapshot: fixture.baseline)
        await backend.leaveAppliedGeometryUnchanged()
        let recovery = MemoryOrderingRecovery()
        let writer = coordinator(backend: backend, recovery: recovery)

        await expectError(.movementNotVerified) {
            _ = try await writer.applyOrdering(
                fixture.plan, confirmedFingerprint: fixture.plan.fingerprint
            )
        }
        #expect(await backend.snapshot() == fixture.baseline)
        #expect(await backend.writeCount() == 2)
    }

    @Test("Restore changes only target values and preserves unrelated drift")
    func restorationPreservesUnrelatedDrift() async throws {
        let fixture = try OrderingFixture()
        let backend = MemoryOrderingBackend(snapshot: fixture.baseline)
        let recovery = MemoryOrderingRecovery()
        let writer = coordinator(backend: backend, recovery: recovery)
        _ = try await writer.applyOrdering(fixture.plan, confirmedFingerprint: fixture.plan.fingerprint)

        var drifted = fixture.proposed.group
        drifted["UnrelatedPreference"] = .string("preserve")
        await backend.replaceCurrent(try fixture.snapshot(group: drifted, swapped: true))
        _ = try await writer.restoreOrdering()

        let restored = await backend.snapshot()
        #expect(restored.group["UnrelatedPreference"] == .string("preserve"))
        #expect(try restored.table()[fixture.alphaKey] == fixture.baselineTable[fixture.alphaKey])
        #expect(try restored.table()[fixture.betaKey] == fixture.baselineTable[fixture.betaKey])
    }

    @Test("Restore refuses target drift without a second inverse")
    func restorationRefusesTargetDrift() async throws {
        let fixture = try OrderingFixture()
        let backend = MemoryOrderingBackend(snapshot: fixture.baseline)
        let recovery = MemoryOrderingRecovery()
        let writer = coordinator(backend: backend, recovery: recovery)
        _ = try await writer.applyOrdering(fixture.plan, confirmedFingerprint: fixture.plan.fingerprint)

        await backend.replaceCurrent(try fixture.snapshot(
            table: fixture.proposedTable.merging([fixture.alphaKey: .integer(777)]) { _, new in new },
            swapped: true
        ))
        await expectOrderingError { _ = try await writer.restoreOrdering() }
        #expect(await backend.writeCount() == 1)
        #expect(await recovery.receipt()?.phase == .applied)
    }

    @Test("An inverse write error still succeeds when the following read confirms restoration")
    func readConfirmedInverseAfterWriteErrorSucceeds() async throws {
        let fixture = try OrderingFixture()
        let backend = MemoryOrderingBackend(snapshot: fixture.proposed)
        await backend.failNextWrite(afterMutation: true)
        let recovery = MemoryOrderingRecovery(receipt: OrderingRecoveryReceipt(
            plan: fixture.plan, phase: .applied
        ))
        let writer = coordinator(backend: backend, recovery: recovery)

        let result = try await writer.restoreOrdering()
        #expect(result.relativeOrderVerified)
        #expect(await backend.snapshot() == fixture.baseline)
        #expect(await backend.writeCount() == 1)
        #expect(await recovery.receipt() == nil)
    }

    @Test("A failed inverse is marked once and a later restore does not retry it")
    func failedInverseIsNeverRetried() async throws {
        let fixture = try OrderingFixture()
        let backend = MemoryOrderingBackend(snapshot: fixture.proposed)
        await backend.failNextWrite(afterMutation: false)
        let recovery = MemoryOrderingRecovery(receipt: OrderingRecoveryReceipt(
            plan: fixture.plan, phase: .applied
        ))
        let writer = coordinator(backend: backend, recovery: recovery)

        await expectError(.restorationAlreadyAttempted) { _ = try await writer.restoreOrdering() }
        #expect(await backend.writeCount() == 1)
        #expect(await recovery.receipt()?.phase == .restoreIntent)

        await expectError(.restorationAlreadyAttempted) { _ = try await writer.restoreOrdering() }
        #expect(await backend.writeCount() == 1)
        #expect(await recovery.receipt()?.phase == .restoreIntent)
    }

    @Test("Concurrent Stop or invalidation leaves no applied ordering state", arguments: [false, true])
    func lifecycleRaceLeavesNoAppliedState(connectionInvalidated: Bool) async throws {
        let fixture = try OrderingFixture()
        let barrier = WriteBarrier()
        let backend = MemoryOrderingBackend(snapshot: fixture.baseline)
        await backend.suspendNextWrite(on: barrier)
        let recovery = MemoryOrderingRecovery()
        let writer = coordinator(backend: backend, recovery: recovery)
        let apply = Task {
            do {
                let observed = try await writer.applyOrdering(
                    fixture.plan, confirmedFingerprint: fixture.plan.fingerprint
                )
                await barrier.applyFinishedWithoutEntry()
                return observed
            } catch {
                await barrier.applyFinishedWithoutEntry()
                throw error
            }
        }
        guard await barrier.waitUntilEntered() else {
            do { _ = try await apply.value; Issue.record("Ordering ended before its write barrier.") }
            catch { Issue.record("Ordering failed before its write barrier: \(error)") }
            return
        }
        let cleanup = Task {
            if connectionInvalidated { await writer.connectionInvalidated() }
            else { await writer.restoreAndStop() }
        }
        await barrier.release()

        do {
            _ = try await apply.value
        } catch let error as OrderingTransactionError {
            #expect(error == .contextInvalidated)
        } catch {
            Issue.record("Unexpected concurrent ordering error: \(error)")
        }
        await cleanup.value
        #expect(await backend.snapshot() == fixture.baseline)
        #expect(await recovery.receipt() == nil)
    }

    @Test("Ordering shares the same gate as visibility and persistent transitions")
    func orderingSharesTheCoordinatorGate() async throws {
        let fixture = try OrderingFixture()
        let barrier = WriteBarrier()
        let events = OrderingEventLog()
        let backend = MemoryOrderingBackend(snapshot: fixture.baseline, events: events)
        await backend.suspendNextWrite(on: barrier)
        let recovery = MemoryOrderingRecovery()
        let assertion = RecordingAssertionWriter(events: events)
        let persistent = RecordingPersistentWriter(events: events)
        let writer = CoordinatedPolicyWriter(
            assertionWriter: assertion,
            persistentWriter: persistent,
            orderingBackend: backend,
            orderingRecovery: recovery
        )
        let ordering = Task {
            do {
                let observed = try await writer.applyOrdering(
                    fixture.plan, confirmedFingerprint: fixture.plan.fingerprint
                )
                await barrier.applyFinishedWithoutEntry()
                return observed
            } catch {
                await barrier.applyFinishedWithoutEntry()
                throw error
            }
        }
        guard await barrier.waitUntilEntered() else {
            do { _ = try await ordering.value; Issue.record("Ordering ended before its write barrier.") }
            catch { Issue.record("Ordering failed before its write barrier: \(error)") }
            return
        }
        let visibility = Task {
            try await writer.applySessionTransition(with: RevealAllowlistPlan(
                presentation: .baseline,
                allowedSystemItems: [],
                allowedBundleIdentifiers: ["xyz.fi5h.blenny"]
            ))
        }
        await barrier.release()
        _ = try await ordering.value
        try await visibility.value
        #expect(await assertion.operations() == ["session"])
        #expect(await persistent.applied().count == 1)
        #expect(await events.values() == [
            "ordering-write-enter",
            "ordering-write-resumed",
            "persistent-apply",
            "visibility-session",
        ])
    }

    @Test("Missing owner data retains a preferences-restored receipt for later physical verification")
    func missingOwnerKeepsRecoveryReceipt() async throws {
        let fixture = try OrderingFixture()
        let missingOwner = try fixture.snapshot(
            table: fixture.proposedTable,
            swapped: true,
            includeBeta: false
        )
        let backend = MemoryOrderingBackend(snapshot: missingOwner)
        let recovery = MemoryOrderingRecovery(receipt: OrderingRecoveryReceipt(
            plan: fixture.plan, phase: .applied
        ))
        let writer = coordinator(backend: backend, recovery: recovery)

        let result = try await writer.restoreOrdering()
        #expect(result.preferencesRestored)
        #expect(!result.relativeOrderVerified)
        #expect(await recovery.receipt()?.phase == .preferencesRestored)
        #expect(await writer.hasPendingRestoration())
    }

    @Test("Management cleanup honors an ordering pending-restoration signal even without an active policy")
    func managementCleanupHonorsOrderingRecovery() async {
        let pending = PendingRecoveryWriter()
        let loop = ManagementLoopController(writerProvider: { pending })
        _ = try? await loop.writerForTransaction()

        await loop.failClosed("ordering receipt requires observation")
        #expect(await loop.state == .restorationFailed("ordering receipt requires observation"))
        #expect(await pending.activePlanSnapshot() == nil)
    }

    @Test("Owner namespace or container replacement cannot be reported as complete restoration")
    func changedPreferenceSourceKeepsRecoveryReceipt() async throws {
        for sourceOnly in [false, true] {
            let fixture = try OrderingFixture()
            let originalNamespace: OrderingOwnerPreferenceNamespace = sourceOnly
                ? .sandboxContainer : .currentUserAnyHost
            let originalSource = sourceOnly ? String(repeating: "a", count: 64) : nil
            let baseline = try replacingOrderingSnapshot(fixture.baseline,
                table: fixture.baselineTable, swapped: false,
                namespace: originalNamespace, sourceIdentity: originalSource)
            let plan = try OrderingPlan.make(snapshot: baseline,
                bundleIdentifiers: ["com.example.alpha", "com.example.beta"])
            let backend = MemoryOrderingBackend(snapshot: baseline)
            let recovery = MemoryOrderingRecovery()
            let writer = coordinator(backend: backend, recovery: recovery)
            let applied = try await writer.applyOrdering(plan, confirmedFingerprint: plan.fingerprint)
            let changed = try replacingOrderingSnapshot(applied,
                table: fixture.proposedTable, swapped: true,
                namespace: .sandboxContainer, sourceIdentity: String(repeating: "b", count: 64))
            await backend.replaceCurrent(changed)

            let result = try await writer.restoreOrdering()
            #expect(result.preferencesRestored)
            #expect(!result.relativeOrderVerified)
            #expect(await recovery.receipt()?.phase == .preferencesRestored)
            #expect(await recovery.completed().isEmpty)
            #expect(await backend.writeCount() == 2)

            // Once the original namespace can be verified again, only observe:
            // the exact table inverse has already been written once.
            let originalEvidence = try replacingOrderingSnapshot(await backend.snapshot(),
                table: fixture.baselineTable, swapped: false,
                namespace: originalNamespace, sourceIdentity: originalSource)
            await backend.replaceCurrent(originalEvidence)
            let verified = try await writer.restoreOrdering()
            #expect(verified.relativeOrderVerified)
            #expect(await backend.writeCount() == 2)
            #expect(await recovery.receipt() == nil)
        }
    }

    private func coordinator(
        backend: MemoryOrderingBackend,
        recovery: MemoryOrderingRecovery
    ) -> CoordinatedPolicyWriter {
        CoordinatedPolicyWriter(
            assertionWriter: RecordingAssertionWriter(),
            persistentWriter: RecordingPersistentWriter(),
            orderingBackend: backend,
            orderingRecovery: recovery
        )
    }

    private func expectError(
        _ expected: OrderingTransactionError,
        operation: () async throws -> Void
    ) async {
        do { try await operation(); Issue.record("Expected \(expected), but operation succeeded.") }
        catch let error as OrderingTransactionError { #expect(error == expected) }
        catch { Issue.record("Expected \(expected), received \(error).") }
    }

    private func expectOrderingError(operation: () async throws -> Void) async {
        do { try await operation(); Issue.record("Expected an ordering validation error.") }
        catch is OrderingError {}
        catch { Issue.record("Expected OrderingError, received \(error).") }
    }
}

private struct OrderingFixture: Sendable {
    let capturedAt: Date
    let alphaKey = "status:com.example.alpha::alpha-item"
    let betaKey = "status:com.example.beta::beta-item"
    let baselineTable: [String: OrderingValue]
    let proposedTable: [String: OrderingValue]
    let baseline: OrderingSnapshot
    let proposed: OrderingSnapshot
    let plan: OrderingPlan

    init() throws {
        capturedAt = Date()
        baselineTable = [alphaKey: .integer(100), betaKey: .integer(200)]
        proposedTable = [alphaKey: .integer(200), betaKey: .integer(100)]
        baseline = try Self.makeSnapshot(
            table: baselineTable, capturedAt: capturedAt, swapped: false, includeBeta: true
        )
        proposed = try Self.makeSnapshot(
            table: proposedTable, capturedAt: capturedAt, swapped: true, includeBeta: true
        )
        plan = try OrderingPlan.make(
            snapshot: baseline,
            bundleIdentifiers: ["com.example.alpha", "com.example.beta"],
            now: capturedAt,
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
        )
    }

    func snapshot(
        table: [String: OrderingValue]? = nil,
        group: [String: OrderingValue]? = nil,
        swapped: Bool = false,
        includeBeta: Bool = true
    ) throws -> OrderingSnapshot {
        let resolvedGroup = group ?? [OrderingSnapshot.tableKey: .dictionary(table ?? baselineTable)]
        let resolvedTable: [String: OrderingValue]
        if case let .dictionary(value)? = resolvedGroup[OrderingSnapshot.tableKey] { resolvedTable = value }
        else { resolvedTable = table ?? baselineTable }
        return try Self.makeSnapshot(
            table: resolvedTable,
            group: resolvedGroup,
            capturedAt: capturedAt,
            swapped: swapped,
            includeBeta: includeBeta
        )
    }

    private static func makeSnapshot(
        table: [String: OrderingValue],
        group: [String: OrderingValue]? = nil,
        capturedAt: Date,
        swapped: Bool,
        includeBeta: Bool
    ) throws -> OrderingSnapshot {
        let alpha = OrderingProcess(bundleIdentifier: "com.example.alpha", executableName: "Alpha", pid: 101, launchTime: capturedAt.addingTimeInterval(-20), isSystem: false)
        let beta = OrderingProcess(bundleIdentifier: "com.example.beta", executableName: "Beta", pid: 202, launchTime: capturedAt.addingTimeInterval(-20), isSystem: false)
        let alphaFrame = RectSnapshot(x: swapped ? 80 : 20, y: 0, width: 20, height: 22)
        let betaFrame = RectSnapshot(x: swapped ? 20 : 80, y: 0, width: 20, height: 22)
        let alphaObservation = OrderingOwnerObservation(process: alpha, displayName: "Alpha", axComplete: true, itemFrames: [alphaFrame], ownerPreferencesComplete: true, ownerSavedPositions: ["alpha-item": .integer(100)])
        let betaObservation = OrderingOwnerObservation(process: beta, displayName: "Beta", axComplete: true, itemFrames: [betaFrame], ownerPreferencesComplete: true, ownerSavedPositions: ["beta-item": .integer(200)])
        var before = [alpha]
        var observations: [Int32: OrderingOwnerObservation] = [101: alphaObservation]
        if includeBeta { before.append(beta); observations[202] = betaObservation }
        return try OrderingSnapshot(
            group: group ?? [OrderingSnapshot.tableKey: .dictionary(table)],
            beforeProcesses: before,
            afterProcesses: before,
            observationsByPID: observations,
            osBuild: OrderingSnapshot.supportedBuild,
            architecture: OrderingSnapshot.supportedArchitecture,
            runtimeContractVerified: true,
            displaySignature: "test-display",
            displayCount: 1,
            displayFrame: RectSnapshot(x: 0, y: 0, width: 1_440, height: 24),
            lifecycleGeneration: 1,
            policyFingerprint: "test-policy",
            orderingAllowedBundleIdentifiers: Set(before.compactMap(\.bundleIdentifier)),
            capturedAt: capturedAt
        )
    }
}

private actor MemoryOrderingBackend: MenuBarOrderingBackend {
    private var current: OrderingSnapshot
    private var writes = 0
    private var failAfterMutation = false
    private var failBeforeMutation = false
    private var appliedGeometryUnchanged = false
    private var nextWriteBarrier: WriteBarrier?
    private let events: OrderingEventLog?

    init(snapshot: OrderingSnapshot, events: OrderingEventLog? = nil) {
        current = snapshot
        self.events = events
    }

    func capture() async throws -> OrderingSnapshot { current }

    func writeTable(_ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot) async throws {
        guard current == snapshot else { throw OrderingTransactionError.receiptStorageUnavailable }
        writes += 1
        let barrier = nextWriteBarrier
        nextWriteBarrier = nil
        if let events { await events.append("ordering-write-enter") }
        if let barrier { await barrier.enter() }
        if let events { await events.append("ordering-write-resumed") }
        if failBeforeMutation { failBeforeMutation = false; throw OrderingTransactionError.receiptStorageUnavailable }
        let swapped = !appliedGeometryUnchanged && table.values.contains(.integer(200))
            && table["status:com.example.alpha::alpha-item"] == .integer(200)
        current = try replacingOrderingSnapshot(current, table: table, swapped: swapped)
        if failAfterMutation { failAfterMutation = false; throw OrderingTransactionError.receiptStorageUnavailable }
    }

    func failNextWrite(afterMutation: Bool) {
        if afterMutation { failAfterMutation = true } else { failBeforeMutation = true }
    }
    func leaveAppliedGeometryUnchanged() { appliedGeometryUnchanged = true }
    func suspendNextWrite(on barrier: WriteBarrier) { nextWriteBarrier = barrier }
    func replaceCurrent(_ snapshot: OrderingSnapshot) { current = snapshot }
    func snapshot() -> OrderingSnapshot { current }
    func writeCount() -> Int { writes }
}

private func replacingOrderingSnapshot(
    _ snapshot: OrderingSnapshot,
    table: [String: OrderingValue],
    swapped: Bool,
    namespace: OrderingOwnerPreferenceNamespace? = nil,
    sourceIdentity: String? = nil
) throws -> OrderingSnapshot {
    var group = snapshot.group
    group[OrderingSnapshot.tableKey] = .dictionary(table)
    var observations = snapshot.observationsByPID
    for (pid, observation) in observations {
        let x: Double
        switch pid {
        case 101: x = swapped ? 80 : 20
        case 202: x = swapped ? 20 : 80
        default: continue
        }
        observations[pid] = OrderingOwnerObservation(
            process: observation.process,
            displayName: observation.displayName,
            axComplete: observation.axComplete,
            itemFrames: [RectSnapshot(x: x, y: 0, width: 20, height: 22)],
            ownerPreferencesComplete: observation.ownerPreferencesComplete,
            ownerSavedPositions: observation.ownerSavedPositions,
            ownerPreferenceNamespace: namespace ?? observation.ownerPreferenceNamespace,
            ownerPreferenceSourceIdentity: namespace == nil
                ? observation.ownerPreferenceSourceIdentity : sourceIdentity
        )
    }
    return try OrderingSnapshot(
        group: group,
        beforeProcesses: snapshot.beforeProcesses,
        afterProcesses: snapshot.afterProcesses,
        observationsByPID: observations,
        osBuild: snapshot.osBuild,
        architecture: snapshot.architecture,
        runtimeContractVerified: snapshot.runtimeContractVerified,
        displaySignature: snapshot.displaySignature,
        displayCount: snapshot.displayCount,
        displayFrame: snapshot.displayFrame,
        lifecycleGeneration: snapshot.lifecycleGeneration,
        policyFingerprint: snapshot.policyFingerprint,
        orderingAllowedBundleIdentifiers: snapshot.orderingAllowedBundleIdentifiers,
        capturedAt: snapshot.capturedAt
    )
}

private actor MemoryOrderingRecovery: OrderingRecoveryStoring {
    private var active: OrderingRecoveryReceipt?
    private var archived: [OrderingRecoveryReceipt] = []
    private var saves = 0
    private var failSave = false

    init(receipt: OrderingRecoveryReceipt? = nil) { active = receipt }
    func acquireLease() throws {}
    func releaseLease() {}
    func load() throws -> OrderingRecoveryReceipt? { active }
    func save(_ receipt: OrderingRecoveryReceipt) throws {
        if failSave { failSave = false; throw OrderingTransactionError.receiptStorageUnavailable }
        saves += 1; active = receipt
    }
    func complete(_ receipt: OrderingRecoveryReceipt) throws {
        guard active?.plan.id == receipt.plan.id else { throw OrderingTransactionError.invalidReceipt }
        archived.append(receipt); active = nil
    }
    func failNextSave() { failSave = true }
    func receipt() -> OrderingRecoveryReceipt? { active }
    func completed() -> [OrderingRecoveryReceipt] { archived }
    func saveCount() -> Int { saves }
}

private actor WriteBarrier {
    private var entered = false
    private var applyFinishedBeforeEntry = false
    private var enteredWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?
    func enter() async {
        entered = true; enteredWaiter?.resume(); enteredWaiter = nil
        await withCheckedContinuation { releaseWaiter = $0 }
    }
    func waitUntilEntered() async -> Bool {
        if entered { return true }
        if applyFinishedBeforeEntry { return false }
        await withCheckedContinuation { enteredWaiter = $0 }
        return entered
    }

    func applyFinishedWithoutEntry() {
        guard !entered else { return }
        applyFinishedBeforeEntry = true
        enteredWaiter?.resume()
        enteredWaiter = nil
    }
    func release() { releaseWaiter?.resume(); releaseWaiter = nil }
}

private actor OrderingEventLog {
    private var events: [String] = []
    func append(_ value: String) { events.append(value) }
    func values() -> [String] { events }
}

private actor RecordingAssertionWriter: PolicyAssertionWriting {
    private var active: RevealAllowlistPlan?
    private var log: [String] = []
    private let events: OrderingEventLog?
    init(events: OrderingEventLog? = nil) { self.events = events }
    func applySessionTransition(with plan: RevealAllowlistPlan) async throws {
        if let events { await events.append("visibility-session") }
        log.append("session")
        active = plan
    }
    func restoreAndStop() async { log.append("stop"); active = nil }
    func connectionInvalidated() async { log.append("invalidated"); active = nil }
    func activePlanSnapshot() async -> RevealAllowlistPlan? { active }
    func operations() -> [String] { log }
}

private actor RecordingPersistentWriter: PersistentSystemItemPlanWriting {
    private var plans: [[String: PersistentSystemItemPresentation]] = []
    private let events: OrderingEventLog?
    init(events: OrderingEventLog? = nil) { self.events = events }
    func applyManagedPlan(_ plan: [String: PersistentSystemItemPresentation]) async throws {
        if let events { await events.append("persistent-apply") }
        plans.append(plan)
    }
    func verifyManagedPlan(_ plan: [String: PersistentSystemItemPresentation]) async throws -> Bool { true }
    func finalizeCommittedPlan(_ plan: [String: PersistentSystemItemPresentation]) async {}
    func restoreAllManagedItems() async -> Bool { true }
    func applied() -> [[String: PersistentSystemItemPresentation]] { plans }
}

private actor PendingRecoveryWriter: PolicyAssertionWriting {
    func applySessionTransition(with plan: RevealAllowlistPlan) async throws {}
    func restoreAndStop() async {}
    func connectionInvalidated() async {}
    func activePlanSnapshot() async -> RevealAllowlistPlan? { nil }
    func hasPendingRestoration() async -> Bool { true }
}
#endif
