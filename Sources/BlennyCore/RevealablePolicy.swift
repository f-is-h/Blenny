import CryptoKit
import Foundation

public enum MenuBarBundlePolicy: String, CaseIterable, Codable, Hashable, Sendable {
    case visible
    case revealable
    case hidden
}

public enum BundlePolicyAssignmentsError: Error, Equatable, Sendable {
    case emptyBundleIdentifier
    case overlappingPolicies(bundleIdentifier: String)
}

public struct BundlePolicyAssignments: Equatable, Sendable {
    public let visible: Set<String>
    public let revealable: Set<String>
    public let hidden: Set<String>

    public init(
        visible: Set<String>,
        revealable: Set<String>,
        hidden: Set<String>
    ) throws {
        let allIdentifiers = visible.union(revealable).union(hidden)
        guard allIdentifiers.allSatisfy(Self.isValidBundleIdentifier) else {
            throw BundlePolicyAssignmentsError.emptyBundleIdentifier
        }

        let overlaps = visible.intersection(revealable)
            .union(visible.intersection(hidden))
            .union(revealable.intersection(hidden))
        if let overlap = overlaps.sorted().first {
            throw BundlePolicyAssignmentsError.overlappingPolicies(
                bundleIdentifier: overlap
            )
        }

        self.visible = visible
        self.revealable = revealable
        self.hidden = hidden
    }

