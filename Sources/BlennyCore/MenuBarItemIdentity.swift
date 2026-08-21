import Foundation

public enum MenuBarItemIdentityConfidence: String, Codable, Sendable {
    case strong
    case moderate
    case weak
}

public struct MenuBarItemIdentity: Codable, Hashable, Sendable {
    public let ownerBundleIdentifier: String
    public let accessibilityIdentifier: String?
    public let semanticLabel: String?
    public let role: String
    public let subrole: String?
    public let instanceOrdinal: Int
    public let confidence: MenuBarItemIdentityConfidence

    public init(
        ownerBundleIdentifier: String,
        accessibilityIdentifier: String?,
        semanticLabel: String?,
        role: String,
        subrole: String?,
        instanceOrdinal: Int,
        confidence: MenuBarItemIdentityConfidence
    ) {
        self.ownerBundleIdentifier = ownerBundleIdentifier
        self.accessibilityIdentifier = accessibilityIdentifier
        self.semanticLabel = semanticLabel
        self.role = role
        self.subrole = subrole
        self.instanceOrdinal = instanceOrdinal
        self.confidence = confidence
    }

    public var stableKey: String {
        let components = [
            "blenny-identity-v2",
            ownerBundleIdentifier,
            accessibilityIdentifier ?? "",
            semanticLabel ?? "",
            role,
            subrole ?? "",
            String(instanceOrdinal)
        ]
        return components.map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
    }
}

public struct MenuBarItemIdentityCandidate: Equatable, Sendable {
    public let observationKey: String
    public let ownerBundleIdentifier: String?
    public let accessibilityIdentifier: String?
    public let title: String?
    public let itemDescription: String?
    public let role: String?
    public let subrole: String?

    public init(
        observationKey: String,
        ownerBundleIdentifier: String?,
        accessibilityIdentifier: String?,
        title: String?,
        itemDescription: String?,
        role: String?,
        subrole: String?
    ) {
        self.observationKey = observationKey
        self.ownerBundleIdentifier = ownerBundleIdentifier
        self.accessibilityIdentifier = accessibilityIdentifier
        self.title = title
        self.itemDescription = itemDescription
        self.role = role
        self.subrole = subrole
    }
}

public struct ResolvedMenuBarItemIdentity: Equatable, Sendable {
    public let observationKey: String
    public let identity: MenuBarItemIdentity

    public init(observationKey: String, identity: MenuBarItemIdentity) {
        self.observationKey = observationKey
        self.identity = identity
    }
}

public enum MenuBarItemIdentityResolver {
    public static func normalize(_ value: String?) -> String? {
        guard let value else { return nil }

        let folded = value
            .precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let normalized = folded
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return normalized.isEmpty ? nil : normalized
    }

    public static func normalizeSemanticLabel(_ value: String?) -> String? {
        guard let normalized = normalize(value) else { return nil }

        var result = ""
        var isInsideDecimalRun = false
        for scalar in normalized.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar) {
                if !isInsideDecimalRun {
                    result.append(contentsOf: "{number}")
                }
                isInsideDecimalRun = true
            } else {
                result.append(contentsOf: String(scalar))
                isInsideDecimalRun = false
            }
        }
        return result
    }

    public static func resolve(_ candidates: [MenuBarItemIdentityCandidate]) -> [ResolvedMenuBarItemIdentity] {
        var seenObservationKeys = Set<String>()
        var instanceCounts: [BaseIdentity: Int] = [:]
        var results: [ResolvedMenuBarItemIdentity] = []

        for candidate in candidates {
            if !candidate.observationKey.isEmpty,
               !seenObservationKeys.insert(candidate.observationKey).inserted {
                continue
            }

            let bundleIdentifier = normalize(candidate.ownerBundleIdentifier) ?? "unknown.bundle"
            let identifier = normalize(candidate.accessibilityIdentifier)
            let rawLabel = identifier == nil
                ? normalize(candidate.title) ?? normalize(candidate.itemDescription)
                : nil
            let label = normalizeSemanticLabel(rawLabel)
            let usesVolatileNumberMask = label != rawLabel
            let role = normalize(candidate.role) ?? "unknown-role"
            let subrole = normalize(candidate.subrole)
            let confidence: MenuBarItemIdentityConfidence

            if identifier != nil {
                confidence = .strong
            } else if usesVolatileNumberMask {
                confidence = .weak
            } else if label != nil {
                confidence = .moderate
            } else {
                confidence = .weak
            }

            let base = BaseIdentity(
                ownerBundleIdentifier: bundleIdentifier,
                accessibilityIdentifier: identifier,
                semanticLabel: label,
                role: role,
                subrole: subrole
            )
            let ordinal = instanceCounts[base, default: 0]
            instanceCounts[base] = ordinal + 1

            let identity = MenuBarItemIdentity(
                ownerBundleIdentifier: bundleIdentifier,
                accessibilityIdentifier: identifier,
                semanticLabel: label,
                role: role,
                subrole: subrole,
                instanceOrdinal: ordinal,
                confidence: confidence
            )
            results.append(
                ResolvedMenuBarItemIdentity(
                    observationKey: candidate.observationKey,
                    identity: identity
                )
            )
        }

        return results
    }
}

private struct BaseIdentity: Hashable {
    let ownerBundleIdentifier: String
    let accessibilityIdentifier: String?
    let semanticLabel: String?
    let role: String
    let subrole: String?
}
