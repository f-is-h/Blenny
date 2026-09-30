#if BLENNY_PRODUCT || DEBUG
import Foundation
import Testing
@testable import BlennyCore

@Suite("Configuration-first ordering model")
struct OrderingConfigurationModelTests {
    private let now = Date(timeIntervalSince1970: 12_000)
    private let alpha = OrderingProcess(
        bundleIdentifier: "example.alpha", executableName: "Alpha", pid: 301,
        launchTime: Date(timeIntervalSince1970: 10_000), isSystem: false
    )
    private let beta = OrderingProcess(
        bundleIdentifier: "example.beta", executableName: "Beta", pid: 302,
        launchTime: Date(timeIntervalSince1970: 10_100), isSystem: false
    )

    @Test func foldedOwnersWithoutGeometryOrAutosavesHaveConfigurationIdentity() throws {
        let snapshot = try fixture()
        let candidates = try OrderingConfigurationIdentityResolver.resolve(snapshot: snapshot)
        #expect(candidates.count == 2)
        #expect(candidates.allSatisfy { $0.eligible })
        let plan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: snapshot, orderedBundleIdentifiers: ["example.beta", "example.alpha"], now: now
        )
        #expect(plan.schemaVersion == 3)
        #expect(plan.physicalVerificationStatus(in: snapshot) == .unavailable)
        #expect(plan.configurationAfterValues?["status:Beta::Item-0"] == .integer(900))
    }

    @Test func everyAssociatedKeyMovesAsOneInternallyOrderedOwnerBlock() throws {
        let plan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: fixture(), orderedBundleIdentifiers: ["example.beta", "example.alpha"], now: now
        )
        let owners = try #require(plan.configurationTargets)
        #expect(owners.map(\.bundleIdentifier) == ["example.beta", "example.alpha"])
        #expect(owners[1].keys.map(\.persistentIdentifier) == ["Pinned", "Item-0"])
        #expect(owners[1].keys.map(\.after) == [.integer(500), .integer(100)])
        let group = try plan.applying(to: plan.baseline.group)
        #expect(group["OtherSetting"] == .bool(true))
        #expect(try plan.restoring(current: group) == plan.baseline.group)
        #expect(try JSONDecoder().decode(OrderingPlan.self, from: JSONEncoder().encode(plan)) == plan)
    }

    @Test func overlappingProxyFramesRemainEligibleButVisuallyUnverified() throws {
        let proxy = RectSnapshot(x: 100, y: 0, width: 30, height: 24)
        let snapshot = try fixture(frames: [proxy])
        #expect(try OrderingConfigurationIdentityResolver.resolve(snapshot: snapshot).allSatisfy { $0.eligible })
        let plan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: snapshot, orderedBundleIdentifiers: ["example.beta", "example.alpha"], now: now
        )
        #expect(plan.physicalVerificationStatus(in: snapshot) == .unavailable)
    }

    @Test func configurationFreshnessIgnoresDrawingButNotPreferenceChanges() throws {
        let snapshot = try fixture()
        let plan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: snapshot, orderedBundleIdentifiers: ["example.beta", "example.alpha"], now: now
        )
        try plan.validateFresh(equivalentTo: fixture(
            frames: [RectSnapshot(x: 300, y: 0, width: 100, height: 24)]
        ), now: now)
        #expect(!plan.isFresh(equivalentTo: try fixture(saved: ["NewRecord": .integer(12)]), now: now))
        #expect(!plan.isFresh(equivalentTo: try fixture(lifecycle: 8), now: now))
    }

    @Test func configurationFreshnessIgnoresUnrelatedInventoryAndConfigurationChurn() throws {
        let snapshot = try fixture()
        let plan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: snapshot, orderedBundleIdentifiers: ["example.beta", "example.alpha"], now: now
        )
        let unrelated = OrderingProcess(
            bundleIdentifier: "example.unrelated", executableName: "Unrelated", pid: 399,
            launchTime: Date(timeIntervalSince1970: 10_300), isSystem: false
        )
        let current = try fixture(
            extraProcess: unrelated,
            table: [
                "status:example.alpha::Pinned": .integer(900),
                "status:example.alpha::Item-0": .integer(100),
                "status:Beta::Item-0": .integer(500),
                "status:Unrelated::Item-0": .integer(50),
            ],
            allowedBundleIdentifiers: ["example.alpha", "example.beta", "example.unrelated"],
            otherSetting: .string("changed independently")
        )

        try plan.validateFresh(equivalentTo: current, now: now)
        let proposed = try plan.applying(to: current.group)
        #expect(proposed["OtherSetting"] == .string("changed independently"))
        guard case let .dictionary(table)? = proposed[OrderingSnapshot.tableKey] else {
            Issue.record("Missing proposed configuration table.")
            return
        }
        #expect(table["status:Unrelated::Item-0"] == .integer(50))
    }

    @Test func configurationFreshnessStillRejectsEverySelectedOwnerBindingChange() throws {
        let plan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: fixture(), orderedBundleIdentifiers: ["example.beta", "example.alpha"], now: now
        )
        let collision = OrderingProcess(
            bundleIdentifier: "example.other", executableName: "Beta", pid: 303,
            launchTime: Date(timeIntervalSince1970: 10_200), isSystem: false
        )
        #expect(!plan.isFresh(equivalentTo: try fixture(extraProcess: collision), now: now))
        #expect(!plan.isFresh(equivalentTo: try fixture(table: [
            "status:example.alpha::Pinned": .integer(900),
            "status:example.alpha::Item-0": .integer(100),
            "status:example.alpha::New": .integer(80),
            "status:Beta::Item-0": .integer(500),
        ]), now: now))
        #expect(!plan.isFresh(equivalentTo: try fixture(table: [
            "status:example.alpha::Pinned": .integer(901),
            "status:example.alpha::Item-0": .integer(100),
            "status:Beta::Item-0": .integer(500),
        ]), now: now))
    }

    @Test func executableCollisionDoesNotSilentlyPreferBundleIdentity() throws {
        let collision = OrderingProcess(
            bundleIdentifier: "example.other", executableName: "Beta", pid: 303,
            launchTime: Date(timeIntervalSince1970: 10_200), isSystem: false
        )
        let candidate = try #require(try OrderingConfigurationIdentityResolver.resolve(
            snapshot: fixture(extraProcess: collision)
        ).first { $0.bundleIdentifier == "example.beta" })
        #expect(!candidate.eligible)
        #expect(candidate.reasons.contains(.ownerTokenCollision))
    }

    @Test func incompletePreferenceReadStillCannotAuthorizeAWrite() throws {
        let candidates = try OrderingConfigurationIdentityResolver.resolve(
            snapshot: fixture(preferencesComplete: false, useCodeIdentity: true)
        )
        #expect(candidates.first { $0.bundleIdentifier == "example.alpha" }?.eligible == true)
        let executableMapped = try #require(candidates.first {
            $0.bundleIdentifier == "example.beta"
        })
        #expect(!executableMapped.eligible)
        #expect(executableMapped.reasons.contains(.ownerPreferencesIncomplete))
    }

    @Test func exactBundleKeysUsePublicCodeIdentityWithoutOwnerPreferences() throws {
        let exactTable: [String: OrderingValue] = [
            "status:example.alpha::Pinned": .integer(900),
            "status:example.alpha::Item-0": .integer(100),
            "status:example.beta::Item-0": .integer(500),
        ]
        let snapshot = try fixture(
            saved: ["unavailable-owner-data": .integer(77)],
            preferencesComplete: false, table: exactTable, useCodeIdentity: true
        )
        let candidates = try OrderingConfigurationIdentityResolver.resolve(snapshot: snapshot)
        #expect(candidates.allSatisfy { $0.eligible && $0.exactBundleCodeIdentity != nil })
        #expect(candidates.allSatisfy { $0.ownerSavedPositions.isEmpty })

        let plan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: snapshot,
            orderedBundleIdentifiers: ["example.beta", "example.alpha"], now: now
        )
        #expect(plan.configurationTargets?.allSatisfy {
            $0.exactBundleCodeIdentity != nil
                && $0.ownerSavedPositions.isEmpty
                && $0.ownerPreferenceNamespace == .unknown
        } == true)
        #expect(try JSONDecoder().decode(
            OrderingPlan.self, from: JSONEncoder().encode(plan)
        ) == plan)

        let changedUnavailablePreferences = try fixture(
            saved: ["different-denied-read": .integer(88)],
            preferencesComplete: false, table: exactTable, useCodeIdentity: true
        )
        try plan.validateFresh(equivalentTo: changedUnavailablePreferences, now: now)

        let changedIdentity = try fixture(
            preferencesComplete: false, table: exactTable, useCodeIdentity: true,
            codeIdentityDigest: String(repeating: "b", count: 64)
        )
        #expect(!plan.isFresh(equivalentTo: changedIdentity, now: now))
    }

    @Test func exactBundleAnchorCarriesUniqueExecutableAliasKeys() throws {
        let snapshot = try fixture(
            preferencesComplete: false,
            table: [
                "status:example.alpha::Item-0": .integer(900),
                "status:Alpha::Legacy": .integer(700),
                "status:example.beta::Item-0": .integer(500),
            ],
            useCodeIdentity: true
        )
        let alpha = try #require(try OrderingConfigurationIdentityResolver.resolve(
            snapshot: snapshot
        ).first { $0.bundleIdentifier == "example.alpha" })
        #expect(alpha.eligible)
        #expect(alpha.exactBundleCodeIdentity != nil)
        #expect(Set(alpha.keys.map(\.key)) == Set([
            "status:example.alpha::Item-0", "status:Alpha::Legacy",
        ]))
    }

    @Test func onlyExactCatalogAppleOwnersAreConfigurationEligible() throws {
        let processes = [
            OrderingProcess(bundleIdentifier: "com.apple.weather.menu", executableName: "WeatherMenu",
                            pid: 401, launchTime: now.addingTimeInterval(-20), isSystem: true),
            OrderingProcess(bundleIdentifier: "com.apple.TextInputMenuAgent", executableName: "TextInputMenuAgent",
                            pid: 402, launchTime: now.addingTimeInterval(-20), isSystem: true),
            OrderingProcess(bundleIdentifier: "com.apple.controlcenter", executableName: "ControlCenter",
                            pid: 403, launchTime: now.addingTimeInterval(-20), isSystem: true),
            OrderingProcess(bundleIdentifier: "com.apple.systemuiserver", executableName: "SystemUIServer",
                            pid: 404, launchTime: now.addingTimeInterval(-20), isSystem: true),
            OrderingProcess(bundleIdentifier: "com.apple.othermenu", executableName: "OtherMenu",
                            pid: 405, launchTime: now.addingTimeInterval(-20), isSystem: true),
        ]
        let table = Dictionary(uniqueKeysWithValues: processes.enumerated().map { index, process in
            ("status:\(process.bundleIdentifier!)::Item-0", OrderingValue.integer(Int64(900 - index * 100)))
        })
        let observations = Dictionary(uniqueKeysWithValues: processes.map { process in
            (process.pid, OrderingOwnerObservation(
                process: process, displayName: process.executableName!, axComplete: false, itemFrames: [],
                ownerPreferencesComplete: true, ownerSavedPositions: [:]
            ))
        })
        let snapshot = try OrderingSnapshot(
            group: [OrderingSnapshot.tableKey: .dictionary(table)],
            beforeProcesses: processes, afterProcesses: processes,
            observationsByPID: observations, osBuild: OrderingSnapshot.supportedBuild,
            architecture: OrderingSnapshot.supportedArchitecture, runtimeContractVerified: true,
            displaySignature: "fixture-display", displayCount: 1,
            displayFrame: RectSnapshot(x: 0, y: 0, width: 1000, height: 40),
            lifecycleGeneration: 7, policyFingerprint: "managed-all-areas",
            orderingAllowedBundleIdentifiers: [], capturedAt: now
        )
        let candidates = try OrderingConfigurationIdentityResolver.resolve(snapshot: snapshot)
        #expect(candidates.first { $0.bundleIdentifier == "com.apple.weather.menu" }?.eligible == true)
        #expect(candidates.first { $0.bundleIdentifier == "com.apple.TextInputMenuAgent" }?.eligible == true)
        for bundle in ["com.apple.controlcenter", "com.apple.systemuiserver", "com.apple.othermenu"] {
            let candidate = try #require(candidates.first { $0.bundleIdentifier == bundle })
            #expect(!candidate.eligible)
            #expect(candidate.reasons.contains(.systemOwnerExcluded))
        }
    }

    @Test func unknownPrivateRuntimeIsRefusedBeforePlanning() {
        #expect(throws: OrderingError.unsupportedRuntime) {
            try fixture(build: "unrecognized-build")
        }
    }

    @Test("The macOS 27 public build is admitted after its read-only contract check")
    func publicBuildIsAdmitted() throws {
        let snapshot = try fixture(build: "26A428")
        try snapshot.validate()
        #expect(snapshot.osBuild == "26A428")
    }

    @Test func noOpPositionsCanBindACombinedAreaOnlyCommit() throws {
        let snapshot = try fixture(table: [
            "status:example.alpha::Pinned": .integer(900),
            "status:example.alpha::Item-0": .integer(500),
            "status:Beta::Item-0": .integer(100)
        ])
        let plan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: snapshot, orderedBundleIdentifiers: ["example.alpha", "example.beta"], now: now
        )
        #expect(plan.configurationBeforeValues == plan.configurationAfterValues)
        try plan.validate()
    }

    @Test func oneMappedOwnerStillSupportsAnAreaOnlyReview() throws {
        let plan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: fixture(), orderedBundleIdentifiers: ["example.beta"], now: now
        )
        #expect(plan.configurationTargets?.count == 1)
        #expect(plan.configurationBeforeValues == plan.configurationAfterValues)
        try plan.validate()
    }

    private func fixture(
        frames: [RectSnapshot] = [], saved: [String: OrderingValue] = [:],
        preferencesComplete: Bool = true, lifecycle: Int = 7,
        extraProcess: OrderingProcess? = nil,
        build: String = OrderingSnapshot.supportedBuild,
        table: [String: OrderingValue]? = nil,
        allowedBundleIdentifiers: Set<String> = [],
        otherSetting: OrderingValue = .bool(true),
        useCodeIdentity: Bool = false,
        codeIdentityDigest: String = String(repeating: "a", count: 64)
    ) throws -> OrderingSnapshot {
        let processes = [alpha, beta] + (extraProcess.map { [$0] } ?? [])
        let observations = Dictionary(uniqueKeysWithValues: processes.map { process in
            (process.pid, OrderingOwnerObservation(
                process: process, displayName: process.executableName!,
                axComplete: !frames.isEmpty, itemFrames: frames,
                ownerPreferencesComplete: preferencesComplete, ownerSavedPositions: saved,
                applicationCodeIdentity: useCodeIdentity ? OrderingApplicationCodeIdentity(
                    signingIdentifier: process.bundleIdentifier!, teamIdentifier: "TEAM123456",
                    designatedRequirementDigest: codeIdentityDigest
                ) : nil
            ))
        })
        return try OrderingSnapshot(
            group: [OrderingSnapshot.tableKey: .dictionary(table ?? [
                "status:example.alpha::Pinned": .integer(900),
                "status:example.alpha::Item-0": .integer(100),
                "status:Beta::Item-0": .integer(500)
            ]), "OtherSetting": otherSetting],
            beforeProcesses: processes, afterProcesses: processes,
            observationsByPID: observations, osBuild: build,
            architecture: OrderingSnapshot.supportedArchitecture, runtimeContractVerified: true,
            displaySignature: "fixture-display", displayCount: 1,
            displayFrame: RectSnapshot(x: 0, y: 0, width: 1000, height: 40),
            lifecycleGeneration: lifecycle, policyFingerprint: "managed-all-areas",
            orderingAllowedBundleIdentifiers: allowedBundleIdentifiers, capturedAt: now
        )
    }
}
#endif
