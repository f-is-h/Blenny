#if DEBUG
import AppKit
import BlennyCore
import ServiceManagement

/// Installed, owner-driven calibration for one Blenny fish. The process never
/// loads normal policy and never moves the pointer or another owner's item.
@MainActor
final class DebugManualPositionCalibrationDelegate: NSObject,
    NSApplicationDelegate {
    static let modeKey = "BLENNY_MANUAL_POSITION_CALIBRATION"
    static let receiptKey = "BLENNY_MANUAL_POSITION_RECEIPT"
    static let confirmationKey = "BLENNY_MANUAL_POSITION_CONFIRM"
    private(set) static var creationAutosaveName: String?

    private var items: StatusItemController?
    private let observer = NativeOverflowObserver(reconnectOnAgentChange: false)
    private var lease: ManualPositionCalibrationLease?
    private var writer: RevealAssertionWriter?
    private var task: Task<Void, Never>?
    private var receiptURL: URL?
    private var plan: ManualPositionCalibrationPlan?
    private var captured = false
    private var stopping = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        task = Task { await run() }
    }

    private func run() async {
        do {
            let env = ProcessInfo.processInfo.environment
            let mode = env[Self.modeKey] ?? ""
            guard ["PREVIEW", "CAPTURE", "RECOVER"].contains(mode),
                  Bundle.main.bundleIdentifier
                    == ManualPositionCalibrationPlan.bundleIdentifier,
                  Bundle.main.bundleURL.standardizedFileURL.path
                    == "/Applications/Blenny.app",
                  NSRunningApplication.runningApplications(
                    withBundleIdentifier:
                        ManualPositionCalibrationPlan.bundleIdentifier
                  ).count == 1,
                  AccessibilityAuthorization.isTrusted,
                  let path = env[Self.receiptKey] else {
                throw ManualPositionCalibrationError.invalidScope
            }
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard url.deletingLastPathComponent().resolvingSymlinksInPath()
                    .pathComponents.contains("LocalData") else {
                throw ManualPositionCalibrationError.invalidScope
            }
            receiptURL = url

            let backend = MacOS27ManualPositionCalibrationBackend(
                createItems: { [weak self] name in
                    guard let self else {
                        throw ManualPositionCalibrationError.stopped
                    }
                    try self.createItems(autosaveName: name)
                },
                removeItems: { [weak self] in self?.removeItems() },
                readCurrentPreferredPosition: { [weak self] in
                    guard let self, let items = self.items else {
                        throw ManualPositionCalibrationError.stopped
                    }
                    return try items.debugCurrentFishPreferredPosition()
                })
            let recovery = mode == "RECOVER"
            let calibrationPlan: ManualPositionCalibrationPlan
            let reviewedReceipt: ManualPositionCalibrationReceipt?
            if recovery || mode == "CAPTURE" {
                let receipt = try decodeReceipt(url)
                reviewedReceipt = receipt
                calibrationPlan = receipt.plan
            } else {
                reviewedReceipt = nil
                calibrationPlan = try ManualPositionCalibrationPlan(
                    baseline: backend.capture(), runtime: .current())
            }
            try calibrationPlan.validate()
            guard calibrationPlan.runtime == RuntimeEnvironment.current() else {
                throw ManualPositionCalibrationError.invalidScope
            }
            plan = calibrationPlan

            output("WARNING owner-driven self-only manual calibration")
            output("mode=\(mode) accessibility=true login=\(SMAppService.mainApp.status)")
            output("target=fish autosave=\(ManualPositionCalibrationPlan.autosaveName) seconds=\(ManualPositionCalibrationPlan.durationSeconds)")
            output("baseline=\(try calibrationPlan.baseline.fingerprint) plan=\(try calibrationPlan.fingerprint)")

            if mode == "PREVIEW" {
                try writeReceipt(ManualPositionCalibrationReceipt(
                    plan: calibrationPlan), to: url, withoutOverwriting: true)
                try createItems(autosaveName: nil)
                try await Task.sleep(for: .seconds(1))
                guard items?.debugValidateNativeFallbackPresentation() == true,
                      items?.debugValidateCurrentFishPreferredPositionContract() == true,
                      try backend.capture() == calibrationPlan.baseline else {
                    throw ManualPositionCalibrationError.unexpectedStateChange
                }
                output("PREVIEW PASS writerCreated=false autosaveAssigned=false positionChanged=false \(items?.debugSelfPositionSummary ?? "items=missing")")
                quitOnRunLoop()
                return
            }

            guard reviewedReceipt?.plan == calibrationPlan else {
                throw ManualPositionCalibrationError.staleState
            }
            if mode == "CAPTURE" {
                guard reviewedReceipt?.observation == nil else {
                    throw ManualPositionCalibrationError.staleState
                }
            }
            let lease = ManualPositionCalibrationLease(backend: backend,
                plan: calibrationPlan,
                confirmation: env[Self.confirmationKey] ?? "",
                recoveryOnly: recovery)
            self.lease = lease
            let writer = RevealAssertionWriter(
                factory: ManualPositionCalibrationFactory(lease: lease))
            self.writer = writer
            try await writer.replace(with:
                ManualPositionCalibrationPlan.writerToken)
            guard !stopping else { return }
            if recovery {
                output("RECOVERY VERIFIED experiment keys restored; no items created")
                quitOnRunLoop()
                return
            }

            items?.debugInstallManualPositionCapture { [weak self] in
                self?.recordManualPosition()
            }
            output("CAPTURE ARMED drag only the fish once with Command, then use its Record Manual Position menu item")
            try await Task.sleep(for: .seconds(
                ManualPositionCalibrationPlan.durationSeconds))
            guard !captured else { return }
            output("CAPTURE TIMEOUT no explicit Record Manual Position action received")
            quitOnRunLoop()
        } catch is CancellationError {
        } catch {
            output("CALIBRATION FAILED \(error)")
            quitOnRunLoop()
        }
    }

    private func recordManualPosition() {
        guard !captured, !stopping,
              let lease, let plan, let receiptURL else { return }
        do {
            let observation = try lease.recordCurrent()
            captured = true
            try writeReceipt(ManualPositionCalibrationReceipt(
                plan: plan, observation: observation), to: receiptURL,
                withoutOverwriting: false)
            output("CAPTURED savedPosition=\(observation.savedPosition.map { String($0) } ?? "absent") runtimePreferredPosition=\(observation.runtimePreferredPosition)")
            quitOnRunLoop()
        } catch {
            output("CALIBRATION FAILED event=\(error)")
            quitOnRunLoop()
        }
    }

    private func decodeReceipt(_ url: URL) throws
        -> ManualPositionCalibrationReceipt {
        let attributes = try FileManager.default.attributesOfItem(
            atPath: url.path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 65_536,
              (attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600 else {
            throw ManualPositionCalibrationError.invalidScope
        }
        return try JSONDecoder().decode(ManualPositionCalibrationReceipt.self,
            from: Data(contentsOf: url))
    }

    private func writeReceipt(_ receipt: ManualPositionCalibrationReceipt,
                              to url: URL,
                              withoutOverwriting: Bool) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(receipt).write(to: url,
            options: withoutOverwriting ? .withoutOverwriting : .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600],
            ofItemAtPath: url.path)
    }

    private func createItems(autosaveName: String?) throws {
        guard items == nil, !stopping else {
            throw ManualPositionCalibrationError.stopped
        }
        Self.creationAutosaveName = autosaveName
        defer { Self.creationAutosaveName = nil }
        let controller = StatusItemController(onOpenDiagnostics: {},
            onRefresh: {}, onRequestAccess: {},
            onToggleOrdinaryReveal: {}, onResumeManaging: {},
            onStopManaging: {}, onRestorePreviousPolicy: {},
            onQuit: { NSApplication.shared.terminate(nil) })
        items = controller
        controller.setAccessibilityTrusted(true)
        controller.setManagementState(.stopped,
            persistedManagementEnabled: false, recoveryAvailable: false,
            hasRevealableBundles: false)
        observer.start(onAgentConnectionLost: { [weak self] in
            self?.quitOnRunLoop()
        }) { [weak self] snapshot in
            self?.items?.setNativeOverflow(snapshot)
        }
        output("itemsCreated \(controller.debugSelfPositionSummary)")
    }

    private func removeItems() {
        observer.stop()
        items?.debugRemoveOrdinaryStatusItems()
        items = nil
    }

    func applicationShouldTerminate(_ sender: NSApplication)
        -> NSApplication.TerminateReply {
        guard !stopping else { return .terminateLater }
        stopping = true
        task?.cancel()
        observer.stop()
        guard let writer else {
            removeItems()
            output("EXIT no writer; no calibration cleanup write")
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
            MainActor.assumeIsolated {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func output(_ value: String) {
        FileHandle.standardOutput.write(
            Data("MANUAL_POSITION \(value)\n".utf8))
    }
}
#endif
