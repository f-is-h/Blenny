#if DEBUG
import Combine
import Foundation

/// Launch-time controls only. Never writes policy, ordering, or recovery state.
@MainActor
enum DebugDragStartDiagnostics {
    enum Mode: String {
        case baseline
        case snapshotSystemItems = "snapshot-system-items"
        case noViewExtras = "no-view-extras"
        case simpleLane = "simple-lane"
        case minimalSession = "minimal-session"
        case noFocus = "no-focus"
        case applicationSourcesOnly = "application-sources-only"
        case systemPayloadOnly = "system-payload-only"
    }

    static let mode = ProcessInfo.processInfo.environment["BLENNY_DRAG_DIAGNOSTIC"]
        .flatMap(Mode.init(rawValue:))
    static let typedSource = ProcessInfo.processInfo.environment["BLENNY_DRAG_SOURCE"] != "provider"
    static let publishUnchangedOverflow = ProcessInfo.processInfo.environment["BLENNY_DRAG_OVERFLOW_PUBLISH"] == "always"
    private static var attemptStarted = false
    static func beginAttempt() {
        guard mode != nil, !attemptStarted else { return }
        attemptStarted = true
        counts.removeAll()
        total = 0
        record("attempt.begin")
    }
    private static var counts: [String: Int] = [:]
    private static var total = 0

    /// Bounded, event-driven stderr evidence; values and inventory are omitted.
    static func record(_ event: String, stack: Bool = false) {
        guard mode != nil, total < 600 else { return }
        let count = counts[event, default: 0]
        guard count < 16 else { return }
        counts[event] = count + 1
        total += 1
        var line = "drag-diagnostic \(ProcessInfo.processInfo.systemUptime) \(event) #\(count + 1)"
        if count == 15 { line += " [event log limit reached]" }
        if stack && count < 2 {
            line += "\n" + Thread.callStackSymbols.prefix(24).joined(separator: "\n")
        }
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }

    static func watch<P: Publisher>(
        _ publisher: P, name: String, in cancellables: inout Set<AnyCancellable>
    ) where P.Failure == Never {
        guard mode != nil else { return }
        publisher.dropFirst().sink { _ in
            record("published.\(name)", stack: true)
        }.store(in: &cancellables)
    }
}
#endif
