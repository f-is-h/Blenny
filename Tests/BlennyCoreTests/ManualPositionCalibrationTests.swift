#if DEBUG
import Foundation
import Testing
@testable import BlennyCore

@MainActor
@Suite("Debug-only manual position calibration")
struct ManualPositionCalibrationTests {
    private let runtime = RuntimeEnvironment(macOSVersion: "27.0.0",
        buildVersion: "26A5416b", architecture: "arm64")

    private func baseline() throws -> SelfPositionSnapshot {
        SelfPositionSnapshot(domain: ManualPositionCalibrationPlan.bundleIdentifier,
            persistent: ["NSStatusItem Preferred Position Existing":
                try SelfPositionSnapshot.encodeValue(400)], registration: [:])
    }

    @Test("Plan and receipt bind the dedicated absent autosave identity")
    func planBinding() throws {
        let plan = try ManualPositionCalibrationPlan(
            baseline: baseline(), runtime: runtime)
        let receipt = ManualPositionCalibrationReceipt(plan: plan)
        let decoded = try JSONDecoder().decode(ManualPositionCalibrationReceipt.self,
            from: JSONEncoder().encode(receipt))
        #expect(decoded == receipt)
        #expect(try plan.fingerprint.count == 64)
        #expect(plan.baseline.persistent[
            ManualPositionCalibrationPlan.positionKey] == nil)
    }

    @Test("Wrong runtime, occupied keys and malformed observations fail closed")
    func invalidInputs() throws {
        #expect(throws: ManualPositionCalibrationError.invalidScope) {
            try ManualPositionCalibrationPlan(baseline: baseline(), runtime:
                RuntimeEnvironment(macOSVersion: "27.0.0",
                    buildVersion: "other", architecture: "arm64"))
        }
        let occupied = SelfPositionSnapshot(
            domain: ManualPositionCalibrationPlan.bundleIdentifier,
            persistent: [ManualPositionCalibrationPlan.positionKey:
                try SelfPositionSnapshot.encodeValue(1)], registration: [:])
        #expect(throws: ManualPositionCalibrationError.occupiedExperimentKey) {
            try ManualPositionCalibrationPlan(baseline: occupied, runtime: runtime)
        }
        #expect(throws: ManualPositionCalibrationError.invalidScope) {
            try ManualPositionCalibrationObservation(savedPosition: .infinity,
                runtimePreferredPosition: 1)
        }
    }

    @Test("Preview construction is read-only")
    func preview() throws {
        let backend = FakeManualCalibrationBackend(state: try baseline())
        _ = try ManualPositionCalibrationPlan(
            baseline: backend.capture(), runtime: runtime)
        #expect(backend.events == ["read"])
    }

    @Test("Confirmation and stale-state gates reject before item creation")
    func gates() async throws {
        let plan = try ManualPositionCalibrationPlan(
            baseline: baseline(), runtime: runtime)
        for stale in [false, true] {
            let backend = FakeManualCalibrationBackend(state: plan.baseline)
            if stale {
                backend.state = SelfPositionSnapshot(
                    domain: ManualPositionCalibrationPlan.bundleIdentifier,
                    persistent: [:], registration: [:])
            }
            let lease = ManualPositionCalibrationLease(backend: backend, plan: plan,
                confirmation: stale ? try plan.fingerprint : "wrong")
            let writer = RevealAssertionWriter(
                factory: ManualPositionCalibrationFactory(lease: lease))
            await #expect(throws: stale ? ManualPositionCalibrationError.staleState
                    : .unconfirmedPlan) {
                try await writer.replace(with:
                    ManualPositionCalibrationPlan.writerToken)
            }
            #expect(!backend.events.contains("start"))
        }
    }

    @Test("One explicit record captures saved and runtime positions")
    func explicitCapture() async throws {
        let plan = try ManualPositionCalibrationPlan(
            baseline: baseline(), runtime: runtime)
        let backend = FakeManualCalibrationBackend(state: plan.baseline)
        backend.startPosition = 500
        backend.runtimePosition = 618
        let lease = ManualPositionCalibrationLease(backend: backend, plan: plan,
            confirmation: try plan.fingerprint)
        let writer = RevealAssertionWriter(
            factory: ManualPositionCalibrationFactory(lease: lease))
        try await writer.replace(with: ManualPositionCalibrationPlan.writerToken)
        backend.setPosition(618)
        let observation = try lease.recordCurrent()
        #expect(observation.savedPosition == 618)
        #expect(observation.runtimePreferredPosition == 618)
        #expect(try lease.recordCurrent() == observation)
        await writer.restoreAndStop()
        #expect(backend.state == plan.baseline)
        #expect(lease.restoreVerified)
        #expect(backend.events.filter { $0 == "start" }.count == 1)
        #expect(backend.events.filter { $0 == "restore" }.count == 1)
    }

    @Test("Explicit record accepts a runtime position when owner storage is absent")
    func runtimeOnlyCapture() async throws {
        let plan = try ManualPositionCalibrationPlan(
            baseline: baseline(), runtime: runtime)
        let backend = FakeManualCalibrationBackend(state: plan.baseline)
        backend.runtimePosition = 853
        let lease = ManualPositionCalibrationLease(backend: backend, plan: plan,
            confirmation: try plan.fingerprint)
        let writer = RevealAssertionWriter(
            factory: ManualPositionCalibrationFactory(lease: lease))
        try await writer.replace(with: ManualPositionCalibrationPlan.writerToken)
        let observation = try lease.recordCurrent()
        #expect(observation.savedPosition == nil)
        #expect(observation.runtimePreferredPosition == 853)
        #expect(backend.events.filter { $0 == "read" }.count == 3)
        await writer.restoreAndStop()
    }

    @Test("Unrelated drift is rejected and serial cleanup restores once")
    func driftAndCleanup() async throws {
        let plan = try ManualPositionCalibrationPlan(
            baseline: baseline(), runtime: runtime)
        let backend = FakeManualCalibrationBackend(state: plan.baseline)
        let lease = ManualPositionCalibrationLease(backend: backend, plan: plan,
            confirmation: try plan.fingerprint)
        let writer = RevealAssertionWriter(
            factory: ManualPositionCalibrationFactory(lease: lease))
        try await writer.replace(with: ManualPositionCalibrationPlan.writerToken)
        backend.state = SelfPositionSnapshot(
            domain: ManualPositionCalibrationPlan.bundleIdentifier,
            persistent: ["NSStatusItem Preferred Position Other":
                try SelfPositionSnapshot.encodeValue(1)], registration: [:])
        #expect(throws: ManualPositionCalibrationError.unexpectedStateChange) {
            try lease.recordCurrent()
        }
        await writer.restoreAndStop()
        await writer.restoreAndStop()
        #expect(backend.events.filter { $0 == "restore" }.count == 1)
        #expect(backend.state == plan.baseline)
    }

    @Test("Partial start and restore failures stay visible")
    func failures() async throws {
        let plan = try ManualPositionCalibrationPlan(
            baseline: baseline(), runtime: runtime)
        let backend = FakeManualCalibrationBackend(state: plan.baseline)
        backend.failStart = true
        let lease = ManualPositionCalibrationLease(backend: backend, plan: plan,
            confirmation: try plan.fingerprint)
        let writer = RevealAssertionWriter(
            factory: ManualPositionCalibrationFactory(lease: lease))
        await #expect(throws: ManualPositionCalibrationError.unexpectedStateChange) {
            try await writer.replace(with: ManualPositionCalibrationPlan.writerToken)
        }
        #expect(backend.state == plan.baseline)
        #expect(backend.events.filter { $0 == "restore" }.count == 1)

        let failing = FakeManualCalibrationBackend(state: plan.baseline)
        failing.failRestore = true
        let failingLease = ManualPositionCalibrationLease(backend: failing,
            plan: plan, confirmation: try plan.fingerprint)
        let failingWriter = RevealAssertionWriter(
            factory: ManualPositionCalibrationFactory(lease: failingLease))
        try await failingWriter.replace(with:
            ManualPositionCalibrationPlan.writerToken)
        await failingWriter.restoreAndStop()
        #expect(!failingLease.restoreVerified)
        #expect(failingLease.failure != nil)
    }

    @Test("Explicit recovery restores only experiment-scoped state")
    func recovery() async throws {
        let plan = try ManualPositionCalibrationPlan(
            baseline: baseline(), runtime: runtime)
        let backend = FakeManualCalibrationBackend(state: plan.baseline)
        backend.setPosition(618)
        let lease = ManualPositionCalibrationLease(backend: backend, plan: plan,
            confirmation: try plan.fingerprint + ":restore", recoveryOnly: true)
        let writer = RevealAssertionWriter(
            factory: ManualPositionCalibrationFactory(lease: lease))
        try await writer.replace(with: ManualPositionCalibrationPlan.writerToken)
        await writer.restoreAndStop()
        #expect(backend.state == plan.baseline)
        #expect(!backend.events.contains("start"))
        #expect(backend.events.filter { $0 == "restore" }.count == 1)
    }
}

@MainActor
private final class FakeManualCalibrationBackend:
    ManualPositionCalibrationBackend {
    var state: SelfPositionSnapshot
    let baseline: SelfPositionSnapshot
    var events: [String] = []
    var startPosition: Double?
    var runtimePosition: Double?
    var failStart = false
    var failRestore = false

    init(state: SelfPositionSnapshot) {
        self.state = state
        baseline = state
    }

    func capture() -> SelfPositionSnapshot {
        events.append("read")
        return state
    }

    func start() throws {
        events.append("start")
        if let startPosition { setPosition(startPosition) }
        if failStart { throw ManualPositionCalibrationError.unexpectedStateChange }
    }

    func currentPreferredPosition() -> Double? {
        events.append("runtime")
        return runtimePosition
    }

    func restore() throws {
        events.append("restore")
        if failRestore { throw ManualPositionCalibrationError.restoreFailed }
        state = baseline
    }

    func setPosition(_ value: Double) {
        var persistent = baseline.persistent
        persistent[ManualPositionCalibrationPlan.positionKey] =
            try! SelfPositionSnapshot.encodeValue(value)
        state = SelfPositionSnapshot(domain: baseline.domain,
            persistent: persistent, registration: baseline.registration)
    }
}
#endif
