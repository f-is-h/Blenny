import Testing
@testable import BlennyCore

@Suite("Blenny native status-button actions")
struct StatusItemClickRoutingTests {
    @Test("Native sender identity determines the action without pointer coordinates")
    func separateNativeActions() {
        #expect(StatusItemClickRouting.action(
            control: .arrow, isSecondaryClick: false, canToggleReveal: true
        ) == .toggleReveal)
        #expect(StatusItemClickRouting.action(
            control: .artwork, isSecondaryClick: false, canToggleReveal: true
        ) == .openEditor)
    }

    @Test("A busy arrow does nothing; secondary click retains the safety menu")
    func busyAndSecondaryClick() {
        #expect(StatusItemClickRouting.action(
            control: .arrow, isSecondaryClick: false, canToggleReveal: false
        ) == .ignore)
        for control: StatusItemControl in [.arrow, .artwork] {
            #expect(StatusItemClickRouting.action(
                control: control, isSecondaryClick: true, canToggleReveal: false
            ) == .openMenu)
        }
        #expect(StatusItemClickRouting.action(
            control: .artwork, isSecondaryClick: false, canToggleReveal: false
        ) == .openEditor)
    }

    @Test("Inactive native arrow has a stable disabled identity, never an active claim", arguments: [
        ManagementLoopState.unknown, .stopped, .acceptedPolicyLoadedInactive,
        .applying, .terminating, .unsupportedRuntimeContract("unsupported"),
        .failClosedUnrestricted("restored")
    ])
    func inactiveNativeArrow(_ state: ManagementLoopState) {
        let presentation = ManagementStatusPresentation(
            state: state, hasRevealableBundles: true, isBusy: false
        )
        #expect(presentation.nativeArrowSymbolName == "chevron.right.2")
        #expect(presentation.nativeArrowHelp.contains("unavailable"))
        #expect(!presentation.canToggleReveal)
        #expect(StatusItemClickRouting.action(
            control: .arrow, isSecondaryClick: false, canToggleReveal: presentation.canToggleReveal
        ) == .ignore)
    }

    @Test("Repeated arrow actions share the ordinary toggle and retain direction through native appearance")
    func repeatedOwnArrowSessions() {
        var coordinator = OrdinaryRevealCoordinator()
        coordinator.synchronize(.active("baseline"), hasRevealableBundles: true)
        for _ in 0..<3 {
            let baseline = ManagementStatusPresentation(
                state: .active("baseline"), hasRevealableBundles: true, isBusy: false,
                nativeOverflow: coordinator.observation
            )
            #expect(StatusItemClickRouting.action(
                control: .arrow, isSecondaryClick: false, canToggleReveal: baseline.canToggleReveal
            ) == .toggleReveal)
            coordinator.requestBlennyToggle()
            #expect(coordinator.takePendingTransition()?.presentation == .revealed)
            coordinator.observe(.init(isPresent: true, presentationState: .collapsed, observationAvailable: true))
            coordinator.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
            let revealed = ManagementStatusPresentation(
                state: .ordinaryRevealSession("reveal"), hasRevealableBundles: true, isBusy: false,
                nativeOverflow: coordinator.observation
            )
            #expect(revealed.canToggleReveal)
            #expect(revealed.nativeArrowSymbolName == "chevron.left.2")
            coordinator.requestBlennyToggle()
            #expect(coordinator.takePendingTransition()?.presentation == .baseline)
            coordinator.synchronize(.active("baseline"), hasRevealableBundles: true)
        }
    }
}
