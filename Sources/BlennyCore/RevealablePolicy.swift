import Foundation

public enum MenuBarBundlePolicy: String, CaseIterable, Sendable {
    case pinned
    case revealable
    case hidden
}

public enum BundlePolicyAssignmentsError: Error, Equatable, Sendable {
    case emptyBundleIdentifier
    case overlappingPolicies(bundleIdentifier: String)
}

public struct BundlePolicyAssignments: Equatable, Sendable {
    public let pinned: Set<String>
    public let revealable: Set<String>
    public let hidden: Set<String>

    public init(
        pinned: Set<String>,
        revealable: Set<String>,
        hidden: Set<String>
    ) throws {
        let allIdentifiers = pinned.union(revealable).union(hidden)
        guard allIdentifiers.allSatisfy(Self.isValidBundleIdentifier) else {
            throw BundlePolicyAssignmentsError.emptyBundleIdentifier
        }

        let overlaps = pinned.intersection(revealable)
            .union(pinned.intersection(hidden))
            .union(revealable.intersection(hidden))
        if let overlap = overlaps.sorted().first {
            throw BundlePolicyAssignmentsError.overlappingPolicies(
                bundleIdentifier: overlap
            )
        }

        self.pinned = pinned
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

public struct RevealAllowlistPlan: Equatable, Sendable {
    public let presentation: RevealSessionPresentation
    public let allowedSystemItems: [Int]
    public let allowedBundleIdentifiers: [String]

    public init(
        presentation: RevealSessionPresentation,
        allowedSystemItems: [Int],
        allowedBundleIdentifiers: [String]
    ) {
        self.presentation = presentation
        self.allowedSystemItems = allowedSystemItems
        self.allowedBundleIdentifiers = allowedBundleIdentifiers
    }
}

public enum RevealAllowlistPlannerError: Error, Equatable, Sendable {
    case invalidBlennyBundleIdentifier
}

public enum RevealAllowlistPlanner {
    public static let allKnownSystemItems = Array(0 ..< 9)

    public static func plan(
        presentation: RevealSessionPresentation,
        assignments: BundlePolicyAssignments,
        observedRunningBundleIdentifiers: Set<String>,
        blennyBundleIdentifier: String
    ) throws -> RevealAllowlistPlan {
        guard !blennyBundleIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty else {
            throw RevealAllowlistPlannerError.invalidBlennyBundleIdentifier
        }

        var allowed = observedRunningBundleIdentifiers
        allowed.formUnion(assignments.pinned)
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

        return RevealAllowlistPlan(
            presentation: presentation,
            allowedSystemItems: allKnownSystemItems,
            allowedBundleIdentifiers: allowed.sorted()
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
    case connectionInvalidated(sequence: UInt64)

    var sequence: UInt64 {
        switch self {
        case let .entryAvailabilityChanged(_, _, sequence),
             let .nativeOverflowChanged(_, sequence),
             let .blennyFallbackToggled(sequence),
             let .sessionTimedOut(sequence),
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

        case .connectionInvalidated:
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
