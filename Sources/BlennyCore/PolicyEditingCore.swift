import CryptoKit
import Foundation

public struct BundlePolicyDraft: Equatable, Sendable {
    public let pinned: [String]
    public let revealable: [String]
    public let hidden: [String]

    public init(
        pinned: [String],
        revealable: [String],
        hidden: [String]
    ) {
        self.pinned = pinned
        self.revealable = revealable
        self.hidden = hidden
    }

    public init(acceptedPolicy: PersistentBundlePolicyDocument) {
        self.init(
            pinned: acceptedPolicy.policies
                .filter { $0.policy == .pinned }
                .map(\.bundleIdentifier),
            revealable: acceptedPolicy.policies
                .filter { $0.policy == .revealable }
                .map(\.bundleIdentifier),
            hidden: acceptedPolicy.policies
                .filter { $0.policy == .hidden }
                .map(\.bundleIdentifier)
        )
    }

    public func assigning(
        _ bundleIdentifier: String,
        to policy: MenuBarBundlePolicy
    ) -> Self {
        let canonical = BundlePolicyIdentity.canonicalKey(for: bundleIdentifier)
        func removingMatch(from values: [String]) -> [String] {
            values.filter { BundlePolicyIdentity.canonicalKey(for: $0) != canonical }
        }

        var pinned = removingMatch(from: self.pinned)
        var revealable = removingMatch(from: self.revealable)
        var hidden = removingMatch(from: self.hidden)
        switch policy {
        case .pinned:
            pinned.append(bundleIdentifier)
        case .revealable:
            revealable.append(bundleIdentifier)
        case .hidden:
            hidden.append(bundleIdentifier)
        }
        return Self(pinned: pinned, revealable: revealable, hidden: hidden)
    }
}

public struct PolicyCandidate: Equatable, Sendable {
    public let bundleIdentifier: String
    public let processIdentifiers: [Int32]
    public let menuBarItemCount: Int

    public init(
        bundleIdentifier: String,
        processIdentifiers: [Int32],
        menuBarItemCount: Int
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifiers = Array(Set(processIdentifiers)).sorted()
        self.menuBarItemCount = menuBarItemCount
    }
}

public enum PolicyCandidateIssue: Error, Equatable, Hashable, Sendable {
    case unknownOwner(processIdentifier: Int32)
    case invalidBundleIdentifier(String)
    case caseConflictingIdentifiers([String])
    case ambiguousOwnership(bundleIdentifier: String, processIdentifiers: [Int32])
}

extension PolicyCandidateIssue: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .unknownOwner(processIdentifier):
            return "menu-bar owner PID \(processIdentifier) has unknown bundle ownership"
        case let .invalidBundleIdentifier(bundleIdentifier):
            return "menu-bar owner has invalid bundle identifier \(bundleIdentifier)"
        case let .caseConflictingIdentifiers(identifiers):
            return "menu-bar observations contain case-conflicting identifiers \(identifiers)"
        case let .ambiguousOwnership(bundleIdentifier, processIdentifiers):
            return "bundle \(bundleIdentifier) has ambiguous owner PIDs \(processIdentifiers)"
        }
    }
}

public struct PolicyCandidateInventory: Equatable, Sendable {
    public let candidates: [PolicyCandidate]
    public let issues: [PolicyCandidateIssue]

