import Foundation

public enum AccessibilityOnboardingAction: Equatable, Sendable {
    case alreadyGranted
    case requestSystemPrompt
    case openSystemSettings
}

public enum AccessibilityOnboardingPolicy {
    public static func action(
        isTrusted: Bool,
        hasRequestedSystemPrompt: Bool
    ) -> AccessibilityOnboardingAction {
        if isTrusted { return .alreadyGranted }
        return hasRequestedSystemPrompt ? .openSystemSettings : .requestSystemPrompt
    }
}

public enum MenuBarOwnershipSnapshotIssue: Error, Equatable, Sendable {
    case accessibilityNotGranted
    case elementLimitReached
    case timeLimitReached
}

extension MenuBarOwnershipSnapshotIssue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .accessibilityNotGranted:
            return "Accessibility access is required for the bounded read-only menu-bar scan"
        case .elementLimitReached:
            return "the bounded menu-bar scan reached its element limit"
        case .timeLimitReached:
            return "the bounded menu-bar scan reached its time limit"
        }
    }
}

public struct MenuBarOwnershipSnapshot: Equatable, Sendable {
    public let observations: [MenuBarPolicyOwnershipObservation]
    public let issues: [MenuBarOwnershipSnapshotIssue]

    public var isComplete: Bool { issues.isEmpty }

    public init(
        observations: [MenuBarPolicyOwnershipObservation],
        issues: [MenuBarOwnershipSnapshotIssue]
    ) {
        self.observations = observations
        self.issues = issues
    }
}

public enum MenuBarOwnershipSnapshotBuilder {
    public static func make(from report: DiagnosticReport) -> MenuBarOwnershipSnapshot {
        var issues: [MenuBarOwnershipSnapshotIssue] = []
        if !report.accessibilityTrusted {
            issues.append(.accessibilityNotGranted)
        }
        if report.elementLimitReached {
            issues.append(.elementLimitReached)
        }
        if report.timeLimitReached {
            issues.append(.timeLimitReached)
        }

        struct OwnerKey: Hashable {
            let processIdentifier: Int32
            let bundleIdentifier: String?
        }

        let topLevelMenuExtras = report.items.filter { item in
            item.source == .applicationExtrasMenuBar
                && item.classification == .manageableCandidate
                && item.role == "AXMenuBarItem"
                && item.subrole == "AXMenuExtra"
                && !isCriticalSystemOwner(item.ownerBundleIdentifier)
        }
        let grouped = Dictionary(grouping: topLevelMenuExtras) { item in
            OwnerKey(
                processIdentifier: item.ownerPID,
                bundleIdentifier: item.ownerBundleIdentifier
            )
        }
        let observations = grouped.map { key, items in
            MenuBarPolicyOwnershipObservation(
                bundleIdentifier: key.bundleIdentifier,
                processIdentifier: key.processIdentifier,
                menuBarItemCount: items.count
            )
        }.sorted { first, second in
            let firstIdentifier = first.bundleIdentifier ?? ""
            let secondIdentifier = second.bundleIdentifier ?? ""
            return (firstIdentifier.lowercased(), firstIdentifier, first.processIdentifier)
                < (secondIdentifier.lowercased(), secondIdentifier, second.processIdentifier)
        }
        return MenuBarOwnershipSnapshot(observations: observations, issues: issues)
    }

    private static func isCriticalSystemOwner(_ bundleIdentifier: String?) -> Bool {
        bundleIdentifier?.lowercased().hasPrefix("com.apple.") == true
    }
}

public enum PolicyEditorAssignmentResult: Equatable, Sendable {
    case changed
    case unchanged
    case rejectedPinnedBlenny
    case unknownCandidate
}

public struct PolicyEditorViewModel: Equatable, Sendable {
    public let acceptedPolicy: PersistentBundlePolicyDocument
    public let candidateInventory: PolicyCandidateInventory
    public let blennyBundleIdentifier: String
    public private(set) var draft: BundlePolicyDraft

    private let initialDraft: BundlePolicyDraft

    public init(
        acceptedPolicy: PersistentBundlePolicyDocument,
        candidateInventory: PolicyCandidateInventory,
        blennyBundleIdentifier: String
    ) throws {
        self.acceptedPolicy = try acceptedPolicy.validated(
            forBlennyBundleIdentifier: blennyBundleIdentifier
        )
        self.candidateInventory = candidateInventory
        self.blennyBundleIdentifier = blennyBundleIdentifier
        let draft = Self.makeDraft(
            acceptedPolicy: acceptedPolicy,
            candidateInventory: candidateInventory,
            blennyBundleIdentifier: blennyBundleIdentifier
        )
        self.initialDraft = draft
        self.draft = draft
    }

