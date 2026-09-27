#if DEBUG
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

    fileprivate var positivePosition: Double? {
        switch self {
        case let .integer(value) where value > 0 && value <= 1_000_000: Double(value)
        case let .real(value) where value.isFinite && value > 0 && value <= 1_000_000: value
        default: nil
        }
    }
}

public struct OrderingProcess: Codable, Equatable, Sendable {
    public let bundleIdentifier: String?
    public let executableName: String?
    public let pid: Int32
    public let launchTime: Date?
    public let isSystem: Bool

    public init(bundleIdentifier: String?, executableName: String?, pid: Int32, launchTime: Date?, isSystem: Bool) {
        self.bundleIdentifier = bundleIdentifier
        self.executableName = executableName
        self.pid = pid
        self.launchTime = launchTime
        self.isSystem = isSystem
    }
}

/// The deliberately bounded Apple-owned status items whose menu-bar ordering
/// identity has an exact configuration key and an independently attested host.
/// Shared-host items remain separate subjects; a host bundle is never used as
/// a substitute for the individual item identity.
public enum ExactSystemOrderingItem: String, Codable, CaseIterable, Hashable, Sendable {
    case bluetooth
    case wifi
    case sound
    case nowPlaying
    case controlCenter
    case siri
    case timeMachine
    case spotlight

    /// Product availability is separate from historical identity and recovery.
    /// These identities remain decodable so existing receipts can be restored.
    public var isOrderingOffered: Bool {
        switch self {
        case .siri, .timeMachine, .controlCenter: false
        case .bluetooth, .wifi, .sound, .nowPlaying: true
        case .spotlight:
            #if DEBUG
            true
            #else
            false
            #endif
        }
    }

    public init?(configurationKey: String) {
        guard let item = Self.allCases.first(where: { $0.configurationKey == configurationKey }) else {
            return nil
        }
        self = item
    }

    public init?(observationIdentifier: String) {
        let normalized = MenuBarItemIdentityResolver.normalize(observationIdentifier) ?? ""
        if normalized == "com.apple.menuextra.bluetooth" || normalized.contains(":bluetooth|") {
            self = .bluetooth
        } else if normalized == "com.apple.menuextra.wifi"
                    || normalized.contains(":wi-fi|") || normalized.contains(":wifi|") {
            self = .wifi
        } else if normalized == "com.apple.menuextra.sound" || normalized.contains(":sound|") {
            self = .sound
        } else if normalized == "com.apple.menuextra.now-playing"
                    || normalized.contains(":now playing|") {
            self = .nowPlaying
        } else if normalized == "com.apple.menuextra.controlcenter"
                    || normalized.contains(":control center|") {
            self = .controlCenter
        } else if normalized == "com.apple.menuextra.siri" || normalized.contains(":siri|") {
            self = .siri
        } else if normalized == "com.apple.menuextra.timemachine"
                    || normalized.contains(":time machine|") {
            self = .timeMachine
        } else if PersistentSystemItemPolicyCatalog.controllableItem(
            forObservationIdentifier: observationIdentifier
        )?.identifier == "com.apple.menuextra.spotlight" {
            self = .spotlight
        } else {
            return nil
        }
    }

    public var configurationKey: String {
        switch self {
        case .bluetooth: "module:Bluetooth"
        case .wifi: "module:WiFi"
        case .sound: "module:Sound"
        case .nowPlaying: "module:NowPlaying"
        case .controlCenter: "module:BentoBox-0"
        case .siri: "status:com.apple.systemuiserver::Siri"
        case .timeMachine: "status:com.apple.systemuiserver::com.apple.menuextra.TimeMachine"
        case .spotlight: "status:com.apple.campo::Item-0"
        }
    }

    public var hostBundleIdentifier: String {
        switch self {
        case .bluetooth, .wifi, .sound, .nowPlaying, .controlCenter:
            "com.apple.controlcenter"
        case .siri, .timeMachine: "com.apple.systemuiserver"
        case .spotlight: "com.apple.campo"
        }
    }

    public var observationIdentifier: String {
        switch self {
        case .bluetooth: "com.apple.menuextra.bluetooth"
        case .wifi: "com.apple.menuextra.wifi"
        case .sound: "com.apple.menuextra.sound"
        case .nowPlaying: "com.apple.menuextra.now-playing"
        case .controlCenter: "com.apple.menuextra.controlcenter"
        case .siri: "com.apple.menuextra.siri"
        case .timeMachine: "com.apple.menuextra.TimeMachine"
        case .spotlight: "com.apple.menuextra.spotlight"
        }
    }

    public var displayName: String {
        switch self {
        case .bluetooth: "Bluetooth"
        case .wifi: "Wi-Fi"
        case .sound: "Sound"
        case .nowPlaying: "Now Playing"
        case .controlCenter: "Control Center"
        case .siri: "Siri"
        case .timeMachine: "Time Machine"
        case .spotlight: "Spotlight"
        }
    }

    public var systemSymbolName: String {
        switch self {
        case .bluetooth: "bluetooth"
        case .wifi: "wifi"
        case .sound: "speaker.wave.2"
        case .nowPlaying: "play.square.stack"
        case .controlCenter: "switch.2"
        case .siri: "siri"
        case .timeMachine: "clock.arrow.circlepath"
        case .spotlight: "magnifyingglass"
        }
    }

    /// The primary Control Center mapping is a build-specific experimental
    /// inference. The current binary/table contract admits it only when the
    /// complete table contains exactly one BentoBox-shaped key and that key is
    /// the observed `module:BentoBox-0`. This does not generalize suffix `0`.
    public func admitsConfigurationTable(_ table: [String: OrderingValue]) -> Bool {
        table[configurationKey]?.positivePosition != nil
            && hasAdmissibleConfigurationNamespace(table)
    }

    public func hasAdmissibleConfigurationNamespace(
        _ table: [String: OrderingValue]
    ) -> Bool {
        if self == .spotlight {
            let campoKeys = table.keys.filter { $0.hasPrefix("status:com.apple.campo::") }
            return campoKeys == [configurationKey]
        }
        guard self == .controlCenter else { return true }
        let bentoBoxKeys = table.keys.filter {
            $0 == "module:BentoBox" || $0.hasPrefix("module:BentoBox-")
        }.sorted()
        return bentoBoxKeys == [configurationKey]
    }
}

/// Stable Board and transaction identity. Application and system subjects use
/// separate namespaces so a shared Apple host can never masquerade as a bundle.
public enum OrderingSubjectID: Hashable, Sendable {
    case application(String)
    case systemItem(ExactSystemOrderingItem)

    public var boardID: String {
        switch self {
        case let .application(bundleIdentifier): "application:\(bundleIdentifier)"
        case let .systemItem(item): "system:\(item.rawValue)"
        }
    }

    public init?(boardID: String) {
        if boardID.hasPrefix("application:") {
            let bundle = String(boardID.dropFirst("application:".count))
            guard OrderingSnapshot.validToken(bundle) else { return nil }
            self = .application(bundle)
            return
        }
        if boardID.hasPrefix("system:") {
            let rawValue = String(boardID.dropFirst("system:".count))
            guard let item = ExactSystemOrderingItem(rawValue: rawValue) else { return nil }
            self = .systemItem(item)
            return
        }
        return nil
    }
}

extension OrderingSubjectID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let boardID = try container.decode(String.self)
        guard let value = Self(boardID: boardID) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid ordering subject identity."
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(boardID)
    }
}

/// Capture-time evidence binding one exact item key to one signed Apple host
/// process. The backend supplies this only after validating the Apple code
/// requirement for the exact host bundle.
public struct OrderingSystemHostBinding: Codable, Equatable, Sendable {
    public let item: ExactSystemOrderingItem
    public let configurationKey: String
    public let hostProcess: OrderingProcess
    public let codeIdentityVerified: Bool

    public init(
        item: ExactSystemOrderingItem,
        configurationKey: String,
        hostProcess: OrderingProcess,
        codeIdentityVerified: Bool
    ) {
        self.item = item
        self.configurationKey = configurationKey
        self.hostProcess = hostProcess
        self.codeIdentityVerified = codeIdentityVerified
    }
}

public enum OrderingOwnerPreferenceNamespace: String, Codable, Equatable, Sendable {
    case currentUserAnyHost
    case sandboxContainer
    case sandboxed
    case unknown
}

/// Public code-signing evidence for one running application. The backend emits
/// this only after strict validity succeeds and the signing identifier matches
/// the process bundle identifier. The designated-requirement digest binds the
/// captured identity without persisting the full requirement text.
public struct OrderingApplicationCodeIdentity: Codable, Equatable, Sendable {
    public let signingIdentifier: String
    public let teamIdentifier: String?
    public let designatedRequirementDigest: String

    public init(
        signingIdentifier: String,
        teamIdentifier: String?,
        designatedRequirementDigest: String
    ) {
        self.signingIdentifier = signingIdentifier
        self.teamIdentifier = teamIdentifier
        self.designatedRequirementDigest = designatedRequirementDigest
    }
}

public struct OrderingOwnerObservation: Codable, Equatable, Sendable {
    public let process: OrderingProcess
    public let displayName: String
    public let axComplete: Bool
    public let itemFrames: [RectSnapshot]
    public let ownerPreferencesComplete: Bool
    public let ownerSavedPositions: [String: OrderingValue]
    public let ownerPreferenceNamespace: OrderingOwnerPreferenceNamespace
    public let ownerPreferenceSourceIdentity: String?
    /// Present only when public Security.framework evidence binds this running
    /// process to an exact bundle identifier. Legacy snapshots omit it.
    public let applicationCodeIdentity: OrderingApplicationCodeIdentity?

    public init(process: OrderingProcess, displayName: String, axComplete: Bool, itemFrames: [RectSnapshot],
                ownerPreferencesComplete: Bool, ownerSavedPositions: [String: OrderingValue],
                ownerPreferenceNamespace: OrderingOwnerPreferenceNamespace = .currentUserAnyHost,
                ownerPreferenceSourceIdentity: String? = nil,
                applicationCodeIdentity: OrderingApplicationCodeIdentity? = nil) {
        self.process = process
        self.displayName = displayName
        self.axComplete = axComplete
        self.itemFrames = itemFrames
        self.ownerPreferencesComplete = ownerPreferencesComplete
        self.ownerSavedPositions = ownerSavedPositions
        self.ownerPreferenceNamespace = ownerPreferenceNamespace
        self.ownerPreferenceSourceIdentity = ownerPreferenceSourceIdentity
        self.applicationCodeIdentity = applicationCodeIdentity
    }
}

public enum OrderingPolicyScope {
    public static func allows(intent: MenuBarBundlePolicy, managementEnabled: Bool) -> Bool {
        switch intent {
        case .visible:
            true
        case .revealable, .hidden:
            !managementEnabled
        }
    }
}

public struct OrderingSnapshot: Codable, Equatable, Sendable {
    public static let tableKey = "TrailingItemPreferredPositions"
    public static let supportedOperatingSystemMajorVersion = 27
    /// macOS 27 uses Darwin/build major 26. The complete build remains part of
    /// snapshot freshness, but every well-formed build in this OS major can be
    /// captured after the live private-contract probes pass.
    public static let supportedBuildMajor = 26
    /// Kept as the deterministic fixture default for the already accepted
    /// 0.10.0 build. Runtime capture records the actual admitted build.
    public static let supportedBuild = "26A5425a"
    public static let supportedArchitecture = "arm64"

    public static func supportsBuild(_ build: String) -> Bool {
        let digits = build.prefix(while: { $0.isNumber })
        let suffix = build.dropFirst(digits.count)
        guard Int(digits) == supportedBuildMajor,
              let first = suffix.first, first.isASCII, first.isUppercase,
              first.isLetter else { return false }
        return suffix.dropFirst().allSatisfy {
            $0.isASCII && ($0.isLetter || $0.isNumber)
        }
    }

