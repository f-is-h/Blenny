import CryptoKit
import Foundation

private enum PolicyFingerprint {
    static func sha256(_ lines: [String]) -> String {
        SHA256.hash(data: Data(lines.joined(separator: "\n").utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private extension Array where Element == String {
    func sortedByBundleIdentifier() -> [String] {
        sorted { ($0.lowercased(), $0) < ($1.lowercased(), $1) }
    }
}

public struct BundlePolicyDraft: Equatable, Sendable {
    public let visible: [String]
    public let revealable: [String]
    public let hidden: [String]

    public init(
        visible: [String],
        revealable: [String],
        hidden: [String]
    ) {
        self.visible = visible
        self.revealable = revealable
        self.hidden = hidden
    }

    public init(acceptedPolicy: PersistentBundlePolicyDocument) {
        self.init(
            visible: acceptedPolicy.policies
                .filter { $0.policy == .visible }
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

        var visible = removingMatch(from: self.visible)
        var revealable = removingMatch(from: self.revealable)
        var hidden = removingMatch(from: self.hidden)
        switch policy {
        case .visible:
            visible.append(bundleIdentifier)
        case .revealable:
            revealable.append(bundleIdentifier)
        case .hidden:
            hidden.append(bundleIdentifier)
        }
        return Self(visible: visible, revealable: revealable, hidden: hidden)
    }

    public var fingerprint: String {
        PolicyFingerprint.sha256([
            "visible=\(visible.sortedByBundleIdentifier().joined(separator: ","))",
            "revealable=\(revealable.sortedByBundleIdentifier().joined(separator: ","))",
            "hidden=\(hidden.sortedByBundleIdentifier().joined(separator: ","))",
        ])
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

    public var fingerprint: String {
        PolicyFingerprint.sha256(
            candidates.map {
                "candidate=\($0.bundleIdentifier)|pids=\($0.processIdentifiers.map(String.init).joined(separator: ","))|items=\($0.menuBarItemCount)"
            } + issues.map { "issue=\($0.description)" }
        )
    }

    public func fingerprint(
        for authorizedBundleIdentifiers: [String]
    ) -> String {
        let authorized = Set(
            authorizedBundleIdentifiers.compactMap(BundlePolicyIdentity.canonicalKey)
        )
        let lines = candidates
            .filter { candidate in
                BundlePolicyIdentity.canonicalKey(for: candidate.bundleIdentifier)
                    .map(authorized.contains) == true
            }
            .map {
                "candidate=\($0.bundleIdentifier)|pids=\($0.processIdentifiers.map(String.init).joined(separator: ","))|items=\($0.menuBarItemCount)"
            }
        return PolicyFingerprint.sha256(lines)
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

    public var fingerprint: String {
        PolicyFingerprint.sha256(
            approvedBundleIdentifiers.map { "approved=\($0.lowercased())" }
        )
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
    case mutableAppleSystemBundle(String)
    case missingVisibleBlenny(String)
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
        case let .mutableAppleSystemBundle(bundleIdentifier):
            return "Apple system bundle \(bundleIdentifier) is read-only and cannot be managed"
        case let .missingVisibleBlenny(bundleIdentifier):
            return "Blenny bundle \(bundleIdentifier) must remain visible"
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
            (.visible, draft.visible),
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
        for canonical in occurrences.keys.sorted() where canonical.hasPrefix("com.apple.") {
            let spelling = occurrences[canonical]?.map(\.spelling).sorted().first ?? canonical
            issues.append(.mutableAppleSystemBundle(spelling))
        }

        if let blennyCanonical = BundlePolicyIdentity.canonicalKey(
            for: blennyBundleIdentifier
        ) {
            let visibleCanonicals = Set(draft.visible.compactMap(BundlePolicyIdentity.canonicalKey))
            if !visibleCanonicals.contains(blennyCanonical) {
                issues.append(.missingVisibleBlenny(blennyBundleIdentifier))
            }
        } else {
            issues.append(
                .invalidBundleIdentifier(policy: .visible, value: blennyBundleIdentifier)
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
                issues: [.missingVisibleBlenny(blennyBundleIdentifier)]
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
    /// An unchanged accepted policy still needs activation after failed startup.
    case resumeManagement
}

public extension PersistentBundlePolicyDocument {
    var policyFingerprint: String {
        PolicyFingerprint.sha256(
            [
                "schema=\(schemaVersion)",
                "managementEnabled=\(managementEnabled)",
            ] + policies.map {
                "policy=\($0.bundleIdentifier.lowercased())|\($0.policy.rawValue)"
            }
        )
    }
}

public struct PolicyReviewBinding: Equatable, Sendable {
    public static let unversionedCandidateGeneration = UUID(
        uuidString: "00000000-0000-0000-0000-000000000000"
    )!

    public let acceptedPolicyFingerprint: String
    public let draftFingerprint: String
    public let candidateGeneration: UUID
    public let candidateInventoryFingerprint: String
    public let validationScopeFingerprint: String
    public let observationFingerprint: String
    public let runtimeContractFingerprint: String
    public let recoveryBackupFingerprint: String?
    public let baselinePlanFingerprint: String?
    public let ordinaryRevealPlanFingerprint: String?
    public let authorizedBundleIdentifiers: [String]

    public var fingerprint: String {
        PolicyFingerprint.sha256([
            "accepted=\(acceptedPolicyFingerprint)",
            "draft=\(draftFingerprint)",
            "candidateGeneration=\(candidateGeneration.uuidString.lowercased())",
            "inventory=\(candidateInventoryFingerprint)",
            "scope=\(validationScopeFingerprint)",
            "observation=\(observationFingerprint)",
            "runtime=\(runtimeContractFingerprint)",
            "backup=\(recoveryBackupFingerprint ?? "none")",
            "baseline=\(baselinePlanFingerprint ?? "unavailable")",
            "reveal=\(ordinaryRevealPlanFingerprint ?? "unavailable")",
            "authorized=\(authorizedBundleIdentifiers.joined(separator: ","))",
        ])
    }

    public static func make(
        acceptedPolicy: PersistentBundlePolicyDocument,
        draft: BundlePolicyDraft,
        candidateGeneration: UUID,
        candidates: PolicyCandidateInventory,
        scope: PolicyValidationScope,
        observedRunningBundleIdentifiers: Set<String>,
        runtimeContractFingerprint: String,
        recoveryBackupFingerprint: String?,
        baselinePlan: RevealAllowlistPlan?,
        ordinaryRevealPlan: RevealAllowlistPlan?
    ) -> Self {
        let authorizedBundleIdentifiers = scope.approvedBundleIdentifiers
            .sortedByBundleIdentifier()
        let authorizedCanonicalIdentifiers = Set(
            authorizedBundleIdentifiers.compactMap(BundlePolicyIdentity.canonicalKey)
        )
        return Self(
            acceptedPolicyFingerprint: acceptedPolicy.policyFingerprint,
            draftFingerprint: draft.fingerprint,
            candidateGeneration: candidateGeneration,
            candidateInventoryFingerprint: candidates.fingerprint(
                for: authorizedBundleIdentifiers
            ),
            validationScopeFingerprint: scope.fingerprint,
            observationFingerprint: PolicyFingerprint.sha256(
                observedRunningBundleIdentifiers
                    .filter {
                        BundlePolicyIdentity.canonicalKey(for: $0)
                            .map(authorizedCanonicalIdentifiers.contains) == true
                    }
                    .map { "running=\($0.lowercased())" }
                    .sorted()
            ),
            runtimeContractFingerprint: runtimeContractFingerprint,
            recoveryBackupFingerprint: recoveryBackupFingerprint,
            baselinePlanFingerprint: baselinePlan?.authorizationFingerprint(
                for: authorizedBundleIdentifiers
            ),
            ordinaryRevealPlanFingerprint: ordinaryRevealPlan?.authorizationFingerprint(
                for: authorizedBundleIdentifiers
            ),
            authorizedBundleIdentifiers: authorizedBundleIdentifiers
        )
    }
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
    public let reviewBinding: PolicyReviewBinding
    public let recoverySteps: [String]

    public var isApplicable: Bool {
        proposedPolicy != nil && issues.isEmpty && newBaselinePlan != nil && newRevealPlan != nil
    }

    public var text: String {
        var lines: [String] = [
            "Blenny Reviewed Management Loop technical dry-run report",
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
        lines.append("EXACT BASELINE ALLOWED BUNDLES")
        lines.append(contentsOf: Self.allowedBundleLines(newBaselinePlan))
        lines.append("ORDINARY REVEAL IMPACT")
        lines.append(
            Self.planLine(
                newRevealPlan,
                policy: proposedPolicy,
                approvedBundleIdentifiers: approvedBundleIdentifiers
            )
        )
        lines.append("EXACT ORDINARY REVEAL ALLOWED BUNDLES")
        lines.append(contentsOf: Self.allowedBundleLines(newRevealPlan))
        lines.append("HIDDEN EXCLUSION")
        if let proposedPolicy {
            let hidden = proposedPolicy.policies
                .filter { $0.policy == .hidden }
                .map(\.bundleIdentifier)
                .sorted { $0.lowercased() < $1.lowercased() }
            lines.append(contentsOf: hidden.isEmpty ? ["- none"] : hidden.map { "- \($0): excluded from baseline and ordinary reveal" })
        } else {
            lines.append("- unavailable")
        }
        lines.append("APPROVED BUNDLES")
        lines.append(contentsOf: approvedBundleIdentifiers.map { "- \($0)" })
        lines.append("REVIEW BINDING")
        lines.append("- review=\(reviewBinding.fingerprint)")
        lines.append("- accepted=\(reviewBinding.acceptedPolicyFingerprint)")
        lines.append("- draft=\(reviewBinding.draftFingerprint)")
        lines.append("- candidateGeneration=\(reviewBinding.candidateGeneration.uuidString.lowercased())")
        lines.append("- inventory=\(reviewBinding.candidateInventoryFingerprint)")
        lines.append("- validationScope=\(reviewBinding.validationScopeFingerprint)")
        lines.append("- observation=\(reviewBinding.observationFingerprint)")
        lines.append("- runtime=\(reviewBinding.runtimeContractFingerprint)")
        lines.append("VALIDATION")
        lines.append(contentsOf: issues.isEmpty ? ["PASS"] : issues.map { "FAIL: \($0)" })
        lines.append("TRANSACTION")
        lines.append("- writer: one serialized exact allow-list replacement")
        lines.append("- assertion replacement: activate reviewed baseline, then verify once")
        lines.append("- failed write: verify prior state once; retry the exact write at most once")
        lines.append("- persistence: commit accepted policy only after activation verification")
        lines.append("- unchanged Resume: activate and verify only if inactive; no policy save or backup rotation; failure restores unrestricted state")
        lines.append("- backup: scoped atomic 0600 previous policy; no no-op rotation")
        lines.append("- rollback: replace and verify previous baseline, otherwise invalidate and fail closed")
        lines.append("- Stop: reviewed disabled commit followed by owned-assertion cleanup")
        lines.append("- restoration: reviewed scoped backup restore; repeated restore is idempotent")
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
            "visible=\(draft.visible.joined(separator: ","))",
            "revealable=\(draft.revealable.joined(separator: ","))",
            "hidden=\(draft.hidden.joined(separator: ","))",
        ]
    }

    private static func allowedBundleLines(
        _ plan: RevealAllowlistPlan?
    ) -> [String] {
        guard let plan else { return ["- unavailable"] }
        let identifiers = plan.allowedBundleIdentifiers
            .sorted { $0.lowercased() < $1.lowercased() }
        return identifiers.isEmpty ? ["- none"] : identifiers.map { "- \($0)" }
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
            visible: Set(policy.policies.filter { $0.policy == .visible }.map(\.bundleIdentifier)),
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

public extension PolicyDryRunImpactReport {
    var validationFailureSummary: String {
        let missing = Set(issues.compactMap { issue -> String? in
            switch issue {
            case let .unknownBundleIdentifier(identifier), let .missingCurrentOwnership(identifier):
                identifier
            default:
                nil
            }
        }).sorted()
        if !missing.isEmpty {
            return "Open the managed app(s) \(missing.joined(separator: ", ")) with their menu-bar items, then choose Resume."
        }
        let detail = issues.map(\.description).joined(separator: "; ")
        return detail.isEmpty ? "No safe baseline is available. Refresh and try again." : detail
    }
}

public struct PreparedPolicyEdit: Equatable, Sendable {
    public let reviewIdentifier: UUID
    public let oldPolicy: PersistentBundlePolicyDocument
    public let newPolicy: PersistentBundlePolicyDocument
    public let report: PolicyDryRunImpactReport
    public let persistenceMode: PolicyEditPersistenceMode

    public var reviewBinding: PolicyReviewBinding { report.reviewBinding }
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
        persistenceMode: PolicyEditPersistenceMode = .saveAcceptedPolicy,
        candidateGeneration: UUID = PolicyReviewBinding.unversionedCandidateGeneration,
        runtimeContractFingerprint: String = "deterministic-core",
        recoveryBackupFingerprint: String? = nil,
        reviewIdentifier: UUID = UUID()
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
            "After activation, atomically persist changed accepted policy and one 0600 previous-policy backup. Unchanged Resume does not save or rotate either file.",
            "If persistence fails, replace the candidate with the previous baseline; if that replacement fails, invalidate all owned assertions and remain unrestricted.",
            "For a disabled proposal, acquire the current writer, persist disabled intent first, then invalidate all owned assertions; process disconnect remains the final restoration boundary.",
            "Restore Previous Policy reuses the scoped backup without rotating it; repeating the restore is a no-op.",
        ]
        let reviewBinding = PolicyReviewBinding.make(
            acceptedPolicy: oldPolicy,
            draft: draft,
            candidateGeneration: candidateGeneration,
            candidates: candidates,
            scope: scope,
            observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
            runtimeContractFingerprint: runtimeContractFingerprint,
            recoveryBackupFingerprint: recoveryBackupFingerprint,
            baselinePlan: newBaseline,
            ordinaryRevealPlan: newReveal
        )
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
            reviewBinding: reviewBinding,
            recoverySteps: recoverySteps
        )
        guard let newPolicy = validation.document, report.isApplicable else {
            return (report, nil)
        }
        return (
            report,
            PreparedPolicyEdit(
                reviewIdentifier: reviewIdentifier,
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
            visible: Set(document.policies.filter { $0.policy == .visible }.map(\.bundleIdentifier)),
            revealable: Set(
                document.policies.filter { $0.policy == .revealable }.map(\.bundleIdentifier)
            ),
            hidden: Set(document.policies.filter { $0.policy == .hidden }.map(\.bundleIdentifier))
        )
    }
}
