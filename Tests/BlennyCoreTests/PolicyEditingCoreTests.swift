import Foundation
import Testing

@testable import BlennyCore

@Suite("Policy editing draft, diff, and dry-run")
struct PolicyEditingCoreTests {
    private let blenny = "xyz.fi5h.blenny"
    private let usage = "xyz.fi5h.Usage4Claude"
    private let cleanShot = "pl.maketheweb.cleanshotx"

    @Test("Draft mutations remain immutably separate from accepted policy")
    func draftIsSeparatedFromAcceptedPolicy() throws {
        let accepted = try document(
            enabled: false,
            revealable: usage,
            hidden: cleanShot
        )
        let originalDraft = BundlePolicyDraft(acceptedPolicy: accepted)
        let edited = originalDraft.assigning(usage, to: .hidden)

        #expect(accepted.policies.first { $0.bundleIdentifier == usage }?.policy == .revealable)
        #expect(originalDraft.revealable == [usage])
        #expect(edited.revealable.isEmpty)
        #expect(edited.hidden.contains(usage))
    }

    @Test("Policy diff is stable for no-op, add, remove, and moves")
    func deterministicDiff() throws {
        let old = try PersistentBundlePolicyDocument(
            managementEnabled: true,
            policies: [
                .init(bundleIdentifier: blenny, policy: .visible),
                .init(bundleIdentifier: usage, policy: .revealable),
                .init(bundleIdentifier: cleanShot, policy: .hidden),
            ]
        )
        let new = try PersistentBundlePolicyDocument(
            managementEnabled: true,
            policies: [
                .init(bundleIdentifier: "com.example.Added", policy: .revealable),
                .init(bundleIdentifier: blenny, policy: .visible),
                .init(bundleIdentifier: usage, policy: .hidden),
            ]
        )

        #expect(BundlePolicyDiff.between(old: old, new: old).isNoOp)
        #expect(BundlePolicyDiff.between(old: old, new: new).changes.map(\.description) == [
            "ADD com.example.Added -> revealable",
            "REMOVE pl.maketheweb.cleanshotx <- hidden",
            "MOVE xyz.fi5h.Usage4Claude revealable -> hidden",
        ])

        let reordered = try PersistentBundlePolicyDocument(
            managementEnabled: true,
            policies: Array(new.policies.reversed())
        )
        #expect(
            BundlePolicyDiff.between(old: old, new: reordered)
                == BundlePolicyDiff.between(old: old, new: new)
        )
    }

    @Test("Resume Managing is an explicit deterministic diff")
    func resumeManagingDiff() throws {
        let disabled = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let enabled = try document(enabled: true, revealable: usage, hidden: cleanShot)

        #expect(BundlePolicyDiff.between(old: disabled, new: enabled).changes.map(\.description) == [
            "MANAGEMENT disabled -> enabled",
        ])
    }

    @Test("Dry-run text is stable and cannot create a writer, factory, or assertion")
    func stableDryRunHasNoMutationObjects() async throws {
        let accepted = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let store = MemoryPolicyStore(document: accepted)
        let provider = WriterProviderProbe()
        let core = PolicyEditingCore(
            store: store,
            blennyBundleIdentifier: blenny,
            scope: approvedScope,
            writerProvider: { try await provider.makeWriter() }
        )
        let draft = BundlePolicyDraft(acceptedPolicy: accepted)
            .assigning(usage, to: .hidden)
            .assigning(cleanShot, to: .revealable)

        let first = try await core.preview(
            draft: draft,
            candidates: inventory(order: [cleanShot, blenny, usage]),
            observedRunningBundleIdentifiers: [usage, blenny, cleanShot]
        )
        let second = try await core.preview(
            draft: draft,
            candidates: inventory(order: [usage, cleanShot, blenny]),
            observedRunningBundleIdentifiers: [cleanShot, usage, blenny]
        )

        #expect(first.0.text == second.0.text)
        #expect(first.0.fingerprint == second.0.fingerprint)
        #expect(first.0.text.contains("MOVE pl.maketheweb.cleanshotx hidden -> revealable"))
        #expect(first.0.text.contains("MOVE xyz.fi5h.Usage4Claude revealable -> hidden"))
        #expect(await provider.creationCount == 0)
        #expect(await provider.assertionCount == 0)
    }

    @Test("Reviewed authorization ignores unrelated running-bundle churn")
    func reviewIgnoresUnrelatedRunningBundles() throws {
        let accepted = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let draft = BundlePolicyDraft(acceptedPolicy: accepted)
        let first = try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: draft,
            managementEnabled: true,
            candidates: inventory(),
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot],
            scope: approvedScope,
            blennyBundleIdentifier: blenny
        )
        let churned = try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: draft,
            managementEnabled: true,
            candidates: inventory(),
            observedRunningBundleIdentifiers: [
                blenny,
                usage,
                cleanShot,
                "com.example.UnrelatedHelper",
            ],
            scope: approvedScope,
            blennyBundleIdentifier: blenny
        )

        #expect(first.report.fingerprint != churned.report.fingerprint)
        #expect(first.prepared?.reviewBinding == churned.prepared?.reviewBinding)
        #expect(
            first.report.newBaselinePlan?.fingerprint
                != churned.report.newBaselinePlan?.fingerprint
        )
    }

    @Test("Draft Apply prepares active management without mutating during preparation")
    func draftApplyStartsManagement() async throws {
        let accepted = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let core = PolicyEditingCore(
            store: MemoryPolicyStore(document: accepted),
            blennyBundleIdentifier: blenny,
            scope: approvedScope,
            writerProvider: { ProbePolicyWriter(probe: WriterProviderProbe()) }
        )
        let preview = try await core.preview(
            draft: BundlePolicyDraft(acceptedPolicy: accepted).assigning(usage, to: .hidden),
            candidates: inventory(),
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot]
        )

        #expect(preview.1?.newPolicy.managementEnabled == true)
        #expect(preview.0.text.contains("REVIEW BINDING"))
        #expect(preview.0.text.contains("RECOVERY PLAN"))
    }

    @Test("Invalid, duplicate, case-conflicting, overlapping, and unknown input fails closed")
    func invalidDraftsFailClosed() throws {
        let old = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let invalid = BundlePolicyDraft(
            visible: [blenny, "not a bundle"],
            revealable: [usage, usage, cleanShot],
            hidden: [usage.uppercased(), "com.example.Unknown"]
        )
        let result = try PolicyDryRunner.prepare(
            oldPolicy: old,
            draft: invalid,
            managementEnabled: false,
            candidates: inventory(),
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot],
            scope: approvedScope,
            blennyBundleIdentifier: blenny
        )

        #expect(result.prepared == nil)
        #expect(!result.report.isApplicable)
        let text = result.report.issues.map(\.description).joined(separator: "\n")
        #expect(text.contains("invalid bundle identifier"))
        #expect(text.contains("duplicate bundle identifier"))
        #expect(text.contains("case-conflicting"))
        #expect(text.contains("overlaps policies"))
        #expect(text.contains("not a current menu-bar ownership candidate"))
        #expect(text.contains("outside the approved validation scope"))
    }

    @Test("Missing approved bundles and missing visible Blenny fail closed")
    func missingAssignmentsFailClosed() throws {
        let old = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let result = try PolicyDryRunner.prepare(
            oldPolicy: old,
            draft: BundlePolicyDraft(visible: [], revealable: [usage], hidden: []),
            managementEnabled: false,
            candidates: inventory(),
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot],
            scope: approvedScope,
            blennyBundleIdentifier: blenny
        )

        #expect(result.prepared == nil)
        #expect(result.report.issues.contains(.missingApprovedBundle(cleanShot)))
        #expect(result.report.issues.contains(.missingApprovedBundle(blenny)))
        #expect(result.report.issues.contains(.missingVisibleBlenny(blenny)))
    }

    @Test("An approved bundle missing from current ownership observation is explicit")
    func missingCurrentOwnershipFailsClosed() throws {
        let old = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let candidates = PolicyCandidateInventory(observations: observations(
            order: [blenny, usage]
        ))
        let result = try PolicyDryRunner.prepare(
            oldPolicy: old,
            draft: BundlePolicyDraft(acceptedPolicy: old),
            managementEnabled: true,
            candidates: candidates,
            observedRunningBundleIdentifiers: [blenny, usage],
            scope: approvedScope,
            blennyBundleIdentifier: blenny
        )

        #expect(result.prepared == nil)
        #expect(result.report.issues.contains(.missingCurrentOwnership(cleanShot)))
    }

    @Test("Unknown ownership and multi-process ambiguity fail closed")
    func ownershipIssuesFailClosed() throws {
        let observations = observations(order: [blenny, usage, cleanShot]) + [
            MenuBarPolicyOwnershipObservation(
                bundleIdentifier: nil,
                processIdentifier: 77,
                menuBarItemCount: 1
            ),
            MenuBarPolicyOwnershipObservation(
                bundleIdentifier: usage,
                processIdentifier: 88,
                menuBarItemCount: 1
            ),
        ]
        let inventory = PolicyCandidateInventory(observations: observations)
        let result = try PolicyDryRunner.prepare(
            oldPolicy: document(enabled: false, revealable: usage, hidden: cleanShot),
            draft: BundlePolicyDraft(
                visible: [blenny],
                revealable: [usage],
                hidden: [cleanShot]
            ),
            managementEnabled: true,
            candidates: inventory,
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot],
            scope: approvedScope,
            blennyBundleIdentifier: blenny
        )

        #expect(result.prepared == nil)
        let issueText = result.report.issues.map(\.description).joined(separator: "\n")
        #expect(issueText.contains("unknown bundle ownership"))
        #expect(issueText.contains("ambiguous owner PIDs [20, 88]"))
    }

    @Test("Blenny stays visible and Hidden stays excluded from ordinary reveal")
    func safetyInvariantsHold() throws {
        let accepted = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let result = try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: BundlePolicyDraft(acceptedPolicy: accepted),
            managementEnabled: true,
            candidates: inventory(),
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot],
            scope: approvedScope,
            blennyBundleIdentifier: blenny
        )
        let baseline = try #require(result.report.newBaselinePlan)
        let revealed = try #require(result.report.newRevealPlan)

        #expect(baseline.allowedBundleIdentifiers.contains(blenny))
        #expect(revealed.allowedBundleIdentifiers.contains(blenny))
        #expect(!baseline.allowedBundleIdentifiers.contains(cleanShot))
        #expect(!revealed.allowedBundleIdentifiers.contains(cleanShot))
        #expect(!baseline.allowedBundleIdentifiers.contains(usage))
        #expect(revealed.allowedBundleIdentifiers.contains(usage))
    }

    @Test("PID replacement preserves policy identity but invalidates Review")
    func pidReplacementInvalidatesReview() throws {
        let accepted = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let first = try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: BundlePolicyDraft(acceptedPolicy: accepted),
            managementEnabled: true,
            candidates: inventory(pids: [10, 20, 30]),
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot],
            scope: approvedScope,
            blennyBundleIdentifier: blenny
        )
        let replacement = try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: BundlePolicyDraft(acceptedPolicy: accepted),
            managementEnabled: true,
            candidates: inventory(pids: [1010, 2020, 3030]),
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot],
            scope: approvedScope,
            blennyBundleIdentifier: blenny
        )

        #expect(first.report.fingerprint != replacement.report.fingerprint)
        #expect(first.prepared?.reviewBinding != replacement.prepared?.reviewBinding)
        #expect(first.prepared?.newPolicy == replacement.prepared?.newPolicy)
    }

    @Test("Candidate generation, validation scope, and observation bind Review")
    func reviewBindingRejectsEveryStaleInput() throws {
        let accepted = try document(enabled: false, revealable: usage, hidden: cleanShot)
        let draft = BundlePolicyDraft(acceptedPolicy: accepted)
        let generation = UUID()
        let first = try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: draft,
            managementEnabled: true,
            candidates: inventory(),
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot],
            scope: approvedScope,
            blennyBundleIdentifier: blenny,
            candidateGeneration: generation,
            runtimeContractFingerprint: "runtime-a"
        )
        let newGeneration = try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: draft,
            managementEnabled: true,
            candidates: inventory(),
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot],
            scope: approvedScope,
            blennyBundleIdentifier: blenny,
            candidateGeneration: UUID(),
            runtimeContractFingerprint: "runtime-a"
        )
        let changedScope = try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: draft,
            managementEnabled: true,
            candidates: inventory(),
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot],
            scope: PolicyValidationScope(
                approvedBundleIdentifiers: [blenny, usage]
            ),
            blennyBundleIdentifier: blenny,
            candidateGeneration: generation,
            runtimeContractFingerprint: "runtime-a"
        )
        let changedRuntime = try PolicyDryRunner.prepare(
            oldPolicy: accepted,
            draft: draft,
            managementEnabled: true,
            candidates: inventory(),
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot],
            scope: approvedScope,
            blennyBundleIdentifier: blenny,
            candidateGeneration: generation,
            runtimeContractFingerprint: "runtime-b"
        )

        #expect(first.prepared?.reviewBinding != newGeneration.prepared?.reviewBinding)
        #expect(first.report.reviewBinding != changedScope.report.reviewBinding)
        #expect(first.prepared?.reviewBinding != changedRuntime.prepared?.reviewBinding)
    }

    @Test("Apple system bundles cannot become mutable targets")
    func appleBundlesStayReadOnly() throws {
        let apple = "com.apple.controlcenter"
        let candidates = PolicyCandidateInventory(
            observations: observations(order: [blenny, usage, cleanShot]) + [
                MenuBarPolicyOwnershipObservation(
                    bundleIdentifier: apple,
                    processIdentifier: 99,
                    menuBarItemCount: 1
                )
            ]
        )
        let result = try PolicyDryRunner.prepare(
            oldPolicy: document(enabled: false, revealable: usage, hidden: cleanShot),
            draft: BundlePolicyDraft(
                visible: [blenny],
                revealable: [usage],
                hidden: [cleanShot, apple]
            ),
            managementEnabled: true,
            candidates: candidates,
            observedRunningBundleIdentifiers: [blenny, usage, cleanShot, apple],
            scope: PolicyValidationScope(
                approvedBundleIdentifiers: [blenny, usage, cleanShot, apple]
            ),
            blennyBundleIdentifier: blenny
        )

        #expect(result.prepared == nil)
        #expect(result.report.issues.contains(.mutableAppleSystemBundle(apple)))
    }

    private var approvedScope: PolicyValidationScope {
        PolicyValidationScope(approvedBundleIdentifiers: [blenny, usage, cleanShot])
    }

    private func document(
        enabled: Bool,
        revealable: String,
        hidden: String
    ) throws -> PersistentBundlePolicyDocument {
        try PersistentBundlePolicyDocument(
            managementEnabled: enabled,
            policies: [
                .init(bundleIdentifier: blenny, policy: .visible),
                .init(bundleIdentifier: revealable, policy: .revealable),
                .init(bundleIdentifier: hidden, policy: .hidden),
            ]
        )
    }

    private func inventory(
        order: [String]? = nil,
        pids: [Int32] = [10, 20, 30]
    ) -> PolicyCandidateInventory {
        PolicyCandidateInventory(
            observations: observations(
                order: order ?? [blenny, usage, cleanShot],
                pids: pids
            )
        )
    }

    private func observations(
        order: [String],
        pids: [Int32] = [10, 20, 30]
    ) -> [MenuBarPolicyOwnershipObservation] {
        let pidByIdentifier = Dictionary(uniqueKeysWithValues: zip(
            [blenny, usage, cleanShot],
            pids
        ))
        return order.map {
            MenuBarPolicyOwnershipObservation(
                bundleIdentifier: $0,
                processIdentifier: pidByIdentifier[$0] ?? -1,
                menuBarItemCount: $0 == usage ? 2 : 1
            )
        }
    }
}

private actor WriterProviderProbe {
    private(set) var creationCount = 0
    private(set) var assertionCount = 0

    func makeWriter() throws -> any PolicyAssertionWriting {
        creationCount += 1
        return ProbePolicyWriter(probe: self)
    }

    func assertionCreated() {
        assertionCount += 1
    }
}

private actor ProbePolicyWriter: PolicyAssertionWriting {
    let probe: WriterProviderProbe

    init(probe: WriterProviderProbe) {
        self.probe = probe
    }

    func applySessionTransition(with plan: RevealAllowlistPlan) async throws {
        await probe.assertionCreated()
    }

    func restoreAndStop() async {}
    func connectionInvalidated() async {}
    func activePlanSnapshot() async -> RevealAllowlistPlan? { nil }
}
