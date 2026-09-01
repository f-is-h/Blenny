#if DEBUG
import AppKit
import BlennyCore
import ServiceManagement

/// Separate launch delegate: normal policy loading, management, historical
/// experiments and private assessment factories cannot run in this process.
@MainActor
final class DebugSelfPositionValidationDelegate: NSObject, NSApplicationDelegate {
    static let modeKey = "BLENNY_SELF_POSITION_VALIDATION"
    private(set) static var creationAutosaveName: String?
    private var items: StatusItemController?
    private let observer = NativeOverflowObserver(reconnectOnAgentChange: false)
    private var backend: MacOS27SelfPositionBackend?
    private var lease: SelfPositionValidationLease?
    private var writer: RevealAssertionWriter?
    private var task: Task<Void, Never>?
    private var stopping = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        task = Task { await run() }
    }

    private func run() async {
        do {
            let env = ProcessInfo.processInfo.environment
            guard ["PREVIEW", "APPLY", "RECOVER"].contains(env[Self.modeKey] ?? ""),
                  Bundle.main.bundleIdentifier == SelfPositionPlan.bundleIdentifier,
                  Bundle.main.bundleURL.standardizedFileURL.path == "/Applications/Blenny.app",
                  NSRunningApplication.runningApplications(withBundleIdentifier: SelfPositionPlan.bundleIdentifier).count == 1,
                  NSWorkspace.shared.urlForApplication(withBundleIdentifier: SelfPositionPlan.bundleIdentifier)?
                    .resolvingSymlinksInPath().standardizedFileURL == Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL,
                  AccessibilityAuthorization.isTrusted,
                  let path = env["BLENNY_SELF_POSITION_RECEIPT"] else {
                throw SelfPositionValidationError.invalidScope
            }
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard url.deletingLastPathComponent().resolvingSymlinksInPath().pathComponents.contains("LocalData") else {
                throw SelfPositionValidationError.invalidScope
            }
            let backend = MacOS27SelfPositionBackend(
                createItems: { [weak self] name in
                    guard let self else { throw SelfPositionValidationError.stopped }
                    try self.createItems(autosaveName: name)
                },
                removeItems: { [weak self] in self?.removeItems() })
            self.backend = backend
            let current = try backend.capture()
            let isRecovery = env[Self.modeKey] == "RECOVER"
            let plan: SelfPositionPlan
            if isRecovery {
                guard (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? Int.max <= 65_536 else {
                    throw SelfPositionValidationError.invalidScope
                }
                plan = try JSONDecoder().decode(SelfPositionPlan.self, from: Data(contentsOf: url))
                try plan.validate()
                guard plan.runtime == RuntimeEnvironment.current() else { throw SelfPositionValidationError.invalidScope }
            } else {
                plan = try SelfPositionPlan(baseline: current, runtime: .current())
            }
            output("WARNING unsupported self-only position validation; no policy load/save or private assessment factory")
            output("accessibility=true login=\(SMAppService.mainApp.status) mode=\(env[Self.modeKey]!)")
            output("bundle=\(SelfPositionPlan.bundleIdentifier) target=fish autosave=\(SelfPositionPlan.autosaveName) value=500 seconds=60 fallbackPosition=unchanged")
            output("baseline=\(try plan.baseline.fingerprint) plan=\(try plan.fingerprint)")

            if env[Self.modeKey] == "PREVIEW" {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(plan).write(to: url, options: .withoutOverwriting)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                try createItems(autosaveName: nil)
                try await Task.sleep(for: .seconds(1))
                guard items?.debugValidateNativeFallbackPresentation() == true,
                      items?.debugOrdinaryRevealHasDedicatedButton == true,
                      try backend.capture() == plan.baseline else {
                    throw SelfPositionValidationError.unexpectedStateChange
                }
                output("PREVIEW PASS writerCreated=false positionChanged=false policyChanged=false fixtures=true \(items?.debugSelfPositionSummary ?? "items=missing")")
                quitOnRunLoop()
                return
            }

            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 65_536,
                  (attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600 else {
                throw SelfPositionValidationError.invalidScope
            }
            let reviewed = try JSONDecoder().decode(SelfPositionPlan.self, from: Data(contentsOf: url))
            try reviewed.validate()
            guard reviewed == plan else { throw SelfPositionValidationError.staleState }
            let lease = SelfPositionValidationLease(backend: backend, plan: plan,
                confirmation: env["BLENNY_SELF_POSITION_CONFIRM"] ?? "", recoveryOnly: isRecovery)
            self.lease = lease
            let writer = RevealAssertionWriter(factory: SelfPositionValidationFactory(lease: lease))
            self.writer = writer
            try await writer.replace(with: SelfPositionPlan.writerToken)
            guard !stopping else { return }
            if isRecovery {
                output("RECOVERY VERIFIED no status items created; experiment keys restored")
                quitOnRunLoop()
                return
            }
            output("APPLY VERIFIED privateAssertionCreated=false \(items?.debugSelfPositionSummary ?? "items=missing")")
            try await Task.sleep(for: .seconds(SelfPositionPlan.durationSeconds))
            output("deadline requesting normal Quit and serial restoration")
            quitOnRunLoop()
        } catch is CancellationError {
            // The normal termination path owns cleanup. Cancellation never
            // schedules another launch, mutation or retry.
        } catch {
            output("VALIDATION FAILED \(error)")
            quitOnRunLoop()
        }
    }

    private func createItems(autosaveName: String?) throws {
        guard items == nil, !stopping else { throw SelfPositionValidationError.stopped }
        Self.creationAutosaveName = autosaveName
        defer { Self.creationAutosaveName = nil }
        let items = StatusItemController(onOpenDiagnostics: {}, onRefresh: {}, onRequestAccess: {},
            onToggleOrdinaryReveal: {}, onResumeManaging: {}, onStopManaging: {},
            onRestorePreviousPolicy: {}, onQuit: { NSApplication.shared.terminate(nil) })
        self.items = items
        items.setAccessibilityTrusted(true)
        items.setManagementState(.stopped, persistedManagementEnabled: false,
                                 recoveryAvailable: false, hasRevealableBundles: false)
        observer.start(onAgentConnectionLost: { [weak self] in self?.quitOnRunLoop() }) { [weak self] snapshot in
            self?.items?.setNativeOverflow(snapshot)
        }
        output("itemsCreated selfPosition=\(autosaveName == nil ? "none" : "500") \(items.debugSelfPositionSummary)")
    }

    private func removeItems() {
        observer.stop()
        items?.debugRemoveOrdinaryStatusItems()
        items = nil
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !stopping else { return .terminateLater }
        stopping = true
        task?.cancel()
        observer.stop()
        guard let writer else {
            removeItems()
            output("EXIT no writer; no position cleanup write")
            return .terminateNow
        }
        Task {
            await writer.restoreAndStop()
            output("RESTORE verified=\(lease?.restoreVerified == true) failure=\(lease?.failure ?? "none")")
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private func quitOnRunLoop() {
        RunLoop.main.perform(inModes: [.common]) {
            MainActor.assumeIsolated { NSApplication.shared.terminate(nil) }
        }
    }

    private func output(_ value: String) {
        FileHandle.standardOutput.write(Data("SELF_POSITION \(value)\n".utf8))
    }
}
#endif
