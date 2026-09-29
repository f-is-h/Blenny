#if DEBUG
import AppKit
import BlennyCore
import Foundation

/// Explicit, bounded owner-authorized trial of one existing preference target.
/// It never activates an assessment assertion or changes accepted policy.
@MainActor
final class DebugNowPlayingValidationDelegate: NSObject, NSApplicationDelegate {
    static let modeKey = "BLENNY_NOW_PLAYING_VALIDATION"
    private var task: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        task = Task { await run() }
    }

    private func run() async {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Blenny")
        let backend = DebugSharedSystemItemTrialBackend()
        let writer = SharedSystemItemManualTrialWriter(backend: backend,
            receiptDirectory: directory.appendingPathComponent("DebugSharedSystemItemTrials"))
        var touched = false
        do {
            let env = ProcessInfo.processInfo.environment
            let mode = env[Self.modeKey] ?? ""
            guard ["PREVIEW", "APPLY"].contains(mode),
                  Bundle.main.bundleURL.path == "/Applications/Blenny.app",
                  NSRunningApplication.runningApplications(withBundleIdentifier: "xyz.fi5h.blenny").count == 1,
                  AccessibilityAuthorization.isTrusted,
                  let path = env["BLENNY_NOW_PLAYING_SNAPSHOT"] else {
                throw SharedSystemItemTrialError.unsafeBaseline
            }
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard url.deletingLastPathComponent().resolvingSymlinksInPath().pathComponents.contains("LocalData") else {
                throw SharedSystemItemTrialError.unsafeBaseline
            }
            let policy = try JSONDecoder().decode(PersistentBundlePolicyDocument.self,
                from: Data(contentsOf: directory.appendingPathComponent("ManualSystemItemTrial/bundle-policies.json")))
            guard !policy.managementEnabled else { throw SharedSystemItemTrialError.unsafeBaseline }
            for target in SharedSystemItemTrialTarget.allCases {
                guard !(await writer.hasRecoveryReceipt(for: target)) else {
                    throw SharedSystemItemTrialError.staleState
                }
            }
            let baseline = try backend.capture(.nowPlaying)
            guard baseline.effectiveVisible else { throw SharedSystemItemTrialError.unsafeBaseline }
            if mode == "PREVIEW" {
                try JSONEncoder().encode(baseline).write(to: url, options: .withoutOverwriting)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                await observe("baseline", backend: backend)
                output("PREVIEW PASS writes=0")
            } else {
                guard env["BLENNY_NOW_PLAYING_CONFIRM"] == "HIDE_REVEAL_RESTORE_NOW_PLAYING",
                      try JSONDecoder().decode(SharedSystemItemPreferenceSnapshot.self,
                        from: Data(contentsOf: url)) == baseline else {
                    throw SharedSystemItemTrialError.staleState
                }
                let id = SharedSystemItemTrialTarget.nowPlaying.observationIdentifier
                touched = true
                try await writer.applyManagedPlan([id: .hidden])
                // Observation-only pause in this explicit trial, never a product delay.
                try await Task.sleep(for: .seconds(2))
                await observe("hidden", backend: backend)
                try await writer.applyManagedPlan([id: .revealed])
                guard try await writer.verifyManagedPlan([id: .revealed]) else {
                    throw SharedSystemItemTrialError.verificationFailed
                }
                try await Task.sleep(for: .seconds(2))
                await observe("revealed", backend: backend)
                guard await writer.restoreAllManagedItems(),
                      try backend.capture(.nowPlaying) == baseline,
                      !(await writer.hasRecoveryReceipt(for: .nowPlaying)) else {
                    throw SharedSystemItemTrialError.restorationFailed
                }
                touched = false
                await observe("restored", backend: backend)
                output("APPLY PASS exactBaselineRestored=true receiptRemoved=true assertionCreated=false")
            }
        } catch {
            if touched {
                output("COMPENSATION restored=\(await writer.restoreAllManagedItems())")
            }
            output("FAIL \(error)")
        }
        RunLoop.main.perform(inModes: [.common]) {
            MainActor.assumeIsolated { NSApp.terminate(nil) }
        }
    }

    private func observe(_ stage: String, backend: DebugSharedSystemItemTrialBackend) async {
        do {
            let snapshot = try backend.capture(.nowPlaying)
            let value = try snapshot.values["NowPlaying"]?.propertyListValue()
            output("stage=\(stage) preference=\(value.map { String(describing: $0) } ?? "absent")")
            let hosts = NSWorkspace.shared.runningApplications.filter {
                ["com.apple.MenuBarAgent", "com.apple.controlcenter"].contains($0.bundleIdentifier ?? "")
            }.map { RunningApplicationDescriptor(processIdentifier: $0.processIdentifier,
                bundleIdentifier: $0.bundleIdentifier) }
            let report = await AccessibilityInventory(maximumDurationMilliseconds: 3_000).capture(
                applications: hosts, accessibilityTrusted: true)
            let items = report.items.filter { $0.accessibilityIdentifier == "com.apple.menuextra.now-playing" }
            let encoded = try JSONEncoder().encode(items)
            output("stage=\(stage) ax=\(String(decoding: encoded, as: UTF8.self))")
        } catch { output("stage=\(stage) observationError=\(error)") }
    }

    private func output(_ text: String) {
        FileHandle.standardOutput.write(Data("NOW_PLAYING_TRIAL \(text)\n".utf8))
    }
}
#endif
