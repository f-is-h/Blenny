#if BLENNY_PRODUCT || DEBUG
import CoreFoundation
import CryptoKit
import Foundation

public enum OrderingError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedPropertyListValue
    case propertyListLimitExceeded
    case invalidSnapshot(String)
    case unsupportedRuntime
    case invalidSelection
    case ineligibleBundle(String, [OrderingEligibilityReason])
    case indistinguishablePositions
    case invalidGeometry
    case malformedPlan
    case unavailableOrderChanges([String])
    case staleSnapshot(String)
    case targetDrift(String)
    case relativeOrderMismatch

    public var errorDescription: String? {
        switch self {
        case .unsupportedPropertyListValue:
            "The captured property list contains an unsupported value."
        case .propertyListLimitExceeded:
            "The captured property list exceeds the bounded ordering limits."
        case let .invalidSnapshot(reason):
            "The ordering snapshot is incomplete or invalid: \(reason)."
        case .unsupportedRuntime:
            "Ordering is available only on the verified macOS 27 build and architecture."
        case .invalidSelection:
            "Select between two and 32 distinct eligible application bundles."
        case let .ineligibleBundle(bundle, reasons):
            "\(bundle) cannot be ordered: \(reasons.map(\.userDescription).joined(separator: ", "))."
        case .indistinguishablePositions:
            "The selected applications do not have two distinct configured positions."
        case .invalidGeometry:
            "The observed positions do not establish a distinguishable left-to-right order."
        case .malformedPlan:
            "The ordering plan no longer matches its reviewed inputs."
        case let .unavailableOrderChanges(names):
            "This draft changes the relative order of items that cannot be sorted: \(names.joined(separator: ", "))."
        case let .staleSnapshot(reason):
            "The ordering snapshot is stale: \(reason)."
        case let .targetDrift(key):
            "The ordering target changed unexpectedly: \(key)."
        case .relativeOrderMismatch:
            "The observed application order does not match the reviewed operation."
        }
    }
}

/// A bounded, lossless representation of the property-list value kinds used by
/// the menu-bar group defaults. Numeric kinds deliberately preserve integer,
/// real and Boolean identity.
public enum OrderingValue: Codable, Equatable, Sendable {
    case integer(Int64)
    case real(Double)
    case bool(Bool)
    case string(String)
    case data(Data)
    case date(Date)
    case array([OrderingValue])
    case dictionary([String: OrderingValue])

    private static let maximumDepth = 16
    private static let maximumNodes = 4_096
    private static let maximumCollectionCount = 512
    private static let maximumStringBytes = 16_384
    private static let maximumDataBytes = 262_144

