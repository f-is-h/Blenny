import Foundation
import Testing

@testable import BlennyCore

@Suite("Policy editing persist/apply transaction")
struct PolicyEditingTransactionTests {
    private let blenny = "com.example.BlennyProbe"
    private let usage = "xyz.fi5h.Usage4Claude"
    private let cleanShot = "pl.maketheweb.cleanshotx"

    @Test("Successful resume activates before persistence and preserves accepted edit")
    func successfulResume() async throws {
        let old = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let prepared = try makePrepared(old: old, enabled: true)
        let events = TransactionEventRecorder()
        let store = MemoryPolicyStore(document: old, events: events)
        let writer = TransactionPolicyWriter(events: events, behaviors: [.succeed])
        let coordinator = PolicyEditingTransactionCoordinator(
            store: store,
            writerProvider: { writer }
        )

        #expect(try await coordinator.commit(prepared) == .committed(prepared.newPolicy))
        #expect(await store.document == prepared.newPolicy)
        #expect(await events.values == ["load", "apply-new", "save"])
    }

    @Test("Stale or unreadable accepted policy fails before writer creation")
    func staleAcceptedPolicyFailsBeforeWriter() async throws {
        let old = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let prepared = try makePrepared(old: old, enabled: true)
        let provider = TransactionWriterProvider()
        let stale = try document(enabled: false, revealable: cleanShot, hidden: usage)
        let staleCoordinator = PolicyEditingTransactionCoordinator(
            store: MemoryPolicyStore(document: stale),
            writerProvider: { try await provider.makeWriter() }
        )

        await #expect(throws: PolicyEditingTransactionFailure.self) {
            try await staleCoordinator.commit(prepared)
        }
        #expect(await provider.creationCount == 0)

