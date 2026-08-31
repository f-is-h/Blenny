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
    case invalidBaselineReplacement
}

public enum RevealAssertionWriterState: Equatable, Sendable {
    case idle
    case active(RevealSessionPresentation)
    case restored
}

public actor RevealAssertionWriter {
    public typealias DiagnosticHandler = @Sendable (String) -> Void
    private let factory: any RevealAssertionCandidateFactory
    private let activationTimeout: Duration
    private let diagnostic: DiagnosticHandler?
    private var activeAssertion: (any RevealAssertionCandidate)?
    private var activePlan: RevealAllowlistPlan?
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
        activationTimeout: Duration = .seconds(1),
        diagnostic: DiagnosticHandler? = nil
    ) {
        self.factory = factory
        self.activationTimeout = activationTimeout
        self.diagnostic = diagnostic
    }

    public func replace(with plan: RevealAllowlistPlan) async throws {
        diagnostic?("writer request=\(plan.presentation.rawValue) plan=\(plan.fingerprint) active=\(activePlan?.fingerprint ?? "none")")
        guard !stopped else { throw RevealAssertionWriterError.writerStopped }
        guard !transitioning else {
            throw RevealAssertionWriterError.transitionAlreadyInProgress
        }
        if activePlan == plan { diagnostic?("writer unchanged-plan"); return }

        transitioning = true
        let replacement: any RevealAssertionCandidate
        do {
            replacement = try factory.makeCandidate(for: plan)
        } catch {
            diagnostic?("writer candidate-failed error=\(error)")
            transitioning = false
            throw error
        }

        nextTransitionIdentifier &+= 1
        let transitionIdentifier = nextTransitionIdentifier
        pendingAssertion = (transitionIdentifier, replacement)

        do {
            diagnostic?("writer activation-begin id=\(transitionIdentifier)")
            try await activate(replacement)
            diagnostic?("writer activation-returned id=\(transitionIdentifier)")
        } catch {
            diagnostic?("writer activation-failed id=\(transitionIdentifier) error=\(error)")
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
        let precedingFingerprint = activePlan?.fingerprint ?? "none"
        pendingAssertion = nil
        activeAssertion = replacement
        activePlan = plan
        state = .active(plan.presentation)
        transitioning = false
        diagnostic?("writer active=\(plan.presentation.rawValue) plan=\(plan.fingerprint) preceding-invalidate=\(precedingFingerprint)")
        await preceding?.invalidate()
        diagnostic?("writer replacement-complete id=\(transitionIdentifier)")
    }

    public func applySessionTransition(
        with plan: RevealAllowlistPlan
    ) async throws {
        do {
            try await replace(with: plan)
        } catch {
            // A failed reveal leaves the preceding concealed baseline active.
            // A failed conceal cannot safely leave a revealed assertion active,
            // so it removes every owned restriction and stops this writer.
            if plan.presentation == .baseline {
                await restoreAndStop()
            }
            throw error
        }
    }

    public func applyBaselineReplacement(
        with plan: RevealAllowlistPlan
    ) async throws {
        guard plan.presentation == .baseline else {
            throw RevealAssertionWriterError.invalidBaselineReplacement
        }
        try await replace(with: plan)
    }

    public func verifyActivePlan(_ expected: RevealAllowlistPlan) -> Bool {
        !stopped
            && !transitioning
            && pendingAssertion == nil
            && activeAssertion != nil
            && activePlan == expected
            && state == .active(expected.presentation)
    }

    public func restoreAndStop() async {
        diagnostic?("writer restore-begin active=\(activePlan?.fingerprint ?? "none")")
        stopped = true
        transitioning = false
        let pending = pendingAssertion?.candidate
        let preceding = activeAssertion
        pendingAssertion = nil
        activeAssertion = nil
        activePlan = nil
        state = .restored
        await pending?.invalidate()
        await preceding?.invalidate()
        diagnostic?("writer restore-complete active=none")
    }

    public func connectionInvalidated() async {
        diagnostic?("writer connection-invalidated")
        // Invalidation is idempotent. Calling it locally as well as relying on
        // MenuBarAgent's process-connection cleanup keeps the restore path clear.
        stopped = true
        let pending = pendingAssertion?.candidate
        let preceding = activeAssertion
        pendingAssertion = nil
        activeAssertion = nil
        activePlan = nil
        transitioning = false
        state = .restored
        await pending?.invalidate()
        await preceding?.invalidate()
    }

    public func activePlanSnapshot() -> RevealAllowlistPlan? {
        activePlan
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
