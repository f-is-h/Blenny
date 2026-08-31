import AppKit
import BlennyCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let legacyBlennyBundleIdentifier = "com.example.BlennyProbe"
    private static let accessibilityPromptRequestedKey =
        "AccessibilitySystemPromptRequestedForMenuBarOwnership"
    private static let readOnlySystemMenuBarOwners = Set([
        "com.apple.controlcenter",
        "com.apple.menubaragent",
        "com.apple.systemuiserver",
        "com.apple.textinputmenuagent",
        "com.apple.weather.menu",
    ])

    private let inventory = AccessibilityInventory(
        maximumDurationMilliseconds: 10_000,
        messagingTimeoutSeconds: 0.1
    )
    private var isRefreshing = false
    private var lastKnownAccessibilityTrust: Bool?
    private var persistentStore: PersistentBundlePolicyStore?
    private var interfaceStore: PolicyInterfaceStore?
    private var editorModel: PolicyEditorViewModel?
    private var ownershipSnapshot: MenuBarOwnershipSnapshot?
    private var observedRunningBundleIdentifiers = Set<String>()
    private var recoveryAvailable = false
    private var developmentMutationAvailable = false
    private var terminationRestoreInProgress = false
    private var activeBaselinePlan: RevealAllowlistPlan?
    private var activeRevealPlan: RevealAllowlistPlan?
    private var ordinaryRevealTimeoutTask: Task<Void, Never>?
    private var interactionGate = ManagementInteractionGate()
    private var actionAudit = PolicyActionAuditTrail()
    private var managementInteractionTask: Task<Void, Never>?
    private let nativeOverflowObserver = NativeOverflowObserver(reconnectOnAgentChange: false)
    private var nativeObservationStarted = false
    private var ordinaryReveal = OrdinaryRevealCoordinator()
    private var attemptedStartupRecovery = false
    private var connectionInvalidationTask: Task<Void, Never>?
    private var lifecycleGeneration: UInt64 = 0
    private var lifecycleObservers: [(NotificationCenter, NSObjectProtocol)] = []
    private var lifecycleRestartRequired = false
    private lazy var managementLoop: ManagementLoopController = {
        let readOnly = isReadOnlyValidation
        return ManagementLoopController(writerProvider: {
            guard !readOnly else { throw PolicyInterfaceWriteError.installedDryRunRequired }
            #if DEBUG
            let factory = try ExperimentalMacOS27AssessmentFactory()
            let trace = DebugSessionTrace.shared
            if trace.enabled {
                return RevealAssertionWriter(factory: factory, diagnostic: { message in
                    trace.write(message)
                })
            }
            return RevealAssertionWriter(factory: factory)
            #else
            throw PolicyInterfaceWriteError.releaseBackendUnavailable
            #endif
        })
    }()
    private var isReadOnlyValidation: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["BLENNY_0_6_0_DRY_RUN"] == "YES"
            || ProcessInfo.processInfo.environment["BLENNY_0_5_0_DRY_RUN"] == "YES"
        #else
        false
        #endif
    }
    #if DEBUG
    private var policyCoexistenceController: DebugPolicyCoexistenceController?
    private var validationDeadlineTask: Task<Void, Never>?
    #endif

    private lazy var editorWindowController = PolicyEditorWindowController(
        onRefresh: { [weak self] in self?.refresh() },
        onRequestAccess: { [weak self] in self?.requestAccessibilityAccess() },
        onResumeManaging: { [weak self] in self?.resumeManaging() },
        onStopManaging: { [weak self] in self?.stopManaging() },
        onRestorePreviousPolicy: { [weak self] in self?.restorePreviousPolicy() },
        onDraftDidChange: { [weak self] model in self?.draftDidChange(model) },
        onApplyDraft: { [weak self] in self?.applyDraftChanges() },
        onOpenProjectWebsite: { [weak self] in self?.openProjectWebsite() },
        onOpenMonthlySponsor: { [weak self] in self?.openMonthlySponsor() },
        onOpenOneTimeSponsor: { [weak self] in self?.openOneTimeSponsor() },
        onOpenKoFi: { [weak self] in self?.openKoFi() },
        onSetLaunchAtLogin: { [weak self] enabled in self?.setLaunchAtLogin(enabled) },
        onOpenLoginItemsSettings: { [weak self] in self?.openLoginItemsSettings() }
    )

    private lazy var statusItemController = StatusItemController(
        onOpenDiagnostics: { [weak self] in self?.showEditor() },
        onRefresh: { [weak self] in self?.refresh() },
        onRequestAccess: { [weak self] in self?.requestAccessibilityAccess() },
        onToggleOrdinaryReveal: { [weak self] in self?.toggleOrdinaryReveal() },
        onResumeManaging: { [weak self] in self?.resumeManaging() },
        onStopManaging: { [weak self] in self?.stopManaging() },
        onRestorePreviousPolicy: { [weak self] in self?.restorePreviousPolicy() },
        onQuit: { NSApplication.shared.terminate(nil) }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        _ = statusItemController
        updatePermissionPresentation()
        updateLaunchAtLoginPresentation()
        sessionDiagnostic("launch accessibility=\(AccessibilityAuthorization.isTrusted) login=\(SMAppService.mainApp.status)")

        #if DEBUG
        if isReadOnlyValidation,
           !AccessibilityAuthorization.isTrusted {
            Self.writeDryRunOutput(
                "DRY-RUN FAILED: Accessibility is not granted to the installed Debug app."
            )
            NSApplication.shared.terminate(nil)
            return
        }
        #endif

        #if DEBUG
        if !isReadOnlyValidation, ProcessInfo.processInfo.environment[
            DebugPolicyCoexistenceController.editingActionEnvironmentKey
        ] != nil {
            policyCoexistenceController = DebugPolicyCoexistenceController(
                statusItemController: statusItemController
            )
            policyCoexistenceController?.start()
            return
        }
        #endif

        installLifecycleObservers()
        updateNativeOverflowObservation()
        // Managed startup preserves the owner's current leading-menu width,
        // just as the successful native-owner spike did. Setup/failure still
        // opens the editor; the fish and explicit reopen always open it.
        if !isReadOnlyValidation && !AccessibilityAuthorization.isTrusted { showEditor() }
        #if DEBUG
        if !isReadOnlyValidation, DebugSessionTrace.shared.enabled,
           let raw = ProcessInfo.processInfo.environment["BLENNY_0_6_0_TRACE_SECONDS"],
           let seconds = Int(raw), (1...300).contains(seconds) {
            sessionDiagnostic("bounded-normal-trace seconds=\(seconds)")
            validationDeadlineTask = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
                self?.sessionDiagnostic("bounded-normal-trace expired requesting-normal-quit")
                // Leave both the Swift job and the main dispatch-queue drain
                // before AppKit enters its terminateLater nested loop, so the
                // asynchronous restoration job can run inside that loop.
                RunLoop.main.perform(inModes: [.common]) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        #endif
        refresh()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        interactionGate.terminate()
        ordinaryReveal.suspend()
        nativeOverflowObserver.stop()
        nativeObservationStarted = false
        for (center, token) in lifecycleObservers { center.removeObserver(token) }
        lifecycleObservers.removeAll()
        #if DEBUG
        validationDeadlineTask?.cancel()
        validationDeadlineTask = nil
        if isReadOnlyValidation {
            return .terminateNow
        }
        #endif
        #if DEBUG
        if let policyCoexistenceController,
           policyCoexistenceController.isRunning {
            guard !terminationRestoreInProgress else { return .terminateLater }
            terminationRestoreInProgress = true
            Task { @MainActor in
                await policyCoexistenceController.stop()
                sender.reply(toApplicationShouldTerminate: true)
            }
            return .terminateLater
        }
        #endif
        guard !terminationRestoreInProgress else { return .terminateLater }
        terminationRestoreInProgress = true
        ordinaryRevealTimeoutTask?.cancel()
        ordinaryRevealTimeoutTask = nil
        let activeInteraction = managementInteractionTask
        Task { @MainActor in
            await activeInteraction?.value
            await connectionInvalidationTask?.value
            await managementLoop.terminate()
            let writerRestored = await managementLoop.activePlanSnapshot() == nil
            sessionDiagnostic("termination writerRestored=\(writerRestored)")
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        let previouslyTrusted = lastKnownAccessibilityTrust
        updatePermissionPresentation()
        updateLaunchAtLoginPresentation()
        updateNativeOverflowObservation()
        let shouldRefreshAfterGrant = AccessibilityPermissionRefreshPolicy.shouldRefresh(
            previouslyTrusted: previouslyTrusted,
            isTrusted: lastKnownAccessibilityTrust == true,
            isRefreshing: isRefreshing,
            hasDraftChanges: editorModel?.hasDraftChanges == true
        )
        if shouldRefreshAfterGrant {
            refresh()
        } else if previouslyTrusted == false,
                  lastKnownAccessibilityTrust == true,
                  editorModel?.hasDraftChanges == true {
            editorWindowController.setStatus(
                "Accessibility is granted. Apply or discard the local Draft before refreshing.",
                isError: false
            )
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        ordinaryRevealTimeoutTask?.cancel()
        ordinaryRevealTimeoutTask = nil
        Task { await managementLoop.terminate() }
        #if DEBUG
        statusItemController.restoreDebugStatusItemPlacement()
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showEditor()
        return true
    }

    private func showEditor() {
        editorWindowController.showEditor()
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Blenny")
        let quitItem = NSMenuItem(
            title: "Quit Blenny",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApplication.shared
        applicationMenu.addItem(quitItem)
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(
            withTitle: "Close",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)
        NSApplication.shared.mainMenu = mainMenu
        NSApplication.shared.windowsMenu = windowMenu
    }

    private func refresh() {
        guard !isRefreshing, !interactionGate.isBusy, !interactionGate.isTerminating,
              editorModel?.hasDraftChanges != true, connectionInvalidationTask == nil else { return }
        updatePermissionPresentation()
        guard AccessibilityAuthorization.isTrusted else {
            editorWindowController.setStatus(
                "Enable Accessibility, then return to Blenny. One bounded refresh will run automatically.",
                isError: false
            )
            return
        }

        guard beginManagementInteraction() else { return }
        ordinaryReveal.suspend()
        isRefreshing = true
        let descriptors = runningApplicationDescriptors()
        let generation = lifecycleGeneration
        let runningIdentifiers = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        ).union(Bundle.main.bundleIdentifier.map { [$0] } ?? [])
        statusItemController.setRefreshing(true)
        editorWindowController.setRefreshing(true)
        managementInteractionTask = Task { [weak self, inventory] in
            let report = await inventory.capture(
                applications: descriptors,
                accessibilityTrusted: true
            )
            guard let self else { return }
            guard generation == self.lifecycleGeneration else {
                self.isRefreshing = false
                self.statusItemController.setRefreshing(false)
                self.editorWindowController.setRefreshing(false)
                self.finishManagementInteraction()
                return
            }
            await self.completeRefresh(
                report: report,
                runningBundleIdentifiers: runningIdentifiers
            )
        }
    }

    private func completeRefresh(
        report: DiagnosticReport,
        runningBundleIdentifiers: Set<String>
    ) async {
        defer {
            isRefreshing = false
            statusItemController.setRefreshing(false)
            editorWindowController.setRefreshing(false)
            finishManagementInteraction(refreshNativeObservation: true)
        }
        guard !interactionGate.isTerminating else { return }

        let snapshot = MenuBarOwnershipSnapshotBuilder.make(from: report)
        ownershipSnapshot = snapshot
        editorWindowController.setDiscoveryWarnings(
            report.applicationDiscoveries.compactMap(\.failureDescription)
        )
        #if DEBUG
        if isReadOnlyValidation,
           let target = ProcessInfo.processInfo.environment["BLENNY_DISCOVERY_BUNDLE_ID"] {
            let discovery = report.applicationDiscoveries.first {
                $0.bundleIdentifier?.lowercased() == target.lowercased()
            }
            let owner = snapshot.observations.first {
                $0.bundleIdentifier?.lowercased() == target.lowercased()
            }
            Self.writeDryRunOutput(
                "DISCOVERY bundle=\(target) root=\(discovery?.outcome.rawValue ?? "not-scanned")"
                    + " ax=\(discovery?.rootReadResult.description ?? "none")"
                    + " records=\(discovery?.observationCount ?? 0) attributedItems=\(owner?.menuBarItemCount ?? 0)"
            )
        }
        #endif
        guard snapshot.isComplete else {
            let detail = snapshot.issues.map(\.description).joined(separator: "; ")
            #if DEBUG
            if isReadOnlyValidation {
                Self.writeDryRunOutput(
                    "DRY-RUN FAILED: read-only observation was incomplete: \(detail)"
                )
                NSApplication.shared.terminate(nil)
            }
            #endif
            editorWindowController.setStatus(
                "The read-only observation was incomplete: \(detail). Apply remains unavailable.",
                isError: true
            )
            return
        }

        do {
            let blennyBundleIdentifier = try currentBundleIdentifier()
            let store = try makePersistentStore()
            persistentStore = store
            if !isReadOnlyValidation {
                _ = try await store.migrateBundleIdentifier(
                    from: Self.legacyBlennyBundleIdentifier,
                    to: blennyBundleIdentifier
                )
            }
            let accepted = try await store.load() ?? initialPolicy(
                blennyBundleIdentifier: blennyBundleIdentifier
            )
            let candidateInventory = PolicyCandidateInventory(
                observations: snapshot.observations
            )
            let model = try PolicyEditorViewModel(
                acceptedPolicy: accepted,
                candidateInventory: candidateInventory,
                systemItems: snapshot.systemItems,
                blennyBundleIdentifier: blennyBundleIdentifier
            )
            let interfaceStore = PolicyInterfaceStore(
                persistentStore: store,
                initialPolicy: accepted
            )
            let runningIdentifiers = runningBundleIdentifiers.union([blennyBundleIdentifier])
            let backup = try await store.loadBackup()
            let hasBackup = backup != nil

            if let previous = editorModel?.acceptedPolicy, previous != accepted {
                await managementLoop.failClosed("accepted policy changed outside the current management session")
                activeBaselinePlan = nil
                activeRevealPlan = nil
            }
            let isInitialPolicyLoad = editorModel == nil
            self.interfaceStore = interfaceStore
            editorModel = model
            observedRunningBundleIdentifiers = runningIdentifiers
            recoveryAvailable = hasBackup
            statusItemController.setDraftHasChanges(model.hasDraftChanges)
            editorWindowController.display(
                model: model,
                observationCount: candidateInventory.candidates.count,
                recoveryAvailable: hasBackup
            )
            #if DEBUG
            if isReadOnlyValidation,
               let target = ProcessInfo.processInfo.environment["BLENNY_DISCOVERY_BUNDLE_ID"] {
                Self.writeDryRunOutput(
                    "DISCOVERY candidate=\(model.effectivePolicy(for: target) != nil)"
                        + " implicitVisible=\(model.implicitVisibleCandidates.contains { $0.bundleIdentifier.lowercased() == target.lowercased() })"
                        + " authorized=\(model.acceptedPolicyScope.approvedBundleIdentifiers.contains { $0.lowercased() == target.lowercased() })"
                        + " \(editorWindowController.debugPresentationSummary(for: target))"
                )
            }
            #endif
            developmentMutationAvailable = developmentCompatibilityAvailable(
                bundleIdentifier: blennyBundleIdentifier
            )
            let managementState = await recoverManagement(
                accepted: accepted,
                backup: backup,
                model: model,
                candidateGeneration: editorWindowController.candidateGeneration
            )
            presentManagementState(
                managementState,
                persistedManagementEnabled: accepted.managementEnabled
            )
            if isInitialPolicyLoad && !isReadOnlyValidation {
                switch managementState {
                case .active, .ordinaryRevealSession: break
                default: showEditor()
                }
            }
            #if DEBUG
            await runInstalledDryRunIfRequested(model: model)
            #endif
        } catch {
            editorWindowController.setStatus(
                "Could not prepare the policy editor: \(error.localizedDescription)",
                isError: true
            )
            #if DEBUG
            if isReadOnlyValidation {
                Self.writeDryRunOutput("DRY-RUN FAILED: \(error)")
                NSApplication.shared.terminate(nil)
            }
            #endif
        }
    }

    private func recoverManagement(
        accepted: PersistentBundlePolicyDocument,
        backup: PersistentBundlePolicyBackup?,
        model: PolicyEditorViewModel,
        candidateGeneration: UUID
    ) async -> ManagementLoopState {
        guard !interactionGate.isTerminating else { return .terminating }
        // Refresh updates read-only candidates, not the active assertion. Only
        // ordinary startup or an explicit prepared action can activate policy.
        guard !attemptedStartupRecovery else { return await managementLoop.state }
        attemptedStartupRecovery = true
        guard accepted.managementEnabled else {
            activeBaselinePlan = nil
            activeRevealPlan = nil
            return await managementLoop.recover(
                acceptedPolicy: accepted,
                baseline: nil
            )
        }
        guard developmentMutationAvailable else {
            await managementLoop.failClosed(
                "Grant Accessibility and choose Resume in the supported installed Debug app."
            )
            return await managementLoop.state
        }
        guard let backup,
              (try? backup.previousPolicy.validated(
                forBlennyBundleIdentifier: model.blennyBundleIdentifier
              )) != nil,
              !backup.previousPolicy.policies.contains(where: {
                $0.bundleIdentifier.lowercased().hasPrefix("com.apple.")
              }) else {
            await managementLoop.failClosed(
                "the scoped recovery backup is missing or incompatible"
            )
            return await managementLoop.state
        }

        do {
            let prepared = try PolicyDryRunner.prepare(
                oldPolicy: accepted,
                draft: BundlePolicyDraft(acceptedPolicy: accepted),
                managementEnabled: true,
                candidates: model.candidateInventory,
                observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                scope: model.acceptedPolicyScope,
                blennyBundleIdentifier: model.blennyBundleIdentifier,
                candidateGeneration: candidateGeneration,
                runtimeContractFingerprint: runtimeContractFingerprint,
                recoveryBackupFingerprint: backup.backupFingerprint
            )
            guard let baseline = prepared.report.newBaselinePlan,
                  let reveal = prepared.report.newRevealPlan,
                  prepared.prepared != nil else {
                await managementLoop.failClosed(
                    prepared.report.validationFailureSummary
                )
                return await managementLoop.state
            }
            activeBaselinePlan = baseline
            activeRevealPlan = reveal
            return await managementLoop.recover(
                acceptedPolicy: accepted,
                baseline: baseline
            )
        } catch {
            await managementLoop.failClosed("startup preflight failed: \(error)")
            return await managementLoop.state
        }
    }

    private func presentManagementState(
        _ state: ManagementLoopState,
        persistedManagementEnabled: Bool
    ) {
        let state = interactionGate.isTerminating ? ManagementLoopState.terminating
            : (connectionInvalidationTask != nil ? .restoring : state)
        let hasRevealable = editorModel?.acceptedPolicy.policies.contains { $0.policy == .revealable } == true
        ordinaryReveal.synchronize(state, hasRevealableBundles: hasRevealable)
        updateNativeOverflowObservation()
        statusItemController.setNativeOverflow(ordinaryReveal.observation)
        sessionDiagnostic("management=\(state) entry=\(ordinaryReveal.entryPoint.rawValue)")
        statusItemController.setManagementState(
            state,
            persistedManagementEnabled: persistedManagementEnabled,
            recoveryAvailable: recoveryAvailable,
            hasRevealableBundles: hasRevealable
        )
        editorWindowController.setManagementRuntimeState(
            state,
            developmentMutationAvailable: developmentMutationAvailable
        )
        guard !interactionGate.isTerminating else { return }
        switch state {
        case .active:
            editorWindowController.setStatus(
                "Management is active for the verified policy baseline.",
                isError: false
            )
        case .stopped:
            editorWindowController.setStatus(
                "Management is stopped. Draft changes remain local until Apply.",
                isError: false
            )
        case .unsupportedRuntimeContract:
            editorWindowController.setStatus(
                "Management is unavailable because this runtime contract is unsupported. No assertion was created.",
                isError: true
            )
        case let .failClosedUnrestricted(detail) where persistedManagementEnabled:
            editorWindowController.setStatus(
                "Management is inactive; Blenny's restrictions are removed. \(detail)",
                isError: true
            )
        case let .restorationFailed(detail):
            editorWindowController.setStatus(
                "Cleanup could not be confirmed. Blenny will quit to release its connection. \(detail)",
                isError: true
            )
            NSApplication.shared.terminate(nil)
        default:
            break
        }
    }

    #if DEBUG
    private func runInstalledDryRunIfRequested(
        model: PolicyEditorViewModel
    ) async {
        guard isReadOnlyValidation
        else { return }
        do {
            guard statusItemController.debugValidateNativeFallbackPresentation() else {
                throw NSError(domain: "Blenny.InstalledDryRun", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Local AppKit fallback-presentation fixtures failed."
                ])
            }
            Self.writeDryRunOutput(
                "APPKIT PRESENTATION FIXTURES passed=true"
                    + " nativeEventEvidence=false writerCreated=false"
            )
            let core = try await makeCore(scope: model.acceptedPolicyScope)
            let preview = try await core.previewResumeManaging(
                candidates: model.candidateInventory,
                observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                candidateGeneration: editorWindowController.candidateGeneration,
                runtimeContractFingerprint: runtimeContractFingerprint
            )
            // The ordinary app already started this observer, independently of
            // management. Do not create a second, dry-run-only observation path.
            let native = ordinaryReveal.observation
            let nativeFailure = nativeOverflowObserver.unavailabilityReason ?? "none"
            let nativeDetails = nativeOverflowObserver.debugObservationDetails.joined(separator: "\n- ")
            Self.writeDryRunOutput(
                preview.0.text
                    + "\nNATIVE OBSERVATION (READ ONLY)"
                    + "\n- present=\(native.isPresent) observable=\(native.observationAvailable) state=\(native.presentationState.rawValue) failure=\(nativeFailure)"
                    + "\n- controls=\(native.controlCount) usable=\(native.isUsable)"
                    + "\n- \(nativeDetails)"
                    + "\nDRY-RUN GUARANTEES"
                    + "\n- installedBundle=\(Bundle.main.bundleURL.path)"
                    + "\n- writerCreated=false"
                    + "\n- assertionCreated=false"
                    + "\n- persistenceChanged=false"
                    + "\n- managementEnabledChanged=false"
                    + "\n- readOnlyStore=true"
                    + "\n- planPrepared=\(preview.1 != nil)"
            )
            if let raw = ProcessInfo.processInfo.environment["BLENNY_0_6_0_OBSERVE_SECONDS"],
               let seconds = Int(raw), (1...300).contains(seconds) {
                Self.writeDryRunOutput("READ-ONLY OBSERVATION WINDOW seconds=\(seconds); no writer is available")
                try await Task.sleep(for: .seconds(seconds))
            }
            nativeOverflowObserver.stop()
            statusItemController.setNativeOverflow(.unavailable)
        } catch {
            nativeOverflowObserver.stop()
            statusItemController.setNativeOverflow(.unavailable)
            Self.writeDryRunOutput("DRY-RUN FAILED: \(error)")
        }
        NSApplication.shared.terminate(nil)
    }

    private static func writeDryRunOutput(_ text: String) {
        guard let data = "\(text)\n".data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }
    #endif

    private var runtimeContractFingerprint: String {
        #if DEBUG
        ExperimentalMacOS27AssessmentFactory.compatibilityFingerprint
        #else
        "release-backend-unavailable"
        #endif
    }

    private func developmentCompatibilityAvailable(
        bundleIdentifier: String
    ) -> Bool {
        #if DEBUG
        guard !isReadOnlyValidation,
              AccessibilityAuthorization.isTrusted,
              Bundle.main.bundleURL.path.hasPrefix("/Applications/"),
              Bundle.main.bundleIdentifier == bundleIdentifier,
              let registeredURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleIdentifier
              ),
              registeredURL.resolvingSymlinksInPath().standardizedFileURL
                == Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL else {
            return false
        }
        do {
            _ = try ExperimentalMacOS27AssessmentFactory()
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    private func resumeManaging() { performPolicyAction(.resume) }
    private func applyDraftChanges() { performPolicyAction(.apply) }
    private func stopManaging() { performPolicyAction(.stop) }
    private func restorePreviousPolicy() { performPolicyAction(.restore) }

    private func draftDidChange(_ model: PolicyEditorViewModel) {
        guard !interactionGate.isBusy, !interactionGate.isTerminating else { return }
        editorModel = model
        statusItemController.setDraftHasChanges(model.hasDraftChanges)
    }

    private func beginManagementInteraction() -> Bool {
        guard !isRefreshing, connectionInvalidationTask == nil, interactionGate.begin() else { return false }
        editorWindowController.setApplying(true)
        statusItemController.setInteractionBusy(true)
        return true
    }

    private func finishManagementInteraction(refreshNativeObservation: Bool = false) {
        // Read once while the transition still owns the gate. This discovers
        // an arrow created by the just-completed reflow without a polling loop.
        if !interactionGate.isTerminating {
            if refreshNativeObservation { nativeOverflowObserver.refreshCurrentControl() }
            else { nativeOverflowObserver.sampleCurrentControl() }
        }
        interactionGate.finish()
        if !interactionGate.isTerminating { ordinaryReveal.resume() }
        editorWindowController.setApplying(false)
        statusItemController.setInteractionBusy(interactionGate.isTerminating)
        #if DEBUG
        sessionDiagnostic("controls arrowEnabled=\(statusItemController.debugOrdinaryRevealButtonEnabled) localGlyphPresent=\(statusItemController.debugOrdinaryRevealButtonVisible) coordinatorEnabled=\(ordinaryReveal.canToggleBlenny) busy=\(interactionGate.isBusy)")
        sessionDiagnostic("resume editorEnabled=\(editorWindowController.debugResumeEnabled) menuEnabled=\(statusItemController.debugResumeEnabled)")
        sessionDiagnostic("arrowHasDedicatedNativeButton=\(statusItemController.debugOrdinaryRevealHasDedicatedButton)")
        #endif
        drainOrdinaryRevealRequest()
    }

    private func performPolicyAction(_ action: PolicyActionAuditTrail.Action) {
        guard !isReadOnlyValidation, let model = editorModel,
              action != .apply || model.hasDraftChanges,
              !model.hasDraftChanges || action == .apply || action == .stop,
              beginManagementInteraction() else { return }
        ordinaryReveal.suspend()
        actionAudit.record(action, phase: .preparing)
        editorWindowController.setStatus("Checking changes…", isError: false)
        ordinaryRevealTimeoutTask?.cancel()
        ordinaryRevealTimeoutTask = nil
        let generation = lifecycleGeneration

        managementInteractionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { finishManagementInteraction() }
            var preparedForAudit: PreparedPolicyEdit?
            do {
                var actionModel = model
                var preparationRunning = observedRunningBundleIdentifiers
                if action == .resume {
                    // A target may have launched after the failed startup. Re-read
                    // once for this explicit action, without a background refresh.
                    let observation = try await captureApplyPreflight()
                    actionModel = try PolicyEditorViewModel(
                        acceptedPolicy: model.acceptedPolicy,
                        candidateInventory: observation.candidates,
                        systemItems: model.systemItems,
                        blennyBundleIdentifier: model.blennyBundleIdentifier
                    )
                    preparationRunning = observation.runningBundleIdentifiers
                }
                if case .ordinaryRevealSession = await managementLoop.state,
                   let baseline = activeBaselinePlan {
                    await endOrdinaryReveal(
                        baseline: baseline,
                        persistedManagementEnabled: model.acceptedPolicy.managementEnabled
                    )
                }
                let scope: PolicyValidationScope
                var permitsReviewedActivation = action == .apply || action == .resume
                if action == .restore {
                    guard let backup = try await persistentStore?.loadBackup() else {
                        throw PolicyEditingCoreError.previousPolicyBackupMissing
                    }
                    scope = PolicyValidationScope(
                        approvedBundleIdentifiers: backup.previousPolicy.policies.map(\.bundleIdentifier)
                    )
                    permitsReviewedActivation = backup.previousPolicy.managementEnabled
                } else {
                    scope = action == .apply ? model.validationScope : model.acceptedPolicyScope
                }
                guard generation == lifecycleGeneration else {
                    throw ManagementLoopError.staleLifecycleGeneration
                }
                let core = try await makeCore(scope: scope, permitsReviewedActivation: permitsReviewedActivation)
                let preview: (PolicyDryRunImpactReport, PreparedPolicyEdit?)
                let candidateGeneration = editorWindowController.candidateGeneration
                switch action {
                case .apply:
                    preview = try await core.preview(
                        draft: model.draft,
                        candidates: model.candidateInventory,
                        observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                        candidateGeneration: candidateGeneration,
                        runtimeContractFingerprint: runtimeContractFingerprint
                    )
                case .resume:
                    preview = try await core.previewResumeManaging(
                        candidates: actionModel.candidateInventory,
                        observedRunningBundleIdentifiers: preparationRunning,
                        candidateGeneration: candidateGeneration,
                        runtimeContractFingerprint: runtimeContractFingerprint
                    )
                case .stop:
                    preview = try await core.previewStopManaging(
                        candidates: model.candidateInventory,
                        observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                        candidateGeneration: candidateGeneration,
                        runtimeContractFingerprint: runtimeContractFingerprint
                    )
                case .restore:
                    preview = try await core.previewRestorePreviousPolicy(
                        candidates: model.candidateInventory,
                        observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                        candidateGeneration: candidateGeneration,
                        runtimeContractFingerprint: runtimeContractFingerprint
                    )
                }
                guard let prepared = preview.1 else {
                    throw PolicyInterfaceWriteError.applyPreflightUnavailable(
                        preview.0.validationFailureSummary
                    )
                }
                preparedForAudit = prepared
                actionAudit.record(action, phase: .prepared, prepared: prepared)
                guard editorModel?.draft == model.draft,
                      generation == lifecycleGeneration,
                      !interactionGate.isTerminating else {
                    throw PolicyEditingCoreError.staleReviewedPlan
                }
                let outcome = try await apply(prepared, using: core, previousModel: actionModel, action: action)
                actionAudit.record(
                    action,
                    phase: outcome.result == .noChange ? .unchanged : .committed,
                    prepared: outcome.effectivePrepared
                )
            } catch {
                actionAudit.record(
                    action, phase: .failed, prepared: preparedForAudit,
                    failure: error as? PolicyEditingTransactionFailure
                )
                editorWindowController.setStatus(
                    "Could not \(action.rawValue): \(error.localizedDescription)",
                    isError: true
                )
                // Failures invoked from the status menu must also be visible.
                editorWindowController.showEditor()
            }
        }
    }

    private func apply(
        _ prepared: PreparedPolicyEdit,
        using core: PolicyEditingCore,
        previousModel model: PolicyEditorViewModel,
        action: PolicyActionAuditTrail.Action
    ) async throws -> PolicyEditingCommitOutcome {
        let generation = lifecycleGeneration
        developmentMutationAvailable = developmentCompatibilityAvailable(
            bundleIdentifier: model.blennyBundleIdentifier
        )
        guard !prepared.newPolicy.managementEnabled || developmentMutationAvailable else {
            throw PolicyInterfaceWriteError.installedDryRunRequired
        }
        do {
            let currentObservation: (
                candidates: PolicyCandidateInventory,
                runningBundleIdentifiers: Set<String>
            )
            if prepared.newPolicy.managementEnabled {
                editorWindowController.setStatus("Checking managed apps…", isError: false)
                currentObservation = try await captureApplyPreflight()
            } else {
                // A disabling action cannot create an assertion. Unrelated
                // process churn must never obstruct this safety cleanup.
                currentObservation = (
                    candidates: model.candidateInventory,
                    runningBundleIdentifiers: observedRunningBundleIdentifiers
                )
            }
            guard editorModel?.draft == model.draft,
                  generation == lifecycleGeneration,
                  !interactionGate.isTerminating else {
                throw PolicyEditingCoreError.staleReviewedPlan
            }
            await managementLoop.beginTransaction()
            presentManagementState(
                await managementLoop.state,
                persistedManagementEnabled: prepared.oldPolicy.managementEnabled
            )
            let outcome = try await core.commit(
                prepared,
                currentDraft: action == .apply ? model.draft : prepared.report.rawDraft,
                candidates: currentObservation.candidates,
                observedRunningBundleIdentifiers: currentObservation.runningBundleIdentifiers,
                candidateGeneration: editorWindowController.candidateGeneration,
                runtimeContractFingerprint: runtimeContractFingerprint
            )
            let applied = outcome.effectivePrepared
            guard generation == lifecycleGeneration else {
                // Persistence may have reached its commit point before the
                // notification. Keep accepted intent, never republish its writer.
                try await synchronizeInterfaceAfterCommit(
                    applied.newPolicy, previousModel: model, preservingDraft: action == .stop
                )
                throw ManagementLoopError.staleLifecycleGeneration
            }
            if outcome.result != .noChange {
                activeBaselinePlan = applied.newPolicy.managementEnabled
                    ? applied.report.newBaselinePlan : nil
                activeRevealPlan = applied.newPolicy.managementEnabled
                    ? applied.report.newRevealPlan : nil
            }
            try await managementLoop.synchronizeCommittedPolicy(
                applied.newPolicy,
                baseline: activeBaselinePlan
            )
            try await synchronizeInterfaceAfterCommit(
                applied.newPolicy, previousModel: model, preservingDraft: action == .stop
            )
            return outcome
        } catch {
            if generation == lifecycleGeneration {
                await reconcileManagementAfterFailure(prepared)
            }
            throw error
        }
    }

    private func captureApplyPreflight() async throws -> (
        candidates: PolicyCandidateInventory,
        runningBundleIdentifiers: Set<String>
    ) {
        guard AccessibilityAuthorization.isTrusted else {
            throw PolicyInterfaceWriteError.applyPreflightUnavailable(
                "Accessibility is not granted"
            )
        }
        guard !isRefreshing else {
            throw PolicyInterfaceWriteError.applyPreflightUnavailable(
                "a manual refresh is already running"
            )
        }

        let descriptors = runningApplicationDescriptors()
        let runningBundleIdentifiers = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        )
        let report = await inventory.capture(
            applications: descriptors,
            accessibilityTrusted: true
        )
        let snapshot = MenuBarOwnershipSnapshotBuilder.make(from: report)
        guard snapshot.isComplete else {
            let detail = snapshot.issues.map(\.description).joined(separator: "; ")
            throw PolicyInterfaceWriteError.applyPreflightUnavailable(detail)
        }
        let blennyBundleIdentifier = try currentBundleIdentifier()
        return (
            PolicyCandidateInventory(observations: snapshot.observations),
            runningBundleIdentifiers.union([blennyBundleIdentifier])
        )
    }

    private func synchronizeInterfaceAfterCommit(
        _ accepted: PersistentBundlePolicyDocument,
        previousModel: PolicyEditorViewModel,
        preservingDraft: Bool = false
    ) async throws {
        let synchronized = try previousModel.synchronizingAcceptedPolicy(
            accepted, preservingDraft: preservingDraft
        )
        let hasBackup = try await persistentStore?.loadBackup() != nil
        editorModel = synchronized
        recoveryAvailable = hasBackup
        statusItemController.setDraftHasChanges(synchronized.hasDraftChanges)
        editorWindowController.display(
            model: synchronized,
            observationCount: synchronized.candidateInventory.candidates.count,
            recoveryAvailable: hasBackup
        )
        let state = await managementLoop.state
        presentManagementState(
            state,
            persistedManagementEnabled: accepted.managementEnabled
        )
    }

    private func reconcileManagementAfterFailure(
        _ prepared: PreparedPolicyEdit
    ) async {
        if prepared.oldPolicy.managementEnabled,
           let oldBaseline = prepared.report.oldBaselinePlan,
           await managementLoop.activePlanSnapshot() == oldBaseline {
            try? await managementLoop.synchronizeCommittedPolicy(
                prepared.oldPolicy,
                baseline: oldBaseline
            )
        } else if !prepared.oldPolicy.managementEnabled,
                  await managementLoop.activePlanSnapshot() == nil {
            await managementLoop.stop()
        } else {
            await managementLoop.failClosed("transaction failure cleanup")
        }
        presentManagementState(
            await managementLoop.state,
            persistedManagementEnabled: prepared.oldPolicy.managementEnabled
        )
    }

    private func toggleOrdinaryReveal() {
        guard !interactionGate.isBusy, !interactionGate.isTerminating,
              !isRefreshing, connectionInvalidationTask == nil else { return }
        ordinaryReveal.requestBlennyToggle()
        drainOrdinaryRevealRequest()
    }

    private func drainOrdinaryRevealRequest() {
        guard AccessibilityAuthorization.isTrusted else {
            handleLifecycleEvent(.permissionLost)
            return
        }
        guard !interactionGate.isBusy, !interactionGate.isTerminating, !isRefreshing,
              connectionInvalidationTask == nil,
              let transition = ordinaryReveal.takePendingTransition() else { return }
        guard let baseline = activeBaselinePlan,
              let reveal = activeRevealPlan,
              let accepted = editorModel?.acceptedPolicy,
              beginManagementInteraction() else { return }
        sessionDiagnostic("intent consumed=\(transition.presentation.rawValue) owner=\(transition.owner.rawValue) reason=\(ordinaryReveal.lastConsumedReason ?? "none") \(ordinaryReveal.diagnosticSummary)")
        ordinaryRevealTimeoutTask?.cancel()
        ordinaryRevealTimeoutTask = nil
        managementInteractionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { finishManagementInteraction() }
            do {
                switch transition.presentation {
                case .revealed:
                    try await managementLoop.beginOrdinaryReveal(reveal)
                    presentManagementState(
                        await managementLoop.state,
                        persistedManagementEnabled: accepted.managementEnabled
                    )
                    guard let session = ordinaryReveal.sessionIdentifier else { return }
                    ordinaryRevealTimeoutTask = Task { @MainActor [weak self] in
                        do {
                            try await Task.sleep(for: .seconds(30))
                        } catch {
                            return
                        }
                        self?.ordinaryReveal.requestTimeout(session: session)
                        self?.drainOrdinaryRevealRequest()
                    }
                case .baseline:
                    await endOrdinaryReveal(
                        baseline: baseline,
                        persistedManagementEnabled: accepted.managementEnabled
                    )
                }
            } catch {
                // The writer keeps a preceding baseline after a failed reveal.
                // Do not throw that proven safety state away at the UI boundary.
                presentManagementState(
                    await managementLoop.state,
                    persistedManagementEnabled: accepted.managementEnabled
                )
                editorWindowController.setStatus(
                    "Could not reveal items. The previous safe state was retained, or management was stopped: \(error.localizedDescription)",
                    isError: true
                )
            }
        }
    }

    private func updateNativeOverflowObservation() {
        #if DEBUG
        guard policyCoexistenceController == nil else { return }
        #endif
        let shouldObserve = NativeOverflowObservationPolicy.shouldObserve(
            accessibilityTrusted: AccessibilityAuthorization.isTrusted,
            isTerminating: interactionGate.isTerminating,
            restartRequired: lifecycleRestartRequired
        )
        guard shouldObserve else {
            nativeOverflowObserver.stop()
            nativeObservationStarted = false
            ordinaryReveal.observe(.unavailable)
            statusItemController.setNativeOverflow(.unavailable)
            return
        }
        guard !nativeObservationStarted else { return }
        nativeObservationStarted = true
        nativeOverflowObserver.start(
            onAgentConnectionLost: { [weak self] in self?.nativeAgentConnectionLost() },
            onUpdate: { [weak self] snapshot in
                guard let self, !self.interactionGate.isTerminating else { return }
                let previous = self.ordinaryReveal.diagnosticSummary
                self.ordinaryReveal.observe(
                    snapshot, source: self.nativeOverflowObserver.lastUpdateSource
                )
                self.sessionDiagnostic("native present=\(snapshot.isPresent) observable=\(snapshot.observationAvailable) controls=\(snapshot.controlCount) identity=\(snapshot.controlIdentifier?.uuidString ?? "none") state=\(snapshot.presentationState.rawValue) source=\(self.nativeOverflowObserver.lastUpdateSource.rawValue) failure=\(self.nativeOverflowObserver.unavailabilityReason ?? "none") before={\(previous)} after={\(self.ordinaryReveal.diagnosticSummary)}")
                self.statusItemController.setNativeOverflow(snapshot)
                #if DEBUG
                if self.isReadOnlyValidation {
                    Self.writeDryRunOutput(
                        "NATIVE READ-ONLY EVENT wiring=ordinary source=\(self.nativeOverflowObserver.lastUpdateSource.rawValue)"
                            + " controls=\(snapshot.controlCount) state=\(snapshot.presentationState.rawValue)"
                            + " usable=\(snapshot.isUsable) identity=\(snapshot.controlIdentifier?.uuidString ?? "none")"
                            + " localGlyphPresent=\(self.statusItemController.debugOrdinaryRevealButtonVisible)"
                            + " reservedWidth=\(self.statusItemController.debugOrdinaryRevealButtonReservedWidth)"
                    )
                }
                #endif
                self.drainOrdinaryRevealRequest()
            }
        )
        #if DEBUG
        if isReadOnlyValidation || ProcessInfo.processInfo.environment["BLENNY_SESSION_DIAGNOSTICS"] == "YES" {
            nativeOverflowObserver.debugNotificationHandler = { detail in
                DebugSessionTrace.shared.write("native-notification \(detail)")
            }
            sessionDiagnostic("native subscriptions \(nativeOverflowObserver.debugSubscriptionSummary)")
        }
        #endif
    }

    private func nativeAgentConnectionLost() {
        handleLifecycleEvent(.menuBarAgentChanged)
    }

    private func installLifecycleObservers() {
        let workspace = NSWorkspace.shared.notificationCenter
        let events: [(Notification.Name, ManagementLifecycleEvent)] = [
            (NSWorkspace.willSleepNotification, .willSleep),
            (NSWorkspace.didWakeNotification, .didWake),
            (NSWorkspace.sessionDidResignActiveNotification, .sessionChanged),
            (NSWorkspace.sessionDidBecomeActiveNotification, .sessionChanged),
            (NSWorkspace.screensDidSleepNotification, .sessionChanged),
            (NSWorkspace.screensDidWakeNotification, .sessionChanged),
            (NSWorkspace.activeSpaceDidChangeNotification, .spaceChanged),
        ]
        for (name, event) in events {
            let token = workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.handleLifecycleEvent(event) }
            }
            lifecycleObservers.append((workspace, token))
        }
        let center = NotificationCenter.default
        let token = center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleLifecycleEvent(.displayChanged) }
        }
        lifecycleObservers.append((center, token))
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            let token = workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                let identifier = application.bundleIdentifier
                let event: ManagementLifecycleEvent = identifier?.lowercased() == "com.apple.menubaragent"
                    ? .menuBarAgentChanged
                    : (name == NSWorkspace.didLaunchApplicationNotification
                        ? .applicationLaunched(identifier) : .applicationTerminated(identifier))
                MainActor.assumeIsolated { self?.handleLifecycleEvent(event) }
            }
            lifecycleObservers.append((workspace, token))
        }
    }

    private func handleLifecycleEvent(_ event: ManagementLifecycleEvent) {
        guard !interactionGate.isTerminating else { return }
        let managed = Set(editorModel?.validationScope.approvedBundleIdentifiers ?? [])
        let allowed = activeBaselinePlan.map { Set($0.allowedBundleIdentifiers) }
            ?? observedRunningBundleIdentifiers
        guard ManagementLifecyclePolicy.invalidates(
            event, managedBundleIdentifiers: managed, allowedBundleIdentifiers: allowed,
            blennyBundleIdentifier: Bundle.main.bundleIdentifier ?? "xyz.fi5h.blenny"
        ) else { return }
        lifecycleGeneration &+= 1
        if event == .menuBarAgentChanged { lifecycleRestartRequired = true }
        if event == .menuBarAgentChanged || event == .permissionLost {
            updateNativeOverflowObservation()
        }
        // Inactive notification handling is read-only. It never retries startup.
        guard activeBaselinePlan != nil || interactionGate.isBusy || lifecycleRestartRequired else { return }
        attemptedStartupRecovery = true
        ordinaryReveal.suspend()
        // Invalidate queued intent, but keep read-only observation alive while
        // management is safely stopped. This sample cannot activate a writer.
        nativeOverflowObserver.sampleCurrentControl()
        ordinaryRevealTimeoutTask?.cancel()
        ordinaryRevealTimeoutTask = nil
        statusItemController.setInteractionBusy(true)
        guard connectionInvalidationTask == nil else { return }
        let activeInteraction = managementInteractionTask
        connectionInvalidationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if lifecycleRestartRequired {
                developmentMutationAvailable = false
                await managementLoop.connectionInvalidated()
            } else {
                await managementLoop.failClosed(event.reason)
            }
            // The writer is stopped first. Awaiting the bounded action prevents
            // a late completion from repainting the just-invalidated context.
            await activeInteraction?.value
            if lifecycleRestartRequired {
                await managementLoop.connectionInvalidated()
            }
            activeBaselinePlan = nil
            activeRevealPlan = nil
            connectionInvalidationTask = nil
            presentManagementState(
                await managementLoop.state,
                persistedManagementEnabled: editorModel?.acceptedPolicy.managementEnabled == true
            )
            statusItemController.setInteractionBusy(interactionGate.isBusy || interactionGate.isTerminating)
            let restored = await managementLoop.activePlanSnapshot() == nil
            sessionDiagnostic("lifecycle restored=\(restored) reason=\(event.reason)")
        }
    }

    /// Explicit local validation only; no normal disk logger or inventory dump.
    private func sessionDiagnostic(_ message: @autoclosure () -> String) {
        #if DEBUG
        guard DebugSessionTrace.shared.enabled else { return }
        DebugSessionTrace.shared.write(message())
        #endif
    }

    private func endOrdinaryReveal(
        baseline: RevealAllowlistPlan,
        persistedManagementEnabled: Bool
    ) async {
        ordinaryRevealTimeoutTask?.cancel()
        ordinaryRevealTimeoutTask = nil
        do {
            try await managementLoop.endOrdinaryReveal(baseline)
        } catch {
            await managementLoop.failClosed("ordinary reveal restoration failed")
        }
        presentManagementState(
            await managementLoop.state,
            persistedManagementEnabled: persistedManagementEnabled
        )
    }

    private func makeCore(
        scope: PolicyValidationScope,
        permitsReviewedActivation: Bool = false
    ) async throws -> PolicyEditingCore {
        guard let interfaceStore else {
            throw PolicyInterfaceWriteError.interfaceStoreUnavailable
        }
        let managementLoop = self.managementLoop
        let generation = lifecycleGeneration
        let writerGeneration = await managementLoop.generationSnapshot()
        return PolicyEditingCore(
            store: interfaceStore,
            blennyBundleIdentifier: try currentBundleIdentifier(),
            scope: scope,
            writerProvider: { [weak self] in
                guard await self?.permitsWriterUse(generation: generation) == true else {
                    throw ManagementLoopError.staleLifecycleGeneration
                }
                if permitsReviewedActivation {
                    return try await managementLoop.writerForReviewedActivation(expectedGeneration: writerGeneration)
                }
                return try await managementLoop.writerForTransaction()
            }
        )
    }

    private func permitsWriterUse(generation: UInt64) -> Bool {
        generation == lifecycleGeneration && !interactionGate.isTerminating
            && connectionInvalidationTask == nil && !isReadOnlyValidation
    }

    private func requestAccessibilityAccess() {
        guard !isReadOnlyValidation else { return }
        let defaults = UserDefaults.standard
        let action = AccessibilityOnboardingPolicy.action(
            isTrusted: AccessibilityAuthorization.isTrusted,
            hasRequestedSystemPrompt: defaults.bool(
                forKey: Self.accessibilityPromptRequestedKey
            )
        )
        switch action {
        case .alreadyGranted:
            refresh()
        case .requestSystemPrompt:
            defaults.set(true, forKey: Self.accessibilityPromptRequestedKey)
            _ = AccessibilityAuthorization.requestSystemPrompt()
            editorWindowController.setStatus(
                "The one-time system prompt was requested. Enable Blenny, then return for one automatic refresh.",
                isError: false
            )
        case .openSystemSettings:
            openAccessibilitySettings()
            editorWindowController.setStatus(
                "The system prompt will not be repeated. Enable Blenny, then return for one automatic refresh.",
                isError: false
            )
        }
        updatePermissionPresentation()
        showEditor()
    }

    private func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func openProjectWebsite() {
        openExternalURL(ProductSupportLinks.projectWebsite)
    }

    private func openMonthlySponsor() {
        openExternalURL(ProductSupportLinks.monthlySponsor)
    }

    private func openOneTimeSponsor() {
        openExternalURL(ProductSupportLinks.oneTimeSponsor)
    }

    private func openKoFi() {
        openExternalURL(ProductSupportLinks.koFi)
    }

    private func openExternalURL(_ rawValue: String) {
        guard let url = URL(string: rawValue) else { return }
        NSWorkspace.shared.open(url)
    }

    private func updatePermissionPresentation() {
        let trusted = AccessibilityAuthorization.isTrusted
        if lastKnownAccessibilityTrust == true && !trusted {
            handleLifecycleEvent(.permissionLost)
        }
        lastKnownAccessibilityTrust = trusted
        let requested = UserDefaults.standard.bool(
            forKey: Self.accessibilityPromptRequestedKey
        )
        editorWindowController.setAccessibilityTrusted(
            trusted,
            hasRequestedSystemPrompt: requested
        )
        statusItemController.setAccessibilityTrusted(trusted)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        guard !isReadOnlyValidation else { return }
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                } else if service.status != .enabled {
                    try service.register()
                }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
            updateLaunchAtLoginPresentation()
        } catch {
            updateLaunchAtLoginPresentation(failureMessage: error.localizedDescription)
        }
    }

    private func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func updateLaunchAtLoginPresentation(failureMessage: String? = nil) {
        let availability: LaunchAtLoginAvailability
        switch SMAppService.mainApp.status {
        case .notRegistered:
            availability = .disabled
        case .enabled:
            availability = .enabled
        case .requiresApproval:
            availability = .requiresApproval
        case .notFound:
            availability = .notFound
        @unknown default:
            availability = .notFound
        }
        editorWindowController.setLaunchAtLoginState(
            LaunchAtLoginPresentationState(
                availability: availability,
                failureMessage: failureMessage
            )
        )
    }

    private func makePersistentStore() throws -> PersistentBundlePolicyStore {
        if let persistentStore { return persistentStore }
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: !isReadOnlyValidation
        )
        let directory = applicationSupport
            .appendingPathComponent("Blenny", isDirectory: true)
            .appendingPathComponent("PersistentPolicyPrototype", isDirectory: true)
        return try PersistentBundlePolicyStore(
            policyURL: directory.appendingPathComponent("bundle-policies.json"),
            backupURL: directory.appendingPathComponent(
                "bundle-policies.previous.blenny-backup.json"
            ),
            readOnly: isReadOnlyValidation
        )
    }

    private func initialPolicy(
        blennyBundleIdentifier: String
    ) throws -> PersistentBundlePolicyDocument {
        try PersistentBundlePolicyDocument(
            managementEnabled: false,
            policies: [
                .init(bundleIdentifier: blennyBundleIdentifier, policy: .visible)
            ]
        )
    }

    private func currentBundleIdentifier() throws -> String {
        guard let identifier = Bundle.main.bundleIdentifier else {
            throw PersistentBundlePolicyDocumentError.invalidBundleIdentifier(
                "Blenny bundle identifier is unavailable"
            )
        }
        return identifier
    }

    private func runningApplicationDescriptors() -> [RunningApplicationDescriptor] {
        var applications = NSWorkspace.shared.runningApplications
        applications.append(
            contentsOf: NSRunningApplication.runningApplications(
                withBundleIdentifier: "com.apple.MenuBarAgent"
            )
        )
        applications = applications.filter { application in
            application.activationPolicy != .prohibited
                || isReadOnlySystemMenuBarOwner(application.bundleIdentifier)
        }
        applications.sort { first, second in
            scanPriority(for: first) < scanPriority(for: second)
        }

        var seenPIDs = Set<pid_t>()
        return applications.compactMap { application in
            guard application.processIdentifier > 0,
                  seenPIDs.insert(application.processIdentifier).inserted else {
                return nil
            }
            return RunningApplicationDescriptor(
                processIdentifier: application.processIdentifier,
                bundleIdentifier: application.bundleIdentifier
            )
        }
    }

    private func scanPriority(for application: NSRunningApplication) -> Int {
        if application.bundleIdentifier?.lowercased() == "com.apple.menubaragent" {
            return 0
        }
        if isReadOnlySystemMenuBarOwner(application.bundleIdentifier) { return 1 }
        if application.processIdentifier == ProcessInfo.processInfo.processIdentifier { return 2 }
        return 3
    }

    private func isReadOnlySystemMenuBarOwner(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return Self.readOnlySystemMenuBarOwners.contains(bundleIdentifier.lowercased())
    }
}
