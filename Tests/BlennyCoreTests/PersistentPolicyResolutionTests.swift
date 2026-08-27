import Testing

@testable import BlennyCore

@Suite("Persistent policy identity resolution")
struct PersistentPolicyResolutionTests {
    private let blenny = "com.example.BlennyProbe"
    private let revealable = "xyz.fi5h.Usage4Claude"
    private let hidden = "pl.maketheweb.cleanshotx"
    private let unmanaged = "com.example.Unmanaged"

    @Test("Relaunch and update-like PID replacement preserve bundle policy")
    func relaunchAndReplacementPreserveIdentity() throws {
        let document = try makeDocument()
        let first = try resolve(
            document: document,
            revealablePID: 101,
            hiddenPID: 201
        )
        let replacement = try resolve(
            document: document,
            revealablePID: 9101,
            hiddenPID: 9201
        )

        #expect(first.assignments == replacement.assignments)
        #expect(first.managedProcessIdentifiers[revealable] == 101)
        #expect(replacement.managedProcessIdentifiers[revealable] == 9101)

        let baseline = try RevealAllowlistPlanner.plan(
            presentation: .baseline,
            assignments: replacement.assignments,
            observedRunningBundleIdentifiers: replacement.observedRunningBundleIdentifiers,
            blennyBundleIdentifier: blenny
        )
        let revealed = try RevealAllowlistPlanner.plan(
            presentation: .revealed,
            assignments: replacement.assignments,
            observedRunningBundleIdentifiers: replacement.observedRunningBundleIdentifiers,
            blennyBundleIdentifier: blenny
        )
        #expect(!baseline.allowedBundleIdentifiers.contains(revealable))
        #expect(!baseline.allowedBundleIdentifiers.contains(hidden))
        #expect(revealed.allowedBundleIdentifiers.contains(revealable))
        #expect(!revealed.allowedBundleIdentifiers.contains(hidden))
    }

    @Test("Multiple status items from one owner remain one bundle policy")
    func multipleItemsOneOwnerAreValid() throws {
        let resolution = try PersistentPolicyResolver.resolve(
            document: makeDocument(),
            ownershipObservations: [
                observation(blenny, pid: 1),
                observation(revealable, pid: 2, itemCount: 3),
                observation(hidden, pid: 3, itemCount: 2),
            ],
            observedRunningBundleIdentifiers: [blenny, revealable, hidden],
            blennyBundleIdentifier: blenny
        )
        #expect(resolution.assignments.revealable == [revealable])
        #expect(resolution.assignments.hidden == [hidden])
    }

    @Test("Unknown configured bundles are reported and fail closed")
    func missingConfiguredBundleFailsClosed() throws {
        #expect(
            throws: PersistentPolicyResolverError.unresolved([
                .configuredBundleNotObserved(hidden),
            ])
        ) {
            _ = try PersistentPolicyResolver.resolve(
                document: makeDocument(),
                ownershipObservations: [
                    observation(blenny, pid: 1),
                    observation(revealable, pid: 2),
                ],
                observedRunningBundleIdentifiers: [blenny, revealable],
                blennyBundleIdentifier: blenny
            )
        }
    }

    @Test("Ambiguous configured bundle ownership is reported and fails closed")
    func ambiguousConfiguredBundleFailsClosed() throws {
        #expect(
            throws: PersistentPolicyResolverError.unresolved([
                .ambiguousConfiguredBundle(
                    bundleIdentifier: revealable,
                    processIdentifiers: [2, 4]
                ),
            ])
        ) {
            _ = try PersistentPolicyResolver.resolve(
                document: makeDocument(),
                ownershipObservations: [
                    observation(blenny, pid: 1),
                    observation(revealable, pid: 2),
                    observation(revealable, pid: 4),
                    observation(hidden, pid: 3),
                ],
                observedRunningBundleIdentifiers: [blenny, revealable, hidden],
                blennyBundleIdentifier: blenny
            )
        }
    }

    @Test("Unidentified menu-bar owners are reported and fail closed")
    func unknownOwnerFailsClosed() throws {
        #expect(
            throws: PersistentPolicyResolverError.unresolved([
                .unknownMenuBarOwner(processIdentifier: 99),
            ])
        ) {
            _ = try PersistentPolicyResolver.resolve(
                document: makeDocument(),
                ownershipObservations: [
                    observation(blenny, pid: 1),
                    observation(revealable, pid: 2),
                    observation(hidden, pid: 3),
                    MenuBarPolicyOwnershipObservation(
                        bundleIdentifier: nil,
                        processIdentifier: 99,
                        menuBarItemCount: 1
                    ),
                ],
                observedRunningBundleIdentifiers: [blenny, revealable, hidden],
                blennyBundleIdentifier: blenny
            )
        }
    }

    @Test("Disabled management remains persistent but cannot be applied")
    func disabledDocumentRetainsIntent() throws {
        let enabled = try makeDocument()
        let disabled = try enabled.settingManagementEnabled(false)
        #expect(!disabled.managementEnabled)
        #expect(disabled.policies == enabled.policies)
    }

    @Test("Ownership scan timeout has an explicit report")
    func ownershipScanTimeoutIsExplicit() {
        #expect(
            PersistentPolicyResolutionIssue.ownershipScanTimedOut.description
                == "bounded menu-bar ownership scan timed out"
        )
    }

    private func resolve(
        document: PersistentBundlePolicyDocument,
        revealablePID: Int32,
        hiddenPID: Int32
    ) throws -> ResolvedPersistentPolicy {
        try PersistentPolicyResolver.resolve(
            document: document,
            ownershipObservations: [
                observation(blenny, pid: 1),
                observation(revealable, pid: revealablePID),
                observation(hidden, pid: hiddenPID),
                observation(unmanaged, pid: 301),
            ],
            observedRunningBundleIdentifiers: [blenny, revealable, hidden, unmanaged],
            blennyBundleIdentifier: blenny
        )
    }

    private func makeDocument() throws -> PersistentBundlePolicyDocument {
        try PersistentBundlePolicyDocument(
            managementEnabled: true,
            policies: [
                .init(bundleIdentifier: blenny, policy: .visible),
                .init(bundleIdentifier: revealable, policy: .revealable),
                .init(bundleIdentifier: hidden, policy: .hidden),
            ]
        )
    }

    private func observation(
        _ bundleIdentifier: String,
        pid: Int32,
        itemCount: Int = 1
    ) -> MenuBarPolicyOwnershipObservation {
        MenuBarPolicyOwnershipObservation(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: pid,
            menuBarItemCount: itemCount
        )
    }
}
