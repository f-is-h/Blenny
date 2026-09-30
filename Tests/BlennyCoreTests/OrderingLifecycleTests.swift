#if BLENNY_PRODUCT || DEBUG
import Foundation
import Testing
@testable import BlennyCore

@Suite("Ordering lifecycle boundaries")
struct OrderingLifecycleTests {
    @Test("Recovery lookup never creates or reactivates a writer")
    func existingRecoveryWriterIsReadOnly() async throws {
        let gate = LifecycleCreationGate()
        let created = LifecyclePolicyWriter()
        let factory = LifecycleWriterFactory(gate: gate, writer: created)
        let loop = ManagementLoopController { try await factory.make() }

        if case .some = await loop.existingWriterForRecovery() {
            Issue.record("Recovery lookup unexpectedly created a writer.")
        }
        #expect(await factory.creationCount() == 0)
        #expect(await loop.state == .unknown)

        let creation = Task { try await loop.writerForTransaction() }
        await gate.waitUntilEntered()
        await gate.release()
        _ = try await creation.value
        if case .none = await loop.existingWriterForRecovery() {
            Issue.record("The existing writer was not retained.")
        }
        #expect(await factory.creationCount() == 1)
        #expect(await loop.state == .unknown)
    }

    @Test("Concurrent writer requests share one suspended factory result")
    func coalescedWriterCreation() async throws {
        let gate = LifecycleCreationGate()
        let created = LifecyclePolicyWriter()
        let factory = LifecycleWriterFactory(gate: gate, writer: created)
        let loop = ManagementLoopController { try await factory.make() }

        async let first = loop.writerForTransaction()
        async let second = loop.writerForTransaction()
        await gate.waitUntilEntered()
        await gate.release()
        _ = try await (first, second)

        #expect(await factory.creationCount() == 1)
        #expect(await created.restoreCount() == 0)
    }

    @Test("Lifecycle invalidation during creation reports stale and cleans once")
    func staleSharedWriterCreation() async {
        let gate = LifecycleCreationGate()
        let created = LifecyclePolicyWriter()
        let factory = LifecycleWriterFactory(gate: gate, writer: created)
        let loop = ManagementLoopController { try await factory.make() }

        let first = Task { try await loop.writerForTransaction() }
        await gate.waitUntilEntered()
        await loop.stop()
        await gate.release()

        #expect(await managementError(first) == .staleLifecycleGeneration)
        #expect(await factory.creationCount() == 1)
        #expect(await created.restoreCount() == 1)
        #expect(await loop.state == .stopped)
    }

