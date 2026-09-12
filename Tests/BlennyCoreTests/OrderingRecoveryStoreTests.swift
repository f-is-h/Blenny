#if DEBUG
import Darwin
import Foundation
import Testing

@testable import BlennyCore

@Suite("Debug ordering recovery store")
struct OrderingRecoveryStoreTests {
    private enum FixtureError: Error {
        case invalidIdentifier
    }

    @Test("Read-only load creates neither a directory nor a receipt")
    func readOnlyLoadCreatesNothing() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OrderingRecoveryStore(directory: directory)

        #expect(try await store.load() == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test("Saving requires an exclusive ordering lease")
    func saveRequiresLease() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OrderingRecoveryStore(directory: directory)
        let receipt = try makeReceipt(id: "00000000-0000-0000-0000-000000000001")

        await expectError(.writerOccupied) {
            try await store.save(receipt)
        }
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test("A lease is nonblocking across separate store instances")
    func crossInstanceLeaseIsNonblocking() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = OrderingRecoveryStore(directory: directory)
        let second = OrderingRecoveryStore(directory: directory)

        try await first.acquireLease()
        await expectError(.writerOccupied) {
            try await second.acquireLease()
        }
        await first.releaseLease()

        try await second.acquireLease()
        await second.releaseLease()
    }

    @Test("A durable receipt round-trips with private directory and file modes")
    func durableReceiptRoundTripUsesPrivateModes() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OrderingRecoveryStore(directory: directory)
        let receipt = try makeReceipt(id: "00000000-0000-0000-0000-000000000002")

        try await store.acquireLease()
        try await store.save(receipt)

        #expect(try await store.load() == receipt)
        #expect(try permissions(of: directory) == 0o700)
        #expect(try permissions(of: directory.appendingPathComponent("ordering.lock")) == 0o600)
        #expect(
            try permissions(of: directory.appendingPathComponent("ordering-recovery.json"))
                == 0o600
        )
        await store.releaseLease()
    }

    @Test("A different plan cannot replace an outstanding receipt")
    func wrongPlanCannotReplaceOutstandingReceipt() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OrderingRecoveryStore(directory: directory)
        let first = try makeReceipt(id: "00000000-0000-0000-0000-000000000003")
        let replacement = try makeReceipt(id: "00000000-0000-0000-0000-000000000004")

        try await store.acquireLease()
        try await store.save(first)

        await expectError(.recoveryRequired) {
            try await store.save(replacement)
        }
        #expect(try await store.load() == first)
        await store.releaseLease()
    }

    @Test("Completing a restored receipt archives it and removes the active record")
    func completionArchivesAndRemovesActiveReceipt() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OrderingRecoveryStore(directory: directory)
        let applyIntent = try makeReceipt(id: "00000000-0000-0000-0000-000000000005")
        var restored = applyIntent
        restored.phase = .preferencesRestored
        restored.detail = "Exact target positions restored."

        try await store.acquireLease()
        try await store.save(applyIntent)
        try await store.save(restored)
        try await store.complete(restored)

        #expect(try await store.load() == nil)
        let archive = directory.appendingPathComponent("ordering-last-restored.json")
        #expect(FileManager.default.fileExists(atPath: archive.path))
        #expect(try JSONDecoder().decode(OrderingRecoveryReceipt.self, from: Data(contentsOf: archive)) == restored)
        #expect(try permissions(of: archive) == 0o600)
        await store.releaseLease()
    }

    @Test("Superseding a clean Undo ledger archives it before installing a new session")
    func supersedeCleanLedgerArchivesExactReceipt() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OrderingRecoveryStore(directory: directory)
        let recovery: any OrderingRecoveryStoring = store
        let (clean, replacement) = try makeCleanAndReplacementReceipts()

        try await store.acquireLease()
        try await store.save(clean)
        try await recovery.supersedeClean(clean, with: replacement)

        #expect(try await store.load() == replacement)
        let archive = directory.appendingPathComponent("ordering-last-superseded.json")
        #expect(FileManager.default.fileExists(atPath: archive.path))
        #expect(
            try JSONDecoder().decode(
                OrderingRecoveryReceipt.self, from: Data(contentsOf: archive)
            ) == clean
        )
        #expect(try permissions(of: archive) == 0o600)
        await store.releaseLease()
    }

    @Test("Malformed receipts are preserved and refused")
    func malformedReceiptIsRefused() async throws {
        let directory = try makePrivateDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeReceiptBytes(Data("not an ordering receipt".utf8), in: directory, mode: 0o600)

        await expectError(.invalidReceipt) {
            _ = try await OrderingRecoveryStore(directory: directory).load()
        }
    }

    @Test("Oversize, insecure, and symbolic-link receipts are refused")
    func unsafeReceiptFormsAreRefused() async throws {
        let oversizeDirectory = try makePrivateDirectory()
        defer { try? FileManager.default.removeItem(at: oversizeDirectory) }
        try writeReceiptBytes(
            Data(repeating: 0, count: 8 * 1024 * 1024 + 1),
            in: oversizeDirectory,
            mode: 0o600
        )
        await expectError(.receiptStorageUnavailable) {
            _ = try await OrderingRecoveryStore(directory: oversizeDirectory).load()
        }

        let insecureDirectory = try makePrivateDirectory()
        defer { try? FileManager.default.removeItem(at: insecureDirectory) }
        try writeReceiptBytes(Data("{}".utf8), in: insecureDirectory, mode: 0o644)
        await expectError(.receiptStorageUnavailable) {
            _ = try await OrderingRecoveryStore(directory: insecureDirectory).load()
        }

        let symlinkDirectory = try makePrivateDirectory()
        defer { try? FileManager.default.removeItem(at: symlinkDirectory) }
        let destination = symlinkDirectory.appendingPathComponent("outside.json")
        try Data("{}".utf8).write(to: destination)
        try FileManager.default.createSymbolicLink(
            atPath: symlinkDirectory.appendingPathComponent("ordering-recovery.json").path,
            withDestinationPath: destination.path
        )
        await expectError(.receiptStorageUnavailable) {
            _ = try await OrderingRecoveryStore(directory: symlinkDirectory).load()
        }
    }

    @Test("A leased store refuses directory path replacement")
    func leasedDirectoryReplacementIsRefused() async throws {
        let directory = temporaryDirectory()
        let displaced = directory.deletingLastPathComponent().appendingPathComponent(
            directory.lastPathComponent + "-displaced", isDirectory: true
        )
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: displaced)
        }
        let store = OrderingRecoveryStore(directory: directory)
        let receipt = try makeReceipt(id: "00000000-0000-0000-0000-000000000006")

        try await store.acquireLease()
        try await store.save(receipt)
        try FileManager.default.moveItem(at: directory, to: displaced)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: NSNumber(value: 0o700)]
        )

        await expectError(.receiptStorageUnavailable) {
            _ = try await store.load()
        }
        #expect(
            !FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("ordering-recovery.json").path
            )
        )
        await store.releaseLease()
    }

    @Test("A leased store refuses insecure directory permission drift")
    func leasedDirectoryPermissionDriftIsRefused() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OrderingRecoveryStore(directory: directory)
        let receipt = try makeReceipt(id: "00000000-0000-0000-0000-000000000007")

        try await store.acquireLease()
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o755)],
            ofItemAtPath: directory.path
        )
        await expectError(.receiptStorageUnavailable) {
            try await store.save(receipt)
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o700)],
            ofItemAtPath: directory.path
        )
        await store.releaseLease()
    }

    private func makeReceipt(id: String) throws -> OrderingRecoveryReceipt {
        let capturedAt = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let alpha = OrderingProcess(
            bundleIdentifier: "com.example.alpha",
            executableName: "Alpha",
            pid: 101,
            launchTime: capturedAt.addingTimeInterval(-20),
            isSystem: false
        )
        let beta = OrderingProcess(
            bundleIdentifier: "com.example.beta",
            executableName: "Beta",
            pid: 202,
            launchTime: capturedAt.addingTimeInterval(-20),
            isSystem: false
        )
        let alphaKey = "status:com.example.alpha::alpha-item"
        let betaKey = "status:com.example.beta::beta-item"
        let table: [String: OrderingValue] = [
            alphaKey: .integer(100),
            betaKey: .integer(200),
        ]
        let alphaObservation = OrderingOwnerObservation(
            process: alpha,
            displayName: "Alpha",
            axComplete: true,
            itemFrames: [RectSnapshot(x: 20, y: 0, width: 20, height: 22)],
            ownerPreferencesComplete: true,
            ownerSavedPositions: ["alpha-item": .integer(100)]
        )
        let betaObservation = OrderingOwnerObservation(
            process: beta,
            displayName: "Beta",
            axComplete: true,
            itemFrames: [RectSnapshot(x: 80, y: 0, width: 20, height: 22)],
            ownerPreferencesComplete: true,
            ownerSavedPositions: ["beta-item": .integer(200)]
        )
        let snapshot = try OrderingSnapshot(
            group: [OrderingSnapshot.tableKey: .dictionary(table)],
            beforeProcesses: [alpha, beta],
            afterProcesses: [alpha, beta],
            observationsByPID: [101: alphaObservation, 202: betaObservation],
            osBuild: OrderingSnapshot.supportedBuild,
            architecture: OrderingSnapshot.supportedArchitecture,
            runtimeContractVerified: true,
            displaySignature: "test-display",
            displayCount: 1,
            displayFrame: RectSnapshot(x: 0, y: 0, width: 1_440, height: 24),
            lifecycleGeneration: 1,
            policyFingerprint: "test-policy",
            orderingAllowedBundleIdentifiers: ["com.example.alpha", "com.example.beta"],
            capturedAt: capturedAt
        )
        guard let identifier = UUID(uuidString: id) else {
            throw FixtureError.invalidIdentifier
        }
        let plan = try OrderingPlan.make(
            snapshot: snapshot,
            bundleIdentifiers: ["com.example.alpha", "com.example.beta"],
            now: capturedAt.addingTimeInterval(1),
            id: identifier
        )
        return OrderingRecoveryReceipt(plan: plan, phase: .applyIntent)
    }

    private func makeCleanAndReplacementReceipts() throws -> (
        OrderingRecoveryReceipt, OrderingRecoveryReceipt
    ) {
        let seed = try makeReceipt(id: "00000000-0000-0000-0000-000000000008")
        let snapshot = seed.plan.baseline
        let plan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: snapshot,
            orderedBundleIdentifiers: ["com.example.alpha", "com.example.beta"],
            now: snapshot.capturedAt.addingTimeInterval(1),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
        )
        let before = try #require(plan.configurationBeforeValues)
        let after = try #require(plan.configurationAfterValues)
        var clean = OrderingRecoveryReceipt(
            configurationPlan: plan,
            sessionIdentifier: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            originalValues: before, committedValues: before, pendingValues: after
        )
        clean.phase = .applied
        clean.committedValues = after
        clean.pendingValues = nil
        clean.configurationVerified = true
        let replacement = OrderingRecoveryReceipt(
            configurationPlan: plan,
            sessionIdentifier: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            originalValues: after, committedValues: after, pendingValues: before
        )
        try clean.validate()
        try replacement.validate()
        return (clean, replacement)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "BlennyOrderingRecoveryStoreTests-\(UUID().uuidString)",
            isDirectory: true
        )
    }

    private func makePrivateDirectory() throws -> URL {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: NSNumber(value: 0o700)]
        )
        return directory
    }

    private func writeReceiptBytes(_ bytes: Data, in directory: URL, mode: Int16) throws {
        let receipt = directory.appendingPathComponent("ordering-recovery.json")
        try bytes.write(to: receipt)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: mode)],
            ofItemAtPath: receipt.path
        )
    }

    private func permissions(of url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
    }

    private func expectError(
        _ expected: OrderingTransactionError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Expected \(expected), but the operation succeeded.")
        } catch let error as OrderingTransactionError {
            #expect(error == expected)
        } catch {
            Issue.record("Expected \(expected), received \(error).")
        }
    }
}
#endif