        let failedLoad = MemoryPolicyStore(document: old)
        await failedLoad.setFailure(.load)
        let failedLoadCoordinator = PolicyEditingTransactionCoordinator(
            store: failedLoad,
            writerProvider: { try await provider.makeWriter() }
        )
        await #expect(throws: PolicyEditingTransactionFailure.self) {
            try await failedLoadCoordinator.commit(prepared)
        }
        #expect(await provider.creationCount == 0)
    }

    @Test("Writer creation and activation failures preserve old persistence and unrestricted state")
    func creationAndActivationFailures() async throws {
        let old = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let prepared = try makePrepared(old: old, enabled: true)
        let creationFailure = PolicyEditingTransactionCoordinator(
            store: MemoryPolicyStore(document: old),
            writerProvider: { throw TransactionTestError.writerCreation }
        )
        do {
            _ = try await creationFailure.commit(prepared)
            Issue.record("Expected writer creation failure")
        } catch let failure as PolicyEditingTransactionFailure {
            #expect(failure.stage == .writerCreation)
            #expect(failure.systemState == .unrestricted)
        }

        let store = MemoryPolicyStore(document: old)
        let writer = TransactionPolicyWriter(behaviors: [.fail])
        let activationFailure = PolicyEditingTransactionCoordinator(
            store: store,
            writerProvider: { writer }
        )
        do {
            _ = try await activationFailure.commit(prepared)
            Issue.record("Expected activation failure")
        } catch let failure as PolicyEditingTransactionFailure {
            #expect(failure.stage == .activation)
            #expect(failure.systemState == .unrestricted)
        }
        #expect(await store.document == old)
        #expect(await writer.restoreCount == 1)
    }

    @Test("Persistence failure restores unrestricted state when management was disabled")
    func persistenceFailureAfterResumeRestoresUnrestricted() async throws {
        let old = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let prepared = try makePrepared(old: old, enabled: true)
        let store = MemoryPolicyStore(document: old)
        await store.setFailure(.save)
        let writer = TransactionPolicyWriter(behaviors: [.succeed])
        let coordinator = PolicyEditingTransactionCoordinator(
            store: store,
            writerProvider: { writer }
        )

        do {
            _ = try await coordinator.commit(prepared)
            Issue.record("Expected persistence failure")
        } catch let failure as PolicyEditingTransactionFailure {
            #expect(failure.stage == .persistence)
            #expect(failure.systemState == .unrestricted)
        }
        #expect(await store.document == old)
        #expect(await writer.restoreCount == 1)
    }

    @Test("Disabling management persists before invalidating the active writer")
    func disablingManagementPersistsThenRestores() async throws {
        let old = try document(enabled: true, revealable: usage, hidden: cleanShot)
        let prepared = try makePrepared(old: old, enabled: false)
        let events = TransactionEventRecorder()
        let store = MemoryPolicyStore(document: old, events: events)
        let writer = TransactionPolicyWriter(events: events, behaviors: [])
        let coordinator = PolicyEditingTransactionCoordinator(
            store: store,
            writerProvider: { writer }
        )

        #expect(try await coordinator.commit(prepared) == .committed(prepared.newPolicy))
        #expect(await events.values == ["load", "save", "restore"])
        #expect(await store.document?.managementEnabled == false)
        #expect(await writer.restoreCount == 1)
    }

    @Test("A failed disable persistence leaves the previous writer untouched")
    func failedDisablePersistencePreservesOldState() async throws {
        let old = try document(enabled: true, revealable: usage, hidden: cleanShot)
        let prepared = try makePrepared(old: old, enabled: false)
        let store = MemoryPolicyStore(document: old)
        await store.setFailure(.save)
        let writer = TransactionPolicyWriter(behaviors: [])
        let coordinator = PolicyEditingTransactionCoordinator(
            store: store,
            writerProvider: { writer }
        )

        do {
            _ = try await coordinator.commit(prepared)
            Issue.record("Expected disable persistence failure")
        } catch let failure as PolicyEditingTransactionFailure {
            #expect(failure.stage == .persistence)
            #expect(failure.systemState == .previousPolicyActive)
        }
        #expect(await store.document == old)
        #expect(await writer.restoreCount == 0)
    }

    @Test("Process disconnect before persistence leaves old policy and unrestricted state")
    func processDisconnectBeforePersistenceFailsClosed() async throws {
        let old = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let prepared = try makePrepared(old: old, enabled: true)
        let store = MemoryPolicyStore(document: old)
        let writer = TransactionPolicyWriter(behaviors: [.disconnect])
        let coordinator = PolicyEditingTransactionCoordinator(
            store: store,
            writerProvider: { writer }
        )

        do {
            _ = try await coordinator.commit(prepared)
            Issue.record("Expected process-disconnect failure")
        } catch let failure as PolicyEditingTransactionFailure {
            #expect(failure.stage == .activation)
            #expect(failure.systemState == .unrestricted)
        }
        #expect(await store.document == old)
        #expect(await store.saveCount == 0)
        #expect(await writer.restoreCount >= 1)
    }

    @Test("Persistence failure reactivates the previous safe baseline")
    func persistenceFailureRollsBackToOldBaseline() async throws {
        let old = try document(enabled: true, revealable: usage, hidden: cleanShot)
        let prepared = try makePrepared(
            old: old,
            enabled: true,
            revealable: cleanShot,
            hidden: usage
        )
        let store = MemoryPolicyStore(document: old)
        await store.setFailure(.save)
        let writer = TransactionPolicyWriter(behaviors: [.succeed, .succeed])
        let coordinator = PolicyEditingTransactionCoordinator(
            store: store,
            writerProvider: { writer }
        )

        do {
            _ = try await coordinator.commit(prepared)
            Issue.record("Expected persistence failure")
        } catch let failure as PolicyEditingTransactionFailure {
            #expect(failure.stage == .persistence)
            #expect(failure.systemState == .previousPolicyActive)
        }
        #expect(await writer.appliedPlans == [
            prepared.report.newBaselinePlan,
            prepared.report.oldBaselinePlan,
        ].compactMap { $0 })
        #expect(await writer.restoreCount == 0)
        #expect(await store.document == old)
    }

    @Test("Rollback failure invalidates all assertions and remains unrestricted")
    func rollbackFailureRestoresEverything() async throws {
        let old = try document(enabled: true, revealable: usage, hidden: cleanShot)
        let prepared = try makePrepared(
            old: old,
            enabled: true,
            revealable: cleanShot,
            hidden: usage
        )
        let store = MemoryPolicyStore(document: old)
        await store.setFailure(.save)
        let writer = TransactionPolicyWriter(behaviors: [.succeed, .fail])
        let coordinator = PolicyEditingTransactionCoordinator(
            store: store,
            writerProvider: { writer }
        )

        do {
            _ = try await coordinator.commit(prepared)
            Issue.record("Expected rollback failure")
        } catch let failure as PolicyEditingTransactionFailure {
            #expect(failure.stage == .rollback)
            #expect(failure.systemState == .unrestricted)
        }
        #expect(await writer.restoreCount == 1)
        #expect(await store.document == old)
    }

    @Test("Restore Previous Policy keeps one backup and repeated restore is a no-op")
    func restorePreviousPolicyIsDeterministic() async throws {
        let current = try document(enabled: false, revealable: cleanShot, hidden: usage)
        let previous = try document(enabled: true, revealable: usage, hidden: cleanShot)
        let store = MemoryPolicyStore(
            document: current,
            backup: PersistentBundlePolicyBackup(previousPolicy: previous)
        )
        let provider = TransactionWriterProvider()
        let core = PolicyEditingCore(
            store: store,
            blennyBundleIdentifier: blenny,
            scope: scope,
            writerProvider: { try await provider.makeWriter() }
        )
        let preview = try await core.previewRestorePreviousPolicy(
            candidates: inventory(),
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot]
        )
        let prepared = try #require(preview.1)

        #expect(try await core.commit(prepared) == .committed(previous))
        #expect(await store.document == previous)
        #expect(await store.backup?.previousPolicy == previous)

        let repeated = try await core.previewRestorePreviousPolicy(
            candidates: inventory(),
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot]
        )
        let repeatedPrepared = try #require(repeated.1)
        #expect(try await core.commit(repeatedPrepared) == .noChange)
        #expect(await provider.creationCount == 1)
        #expect(await store.backup?.previousPolicy == previous)
    }

    @Test("Discard draft reloads accepted policy without persistence or writer creation")
    func discardDraftIsPure() async throws {
        let accepted = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let store = MemoryPolicyStore(document: accepted)
        let provider = TransactionWriterProvider()
        let core = PolicyEditingCore(
            store: store,
            blennyBundleIdentifier: blenny,
            scope: scope,
            writerProvider: { try await provider.makeWriter() }
        )

        let discarded = try await core.discardDraft()
        #expect(discarded == BundlePolicyDraft(acceptedPolicy: accepted))
        #expect(await store.saveCount == 0)
        #expect(await provider.creationCount == 0)
    }

    @Test("Stop Managing is previewed before persistence and restoration")
    func stopManagingUsesPreparedTransaction() async throws {
        let accepted = try document(enabled: true, revealable: usage, hidden: cleanShot)
        let store = MemoryPolicyStore(document: accepted)
        let provider = TransactionWriterProvider()
        let core = PolicyEditingCore(
            store: store,
            blennyBundleIdentifier: blenny,
            scope: scope,
            writerProvider: { try await provider.makeWriter() }
        )

        let preview = try await core.previewStopManaging(
            candidates: inventory(),
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot]
        )
        let prepared = try #require(preview.1)

        #expect(preview.0.diff?.changes.first?.description == "MANAGEMENT enabled -> disabled")
        #expect(await store.saveCount == 0)
        #expect(await provider.creationCount == 0)
        #expect(try await core.commit(prepared) == .committed(prepared.newPolicy))
        #expect(await store.document?.managementEnabled == false)
        #expect(await provider.creationCount == 1)
    }

    @Test("Malformed policy or unsupported backup cannot reach writer creation")
    func malformedFilesFailBeforeWriter() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BlennyEditingMalformed-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let policyURL = directory.appendingPathComponent("bundle-policies.json")
        let backupURL = directory.appendingPathComponent("previous.blenny-backup.json")
        let store = try PersistentBundlePolicyStore(policyURL: policyURL, backupURL: backupURL)
        let provider = TransactionWriterProvider()
        let core = PolicyEditingCore(
            store: store,
            blennyBundleIdentifier: blenny,
            scope: scope,
            writerProvider: { try await provider.makeWriter() }
        )

        try Data("{malformed".utf8).write(to: policyURL)
        await #expect(throws: (any Error).self) {
            _ = try await core.makeDraft()
        }
        #expect(await provider.creationCount == 0)

        let accepted = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let encoder = JSONEncoder()
        try encoder.encode(accepted).write(to: policyURL)
        try Data("{\"schemaVersion\":99,\"previousPolicy\":{}}".utf8).write(to: backupURL)
        await #expect(throws: (any Error).self) {
            _ = try await core.previewRestorePreviousPolicy(
                candidates: inventory(),
                observedRunningBundleIdentifiers: [blenny, usage, cleanShot]
            )
        }
        #expect(await provider.creationCount == 0)
    }

    private var scope: PolicyValidationScope {
        PolicyValidationScope(approvedBundleIdentifiers: [blenny, usage, cleanShot])
    }

    private func document(
        enabled: Bool,
        revealable: String,
        hidden: String
    ) throws -> PersistentBundlePolicyDocument {
        try PersistentBundlePolicyDocument(
            managementEnabled: enabled,
            policies: [
                .init(bundleIdentifier: blenny, policy: .visible),
                .init(bundleIdentifier: revealable, policy: .revealable),
                .init(bundleIdentifier: hidden, policy: .hidden),
            ]
        )
    }

    private func inventory() -> PolicyCandidateInventory {
        PolicyCandidateInventory(observations: [
            .init(bundleIdentifier: blenny, processIdentifier: 10, menuBarItemCount: 1),
            .init(bundleIdentifier: usage, processIdentifier: 20, menuBarItemCount: 2),
            .init(bundleIdentifier: cleanShot, processIdentifier: 30, menuBarItemCount: 1),
        ])
    }

    private func makePrepared(
        old: PersistentBundlePolicyDocument,
        enabled: Bool,
        revealable: String? = nil,
        hidden: String? = nil
    ) throws -> PreparedPolicyEdit {
        let newRevealable = revealable ?? usage
        let newHidden = hidden ?? cleanShot
        let result = try PolicyDryRunner.prepare(
            oldPolicy: old,
            draft: BundlePolicyDraft(
                visible: [blenny],
                revealable: [newRevealable],
                hidden: [newHidden]
            ),
            managementEnabled: enabled,
            candidates: inventory(),
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot],
            scope: scope,
            blennyBundleIdentifier: blenny
        )
        return try #require(result.prepared)
    }
}

