import Foundation

public enum AccessibilityOnboardingAction: Equatable, Sendable {
    case alreadyGranted
    case requestSystemPrompt
    case openSystemSettings
}

/// Prevents repeated system prompts during one process lifetime without
/// suppressing a new request after the app is replaced or reopened.
public struct AccessibilityOnboardingState: Sendable {
    public private(set) var hasRequestedSystemPromptThisLaunch = false

    public init() {}

    public mutating func nextAction(isTrusted: Bool) -> AccessibilityOnboardingAction {
        if isTrusted { return .alreadyGranted }
        if hasRequestedSystemPromptThisLaunch { return .openSystemSettings }
        hasRequestedSystemPromptThisLaunch = true
        return .requestSystemPrompt
    }
}

/// Retains a grant event even when presentation reads trust before activation.
public struct AccessibilityGrantRefreshState: Sendable {
    public private(set) var pending = false
    private var previousTrust: Bool?

    public init() {}

    public mutating func observe(trusted: Bool) {
        if !trusted { pending = false }
        else if previousTrust == false { pending = true }
        previousTrust = trusted
    }

    public mutating func didBeginRefresh() { pending = false }
}

public enum AccessibilityPermissionRefreshPolicy {
    public static func shouldRefresh(
        previouslyTrusted: Bool?,
        isTrusted: Bool,
        isRefreshing: Bool,
        hasDraftChanges: Bool
    ) -> Bool {
        previouslyTrusted == false
            && isTrusted
            && !isRefreshing
            && !hasDraftChanges
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
    public let systemItems: [SystemMenuBarItemObservation]
    public let unattributedItems: [UnattributedMenuBarItemObservation]
    public let issues: [MenuBarOwnershipSnapshotIssue]

    public var isComplete: Bool { issues.isEmpty }

    public func observedMenuBarItemCount(forProcessIdentifier processIdentifier: Int32) -> Int {
        observations.filter { $0.processIdentifier == processIdentifier }
            .reduce(0) { $0 + $1.menuBarItemCount }
            + unattributedItems.filter { $0.processIdentifier == processIdentifier }
                .reduce(0) { $0 + $1.observationCount }
    }

    public init(
        observations: [MenuBarPolicyOwnershipObservation],
        systemItems: [SystemMenuBarItemObservation],
        unattributedItems: [UnattributedMenuBarItemObservation] = [],
        issues: [MenuBarOwnershipSnapshotIssue]
    ) {
        self.observations = observations
        self.systemItems = systemItems
        self.unattributedItems = unattributedItems
        self.issues = issues
    }
}

public struct SystemMenuBarItemObservation: Equatable, Sendable {
    public static let bluetoothIdentifier = "com.apple.menuextra.bluetooth"
    public static let clockIdentifier = "com.apple.menuextra.clock"
    public let observationIdentifier: String
    public let ownerBundleIdentifier: String
    public let displayName: String
    public let observationCount: Int

    public init(
        observationIdentifier: String,
        ownerBundleIdentifier: String,
        displayName: String,
        observationCount: Int
    ) {
        self.observationIdentifier = observationIdentifier
        self.ownerBundleIdentifier = ownerBundleIdentifier
        self.displayName = displayName
        self.observationCount = observationCount
    }
}

/// A live menu extra without bundle ownership is presentation only. Its PID
/// identifies this refresh's row, never a persistent policy or writer target.
public struct UnattributedMenuBarItemObservation: Equatable, Sendable {
    public let processIdentifier: Int32
    public let observationCount: Int
    public let itemHelp: String?

