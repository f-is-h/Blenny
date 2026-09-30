#if BLENNY_PRODUCT || DEBUG
import CoreFoundation
import CryptoKit
import Foundation

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
#endif
