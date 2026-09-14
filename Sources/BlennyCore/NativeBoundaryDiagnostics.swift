#if DEBUG
import Foundation

/// One explicitly armed check. Late callbacks cannot overwrite a newer check.
/// This contains no event monitor, timer, preference reader or system writer.
public struct NativeControlClickCheck: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable { case idle, armed, active, finished }
    public private(set) var id: UUID?
    public private(set) var phase: Phase = .idle
    public private(set) var source: String?
    public private(set) var stages: [String] = []

    public init() {}

    public mutating func arm() {
        id = UUID()
        phase = .armed
        source = nil
        stages = []
    }

    @discardableResult
    public mutating func begin(source: String, event: String) -> UUID? {
        guard phase == .armed else { return nil }
        self.source = source
        phase = .active
        stages = ["input=\(source) event=\(event)"]
        return id
    }

    public mutating func record(id: UUID?, stage: String, finished: Bool = false) {
        guard let id, id == self.id, phase == .active else { return }
        if stages.count < 20 { stages.append(String(stage.prefix(512))) }
        else if finished { stages[stages.count - 1] = String(stage.prefix(512)) }
        if finished { phase = .finished }
    }

    public var summary: String {
        "check=\(id?.uuidString ?? "none") phase=\(phase.rawValue)"
            + " source=\(source ?? "none") stages=[\(stages.joined(separator: " | "))]"
    }
}

/// Stored own keys are not evidence of instantiated controls. Keep the two
/// sets separate without deleting historical preferences or admitting a write.
public struct OwnControlKeyEvidence: Codable, Equatable, Sendable {
    public let instantiatedKeys: [String]
    public let instantiatedKeysMissingFromTable: [String]
    public let storedOwnKeysNotInstantiated: [String]

    public init(tableKeys: Set<String>, bundleIdentifier: String, autosaveNames: [String]) {
        let prefix = "status:\(bundleIdentifier)::"
        let live = Set(autosaveNames.map { prefix + $0 })
        instantiatedKeys = live.intersection(tableKeys).sorted()
        instantiatedKeysMissingFromTable = live.subtracting(tableKeys).sorted()
        storedOwnKeysNotInstantiated = tableKeys
            .filter { $0.hasPrefix(prefix) && !live.contains($0) }.sorted()
    }
}
#endif
