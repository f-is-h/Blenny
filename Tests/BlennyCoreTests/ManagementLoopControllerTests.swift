import Foundation
import Testing

@testable import BlennyCore

@Suite("Reviewed management loop")
struct ManagementLoopControllerTests {
    private let blenny = "xyz.fi5h.blenny"
    private let usage = "xyz.fi5h.Usage4Claude"
    private let hidden = "pl.maketheweb.cleanshotx"

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
    private var verificationCount = 0
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
