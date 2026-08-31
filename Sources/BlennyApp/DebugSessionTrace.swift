#if DEBUG
import Foundation

/// Explicit validation stdout only. The launcher redirects evidence to ignored
/// LocalData. One bounded, monotonic sequence spans MainActor and writer events.
final class DebugSessionTrace: @unchecked Sendable {
    static let shared = DebugSessionTrace()
    let enabled = ProcessInfo.processInfo.environment["BLENNY_SESSION_DIAGNOSTICS"] == "YES"
    private let lock = NSLock()
    private let startedAt = ProcessInfo.processInfo.systemUptime
    private var sequence = 0

    func write(_ message: String) {
        guard enabled else { return }
        lock.withLock {
            guard sequence < 1_024 else { return }
            sequence += 1
            let elapsed = String(format: "%.6f", ProcessInfo.processInfo.systemUptime - startedAt)
            let payload = sequence == 1_024 ? "trace-limit-reached" : message
            FileHandle.standardOutput.write(Data(
                "BLENNY_SESSION seq=\(sequence) elapsed=\(elapsed) \(payload)\n".utf8
            ))
        }
    }
}
#endif