enum MemoryPolicyStoreFailure: Error {
    case load
    case save
    case restore
}

actor MemoryPolicyStore: PersistentBundlePolicyStoring {
    private(set) var document: PersistentBundlePolicyDocument?
    private(set) var backup: PersistentBundlePolicyBackup?
    private(set) var saveCount = 0
    private var failure: MemoryPolicyStoreFailure?
    private let events: TransactionEventRecorder?

    init(
        document: PersistentBundlePolicyDocument?,
        backup: PersistentBundlePolicyBackup? = nil,
        events: TransactionEventRecorder? = nil
    ) {
        self.document = document
        self.backup = backup
        self.events = events
    }

    func setFailure(_ failure: MemoryPolicyStoreFailure?) {
        self.failure = failure
    }

    func load() async throws -> PersistentBundlePolicyDocument? {
        await events?.append("load")
        if failure == .load { throw MemoryPolicyStoreFailure.load }
        return document
    }

    func loadBackup() async throws -> PersistentBundlePolicyBackup? {
        backup
    }

    func save(_ document: PersistentBundlePolicyDocument) async throws {
        await events?.append("save")
        saveCount += 1
        if failure == .save { throw MemoryPolicyStoreFailure.save }
        if let existing = self.document, existing != document {
            backup = PersistentBundlePolicyBackup(previousPolicy: existing)
        }
        self.document = document
    }

    func restoreBackup() async throws -> PersistentBundlePolicyDocument? {
        if failure == .restore { throw MemoryPolicyStoreFailure.restore }
        document = backup?.previousPolicy
        return document
    }
}

