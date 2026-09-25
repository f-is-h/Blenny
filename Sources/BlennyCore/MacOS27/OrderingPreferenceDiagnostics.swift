#if DEBUG
import Darwin
import Foundation

/// Opt-in, bounded local evidence. Never synchronizes preferences or changes a
/// transaction decision. Raw tables must remain in an ignored local directory.
enum OrderingPreferenceDiagnostics {
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var sequence = 0
    }
    private static let state = State()
    static var enabled: Bool { directory != nil }
    private static var directory: URL? {
        guard let path = ProcessInfo.processInfo.environment["BLENNY_ORDERING_DIAGNOSTICS_DIRECTORY"],
              (path as NSString).isAbsolutePath else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    struct Event: Codable {
        let sequence: Int
        let process: Int32
        let uptime: TimeInterval
        let stage: String
        let groups: [String: [String: OrderingValue]]
        let detail: String?
    }

    static func record(
        _ stage: String, groups: [String: [String: OrderingValue]] = [:], detail: String? = nil
    ) {
        guard let directory else { return }
        state.lock.lock()
        defer { state.lock.unlock() }
        // No timers, retries, or unbounded files. A new process gets a distinct
        // prefix so a fresh-reader comparison cannot overwrite the live trace.
        guard state.sequence < 128 else { return }
        state.sequence += 1
        let event = Event(sequence: state.sequence, process: getpid(),
                          uptime: ProcessInfo.processInfo.systemUptime,
                          stage: stage, groups: groups, detail: detail)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            let data = try encoder.encode(event)
            guard data.count <= 4 * 1_024 * 1_024 else { return }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                     attributes: [.posixPermissions: 0o700])
            let file = directory.appendingPathComponent("preferences-\(getpid())-\(state.sequence).json")
            // Writing to the evidence directory is unrelated to system preferences.
            try data.write(to: file, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        } catch {
            // Diagnostic storage must never fail a reviewed operation.
        }
    }
}
#endif
