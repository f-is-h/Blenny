#if DEBUG
import Foundation
import Testing
@testable import BlennyCore

@Suite("Sandbox owner preference namespace")
struct SandboxOwnerPreferenceNamespaceTests {
    private var valid: SandboxOwnerPreferenceSourceEvidence {
        SandboxOwnerPreferenceSourceEvidence(
            bundleIdentifier: "com.example.Sandbox",
            signingIdentifier: "com.example.Sandbox",
            homeDirectoryPath: "/fixture-home/tester",
            containerRootPath: "/fixture-home/tester/Library/Containers/com.example.Sandbox",
            dataDirectoryPath: "/fixture-home/tester/Library/Containers/com.example.Sandbox/Data",
            metadataIdentifier: "com.example.Sandbox",
            rootDevice: 10, rootInode: 20,
            dataDevice: 10, dataInode: 21,
            metadataDevice: 10, metadataInode: 22,
            metadataDigest: String(repeating: "a", count: 64)
        )
    }

    @Test("Exact signed owner and standard container produce stable provenance")
    func acceptedSource() throws {
        let first = try #require(SandboxOwnerPreferenceNamespaceValidator.sourceIdentity(for: valid))
        let second = try #require(SandboxOwnerPreferenceNamespaceValidator.sourceIdentity(for: valid))
        #expect(first == second)
        #expect(first.count == 64)
        #expect(first.utf8.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) })
    }

    @Test("Signed and metadata identities must both match exactly")
    func identityMismatch() {
        var evidence = valid
        evidence = replacing(evidence, signingIdentifier: "com.example.Other")
        #expect(SandboxOwnerPreferenceNamespaceValidator.sourceIdentity(for: evidence) == nil)
        evidence = replacing(valid, metadataIdentifier: "com.example.Other")
        #expect(SandboxOwnerPreferenceNamespaceValidator.sourceIdentity(for: evidence) == nil)
    }

    @Test("Traversal, aliases and shared containers are rejected")
    func pathScope() {
        for bundle in ["..", "com.example/Sandbox", "group.com.example.Sandbox"] {
            var evidence = valid
            evidence = replacing(evidence, bundleIdentifier: bundle)
            #expect(SandboxOwnerPreferenceNamespaceValidator.sourceIdentity(for: evidence) == nil)
        }
        var evidence = replacing(
            valid,
            containerRootPath: "/fixture-home/tester/Library/Group Containers/com.example.Sandbox"
        )
        #expect(SandboxOwnerPreferenceNamespaceValidator.sourceIdentity(for: evidence) == nil)
        evidence = replacing(valid, homeDirectoryPath: "/fixture-home/../tester")
        #expect(SandboxOwnerPreferenceNamespaceValidator.sourceIdentity(for: evidence) == nil)
    }

    @Test("Filesystem and metadata identities are fingerprinted")
    func provenanceChanges() throws {
        let baseline = try #require(SandboxOwnerPreferenceNamespaceValidator.sourceIdentity(for: valid))
        let changedRoot = replacing(valid, rootInode: valid.rootInode + 1)
        let changedData = replacing(valid, dataInode: valid.dataInode + 1)
        let changedMetadata = replacing(valid, metadataDigest: String(repeating: "b", count: 64))
        #expect(SandboxOwnerPreferenceNamespaceValidator.sourceIdentity(for: changedRoot) != baseline)
        #expect(SandboxOwnerPreferenceNamespaceValidator.sourceIdentity(for: changedData) != baseline)
        #expect(SandboxOwnerPreferenceNamespaceValidator.sourceIdentity(for: changedMetadata) != baseline)
    }