private enum TransactionTestError: Error {
    case writerCreation
    case activation
}

private enum TransactionWriterBehavior {
    case succeed
    case fail
    case disconnect
}

private actor TransactionPolicyWriter: PolicyAssertionWriting {
    private(set) var appliedPlans: [RevealAllowlistPlan] = []
    private(set) var restoreCount = 0
    private var behaviors: [TransactionWriterBehavior]
    private var activePlan: RevealAllowlistPlan?
    private let events: TransactionEventRecorder?

    init(
        events: TransactionEventRecorder? = nil,
        behaviors: [TransactionWriterBehavior]
    ) {
        self.events = events
        self.behaviors = behaviors
    }

    func applySessionTransition(with plan: RevealAllowlistPlan) async throws {
        appliedPlans.append(plan)
        await events?.append(appliedPlans.count == 1 ? "apply-new" : "apply-old")
        let behavior = behaviors.isEmpty ? .succeed : behaviors.removeFirst()
        switch behavior {
        case .succeed:
            activePlan = plan
        case .fail:
            throw TransactionTestError.activation
        case .disconnect:
            activePlan = nil
        }
    }

    func restoreAndStop() async {
        restoreCount += 1
        activePlan = nil
        await events?.append("restore")
    }

    func connectionInvalidated() async {
        await restoreAndStop()
    }

    func activePlanSnapshot() async -> RevealAllowlistPlan? {
        activePlan
    }
}

private actor TransactionWriterProvider {
    private(set) var creationCount = 0

    func makeWriter() throws -> any PolicyAssertionWriting {
        creationCount += 1
        return TransactionPolicyWriter(behaviors: [.succeed])
    }
}

actor TransactionEventRecorder {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}
