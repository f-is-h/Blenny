import Foundation
import Testing
@testable import BlennyCore

@Suite("Exact-file bookmark lifecycle")
struct MenuBarLayoutAccessSessionTests {
    private let home = URL(fileURLWithPath: "/fixture-home/tester")

    @Test("A stale bookmark renews once within its validated security scope")
    func staleRenewal() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MenuBarLayoutBookmarkStore(directory: directory)
        try store.save(Data("old".utf8))
        let expected = MenuBarLayoutAccessSession.expectedLayoutFileURL(homeDirectory: home)
        var events: [String] = []
        let operations = MenuBarLayoutAccessOperations(
            resolve: { _ in events.append("resolve"); return (expected, true) },
            bookmark: { _ in events.append("renew"); return Data("new".utf8) },
            start: { _ in events.append("start"); return true },
            stop: { _ in events.append("stop") }
        )
        do {
            let session = MenuBarLayoutAccessSession(store: store, homeDirectory: home, operations: operations)
            #expect(try session.restoreSavedAccess())
            #expect(session.isActive)
            #expect(try store.load() == Data("new".utf8))
            #expect(events == ["resolve", "start", "renew"])
        }
        #expect(events.last == "stop")
    }

    @Test("Revoked or wrong-file grants never renew or replace saved bytes")
    func rejectedGrant() throws {
        for wrongFile in [false, true] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = MenuBarLayoutBookmarkStore(directory: directory)
            let old = Data("old".utf8)
            try store.save(old)
            let expected = MenuBarLayoutAccessSession.expectedLayoutFileURL(homeDirectory: home)
            var renewals = 0
            let operations = MenuBarLayoutAccessOperations(
                resolve: { _ in (wrongFile ? expected.deletingLastPathComponent() : expected, true) },
                bookmark: { _ in renewals += 1; return Data("new".utf8) },
                start: { _ in false }, stop: { _ in }
            )
            let session = MenuBarLayoutAccessSession(store: store, homeDirectory: home, operations: operations)
            #expect(throws: MenuBarLayoutAccessError.self) { try session.restoreSavedAccess() }
            #expect(!session.isActive)
            #expect(renewals == 0)
            #expect(try store.load() == old)
        }
    }

    @Test("Failed renewal retains the previous active scope and saved bookmark")
    func renewalFailurePreservesAccess() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MenuBarLayoutBookmarkStore(directory: directory)
        let old = Data("old".utf8)
        try store.save(old)
        let expected = MenuBarLayoutAccessSession.expectedLayoutFileURL(homeDirectory: home)
        var stale = false
        var stops = 0
        let operations = MenuBarLayoutAccessOperations(
            resolve: { _ in (expected, stale) },
            bookmark: { _ in throw MenuBarLayoutAccessError.storageUnavailable },
            start: { _ in true }, stop: { _ in stops += 1 }
        )
        let session = MenuBarLayoutAccessSession(store: store, homeDirectory: home, operations: operations)
        #expect(try session.restoreSavedAccess())
        stale = true
        #expect(throws: MenuBarLayoutAccessError.storageUnavailable) { try session.restoreSavedAccess() }
        #expect(session.isActive)
        #expect(stops == 1)
        #expect(try store.load() == old)
    }
}
