#if DEBUG
import Foundation
import Testing
@testable import BlennyCore

@Suite("Exact system-item ordering core")
struct SystemOrderingCoreTests {
    @Test("Deferred sorting retains exact identities for historical recovery")
    func deferredProductAvailability() throws {
        #expect(ExactSystemOrderingItem.allCases.filter(\.isOrderingOffered)
            == [.bluetooth, .wifi, .sound, .nowPlaying])
        for item in [ExactSystemOrderingItem.siri, .timeMachine, .controlCenter] {
            #expect(!item.isOrderingOffered)
            #expect(ExactSystemOrderingItem(configurationKey: item.configurationKey) == item)
            #expect(try JSONDecoder().decode(ExactSystemOrderingItem.self,
                from: JSONEncoder().encode(item)) == item)
        }
    }

    @Test("The bounded catalog has stable item, key, host, and Board identities")
    func exactCatalogMappings() throws {
        #expect(ExactSystemOrderingItem.allCases.count == 7)
        for item in ExactSystemOrderingItem.allCases {
            #expect(ExactSystemOrderingItem(configurationKey: item.configurationKey) == item)
            #expect(ExactSystemOrderingItem(observationIdentifier: item.observationIdentifier) == item)
            let subject = OrderingSubjectID.systemItem(item)
            #expect(OrderingSubjectID(boardID: subject.boardID) == subject)
            #expect(try JSONDecoder().decode(
                OrderingSubjectID.self, from: JSONEncoder().encode(subject)
            ) == subject)
        }
        #expect(ExactSystemOrderingItem(configurationKey: "module:Clock") == nil)
        #expect(ExactSystemOrderingItem(configurationKey: "module:AudioVideoModule") == nil)
        #expect(OrderingSubjectID(boardID: "system:clock") == nil)
    }

    @Test("Control Center requires the exact singleton namespace and binary pins")
    func controlCenterConditionalAdmission() {
        let exact: [String: OrderingValue] = [
            "module:BentoBox-0": .integer(49), "module:Clock": .integer(90),
            "module:AudioVideoModule": .integer(80), "module:WiFi": .integer(70),
        ]
        #expect(MacOS27MenuBarOrderingBackend.controlCenterNamespaceEligibleForTesting(exact))
        #expect(!MacOS27MenuBarOrderingBackend.controlCenterNamespaceEligibleForTesting(
            exact.merging(["module:BentoBox": .integer(48)]) { _, new in new }
        ))
        #expect(!MacOS27MenuBarOrderingBackend.controlCenterNamespaceEligibleForTesting(
            exact.merging(["module:BentoBox-1": .integer(48)]) { _, new in new }
        ))
        #expect(!MacOS27MenuBarOrderingBackend.controlCenterNamespaceEligibleForTesting([
            "module:BentoBox": .integer(49)
        ]))
        #expect(!MacOS27MenuBarOrderingBackend.controlCenterNamespaceEligibleForTesting([
            "module:BentoBox-0": .integer(0)
        ]))
        #expect(MacOS27MenuBarOrderingBackend.controlCenterBinaryUUIDsMatchForTesting(
            controlCenter: "e842fc2a-0aab-350d-bea6-66229257c329",
            menuBarAgent: "de3cdaba-05ed-328c-88be-41d240550156"
        ))
        #expect(!MacOS27MenuBarOrderingBackend.controlCenterBinaryUUIDsMatchForTesting(
            controlCenter: "00000000-0000-0000-0000-000000000000",
            menuBarAgent: "DE3CDABA-05ED-328C-88BE-41D240550156"
        ))
    }

    @Test("Control Center scope preserves Clock, AudioVideo, and other modules")
    func controlCenterExactWriteScope() throws {
        let previous: [String: OrderingValue] = [
            "module:BentoBox-0": .integer(49), "module:Clock": .integer(90),
            "module:AudioVideoModule": .integer(80), "module:WiFi": .integer(70),
        ]
        var proposed = previous
        proposed["module:BentoBox-0"] = .integer(95)
        #expect(try MacOS27MenuBarOrderingBackend.validateWriteScopeForTesting(
            previous: previous, proposed: proposed, configurationMode: true
        ) == ["module:BentoBox-0"])
        #expect(proposed.filter { $0.key != "module:BentoBox-0" }
            == previous.filter { $0.key != "module:BentoBox-0" })
    }

    @Test("A BentoBox sibling appearing after preview invalidates Control Center")
    func controlCenterSiblingInvalidatesFreshnessAndFinalScope() async throws {
        let fixture = try SystemOrderingFixture()
        let plan = try fixture.controlCenterPlan()
        var group = fixture.baseline.group
        var table = try fixture.baseline.table()
        table["module:BentoBox"] = .integer(48)
        group[OrderingSnapshot.tableKey] = .dictionary(table)
        let changed = try fixture.snapshot(
            group: group, bindings: fixture.bindingsWithoutControlCenter
        )
        let candidate = try OrderingSystemConfigurationIdentityResolver.resolve(
            snapshot: changed
        ).first { $0.item == .controlCenter }
        #expect(candidate?.reasons.contains(.systemConfigurationNamespaceAmbiguous) == true)
        #expect(throws: OrderingError.self) {
            try plan.validateFresh(equivalentTo: changed, now: fixture.now)
        }
        let backend = SystemOrderingBackend(fixture: fixture)
        await backend.replaceCurrent(changed)
        await #expect(throws: OrderingError.self) {
            try await backend.writeConfigurationTable(
                table, expecting: fixture.baseline,
                ownerKeys: [ExactSystemOrderingItem.controlCenter.configurationKey]
            )
        }
    }

    @Test("Recovery refuses Control Center when its exact mapping is absent")
    func controlCenterRecoveryRequiresMapping() async throws {
        let fixture = try SystemOrderingFixture()
        let backend = SystemOrderingBackend(fixture: fixture)
        let recovery = SystemOrderingRecovery()
        let writer = makeWriter(backend: backend, recovery: recovery)
        let plan = try fixture.controlCenterPlan()
        _ = try await writer.applyConfigurationOrdering(
            plan, confirmedFingerprint: plan.fingerprint
        )
        let committed = await backend.current
        let withoutBinding = try fixture.snapshot(
            group: committed.group, bindings: fixture.bindingsWithoutControlCenter
        )
        await backend.replaceCurrent(withoutBinding)
        await #expect(throws: OrderingTransactionError.recoveryIdentityConflict) {
            _ = try await writer.restoreOrdering()
        }
    }

    @Test("Control Center exact configuration restores and clears its receipt")
    func controlCenterRecoverySuccess() async throws {
        let fixture = try SystemOrderingFixture()
        let backend = SystemOrderingBackend(fixture: fixture)
        let recovery = SystemOrderingRecovery()
        let writer = makeWriter(backend: backend, recovery: recovery)
        let plan = try fixture.controlCenterPlan()
        _ = try await writer.applyConfigurationOrdering(
            plan, confirmedFingerprint: plan.fingerprint
        )
        _ = try await writer.restoreOrdering()
        #expect(await backend.current.group == fixture.baseline.group)
        #expect(await recovery.receipt == nil)
    }

    @Test("A mixed plan moves exact system items and one whole application owner")
    func mixedPlan() throws {
        let fixture = try SystemOrderingFixture()
        let candidates = try OrderingConfigurationSubjectIdentityResolver.resolve(
            snapshot: fixture.baseline
        )
        #expect(candidates.first(where: { $0.subjectID == .systemItem(.bluetooth) })?.eligible == true)
        #expect(candidates.first(where: { $0.subjectID == .systemItem(.siri) })?.eligible == true)
        #expect(candidates.first(where: { $0.subjectID == .systemItem(.sound) })?.eligible == false)

        let plan = try fixture.mixedPlan()
        #expect(plan.schemaVersion == 4)
        #expect(plan.orderedConfigurationSubjects == [
            .systemItem(.bluetooth), .application(fixture.application.bundleIdentifier!),
            .systemItem(.siri),
        ])
        #expect(plan.configurationAfterValues?[ExactSystemOrderingItem.bluetooth.configurationKey]
            == .integer(900))
        #expect(plan.configurationAfterValues?[fixture.applicationKey] == .integer(500))
        #expect(plan.configurationAfterValues?[ExactSystemOrderingItem.siri.configurationKey]
            == .integer(100))
        #expect(try JSONDecoder().decode(
            OrderingPlan.self, from: JSONEncoder().encode(plan)
        ) == plan)
    }

    @Test("System status-key token collisions fail closed")
    func statusProcessCollision() throws {
        let fixture = try SystemOrderingFixture()
        let plan = try fixture.mixedPlan()
        let collision = OrderingProcess(
            bundleIdentifier: "example.collision",
            executableName: "com.apple.systemuiserver", pid: 999,
            launchTime: fixture.now.addingTimeInterval(-10), isSystem: false
        )
        let collided = try fixture.snapshot(
            group: fixture.baseline.group,
            extraProcesses: [collision]
        )
        let candidates = try OrderingSystemConfigurationIdentityResolver.resolve(snapshot: collided)
        #expect(candidates.first(where: { $0.item == .siri })?.reasons.contains(.ownerTokenCollision) == true)
        #expect(candidates.first(where: { $0.item == .bluetooth })?.eligible == true)
        #expect(throws: OrderingError.self) {
            _ = try OrderingPlan.makeConfigurationOrdering(
                snapshot: collided, orderedSubjects: [.systemItem(.siri)], now: fixture.now
            )
        }
        #expect(throws: OrderingError.self) {
            try plan.validateFresh(equivalentTo: collided, now: fixture.now)
        }
    }

    @Test("System-only plans reject unsupported display scope during preview")
    func systemOnlyDisplayScope() throws {
        let fixture = try SystemOrderingFixture()
        let current = try fixture.snapshot(group: fixture.baseline.group, displayCount: 2)
        let candidates = try OrderingSystemConfigurationIdentityResolver.resolve(snapshot: current)
        #expect(candidates.allSatisfy { $0.reasons.contains(.singleDisplayRequired) })
        #expect(throws: OrderingError.self) {
            _ = try OrderingPlan.makeConfigurationOrdering(
                snapshot: current, orderedSubjects: [.systemItem(.bluetooth), .systemItem(.siri)],
                now: fixture.now
            )
        }
    }

    @Test("Signed system host relaunch still requires a fresh review")
    func systemHostRelaunchAndUnverifiedSignature() throws {
        let fixture = try SystemOrderingFixture()
        let plan = try fixture.mixedPlan()
        let restarted = OrderingProcess(
            bundleIdentifier: fixture.controlCenter.bundleIdentifier,
            executableName: fixture.controlCenter.executableName,
            pid: fixture.controlCenter.pid,
            launchTime: fixture.now.addingTimeInterval(-1), isSystem: true
        )
        let bindings = (fixture.baseline.systemHostBindings ?? []).map { binding in
            binding.item.hostBundleIdentifier == fixture.controlCenter.bundleIdentifier
                ? OrderingSystemHostBinding(
                item: binding.item, configurationKey: binding.configurationKey,
                hostProcess: restarted, codeIdentityVerified: true
            ) : binding
        }
        let current = try fixture.snapshot(
            group: fixture.baseline.group,
            processes: fixture.baseline.beforeProcesses.map {
                $0 == fixture.controlCenter ? restarted : $0
            },
            bindings: bindings
        )
        #expect(throws: OrderingError.self) {
            try plan.validateFresh(equivalentTo: current, now: fixture.now)
        }
        #expect(throws: OrderingError.self) {
            _ = try fixture.snapshot(
                group: fixture.baseline.group,
                bindings: [OrderingSystemHostBinding(
                    item: .bluetooth,
                    configurationKey: ExactSystemOrderingItem.bluetooth.configurationKey,
                    hostProcess: fixture.controlCenter, codeIdentityVerified: false
                )]
            )
        }
    }

    @Test("Mixed ordering preserves a whole multi-key app and an unselected system sibling")
    func multiKeyOwnerAndUnselectedSibling() throws {
        let fixture = try SystemOrderingFixture()
        let extraKey = "status:example.alpha::SecondItem"
        let siblingKey = ExactSystemOrderingItem.timeMachine.configurationKey
        var table = try fixture.baseline.table()
        table[extraKey] = .integer(800)
        table[siblingKey] = .integer(700)
        var group = fixture.baseline.group
        group[OrderingSnapshot.tableKey] = .dictionary(table)
        let current = try fixture.snapshot(group: group)
        let plan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: current,
            orderedSubjects: [.systemItem(.bluetooth),
                              .application(fixture.application.bundleIdentifier!),
                              .systemItem(.siri)],
            now: fixture.now
        )
        let targets = try #require(plan.configurationSubjectTargets)
        guard case let .application(owner) = targets[1] else {
            Issue.record("The middle subject must retain its whole application owner")
            return
        }
        #expect(owner.keys.map(\.key) == [fixture.applicationKey, extraKey])
        #expect(owner.keys.map(\.after) == [.integer(800), .integer(500)])
        let proposed = try plan.applying(to: current.group)
        guard case let .dictionary(proposedTable)? = proposed[OrderingSnapshot.tableKey] else {
            Issue.record("The proposal must preserve the group table")
            return
        }
        #expect(proposedTable[siblingKey] == .integer(700))
    }

    @Test("The process-only scope overload cannot authorize a system key")
    func systemScopeRequiresSignedBindings() throws {
        let fixture = try SystemOrderingFixture()
        #expect(throws: OrderingError.self) {
            try fixture.baseline.validateConfigurationProcessScope(
                for: [ExactSystemOrderingItem.bluetooth.configurationKey],
                against: fixture.baseline.afterProcesses
            )
        }
        try fixture.baseline.validateConfigurationProcessScope(
            for: [ExactSystemOrderingItem.bluetooth.configurationKey],
            against: fixture.baseline
        )
        let bindings = try #require(fixture.baseline.systemHostBindings)
        #expect(throws: OrderingError.self) {
            try fixture.baseline.validateConfigurationProcessScope(
                for: [ExactSystemOrderingItem.bluetooth.configurationKey],
                against: fixture.baseline.afterProcesses,
                systemHostBindings: bindings + [bindings[0]]
            )
        }
    }

    @Test("A schema-2 application receipt migrates without losing its original value")
    func legacyReceiptMigration() async throws {
        let fixture = try SystemOrderingFixture()
        let legacyPlan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: fixture.baseline,
            orderedBundleIdentifiers: [fixture.application.bundleIdentifier!],
            now: fixture.now
        )
        let legacyValues = try #require(legacyPlan.configurationBeforeValues)
        let legacy = OrderingRecoveryReceipt(
            configurationPlan: legacyPlan,
            originalValues: legacyValues,
            committedValues: legacyValues,
            pendingValues: legacyValues,
            phase: .applyIntent
        )
        var cleanLegacy = legacy
        cleanLegacy.phase = .applied
        cleanLegacy.pendingValues = nil
        cleanLegacy.configurationVerified = true
        try cleanLegacy.validate()

        let backend = SystemOrderingBackend(fixture: fixture)
        let recovery = SystemOrderingRecovery(receipt: cleanLegacy)
        let writer = makeWriter(backend: backend, recovery: recovery)
        let plan = try fixture.mixedPlan()
        _ = try await writer.applyConfigurationOrdering(
            plan, confirmedFingerprint: plan.fingerprint
        )
        let migrated = try #require(await recovery.receipt)
        #expect(migrated.schemaVersion == 4)
        #expect(migrated.originalValues?[fixture.applicationKey] == .integer(900))
        #expect(migrated.subjectBindings?.map(\.subjectID).contains(.systemItem(.siri)) == true)
        try migrated.validate()
    }

    @Test("A schema-3 mixed ledger rebases to a fresh selected system scope")
    func mixedSystemReceiptRebaseAndUndo() async throws {
        let fixture = try SystemOrderingFixture()
        let backend = SystemOrderingBackend(fixture: fixture)
        let recovery = SystemOrderingRecovery()
        let writer = makeWriter(backend: backend, recovery: recovery)
        let first = try fixture.mixedPlan()
        _ = try await writer.applyConfigurationOrdering(
            first, confirmedFingerprint: first.fingerprint
        )
        let clean = try #require(await recovery.receipt)
        #expect(clean.schemaVersion == 4)
        try await backend.perturb(
            ExactSystemOrderingItem.bluetooth.configurationKey, to: .integer(777)
        )
        let externalBaseline = await backend.current
        let review = try #require(try clean.undoLedgerRebaseReview(in: externalBaseline))
        let second = try OrderingPlan.makeConfigurationOrdering(
            snapshot: externalBaseline,
            orderedSubjects: [
                .systemItem(.siri), .application(fixture.application.bundleIdentifier!),
            ],
            now: fixture.now
        )

        _ = try await writer.applyConfigurationOrdering(
            second, confirmedFingerprint: second.fingerprint,
            confirmedUndoRebaseToken: review.token
        )
        let rebased = try #require(await recovery.receipt)
        #expect(rebased.schemaVersion == 4)
        #expect(await recovery.archivedReceipt == clean)
        #expect(Set(try #require(rebased.subjectBindings).map(\.subjectID)) == Set([
            .systemItem(.siri), .application(fixture.application.bundleIdentifier!),
        ]))

        _ = try await writer.restoreOrdering()
        let restored = try await backend.current.table()
        let expected = try externalBaseline.table()
        #expect(restored[ExactSystemOrderingItem.siri.configurationKey]
            == expected[ExactSystemOrderingItem.siri.configurationKey])
        #expect(restored[fixture.applicationKey] == expected[fixture.applicationKey])
        #expect(restored[ExactSystemOrderingItem.bluetooth.configurationKey] == .integer(777))
    }

    @Test("Partial mixed writes roll back once and retain a clean durable baseline")
    func partialFailureRollback() async throws {
        let fixture = try SystemOrderingFixture()
        let backend = SystemOrderingBackend(fixture: fixture, partialFailure: true)
        let recovery = SystemOrderingRecovery()
        let writer = makeWriter(backend: backend, recovery: recovery)
        let plan = try fixture.mixedPlan()

        await #expect(throws: OrderingTransactionError.receiptStorageUnavailable) {
            _ = try await writer.applyConfigurationOrdering(
                plan, confirmedFingerprint: plan.fingerprint
            )
        }
        #expect(await backend.current.group == fixture.baseline.group)
        #expect(await backend.writeCount == 2)
        #expect(await recovery.receipt?.isPendingRestoration == false)
    }

    @Test("Undo restores mixed values while Stop leaves a clean user order committed")
    func undoAndStopPersistence() async throws {
        let fixture = try SystemOrderingFixture()
        let backend = SystemOrderingBackend(fixture: fixture)
        let recovery = SystemOrderingRecovery()
        let writer = makeWriter(backend: backend, recovery: recovery)
        let plan = try fixture.mixedPlan()

        _ = try await writer.applyConfigurationOrdering(
            plan, confirmedFingerprint: plan.fingerprint
        )
        let committed = await backend.current.group
        await writer.restoreAndStop()
        #expect(await backend.current.group == committed)
        #expect(await recovery.receipt?.phase == .applied)

        _ = try await writer.restoreOrdering()
        #expect(await backend.current.group == fixture.baseline.group)
        #expect(await recovery.receipt == nil)
    }

    @Test("A visibility transition that changes an ordered system key is compensated")
    func postPolicyOrderingDrift() async throws {
        let fixture = try SystemOrderingFixture()
        let backend = SystemOrderingBackend(fixture: fixture)
        let recovery = SystemOrderingRecovery()
        let assertion = SystemOrderingAssertionWriter()
        let persistent = PerturbingSystemOrderingPersistentWriter(
            backend: backend,
            key: ExactSystemOrderingItem.bluetooth.configurationKey,
            value: .integer(100)
        )
        let writer = CoordinatedPolicyWriter(
            assertionWriter: assertion, persistentWriter: persistent,
            orderingBackend: backend, orderingRecovery: recovery
        )
        let prepared = try preparedPolicyChange()
        let policyStore = SystemOrderingPolicyStore(document: prepared.oldPolicy)
        let plan = try fixture.mixedPlan()

        await #expect(throws: OrderingTransactionError.movementNotVerified) {
            _ = try await writer.applyConfigurationOrdering(
                plan, confirmedFingerprint: plan.fingerprint,
                policyChange: prepared, policyStore: policyStore
            )
        }
        #expect(await backend.current.group == fixture.baseline.group)
        #expect(await policyStore.document == prepared.oldPolicy)
        #expect(await recovery.receipt?.isPendingRestoration == false)
    }

    @Test("Mixed Undo refuses collateral group drift after the inverse write")
    func inverseCollateralDrift() async throws {
        let fixture = try SystemOrderingFixture()
        let backend = SystemOrderingBackend(fixture: fixture)
        let recovery = SystemOrderingRecovery()
        let writer = makeWriter(backend: backend, recovery: recovery)
        let plan = try fixture.mixedPlan()
        _ = try await writer.applyConfigurationOrdering(
            plan, confirmedFingerprint: plan.fingerprint
        )
        await backend.enableCollateralOnRestore()

        await #expect(throws: OrderingTransactionError.restorationAlreadyAttempted) {
            _ = try await writer.restoreOrdering()
        }
        #expect(await recovery.receipt?.phase == .restoreIntent)
        #expect(await recovery.receipt?.isPendingRestoration == true)
    }

    private func makeWriter(
        backend: SystemOrderingBackend,
        recovery: SystemOrderingRecovery
    ) -> CoordinatedPolicyWriter {
        CoordinatedPolicyWriter(
            assertionWriter: SystemOrderingAssertionWriter(),
            persistentWriter: SystemOrderingPersistentWriter(),
            orderingBackend: backend, orderingRecovery: recovery
        )
    }

    private func preparedPolicyChange() throws -> PreparedPolicyEdit {
        let blenny = "xyz.fi5h.blenny"
        let alpha = "example.alpha"
        let beta = "example.beta"
        let old = try PersistentBundlePolicyDocument(
            managementEnabled: true,
            policies: [
                .init(bundleIdentifier: blenny, policy: .visible),
                .init(bundleIdentifier: alpha, policy: .visible),
                .init(bundleIdentifier: beta, policy: .revealable),
            ]
        )
        let prepared = try PolicyDryRunner.prepare(
            oldPolicy: old,
            draft: BundlePolicyDraft(
                visible: [blenny, beta], revealable: [alpha], hidden: []
            ),
            managementEnabled: true,
            candidates: PolicyCandidateInventory(observations: [
                .init(bundleIdentifier: blenny, processIdentifier: 10, menuBarItemCount: 1),
                .init(bundleIdentifier: alpha, processIdentifier: 11, menuBarItemCount: 1),
                .init(bundleIdentifier: beta, processIdentifier: 12, menuBarItemCount: 1),
            ]),
            observedRunningBundleIdentifiers: [blenny, alpha, beta],
            scope: PolicyValidationScope(approvedBundleIdentifiers: [blenny, alpha, beta]),
            blennyBundleIdentifier: blenny,
            recoveryBackupFingerprint: nil
        )
        return try #require(prepared.prepared)
    }
}

