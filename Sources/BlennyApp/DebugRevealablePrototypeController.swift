#if DEBUG
import AppKit
import ApplicationServices
import BlennyCore
import Foundation

@MainActor
final class DebugPolicyCoexistenceController {
    static let revealableEnvironmentKey = "BLENNY_0_0_3_REVEALABLE_BUNDLE_ID"
    static let hiddenEnvironmentKey = "BLENNY_0_0_3_HIDDEN_BUNDLE_ID"
    static let realWriteEnvironmentKey = "BLENNY_ENABLE_0_0_3_REAL_WRITES"
    static let approvedRevealableBundleIdentifier = "xyz.fi5h.Usage4Claude"
    static let approvedHiddenBundleIdentifier = "pl.maketheweb.cleanshotx"
    static let revealSessionTimeout: Duration = .seconds(30)
    static let experimentTimeout: Duration = .seconds(300)

    private let statusItemController: StatusItemController
    private let nativeOverflowObserver = NativeOverflowObserver()
    private let assignments: BundlePolicyAssignments
    private let observedBundleIdentifiers: Set<String>
    private let blennyBundleIdentifier: String
    private let targetObservations: [MenuBarPolicyTargetObservation]
    private let realWritesEnabled: Bool
    private let fallbackInstalledAndRegistered: Bool
    private let writer: RevealAssertionWriter?
    private let startedAt = ContinuousClock.now

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
        guard let revealableBundleIdentifier = environment[Self.revealableEnvironmentKey],
              let hiddenBundleIdentifier = environment[Self.hiddenEnvironmentKey],
              revealableBundleIdentifier == Self.approvedRevealableBundleIdentifier,
              hiddenBundleIdentifier == Self.approvedHiddenBundleIdentifier,
              let blennyBundleIdentifier = Bundle.main.bundleIdentifier else {
            Self.debugLog(
                "BLENNY_0_0_3 FAIL_CLOSED exact approved Revealable and Hidden "
                    + "environment values are required"
            )
            return nil
        }

