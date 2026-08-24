import CoreFoundation
import CryptoKit
import Foundation

public enum PreferredPositionStateError: Error, LocalizedError, Sendable {
    case unsupportedValueType(domain: String, key: String, typeID: UInt)
    case invalidNumber(domain: String, key: String)
    case invalidNumberType(Int)
    case scopeMismatch
    case invalidBackupFingerprint
    case staleCurrentState(expected: String, actual: String)
    case backupFingerprintMismatch(expected: String, actual: String)
    case proposedFingerprintMismatch(expected: String, actual: String)
    case invalidExperimentalPlan
    case operationLimitExceeded(limit: Int, actual: Int)
    case synchronizationFailed(domain: String)
    case restoreVerificationFailed(expected: String, actual: String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedValueType(domain, key, typeID):
            "Unsupported preferred-position value in \(domain), key \(key), CFTypeID \(typeID)."
        case let .invalidNumber(domain, key):
            "Could not decode the preferred-position number in \(domain), key \(key)."
        case let .invalidNumberType(rawValue):
            "Unsupported CFNumber type \(rawValue) in the backup."
        case .scopeMismatch:
            "Backup and current snapshots cover different preference domains."
        case .invalidBackupFingerprint:
            "The backup fingerprint does not match its entries."
        case let .staleCurrentState(expected, actual):
            "Current state changed after preview. Expected \(expected), found \(actual)."
        case let .backupFingerprintMismatch(expected, actual):
            "Backup confirmation mismatch. Expected \(expected), received \(actual)."
        case let .proposedFingerprintMismatch(expected, actual):
            "Proposed-state confirmation mismatch. Expected \(expected), received \(actual)."
        case .invalidExperimentalPlan:
            "The experimental write must contain exactly one set operation."
        case let .operationLimitExceeded(limit, actual):
            "Restore requires \(actual) operations, exceeding the limit of \(limit)."
        case let .synchronizationFailed(domain):
            "CFPreferences failed to synchronize \(domain)."
        case let .restoreVerificationFailed(expected, actual):
            "Restore verification failed. Expected \(expected), found \(actual)."
        }
    }
}

public enum PreferredPositionValue: Codable, Equatable, Hashable, Sendable {
    case number(value: Double, cfNumberTypeRawValue: Int)
    case string(String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case value
        case cfNumberTypeRawValue
    }

