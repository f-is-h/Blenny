#if DEBUG
import Foundation

/// Pure value transformation for the attended fallback experiment. This is not
/// write authorization, runtime identity evidence, or a durable recovery receipt.
/// The coordinator must supply those independently before using either table.
public struct FallbackPositionDelta: Codable, Equatable, Sendable {
    public static let key = "status:xyz.fi5h.blenny::Item-1"
    public static let fishKey = "status:xyz.fi5h.blenny::Blenny.Fish"
    public let fishOriginal: OrderingValue?
    public let fishProposed: OrderingValue?
    public let original: OrderingValue
    public let proposed: OrderingValue

    public enum Failure: Error, Equatable, LocalizedError {
        case invalidPosition
        case unchangedPosition
        case targetDrift

        public var errorDescription: String? {
            switch self {
            case .targetDrift:
                "Blenny’s saved control positions have changed. Choose Position Blenny Controls to review a new placement."
            case .invalidPosition: "The control positions are invalid."
            case .unchangedPosition: "Blenny’s controls are already positioned."
            }
        }
    }

    public init(original: OrderingValue, proposed: OrderingValue,
                fishOriginal: OrderingValue? = nil, fishProposed: OrderingValue? = nil) throws {
        guard let before = Self.position(original), let after = Self.position(proposed) else {
            throw Failure.invalidPosition
        }
        guard (fishOriginal == nil) == (fishProposed == nil) else { throw Failure.invalidPosition }
        if let fishOriginal, let fishProposed {
            guard Self.position(fishOriginal) != nil, Self.position(fishProposed) != nil else {
                throw Failure.invalidPosition
            }
        }
        guard before != after || fishOriginal != fishProposed else { throw Failure.unchangedPosition }
        self.fishOriginal = fishOriginal
        self.fishProposed = fishProposed
        self.original = original
        self.proposed = proposed
    }

    private enum CodingKeys: String, CodingKey { case original, proposed, fishOriginal, fishProposed }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(original: values.decode(OrderingValue.self, forKey: .original),
                      proposed: values.decode(OrderingValue.self, forKey: .proposed),
                      fishOriginal: values.decodeIfPresent(OrderingValue.self, forKey: .fishOriginal),
                      fishProposed: values.decodeIfPresent(OrderingValue.self, forKey: .fishProposed))
    }

    /// The caller must separately compare its complete fresh preflight context.
    public func applying(to current: [String: OrderingValue]) throws -> [String: OrderingValue] {
        guard originalValues.allSatisfy({ current[$0.key] == $0.value }) else { throw Failure.targetDrift }
        var result = current
        for (key, value) in proposedValues { result[key] = value }
        return result
    }

    /// An interrupted write may have left either known endpoint. Never overwrite
    /// a third value or recreate a missing target. Unrelated drift is preserved.
    public func restoring(in current: [String: OrderingValue]) throws -> [String: OrderingValue] {
        guard originalValues.allSatisfy({ current[$0.key] == $0.value || current[$0.key] == proposedValues[$0.key] }) else {
            throw Failure.targetDrift
        }
        var result = current
        for (key, value) in originalValues { result[key] = value }
        return result
    }

    public var originalValues: [String: OrderingValue] {
        var values = [Self.key: original]
        if let fishOriginal { values[Self.fishKey] = fishOriginal }
        return values
    }

    public var proposedValues: [String: OrderingValue] {
        var values = [Self.key: proposed]
        if let fishProposed { values[Self.fishKey] = fishProposed }
        return values
    }

    public func canBeReplaced(by next: Self) -> Bool {
        proposedValues.allSatisfy { next.originalValues[$0.key] == $0.value }
    }

    private static func position(_ value: OrderingValue) -> Double? {
        let number: Double
        switch value {
        case let .integer(value): number = Double(value)
        case let .real(value): number = value
        default: return nil
        }
        return number.isFinite && number > 0 && number <= 1_000_000 ? number : nil
    }
}
#endif