    public init(observations: [MenuBarPolicyOwnershipObservation]) {
        var issues: [PolicyCandidateIssue] = []
        var grouped: [String: [MenuBarPolicyOwnershipObservation]] = [:]

        for observation in observations where observation.menuBarItemCount > 0 {
            guard let bundleIdentifier = observation.bundleIdentifier else {
                issues.append(.unknownOwner(processIdentifier: observation.processIdentifier))
                continue
            }
            guard let canonical = BundlePolicyIdentity.canonicalKey(for: bundleIdentifier) else {
                issues.append(.invalidBundleIdentifier(bundleIdentifier))
                continue
            }
            grouped[canonical, default: []].append(observation)
        }

        var candidates: [PolicyCandidate] = []
        for canonical in grouped.keys.sorted() {
            guard let matching = grouped[canonical] else { continue }
            let spellings = Array(Set(matching.compactMap(\.bundleIdentifier))).sorted()
            if spellings.count > 1 {
                issues.append(.caseConflictingIdentifiers(spellings))
                continue
            }
            guard let bundleIdentifier = spellings.first else { continue }
            let processIdentifiers = Array(Set(matching.map(\.processIdentifier))).sorted()
            if processIdentifiers.count != 1 {
                issues.append(
                    .ambiguousOwnership(
                        bundleIdentifier: bundleIdentifier,
                        processIdentifiers: processIdentifiers
                    )
                )
                continue
            }
            candidates.append(
                PolicyCandidate(
                    bundleIdentifier: bundleIdentifier,
                    processIdentifiers: processIdentifiers,
                    menuBarItemCount: matching.reduce(0) { $0 + $1.menuBarItemCount }
                )
            )
        }

        self.candidates = candidates.sorted {
            ($0.bundleIdentifier.lowercased(), $0.bundleIdentifier)
                < ($1.bundleIdentifier.lowercased(), $1.bundleIdentifier)
        }
        self.issues = issues.sorted { $0.description < $1.description }
    }

    public var bundleIdentifiers: [String] {
        candidates.map(\.bundleIdentifier)
    }

    fileprivate var candidatesByCanonicalIdentifier: [String: PolicyCandidate] {
        Dictionary(uniqueKeysWithValues: candidates.compactMap { candidate in
            BundlePolicyIdentity.canonicalKey(for: candidate.bundleIdentifier).map {
                ($0, candidate)
            }
        })
    }
}

public struct PolicyValidationScope: Equatable, Sendable {
    public let approvedBundleIdentifiers: [String]

    public init(approvedBundleIdentifiers: [String]) {
        self.approvedBundleIdentifiers = approvedBundleIdentifiers.sorted {
            $0.lowercased() < $1.lowercased()
        }
    }
}

public enum PolicyEditIssue: Error, Equatable, Hashable, Sendable {
    case candidateInventory(PolicyCandidateIssue)
    case invalidBundleIdentifier(policy: MenuBarBundlePolicy, value: String)
    case duplicateBundleIdentifier(policy: MenuBarBundlePolicy, value: String)
    case caseConflictingBundleIdentifiers([String])
    case overlappingPolicies(bundleIdentifier: String, policies: [MenuBarBundlePolicy])
    case unknownBundleIdentifier(String)
    case missingCurrentOwnership(String)
    case missingApprovedBundle(String)
    case unapprovedBundle(String)
    case missingPinnedBlenny(String)
}

extension PolicyEditIssue: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .candidateInventory(issue):
            return issue.description
        case let .invalidBundleIdentifier(policy, value):
            return "\(policy.rawValue) contains invalid bundle identifier \(value)"
        case let .duplicateBundleIdentifier(policy, value):
            return "\(policy.rawValue) contains duplicate bundle identifier \(value)"
        case let .caseConflictingBundleIdentifiers(values):
            return "draft contains case-conflicting bundle identifiers \(values)"
        case let .overlappingPolicies(bundleIdentifier, policies):
            return "bundle \(bundleIdentifier) overlaps policies \(policies.map(\.rawValue))"
        case let .unknownBundleIdentifier(bundleIdentifier):
            return "draft bundle \(bundleIdentifier) is not a current menu-bar ownership candidate"
        case let .missingCurrentOwnership(bundleIdentifier):
            return "approved bundle \(bundleIdentifier) has no current attributable menu-bar owner"
        case let .missingApprovedBundle(bundleIdentifier):
            return "approved bundle \(bundleIdentifier) is missing from the draft"
        case let .unapprovedBundle(bundleIdentifier):
            return "draft bundle \(bundleIdentifier) is outside the approved validation scope"
        case let .missingPinnedBlenny(bundleIdentifier):
            return "Blenny bundle \(bundleIdentifier) must remain pinned"
        }
    }
}

public struct ValidatedPolicyDraft: Equatable, Sendable {
    public let document: PersistentBundlePolicyDocument?
    public let issues: [PolicyEditIssue]

    public var isValid: Bool { document != nil && issues.isEmpty }
}

public enum PolicyDraftValidator {
    private struct Occurrence {
        let spelling: String
        let policy: MenuBarBundlePolicy
    }