private struct SystemOrderingFixture: Sendable {
    let now = Date()
    let application: OrderingProcess
    let controlCenter: OrderingProcess
    let systemUIServer: OrderingProcess
    let applicationKey = "status:example.alpha::AlphaItem"
    let baseline: OrderingSnapshot

    init() throws {
        application = OrderingProcess(
            bundleIdentifier: "example.alpha", executableName: "Alpha", pid: 501,
            launchTime: now.addingTimeInterval(-200), isSystem: false
        )
        controlCenter = OrderingProcess(
            bundleIdentifier: "com.apple.controlcenter", executableName: "ControlCenter", pid: 502,
            launchTime: now.addingTimeInterval(-300), isSystem: true
        )
        systemUIServer = OrderingProcess(
            bundleIdentifier: "com.apple.systemuiserver", executableName: "SystemUIServer", pid: 503,
            launchTime: now.addingTimeInterval(-400), isSystem: true
        )
        let processes = [application, controlCenter, systemUIServer]
        let table: [String: OrderingValue] = [
            applicationKey: .integer(900),
            ExactSystemOrderingItem.bluetooth.configurationKey: .integer(100),
            ExactSystemOrderingItem.siri.configurationKey: .integer(500),
            ExactSystemOrderingItem.controlCenter.configurationKey: .integer(49),
        ]
        let observation = OrderingOwnerObservation(
            process: application, displayName: "Alpha", axComplete: true,
            itemFrames: [], ownerPreferencesComplete: true,
            ownerSavedPositions: ["AlphaItem": .integer(900)]
        )
        baseline = try OrderingSnapshot(
            group: [OrderingSnapshot.tableKey: .dictionary(table)],
            beforeProcesses: processes, afterProcesses: processes,
            observationsByPID: [application.pid: observation],
            osBuild: OrderingSnapshot.supportedBuild,
            architecture: OrderingSnapshot.supportedArchitecture,
            runtimeContractVerified: true, displaySignature: "system-ordering-display",
            displayCount: 1,
            displayFrame: RectSnapshot(x: 0, y: 0, width: 1_000, height: 24),
            lifecycleGeneration: 4, policyFingerprint: "system-ordering-policy",
            orderingAllowedBundleIdentifiers: [application.bundleIdentifier!],
            systemHostBindings: [
                .init(
                    item: .bluetooth,
                    configurationKey: ExactSystemOrderingItem.bluetooth.configurationKey,
                    hostProcess: controlCenter, codeIdentityVerified: true
                ),
                .init(
                    item: .siri,
                    configurationKey: ExactSystemOrderingItem.siri.configurationKey,
                    hostProcess: systemUIServer, codeIdentityVerified: true
                ),
                .init(
                    item: .controlCenter,
                    configurationKey: ExactSystemOrderingItem.controlCenter.configurationKey,
                    hostProcess: controlCenter, codeIdentityVerified: true
                ),
            ],
            capturedAt: now
        )
    }