    public let schemaVersion: Int
    public let group: [String: OrderingValue]
    public let beforeProcesses: [OrderingProcess]
    public let afterProcesses: [OrderingProcess]
    public let observationsByPID: [Int32: OrderingOwnerObservation]
    public let osBuild: String
    public let architecture: String
    public let runtimeContractVerified: Bool
    public let displaySignature: String
    public let displayCount: Int
    public let displayFrame: RectSnapshot
    public let lifecycleGeneration: Int
    public let policyFingerprint: String
    public let orderingAllowedBundleIdentifiers: Set<String>
    /// Absent in legacy snapshots. A non-empty value is exact per-item Apple
    /// host evidence, not an application-owner observation.
    public let systemHostBindings: [OrderingSystemHostBinding]?
    public let capturedAt: Date

    public init(group: [String: OrderingValue], beforeProcesses: [OrderingProcess],
                afterProcesses: [OrderingProcess],
                observationsByPID: [Int32: OrderingOwnerObservation], osBuild: String,
                architecture: String, runtimeContractVerified: Bool, displaySignature: String,
                displayCount: Int, displayFrame: RectSnapshot, lifecycleGeneration: Int,
                policyFingerprint: String, orderingAllowedBundleIdentifiers: Set<String>,
                systemHostBindings: [OrderingSystemHostBinding] = [], capturedAt: Date) throws {
        schemaVersion = 1
        self.group = group
        self.beforeProcesses = beforeProcesses
        self.afterProcesses = afterProcesses
        self.observationsByPID = observationsByPID
        self.osBuild = osBuild
        self.architecture = architecture
        self.runtimeContractVerified = runtimeContractVerified
        self.displaySignature = displaySignature
        self.displayCount = displayCount
        self.displayFrame = displayFrame
        self.lifecycleGeneration = lifecycleGeneration
        self.policyFingerprint = policyFingerprint
        self.orderingAllowedBundleIdentifiers = orderingAllowedBundleIdentifiers
        self.systemHostBindings = systemHostBindings.isEmpty ? nil : systemHostBindings
        self.capturedAt = capturedAt
        try validate()
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, group, beforeProcesses, afterProcesses, observationsByPID
        case osBuild, architecture, runtimeContractVerified, displaySignature
        case displayCount, displayFrame, lifecycleGeneration, policyFingerprint
        case orderingAllowedBundleIdentifiers, systemHostBindings, capturedAt
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(group, forKey: .group)
        try container.encode(beforeProcesses, forKey: .beforeProcesses)
        try container.encode(afterProcesses, forKey: .afterProcesses)
        // JSONEncoder encodes dictionaries with non-string keys as alternating
        // key/value arrays; sortedKeys does not order those entries.
        var observations = container.nestedUnkeyedContainer(forKey: .observationsByPID)
        for pid in observationsByPID.keys.sorted() {
            try observations.encode(pid)
            try observations.encode(observationsByPID[pid])
        }
        try container.encode(osBuild, forKey: .osBuild)
        try container.encode(architecture, forKey: .architecture)
        try container.encode(runtimeContractVerified, forKey: .runtimeContractVerified)
        try container.encode(displaySignature, forKey: .displaySignature)
        try container.encode(displayCount, forKey: .displayCount)
        try container.encode(displayFrame, forKey: .displayFrame)
        try container.encode(lifecycleGeneration, forKey: .lifecycleGeneration)
        try container.encode(policyFingerprint, forKey: .policyFingerprint)
        try container.encode(orderingAllowedBundleIdentifiers.sorted(), forKey: .orderingAllowedBundleIdentifiers)
        try container.encodeIfPresent(systemHostBindings, forKey: .systemHostBindings)
        try container.encode(capturedAt, forKey: .capturedAt)
    }

    public func table() throws -> [String: OrderingValue] {
        guard case let .dictionary(table)? = group[Self.tableKey] else {
            throw OrderingError.invalidSnapshot("the complete preferred-position table is missing")
        }
        return table
    }

    /// Verifies only the live process identities that can own the supplied
    /// configuration keys. Unrelated application launches and exits do not
    /// invalidate a reviewed configuration write, while a target replacement,
    /// duplicate bundle owner or token collision still fails closed.
    public func validateConfigurationProcessScope(
        for keys: Set<String>, against currentProcesses: [OrderingProcess]
    ) throws {
        guard keys.allSatisfy({ ExactSystemOrderingItem(configurationKey: $0) == nil }) else {
            throw OrderingError.staleSnapshot("exact system host evidence is missing")
        }
        try validateConfigurationProcessScope(
            for: keys, against: currentProcesses, systemHostBindings: []
        )
    }

    public func validateConfigurationProcessScope(
        for keys: Set<String>, against snapshot: OrderingSnapshot
    ) throws {
        try snapshot.validate()
        let currentTable = try snapshot.table()
        guard keys.compactMap({ ExactSystemOrderingItem(configurationKey: $0) })
            .allSatisfy({ $0.admitsConfigurationTable(currentTable) }) else {
            throw OrderingError.staleSnapshot("an exact system configuration namespace changed")
        }
        try validateConfigurationProcessScope(
            for: keys,
            against: snapshot.afterProcesses,
            systemHostBindings: snapshot.systemHostBindings ?? []
        )
    }

    public func validateConfigurationProcessScope(
        for keys: Set<String>, against currentProcesses: [OrderingProcess],
        systemHostBindings currentSystemHostBindings: [OrderingSystemHostBinding]
    ) throws {
        try validate()
        guard !keys.isEmpty, keys.count <= OrderingPlan.maximumConfigurationKeys else {
            throw OrderingError.staleSnapshot("the target key scope changed")
        }
        try Self.validateProcesses(currentProcesses)
        guard Set(currentSystemHostBindings.map(\.item)).count
                == currentSystemHostBindings.count else {
            throw OrderingError.staleSnapshot("exact system host evidence is duplicated")
        }
        let expectedInventory = (beforeProcesses + afterProcesses).reduce(
            into: [OrderingProcess]()) { result, process in
                if !result.contains(process) { result.append(process) }
            }
        var expectedOwners: [OrderingProcess] = []
        for key in keys {
            if let item = ExactSystemOrderingItem(configurationKey: key) {
                let expectedBindings = systemHostBindings?.filter { $0.item == item } ?? []
                let currentBindings = currentSystemHostBindings.filter { $0.item == item }
                guard expectedBindings.count == 1, currentBindings.count == 1,
                      let expectedBinding = expectedBindings.first,
                      let currentBinding = currentBindings.first,
                      expectedBinding == currentBinding,
                      currentBinding.configurationKey == key,
                      currentBinding.codeIdentityVerified else {
                    throw OrderingError.staleSnapshot("an exact system host binding changed")
                }
                let matchingHosts = currentProcesses.filter {
                    $0.bundleIdentifier == item.hostBundleIdentifier
                }
                guard matchingHosts == [currentBinding.hostProcess] else {
                    throw OrderingError.staleSnapshot("an exact system host process changed")
                }
                if key.hasPrefix("status:"), let token = Self.configurationToken(for: key) {
                    let expectedMatches = expectedInventory.filter {
                        $0.bundleIdentifier == token || $0.executableName == token
                    }
                    let currentMatches = currentProcesses.filter {
                        $0.bundleIdentifier == token || $0.executableName == token
                    }
                    guard expectedMatches == [expectedBinding.hostProcess],
                          currentMatches == [currentBinding.hostProcess] else {
                        throw OrderingError.staleSnapshot("a system status-key token collides")
                    }
                }
                continue
            }
            guard let token = Self.configurationToken(for: key) else {
                throw OrderingError.staleSnapshot("a target key is no longer attributable")
            }
            let expectedMatches = expectedInventory.filter {
                $0.bundleIdentifier == token || $0.executableName == token
            }
            guard expectedMatches.count == 1, let expectedOwner = expectedMatches.first else {
                throw OrderingError.staleSnapshot("a target key is no longer uniquely attributable")
            }
            let currentMatches = currentProcesses.filter {
                $0.bundleIdentifier == token || $0.executableName == token
            }
            guard Self.sortedProcesses(currentMatches) == [expectedOwner] else {
                throw OrderingError.staleSnapshot("a target process or token binding changed")
            }
            if !expectedOwners.contains(expectedOwner) { expectedOwners.append(expectedOwner) }
        }
        for owner in expectedOwners {
            guard let bundle = owner.bundleIdentifier,
                  Self.sortedProcesses(currentProcesses.filter({ $0.bundleIdentifier == bundle }))
                    == [owner] else {
                throw OrderingError.staleSnapshot("a target owner process changed")
            }
        }
    }

