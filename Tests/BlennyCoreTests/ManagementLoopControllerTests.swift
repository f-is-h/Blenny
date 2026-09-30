import Foundation
import Testing

@testable import BlennyCore

@Suite("Reviewed management loop")
struct ManagementLoopControllerTests {
    private let blenny = "xyz.fi5h.blenny"
    private let usage = "xyz.fi5h.Usage4Claude"
    private let hidden = "pl.maketheweb.cleanshotx"

    @Test("One additions-only expansion reuses the writer and retains both policy plans")
    func passThroughExpansion() async throws {
        let writer = ManagementTestWriter()
        let loop = ManagementLoopController(writerProvider: { writer })
        _ = await loop.recover(acceptedPolicy: try policy(enabled: true), baseline: baseline)
        let expansion = try #require(try PassThroughExpansion.prepare(
            baseline: baseline, reveal: revealed,
            acceptedBundleIdentifiers: [blenny, usage, hidden],
            launchedBundleIdentifiers: ["com.example.New", hidden, usage]
        ))
        try await loop.expandPassThrough(
            from: baseline, to: expansion.baseline,
            addedBundleIdentifiers: Set(expansion.addedBundleIdentifiers)
        )
        #expect(await writer.appliedPlans == [baseline, expansion.baseline])
        #expect(await writer.verificationCount == 2)
        #expect(await loop.state == .active(expansion.baseline.fingerprint))
        #expect(await writer.restoreCount == 0)
        #expect(try PassThroughExpansion.prepare(
            baseline: expansion.baseline, reveal: expansion.reveal,
            acceptedBundleIdentifiers: [blenny, usage, hidden],
            launchedBundleIdentifiers: ["com.example.New"]
        ) == nil)
        try await loop.beginOrdinaryReveal(expansion.reveal)
        #expect(!expansion.reveal.allowedBundleIdentifiers.contains(hidden))
        try await loop.endOrdinaryReveal(expansion.baseline)
        await loop.terminate()
        #expect(await writer.restoreCount == 1)
    }

    @Test("Expansion during Reveal retains presentation and returns to the expanded baseline")
    func passThroughDuringReveal() async throws {
        let writer = ManagementTestWriter()
        let loop = ManagementLoopController(writerProvider: { writer })
        _ = await loop.recover(acceptedPolicy: try policy(enabled: true), baseline: baseline)
        try await loop.beginOrdinaryReveal(revealed)
        let expansion = try #require(try PassThroughExpansion.prepare(
            baseline: baseline, reveal: revealed,
            acceptedBundleIdentifiers: [blenny, usage, hidden],
            launchedBundleIdentifiers: ["com.example.New"]
        ))
        try await loop.expandPassThrough(
            from: revealed, to: expansion.reveal,
            addedBundleIdentifiers: Set(expansion.addedBundleIdentifiers)
        )
        #expect(await loop.state == .ordinaryRevealSession(expansion.reveal.fingerprint))
        #expect(await writer.restoreCount == 0)
        try await loop.endOrdinaryReveal(expansion.baseline)
        #expect(await loop.activePlanSnapshot() == expansion.baseline)
        #expect(!expansion.baseline.allowedBundleIdentifiers.contains(usage))
        #expect(!expansion.baseline.allowedBundleIdentifiers.contains(hidden))
    }

    @Test("Expansion verification failure stops once without retry or writer recreation")
    func passThroughVerificationFailure() async throws {
        let writer = ManagementTestWriter(verificationResults: [true, false])
        let loop = ManagementLoopController(writerProvider: { writer })
        _ = await loop.recover(acceptedPolicy: try policy(enabled: true), baseline: baseline)
        let expanded = RevealAllowlistPlan(
            presentation: .baseline, allowedSystemItems: baseline.allowedSystemItems,
            allowedBundleIdentifiers: baseline.allowedBundleIdentifiers + ["com.example.New"]
        )
        await #expect(throws: ManagementLoopError.activationCouldNotBeVerified) {
            try await loop.expandPassThrough(
                from: baseline, to: expanded, addedBundleIdentifiers: ["com.example.New"]
            )
        }
        #expect(await writer.appliedPlans == [baseline, expanded])
        #expect(await writer.verificationCount == 2)
        #expect(await writer.restoreCount == 1)
        #expect(await loop.activePlanSnapshot() == nil)
        await #expect(throws: ManagementLoopError.managementIsNotActive) {
            try await loop.expandPassThrough(
                from: baseline, to: expanded, addedBundleIdentifiers: ["com.example.New"]
            )
        }
        #expect(await writer.appliedPlans.count == 2)
    }

    @Test("Late expansion verification cannot resurrect a stopped writer")
    func passThroughStopRace() async throws {
        let barrier = VerificationBarrier()
        let writer = ManagementTestWriter(verificationBarrier: barrier)
        let loop = ManagementLoopController(writerProvider: { writer })
        _ = await loop.recover(acceptedPolicy: try policy(enabled: true), baseline: baseline)
        let expanded = RevealAllowlistPlan(
            presentation: .baseline, allowedSystemItems: baseline.allowedSystemItems,
            allowedBundleIdentifiers: baseline.allowedBundleIdentifiers + ["com.example.New"]
        )
        let update = Task {
            try await loop.expandPassThrough(
                from: baseline, to: expanded, addedBundleIdentifiers: ["com.example.New"]
            )
        }
        await barrier.waitUntilEntered()
        await #expect(throws: ManagementLoopError.managementIsNotActive) {
            try await loop.beginOrdinaryReveal(revealed)
        }
        await loop.stop()
        await barrier.release()
        await #expect(throws: ManagementLoopError.staleLifecycleGeneration) { try await update.value }
        #expect(await loop.state == .stopped)
        #expect(await writer.restoreCount == 1)
        #expect(await loop.activePlanSnapshot() == nil)
    }

    @Test("Stopped management cannot acquire a writer from an additions-only event")
    func passThroughDoesNotResume() async throws {
        let provider = ManagementWriterProvider()
        let loop = ManagementLoopController(writerProvider: { await provider.makeWriter() })
        _ = await loop.recover(acceptedPolicy: try policy(enabled: false), baseline: nil)
        let expanded = RevealAllowlistPlan(
            presentation: .baseline, allowedSystemItems: baseline.allowedSystemItems,
            allowedBundleIdentifiers: baseline.allowedBundleIdentifiers + ["com.example.New"]
        )
        await #expect(throws: ManagementLoopError.managementIsNotActive) {
            try await loop.expandPassThrough(
                from: baseline, to: expanded, addedBundleIdentifiers: ["com.example.New"]
            )
        }
        #expect(await provider.creationCount == 0)
    }

    @Test("Confirmed unrestricted pause is truthful and non-alarming; cleanup failure remains an error")
    func statusSeverity() throws {
        let pause = try #require(ManagementLoopState.failClosedUnrestricted(
            ManagementLifecycleEvent.applicationLaunched("com.example.New").reason
        ).statusNotice(persistedManagementEnabled: true))
        #expect(!pause.isError)
        #expect(pause.message.contains("paused"))
        #expect(pause.message.contains("restrictions are removed"))
        #expect(pause.message.contains("com.example.New"))
        #expect(pause.message.contains("Resume"))
        #expect(!pause.message.contains("frozen management scope"))
        #expect(ManagementLoopState.failClosedUnrestricted("stopped").statusNotice(
            persistedManagementEnabled: false
        ) == nil)
        #expect(ManagementLoopState.unsupportedRuntimeContract("unknown").statusNotice(
            persistedManagementEnabled: true
        )?.isError == false)
        #expect(ManagementLoopState.restorationFailed("writer retained").statusNotice(
            persistedManagementEnabled: true
        )?.isError == true)
        #expect(ManagementLoopState.restorationFailed("writer retained")
            .requiresImmediateProcessExit)
        #expect(!ManagementLoopState.failClosedUnrestricted("stopped")
            .requiresImmediateProcessExit)
    }

    @Test("Accepted app churn leaves the exact active assertion intact")
    func acceptedAppLifecycleIsNonMutating() async throws {
        let writer = ManagementTestWriter()
        let loop = ManagementLoopController(writerProvider: { writer })
        _ = await loop.recover(acceptedPolicy: try policy(enabled: true), baseline: baseline)
        for event in [
            ManagementLifecycleEvent.applicationLaunched(usage),
            .applicationTerminated(usage), .applicationLaunched(hidden),
            .applicationTerminated(hidden),
        ] {
            if ManagementLifecyclePolicy.invalidates(
                event, managedBundleIdentifiers: [blenny, usage, hidden],
                allowedBundleIdentifiers: Set(baseline.allowedBundleIdentifiers),
                blennyBundleIdentifier: blenny
            ) {
                await loop.failClosed(event.reason)
            }
        }
        #expect(await loop.state == .active(baseline.fingerprint))
        #expect(await writer.appliedPlans == [baseline])
        #expect(await writer.restoreCount == 0)
        #expect(await loop.activePlanSnapshot() == baseline)
        await loop.terminate()
        #expect(await writer.restoreCount == 1)
    }

    @Test("Stopped startup never creates a writer")
    func stoppedStartupIsPure() async throws {
        let provider = ManagementWriterProvider()
        let loop = ManagementLoopController(
            writerProvider: { await provider.makeWriter() }
        )

        #expect(await loop.recover(
            acceptedPolicy: try policy(enabled: false),
            baseline: baseline
        ) == .stopped)
        #expect(await provider.creationCount == 0)
        #expect(await loop.activePlanSnapshot() == nil)
    }

    @Test("Enabled startup activates and verifies one exact baseline")
    func enabledStartupRecoversManagement() async throws {
        let writer = ManagementTestWriter()
        let loop = ManagementLoopController(writerProvider: { writer })

        #expect(await loop.recover(
            acceptedPolicy: try policy(enabled: true),
            baseline: baseline
        ) == .active(baseline.fingerprint))
        #expect(await writer.appliedPlans == [baseline])
        #expect(await loop.activePlanSnapshot() == baseline)
    }

    @Test("Unsupported writer fails closed without an assertion")
    func unsupportedRuntimeFailsClosed() async throws {
        let loop = ManagementLoopController(
            writerProvider: { throw ManagementLoopTestError.unsupported }
        )

        let result = await loop.recover(
            acceptedPolicy: try policy(enabled: true),
            baseline: baseline
        )
        guard case .failClosedUnrestricted = result else {
            Issue.record("Expected fail-closed unrestricted state")
            return
        }
        #expect(await loop.activePlanSnapshot() == nil)
    }

    @Test("Verification failure clears the active assertion")
    func verificationFailureFailsClosed() async throws {
        let writer = ManagementTestWriter(verificationResults: [false])
        let loop = ManagementLoopController(writerProvider: { writer })

        let result = await loop.recover(
            acceptedPolicy: try policy(enabled: true),
            baseline: baseline
        )
        guard case .failClosedUnrestricted = result else {
            Issue.record("Expected fail-closed unrestricted state")
            return
        }
        #expect(await writer.restoreCount == 1)
        #expect(await loop.activePlanSnapshot() == nil)
    }

    @Test("Fail-closed Stop can confirm unrestricted state without creating a backend")
    func failClosedStopNeedsNoBackend() async throws {
        let provider = ManagementWriterProvider()
        let loop = ManagementLoopController(
            writerProvider: { await provider.makeWriter() }
        )
        await loop.failClosed("unsupported runtime")

        let restoredWriter = try await loop.writerForTransaction()
        await restoredWriter.restoreAndStop()
        #expect(await restoredWriter.activePlanSnapshot() == nil)
        #expect(await provider.creationCount == 0)
    }

    @Test("Explicit reviewed activation can acquire a fresh writer after failed startup")
    func explicitResumeAfterFailedStartup() async throws {
        let provider = ManagementWriterProvider()
        let loop = ManagementLoopController(writerProvider: { await provider.makeWriter() })
        await loop.failClosed("permission unavailable at startup")
        let writer = try await loop.writerForReviewedActivation()
        try await writer.applyBaselineReplacement(with: baseline)
        try await loop.synchronizeCommittedPolicy(policy(enabled: true), baseline: baseline)
        #expect(await loop.state == .active(baseline.fingerprint))
        #expect(await provider.creationCount == 1)
        await loop.terminate()
        #expect(await loop.activePlanSnapshot() == nil)
    }

    @Test("Explicit Resume cannot reconnect after termination or connection invalidation", arguments: [false, true])
    func resumeDoesNotBypassLifecycleBoundary(terminating: Bool) async throws {
        let provider = ManagementWriterProvider()
        let loop = ManagementLoopController(writerProvider: { await provider.makeWriter() })
        if terminating { await loop.terminate() } else { await loop.connectionInvalidated() }
        await #expect(throws: ManagementLoopError.restartRequired) {
            _ = try await loop.writerForReviewedActivation()
        }
        _ = await loop.recover(acceptedPolicy: try policy(enabled: true), baseline: baseline)
        #expect(await provider.creationCount == 0)
        #expect(await loop.activePlanSnapshot() == nil)
    }

    @Test("Ordinary reveal excludes Hidden and returns to baseline")
    func ordinaryRevealReturnsToBaseline() async throws {
        let writer = ManagementTestWriter()
        let loop = ManagementLoopController(writerProvider: { writer })
        _ = await loop.recover(
            acceptedPolicy: try policy(enabled: true),
            baseline: baseline
        )

        try await loop.beginOrdinaryReveal(revealed)
        #expect(!revealed.allowedBundleIdentifiers.contains(hidden))
        #expect(revealed.allowedBundleIdentifiers.contains(usage))
        try await loop.endOrdinaryReveal(baseline)
        #expect(await loop.state == .active(baseline.fingerprint))
        #expect(await loop.activePlanSnapshot() == baseline)
    }

    @Test("Apply state rejects an overlapping ordinary reveal")
    func applyAndRevealCannotOverlap() async throws {
        let writer = ManagementTestWriter()
        let loop = ManagementLoopController(writerProvider: { writer })
        _ = await loop.recover(
            acceptedPolicy: try policy(enabled: true),
            baseline: baseline
        )

        await loop.beginTransaction()
        #expect(await loop.state == .applying)
        await #expect(throws: ManagementLoopError.managementIsNotActive) {
            try await loop.beginOrdinaryReveal(revealed)
        }
        #expect(await writer.appliedPlans == [baseline])
    }

    @Test("Connection invalidation and termination are idempotent cleanup")
    func lifecycleCleanupIsIdempotent() async throws {
        let writer = ManagementTestWriter()
        let loop = ManagementLoopController(writerProvider: { writer })
        _ = await loop.recover(
            acceptedPolicy: try policy(enabled: true),
            baseline: baseline
        )

        await loop.connectionInvalidated()
        await loop.connectionInvalidated()
        #expect(await loop.activePlanSnapshot() == nil)
        #expect(await writer.connectionInvalidationCount == 1)

        let terminationWriter = ManagementTestWriter()
        let terminationLoop = ManagementLoopController(
            writerProvider: { terminationWriter }
        )
        _ = await terminationLoop.recover(
            acceptedPolicy: try policy(enabled: true),
            baseline: baseline
        )
        await terminationLoop.terminate()
        await terminationLoop.terminate()
        #expect(await terminationLoop.activePlanSnapshot() == nil)
        #expect(await terminationWriter.restoreCount == 1)
    }

    @Test("Normal quit restores assertions and keeps the saved Resume choice for relaunch")
    func normalQuitRetainsResumeIntent() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BlennyRelaunchTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try PersistentBundlePolicyStore(
            policyURL: directory.appendingPathComponent("bundle-policies.json"),
            backupURL: directory.appendingPathComponent("bundle-policies.previous.blenny-backup.json")
        )
        let enabled = try policy(enabled: true)
        try await store.save(enabled)

        let firstWriter = ManagementTestWriter()
        let firstLoop = ManagementLoopController(writerProvider: { firstWriter })
        #expect(await firstLoop.recover(acceptedPolicy: enabled, baseline: baseline)
            == .active(baseline.fingerprint))
        await firstLoop.terminate()
        #expect(await firstWriter.restoreCount == 1)
        #expect(await firstLoop.activePlanSnapshot() == nil)

        let savedForRelaunch = try #require(try await store.load())
        #expect(savedForRelaunch.managementEnabled)
        let secondWriter = ManagementTestWriter()
        let secondLoop = ManagementLoopController(writerProvider: { secondWriter })
        #expect(await secondLoop.recover(acceptedPolicy: savedForRelaunch, baseline: baseline)
            == .active(baseline.fingerprint))
        await secondLoop.terminate()

        let stopped = try enabled.settingManagementEnabled(false)
        try await store.save(stopped)
        let stoppedWriter = ManagementTestWriter()
        let stoppedLoop = ManagementLoopController(writerProvider: { stoppedWriter })
        #expect(await stoppedLoop.recover(
            acceptedPolicy: try #require(try await store.load()), baseline: nil
        ) == .stopped)
        #expect(await stoppedWriter.appliedPlans.isEmpty)
    }

    @Test("Ordinary reveal activation failure preserves a verified baseline")
    func failedRevealPreservesBaseline() async throws {
        let writer = ManagementTestWriter(failReveal: true)
        let loop = ManagementLoopController(writerProvider: { writer })
        _ = await loop.recover(acceptedPolicy: try policy(enabled: true), baseline: baseline)
        await #expect(throws: ManagementLoopTestError.unsupported) {
            try await loop.beginOrdinaryReveal(revealed)
        }
        #expect(await loop.state == .active(baseline.fingerprint))
        #expect(await loop.activePlanSnapshot() == baseline)
        #expect(await writer.restoreCount == 0)
    }

    @Test("A throwing reveal verifier clears the assertion instead of reporting active")
    func throwingRevealVerificationFailsClosed() async throws {
        let writer = ManagementTestWriter(throwVerificationOnCall: 2)
        let loop = ManagementLoopController(writerProvider: { writer })
        _ = await loop.recover(acceptedPolicy: try policy(enabled: true), baseline: baseline)
        await #expect(throws: ManagementLoopTestError.unsupported) {
            try await loop.beginOrdinaryReveal(revealed)
        }
        guard case .failClosedUnrestricted = await loop.state else {
            Issue.record("Throwing verification must fail closed")
            return
        }
        #expect(await loop.activePlanSnapshot() == nil)
    }

    @Test("Native events and Blenny clicks with native overflow share one writer and exclude Hidden", arguments: [false, true])
    func nativeSessionIntegration(useBlennyButton: Bool) async throws {
        let writer = ManagementTestWriter()
        let loop = ManagementLoopController(writerProvider: { writer })
        let initial = await loop.recover(acceptedPolicy: try policy(enabled: true), baseline: baseline)
        var controls = OrdinaryRevealCoordinator()
        let controlIdentifier = UUID()
        controls.synchronize(initial, hasRevealableBundles: true)
        controls.observe(.init(isPresent: true, presentationState: .collapsed, observationAvailable: true, controlIdentifier: controlIdentifier))
        if useBlennyButton {
            controls.requestBlennyToggle()
        } else {
            controls.observe(.init(isPresent: true, presentationState: .expanded, observationAvailable: true, controlIdentifier: controlIdentifier), source: .valueChange)
        }
        #expect(controls.takePendingTransition()?.presentation == .revealed)
        try await loop.beginOrdinaryReveal(revealed)
        controls.synchronize(await loop.state, hasRevealableBundles: true)
        controls.observe(.init(isPresent: true, presentationState: .expanded, observationAvailable: true, controlIdentifier: controlIdentifier), source: .valueChange)
        controls.observe(.init(isPresent: true, presentationState: .collapsed, observationAvailable: true, controlIdentifier: controlIdentifier), source: .valueChange)
        #expect(controls.takePendingTransition()?.presentation == .baseline)
        try await loop.endOrdinaryReveal(baseline)
        controls.synchronize(await loop.state, hasRevealableBundles: true)
        #expect(await writer.appliedPlans == [baseline, revealed, baseline])
        #expect(await writer.appliedPlans.allSatisfy { !$0.allowedBundleIdentifiers.contains(hidden) })
        await loop.terminate()
        #expect(await loop.activePlanSnapshot() == nil)
    }

    @Test("All macOS 27 localized labels retain native takeover and collapse", arguments: NativeOverflowLocaleFixture.all)
    func localizedNativeTakeover(labels: NativeOverflowLocaleFixture.Labels) async throws {
        let identifier = UUID()
        func snapshot(_ label: String) -> NativeOverflowObservationSnapshot {
            let classification = NativeOverflowClassifier.classify(
                ownerBundleIdentifier: "com.apple.MenuBarAgent", role: "AXButton",
                title: nil, itemDescription: label, accessibilityIdentifier: nil
            )
            #expect(classification.classification == .nativeOverflowPresentationControl)
            let state = NativeOverflowPresentationStateClassifier.classify(
                title: nil, itemDescription: label, accessibilityIdentifier: nil
            )
            #expect(state != .unknown)
            return .observed(states: [state], controlIdentifier: identifier)
        }
        let writer = ManagementTestWriter()
        let loop = ManagementLoopController(writerProvider: { writer })
        var controls = OrdinaryRevealCoordinator()
        controls.synchronize(
            await loop.recover(acceptedPolicy: try policy(enabled: true), baseline: baseline),
            hasRevealableBundles: true
        )
        controls.requestBlennyToggle()
        #expect(controls.takePendingTransition()?.owner == .blennyFallback)
        try await loop.beginOrdinaryReveal(revealed)
        controls.synchronize(await loop.state, hasRevealableBundles: true)
        controls.observe(snapshot(labels.collapsed), source: .layout)
        controls.observe(snapshot(labels.expanded), source: .valueChange)
        #expect(controls.takePendingTransition() == nil)
        #expect(!ManagementStatusPresentation(
            state: await loop.state, hasRevealableBundles: true, isBusy: false,
            nativeOverflow: controls.observation
        ).showsInlineArrow)
        controls.observe(snapshot(labels.collapsed), source: .valueChange)
        #expect(controls.takePendingTransition() == .init(
            presentation: .baseline, owner: .nativeOverflow
        ))
        try await loop.endOrdinaryReveal(baseline)
        controls.synchronize(await loop.state, hasRevealableBundles: true)
        #expect(await writer.appliedPlans == [baseline, revealed, baseline])
        #expect(await writer.appliedPlans.allSatisfy { !$0.allowedBundleIdentifiers.contains(hidden) })
        await loop.terminate()
    }

    @Test("Late successful verification cannot resurrect management after connection loss")
    func lateVerificationAfterDisconnect() async throws {
        let barrier = VerificationBarrier()
        let writer = ManagementTestWriter(verificationBarrier: barrier)
        let loop = ManagementLoopController(writerProvider: { writer })
        _ = await loop.recover(acceptedPolicy: try policy(enabled: true), baseline: baseline)
        let revealPlan = revealed
        let transition = Task { try await loop.beginOrdinaryReveal(revealPlan) }
        await barrier.waitUntilEntered()
        await loop.connectionInvalidated()
        await barrier.release()
        await #expect(throws: ManagementLoopError.activationCouldNotBeVerified) {
            try await transition.value
        }
        guard case .failClosedUnrestricted = await loop.state else {
            Issue.record("A late verification result must not report an active session")
            return
        }
        #expect(await loop.activePlanSnapshot() == nil)
    }

    private var baseline: RevealAllowlistPlan {
        RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: Array(0 ..< 9),
            allowedBundleIdentifiers: [blenny]
        )
    }

    @Test("Lifecycle invalidation rejects a stale writer lease and never recreates it automatically")
    func staleLifecycleLease() async throws {
        let provider = ManagementWriterProvider()
        let loop = ManagementLoopController(writerProvider: { await provider.makeWriter() })
        _ = await loop.recover(acceptedPolicy: try policy(enabled: true), baseline: baseline)
        let before = await loop.generationSnapshot()
        await loop.failClosed("display changed")
        await loop.failClosed("display notification duplicate")
        #expect(await loop.activePlanSnapshot() == nil)
        await #expect(throws: ManagementLoopError.staleLifecycleGeneration) {
            _ = try await loop.writerForReviewedActivation(expectedGeneration: before)
        }
        #expect(await provider.creationCount == 1)
        // Only a new, explicitly reviewed action can acquire the next lease.
        let current = await loop.generationSnapshot()
        _ = try await loop.writerForReviewedActivation(expectedGeneration: current)
        #expect(await provider.creationCount == 2)
        await loop.terminate()
    }

    @Test("Lifecycle cleanup during reveal verification cannot resurrect the assertion")
    func lifecycleDuringVerification() async throws {
        let barrier = VerificationBarrier()
        let writer = ManagementTestWriter(verificationBarrier: barrier)
        let loop = ManagementLoopController(writerProvider: { writer })
        _ = await loop.recover(acceptedPolicy: try policy(enabled: true), baseline: baseline)
        let plan = revealed
        let transition = Task { try await loop.beginOrdinaryReveal(plan) }
        await barrier.waitUntilEntered()
        await loop.failClosed("system sleep")
        await barrier.release()
        await #expect(throws: ManagementLoopError.activationCouldNotBeVerified) {
            try await transition.value
        }
        #expect(await loop.activePlanSnapshot() == nil)
        #expect(await writer.restoreCount == 1)
    }

    private var revealed: RevealAllowlistPlan {
        RevealAllowlistPlan(
            presentation: .revealed,
            allowedSystemItems: Array(0 ..< 9),
            allowedBundleIdentifiers: [blenny, usage]
        )
    }

    @Test("Native presentation loss never adds a writer transition or extends the authorized reveal", arguments: [false, true])
    func nativeHandoffWriterSequence(firstAppearance: Bool) async throws {
        let writer = ManagementTestWriter()
        let loop = ManagementLoopController(writerProvider: { writer })
        var coordinator = OrdinaryRevealCoordinator()
        let state = await loop.recover(acceptedPolicy: try policy(enabled: true), baseline: baseline)
        coordinator.synchronize(state, hasRevealableBundles: true)
        let identifier = UUID()
        coordinator.observe(.observed(
            states: firstAppearance ? [] : [.collapsed], controlIdentifier: firstAppearance ? nil : identifier
        ))
        coordinator.observe(.observed(states: [.expanded], controlIdentifier: identifier), source: .layout)
        #expect(coordinator.takePendingTransition()?.presentation == .revealed)
        coordinator.observe(.unavailable, source: .layout)
        try await loop.beginOrdinaryReveal(revealed)
        coordinator.synchronize(await loop.state, hasRevealableBundles: true)
        let session = try #require(coordinator.sessionIdentifier)
        coordinator.observe(.observed(states: [.expanded], controlIdentifier: UUID()), source: .sample)
        #expect(coordinator.takePendingTransition() == nil)
        #expect(coordinator.entryPoint == .blennyFallback)
        #expect(await writer.appliedPlans == [baseline, revealed])
        #expect(!(await writer.activePlanSnapshot())!.allowedBundleIdentifiers.contains(hidden))
        coordinator.requestTimeout(session: session)
        coordinator.observe(.unavailable, source: .layout)
        #expect(coordinator.takePendingTransition()?.presentation == .baseline)
        try await loop.endOrdinaryReveal(baseline)
        coordinator.synchronize(await loop.state, hasRevealableBundles: true)
        #expect(await writer.appliedPlans == [baseline, revealed, baseline])
        #expect(coordinator.sessionIdentifier == nil)
        await loop.terminate()
        #expect(await loop.activePlanSnapshot() == nil)
    }

    private func policy(enabled: Bool) throws -> PersistentBundlePolicyDocument {
        try PersistentBundlePolicyDocument(
            managementEnabled: enabled,
            policies: [
                .init(bundleIdentifier: blenny, policy: .visible),
                .init(bundleIdentifier: usage, policy: .revealable),
                .init(bundleIdentifier: hidden, policy: .hidden),
            ]
        )
    }

    @Test("Unconfirmed cleanup is terminal and is never reported as unrestricted")
    func unconfirmedCleanup() async throws {
        let writer = ManagementTestWriter(retainOnRestore: true)
        let loop = ManagementLoopController(writerProvider: { writer })
        _ = await loop.recover(acceptedPolicy: try policy(enabled: true), baseline: baseline)
        await loop.failClosed("sleep")
        #expect(await loop.state == .restorationFailed("sleep"))
        #expect(await loop.activePlanSnapshot() == baseline)
        await loop.failClosed("duplicate")
        await loop.connectionInvalidated()
        #expect(await writer.restoreCount == 1)
        await #expect(throws: ManagementLoopError.restartRequired) {
            _ = try await loop.writerForReviewedActivation()
        }
        await loop.terminate()
        await loop.terminate()
        #expect(await writer.restoreCount == 2)
        #expect(await loop.state == .restorationFailed("application termination restored assertions"))
    }
}

