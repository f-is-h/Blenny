import Foundation
import Testing

@testable import BlennyCore

@Suite("Persistent bundle policy storage")
struct PersistentBundlePolicyTests {
    private let blenny = "com.example.BlennyProbe"
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
        #expect(decoded.policies.map(\.bundleIdentifier) == [
            blenny,
            hidden,
            revealable,
        ])
    }

    @Test("Invalid and case-colliding bundle identifiers fail closed")
    func invalidIdentityFailsClosed() {
        #expect(throws: PersistentBundlePolicyDocumentError.self) {
            _ = try PersistentBundlePolicyDocument(
                managementEnabled: true,
                policies: [
                    .init(bundleIdentifier: "not a bundle", policy: .pinned),
                ]
            )
        }
        #expect(throws: PersistentBundlePolicyDocumentError.self) {
            _ = try PersistentBundlePolicyDocument(
                managementEnabled: true,
                policies: [
                    .init(bundleIdentifier: "com..example", policy: .pinned),
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
                .init(bundleIdentifier: blenny, policy: .pinned),
                .init(bundleIdentifier: hidden, policy: .hidden),
            ]
        )
    }
}
