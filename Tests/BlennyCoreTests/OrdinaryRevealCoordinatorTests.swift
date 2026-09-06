import Foundation
import Testing
@testable import BlennyCore

@Suite("Ordinary native and fallback integration")
struct OrdinaryRevealCoordinatorTests {
    @Test("Pass-through update preserves an existing reveal and its already-fired timeout")
    func passThroughPreservesDeadline() throws {
        var control = activeControl()
        control.requestBlennyToggle()
        _ = control.takePendingTransition()
        control.synchronize(.ordinaryRevealSession("original"), hasRevealableBundles: true)
        let session = try #require(control.sessionIdentifier)
        control.requestTimeout(session: session)
        control.suspendForPassThroughUpdate()
        control.observe(.unavailable, source: .layout)
        control.synchronize(.ordinaryRevealSession("expanded-allowance"), hasRevealableBundles: true)
        #expect(control.sessionIdentifier == session)
        #expect(control.presentation == .revealed)
        control.resume()
        #expect(control.takePendingTransition()?.presentation == .baseline)
    }

    @Test("Pass-through update consumes native reflow without an extra write")
    func passThroughIgnoresReflow() {
        var control = activeControl()
        control.observe(collapsed, source: .valueChange)
        control.observe(expanded, source: .valueChange)
        control.suspendForPassThroughUpdate()
        control.observe(collapsed, source: .layout)
        control.synchronize(.active("expanded-allowance"), hasRevealableBundles: true)
        control.resume()
        #expect(control.takePendingTransition() == nil)
    }
    private let collapsed = NativeOverflowObservationSnapshot(
        isPresent: true, presentationState: .collapsed, observationAvailable: true,
        controlIdentifier: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    )
    private let expanded = NativeOverflowObservationSnapshot(
        isPresent: true, presentationState: .expanded, observationAvailable: true,
        controlIdentifier: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    )

    @Test("Initial snapshots and duplicate notifications never open a session")
    func snapshotIsNotUserIntent() {
        var control = activeControl()
        control.observe(expanded, source: .valueChange)
        control.observe(expanded, source: .valueChange)
        #expect(control.takePendingTransition() == nil)
        #expect(control.entryPoint == .nativeOverflow)
        #expect(control.canToggleBlenny)
    }

    @Test("Known native expand and collapse edges use the ordinary session")
    func nativeEdges() {
        var control = activeControl()
        control.observe(collapsed, source: .valueChange)
        control.observe(expanded, source: .valueChange)
        let reveal = control.takePendingTransition()
        #expect(reveal?.presentation == .revealed)
        #expect(reveal?.owner == .nativeOverflow)
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        control.observe(expanded, source: .valueChange)
        #expect(control.takePendingTransition() == nil)
        control.observe(collapsed, source: .valueChange)
        #expect(control.takePendingTransition()?.presentation == .baseline)
        control.synchronize(.active("baseline"), hasRevealableBundles: true)
        #expect(control.sessionIdentifier == nil)
    }

    @Test("Native collapse during our activation is consumed as reflow, not queued")
    func collapsedDuringActivation() {
        var control = activeControl()
        control.observe(collapsed, source: .valueChange)
        control.observe(expanded, source: .valueChange)
        #expect(control.takePendingTransition()?.presentation == .revealed)
        control.observe(collapsed, source: .valueChange)
        control.observe(collapsed, source: .valueChange)
        #expect(control.takePendingTransition() == nil)
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        #expect(control.takePendingTransition() == nil)
        control.observe(expanded, source: .valueChange)
        #expect(control.takePendingTransition() == nil)
        control.observe(collapsed, source: .valueChange)
        #expect(control.takePendingTransition()?.presentation == .baseline)
    }

