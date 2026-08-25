#if DEBUG
import AppKit
import BlennyCore
import Foundation

@MainActor
final class DebugRevealablePrototypeController {
    static let targetEnvironmentKey = "BLENNY_0_0_2_REVEALABLE_BUNDLE_ID"
    static let realWriteEnvironmentKey = "BLENNY_ENABLE_0_0_2_REAL_WRITES"
    static let revealSessionTimeout: Duration = .seconds(30)
    static let experimentTimeout: Duration = .seconds(300)

    private let statusItemController: StatusItemController
    private let nativeOverflowObserver = NativeOverflowObserver()
    private let assignments: BundlePolicyAssignments
    private let observedBundleIdentifiers: Set<String>
    private let blennyBundleIdentifier: String
    private let realWritesEnabled: Bool
    private let fallbackInstalledAndRegistered: Bool
    private let writer: RevealAssertionWriter?

    private var reducer = RevealSessionReducer()
    private var eventSequence: UInt64 = 0
    private var eventQueue: [RevealSessionEvent] = []
    private var eventProcessingTask: Task<Void, Never>?
    private var sessionTimeoutTask: Task<Void, Never>?
    private var experimentTimeoutTask: Task<Void, Never>?
    private var bootstrapping = true
    private var pendingNativeSnapshot: NativeOverflowObservationSnapshot?
    private var stopped = false

    init?(statusItemController: StatusItemController) {
        let environment = ProcessInfo.processInfo.environment
        guard let targetBundleIdentifier = environment[Self.targetEnvironmentKey],
              !targetBundleIdentifier.isEmpty,
              let blennyBundleIdentifier = Bundle.main.bundleIdentifier else {
            return nil
        }

        let observedBundleIdentifiers = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        )
        guard observedBundleIdentifiers.contains(targetBundleIdentifier) else {
            return nil
        }

        do {
            self.assignments = try BundlePolicyAssignments(
                pinned: [blennyBundleIdentifier],
                revealable: [targetBundleIdentifier],
                // Hidden is logic-only in 0.0.2. This deliberately nonexistent
                // identifier cannot apply a policy to a real target application.
                hidden: ["com.example.Blenny.Hidden.LogicalOnly"]
            )
        } catch {
            return nil
        }

        self.statusItemController = statusItemController
        self.observedBundleIdentifiers = observedBundleIdentifiers
        self.blennyBundleIdentifier = blennyBundleIdentifier
        self.realWritesEnabled = environment[Self.realWriteEnvironmentKey] == "YES"
        self.fallbackInstalledAndRegistered = Self.isInstalledAndRegistered(
            bundleIdentifier: blennyBundleIdentifier
        )

