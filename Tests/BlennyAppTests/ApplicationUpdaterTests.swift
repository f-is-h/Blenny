import AppKit
import Sparkle
import Testing
@testable import BlennyApp

@MainActor
struct ApplicationUpdaterTests {
    @Test func automaticAndManualDelegatePathsShareTheInteractionGate() throws {
        let service = ApplicationUpdater()
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        let item = SUAppcastItem.empty()
        for check: SPUUpdateCheck in [.updates, .updatesInBackground, .updateInformation] {
            service.permitsInteraction = { false }
            #expect(throws: NSError.self) { try service.updater(controller.updater, mayPerform: check) }
            #expect(throws: NSError.self) { try service.updater(controller.updater, shouldProceedWithUpdate: item, updateCheck: check) }
            service.permitsInteraction = { true }
            try service.updater(controller.updater, mayPerform: check)
            try service.updater(controller.updater, shouldProceedWithUpdate: item, updateCheck: check)
        }
    }
}
