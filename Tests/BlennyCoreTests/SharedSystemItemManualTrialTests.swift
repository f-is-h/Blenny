#if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
import Foundation
import Testing
@testable import BlennyCore

@MainActor
@Suite("Debug shared system-item manual trial")
struct SharedSystemItemManualTrialTests {
    @Test("Persistent item observations map only exact supported identities")
    func exactObservationMapping() {
        #expect(SharedSystemItemTrialTarget.matchingSystemItem(
            observationIdentifier: "com.apple.menuextra.Siri"
        ) == .siri)
        #expect(SharedSystemItemTrialTarget.matchingSystemItem(
            observationIdentifier: "com.apple.menuextra.TimeMachine"
        ) == .timeMachine)
        #expect(SharedSystemItemTrialTarget.matchingSystemItem(
            observationIdentifier: "com.apple.menuextra.now-playing"
        ) == .nowPlaying)
        #expect(SharedSystemItemTrialTarget.matchingSystemItem(
            observationIdentifier: "com.apple.systemuiserver|:siri|axmenubaritem"
        ) == .siri)
        #expect(SharedSystemItemTrialTarget.matchingSystemItem(
            observationIdentifier: "com.apple.systemuiserver|:time machine|axmenubaritem"
        ) == .timeMachine)
        #expect(SharedSystemItemTrialTarget.matchingSystemItem(
            observationIdentifier: "com.apple.controlcenter|:now playing|axmenubaritem"
        ) == .nowPlaying)
        #expect(SharedSystemItemTrialTarget.matchingSystemItem(
            observationIdentifier: "com.apple.menuextra.clock"
        ) == nil)
        #expect(SharedSystemItemTrialTarget.siri.observationIdentifier
            == "com.apple.menuextra.siri")
        #expect(SharedSystemItemTrialTarget.timeMachine.observationIdentifier
            == "com.apple.menuextra.TimeMachine")
        #expect(SharedSystemItemTrialTarget.nowPlaying.observationIdentifier
            == "com.apple.menuextra.now-playing")
    }

    @Test("Persistent item hide proposals preserve exact unrelated target state")
    func exactProposals() throws {
        let nowPlaying = try makeNowPlayingSnapshot()
        let hiddenNowPlaying = try nowPlaying.hidingProposal()
        #expect(try hiddenNowPlaying.values["NowPlaying"]?.unsignedFlags() == 0x18)
        #expect(!hiddenNowPlaying.effectiveVisible)

        let siri = try makeSiriSnapshot()
        let hiddenSiri = try siri.hidingProposal()
        #expect(try hiddenSiri.values["StatusMenuVisible"]?.optionalBoolean() == false)
        #expect(hiddenSiri.values["SiriPrefStashedStatusMenuVisible"]?.encodedValue == nil)

        let timeMachine = try makeTimeMachineSnapshot()
        let hiddenTimeMachine = try timeMachine.hidingProposal()
        #expect(try hiddenTimeMachine.values["menuExtras"]?.stringArray() == [
            "first.menu", "last.menu"
        ])
        #expect(hiddenTimeMachine.values[
            "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine"
        ] == timeMachine.values[
            "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine"
        ])
        #expect(hiddenTimeMachine.values[
            "NSStatusItem Preferred Position com.apple.menuextra.TimeMachine"
        ] == timeMachine.values[
            "NSStatusItem Preferred Position com.apple.menuextra.TimeMachine"
        ])
    }

    @Test("Now Playing absent baseline restores as absence")
    func nowPlayingAbsenceRoundTripsExactly() throws {
        let baseline = try SharedSystemItemPreferenceSnapshot(
            target: .nowPlaying,
            values: ["NowPlaying": try ExactPreferenceValue(nil)],
            effectiveVisible: true
        )
        let proposal = try baseline.hidingProposal()
        #expect(try proposal.values["NowPlaying"]?.unsignedFlags() == 0x8)
        var receipt = try SharedSystemItemTrialReceipt(
            runtime: .current(), baseline: baseline
        )
        try receipt.recordApplied(proposal)
        #expect(try receipt.acceptsRestoreCurrent(proposal))
        #expect(try receipt.acceptsRestoreCurrent(baseline))
        #expect(baseline.values["NowPlaying"]?.encodedValue == nil)
    }

    @Test("Schema 1 receipts decode without a reveal intent")
    func schemaOneReceiptCompatibility() throws {
        let original = try SharedSystemItemTrialReceipt(
            runtime: .current(), baseline: makeSiriSnapshot()
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            SharedSystemItemTrialReceipt.self, from: data
        )

        #expect(decoded == original)
        #expect(decoded.schemaVersion == 1)
        #expect(decoded.revealIntent == nil)
    }

    @Test("Time Machine accepts setter-normalized target state and restores exactly")
    func timeMachineSetterNormalization() throws {
        let path = SharedSystemItemPreferenceSnapshot.timeMachineMenuExtraPath
        let baseline = try SharedSystemItemPreferenceSnapshot(
            target: .timeMachine,
            values: [
                "menuExtras": try ExactPreferenceValue([path]),
                "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(true),
                "NSStatusItem Preferred Position com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(86),
            ],
            effectiveVisible: true
        )
        let normalizedApplied = try SharedSystemItemPreferenceSnapshot(
            target: .timeMachine,
            values: [
                "menuExtras": try ExactPreferenceValue(nil),
                "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(false),
                "NSStatusItem Preferred Position com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(nil),
            ],
            effectiveVisible: false
        )
        var receipt = try SharedSystemItemTrialReceipt(
            runtime: .current(), baseline: baseline
        )
        try receipt.recordApplied(normalizedApplied)
        try receipt.validate()
        #expect(try receipt.acceptsRestoreCurrent(normalizedApplied))
        #expect(try receipt.acceptsRestoreCurrent(baseline))

        let postWriteNormalization = try SharedSystemItemPreferenceSnapshot(
            target: .timeMachine,
            values: [
                "menuExtras": try ExactPreferenceValue(nil),
                "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(nil),
                "NSStatusItem Preferred Position com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(nil),
            ],
            effectiveVisible: false
        )
        #expect(try receipt.acceptsOwnedHiddenCurrent(postWriteNormalization))
        #expect(try receipt.acceptsRestoreCurrent(postWriteNormalization))

        let unrelatedDrift = try SharedSystemItemPreferenceSnapshot(
            target: .timeMachine,
            values: [
                "menuExtras": try ExactPreferenceValue(["external.menu"]),
                "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(nil),
                "NSStatusItem Preferred Position com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(nil),
            ],
            effectiveVisible: false
        )
        #expect(try !receipt.acceptsOwnedHiddenCurrent(unrelatedDrift))
        #expect(try !receipt.acceptsRestoreCurrent(unrelatedDrift))
    }

    @Test("Time Machine accepts getter-confirmed hide with legacy membership retained")
    func timeMachineGetterStateOverridesLegacyMembership() throws {
        let baseline = try makeTimeMachineSnapshot()
        let applied = try SharedSystemItemPreferenceSnapshot(
            target: .timeMachine,
            values: baseline.values,
            effectiveVisible: false
        )
        var receipt = try SharedSystemItemTrialReceipt(
            runtime: .current(), baseline: baseline
        )

        try receipt.recordApplied(applied)

        #expect(receipt.applied == applied)
        #expect(try receipt.acceptsRestoreCurrent(applied))
    }

    @Test("The writer records normalized Time Machine state before exact restore")
    func writerRecordsNormalizedTimeMachineState() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let baseline = try makeTimeMachineSnapshot()
        let backend = FakeSharedSystemItemTrialBackend(
            states: [.timeMachine: baseline],
            normalizeTimeMachineHide: true
        )
        let writer = SharedSystemItemManualTrialWriter(
            backend: backend, receiptDirectory: directory
        )

        let receipt = try await writer.hide(.timeMachine)
        #expect(receipt.applied != nil)
        #expect(receipt.applied != receipt.proposed)
        #expect(await writer.hasRecoveryReceipt(for: .timeMachine))

        try await writer.restore(.timeMachine)
        #expect(backend.states[.timeMachine] == baseline)
        #expect(!(await writer.hasRecoveryReceipt(for: .timeMachine)))
    }

    @Test("The writer restores a second bounded Time Machine normalization")
    func writerRestoresPostWriteTimeMachineNormalization() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let baseline = try makeTimeMachineSnapshot()
        let backend = FakeSharedSystemItemTrialBackend(
            states: [.timeMachine: baseline],
            normalizeTimeMachineHide: true
        )
        let writer = SharedSystemItemManualTrialWriter(
            backend: backend, receiptDirectory: directory
        )

        _ = try await writer.hide(.timeMachine)
        backend.states[.timeMachine] = try SharedSystemItemPreferenceSnapshot(
            target: .timeMachine,
            values: [
                "menuExtras": try ExactPreferenceValue(["first.menu", "last.menu"]),
                "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(nil),
                "NSStatusItem Preferred Position com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(nil),
            ],
            effectiveVisible: false
        )

        #expect(await writer.verifyAllManagedItemsAreRestorable())
        #expect(await writer.restoreAllManagedItems())

        #expect(backend.states[.timeMachine] == baseline)
        #expect(!(await writer.hasRecoveryReceipt(for: .timeMachine)))
    }

    @Test("A Time Machine normalization after the applied capture remains recoverable")
    func writerAcceptsNormalizationAfterAppliedCapture() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let baseline = try makeTimeMachineSnapshot()
        let backend = FakeSharedSystemItemTrialBackend(
            states: [.timeMachine: baseline],
            normalizeTimeMachineAfterFirstAppliedCapture: true
        )
        let writer = SharedSystemItemManualTrialWriter(
            backend: backend, receiptDirectory: directory
        )

        let receipt = try await writer.hide(.timeMachine)
        #expect(receipt.applied?.effectiveVisible == false)
        let recordedMenuExtras = try receipt.applied?.values["menuExtras"]?.stringArray() ?? []
        #expect(recordedMenuExtras.contains(
            SharedSystemItemPreferenceSnapshot.timeMachineMenuExtraPath
        ))
        let normalizedMenuExtras = try backend.states[.timeMachine]?
            .values["menuExtras"]?.stringArray() ?? []
        #expect(!normalizedMenuExtras.contains(
            SharedSystemItemPreferenceSnapshot.timeMachineMenuExtraPath
        ))

        let hidden = [
            SharedSystemItemTrialTarget.timeMachine.observationIdentifier:
                PersistentSystemItemPresentation.hidden,
        ]
        #expect(try await writer.verifyManagedPlan(hidden))
        try await writer.restore(.timeMachine)
        #expect(backend.states[.timeMachine] == baseline)
        #expect(backend.restoreCounts[.timeMachine] == 1)
        #expect(!(await writer.hasRecoveryReceipt(for: .timeMachine)))
    }

    @Test("Time Machine still rejects unrelated menu-extra drift")
    func timeMachineRejectsUnrelatedDrift() throws {
        let baseline = try makeTimeMachineSnapshot()
        let drifted = try SharedSystemItemPreferenceSnapshot(
            target: .timeMachine,
            values: [
                "menuExtras": try ExactPreferenceValue(["first.menu"]),
                "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(false),
                "NSStatusItem Preferred Position com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(nil),
            ],
            effectiveVisible: false
        )
        #expect(try !baseline.acceptsAppliedHide(drifted))
    }

    @Test("One actor serializes manual hides and exact restores")
    func serialHideAndRestore() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let backend = FakeSharedSystemItemTrialBackend(states: [
            .siri: try makeSiriSnapshot(),
            .timeMachine: try makeTimeMachineSnapshot(),
        ])
        let writer = SharedSystemItemManualTrialWriter(
            backend: backend, receiptDirectory: directory
        )

        async let siri = writer.hide(.siri)
        async let timeMachine = writer.hide(.timeMachine)
        let receipts = try await [siri, timeMachine]

        #expect(receipts.count == 2)
        #expect(backend.maximumConcurrentMutations == 1)
        #expect(await writer.hasRecoveryReceipt(for: .siri))
        #expect(await writer.hasRecoveryReceipt(for: .timeMachine))

        try await writer.restore(.siri)
        try await writer.restore(.timeMachine)
        #expect(backend.states[.siri] == (try makeSiriSnapshot()))
        #expect(backend.states[.timeMachine] == (try makeTimeMachineSnapshot()))
        #expect(!(await writer.hasRecoveryReceipt(for: .siri)))
        #expect(!(await writer.hasRecoveryReceipt(for: .timeMachine)))
    }

    @Test("Siri ordinary reveal persists its exact intent before the setter")
    func siriRevealIntentPrecedesSetter() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let baseline = try makeImplicitSiriSnapshot()
        let backend = FakeSharedSystemItemTrialBackend(states: [.siri: baseline])
        let writer = SharedSystemItemManualTrialWriter(
            backend: backend, receiptDirectory: directory
        )
        let identifier = SharedSystemItemTrialTarget.siri.observationIdentifier
        var intentObservedBeforeSetter = false
        backend.beforeVisibilityMutation = { target, visible in
            guard target == .siri, visible,
                  let data = try? Data(contentsOf: directory.appendingPathComponent("siri.json")),
                  let receipt = try? JSONDecoder().decode(
                    SharedSystemItemTrialReceipt.self, from: data
                  ) else { return }
            intentObservedBeforeSetter = receipt.schemaVersion == 2
                && receipt.revealIntent?.effectiveVisible == true
        }

        try await writer.applyManagedPlan([identifier: .hidden])
        try await writer.applyManagedPlan([identifier: .revealed])

        #expect(intentObservedBeforeSetter)
        #expect(backend.restoreCounts[.siri, default: 0] == 0)
        #expect(backend.states[.siri] != baseline)
        #expect(try await writer.verifyManagedPlan([identifier: .revealed]))
    }

    @Test("A persisted Siri reveal intent restores after a setter-side crash")
    func siriRevealIntentCrashRecovery() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let baseline = try makeImplicitSiriSnapshot()
        var receipt = try SharedSystemItemTrialReceipt(
            runtime: .current(), baseline: baseline
        )
        let hidden = try baseline.hidingProposal()
        try receipt.recordApplied(hidden)
        try receipt.recordSiriRevealIntent(from: hidden)
        let encoder = JSONEncoder()
        let url = directory.appendingPathComponent("siri.json")
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try encoder.encode(receipt).write(to: url, options: [.atomic])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: url.path
        )
        let backend = FakeSharedSystemItemTrialBackend(states: [
            .siri: try #require(receipt.revealIntent),
        ])
        let restarted = SharedSystemItemManualTrialWriter(
            backend: backend, receiptDirectory: directory
        )

        #expect(await restarted.verifyAllManagedItemsAreRestorable())
        #expect(await restarted.restoreAllManagedItems())
        #expect(backend.states[.siri] == baseline)
        #expect(backend.restoreCounts[.siri] == 1)
        #expect(!(await restarted.hasRecoveryReceipt(for: .siri)))
    }

    @Test("A failed Siri reveal-intent write never reaches the setter")
    func siriRevealIntentWriteFailureDoesNotMutate() async throws {
        let directory = temporaryDirectory()
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: directory.path
            )
            try? FileManager.default.removeItem(at: directory)
        }
        let backend = FakeSharedSystemItemTrialBackend(states: [
            .siri: try makeImplicitSiriSnapshot(),
        ])
        let writer = SharedSystemItemManualTrialWriter(
            backend: backend, receiptDirectory: directory
        )
        let identifier = SharedSystemItemTrialTarget.siri.observationIdentifier
        try await writer.applyManagedPlan([identifier: .hidden])
        var revealSetterCalled = false
        backend.beforeVisibilityMutation = { target, visible in
            if target == .siri, visible { revealSetterCalled = true }
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500], ofItemAtPath: directory.path
        )

        await #expect(throws: SharedSystemItemTrialError.restorationFailed) {
            try await writer.applyManagedPlan([identifier: .revealed])
        }
        #expect(!revealSetterCalled)
    }

    @Test("Siri reveal hides quickly and Stop still restores exactly")
    func siriRevealHideAndExactStop() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let baseline = try makeImplicitSiriSnapshot()
        let backend = FakeSharedSystemItemTrialBackend(states: [.siri: baseline])
        let writer = SharedSystemItemManualTrialWriter(
            backend: backend, receiptDirectory: directory
        )
        let identifier = SharedSystemItemTrialTarget.siri.observationIdentifier

        try await writer.applyManagedPlan([identifier: .hidden])
        try await writer.applyManagedPlan([identifier: .revealed])
        #expect(backend.states[.siri] != baseline)
        try await writer.applyManagedPlan([identifier: .hidden])
        #expect(backend.restoreCounts[.siri, default: 0] == 0)
        #expect(backend.states[.siri]?.effectiveVisible == false)

        #expect(await writer.restoreAllManagedItems())
        #expect(backend.states[.siri] == baseline)
        #expect(backend.restoreCounts[.siri] == 1)
    }

    @Test("Siri revealed-state drift is not taken over by cleanup")
    func siriRevealedStateDriftRefusesRestore() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let baseline = try makeImplicitSiriSnapshot()
        let backend = FakeSharedSystemItemTrialBackend(states: [.siri: baseline])
        let writer = SharedSystemItemManualTrialWriter(
            backend: backend, receiptDirectory: directory
        )
        let identifier = SharedSystemItemTrialTarget.siri.observationIdentifier
        try await writer.applyManagedPlan([identifier: .hidden])
        try await writer.applyManagedPlan([identifier: .revealed])
        backend.states[.siri] = try SharedSystemItemPreferenceSnapshot(
            target: .siri,
            values: [
                "StatusMenuVisible": try ExactPreferenceValue(true),
                "SiriPrefStashedStatusMenuVisible": try ExactPreferenceValue(true),
            ],
            effectiveVisible: true
        )

        #expect(!(try await writer.verifyManagedPlan([identifier: .revealed])))
        #expect(!(await writer.restoreAllManagedItems()))
        #expect(backend.restoreCounts[.siri, default: 0] == 0)
        #expect(await writer.hasRecoveryReceipt(for: .siri))
    }

    @Test("Time Machine ordinary reveal uses the trial route and cleanup stays exact")
    func timeMachineOrdinaryRevealRoute() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let baseline = try makeTimeMachineSnapshot()
        let backend = FakeSharedSystemItemTrialBackend(states: [.timeMachine: baseline])
        let writer = SharedSystemItemManualTrialWriter(backend: backend, receiptDirectory: directory)
        let identifier = SharedSystemItemTrialTarget.timeMachine.observationIdentifier
        try await writer.applyManagedPlan([identifier: .hidden])
        try await writer.applyManagedPlan([identifier: .revealed])
        #expect(backend.ordinaryRevealCounts[.timeMachine] == 1)
        #expect(backend.restoreCounts[.timeMachine, default: 0] == 0)
        #expect(try await writer.verifyManagedPlan([identifier: .revealed]))
        try await writer.applyManagedPlan([identifier: .hidden])
        #expect(await writer.restoreAllManagedItems())
        #expect(backend.restoreCounts[.timeMachine] == 1)
        #expect(backend.states[.timeMachine] == baseline)
    }

    @Test("A failed Time Machine reveal restores its hidden checkpoint and receipt")
    func timeMachineOrdinaryRevealFailure() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let baseline = try makeTimeMachineSnapshot()
        let backend = FakeSharedSystemItemTrialBackend(states: [.timeMachine: baseline])
        let writer = SharedSystemItemManualTrialWriter(backend: backend, receiptDirectory: directory)
        let identifier = SharedSystemItemTrialTarget.timeMachine.observationIdentifier
        try await writer.applyManagedPlan([identifier: .hidden])
        let hidden = backend.states[.timeMachine]
        let receiptURL = directory.appendingPathComponent("timeMachine.json")
        let receipt = try Data(contentsOf: receiptURL)
        backend.failOrdinaryRevealVerification = true
        await #expect(throws: SharedSystemItemTrialError.restorationFailed) {
            try await writer.applyManagedPlan([identifier: .revealed])
        }
        #expect(backend.ordinaryRevealCounts[.timeMachine] == 1)
        #expect(backend.restoreCounts[.timeMachine] == 1)
        #expect(backend.states[.timeMachine] == hidden)
        #expect(try Data(contentsOf: receiptURL) == receipt)
        #expect(await writer.restoreAllManagedItems())
        #expect(backend.states[.timeMachine] == baseline)
    }

    @Test("Managed persistent items implement all three policy states")
    func managedThreeStateLifecycle() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let baselines: [SharedSystemItemTrialTarget: SharedSystemItemPreferenceSnapshot] = [
            .nowPlaying: try makeNowPlayingSnapshot(),
            .siri: try makeSiriSnapshot(),
            .timeMachine: try makeTimeMachineSnapshot(),
        ]
        let backend = FakeSharedSystemItemTrialBackend(states: baselines)
        let writer = SharedSystemItemManualTrialWriter(
            backend: backend, receiptDirectory: directory
        )
        let hidden = Dictionary(uniqueKeysWithValues: SharedSystemItemTrialTarget.allCases.map {
            ($0.observationIdentifier, PersistentSystemItemPresentation.hidden)
        })
        let revealed = Dictionary(uniqueKeysWithValues: SharedSystemItemTrialTarget.allCases.map {
            ($0.observationIdentifier, PersistentSystemItemPresentation.revealed)
        })
        let restored = Dictionary(uniqueKeysWithValues: SharedSystemItemTrialTarget.allCases.map {
            ($0.observationIdentifier, PersistentSystemItemPresentation.restored)
        })

        try await writer.applyManagedPlan(hidden)
        #expect(try await writer.verifyManagedPlan(hidden))
        for target in SharedSystemItemTrialTarget.allCases {
            #expect(await writer.hasRecoveryReceipt(for: target))
            #expect(backend.states[target]?.effectiveVisible == false)
        }

        try await writer.applyManagedPlan(revealed)
        #expect(try await writer.verifyManagedPlan(revealed))
        for target in SharedSystemItemTrialTarget.allCases {
            #expect(await writer.hasRecoveryReceipt(for: target))
            #expect(backend.states[target] == baselines[target])
        }

        try await writer.applyManagedPlan(hidden)
        #expect(try await writer.verifyManagedPlan(hidden))
        try await writer.applyManagedPlan(restored)
        #expect(try await writer.verifyManagedPlan(restored))
        await writer.finalizeCommittedPlan(restored)
        for target in SharedSystemItemTrialTarget.allCases {
            #expect(!(await writer.hasRecoveryReceipt(for: target)))
            #expect(backend.states[target] == baselines[target])
        }
        #expect(backend.maximumConcurrentMutations == 1)
    }

    @Test("Removing a persistent policy restores and relinquishes its receipt")
    func omittedTargetMeansRestored() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let baseline = try makeNowPlayingSnapshot()
        let backend = FakeSharedSystemItemTrialBackend(states: [.nowPlaying: baseline])
        let writer = SharedSystemItemManualTrialWriter(
            backend: backend, receiptDirectory: directory
        )
        let identifier = SharedSystemItemTrialTarget.nowPlaying.observationIdentifier

        try await writer.applyManagedPlan([identifier: .hidden])
        #expect(await writer.hasRecoveryReceipt(for: .nowPlaying))
        try await writer.applyManagedPlan([:])
        #expect(try await writer.verifyManagedPlan([:]))
        #expect(backend.states[.nowPlaying] == baseline)
        #expect(await writer.hasRecoveryReceipt(for: .nowPlaying))
        await writer.finalizeCommittedPlan([:])
        #expect(!(await writer.hasRecoveryReceipt(for: .nowPlaying)))
    }

    @Test("Managed batch failure restores every snapshot and receipt")
    func managedBatchFailureRollsBackExactly() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let baselines: [SharedSystemItemTrialTarget: SharedSystemItemPreferenceSnapshot] = [
            .nowPlaying: try makeNowPlayingSnapshot(),
            .siri: try makeSiriSnapshot(),
            .timeMachine: try makeTimeMachineSnapshot(),
        ]
        let backend = FakeSharedSystemItemTrialBackend(
            states: baselines, failNextHideVerification: true
        )
        let writer = SharedSystemItemManualTrialWriter(
            backend: backend, receiptDirectory: directory
        )
        let hidden = Dictionary(uniqueKeysWithValues: SharedSystemItemTrialTarget.allCases.map {
            ($0.observationIdentifier, PersistentSystemItemPresentation.hidden)
        })

        await #expect(throws: SharedSystemItemTrialError.verificationFailed) {
            try await writer.applyManagedPlan(hidden)
        }
        for target in SharedSystemItemTrialTarget.allCases {
            #expect(backend.states[target] == baselines[target])
            #expect(!(await writer.hasRecoveryReceipt(for: target)))
        }
    }

    @Test("A failed verification performs one bounded exact rollback")
    func failedVerificationRollsBack() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let baseline = try makeSiriSnapshot()
        let backend = FakeSharedSystemItemTrialBackend(
            states: [.siri: baseline], failNextHideVerification: true
        )
        let writer = SharedSystemItemManualTrialWriter(
            backend: backend, receiptDirectory: directory
        )

        await #expect(throws: SharedSystemItemTrialError.verificationFailed) {
            try await writer.hide(.siri)
        }
        #expect(backend.states[.siri] == baseline)
        #expect(backend.restoreCounts[.siri] == 1)
        #expect(!(await writer.hasRecoveryReceipt(for: .siri)))
    }

    @Test("Restore refuses an intervening preference change and keeps its receipt")
    func staleRestoreRefuses() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let backend = FakeSharedSystemItemTrialBackend(states: [
            .timeMachine: try makeTimeMachineSnapshot()
        ])
        let writer = SharedSystemItemManualTrialWriter(
            backend: backend, receiptDirectory: directory
        )
        _ = try await writer.hide(.timeMachine)
        backend.states[.timeMachine] = try SharedSystemItemPreferenceSnapshot(
            target: .timeMachine,
            values: [
                "menuExtras": try ExactPreferenceValue(["external.menu"]),
                "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(true),
                "NSStatusItem Preferred Position com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(86),
            ],
            effectiveVisible: false
        )

        await #expect(throws: SharedSystemItemTrialError.staleState) {
            try await writer.restore(.timeMachine)
        }
        #expect(!(await writer.verifyAllManagedItemsAreRestorable()))
        #expect(await writer.hasRecoveryReceipt(for: .timeMachine))
        #expect(backend.restoreCounts[.timeMachine, default: 0] == 0)
    }

    private func makeSiriSnapshot() throws -> SharedSystemItemPreferenceSnapshot {
        try SharedSystemItemPreferenceSnapshot(
            target: .siri,
            values: [
                "StatusMenuVisible": try ExactPreferenceValue(true),
                "SiriPrefStashedStatusMenuVisible": try ExactPreferenceValue(nil),
            ],
            effectiveVisible: true
        )
    }

    private func makeImplicitSiriSnapshot() throws -> SharedSystemItemPreferenceSnapshot {
        try SharedSystemItemPreferenceSnapshot(
            target: .siri,
            values: [
                "StatusMenuVisible": try ExactPreferenceValue(nil),
                "SiriPrefStashedStatusMenuVisible": try ExactPreferenceValue(false),
            ],
            effectiveVisible: true
        )
    }

    private func makeNowPlayingSnapshot() throws -> SharedSystemItemPreferenceSnapshot {
        try SharedSystemItemPreferenceSnapshot(
            target: .nowPlaying,
            values: ["NowPlaying": try ExactPreferenceValue(NSNumber(value: UInt64(0x12)))],
            effectiveVisible: true
        )
    }

    private func makeTimeMachineSnapshot() throws -> SharedSystemItemPreferenceSnapshot {
        try SharedSystemItemPreferenceSnapshot(
            target: .timeMachine,
            values: [
                "menuExtras": try ExactPreferenceValue([
                    "first.menu",
                    SharedSystemItemPreferenceSnapshot.timeMachineMenuExtraPath,
                    "last.menu",
                ]),
                "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(true),
                "NSStatusItem Preferred Position com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(86),
            ],
            effectiveVisible: true
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("BlennySharedSystemItemTests-\(UUID().uuidString)")
    }
}

