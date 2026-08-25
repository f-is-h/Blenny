import Foundation

public protocol RevealAssertionCandidate: AnyObject, Sendable {
    func activate() async throws
    func invalidate() async
}

public protocol RevealAssertionCandidateFactory: Sendable {
    func makeCandidate(
        for plan: RevealAllowlistPlan
    ) throws -> any RevealAssertionCandidate
}

public enum RevealAssertionWriterError: Error, Equatable, Sendable {
    case transitionAlreadyInProgress
    case activationTimedOut
    case transitionSuperseded
    case writerStopped
}

public enum RevealAssertionWriterState: Equatable, Sendable {
    case idle
    case active(RevealSessionPresentation)
    case restored
}

public actor RevealAssertionWriter {
    private let factory: any RevealAssertionCandidateFactory
    private let activationTimeout: Duration
    private var activeAssertion: (any RevealAssertionCandidate)?
    private var pendingAssertion: (
        identifier: UInt64,
        candidate: any RevealAssertionCandidate
    )?
    private var nextTransitionIdentifier: UInt64 = 0
    private var transitioning = false
    private var stopped = false

    public private(set) var state: RevealAssertionWriterState = .idle

    public init(
        factory: any RevealAssertionCandidateFactory,
        activationTimeout: Duration = .seconds(1)
    ) {
        self.factory = factory
        self.activationTimeout = activationTimeout
    }

    public func replace(with plan: RevealAllowlistPlan) async throws {
        guard !stopped else { throw RevealAssertionWriterError.writerStopped }
        guard !transitioning else {
            throw RevealAssertionWriterError.transitionAlreadyInProgress
        }
        if state == .active(plan.presentation) { return }

        transitioning = true
        let replacement: any RevealAssertionCandidate
        do {
            replacement = try factory.makeCandidate(for: plan)
        } catch {
            transitioning = false
            throw error
        }

        nextTransitionIdentifier &+= 1
        let transitionIdentifier = nextTransitionIdentifier
        pendingAssertion = (transitionIdentifier, replacement)

        do {
            try await activate(replacement)
        } catch {
            let stillOwned = pendingAssertion?.identifier == transitionIdentifier
            if stillOwned {
                pendingAssertion = nil
                transitioning = false
                await replacement.invalidate()
            }
            if stopped {
                throw RevealAssertionWriterError.writerStopped
            }
            if !stillOwned {
                throw RevealAssertionWriterError.transitionSuperseded
            }
            throw error
        }

        guard pendingAssertion?.identifier == transitionIdentifier else {
            if stopped {
                throw RevealAssertionWriterError.writerStopped
            }
            throw RevealAssertionWriterError.transitionSuperseded
        }

        // The preceding assertion remains active throughout replacement
        // activation. Only a confirmed active replacement can become current.
        let preceding = activeAssertion
        pendingAssertion = nil
        activeAssertion = replacement
        state = .active(plan.presentation)
        transitioning = false
        await preceding?.invalidate()
    }

    public func restoreAndStop() async {
        stopped = true
        transitioning = false
        let pending = pendingAssertion?.candidate
        let preceding = activeAssertion
        pendingAssertion = nil
        activeAssertion = nil
        state = .restored
        await pending?.invalidate()
        await preceding?.invalidate()
    }

    public func connectionInvalidated() async {
        // Invalidation is idempotent. Calling it locally as well as relying on
        // MenuBarAgent's process-connection cleanup keeps the restore path clear.
        let pending = pendingAssertion?.candidate
        let preceding = activeAssertion
        pendingAssertion = nil
        activeAssertion = nil
        transitioning = false
        state = .restored
        await pending?.invalidate()
        await preceding?.invalidate()
    }

    private func activate(
        _ assertion: any RevealAssertionCandidate
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await assertion.activate()
            }
            group.addTask { [activationTimeout] in
                try await Task.sleep(for: activationTimeout)
                throw RevealAssertionWriterError.activationTimedOut
            }

            defer { group.cancelAll() }
            guard let result = try await group.next() else { return }
            return result
        }
    }
}