    public static func validate(
        draft: BundlePolicyDraft,
        managementEnabled: Bool,
        candidates: PolicyCandidateInventory,
        scope: PolicyValidationScope,
        blennyBundleIdentifier: String
    ) -> ValidatedPolicyDraft {
        var issues = candidates.issues.map(PolicyEditIssue.candidateInventory)
        var occurrences: [String: [Occurrence]] = [:]

        let groups: [(MenuBarBundlePolicy, [String])] = [
            (.pinned, draft.pinned),
            (.revealable, draft.revealable),
            (.hidden, draft.hidden),
        ]
        for (policy, values) in groups {
            var seenInGroup = Set<String>()
            for value in values {
                guard let canonical = BundlePolicyIdentity.canonicalKey(for: value) else {
                    issues.append(.invalidBundleIdentifier(policy: policy, value: value))
                    continue
                }
                if !seenInGroup.insert(canonical).inserted {
                    issues.append(.duplicateBundleIdentifier(policy: policy, value: value))
                }
                occurrences[canonical, default: []].append(
                    Occurrence(spelling: value, policy: policy)
                )
            }
        }

        for canonical in occurrences.keys.sorted() {
            guard let matching = occurrences[canonical] else { continue }
            let spellings = Array(Set(matching.map(\.spelling))).sorted()
            if spellings.count > 1 {
                issues.append(.caseConflictingBundleIdentifiers(spellings))
            }
            let policies = Array(Set(matching.map(\.policy))).sorted {
                $0.rawValue < $1.rawValue
            }
            if policies.count > 1 {
                issues.append(
                    .overlappingPolicies(
                        bundleIdentifier: spellings.first ?? canonical,
                        policies: policies
                    )
                )
            }
        }

        let candidateMap = candidates.candidatesByCanonicalIdentifier
        let approved = Dictionary(uniqueKeysWithValues: scope.approvedBundleIdentifiers.compactMap {
            identifier in
            BundlePolicyIdentity.canonicalKey(for: identifier).map { ($0, identifier) }
        })
        for canonical in occurrences.keys.sorted() where candidateMap[canonical] == nil {
            let spelling = occurrences[canonical]?.map(\.spelling).sorted().first ?? canonical
            if approved[canonical] != nil {
                issues.append(.missingCurrentOwnership(spelling))
            } else {
                issues.append(.unknownBundleIdentifier(spelling))
            }
        }

        for canonical in approved.keys.sorted() where occurrences[canonical] == nil {
            if let identifier = approved[canonical] {
                issues.append(.missingApprovedBundle(identifier))
            }
        }
        for canonical in occurrences.keys.sorted() where approved[canonical] == nil {
            let spelling = occurrences[canonical]?.map(\.spelling).sorted().first ?? canonical
            issues.append(.unapprovedBundle(spelling))
        }

        if let blennyCanonical = BundlePolicyIdentity.canonicalKey(
            for: blennyBundleIdentifier
        ) {
            let pinnedCanonicals = Set(draft.pinned.compactMap(BundlePolicyIdentity.canonicalKey))
            if !pinnedCanonicals.contains(blennyCanonical) {
                issues.append(.missingPinnedBlenny(blennyBundleIdentifier))
            }
        } else {
            issues.append(
                .invalidBundleIdentifier(policy: .pinned, value: blennyBundleIdentifier)
            )
        }

        issues = Array(Set(issues)).sorted { $0.description < $1.description }
        guard issues.isEmpty else {
            return ValidatedPolicyDraft(document: nil, issues: issues)
        }

        let entries = groups.flatMap { policy, values in
            values.compactMap { value -> PersistentBundlePolicyEntry? in
                guard let canonical = BundlePolicyIdentity.canonicalKey(for: value),
                      let candidate = candidateMap[canonical] else {
                    return nil
                }
                return PersistentBundlePolicyEntry(
                    bundleIdentifier: candidate.bundleIdentifier,
                    policy: policy
                )
            }
        }
        do {
            let document = try PersistentBundlePolicyDocument(
                managementEnabled: managementEnabled,
                policies: entries
            ).validated(forBlennyBundleIdentifier: blennyBundleIdentifier)
            return ValidatedPolicyDraft(document: document, issues: [])
        } catch {
            return ValidatedPolicyDraft(
                document: nil,
                issues: [.missingPinnedBlenny(blennyBundleIdentifier)]
            )
        }
    }
}