    @Test("Invalid filesystem facts and hashes are rejected")
    func invalidFacts() {
        #expect(SandboxOwnerPreferenceNamespaceValidator.sourceIdentity(
            for: replacing(valid, rootInode: 0)
        ) == nil)
        #expect(SandboxOwnerPreferenceNamespaceValidator.sourceIdentity(
            for: replacing(valid, metadataDigest: String(repeating: "A", count: 64))
        ) == nil)
    }

    @Test("Descriptor-relative validation accepts a regular standard container")
    func standardContainerFilesystem() throws {
        let fixture = try makeFileSystemFixture()
        defer { try? FileManager.default.removeItem(at: fixture.home) }
        let identity = MacOS27MenuBarOrderingBackend.sandboxContainerSourceIdentityForTesting(
            bundle: fixture.bundle,
            signingIdentifier: fixture.bundle,
            homeDirectoryPath: fixture.home.path
        )
        #expect(identity?.count == 64)
        #expect(MacOS27MenuBarOrderingBackend.sandboxPreferenceFileReadableForTesting(
            bundle: fixture.bundle,
            signingIdentifier: fixture.bundle,
            homeDirectoryPath: fixture.home.path
        ))
    }

    @Test("Container Data and metadata symlinks fail closed")
    func containerSymlinks() throws {
        let manager = FileManager.default
        var fixture = try makeFileSystemFixture()
        defer { try? manager.removeItem(at: fixture.home) }
        let externalData = fixture.home.appendingPathComponent("external-data", isDirectory: true)
        try manager.createDirectory(at: externalData, withIntermediateDirectories: true)
        try manager.removeItem(at: fixture.data)
        try manager.createSymbolicLink(at: fixture.data, withDestinationURL: externalData)
        #expect(MacOS27MenuBarOrderingBackend.sandboxContainerSourceIdentityForTesting(
            bundle: fixture.bundle,
            signingIdentifier: fixture.bundle,
            homeDirectoryPath: fixture.home.path
        ) == nil)

        try manager.removeItem(at: fixture.home)
        fixture = try makeFileSystemFixture()
        let externalMetadata = fixture.home.appendingPathComponent("metadata.plist")
        try metadataData(bundle: fixture.bundle).write(to: externalMetadata)
        try manager.removeItem(at: fixture.metadata)
        try manager.createSymbolicLink(at: fixture.metadata, withDestinationURL: externalMetadata)
        #expect(MacOS27MenuBarOrderingBackend.sandboxContainerSourceIdentityForTesting(
            bundle: fixture.bundle,
            signingIdentifier: fixture.bundle,
            homeDirectoryPath: fixture.home.path
        ) == nil)
    }

    @Test("A preference plist symlink is not an independent source")
    func preferenceSymlink() throws {
        let manager = FileManager.default
        let fixture = try makeFileSystemFixture()
        defer { try? manager.removeItem(at: fixture.home) }
        let external = fixture.home.appendingPathComponent("preferences.plist")
        try preferenceData().write(to: external)
        try manager.removeItem(at: fixture.preferences)
        try manager.createSymbolicLink(at: fixture.preferences, withDestinationURL: external)
        #expect(!MacOS27MenuBarOrderingBackend.sandboxPreferenceFileReadableForTesting(
            bundle: fixture.bundle,
            signingIdentifier: fixture.bundle,
            homeDirectoryPath: fixture.home.path
        ))
    }

    @Test("Replacing validated metadata changes runtime provenance")
    func metadataReplacement() throws {
        let manager = FileManager.default
        let fixture = try makeFileSystemFixture()
        defer { try? manager.removeItem(at: fixture.home) }
        let first = try #require(
            MacOS27MenuBarOrderingBackend.sandboxContainerSourceIdentityForTesting(
                bundle: fixture.bundle,
                signingIdentifier: fixture.bundle,
                homeDirectoryPath: fixture.home.path
            )
        )
        let replacement = try PropertyListSerialization.data(
            fromPropertyList: [
                "MCMMetadataIdentifier": fixture.bundle,
                "MCMMetadataSchemaVersion": 44,
            ],
            format: .binary,
            options: 0
        )
        try manager.removeItem(at: fixture.metadata)
        try replacement.write(to: fixture.metadata)
        let second = try #require(
            MacOS27MenuBarOrderingBackend.sandboxContainerSourceIdentityForTesting(
                bundle: fixture.bundle,
                signingIdentifier: fixture.bundle,
                homeDirectoryPath: fixture.home.path
            )
        )
        #expect(second != first)
    }

    private func replacing(
        _ value: SandboxOwnerPreferenceSourceEvidence,
        bundleIdentifier: String? = nil,
        signingIdentifier: String? = nil,
        homeDirectoryPath: String? = nil,
        containerRootPath: String? = nil,
        dataDirectoryPath: String? = nil,
        metadataIdentifier: String? = nil,
        rootDevice: UInt64? = nil,
        rootInode: UInt64? = nil,
        dataDevice: UInt64? = nil,
        dataInode: UInt64? = nil,
        metadataDevice: UInt64? = nil,
        metadataInode: UInt64? = nil,
        metadataDigest: String? = nil
    ) -> SandboxOwnerPreferenceSourceEvidence {
        SandboxOwnerPreferenceSourceEvidence(
            bundleIdentifier: bundleIdentifier ?? value.bundleIdentifier,
            signingIdentifier: signingIdentifier ?? value.signingIdentifier,
            homeDirectoryPath: homeDirectoryPath ?? value.homeDirectoryPath,
            containerRootPath: containerRootPath ?? value.containerRootPath,
            dataDirectoryPath: dataDirectoryPath ?? value.dataDirectoryPath,
            metadataIdentifier: metadataIdentifier ?? value.metadataIdentifier,
            rootDevice: rootDevice ?? value.rootDevice,
            rootInode: rootInode ?? value.rootInode,
            dataDevice: dataDevice ?? value.dataDevice,
            dataInode: dataInode ?? value.dataInode,
            metadataDevice: metadataDevice ?? value.metadataDevice,
            metadataInode: metadataInode ?? value.metadataInode,
            metadataDigest: metadataDigest ?? value.metadataDigest
        )
    }

    private struct FileSystemFixture {
        let bundle: String
        let home: URL
        let data: URL
        let metadata: URL
        let preferences: URL
    }

    private func makeFileSystemFixture() throws -> FileSystemFixture {
        let manager = FileManager.default
        let bundle = "com.example.Sandbox"
        let home = manager.temporaryDirectory.appendingPathComponent(
            "BlennySandboxOwner-\(UUID().uuidString)", isDirectory: true
        )
        let root = home.appendingPathComponent("Library/Containers/\(bundle)", isDirectory: true)
        let data = root.appendingPathComponent("Data", isDirectory: true)
        let preferencesDirectory = data.appendingPathComponent(
            "Library/Preferences", isDirectory: true
        )
        try manager.createDirectory(at: preferencesDirectory, withIntermediateDirectories: true)
        let metadata = root.appendingPathComponent(
            ".com.apple.containermanagerd.metadata.plist"
        )
        try metadataData(bundle: bundle).write(to: metadata)
        let preferences = preferencesDirectory.appendingPathComponent("\(bundle).plist")
        try preferenceData().write(to: preferences)
        return FileSystemFixture(
            bundle: bundle,
            home: home,
            data: data,
            metadata: metadata,
            preferences: preferences
        )
    }

    private func metadataData(bundle: String) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: ["MCMMetadataIdentifier": bundle],
            format: .binary,
            options: 0
        )
    }

    private func preferenceData() throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: ["NSStatusItem Preferred Position Item-0": 618],
            format: .binary,
            options: 0
        )
    }
}
#endif
