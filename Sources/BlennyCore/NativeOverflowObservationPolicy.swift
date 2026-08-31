/// Read-only observation has no dependency on a management writer or policy.
/// A changed MenuBarAgent remains terminal for this process.
public enum NativeOverflowObservationPolicy {
    public static func shouldObserve(
        accessibilityTrusted: Bool, isTerminating: Bool, restartRequired: Bool
    ) -> Bool {
        accessibilityTrusted && !isTerminating && !restartRequired
    }
}

/// A failed read keeps its container subscription, but allows only one later
/// event-triggered recovery read. A second failure requires explicit Refresh.
/// No retry task, timer, polling, or assertion acquisition is scheduled here.
public struct NativeOverflowReadRecovery: Sendable {
    public private(set) var consecutiveFailures = 0
    public var allowsEventRead: Bool { consecutiveFailures < 2 }
    public init() {}
    public mutating func failed() { consecutiveFailures = min(2, consecutiveFailures + 1) }
    public mutating func succeeded() { consecutiveFailures = 0 }
    public mutating func explicitRefresh() { consecutiveFailures = 0 }
}