public enum PolicyDiffOperation: Equatable, Sendable {
    case managementEnabledChanged(from: Bool, to: Bool)
    case added(policy: MenuBarBundlePolicy)
    case removed(policy: MenuBarBundlePolicy)
    case moved(from: MenuBarBundlePolicy, to: MenuBarBundlePolicy)
}

public struct PolicyDiffChange: Equatable, Sendable {
    public let bundleIdentifier: String
    public let operation: PolicyDiffOperation
}

extension PolicyDiffChange: CustomStringConvertible {
    public var description: String {
        switch operation {
        case let .managementEnabledChanged(oldValue, newValue):
            return "MANAGEMENT \(oldValue ? "enabled" : "disabled") -> \(newValue ? "enabled" : "disabled")"
        case let .added(policy):
            return "ADD \(bundleIdentifier) -> \(policy.rawValue)"
        case let .removed(policy):
            return "REMOVE \(bundleIdentifier) <- \(policy.rawValue)"
        case let .moved(oldPolicy, newPolicy):
            return "MOVE \(bundleIdentifier) \(oldPolicy.rawValue) -> \(newPolicy.rawValue)"
        }
    }
}

public struct BundlePolicyDiff: Equatable, Sendable {
    public let changes: [PolicyDiffChange]

    public var isNoOp: Bool { changes.isEmpty }

    public static func between(
        old: PersistentBundlePolicyDocument,
        new: PersistentBundlePolicyDocument
    ) -> Self {
        let oldEntries = canonicalEntries(in: old)
        let newEntries = canonicalEntries(in: new)
        var changes: [PolicyDiffChange] = []

        if old.managementEnabled != new.managementEnabled {
            changes.append(
                PolicyDiffChange(
                    bundleIdentifier: "<management>",
                    operation: .managementEnabledChanged(
                        from: old.managementEnabled,
                        to: new.managementEnabled
                    )
                )
            )
        }

        for canonical in Set(oldEntries.keys).union(newEntries.keys).sorted() {
            let oldEntry = oldEntries[canonical]
            let newEntry = newEntries[canonical]
            switch (oldEntry, newEntry) {
            case let (nil, newEntry?):
                changes.append(
                    PolicyDiffChange(
                        bundleIdentifier: newEntry.bundleIdentifier,
                        operation: .added(policy: newEntry.policy)
                    )
                )
            case let (oldEntry?, nil):
                changes.append(
                    PolicyDiffChange(
                        bundleIdentifier: oldEntry.bundleIdentifier,
                        operation: .removed(policy: oldEntry.policy)
                    )
                )
            case let (oldEntry?, newEntry?) where oldEntry.policy != newEntry.policy:
                changes.append(
                    PolicyDiffChange(
                        bundleIdentifier: newEntry.bundleIdentifier,
                        operation: .moved(from: oldEntry.policy, to: newEntry.policy)
                    )
                )
            default:
                break
            }
        }
        return Self(changes: changes)
    }

    private static func canonicalEntries(
        in document: PersistentBundlePolicyDocument
    ) -> [String: PersistentBundlePolicyEntry] {
        Dictionary(uniqueKeysWithValues: document.policies.compactMap { entry in
            BundlePolicyIdentity.canonicalKey(for: entry.bundleIdentifier).map {
                ($0, entry)
            }
        })
    }
}

public enum PolicyEditPersistenceMode: Equatable, Sendable {
    case saveAcceptedPolicy
    case restorePreviousPolicy
}

public struct PolicyDryRunImpactReport: Equatable, Sendable {
    public let oldPolicy: PersistentBundlePolicyDocument
    public let proposedPolicy: PersistentBundlePolicyDocument?
    public let rawDraft: BundlePolicyDraft
    public let diff: BundlePolicyDiff?
    public let issues: [PolicyEditIssue]
    public let oldBaselinePlan: RevealAllowlistPlan?
    public let newBaselinePlan: RevealAllowlistPlan?
    public let newRevealPlan: RevealAllowlistPlan?
    public let approvedBundleIdentifiers: [String]
    public let recoverySteps: [String]

    public var isApplicable: Bool {
        proposedPolicy != nil && issues.isEmpty && newBaselinePlan != nil && newRevealPlan != nil
    }

