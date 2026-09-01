#if DEBUG
import AppKit
import BlennyCore
import ServiceManagement

/// Isolated self-only MenuBarAgent position-table experiment. Ordinary policy,
/// assessment assertions and the normal app delegate never start in this process.
@MainActor
final class DebugAgentPositionValidationDelegate: NSObject, NSApplicationDelegate {
    static let modeKey = "BLENNY_AGENT_POSITION_VALIDATION"
    static let receiptKey = "BLENNY_AGENT_POSITION_RECEIPT"
    static let confirmationKey = "BLENNY_AGENT_POSITION_CONFIRM"
    private(set) static var creationAutosaveName: String?
    private var items: StatusItemController?
    private let observer = NativeOverflowObserver(reconnectOnAgentChange: false)
    private var lease: AgentPositionValidationLease?
    private var writer: RevealAssertionWriter?
    private var task: Task<Void, Never>?
    private var stopping = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        task = Task { await run() }
    }

    private func run() async {
        do {
            let env = ProcessInfo.processInfo.environment
            let mode = env[Self.modeKey] ?? ""
            guard ["PREVIEW", "APPLY", "RECOVER"].contains(mode),
                  Bundle.main.bundleIdentifier == AgentPositionPlan.bundleIdentifier,
                  Bundle.main.bundleURL.standardizedFileURL.path == "/Applications/Blenny.app",
                  NSRunningApplication.runningApplications(
                    withBundleIdentifier: AgentPositionPlan.bundleIdentifier
                  ).count == 1,
                  AccessibilityAuthorization.isTrusted,
                  let path = env[Self.receiptKey] else {
                throw AgentPositionValidationError.invalidScope
            }
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard url.deletingLastPathComponent().resolvingSymlinksInPath()
                    .pathComponents.contains("LocalData") else {
                throw AgentPositionValidationError.invalidScope
            }
            let backend = MacOS27AgentPositionBackend(
                createItems: { [weak self] name in try self?.createItems(name) },
                removeItems: { [weak self] in self?.removeItems() })
            let recovery = mode == "RECOVER"
            let plan: AgentPositionPlan
            if recovery {
                plan = try decodePlan(url)
            } else {
                plan = try AgentPositionPlan(baseline: backend.capture(), runtime: .current())
            }
            output("WARNING unsupported self-only MenuBarAgent table experiment")
            output("mode=\(mode) accessibility=true login=\(SMAppService.mainApp.status)")
            output("domain=\(AgentPositionPlan.domain) key=\(AgentPositionPlan.preferenceKey) target=\(AgentPositionPlan.targetIdentifier) weight=\(AgentPositionPlan.weight) seconds=\(AgentPositionPlan.durationSeconds)")
            output("baseline=\(plan.baseline.encodedDictionary == nil ? "absent" : "present") plan=\(try plan.fingerprint)")

            if mode == "PREVIEW" {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(plan).write(to: url, options: .withoutOverwriting)
                try FileManager.default.setAttributes([.posixPermissions: 0o600],
                    ofItemAtPath: url.path)
                try createItems(nil)
                try await Task.sleep(for: .seconds(1))
                guard items?.debugValidateNativeFallbackPresentation() == true,
                      try backend.capture() == plan.baseline else {
                    throw AgentPositionValidationError.unexpectedStateChange
                }
                output("PREVIEW PASS writerCreated=false agentTableChanged=false policyChanged=false \(items?.debugSelfPositionSummary ?? "items=missing")")
                quitOnRunLoop()
                return
            }

            let reviewed = try decodePlan(url)
            guard reviewed == plan else { throw AgentPositionValidationError.staleState }
            let lease = AgentPositionValidationLease(backend: backend, plan: plan,
                confirmation: env[Self.confirmationKey] ?? "", recoveryOnly: recovery)
            self.lease = lease
            let writer = RevealAssertionWriter(factory: AgentPositionValidationFactory(lease: lease))
            self.writer = writer
            try await writer.replace(with: AgentPositionPlan.writerToken)
            if recovery {
                output("RECOVERY VERIFIED agent table restored; no items created")
                quitOnRunLoop()
                return
            }
            output("APPLY VERIFIED agentTableChanged=true privateAssertionCreated=false \(items?.debugSelfPositionSummary ?? "items=missing")")
            try await Task.sleep(for: .seconds(AgentPositionPlan.durationSeconds))
            output("deadline requesting normal Quit and serial preference restoration")
            quitOnRunLoop()
        } catch is CancellationError {
        } catch {
            output("VALIDATION FAILED \(error)")
            quitOnRunLoop()
        }
    }

    private func decodePlan(_ url: URL) throws -> AgentPositionPlan {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 65_536,
              (attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600 else {
            throw AgentPositionValidationError.invalidScope
        }
        let plan = try JSONDecoder().decode(AgentPositionPlan.self, from: Data(contentsOf: url))
        try plan.validate()
        guard plan.runtime == RuntimeEnvironment.current() else {
            throw AgentPositionValidationError.invalidScope
        }
        return plan
    }

    private func createItems(_ autosaveName: String?) throws {
        guard items == nil, !stopping else { throw AgentPositionValidationError.stopped }
        Self.creationAutosaveName = autosaveName
        defer { Self.creationAutosaveName = nil }
        let controller = StatusItemController(onOpenDiagnostics: {}, onRefresh: {},
            onRequestAccess: {}, onToggleOrdinaryReveal: {}, onResumeManaging: {},
            onStopManaging: {}, onRestorePreviousPolicy: {},
            onQuit: { NSApplication.shared.terminate(nil) })
        items = controller
        controller.setAccessibilityTrusted(true)
        controller.setManagementState(.stopped, persistedManagementEnabled: false,
            recoveryAvailable: false, hasRevealableBundles: false)
        observer.start(onAgentConnectionLost: { [weak self] in self?.quitOnRunLoop() }) {
            [weak self] snapshot in self?.items?.setNativeOverflow(snapshot)
        }
        output("itemsCreated autosave=\(autosaveName ?? "none") \(controller.debugSelfPositionSummary)")
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
            output("EXIT no writer; no agent-table cleanup write")
            return .terminateNow
        }
        Task {
            await writer.restoreAndStop()
            output("RESTORE preferenceVerified=\(lease?.restoreVerified == true) physicalOrderNotGuaranteed=true failure=\(lease?.failure ?? "none")")
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
        FileHandle.standardOutput.write(Data("AGENT_POSITION \(value)\n".utf8))
    }
}
#endif