    public var canonicalFingerprint: String {
        get throws {
            struct ObservationBinding: Codable {
                let pid: Int32
                let observation: OrderingOwnerObservation
            }
            struct LegacyBinding: Codable {
                let schemaVersion: Int
                let group: [String: OrderingValue]
                let beforeProcesses: [OrderingProcess]
                let afterProcesses: [OrderingProcess]
                let observations: [ObservationBinding]
                let osBuild: String
                let architecture: String
                let runtimeContractVerified: Bool
                let displaySignature: String
                let displayCount: Int
                let displayFrame: RectSnapshot
                let lifecycleGeneration: Int
                let policyFingerprint: String
                let orderingAllowedBundleIdentifiers: [String]
                let capturedAt: Date
            }
            struct SystemBinding: Codable {
                let legacy: LegacyBinding
                let systemHostBindings: [OrderingSystemHostBinding]
            }
            try validate()
            let legacy = LegacyBinding(schemaVersion: schemaVersion, group: group,
                beforeProcesses: Self.sortedProcesses(beforeProcesses),
                afterProcesses: Self.sortedProcesses(afterProcesses),
                observations: observationsByPID.keys.sorted().map {
                    ObservationBinding(pid: $0, observation: observationsByPID[$0]!)
                }, osBuild: osBuild, architecture: architecture,
                runtimeContractVerified: runtimeContractVerified,
                displaySignature: displaySignature, displayCount: displayCount,
                displayFrame: displayFrame, lifecycleGeneration: lifecycleGeneration,
                policyFingerprint: policyFingerprint,
                orderingAllowedBundleIdentifiers: orderingAllowedBundleIdentifiers.sorted(), capturedAt: capturedAt)
            guard let systemHostBindings else {
                return try OrderingDigest.hash(legacy)
            }
            return try OrderingDigest.hash(SystemBinding(
                legacy: legacy,
                systemHostBindings: systemHostBindings.sorted { $0.item.rawValue < $1.item.rawValue }
            ))
        }
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw OrderingError.invalidSnapshot("unknown schema") }
        guard Self.supportsBuild(osBuild), architecture == Self.supportedArchitecture,
              runtimeContractVerified else { throw OrderingError.unsupportedRuntime }
        guard (1...16).contains(displayCount), !displaySignature.isEmpty, lifecycleGeneration >= 0,
              !policyFingerprint.isEmpty, Self.valid(displayFrame), displayFrame.width > 0,
              displayFrame.height > 0, capturedAt.timeIntervalSinceReferenceDate.isFinite else {
            throw OrderingError.invalidSnapshot("unsupported display or lifecycle context")
        }
        guard group.count <= 512, beforeProcesses.count <= 512, afterProcesses.count <= 512,
              observationsByPID.count <= 512, orderingAllowedBundleIdentifiers.count <= 512 else {
            throw OrderingError.propertyListLimitExceeded
        }
        try OrderingValue.dictionary(group).validate()
        _ = try table()
        try Self.validateProcesses(beforeProcesses)
        try Self.validateProcesses(afterProcesses)
        for (pid, observation) in observationsByPID {
            guard pid == observation.process.pid, beforeProcesses.contains(observation.process),
                  !observation.displayName.isEmpty, observation.itemFrames.count <= 16,
                  observation.ownerSavedPositions.count <= 64 else {
                throw OrderingError.invalidSnapshot("owner observation metadata differs")
            }
            try OrderingValue.dictionary(observation.ownerSavedPositions).validate()
            if let source = observation.ownerPreferenceSourceIdentity {
                guard source.utf8.count == 64,
                      source.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
                    throw OrderingError.invalidSnapshot("owner preference source identity is invalid")
                }
            }
            if let identity = observation.applicationCodeIdentity {
                guard identity.signingIdentifier == observation.process.bundleIdentifier,
                      Self.validToken(identity.signingIdentifier),
                      identity.teamIdentifier.map(Self.validToken) != false,
                      Self.validSHA256(identity.designatedRequirementDigest) else {
                    throw OrderingError.invalidSnapshot("application code identity is invalid")
                }
            }
            guard observation.itemFrames.allSatisfy(Self.valid) else {
                throw OrderingError.invalidSnapshot("an AX frame is invalid")
            }
        }
        guard orderingAllowedBundleIdentifiers.allSatisfy(Self.validToken) else {
            throw OrderingError.invalidSnapshot("ordering policy scope contains an invalid bundle identifier")
        }
        if let systemHostBindings {
            guard !systemHostBindings.isEmpty,
                  systemHostBindings.count <= ExactSystemOrderingItem.allCases.count,
                  Set(systemHostBindings.map(\.item)).count == systemHostBindings.count else {
                throw OrderingError.invalidSnapshot("system host bindings are duplicated or empty")
            }
            let inventory = beforeProcesses + afterProcesses
            for binding in systemHostBindings {
                let process = binding.hostProcess
                guard binding.configurationKey == binding.item.configurationKey,
                      binding.codeIdentityVerified,
                      process.bundleIdentifier == binding.item.hostBundleIdentifier,
                      process.isSystem, process.launchTime != nil,
                      beforeProcesses.filter({ $0.bundleIdentifier == binding.item.hostBundleIdentifier })
                        == [process],
                      afterProcesses.filter({ $0.bundleIdentifier == binding.item.hostBundleIdentifier })
                        == [process],
                      inventory.contains(process),
                      binding.item.admitsConfigurationTable(try table()) else {
                    throw OrderingError.invalidSnapshot("an exact system host binding is invalid")
                }
            }
        }
    }

    private static func validateProcesses(_ processes: [OrderingProcess]) throws {
        guard Set(processes.map(\.pid)).count == processes.count else {
            throw OrderingError.invalidSnapshot("duplicate process identifier")
        }
        for process in processes {
            guard process.pid > 0, process.launchTime?.timeIntervalSinceReferenceDate.isFinite != false,
                  process.bundleIdentifier.map(validToken) != false,
                  process.executableName.map(validToken) != false else {
                throw OrderingError.invalidSnapshot("invalid process descriptor")
            }
        }
    }

    private static func configurationToken(for key: String) -> String? {
        guard key.hasPrefix("status:") else { return nil }
        let pieces = key.dropFirst("status:".count).components(separatedBy: "::")
        guard pieces.count == 2, validToken(pieces[0]), validToken(pieces[1]) else {
            return nil
        }
        return pieces[0]
    }

    fileprivate static func valid(_ frame: RectSnapshot) -> Bool {
        [frame.x, frame.y, frame.width, frame.height].allSatisfy(\.isFinite)
            && frame.width >= 0 && frame.height >= 0
    }

    fileprivate static func validToken(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 1_024
            && !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    }

    fileprivate static func validSHA256(_ value: String) -> Bool {
        value.utf8.count == 64
            && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    fileprivate static func sortedProcesses(_ values: [OrderingProcess]) -> [OrderingProcess] {
        values.sorted {
            if $0.pid != $1.pid { return $0.pid < $1.pid }
            return ($0.bundleIdentifier ?? "") < ($1.bundleIdentifier ?? "")
        }
    }
}

public enum OrderingEligibilityReason: String, Codable, Equatable, Sendable {
    case singleDisplayRequired
    case selfExcluded
    case systemOwnerExcluded
    case duplicateBundleOwner
    case ownerLifetimeUnverified
    case ownerTokenCollision
    case missingConfiguredKey
    case multipleAssociatedKeys
    case configuredPositionInvalid
    case observationMissing
    case accessibilityIncomplete
    case singleItemNotEstablished
    case ownerPreferencesIncomplete
    case ownerPreferenceNamespaceUnsupported
    case ownerAutosaveMismatch
    case ownerSavedPositionInvalid
    case policyScopeExcluded
    case geometryInvalid
    case geometryAmbiguous
    case systemHostBindingMissing
    case systemHostCollision
    case systemCodeIdentityUnverified
    case systemKeyMismatch
    case systemConfigurationNamespaceAmbiguous

    public var userDescription: String {
        switch self {
        case .singleDisplayRequired: "ordering requires exactly one display"
        case .selfExcluded: "Blenny itself is excluded"
        case .systemOwnerExcluded: "Apple and system owners are excluded"
        case .duplicateBundleOwner: "more than one process owns the bundle"
        case .ownerLifetimeUnverified: "the process lifetime changed or is unknown"
        case .ownerTokenCollision: "the bundle or executable token collides"
        case .missingConfiguredKey: "no configured system key was found"
        case .multipleAssociatedKeys: "more than one configured system key belongs to the bundle"
        case .configuredPositionInvalid: "the configured position is not a finite positive number"
        case .observationMissing: "the owner observation is missing"
        case .accessibilityIncomplete: "Accessibility enumeration is incomplete"
        case .singleItemNotEstablished: "exactly one live menu-bar item was not established"
        case .ownerPreferencesIncomplete: "the owner preference read is incomplete"
        case .ownerPreferenceNamespaceUnsupported: "the owner preference namespace is unsupported"
        case .ownerAutosaveMismatch: "the sole owner autosave name does not match the system key"
        case .ownerSavedPositionInvalid: "the owner saved position is invalid"
        case .policyScopeExcluded: "the current accepted policy scope excludes this bundle"
        case .geometryInvalid: "the item is not visibly contained by the known display"
        case .geometryAmbiguous: "the observed frame is shared with or nested inside another owner"
        case .systemHostBindingMissing: "the exact signed Apple host binding is missing"
        case .systemHostCollision: "the exact Apple host process is duplicated or changed"
        case .systemCodeIdentityUnverified: "the Apple host code identity is unverified"
        case .systemKeyMismatch: "the system item key does not match the exact catalog mapping"
        case .systemConfigurationNamespaceAmbiguous:
            "the build-specific system item configuration namespace is missing or ambiguous"
        }
    }
}

public struct OrderingBundleCandidate: Codable, Equatable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let process: OrderingProcess?
    public let key: String?
    public let persistentIdentifier: String?
    public let configuredValue: OrderingValue?
    public let ownerSavedValue: OrderingValue?
    public let frame: RectSnapshot?
    public let reasons: [OrderingEligibilityReason]
    public var eligible: Bool { reasons.isEmpty }
}

public enum OrderingObservedGeometry {
    /// Returns owners whose horizontally identical or nested rectangles cannot
    /// establish separate visible menu-bar slots. Ordinary partial overlap remains
    /// distinguishable when both horizontal edges agree on the relative order.
    public static func ambiguousOwners(frames: [String: RectSnapshot]) -> Set<String> {
        let validFrames = frames.filter { _, frame in
            OrderingSnapshot.valid(frame) && frame.width > 0 && frame.height > 0
        }
        let owners = validFrames.keys.sorted()
        var ambiguous: Set<String> = []
        for firstIndex in owners.indices {
            let firstOwner = owners[firstIndex]
            let first = validFrames[firstOwner]!
            for secondOwner in owners[owners.index(after: firstIndex)...] {
                let second = validFrames[secondOwner]!
                guard verticalRangesIntersect(first, second) else { continue }
                let firstContainsSecond = first.x <= second.x
                    && first.x + first.width >= second.x + second.width
                let secondContainsFirst = second.x <= first.x
                    && second.x + second.width >= first.x + first.width
                if firstContainsSecond || secondContainsFirst {
                    ambiguous.insert(firstOwner)
                    ambiguous.insert(secondOwner)
                }
            }
        }
        return ambiguous
    }

    private static func verticalRangesIntersect(_ first: RectSnapshot, _ second: RectSnapshot) -> Bool {
        max(first.y, second.y) < min(first.y + first.height, second.y + second.height)
    }
}

public enum OrderingIdentityResolver {
    public static func resolve(snapshot: OrderingSnapshot) throws -> [OrderingBundleCandidate] {
        try snapshot.validate()
        let table = try snapshot.table()
        var observedFramesByPID: [String: RectSnapshot] = [:]
        var bundleByPIDToken: [String: String] = [:]
        for (pid, observation) in snapshot.observationsByPID
            where observation.itemFrames.count == 1 {
            guard let bundle = observation.process.bundleIdentifier else { continue }
            let token = String(pid)
            observedFramesByPID[token] = observation.itemFrames[0]
            bundleByPIDToken[token] = bundle
        }
        let ambiguousBundles = Set(OrderingObservedGeometry.ambiguousOwners(
            frames: observedFramesByPID
        ).compactMap { bundleByPIDToken[$0] })
        let completeProcessInventory = (snapshot.beforeProcesses + snapshot.afterProcesses).reduce(into: [OrderingProcess]()) {
            if !$0.contains($1) { $0.append($1) }
        }
        let parsedKeys = table.keys.sorted().compactMap { key -> (String, String, String)? in
            guard let parsed = parse(key: key) else { return nil }
            return (key, parsed.token, parsed.persistentIdentifier)
        }
        let grouped = Dictionary(grouping: snapshot.beforeProcesses.compactMap { process in
            process.bundleIdentifier.map { ($0, process) }
        }, by: { $0.0 })

        return grouped.keys.sorted().map { bundle in
            let owners = grouped[bundle]!.map(\.1)
            let process = owners.count == 1 ? owners[0] : nil
            var reasons: [OrderingEligibilityReason] = []
            if snapshot.displayCount != 1 { reasons.append(.singleDisplayRequired) }
            let laterBundleOwners = snapshot.afterProcesses.filter { $0.bundleIdentifier == bundle }
            if owners.count != 1 || laterBundleOwners.count != 1 { reasons.append(.duplicateBundleOwner) }
            if bundle == "xyz.fi5h.blenny" { reasons.append(.selfExcluded) }
            if (bundle.hasPrefix("com.apple.") || owners.contains(where: \.isSystem))
                && !ExperimentalAppleBundlePolicyCatalog.contains(bundle) {
                reasons.append(.systemOwnerExcluded)
            }

            var key: String?
            var persistentIdentifier: String?
            var configuredValue: OrderingValue?
            var ownerSavedValue: OrderingValue?
            var frame: RectSnapshot?
            var displayName = bundle

            if let process {
                let later = snapshot.afterProcesses.filter { $0.pid == process.pid }
                if process.launchTime == nil || later.count != 1 || later[0] != process {
                    reasons.append(.ownerLifetimeUnverified)
                }

                var associated: [(String, String)] = []
                var collision = false
                for parsed in parsedKeys {
                    let matches = completeProcessInventory.filter { candidate in
                        parsed.1 == candidate.bundleIdentifier || parsed.1 == candidate.executableName
                    }
                    if matches.contains(process) {
                        if matches.count == 1 { associated.append((parsed.0, parsed.2)) }
                        else { collision = true }
                    }
                }
                if collision { reasons.append(.ownerTokenCollision) }
                if associated.isEmpty { reasons.append(.missingConfiguredKey) }
                if associated.count > 1 { reasons.append(.multipleAssociatedKeys) }
                if associated.count == 1 {
                    key = associated[0].0
                    persistentIdentifier = associated[0].1
                    configuredValue = table[key!]
                    if configuredValue?.positivePosition == nil { reasons.append(.configuredPositionInvalid) }
                }

                if let observation = snapshot.observationsByPID[process.pid] {
                    displayName = observation.displayName
                    if observation.process != process { reasons.append(.ownerLifetimeUnverified) }
                    if !observation.axComplete { reasons.append(.accessibilityIncomplete) }
                    if observation.itemFrames.count != 1 { reasons.append(.singleItemNotEstablished) }
                    if !observation.ownerPreferencesComplete { reasons.append(.ownerPreferencesIncomplete) }
                    let namespaceVerified = observation.ownerPreferenceNamespace == .currentUserAnyHost
                        || (observation.ownerPreferenceNamespace == .sandboxContainer
                            && observation.ownerPreferenceSourceIdentity != nil)
                    if !namespaceVerified {
                        reasons.append(.ownerPreferenceNamespaceUnsupported)
                    }
                    if observation.ownerSavedPositions.count != 1
                        || persistentIdentifier == nil
                        || observation.ownerSavedPositions[persistentIdentifier!] == nil {
                        reasons.append(.ownerAutosaveMismatch)
                    } else {
                        ownerSavedValue = observation.ownerSavedPositions[persistentIdentifier!]
                        if ownerSavedValue?.positivePosition == nil { reasons.append(.ownerSavedPositionInvalid) }
                    }
                    if observation.itemFrames.count == 1 {
                        let observedFrame = observation.itemFrames[0]
                        let isVisible = visible(observedFrame, in: snapshot.displayFrame)
                        let isAmbiguous = ambiguousBundles.contains(bundle)
                        if !isVisible {
                            reasons.append(.geometryInvalid)
                        }
                        if isAmbiguous {
                            reasons.append(.geometryAmbiguous)
                        }
                        if isVisible && !isAmbiguous {
                            frame = observedFrame
                        }
                    }
                } else {
                    reasons.append(.observationMissing)
                }
                if !snapshot.orderingAllowedBundleIdentifiers.contains(bundle) { reasons.append(.policyScopeExcluded) }
            }

            return OrderingBundleCandidate(bundleIdentifier: bundle, displayName: displayName,
                process: process, key: key, persistentIdentifier: persistentIdentifier,
                configuredValue: configuredValue, ownerSavedValue: ownerSavedValue,
                frame: frame, reasons: deduplicated(reasons))
        }
    }