    public var text: String {
        var lines: [String] = [
            "Blenny 0.0.5 Policy Editing Core dry-run impact report",
            "OLD POLICY",
        ]
        lines.append(contentsOf: Self.policyLines(oldPolicy))
        lines.append("NEW POLICY")
        if let proposedPolicy {
            lines.append(contentsOf: Self.policyLines(proposedPolicy))
        } else {
            lines.append("managementEnabled=<invalid draft>")
            lines.append(contentsOf: Self.draftLines(rawDraft))
        }
        lines.append("DIFF")
        if let diff, !diff.isNoOp {
            lines.append(contentsOf: diff.changes.map(\.description))
        } else if diff != nil {
            lines.append("NO-OP")
        } else {
            lines.append("UNAVAILABLE: validation failed")
        }
        lines.append("BASELINE IMPACT")
        lines.append(
            Self.planLine(
                newBaselinePlan,
                policy: proposedPolicy,
                approvedBundleIdentifiers: approvedBundleIdentifiers
            )
        )
        lines.append("ORDINARY REVEAL IMPACT")
        lines.append(
            Self.planLine(
                newRevealPlan,
                policy: proposedPolicy,
                approvedBundleIdentifiers: approvedBundleIdentifiers
            )
        )
        lines.append("APPROVED BUNDLES")
        lines.append(contentsOf: approvedBundleIdentifiers.map { "- \($0)" })
        lines.append("VALIDATION")
        lines.append(contentsOf: issues.isEmpty ? ["PASS"] : issues.map { "FAIL: \($0)" })
        lines.append("RECOVERY PLAN")
        lines.append(contentsOf: recoverySteps.enumerated().map { "\($0.offset + 1). \($0.element)" })
        return lines.joined(separator: "\n")
    }