    private enum Kind: String, Codable {
        case number
        case string
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .number:
            self = .number(
                value: try container.decode(Double.self, forKey: .value),
                cfNumberTypeRawValue: try container.decode(Int.self, forKey: .cfNumberTypeRawValue)
            )
        case .string:
            self = .string(try container.decode(String.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .number(value, cfNumberTypeRawValue):
            try container.encode(Kind.number, forKey: .kind)
            try container.encode(value, forKey: .value)
            try container.encode(cfNumberTypeRawValue, forKey: .cfNumberTypeRawValue)
        case let .string(value):
            try container.encode(Kind.string, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }
}

public struct PreferredPositionEntry: Codable, Equatable, Hashable, Sendable {
    public let domain: String
    public let key: String
    public let value: PreferredPositionValue

    public init(domain: String, key: String, value: PreferredPositionValue) {
        self.domain = domain
        self.key = key
        self.value = value
    }
}

public struct PreferredPositionSnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let environment: RuntimeEnvironment
    public let domains: [String]
    public let entries: [PreferredPositionEntry]
    public let fingerprint: String

    public init(
        generatedAt: Date = Date(),
        environment: RuntimeEnvironment = .current(),
        domains: [String]? = nil,
        entries: [PreferredPositionEntry]
    ) throws {
        let sortedEntries = entries.sorted(by: PreferredPositionEntry.stableSort)
        let sortedDomains = Array(Set(domains ?? entries.map(\.domain))).sorted()
        self.schemaVersion = 1
        self.generatedAt = generatedAt
        self.environment = environment
        self.domains = sortedDomains
        self.entries = sortedEntries
        self.fingerprint = try Self.fingerprint(domains: sortedDomains, entries: sortedEntries)
    }

    public func validateFingerprint() throws {
        guard fingerprint == (try Self.fingerprint(domains: domains, entries: entries)) else {
            throw PreferredPositionStateError.invalidBackupFingerprint
        }
    }

    private static func fingerprint(
        domains: [String],
        entries: [PreferredPositionEntry]
    ) throws -> String {
        struct Payload: Codable {
            let domains: [String]
            let entries: [PreferredPositionEntry]
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(Payload(
            domains: Array(Set(domains)).sorted(),
            entries: entries.sorted(by: PreferredPositionEntry.stableSort)
        ))
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

public enum PreferredPositionOperationKind: String, Codable, Sendable {
    case set
    case remove
}

public struct PreferredPositionRestoreOperation: Codable, Equatable, Sendable {
    public let kind: PreferredPositionOperationKind
    public let domain: String
    public let key: String
    public let currentValue: PreferredPositionValue?
    public let targetValue: PreferredPositionValue?
}

public struct PreferredPositionRestorePlan: Codable, Equatable, Sendable {
    public let backupFingerprint: String
    public let currentFingerprint: String
    public let operations: [PreferredPositionRestoreOperation]

    public var setOperationCount: Int {
        operations.count { $0.kind == .set }
    }

    public var removeOperationCount: Int {
        operations.count { $0.kind == .remove }
    }

    public static func make(
        backup: PreferredPositionSnapshot,
        current: PreferredPositionSnapshot
    ) throws -> PreferredPositionRestorePlan {
        try backup.validateFingerprint()
        try current.validateFingerprint()
        guard backup.domains == current.domains else {
            throw PreferredPositionStateError.scopeMismatch
        }

        let backupEntries = Dictionary(uniqueKeysWithValues: backup.entries.map { ($0.identityKey, $0) })
        let currentEntries = Dictionary(uniqueKeysWithValues: current.entries.map { ($0.identityKey, $0) })
        let allKeys = Set(backupEntries.keys).union(currentEntries.keys).sorted()
        let operations = allKeys.compactMap { identityKey -> PreferredPositionRestoreOperation? in
            let backupEntry = backupEntries[identityKey]
            let currentEntry = currentEntries[identityKey]
            guard backupEntry?.value != currentEntry?.value else { return nil }

            let reference = backupEntry ?? currentEntry!
            return PreferredPositionRestoreOperation(
                kind: backupEntry == nil ? .remove : .set,
                domain: reference.domain,
                key: reference.key,
                currentValue: currentEntry?.value,
                targetValue: backupEntry?.value
            )
        }

        return PreferredPositionRestorePlan(
            backupFingerprint: backup.fingerprint,
            currentFingerprint: current.fingerprint,
            operations: operations
        )
    }
}

public actor MacOS27PreferredPositionReader {
    public static let preferredPositionPrefix = "NSStatusItem Preferred Position "
    public static let supportedDomains = [
        "com.apple.controlcenter",
        "com.apple.systemuiserver"
    ]

    public init() {}

    public func capture(domains: [String] = supportedDomains) throws -> PreferredPositionSnapshot {
        let scopedDomains = Array(Set(domains)).sorted()
        var entries: [PreferredPositionEntry] = []

        for domain in scopedDomains {
            let applicationID = domain as CFString
            let keys = (CFPreferencesCopyKeyList(
                applicationID,
                kCFPreferencesCurrentUser,
                kCFPreferencesAnyHost
            ) as? [String]) ?? []

            for key in keys where key.hasPrefix(Self.preferredPositionPrefix) {
                guard let rawValue = CFPreferencesCopyValue(
                    key as CFString,
                    applicationID,
                    kCFPreferencesCurrentUser,
                    kCFPreferencesAnyHost
                ) else { continue }

                entries.append(
                    PreferredPositionEntry(
                        domain: domain,
                        key: key,
                        value: try decodeValue(rawValue, domain: domain, key: key)
                    )
                )
            }
        }

        return try PreferredPositionSnapshot(domains: scopedDomains, entries: entries)
    }
}

#if DEBUG
/// Unsupported macOS 27 experiment. This is the only type allowed to write preferred-position state.
/// Never call it without a validated backup, a fresh preview, and explicit user confirmation.
public actor ExperimentalMacOS27PreferredPositionWriter {
    public static let shared = ExperimentalMacOS27PreferredPositionWriter()

    private let reader: MacOS27PreferredPositionReader
    private let maximumOperationCount: Int

    private init(
        reader: MacOS27PreferredPositionReader = MacOS27PreferredPositionReader(),
        maximumOperationCount: Int = 4
    ) {
        self.reader = reader
        self.maximumOperationCount = maximumOperationCount
    }

    public func apply(
        baseline: PreferredPositionSnapshot,
        proposed: PreferredPositionSnapshot,
        confirmedBaselineFingerprint: String,
        confirmedProposedFingerprint: String
    ) async throws -> PreferredPositionSnapshot {
        try baseline.validateFingerprint()
        try proposed.validateFingerprint()
        guard baseline.domains == proposed.domains else {
            throw PreferredPositionStateError.scopeMismatch
        }
        guard confirmedBaselineFingerprint == baseline.fingerprint else {
            throw PreferredPositionStateError.backupFingerprintMismatch(
                expected: baseline.fingerprint,
                actual: confirmedBaselineFingerprint
            )
        }
        guard confirmedProposedFingerprint == proposed.fingerprint else {
            throw PreferredPositionStateError.proposedFingerprintMismatch(
                expected: proposed.fingerprint,
                actual: confirmedProposedFingerprint
            )
        }

        let current = try await reader.capture(domains: baseline.domains)
        guard current.fingerprint == baseline.fingerprint else {
            throw PreferredPositionStateError.staleCurrentState(
                expected: baseline.fingerprint,
                actual: current.fingerprint
            )
        }

        let plan = try PreferredPositionRestorePlan.make(backup: proposed, current: current)
        guard plan.operations.count == 1,
              plan.operations.first?.kind == .set else {
            throw PreferredPositionStateError.invalidExperimentalPlan
        }

        try apply(plan.operations)
        return try await verify(expected: proposed)
    }

    public func restore(
        backup: PreferredPositionSnapshot,
        confirmedBackupFingerprint: String,
        confirmedCurrentFingerprint: String
    ) async throws -> PreferredPositionSnapshot {
        try backup.validateFingerprint()
        guard confirmedBackupFingerprint == backup.fingerprint else {
            throw PreferredPositionStateError.backupFingerprintMismatch(
                expected: backup.fingerprint,
                actual: confirmedBackupFingerprint
            )
        }

        let current = try await reader.capture(domains: backup.domains)
        guard current.fingerprint == confirmedCurrentFingerprint else {
            throw PreferredPositionStateError.staleCurrentState(
                expected: confirmedCurrentFingerprint,
                actual: current.fingerprint
            )
        }

        let plan = try PreferredPositionRestorePlan.make(backup: backup, current: current)
        guard plan.operations.count <= maximumOperationCount else {
            throw PreferredPositionStateError.operationLimitExceeded(
                limit: maximumOperationCount,
                actual: plan.operations.count
            )
        }

        try apply(plan.operations)
        return try await verify(expected: backup)
    }

    private func apply(_ operations: [PreferredPositionRestoreOperation]) throws {
        for operation in operations {
            let value = try operation.targetValue?.makeCFPropertyListValue()
            CFPreferencesSetValue(
                operation.key as CFString,
                value,
                operation.domain as CFString,
                kCFPreferencesCurrentUser,
                kCFPreferencesAnyHost
            )
        }

        for domain in Set(operations.map(\.domain)) {
            guard CFPreferencesSynchronize(
                domain as CFString,
                kCFPreferencesCurrentUser,
                kCFPreferencesAnyHost
            ) else {
                throw PreferredPositionStateError.synchronizationFailed(domain: domain)
            }
        }
    }

    private func verify(
        expected: PreferredPositionSnapshot
    ) async throws -> PreferredPositionSnapshot {
        let verification = try await reader.capture(domains: expected.domains)
        guard verification.fingerprint == expected.fingerprint else {
            throw PreferredPositionStateError.restoreVerificationFailed(
                expected: expected.fingerprint,
                actual: verification.fingerprint
            )
        }
        return verification
    }
}
#endif

private extension PreferredPositionEntry {
    var identityKey: String {
        "\(domain.utf8.count):\(domain)|\(key.utf8.count):\(key)"
    }

    static func stableSort(_ first: PreferredPositionEntry, _ second: PreferredPositionEntry) -> Bool {
        first.identityKey < second.identityKey
    }
}

private func decodeValue(
    _ rawValue: CFPropertyList,
    domain: String,
    key: String
) throws -> PreferredPositionValue {
    let typeID = CFGetTypeID(rawValue)
    if typeID == CFNumberGetTypeID() {
        let number = unsafeDowncast(rawValue, to: CFNumber.self)
        var value = 0.0
        guard CFNumberGetValue(number, .doubleType, &value) else {
            throw PreferredPositionStateError.invalidNumber(domain: domain, key: key)
        }
        return .number(
            value: value,
            cfNumberTypeRawValue: Int(CFNumberGetType(number).rawValue)
        )
    }
    if typeID == CFStringGetTypeID(), let value = rawValue as? String {
        return .string(value)
    }
    throw PreferredPositionStateError.unsupportedValueType(
        domain: domain,
        key: key,
        typeID: UInt(typeID)
    )
}

#if DEBUG
private extension PreferredPositionValue {
    func makeCFPropertyListValue() throws -> CFPropertyList {
        switch self {
        case let .number(value, rawType):
            guard let numberType = CFNumberType(rawValue: CFIndex(rawType)) else {
                throw PreferredPositionStateError.invalidNumberType(rawType)
            }
            guard let number = createCFNumber(value: value, type: numberType) else {
                throw PreferredPositionStateError.invalidNumberType(rawType)
            }
            return number
        case let .string(value):
            return value as CFString
        }
    }
}

private func createCFNumber(value: Double, type: CFNumberType) -> CFNumber? {
    switch type {
    case .sInt8Type, .charType:
        var typedValue = Int8(value)
        return CFNumberCreate(kCFAllocatorDefault, type, &typedValue)
    case .sInt16Type, .shortType:
        var typedValue = Int16(value)
        return CFNumberCreate(kCFAllocatorDefault, type, &typedValue)
    case .sInt32Type, .intType:
        var typedValue = Int32(value)
        return CFNumberCreate(kCFAllocatorDefault, type, &typedValue)
    case .sInt64Type, .longLongType:
        var typedValue = Int64(value)
        return CFNumberCreate(kCFAllocatorDefault, type, &typedValue)
    case .longType, .cfIndexType, .nsIntegerType:
        var typedValue = Int(value)
        return CFNumberCreate(kCFAllocatorDefault, type, &typedValue)
    case .float32Type, .floatType:
        var typedValue = Float(value)
        return CFNumberCreate(kCFAllocatorDefault, type, &typedValue)
    case .float64Type, .doubleType, .cgFloatType:
        var typedValue = value
        return CFNumberCreate(kCFAllocatorDefault, type, &typedValue)
    @unknown default:
        return nil
    }
}
#endif
