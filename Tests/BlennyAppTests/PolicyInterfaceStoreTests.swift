import Foundation
import Testing
import BlennyCore
@testable import BlennyApp

struct PolicyInterfaceStoreTests {
    @Test("A clean first Apply and Undo remain resumable after relaunch", arguments: [false, true])
    func firstApplyAndUndo(stopped: Bool) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistent = try makeStore(directory)
        let initial = try initialPolicy()
        let interface = PolicyInterfaceStore(persistentStore: persistent, initialPolicy: initial)
        let inventory = PolicyCandidateInventory(observations: [
            .init(bundleIdentifier: "xyz.fi5h.blenny", processIdentifier: 10, menuBarItemCount: 1),
            .init(bundleIdentifier: "com.example.owner", processIdentifier: 11, menuBarItemCount: 1)
        ])
        let scope = PolicyValidationScope(approvedBundleIdentifiers: ["xyz.fi5h.blenny", "com.example.owner"])
        let forward = try #require(PolicyDryRunner.prepare(
            oldPolicy: initial,
            draft: BundlePolicyDraft(visible: ["xyz.fi5h.blenny"], revealable: ["com.example.owner"], hidden: []),
            managementEnabled: true, candidates: inventory,
            observedRunningBundleIdentifiers: Set(scope.approvedBundleIdentifiers),
            scope: scope, blennyBundleIdentifier: "xyz.fi5h.blenny"
        ).prepared)
        let snapshot = try OrderingSnapshot(
            group: [OrderingSnapshot.tableKey: .dictionary([:])],
            beforeProcesses: [], afterProcesses: [], observationsByPID: [:],
            osBuild: OrderingSnapshot.supportedBuild, architecture: OrderingSnapshot.supportedArchitecture,
            runtimeContractVerified: true, displaySignature: "first-launch-display", displayCount: 1,
            displayFrame: RectSnapshot(x: 0, y: 0, width: 1000, height: 24),
            lifecycleGeneration: 1, policyFingerprint: initial.policyFingerprint,
            orderingAllowedBundleIdentifiers: [], capturedAt: Date()
        )
        let backend = FirstLaunchReadOnlyBackend(snapshot: snapshot)
        let recovery = OrderingRecoveryStore(directory: directory.appendingPathComponent("ordering"))
        let writer = CoordinatedPolicyWriter(
            assertionWriter: FirstLaunchAssertionWriter(), persistentWriter: FirstLaunchSystemWriter(),
            orderingBackend: backend, orderingRecovery: recovery, orderingPolicyStore: interface
        )
        let plan = try OrderingPlan.makeConfigurationOrdering(snapshot: snapshot, orderedSubjects: [])
        #expect(try await interface.load() == initial)
        #expect(try await persistent.load() == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.path))

        // Reproduce Build 106's pre-write rejection with its raw disk store.
        await #expect(throws: OrderingTransactionError.contextInvalidated) {
            _ = try await writer.applyConfigurationOrdering(
                plan, confirmedFingerprint: plan.fingerprint, policyChange: forward, policyStore: persistent
            )
        }
        #expect(try await recovery.load() == nil)
        #expect(try await persistent.load() == nil)

        _ = try await writer.applyConfigurationOrdering(
            plan, confirmedFingerprint: plan.fingerprint, policyChange: forward, policyStore: interface
        )
        #expect(try await persistent.load() == forward.newPolicy)
        #expect(try await persistent.loadBackup()?.previousPolicy == initial)
        #expect(try await recovery.load()?.hasConfigurationUndo == true)
        #expect(try await recovery.load()?.isPendingRestoration == false)

        let reopened = try makeStore(directory)
        #expect(try await reopened.load() == forward.newPolicy)
        #expect(try await reopened.loadBackup()?.previousPolicy == initial)
        if stopped {
            await writer.restoreAndStop()
            _ = try #require(await reopened.disableManualTrialManagementPreservingBackup())
        }
        let core = PolicyEditingCore(store: interface, blennyBundleIdentifier: "xyz.fi5h.blenny",
            scope: scope, writerProvider: { writer })
        let inverse = try #require(await core.previewUndoKeepingManagementState(
            targetPolicy: initial, candidates: inventory,
            observedRunningBundleIdentifiers: Set(scope.approvedBundleIdentifiers),
            runtimeContractFingerprint: "first-launch-test"
        ).1)
        let expected = try initial.settingManagementEnabled(!stopped)
        #expect(inverse.newPolicy == expected)
        #expect(inverse.report.newBaselinePlan?.allowedBundleIdentifiers.contains("com.example.owner") == true)
        let restored = try await writer.restoreOrdering(policyStore: interface, policyUndo: inverse)
        #expect(restored.preferencesRestored)
        #expect(try await reopened.load() == expected)
        #expect(try await reopened.loadBackup() == nil)
        #expect(expected.isInitialVisiblePolicy(forBlennyBundleIdentifier: "xyz.fi5h.blenny"))
        #expect(try await recovery.load() == nil)
        #expect(await writer.activePlanSnapshot() == (stopped ? nil : inverse.report.newBaselinePlan))
        let resumeCore = PolicyEditingCore(store: reopened, blennyBundleIdentifier: "xyz.fi5h.blenny",
            scope: PolicyValidationScope(approvedBundleIdentifiers: ["xyz.fi5h.blenny"]),
            writerProvider: { FirstLaunchAssertionWriter() })
        let resumed = try await resumeCore.previewResumeManaging(
            candidates: inventory, observedRunningBundleIdentifiers: Set(scope.approvedBundleIdentifiers))
        #expect(resumed.1 != nil)
    }

    @Test("Snapshot rollback preserves the exact earlier backup, including absence", arguments: [false, true])
    func rollbackPreservesBackup(existingBackup: Bool) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistent = try makeStore(directory)
        let initial = try initialPolicy()
        let proposed = try initial.settingManagementEnabled(true)
        if existingBackup {
            try await persistent.save(proposed)
            try await persistent.save(initial)
        }
        let backup = try await persistent.loadBackup()
        let interface = PolicyInterfaceStore(persistentStore: persistent, initialPolicy: initial)
        try await interface.save(proposed)
        try await interface.restoreSnapshot(document: initial, backup: backup, expecting: proposed)
        #expect(try await persistent.load() == initial)
        #expect(try await persistent.loadBackup() == backup)
    }

    @Test("Noninitial policies still require their recovery backup", arguments: [false, true])
    func noninitialPolicyRequiresBackup(extraOwner: Bool) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try makeStore(directory)
        let policy = try PersistentBundlePolicyDocument(managementEnabled: true, policies: [
            .init(bundleIdentifier: "xyz.fi5h.blenny", policy: .visible)
        ] + (extraOwner ? [.init(bundleIdentifier: "com.example.owner", policy: .visible)] : []),
            bluetoothPolicy: extraOwner ? .visible : .hidden)
        try await store.save(policy)
        #expect(!policy.isInitialVisiblePolicy(forBlennyBundleIdentifier: "xyz.fi5h.blenny"))
        #expect(try await store.loadBackup() == nil)
        let core = PolicyEditingCore(store: store, blennyBundleIdentifier: "xyz.fi5h.blenny",
            scope: PolicyValidationScope(approvedBundleIdentifiers: policy.policies.map(\.bundleIdentifier)),
            writerProvider: { FirstLaunchAssertionWriter() })
        await #expect(throws: PolicyEditingCoreError.previousPolicyBackupMissing) {
            _ = try await core.previewResumeManaging(candidates: PolicyCandidateInventory(observations: []),
                observedRunningBundleIdentifiers: [])
        }
    }

    @Test("Restoring the first backup returns newly assigned owners to implicit Visible")
    func restoreInitialBackup() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistent = try makeStore(directory)
        let initial = try initialPolicy()
        let interface = PolicyInterfaceStore(persistentStore: persistent, initialPolicy: initial)
        let proposed = try PersistentBundlePolicyDocument(managementEnabled: true, policies: [
            .init(bundleIdentifier: "xyz.fi5h.blenny", policy: .visible),
            .init(bundleIdentifier: "com.example.owner", policy: .hidden)
        ])
        try await interface.save(proposed)
        let inventory = PolicyCandidateInventory(observations: [
            .init(bundleIdentifier: "xyz.fi5h.blenny", processIdentifier: 10, menuBarItemCount: 1),
            .init(bundleIdentifier: "com.example.owner", processIdentifier: 11, menuBarItemCount: 1)
        ])
        let core = PolicyEditingCore(store: interface, blennyBundleIdentifier: "xyz.fi5h.blenny",
            scope: PolicyValidationScope(approvedBundleIdentifiers: ["xyz.fi5h.blenny", "com.example.owner"]),
            writerProvider: { FirstLaunchAssertionWriter() })
        let generation = UUID()
        let prepared = try #require(await core.previewRestorePreviousPolicy(
            candidates: inventory, observedRunningBundleIdentifiers: ["xyz.fi5h.blenny", "com.example.owner"],
            candidateGeneration: generation, runtimeContractFingerprint: "first-launch-test"
        ).1)
        let result = try await core.commit(prepared, currentDraft: BundlePolicyDraft(acceptedPolicy: initial),
            candidates: inventory, observedRunningBundleIdentifiers: ["xyz.fi5h.blenny", "com.example.owner"],
            candidateGeneration: generation, runtimeContractFingerprint: "first-launch-test")
        #expect(result.result == .committed(initial))
        #expect(try await persistent.load() == initial)
        #expect(try await persistent.loadBackup()?.previousPolicy == initial)

        let unauthorized = try PersistentBundlePolicyDocument(managementEnabled: false, policies: [
            .init(bundleIdentifier: "xyz.fi5h.blenny", policy: .visible),
            .init(bundleIdentifier: "com.example.unapproved", policy: .hidden)
        ])
        let rejected = try await core.previewUndoKeepingManagementState(targetPolicy: unauthorized,
            candidates: inventory, observedRunningBundleIdentifiers: ["xyz.fi5h.blenny", "com.example.owner"])
        #expect(rejected.1 == nil)
        #expect(rejected.0.issues.contains(.unapprovedBundle("com.example.unapproved")))
        #expect(try await persistent.load() == initial)
    }

    private func makeStore(_ directory: URL) throws -> PersistentBundlePolicyStore {
        try PersistentBundlePolicyStore(
            policyURL: directory.appendingPathComponent("policy.json"),
            backupURL: directory.appendingPathComponent("backup.json")
        )
    }

    private func initialPolicy() throws -> PersistentBundlePolicyDocument {
        try PersistentBundlePolicyDocument(managementEnabled: false, policies: [
            .init(bundleIdentifier: "xyz.fi5h.blenny", policy: .visible)
        ])
    }
}

private struct FirstLaunchReadOnlyBackend: MenuBarOrderingBackend {
    let snapshot: OrderingSnapshot
    func capture() -> OrderingSnapshot { snapshot }
    func writeTable(_ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot) throws {
        Issue.record("A policy-only first Apply must not write ordering preferences")
        throw OrderingTransactionError.unavailable
    }
}

private actor FirstLaunchAssertionWriter: PolicyAssertionWriting {
    var plan: RevealAllowlistPlan?
    func applySessionTransition(with plan: RevealAllowlistPlan) { self.plan = plan }
    func activePlanSnapshot() -> RevealAllowlistPlan? { plan }
    func restoreAndStop() { plan = nil }
    func connectionInvalidated() { plan = nil }
}

private struct FirstLaunchSystemWriter: PersistentSystemItemPlanWriting {
    func applyManagedPlan(_ plan: [String: PersistentSystemItemPresentation]) {}
    func verifyManagedPlan(_ plan: [String: PersistentSystemItemPresentation]) -> Bool { true }
    func finalizeCommittedPlan(_ plan: [String: PersistentSystemItemPresentation]) {}
    func restoreAllManagedItems() -> Bool { true }
}
