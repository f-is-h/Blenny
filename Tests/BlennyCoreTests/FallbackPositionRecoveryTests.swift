#if BLENNY_PRODUCT || DEBUG
import Foundation
import Testing
@testable import BlennyCore

@Suite("Fallback experiment recovery")
struct FallbackPositionRecoveryTests {
    private func directory() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("LocalData/FallbackRecoveryTests/\(UUID().uuidString)")
    }

    fileprivate func receipt() throws -> FallbackPositionReceipt {
        let process = OrderingProcess(bundleIdentifier: "xyz.fi5h.blenny",
            executableName: "Blenny", pid: 101, launchTime: Date(timeIntervalSince1970: 100), isSystem: false)
        let snapshot = try OrderingSnapshot(
            group: [OrderingSnapshot.tableKey: .dictionary([FallbackPositionDelta.key: .integer(800),
                FallbackPositionDelta.fishKey: .integer(900)])],
            beforeProcesses: [process], afterProcesses: [process], observationsByPID: [:],
            osBuild: OrderingSnapshot.supportedBuild, architecture: OrderingSnapshot.supportedArchitecture,
            runtimeContractVerified: true, displaySignature: "fixture", displayCount: 1,
            displayFrame: RectSnapshot(x: 0, y: 0, width: 1440, height: 24),
            lifecycleGeneration: 1, policyFingerprint: "fixture",
            orderingAllowedBundleIdentifiers: [], capturedAt: Date())
        return try FallbackPositionReceipt(
            delta: FallbackPositionDelta(original: .integer(800), proposed: .real(680.5)),
            baseline: snapshot)
    }

    @Test("The boundary includes Revealable system items and ignores fish placement")
    func systemBoundary() throws {
        let seed = try receipt().baseline
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(seed)) as? [String: Any])
        let table: [String: OrderingValue] = [FallbackPositionDelta.key: .integer(800),
            "status:xyz.fi5h.blenny::Blenny.Fish": .integer(900),
            "module:WiFi": .real(700), "module:Bluetooth": .real(750), "module:Sound": .real(650),
            ExactSystemOrderingItem.siri.configurationKey: .real(600)]
        json["group"] = try JSONSerialization.jsonObject(with:
            JSONEncoder().encode([OrderingSnapshot.tableKey: OrderingValue.dictionary(table)]))
        let snapshot = try JSONDecoder().decode(OrderingSnapshot.self,
            from: JSONSerialization.data(withJSONObject: json))
        let policy = try PersistentBundlePolicyDocument(managementEnabled: true, policies: [],
            bluetoothPolicy: .revealable,
            systemItemPolicies: [ExactSystemOrderingItem.wifi.observationIdentifier: .revealable,
                ExactSystemOrderingItem.siri.observationIdentifier: .revealable])
        let result = try FallbackBoundaryCandidate.make(snapshot: snapshot, policy: policy)
        #expect(result.revealableKey == "module:WiFi")
        #expect(result.visibleKey == "module:Sound")
        #expect(result.delta.proposed == .real(675))
        let pair = try FallbackBoundaryCandidate.make(snapshot: snapshot, policy: policy, includeFish: true)
        #expect(pair.delta.fishOriginal == .integer(900))
        #expect(try FallbackPositionReceipt(delta: pair.delta, baseline: snapshot).schemaVersion == 2)
        let moved = try pair.delta.applying(to: snapshot.table())
        json["group"] = try JSONSerialization.jsonObject(with:
            JSONEncoder().encode([OrderingSnapshot.tableKey: OrderingValue.dictionary(moved)]))
        let positioned = try JSONDecoder().decode(OrderingSnapshot.self,
            from: JSONSerialization.data(withJSONObject: json))
        #expect(throws: FallbackPositionDelta.Failure.unchangedPosition) {
            try FallbackBoundaryCandidate.make(snapshot: positioned, policy: policy, includeFish: true)
        }
    }

    @Test("An unattributed visible item blocks a claimed complete control boundary")
    func unattributedBoundary() throws {
        let seed = try receipt().baseline
        let process = OrderingProcess(bundleIdentifier: nil,
            executableName: "wine", pid: 1972,
            launchTime: Date(timeIntervalSince1970: 100), isSystem: false)
        let observation = OrderingOwnerObservation(process: process,
            displayName: "Wine", axComplete: true,
            itemFrames: [RectSnapshot(x: 810, y: 3, width: 22, height: 22)],
            ownerPreferencesComplete: false, ownerSavedPositions: [:])
        let snapshot = try OrderingSnapshot(group: seed.group,
            beforeProcesses: seed.beforeProcesses + [process],
            afterProcesses: seed.afterProcesses + [process],
            observationsByPID: [process.pid: observation],
            osBuild: seed.osBuild, architecture: seed.architecture,
            runtimeContractVerified: seed.runtimeContractVerified,
            displaySignature: seed.displaySignature, displayCount: seed.displayCount,
            displayFrame: seed.displayFrame,
            lifecycleGeneration: seed.lifecycleGeneration,
            policyFingerprint: seed.policyFingerprint,
            orderingAllowedBundleIdentifiers: seed.orderingAllowedBundleIdentifiers,
            capturedAt: seed.capturedAt)
        let policy = try PersistentBundlePolicyDocument(managementEnabled: true, policies: [])
        #expect(throws: FallbackBoundaryCandidate.Failure.unattributedItems) {
            try FallbackBoundaryCandidate.make(snapshot: snapshot, policy: policy,
                includeFish: true)
        }
    }

    @Test("An explicitly supplied private export can be assessed without launching the app")
    func localEvidence() throws {
        guard let path = ProcessInfo.processInfo.environment["BLENNY_BOUNDARY_FIXTURE_PATH"] else { return }
        struct Export: Decodable {
            let ordering: OrderingSnapshot
            let acceptedPolicy: PersistentBundlePolicyDocument
            let contextUnchanged: Bool
        }
        let export = try JSONDecoder().decode(Export.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        #expect(export.contextUnchanged)
        let result = try FallbackBoundaryCandidate.make(snapshot: export.ordering, policy: export.acceptedPolicy)
        print("Private boundary candidate:", result.revealableKey, result.visibleKey, result.delta.proposed)
        let changed = try result.delta.applying(to: export.ordering.table())
        #expect(try result.delta.restoring(in: changed) == export.ordering.table())
    }

    @Test("Coordinator writes only after durable intent and verifies its independent inverse")
    func coordinatedInverse() async throws {
        let path = directory()
        defer { try? FileManager.default.removeItem(at: path) }
        let record = try receipt()
        let recovery = FallbackPositionRecoveryStore(directory: path.appendingPathComponent("fallback"))
        let ordering = OrderingRecoveryStore(directory: path.appendingPathComponent("ordering"))
        let backend = FallbackTestBackend(record.baseline, recovery: recovery)
        let coordinator = CoordinatedPolicyWriter(assertionWriter: FallbackTestAssertion(),
            persistentWriter: FallbackTestPersistent(), orderingBackend: backend,
            orderingRecovery: ordering, fallbackRecovery: recovery)
        let result = try await coordinator.applyFallbackPosition(record.delta,
            baseline: record.baseline, identity: backend.identity)
        #expect(try result.table()[FallbackPositionDelta.key] == record.delta.proposed)
        #expect(await coordinator.hasPendingRestoration())
        await #expect(throws: OrderingTransactionError.recoveryRequired) {
            try await coordinator.restoreOrdering()
        }
        _ = try await coordinator.restoreFallbackPosition()
        #expect(try await backend.capture().table()[FallbackPositionDelta.key] == record.delta.original)
        #expect(await backend.writes == 2)
        #expect(try await recovery.load() == nil)
        #expect(try await ordering.load() == nil)
    }

    @Test("An acknowledged write failure receives exactly one durable inverse")
    func failedWrite() async throws {
        let path = directory()
        defer { try? FileManager.default.removeItem(at: path) }
        let record = try receipt()
        let recovery = FallbackPositionRecoveryStore(directory: path.appendingPathComponent("fallback"))
        let backend = FallbackTestBackend(record.baseline, recovery: recovery, failAfterFirstWrite: true)
        let coordinator = CoordinatedPolicyWriter(assertionWriter: FallbackTestAssertion(),
            persistentWriter: FallbackTestPersistent(), orderingBackend: backend,
            orderingRecovery: OrderingRecoveryStore(directory: path.appendingPathComponent("ordering")),
            fallbackRecovery: recovery)
        await #expect(throws: OrderingTransactionError.movementNotVerified) {
            try await coordinator.applyFallbackPosition(record.delta,
                baseline: record.baseline, identity: backend.identity)
        }
        #expect(await backend.writes == 2)
        #expect(try await recovery.load() == nil)
        #expect(try await backend.capture().table()[FallbackPositionDelta.key] == record.delta.original)
    }

    @Test("A replaced native instance is rejected before intent or system write")
    func replacedInstance() async throws {
        let path = directory()
        defer { try? FileManager.default.removeItem(at: path) }
        let record = try receipt()
        let recovery = FallbackPositionRecoveryStore(directory: path.appendingPathComponent("fallback"))
        let backend = FallbackTestBackend(record.baseline, recovery: recovery)
        let coordinator = CoordinatedPolicyWriter(assertionWriter: FallbackTestAssertion(),
            persistentWriter: FallbackTestPersistent(), orderingBackend: backend,
            orderingRecovery: OrderingRecoveryStore(directory: path.appendingPathComponent("ordering")),
            fallbackRecovery: recovery)
        let replaced = FallbackNativeIdentity(pid: 101, session: backend.identity.session, instance: 2)
        await #expect(throws: OrderingTransactionError.contextInvalidated) {
            try await coordinator.applyFallbackPosition(record.delta,
                baseline: record.baseline, identity: replaced)
        }
        #expect(await backend.writes == 0)
        #expect(try await recovery.load() == nil)
    }

    @Test("Accepted placement survives Stop and a new coordinator, with explicit Undo")
    func persistentPlacement() async throws {
        let path = directory()
        defer { try? FileManager.default.removeItem(at: path) }
        let record = try receipt()
        let recovery = FallbackPositionRecoveryStore(directory: path.appendingPathComponent("fallback"))
        let ordering = OrderingRecoveryStore(directory: path.appendingPathComponent("ordering"))
        let backend = FallbackTestBackend(record.baseline, recovery: recovery)
        let coordinator = CoordinatedPolicyWriter(assertionWriter: FallbackTestAssertion(),
            persistentWriter: FallbackTestPersistent(), orderingBackend: backend,
            orderingRecovery: ordering, fallbackRecovery: recovery)
        _ = try await coordinator.applyFallbackPosition(record.delta, baseline: record.baseline,
            identity: backend.identity, persistsAfterQuit: true)
        #expect(!(await coordinator.hasPendingRestoration()))
        _ = try await coordinator.restoreOrdering()
        await coordinator.restoreAndStop()
        #expect(await backend.writes == 1)
        #expect(try await recovery.load()?.phase == .applied)
        let restarted = CoordinatedPolicyWriter(assertionWriter: FallbackTestAssertion(),
            persistentWriter: FallbackTestPersistent(), orderingBackend: backend,
            orderingRecovery: ordering, fallbackRecovery: recovery)
        #expect(!(await restarted.hasPendingRestoration()))
        _ = try await restarted.restoreFallbackPosition()
        #expect(await backend.writes == 2)
        #expect(try await backend.capture().table()[FallbackPositionDelta.key] == record.delta.original)
    }

    @Test("Repositioning archives the preceding Undo and restores the most recent baseline")
    func persistentReposition() async throws {
        let path = directory()
        defer { try? FileManager.default.removeItem(at: path) }
        let record = try receipt()
        let recovery = FallbackPositionRecoveryStore(directory: path.appendingPathComponent("fallback"))
        let backend = FallbackTestBackend(record.baseline, recovery: recovery)
        let coordinator = CoordinatedPolicyWriter(assertionWriter: FallbackTestAssertion(),
            persistentWriter: FallbackTestPersistent(), orderingBackend: backend,
            orderingRecovery: OrderingRecoveryStore(directory: path.appendingPathComponent("ordering")),
            fallbackRecovery: recovery)
        let first = try await coordinator.applyFallbackPosition(record.delta, baseline: record.baseline,
            identity: backend.identity, persistsAfterQuit: true)
        let second = try FallbackPositionDelta(original: record.delta.proposed, proposed: .real(670))
        _ = try await coordinator.applyFallbackPosition(second, baseline: first,
            identity: backend.identity, persistsAfterQuit: true)
        let archive = path.appendingPathComponent("fallback/fallback-last-superseded.json")
        let archived = try JSONDecoder().decode(FallbackPositionReceipt.self, from: Data(contentsOf: archive))
        #expect(archived.delta == record.delta)
        #expect(archived.phase == .applied)
        _ = try await coordinator.restoreFallbackPosition()
        #expect(try await backend.capture().table()[FallbackPositionDelta.key] == record.delta.proposed)
        #expect(await backend.writes == 3)
    }

    @Test("Reviewed target drift archives the stale receipt and Undo restores the fresh baseline")
    func reviewedTargetDrift() async throws {
        let path = directory()
        defer { try? FileManager.default.removeItem(at: path) }
        let record = try receipt()
        let recovery = FallbackPositionRecoveryStore(directory: path.appendingPathComponent("fallback"))
        let backend = FallbackTestBackend(record.baseline, recovery: recovery)
        let coordinator = CoordinatedPolicyWriter(assertionWriter: FallbackTestAssertion(),
            persistentWriter: FallbackTestPersistent(), orderingBackend: backend,
            orderingRecovery: OrderingRecoveryStore(directory: path.appendingPathComponent("ordering")),
            fallbackRecovery: recovery)
        let first = try await coordinator.applyFallbackPosition(record.delta, baseline: record.baseline,
            identity: backend.identity, persistsAfterQuit: true)
        let reviewed = try #require(try await recovery.load())
        var table = try first.table()
        table[FallbackPositionDelta.key] = .real(710)
        try await backend.replaceConfiguration(table)
        let fresh = await backend.capture()
        let second = try FallbackPositionDelta(original: .real(710), proposed: .real(670))
        await #expect(throws: FallbackPositionDelta.Failure.targetDrift) {
            _ = try await coordinator.applyFallbackPosition(second, baseline: fresh,
                identity: backend.identity, persistsAfterQuit: true)
        }
        #expect(await backend.writes == 1)
        _ = try await coordinator.applyFallbackPosition(second, baseline: fresh,
            identity: backend.identity, persistsAfterQuit: true, reviewedPreviousReceipt: reviewed)
        let archive = path.appendingPathComponent("fallback/fallback-last-superseded.json")
        let archived = try JSONDecoder().decode(FallbackPositionReceipt.self, from: Data(contentsOf: archive))
        #expect(archived.delta == record.delta)
        #expect(archived.phase == .applied)
        _ = try await coordinator.restoreFallbackPosition()
        #expect(try await backend.capture().table()[FallbackPositionDelta.key] == .real(710))
        #expect(await backend.writes == 3)
    }

    @Test("Adding fish placement upgrades an arrow-only journal and leaves the arrow fixed")
    func addFishToAcceptedArrow() async throws {
        let path = directory()
        defer { try? FileManager.default.removeItem(at: path) }
        let record = try receipt()
        let recovery = FallbackPositionRecoveryStore(directory: path.appendingPathComponent("fallback"))
        let backend = FallbackTestBackend(record.baseline, recovery: recovery)
        let coordinator = CoordinatedPolicyWriter(assertionWriter: FallbackTestAssertion(),
            persistentWriter: FallbackTestPersistent(), orderingBackend: backend,
            orderingRecovery: OrderingRecoveryStore(directory: path.appendingPathComponent("ordering")),
            fallbackRecovery: recovery)
        let arrow = try await coordinator.applyFallbackPosition(record.delta, baseline: record.baseline,
            identity: backend.identity, persistsAfterQuit: true)
        let pair = try FallbackPositionDelta(original: record.delta.proposed, proposed: record.delta.proposed,
            fishOriginal: .integer(900), fishProposed: .real(660))
        let positioned = try await coordinator.applyFallbackPosition(pair, baseline: arrow,
            identity: backend.identity, persistsAfterQuit: true)
        #expect(try positioned.table()[FallbackPositionDelta.key] == record.delta.proposed)
        #expect(try positioned.table()[FallbackPositionDelta.fishKey] == .real(660))
        #expect(try await recovery.load()?.schemaVersion == 2)
        _ = try await coordinator.restoreFallbackPosition()
        #expect(await backend.capture().group == arrow.group)
    }

    @Test("Accepted controls follow a boundary shifted by one or two reassigned slots")
    func boundaryAfterApply() async throws {
        let path = directory()
        defer { try? FileManager.default.removeItem(at: path) }
        let recovery = FallbackPositionRecoveryStore(directory: path.appendingPathComponent("fallback"))
        let backend = FallbackTestBackend(try receipt().baseline, recovery: recovery)
        let coordinator = CoordinatedPolicyWriter(assertionWriter: FallbackTestAssertion(),
            persistentWriter: FallbackTestPersistent(), orderingBackend: backend,
            orderingRecovery: OrderingRecoveryStore(directory: path.appendingPathComponent("ordering")),
            fallbackRecovery: recovery)
        let policy = try PersistentBundlePolicyDocument(managementEnabled: true, policies: [],
            bluetoothPolicy: .revealable,
            systemItemPolicies: [ExactSystemOrderingItem.wifi.observationIdentifier: .revealable])
        var table = try await backend.capture().table()
        table["module:Sound"] = .real(650)
        table["module:WiFi"] = .real(700)
        table["module:Bluetooth"] = .real(750)
        try await backend.replaceConfiguration(table)
        #expect(try await coordinator.updateAcceptedControlBoundary(policy: policy) == nil)
        #expect(await backend.writes == 0)
        let before = await backend.capture()
        let placement = try FallbackBoundaryCandidate.make(snapshot: before, policy: policy, includeFish: true)
        _ = try await coordinator.applyFallbackPosition(placement.delta, baseline: before,
            identity: backend.identity, persistsAfterQuit: true)
        for count in [1, 2] {
            var rearranged = try await backend.capture().table()
            let visible = Double(650 - 50 * count)
            let revealable = Double(700 - 50 * count)
            rearranged["module:Sound"] = .real(visible)
            rearranged["module:WiFi"] = .real(revealable)
            try await backend.replaceConfiguration(rearranged)
            let result = try #require(try await coordinator.updateAcceptedControlBoundary(policy: policy))
            let values = try result.table()
            guard case let .real(arrow)? = values[FallbackPositionDelta.key],
                  case let .real(fish)? = values[FallbackPositionDelta.fishKey] else {
                Issue.record("Missing control positions")
                return
            }
            #expect(visible < fish && fish < arrow && arrow < revealable)
            for key in rearranged.keys where key != FallbackPositionDelta.key && key != FallbackPositionDelta.fishKey {
                #expect(values[key] == rearranged[key])
            }
            let writes = await backend.writes
            #expect(try await coordinator.updateAcceptedControlBoundary(policy: policy) == nil)
            #expect(await backend.writes == writes)
        }
        var committedApps = try await backend.capture().table()
        committedApps["module:Sound"] = .real(500)
        committedApps["module:WiFi"] = .real(550)
        try await backend.replaceConfiguration(committedApps)
        await backend.failNextWrite()
        await #expect(throws: OrderingTransactionError.movementNotVerified) {
            try await coordinator.updateAcceptedControlBoundary(policy: policy)
        }
        #expect(try await backend.capture().table() == committedApps)
    }

    @Test("Old trial receipts without the persistence field still require recovery")
    func legacyTemporaryReceipt() throws {
        var old = try receipt()
        old.phase = .applied
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        json.removeValue(forKey: "persistsAfterQuit")
        let decoded = try JSONDecoder().decode(FallbackPositionReceipt.self,
            from: JSONSerialization.data(withJSONObject: json))
        try decoded.validate()
        #expect(decoded.isPendingRestoration)
    }

    @Test("Read-only access is inert; writes need a cross-instance exclusive lease")
    func lease() async throws {
        let path = directory()
        defer { try? FileManager.default.removeItem(at: path) }
        let first = FallbackPositionRecoveryStore(directory: path)
        let second = FallbackPositionRecoveryStore(directory: path)
        #expect(try await first.load() == nil)
        #expect(!FileManager.default.fileExists(atPath: path.path))
        let record = try receipt()
        await #expect(throws: OrderingTransactionError.writerOccupied) { try await first.save(record) }
        try await first.acquireLease()
        await #expect(throws: OrderingTransactionError.writerOccupied) { try await second.acquireLease() }
        await first.releaseLease()
        try await second.acquireLease()
        await second.releaseLease()
    }

    @Test("Durable intent survives a new store and completes only after verified restoration")
    func restart() async throws {
        let path = directory()
        defer { try? FileManager.default.removeItem(at: path) }
        let first = FallbackPositionRecoveryStore(directory: path)
        var record = try receipt()
        try await first.acquireLease()
        try await first.save(record)
        await first.releaseLease()
        let restarted = FallbackPositionRecoveryStore(directory: path)
        #expect(try await restarted.load() == record)
        try await restarted.acquireLease()
        await #expect(throws: OrderingTransactionError.invalidReceipt) { try await restarted.complete(record) }
        record.phase = .restoreIntent
        try await restarted.save(record)
        record.phase = .restored
        try await restarted.save(record)
        try await restarted.complete(record)
        #expect(try await restarted.load() == nil)
        let archive = path.appendingPathComponent("fallback-last-restored.json")
        #expect(try JSONDecoder().decode(FallbackPositionReceipt.self, from: Data(contentsOf: archive)) == record)
        let permissions = try FileManager.default.attributesOfItem(atPath: archive.path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)
        #expect(try FileManager.default.attributesOfItem(atPath: path.path)[.posixPermissions] as? Int == 0o700)
        await restarted.releaseLease()
    }

    @Test("Another transaction, skipped restoration and phase rewind cannot overwrite intent")
    func invalidTransitions() async throws {
        let path = directory()
        defer { try? FileManager.default.removeItem(at: path) }
        let store = FallbackPositionRecoveryStore(directory: path)
        let original = try receipt()
        try await store.acquireLease()
        try await store.save(original)
        let other = try receipt()
        await #expect(throws: OrderingTransactionError.recoveryRequired) { try await store.save(other) }
        var next = original
        next.phase = .restored
        await #expect(throws: OrderingTransactionError.recoveryRequired) { try await store.save(next) }
        next.phase = .applied
        try await store.save(next)
        await #expect(throws: OrderingTransactionError.recoveryRequired) { try await store.save(original) }
        #expect(try await store.load() == next)
        await store.releaseLease()
    }

    @Test("A symlink cannot become a recovery directory")
    func symlink() async throws {
        let path = directory()
        let target = directory()
        defer {
            try? FileManager.default.removeItem(at: path)
            try? FileManager.default.removeItem(at: target)
        }
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        try FileManager.default.createSymbolicLink(at: path, withDestinationURL: target)
        let store = FallbackPositionRecoveryStore(directory: path)
        await #expect(throws: OrderingTransactionError.receiptStorageUnavailable) { try await store.acquireLease() }
    }
}