    private static func isValidBundleIdentifier(_ identifier: String) -> Bool {
        !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public enum RevealSessionPresentation: String, Sendable {
    case baseline
    case revealed
}

public enum PersistentSystemItemPresentation: String, Codable, Equatable, Sendable {
    /// Restore the exact pre-management value and relinquish the receipt after commit.
    case restored
    /// Restore the exact pre-management value temporarily while retaining the receipt.
    case revealed
    /// Apply the item-scoped hidden value and retain the receipt.
    case hidden
}

public struct RevealAllowlistPlan: Equatable, Sendable {
    public let presentation: RevealSessionPresentation
    public let allowedSystemItems: [Int]
    public let allowedBundleIdentifiers: [String]
    public let persistentSystemItems: [String: PersistentSystemItemPresentation]

    public init(
        presentation: RevealSessionPresentation,
        allowedSystemItems: [Int],
        allowedBundleIdentifiers: [String],
        persistentSystemItems: [String: PersistentSystemItemPresentation] = [:]
    ) {
        self.presentation = presentation
        self.allowedSystemItems = allowedSystemItems
        self.allowedBundleIdentifiers = allowedBundleIdentifiers
        self.persistentSystemItems = persistentSystemItems
    }

    public var fingerprint: String {
        let canonical = [
            "presentation=\(presentation.rawValue)",
            "system=\(allowedSystemItems.sorted().map(String.init).joined(separator: ","))",
            "bundles=\(allowedBundleIdentifiers.sorted().joined(separator: "\n"))",
            "persistent=\(persistentSystemItems.keys.sorted().map { "\($0)|\(persistentSystemItems[$0]!.rawValue)" }.joined(separator: "\n"))",
        ].joined(separator: "\n")
        return Self.sha256(canonical)
    }

    /// Binds Review to the effective state of owner-approved bundles while
    /// allowing unrelated pass-through processes to change before Apply.
    public func authorizationFingerprint(
        for authorizedBundleIdentifiers: [String]
    ) -> String {
        let allowed = Set(allowedBundleIdentifiers.map { $0.lowercased() })
        let authorizedStates = authorizedBundleIdentifiers
            .map { $0.lowercased() }
            .sorted()
            .map { "\($0)|allowed=\(allowed.contains($0))" }
        let canonical = [
            "presentation=\(presentation.rawValue)",
            "system=\(allowedSystemItems.sorted().map(String.init).joined(separator: ","))",
            "persistent=\(persistentSystemItems.keys.sorted().map { "\($0)|\(persistentSystemItems[$0]!.rawValue)" }.joined(separator: "\n"))",
            "authorized=\(authorizedStates.joined(separator: "\n"))",
        ].joined(separator: "\n")
        return Self.sha256(canonical)
    }

    /// A stable authorization fingerprint for owner-approved managed policy.
    ///
    /// The exact plan fingerprint above deliberately includes every observed
    /// running bundle for audit evidence. This fingerprint excludes unrelated
    /// bundles whose helper processes can appear between dry-run and mutation,
    /// while still binding authorization to every managed bundle's policy,
    /// effective allow/deny state, presentation, and system-item set.
    public func managedPolicyFingerprint(
        assignments: BundlePolicyAssignments
    ) -> String {
        let allowed = Set(allowedBundleIdentifiers)
        let managedStates = [
            (MenuBarBundlePolicy.visible, assignments.visible),
            (MenuBarBundlePolicy.revealable, assignments.revealable),
            (MenuBarBundlePolicy.hidden, assignments.hidden),
        ].flatMap { policy, identifiers in
            identifiers.sorted().map { identifier in
                "\(identifier)|\(policy.rawValue)|allowed=\(allowed.contains(identifier))"
            }
        }
        let canonical = [
            "presentation=\(presentation.rawValue)",
            "system=\(allowedSystemItems.sorted().map(String.init).joined(separator: ","))",
            "persistent=\(persistentSystemItems.keys.sorted().map { "\($0)|\(persistentSystemItems[$0]!.rawValue)" }.joined(separator: "\n"))",
            "managed=\(managedStates.joined(separator: "\n"))",
        ].joined(separator: "\n")
        return Self.sha256(canonical)
    }

    private static func sha256(_ canonical: String) -> String {
        return SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

public enum RevealAllowlistPlannerError: Error, Equatable, Sendable {
    case invalidBlennyBundleIdentifier
    case invalidSystemItemPolicy(String)
    case systemItemPoliciesUnavailable
}

public enum RevealAllowlistPlanner {
    public static let allKnownSystemItems = Array(0 ..< 9)
    public static let bluetoothSystemItem = 1

    public static func plan(
        presentation: RevealSessionPresentation,
        assignments: BundlePolicyAssignments,
        observedRunningBundleIdentifiers: Set<String>,
        blennyBundleIdentifier: String,
        bluetoothPolicy: MenuBarBundlePolicy = .visible,
        systemItemPolicies: [String: MenuBarBundlePolicy] = [:]
    ) throws -> RevealAllowlistPlan {
        guard !blennyBundleIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty else {
            throw RevealAllowlistPlannerError.invalidBlennyBundleIdentifier
        }

        var allowed = observedRunningBundleIdentifiers
        allowed.formUnion(assignments.visible)
        allowed.insert(blennyBundleIdentifier)
        allowed.subtract(assignments.hidden)

        switch presentation {
        case .baseline:
            allowed.subtract(assignments.revealable)
        case .revealed:
            allowed.formUnion(assignments.revealable)
        }

        // Blenny is the bounded fallback affordance and must never be removed by
        // a policy assignment. The validated initializer prevents overlap among
        // user policies; this final insertion protects the system safety invariant.
        allowed.insert(blennyBundleIdentifier)

        var allowedSystemItems = allKnownSystemItems
        let bluetoothAllowed: Bool
        switch (presentation, bluetoothPolicy) {
        case (_, .visible), (.revealed, .revealable):
            bluetoothAllowed = true
        case (.baseline, .revealable), (_, .hidden):
            bluetoothAllowed = false
        }
        if !bluetoothAllowed {
            allowedSystemItems.removeAll { $0 == bluetoothSystemItem }
        }

        var persistentSystemItems: [String: PersistentSystemItemPresentation] = [:]
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        for identifier in systemItemPolicies.keys.sorted() {
            guard identifier != "com.apple.menuextra.bluetooth",
                  let policy = systemItemPolicies[identifier] else {
                throw RevealAllowlistPlannerError.invalidSystemItemPolicy(identifier)
            }
            if PersistentSystemItemPolicyCatalog.controllableItem(for: identifier) != nil {
                switch (presentation, policy) {
                case (_, .visible):
                    persistentSystemItems[identifier] = .restored
                case (.revealed, .revealable):
                    persistentSystemItems[identifier] = .revealed
                case (.baseline, .revealable), (_, .hidden):
                    persistentSystemItems[identifier] = .hidden
                }
                continue
            }
            guard let item = SystemItemPolicyCatalog.controllableItem(for: identifier) else {
                throw RevealAllowlistPlannerError.invalidSystemItemPolicy(identifier)
            }
            let itemAllowed: Bool
            switch (presentation, policy) {
            case (_, .visible), (.revealed, .revealable):
                itemAllowed = true
            case (.baseline, .revealable), (_, .hidden):
                itemAllowed = false
            }
            if !itemAllowed {
                allowedSystemItems.removeAll { $0 == item.rawValue }
            }
        }
        #else
        guard systemItemPolicies.isEmpty else {
            throw RevealAllowlistPlannerError.systemItemPoliciesUnavailable
        }
        #endif

        return RevealAllowlistPlan(
            presentation: presentation,
            allowedSystemItems: allowedSystemItems,
            allowedBundleIdentifiers: allowed.sorted(),
            persistentSystemItems: persistentSystemItems
        )
    }
}

public enum RevealEntryPoint: String, Equatable, Sendable {
    case nativeOverflow
    case blennyFallback
}

public enum RevealEntryPointSelectionError: Error, Equatable, Sendable {
    case noUsableEntryPoint
}

public enum RevealEntryPointSelector {
    public static func select(
        nativeOverflowPresent: Bool,
        blennyFallbackInstalled: Bool
    ) throws -> RevealEntryPoint {
        if nativeOverflowPresent {
            return .nativeOverflow
        }
        if blennyFallbackInstalled {
            return .blennyFallback
        }
        throw RevealEntryPointSelectionError.noUsableEntryPoint
    }
}

public enum RevealSessionEvent: Equatable, Sendable {
    case entryAvailabilityChanged(
        nativeOverflowPresent: Bool,
        blennyFallbackInstalled: Bool,
        sequence: UInt64
    )
    case nativeOverflowChanged(expanded: Bool, sequence: UInt64)
    case blennyFallbackToggled(sequence: UInt64)
    case sessionTimedOut(sequence: UInt64)
    case experimentTimedOut(sequence: UInt64)
    case connectionInvalidated(sequence: UInt64)

    var sequence: UInt64 {
        switch self {
        case let .entryAvailabilityChanged(_, _, sequence),
             let .nativeOverflowChanged(_, sequence),
             let .blennyFallbackToggled(sequence),
             let .sessionTimedOut(sequence),
             let .experimentTimedOut(sequence),
             let .connectionInvalidated(sequence):
            sequence
        }
    }
}

public enum RevealSessionEventDisposition: Equatable, Sendable {
    case ignoredDuplicateOrOutOfOrder
    case ignoredInactiveEntryPoint
    case entryPointChanged(RevealEntryPoint)
    case transitionRequired(RevealSessionPresentation)
    case noChange
    case restoreRequired
    case failedClosed
}

public struct RevealSessionReducer: Equatable, Sendable {
    public private(set) var presentation: RevealSessionPresentation
    public private(set) var entryPoint: RevealEntryPoint?
    public private(set) var lastSequence: UInt64?
    private var nativeOverflowPresent = false
    private var blennyFallbackInstalled = false

    public init(
        presentation: RevealSessionPresentation = .baseline,
        entryPoint: RevealEntryPoint? = nil
    ) {
        self.presentation = presentation
        self.entryPoint = entryPoint
    }

    public mutating func reduce(
        _ event: RevealSessionEvent
    ) -> RevealSessionEventDisposition {
        if let lastSequence, event.sequence <= lastSequence {
            return .ignoredDuplicateOrOutOfOrder
        }
        lastSequence = event.sequence

        switch event {
        case let .entryAvailabilityChanged(
            nativeOverflowPresent,
            blennyFallbackInstalled,
            _
        ):
            self.nativeOverflowPresent = nativeOverflowPresent
            self.blennyFallbackInstalled = blennyFallbackInstalled
            do {
                let selected = try RevealEntryPointSelector.select(
                    nativeOverflowPresent: nativeOverflowPresent,
                    blennyFallbackInstalled: blennyFallbackInstalled
                )
                if presentation == .revealed,
                   entryPoint == .blennyFallback,
                   selected == .nativeOverflow {
                    // A fallback reveal can itself create native overflow. Keep
                    // the already-usable fallback until that bounded session ends.
                    return .noChange
                }
                if entryPoint == selected { return .noChange }
                entryPoint = selected
                return .entryPointChanged(selected)
            } catch {
                entryPoint = nil
                return .failedClosed
            }

        case let .nativeOverflowChanged(expanded, _):
            guard entryPoint == .nativeOverflow else {
                return .ignoredInactiveEntryPoint
            }
            return setPresentation(expanded ? .revealed : .baseline)

        case .blennyFallbackToggled:
            guard entryPoint == .blennyFallback else {
                return .ignoredInactiveEntryPoint
            }
            return setPresentation(presentation == .baseline ? .revealed : .baseline)

        case .sessionTimedOut:
            return setPresentation(.baseline)

        case .experimentTimedOut,
             .connectionInvalidated:
            presentation = .baseline
            return .restoreRequired
        }
    }

    private mutating func setPresentation(
        _ desired: RevealSessionPresentation
    ) -> RevealSessionEventDisposition {
        guard presentation != desired else { return .noChange }
        presentation = desired
        if desired == .baseline {
            entryPoint = try? RevealEntryPointSelector.select(
                nativeOverflowPresent: nativeOverflowPresent,
                blennyFallbackInstalled: blennyFallbackInstalled
            )
        }
        return .transitionRequired(desired)
    }
}
