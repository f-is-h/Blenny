import Foundation
import Testing
@testable import BlennyCore

struct DurablePrivateFileTests {
    @Test func privateAtomicReplacementAndRemoval() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("policy.json")
        try DurablePrivateFile.write(Data("old".utf8), to: url)
        try DurablePrivateFile.write(Data("new".utf8), to: url)
        #expect(try Data(contentsOf: url) == Data("new".utf8))
        #expect(try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int == 0o600)
        #expect(try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? Int == 0o700)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["policy.json"])
        try DurablePrivateFile.remove(url)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func refusesSymlinkDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("target")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(throws: (any Error).self) {
            try DurablePrivateFile.write(Data("data".utf8), to: link.appendingPathComponent("policy.json"))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: target.path).isEmpty)
    }
}
