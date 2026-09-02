import Foundation

public struct DisplayConfigurationRecord: Equatable, Sendable {
    public let displayIdentifier: UInt64?
    public let frameX: Double
    public let frameY: Double
    public let frameWidth: Double
    public let frameHeight: Double
    public let backingScaleFactor: Double

    public init(
        displayIdentifier: UInt64?,
        frameX: Double,
        frameY: Double,
        frameWidth: Double,
        frameHeight: Double,
        backingScaleFactor: Double
    ) {
        self.displayIdentifier = displayIdentifier
        self.frameX = frameX
        self.frameY = frameY
        self.frameWidth = frameWidth
        self.frameHeight = frameHeight
        self.backingScaleFactor = backingScaleFactor
    }
}

public struct DisplayConfigurationSignature: Equatable, Sendable {
    public let displays: [DisplayConfigurationRecord]

    public init(displays: [DisplayConfigurationRecord]) {
        self.displays = displays.sorted(by: Self.precedes)
    }

    private static func precedes(
        _ lhs: DisplayConfigurationRecord,
        _ rhs: DisplayConfigurationRecord
    ) -> Bool {
        let left = [
            Double(lhs.displayIdentifier ?? UInt64.max), lhs.frameX, lhs.frameY,
            lhs.frameWidth, lhs.frameHeight, lhs.backingScaleFactor,
        ]
        let right = [
            Double(rhs.displayIdentifier ?? UInt64.max), rhs.frameX, rhs.frameY,
            rhs.frameWidth, rhs.frameHeight, rhs.backingScaleFactor,
        ]
        for (leftValue, rightValue) in zip(left, right) where leftValue != rightValue {
            return leftValue < rightValue
        }
        return false
    }
}

public enum DisplayConfigurationPolicy {
    public static func invalidates(
        previous: DisplayConfigurationSignature,
        current: DisplayConfigurationSignature
    ) -> Bool {
        previous != current
    }
}
