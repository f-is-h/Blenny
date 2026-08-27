#if DEBUG
import AppKit
import ApplicationServices
import BlennyCore
import Foundation

@MainActor
final class DebugPolicyCoexistenceController {
    static let revealableEnvironmentKey = "BLENNY_0_0_4_REVEALABLE_BUNDLE_ID"
    static let hiddenEnvironmentKey = "BLENNY_0_0_4_HIDDEN_BUNDLE_ID"
    static let realWriteEnvironmentKey = "BLENNY_ENABLE_0_0_4_REAL_WRITES"
    static let expectedBaselineFingerprintEnvironmentKey =
        "BLENNY_0_0_4_EXPECTED_BASELINE_FINGERPRINT"
    static let expectedRevealFingerprintEnvironmentKey =
        "BLENNY_0_0_4_EXPECTED_REVEAL_FINGERPRINT"
    static let approvedRevealableBundleIdentifier = "xyz.fi5h.Usage4Claude"
    static let approvedHiddenBundleIdentifier = "pl.maketheweb.cleanshotx"
    static let revealSessionTimeout: Duration = .seconds(30)
    static let experimentTimeout: Duration = .seconds(300)

    private let statusItemController: StatusItemController
    private let nativeOverflowObserver = NativeOverflowObserver()
    private let blennyBundleIdentifier: String
    private let policyStore: PersistentBundlePolicyStore
    private let realWritesEnabled: Bool
    private let fallbackInstalledAndRegistered: Bool
    private let startedAt = ContinuousClock.now

    private var policyDocument: PersistentBundlePolicyDocument?
    private var assignments: BundlePolicyAssignments?
    private var observedBundleIdentifiers = Set<String>()
    private var writer: RevealAssertionWriter?
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
        guard let blennyBundleIdentifier = Bundle.main.bundleIdentifier,
              let applicationSupport = try? FileManager.default.url(
                  for: .applicationSupportDirectory,
                  in: .userDomainMask,
                  appropriateFor: nil,
                  create: true
              ) else {
            Self.debugLog("BLENNY_0_0_4 FAIL_CLOSED policy storage unavailable")
            return nil
        }
        let policyDirectory = applicationSupport
            .appendingPathComponent("Blenny", isDirectory: true)
            .appendingPathComponent("PersistentPolicyPrototype", isDirectory: true)
        do {
            self.policyStore = try PersistentBundlePolicyStore(
                policyURL: policyDirectory.appendingPathComponent("bundle-policies.json"),
                backupURL: policyDirectory.appendingPathComponent(
                    "bundle-policies.previous.blenny-backup.json"
                )
            )
        } catch {
            Self.debugLog("BLENNY_0_0_4 FAIL_CLOSED invalid policy storage paths")
            return nil
        }

