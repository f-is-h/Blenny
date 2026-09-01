#if DEBUG
import Foundation
import Testing
@testable import BlennyCore

@Suite("Debug self-position validation")
@MainActor
struct SelfPositionValidationTests {
    private let runtime = RuntimeEnvironment(macOSVersion: "27.0.0", buildVersion: "26A5416b", architecture: "arm64")

    private func baseline() throws -> SelfPositionSnapshot {
        SelfPositionSnapshot(domain: SelfPositionPlan.bundleIdentifier,
            persistent: ["NSStatusItem Preferred Position Item-0": try SelfPositionSnapshot.encodeValue(510),
                         "NSStatusItem Visible Item-1": try SelfPositionSnapshot.encodeValue(true)], registration: [:])
    }

    @Test("Snapshot serialization preserves values, absence and deterministic fingerprints")
    func serialization() throws {
        let original = try baseline()
        let plan = try SelfPositionPlan(baseline: original, runtime: runtime)
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(SelfPositionPlan.self, from: data)
        try decoded.validate()
        #expect(decoded == plan)
        #expect(try decoded.fingerprint == plan.fingerprint)
        #expect(decoded.baseline.persistent[SelfPositionPlan.positionKey] == nil)
        for value: Any in [500, 500.5, true, "sample"] {
            let encoded = try SelfPositionSnapshot.encodeValue(value)
            #expect(try SelfPositionSnapshot.encodeValue(SelfPositionSnapshot.decodeValue(encoded)) == encoded)
        }
    }