    @Test("Recovery checks token collisions added in the after-process inventory")
    func recoveryRejectsAfterSetCollision() async throws {
        let fixture = try LifecycleOrderingFixture()
        let collision = OrderingProcess(bundleIdentifier: "com.example.new",
            executableName: "com.example.alpha", pid: 303,
            launchTime: fixture.capturedAt.addingTimeInterval(-2), isSystem: false)
        let current = try fixture.snapshot(table: fixture.proposedTable, swapped: true,
            afterProcesses: fixture.processes + [collision])
        let backend = LifecycleOrderingBackend(current)
        let recovery = LifecycleOrderingRecovery(receipt: OrderingRecoveryReceipt(
            plan: fixture.plan, phase: .applied
        ))
        let writer = lifecycleCoordinator(backend: backend, recovery: recovery)

        await #expect(throws: OrderingTransactionError.recoveryIdentityConflict) {
            try await writer.restoreOrdering()
        }
        #expect(await backend.writeCount() == 0)
        #expect(await recovery.currentReceipt()?.phase == .applied)
    }

    @Test("An ambiguous durable-intent save keeps recovery pending and the lease held")
    func ambiguousIntentSaveRemainsPending() async throws {
        let fixture = try LifecycleOrderingFixture()
        let backend = LifecycleOrderingBackend(fixture.baseline)
        let recovery = LifecycleOrderingRecovery(ambiguousFirstSave: true)
        let writer = lifecycleCoordinator(backend: backend, recovery: recovery)

        await #expect(throws: OrderingTransactionError.receiptStorageUnavailable) {
            try await writer.applyOrdering(fixture.plan,
                confirmedFingerprint: fixture.plan.fingerprint)
        }
        #expect(await backend.writeCount() == 0)
        #expect(await recovery.hasStoredReceipt())
        #expect(await recovery.releaseCount() == 0)
        #expect(await writer.hasPendingRestoration())
    }

    @Test("Manual system-item hide shares the ordering and policy operation gate")
    func manualHideSharesCoordinatorGate() async throws {
        let hideGate = LifecycleCreationGate()
        let manual = try GatedManualPersistentWriter(hideGate: hideGate)
        let writer = CoordinatedPolicyWriter(assertionWriter: LifecyclePolicyWriter(),
            persistentWriter: manual, orderingBackend: LifecycleOrderingBackend(
                try LifecycleOrderingFixture().baseline
            ), orderingRecovery: LifecycleOrderingRecovery())
        let plan = RevealAllowlistPlan(presentation: .baseline, allowedSystemItems: [],
            allowedBundleIdentifiers: ["xyz.fi5h.blenny"])

        let hide = Task { try await writer.hideManualSystemItem(.nowPlaying) }
        await hideGate.waitUntilEntered()
        let policy = Task { try await writer.applySessionTransition(with: plan) }
        await Task.yield()
        #expect(await manual.events() == ["hide"])
        await hideGate.release()
        _ = try await hide.value
        try await policy.value
        #expect(await manual.events() == ["hide", "policy"])
    }

    @Test("Manual system-item restore remains available after coordinator Stop")
    func manualRestoreAllowedWhileStopped() async throws {
        let manual = try GatedManualPersistentWriter(hideGate: LifecycleCreationGate())
        let writer = CoordinatedPolicyWriter(assertionWriter: LifecyclePolicyWriter(),
            persistentWriter: manual, orderingBackend: LifecycleOrderingBackend(
                try LifecycleOrderingFixture().baseline
            ), orderingRecovery: LifecycleOrderingRecovery())

        await writer.restoreAndStop()
        try await writer.restoreManualSystemItem(.nowPlaying)
        #expect(await manual.events() == ["restore"])
    }

    private func managementError(
        _ task: Task<any PolicyAssertionWriting, Error>
    ) async -> ManagementLoopError? {
        do { _ = try await task.value; return nil }
        catch let error as ManagementLoopError { return error }
        catch { return nil }
    }

    private func lifecycleCoordinator(
        backend: LifecycleOrderingBackend,
        recovery: LifecycleOrderingRecovery
    ) -> CoordinatedPolicyWriter {
        CoordinatedPolicyWriter(assertionWriter: LifecyclePolicyWriter(),
            persistentWriter: LifecyclePersistentWriter(), orderingBackend: backend,
            orderingRecovery: recovery)
    }
}