    public init(processIdentifier: Int32, observationCount: Int, itemHelp: String? = nil) {
        self.processIdentifier = processIdentifier
        self.observationCount = observationCount
        self.itemHelp = itemHelp
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
                && (!isCriticalSystemOwner(item.ownerBundleIdentifier)
                    || ExperimentalAppleBundlePolicyCatalog.contains(
                        item.ownerBundleIdentifier
                    ))
        }
        let grouped = Dictionary(grouping: topLevelMenuExtras.filter {
            $0.ownerBundleIdentifier != nil
        }) { item in
            OwnerKey(
                processIdentifier: item.ownerPID,
                bundleIdentifier: item.ownerBundleIdentifier
            )
        }
        let unattributedItems = Dictionary(grouping: topLevelMenuExtras.filter {
            $0.ownerBundleIdentifier == nil
        }, by: \.ownerPID).map { processIdentifier, items in
            UnattributedMenuBarItemObservation(
                processIdentifier: processIdentifier,
                observationCount: items.count,
                itemHelp: items.count == 1 ? items[0].itemHelp : nil
            )
        }.sorted { $0.processIdentifier < $1.processIdentifier }
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
        let systemItems = makeSystemItems(from: report.items)
        return MenuBarOwnershipSnapshot(
            observations: observations,
            systemItems: systemItems,
            unattributedItems: unattributedItems,
            issues: issues
        )
    }

    private static func makeSystemItems(
        from records: [MenuBarItemRecord]
    ) -> [SystemMenuBarItemObservation] {
        let identifiableItems = records.filter { record in
            (record.source == .menuBarAgent
                || (isCriticalSystemOwner(record.ownerBundleIdentifier)
                    && !ExperimentalAppleBundlePolicyCatalog.contains(
                        record.ownerBundleIdentifier
                    )))
                && record.classification != .nativeOverflowPresentationControl
                && record.role == "AXMenuBarItem"
                && record.subrole == "AXMenuExtra"
                && systemItemObservationIdentifier(for: record) != nil
                && hasSystemItemDisplayIdentity(record)
        }
        let grouped = Dictionary(grouping: identifiableItems) {
            systemItemObservationIdentifier(for: $0) ?? ""
        }
        return grouped.compactMap { identifier, records in
            guard !identifier.isEmpty, let first = records.first else { return nil }
            return SystemMenuBarItemObservation(
                observationIdentifier: identifier,
                ownerBundleIdentifier: first.ownerBundleIdentifier
                    ?? "com.apple.MenuBarAgent",
                displayName: systemItemDisplayName(
                    identifier: identifier,
                    records: records
                ),
                observationCount: records.count
            )
        }.sorted {
            ($0.displayName.lowercased(), $0.observationIdentifier)
                < ($1.displayName.lowercased(), $1.observationIdentifier)
        }
    }

    private static func systemItemObservationIdentifier(
        for record: MenuBarItemRecord
    ) -> String? {
        if let identifier = record.accessibilityIdentifier, !identifier.isEmpty {
            return identifier
        }
        return record.identity?.stableKey
    }

    private static func systemItemObservedName(
        for record: MenuBarItemRecord
    ) -> String? {
        [record.title, record.itemDescription].compactMap { $0 }.first { !$0.isEmpty }
    }

    private static func hasSystemItemDisplayIdentity(
        _ record: MenuBarItemRecord
    ) -> Bool {
        if systemItemObservedName(for: record) != nil { return true }
        guard let identifier = systemItemObservationIdentifier(for: record) else {
            return false
        }
        return knownSystemItemDisplayName(identifier: identifier) != nil
    }

    private static func systemItemDisplayName(
        identifier: String,
        records: [MenuBarItemRecord]
    ) -> String {
        if let knownName = knownSystemItemDisplayName(identifier: identifier) {
            return knownName
        }
        let observedName = records.lazy.compactMap(systemItemObservedName(for:)).first
        return observedName ?? identifier.split(separator: ".").last.map(String.init)
            ?? identifier
    }

    private static func knownSystemItemDisplayName(identifier: String) -> String? {
        PolicyIconResolver.systemItemDisplayName(observationIdentifier: identifier)
    }

    private static func isCriticalSystemOwner(_ bundleIdentifier: String?) -> Bool {
        bundleIdentifier?.lowercased().hasPrefix("com.apple.") == true
    }
}

public enum PolicyEditorAssignmentResult: Equatable, Sendable {
    case changed
    case unchanged
    case rejectedBlennyMustRemainVisible
    case unknownCandidate
}