    private static func parse(key: String) -> (token: String, persistentIdentifier: String)? {
        guard key.hasPrefix("status:"), key.components(separatedBy: "::").count == 2 else { return nil }
        let body = String(key.dropFirst("status:".count))
        let pieces = body.components(separatedBy: "::")
        guard pieces.count == 2, OrderingSnapshot.validToken(pieces[0]),
              OrderingSnapshot.validToken(pieces[1]) else { return nil }
        return (pieces[0], pieces[1])
    }

    private static func visible(_ frame: RectSnapshot, in display: RectSnapshot) -> Bool {
        guard OrderingSnapshot.valid(frame), frame.width > 0, frame.height > 0 else { return false }
        return frame.x >= display.x && frame.y >= display.y
            && frame.x + frame.width <= display.x + display.width
            && frame.y + frame.height <= display.y + display.height
    }

    private static func deduplicated(_ reasons: [OrderingEligibilityReason]) -> [OrderingEligibilityReason] {
        var seen: Set<String> = []
        return reasons.filter { seen.insert($0.rawValue).inserted }
    }
}

public struct OrderingTarget: Codable, Equatable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let key: String
    public let before: OrderingValue
    public let after: OrderingValue
    public let process: OrderingProcess
    public let frame: RectSnapshot
}

/// One exact configured key belonging to an application owner. Configuration
/// ordering always moves every resolved key for an owner as one bundle-level
/// block; it never exposes per-status-item selection.
public struct OrderingConfigurationKeyTarget: Codable, Equatable, Sendable {
    public let key: String
    public let persistentIdentifier: String
    public let before: OrderingValue
    public let after: OrderingValue

    public init(
        key: String, persistentIdentifier: String,
        before: OrderingValue, after: OrderingValue
    ) {
        self.key = key
        self.persistentIdentifier = persistentIdentifier
        self.before = before
        self.after = after
    }
}

public struct OrderingConfigurationOwnerTarget: Codable, Equatable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let process: OrderingProcess
    public let keys: [OrderingConfigurationKeyTarget]
    public let ownerSavedPositions: [String: OrderingValue]
    public let ownerPreferenceNamespace: OrderingOwnerPreferenceNamespace
    public let ownerPreferenceSourceIdentity: String?
    /// Non-nil only when the owner has an exact bundle-ID status key anchor and
    /// every associated bundle/executable token is unique to the same process.
    /// This public signing proof replaces cross-application preference evidence
    /// for that narrow configuration identity route.
    public let exactBundleCodeIdentity: OrderingApplicationCodeIdentity?

    public init(
        bundleIdentifier: String, displayName: String,
        process: OrderingProcess, keys: [OrderingConfigurationKeyTarget],
        ownerSavedPositions: [String: OrderingValue],
        ownerPreferenceNamespace: OrderingOwnerPreferenceNamespace,
        ownerPreferenceSourceIdentity: String?,
        exactBundleCodeIdentity: OrderingApplicationCodeIdentity? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.process = process
        self.keys = keys
        self.ownerSavedPositions = ownerSavedPositions
        self.ownerPreferenceNamespace = ownerPreferenceNamespace
        self.ownerPreferenceSourceIdentity = ownerPreferenceSourceIdentity
        self.exactBundleCodeIdentity = exactBundleCodeIdentity
    }
}

public struct OrderingConfigurationSystemTarget: Codable, Equatable, Sendable {
    public let item: ExactSystemOrderingItem
    public let displayName: String
    public let hostBinding: OrderingSystemHostBinding
    public let key: OrderingConfigurationKeyTarget

    public init(
        item: ExactSystemOrderingItem,
        displayName: String,
        hostBinding: OrderingSystemHostBinding,
        key: OrderingConfigurationKeyTarget
    ) {
        self.item = item
        self.displayName = displayName
        self.hostBinding = hostBinding
        self.key = key
    }
}

/// One ordered configuration subject. Application cases preserve whole-owner
/// grouping; system cases are the six exact per-item exceptions above.
public enum OrderingConfigurationSubjectTarget: Codable, Equatable, Sendable {
    case application(OrderingConfigurationOwnerTarget)
    case systemItem(OrderingConfigurationSystemTarget)

    public var subjectID: OrderingSubjectID {
        switch self {
        case let .application(target): .application(target.bundleIdentifier)
        case let .systemItem(target): .systemItem(target.item)
        }
    }

    public var displayName: String {
        switch self {
        case let .application(target): target.displayName
        case let .systemItem(target): target.displayName
        }
    }

    public var process: OrderingProcess {
        switch self {
        case let .application(target): target.process
        case let .systemItem(target): target.hostBinding.hostProcess
        }
    }

    public var keys: [OrderingConfigurationKeyTarget] {
        switch self {
        case let .application(target): target.keys
        case let .systemItem(target): [target.key]
        }
    }
}

public struct OrderingConfigurationSystemCandidate: Equatable, Sendable {
    public let item: ExactSystemOrderingItem
    public let displayName: String
    public let hostBinding: OrderingSystemHostBinding?
    public let key: String
    public let value: OrderingValue?
    public let reasons: [OrderingEligibilityReason]

    public var subjectID: OrderingSubjectID { .systemItem(item) }
    public var eligible: Bool { reasons.isEmpty }
}

public enum OrderingSystemConfigurationIdentityResolver {
    public static func resolve(
        snapshot: OrderingSnapshot
    ) throws -> [OrderingConfigurationSystemCandidate] {
        try snapshot.validate()
        let table = try snapshot.table()
        let bindings = snapshot.systemHostBindings ?? []
        let inventory = (snapshot.beforeProcesses + snapshot.afterProcesses).reduce(
            into: [OrderingProcess]()) { result, process in
                if !result.contains(process) { result.append(process) }
            }
        return ExactSystemOrderingItem.allCases.map { item in
            let matchingBindings = bindings.filter { $0.item == item }
            let binding = matchingBindings.count == 1 ? matchingBindings[0] : nil
            var reasons: [OrderingEligibilityReason] = []
            if snapshot.displayCount != 1 { reasons.append(.singleDisplayRequired) }
            let value = table[item.configurationKey]
            if value == nil { reasons.append(.missingConfiguredKey) }
            if value?.positivePosition == nil { reasons.append(.configuredPositionInvalid) }
            if item == .controlCenter,
               !item.hasAdmissibleConfigurationNamespace(table) {
                reasons.append(.systemConfigurationNamespaceAmbiguous)
            }
            if binding == nil { reasons.append(.systemHostBindingMissing) }
            if let binding {
                if binding.configurationKey != item.configurationKey {
                    reasons.append(.systemKeyMismatch)
                }
                if !binding.codeIdentityVerified {
                    reasons.append(.systemCodeIdentityUnverified)
                }
                let before = snapshot.beforeProcesses.filter {
                    $0.bundleIdentifier == item.hostBundleIdentifier
                }
                let after = snapshot.afterProcesses.filter {
                    $0.bundleIdentifier == item.hostBundleIdentifier
                }
                if before != [binding.hostProcess] || after != [binding.hostProcess] {
                    reasons.append(.systemHostCollision)
                }
                if item.configurationKey.hasPrefix("status:"),
                   inventory.filter({
                       $0.bundleIdentifier == item.hostBundleIdentifier
                           || $0.executableName == item.hostBundleIdentifier
                   }) != [binding.hostProcess] {
                    reasons.append(.ownerTokenCollision)
                }
            }
            return OrderingConfigurationSystemCandidate(
                item: item, displayName: item.displayName, hostBinding: binding,
                key: item.configurationKey, value: value,
                reasons: deduplicated(reasons)
            )
        }
    }

    private static func deduplicated(
        _ reasons: [OrderingEligibilityReason]
    ) -> [OrderingEligibilityReason] {
        var seen: Set<String> = []
        return reasons.filter { seen.insert($0.rawValue).inserted }
    }
}

public struct OrderingConfigurationSubjectCandidate: Equatable, Sendable {
    public let subjectID: OrderingSubjectID
    public let displayName: String
    public let keys: [(key: String, persistentIdentifier: String, value: OrderingValue)]
    public let reasons: [OrderingEligibilityReason]

    public var eligible: Bool { reasons.isEmpty }

    public static func == (
        lhs: OrderingConfigurationSubjectCandidate,
        rhs: OrderingConfigurationSubjectCandidate
    ) -> Bool {
        lhs.subjectID == rhs.subjectID
            && lhs.displayName == rhs.displayName
            && lhs.keys.map { [$0.key, $0.persistentIdentifier] }
                == rhs.keys.map { [$0.key, $0.persistentIdentifier] }
            && lhs.keys.map(\.value) == rhs.keys.map(\.value)
            && lhs.reasons == rhs.reasons
    }
}

public enum OrderingConfigurationSubjectIdentityResolver {
    public static func resolve(
        snapshot: OrderingSnapshot
    ) throws -> [OrderingConfigurationSubjectCandidate] {
        let applications = try OrderingConfigurationIdentityResolver.resolve(snapshot: snapshot).map {
            OrderingConfigurationSubjectCandidate(
                subjectID: .application($0.bundleIdentifier),
                displayName: $0.displayName, keys: $0.keys, reasons: $0.reasons
            )
        }
        let systems = try OrderingSystemConfigurationIdentityResolver.resolve(snapshot: snapshot).map { candidate in
            OrderingConfigurationSubjectCandidate(
                subjectID: .systemItem(candidate.item), displayName: candidate.displayName,
                keys: candidate.value.map {
                    [(candidate.key, candidate.item.rawValue, $0)]
                } ?? [],
                reasons: candidate.reasons
            )
        }
        return applications + systems
    }
}

