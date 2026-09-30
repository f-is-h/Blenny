import AppKit
import BlennyCore
import Sparkle

/// Owns Sparkle only. Management and termination remain with the application.
@MainActor
final class ApplicationUpdater: NSObject, SPUUpdaterDelegate {
    private var controller: SPUStandardUpdaterController?
    var permitsInteraction: () -> Bool = { false }

    private var allowsLoopback: Bool {
        #if BLENNY_UPDATE_TEST
        true
        #else
        false
        #endif
    }
    var isConfigured: Bool {
        UpdateFeedConfiguration.isUsable(
            feedURL: Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            publicEDKey: Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
            allowsLoopback: allowsLoopback
        )
    }
    var canCheck: Bool { controller?.updater.canCheckForUpdates == true && permitsInteraction() }
    var automaticallyChecks: Bool { controller?.updater.automaticallyChecksForUpdates == true }

    func start() {
        guard isConfigured, controller == nil else { return }
        controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil
        )
    }
    func check(_ sender: Any?) {
        guard canCheck else { return }
        controller?.checkForUpdates(sender)
    }
    func setAutomaticChecks(_ enabled: Bool) {
        controller?.updater.automaticallyChecksForUpdates = enabled
    }
    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        try requireSafeInteraction()
    }
    func updater(
        _ updater: SPUUpdater, shouldProceedWithUpdate updateItem: SUAppcastItem,
        updateCheck: SPUUpdateCheck
    ) throws {
        try requireSafeInteraction()
    }
    private func requireSafeInteraction() throws {
        guard permitsInteraction() else {
            throw NSError(domain: "Blenny.Update", code: 1, userInfo: [
                NSLocalizedDescriptionKey:
                    "Finish the current change or recovery and apply or discard your draft before updating."
            ])
        }
    }
}
