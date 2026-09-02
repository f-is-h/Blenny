import Foundation

/// A process-local, one-attempt guard around removing Blenny's empty fallback
/// slot after macOS supplies a usable native overflow control.
public struct NativeFallbackSlotCompaction: Equatable, Sendable {
    public enum Allocation: Equatable, Sendable {
        case reserved
        case compact
        case absent
    }

    public struct Update: Equatable, Sendable {
        public let allocation: Allocation
        public let requestsVerification: Bool

        public init(allocation: Allocation, requestsVerification: Bool) {
            self.allocation = allocation
            self.requestsVerification = requestsVerification
        }
    }

    private enum State: Equatable, Sendable {
        case reserved
        case verifyingAbsent
        case absent
        case verifyingCompact
        case compact
        case reservedForSession
    }

    private var state: State = .reserved

    public init() {}

    /// A fresh bounded attempt is permitted only by an explicit user reveal.
    /// Layout observations alone can never clear the session latch.
    public mutating func beginUserRevealAttempt() {
        state = .reserved
    }

    public mutating func update(
        nativeOverflowUsable: Bool,
        mayBeginCompaction: Bool
    ) -> Update {
        switch state {
        case .reserved:
            guard nativeOverflowUsable, mayBeginCompaction else {
                return Update(allocation: .reserved, requestsVerification: false)
            }
            state = .verifyingAbsent
            return Update(allocation: .absent, requestsVerification: true)

        case .verifyingAbsent, .absent:
            if nativeOverflowUsable {
                state = .absent
                return Update(allocation: .absent, requestsVerification: false)
            }
            state = .verifyingCompact
            return Update(allocation: .compact, requestsVerification: true)

        case .verifyingCompact:
            if nativeOverflowUsable {
                state = .compact
                return Update(allocation: .compact, requestsVerification: false)
            }
            state = .reservedForSession
            return Update(allocation: .reserved, requestsVerification: false)

        case .compact:
            guard nativeOverflowUsable else {
                state = .reservedForSession
                return Update(allocation: .reserved, requestsVerification: false)
            }
            return Update(allocation: .compact, requestsVerification: false)

        case .reservedForSession:
            return Update(allocation: .reserved, requestsVerification: false)
        }
    }
}