public enum OrderingPhysicalVerificationStatus: String, Codable, Equatable, Sendable {
    case unavailable
    case verified
    case mismatch
}

public struct OrderingConfigurationBundleCandidate: Equatable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let process: OrderingProcess?
    public let keys: [(key: String, persistentIdentifier: String, value: OrderingValue)]
    public let ownerSavedPositions: [String: OrderingValue]
    public let exactBundleCodeIdentity: OrderingApplicationCodeIdentity?
    public let reasons: [OrderingEligibilityReason]

    public var eligible: Bool { reasons.isEmpty }

    public static func == (
        lhs: OrderingConfigurationBundleCandidate,
        rhs: OrderingConfigurationBundleCandidate
    ) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
            && lhs.displayName == rhs.displayName
            && lhs.process == rhs.process
            && lhs.keys.map { [$0.key, $0.persistentIdentifier] } == rhs.keys.map { [$0.key, $0.persistentIdentifier] }
            && lhs.keys.map(\.value) == rhs.keys.map(\.value)
            && lhs.ownerSavedPositions == rhs.ownerSavedPositions
            && lhs.exactBundleCodeIdentity == rhs.exactBundleCodeIdentity
            && lhs.reasons == rhs.reasons
    }
}

/// Configuration eligibility deliberately excludes AX geometry and policy area.
/// Those inputs describe visual evidence, not whether an exact preference write
/// can be attributed and recovered.
public enum OrderingConfigurationIdentityResolver {
    public static func resolve(snapshot: OrderingSnapshot) throws -> [OrderingConfigurationBundleCandidate] {
        try snapshot.validate()
        let table = try snapshot.table()
        let inventory = (snapshot.beforeProcesses + snapshot.afterProcesses).reduce(into: [OrderingProcess]()) {
            if !$0.contains($1) { $0.append($1) }
        }
        let parsedKeys = table.keys.sorted().compactMap { key -> (String, String, String)? in
            guard let parsed = parse(key: key) else { return nil }
            return (key, parsed.token, parsed.persistentIdentifier)
        }
        let grouped = Dictionary(grouping: snapshot.beforeProcesses.compactMap { process in
            process.bundleIdentifier.map { ($0, process) }
        }, by: { $0.0 })

        return grouped.keys.sorted().map { bundle in
            let owners = grouped[bundle]!.map(\.1)
            let process = owners.count == 1 ? owners[0] : nil
            var reasons: [OrderingEligibilityReason] = []
            var keys: [(key: String, persistentIdentifier: String, value: OrderingValue)] = []
            var displayName = bundle
            var ownerSavedPositions: [String: OrderingValue] = [:]
            var exactBundleCodeIdentity: OrderingApplicationCodeIdentity?

            if snapshot.displayCount != 1 { reasons.append(.singleDisplayRequired) }
            if owners.count != 1 || snapshot.afterProcesses.filter({ $0.bundleIdentifier == bundle }).count != 1 {
                reasons.append(.duplicateBundleOwner)
            }
            if bundle == "xyz.fi5h.blenny" { reasons.append(.selfExcluded) }
            if (bundle.hasPrefix("com.apple.") || owners.contains(where: \.isSystem))
                && !ExperimentalAppleBundlePolicyCatalog.contains(bundle) {
                reasons.append(.systemOwnerExcluded)
            }

            if let process {
                let later = snapshot.afterProcesses.filter { $0.pid == process.pid }
                if process.launchTime == nil || later.count != 1 || later[0] != process {
                    reasons.append(.ownerLifetimeUnverified)
                }

                var collision = false
                for parsed in parsedKeys {
                    let matches = inventory.filter {
                        parsed.1 == $0.bundleIdentifier || parsed.1 == $0.executableName
                    }
                    if matches.contains(process) {
                        if matches.count == 1, let value = table[parsed.0] {
                            keys.append((parsed.0, parsed.2, value))
                        } else {
                            collision = true
                        }
                    }
                }
                if collision { reasons.append(.ownerTokenCollision) }
                if keys.isEmpty { reasons.append(.missingConfiguredKey) }
                if keys.contains(where: { $0.value.positivePosition == nil }) {
                    reasons.append(.configuredPositionInvalid)
                }

                if let observation = snapshot.observationsByPID[process.pid] {
                    displayName = observation.displayName
                    ownerSavedPositions = observation.ownerSavedPositions
                    if observation.process != process { reasons.append(.ownerLifetimeUnverified) }
                    let hasExactBundleKey = keys.contains { key in
                        parsedKeys.first(where: { $0.0 == key.key })?.1 == bundle
                    }
                    if hasExactBundleKey,
                       observation.applicationCodeIdentity?.signingIdentifier == bundle {
                        exactBundleCodeIdentity = observation.applicationCodeIdentity
                        ownerSavedPositions = [:]
                    } else {
                        if !observation.ownerPreferencesComplete {
                            reasons.append(.ownerPreferencesIncomplete)
                        }
                        let namespaceVerified = observation.ownerPreferenceNamespace == .currentUserAnyHost
                            || (observation.ownerPreferenceNamespace == .sandboxContainer
                                && observation.ownerPreferenceSourceIdentity != nil)
                        if !namespaceVerified {
                            reasons.append(.ownerPreferenceNamespaceUnsupported)
                        }
                    }
                } else {
                    reasons.append(.observationMissing)
                }
            }

            keys.sort {
                let lhs = $0.value.positivePosition ?? -.infinity
                let rhs = $1.value.positivePosition ?? -.infinity
                if lhs != rhs { return lhs > rhs }
                return $0.key < $1.key
            }
            return OrderingConfigurationBundleCandidate(
                bundleIdentifier: bundle, displayName: displayName,
                process: process, keys: keys, ownerSavedPositions: ownerSavedPositions,
                exactBundleCodeIdentity: exactBundleCodeIdentity,
                reasons: deduplicated(reasons)
            )
        }
    }

    private static func parse(key: String) -> (token: String, persistentIdentifier: String)? {
        guard key.hasPrefix("status:") else { return nil }
        let body = String(key.dropFirst("status:".count))
        let pieces = body.components(separatedBy: "::")
        guard pieces.count == 2, OrderingSnapshot.validToken(pieces[0]),
              OrderingSnapshot.validToken(pieces[1]) else { return nil }
        return (pieces[0], pieces[1])
    }

    private static func deduplicated(_ reasons: [OrderingEligibilityReason]) -> [OrderingEligibilityReason] {
        var seen: Set<String> = []
        return reasons.filter { seen.insert($0.rawValue).inserted }
    }
}

public enum OrderingPhase: String, Codable, Equatable, Sendable { case baseline, applied }
public enum OrderingRelativeOrder: String, Codable, Equatable, Sendable {
    case firstBeforeSecond
    case secondBeforeFirst

    fileprivate var inverse: OrderingRelativeOrder {
        self == .firstBeforeSecond ? .secondBeforeFirst : .firstBeforeSecond
    }
}

public struct OrderingPlan: Codable, Equatable, Sendable {
    public static let maximumSnapshotAge: TimeInterval = 60
    public static let maximumReorderingTargets = 32
    public static let maximumConfigurationKeys = 128

    public let schemaVersion: Int
    public let id: UUID
    public let createdAt: Date
    public let baseline: OrderingSnapshot
    public let targets: [OrderingTarget]
    /// Present only for schema 3. Legacy schema 1/2 encoding and fingerprints
    /// remain unchanged because they continue to encode this as absent.
    public let configurationTargets: [OrderingConfigurationOwnerTarget]?
    /// Present only for schema 4. The array preserves the reviewed mixed order
    /// across whole application owners and exact Apple system items.
    public let configurationSubjectTargets: [OrderingConfigurationSubjectTarget]?
    public let fingerprint: String

    public var configurationKeyTargets: [OrderingConfigurationKeyTarget] {
        if let configurationSubjectTargets {
            return configurationSubjectTargets.flatMap(\.keys)
        }
        return configurationTargets?.flatMap(\.keys) ?? []
    }

    public var orderedConfigurationSubjects: [OrderingSubjectID]? {
        if let configurationSubjectTargets {
            return configurationSubjectTargets.map(\.subjectID)
        }
        return configurationTargets?.map { .application($0.bundleIdentifier) }
    }

    public static func make(snapshot: OrderingSnapshot, bundleIdentifiers: [String], now: Date = Date(),
                            id: UUID = UUID()) throws -> OrderingPlan {
        try snapshot.validate()
        guard bundleIdentifiers.count == 2, Set(bundleIdentifiers).count == 2 else {
            throw OrderingError.invalidSelection
        }
        try validateAge(snapshot.capturedAt, now: now)
        let targets = try deriveTargets(snapshot: snapshot, bundleIdentifiers: bundleIdentifiers)
        let plan = OrderingPlan(schemaVersion: 1, id: id, createdAt: now, baseline: snapshot,
                                targets: targets, configurationTargets: nil,
                                configurationSubjectTargets: nil, fingerprint: "")
        let fingerprint = try plan.computedFingerprint()
        return OrderingPlan(schemaVersion: 1, id: id, createdAt: now, baseline: snapshot,
                            targets: targets, configurationTargets: nil,
                            configurationSubjectTargets: nil, fingerprint: fingerprint)
    }

    /// Builds a bounded permutation from the owners' current visible slots.
    /// `orderedBundleIdentifiers` is the complete desired left-to-right order
    /// for the selected owners. Existing configured values are moved between
    /// those owners; this planner never synthesizes a numeric position.
    public static func makeReordering(
        snapshot: OrderingSnapshot,
        orderedBundleIdentifiers: [String],
        now: Date = Date(),
        id: UUID = UUID()
    ) throws -> OrderingPlan {
        try snapshot.validate()
        guard (2...maximumReorderingTargets).contains(orderedBundleIdentifiers.count),
              Set(orderedBundleIdentifiers).count == orderedBundleIdentifiers.count else {
            throw OrderingError.invalidSelection
        }
        try validateAge(snapshot.capturedAt, now: now)
        let targets = try deriveReorderingTargets(
            snapshot: snapshot,
            orderedBundleIdentifiers: orderedBundleIdentifiers
        )
        guard targets.contains(where: { $0.before != $0.after }) else {
            throw OrderingError.invalidSelection
        }
        let plan = OrderingPlan(schemaVersion: 2, id: id, createdAt: now, baseline: snapshot,
                                targets: targets, configurationTargets: nil,
                                configurationSubjectTargets: nil, fingerprint: "")
        let fingerprint = try plan.computedFingerprint()
        return OrderingPlan(schemaVersion: 2, id: id, createdAt: now, baseline: snapshot,
                            targets: targets, configurationTargets: nil,
                            configurationSubjectTargets: nil, fingerprint: fingerprint)
    }

