#if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
import AppKit
import BlennyCore
import Foundation

/// Explicit, one-shot recovery for an installed trial build. Normal product
/// startup never enters this delegate and never restores a receipt implicitly.
@MainActor
final class SharedSystemItemRecoveryDelegate: NSObject, NSApplicationDelegate {
    static let modeKey = "BLENNY_SHARED_SYSTEM_ITEM_RECOVERY"
    static let confirmationKey = "BLENNY_SHARED_SYSTEM_ITEM_RECOVERY_CONFIRM"

    private static let expectedConfirmation = "RESTORE_ALL_OWNED_RECEIPTS"
    private var task: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        task = Task { await run() }
    }

    private func run() async {
        do {
            let environment = ProcessInfo.processInfo.environment
            let mode = environment[Self.modeKey] ?? ""
            guard ["PREVIEW", "APPLY"].contains(mode),
                  Bundle.main.bundleIdentifier == "xyz.fi5h.blenny",
                  Bundle.main.bundleURL.standardizedFileURL.path == "/Applications/Blenny.app",
                  NSRunningApplication.runningApplications(
                    withBundleIdentifier: "xyz.fi5h.blenny"
                  ).count == 1 else {
                throw SharedSystemItemTrialError.unsafeBaseline
            }
            let receiptDirectory = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Blenny/DebugSharedSystemItemTrials")
            let writer = SharedSystemItemManualTrialWriter(
                backend: MacOS27SystemItemPreferenceBackend(),
                receiptDirectory: receiptDirectory
            )
            var targets: [SharedSystemItemTrialTarget] = []
            for target in SharedSystemItemTrialTarget.allCases {
                if await writer.hasRecoveryReceipt(for: target) {
                    targets.append(target)
                }
            }
            guard !targets.isEmpty,
                  await writer.verifyAllManagedItemsAreRestorable() else {
                throw SharedSystemItemTrialError.staleState
            }
            output("PREVIEW PASS targets=\(targets.map(\.rawValue).joined(separator: ",")) write=false")
            guard mode == "APPLY" else {
                quitOnRunLoop()
                return
            }
            guard environment[Self.confirmationKey] == Self.expectedConfirmation,
                  await writer.restoreAllManagedItems() else {
                throw SharedSystemItemTrialError.restorationFailed
            }
            for target in targets {
                if await writer.hasRecoveryReceipt(for: target) {
                    throw SharedSystemItemTrialError.restorationFailed
                }
            }
            output("RESTORE PASS targets=\(targets.map(\.rawValue).joined(separator: ","))")
            quitOnRunLoop()
        } catch {
            output("RECOVERY FAILED error=\(error)")
            quitOnRunLoop()
        }
    }

    private func quitOnRunLoop() {
        RunLoop.main.perform(inModes: [.common]) {
            MainActor.assumeIsolated { NSApplication.shared.terminate(nil) }
        }
    }

    private func output(_ value: String) {
        FileHandle.standardOutput.write(Data("SHARED_SYSTEM_ITEM_RECOVERY \(value)\n".utf8))
    }
}
#endif
