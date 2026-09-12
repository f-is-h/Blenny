import Foundation
import Testing
@testable import BlennyCore

@Suite("Exact policy snapshot compensation")
struct PolicySnapshotRestorationTests {
    @Test func restoresEarlierBackupInsteadOfRejectedPolicy() async throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let prior = try policy(.visible)
        let original = try policy(.revealable)
        let rejected = try policy(.hidden)
        try await fixture.store.save(prior)
        try await fixture.store.save(original)
        let backup = try await fixture.store.loadBackup()
        try await fixture.store.save(rejected)
        try await fixture.store.restoreSnapshot(document: original, backup: backup, expecting: rejected)
        #expect(try await fixture.store.load() == original)
        #expect(try await fixture.store.loadBackup()?.previousPolicy == prior)
        #expect(!FileManager.default.fileExists(atPath: fixture.transactionURL.path))
    }

    @Test func restoresAbsentBackupAndIsIdempotent() async throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let original = try policy(.visible), rejected = try policy(.hidden)
        try await fixture.store.save(original)
        try await fixture.store.save(rejected)
        try await fixture.store.restoreSnapshot(document: original, backup: nil, expecting: rejected)
        try await fixture.store.restoreSnapshot(document: original, backup: nil, expecting: rejected)
        #expect(try await fixture.store.load() == original)
        #expect(try await fixture.store.loadBackup() == nil)
    }

    @Test func refusesForeignPolicyWithoutReplacingEitherFile() async throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let original = try policy(.visible), rejected = try policy(.hidden)
        let foreign = try policy(.revealable)
        try await fixture.store.save(original)
        try await fixture.store.save(foreign)
        let backup = try await fixture.store.loadBackup()
        await #expect(throws: PersistentBundlePolicyStoreError.interruptedTransactionStateMismatch) {
            try await fixture.store.restoreSnapshot(document: original, backup: nil, expecting: rejected)
        }
        #expect(try await fixture.store.load() == foreign)
        #expect(try await fixture.store.loadBackup() == backup)
    }

    @Test func interruptedRestorationFinishesExactBackupAbsence() async throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let original = try policy(.visible), rejected = try policy(.hidden)
        try await fixture.store.save(original)
        try await fixture.store.save(rejected)
        let restoredData = try JSONEncoder().encode(original)
        let marker = PersistentBundlePolicyTransactionMarker(
            oldPolicyData: try Data(contentsOf: fixture.policyURL),
            newPolicyHash: PersistentBundlePolicyStore.hash(restoredData),
            oldBackupData: try Data(contentsOf: fixture.backupURL),
            newBackupData: nil, schemaVersion: 2
        )
        try JSONEncoder().encode(marker).write(to: fixture.transactionURL)
        try restoredData.write(to: fixture.policyURL)
        let recovered = try PersistentBundlePolicyStore(
            policyURL: fixture.policyURL, backupURL: fixture.backupURL
        )
        #expect(try await recovered.load() == original)
        #expect(try await recovered.loadBackup() == nil)
    }

    private func policy(_ intent: MenuBarBundlePolicy) throws -> PersistentBundlePolicyDocument {
        try PersistentBundlePolicyDocument(managementEnabled: true, policies: [
            .init(bundleIdentifier: "xyz.fi5h.blenny", policy: .visible),
            .init(bundleIdentifier: "example.owner", policy: intent)
        ])
    }

    private struct Fixture {
        let directory: URL
        var policyURL: URL { directory.appendingPathComponent("policy.json") }
        var backupURL: URL { directory.appendingPathComponent("backup.json") }
        var transactionURL: URL { directory.appendingPathComponent(".policy.json.transaction") }
        let store: PersistentBundlePolicyStore
        init() throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            store = try PersistentBundlePolicyStore(
                policyURL: directory.appendingPathComponent("policy.json"),
                backupURL: directory.appendingPathComponent("backup.json")
            )
        }
    }
}