    /// Creates a configuration-first bundle ordering. The identifiers are the
    /// desired physical left-to-right bundle order. macOS 27 ranks larger
    /// preferred-position values farther left, so existing exact numeric slots
    /// are assigned in descending order without deriving values from AX frames.
    public static func makeConfigurationOrdering(
        snapshot: OrderingSnapshot,
        orderedBundleIdentifiers: [String],
        now: Date = Date(),
        id: UUID = UUID()
    ) throws -> OrderingPlan {
        try snapshot.validate()
        guard (1...maximumReorderingTargets).contains(orderedBundleIdentifiers.count),
              Set(orderedBundleIdentifiers).count == orderedBundleIdentifiers.count else {
            throw OrderingError.invalidSelection
        }
        try validateAge(snapshot.capturedAt, now: now)
        let ownerTargets = try deriveConfigurationTargets(
            snapshot: snapshot,
            orderedBundleIdentifiers: orderedBundleIdentifiers
        )
        let plan = OrderingPlan(
            schemaVersion: 3, id: id, createdAt: now, baseline: snapshot,
            targets: [], configurationTargets: ownerTargets,
            configurationSubjectTargets: nil, fingerprint: ""
        )
        let fingerprint = try plan.computedFingerprint()
        return OrderingPlan(
            schemaVersion: 3, id: id, createdAt: now, baseline: snapshot,
            targets: [], configurationTargets: ownerTargets,
            configurationSubjectTargets: nil, fingerprint: fingerprint
        )
    }

    public static func makeConfigurationOrdering(
        snapshot: OrderingSnapshot,
        orderedSubjects: [OrderingSubjectID],
        now: Date = Date(),
        id: UUID = UUID()
    ) throws -> OrderingPlan {
        try snapshot.validate()
        guard (0...maximumReorderingTargets).contains(orderedSubjects.count),
              Set(orderedSubjects).count == orderedSubjects.count else {
            throw OrderingError.invalidSelection
        }
        try validateAge(snapshot.capturedAt, now: now)
        let subjectTargets = try deriveConfigurationSubjectTargets(
            snapshot: snapshot, orderedSubjects: orderedSubjects
        )
        let plan = OrderingPlan(
            schemaVersion: 4, id: id, createdAt: now, baseline: snapshot,
            targets: [], configurationTargets: nil,
            configurationSubjectTargets: subjectTargets, fingerprint: ""
        )
        let fingerprint = try plan.computedFingerprint()
        return OrderingPlan(
            schemaVersion: 4, id: id, createdAt: now, baseline: snapshot,
            targets: [], configurationTargets: nil,
            configurationSubjectTargets: subjectTargets, fingerprint: fingerprint
        )
    }

