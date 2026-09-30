#if BLENNY_PRODUCT || DEBUG
import CoreFoundation
import CryptoKit
import Foundation

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
        case .nowPlaying, .siri, .timeMachine, .controlCenter: false
        case .bluetooth, .wifi, .sound: true
        case .spotlight:
            #if BLENNY_PRODUCT || DEBUG
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

    static func valid(_ frame: RectSnapshot) -> Bool {
        [frame.x, frame.y, frame.width, frame.height].allSatisfy(\.isFinite)
            && frame.width >= 0 && frame.height >= 0
    }

    static func validToken(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 1_024
            && !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    }

    static func validSHA256(_ value: String) -> Bool {
        value.utf8.count == 64
            && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    static func sortedProcesses(_ values: [OrderingProcess]) -> [OrderingProcess] {
        values.sorted {
            if $0.pid != $1.pid { return $0.pid < $1.pid }
            return ($0.bundleIdentifier ?? "") < ($1.bundleIdentifier ?? "")
        }
    }
}
#endif
