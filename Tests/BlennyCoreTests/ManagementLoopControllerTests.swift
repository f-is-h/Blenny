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

    private var baseline: RevealAllowlistPlan {
        RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: Array(0 ..< 9),
            allowedBundleIdentifiers: [blenny]
        )
    }

    private var revealed: RevealAllowlistPlan {
        RevealAllowlistPlan(
            presentation: .revealed,
            allowedSystemItems: Array(0 ..< 9),
            allowedBundleIdentifiers: [blenny, usage]
        )
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

    init(verificationResults: [Bool] = []) {
        self.verificationResults = verificationResults
    }

    func applyBaselineReplacement(with plan: RevealAllowlistPlan) async throws {
        appliedPlans.append(plan)
        activePlan = plan
    }

    func applySessionTransition(with plan: RevealAllowlistPlan) async throws {
        appliedPlans.append(plan)
        activePlan = plan
    }

    func verifyActivePlan(_ expected: RevealAllowlistPlan) async throws -> Bool {
        if !verificationResults.isEmpty {
            return verificationResults.removeFirst()
        }
        return activePlan == expected
    }

    func restoreAndStop() async {
        guard activePlan != nil else { return }
        restoreCount += 1
        activePlan = nil
    }

    func connectionInvalidated() async {
        connectionInvalidationCount += 1
        activePlan = nil
    }

    func activePlanSnapshot() async -> RevealAllowlistPlan? {
        activePlan
    }
}
