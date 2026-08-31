import Foundation
import Testing
@testable import BlennyCore

@Suite("Direct management interactions")
struct ManagementInteractionTests {
    @Test("Preparation, commit and reveal share a duplicate-action gate")
    func duplicateActionsAreRejected() {
        var gate = ManagementInteractionGate()
        let first = gate.begin()
        #expect(first)
        #expect(gate.isBusy)
        let duplicate = gate.begin()
        #expect(!duplicate)
        gate.finish()
        #expect(!gate.isBusy)
        let next = gate.begin()
        #expect(next)
    }

    @Test("Termination cannot reopen the interaction gate")
    func terminationBlocksNewActions() {
        var gate = ManagementInteractionGate()
        let first = gate.begin()
        #expect(first)
        gate.terminate()
        gate.finish()
        let afterTermination = gate.begin()
        #expect(!afterTermination)
        #expect(gate.isTerminating)
    }

    @Test("Normal management has independent reveal and conceal chevrons")
    func ordinaryStatusChevrons() {
        let baseline = ManagementStatusPresentation(
            state: .active("baseline"), hasRevealableBundles: true, isBusy: false
        )
        let revealed = ManagementStatusPresentation(
            state: .ordinaryRevealSession("revealed"), hasRevealableBundles: true, isBusy: false
        )
        #expect(baseline.arrowSymbolName == "chevron.right.2")
        #expect(revealed.arrowSymbolName == "chevron.left.2")
        #expect(baseline.canToggleReveal && revealed.canToggleReveal)
        #expect(baseline.showsInlineArrow && revealed.showsInlineArrow)
        #expect(!baseline.opensMenu(isSecondaryClick: false))
        #expect(!revealed.opensMenu(isSecondaryClick: false))
        #expect(baseline.opensMenu(isSecondaryClick: true))
        #expect(revealed.opensMenu(isSecondaryClick: true))
        #expect(baseline.accessibilityLabel.contains("Reveal Revealable"))
        #expect(revealed.accessibilityLabel.contains("Conceal Revealable"))
    }

    @Test("One known observed native control hides only the fallback arrow", arguments: [
        NativeOverflowPresentationState.collapsed, .expanded
    ])
    func nativeHidesFallbackButRetainsSafetyAction(_ state: NativeOverflowPresentationState) {
        for management in [ManagementLoopState.active("baseline"), .ordinaryRevealSession("reveal")] {
            let presentation = ManagementStatusPresentation(
                state: management, hasRevealableBundles: true, isBusy: false,
                nativeOverflow: .init(
                    isPresent: true, presentationState: state, observationAvailable: true,
                    controlIdentifier: UUID()
                )
            )
            #expect(!presentation.showsInlineArrow)
            #expect(presentation.canToggleReveal)
            #expect(presentation.opensMenu(isSecondaryClick: true))
        }
    }

    @Test("Unknown, absent or unobservable native overflow retains the fallback", arguments: [
        NativeOverflowObservationSnapshot.unavailable,
        .init(isPresent: true, presentationState: .unknown, observationAvailable: true),
        .init(isPresent: true, presentationState: .collapsed, observationAvailable: false),
        .init(isPresent: false, presentationState: .collapsed, observationAvailable: true),
        .init(isPresent: true, presentationState: .collapsed, observationAvailable: true),
        .init(isPresent: true, presentationState: .expanded, observationAvailable: true,
              controlIdentifier: UUID(), controlCount: 2)
    ])
    func unavailableNativeKeepsArrow(_ snapshot: NativeOverflowObservationSnapshot) {
        let presentation = ManagementStatusPresentation(
            state: .active("baseline"), hasRevealableBundles: true, isBusy: false,
            nativeOverflow: snapshot
        )
        #expect(presentation.showsInlineArrow)
        #expect(presentation.canToggleReveal)
    }

    @Test("Native loss restores fallback without changing the verified direction")
    func fallbackReturnsOnNativeLoss() {
        let native = NativeOverflowObservationSnapshot(
            isPresent: true, presentationState: .expanded, observationAvailable: true,
            controlIdentifier: UUID()
        )
        let snapshots: [NativeOverflowObservationSnapshot] = [
            .unavailable, native, .unavailable, native,
            .observed(states: [.collapsed, .expanded], controlIdentifier: nil), .unavailable
        ]
        let expected = [true, false, true, false, true, true]
        for (snapshot, visible) in zip(snapshots, expected) {
            let presentation = ManagementStatusPresentation(
                state: .ordinaryRevealSession("verified reveal"), hasRevealableBundles: true,
                isBusy: false, nativeOverflow: snapshot
            )
            #expect(presentation.showsInlineArrow == visible)
            #expect(presentation.arrowSymbolName == "chevron.left.2")
            #expect(presentation.canToggleReveal)
        }
    }

