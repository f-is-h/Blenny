#if DEBUG
import AppKit
import BlennyCore

/// Isolated Apple-system-item experiment. Normal policy, application UI and
/// ordinary management never start in this process.
@MainActor
final class DebugSystemItemVisibilityValidationDelegate: NSObject, NSApplicationDelegate {
    static let modeKey = "BLENNY_SYSTEM_ITEM_VISIBILITY_VALIDATION"
    static let receiptKey = "BLENNY_SYSTEM_ITEM_VISIBILITY_RECEIPT"
    static let confirmationKey = "BLENNY_SYSTEM_ITEM_VISIBILITY_CONFIRM"
    static let targetKey = "BLENNY_SYSTEM_ITEM_VISIBILITY_TARGET"

    private var assessmentFactory: ExperimentalMacOS27AssessmentFactory?
    private var candidate: SystemItemVisibilityValidationCandidate?
    private var writer: RevealAssertionWriter?
    private var task: Task<Void, Never>?
    private var stopping = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        task = Task { await run() }
    }

    private func run() async {
        do {
            let environment = ProcessInfo.processInfo.environment
            let mode = environment[Self.modeKey] ?? ""
            guard ["PREVIEW", "APPLY", "RECOVER"].contains(mode),
                  Bundle.main.bundleIdentifier == SystemItemVisibilityPlan.bundleIdentifier,
                  Bundle.main.bundleURL.standardizedFileURL.path == "/Applications/Blenny.app",
                  NSRunningApplication.runningApplications(
                    withBundleIdentifier: SystemItemVisibilityPlan.bundleIdentifier
                  ).count == 1,
                  NSWorkspace.shared.urlForApplication(
                    withBundleIdentifier: SystemItemVisibilityPlan.bundleIdentifier
                  )?.resolvingSymlinksInPath().standardizedFileURL
                    == Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL,
                  AccessibilityAuthorization.isTrusted,
                  let receiptPath = environment[Self.receiptKey] else {
                throw SystemItemVisibilityValidationError.invalidScope
            }
            let receiptURL = URL(fileURLWithPath: receiptPath).standardizedFileURL
            guard receiptURL.deletingLastPathComponent().resolvingSymlinksInPath()
                    .pathComponents.contains("LocalData") else {
                throw SystemItemVisibilityValidationError.invalidScope
            }
            let backend = MacOS27SystemItemVisibilityBackend(
                diagnostic: { [weak self] message in self?.output(message) }
            )
            let plan: SystemItemVisibilityPlan
            if mode == "PREVIEW" {
                guard let target = SystemItemVisibilityTarget(
                    rawValue: environment[Self.targetKey] ?? "bluetooth"
                ) else { throw SystemItemVisibilityValidationError.invalidScope }
                plan = try SystemItemVisibilityPlan(
                    runtime: .current(), baseline: await backend.capture(), target: target
                )
            } else {
                plan = try decodePlan(receiptURL)
                if let requestedTarget = environment[Self.targetKey],
                   requestedTarget != plan.target.rawValue {
                    throw SystemItemVisibilityValidationError.invalidScope
                }
            }

            output("WARNING unsupported Debug-only Apple system-item visibility validation")
            output("mode=\(mode) target=\(plan.target.displayName) privateRaw=\(plan.target.identity.rawValue) privateName=\(plan.target.identity.privateName) ax=\(plan.target.axIdentifier)")
            output("allowedSystemItems=\(plan.allowedSystemItems) protected=all-other-required-system-identities nativeOverflow=dynamic-zero-or-one")
            output("preferenceWrite=false systemUIRestart=false duration=\(SystemItemVisibilityPlan.durationSeconds) writer=\(mode == "APPLY")")
            output("bundles=\(plan.baseline.runningBundleIdentifiers.count) files=\(plan.baseline.localFileDigests.count) plan=\(try plan.fingerprint)")

            if mode == "PREVIEW" {
                let fresh = try await backend.capture()
                do {
                    try plan.validateFresh(fresh)
                } catch {
                    output(staleDifference(baseline: plan.baseline, fresh: fresh))
                    throw SystemItemVisibilityValidationError.staleState
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                try encoder.encode(plan).write(to: receiptURL, options: .withoutOverwriting)
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o600], ofItemAtPath: receiptURL.path
                )
                output("PREVIEW PASS writerCreated=false assertionCreated=false preferenceChanged=false fileHashChanged=false")
                quitOnRunLoop()
                return
            }

            if mode == "RECOVER" {
                try plan.validateRestored(await backend.capture())
                output("RECOVERY VERIFIED baselineState=true preferenceState=true fileHashes=true writerCreated=false")
                quitOnRunLoop()
                return
            }

            let assessmentFactory = try ExperimentalMacOS27AssessmentFactory()
            self.assessmentFactory = assessmentFactory
            let inner = try assessmentFactory.makeCandidate(for: plan.writerPlan)
            let candidate = SystemItemVisibilityValidationCandidate(
                backend: backend,
                inner: inner,
                plan: plan,
                confirmation: environment[Self.confirmationKey] ?? ""
            )
            self.candidate = candidate
            let writer = RevealAssertionWriter(
                factory: SystemItemVisibilityValidationFactory(
                    candidate: candidate, expectedPlan: plan.writerPlan
                ),
                activationTimeout: .seconds(10)
            )
            self.writer = writer
            try await writer.replace(with: plan.writerPlan)
            let writerActive = try await writer.verifyActivePlan(plan.writerPlan)
            guard writerActive, candidate.appliedVerified else {
                throw SystemItemVisibilityValidationError.unexpectedStateChange
            }
            output(
                "OBSERVATION READY target=\(plan.target.displayName) targetVisible=false"
                    + " criticalSystemCountsUnchanged=true"
                    + " nativeOverflow=\(candidate.observedNativeOverflowCount)"
                    + " baselineNativeOverflow=\(plan.baseline.nativeOverflowFrames.count)"
                    + " preferencesUnchanged=true fileHashesUnchanged=true"
                    + " holdSeconds=\(SystemItemVisibilityPlan.durationSeconds)"
            )
            try await Task.sleep(for: .seconds(SystemItemVisibilityPlan.durationSeconds / 2))
            output("RESTORE WARNING remainingSeconds=\(SystemItemVisibilityPlan.durationSeconds / 2) ownerObservationCheckpoint=true")
            try await Task.sleep(for: .seconds(SystemItemVisibilityPlan.durationSeconds / 2))
            output("deadline requesting normal Quit and serial assertion invalidation")
            quitOnRunLoop()
        } catch is CancellationError {
            // Termination owns cleanup. Cancellation never schedules another
            // assertion, write, launch or retry.
        } catch {
            output("VALIDATION FAILED \(error)")
            quitOnRunLoop()
        }
    }

    private func decodePlan(_ url: URL) throws -> SystemItemVisibilityPlan {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 4_194_304,
              (attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600 else {
            throw SystemItemVisibilityValidationError.invalidScope
        }
        let plan = try JSONDecoder().decode(
            SystemItemVisibilityPlan.self, from: Data(contentsOf: url)
        )
        try plan.validate()
        guard plan.runtime == RuntimeEnvironment.current() else {
            throw SystemItemVisibilityValidationError.invalidScope
        }
        return plan
    }

    private func staleDifference(
        baseline: SystemItemVisibilitySnapshot,
        fresh: SystemItemVisibilitySnapshot
    ) -> String {
        "STALE DIFFERENCE"
            + " complete=\(baseline.captureComplete == fresh.captureComplete)"
            + " systemItems=\(baseline.systemItems == fresh.systemItems)"
            + " nativeOverflow=\(baseline.nativeOverflowFrames == fresh.nativeOverflowFrames)"
            + " preferences=\(baseline.scopedPreferences == fresh.scopedPreferences)"
            + " files=\(baseline.localFileDigests == fresh.localFileDigests)"
            + " bundles=\(baseline.runningBundleIdentifiers == fresh.runningBundleIdentifiers)"
    }

    func applicationShouldTerminate(
        _ sender: NSApplication
    ) -> NSApplication.TerminateReply {
        guard !stopping else { return .terminateLater }
        stopping = true
        task?.cancel()
        guard let writer else {
            output("EXIT no writer; no assertion invalidation required")
            return .terminateNow
        }
        Task {
            await writer.restoreAndStop()
            output(
                "RESTORE verified=\(candidate?.restoreVerified == true)"
                    + " preferenceState=\(candidate?.restoreVerified == true)"
                    + " fileHashes=\(candidate?.restoreVerified == true)"
                    + " retryCount=0 failure=\(candidate?.failure ?? "none")"
            )
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
        FileHandle.standardOutput.write(Data("SYSTEM_ITEM_VISIBILITY \(value)\n".utf8))
    }
}
#endif
