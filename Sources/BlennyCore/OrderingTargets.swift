#if BLENNY_PRODUCT || DEBUG
import CoreFoundation
import CryptoKit
import Foundation

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
#endif