private enum ManagementLoopTestError: Error {
    case unsupported
}

private actor ManagementWriterProvider {
    private(set) var creationCount = 0

    func makeWriter() -> any PolicyAssertionWriting {
        creationCount += 1
        return ManagementTestWriter()
    }
}

private actor ManagementTestWriter: PolicyAssertionWriting {
    private(set) var appliedPlans: [RevealAllowlistPlan] = []
    private(set) var restoreCount = 0
    private(set) var connectionInvalidationCount = 0
    private var activePlan: RevealAllowlistPlan?
    private var verificationResults: [Bool]
    private let failReveal: Bool
    private let throwVerificationOnCall: Int?
    private(set) var verificationCount = 0
    private let verificationBarrier: VerificationBarrier?
    private let retainOnRestore: Bool

    init(verificationResults: [Bool] = [], failReveal: Bool = false, throwVerificationOnCall: Int? = nil, verificationBarrier: VerificationBarrier? = nil, retainOnRestore: Bool = false) {
        self.verificationResults = verificationResults
        self.failReveal = failReveal
        self.throwVerificationOnCall = throwVerificationOnCall
        self.verificationBarrier = verificationBarrier
        self.retainOnRestore = retainOnRestore
    }

    func applyBaselineReplacement(with plan: RevealAllowlistPlan) async throws {
        appliedPlans.append(plan)
        activePlan = plan
    }

    func applySessionTransition(with plan: RevealAllowlistPlan) async throws {
        if failReveal && plan.presentation == .revealed { throw ManagementLoopTestError.unsupported }
        appliedPlans.append(plan)
        activePlan = plan
    }

    func verifyActivePlan(_ expected: RevealAllowlistPlan) async throws -> Bool {
        verificationCount += 1
        if verificationCount == throwVerificationOnCall { throw ManagementLoopTestError.unsupported }
        if verificationCount == 2, let verificationBarrier {
            await verificationBarrier.enter()
            return true
        }
        if !verificationResults.isEmpty {
            return verificationResults.removeFirst()
        }
        return activePlan == expected
    }

    func restoreAndStop() async {
        guard activePlan != nil else { return }
        restoreCount += 1
        if !retainOnRestore { activePlan = nil }
    }

    func connectionInvalidated() async {
        connectionInvalidationCount += 1
        activePlan = nil
    }

    func activePlanSnapshot() async -> RevealAllowlistPlan? {
        activePlan
    }
}

private actor VerificationBarrier {
    private var entered = false
    private var enteredWaiter: CheckedContinuation<Void, Never>?
    private var completion: CheckedContinuation<Void, Never>?

    func enter() async {
        entered = true
        enteredWaiter?.resume()
        enteredWaiter = nil
        await withCheckedContinuation { completion = $0 }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { enteredWaiter = $0 }
    }

    func release() {
        completion?.resume()
        completion = nil
    }
}