private actor FallbackTestBackend: FallbackPositionWriting {
    nonisolated let identity = FallbackNativeIdentity(pid: 101, session: UUID(), instance: 1)
    private var current: OrderingSnapshot
    private let recovery: FallbackPositionRecoveryStore
    private let failAfterFirstWrite: Bool
    private var failNext = false
    private(set) var writes = 0
    init(_ snapshot: OrderingSnapshot, recovery: FallbackPositionRecoveryStore,
         failAfterFirstWrite: Bool = false) {
        current = snapshot
        self.recovery = recovery
        self.failAfterFirstWrite = failAfterFirstWrite
    }
    func fallbackIdentity() -> FallbackNativeIdentity { identity }
    func capture() -> OrderingSnapshot { current }
    func failNextWrite() { failNext = true }
    func replaceConfiguration(_ table: [String: OrderingValue]) throws {
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any])
        json["group"] = try JSONSerialization.jsonObject(with:
            JSONEncoder().encode([OrderingSnapshot.tableKey: OrderingValue.dictionary(table)]))
        current = try JSONDecoder().decode(OrderingSnapshot.self,
            from: JSONSerialization.data(withJSONObject: json))
    }
    func writeTable(_ table: [String: OrderingValue], expecting: OrderingSnapshot) throws {
        throw OrderingTransactionError.unavailable
    }
    func writeFallbackPosition(_ table: [String: OrderingValue], expecting: OrderingSnapshot,
                               identity: FallbackNativeIdentity) async throws {
        let intent = try await recovery.load()
        #expect(intent?.phase == .applyIntent || intent?.phase == .restoreIntent)
        #expect(table[FallbackPositionDelta.key] ==
            (intent?.phase == .applyIntent ? intent?.delta.proposed : intent?.delta.original))
        #expect(identity == self.identity)
        #expect(expecting == current)
        let encoded = try JSONEncoder().encode(current)
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let group = [OrderingSnapshot.tableKey: OrderingValue.dictionary(table)]
        json["group"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(group))
        current = try JSONDecoder().decode(OrderingSnapshot.self,
            from: JSONSerialization.data(withJSONObject: json))
        writes += 1
        if (failAfterFirstWrite && writes == 1) || failNext {
            failNext = false
            throw OrderingTransactionError.movementNotVerified
        }
    }
}

private actor FallbackTestAssertion: PolicyAssertionWriting {
    func applySessionTransition(with plan: RevealAllowlistPlan) async throws {}
    func restoreAndStop() async {}
    func connectionInvalidated() async {}
    func activePlanSnapshot() async -> RevealAllowlistPlan? { nil }
}

private actor FallbackTestPersistent: PersistentSystemItemPlanWriting {
    func applyManagedPlan(_ plan: [String: PersistentSystemItemPresentation]) async throws {}
    func verifyManagedPlan(_ plan: [String: PersistentSystemItemPresentation]) async throws -> Bool { true }
    func finalizeCommittedPlan(_ plan: [String: PersistentSystemItemPresentation]) async {}
    func restoreAllManagedItems() async -> Bool { true }
}
#endif