    @Test("Blenny activation keeps ownership through its own native reflow")
    func fallbackDoesNotHandOverDuringActivation() {
        var control = activeControl()
        control.requestBlennyToggle()
        #expect(control.takePendingTransition()?.owner == .blennyFallback)
        control.observe(collapsed, source: .valueChange)
        control.observe(expanded, source: .valueChange)
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        #expect(control.entryPoint == .blennyFallback)
        #expect(control.canToggleBlenny)
        #expect(control.takePendingTransition() == nil)
        control.requestBlennyToggle()
        #expect(control.takePendingTransition()?.presentation == .baseline)
        control.synchronize(.active("baseline"), hasRevealableBundles: true)
        #expect(control.entryPoint == .nativeOverflow)
        #expect(control.canToggleBlenny)
    }

    @Test("A fresh native collapse can close a completed Blenny-opened session")
    func nativeTakesOverCompletedBlennyReveal() {
        var control = activeControl()
        control.requestBlennyToggle()
        _ = control.takePendingTransition()
        control.observe(collapsed, source: .valueChange)
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        // Appearance is not a click, and native expansion needs no duplicate
        // assertion because the same ordinary allow-list is already active.
        #expect(control.takePendingTransition() == nil)
        control.observe(expanded, source: .valueChange)
        #expect(control.takePendingTransition() == nil)
        control.observe(collapsed, source: .valueChange)
        #expect(control.takePendingTransition() == .init(presentation: .baseline, owner: .nativeOverflow))
        control.observe(expanded, source: .valueChange)
        control.synchronize(.active("baseline"), hasRevealableBundles: true)
        #expect(control.takePendingTransition() == nil)
    }

    @Test("Native appearance during an open Blenny session does not close it")
    func nativeAppearanceDoesNotWrite() {
        var control = activeControl()
        control.requestBlennyToggle()
        _ = control.takePendingTransition()
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        control.observe(collapsed, source: .valueChange)
        #expect(control.takePendingTransition() == nil)
        control.observe(.unavailable)
        #expect(control.takePendingTransition() == nil)
        #expect(control.canToggleBlenny)
        #expect(control.presentation == .revealed)
    }

    @Test("A post-write discovery sample cannot immediately undo a Blenny reveal")
    func sampledReflowDoesNotConcealBlennySession() {
        var control = activeControl()
        control.requestBlennyToggle()
        _ = control.takePendingTransition()
        control.observe(expanded, source: .valueChange)
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        control.observe(collapsed, source: .sample)
        #expect(control.takePendingTransition() == nil)
        #expect(control.presentation == .revealed)
        control.observe(expanded, source: .valueChange)
        #expect(control.takePendingTransition() == nil)
        control.observe(collapsed, source: .valueChange)
        #expect(control.takePendingTransition()?.presentation == .baseline)
    }

    @Test("Losing native presentation hands the bounded reveal to Blenny without writing")
    func unavailableNativeCloses() {
        var control = activeControl()
        control.observe(collapsed, source: .valueChange)
        control.observe(expanded, source: .valueChange)
        _ = control.takePendingTransition()
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        let session = control.sessionIdentifier
        control.observe(.unavailable)
        #expect(control.takePendingTransition() == nil)
        #expect(control.presentation == .revealed)
        #expect(control.sessionIdentifier == session)
        #expect(control.entryPoint == .blennyFallback)
        #expect(control.canToggleBlenny)
        control.requestBlennyToggle()
        #expect(control.takePendingTransition()?.presentation == .baseline)
    }

    @Test("Unknown or unobservable native state cannot steal the fallback")
    func unknownState() {
        var control = activeControl()
        control.observe(.init(isPresent: true, presentationState: .unknown, observationAvailable: true))
        #expect(control.entryPoint == .blennyFallback)
        control.observe(expanded, source: .valueChange)
        #expect(control.takePendingTransition() == nil)
        control.observe(.init(isPresent: true, presentationState: .expanded, observationAvailable: false))
        #expect(control.entryPoint == .blennyFallback)
    }