    func mixedPlan() throws -> OrderingPlan {
        try OrderingPlan.makeConfigurationOrdering(
            snapshot: baseline,
            orderedSubjects: [
                .systemItem(.bluetooth), .application(application.bundleIdentifier!),
                .systemItem(.siri),
            ],
            now: now
        )
    }

    func controlCenterPlan() throws -> OrderingPlan {
        try OrderingPlan.makeConfigurationOrdering(
            snapshot: baseline,
            orderedSubjects: [
                .systemItem(.controlCenter), .application(application.bundleIdentifier!),
            ],
            now: now
        )
    }

    var bindingsWithoutControlCenter: [OrderingSystemHostBinding] {
        (baseline.systemHostBindings ?? []).filter { $0.item != .controlCenter }
    }

    func snapshot(
        group: [String: OrderingValue],
        extraProcesses: [OrderingProcess] = [],
        processes: [OrderingProcess]? = nil,
        bindings: [OrderingSystemHostBinding]? = nil,
        displayCount: Int? = nil
    ) throws -> OrderingSnapshot {
        let processes = (processes ?? baseline.beforeProcesses) + extraProcesses
        return try OrderingSnapshot(
            group: group, beforeProcesses: processes, afterProcesses: processes,
            observationsByPID: baseline.observationsByPID,
            osBuild: baseline.osBuild, architecture: baseline.architecture,
            runtimeContractVerified: true, displaySignature: baseline.displaySignature,
            displayCount: displayCount ?? baseline.displayCount, displayFrame: baseline.displayFrame,
            lifecycleGeneration: baseline.lifecycleGeneration,
            policyFingerprint: baseline.policyFingerprint,
            orderingAllowedBundleIdentifiers: baseline.orderingAllowedBundleIdentifiers,
            systemHostBindings: bindings ?? baseline.systemHostBindings ?? [], capturedAt: baseline.capturedAt
        )
    }
}