        self.statusItemController = statusItemController
        self.blennyBundleIdentifier = blennyBundleIdentifier
        self.realWritesEnabled = environment[Self.realWriteEnvironmentKey] == "YES"
        self.fallbackInstalledAndRegistered = Self.isInstalledAndRegistered(
            bundleIdentifier: blennyBundleIdentifier
        )
    }

    var isRunning: Bool { !stopped }

    func start() {
        statusItemController.configureDebugRevealPrototype(
            onToggle: { [weak self] in self?.enqueueFallbackToggle() },
            onStopManagingAndRestore: { [weak self] in
                Task { @MainActor in
                    await self?.stopManagingAndRestore()
                }
            }
        )
        statusItemController.updateDebugRevealPrototype(
            entryPoint: nil,
            presentation: .baseline,
            enabled: false,
            status: realWritesEnabled ? "preparing persistent real run" : "persistent dry-run"
        )
        Task { @MainActor [weak self] in
            await self?.preparePersistentPolicy()
        }
    }

    private func beginBoundedSession() {
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

    func stopManagingAndRestore() async {
        let wasAlreadyStopped = stopped
        var persistenceStatus = "management disabled persistently"
        var persistenceSucceeded = false
        do {
            guard try await policyStore.disableManagement() != nil else {
                persistenceStatus = "no stored policy; management remains disabled"
                persistenceSucceeded = true
                if !wasAlreadyStopped {
                    await stop(reason: "Stop Managing restored; \(persistenceStatus)")
                }
                statusItemController.setDebugStopManagingEnabled(false)
                return
            }
            policyDocument = try await policyStore.load()
            persistenceSucceeded = true
        } catch {
            persistenceStatus = "disable persistence failed: \(error)"
        }
        if !wasAlreadyStopped {
            await stop(reason: "Stop Managing restored; \(persistenceStatus)")
        } else {
            statusItemController.updateDebugRevealPrototype(
                entryPoint: nil,
                presentation: .baseline,
                enabled: false,
                status: "Stop Managing restored; \(persistenceStatus)"
            )
        }
        statusItemController.setDebugStopManagingEnabled(!persistenceSucceeded)
    }

    private func preparePersistentPolicy() async {
        guard AccessibilityAuthorization.isTrusted else {
            failClosed(status: "unknown ownership: Accessibility is not granted")
            return
        }

        do {
            let document = try await loadOrSeedPolicy()
            policyDocument = document
            guard document.managementEnabled else {
                await stop(reason: "management disabled; unrestricted state preserved")
                return
            }
            try validatePrototypeScope(document)

            let ownershipScan = Self.observeMenuBarOwnership()
            guard ownershipScan.completed else {
                throw PersistentPolicyResolverError.unresolved([.ownershipScanTimedOut])
            }
            let runningBundleIdentifiers = Set(
                NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
            )
            let resolved = try PersistentPolicyResolver.resolve(
                document: document,
                ownershipObservations: ownershipScan.observations,
                observedRunningBundleIdentifiers: runningBundleIdentifiers,
                blennyBundleIdentifier: blennyBundleIdentifier
            )
            assignments = resolved.assignments
            observedBundleIdentifiers = resolved.observedRunningBundleIdentifiers

            for entry in document.policies {
                let pid = resolved.managedProcessIdentifiers[entry.bundleIdentifier] ?? -1
                debugLog(
                    "BLENNY_0_0_4 PREFLIGHT bundle=\(entry.bundleIdentifier) "
                        + "policy=\(entry.policy.rawValue) pid=\(pid) ownership=unique"
                )
            }

            // Establish the installed fallback before any baseline assertion.
            guard !realWritesEnabled || fallbackInstalledAndRegistered else {
                throw RevealEntryPointSelectionError.noUsableEntryPoint
            }
            if !realWritesEnabled {
                debugLog(
                    "BLENNY_0_0_4 assertion_factory_created=false "
                        + "assertion_candidate_created=false"
                )
            } else {
                debugLog(
                    "BLENNY_0_0_4 assertion_factory_created=false "
                        + "reason=awaiting_exact_plan_fingerprint_match"
                )
            }
            statusItemController.setDebugStopManagingEnabled(true)
            beginBoundedSession()
        } catch let PersistentPolicyResolverError.unresolved(issues) {
            for issue in issues {
                debugLog("BLENNY_0_0_4 FAIL_CLOSED ownership_issue=\(issue)")
            }
            failClosed(status: "unknown or ambiguous bundle ownership; no write")
        } catch {
            debugLog("BLENNY_0_0_4 FAIL_CLOSED persistent preflight failed: \(error)")
            failClosed(status: "persistent policy preflight failed; no write")
        }
    }

    private func loadOrSeedPolicy() async throws -> PersistentBundlePolicyDocument {
        if let existing = try await policyStore.load() {
            debugLog(
                "BLENNY_0_0_4 policy_source=persistent_store "
                    + "management_enabled=\(existing.managementEnabled)"
            )
            return existing
        }

        let environment = ProcessInfo.processInfo.environment
        guard environment[Self.revealableEnvironmentKey]
                == Self.approvedRevealableBundleIdentifier,
              environment[Self.hiddenEnvironmentKey]
                == Self.approvedHiddenBundleIdentifier else {
            throw PersistentBundlePolicyDocumentError.invalidBundleIdentifier(
                "exact approved seed environment values are required"
            )
        }
        let document = try PersistentBundlePolicyDocument(
            managementEnabled: true,
            policies: [
                .init(bundleIdentifier: blennyBundleIdentifier, policy: .pinned),
                .init(
                    bundleIdentifier: Self.approvedRevealableBundleIdentifier,
                    policy: .revealable
                ),
                .init(
                    bundleIdentifier: Self.approvedHiddenBundleIdentifier,
                    policy: .hidden
                ),
            ]
        )
        try await policyStore.save(document)
        debugLog("BLENNY_0_0_4 policy_source=approved_seed persisted=true")
        return document
    }

    private func validatePrototypeScope(
        _ document: PersistentBundlePolicyDocument
    ) throws {
        _ = try document.validated(
            forBlennyBundleIdentifier: blennyBundleIdentifier
        )
        let expected = Set([
            "\(blennyBundleIdentifier)|\(MenuBarBundlePolicy.pinned.rawValue)",
            "\(Self.approvedRevealableBundleIdentifier)|\(MenuBarBundlePolicy.revealable.rawValue)",
            "\(Self.approvedHiddenBundleIdentifier)|\(MenuBarBundlePolicy.hidden.rawValue)",
        ])
        let actual = Set(
            document.policies.map { "\($0.bundleIdentifier)|\($0.policy.rawValue)" }
        )
        guard actual == expected else {
            throw BoundedPolicyTargetValidationError.assignmentMismatch
        }
    }

    private func receivedNativeOverflow(
        _ snapshot: NativeOverflowObservationSnapshot
    ) {
        if bootstrapping {
            pendingNativeSnapshot = snapshot
            return
        }
        debugLog(
            "BLENNY_0_0_4 native_present=\(snapshot.isPresent) "
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
            let baselinePlan = try makePlan(presentation: .baseline)
            let revealPlan = try makePlan(presentation: .revealed)
            logPlan(baselinePlan)
            logPlan(revealPlan)
            if realWritesEnabled {
                try authorizeManagedPolicyPlans(
                    baseline: baselinePlan,
                    revealed: revealPlan
                )
                writer = RevealAssertionWriter(
                    factory: try ExperimentalMacOS27AssessmentFactory(),
                    activationTimeout: .seconds(1)
                )
                debugLog("BLENNY_0_0_4 assertion_factory_created=true managed_policy_match=true")
            }
            try await writer?.applySessionTransition(with: baselinePlan)
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
                    "BLENNY_0_0_4 transition=\(presentation.rawValue) "
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
        guard let assignments else {
            throw BoundedPolicyTargetValidationError.assignmentMismatch
        }
        return try RevealAllowlistPlanner.plan(
            presentation: presentation,
            assignments: assignments,
            observedRunningBundleIdentifiers: observedBundleIdentifiers,
            blennyBundleIdentifier: blennyBundleIdentifier
        )
    }

    private func logPlan(_ plan: RevealAllowlistPlan) {
        guard let assignments else { return }
        let revealableAllowed = plan.allowedBundleIdentifiers.contains(
            assignments.revealable.first ?? ""
        )
        let hiddenAllowed = !assignments.hidden.isDisjoint(
            with: plan.allowedBundleIdentifiers
        )
        let managedPolicyFingerprint = plan.managedPolicyFingerprint(
            assignments: assignments
        )
        debugLog(
            "BLENNY_0_0_4 mode=\(realWritesEnabled ? "REAL" : "DRY_RUN") "
                + "plan=\(plan.presentation.rawValue) "
                + "exact_snapshot_fingerprint=\(plan.fingerprint) "
                + "managed_policy_fingerprint=\(managedPolicyFingerprint) "
                + "bundle_count=\(plan.allowedBundleIdentifiers.count) "
                + "system_items=\(plan.allowedSystemItems) "
                + "pinned_allowed=\(plan.allowedBundleIdentifiers.contains(blennyBundleIdentifier)) "
                + "revealable=\(assignments.revealable.first ?? "") "
                + "revealable_allowed=\(revealableAllowed) "
                + "hidden=\(assignments.hidden.first ?? "") "
                + "hidden_allowed=\(hiddenAllowed)"
        )
    }

    private func authorizeManagedPolicyPlans(
        baseline: RevealAllowlistPlan,
        revealed: RevealAllowlistPlan
    ) throws {
        guard let assignments else {
            throw BoundedPolicyTargetValidationError.assignmentMismatch
        }
        let environment = ProcessInfo.processInfo.environment
        guard environment[Self.expectedBaselineFingerprintEnvironmentKey]
                == baseline.managedPolicyFingerprint(assignments: assignments),
              environment[Self.expectedRevealFingerprintEnvironmentKey]
                == revealed.managedPolicyFingerprint(assignments: assignments) else {
            debugLog(
                "BLENNY_0_0_4 FAIL_CLOSED managed policy fingerprints were not authorized; "
                    + "assertion_factory_created=false assertion_candidate_created=false"
            )
            throw RealPlanAuthorizationError.fingerprintMismatch
        }
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
            "BLENNY_0_0_4 state=\(reducer.presentation.rawValue) "
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
        statusItemController.setDebugStopManagingEnabled(policyDocument?.managementEnabled == true)
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

    private static func observeMenuBarOwnership() -> (
        observations: [MenuBarPolicyOwnershipObservation],
        completed: Bool
    ) {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        var applications = NSWorkspace.shared.runningApplications
        applications.append(
            contentsOf: NSRunningApplication.runningApplications(
                withBundleIdentifier: "com.apple.MenuBarAgent"
            )
        )
        var seenProcesses = Set<pid_t>()
        applications = applications.filter { application in
            application.processIdentifier > 0
                && seenProcesses.insert(application.processIdentifier).inserted
                && (application.activationPolicy != .prohibited
                    || application.bundleIdentifier == "com.apple.MenuBarAgent")
        }

        var observations: [MenuBarPolicyOwnershipObservation] = []
        for application in applications {
            guard ContinuousClock.now < deadline else {
                return (observations, false)
            }
            let applicationElement = AXUIElementCreateApplication(
                application.processIdentifier
            )
            guard AXUIElementSetMessagingTimeout(applicationElement, 0.25) == .success else {
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
            let menuBarItemCount = children.filter(Self.isTopLevelMenuExtra).count
            guard menuBarItemCount > 0 else { continue }
            observations.append(
                MenuBarPolicyOwnershipObservation(
                    bundleIdentifier: application.bundleIdentifier,
                    processIdentifier: Int32(application.processIdentifier),
                    menuBarItemCount: menuBarItemCount
                )
            )
        }
        return (observations, true)
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

private enum RealPlanAuthorizationError: Error {
    case fingerprintMismatch
}
#endif