    @Test("Apply and Stop discard pre-action edges rather than replaying them")
    func policyActionsSuspend() {
        var control = activeControl()
        control.observe(collapsed, source: .valueChange)
        control.observe(expanded, source: .valueChange)
        control.suspend()
        control.observe(collapsed, source: .valueChange)
        control.observe(expanded, source: .valueChange)
        control.synchronize(.active("new baseline"), hasRevealableBundles: true)
        control.resume()
        #expect(control.takePendingTransition() == nil)
        control.observe(expanded, source: .valueChange)
        #expect(control.takePendingTransition() == nil)
    }

    @Test("Timeout belongs to exactly one session and waits behind Refresh")
    func timeoutGeneration() throws {
        var control = activeControl()
        control.requestBlennyToggle()
        _ = control.takePendingTransition()
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        let identifier = try #require(control.sessionIdentifier)
        control.suspend()
        control.requestTimeout(session: identifier)
        #expect(control.takePendingTransition() == nil)
        control.resume()
        #expect(control.takePendingTransition()?.presentation == .baseline)
        control.synchronize(.active("baseline"), hasRevealableBundles: true)
        control.requestBlennyToggle()
        _ = control.takePendingTransition()
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        control.requestTimeout(session: identifier)
        #expect(control.takePendingTransition() == nil)
    }

    @Test("Stopped, failed and terminating management cannot react to native events", arguments: [
        ManagementLoopState.stopped, .applying, .terminating, .connectionInvalidated,
        .failClosedUnrestricted("lost"), .unsupportedRuntimeContract("unsupported")
    ])
    func inactiveNeverWrites(_ state: ManagementLoopState) {
        var control = activeControl()
        control.observe(collapsed, source: .valueChange)
        control.synchronize(state, hasRevealableBundles: true)
        control.observe(expanded, source: .valueChange)
        control.requestBlennyToggle()
        #expect(control.takePendingTransition() == nil)
    }

    @Test("A failed reveal does not publish a revealed arrow or retry the same event")
    func failedReveal() {
        var control = activeControl()
        control.observe(collapsed, source: .valueChange)
        control.observe(expanded, source: .valueChange)
        _ = control.takePendingTransition()
        control.synchronize(.active("baseline"), hasRevealableBundles: true)
        control.observe(expanded, source: .valueChange)
        #expect(control.presentation == .baseline)
        #expect(control.sessionIdentifier == nil)
        #expect(control.takePendingTransition() == nil)
    }

    @Test("A reflow during conceal cannot enqueue another reveal")
    func concealCannotStartFeedbackLoop() {
        var control = activeControl()
        control.observe(collapsed, source: .valueChange)
        control.observe(expanded, source: .valueChange)
        _ = control.takePendingTransition()
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        control.observe(collapsed, source: .valueChange)
        _ = control.takePendingTransition()
        control.observe(expanded, source: .valueChange)
        control.synchronize(.active("baseline"), hasRevealableBundles: true)
        #expect(control.takePendingTransition() == nil)
    }

    @Test("A read-only discovery sample never treats reflow as an expand click")
    func discoveryDoesNotReveal() {
        var control = activeControl()
        control.observe(collapsed, source: .valueChange)
        control.observe(expanded, source: .sample)
        #expect(control.takePendingTransition() == nil)
        control.observe(expanded, source: .valueChange)
        #expect(control.takePendingTransition() == nil)
        control.observe(collapsed, source: .valueChange)
        control.observe(expanded, source: .valueChange)
        #expect(control.takePendingTransition()?.presentation == .revealed)
    }

    @Test("Native presence never disables the verified Blenny button", arguments: [
        NativeOverflowPresentationState.collapsed, .expanded, .unknown
    ])
    func nativeStatusPresentation(_ nativeState: NativeOverflowPresentationState) {
        var control = activeControl()
        control.observe(.init(isPresent: true, presentationState: nativeState, observationAvailable: true))
        let status = ManagementStatusPresentation(
            state: .active("baseline"), hasRevealableBundles: true, isBusy: false
        )
        #expect(status.canToggleReveal && control.canToggleBlenny)
        #expect(control.takePendingTransition() == nil)
        control.requestBlennyToggle()
        #expect(control.takePendingTransition() == .init(presentation: .revealed, owner: .blennyFallback))
        #expect(!control.canToggleBlenny)
        control.requestBlennyToggle()
        #expect(control.takePendingTransition() == nil)
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        #expect(control.entryPoint == .blennyFallback)
        #expect(control.canToggleBlenny)
        #expect(control.takePendingTransition() == nil)
    }