private actor SystemOrderingBackend: MenuBarOrderingBackend {
    let fixture: SystemOrderingFixture
    var current: OrderingSnapshot
    var writeCount = 0
    private var partialFailure: Bool
    private var collateralOnRestore = false

    init(fixture: SystemOrderingFixture, partialFailure: Bool = false) {
        self.fixture = fixture
        current = fixture.baseline
        self.partialFailure = partialFailure
    }

    func capture() -> OrderingSnapshot { current }

    func writeTable(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot
    ) throws {
        guard snapshot == current else { throw OrderingTransactionError.contextInvalidated }
        writeCount += 1
        var group = current.group
        if partialFailure {
            partialFailure = false
            var partial = try current.table()
            guard let key = table.keys.sorted().first(where: { table[$0] != partial[$0] }) else {
                throw OrderingTransactionError.invalidReceipt
            }
            partial[key] = table[key]
            group[OrderingSnapshot.tableKey] = .dictionary(partial)
            current = try fixture.snapshot(group: group)
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        group[OrderingSnapshot.tableKey] = .dictionary(table)
        current = try fixture.snapshot(group: group)
    }

    func restoreTable(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot
    ) throws {
        try writeTable(table, expecting: snapshot)
    }

    func writeConfigurationTable(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot,
        ownerKeys: Set<String>
    ) async throws {
        try snapshot.validateConfigurationProcessScope(for: ownerKeys, against: current)
        try writeTable(table, expecting: snapshot)
    }

    func restoreConfigurationTable(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot,
        ownerKeys: Set<String>
    ) async throws {
        try snapshot.validateConfigurationProcessScope(for: ownerKeys, against: current)
        try await restoreTable(table, expecting: snapshot)
        if collateralOnRestore {
            collateralOnRestore = false
            var group = current.group
            group["collateral"] = .string("unexpected")
            current = try fixture.snapshot(group: group)
        }
    }


    func perturb(_ key: String, to value: OrderingValue) throws {
        var group = current.group
        var table = try current.table()
        table[key] = value
        group[OrderingSnapshot.tableKey] = .dictionary(table)
        current = try fixture.snapshot(group: group)
    }


    func enableCollateralOnRestore() { collateralOnRestore = true }

    func replaceCurrent(_ snapshot: OrderingSnapshot) { current = snapshot }
}

private actor SystemOrderingRecovery: OrderingRecoveryStoring {
    var receipt: OrderingRecoveryReceipt?
    var archivedReceipt: OrderingRecoveryReceipt?

    init(receipt: OrderingRecoveryReceipt? = nil) { self.receipt = receipt }
    func acquireLease() {}
    func releaseLease() {}
    func load() -> OrderingRecoveryReceipt? { receipt }
    func save(_ receipt: OrderingRecoveryReceipt) throws {
        try receipt.validate()
        self.receipt = receipt
    }
    func supersedeClean(
        _ existing: OrderingRecoveryReceipt,
        with replacement: OrderingRecoveryReceipt
    ) async throws {
        guard receipt == existing, !existing.isPendingRestoration else {
            throw OrderingTransactionError.recoveryRequired
        }
        try replacement.validate()
        archivedReceipt = existing
        receipt = replacement
    }
    func complete(_ receipt: OrderingRecoveryReceipt) throws {
        try receipt.validate()
        self.receipt = nil
    }
}

private actor SystemOrderingAssertionWriter: PolicyAssertionWriting {
    private var active: RevealAllowlistPlan?
    func applySessionTransition(with plan: RevealAllowlistPlan) { active = plan }
    func restoreAndStop() { active = nil }
    func connectionInvalidated() { active = nil }
    func activePlanSnapshot() -> RevealAllowlistPlan? { active }
}

private actor SystemOrderingPersistentWriter: PersistentSystemItemPlanWriting {
    func applyManagedPlan(_ plan: [String: PersistentSystemItemPresentation]) {}
    func verifyManagedPlan(_ plan: [String: PersistentSystemItemPresentation]) -> Bool { true }
    func finalizeCommittedPlan(_ plan: [String: PersistentSystemItemPresentation]) {}
    func restoreAllManagedItems() -> Bool { true }
}

private actor PerturbingSystemOrderingPersistentWriter: PersistentSystemItemPlanWriting {
    let backend: SystemOrderingBackend
    let key: String
    let value: OrderingValue
    var shouldPerturb = true

    init(backend: SystemOrderingBackend, key: String, value: OrderingValue) {
        self.backend = backend
        self.key = key
        self.value = value
    }

    func applyManagedPlan(_ plan: [String: PersistentSystemItemPresentation]) async throws {
        if shouldPerturb {
            shouldPerturb = false
            try await backend.perturb(key, to: value)
        }
    }
    func verifyManagedPlan(_ plan: [String: PersistentSystemItemPresentation]) -> Bool { true }
    func finalizeCommittedPlan(_ plan: [String: PersistentSystemItemPresentation]) {}
    func restoreAllManagedItems() -> Bool { true }
}

private actor SystemOrderingPolicyStore: PersistentBundlePolicyStoring {
    private(set) var document: PersistentBundlePolicyDocument

    init(document: PersistentBundlePolicyDocument) { self.document = document }
    func load() -> PersistentBundlePolicyDocument? { document }
    func loadBackup() -> PersistentBundlePolicyBackup? { nil }
    func save(_ document: PersistentBundlePolicyDocument) { self.document = document }
    func restoreBackup() -> PersistentBundlePolicyDocument? { nil }
    func restoreSnapshot(
        document: PersistentBundlePolicyDocument,
        backup: PersistentBundlePolicyBackup?,
        expecting: PersistentBundlePolicyDocument
    ) throws {
        guard self.document == expecting else {
            throw PersistentBundlePolicyStoreError.interruptedTransactionStateMismatch
        }
        self.document = document
    }
}
#endif
