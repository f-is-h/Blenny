import Foundation
import Testing

@testable import BlennyCore

@Suite("Persistent bundle policy storage")
struct PersistentBundlePolicyTests {
    private let blenny = "xyz.fi5h.blenny"
    private let legacyBlenny = "com.example.BlennyProbe"
    private let revealable = "xyz.fi5h.Usage4Claude"
    private let hidden = "pl.maketheweb.cleanshotx"

    @Test("Document encoding is deterministic and preserves three policies")
    func deterministicRoundTrip() throws {
        let document = try makeDocument()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(document)
        let decoded = try JSONDecoder().decode(
            PersistentBundlePolicyDocument.self,
            from: data
        )

        #expect(decoded == document)
        #expect(decoded.schemaVersion == 2)
        #expect(decoded.policies.map(\.bundleIdentifier) == [
            hidden,
            blenny,
            revealable,
        ])
        let encodedText = try #require(String(data: data, encoding: .utf8))
        #expect(encodedText.contains("\"policy\":\"visible\""))
        #expect(!encodedText.contains("\"policy\":\"pinned\""))
    }

    @Test("Schema 1 policy terminology migrates into the unified schema 2 model")
    func legacyTerminologyMigration() throws {
        let json = """
        {
          "schemaVersion": 1,
          "managementEnabled": false,
          "policies": [
            {"bundleIdentifier": "com.example.BlennyProbe", "policy": "pinned"},
            {"bundleIdentifier": "xyz.fi5h.Usage4Claude", "policy": "revealable"}
          ]
        }
        """
        let document = try JSONDecoder().decode(
            PersistentBundlePolicyDocument.self,
            from: Data(json.utf8)
        )

        #expect(document.schemaVersion == 2)
        #expect(document.policies.first?.policy == .visible)
        let encoded = try JSONEncoder().encode(document)
        let encodedText = try #require(String(data: encoded, encoding: .utf8))
        #expect(encodedText.contains("\"policy\":\"visible\""))
        #expect(!encodedText.contains("\"policy\":\"pinned\""))
    }

    @Test("Invalid and case-colliding bundle identifiers fail closed")
    func invalidIdentityFailsClosed() {
        #expect(throws: PersistentBundlePolicyDocumentError.self) {
            _ = try PersistentBundlePolicyDocument(
                managementEnabled: true,
                policies: [
                    .init(bundleIdentifier: "not a bundle", policy: .visible),
                ]
            )
        }
        #expect(throws: PersistentBundlePolicyDocumentError.self) {
            _ = try PersistentBundlePolicyDocument(
                managementEnabled: true,
                policies: [
                    .init(bundleIdentifier: "com..example", policy: .visible),
                ]
            )
        }
        #expect(throws: PersistentBundlePolicyDocumentError.self) {
            _ = try PersistentBundlePolicyDocument(
                managementEnabled: true,
                policies: [
                    .init(bundleIdentifier: revealable, policy: .revealable),
                    .init(bundleIdentifier: revealable.lowercased(), policy: .hidden),
                ]
            )
        }
    }

    @Test("Unsupported schema versions fail closed")
    func unsupportedSchemaFailsClosed() {
        let json = """
        {"schemaVersion":99,"managementEnabled":true,"policies":[]}
        """
        #expect(
            throws: PersistentBundlePolicyDocumentError.unsupportedSchemaVersion(99)
        ) {
            _ = try JSONDecoder().decode(
                PersistentBundlePolicyDocument.self,
                from: Data(json.utf8)
            )
        }
    }

    @Test("Bundle identifier replacement preserves policy and fails closed on collisions")
    func bundleIdentifierReplacement() throws {
        let legacy = try PersistentBundlePolicyDocument(
            managementEnabled: true,
            policies: [
                .init(bundleIdentifier: legacyBlenny, policy: .visible),
                .init(bundleIdentifier: revealable, policy: .revealable),
                .init(bundleIdentifier: hidden, policy: .hidden),
            ]
        )

        let migrated = try legacy.replacingBundleIdentifier(
            from: legacyBlenny,
            with: blenny
        )
        #expect(migrated.managementEnabled)
        #expect(migrated.policies.contains {
            $0.bundleIdentifier == blenny && $0.policy == .visible
        })
        #expect(!migrated.policies.contains { $0.bundleIdentifier == legacyBlenny })
        #expect(
            try migrated.replacingBundleIdentifier(from: legacyBlenny, with: blenny)
                == migrated
        )

        let conflicting = try PersistentBundlePolicyDocument(
            managementEnabled: false,
            policies: [
                .init(bundleIdentifier: legacyBlenny, policy: .visible),
                .init(bundleIdentifier: blenny, policy: .visible),
            ]
        )
        #expect(
            throws: PersistentBundlePolicyDocumentError.duplicateBundleIdentifier(blenny)
        ) {
            _ = try conflicting.replacingBundleIdentifier(
                from: legacyBlenny,
                with: blenny
            )
        }
    }

    @Test("Save, relaunch load, disable, and backup restore are atomic and scoped")
    func storeLifecycle() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BlennyPolicyTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let policyURL = directory.appendingPathComponent("bundle-policies.json")
        let backupURL = directory.appendingPathComponent(
            "bundle-policies.previous.blenny-backup.json"
        )
        let store = try PersistentBundlePolicyStore(
            policyURL: policyURL,
            backupURL: backupURL
        )
        let enabled = try makeDocument()

        try await store.save(enabled)
        #expect(try await store.load() == enabled)
        #expect(try await store.loadBackup() == nil)

        let disabled = try #require(try await store.disableManagement())
        #expect(!disabled.managementEnabled)
        #expect(try await store.load() == disabled)
        #expect(try await store.loadBackup()?.previousPolicy == enabled)

        let backupText = try String(contentsOf: backupURL, encoding: .utf8)
        #expect(backupText.contains(revealable))
        #expect(backupText.contains(hidden))
        #expect(!backupText.contains("processIdentifier"))
        #expect(!backupText.contains("/Applications/"))
        #expect(!backupText.contains("ownerPID"))

        #expect(try await store.restoreBackup() == enabled)
        #expect(try await store.load() == enabled)
        #expect(try await store.restoreBackup() == enabled)
        #expect(try await store.loadBackup()?.previousPolicy == enabled)

        let attributes = try FileManager.default.attributesOfItem(atPath: policyURL.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        let backupAttributes = try FileManager.default.attributesOfItem(atPath: backupURL.path)
        #expect((backupAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect(
            try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasSuffix(".blenny-backup.json") }
                .count == 1
        )
    }

    @Test("Store migration updates accepted policy and backup once without rotating recovery")
    func storeBundleIdentifierMigration() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BlennyIdentityMigrationTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let policyURL = directory.appendingPathComponent("bundle-policies.json")
        let backupURL = directory.appendingPathComponent(
            "bundle-policies.previous.blenny-backup.json"
        )
        let store = try PersistentBundlePolicyStore(
            policyURL: policyURL,
            backupURL: backupURL
        )
        let legacyPolicyJSON = """
        {
          "schemaVersion": 1,
          "managementEnabled": false,
          "policies": [
            {"bundleIdentifier": "\(legacyBlenny)", "policy": "pinned"},
            {"bundleIdentifier": "\(revealable)", "policy": "revealable"},
            {"bundleIdentifier": "\(hidden)", "policy": "hidden"}
          ]
        }
        """
        let legacyBackupJSON = """
        {
          "schemaVersion": 1,
          "previousPolicy": {
            "schemaVersion": 1,
            "managementEnabled": true,
            "policies": [
              {"bundleIdentifier": "\(legacyBlenny)", "policy": "pinned"},
              {"bundleIdentifier": "\(revealable)", "policy": "revealable"},
              {"bundleIdentifier": "\(hidden)", "policy": "hidden"}
            ]
          }
        }
        """
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try Data(legacyPolicyJSON.utf8).write(to: policyURL)
        try Data(legacyBackupJSON.utf8).write(to: backupURL)

        #expect(
            try await store.migrateBundleIdentifier(from: legacyBlenny, to: blenny)
        )
        let migratedPolicy = try #require(try await store.load())
        let migratedBackup = try #require(try await store.loadBackup())
        #expect(!migratedPolicy.managementEnabled)
        #expect(migratedBackup.previousPolicy.managementEnabled)
        for document in [migratedPolicy, migratedBackup.previousPolicy] {
            #expect(document.policies.contains {
                $0.bundleIdentifier == blenny && $0.policy == .visible
            })
            #expect(!document.policies.contains { $0.bundleIdentifier == legacyBlenny })
        }

        let policyData = try Data(contentsOf: policyURL)
        let backupData = try Data(contentsOf: backupURL)
        #expect(
            try await store.migrateBundleIdentifier(from: legacyBlenny, to: blenny) == false
        )
        #expect(try Data(contentsOf: policyURL) == policyData)
        #expect(try Data(contentsOf: backupURL) == backupData)

        let policyAttributes = try FileManager.default.attributesOfItem(
            atPath: policyURL.path
        )
        let backupAttributes = try FileManager.default.attributesOfItem(
            atPath: backupURL.path
        )
        #expect((policyAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect((backupAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    }

    @Test("No-op save does not rewrite accepted policy or rotate recovery")
    func noOpSavePreservesFiles() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BlennyPolicyNoOp-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let policyURL = directory.appendingPathComponent("bundle-policies.json")
        let backupURL = directory.appendingPathComponent("previous.blenny-backup.json")
        let store = try PersistentBundlePolicyStore(
            policyURL: policyURL,
            backupURL: backupURL
        )
        let enabled = try makeDocument()
        try await store.save(enabled)
        let disabled = try #require(try await store.disableManagement())
        let policyData = try Data(contentsOf: policyURL)
        let backupData = try Data(contentsOf: backupURL)
        let transactionPath = await store.transactionURL.path

        try await store.save(disabled)

        #expect(try Data(contentsOf: policyURL) == policyData)
        #expect(try Data(contentsOf: backupURL) == backupData)
        #expect(!FileManager.default.fileExists(atPath: transactionPath))
    }

    @Test("Interrupted persistence restores old backup before commit and completes after commit")
    func interruptedPersistenceRecovery() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BlennyPolicyRecovery-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let policyURL = directory.appendingPathComponent("bundle-policies.json")
        let backupURL = directory.appendingPathComponent("previous.blenny-backup.json")
        let store = try PersistentBundlePolicyStore(
            policyURL: policyURL,
            backupURL: backupURL
        )
        let enabled = try makeDocument()
        try await store.save(enabled)
        let oldPolicy = try #require(try await store.disableManagement())
        let oldPolicyData = try Data(contentsOf: policyURL)
        let oldBackupData = try Data(contentsOf: backupURL)
        let newPolicy = try PersistentBundlePolicyDocument(
            managementEnabled: true,
            policies: [
                .init(bundleIdentifier: blenny, policy: .visible),
                .init(bundleIdentifier: hidden, policy: .revealable),
                .init(bundleIdentifier: revealable, policy: .hidden),
            ]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let newPolicyData = try encoder.encode(newPolicy)
        let newBackupData = try encoder.encode(
            PersistentBundlePolicyBackup(previousPolicy: oldPolicy)
        )
        let marker = PersistentBundlePolicyTransactionMarker(
            oldPolicyData: oldPolicyData,
            newPolicyHash: PersistentBundlePolicyStore.hash(newPolicyData),
            oldBackupData: oldBackupData,
            newBackupData: newBackupData
        )
        let markerURL = await store.transactionURL

        try encoder.encode(marker).write(to: markerURL, options: .atomic)
        try newBackupData.write(to: backupURL, options: .atomic)
        let recoveredBeforeCommit = try PersistentBundlePolicyStore(
            policyURL: policyURL,
            backupURL: backupURL
        )
        #expect(try await recoveredBeforeCommit.load() == oldPolicy)
        #expect(try Data(contentsOf: backupURL) == oldBackupData)
        #expect(!FileManager.default.fileExists(atPath: markerURL.path))

        try encoder.encode(marker).write(to: markerURL, options: .atomic)
        try newBackupData.write(to: backupURL, options: .atomic)
        try newPolicyData.write(to: policyURL, options: .atomic)
        let recoveredAfterCommit = try PersistentBundlePolicyStore(
            policyURL: policyURL,
            backupURL: backupURL
        )
        #expect(try await recoveredAfterCommit.load() == newPolicy)
        #expect(try await recoveredAfterCommit.loadBackup()?.previousPolicy == oldPolicy)
        #expect(!FileManager.default.fileExists(atPath: markerURL.path))
    }

    @Test("Policy and backup paths cannot alias")
    func storePathsMustDiffer() {
        let url = URL(fileURLWithPath: "/tmp/blenny-policy-test.json")
        #expect(throws: PersistentBundlePolicyStoreError.policyAndBackupPathsMustDiffer) {
            _ = try PersistentBundlePolicyStore(policyURL: url, backupURL: url)
        }
    }

    private func makeDocument() throws -> PersistentBundlePolicyDocument {
        try PersistentBundlePolicyDocument(
            managementEnabled: true,
            policies: [
                .init(bundleIdentifier: revealable, policy: .revealable),
                .init(bundleIdentifier: blenny, policy: .visible),
                .init(bundleIdentifier: hidden, policy: .hidden),
            ]
        )
    }
}
