#if DEBUG
import Darwin
import Foundation
import Testing

@testable import BlennyCore

@Suite("Menu bar layout access")
struct MenuBarLayoutAccessTests {
    @Test("The requested capability is bound to the exact MenuBar layout file")
    func exactLayoutFileOnly() throws {
        let home = URL(fileURLWithPath: "/fixture-home/tester", isDirectory: true)
        let store = MenuBarLayoutBookmarkStore(
            directory: home.appendingPathComponent("Library/Application Support/Blenny/DebugOrdering")
        )
        let session = MenuBarLayoutAccessSession(store: store, homeDirectory: home)
        let expected = home.appendingPathComponent(
            "Library/Group Containers/com.apple.MenuBar/Library/Preferences/com.apple.MenuBar.plist"
        )

        #expect(session.expectedFileURL == expected)
        try session.validateSelection(expected)
        #expect(throws: MenuBarLayoutAccessError.unexpectedSelection(
            expected.deletingLastPathComponent().path
        )) {
            try session.validateSelection(expected.deletingLastPathComponent())
        }
        #expect(throws: MenuBarLayoutAccessError.unexpectedSelection(
            expected.deletingLastPathComponent().appendingPathComponent("other.plist").path
        )) {
            try session.validateSelection(
                expected.deletingLastPathComponent().appendingPathComponent("other.plist")
            )
        }
    }

    @Test("Bookmark bytes round-trip with private directory and file modes")
    func privateBookmarkRoundTrip() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MenuBarLayoutBookmarkStore(directory: directory)
        let bookmark = Data("bounded-security-scope-fixture".utf8)

        #expect(try store.load() == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
        try store.save(bookmark)

        #expect(try store.load() == bookmark)
        #expect(try permissions(of: directory) == 0o700)
        #expect(try permissions(of: store.bookmarkURL) == 0o600)
    }

    @Test("A symlink cannot stand in for the private bookmark directory")
    func symlinkDirectoryFailsClosed() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let link = root.appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: destination)
        let store = MenuBarLayoutBookmarkStore(directory: link)

        #expect(throws: MenuBarLayoutAccessError.self) {
            try store.save(Data("bookmark".utf8))
        }
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("blenny-layout-access-\(UUID().uuidString)", isDirectory: true)
    }

    private func permissions(of url: URL) throws -> mode_t {
        var attributes = stat()
        guard lstat(url.path, &attributes) == 0 else {
            throw MenuBarLayoutAccessError.storageUnavailable
        }
        return attributes.st_mode & 0o777
    }
}
#endif
