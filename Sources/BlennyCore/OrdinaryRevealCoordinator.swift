import Foundation

/// Event-driven arbitration shared by the ordinary app and deterministic tests.
/// Known native edges outside our own write may request a transition. A layout
/// notification can carry that edge; it is state observation, not a proven click.
/// Discovery, explicit samples and initial snapshots never open a session.
/// A witnessed absent-to-expanded layout can be the first runtime handoff edge.
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
    private enum IntentOrigin { case native, explicit, timeout }
    private var pendingOrigin: IntentOrigin?
    private var pendingReason: String?
    public private(set) var lastConsumedReason: String?
    private var suspended = false
    public private(set) var lastDecision = "initial"

    public var diagnosticSummary: String {
        "presentation=\(presentation.rawValue) owner=\(entryPoint.rawValue)"
            + " enabled=\(isEnabled) suspended=\(suspended)"
            + " inFlight=\(inFlight?.presentation.rawValue ?? "none")"
            + " pending=\(pending?.presentation.rawValue ?? "none") pendingReason=\(pendingReason ?? "none") lastDecision=\(lastDecision)"
    }

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
        _ snapshot: NativeOverflowObservationSnapshot,
        source: NativeOverflowUpdateSource = .discovery
    ) {
        let previous = observation
        observation = snapshot
        guard isEnabled, !suspended else {
            lastDecision = "observation-only-inactive-or-suspended"
            return
        }
        // Explicit input and the existing deadline cannot be cancelled by AX.
        guard pendingOrigin != .explicit, pendingOrigin != .timeout else {
            lastDecision = "retain-explicit-or-timeout-intent"
            return
        }
        let sameControl = previous.controlIdentifier != nil
            && previous.controlIdentifier == snapshot.controlIdentifier
        if !nativeIsUsable || (previous.isUsable && !sameControl) {
            if pendingOrigin == .native { pending = nil; pendingOrigin = nil; pendingReason = nil }
            // Presentation loss is not policy/permission loss. Preserve the
            // authorized reveal and its original deadline; hand control to
            // Blenny without another assertion. Lifecycle loss still stops the
            // writer through ManagementLoopController, outside this reducer.
            if entryPoint == .nativeOverflow,
               presentation == .revealed || inFlight?.presentation == .revealed {
                sessionOwner = .blennyFallback
                if inFlight?.presentation == .revealed {
                    inFlight = Transition(presentation: .revealed, owner: .blennyFallback)
                }
            }
            lastDecision = "presentation-loss-handoff-no-write"
            return
        }
        // AX changes while an assertion is being replaced cannot distinguish
        // rapid user input from our own reflow. Consume them as the new anchor,
        // never queue a compensating write. A fresh post-write edge can act.
        guard inFlight == nil else {
            lastDecision = "own-write-reflow-observation-only"
            return
        }
        // A control can be created and expanded before the container layout
        // callback lets us publish its collapsed registration anchor. When the
        // immediately preceding snapshot was a successful empty-root read, the
        // new expanded layout is the first observable edge of that appearance.
        // This is deliberately narrower than accepting a first snapshot: app
        // startup, read recovery, ambiguity and identity replacement are not a
        // witnessed absent-to-present transition and remain observation-only.
        let appearedExpandedAfterKnownAbsence = source == .layout
            && previous.observationAvailable
            && !previous.isPresent
            && previous.controlCount == 0
            && snapshot.isUsable
            && snapshot.presentationState == .expanded
            && presentation == .baseline
        if appearedExpandedAfterKnownAbsence {
            pending = Transition(presentation: .revealed, owner: .nativeOverflow)
            pendingOrigin = .native
            lastDecision = "native-layout-appeared-expanded"
            pendingReason = lastDecision
            return
        }
        guard source == .valueChange || source == .layout else {
            if pendingOrigin == .native { pending = nil; pendingOrigin = nil; pendingReason = nil }
            lastDecision = "discovery-or-sample-observation-only"
            return
        }
        guard sameControl,
              previous.isUsable,
              previous.presentationState != snapshot.presentationState else {
            lastDecision = "no-fresh-known-edge"
            return
        }
        pending = Transition(
            presentation: snapshot.presentationState == .expanded ? .revealed : .baseline,
            owner: .nativeOverflow
        )
        pendingOrigin = .native
        lastDecision = "native-\(source.rawValue)-\(snapshot.presentationState.rawValue)"
        pendingReason = lastDecision
    }

    public mutating func requestBlennyToggle() {
        guard canToggleBlenny else { return }
        // The explicit action supersedes queued native intent. Its session
        // keeps Blenny ownership across its own in-flight native reflow.
        pending = Transition(
            presentation: presentation == .baseline ? .revealed : .baseline,
            owner: .blennyFallback
        )
        pendingOrigin = .explicit
        lastDecision = "explicit-blenny-toggle"
        pendingReason = lastDecision
    }

    public mutating func requestTimeout(session identifier: UUID) {
        guard isEnabled, sessionIdentifier == identifier,
              presentation == .revealed else { return }
        pending = Transition(presentation: .baseline, owner: entryPoint)
        pendingOrigin = .timeout
        lastDecision = "original-session-deadline"
        pendingReason = lastDecision
    }

    public mutating func takePendingTransition() -> Transition? {
        guard isEnabled, !suspended, inFlight == nil, let requested = pending else { return nil }
        lastConsumedReason = pendingReason
        pendingReason = nil
        pending = nil
        pendingOrigin = nil
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
            pendingOrigin = nil
            pendingReason = nil
        }
        inFlight = nil
        if !isEnabled { pending = nil; pendingOrigin = nil; pendingReason = nil }
    }

    /// Apply, Stop, Restore, Refresh and termination discard pre-action events.
    /// Snapshots still update during suspension, so resuming cannot replay them.
    public mutating func suspend() {
        suspended = true
        pending = nil
        pendingOrigin = nil
        pendingReason = nil
        lastDecision = "suspended-discard-intent"
    }

    public mutating func resume() { suspended = false }

    /// A pass-through expansion does not alter user intent or the reveal clock.
    /// Ignore native reflow, but retain explicit input and an already-fired timeout.
    public mutating func suspendForPassThroughUpdate() {
        suspended = true
        if pendingOrigin == .native {
            pending = nil
            pendingOrigin = nil
            pendingReason = nil
        }
        lastDecision = "pass-through-update-preserve-explicit-intent"
    }
}
