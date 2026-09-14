import Testing

@testable import BlennyCore

@Suite("Product management presentation")
struct ProductManagementPresentationTests {
    @Test("A saved change with failed observation permits Refresh, not another Apply")
    func savedChangeRequiresFreshObservation() {
        for active in [false, true] {
            let controls = ProductInterfaceControlState(
                hasModel: true,
                managementEnabled: active,
                managementRuntimeState: active ? .active("baseline") : .stopped,
                recoveryAvailable: true,
                hasDraftChanges: false,
                isRefreshing: false,
                accessibilityTrusted: true,
                accessibilityPromptRequested: true,
                requiresObservationRefresh: true
            )
            #expect(controls.refreshEnabled)
            #expect(!controls.applyEnabled)
            #expect(!controls.resumeEnabled)
            #expect(!controls.restoreEnabled)
            #expect(controls.stopEnabled == active)
        }
    }

    @Test("Terminal failures are not presented as loading or successfully restored")
    func failureStatesStayDistinct() {
        let connection = ProductManagementPresentation(state: .connectionInvalidated)
        let failed = ProductManagementPresentation(state: .restorationFailed("private detail"))
        let unsupported = ProductManagementPresentation(state: .unsupportedRuntimeContract("private detail"))
        let paused = ProductManagementPresentation(state: .failClosedUnrestricted("private detail"))
        let checking = ProductManagementPresentation(state: .unknown)
        #expect(Set([connection.title, failed.title, unsupported.title, paused.title, checking.title]).count == 5)
        #expect(connection.isError)
        #expect(failed.isError)
        #expect(!paused.isError)
        #expect(!unsupported.isError)
        #expect(connection.detail.contains("Quit and reopen"))
        #expect(failed.detail.contains("could not be confirmed"))
        #expect(!failed.detail.contains("private detail"))
        #expect(!unsupported.detail.contains("private detail"))
    }

    @Test("Stopping and quitting never claim to undo accepted ordering")
    func orderContractRemainsExplicit() {
        let states: [ManagementLoopState] = [.stopped, .acceptedPolicyLoadedInactive, .stopping, .terminating]
        for state in states {
            let presentation = ProductManagementPresentation(state: state)
            #expect(presentation.detail.contains("order"))
            #expect(presentation.detail.contains("unchanged"))
            #expect(!presentation.isError)
        }
    }

    @Test("Expanded and collapsed states retain Hidden exclusion")
    func revealContractRemainsExplicit() {
        let collapsed = ProductManagementPresentation(state: .active("baseline"))
        let expanded = ProductManagementPresentation(state: .ordinaryRevealSession("reveal"))
        #expect(collapsed.title != expanded.title)
        #expect(collapsed.detail.contains("Hidden items stay hidden"))
        #expect(expanded.detail.contains("Hidden items stay hidden"))
        #expect(expanded.detail.contains("Collapse"))
    }
}