        let observedBundleIdentifiers = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        )
        guard AccessibilityAuthorization.isTrusted else {
            Self.debugLog("BLENNY_0_0_3 FAIL_CLOSED Accessibility is not granted")
            return nil
        }

        let assignments: BundlePolicyAssignments
        do {
            assignments = try BundlePolicyAssignments(
                pinned: [blennyBundleIdentifier],
                revealable: [revealableBundleIdentifier],
                hidden: [hiddenBundleIdentifier]
            )
        } catch {
            Self.debugLog("BLENNY_0_0_3 FAIL_CLOSED overlapping policy assignments")
            return nil
        }

        let targetObservations = [revealableBundleIdentifier, hiddenBundleIdentifier]
            .map { Self.observeMenuBarTarget(bundleIdentifier: $0) }
        do {
            try BoundedPolicyTargetValidator.validate(
                assignments: assignments,
                pinnedBundleIdentifier: blennyBundleIdentifier,
                revealableBundleIdentifier: revealableBundleIdentifier,
                hiddenBundleIdentifier: hiddenBundleIdentifier,
                observations: targetObservations
            )
        } catch {
            Self.debugLog("BLENNY_0_0_3 FAIL_CLOSED target ownership validation failed: \(error)")
            return nil
        }

        self.statusItemController = statusItemController
        self.assignments = assignments
        self.observedBundleIdentifiers = observedBundleIdentifiers
        self.blennyBundleIdentifier = blennyBundleIdentifier
        self.targetObservations = targetObservations
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
        for observation in targetObservations {
            Self.debugLog(
                "BLENNY_0_0_3 PREFLIGHT bundle=\(observation.bundleIdentifier) "
                    + "pid=\(observation.processIdentifiers[0]) "
                    + "menu_bar_items=\(observation.menuBarItemCount)"
            )
        }
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
            guard let self else { return }
            self.debugLog("lifecycle_event=experiment_timeout")
            self.enqueue(.experimentTimedOut(sequence: self.nextSequence()))
        }
    }

    func stop(reason: String = "restored on exit") async {
        guard !stopped else { return }
        debugLog("stop_begin reason=\(reason)")
        stopped = true
        sessionTimeoutTask?.cancel()
        experimentTimeoutTask?.cancel()
        eventProcessingTask?.cancel()
        nativeOverflowObserver.stop()
        await writer?.restoreAndStop()
        statusItemController.restoreDebugStatusItemPlacement()
        statusItemController.updateDebugRevealPrototype(
            entryPoint: nil,
            presentation: .baseline,
            enabled: false,
            status: reason
        )
        debugLog("stop_complete reason=\(reason)")
    }

    private func receivedNativeOverflow(
        _ snapshot: NativeOverflowObservationSnapshot
    ) {
        if bootstrapping {
            pendingNativeSnapshot = snapshot
            return
        }
        debugLog(
            "BLENNY_0_0_3 native_present=\(snapshot.isPresent) "
                + "native_state=\(snapshot.presentationState.rawValue) "
                + "observer_available=\(snapshot.observationAvailable)"
        )
        enqueue(
            .entryAvailabilityChanged(
                nativeOverflowPresent: snapshot.isPresent
                    && snapshot.observationAvailable,
                blennyFallbackInstalled: fallbackInstalledAndRegistered,
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
                    blennyFallbackInstalled: fallbackInstalledAndRegistered,
                    sequence: nextSequence()
                )
            )
            if entryDisposition == .failedClosed {
                throw RevealEntryPointSelectionError.noUsableEntryPoint
            }
            updateStatus(entryPoint: reducer.entryPoint)
            let plan = try makePlan(presentation: .baseline)
            logPlan(plan)
            if !realWritesEnabled {
                logPlan(try makePlan(presentation: .revealed))
            }
            try await writer?.applySessionTransition(with: plan)
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
                try await writer?.applySessionTransition(with: plan)
                let elapsed = transitionStart.duration(to: .now)
                debugLog(
                    "BLENNY_0_0_3 transition=\(presentation.rawValue) "
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
            await stop(reason: "bounded lifecycle ended; fully restored")

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
        let revealableAllowed = plan.allowedBundleIdentifiers.contains(
            assignments.revealable.first ?? ""
        )
        let hiddenAllowed = !assignments.hidden.isDisjoint(
            with: plan.allowedBundleIdentifiers
        )
        debugLog(
            "BLENNY_0_0_3 mode=\(realWritesEnabled ? "REAL" : "DRY_RUN") "
                + "plan=\(plan.presentation.rawValue) "
                + "bundle_count=\(plan.allowedBundleIdentifiers.count) "
                + "system_items=\(plan.allowedSystemItems) "
                + "pinned_allowed=\(plan.allowedBundleIdentifiers.contains(blennyBundleIdentifier)) "
                + "revealable=\(assignments.revealable.first ?? "") "
                + "revealable_allowed=\(revealableAllowed) "
                + "hidden=\(assignments.hidden.first ?? "") "
                + "hidden_allowed=\(hiddenAllowed)"
        )
    }

    private static func debugLog(_ message: String) {
        guard let data = "\(message)\n".data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }

    private func debugLog(_ message: String) {
        Self.debugLog(
            "\(message) elapsed_since_start=\(startedAt.duration(to: .now))"
        )
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
            self.debugLog("lifecycle_event=session_timeout")
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
            "BLENNY_0_0_3 state=\(reducer.presentation.rawValue) "
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

    private static func observeMenuBarTarget(
        bundleIdentifier: String
    ) -> MenuBarPolicyTargetObservation {
        let applications = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        )
        var menuBarItemCount = 0

        for application in applications {
            let applicationElement = AXUIElementCreateApplication(
                application.processIdentifier
            )
            guard AXUIElementSetMessagingTimeout(applicationElement, 0.5) == .success else {
                continue
            }
            var extrasValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                applicationElement,
                kAXExtrasMenuBarAttribute as CFString,
                &extrasValue
            ) == .success,
            let extrasValue,
            CFGetTypeID(extrasValue) == AXUIElementGetTypeID() else {
                continue
            }

            let extrasMenuBar = unsafeDowncast(extrasValue, to: AXUIElement.self)
            var childrenValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                extrasMenuBar,
                kAXChildrenAttribute as CFString,
                &childrenValue
            ) == .success,
            let children = childrenValue as? [AXUIElement] else {
                continue
            }
            menuBarItemCount += children.filter(Self.isTopLevelMenuExtra).count
        }

        return MenuBarPolicyTargetObservation(
            bundleIdentifier: bundleIdentifier,
            processIdentifiers: applications.map { Int32($0.processIdentifier) },
            menuBarItemCount: menuBarItemCount
        )
    }

    private static func isTopLevelMenuExtra(_ element: AXUIElement) -> Bool {
        copyStringAttribute(kAXRoleAttribute as CFString, from: element)
            == (kAXMenuBarItemRole as String)
            && copyStringAttribute(kAXSubroleAttribute as CFString, from: element)
                == "AXMenuExtra"
    }

    private static func copyStringAttribute(
        _ attribute: CFString,
        from element: AXUIElement
    ) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value as? String
    }
}
#endif
