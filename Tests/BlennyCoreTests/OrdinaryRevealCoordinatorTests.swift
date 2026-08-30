import Foundation
import Testing
@testable import BlennyCore

@Suite("Ordinary native and fallback integration")
struct OrdinaryRevealCoordinatorTests {
    private let collapsed = NativeOverflowObservationSnapshot(
        isPresent: true, presentationState: .collapsed, observationAvailable: true
    )
    private let expanded = NativeOverflowObservationSnapshot(
        isPresent: true, presentationState: .expanded, observationAvailable: true
    )

    @Test("Initial snapshots and duplicate notifications never open a session")
    func snapshotIsNotUserIntent() {
        var control = activeControl()
        control.observe(expanded)
        control.observe(expanded)
        #expect(control.takePendingTransition() == nil)
        #expect(control.entryPoint == .nativeOverflow)
        #expect(control.canToggleBlenny)
    }

    @Test("Known native expand and collapse edges use the ordinary session")
    func nativeEdges() {
        var control = activeControl()
        control.observe(collapsed)
        control.observe(expanded)
        let reveal = control.takePendingTransition()
        #expect(reveal?.presentation == .revealed)
        #expect(reveal?.owner == .nativeOverflow)
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        control.observe(expanded)
        #expect(control.takePendingTransition() == nil)
        control.observe(collapsed)
        #expect(control.takePendingTransition()?.presentation == .baseline)
        control.synchronize(.active("baseline"), hasRevealableBundles: true)
        #expect(control.sessionIdentifier == nil)
    }

    @Test("Native collapse arriving during activation is retained once, not raced")
    func collapsedDuringActivation() {
        var control = activeControl()
        control.observe(collapsed)
        control.observe(expanded)
        #expect(control.takePendingTransition()?.presentation == .revealed)
        control.observe(collapsed)
        control.observe(collapsed)
        #expect(control.takePendingTransition() == nil)
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        #expect(control.takePendingTransition()?.presentation == .baseline)
        #expect(control.takePendingTransition() == nil)
    }

    @Test("Blenny activation keeps ownership through its own native reflow")
    func fallbackDoesNotHandOverDuringActivation() {
        var control = activeControl()
        control.requestBlennyToggle()
        #expect(control.takePendingTransition()?.owner == .blennyFallback)
        control.observe(collapsed)
        control.observe(expanded)
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
        control.observe(collapsed)
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        // Appearance is not a click, and native expansion needs no duplicate
        // assertion because the same ordinary allow-list is already active.
        #expect(control.takePendingTransition() == nil)
        control.observe(expanded)
        #expect(control.takePendingTransition() == nil)
        control.observe(collapsed)
        #expect(control.takePendingTransition() == .init(presentation: .baseline, owner: .nativeOverflow))
        control.observe(expanded)
        control.synchronize(.active("baseline"), hasRevealableBundles: true)
        #expect(control.takePendingTransition() == nil)
    }

    @Test("Native appearance during an open Blenny session does not close it")
    func nativeAppearanceDoesNotWrite() {
        var control = activeControl()
        control.requestBlennyToggle()
        _ = control.takePendingTransition()
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        control.observe(collapsed)
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
        control.observe(expanded)
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        control.observe(collapsed, permitsReveal: false)
        #expect(control.takePendingTransition() == nil)
        #expect(control.presentation == .revealed)
        control.observe(expanded)
        #expect(control.takePendingTransition() == nil)
        control.observe(collapsed)
        #expect(control.takePendingTransition()?.presentation == .baseline)
    }

    @Test("Losing the native control closes a native session before fallback")
    func unavailableNativeCloses() {
        var control = activeControl()
        control.observe(collapsed)
        control.observe(expanded)
        _ = control.takePendingTransition()
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        control.observe(.unavailable)
        #expect(control.takePendingTransition()?.presentation == .baseline)
        control.synchronize(.active("baseline"), hasRevealableBundles: true)
        #expect(control.entryPoint == .blennyFallback)
    }

