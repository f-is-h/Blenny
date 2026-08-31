import ApplicationServices
import Foundation

/// Read-only discovery evidence. A running process is not a policy candidate.
public struct ApplicationMenuBarDiscovery: Codable, Equatable, Sendable {
    public enum Outcome: String, Codable, Sendable {
        case observed, noExtrasMenuBar, unavailable
    }

    public let processIdentifier: Int32
    public let bundleIdentifier: String?
    public let outcome: Outcome
    public let rootReadResult: Int32
    public let observationCount: Int

    public init(
        application: RunningApplicationDescriptor, rootReadResult: Int32,
        hasValidRoot: Bool, observationCount: Int
    ) {
        processIdentifier = application.processIdentifier
        bundleIdentifier = application.bundleIdentifier
        self.rootReadResult = rootReadResult
        self.observationCount = observationCount
        if rootReadResult == AXError.success.rawValue && hasValidRoot {
            outcome = .observed
        } else if rootReadResult == AXError.noValue.rawValue
            || rootReadResult == AXError.attributeUnsupported.rawValue {
            outcome = .noExtrasMenuBar
        } else {
            outcome = .unavailable
        }
    }

    public var failureDescription: String? {
        guard outcome == .unavailable else { return nil }
        return "\(bundleIdentifier ?? "Unidentified application") — menu-bar read unavailable (AX \(rootReadResult))"
    }
}