@MainActor
private final class FakeSharedSystemItemTrialBackend: SharedSystemItemTrialBackend,
    @unchecked Sendable
{
    var states: [SharedSystemItemTrialTarget: SharedSystemItemPreferenceSnapshot]
    var restoreCounts: [SharedSystemItemTrialTarget: Int] = [:]
    var ordinaryRevealCounts: [SharedSystemItemTrialTarget: Int] = [:]
    var failOrdinaryRevealVerification = false
    var beforeVisibilityMutation: ((SharedSystemItemTrialTarget, Bool) -> Void)?
    var maximumConcurrentMutations = 0
    private var activeMutations = 0
    private var failNextHideVerification: Bool
    private let normalizeTimeMachineHide: Bool
    private let normalizeTimeMachineAfterFirstAppliedCapture: Bool
    private var timeMachineNormalizationPending = false

    init(
        states: [SharedSystemItemTrialTarget: SharedSystemItemPreferenceSnapshot],
        failNextHideVerification: Bool = false,
        normalizeTimeMachineHide: Bool = false,
        normalizeTimeMachineAfterFirstAppliedCapture: Bool = false
    ) {
        self.states = states
        self.failNextHideVerification = failNextHideVerification
        self.normalizeTimeMachineHide = normalizeTimeMachineHide
        self.normalizeTimeMachineAfterFirstAppliedCapture =
            normalizeTimeMachineAfterFirstAppliedCapture
    }

    func capture(_ target: SharedSystemItemTrialTarget) throws
        -> SharedSystemItemPreferenceSnapshot {
        guard let state = states[target] else {
            throw SharedSystemItemTrialError.unsafeBaseline
        }
        if failNextHideVerification, !state.effectiveVisible {
            failNextHideVerification = false
            return try SharedSystemItemPreferenceSnapshot(
                target: .siri,
                values: [
                    "StatusMenuVisible": try ExactPreferenceValue(true),
                    "SiriPrefStashedStatusMenuVisible": try ExactPreferenceValue(nil),
                ],
                effectiveVisible: true
            )
        }
        if target == .timeMachine, timeMachineNormalizationPending {
            timeMachineNormalizationPending = false
            states[target] = try normalizedTimeMachineHiddenState(from: state)
            return state
        }
        return state
    }

    func setVisibility(
        _ visible: Bool,
        for target: SharedSystemItemTrialTarget
    ) async throws {
        activeMutations += 1
        maximumConcurrentMutations = max(maximumConcurrentMutations, activeMutations)
        defer { activeMutations -= 1 }
        try await Task.sleep(for: .milliseconds(5))
        beforeVisibilityMutation?(target, visible)
        guard let state = states[target] else {
            throw SharedSystemItemTrialError.unsafeBaseline
        }
        if visible {
            guard target == .siri else {
                throw SharedSystemItemTrialError.unsafeBaseline
            }
            states[target] = try state.siriRevealingProposal()
        } else if target == .timeMachine, normalizeTimeMachineAfterFirstAppliedCapture {
            states[target] = try SharedSystemItemPreferenceSnapshot(
                target: .timeMachine, values: state.values, effectiveVisible: false
            )
            timeMachineNormalizationPending = true
        } else if target == .timeMachine, normalizeTimeMachineHide {
            states[target] = try normalizedTimeMachineHiddenState(from: state)
        } else {
            states[target] = try state.hidingProposal()
        }
    }

    func restoreForOrdinaryReveal(_ snapshot: SharedSystemItemPreferenceSnapshot) async throws {
        guard snapshot.target == .timeMachine else {
            try await restoreExact(snapshot)
            return
        }
        ordinaryRevealCounts[snapshot.target, default: 0] += 1
        states[snapshot.target] = snapshot
        if failOrdinaryRevealVerification {
            failOrdinaryRevealVerification = false
            // Simulate late target-local reflow before the writer's readback.
            states[snapshot.target] = try snapshot.hidingProposal()
        }
        timeMachineNormalizationPending = false
    }

    func restoreExact(_ snapshot: SharedSystemItemPreferenceSnapshot) async throws {
        activeMutations += 1
        maximumConcurrentMutations = max(maximumConcurrentMutations, activeMutations)
        defer { activeMutations -= 1 }
        try await Task.sleep(for: .milliseconds(5))
        states[snapshot.target] = snapshot
        if snapshot.target == .timeMachine { timeMachineNormalizationPending = false }
        restoreCounts[snapshot.target, default: 0] += 1
    }

    private func normalizedTimeMachineHiddenState(
        from state: SharedSystemItemPreferenceSnapshot
    ) throws -> SharedSystemItemPreferenceSnapshot {
        let appliedEntries = (try state.values["menuExtras"]?.stringArray() ?? [])
            .filter {
                $0 != SharedSystemItemPreferenceSnapshot.timeMachineMenuExtraPath
            }
        return try SharedSystemItemPreferenceSnapshot(
            target: .timeMachine,
            values: [
                "menuExtras": try ExactPreferenceValue(
                    appliedEntries.isEmpty ? nil : appliedEntries
                ),
                "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(false),
                "NSStatusItem Preferred Position com.apple.menuextra.TimeMachine":
                    try ExactPreferenceValue(nil),
            ],
            effectiveVisible: false
        )
    }
}
#endif