    @Test("Blenny can explicitly conceal a native-owned session")
    func directConcealOfNativeSession() {
        var control = activeControl()
        control.observe(collapsed, source: .valueChange)
        control.observe(expanded, source: .valueChange)
        _ = control.takePendingTransition()
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        #expect(control.entryPoint == .nativeOverflow)
        #expect(control.canToggleBlenny)
        control.requestBlennyToggle()
        #expect(control.takePendingTransition() == .init(presentation: .baseline, owner: .blennyFallback))
        control.observe(collapsed, source: .valueChange)
        control.observe(expanded, source: .valueChange)
        control.synchronize(.active("baseline"), hasRevealableBundles: true)
        #expect(control.takePendingTransition() == nil)
        #expect(control.canToggleBlenny)
    }

    @Test("An explicit click supersedes pending native intent and survives discovery")
    func directIntentWins() {
        var control = activeControl()
        control.observe(collapsed, source: .valueChange)
        control.observe(expanded, source: .valueChange)
        control.requestBlennyToggle()
        control.observe(collapsed, source: .valueChange)
        control.observe(.unavailable)
        #expect(control.takePendingTransition() == .init(presentation: .revealed, owner: .blennyFallback))
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        #expect(control.takePendingTransition() == nil)
    }

    @Test("Stop and Resume are not required to enable the Blenny arrow")
    func startupAndRepeatedStopResume() {
        var control = activeControl()
        for _ in 0..<3 {
            control.observe(collapsed, source: .valueChange)
            #expect(control.canToggleBlenny)
            control.suspend()
            #expect(!control.canToggleBlenny)
            control.requestBlennyToggle()
            control.synchronize(.stopped, hasRevealableBundles: true)
            control.observe(.unavailable)
            control.resume()
            #expect(!control.canToggleBlenny)
            #expect(control.takePendingTransition() == nil)
            control.synchronize(.active("baseline"), hasRevealableBundles: true)
            control.observe(collapsed, source: .valueChange)
            #expect(control.canToggleBlenny)
            #expect(control.takePendingTransition() == nil)
        }
    }

    @Test("No Revealable assignment means neither native nor fallback can write")
    func hiddenOnly() {
        var control = OrdinaryRevealCoordinator()
        control.synchronize(.active("baseline"), hasRevealableBundles: false)
        control.observe(collapsed, source: .valueChange)
        control.observe(expanded, source: .valueChange)
        control.requestBlennyToggle()
        #expect(control.takePendingTransition() == nil)
    }

    @Test("Discovery and samples cannot turn changed state into user intent", arguments: [
        NativeOverflowUpdateSource.discovery, .sample
    ])
    func provenanceIsRequired(_ source: NativeOverflowUpdateSource) {
        var control = activeControl()
        control.observe(collapsed)
        control.observe(expanded, source: source)
        #expect(control.takePendingTransition() == nil)
        control.observe(collapsed, source: .valueChange)
        control.observe(expanded, source: .valueChange)
        #expect(control.takePendingTransition()?.presentation == .revealed)
    }

    @Test("Replacement controls cannot inherit edges from the previous registration")
    func replacementIsNotAnEdge() {
        var control = activeControl()
        control.observe(collapsed)
        let replacement = NativeOverflowObservationSnapshot.observed(
            states: [.expanded], controlIdentifier: UUID()
        )
        control.observe(replacement, source: .valueChange)
        #expect(control.takePendingTransition() == nil)
        #expect(control.canToggleBlenny)
    }

