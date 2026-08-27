import Foundation

public struct MenuBarPolicyOwnershipObservation: Equatable, Sendable {
    public let bundleIdentifier: String?
    public let processIdentifier: Int32
    public let menuBarItemCount: Int

    public init(
        bundleIdentifier: String?,
        processIdentifier: Int32,
        menuBarItemCount: Int
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.menuBarItemCount = menuBarItemCount
    }
}

public enum PersistentPolicyResolutionIssue: Error, Equatable, Sendable {
    case ownershipScanTimedOut
    case unknownMenuBarOwner(processIdentifier: Int32)
    case invalidObservedBundleIdentifier(String)
    case configuredBundleNotObserved(String)
    case ambiguousConfiguredBundle(bundleIdentifier: String, processIdentifiers: [Int32])
}

extension PersistentPolicyResolutionIssue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .ownershipScanTimedOut:
            return "bounded menu-bar ownership scan timed out"
        case let .unknownMenuBarOwner(processIdentifier):
            return "menu-bar owner PID \(processIdentifier) has no bundle identifier"
        case let .invalidObservedBundleIdentifier(bundleIdentifier):
            return "menu-bar owner has invalid bundle identifier \(bundleIdentifier)"
        case let .configuredBundleNotObserved(bundleIdentifier):
            return "configured bundle \(bundleIdentifier) has no attributable menu-bar owner"
        case let .ambiguousConfiguredBundle(bundleIdentifier, processIdentifiers):
            return "configured bundle \(bundleIdentifier) has ambiguous owner PIDs \(processIdentifiers)"
        }
    }
}

public struct ResolvedPersistentPolicy: Equatable, Sendable {
    public let assignments: BundlePolicyAssignments
    public let observedRunningBundleIdentifiers: Set<String>
    public let managedProcessIdentifiers: [String: Int32]

    public init(
        assignments: BundlePolicyAssignments,
        observedRunningBundleIdentifiers: Set<String>,
        managedProcessIdentifiers: [String: Int32]
    ) {
        self.assignments = assignments
        self.observedRunningBundleIdentifiers = observedRunningBundleIdentifiers
        self.managedProcessIdentifiers = managedProcessIdentifiers
    }
}

public enum PersistentPolicyResolverError: Error, Equatable, Sendable {
    case unresolved([PersistentPolicyResolutionIssue])
}

public enum PersistentPolicyResolver {
    public static func resolve(
        document: PersistentBundlePolicyDocument,
        ownershipObservations: [MenuBarPolicyOwnershipObservation],
        observedRunningBundleIdentifiers: Set<String>,
        blennyBundleIdentifier: String
    ) throws -> ResolvedPersistentPolicy {
        _ = try document.validated(
            forBlennyBundleIdentifier: blennyBundleIdentifier
        )

        var issues: [PersistentPolicyResolutionIssue] = []
        var observationsByCanonicalIdentifier: [String: [MenuBarPolicyOwnershipObservation]] = [:]

        for observation in ownershipObservations where observation.menuBarItemCount > 0 {
            guard let bundleIdentifier = observation.bundleIdentifier else {
                issues.append(
                    .unknownMenuBarOwner(processIdentifier: observation.processIdentifier)
                )
                continue
            }
            guard let canonical = BundlePolicyIdentity.canonicalKey(
                for: bundleIdentifier
            ) else {
                issues.append(.invalidObservedBundleIdentifier(bundleIdentifier))
                continue
            }
            observationsByCanonicalIdentifier[canonical, default: []].append(observation)
        }

        var visible = Set<String>()
        var revealable = Set<String>()
        var hidden = Set<String>()
        var managedProcessIdentifiers: [String: Int32] = [:]

        for entry in document.policies {
            guard let canonical = BundlePolicyIdentity.canonicalKey(
                for: entry.bundleIdentifier
            ) else {
                issues.append(.invalidObservedBundleIdentifier(entry.bundleIdentifier))
                continue
            }
            let matching = observationsByCanonicalIdentifier[canonical] ?? []
            let processIdentifiers = Array(Set(matching.map(\.processIdentifier))).sorted()
            guard !matching.isEmpty else {
                issues.append(.configuredBundleNotObserved(entry.bundleIdentifier))
                continue
            }
            guard processIdentifiers.count == 1,
                  let processIdentifier = processIdentifiers.first else {
                issues.append(
                    .ambiguousConfiguredBundle(
                        bundleIdentifier: entry.bundleIdentifier,
                        processIdentifiers: processIdentifiers
                    )
                )
                continue
            }

            let observedIdentifier = matching.compactMap(\.bundleIdentifier).sorted().first
                ?? entry.bundleIdentifier
            managedProcessIdentifiers[entry.bundleIdentifier] = processIdentifier
            switch entry.policy {
            case .visible:
                visible.insert(observedIdentifier)
            case .revealable:
                revealable.insert(observedIdentifier)
            case .hidden:
                hidden.insert(observedIdentifier)
            }
        }

        if !issues.isEmpty {
            throw PersistentPolicyResolverError.unresolved(issues)
        }

        return ResolvedPersistentPolicy(
            assignments: try BundlePolicyAssignments(
                visible: visible,
                revealable: revealable,
                hidden: hidden
            ),
            observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
            managedProcessIdentifiers: managedProcessIdentifiers
        )
    }
}