    private init(schemaVersion: Int, id: UUID, createdAt: Date, baseline: OrderingSnapshot,
                 targets: [OrderingTarget], configurationTargets: [OrderingConfigurationOwnerTarget]?,
                 configurationSubjectTargets: [OrderingConfigurationSubjectTarget]?,
                 fingerprint: String) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.createdAt = createdAt
        self.baseline = baseline
        self.targets = targets
        self.configurationTargets = configurationTargets
        self.configurationSubjectTargets = configurationSubjectTargets
        self.fingerprint = fingerprint
    }

    public func validate() throws {
        let validTargetCount = switch schemaVersion {
        case 1: targets.count == 2
        case 2: (2...Self.maximumReorderingTargets).contains(targets.count)
            && targets.contains(where: { $0.before != $0.after })
        case 3:
            targets.isEmpty
                && configurationTargets.map {
                    (1...Self.maximumReorderingTargets).contains($0.count)
                        && !$0.isEmpty
                        && $0.flatMap(\.keys).count <= Self.maximumConfigurationKeys
                } == true
        case 4:
            targets.isEmpty && configurationTargets == nil
                && configurationSubjectTargets.map {
                    (0...Self.maximumReorderingTargets).contains($0.count)
                        && $0.flatMap(\.keys).count <= Self.maximumConfigurationKeys
                } == true
        default: false
        }
        guard validTargetCount,
              createdAt >= baseline.capturedAt,
              createdAt.timeIntervalSince(baseline.capturedAt) <= Self.maximumSnapshotAge else {
            throw OrderingError.malformedPlan
        }
        try baseline.validate()
        if schemaVersion == 3 {
            guard configurationSubjectTargets == nil, let configurationTargets,
                  Set(configurationTargets.map(\.bundleIdentifier)).count == configurationTargets.count,
                  Set(configurationTargets.map(\.process.pid)).count == configurationTargets.count,
                  Set(configurationTargets.flatMap(\.keys).map(\.key)).count
                    == configurationTargets.flatMap(\.keys).count,
                  configurationTargets.allSatisfy({ !$0.keys.isEmpty }),
                  configurationTargets.flatMap(\.keys).allSatisfy({
                      $0.before.positivePosition != nil && $0.after.positivePosition != nil
                  }) else {
                throw OrderingError.malformedPlan
            }
            let derived = try Self.deriveConfigurationTargets(
                snapshot: baseline,
                orderedBundleIdentifiers: configurationTargets.map(\.bundleIdentifier)
            )
            guard derived == configurationTargets, fingerprint == (try computedFingerprint()) else {
                throw OrderingError.malformedPlan
            }
            return
        }
        if schemaVersion == 4 {
            guard let configurationSubjectTargets,
                  Set(configurationSubjectTargets.map(\.subjectID)).count
                    == configurationSubjectTargets.count,
                  Set(configurationSubjectTargets.flatMap(\.keys).map(\.key)).count
                    == configurationSubjectTargets.flatMap(\.keys).count,
                  configurationSubjectTargets.allSatisfy({ !$0.keys.isEmpty }),
                  configurationSubjectTargets.flatMap(\.keys).allSatisfy({
                      $0.before.positivePosition != nil && $0.after.positivePosition != nil
                  }) else {
                throw OrderingError.malformedPlan
            }
            let derived = try Self.deriveConfigurationSubjectTargets(
                snapshot: baseline,
                orderedSubjects: configurationSubjectTargets.map(\.subjectID)
            )
            guard derived == configurationSubjectTargets,
                  fingerprint == (try computedFingerprint()) else {
                throw OrderingError.malformedPlan
            }
            return
        }
        guard configurationTargets == nil,
              configurationSubjectTargets == nil,
              Set(targets.map(\.bundleIdentifier)).count == targets.count,
              Set(targets.map(\.key)).count == targets.count,
              Set(targets.map(\.process.pid)).count == targets.count else {
            throw OrderingError.malformedPlan
        }
        let derived: [OrderingTarget]
        switch schemaVersion {
        case 1:
            derived = try Self.deriveTargets(snapshot: baseline,
                                             bundleIdentifiers: targets.map(\.bundleIdentifier))
        case 2:
            derived = try Self.deriveReorderingTargets(
                snapshot: baseline,
                orderedBundleIdentifiers: targets.map(\.bundleIdentifier)
            )
        default:
            throw OrderingError.malformedPlan
        }
        guard derived == targets, fingerprint == (try computedFingerprint()) else {
            throw OrderingError.malformedPlan
        }
    }

    public func validateFresh(equivalentTo snapshot: OrderingSnapshot, now: Date = Date()) throws {
        try validate()
        try snapshot.validate()
        try Self.validateAge(createdAt, now: now)
        try Self.validateAge(snapshot.capturedAt, now: now)
        let configurationPlan = schemaVersion == 3 || schemaVersion == 4
        if !configurationPlan, baseline.group != snapshot.group {
            throw OrderingError.staleSnapshot("group preferences changed")
        }
        guard baseline.osBuild == snapshot.osBuild, baseline.architecture == snapshot.architecture,
              baseline.runtimeContractVerified == snapshot.runtimeContractVerified,
              baseline.displaySignature == snapshot.displaySignature,
              baseline.displayCount == snapshot.displayCount, baseline.displayFrame == snapshot.displayFrame,
              baseline.lifecycleGeneration == snapshot.lifecycleGeneration,
              baseline.policyFingerprint == snapshot.policyFingerprint else {
            throw OrderingError.staleSnapshot("runtime, display, lifecycle or policy context changed")
        }
        if !configurationPlan,
           baseline.orderingAllowedBundleIdentifiers != snapshot.orderingAllowedBundleIdentifiers {
            throw OrderingError.staleSnapshot("runtime, display, lifecycle or policy context changed")
        }
        // The complete process inventory below establishes token uniqueness.
        // AX/pref evidence belongs to the selected owners; unrelated dynamic
        // icons cannot change any target's identity or reviewed positions.
        let selectedPIDs: Set<Int32> = if schemaVersion == 3 {
            Set((configurationTargets ?? []).map(\.process.pid))
        } else if schemaVersion == 4 {
            Set((configurationSubjectTargets ?? []).compactMap { target in
                if case let .application(owner) = target { return owner.process.pid }
                return nil
            })
        } else {
            Set(targets.map(\.process.pid))
        }
        let exactCodeIdentitiesByPID: [Int32: OrderingApplicationCodeIdentity] = if schemaVersion == 3 {
            Dictionary(uniqueKeysWithValues: (configurationTargets ?? []).compactMap { target in
                target.exactBundleCodeIdentity.map { (target.process.pid, $0) }
            })
        } else if schemaVersion == 4 {
            Dictionary(uniqueKeysWithValues: (configurationSubjectTargets ?? []).compactMap { target in
                guard case let .application(owner) = target,
                      let identity = owner.exactBundleCodeIdentity else { return nil }
                return (owner.process.pid, identity)
            })
        } else {
            [:]
        }
        if let difference = Self.observationDifference(
            baseline.observationsByPID.filter { selectedPIDs.contains($0.key) },
            snapshot.observationsByPID.filter { selectedPIDs.contains($0.key) },
            selectedPIDs: selectedPIDs,
            includeGeometryEvidence: !configurationPlan,
            exactCodeIdentitiesByPID: exactCodeIdentitiesByPID
        ) {
            throw OrderingError.staleSnapshot(difference)
        }
        if configurationPlan {
            let targetKeys = Set(configurationKeyTargets.map(\.key))
            if !targetKeys.isEmpty {
                try baseline.validateConfigurationProcessScope(for: targetKeys, against: snapshot)
            }
            if schemaVersion == 3 {
                let resolved = try OrderingConfigurationIdentityResolver.resolve(snapshot: snapshot)
                for target in configurationTargets ?? [] {
                    guard let candidate = resolved.first(where: { $0.bundleIdentifier == target.bundleIdentifier }),
                          candidate.eligible,
                          candidate.process == target.process,
                          candidate.keys.map(\.key) == target.keys.map(\.key),
                          Dictionary(uniqueKeysWithValues: candidate.keys.map { ($0.key, $0.value) })
                            == Dictionary(uniqueKeysWithValues: target.keys.map { ($0.key, $0.before) }) else {
                        throw OrderingError.staleSnapshot("target identity is no longer eligible")
                    }
                }
            } else {
                let derived = try Self.deriveConfigurationSubjectTargets(
                    snapshot: snapshot,
                    orderedSubjects: (configurationSubjectTargets ?? []).map(\.subjectID)
                )
                guard derived == configurationSubjectTargets else {
                    throw OrderingError.staleSnapshot("target identity is no longer eligible")
                }
            }
        } else {
            guard Self.sorted(baseline.beforeProcesses) == Self.sorted(snapshot.beforeProcesses),
                  Self.sorted(baseline.afterProcesses) == Self.sorted(snapshot.afterProcesses) else {
                throw OrderingError.staleSnapshot("the process inventory changed")
            }
            try verifyRelativeOrder(in: snapshot, phase: .baseline)
            let resolved = try OrderingIdentityResolver.resolve(snapshot: snapshot)
            for target in targets {
                guard let candidate = resolved.first(where: { $0.bundleIdentifier == target.bundleIdentifier }),
                      candidate.eligible else {
                    throw OrderingError.staleSnapshot("target identity is no longer eligible")
                }
            }
        }
    }

    public func isFresh(equivalentTo snapshot: OrderingSnapshot, now: Date = Date()) -> Bool {
        do { try validateFresh(equivalentTo: snapshot, now: now); return true }
        catch { return false }
    }

    public func applying(to currentGroup: [String: OrderingValue]) throws -> [String: OrderingValue] {
        try validate()
        try OrderingValue.dictionary(currentGroup).validate()
        if schemaVersion != 3 && schemaVersion != 4, currentGroup != baseline.group {
            throw OrderingError.staleSnapshot("the complete baseline group changed")
        }
        var result = currentGroup
        var table = try table(in: currentGroup)
        if schemaVersion == 3 || schemaVersion == 4 {
            for target in configurationKeyTargets {
                guard table[target.key] == target.before else { throw OrderingError.targetDrift(target.key) }
                table[target.key] = target.after
            }
        } else {
            for target in targets {
                guard table[target.key] == target.before else { throw OrderingError.targetDrift(target.key) }
                table[target.key] = target.after
            }
        }
        result[OrderingSnapshot.tableKey] = .dictionary(table)
        return result
    }

    public var configurationBeforeValues: [String: OrderingValue]? {
        guard schemaVersion == 3 || schemaVersion == 4 else { return nil }
        return Dictionary(uniqueKeysWithValues: configurationKeyTargets.map {
            ($0.key, $0.before)
        })
    }

    public var configurationAfterValues: [String: OrderingValue]? {
        guard schemaVersion == 3 || schemaVersion == 4 else { return nil }
        return Dictionary(uniqueKeysWithValues: configurationKeyTargets.map {
            ($0.key, $0.after)
        })
    }

    public func restoring(current currentGroup: [String: OrderingValue]) throws -> [String: OrderingValue] {
        try validate()
        try OrderingValue.dictionary(currentGroup).validate()
        var result = currentGroup
        var table = try table(in: currentGroup)
        if schemaVersion == 3 || schemaVersion == 4 {
            let values = configurationKeyTargets
            for target in values {
                guard let value = table[target.key], value == target.before || value == target.after else {
                    throw OrderingError.targetDrift(target.key)
                }
            }
            for target in values { table[target.key] = target.before }
        } else {
            for target in targets {
                guard let value = table[target.key], value == target.before || value == target.after else {
                    throw OrderingError.targetDrift(target.key)
                }
            }
            for target in targets { table[target.key] = target.before }
        }
        result[OrderingSnapshot.tableKey] = .dictionary(table)
        return result
    }

    public func relativeOrder(in snapshot: OrderingSnapshot) throws -> OrderingRelativeOrder {
        guard targets.count == 2,
              let first = snapshot.observationsByPID[targets[0].process.pid],
              let second = snapshot.observationsByPID[targets[1].process.pid],
              first.process == targets[0].process, second.process == targets[1].process,
              first.axComplete, second.axComplete,
              first.itemFrames.count == 1, second.itemFrames.count == 1 else {
            throw OrderingError.invalidGeometry
        }
        return try Self.relativeOrder(first.itemFrames[0], second.itemFrames[0])
    }

    public func verifyRelativeOrder(in snapshot: OrderingSnapshot, phase: OrderingPhase) throws {
        try snapshot.validate()
        guard snapshot.displaySignature == baseline.displaySignature,
              snapshot.displayCount == baseline.displayCount,
              snapshot.displayFrame == baseline.displayFrame else {
            throw OrderingError.invalidGeometry
        }

        if schemaVersion == 3 {
            guard physicalVerificationStatus(in: snapshot, phase: phase) == .verified else {
                throw OrderingError.relativeOrderMismatch
            }
            return
        }

        var observedFrames: [(bundleIdentifier: String, frame: RectSnapshot)] = []
        for target in targets {
            guard let observation = snapshot.observationsByPID[target.process.pid],
                  observation.process == target.process, observation.axComplete,
                  observation.itemFrames.count == 1 else {
                throw OrderingError.invalidGeometry
            }
            let frame = observation.itemFrames[0]
            guard Self.visible(frame, in: snapshot.displayFrame) else {
                throw OrderingError.invalidGeometry
            }
            observedFrames.append((target.bundleIdentifier, frame))
        }

        let observed = try Self.leftToRightBundleIdentifiers(observedFrames)
        let baselineOrder = try Self.leftToRightBundleIdentifiers(targets.map {
            ($0.bundleIdentifier, $0.frame)
        })
        let appliedOrder: [String]
        switch schemaVersion {
        case 1: appliedOrder = baselineOrder.reversed()
        case 2: appliedOrder = targets.map(\.bundleIdentifier)
        default: throw OrderingError.malformedPlan
        }
        let expected = phase == .baseline ? baselineOrder : appliedOrder
        guard observed == expected else { throw OrderingError.relativeOrderMismatch }
    }

    public func physicalVerificationStatus(
        in snapshot: OrderingSnapshot, phase: OrderingPhase = .applied
    ) -> OrderingPhysicalVerificationStatus {
        guard schemaVersion == 3, let configurationTargets else { return .unavailable }
        var values: [(bundleIdentifier: String, frame: RectSnapshot)] = []
        for target in configurationTargets {
            guard let observation = snapshot.observationsByPID[target.process.pid],
                  observation.process == target.process, observation.axComplete,
                  observation.itemFrames.count == 1,
                  Self.visible(observation.itemFrames[0], in: snapshot.displayFrame) else {
                return .unavailable
            }
            values.append((target.bundleIdentifier, observation.itemFrames[0]))
        }
        guard let observed = try? Self.leftToRightBundleIdentifiers(values) else {
            return .unavailable
        }
        let desired = configurationTargets.map(\.bundleIdentifier)
        let baseline: [String]
        let candidates = try? OrderingConfigurationIdentityResolver.resolve(snapshot: self.baseline)
        let baselineFrames = configurationTargets.compactMap { target -> (String, RectSnapshot)? in
            guard let process = candidates?.first(where: { $0.bundleIdentifier == target.bundleIdentifier })?.process,
                  let observation = self.baseline.observationsByPID[process.pid],
                  observation.itemFrames.count == 1 else { return nil }
            return (target.bundleIdentifier, observation.itemFrames[0])
        }
        baseline = (try? Self.leftToRightBundleIdentifiers(baselineFrames)) ?? []
        let expected = phase == .applied ? desired : baseline
        guard expected.count == desired.count else { return .unavailable }
        return observed == expected ? .verified : .mismatch
    }

    private static func deriveTargets(snapshot: OrderingSnapshot,
                                      bundleIdentifiers: [String]) throws -> [OrderingTarget] {
        let candidates = try OrderingIdentityResolver.resolve(snapshot: snapshot)
        var selected: [OrderingBundleCandidate] = []
        for bundle in bundleIdentifiers.sorted() {
            guard let candidate = candidates.first(where: { $0.bundleIdentifier == bundle }) else {
                throw OrderingError.ineligibleBundle(bundle, [.missingConfiguredKey])
            }
            guard candidate.eligible else { throw OrderingError.ineligibleBundle(bundle, candidate.reasons) }
            selected.append(candidate)
        }
        guard let firstPosition = selected[0].configuredValue?.positivePosition,
              let secondPosition = selected[1].configuredValue?.positivePosition,
              firstPosition != secondPosition,
              let firstFrame = selected[0].frame, let secondFrame = selected[1].frame else {
            throw OrderingError.indistinguishablePositions
        }
        _ = try relativeOrder(firstFrame, secondFrame)
        return [
            OrderingTarget(bundleIdentifier: selected[0].bundleIdentifier,
                           displayName: selected[0].displayName, key: selected[0].key!,
                           before: selected[0].configuredValue!, after: selected[1].configuredValue!,
                           process: selected[0].process!, frame: firstFrame),
            OrderingTarget(bundleIdentifier: selected[1].bundleIdentifier,
                           displayName: selected[1].displayName, key: selected[1].key!,
                           before: selected[1].configuredValue!, after: selected[0].configuredValue!,
                           process: selected[1].process!, frame: secondFrame)
        ]
    }

    private static func deriveReorderingTargets(
        snapshot: OrderingSnapshot,
        orderedBundleIdentifiers: [String]
    ) throws -> [OrderingTarget] {
        guard (2...maximumReorderingTargets).contains(orderedBundleIdentifiers.count),
              Set(orderedBundleIdentifiers).count == orderedBundleIdentifiers.count else {
            throw OrderingError.invalidSelection
        }
        let candidates = try OrderingIdentityResolver.resolve(snapshot: snapshot)
        var selected: [OrderingBundleCandidate] = []
        for bundle in orderedBundleIdentifiers {
            guard let candidate = candidates.first(where: { $0.bundleIdentifier == bundle }) else {
                throw OrderingError.ineligibleBundle(bundle, [.missingConfiguredKey])
            }
            guard candidate.eligible else { throw OrderingError.ineligibleBundle(bundle, candidate.reasons) }
            selected.append(candidate)
        }

        let configuredValues = selected.compactMap(\.configuredValue)
        let configuredPositions = configuredValues.compactMap(\.positivePosition)
        guard selected.allSatisfy({ $0.configuredValue?.positivePosition != nil && $0.frame != nil }),
              configuredValues.count == selected.count,
              configuredPositions.count == selected.count,
              Set(configuredPositions).count == selected.count else {
            throw OrderingError.indistinguishablePositions
        }
        let currentOrder = try leftToRightBundleIdentifiers(selected.map {
            ($0.bundleIdentifier, $0.frame!)
        })
        let selectedByBundle = Dictionary(uniqueKeysWithValues: selected.map {
            ($0.bundleIdentifier, $0)
        })
        let currentSlots = currentOrder.compactMap { selectedByBundle[$0] }
        guard currentSlots.count == selected.count else { throw OrderingError.invalidGeometry }
        let slotValues = currentSlots.map { $0.configuredValue! }

        return selected.enumerated().map { index, candidate in
            OrderingTarget(bundleIdentifier: candidate.bundleIdentifier,
                           displayName: candidate.displayName, key: candidate.key!,
                           before: candidate.configuredValue!, after: slotValues[index],
                           process: candidate.process!, frame: candidate.frame!)
        }
    }

    private static func deriveConfigurationTargets(
        snapshot: OrderingSnapshot,
        orderedBundleIdentifiers: [String]
    ) throws -> [OrderingConfigurationOwnerTarget] {
        guard (1...maximumReorderingTargets).contains(orderedBundleIdentifiers.count),
              Set(orderedBundleIdentifiers).count == orderedBundleIdentifiers.count else {
            throw OrderingError.invalidSelection
        }
        let candidates = try OrderingConfigurationIdentityResolver.resolve(snapshot: snapshot)
        var selected: [OrderingConfigurationBundleCandidate] = []
        for bundle in orderedBundleIdentifiers {
            guard let candidate = candidates.first(where: { $0.bundleIdentifier == bundle }) else {
                throw OrderingError.ineligibleBundle(bundle, [.missingConfiguredKey])
            }
            guard candidate.eligible else {
                throw OrderingError.ineligibleBundle(bundle, candidate.reasons)
            }
            selected.append(candidate)
        }
        let keyCount = selected.reduce(0) { $0 + $1.keys.count }
        guard keyCount >= 1, keyCount <= maximumConfigurationKeys else {
            throw OrderingError.invalidSelection
        }
        let slots = selected.flatMap(\.keys).sorted {
            let lhs = $0.value.positivePosition!
            let rhs = $1.value.positivePosition!
            if lhs != rhs { return lhs > rhs }
            return $0.key < $1.key
        }.map(\.value)
        var slotIndex = 0
        return selected.map { candidate in
            let targets = candidate.keys.map { key in
                defer { slotIndex += 1 }
                return OrderingConfigurationKeyTarget(
                    key: key.key, persistentIdentifier: key.persistentIdentifier,
                    before: key.value, after: slots[slotIndex]
                )
            }
            return OrderingConfigurationOwnerTarget(
                bundleIdentifier: candidate.bundleIdentifier,
                displayName: candidate.displayName,
                process: candidate.process!, keys: targets,
                ownerSavedPositions: candidate.ownerSavedPositions,
                ownerPreferenceNamespace: candidate.exactBundleCodeIdentity == nil
                    ? snapshot.observationsByPID[candidate.process!.pid]!.ownerPreferenceNamespace : .unknown,
                ownerPreferenceSourceIdentity: candidate.exactBundleCodeIdentity == nil
                    ? snapshot.observationsByPID[candidate.process!.pid]!.ownerPreferenceSourceIdentity : nil,
                exactBundleCodeIdentity: candidate.exactBundleCodeIdentity
            )
        }
    }

    private static func deriveConfigurationSubjectTargets(
        snapshot: OrderingSnapshot,
        orderedSubjects: [OrderingSubjectID]
    ) throws -> [OrderingConfigurationSubjectTarget] {
        guard (0...maximumReorderingTargets).contains(orderedSubjects.count),
              Set(orderedSubjects).count == orderedSubjects.count else {
            throw OrderingError.invalidSelection
        }
        if orderedSubjects.isEmpty { return [] }
        let applications = try OrderingConfigurationIdentityResolver.resolve(snapshot: snapshot)
        let systems = try OrderingSystemConfigurationIdentityResolver.resolve(snapshot: snapshot)

        enum Selected {
            case application(OrderingConfigurationBundleCandidate)
            case system(OrderingConfigurationSystemCandidate)

            var values: [OrderingValue] {
                switch self {
                case let .application(candidate): candidate.keys.map(\.value)
                case let .system(candidate): candidate.value.map { [$0] } ?? []
                }
            }
        }

        var selected: [Selected] = []
        for subject in orderedSubjects {
            switch subject {
            case let .application(bundleIdentifier):
                guard let candidate = applications.first(where: {
                    $0.bundleIdentifier == bundleIdentifier
                }) else {
                    throw OrderingError.ineligibleBundle(
                        bundleIdentifier, [.missingConfiguredKey]
                    )
                }
                guard candidate.eligible else {
                    throw OrderingError.ineligibleBundle(bundleIdentifier, candidate.reasons)
                }
                selected.append(.application(candidate))
            case let .systemItem(item):
                guard let candidate = systems.first(where: { $0.item == item }) else {
                    throw OrderingError.ineligibleBundle(
                        item.displayName, [.missingConfiguredKey]
                    )
                }
                guard candidate.eligible else {
                    throw OrderingError.ineligibleBundle(item.displayName, candidate.reasons)
                }
                selected.append(.system(candidate))
            }
        }

        let keyCount = selected.reduce(0) { $0 + $1.values.count }
        guard keyCount >= 1, keyCount <= maximumConfigurationKeys else {
            throw OrderingError.invalidSelection
        }
        let slots = selected.flatMap(\.values).sorted {
            let lhs = $0.positivePosition!
            let rhs = $1.positivePosition!
            if lhs != rhs { return lhs > rhs }
            let leftFingerprint = (try? $0.canonicalFingerprint) ?? ""
            let rightFingerprint = (try? $1.canonicalFingerprint) ?? ""
            return leftFingerprint < rightFingerprint
        }
        var slotIndex = 0
        return selected.map { selected in
            switch selected {
            case let .application(candidate):
                let keys = candidate.keys.map { source in
                    defer { slotIndex += 1 }
                    return OrderingConfigurationKeyTarget(
                        key: source.key, persistentIdentifier: source.persistentIdentifier,
                        before: source.value, after: slots[slotIndex]
                    )
                }
                let process = candidate.process!
                let observation = snapshot.observationsByPID[process.pid]!
                return .application(OrderingConfigurationOwnerTarget(
                    bundleIdentifier: candidate.bundleIdentifier,
                    displayName: candidate.displayName, process: process, keys: keys,
                    ownerSavedPositions: candidate.ownerSavedPositions,
                    ownerPreferenceNamespace: candidate.exactBundleCodeIdentity == nil
                        ? observation.ownerPreferenceNamespace : .unknown,
                    ownerPreferenceSourceIdentity: candidate.exactBundleCodeIdentity == nil
                        ? observation.ownerPreferenceSourceIdentity : nil,
                    exactBundleCodeIdentity: candidate.exactBundleCodeIdentity
                ))
            case let .system(candidate):
                let value = candidate.value!
                let key = OrderingConfigurationKeyTarget(
                    key: candidate.key, persistentIdentifier: candidate.item.rawValue,
                    before: value, after: slots[slotIndex]
                )
                slotIndex += 1
                return .systemItem(OrderingConfigurationSystemTarget(
                    item: candidate.item, displayName: candidate.displayName,
                    hostBinding: candidate.hostBinding!, key: key
                ))
            }
        }
    }

    private static func leftToRightBundleIdentifiers(
        _ values: [(bundleIdentifier: String, frame: RectSnapshot)]
    ) throws -> [String] {
        guard let first = values.first else { return [] }
        let commonMinimumY = values.reduce(first.frame.y) { max($0, $1.frame.y) }
        let commonMaximumY = values.reduce(first.frame.y + first.frame.height) {
            min($0, $1.frame.y + $1.frame.height)
        }
        guard commonMinimumY < commonMaximumY else { throw OrderingError.invalidGeometry }
        for firstIndex in values.indices {
            for secondIndex in values.index(after: firstIndex)..<values.endIndex {
                _ = try relativeOrder(values[firstIndex].frame, values[secondIndex].frame)
            }
        }
        let sorted = values.sorted { $0.frame.x < $1.frame.x }
        return sorted.map(\.bundleIdentifier)
    }

    private static func visible(_ frame: RectSnapshot, in display: RectSnapshot) -> Bool {
        guard OrderingSnapshot.valid(frame), OrderingSnapshot.valid(display),
              frame.width > 0, frame.height > 0, display.width > 0, display.height > 0 else {
            return false
        }
        return frame.x >= display.x && frame.y >= display.y
            && frame.x + frame.width <= display.x + display.width
            && frame.y + frame.height <= display.y + display.height
    }

    private static func relativeOrder(_ first: RectSnapshot,
                                      _ second: RectSnapshot) throws -> OrderingRelativeOrder {
        guard OrderingSnapshot.valid(first), OrderingSnapshot.valid(second),
              first.width > 0, first.height > 0, second.width > 0, second.height > 0 else {
            throw OrderingError.invalidGeometry
        }
        guard max(first.y, second.y) < min(first.y + first.height, second.y + second.height) else {
            throw OrderingError.invalidGeometry
        }
        let firstMaxX = first.x + first.width
        let secondMaxX = second.x + second.width
        if first.x < second.x, firstMaxX < secondMaxX { return .firstBeforeSecond }
        if second.x < first.x, secondMaxX < firstMaxX { return .secondBeforeFirst }
        throw OrderingError.invalidGeometry
    }

    private static func validateAge(_ capturedAt: Date, now: Date) throws {
        let age = now.timeIntervalSince(capturedAt)
        guard age >= 0, age <= maximumSnapshotAge else {
            throw OrderingError.staleSnapshot("capture is older than the bounded review window")
        }
    }

    private func computedFingerprint() throws -> String {
        if schemaVersion == 4 {
            struct SubjectConfigurationBinding: Codable {
                let schemaVersion: Int
                let id: UUID
                let createdAt: Date
                let baselineFingerprint: String
                let configurationSubjectTargets: [OrderingConfigurationSubjectTarget]
            }
            return try OrderingDigest.hash(SubjectConfigurationBinding(
                schemaVersion: schemaVersion, id: id, createdAt: createdAt,
                baselineFingerprint: try baseline.canonicalFingerprint,
                configurationSubjectTargets: configurationSubjectTargets ?? []
            ))
        }
        if schemaVersion == 3 {
            struct ConfigurationBinding: Codable {
                let schemaVersion: Int
                let id: UUID
                let createdAt: Date
                let baselineFingerprint: String
                let configurationTargets: [OrderingConfigurationOwnerTarget]
            }
            return try OrderingDigest.hash(ConfigurationBinding(
                schemaVersion: schemaVersion, id: id, createdAt: createdAt,
                baselineFingerprint: try baseline.canonicalFingerprint,
                configurationTargets: configurationTargets ?? []
            ))
        }
        struct Binding: Codable {
            let schemaVersion: Int
            let id: UUID
            let createdAt: Date
            let baselineFingerprint: String
            let targets: [OrderingTarget]
        }
        return try OrderingDigest.hash(Binding(schemaVersion: schemaVersion, id: id,
            createdAt: createdAt, baselineFingerprint: try baseline.canonicalFingerprint,
            targets: targets))
    }

    private func table(in group: [String: OrderingValue]) throws -> [String: OrderingValue] {
        guard case let .dictionary(table)? = group[OrderingSnapshot.tableKey] else {
            throw OrderingError.invalidSnapshot("the complete preferred-position table is missing")
        }
        return table
    }

    private static func sorted(_ values: [OrderingProcess]) -> [OrderingProcess] {
        OrderingSnapshot.sortedProcesses(values)
    }

    private static func observationDifference(
        _ lhs: [Int32: OrderingOwnerObservation],
        _ rhs: [Int32: OrderingOwnerObservation],
        selectedPIDs: Set<Int32>,
        includeGeometryEvidence: Bool,
        exactCodeIdentitiesByPID: [Int32: OrderingApplicationCodeIdentity] = [:]
    ) -> String? {
        let allPIDs = Set(lhs.keys).union(rhs.keys)
        if let pid = allPIDs.sorted().first(where: { (lhs[$0] == nil) != (rhs[$0] == nil) }) {
            let owner = observationOwnerDescription(
                pid: pid, lhs: lhs, rhs: rhs, selectedPIDs: selectedPIDs
            )
            return "observation inventory changed for \(owner)"
        }
        for pid in allPIDs.sorted() {
            guard let first = lhs[pid], let second = rhs[pid] else { continue }
            let owner = observationOwnerDescription(
                pid: pid, lhs: lhs, rhs: rhs, selectedPIDs: selectedPIDs
            )
            if first.process != second.process { return "owner process metadata changed for \(owner)" }
            if includeGeometryEvidence, first.displayName != second.displayName {
                return "owner name changed for \(owner)"
            }
            if includeGeometryEvidence, first.axComplete != second.axComplete {
                return "Accessibility completeness changed for \(owner)"
            }
            if let expectedIdentity = exactCodeIdentitiesByPID[pid] {
                if first.applicationCodeIdentity != expectedIdentity
                    || second.applicationCodeIdentity != expectedIdentity {
                    return "application code identity changed for \(owner)"
                }
                continue
            }
            if first.ownerPreferencesComplete != second.ownerPreferencesComplete {
                return "owner preference completeness changed for \(owner)"
            }
            if first.ownerPreferenceNamespace != second.ownerPreferenceNamespace {
                return "owner preference namespace changed for \(owner)"
            }
            if first.ownerPreferenceSourceIdentity != second.ownerPreferenceSourceIdentity {
                return "owner preference source identity changed for \(owner)"
            }
            if first.ownerSavedPositions != second.ownerSavedPositions {
                return "owner saved-position set changed for \(owner)"
            }
            if includeGeometryEvidence, first.itemFrames.count != second.itemFrames.count {
                return "Accessibility item cardinality changed for \(owner)"
            }
        }
        return nil
    }

    private static func observationOwnerDescription(
        pid: Int32,
        lhs: [Int32: OrderingOwnerObservation],
        rhs: [Int32: OrderingOwnerObservation],
        selectedPIDs: Set<Int32>
    ) -> String {
        let bundle = lhs[pid]?.process.bundleIdentifier
            ?? rhs[pid]?.process.bundleIdentifier
            ?? "unknown bundle"
        let scope = selectedPIDs.contains(pid) ? "selected target" : "unrelated owner"
        return "\(scope) \(bundle)"
    }
}

private enum OrderingDigest {
    static func hash(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .secondsSince1970
        return SHA256.hash(data: try encoder.encode(value)).map { String(format: "%02x", $0) }.joined()
    }
}
#endif