        if realWritesEnabled {
            do {
                self.writer = RevealAssertionWriter(
                    factory: try ExperimentalMacOS27AssessmentFactory(),
                    activationTimeout: .seconds(1)
                )
            } catch {
                return nil
            }
        } else {
            self.writer = nil
        }
    }

    var isRunning: Bool { !stopped }

    func start() {
        statusItemController.configureDebugRevealPrototype { [weak self] in
            self?.enqueueFallbackToggle()
        }
        statusItemController.updateDebugRevealPrototype(
            entryPoint: nil,
            presentation: .baseline,
            enabled: false,
            status: realWritesEnabled ? "preparing bounded real run" : "dry-run"
        )

        // Establish the installed fallback before any baseline assertion.
        guard !realWritesEnabled || fallbackInstalledAndRegistered else {
            failClosed(status: "real run refused: installed fallback unavailable")
            return
        }

        nativeOverflowObserver.start { [weak self] snapshot in
            self?.receivedNativeOverflow(snapshot)
        }
        Task { @MainActor [weak self] in
            await self?.activateInitialBaseline()
        }

        experimentTimeoutTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.experimentTimeout)
            } catch {
                return
            }
            await self?.stop(reason: "five-minute experiment timeout restored")
        }
    }

    func stop(reason: String = "restored on exit") async {
        guard !stopped else { return }
        stopped = true
        sessionTimeoutTask?.cancel()
        experimentTimeoutTask?.cancel()
        eventProcessingTask?.cancel()
        nativeOverflowObserver.stop()
        await writer?.restoreAndStop()
        statusItemController.updateDebugRevealPrototype(
            entryPoint: nil,
            presentation: .baseline,
            enabled: false,
            status: reason
        )
    }

    private func receivedNativeOverflow(
        _ snapshot: NativeOverflowObservationSnapshot
    ) {
        if bootstrapping {
            pendingNativeSnapshot = snapshot
            return
        }
        debugLog(
            "BLENNY_0_0_2 native_present=\(snapshot.isPresent) "
                + "native_state=\(snapshot.presentationState.rawValue) "
                + "observer_available=\(snapshot.observationAvailable)"
        )
        enqueue(
            .entryAvailabilityChanged(
                nativeOverflowPresent: snapshot.isPresent
                    && snapshot.observationAvailable,
                blennyFallbackInstalled: fallbackInstalledAndRegistered
                    || !realWritesEnabled,
                sequence: nextSequence()
            )
        )
        switch snapshot.presentationState {
        case .expanded:
            enqueue(.nativeOverflowChanged(expanded: true, sequence: nextSequence()))
        case .collapsed:
            enqueue(.nativeOverflowChanged(expanded: false, sequence: nextSequence()))
        case .unknown:
            break
        }
    }

    private func activateInitialBaseline() async {
        do {
            let snapshot = pendingNativeSnapshot ?? .unavailable
            pendingNativeSnapshot = nil
            let entryDisposition = reducer.reduce(
                .entryAvailabilityChanged(
                    nativeOverflowPresent: snapshot.isPresent
                        && snapshot.observationAvailable,
                    blennyFallbackInstalled: fallbackInstalledAndRegistered
                        || !realWritesEnabled,
                    sequence: nextSequence()
                )
            )
            if entryDisposition == .failedClosed {
                throw RevealEntryPointSelectionError.noUsableEntryPoint
            }
            updateStatus(entryPoint: reducer.entryPoint)
            let plan = try makePlan(presentation: .baseline)
            logPlan(plan)
            try await writer?.replace(with: plan)
            bootstrapping = false
            updateStatus(entryPoint: reducer.entryPoint)
        } catch {
            await stop(reason: "baseline activation failed; fully restored")
        }
    }

    private func enqueueFallbackToggle() {
        enqueue(.blennyFallbackToggled(sequence: nextSequence()))
    }

    private func nextSequence() -> UInt64 {
        eventSequence += 1
        return eventSequence
    }

    private func enqueue(_ event: RevealSessionEvent) {
        guard !stopped else { return }
        eventQueue.append(event)
        guard eventProcessingTask == nil else { return }
        eventProcessingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !self.eventQueue.isEmpty, !Task.isCancelled {
                let next = self.eventQueue.removeFirst()
                await self.process(next)
            }
            self.eventProcessingTask = nil
        }
    }

    private func process(_ event: RevealSessionEvent) async {
        let precedingReducer = reducer
        let disposition = reducer.reduce(event)
        switch disposition {
        case .ignoredDuplicateOrOutOfOrder,
             .ignoredInactiveEntryPoint,
             .noChange:
            return

        case let .entryPointChanged(entryPoint):
            updateStatus(entryPoint: entryPoint)

        case let .transitionRequired(presentation):
            do {
                let plan = try makePlan(presentation: presentation)
                logPlan(plan)
                let transitionStart = ContinuousClock.now
                try await writer?.replace(with: plan)
                let elapsed = transitionStart.duration(to: .now)
                debugLog(
                    "BLENNY_0_0_2 transition=\(presentation.rawValue) "
                        + "elapsed=\(elapsed)"
                )
                updateTimeout(for: presentation)
                updateStatus(entryPoint: reducer.entryPoint)
            } catch {
                reducer = precedingReducer
                if presentation == .baseline {
                    await stop(reason: "conceal failed; restriction fully restored")
                } else {
                    updateStatus(
                        entryPoint: reducer.entryPoint,
                        detail: "reveal failed; old baseline preserved"
                    )
                }
            }

        case .restoreRequired:
            await writer?.connectionInvalidated()
            updateStatus(entryPoint: reducer.entryPoint, detail: "connection restored")

        case .failedClosed:
            await stop(reason: "no usable reveal entry; fully restored")
        }
    }

    private func makePlan(
        presentation: RevealSessionPresentation
    ) throws -> RevealAllowlistPlan {
        try RevealAllowlistPlanner.plan(
            presentation: presentation,
            assignments: assignments,
            observedRunningBundleIdentifiers: observedBundleIdentifiers,
            blennyBundleIdentifier: blennyBundleIdentifier
        )
    }

    private func logPlan(_ plan: RevealAllowlistPlan) {
        let targetAllowed = plan.allowedBundleIdentifiers.contains(
            assignments.revealable.first ?? ""
        )
        let hiddenAllowed = !assignments.hidden.isDisjoint(
            with: plan.allowedBundleIdentifiers
        )
        debugLog(
            "BLENNY_0_0_2 mode=\(realWritesEnabled ? "REAL" : "DRY_RUN") "
                + "plan=\(plan.presentation.rawValue) "
                + "bundle_count=\(plan.allowedBundleIdentifiers.count) "
                + "system_items=\(plan.allowedSystemItems) "
                + "revealable_allowed=\(targetAllowed) hidden_allowed=\(hiddenAllowed)"
        )
    }

    private func debugLog(_ message: String) {
        guard let data = "\(message)\n".data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }

    private func updateTimeout(for presentation: RevealSessionPresentation) {
        sessionTimeoutTask?.cancel()
        sessionTimeoutTask = nil
        guard presentation == .revealed else { return }
        sessionTimeoutTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.revealSessionTimeout)
            } catch {
                return
            }
            guard let self else { return }
            self.enqueue(.sessionTimedOut(sequence: self.nextSequence()))
        }
    }

    private func updateStatus(
        entryPoint: RevealEntryPoint?,
        detail: String? = nil
    ) {
        let mode = realWritesEnabled ? "REAL" : "DRY-RUN"
        let entry = entryPoint?.rawValue ?? "none"
        let detailSuffix = detail.map { "; \($0)" } ?? ""
        debugLog(
            "BLENNY_0_0_2 state=\(reducer.presentation.rawValue) "
                + "entry=\(entry)\(detailSuffix)"
        )
        statusItemController.updateDebugRevealPrototype(
            entryPoint: entryPoint,
            presentation: reducer.presentation,
            enabled: entryPoint != nil,
            status: "\(mode) \(reducer.presentation.rawValue), \(entry)\(detailSuffix)"
        )
    }

    private func failClosed(status: String) {
        stopped = true
        statusItemController.updateDebugRevealPrototype(
            entryPoint: nil,
            presentation: .baseline,
            enabled: false,
            status: status
        )
    }

    private static func isInstalledAndRegistered(
        bundleIdentifier: String
    ) -> Bool {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        let isInstalled = bundleURL.path.hasPrefix("/Applications/")
        guard isInstalled,
              let registeredURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleIdentifier
              )?.standardizedFileURL else {
            return false
        }
        return registeredURL == bundleURL
    }
}
#endif
