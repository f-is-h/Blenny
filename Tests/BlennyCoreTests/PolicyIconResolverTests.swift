import Foundation
import Testing
@testable import BlennyCore

@Suite("Icon-first policy presentation")
struct PolicyIconResolverTests {
    @Test("Installed application eligibility selects an application icon or the shared fallback")
    func applicationSourceSelection() {
        #expect(
            PolicyIconResolver.applicationDescriptor(
                bundleIdentifier: "com.example.Resolved",
                installedApplicationResolved: true
            ) == .installedApplication
        )
        #expect(
            PolicyIconResolver.applicationDescriptor(
                bundleIdentifier: "com.example.Missing",
                installedApplicationResolved: false
            ) == .fallback
        )
        #expect(
            PolicyIconResolver.applicationDescriptor(
                bundleIdentifier: "not a bundle identifier",
                installedApplicationResolved: true
            ) == .fallback
        )
        #expect(PolicyIconDescriptor.fallback.symbolName == "questionmark.square.dashed")

        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        #expect(
            PolicyIconResolver.applicationDescriptor(
                bundleIdentifier: "com.apple.weather.menu",
                installedApplicationResolved: true
            ) == .systemSymbol(name: "cloud.sun")
        )
        #expect(
            PolicyIconResolver.applicationDescriptor(
                bundleIdentifier: "com.apple.TextInputMenuAgent",
                installedApplicationResolved: false
            ) == .systemSymbol(name: "keyboard")
        )
        #expect(ExperimentalAppleBundlePolicyCatalog.displayName(
            for: "COM.APPLE.WEATHER.MENU"
        ) == "Weather")
        #expect(ExperimentalAppleBundlePolicyCatalog.displayName(
            for: "com.apple.TextInputMenuAgent"
        ) == "Input Menu")
        #else
        #expect(ExperimentalAppleBundlePolicyCatalog.displayName(
            for: "com.apple.weather.menu"
        ) == nil)
        #endif
    }

    @Test("Known system observation identities map to semantic SF Symbols")
    func knownSystemSymbols() {
        let expected = [
            "com.apple.menuextra.clock": "clock",
            "com.apple.menuextra.controlcenter": "switch.2",
            "com.apple.menuextra.now-playing": "play.circle",
            "com.apple.menuextra.sound": "speaker.wave.2",
            "com.apple.menuextra.wifi": "wifi",
            "com.apple.menuextra.siri": "siri",
        ]

        #expect(
            PolicyIconResolver.systemItemDescriptor(
                observationIdentifier: "COM.APPLE.MENUEXTRA.BLUETOOTH"
            ) == .namedImage(name: "NSBluetoothTemplate")
        )

        for (identifier, symbolName) in expected {
            #expect(
                PolicyIconResolver.systemItemDescriptor(
                    observationIdentifier: identifier.uppercased()
                ) == .systemSymbol(name: symbolName)
            )
        }

        let stableSiriIdentity = MenuBarItemIdentity(
            ownerBundleIdentifier: "com.apple.systemuiserver",
            accessibilityIdentifier: nil,
            semanticLabel: "siri",
            role: "axmenubaritem",
            subrole: "axmenuextra",
            instanceOrdinal: 0,
            confidence: .moderate
        )
        #expect(
            PolicyIconResolver.systemItemDescriptor(
                observationIdentifier: stableSiriIdentity.stableKey
            ) == .systemSymbol(name: "siri")
        )
        let stableInputSourceIdentity = MenuBarItemIdentity(
            ownerBundleIdentifier: "com.apple.textinputmenuagent",
            accessibilityIdentifier: nil,
            semanticLabel: "简体五笔",
            role: "axmenubaritem",
            subrole: "axmenuextra",
            instanceOrdinal: 0,
            confidence: .moderate
        )
        #expect(
            PolicyIconResolver.systemItemDescriptor(
                observationIdentifier: stableInputSourceIdentity.stableKey
            ) == .systemSymbol(name: "keyboard")
        )
    }

    @Test("Unknown application and system items use one honest fallback")
    func sharedFallback() {
        let application = PolicyIconResolver.applicationDescriptor(
            bundleIdentifier: "com.example.Missing",
            installedApplicationResolved: false
        )
        let system = PolicyIconResolver.systemItemDescriptor(
            observationIdentifier: "com.apple.menuextra.future-item"
        )

        #expect(application == .fallback)
        #expect(system == .fallback)
        #expect(application.symbolName == system.symbolName)
        #expect(application.usesFallback)
        #expect(system.usesFallback)
    }

    @Test("Candidate ordering and duplicate observations do not change icon selection")
    func refreshOrderingStability() {
        let observations = [
            MenuBarPolicyOwnershipObservation(
                bundleIdentifier: "com.example.First",
                processIdentifier: 10,
                menuBarItemCount: 1
            ),
            MenuBarPolicyOwnershipObservation(
                bundleIdentifier: "com.example.First",
                processIdentifier: 10,
                menuBarItemCount: 1
            ),
            MenuBarPolicyOwnershipObservation(
                bundleIdentifier: "com.example.Second",
                processIdentifier: 30,
                menuBarItemCount: 1
            ),
        ]
        let forwardInventory = PolicyCandidateInventory(observations: observations)
        let reversedInventory = PolicyCandidateInventory(
            observations: Array(observations.reversed())
        )
        let first = forwardInventory.candidates[0]
        let second = forwardInventory.candidates[1]
        let resolved = Set(["COM.EXAMPLE.FIRST"])

        let forward = PolicyIconResolver.applicationDescriptors(
            candidates: forwardInventory.candidates,
            resolvedBundleIdentifiers: resolved
        )
        let reversed = PolicyIconResolver.applicationDescriptors(
            candidates: reversedInventory.candidates,
            resolvedBundleIdentifiers: resolved
        )

        #expect(forward == reversed)
        #expect(forwardInventory.candidates.count == 2)
        #expect(forward[first.bundleIdentifier] == .installedApplication)
        #expect(forward[second.bundleIdentifier] == .fallback)
        #expect(first.processIdentifiers == [10])
        #expect(first.menuBarItemCount == 2)
    }

    @Test("Icon resolution cannot alter persistence, draft, diff, report, or fingerprints")
    func iconResolutionIsPresentationOnly() throws {
        let blenny = "xyz.fi5h.blenny"
        let revealable = "com.example.Revealable"
        let hidden = "com.example.Hidden"
        let document = try PersistentBundlePolicyDocument(
            managementEnabled: false,
            policies: [
                .init(bundleIdentifier: blenny, policy: .visible),
                .init(bundleIdentifier: revealable, policy: .revealable),
                .init(bundleIdentifier: hidden, policy: .hidden),
            ]
        )
        let draft = BundlePolicyDraft(acceptedPolicy: document)
        let assignments = try BundlePolicyAssignments(
            visible: [blenny],
            revealable: [revealable],
            hidden: [hidden]
        )
        let baseline = try RevealAllowlistPlanner.plan(
            presentation: .baseline,
            assignments: assignments,
            observedRunningBundleIdentifiers: [blenny, revealable, hidden],
            blennyBundleIdentifier: blenny
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encodedBefore = try encoder.encode(document)
        let fingerprintBefore = baseline.managedPolicyFingerprint(assignments: assignments)
        let inventory = PolicyCandidateInventory(
            observations: [blenny, revealable, hidden].enumerated().map { offset, identifier in
                MenuBarPolicyOwnershipObservation(
                    bundleIdentifier: identifier,
                    processIdentifier: Int32(offset + 1),
                    menuBarItemCount: 1
                )
            }
        )
        let scope = PolicyValidationScope(
            approvedBundleIdentifiers: [blenny, revealable, hidden]
        )
        let dryRunBefore = try PolicyDryRunner.prepare(
            oldPolicy: document,
            draft: draft,
            managementEnabled: false,
            candidates: inventory,
            observedRunningBundleIdentifiers: [blenny, revealable, hidden],
            scope: scope,
            blennyBundleIdentifier: blenny
        )

        _ = PolicyIconResolver.applicationDescriptor(
            bundleIdentifier: revealable,
            installedApplicationResolved: true
        )
        _ = PolicyIconResolver.systemItemDescriptor(
            observationIdentifier: "com.apple.menuextra.wifi"
        )

        #expect(try encoder.encode(document) == encodedBefore)
        #expect(BundlePolicyDraft(acceptedPolicy: document) == draft)
        #expect(baseline.managedPolicyFingerprint(assignments: assignments) == fingerprintBefore)
        let dryRunAfter = try PolicyDryRunner.prepare(
            oldPolicy: document,
            draft: draft,
            managementEnabled: false,
            candidates: inventory,
            observedRunningBundleIdentifiers: [blenny, revealable, hidden],
            scope: scope,
            blennyBundleIdentifier: blenny
        )
        #expect(dryRunAfter.report.diff == dryRunBefore.report.diff)
        #expect(dryRunAfter.report.text == dryRunBefore.report.text)
        #expect(dryRunAfter.report.fingerprint == dryRunBefore.report.fingerprint)
    }
}
