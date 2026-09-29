import Testing
@testable import BlennyCore

struct StatusMenuVisibilityTests {
    @Test func activeSessionOffersStopAndRecovery() {
        for state: ManagementLoopState in [.active("test"), .ordinaryRevealSession("test"), .applying, .restoring, .stopping] {
            let menu = StatusMenuVisibility(state: state, persistedManagementEnabled: true, recoveryAvailable: true)
            #expect(!menu.showsResume)
            #expect(menu.showsStop)
            #expect(menu.showsRestore)
        }
    }

    @Test func stoppedSessionOffersResumeWithoutMissingRecovery() {
        let menu = StatusMenuVisibility(state: .stopped, persistedManagementEnabled: false, recoveryAvailable: true)
        #expect(menu.showsResume)
        #expect(!menu.showsStop)
        #expect(menu.showsRestore)
    }

    @Test func pausedSavedIntentCanBeResumedOrExplicitlyStopped() {
        for state: ManagementLoopState in [.acceptedPolicyLoadedInactive, .failClosedUnrestricted("test"), .unsupportedRuntimeContract("test")] {
            let menu = StatusMenuVisibility(state: state, persistedManagementEnabled: true, recoveryAvailable: false)
            #expect(menu.showsResume)
            #expect(menu.showsStop)
            #expect(!menu.showsRestore)
        }
    }
}