    @Test("Replacing a native control does not conceal an authorized reveal")
    func replacedNativeSessionCloses() {
        var control = activeControl()
        control.observe(collapsed)
        control.observe(expanded, source: .valueChange)
        _ = control.takePendingTransition()
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        control.observe(.observed(states: [.expanded], controlIdentifier: UUID()))
        #expect(control.takePendingTransition() == nil)
        #expect(control.entryPoint == .blennyFallback)
        #expect(control.presentation == .revealed)
    }

    @Test("Multiple controls are ambiguous even when their observed states agree", arguments: [
        [NativeOverflowPresentationState.expanded, .expanded], [.collapsed, .expanded], [.collapsed, .collapsed]
    ])
    func multipleControlsUseBlenny(_ states: [NativeOverflowPresentationState]) {
        var control = activeControl()
        control.observe(collapsed)
        let snapshot = NativeOverflowObservationSnapshot.observed(states: states, controlIdentifier: UUID())
        #expect(!snapshot.isUsable)
        #expect(snapshot.controlCount == 2)
        control.observe(snapshot, source: .valueChange)
        #expect(control.entryPoint == .blennyFallback)
        #expect(control.takePendingTransition() == nil)
        #expect(control.canToggleBlenny)
    }

    @Test("A discovery update cancels a queued native reveal rather than replaying it")
    func discoveryDiscardsPendingReveal() {
        var control = activeControl()
        control.observe(collapsed)
        control.observe(expanded, source: .valueChange)
        control.observe(expanded, source: .discovery)
        #expect(control.takePendingTransition() == nil)
    }

    private func activeControl() -> OrdinaryRevealCoordinator {
        var control = OrdinaryRevealCoordinator()
        control.synchronize(.active("baseline"), hasRevealableBundles: true)
        return control
    }

    @Test("Layout then value delivers one transition for each known edge")
    func layoutBeforeValue() {
        var control = activeControl()
        control.observe(collapsed)
        control.observe(expanded, source: .layout)
        #expect(control.observation == expanded)
        #expect(control.takePendingTransition()?.presentation == .revealed)
        control.observe(expanded, source: .valueChange)
        #expect(control.takePendingTransition() == nil)
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        control.observe(collapsed, source: .layout)
        #expect(control.takePendingTransition()?.presentation == .baseline)
        control.observe(collapsed, source: .valueChange)
        #expect(control.takePendingTransition() == nil)
    }

    @Test("Initial and replacement layout snapshots cannot open a session")
    func layoutIsNotIntent() {
        var control = activeControl()
        control.observe(expanded, source: .layout)
        #expect(control.takePendingTransition() == nil)
        for state in [NativeOverflowPresentationState.expanded, .collapsed, .expanded] {
            control.observe(.observed(states: [state], controlIdentifier: UUID()), source: .layout)
            #expect(control.takePendingTransition() == nil)
        }
        control.observe(expanded, source: .sample)
        control.observe(expanded, source: .valueChange)
        #expect(control.takePendingTransition() == nil)
    }

