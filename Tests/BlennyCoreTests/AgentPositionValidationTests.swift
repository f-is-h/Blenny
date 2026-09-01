#if DEBUG
import Foundation
import Testing
@testable import BlennyCore

@MainActor
@Suite("Debug-only MenuBarAgent position validation")
struct AgentPositionValidationTests {
    let runtime = RuntimeEnvironment(macOSVersion: "27.0.0",
        buildVersion: "26A5416b", architecture: "arm64")

    func baseline(_ values: [String: Double]? = nil) throws -> AgentPositionSnapshot {
        try AgentPositionSnapshot(encodedDictionary: values.map(AgentPositionSnapshot.encode))
    }

    @Test("The plan binds exact self-only target, weight, runtime and absent baseline")
    func binding() throws {
        let plan = try AgentPositionPlan(baseline: baseline(), runtime: runtime)
        #expect(try plan.applied.dictionary() == [AgentPositionPlan.targetIdentifier: 700])
        #expect(try plan.fingerprint.count == 64)
        #expect(AgentPositionPlan.targetIdentifier ==
            "status:xyz.fi5h.blenny::Blenny0.7.0AgentPositionValidation")
    }

    @Test("Malformed dictionaries, runtime and occupied target fail closed")
    func invalidInputs() throws {
        #expect(throws: AgentPositionValidationError.invalidScope) {
            try AgentPositionPlan(baseline: baseline(), runtime:
                RuntimeEnvironment(macOSVersion: "27.0.0", buildVersion: "other", architecture: "arm64"))
        }
        #expect(throws: AgentPositionValidationError.invalidScope) {
            try AgentPositionPlan(baseline: baseline([AgentPositionPlan.targetIdentifier: 1]), runtime: runtime)
        }
        let invalid = try PropertyListSerialization.data(fromPropertyList: ["bad": "value"],
            format: .binary, options: 0)
        #expect(throws: AgentPositionValidationError.invalidScope) {
            try AgentPositionSnapshot(encodedDictionary: invalid)
        }
    }

    @Test("Preview construction is read-only")
    func preview() throws {
        let backend = FakeAgentPositionBackend(state: try baseline())
        _ = try AgentPositionPlan(baseline: backend.capture(), runtime: runtime)
        #expect(backend.events == ["read"])
    }

    @Test("Confirmation and stale state reject before write")
    func gates() async throws {
        let plan = try AgentPositionPlan(baseline: baseline(), runtime: runtime)
        for stale in [false, true] {
            let backend = FakeAgentPositionBackend(state: plan.baseline)
            if stale { backend.state = try baseline(["other": 1]) }
            let lease = AgentPositionValidationLease(backend: backend, plan: plan,
                confirmation: stale ? try plan.fingerprint : "wrong")
            let writer = RevealAssertionWriter(factory: AgentPositionValidationFactory(lease: lease))
            await #expect(throws: stale ? AgentPositionValidationError.staleState : .unconfirmedPlan) {
                try await writer.replace(with: AgentPositionPlan.writerToken)
            }
            #expect(!backend.events.contains("apply"))
        }
    }

    @Test("The serial writer applies and restores once")
    func serialRestore() async throws {
        let plan = try AgentPositionPlan(baseline: baseline(), runtime: runtime)
        let backend = FakeAgentPositionBackend(state: plan.baseline)
        let lease = AgentPositionValidationLease(backend: backend, plan: plan,
            confirmation: try plan.fingerprint)
        let writer = RevealAssertionWriter(factory: AgentPositionValidationFactory(lease: lease))
        try await writer.replace(with: AgentPositionPlan.writerToken)
        try await writer.replace(with: AgentPositionPlan.writerToken)
        await writer.restoreAndStop()
        await writer.restoreAndStop()
        #expect(backend.state == plan.baseline)
        #expect(lease.restoreVerified)
        #expect(backend.events.filter { $0 == "apply" }.count == 1)
        #expect(backend.events.filter { $0 == "restore" }.count == 1)
    }

    @Test("Partial apply failure uses one rollback and no retry")
    func partialFailure() async throws {
        let plan = try AgentPositionPlan(baseline: baseline(), runtime: runtime)
        let backend = FakeAgentPositionBackend(state: plan.baseline)
        backend.failApply = true
        let lease = AgentPositionValidationLease(backend: backend, plan: plan,
            confirmation: try plan.fingerprint)
        let writer = RevealAssertionWriter(factory: AgentPositionValidationFactory(lease: lease))
        await #expect(throws: AgentPositionValidationError.unexpectedStateChange) {
            try await writer.replace(with: AgentPositionPlan.writerToken)
        }
        #expect(backend.state == plan.baseline)
        #expect(backend.events.filter { $0 == "apply" }.count == 1)
        #expect(backend.events.filter { $0 == "restore" }.count == 1)
    }

    @Test("Restore failure remains visible")
    func restoreFailure() async throws {
        let plan = try AgentPositionPlan(baseline: baseline(), runtime: runtime)
        let backend = FakeAgentPositionBackend(state: plan.baseline)
        backend.failRestore = true
        let lease = AgentPositionValidationLease(backend: backend, plan: plan,
            confirmation: try plan.fingerprint)
        let writer = RevealAssertionWriter(factory: AgentPositionValidationFactory(lease: lease))
        try await writer.replace(with: AgentPositionPlan.writerToken)
        await writer.restoreAndStop()
        #expect(!lease.restoreVerified)
        #expect(lease.failure != nil)
        #expect(backend.events.filter { $0 == "restore" }.count == 1)
    }

    @Test("Explicit recovery restores only the exact applied snapshot")
    func recovery() async throws {
        let plan = try AgentPositionPlan(baseline: baseline(), runtime: runtime)
        let backend = FakeAgentPositionBackend(state: try plan.applied)
        let lease = AgentPositionValidationLease(backend: backend, plan: plan,
            confirmation: try plan.fingerprint + ":restore", recoveryOnly: true)
        let writer = RevealAssertionWriter(factory: AgentPositionValidationFactory(lease: lease))
        try await writer.replace(with: AgentPositionPlan.writerToken)
        await writer.restoreAndStop()
        #expect(backend.state == plan.baseline)
        #expect(!backend.events.contains("apply"))
        #expect(backend.events.filter { $0 == "restore" }.count == 1)
    }
}

@MainActor
private final class FakeAgentPositionBackend: AgentPositionValidationBackend {
    var state: AgentPositionSnapshot
    var events: [String] = []
    var failApply = false
    var failRestore = false
    init(state: AgentPositionSnapshot) { self.state = state }
    func capture() -> AgentPositionSnapshot {
        events.append("read")
        return state
    }
    func apply(_ snapshot: AgentPositionSnapshot) throws {
        events.append("apply")
        state = snapshot
        if failApply { throw AgentPositionValidationError.unexpectedStateChange }
    }
    func restore(_ snapshot: AgentPositionSnapshot) throws {
        events.append("restore")
        if failRestore { throw AgentPositionValidationError.restoreFailed }
        state = snapshot
    }
}
#endif