public struct PolicyEditorViewModel: Equatable, Sendable {
    public let acceptedPolicy: PersistentBundlePolicyDocument
    public let candidateInventory: PolicyCandidateInventory
    public let systemItems: [SystemMenuBarItemObservation]
    public let unattributedItems: [UnattributedMenuBarItemObservation]
    public let blennyBundleIdentifier: String
    public private(set) var draft: BundlePolicyDraft

    private let initialDraft: BundlePolicyDraft

    public init(
        acceptedPolicy: PersistentBundlePolicyDocument,
        candidateInventory: PolicyCandidateInventory,
        systemItems: [SystemMenuBarItemObservation] = [],
        unattributedItems: [UnattributedMenuBarItemObservation] = [],
        blennyBundleIdentifier: String
    ) throws {
        self.acceptedPolicy = try acceptedPolicy.validated(
            forBlennyBundleIdentifier: blennyBundleIdentifier
        )
        self.candidateInventory = candidateInventory
        self.unattributedItems = unattributedItems
        var retainedSystemItems = systemItems
        let retainedPolicies = Self.acceptedSystemItemPolicies(acceptedPolicy)
        for (identifier, policy) in retainedPolicies where policy != .visible {
            guard let item = SystemItemPolicyCatalog.controllableItem(for: identifier),
                  !retainedSystemItems.contains(where: {
                      $0.observationIdentifier == item.identifier
                  }) else { continue }
            retainedSystemItems.append(
                SystemMenuBarItemObservation(
                    observationIdentifier: item.identifier,
                    ownerBundleIdentifier: "com.apple.MenuBarAgent",
                    displayName: item.displayName,
                    observationCount: 0
                )
            )
        }
        self.systemItems = retainedSystemItems.sorted {
            ($0.displayName.lowercased(), $0.observationIdentifier)
                < ($1.displayName.lowercased(), $1.observationIdentifier)
        }
        self.blennyBundleIdentifier = blennyBundleIdentifier
        let draft = Self.makeDraft(
            acceptedPolicy: acceptedPolicy,
            blennyBundleIdentifier: blennyBundleIdentifier
        )
        self.initialDraft = draft
        self.draft = draft
    }

    public var hasDraftChanges: Bool { draft != initialDraft }

    public func synchronizingAcceptedPolicy(
        _ accepted: PersistentBundlePolicyDocument,
        preservingDraft: Bool
    ) throws -> Self {
        var updated = try Self(
            acceptedPolicy: accepted,
            candidateInventory: candidateInventory,
            systemItems: systemItems,
            unattributedItems: unattributedItems,
            blennyBundleIdentifier: blennyBundleIdentifier
        )
        if preservingDraft { updated.draft = draft }
        return updated
    }