    @Test("Busy native handoff cannot expose an actionable hidden hit target")
    func busyNativePresentation() {
        let presentation = ManagementStatusPresentation(
            state: .ordinaryRevealSession("verified reveal"), hasRevealableBundles: true,
            isBusy: true,
            nativeOverflow: .init(isPresent: true, presentationState: .expanded,
                                  observationAvailable: true, controlIdentifier: UUID())
        )
        #expect(!presentation.showsInlineArrow)
        #expect(!presentation.canToggleReveal)
        #expect(presentation.arrowSymbolName == "chevron.left.2")
    }

    @Test("Unverified, failed and stopped states never offer a reveal action", arguments: [
        ManagementLoopState.unknown, .stopped, .acceptedPolicyLoadedInactive,
        .writerActivating, .baselineVerified("pending"), .applying, .stopping,
        .restoring, .terminating, .connectionInvalidated,
        .unsupportedRuntimeContract("unsupported"), .failClosedUnrestricted("restored")
    ])
    func inactiveStatus(_ state: ManagementLoopState) {
        let presentation = ManagementStatusPresentation(
            state: state, hasRevealableBundles: true, isBusy: false
        )
        #expect(presentation.arrowSymbolName == nil)
        #expect(!presentation.canToggleReveal)
        #expect(presentation.showsInlineArrow)
        #expect(presentation.opensMenu(isSecondaryClick: false))
        #expect(presentation.opensMenu(isSecondaryClick: true))
    }

    @Test("Hidden-only policy cannot enable an ordinary reveal control")
    func noRevealablePolicy() {
        let presentation = ManagementStatusPresentation(
            state: .active("hidden-only"), hasRevealableBundles: false, isBusy: false
        )
        #expect(presentation.arrowSymbolName == nil)
        #expect(!presentation.canToggleReveal)
    }

    @Test("Busy status retains the proven direction without accepting another toggle")
    func busyStatus() {
        let presentation = ManagementStatusPresentation(
            state: .ordinaryRevealSession("revealed"), hasRevealableBundles: true, isBusy: true
        )
        #expect(presentation.arrowSymbolName == "chevron.left.2")
        #expect(!presentation.canToggleReveal)
        #expect(presentation.opensMenu(isSecondaryClick: true))
    }

    @Test("An in-flight Apply disables Draft, Refresh and recovery actions")
    func applyingDisablesConflictingControls() {
        let controls = ProductInterfaceControlState(
            hasModel: true, managementEnabled: true, managementRuntimeState: .applying, recoveryAvailable: true,
            hasDraftChanges: true, isRefreshing: false, isApplying: true,
            accessibilityTrusted: true, accessibilityPromptRequested: true
        )
        #expect(!controls.refreshEnabled)
        #expect(!controls.discardDraftEnabled)
        #expect(!controls.applyEnabled)
        #expect(!controls.resumeEnabled)
        #expect(!controls.stopEnabled)
        #expect(!controls.restoreEnabled)
    }

    @Test("Action diagnostics stay bounded and do not record raw inventory")
    func boundedAudit() {
        var audit = PolicyActionAuditTrail()
        for _ in 0..<40 { audit.record(.apply, phase: .preparing) }
        audit.record(.stop, phase: .committed)
        #expect(audit.entries.count == 32)
        #expect(audit.entries.last?.action == .stop)
        #expect(audit.entries.last?.phase == .committed)
        #expect(audit.entries.allSatisfy { $0.bindingFingerprint == nil && $0.baselineFingerprint == nil })
    }

    @Test("Dirty Drafts retain Stop but prevent accidental replacement by Resume or Restore")
    func dirtyDraftSafetyControls() {
        let controls = ProductInterfaceControlState(
            hasModel: true, managementEnabled: true, managementRuntimeState: .active("baseline"), recoveryAvailable: true,
            hasDraftChanges: true, isRefreshing: false,
            accessibilityTrusted: true, accessibilityPromptRequested: true
        )
        #expect(controls.stopEnabled)
        #expect(controls.applyEnabled)
        #expect(!controls.restoreEnabled)
        #expect(!controls.resumeEnabled)
    }

    @Test("Audit retains failure stage and proven disposition without raw error detail")
    func failureAudit() {
        var audit = PolicyActionAuditTrail()
        audit.record(.apply, phase: .failed, failure: PolicyEditingTransactionFailure(
            stage: .rollback, systemState: .unrestricted, detail: "private diagnostic context"
        ))
        #expect(audit.entries.last?.failureStage == .rollback)
        #expect(audit.entries.last?.systemState == .unrestricted)
        #expect(!String(describing: audit).contains("private diagnostic context"))
    }
}
