#if DEBUG
import Foundation
import Testing
@testable import BlennyCore

@Suite("Bounded preference-file settlement")
struct OrderingPreferenceFileChangeTests {
    @Test("Atomic replacement wakes the exact-file observer, including before waiting")
    func replacementBeforeWait() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("before".utf8).write(to: file)
        let observation = try #require(OrderingPreferenceFileChange(url: file))
        defer { observation.cancel() }
        try Data("after".utf8).write(to: file, options: .atomic)
        #expect(try await observation.wait(timeout: .seconds(3)))
        #expect(try Data(contentsOf: file) == Data("after".utf8))
    }

    @Test("No file change reaches the deadline without manufacturing an event")
    func deadlineWithoutChange() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("same".utf8).write(to: file)
        let observation = try #require(OrderingPreferenceFileChange(url: file))
        defer { observation.cancel() }
        #expect(try await !observation.wait(timeout: .milliseconds(10)))
        #expect(try Data(contentsOf: file) == Data("same".utf8))
    }

    @Test("Cancellation does not leave a suspended continuation")
    func cancelledWait() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("same".utf8).write(to: file)
        let observation = try #require(OrderingPreferenceFileChange(url: file))
        let task = Task { try await observation.wait() }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
#endif
