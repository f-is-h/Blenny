import Foundation
import Testing
@testable import BlennyCore

@Suite("Serialized reveal assertion writer")
struct RevealAssertionWriterTests {
    @Test("Replacement activates before the preceding assertion invalidates")
    func activationPrecedesInvalidation() async throws {
        let recorder = AssertionRecorder()
        let factory = FakeAssertionFactory(
            recorder: recorder,
            behaviors: [.succeed, .succeed]
        )
        let writer = RevealAssertionWriter(factory: factory)

        try await writer.replace(with: plan(.baseline))
        try await writer.replace(with: plan(.revealed))

        #expect(
            recorder.events == [
                "make-baseline-1",
                "activate-baseline-1",
                "make-revealed-2",
                "activate-revealed-2",
                "invalidate-baseline-1"
            ]
        )
        #expect(await writer.state == .active(.revealed))
    }

    @Test("Failed replacement never invalidates the old safe assertion")
    func failedReplacementPreservesOldAssertion() async throws {
        let recorder = AssertionRecorder()
        let factory = FakeAssertionFactory(
            recorder: recorder,
            behaviors: [.succeed, .fail]
        )
        let writer = RevealAssertionWriter(factory: factory)

        try await writer.replace(with: plan(.baseline))
        await #expect(throws: FakeAssertionError.activationFailed) {
            try await writer.replace(with: plan(.revealed))
        }

        let events = recorder.events
        #expect(events.contains("invalidate-revealed-2"))
        #expect(!events.contains("invalidate-baseline-1"))
        #expect(await writer.state == .active(.baseline))
    }

    @Test("Activation timeout invalidates only the replacement")
    func timeoutPreservesOldAssertion() async throws {
        let recorder = AssertionRecorder()
        let factory = FakeAssertionFactory(
            recorder: recorder,
            behaviors: [.succeed, .stall]
        )
        let writer = RevealAssertionWriter(
            factory: factory,
            activationTimeout: .milliseconds(20)
        )

        try await writer.replace(with: plan(.baseline))
        await #expect(throws: RevealAssertionWriterError.activationTimedOut) {
            try await writer.replace(with: plan(.revealed))
        }

        let events = recorder.events
        #expect(events.contains("invalidate-revealed-2"))
        #expect(!events.contains("invalidate-baseline-1"))
        #expect(await writer.state == .active(.baseline))
    }

    @Test("Normal exit restores by invalidating the active assertion")
    func normalExitRestores() async throws {
        let recorder = AssertionRecorder()
        let writer = RevealAssertionWriter(
            factory: FakeAssertionFactory(recorder: recorder, behaviors: [.succeed])
        )
        try await writer.replace(with: plan(.baseline))

        await writer.restoreAndStop()

        #expect(recorder.events.last == "invalidate-baseline-1")
        #expect(await writer.state == .restored)
        await #expect(throws: RevealAssertionWriterError.writerStopped) {
            try await writer.replace(with: plan(.revealed))
        }
    }

    @Test("Connection invalidation restores the active assertion")
    func disconnectRestores() async throws {
        let recorder = AssertionRecorder()
        let writer = RevealAssertionWriter(
            factory: FakeAssertionFactory(recorder: recorder, behaviors: [.succeed])
        )
        try await writer.replace(with: plan(.revealed))

        await writer.connectionInvalidated()

        #expect(recorder.events.last == "invalidate-revealed-1")
        #expect(await writer.state == .restored)
    }

    private func plan(_ presentation: RevealSessionPresentation) -> RevealAllowlistPlan {
        RevealAllowlistPlan(
            presentation: presentation,
            allowedSystemItems: Array(0 ..< 9),
            allowedBundleIdentifiers: ["com.example.BlennyProbe"]
        )
    }
}

private enum FakeAssertionError: Error {
    case activationFailed
}

private enum FakeAssertionBehavior: Sendable {
    case succeed
    case fail
    case stall
}

private final class AssertionRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedEvents: [String] = []

    var events: [String] {
        lock.withLock { recordedEvents }
    }

    func append(_ event: String) {
        lock.withLock {
            recordedEvents.append(event)
        }
    }
}

private final class FakeAssertionFactory: RevealAssertionCandidateFactory, @unchecked Sendable {
    private let recorder: AssertionRecorder
    private let lock = NSLock()
    private var behaviors: [FakeAssertionBehavior]
    private var candidateCount = 0

    init(recorder: AssertionRecorder, behaviors: [FakeAssertionBehavior]) {
        self.recorder = recorder
        self.behaviors = behaviors
    }

    func makeCandidate(
        for plan: RevealAllowlistPlan
    ) throws -> any RevealAssertionCandidate {
        let candidate: FakeAssertionCandidate = lock.withLock {
            candidateCount += 1
            let behavior = behaviors.removeFirst()
            return FakeAssertionCandidate(
                name: "\(plan.presentation.rawValue)-\(candidateCount)",
                behavior: behavior,
                recorder: recorder
            )
        }
        recorder.append("make-\(candidate.name)")
        return candidate
    }
}

private final class FakeAssertionCandidate: RevealAssertionCandidate, @unchecked Sendable {
    let name: String
    private let behavior: FakeAssertionBehavior
    private let recorder: AssertionRecorder

    init(
        name: String,
        behavior: FakeAssertionBehavior,
        recorder: AssertionRecorder
    ) {
        self.name = name
        self.behavior = behavior
        self.recorder = recorder
    }

    func activate() async throws {
        recorder.append("activate-\(name)")
        switch behavior {
        case .succeed:
            return
        case .fail:
            throw FakeAssertionError.activationFailed
        case .stall:
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                throw CancellationError()
            }
        }
    }

    func invalidate() async {
        recorder.append("invalidate-\(name)")
    }
}