    public var validationScope: PolicyValidationScope {
        PolicyValidationScope(
            approvedBundleIdentifiers: draft.visible + draft.revealable + draft.hidden
        )
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

    public var implicitVisibleCandidates: [PolicyCandidate] {
        let assigned = Set(
            (draft.visible + draft.revealable + draft.hidden)
                .compactMap(BundlePolicyIdentity.canonicalKey)
        )
        return candidateInventory.candidates.filter { candidate in
            guard let canonical = BundlePolicyIdentity.canonicalKey(
                for: candidate.bundleIdentifier
            ) else { return false }
            return !assigned.contains(canonical)
        }
    }

    public func effectivePolicy(for bundleIdentifier: String) -> MenuBarBundlePolicy? {
        guard let canonical = BundlePolicyIdentity.canonicalKey(for: bundleIdentifier),
              candidateInventory.bundleIdentifiers.contains(where: {
                  BundlePolicyIdentity.canonicalKey(for: $0) == canonical
              }) else {
            return nil
        }
        for policy in MenuBarBundlePolicy.allCases {
            if values(for: policy).contains(where: {
                BundlePolicyIdentity.canonicalKey(for: $0) == canonical
            }) {
                return policy
            }
        }
        return .visible
    }

    public func effectiveSystemItemPolicy(
        for observationIdentifier: String
    ) -> MenuBarBundlePolicy? {
        if let item = PersistentSystemItemPolicyCatalog.controllableItem(
            for: observationIdentifier
        ) {
            guard PersistentSystemItemPolicyCatalog.supportsManagement(for: item.identifier) else {
                return nil
            }
            return draft.systemItemPolicies[item.identifier] ?? .visible
        }
        guard let itemIdentifier = SystemItemPolicyCatalog.controllableItem(
                for: observationIdentifier
              )?.identifier,
              systemItems.contains(where: {
                  $0.observationIdentifier.lowercased() == itemIdentifier.lowercased()
              }) else { return nil }
        if itemIdentifier == SystemMenuBarItemObservation.bluetoothIdentifier {
            return draft.bluetoothPolicy
        }
        return draft.systemItemPolicies[itemIdentifier] ?? .visible
    }

    @discardableResult
    public mutating func assignBluetooth(
        to policy: MenuBarBundlePolicy
    ) -> PolicyEditorAssignmentResult {
        assignSystemItem(
            identifier: SystemMenuBarItemObservation.bluetoothIdentifier,
            to: policy
        )
    }

    @discardableResult
    public mutating func assignSystemItem(
        identifier: String,
        to policy: MenuBarBundlePolicy
    ) -> PolicyEditorAssignmentResult {
        let persistentIdentifier = PersistentSystemItemPolicyCatalog.controllableItem(
            for: identifier
        )?.identifier
        let itemIdentifier = persistentIdentifier
            ?? SystemItemPolicyCatalog.controllableItem(for: identifier)?.identifier
        guard let itemIdentifier,
              PersistentSystemItemPolicyCatalog.supportsManagement(for: itemIdentifier) else {
            return .unknownCandidate
        }
        if persistentIdentifier == nil,
           !systemItems.contains(where: {
               $0.observationIdentifier.lowercased() == itemIdentifier.lowercased()
           }) {
            return .unknownCandidate
        }
        let current = effectiveSystemItemPolicy(for: itemIdentifier)
        guard current != policy else { return .unchanged }
        let updated = itemIdentifier == SystemMenuBarItemObservation.bluetoothIdentifier
            ? draft.assigningBluetooth(to: policy)
            : draft.assigningSystemItem(identifier: itemIdentifier, to: policy)
        draft = Self.sorted(updated)
        return .changed
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
           policy != .visible {
            return .rejectedBlennyMustRemainVisible
        }
        let updated = draft.assigning(bundleIdentifier, to: policy)
        guard updated != draft else { return .unchanged }
        draft = Self.sorted(updated)
        return .changed
    }

    public mutating func discardDraft(using acceptedDraft: BundlePolicyDraft) {
        var reset = acceptedDraft
        reset = reset.assigning(blennyBundleIdentifier, to: .visible)
        draft = Self.sorted(reset)
    }

    private func values(for policy: MenuBarBundlePolicy) -> [String] {
        switch policy {
        case .visible: draft.visible
        case .revealable: draft.revealable
        case .hidden: draft.hidden
        }
    }

    private static func makeDraft(
        acceptedPolicy: PersistentBundlePolicyDocument,
        blennyBundleIdentifier: String
    ) -> BundlePolicyDraft {
        var draft = BundlePolicyDraft(acceptedPolicy: acceptedPolicy)
        draft = draft.assigning(blennyBundleIdentifier, to: .visible)
        return sorted(draft)
    }

    private static func sorted(_ draft: BundlePolicyDraft) -> BundlePolicyDraft {
        func sort(_ values: [String]) -> [String] {
            values.sorted { ($0.lowercased(), $0) < ($1.lowercased(), $1) }
        }
        return BundlePolicyDraft(
            visible: sort(draft.visible),
            revealable: sort(draft.revealable),
            hidden: sort(draft.hidden),
            bluetoothPolicy: draft.bluetoothPolicy,
            systemItemPolicies: draft.systemItemPolicies
        )
    }

    private static func acceptedSystemItemPolicies(
        _ policy: PersistentBundlePolicyDocument
    ) -> [String: MenuBarBundlePolicy] {
        var values = policy.systemItemPolicies
        values[SystemMenuBarItemObservation.bluetoothIdentifier] = policy.bluetoothPolicy
        return values
    }
}