    @Test("Malformed scope, unknown runtime and occupied keys fail before mutation")
    func invalidPlans() throws {
        #expect(throws: SelfPositionValidationError.invalidScope) {
            try SelfPositionPlan(baseline: SelfPositionSnapshot(domain: "com.apple.MenuBarAgent", persistent: [:], registration: [:]), runtime: runtime)
        }
        #expect(throws: SelfPositionValidationError.invalidScope) {
            try SelfPositionPlan(baseline: baseline(), runtime: RuntimeEnvironment(macOSVersion: "27.0.0", buildVersion: "unknown", architecture: "arm64"))
        }
        #expect(throws: SelfPositionValidationError.invalidScope) {
            try SelfPositionSnapshot(domain: SelfPositionPlan.bundleIdentifier, persistent: ["other": Data()], registration: [:]).validate()
        }
        #expect(throws: SelfPositionValidationError.unsupportedValue) {
            try SelfPositionSnapshot.encodeValue(["unexpected": true])
        }
        #expect(throws: SelfPositionValidationError.unsupportedValue) {
            try SelfPositionSnapshot.encodeValue(Double.infinity)
        }
        let occupied = SelfPositionSnapshot(domain: SelfPositionPlan.bundleIdentifier,
            persistent: [SelfPositionPlan.positionKey: try SelfPositionSnapshot.encodeValue(600)], registration: [:])
        #expect(throws: SelfPositionValidationError.occupiedExperimentKey) {
            try SelfPositionPlan(baseline: occupied, runtime: runtime)
        }
    }

    @Test("Preview plan construction does not call a backend or writer")
    func previewHasNoWriter() throws {
        let backend = FakeSelfPositionBackend(state: try baseline())
        _ = try SelfPositionPlan(baseline: backend.capture(), runtime: runtime)
        #expect(backend.events == ["read"])
    }

    @Test("Confirmation and fresh-state gates reject before apply")
    func confirmationAndStaleness() async throws {
        let plan = try SelfPositionPlan(baseline: baseline(), runtime: runtime)
        for stale in [false, true] {
            let backend = FakeSelfPositionBackend(state: plan.baseline)
            if stale { backend.state = SelfPositionSnapshot(domain: SelfPositionPlan.bundleIdentifier, persistent: [:], registration: [:]) }
            let lease = SelfPositionValidationLease(backend: backend, plan: plan,
                confirmation: stale ? try plan.fingerprint : "wrong")
            let writer = RevealAssertionWriter(factory: SelfPositionValidationFactory(lease: lease))
            await #expect(throws: stale ? SelfPositionValidationError.staleState : .unconfirmedPlan) {
                try await writer.replace(with: SelfPositionPlan.writerToken)
            }
            #expect(!backend.events.contains("apply"))
            #expect(!backend.events.contains("restore"))
        }
    }

    @Test("Only the exact self-only carrier can reach the local lease")
    func noCrossAppOrReveal() throws {
        let plan = try SelfPositionPlan(baseline: baseline(), runtime: runtime)
        let backend = FakeSelfPositionBackend(state: plan.baseline)
        let lease = SelfPositionValidationLease(backend: backend, plan: plan, confirmation: try plan.fingerprint)
        let factory = SelfPositionValidationFactory(lease: lease)
        for other in [
            RevealAllowlistPlan(presentation: .revealed, allowedSystemItems: [], allowedBundleIdentifiers: [SelfPositionPlan.bundleIdentifier]),
            RevealAllowlistPlan(presentation: .baseline, allowedSystemItems: [0], allowedBundleIdentifiers: [SelfPositionPlan.bundleIdentifier]),
            RevealAllowlistPlan(presentation: .baseline, allowedSystemItems: [], allowedBundleIdentifiers: ["com.example.Other"])
        ] {
            #expect(throws: SelfPositionValidationError.invalidScope) { try factory.makeCandidate(for: other) }
        }
        #expect(backend.events.isEmpty)
    }

    @Test("The existing serial writer applies once and restores exact state once")
    func normalRestoration() async throws {
        let plan = try SelfPositionPlan(baseline: baseline(), runtime: runtime)
        let backend = FakeSelfPositionBackend(state: plan.baseline)
        let lease = SelfPositionValidationLease(backend: backend, plan: plan, confirmation: try plan.fingerprint)
        let writer = RevealAssertionWriter(factory: SelfPositionValidationFactory(lease: lease))
        try await writer.replace(with: SelfPositionPlan.writerToken)
        try await writer.replace(with: SelfPositionPlan.writerToken)
        await writer.restoreAndStop()
        await writer.restoreAndStop()
        #expect(backend.state == plan.baseline)
        #expect(lease.restoreVerified)
        #expect(backend.events.filter { $0 == "apply" }.count == 1)
        #expect(backend.events.filter { $0 == "restore" }.count == 1)
        await #expect(throws: RevealAssertionWriterError.writerStopped) { try await writer.replace(with: SelfPositionPlan.writerToken) }
    }

    @Test("Partial apply failure is rolled back without retrying the write")
    func partialFailure() async throws {
        let plan = try SelfPositionPlan(baseline: baseline(), runtime: runtime)
        let backend = FakeSelfPositionBackend(state: plan.baseline)
        backend.failApply = true
        let lease = SelfPositionValidationLease(backend: backend, plan: plan, confirmation: try plan.fingerprint)
        let writer = RevealAssertionWriter(factory: SelfPositionValidationFactory(lease: lease))
        await #expect(throws: SelfPositionValidationError.unexpectedStateChange) { try await writer.replace(with: SelfPositionPlan.writerToken) }
        #expect(backend.state == plan.baseline)
        #expect(lease.restoreVerified)
        #expect(backend.events.filter { $0 == "apply" }.count == 1)
        #expect(backend.events.filter { $0 == "restore" }.count == 1)
    }

    @Test("Unexpected scope changes and unconfirmed restoration remain failures")
    func unexpectedDriftAndRestoreFailure() async throws {
        let plan = try SelfPositionPlan(baseline: baseline(), runtime: runtime)
        let backend = FakeSelfPositionBackend(state: plan.baseline)
        backend.driftAfterApply = true
        backend.failRestore = true
        let lease = SelfPositionValidationLease(backend: backend, plan: plan, confirmation: try plan.fingerprint)
        let writer = RevealAssertionWriter(factory: SelfPositionValidationFactory(lease: lease))
        await #expect(throws: SelfPositionValidationError.unexpectedStateChange) { try await writer.replace(with: SelfPositionPlan.writerToken) }
        await writer.restoreAndStop()
        #expect(!lease.restoreVerified)
        #expect(lease.failure != nil)
        #expect(backend.events.filter { $0 == "restore" }.count == 1)
    }

    @Test("Invalidation before activation prevents any later placement")
    func earlyTermination() async throws {
        let plan = try SelfPositionPlan(baseline: baseline(), runtime: runtime)
        let backend = FakeSelfPositionBackend(state: plan.baseline)
        let lease = SelfPositionValidationLease(backend: backend, plan: plan, confirmation: try plan.fingerprint)
        await lease.invalidate()
        await #expect(throws: SelfPositionValidationError.stopped) { try await lease.activate() }
        #expect(backend.events.isEmpty)
    }

    @Test("A decoded recovery receipt removes only experiment changes without apply")
    func recoveryReceipt() async throws {
        let original = try SelfPositionPlan(baseline: baseline(), runtime: runtime)
        let plan = try JSONDecoder().decode(SelfPositionPlan.self, from: JSONEncoder().encode(original))
        let backend = FakeSelfPositionBackend(state: plan.baseline)
        backend.state = SelfPositionSnapshot(domain: SelfPositionPlan.bundleIdentifier,
            persistent: plan.baseline.persistent.merging([SelfPositionPlan.positionKey: try SelfPositionSnapshot.encodeValue(500)], uniquingKeysWith: { _, new in new }),
            registration: [:])
        let lease = SelfPositionValidationLease(backend: backend, plan: plan,
            confirmation: try plan.fingerprint + ":restore", recoveryOnly: true)
        let writer = RevealAssertionWriter(factory: SelfPositionValidationFactory(lease: lease))
        try await writer.replace(with: SelfPositionPlan.writerToken)
        await writer.restoreAndStop()
        #expect(backend.state == plan.baseline)
        #expect(lease.restoreVerified)
        #expect(!backend.events.contains("apply"))
        #expect(backend.events.filter { $0 == "restore" }.count == 1)
    }

    @Test("Failed explicit recovery is neither retried nor reported as restored")
    func failedRecovery() async throws {
        let plan = try SelfPositionPlan(baseline: baseline(), runtime: runtime)
        let backend = FakeSelfPositionBackend(state: plan.baseline)
        backend.failRestore = true
        let lease = SelfPositionValidationLease(backend: backend, plan: plan,
            confirmation: try plan.fingerprint + ":restore", recoveryOnly: true)
        let writer = RevealAssertionWriter(factory: SelfPositionValidationFactory(lease: lease))
        await #expect(throws: SelfPositionValidationError.restoreFailed) {
            try await writer.replace(with: SelfPositionPlan.writerToken)
        }
        await writer.restoreAndStop()
        #expect(!lease.restoreVerified)
        #expect(lease.failure != nil)
        #expect(backend.events.filter { $0 == "restore" }.count == 1)
        #expect(!backend.events.contains("apply"))
    }

    @Test("Recovery rejects unrelated drift and ordinary apply confirmation before cleanup")
    func recoveryGates() async throws {
        let plan = try SelfPositionPlan(baseline: baseline(), runtime: runtime)
        for drift in [false, true] {
            let backend = FakeSelfPositionBackend(state: plan.baseline)
            if drift { backend.state = SelfPositionSnapshot(domain: SelfPositionPlan.bundleIdentifier, persistent: [:], registration: [:]) }
            let lease = SelfPositionValidationLease(backend: backend, plan: plan,
                confirmation: try plan.fingerprint + (drift ? ":restore" : ""), recoveryOnly: true)
            let writer = RevealAssertionWriter(factory: SelfPositionValidationFactory(lease: lease))
            await #expect(throws: drift ? SelfPositionValidationError.unexpectedStateChange : .unconfirmedPlan) {
                try await writer.replace(with: SelfPositionPlan.writerToken)
            }
            #expect(!backend.events.contains("restore"))
            #expect(!backend.events.contains("apply"))
        }
    }
}

@MainActor
private final class FakeSelfPositionBackend: SelfPositionValidationBackend {
    var state: SelfPositionSnapshot
    let baseline: SelfPositionSnapshot
    var events: [String] = []
    var failApply = false
    var failRestore = false
    var driftAfterApply = false

    init(state: SelfPositionSnapshot) { self.state = state; self.baseline = state }
    func capture() -> SelfPositionSnapshot { events.append("read"); return state }
    func apply() throws {
        events.append("apply")
        var registration = baseline.registration
        registration[SelfPositionPlan.positionKey] = try SelfPositionSnapshot.encodeValue(500)
        var persistent = baseline.persistent
        if driftAfterApply { persistent["NSStatusItem Preferred Position Other"] = try SelfPositionSnapshot.encodeValue(200) }
        state = SelfPositionSnapshot(domain: baseline.domain, persistent: persistent, registration: registration)
        if failApply { throw SelfPositionValidationError.unexpectedStateChange }
    }
    func restore() throws {
        events.append("restore")
        if failRestore { throw SelfPositionValidationError.restoreFailed }
        state = baseline
    }
}
#endif
