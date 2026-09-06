import Foundation

public enum PassThroughExpansionError: Error, Equatable, Sendable {
    case invalidBaselinePresentation
    case invalidRevealPresentation
    case invalidBundleIdentifier(String)
    case duplicateBundleIdentifier(String)
    case inconsistentUnacceptedBundleIdentifier(String)
    case replacementPresentationChanged
    case replacementSystemItemsChanged
    case replacementPersistentSystemItemsChanged
    case emptyReplacementAdditions
    case replacementBundleIdentifiersChanged
}

/// A bounded, additions-only replacement of both active policy plans.
///
/// Accepted policy bundles are deliberately excluded: their Visible,
/// Revealable, and Hidden behavior remains defined by the reviewed plans.
public struct PassThroughExpansion: Equatable, Sendable {
    public let baseline: RevealAllowlistPlan
    public let reveal: RevealAllowlistPlan
    public let addedBundleIdentifiers: [String]

    public init(
        baseline: RevealAllowlistPlan,
        reveal: RevealAllowlistPlan,
        addedBundleIdentifiers: [String]
    ) {
        self.baseline = baseline
        self.reveal = reveal
        self.addedBundleIdentifiers = addedBundleIdentifiers
    }

    public static func prepare(
        baseline: RevealAllowlistPlan,
        reveal: RevealAllowlistPlan,
        acceptedBundleIdentifiers: Set<String>,
        launchedBundleIdentifiers: Set<String>
    ) throws -> PassThroughExpansion? {
        guard baseline.presentation == .baseline else {
            throw PassThroughExpansionError.invalidBaselinePresentation
        }
        guard reveal.presentation == .revealed else {
            throw PassThroughExpansionError.invalidRevealPresentation
        }

        let baselineIdentifiers = try identifiers(
            in: baseline.allowedBundleIdentifiers
        )
        let revealIdentifiers = try identifiers(
            in: reveal.allowedBundleIdentifiers
        )
        let acceptedIdentifiers = try identifiers(
            in: acceptedBundleIdentifiers
        )
        let launchedIdentifiers = try identifiers(
            in: launchedBundleIdentifiers
        )

        let inconsistent = Set(baselineIdentifiers.keys)
            .symmetricDifference(Set(revealIdentifiers.keys))
            .filter { acceptedIdentifiers[$0] == nil }
            .sorted()
        if let key = inconsistent.first {
            throw PassThroughExpansionError.inconsistentUnacceptedBundleIdentifier(
                baselineIdentifiers[key] ?? revealIdentifiers[key] ?? key
            )
        }

        let additions = launchedIdentifiers.keys.compactMap { key -> String? in
            guard acceptedIdentifiers[key] == nil,
                  baselineIdentifiers[key] == nil,
                  revealIdentifiers[key] == nil else {
                return nil
            }
            return launchedIdentifiers[key]
        }.sorted(by: stableOrder)

        guard !additions.isEmpty else { return nil }

        return PassThroughExpansion(
            baseline: RevealAllowlistPlan(
                presentation: baseline.presentation,
                allowedSystemItems: baseline.allowedSystemItems,
                allowedBundleIdentifiers: baseline.allowedBundleIdentifiers + additions,
                persistentSystemItems: baseline.persistentSystemItems
            ),
            reveal: RevealAllowlistPlan(
                presentation: reveal.presentation,
                allowedSystemItems: reveal.allowedSystemItems,
                allowedBundleIdentifiers: reveal.allowedBundleIdentifiers + additions,
                persistentSystemItems: reveal.persistentSystemItems
            ),
            addedBundleIdentifiers: additions
        )
    }

    /// Validates one writer replacement against the exact additions prepared
    /// above. It permits no removal, rewrite, policy change, or system-item
    /// change.
    public static func validateReplacement(
        from old: RevealAllowlistPlan,
        to new: RevealAllowlistPlan,
        addedBundleIdentifiers: Set<String>
    ) throws {
        guard old.presentation == new.presentation else {
            throw PassThroughExpansionError.replacementPresentationChanged
        }
        guard old.allowedSystemItems == new.allowedSystemItems else {
            throw PassThroughExpansionError.replacementSystemItemsChanged
        }
        guard old.persistentSystemItems == new.persistentSystemItems else {
            throw PassThroughExpansionError.replacementPersistentSystemItemsChanged
        }

        let oldIdentifiers = try identifiers(in: old.allowedBundleIdentifiers)
        let newIdentifiers = try identifiers(in: new.allowedBundleIdentifiers)
        let addedIdentifiers = try identifiers(in: addedBundleIdentifiers)
        guard !addedIdentifiers.isEmpty else {
            throw PassThroughExpansionError.emptyReplacementAdditions
        }
        guard Set(oldIdentifiers.keys).isDisjoint(with: Set(addedIdentifiers.keys)) else {
            throw PassThroughExpansionError.replacementBundleIdentifiersChanged
        }

        for (key, identifier) in oldIdentifiers where newIdentifiers[key] != identifier {
            throw PassThroughExpansionError.replacementBundleIdentifiersChanged
        }

        let expected = Set(oldIdentifiers.keys).union(addedIdentifiers.keys)
        guard Set(newIdentifiers.keys) == expected else {
            throw PassThroughExpansionError.replacementBundleIdentifiersChanged
        }

        for (key, identifier) in addedIdentifiers where newIdentifiers[key] != identifier {
            throw PassThroughExpansionError.replacementBundleIdentifiersChanged
        }
    }

    private static func identifiers<S: Sequence>(
        in identifiers: S
    ) throws -> [String: String] where S.Element == String {
        var result: [String: String] = [:]
        for identifier in identifiers {
            guard let key = BundlePolicyIdentity.canonicalKey(for: identifier) else {
                throw PassThroughExpansionError.invalidBundleIdentifier(identifier)
            }
            guard result[key] == nil else {
                throw PassThroughExpansionError.duplicateBundleIdentifier(key)
            }
            result[key] = identifier
        }
        return result
    }

    private static func stableOrder(_ lhs: String, _ rhs: String) -> Bool {
        (lhs.lowercased(), lhs) < (rhs.lowercased(), rhs)
    }
}
