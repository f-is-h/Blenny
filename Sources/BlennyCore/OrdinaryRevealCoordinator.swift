import Foundation

/// Event-driven arbitration shared by the ordinary app and deterministic tests.
/// Observation is not an instruction: only a known native state edge may request
/// a transition. No discovery, timer, or first snapshot opens a reveal session.
public struct OrdinaryRevealCoordinator: Sendable {
    public struct Transition: Equatable, Sendable {
        public let presentation: RevealSessionPresentation
        public let owner: RevealEntryPoint
    }

    public private(set) var observation = NativeOverflowObservationSnapshot.unavailable
    public private(set) var presentation = RevealSessionPresentation.baseline
    public private(set) var sessionIdentifier: UUID?
    public private(set) var isEnabled = false
    private var sessionOwner: RevealEntryPoint?
    private var inFlight: Transition?
    private var pending: Transition?
    private var suspended = false

    public init() {}

    public var entryPoint: RevealEntryPoint {
        if let owner = inFlight?.owner ?? sessionOwner { return owner }
        return nativeIsUsable ? .nativeOverflow : .blennyFallback
    }

    /// Native observation does not make Blenny's explicit control unavailable.
    /// Both entry points still share one pending intent and in-flight operation.
    public var canToggleBlenny: Bool {
        isEnabled && !suspended && inFlight == nil
    }

    private var nativeIsUsable: Bool {
        observation.isUsable
    }

    public mutating func observe(
        _ snapshot: NativeOverflowObservationSnapshot, permitsReveal: Bool = true
    ) {
        let previous = observation
        observation = snapshot
        guard isEnabled, !suspended else { return }
        // A direct click has priority over observation until it reaches the gate.
        guard pending?.owner != .blennyFallback else { return }
        if !nativeIsUsable {
            // A native-owned session cannot outlive its observable control.
            if entryPoint == .nativeOverflow,
               presentation == .revealed || inFlight?.presentation == .revealed {
                pending = Transition(presentation: .baseline, owner: .nativeOverflow)
            } else {
                pending = nil
            }
            return
        }
        // Once a Blenny transition finishes, a fresh native edge may take over
        // its revealed session. Appearance or our own in-flight reflow may not.
        guard inFlight?.owner != .blennyFallback,
              previous.isPresent, previous.observationAvailable,
              previous.presentationState != .unknown,
              previous.presentationState != snapshot.presentationState else { return }
        guard permitsReveal || (
            snapshot.presentationState == .collapsed && entryPoint == .nativeOverflow
        ) else { return }
        // Conceal can itself reflow the native control. Never queue a reopen
        // behind our own closing transition; only a subsequent fresh edge can.
        guard inFlight?.presentation != .baseline else { return }
        pending = Transition(
            presentation: snapshot.presentationState == .expanded ? .revealed : .baseline,
            owner: .nativeOverflow
        )
    }

    public mutating func requestBlennyToggle() {
        guard canToggleBlenny else { return }
        // The explicit action supersedes queued native intent. Its session
        // keeps Blenny ownership across its own in-flight native reflow.
        pending = Transition(
            presentation: presentation == .baseline ? .revealed : .baseline,
            owner: .blennyFallback
        )
    }

    public mutating func requestTimeout(session identifier: UUID) {
        guard isEnabled, sessionIdentifier == identifier,
              presentation == .revealed else { return }
        pending = Transition(presentation: .baseline, owner: entryPoint)
    }

    public mutating func takePendingTransition() -> Transition? {
        guard isEnabled, !suspended, inFlight == nil, let requested = pending else { return nil }
        pending = nil
        guard requested.presentation != presentation else { return nil }
        inFlight = requested
        return requested
    }

    /// Publish only the management loop's verified result, never optimistic UI.
    public mutating func synchronize(_ state: ManagementLoopState, hasRevealableBundles: Bool) {
        let wasRevealed = presentation == .revealed
        switch state {
        case .active:
            isEnabled = hasRevealableBundles
            presentation = .baseline
            sessionOwner = nil
            sessionIdentifier = nil
        case .ordinaryRevealSession:
            isEnabled = hasRevealableBundles
            presentation = .revealed
            sessionOwner = inFlight?.owner ?? sessionOwner ?? entryPoint
            if !wasRevealed { sessionIdentifier = UUID() }
        default:
            isEnabled = false
            presentation = .baseline
            sessionOwner = nil
            sessionIdentifier = nil
            pending = nil
        }
        inFlight = nil
        if !isEnabled { pending = nil }
    }

    /// Apply, Stop, Restore, Refresh and termination discard pre-action events.
    /// Snapshots still update during suspension, so resuming cannot replay them.
    public mutating func suspend() {
        suspended = true
        pending = nil
    }

    public mutating func resume() { suspended = false }
}