    @Test("Unknown or unobservable native state cannot steal the fallback")
    func unknownState() {
        var control = activeControl()
        control.observe(.init(isPresent: true, presentationState: .unknown, observationAvailable: true))
        #expect(control.entryPoint == .blennyFallback)
        control.observe(expanded)
        #expect(control.takePendingTransition() == nil)
        control.observe(.init(isPresent: true, presentationState: .expanded, observationAvailable: false))
        #expect(control.entryPoint == .blennyFallback)
    }

    @Test("Apply and Stop discard pre-action edges rather than replaying them")
    func policyActionsSuspend() {
        var control = activeControl()
        control.observe(collapsed)
        control.observe(expanded)
        control.suspend()
        control.observe(collapsed)
        control.observe(expanded)
        control.synchronize(.active("new baseline"), hasRevealableBundles: true)
        control.resume()
        #expect(control.takePendingTransition() == nil)
        control.observe(expanded)
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
        control.observe(collapsed)
        control.synchronize(state, hasRevealableBundles: true)
        control.observe(expanded)
        control.requestBlennyToggle()
        #expect(control.takePendingTransition() == nil)
    }

    @Test("A failed reveal does not publish a revealed arrow or retry the same event")
    func failedReveal() {
        var control = activeControl()
        control.observe(collapsed)
        control.observe(expanded)
        _ = control.takePendingTransition()
        control.synchronize(.active("baseline"), hasRevealableBundles: true)
        control.observe(expanded)
        #expect(control.presentation == .baseline)
        #expect(control.sessionIdentifier == nil)
        #expect(control.takePendingTransition() == nil)
    }

    @Test("A reflow during conceal cannot enqueue another reveal")
    func concealCannotStartFeedbackLoop() {
        var control = activeControl()
        control.observe(collapsed)
        control.observe(expanded)
        _ = control.takePendingTransition()
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        control.observe(collapsed)
        _ = control.takePendingTransition()
        control.observe(expanded)
        control.synchronize(.active("baseline"), hasRevealableBundles: true)
        #expect(control.takePendingTransition() == nil)
    }

    @Test("A read-only discovery sample never treats reflow as an expand click")
    func discoveryDoesNotReveal() {
        var control = activeControl()
        control.observe(collapsed)
        control.observe(expanded, permitsReveal: false)
        #expect(control.takePendingTransition() == nil)
        control.observe(expanded)
        #expect(control.takePendingTransition() == nil)
        control.observe(collapsed)
        control.observe(expanded)
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
        control.observe(collapsed)
        control.observe(expanded)
        _ = control.takePendingTransition()
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        #expect(control.entryPoint == .nativeOverflow)
        #expect(control.canToggleBlenny)
        control.requestBlennyToggle()
        #expect(control.takePendingTransition() == .init(presentation: .baseline, owner: .blennyFallback))
        control.observe(collapsed)
        control.observe(expanded)
        control.synchronize(.active("baseline"), hasRevealableBundles: true)
        #expect(control.takePendingTransition() == nil)
        #expect(control.canToggleBlenny)
    }

    @Test("An explicit click supersedes pending native intent and survives discovery")
    func directIntentWins() {
        var control = activeControl()
        control.observe(collapsed)
        control.observe(expanded)
        control.requestBlennyToggle()
        control.observe(collapsed)
        control.observe(.unavailable)
        #expect(control.takePendingTransition() == .init(presentation: .revealed, owner: .blennyFallback))
        control.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        #expect(control.takePendingTransition() == nil)
    }

    @Test("Stop and Resume are not required to enable the Blenny arrow")
    func startupAndRepeatedStopResume() {
        var control = activeControl()
        for _ in 0..<3 {
            control.observe(collapsed)
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
            control.observe(collapsed)
            #expect(control.canToggleBlenny)
            #expect(control.takePendingTransition() == nil)
        }
    }

    @Test("No Revealable assignment means neither native nor fallback can write")
    func hiddenOnly() {
        var control = OrdinaryRevealCoordinator()
        control.synchronize(.active("baseline"), hasRevealableBundles: false)
        control.observe(collapsed)
        control.observe(expanded)
        control.requestBlennyToggle()
        #expect(control.takePendingTransition() == nil)
    }

    private func activeControl() -> OrdinaryRevealCoordinator {
        var control = OrdinaryRevealCoordinator()
        control.synchronize(.active("baseline"), hasRevealableBundles: true)
        return control
    }
}
