#if BLENNY_UPDATE_TEST
import AppKit
import Sparkle

/// Fixture-only driver: exercises Sparkle without starting menu bar management.
@MainActor
final class SparkleLocalTestDriver: NSObject, NSApplicationDelegate, SPUUserDriver {
    private var updater: SPUUpdater?
    private var standardUpdater: ApplicationUpdater?
    private var deadline: Task<Void, Never>?
    private var mode: String { Bundle.main.object(forInfoDictionaryKey: "BlennyUpdateTestMode") as? String ?? "install" }
    private var root: URL { URL(fileURLWithPath: Bundle.main.object(forInfoDictionaryKey: "BlennyUpdateTestRoot") as! String) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        record("launch-\(build)")
        if build == "102" { finish("relaunched-target"); return }
        if mode == "standard-ui" {
            let standard = ApplicationUpdater()
            standard.permitsInteraction = { true }
            standard.start()
            standard.setAutomaticChecks(false)
            standardUpdater = standard
            deadline = Task { try? await Task.sleep(for: .seconds(55)); if !Task.isCancelled { finish("timeout") } }
            record("standard-ui-check")
            standard.check(nil)
            return
        }
        do {
            let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: self, delegate: nil)
            self.updater = updater
            try updater.start()
            deadline = Task { try? await Task.sleep(for: .seconds(55)); if !Task.isCancelled { finish("timeout") } }
            updater.checkForUpdates()
        } catch { finish("start-error: \(error.localizedDescription)") }
    }
    private func record(_ event: String) {
        let path = root.appendingPathComponent("events.txt")
        if !FileManager.default.fileExists(atPath: path.path) { FileManager.default.createFile(atPath: path.path, contents: nil) }
        guard let handle = try? FileHandle(forWritingTo: path) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data((event + "\n").utf8))
        try? handle.synchronize()
    }
    private func finish(_ event: String) { record(event); deadline?.cancel(); NSApplication.shared.terminate(nil) }
    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
    }
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) { record("checking") }
    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        record("found-\(appcastItem.versionString)")
        if mode == "cancel" { reply(.dismiss); finish("cancelled") } else { reply(.install) }
    }
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) { record("notes-error") }
    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) { acknowledgement(); finish("no-update") }
    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) { acknowledgement(); finish("error: \(error.localizedDescription)") }
    func showDownloadInitiated(cancellation: @escaping () -> Void) { record("downloading") }
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) { record("length-\(expectedContentLength)") }
    func showDownloadDidReceiveData(ofLength length: UInt64) {}
    func showDownloadDidStartExtractingUpdate() { record("extracting") }
    func showExtractionReceivedProgress(_ progress: Double) {}
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) { record("ready"); reply(.install) }
    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) { record("installing") }
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) { record("installed-\(relaunched)"); acknowledgement() }
    func dismissUpdateInstallation() { record("dismissed") }
}
#endif