    public var hasDraftChanges: Bool { draft != initialDraft }

    public var validationScope: PolicyValidationScope {
        let identifiers = Set(
            acceptedPolicy.policies.map(\.bundleIdentifier)
                + candidateInventory.bundleIdentifiers
        )
        return PolicyValidationScope(approvedBundleIdentifiers: Array(identifiers))
    }

    public var acceptedPolicyScope: PolicyValidationScope {
        PolicyValidationScope(
            approvedBundleIdentifiers: acceptedPolicy.policies.map(\.bundleIdentifier)
        )
    }

    public func candidates(in policy: MenuBarBundlePolicy) -> [PolicyCandidate] {
        let assigned = Set(values(for: policy).compactMap(BundlePolicyIdentity.canonicalKey))
        return candidateInventory.candidates.filter { candidate in
            guard let canonical = BundlePolicyIdentity.canonicalKey(
                for: candidate.bundleIdentifier
            ) else { return false }
            return assigned.contains(canonical)
        }
    }

    @discardableResult
    public mutating func assign(
        bundleIdentifier: String,
        to policy: MenuBarBundlePolicy
    ) -> PolicyEditorAssignmentResult {
        guard candidateInventory.bundleIdentifiers.contains(where: {
            BundlePolicyIdentity.canonicalKey(for: $0)
                == BundlePolicyIdentity.canonicalKey(for: bundleIdentifier)
        }) else {
            return .unknownCandidate
        }
        if BundlePolicyIdentity.canonicalKey(for: bundleIdentifier)
            == BundlePolicyIdentity.canonicalKey(for: blennyBundleIdentifier),
           policy != .pinned {
            return .rejectedPinnedBlenny
        }
        let updated = draft.assigning(bundleIdentifier, to: policy)
        guard updated != draft else { return .unchanged }
        draft = Self.sorted(updated)
        return .changed
    }

    public mutating func discardDraft(using acceptedDraft: BundlePolicyDraft) {
        var reset = acceptedDraft
        let assigned = Set(
            (reset.pinned + reset.revealable + reset.hidden)
                .compactMap(BundlePolicyIdentity.canonicalKey)
        )
        for candidate in candidateInventory.candidates {
            guard let canonical = BundlePolicyIdentity.canonicalKey(
                for: candidate.bundleIdentifier
            ), !assigned.contains(canonical) else { continue }
            let policy: MenuBarBundlePolicy = canonical
                == BundlePolicyIdentity.canonicalKey(for: blennyBundleIdentifier)
                ? .pinned : .revealable
            reset = reset.assigning(candidate.bundleIdentifier, to: policy)
        }
        reset = reset.assigning(blennyBundleIdentifier, to: .pinned)
        draft = Self.sorted(reset)
    }

    private func values(for policy: MenuBarBundlePolicy) -> [String] {
        switch policy {
        case .pinned: draft.pinned
        case .revealable: draft.revealable
        case .hidden: draft.hidden
        }
    }

    private static func makeDraft(
        acceptedPolicy: PersistentBundlePolicyDocument,
        candidateInventory: PolicyCandidateInventory,
        blennyBundleIdentifier: String
    ) -> BundlePolicyDraft {
        var draft = BundlePolicyDraft(acceptedPolicy: acceptedPolicy)
        let assigned = Set(
            (draft.pinned + draft.revealable + draft.hidden)
                .compactMap(BundlePolicyIdentity.canonicalKey)
        )
        for candidate in candidateInventory.candidates {
            guard let canonical = BundlePolicyIdentity.canonicalKey(
                for: candidate.bundleIdentifier
            ), !assigned.contains(canonical) else { continue }
            let policy: MenuBarBundlePolicy = canonical
                == BundlePolicyIdentity.canonicalKey(for: blennyBundleIdentifier)
                ? .pinned : .revealable
            draft = draft.assigning(candidate.bundleIdentifier, to: policy)
        }
        draft = draft.assigning(blennyBundleIdentifier, to: .pinned)
        return sorted(draft)
    }

    private static func sorted(_ draft: BundlePolicyDraft) -> BundlePolicyDraft {
        func sort(_ values: [String]) -> [String] {
            values.sorted { ($0.lowercased(), $0) < ($1.lowercased(), $1) }
        }
        return BundlePolicyDraft(
            pinned: sort(draft.pinned),
            revealable: sort(draft.revealable),
            hidden: sort(draft.hidden)
        )
    }
}