    private enum CodingKeys: String, CodingKey { case kind, value }
    private enum Kind: String, Codable {
        case integer, real, bool, string, data, date, array, dictionary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .integer: self = .integer(try container.decode(Int64.self, forKey: .value))
        case .real: self = .real(try container.decode(Double.self, forKey: .value))
        case .bool: self = .bool(try container.decode(Bool.self, forKey: .value))
        case .string: self = .string(try container.decode(String.self, forKey: .value))
        case .data: self = .data(try container.decode(Data.self, forKey: .value))
        case .date: self = .date(try container.decode(Date.self, forKey: .value))
        case .array: self = .array(try container.decode([OrderingValue].self, forKey: .value))
        case .dictionary:
            self = .dictionary(try container.decode([String: OrderingValue].self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .integer(value):
            try container.encode(Kind.integer, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .real(value):
            try container.encode(Kind.real, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .bool(value):
            try container.encode(Kind.bool, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .string(value):
            try container.encode(Kind.string, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .data(value):
            try container.encode(Kind.data, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .date(value):
            try container.encode(Kind.date, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .array(value):
            try container.encode(Kind.array, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .dictionary(value):
            try container.encode(Kind.dictionary, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }

    public static func fromFoundation(_ value: Any) throws -> OrderingValue {
        var nodes = 0
        let result = try fromFoundation(value, depth: 0, nodes: &nodes)
        try result.validate()
        return result
    }

    private static func fromFoundation(_ value: Any, depth: Int, nodes: inout Int) throws -> OrderingValue {
        try charge(depth: depth, nodes: &nodes)

        if let value = value as? String { return .string(value) }
        if let value = value as? Data { return .data(value) }
        if let value = value as? Date { return .date(value) }

        if let number = value as? NSNumber {
            let typeID = CFGetTypeID(number)
            if typeID == CFBooleanGetTypeID() { return .bool(number.boolValue) }
            guard typeID == CFNumberGetTypeID() else {
                throw OrderingError.unsupportedPropertyListValue
            }
            let type = String(cString: number.objCType)
            if ["f", "d"].contains(type) {
                guard number.doubleValue.isFinite else { throw OrderingError.unsupportedPropertyListValue }
                return .real(number.doubleValue)
            }
            if ["C", "S", "I", "L", "Q"].contains(type) {
                let integer = number.uint64Value
                guard integer <= UInt64(Int64.max) else { throw OrderingError.unsupportedPropertyListValue }
                return .integer(Int64(integer))
            }
            if ["c", "s", "i", "l", "q"].contains(type) {
                return .integer(number.int64Value)
            }
            throw OrderingError.unsupportedPropertyListValue
        }
        if let values = value as? [Any] {
            guard values.count <= maximumCollectionCount else { throw OrderingError.propertyListLimitExceeded }
            return .array(try values.map { try fromFoundation($0, depth: depth + 1, nodes: &nodes) })
        }
        if let values = value as? [String: Any] {
            guard values.count <= maximumCollectionCount else { throw OrderingError.propertyListLimitExceeded }
            var result: [String: OrderingValue] = [:]
            for key in values.keys.sorted() {
                result[key] = try fromFoundation(values[key]!, depth: depth + 1, nodes: &nodes)
            }
            return .dictionary(result)
        }
        if let values = value as? NSDictionary {
            guard values.count <= maximumCollectionCount else { throw OrderingError.propertyListLimitExceeded }
            var result: [String: OrderingValue] = [:]
            for rawKey in values.allKeys {
                guard let key = rawKey as? String, let rawValue = values[rawKey] else {
                    throw OrderingError.unsupportedPropertyListValue
                }
                result[key] = try fromFoundation(rawValue, depth: depth + 1, nodes: &nodes)
            }
            return .dictionary(result)
        }
        throw OrderingError.unsupportedPropertyListValue
    }

    public func toFoundation() throws -> Any {
        try validate()
        return switch self {
        case let .integer(value): value
        case let .real(value): value
        case let .bool(value): value
        case let .string(value): value
        case let .data(value): value
        case let .date(value): value
        case let .array(values): try values.map { try $0.toFoundation() }
        case let .dictionary(values):
            try values.mapValues { try $0.toFoundation() }
        }
    }

    public func validate() throws {
        var nodes = 0
        try validate(depth: 0, nodes: &nodes)
    }

    private func validate(depth: Int, nodes: inout Int) throws {
        try Self.charge(depth: depth, nodes: &nodes)
        switch self {
        case .integer, .bool:
            break
        case let .real(value):
            guard value.isFinite else { throw OrderingError.unsupportedPropertyListValue }
        case let .string(value):
            guard value.utf8.count <= Self.maximumStringBytes else { throw OrderingError.propertyListLimitExceeded }
        case let .data(value):
            guard value.count <= Self.maximumDataBytes else { throw OrderingError.propertyListLimitExceeded }
        case let .date(value):
            guard value.timeIntervalSinceReferenceDate.isFinite else { throw OrderingError.unsupportedPropertyListValue }
        case let .array(values):
            guard values.count <= Self.maximumCollectionCount else { throw OrderingError.propertyListLimitExceeded }
            for value in values { try value.validate(depth: depth + 1, nodes: &nodes) }
        case let .dictionary(values):
            guard values.count <= Self.maximumCollectionCount else { throw OrderingError.propertyListLimitExceeded }
            for key in values.keys.sorted() {
                guard !key.isEmpty, key.utf8.count <= Self.maximumStringBytes,
                      !key.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else {
                    throw OrderingError.unsupportedPropertyListValue
                }
                try values[key]!.validate(depth: depth + 1, nodes: &nodes)
            }
        }
    }

    private static func charge(depth: Int, nodes: inout Int) throws {
        guard depth <= maximumDepth, nodes < maximumNodes else { throw OrderingError.propertyListLimitExceeded }
        nodes += 1
    }

    public var canonicalFingerprint: String {
        get throws {
            try validate()
            return try OrderingDigest.hash(self)
        }
    }

    var positivePosition: Double? {
        switch self {
        case let .integer(value) where value > 0 && value <= 1_000_000: Double(value)
        case let .real(value) where value.isFinite && value > 0 && value <= 1_000_000: value
        default: nil
        }
    }
}
#endif