    @Test("An expanded layout appearing after a successful empty read opens the first session")
    func firstExpandedAppearanceAfterKnownAbsence() {
        var control = activeControl()
        control.observe(.observed(states: [], controlIdentifier: nil), source: .sample)
        control.observe(expanded, source: .layout)
        #expect(control.takePendingTransition() == .init(
            presentation: .revealed, owner: .nativeOverflow
        ))
        #expect(control.lastConsumedReason == "native-layout-appeared-expanded")
    }

    @Test("Appearance does not broaden startup, read recovery, samples or replacement")
    func firstExpandedAppearanceSafetyBoundaries() {
        for preceding in [
            NativeOverflowObservationSnapshot.unavailable,
            .init(isPresent: true, presentationState: .unknown, observationAvailable: true),
            collapsed
        ] {
            var control = activeControl()
            control.observe(preceding, source: .sample)
            control.observe(.observed(
                states: [.expanded], controlIdentifier: UUID()
            ), source: .layout)
            #expect(control.takePendingTransition() == nil)
        }

        var sampledAppearance = activeControl()
        sampledAppearance.observe(.observed(states: [], controlIdentifier: nil), source: .sample)
        sampledAppearance.observe(expanded, source: .sample)
        #expect(sampledAppearance.takePendingTransition() == nil)
    }

    @Test("A collapsed appearance anchors the normal next native edge")
    func firstCollapsedAppearanceThenExpansion() {
        var control = activeControl()
        control.observe(.observed(states: [], controlIdentifier: nil), source: .sample)
        control.observe(collapsed, source: .layout)
        #expect(control.takePendingTransition() == nil)
        control.observe(expanded, source: .layout)
        #expect(control.takePendingTransition()?.presentation == .revealed)
    }

    @Test("Transient loss during native activation never leaves a sticky conceal request")
    func noStickyConcealAfterRecoveredReflow() throws {
        var control = activeControl()
        control.observe(collapsed)
        control.observe(expanded, source: .layout)
        #expect(control.takePendingTransition()?.presentation == .revealed)
        control.observe(.unavailable, source: .layout)
        control.observe(expanded, source: .layout)
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        let session = try #require(control.sessionIdentifier)
        for _ in 0..<3 {
            control.observe(.unavailable, source: .sample)
            control.observe(expanded, source: .sample)
            #expect(control.takePendingTransition() == nil)
            #expect(control.sessionIdentifier == session)
        }
        #expect(control.entryPoint == .blennyFallback)
        control.requestTimeout(session: session)
        control.observe(.unavailable, source: .layout)
        #expect(control.takePendingTransition()?.presentation == .baseline)
        #expect(control.lastConsumedReason == "original-session-deadline")
    }

    @Test("Unknown state after native reveal keeps Hidden policy and original session deadline")
    func unknownDoesNotCloseOrExtend() throws {
        var control = activeControl()
        control.observe(collapsed)
        control.observe(expanded, source: .valueChange)
        _ = control.takePendingTransition()
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        let session = try #require(control.sessionIdentifier)
        control.observe(.observed(states: [.unknown], controlIdentifier: collapsed.controlIdentifier), source: .sample)
        #expect(control.presentation == .revealed)
        #expect(control.entryPoint == .blennyFallback)
        #expect(control.takePendingTransition() == nil)
        #expect(control.sessionIdentifier == session)
        control.requestTimeout(session: session)
        #expect(control.takePendingTransition()?.presentation == .baseline)
    }

    @Test("Suspension, stop, unknown and replacement end an unconfirmed layout edge")
    func layoutSafetyBoundaries() {
        for boundary in 0..<4 {
            var control = activeControl()
            control.observe(collapsed)
            control.observe(expanded, source: .layout)
            switch boundary {
            case 0:
                control.suspend()
                control.resume()
            case 1:
                control.synchronize(.stopped, hasRevealableBundles: true)
                control.synchronize(.active("baseline"), hasRevealableBundles: true)
            case 2:
                control.observe(.unavailable, source: .layout)
            default:
                control.observe(.observed(states: [.expanded], controlIdentifier: UUID()), source: .layout)
            }
            control.observe(expanded, source: .valueChange)
            #expect(control.takePendingTransition() == nil)
        }
    }

    @Test("Inactive management keeps native presentation current without enabling writes")
    func inactiveObservationStillUpdates() {
        var control = OrdinaryRevealCoordinator()
        control.synchronize(.stopped, hasRevealableBundles: true)
        control.observe(collapsed)
        control.observe(expanded, source: .valueChange)
        #expect(control.observation == expanded)
        #expect(!control.canToggleBlenny)
        #expect(control.takePendingTransition() == nil)
        let status = ManagementStatusPresentation(
            state: .stopped, hasRevealableBundles: true, isBusy: false,
            nativeOverflow: control.observation
        )
        #expect(!status.showsInlineArrow)
    }
}