private actor LifecycleCreationGate {
    private var entered = false
    private var released = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func enterAndWait() async {
        entered = true
        let waiters = entryWaiters
        entryWaiters.removeAll()
        waiters.forEach { $0.resume() }
        if released { return }
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }

    func release() {
        released = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

private actor LifecycleWriterFactory {
    private let gate: LifecycleCreationGate
    private let writer: LifecyclePolicyWriter
    private var count = 0

    init(gate: LifecycleCreationGate, writer: LifecyclePolicyWriter) {
        self.gate = gate
        self.writer = writer
    }

    func make() async throws -> any PolicyAssertionWriting {
        count += 1
        await gate.enterAndWait()
        return writer
    }

    func creationCount() -> Int { count }
}

private actor LifecyclePolicyWriter: PolicyAssertionWriting {
    private var active: RevealAllowlistPlan?
    private var restores = 0

    func applySessionTransition(with plan: RevealAllowlistPlan) { active = plan }
    func restoreAndStop() { restores += 1; active = nil }
    func connectionInvalidated() { restores += 1; active = nil }
    func activePlanSnapshot() -> RevealAllowlistPlan? { active }
    func restoreCount() -> Int { restores }
}

private actor LifecyclePersistentWriter: PersistentSystemItemPlanWriting {
    func applyManagedPlan(_ plan: [String: PersistentSystemItemPresentation]) {}
    func verifyManagedPlan(_ plan: [String: PersistentSystemItemPresentation]) -> Bool { true }
    func finalizeCommittedPlan(_ plan: [String: PersistentSystemItemPresentation]) {}
    func restoreAllManagedItems() -> Bool { true }
}

private actor GatedManualPersistentWriter:
    PersistentSystemItemPlanWriting, ManualSystemItemTrialWriting {
    private let hideGate: LifecycleCreationGate
    private let receipt: SharedSystemItemTrialReceipt
    private var recorded: [String] = []

    init(hideGate: LifecycleCreationGate) throws {
        self.hideGate = hideGate
        let baseline = try SharedSystemItemPreferenceSnapshot(target: .nowPlaying,
            values: ["NowPlaying": try ExactPreferenceValue(NSNumber(value: 0x2))],
            effectiveVisible: true)
        receipt = try SharedSystemItemTrialReceipt(runtime: .current(), baseline: baseline)
    }

    func hide(_ target: SharedSystemItemTrialTarget) async throws -> SharedSystemItemTrialReceipt {
        recorded.append("hide")
        await hideGate.enterAndWait()
        return receipt
    }
    func restore(_ target: SharedSystemItemTrialTarget) { recorded.append("restore") }
    func applyManagedPlan(_ plan: [String: PersistentSystemItemPresentation]) {
        recorded.append("policy")
    }
    func verifyManagedPlan(_ plan: [String: PersistentSystemItemPresentation]) -> Bool { true }
    func finalizeCommittedPlan(_ plan: [String: PersistentSystemItemPresentation]) {}
    func restoreAllManagedItems() -> Bool { true }
    func events() -> [String] { recorded }
}

private actor LifecycleOrderingBackend: MenuBarOrderingBackend {
    private var current: OrderingSnapshot
    private var writes = 0

    init(_ current: OrderingSnapshot) { self.current = current }
    func capture() -> OrderingSnapshot { current }
    func writeTable(_ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot) throws {
        writes += 1
        current = try replacing(table: table)
    }
    func restoreTable(_ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot) throws {
        writes += 1
        current = try replacing(table: table)
    }
    func writeCount() -> Int { writes }

    private func replacing(table: [String: OrderingValue]) throws -> OrderingSnapshot {
        var group = current.group
        group[OrderingSnapshot.tableKey] = .dictionary(table)
        return try OrderingSnapshot(group: group,
            beforeProcesses: current.beforeProcesses, afterProcesses: current.afterProcesses,
            observationsByPID: current.observationsByPID, osBuild: current.osBuild,
            architecture: current.architecture,
            runtimeContractVerified: current.runtimeContractVerified,
            displaySignature: current.displaySignature, displayCount: current.displayCount,
            displayFrame: current.displayFrame, lifecycleGeneration: current.lifecycleGeneration,
            policyFingerprint: current.policyFingerprint,
            orderingAllowedBundleIdentifiers: current.orderingAllowedBundleIdentifiers, capturedAt: Date())
    }
}

private actor LifecycleOrderingRecovery: OrderingRecoveryStoring {
    private var receipt: OrderingRecoveryReceipt?
    private var leaseHeld = false
    private var releases = 0
    private var failAmbiguously: Bool
    private var unreadable = false

    init(receipt: OrderingRecoveryReceipt? = nil, ambiguousFirstSave: Bool = false) {
        self.receipt = receipt
        failAmbiguously = ambiguousFirstSave
    }

    func acquireLease() { leaseHeld = true }
    func releaseLease() { leaseHeld = false; releases += 1 }
    func load() throws -> OrderingRecoveryReceipt? {
        if unreadable { throw OrderingTransactionError.invalidReceipt }
        return receipt
    }
    func save(_ receipt: OrderingRecoveryReceipt) throws {
        guard leaseHeld else { throw OrderingTransactionError.writerOccupied }
        self.receipt = receipt
        if failAmbiguously {
            failAmbiguously = false
            unreadable = true
            throw OrderingTransactionError.receiptStorageUnavailable
        }
    }
    func complete(_ receipt: OrderingRecoveryReceipt) { self.receipt = nil }
    func currentReceipt() -> OrderingRecoveryReceipt? { receipt }
    func hasStoredReceipt() -> Bool { receipt != nil }
    func releaseCount() -> Int { releases }
}

private struct LifecycleOrderingFixture {
    let capturedAt = Date()
    let alphaKey = "status:com.example.alpha::alpha-item"
    let betaKey = "status:com.example.beta::beta-item"
    let processes: [OrderingProcess]
    let baselineTable: [String: OrderingValue]
    let proposedTable: [String: OrderingValue]
    let baseline: OrderingSnapshot
    let plan: OrderingPlan

    init() throws {
        let alpha = OrderingProcess(bundleIdentifier: "com.example.alpha", executableName: "Alpha",
            pid: 101, launchTime: capturedAt.addingTimeInterval(-20), isSystem: false)
        let beta = OrderingProcess(bundleIdentifier: "com.example.beta", executableName: "Beta",
            pid: 202, launchTime: capturedAt.addingTimeInterval(-20), isSystem: false)
        processes = [alpha, beta]
        baselineTable = [alphaKey: .integer(100), betaKey: .integer(200)]
        proposedTable = [alphaKey: .integer(200), betaKey: .integer(100)]
        baseline = try Self.makeSnapshot(capturedAt: capturedAt, processes: processes,
            table: baselineTable, swapped: false, afterProcesses: processes)
        plan = try OrderingPlan.make(snapshot: baseline,
            bundleIdentifiers: ["com.example.alpha", "com.example.beta"],
            now: capturedAt,
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!)
    }

    func snapshot(table: [String: OrderingValue], swapped: Bool,
                  afterProcesses: [OrderingProcess]) throws -> OrderingSnapshot {
        try Self.makeSnapshot(capturedAt: capturedAt, processes: processes, table: table,
            swapped: swapped, afterProcesses: afterProcesses)
    }

    private static func makeSnapshot(capturedAt: Date, processes: [OrderingProcess],
                                     table: [String: OrderingValue], swapped: Bool,
                                     afterProcesses: [OrderingProcess]) throws -> OrderingSnapshot {
        let observations = Dictionary(uniqueKeysWithValues: processes.enumerated().map { index, process in
            let isFirst = index == 0
            let x: Double = swapped ? (isFirst ? 80 : 20) : (isFirst ? 20 : 80)
            let savedKey = isFirst ? "alpha-item" : "beta-item"
            let savedValue: OrderingValue = isFirst ? .integer(100) : .integer(200)
            return (process.pid, OrderingOwnerObservation(process: process,
                displayName: isFirst ? "Alpha" : "Beta", axComplete: true,
                itemFrames: [RectSnapshot(x: x, y: 0, width: 20, height: 22)],
                ownerPreferencesComplete: true, ownerSavedPositions: [savedKey: savedValue]))
        })
        return try OrderingSnapshot(group: [OrderingSnapshot.tableKey: .dictionary(table)],
            beforeProcesses: processes, afterProcesses: afterProcesses,
            observationsByPID: observations, osBuild: OrderingSnapshot.supportedBuild,
            architecture: OrderingSnapshot.supportedArchitecture,
            runtimeContractVerified: true, displaySignature: "lifecycle-display", displayCount: 1,
            displayFrame: RectSnapshot(x: 0, y: 0, width: 1_440, height: 24),
            lifecycleGeneration: 1, policyFingerprint: "lifecycle-policy",
            orderingAllowedBundleIdentifiers: ["com.example.alpha", "com.example.beta"],
            capturedAt: capturedAt)
    }
}
#endif