    public var fingerprint: String {
        SHA256.hash(data: Data(text.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func policyLines(
        _ document: PersistentBundlePolicyDocument
    ) -> [String] {
        ["managementEnabled=\(document.managementEnabled)"] + MenuBarBundlePolicy.allCases.map {
            policy in
            let identifiers = document.policies
                .filter { $0.policy == policy }
                .map(\.bundleIdentifier)
                .sorted { $0.lowercased() < $1.lowercased() }
            return "\(policy.rawValue)=\(identifiers.joined(separator: ","))"
        }
    }

    private static func draftLines(_ draft: BundlePolicyDraft) -> [String] {
        [
            "pinned=\(draft.pinned.joined(separator: ","))",
            "revealable=\(draft.revealable.joined(separator: ","))",
            "hidden=\(draft.hidden.joined(separator: ","))",
        ]
    }

    private static func planLine(
        _ plan: RevealAllowlistPlan?,
        policy: PersistentBundlePolicyDocument?,
        approvedBundleIdentifiers: [String]
    ) -> String {
        guard let plan, let policy else { return "UNAVAILABLE: validation failed" }
        let allowed = Set(plan.allowedBundleIdentifiers)
        let policyByCanonical = Dictionary(uniqueKeysWithValues: policy.policies.compactMap {
            entry in
            BundlePolicyIdentity.canonicalKey(for: entry.bundleIdentifier).map {
                ($0, entry.policy)
            }
        })
        let managed = approvedBundleIdentifiers.compactMap { identifier -> String? in
            guard let canonical = BundlePolicyIdentity.canonicalKey(for: identifier),
                  let assignment = policyByCanonical[canonical] else {
                return nil
            }
            return "\(identifier):\(assignment.rawValue):\(allowed.contains(identifier) ? "allowed" : "denied")"
        }.joined(separator: ",")
        let assignments = try? BundlePolicyAssignments(
            pinned: Set(policy.policies.filter { $0.policy == .pinned }.map(\.bundleIdentifier)),
            revealable: Set(
                policy.policies.filter { $0.policy == .revealable }.map(\.bundleIdentifier)
            ),
            hidden: Set(policy.policies.filter { $0.policy == .hidden }.map(\.bundleIdentifier))
        )
        let fingerprint = assignments.map {
            plan.managedPolicyFingerprint(assignments: $0)
        } ?? "unavailable"
        return "presentation=\(plan.presentation.rawValue) managed=[\(managed)] systemItems=\(plan.allowedSystemItems) managedFingerprint=\(fingerprint)"
    }
}

public struct PreparedPolicyEdit: Equatable, Sendable {
    public let oldPolicy: PersistentBundlePolicyDocument
    public let newPolicy: PersistentBundlePolicyDocument
    public let report: PolicyDryRunImpactReport
    public let persistenceMode: PolicyEditPersistenceMode
}

public enum PolicyDryRunError: Error, Equatable, Sendable {
    case invalidAcceptedPolicy
}

public enum PolicyDryRunner {
    public static func prepare(
        oldPolicy: PersistentBundlePolicyDocument,
        draft: BundlePolicyDraft,
        managementEnabled: Bool,
        candidates: PolicyCandidateInventory,
        observedRunningBundleIdentifiers: Set<String>,
        scope: PolicyValidationScope,
        blennyBundleIdentifier: String,
        persistenceMode: PolicyEditPersistenceMode = .saveAcceptedPolicy
    ) throws -> (report: PolicyDryRunImpactReport, prepared: PreparedPolicyEdit?) {
        _ = try oldPolicy.validated(forBlennyBundleIdentifier: blennyBundleIdentifier)
        let validation = PolicyDraftValidator.validate(
            draft: draft,
            managementEnabled: managementEnabled,
            candidates: candidates,
            scope: scope,
            blennyBundleIdentifier: blennyBundleIdentifier
        )

        let oldAssignments = try assignments(from: oldPolicy)
        let oldBaseline = try RevealAllowlistPlanner.plan(
            presentation: .baseline,
            assignments: oldAssignments,
            observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
            blennyBundleIdentifier: blennyBundleIdentifier
        )

        var diff: BundlePolicyDiff?
        var newBaseline: RevealAllowlistPlan?
        var newReveal: RevealAllowlistPlan?
        if let proposed = validation.document {
            diff = .between(old: oldPolicy, new: proposed)
            let assignments = try assignments(from: proposed)
            newBaseline = try RevealAllowlistPlanner.plan(
                presentation: .baseline,
                assignments: assignments,
                observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                blennyBundleIdentifier: blennyBundleIdentifier
            )
            newReveal = try RevealAllowlistPlanner.plan(
                presentation: .revealed,
                assignments: assignments,
                observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                blennyBundleIdentifier: blennyBundleIdentifier
            )
        }

        let recoverySteps = [
            "For an enabled proposal, keep the accepted policy file unchanged until the proposed baseline activates.",
            "If activation fails, invalidate the candidate and preserve the previous safe assertion or unrestricted state.",
            "After activation, atomically persist the accepted policy and one 0600 previous-policy backup.",
            "If persistence fails, replace the candidate with the previous baseline; if that replacement fails, invalidate all owned assertions and remain unrestricted.",
            "For a disabled proposal, acquire the current writer, persist disabled intent first, then invalidate all owned assertions; process disconnect remains the final restoration boundary.",
            "Restore Previous Policy reuses the scoped backup without rotating it; repeating the restore is a no-op.",
        ]
        let report = PolicyDryRunImpactReport(
            oldPolicy: oldPolicy,
            proposedPolicy: validation.document,
            rawDraft: draft,
            diff: diff,
            issues: validation.issues,
            oldBaselinePlan: oldBaseline,
            newBaselinePlan: newBaseline,
            newRevealPlan: newReveal,
            approvedBundleIdentifiers: scope.approvedBundleIdentifiers,
            recoverySteps: recoverySteps
        )
        guard let newPolicy = validation.document, report.isApplicable else {
            return (report, nil)
        }
        return (
            report,
            PreparedPolicyEdit(
                oldPolicy: oldPolicy,
                newPolicy: newPolicy,
                report: report,
                persistenceMode: persistenceMode
            )
        )
    }

    private static func assignments(
        from document: PersistentBundlePolicyDocument
    ) throws -> BundlePolicyAssignments {
        try BundlePolicyAssignments(
            pinned: Set(document.policies.filter { $0.policy == .pinned }.map(\.bundleIdentifier)),
            revealable: Set(
                document.policies.filter { $0.policy == .revealable }.map(\.bundleIdentifier)
            ),
            hidden: Set(document.policies.filter { $0.policy == .hidden }.map(\.bundleIdentifier))
        )
    }
}
