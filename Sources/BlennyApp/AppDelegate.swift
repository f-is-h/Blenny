import AppKit
import BlennyCore
import Darwin
import ServiceManagement
#if DEBUG
import CryptoKit
#endif

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let legacyBlennyBundleIdentifier = "com.example.BlennyProbe"
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
    private var accessibilityOnboarding = AccessibilityOnboardingState()
    private var accessibilityGrantRefresh = AccessibilityGrantRefreshState()
    private var persistentStore: PersistentBundlePolicyStore?
    private var interfaceStore: PolicyInterfaceStore?
    private var editorModel: PolicyEditorViewModel?
    private var ownershipSnapshot: MenuBarOwnershipSnapshot?
    private var observedRunningBundleIdentifiers = Set<String>()
    // Session-only pass-through memory, never a persisted policy assignment.
    private var admittedPassThroughBundleIdentifiers = Set<String>()
    private var recoveryAvailable = false
    private var developmentMutationAvailable = false
    private var terminationRestoreInProgress = false
    private var terminateImmediatelyToReleaseConnection = false
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
    private var displayConfiguration = DisplayConfigurationSignature(displays: [])
    private var pendingApplicationLaunchAssessments: [String: RunningApplicationDescriptor] = [:]
    private var applicationLaunchAssessmentTask: Task<Void, Never>?
    private var fallbackSlotVerificationTask: Task<Void, Never>?
    private lazy var managementLoop: ManagementLoopController = {
        let readOnly = isReadOnlyValidation
        return ManagementLoopController(writerProvider: { [unowned self] in
            guard !readOnly else { throw PolicyInterfaceWriteError.installedDryRunRequired }
            let factory = try ExperimentalMacOS27AssessmentFactory()
            let assertionWriter: RevealAssertionWriter
            #if DEBUG
            let trace = DebugSessionTrace.shared
            if trace.enabled {
                assertionWriter = RevealAssertionWriter(factory: factory, diagnostic: { message in
                    trace.write(message)
                })
            } else {
                assertionWriter = RevealAssertionWriter(factory: factory)
            }
            #else
            assertionWriter = RevealAssertionWriter(factory: factory)
            #endif
            #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
            let persistentWriter = await self.sharedSystemItemTrialWriter
            #if DEBUG
            let backend = await self.orderingBackend
            let recovery = await self.orderingRecoveryStore
            let orderingPolicyStore = await self.persistentStore
            return CoordinatedPolicyWriter(
                assertionWriter: assertionWriter, persistentWriter: persistentWriter,
                orderingBackend: backend, orderingRecovery: recovery,
                orderingPolicyStore: orderingPolicyStore,
                fallbackRecovery: await self.fallbackTrialRecovery
            )
            #else
            return CoordinatedPolicyWriter(
                assertionWriter: assertionWriter, persistentWriter: persistentWriter
            )
            #endif
            #else
            return assertionWriter
            #endif
        })
    }()
    private var isReadOnlyValidation: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["BLENNY_0_6_0_DRY_RUN"] == "YES"
            || ProcessInfo.processInfo.environment["BLENNY_0_5_0_DRY_RUN"] == "YES"
            || ProcessInfo.processInfo.environment["BLENNY_0_9_0_ORDERING_DRY_RUN"] == "YES"
        #else
        false
        #endif
    }
    #if DEBUG
    private var policyCoexistenceController: DebugPolicyCoexistenceController?
    private var validationDeadlineTask: Task<Void, Never>?
    private var preparedOrderingPlan: OrderingPlan?
    private var preparedBoardPolicy: PreparedPolicyEdit?
    private var preparedBoardRequest: DebugOrderingConfigurationRequest?
    private var preparedBoardFingerprint: String?
    private var preparedUnsortedNames: [String] = []
    private var preparedUndoRebaseToken: String?
    private var lastOrderingSnapshot: OrderingSnapshot?
    private var boundaryCaptureInProgress = false
    private var boundaryCaptureTask: Task<Void, Never>?
    private var boundaryEvidenceDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Blenny/LocalData/BoundaryDiagnostics")
    }
    private var activeOrderingPlan: OrderingPlan?
    private var orderingRecoveryKnown = false
    private lazy var fallbackRecoveryStore = FallbackPositionRecoveryStore(
        directory: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Blenny/LocalData/FallbackPositionExperiment")
    )
    private var fallbackTrialRecovery: (any FallbackPositionRecoveryStoring)? {
        #if DEBUG
        fallbackRecoveryStore
        #else
        nil
        #endif
    }
    private lazy var orderingRecoveryStore = OrderingRecoveryStore(
        directory: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Blenny/DebugOrdering")
    )
    private lazy var menuBarLayoutAccess = MenuBarLayoutAccessSession(
        store: MenuBarLayoutBookmarkStore(
            directory: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Blenny/DebugOrdering")
        )
    )
    private lazy var orderingBackend = MacOS27MenuBarOrderingBackend(
        contextProvider: { [weak self] in
            self?.orderingRuntimeContext() ?? MacOS27MenuBarOrderingContext(
                policyFingerprint: "unavailable", orderingAllowedBundleIdentifiers: [], lifecycleGeneration: 0
            )
        },
        fallbackIdentityProvider: { [weak self] in
            #if DEBUG
            self?.statusItemController.debugFallbackNativeIdentity
            #else
            nil
            #endif
        }
    )
    #endif
    #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    private lazy var sharedSystemItemTrialWriter = SharedSystemItemManualTrialWriter(
        backend: DebugSharedSystemItemTrialBackend(),
        receiptDirectory: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Blenny")
            .appendingPathComponent("DebugSharedSystemItemTrials")
    )
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
        onOpenLoginItemsSettings: { [weak self] in self?.openLoginItemsSettings() },
        onShowFishPlacementGuide: { [weak self] in self?.showFishPlacementGuide() },
        onHideSharedSystemItem: { [weak self] target in
            self?.hideSharedSystemItem(target)
        },
        onRestoreSharedSystemItem: { [weak self] target in
            self?.restoreSharedSystemItem(target)
        }
    )

    private lazy var statusItemController = StatusItemController(
        onOpenDiagnostics: { [weak self] in self?.showEditor() },
        onRefresh: { [weak self] in self?.refresh() },
        onRequestAccess: { [weak self] in self?.requestAccessibilityAccess() },
        onToggleOrdinaryReveal: { [weak self] in self?.toggleOrdinaryReveal() },
        onResumeManaging: { [weak self] in self?.resumeManaging() },
        onStopManaging: { [weak self] in self?.stopManaging() },
        onRestorePreviousPolicy: { [weak self] in self?.restorePreviousPolicy() },
        onQuit: { NSApplication.shared.terminate(nil) },
        onVerifyNativeOverflowAfterSlotCompaction: { [weak self] in
            self?.scheduleFallbackSlotVerification()
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(permissionWindowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        configureMainMenu()
        #if DEBUG
        configureOrderingInterface()
        restoreSavedMenuBarLayoutAccess()
        statusItemController.debugConfigureBoundaryCapture(directory: boundaryEvidenceDirectory) { [weak self] in
            self?.captureBoundaryEvidence()
        }
        #if DEBUG
        statusItemController.debugMoveFallback = { [weak self] in self?.positionRevealArrow(restoring: false) }
        statusItemController.debugRestoreFallback = { [weak self] in self?.positionRevealArrow(restoring: true) }
        #endif
        #endif
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
                DispatchQueue.main.async { @MainActor in
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        #endif
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        refreshSharedSystemItemTrialPresentation()
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
        applicationLaunchAssessmentTask?.cancel()
        applicationLaunchAssessmentTask = nil
        fallbackSlotVerificationTask?.cancel()
        fallbackSlotVerificationTask = nil
        pendingApplicationLaunchAssessments.removeAll()
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
        if terminateImmediatelyToReleaseConnection {
            return .terminateNow
        }
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

    @objc private func permissionWindowDidBecomeKey(_ notification: Notification) {
        applicationDidBecomeActive(notification)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        let previouslyTrusted = lastKnownAccessibilityTrust
        updatePermissionPresentation()
        updateLaunchAtLoginPresentation()
        updateNativeOverflowObservation()
        let shouldRefreshAfterGrant = AccessibilityPermissionRefreshPolicy.shouldRefresh(
            previouslyTrusted: accessibilityGrantRefresh.pending ? false : previouslyTrusted,
            isTrusted: lastKnownAccessibilityTrust == true,
            isRefreshing: isRefreshing,
            hasDraftChanges: editorWindowController.hasDraftChanges
        )
        if shouldRefreshAfterGrant {
            refresh()
        } else if previouslyTrusted == false,
                  lastKnownAccessibilityTrust == true,
                  editorWindowController.hasDraftChanges {
            editorWindowController.setStatus(
                "Accessibility is granted. Apply or discard the local Draft before refreshing.",
                isError: false
            )
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        ordinaryRevealTimeoutTask?.cancel()
        ordinaryRevealTimeoutTask = nil
        if !terminateImmediatelyToReleaseConnection {
            Task { await managementLoop.terminate() }
        }
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
              !editorWindowController.hasDraftChanges, connectionInvalidationTask == nil else { return }
        updatePermissionPresentation()
        guard AccessibilityAuthorization.isTrusted else {
            editorWindowController.setStatus(
                "Turn on Blenny in Device Control and Data Access, then return. Blenny will refresh automatically.",
                isError: false
            )
            return
        }

        guard beginManagementInteraction() else { return }
        accessibilityGrantRefresh.didBeginRefresh()
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
            let loadedPolicy = try await store.load()
            var accepted = try loadedPolicy ?? initialPolicy(
                blennyBundleIdentifier: blennyBundleIdentifier
            )
            #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
            // Manual system-item trials use an isolated store and always wait
            // for an explicit Apply/Resume after launch. Refresh must not stop
            // an already active owner-operated test.
            if editorModel == nil {
                accepted = try accepted.settingManagementEnabled(false)
                if !isReadOnlyValidation, loadedPolicy != accepted {
                    if loadedPolicy == nil {
                        try await store.save(accepted)
                    } else {
                        _ = try await store.disableManualTrialManagementPreservingBackup()
                    }
                }
            }
            #endif
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
            let runningIdentifiers = runningBundleIdentifiers
                .union(admittedPassThroughBundleIdentifiers).union([blennyBundleIdentifier])
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
            statusItemController.setDraftHasChanges(
                editorWindowController.hasDraftChanges,
                requiresObservationRefresh: editorWindowController.requiresObservationRefresh
            )
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
            // The board reads physical order with its ordinary bounded refresh.
            // This stays inside the existing interaction gate and never creates
            // an ordering writer, even when startup has a recovery receipt.
            if !isReadOnlyValidation {
                presentBoardGeometry(report: report, candidates: candidateInventory.candidates)
                await readOrderingForBoard()
            }
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
        switch state {
        case .stopped, .failClosedUnrestricted, .restorationFailed,
             .connectionInvalidated, .unsupportedRuntimeContract, .terminating:
            admittedPassThroughBundleIdentifiers.removeAll()
        default:
            break
        }
        let hasRevealable = editorModel.map { model in
            model.acceptedPolicy.policies.contains { $0.policy == .revealable }
                || model.acceptedPolicy.bluetoothPolicy == .revealable
                || model.acceptedPolicy.systemItemPolicies.values.contains(.revealable)
        } ?? false
        ordinaryReveal.synchronize(state, hasRevealableBundles: hasRevealable)
        updateNativeOverflowObservation()
        statusItemController.setNativeOverflow(ordinaryReveal.observation)
        editorWindowController.setNativeOverflowPlacement(ordinaryReveal.observation)
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
        if let notice = state.statusNotice(persistedManagementEnabled: persistedManagementEnabled) {
            editorWindowController.setStatus(notice.message, isError: notice.isError)
        }
        if state.requiresImmediateProcessExit {
            terminateImmediatelyToReleaseConnection = true
            // Never re-enter termination from the policy transaction that
            // discovered the failed cleanup. The next run-loop turn exits
            // immediately so process-connection teardown cannot self-await.
            RunLoop.main.perform(inModes: [.common]) {
                MainActor.assumeIsolated { NSApplication.shared.terminate(nil) }
            }
        }
    }

    #if DEBUG
    private func runInstalledDryRunIfRequested(
        model: PolicyEditorViewModel
    ) async {
        guard isReadOnlyValidation
        else { return }
        if ProcessInfo.processInfo.environment["BLENNY_0_9_0_ORDERING_DRY_RUN"] == "YES" {
            // Let the ordinary refresh finish its UI interaction before the
            // separately bounded, read-only ordering inspection starts.
            Task { @MainActor [weak self] in await self?.runInstalledOrderingDryRun() }
            return
        }
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
            guard let baseline = preview.0.newBaselinePlan,
                  let reveal = preview.0.newRevealPlan,
                  let expansion = try PassThroughExpansion.prepare(
                    baseline: baseline, reveal: reveal,
                    acceptedBundleIdentifiers: Set(model.acceptedPolicyScope.approvedBundleIdentifiers),
                    launchedBundleIdentifiers: ["xyz.fi5h.blenny.validation.passthrough"]
                  ) else {
                throw PolicyInterfaceWriteError.applyPreflightUnavailable("Pass-through dry-run plan is unavailable")
            }
            try PassThroughExpansion.validateReplacement(
                from: baseline, to: expansion.baseline,
                addedBundleIdentifiers: Set(expansion.addedBundleIdentifiers)
            )
            try PassThroughExpansion.validateReplacement(
                from: reveal, to: expansion.reveal,
                addedBundleIdentifiers: Set(expansion.addedBundleIdentifiers)
            )
            Self.writeDryRunOutput(
                "PASS-THROUGH PREVIEW additions=\(expansion.addedBundleIdentifiers.count)"
                    + " systemItemsUnchanged=true policyUnchanged=true"
                    + " writerCreated=false assertionCreated=false persistenceChanged=false"
            )
            var manualPlansVerified = 0
            for item in SystemItemPolicyCatalog.items {
                for policy in MenuBarBundlePolicy.allCases {
                    let originalDraft = BundlePolicyDraft(acceptedPolicy: model.acceptedPolicy)
                    let trialDraft = item.rawValue == RevealAllowlistPlanner.bluetoothSystemItem
                        ? originalDraft.assigningBluetooth(to: policy)
                        : originalDraft.assigningSystemItem(identifier: item.identifier, to: policy)
                    let trial = try PolicyDryRunner.prepare(
                        oldPolicy: model.acceptedPolicy, draft: trialDraft,
                        managementEnabled: true, candidates: model.candidateInventory,
                        observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                        scope: model.acceptedPolicyScope,
                        blennyBundleIdentifier: model.blennyBundleIdentifier,
                        candidateGeneration: editorWindowController.candidateGeneration,
                        runtimeContractFingerprint: runtimeContractFingerprint
                    )
                    guard trial.prepared != nil,
                          let baseline = trial.report.newBaselinePlan,
                          let reveal = trial.report.newRevealPlan,
                          baseline.allowedSystemItems.contains(2),
                          reveal.allowedSystemItems.contains(2),
                          baseline.allowedSystemItems.contains(item.rawValue) == (policy == .visible),
                          reveal.allowedSystemItems.contains(item.rawValue) == (policy != .hidden) else {
                        throw PolicyInterfaceWriteError.applyPreflightUnavailable(
                            "Manual system-item policy fixture failed for \(item.displayName)"
                        )
                    }
                    manualPlansVerified += 1
                }
            }
            Self.writeDryRunOutput(
                "MANUAL SYSTEM-ITEM PREVIEW controls=\(SystemItemPolicyCatalog.items.count)"
                    + " policyPlans=\(manualPlansVerified) clockAlwaysAllowed=true"
                    + " startsStopped=\(!model.acceptedPolicy.managementEnabled)"
                    + " isolatedPolicyStore=true writerCreated=false assertionCreated=false"
                    + " persistenceChanged=false"
            )
            var appleOwnerPlansVerified = 0
            for catalogIdentifier in ExperimentalAppleBundlePolicyCatalog.bundleIdentifiers.sorted() {
                guard let currentOwner = model.candidateInventory.candidates.first(where: {
                    $0.bundleIdentifier.lowercased() == catalogIdentifier
                }) else {
                    throw PolicyInterfaceWriteError.applyPreflightUnavailable(
                        "Experimental Apple owner is not an exact current menu-bar candidate: \(catalogIdentifier)"
                    )
                }
                let bundleIdentifier = currentOwner.bundleIdentifier
                for policy in MenuBarBundlePolicy.allCases {
                    let trialDraft = BundlePolicyDraft(acceptedPolicy: model.acceptedPolicy)
                        .assigning(bundleIdentifier, to: policy)
                    let trialScope = PolicyValidationScope(
                        approvedBundleIdentifiers:
                            trialDraft.visible + trialDraft.revealable + trialDraft.hidden
                    )
                    let trial = try PolicyDryRunner.prepare(
                        oldPolicy: model.acceptedPolicy, draft: trialDraft,
                        managementEnabled: true, candidates: model.candidateInventory,
                        observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                        scope: trialScope,
                        blennyBundleIdentifier: model.blennyBundleIdentifier,
                        candidateGeneration: editorWindowController.candidateGeneration,
                        runtimeContractFingerprint: runtimeContractFingerprint
                    )
                    guard trial.prepared != nil,
                          let baseline = trial.report.newBaselinePlan,
                          let reveal = trial.report.newRevealPlan,
                          baseline.allowedBundleIdentifiers.contains(bundleIdentifier)
                            == (policy == .visible),
                          reveal.allowedBundleIdentifiers.contains(bundleIdentifier)
                            == (policy != .hidden) else {
                        throw PolicyInterfaceWriteError.applyPreflightUnavailable(
                            "Experimental Apple owner fixture failed for \(bundleIdentifier)"
                        )
                    }
                    appleOwnerPlansVerified += 1
                }
            }
            Self.writeDryRunOutput(
                "EXPERIMENTAL APPLE-OWNER PREVIEW controls="
                    + "\(ExperimentalAppleBundlePolicyCatalog.bundleIdentifiers.count)"
                    + " policyPlans=\(appleOwnerPlansVerified) exactCurrentOwners=true"
                    + " writerCreated=false assertionCreated=false persistenceChanged=false"
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
            editorWindowController.setNativeOverflowPlacement(.unavailable)
        } catch {
            nativeOverflowObserver.stop()
            statusItemController.setNativeOverflow(.unavailable)
            editorWindowController.setNativeOverflowPlacement(.unavailable)
            Self.writeDryRunOutput("DRY-RUN FAILED: \(error)")
        }
        NSApplication.shared.terminate(nil)
    }

    private static func writeDryRunOutput(_ text: String) {
        guard let data = "\(text)\n".data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }

    /// Exercises the installed product reader and planner with the ordinary
    /// read-only policy store. The writer provider rejects this entire launch.
    private func runInstalledOrderingDryRun() async {
        do {
            let snapshot = try await orderingBackend.capture()
            let candidates = try OrderingIdentityResolver.resolve(snapshot: snapshot)
            presentOrderingCandidates(snapshot)
            await updateOrderingRecoveryPresentation()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let receipt = try await orderingRecoveryStore.load(),
               let review = try receipt.undoLedgerRebaseReview(in: snapshot) {
                Self.writeDryRunOutput("ORDERING READ-ONLY UNDO REBASE REVIEW: " + review.userDescription)
            }
            Self.writeDryRunOutput("ORDERING READ-ONLY SNAPSHOT")
            FileHandle.standardOutput.write(try encoder.encode(snapshot))
            Self.writeDryRunOutput("\nORDERING CANDIDATES")
            for candidate in candidates where candidate.key != nil
                || snapshot.observationsByPID.values.contains(where: {
                    $0.process.bundleIdentifier == candidate.bundleIdentifier
                }) {
                Self.writeDryRunOutput(
                    "\(candidate.bundleIdentifier): eligible=\(candidate.eligible) "
                        + candidate.reasons.map(\.userDescription).joined(separator: "; ")
                )
            }
            let insertion = ProcessInfo.processInfo.environment["BLENNY_ORDERING_REORDER_BUNDLES"]
            let previewPlan: OrderingPlan?
            if let selection = ProcessInfo.processInfo.environment["BLENNY_ORDERING_PREVIEW_SUBJECTS"] {
                let identifiers = selection.split(separator: ",").map(String.init)
                let subjects = identifiers.compactMap { OrderingSubjectID(boardID: $0) }
                guard !subjects.isEmpty, subjects.count == identifiers.count else {
                    throw OrderingError.invalidSelection
                }
                previewPlan = try OrderingPlan.makeConfigurationOrdering(
                    snapshot: snapshot, orderedSubjects: subjects
                )
            } else if let selection = insertion
                ?? ProcessInfo.processInfo.environment["BLENNY_ORDERING_PREVIEW_BUNDLES"] {
                let bundles = selection.split(separator: ",").map(String.init)
                previewPlan = try insertion == nil
                    ? OrderingPlan.make(snapshot: snapshot, bundleIdentifiers: bundles)
                    : OrderingPlan.makeReordering(snapshot: snapshot, orderedBundleIdentifiers: bundles)
            } else {
                previewPlan = nil
            }
            if let plan = previewPlan {
                Self.writeDryRunOutput("ORDERING READ-ONLY PREVIEW")
                FileHandle.standardOutput.write(try encoder.encode(plan))
                if ProcessInfo.processInfo.environment["BLENNY_ORDERING_VERIFY_PREFLIGHT"] == "YES" {
                    // One additional read diagnoses freshness without creating a
                    // writer, sleeping, retrying or changing the reviewed plan.
                    let current = try await orderingBackend.capture()
                    Self.writeDryRunOutput("\nORDERING READ-ONLY PREFLIGHT SNAPSHOT")
                    FileHandle.standardOutput.write(try encoder.encode(current))
                    do {
                        try plan.validateFresh(equivalentTo: current)
                        Self.writeDryRunOutput("\nORDERING READ-ONLY PREFLIGHT equivalent=true")
                    } catch {
                        Self.writeDryRunOutput("\nORDERING READ-ONLY PREFLIGHT rejected: \(error.localizedDescription)")
                    }
                }
            }
            Self.writeDryRunOutput(
                "\nORDERING DRY-RUN PASSED writerCreated=false orderingWrite=false"
                    + " receiptWritten=false policyStoreReadOnly=true"
            )
            if let raw = ProcessInfo.processInfo.environment["BLENNY_0_9_0_OBSERVE_SECONDS"],
               let seconds = Int(raw), (1...60).contains(seconds) {
                showEditor()
                Self.writeDryRunOutput("ORDERING READ-ONLY UI WINDOW seconds=\(seconds)")
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds)) {
                    Self.writeDryRunOutput("ORDERING READ-ONLY UI WINDOW finished")
                    NSApplication.shared.terminate(nil)
                }
                return
            }
        } catch {
            Self.writeDryRunOutput("ORDERING DRY-RUN FAILED: \(error)")
        }
        // Exit from an AppKit run-loop turn, outside this Swift task's job.
        RunLoop.main.perform(inModes: [.common]) {
            MainActor.assumeIsolated { NSApplication.shared.terminate(nil) }
        }
    }
    #endif

    #if !DEBUG && !BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    private func hideSharedSystemItem(_ target: SharedSystemItemTrialTarget) {}
    private func restoreSharedSystemItem(_ target: SharedSystemItemTrialTarget) {}
    #endif

    private var runtimeContractFingerprint: String {
        ExperimentalMacOS27AssessmentFactory.compatibilityFingerprint
    }

    private func developmentCompatibilityAvailable(
        bundleIdentifier: String
    ) -> Bool {
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
    }

    private func resumeManaging() { performPolicyAction(.resume) }
    private func applyDraftChanges() {
        #if DEBUG
        if let request = editorWindowController.currentOrderingConfigurationRequest {
            previewBoardConfiguration(request, applyWhenReady: true)
            return
        }
        #endif
        performPolicyAction(.apply)
    }
    private func stopManaging() { performPolicyAction(.stop) }
    private func restorePreviousPolicy() { performPolicyAction(.restore) }

    private func draftDidChange(_ model: PolicyEditorViewModel) {
        guard !interactionGate.isBusy, !interactionGate.isTerminating else { return }
        editorModel = model
        #if DEBUG
        discardOrderingPreview()
        #endif
        statusItemController.setDraftHasChanges(
            editorWindowController.hasDraftChanges,
            requiresObservationRefresh: editorWindowController.requiresObservationRefresh
        )
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
        scheduleApplicationLaunchAssessment()
        if !interactionGate.isTerminating { ordinaryReveal.resume() }
        editorWindowController.setApplying(false)
        statusItemController.setDraftHasChanges(
            editorWindowController.hasDraftChanges,
            requiresObservationRefresh: editorWindowController.requiresObservationRefresh
        )
        statusItemController.setInteractionBusy(interactionGate.isTerminating)
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        refreshSharedSystemItemTrialPresentation()
        #endif
        #if DEBUG
        sessionDiagnostic("controls arrowEnabled=\(statusItemController.debugOrdinaryRevealButtonEnabled) localGlyphPresent=\(statusItemController.debugOrdinaryRevealButtonVisible) coordinatorEnabled=\(ordinaryReveal.canToggleBlenny) busy=\(interactionGate.isBusy)")
        sessionDiagnostic("resume editorEnabled=\(editorWindowController.debugResumeEnabled) menuEnabled=\(statusItemController.debugResumeEnabled)")
        sessionDiagnostic("arrowHasDedicatedNativeButton=\(statusItemController.debugOrdinaryRevealHasDedicatedButton)")
        #endif
        drainOrdinaryRevealRequest()
        if accessibilityGrantRefresh.pending {
            Task { @MainActor [weak self] in
                guard let self, NSApplication.shared.isActive,
                      accessibilityGrantRefresh.pending else { return }
                refresh()
            }
        }

    }

    private func performPolicyAction(_ action: PolicyActionAuditTrail.Action) {
        guard !isReadOnlyValidation, let model = editorModel,
              action == .stop || !editorWindowController.requiresObservationRefresh,
              action != .apply || model.hasDraftChanges,
              !editorWindowController.hasDraftChanges || action == .apply || action == .stop,
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
                #if DEBUG
                discardOrderingPreview()
                if orderingRecoveryKnown && action != .stop {
                    let writer = try await orderingCoordinator()
                    let restored = try await writer.restoreOrdering()
                    guard restored.relativeOrderVerified else {
                        throw OrderingTransactionError.restorationNotVerified
                    }
                    activeOrderingPlan = nil
                    await updateOrderingRecoveryPresentation()
                }
                #endif
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
                if outcome.result != .noChange {
                    editorWindowController.setStatus(
                        action == .apply ? "Changes applied" : "Done", isError: false
                    )
                }
                #if DEBUG
                if action == .apply, let failure = await updateAcceptedControlBoundary() {
                    editorWindowController.setStatus("Changes applied. \(failure)", isError: true)
                }
                #endif
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
                    applied.newPolicy, previousModel: model,
                    preservingDraft: action == .stop,
                    preservingOrderingLayout: action == .apply
                        || action == .resume || action == .stop
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
                applied.newPolicy, previousModel: model,
                preservingDraft: action == .stop,
                preservingOrderingLayout: action == .apply
                    || action == .resume || action == .stop
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
            runningBundleIdentifiers.union(admittedPassThroughBundleIdentifiers)
                .union([blennyBundleIdentifier])
        )
    }

    private func synchronizeInterfaceAfterCommit(
        _ accepted: PersistentBundlePolicyDocument,
        previousModel: PolicyEditorViewModel,
        preservingDraft: Bool = false,
        preservingOrderingLayout: Bool = false
    ) async throws {
        let synchronized = try previousModel.synchronizingAcceptedPolicy(
            accepted, preservingDraft: preservingDraft
        )
        let hasBackup = try await persistentStore?.loadBackup() != nil
        editorModel = synchronized
        recoveryAvailable = hasBackup
        statusItemController.setDraftHasChanges(
            editorWindowController.hasDraftChanges,
            requiresObservationRefresh: editorWindowController.requiresObservationRefresh
        )
        editorWindowController.display(
            model: synchronized,
            observationCount: synchronized.candidateInventory.candidates.count,
            recoveryAvailable: hasBackup,
            preservingOrderingLayout: preservingOrderingLayout
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
        #if DEBUG
        let id = statusItemController.debugDispatchClickCheckID
        statusItemController.debugRecordClickStage("toggle entry", id: id)
        #endif
        guard !interactionGate.isBusy, !interactionGate.isTerminating,
              !isRefreshing, connectionInvalidationTask == nil else {
            #if DEBUG
            statusItemController.debugRecordClickStage(
                "rejected busy=\(interactionGate.isBusy) terminating=\(interactionGate.isTerminating) refreshing=\(isRefreshing) connectionInvalidating=\(connectionInvalidationTask != nil)",
                id: id, finished: true)
            #endif
            return
        }
        ordinaryReveal.requestBlennyToggle()
        #if DEBUG
        drainOrdinaryRevealRequest(diagnosticID: id)
        #else
        drainOrdinaryRevealRequest()
        #endif
    }

    private func drainOrdinaryRevealRequest(diagnosticID: UUID? = nil) {
        guard AccessibilityAuthorization.isTrusted else {
            #if DEBUG
            statusItemController.debugRecordClickStage("rejected: accessibility unavailable",
                id: diagnosticID, finished: true)
            #endif
            handleLifecycleEvent(.permissionLost)
            return
        }
        guard !interactionGate.isBusy, !interactionGate.isTerminating, !isRefreshing,
              connectionInvalidationTask == nil,
              let transition = ordinaryReveal.takePendingTransition() else {
            #if DEBUG
            statusItemController.debugRecordClickStage(
                "not consumed: busy=\(interactionGate.isBusy) refreshing=\(isRefreshing) coordinator=\(ordinaryReveal.diagnosticSummary)",
                id: diagnosticID, finished: true)
            #endif
            return
        }
        guard let baseline = activeBaselinePlan,
              let reveal = activeRevealPlan,
              let accepted = editorModel?.acceptedPolicy,
              beginManagementInteraction() else {
            #if DEBUG
            statusItemController.debugRecordClickStage("rejected: missing active plan/policy or interaction unavailable",
                id: diagnosticID, finished: true)
            #endif
            return
        }
        #if DEBUG
        statusItemController.debugRecordClickStage("consumed=\(transition.presentation.rawValue)", id: diagnosticID)
        #endif
        sessionDiagnostic("intent consumed=\(transition.presentation.rawValue) owner=\(transition.owner.rawValue) reason=\(ordinaryReveal.lastConsumedReason ?? "none") \(ordinaryReveal.diagnosticSummary)")
        ordinaryRevealTimeoutTask?.cancel()
        ordinaryRevealTimeoutTask = nil
        managementInteractionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            #if DEBUG
            var diagnosticOutcome = "transition ended without a state result"
            #endif
            defer {
                #if DEBUG
                statusItemController.debugRecordClickStage(diagnosticOutcome, id: diagnosticID, finished: true)
                #endif
                finishManagementInteraction()
            }
            do {
                switch transition.presentation {
                case .revealed:
                    try await managementLoop.beginOrdinaryReveal(reveal)
                    #if DEBUG
                    diagnosticOutcome = "result=\(await managementLoop.state)"
                    #endif
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
                    #if DEBUG
                    diagnosticOutcome = "result=\(await managementLoop.state)"
                    #endif
                }
            } catch {
                #if DEBUG
                diagnosticOutcome = "failed=\(error.localizedDescription) state=\(await managementLoop.state)"
                #endif
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
            editorWindowController.setNativeOverflowPlacement(.unavailable)
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
                self.statusItemController.setNativeOverflow(snapshot)
                #if DEBUG
                self.sessionDiagnostic("native present=\(snapshot.isPresent) observable=\(snapshot.observationAvailable) controls=\(snapshot.controlCount) identity=\(snapshot.controlIdentifier?.uuidString ?? "none") state=\(snapshot.presentationState.rawValue) source=\(self.nativeOverflowObserver.lastUpdateSource.rawValue) failure=\(self.nativeOverflowObserver.unavailabilityReason ?? "none") localSlot=\(self.statusItemController.debugOrdinaryRevealSlotMode) localSlotWidth=\(self.statusItemController.debugOrdinaryRevealButtonReservedWidth) before={\(previous)} after={\(self.ordinaryReveal.diagnosticSummary)}")
                #endif
                self.editorWindowController.setNativeOverflowPlacement(snapshot)
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

    private func scheduleFallbackSlotVerification() {
        guard fallbackSlotVerificationTask == nil else { return }
        sessionDiagnostic("fallback-slot compaction=started verification=scheduled-once")
        fallbackSlotVerificationTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard let self else { return }
            self.fallbackSlotVerificationTask = nil
            self.sessionDiagnostic("fallback-slot verification=sample-once")
            self.nativeOverflowObserver.sampleCurrentControl()
        }
    }

    private func installLifecycleObservers() {
        displayConfiguration = currentDisplayConfiguration()
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
            MainActor.assumeIsolated { self?.handleDisplayConfigurationNotification() }
        }
        lifecycleObservers.append((center, token))
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            let token = workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if name == NSWorkspace.didLaunchApplicationNotification {
                        self.handleWorkspaceApplicationLaunch(application)
                    } else {
                        if application.bundleIdentifier == nil {
                            self.pendingApplicationLaunchAssessments.removeValue(
                                forKey: "pid:\(application.processIdentifier)"
                            )
                        }
                        let identifier = application.bundleIdentifier
                        self.handleLifecycleEvent(
                            identifier?.lowercased() == "com.apple.menubaragent"
                                ? .menuBarAgentChanged
                                : .applicationTerminated(identifier)
                        )
                    }
                }
            }
            lifecycleObservers.append((workspace, token))
        }
    }

    private func handleDisplayConfigurationNotification() {
        let current = currentDisplayConfiguration()
        guard DisplayConfigurationPolicy.invalidates(
            previous: displayConfiguration,
            current: current
        ) else {
            sessionDiagnostic("display-notification ignored=unchanged-signature")
            return
        }
        displayConfiguration = current
        handleLifecycleEvent(.displayChanged)
    }

    private func currentDisplayConfiguration() -> DisplayConfigurationSignature {
        DisplayConfigurationSignature(displays: NSScreen.screens.map { screen in
            let identifier = (screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? NSNumber)?.uint64Value
            return DisplayConfigurationRecord(
                displayIdentifier: identifier,
                frameX: screen.frame.origin.x,
                frameY: screen.frame.origin.y,
                frameWidth: screen.frame.width,
                frameHeight: screen.frame.height,
                backingScaleFactor: screen.backingScaleFactor
            )
        })
    }

    private func handleWorkspaceApplicationLaunch(
        _ application: NSRunningApplication
    ) {
        let identifier = application.bundleIdentifier
        #if DEBUG
        if activeOrderingPlan != nil {
            handleLifecycleEvent(.applicationLaunched(identifier))
            return
        }
        discardOrderingPreview()
        #endif
        if identifier?.lowercased() == "com.apple.menubaragent" {
            handleLifecycleEvent(.menuBarAgentChanged)
            return
        }

        guard requiresApplicationLaunchAssessment(application),
              !isReadOnlyValidation, !interactionGate.isTerminating,
              activeBaselinePlan != nil || interactionGate.isBusy || isRefreshing else { return }
        let key = identifier.map { "bundle:\($0.lowercased())" }
            ?? "pid:\(application.processIdentifier)"
        guard pendingApplicationLaunchAssessments.count < 256
                || pendingApplicationLaunchAssessments[key] != nil else {
            handleLifecycleEvent(.applicationLaunched(identifier))
            return
        }

        pendingApplicationLaunchAssessments[key] =
            RunningApplicationDescriptor(
                processIdentifier: application.processIdentifier,
                bundleIdentifier: identifier
            )
        scheduleApplicationLaunchAssessment()
    }

    private func scheduleApplicationLaunchAssessment() {
        guard applicationLaunchAssessmentTask == nil,
              !interactionGate.isBusy, !interactionGate.isTerminating, !isRefreshing,
              connectionInvalidationTask == nil, activeBaselinePlan != nil,
              !pendingApplicationLaunchAssessments.isEmpty else { return }
        let generation = lifecycleGeneration
        applicationLaunchAssessmentTask = Task { @MainActor [weak self] in
            // Fixed coalescing window: later arrivals do not postpone this batch.
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            await self?.assessPendingApplicationLaunches(generation: generation)
        }
    }

    private func assessPendingApplicationLaunches(
        generation: UInt64
    ) async {
        applicationLaunchAssessmentTask = nil
        guard !interactionGate.isBusy, !isRefreshing else { return }
        let pending = pendingApplicationLaunchAssessments
        pendingApplicationLaunchAssessments.removeAll()
        guard generation == lifecycleGeneration,
              activeBaselinePlan != nil, !interactionGate.isTerminating else { return }
        guard AccessibilityAuthorization.isTrusted else {
            handleLifecycleEvent(.permissionLost)
            return
        }

        // One cheap Workspace snapshot, not an AX/icon inventory. Coalesce by
        // bundle so multi-process apps cannot fill the queue with duplicate PIDs.
        let applications = NSWorkspace.shared.runningApplications.filter { !$0.isTerminated }
        let running = pending.values.compactMap { descriptor -> RunningApplicationDescriptor? in
            let current = applications.first { application in
                if let identifier = descriptor.bundleIdentifier {
                    return application.bundleIdentifier?.lowercased() == identifier.lowercased()
                }
                return application.processIdentifier == descriptor.processIdentifier
                    && application.bundleIdentifier == nil
            }
            guard let current, requiresApplicationLaunchAssessment(current) else { return nil }
            return RunningApplicationDescriptor(
                processIdentifier: current.processIdentifier, bundleIdentifier: current.bundleIdentifier
            )
        }
        guard !running.isEmpty else {
            scheduleApplicationLaunchAssessment()
            return
        }

        guard beginManagementInteraction() else {
            for descriptor in running {
                let key = descriptor.bundleIdentifier.map { "bundle:\($0.lowercased())" }
                    ?? "pid:\(descriptor.processIdentifier)"
                pendingApplicationLaunchAssessments[key] = descriptor
            }
            return
        }
        ordinaryReveal.suspendForPassThroughUpdate()
        managementInteractionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { finishManagementInteraction() }
            let started = ContinuousClock.now
            do {
                // Valid bundle identity is enough for a more permissive allowance.
                // Only unidentified processes retain the bounded AX fallback.
                let unidentified = running.filter { $0.bundleIdentifier == nil }
                if !unidentified.isEmpty {
                    try await verifyUnidentifiedLaunchesHaveNoExtras(unidentified)
                }
                guard generation == lifecycleGeneration,
                      !interactionGate.isTerminating,
                      let baseline = activeBaselinePlan, let reveal = activeRevealPlan else { return }
                guard let expansion = try PassThroughExpansion.prepare(
                    baseline: baseline, reveal: reveal,
                    acceptedBundleIdentifiers: Set(editorModel?.acceptedPolicyScope.approvedBundleIdentifiers ?? []),
                    launchedBundleIdentifiers: Set(running.compactMap(\.bundleIdentifier))
                ) else { return }
                guard admittedPassThroughBundleIdentifiers.count
                    + expansion.addedBundleIdentifiers.count <= 4_096 else {
                    throw PolicyInterfaceWriteError.applyPreflightUnavailable(
                        "The active session's pass-through identity capacity was exceeded."
                    )
                }
                let currentState = await managementLoop.state
                let expected: RevealAllowlistPlan
                let replacement: RevealAllowlistPlan
                switch currentState {
                case .active:
                    expected = baseline; replacement = expansion.baseline
                case .ordinaryRevealSession:
                    expected = reveal; replacement = expansion.reveal
                default:
                    return // Never resume a stopped writer from a launch event.
                }
                guard generation == lifecycleGeneration, !interactionGate.isTerminating else { return }
                try await managementLoop.expandPassThrough(
                    from: expected, to: replacement,
                    addedBundleIdentifiers: Set(expansion.addedBundleIdentifiers)
                )
                guard generation == lifecycleGeneration, !interactionGate.isTerminating else { return }
                activeBaselinePlan = expansion.baseline
                activeRevealPlan = expansion.reveal
                admittedPassThroughBundleIdentifiers.formUnion(expansion.addedBundleIdentifiers)
                observedRunningBundleIdentifiers.formUnion(expansion.addedBundleIdentifiers)
                sessionDiagnostic("pass-through added=\(expansion.addedBundleIdentifiers.count) writes=1 retries=0 duration=\(started.duration(to: .now))")
                // Preserve the existing reveal session and timeout task verbatim.
                presentManagementState(
                    await managementLoop.state,
                    persistedManagementEnabled: editorModel?.acceptedPolicy.managementEnabled == true
                )
            } catch {
                guard generation == lifecycleGeneration, !interactionGate.isTerminating else { return }
                await managementLoop.failClosed("A new application's visibility could not be verified. Choose Resume to recheck.")
                activeBaselinePlan = nil
                activeRevealPlan = nil
                pendingApplicationLaunchAssessments.removeAll()
                ordinaryRevealTimeoutTask?.cancel()
                ordinaryRevealTimeoutTask = nil
                presentManagementState(
                    await managementLoop.state,
                    persistedManagementEnabled: editorModel?.acceptedPolicy.managementEnabled == true
                )
                sessionDiagnostic("pass-through failed retries=0 error=\(error)")
            }
        }
    }

    private func verifyUnidentifiedLaunchesHaveNoExtras(
        _ running: [RunningApplicationDescriptor]
    ) async throws {
        let report = await inventory.capture(
            applications: running,
            accessibilityTrusted: true
        )
        let ownership = MenuBarOwnershipSnapshotBuilder.make(from: report)
        let captureComplete = !report.elementLimitReached
            && !report.timeLimitReached
            && ownership.issues.isEmpty

        for descriptor in running {
            let discovery = report.applicationDiscoveries.first {
                $0.processIdentifier == descriptor.processIdentifier
            }
            let itemCount = ownership.observations
                .filter { $0.processIdentifier == descriptor.processIdentifier }
                .reduce(0) { $0 + $1.menuBarItemCount }
            let assessment = ManagementLifecyclePolicy.assessApplicationLaunch(
                discovery: discovery,
                attributableMenuBarItemCount: itemCount,
                captureComplete: captureComplete
            )
            sessionDiagnostic(
                "application-launch pid=\(descriptor.processIdentifier)"
                    + " menuBarAssessment=\(assessment) items=\(itemCount)"
            )
            if ManagementLifecyclePolicy.invalidates(
                applicationLaunchAssessment: assessment
            ) {
                throw PolicyInterfaceWriteError.applyPreflightUnavailable(
                    "An unidentified process has menu-bar items or unavailable ownership."
                )
            }
        }
    }

    private func handleLifecycleEvent(_ event: ManagementLifecycleEvent) {
        guard !interactionGate.isTerminating else { return }
        let managed = Set(editorModel?.acceptedPolicyScope.approvedBundleIdentifiers ?? [])
        let allowed = activeBaselinePlan.map { Set($0.allowedBundleIdentifiers) }
            ?? observedRunningBundleIdentifiers
        let visibilityInvalidated = ManagementLifecyclePolicy.invalidates(
            event, managedBundleIdentifiers: managed, allowedBundleIdentifiers: allowed,
            blennyBundleIdentifier: Bundle.main.bundleIdentifier ?? "xyz.fi5h.blenny"
        )
        #if DEBUG
        discardOrderingPreview()
        let orderingInvalidated = activeOrderingPlan != nil
        #else
        let orderingInvalidated = false
        #endif
        guard visibilityInvalidated || orderingInvalidated else { return }
        applicationLaunchAssessmentTask?.cancel()
        applicationLaunchAssessmentTask = nil
        pendingApplicationLaunchAssessments.removeAll()
        lifecycleGeneration &+= 1
        if event == .menuBarAgentChanged { lifecycleRestartRequired = true }
        if event == .menuBarAgentChanged || event == .permissionLost {
            updateNativeOverflowObservation()
        }
        // Inactive notification handling is read-only. It never retries startup.
        guard activeBaselinePlan != nil || interactionGate.isBusy || lifecycleRestartRequired || orderingInvalidated else { return }
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
            #if DEBUG
            activeOrderingPlan = nil
            await updateOrderingRecoveryPresentation()
            #endif
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
        let action = accessibilityOnboarding.nextAction(
            isTrusted: AccessibilityAuthorization.isTrusted
        )
        switch action {
        case .alreadyGranted:
            refresh()
        case .requestSystemPrompt:
            _ = AccessibilityAuthorization.requestSystemPrompt()
            editorWindowController.setStatus(
                "Turn on Blenny in Device Control and Data Access, then return. Blenny will refresh automatically.",
                isError: false
            )
        case .openSystemSettings:
            let opened = openAccessibilitySettings()
            editorWindowController.setStatus(
                opened
                    ? "Turn on Blenny, then return. Blenny will refresh automatically."
                    : "System Settings could not be opened. Open Privacy & Security, then Device Control and Data Access.",
                isError: !opened
            )
        }
        updatePermissionPresentation()
        showEditor()
        if accessibilityGrantRefresh.pending { refresh() }
    }

    @discardableResult
    private func openAccessibilitySettings() -> Bool {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return false }
        return NSWorkspace.shared.open(url)
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
        accessibilityGrantRefresh.observe(trusted: trusted)
        lastKnownAccessibilityTrust = trusted
        editorWindowController.setAccessibilityTrusted(
            trusted,
            hasRequestedSystemPrompt: accessibilityOnboarding.hasRequestedSystemPromptThisLaunch
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

    private func showFishPlacementGuide() {
        let snapshot = ordinaryReveal.observation
        guard BlennyFishPlacement.guideAvailable(for: snapshot) else {
            editorWindowController.setStatus(
                "The system overflow arrow is not currently available. Refresh after it appears.",
                isError: true
            )
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Move Blenny in the Menu Bar"
        alert.informativeText = "Hold Command and drag the fish to your preferred position. macOS controls the final placement; staying beside the system arrow is not guaranteed."
        alert.addButton(withTitle: "Done")
        alert.runModal()
    }

    #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    private func developmentCoordinator(forRecovery: Bool = false) async throws -> CoordinatedPolicyWriter {
        guard !isReadOnlyValidation else { throw PolicyInterfaceWriteError.installedDryRunRequired }
        if forRecovery, let writer = await managementLoop.existingWriterForRecovery() {
            guard let coordinated = writer as? CoordinatedPolicyWriter else {
                throw ManagementLoopError.managementIsNotActive
            }
            return coordinated
        }
        let generation = await managementLoop.generationSnapshot()
        let writer = try await managementLoop.writerForReviewedActivation(expectedGeneration: generation)
        guard let coordinated = writer as? CoordinatedPolicyWriter else {
            throw ManagementLoopError.managementIsNotActive
        }
        return coordinated
    }

    private func refreshSharedSystemItemTrialPresentation() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            for target in SharedSystemItemTrialTarget.allCases {
                do {
                    if await sharedSystemItemTrialWriter.hasRecoveryReceipt(for: target) {
                        editorWindowController.setSharedSystemItemTrial(
                            target, presentation: .recoveryRequired
                        )
                    } else {
                        let snapshot = try await sharedSystemItemTrialWriter.snapshot(target)
                        editorWindowController.setSharedSystemItemTrial(
                            target,
                            presentation: snapshot.effectiveVisible ? .ready : .hidden
                        )
                    }
                } catch {
                    editorWindowController.setSharedSystemItemTrial(
                        target, presentation: .unavailable(String(describing: error))
                    )
                }
            }
        }
    }

    private func hideSharedSystemItem(_ target: SharedSystemItemTrialTarget) {
        guard !isReadOnlyValidation, beginManagementInteraction() else { return }
        editorWindowController.setSharedSystemItemTrial(target, presentation: .busy)
        editorWindowController.setStatus(
            "Applying one Debug-only \(target.displayName) visibility change…",
            isError: false
        )
        managementInteractionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { finishManagementInteraction() }
            do {
                let writer = try await developmentCoordinator()
                let receipt = try await writer.hideManualSystemItem(target)
                editorWindowController.setSharedSystemItemTrial(target, presentation: .recoveryRequired)
                editorWindowController.setStatus(
                    "\(target.displayName) is hidden. Use Restore before changing its macOS setting elsewhere. Receipt \(try receipt.fingerprint.prefix(12)).",
                    isError: false
                )
            } catch {
                let presentation: SharedSystemItemTrialPresentation
                if await sharedSystemItemTrialWriter.hasRecoveryReceipt(for: target) {
                    presentation = .recoveryRequired
                } else if let snapshot = try? await sharedSystemItemTrialWriter.snapshot(target) {
                    presentation = snapshot.effectiveVisible ? .ready : .hidden
                } else {
                    presentation = .unavailable(String(describing: error))
                }
                editorWindowController.setSharedSystemItemTrial(
                    target, presentation: presentation
                )
                editorWindowController.setStatus(
                    "\(target.displayName) hide did not verify. Its safe state was re-read after the bounded rollback: \(error)",
                    isError: true
                )
            }
            #if DEBUG
            discardOrderingPreview()
            await updateOrderingRecoveryPresentation()
            if !orderingRecoveryKnown { activeOrderingPlan = nil }
            #endif
        }
    }

    private func restoreSharedSystemItem(_ target: SharedSystemItemTrialTarget) {
        guard !isReadOnlyValidation, beginManagementInteraction() else { return }
        editorWindowController.setSharedSystemItemTrial(target, presentation: .busy)
        editorWindowController.setStatus(
            "Restoring the exact saved \(target.displayName) state…",
            isError: false
        )
        managementInteractionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { finishManagementInteraction() }
            do {
                let writer = try await developmentCoordinator(forRecovery: true)
                try await writer.restoreManualSystemItem(target)
                editorWindowController.setSharedSystemItemTrial(target, presentation: .ready)
                editorWindowController.setStatus(
                    "\(target.displayName) exact preference state was restored and verified once.",
                    isError: false
                )
            } catch {
                editorWindowController.setSharedSystemItemTrial(
                    target, presentation: .recoveryRequired
                )
                editorWindowController.setStatus(
                    "\(target.displayName) restore stopped without overwriting newer settings: \(error)",
                    isError: true
                )
            }
            #if DEBUG
            discardOrderingPreview()
            await updateOrderingRecoveryPresentation()
            if !orderingRecoveryKnown { activeOrderingPlan = nil }
            #endif
        }
    }
    #endif

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
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        let policyDirectoryName = "ManualSystemItemTrial"
        #else
        let policyDirectoryName = "PersistentPolicyPrototype"
        #endif
        let directory = applicationSupport
            .appendingPathComponent("Blenny", isDirectory: true)
            .appendingPathComponent(policyDirectoryName, isDirectory: true)
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
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        // Import intent read-only; no test action can write the production
        // policy or its recovery backup. The trial begins without an assertion.
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        )
        let sourceURL = applicationSupport
            .appendingPathComponent("Blenny/PersistentPolicyPrototype/bundle-policies.json")
        if FileManager.default.fileExists(atPath: sourceURL.path) {
            let original = try JSONDecoder().decode(
                PersistentBundlePolicyDocument.self, from: Data(contentsOf: sourceURL)
            )
            return try original.validated(forBlennyBundleIdentifier: blennyBundleIdentifier)
                .settingManagementEnabled(false)
        }
        #endif
        return try PersistentBundlePolicyDocument(
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

    private func requiresApplicationLaunchAssessment(_ application: NSRunningApplication) -> Bool {
        ManagementLifecyclePolicy.requiresLaunchAssessment(
            bundleIdentifier: application.bundleIdentifier,
            acceptedBundleIdentifiers: Set(editorModel?.acceptedPolicyScope.approvedBundleIdentifiers ?? []),
            allowedBundleIdentifiers: Set(activeBaselinePlan?.allowedBundleIdentifiers ?? []),
            blennyBundleIdentifier: Bundle.main.bundleIdentifier ?? "xyz.fi5h.blenny"
        )
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

#if DEBUG
extension AppDelegate {
    private func orderingRuntimeContext() -> MacOS27MenuBarOrderingContext {
        let policy = editorModel?.acceptedPolicy
        let allowed = Set(NSWorkspace.shared.runningApplications.compactMap { app -> String? in
            guard let bundle = app.bundleIdentifier, let policy else { return nil }
            let assigned = policy.policies.first {
                BundlePolicyIdentity.canonicalKey(for: $0.bundleIdentifier)
                    == BundlePolicyIdentity.canonicalKey(for: bundle)
            }?.policy ?? .visible
            return OrderingPolicyScope.allows(intent: assigned, managementEnabled: policy.managementEnabled)
                ? bundle : nil
        })
        return MacOS27MenuBarOrderingContext(
            policyFingerprint: policy?.policyFingerprint ?? "policy-unavailable",
            orderingAllowedBundleIdentifiers: allowed,
            lifecycleGeneration: Int(truncatingIfNeeded: lifecycleGeneration)
        )
    }

    private func configureOrderingInterface() {
        let presentation = editorWindowController.orderingPresentation
        presentation.onRefresh = { [weak self] in self?.refresh() }
        presentation.onPreview = { [weak self] bundles in self?.previewOrdering(bundles) }
        presentation.onReorder = { [weak self] bundles in self?.previewBoardOrdering(bundles) }
        presentation.onDraftChanged = { [weak self] model in self?.draftDidChange(model) }
        presentation.onPreviewConfiguration = { [weak self] request in
            self?.previewBoardConfiguration(request)
        }
        presentation.onChooseLayoutFile = { [weak self] in
            self?.requestMenuBarLayoutAccess()
        }
        presentation.onApply = { [weak self] fingerprint in self?.applyOrdering(fingerprint) }
        presentation.onRestore = { [weak self] in self?.restoreOrdering() }
        presentation.onDiscard = { [weak self] in
            guard let self else { return }
            if preparedBoardRequest != nil || editorWindowController.hasOrderingLayoutChanges,
               let discarded = editorWindowController.discardConfigurationDraft() {
                draftDidChange(discarded)
            }
            discardOrderingPreview()
        }
        presentation.message = "Reading the current menu-bar order with the application inventory…"
        Task { [weak self] in await self?.updateOrderingRecoveryPresentation() }
    }

    private func discardOrderingPreview() {
        preparedOrderingPlan = nil
        preparedBoardPolicy = nil
        preparedBoardRequest = nil
        preparedBoardFingerprint = nil
        preparedUnsortedNames = []
        preparedUndoRebaseToken = nil
        let presentation = editorWindowController.orderingPresentation
        presentation.preview = nil
        presentation.requiresUndoReplacement = false
        presentation.canApply = false
    }

    private func restoreSavedMenuBarLayoutAccess() {
        do {
            if try menuBarLayoutAccess.restoreSavedAccess() {
                sessionDiagnostic("layout-access restored exact-file bookmark")
            }
        } catch {
            sessionDiagnostic("layout-access restore-failure \(error.localizedDescription)")
        }
    }

    private func requestMenuBarLayoutAccess() {
        let panel = NSOpenPanel()
        panel.title = "Choose the Menu Bar Layout File"
        panel.message = "Select the menu bar layout file so Blenny can apply and undo the order you choose."
        panel.prompt = "Grant Access"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.directoryURL = menuBarLayoutAccess.expectedFileURL.deletingLastPathComponent()
        panel.nameFieldStringValue = menuBarLayoutAccess.expectedFileURL.lastPathComponent
        panel.begin { [weak self] response in
            guard let self, response == .OK, let selectedURL = panel.url else { return }
            do {
                try menuBarLayoutAccess.grant(selectedURL: selectedURL)
                let presentation = editorWindowController.orderingPresentation
                presentation.needsDataAccess = false
                presentation.isError = false
                presentation.technicalDetail = nil
                presentation.message = "Access granted. Reading the current menu bar order…"
                Task { [weak self] in await self?.readOrderingForBoard() }
            } catch {
                let presentation = editorWindowController.orderingPresentation
                presentation.needsDataAccess = true
                presentation.isError = true
                presentation.message = "Choose the menu bar layout file to enable sorting and Undo."
                presentation.technicalDetail = error.localizedDescription
            }
        }
    }

    private func orderingCoordinator(forRecovery: Bool = false) async throws -> CoordinatedPolicyWriter {
        try await developmentCoordinator(forRecovery: forRecovery)
    }

    private func beginOrderingInteraction(message: String) -> Bool {
        guard editorModel != nil,
              beginManagementInteraction() else {
            editorWindowController.orderingPresentation.message =
                "Finish the current operation before reviewing the layout."
            return false
        }
        ordinaryReveal.suspend()
        let presentation = editorWindowController.orderingPresentation
        presentation.isBusy = true
        presentation.canRefresh = false
        presentation.canApply = false
        presentation.isError = false
        presentation.technicalDetail = nil
        presentation.message = message
        editorWindowController.setStatus(message, isError: false)
        return true
    }

    private func finishOrderingInteraction() {
        let presentation = editorWindowController.orderingPresentation
        presentation.isBusy = false
        presentation.canRefresh = !interactionGate.isTerminating
        presentation.canApply = (preparedOrderingPlan != nil || preparedBoardPolicy != nil) && !orderingRecoveryKnown
            && !isReadOnlyValidation && !interactionGate.isTerminating
        finishManagementInteraction()
    }

    private func refreshOrdering() {
        guard beginOrderingInteraction(message: "Reading current ordering identities…") else { return }
        discardOrderingPreview()
        managementInteractionTask = Task { [weak self] in
            guard let self else { return }
            defer { finishOrderingInteraction() }
            await readOrderingForBoard()
        }
    }

    private func captureBoundaryEvidence() {
        guard !boundaryCaptureInProgress, !isReadOnlyValidation,
              !interactionGate.isBusy, !interactionGate.isTerminating, !isRefreshing,
              connectionInvalidationTask == nil, let model = editorModel,
              AccessibilityAuthorization.isTrusted else {
            editorWindowController.setStatus("Snapshot unavailable. Finish the current operation and check Accessibility.", isError: true)
            return
        }
        boundaryCaptureInProgress = true
        statusItemController.debugSetBoundaryCaptureBusy(true)
        let policy = model.acceptedPolicy
        let generation = lifecycleGeneration
        let ownBefore = statusItemController.debugOwnControls
        let startedAt = Date()
        let descriptors = runningApplicationDescriptors()
        boundaryCaptureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                boundaryCaptureInProgress = false
                boundaryCaptureTask = nil
                statusItemController.debugSetBoundaryCaptureBusy(false)
            }
            let stateBefore = String(describing: await managementLoop.state)
            do {
                // This does not enter the management gate, suspend a reveal,
                // refresh the Board, create a coordinator, or touch recovery.
                let report = await inventory.capture(applications: descriptors, accessibilityTrusted: true)
                let snapshot = try await orderingBackend.capture()
                guard !Task.isCancelled, !interactionGate.isTerminating else { return }
                let ownAfter = statusItemController.debugOwnControls
                let stateAfter = String(describing: await managementLoop.state)
                let unchanged = generation == lifecycleGeneration
                    && policy == editorModel?.acceptedPolicy
                    && ownBefore == ownAfter && stateBefore == stateAfter
                    && !interactionGate.isBusy && !isRefreshing
                guard let executable = Bundle.main.executableURL else {
                    throw OrderingError.invalidSnapshot("missing executable identity")
                }
                let digest = SHA256.hash(data: try Data(contentsOf: executable))
                    .map { String(format: "%02x", $0) }.joined()
                let evidence = DebugBoundaryEvidence(
                    id: UUID(), startedAt: startedAt, finishedAt: Date(),
                    appVersion: BlennyApplicationVersion.display,
                    appPath: Bundle.main.bundleURL.path, executableSHA256: digest,
                    processIdentifier: ProcessInfo.processInfo.processIdentifier,
                    stateBefore: stateBefore, stateAfter: stateAfter, contextUnchanged: unchanged,
                    ownControlsBefore: ownBefore, ownControlsAfter: ownAfter,
                    ownKeyEvidence: OwnControlKeyEvidence(
                        tableKeys: Set(try snapshot.table().keys),
                        bundleIdentifier: Bundle.main.bundleIdentifier ?? "unknown",
                        autosaveNames: ownAfter.compactMap(\.autosaveName)),
                    clickCheck: statusItemController.debugClickCheck,
                    acceptedPolicy: policy, inventory: report, ordering: snapshot,
                    singleItemCandidates: try OrderingIdentityResolver.resolve(snapshot: snapshot),
                    notes: [
                        "Read-only evidence, not a placement plan or restoration receipt.",
                        "Own frames use AppKit screen coordinates; AX inventory frames use Accessibility coordinates. Do not compare Y without conversion.",
                        "Inventory and preference captures are sequential, not an atomic screen snapshot.",
                        "Stored keys and configuration eligibility do not establish a live per-item identity; retain unresolved and historical keys separately.",
                        "Own key evidence matches canonical bundle keys to instantiated autosave names; alternative namespaces still require verification.",
                        "localContentVisible is AppKit content state, not proof of physical screen visibility.",
                        "No complete physical partition or write eligibility is claimed by this export.",
                        unchanged ? "Context unchanged at sampled endpoints." : "Context changed during capture; do not use for boundary conclusions."
                    ])
                let directory = boundaryEvidenceDirectory
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700])
                guard directory.resolvingSymlinksInPath().pathComponents.contains("LocalData") else {
                    throw OrderingError.invalidSnapshot("evidence destination must remain inside LocalData")
                }
                let url = directory.appendingPathComponent("boundary-\(evidence.id.uuidString).json")
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(evidence)
                guard data.count <= 16 * 1_024 * 1_024 else { throw OrderingError.propertyListLimitExceeded }
                try data.write(to: url, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
                editorWindowController.setStatus(unchanged
                    ? "Boundary snapshot saved. File path copied."
                    : "Snapshot saved, but state changed during capture. File path copied.", isError: !unchanged)
            } catch {
                editorWindowController.setStatus("Could not save boundary snapshot: \(error.localizedDescription)", isError: true)
            }
        }
    }

    #if DEBUG
    private func positionRevealArrow(restoring: Bool) {
        guard !boundaryCaptureInProgress, !isReadOnlyValidation, !isRefreshing,
              !interactionGate.isTerminating, AccessibilityAuthorization.isTrusted,
              let model = editorModel,
              (restoring || !editorWindowController.hasDraftChanges),
              beginOrderingInteraction(message: restoring ? "Restoring control positions…" : "Preparing control positions…") else { return }
        let policy = model.acceptedPolicy
        managementInteractionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { finishOrderingInteraction() }
            do {
                let coordinator = try await orderingCoordinator(forRecovery: restoring)
                if restoring {
                    let result = try await coordinator.restoreFallbackPosition()
                    editorWindowController.setStatus(result == nil ? "No control placement to undo." : "Previous control positions restored.", isError: false)
                    return
                }
                let previousReceipt = try await fallbackRecoveryStore.load()
                guard previousReceipt?.isPendingRestoration != true else {
                    throw OrderingTransactionError.recoveryRequired
                }
                let snapshot = try await orderingBackend.capture()
                let identity = try await orderingBackend.fallbackIdentity()
                let candidate = try FallbackBoundaryCandidate.make(snapshot: snapshot, policy: policy, includeFish: true)
                let alert = NSAlert()
                alert.messageText = "Position Blenny’s controls?"
                alert.informativeText = "Place the double arrow and fish between Revealable and Visible items, with the arrow on the left. Other apps’ saved positions stay unchanged.\n\nThis placement stays after Stop or Quit and follows changes you apply in Organize. Undo Control Placement restores the previous positions and turns off automatic adjustment."
                if let previousReceipt, !previousReceipt.delta.canBeReplaced(by: candidate.delta) {
                    alert.informativeText += "\n\nThe saved control positions have changed. This replaces the old control Undo record with the current positions. The old record is archived; Undo Control Placement will return to the positions before this operation."
                }
                alert.addButton(withTitle: "Position Controls")
                alert.addButton(withTitle: "Cancel")
                guard alert.runModal() == .alertFirstButtonReturn else { return }
                _ = try await coordinator.applyFallbackPosition(candidate.delta,
                    baseline: snapshot, identity: identity, persistsAfterQuit: true,
                    reviewedPreviousReceipt: previousReceipt)
                editorWindowController.setStatus("Control positions saved.", isError: false)
            } catch FallbackPositionDelta.Failure.unchangedPosition {
                editorWindowController.setStatus("Blenny’s controls are already positioned.", isError: false)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Couldn’t update Blenny’s controls"
                alert.informativeText = error.localizedDescription
                    + "\n\nIf restoration is needed, choose Undo Control Placement."
                alert.addButton(withTitle: "OK")
                alert.runModal()
                editorWindowController.setStatus("Control positions could not be updated.", isError: true)
            }
        }
    }
    #endif

    private func updateAcceptedControlBoundary() async -> String? {
        guard let policy = editorModel?.acceptedPolicy, !interactionGate.isTerminating else { return nil }
        do {
            guard try await fallbackRecoveryStore.load() != nil else { return nil }
            // Persistent fallback placement is dormant while the native
            // overflow control is usable (or its exact AppKit identity is not
            // currently available). An unrelated Apply or Undo must leave that
            // older placement unchanged instead of reporting the completed
            // primary operation as a failure.
            #if DEBUG
            guard statusItemController.debugFallbackNativeIdentity != nil else { return nil }
            #endif
            let coordinator = try await orderingCoordinator()
            _ = try await coordinator.updateAcceptedControlBoundary(policy: policy)
            return nil
        } catch {
            return "Blenny’s controls could not be positioned: \(error.localizedDescription) Use Position Blenny Controls to review the placement."
        }
    }

    private func readOrderingForBoard() async {
        discardOrderingPreview()
        do {
            let snapshot = try await orderingBackend.capture()
            guard !interactionGate.isTerminating else { return }
            guard presentOrderingCandidates(snapshot) else {
                await updateOrderingRecoveryPresentation()
                return
            }
            editorWindowController.orderingPresentation.finishSuccessfulRead()
        } catch {
            lastOrderingSnapshot = nil
            editorWindowController.orderingPresentation.hasObservation = false
            presentOrderingError(error)
        }
        await updateOrderingRecoveryPresentation()
    }

    private func presentBoardGeometry(report: DiagnosticReport, candidates: [PolicyCandidate]) {
        // Public AX placement can still be displayed when private preferences
        // are unavailable. This observation never grants ordering eligibility.
        let records = Dictionary(grouping: report.items.filter {
            $0.source == .applicationExtrasMenuBar && $0.classification == .manageableCandidate
                && $0.role == "AXMenuBarItem" && $0.subrole == "AXMenuExtra"
        }, by: { $0.ownerBundleIdentifier ?? "" })
        let singleFrames = records.compactMapValues { owned -> RectSnapshot? in
            owned.count == 1 ? owned.first?.frame : nil
        }
        let ambiguousOwners = OrderingObservedGeometry.ambiguousOwners(frames: singleFrames)
        let icons = WorkspacePolicyIconResolver()
        editorWindowController.orderingPresentation.rows = candidates.map { candidate in
            let icon = icons.applicationIcon(bundleIdentifier: candidate.bundleIdentifier)
            let owned = records[candidate.bundleIdentifier] ?? []
            let frame = owned.count == 1 && candidate.menuBarItemCount == 1
                && NSScreen.screens.count == 1
                && !ambiguousOwners.contains(candidate.bundleIdentifier) ? owned.first?.frame : nil
            let x = frame.flatMap { frame -> Double? in
                guard frame.x.isFinite, frame.y.isFinite, frame.width.isFinite,
                      frame.height.isFinite, frame.width > 0, frame.height > 0,
                      frame.x >= 0, frame.x + frame.width <= (NSScreen.screens.first?.frame.width ?? 0)
                else { return nil }
                return frame.x
            }
            return DebugOrderingRow(
                bundleIdentifier: candidate.bundleIdentifier, name: icon.displayName, icon: icon.image,
                reason: ambiguousOwners.contains(candidate.bundleIdentifier)
                    ? "The current menu-bar observation does not expose a separate position for this application."
                    : "Ordering identity and preferences are not verified.",
                isEligible: false, observedX: x
            )
        }
        editorWindowController.orderingPresentation.hasObservation = false
    }

    private func previewBoardConfiguration(_ request: DebugOrderingConfigurationRequest, applyWhenReady: Bool = false) {
        guard !orderingRecoveryKnown,
              let model = editorModel,
              request.sourceCandidateGeneration == editorWindowController.candidateGeneration,
              beginOrderingInteraction(message: "Checking changes…") else { return }
        discardOrderingPreview()
        let generation = lifecycleGeneration
        managementInteractionTask = Task { [weak self] in
            guard let self else { return }
            var handoffToApply = false
            defer { if !handoffToApply { finishOrderingInteraction() } }
            do {
                let current = try await orderingBackend.capture()
                guard generation == lifecycleGeneration,
                      !interactionGate.isTerminating,
                      request == editorWindowController.currentOrderingConfigurationRequest,
                      model.acceptedPolicy.policyFingerprint == current.policyFingerprint,
                      Int(truncatingIfNeeded: generation) == current.lifecycleGeneration else {
                    throw OrderingError.staleSnapshot("the area draft or management context changed while preparing the review")
                }
                // This creates a new review from current configuration. The
                // Board supplies desired owner order, not stale numeric inputs.
                // Execution still checks the resulting plan against a fresh
                // snapshot before the serial writer can change anything.
                let candidates = try OrderingConfigurationSubjectIdentityResolver.resolve(snapshot: current)
                let bySubject = Dictionary(uniqueKeysWithValues: candidates.map { ($0.subjectID, $0) })
                let allEligible = request.orderedSubjects.filter { subject in
                    guard bySubject[subject]?.eligible == true else { return false }
                    if case let .systemItem(item) = subject {
                        return item.isOrderingOffered
                    }
                    return true
                }
                let allEligibleSet = Set(allEligible)
                let unavailable = request.unavailableOrderChanges(
                    eligibleSubjects: allEligibleSet, blenny: model.blennyBundleIdentifier
                )
                guard unavailable.isEmpty else {
                    let names = unavailable.map { bySubject[$0]?.displayName ?? $0.boardID }
                    throw OrderingError.unavailableOrderChanges(names)
                }
                let required = Set(request.subjectsRequiringConfiguration)
                let selected = allEligible.filter { required.contains($0) }
                let selectedSet = Set(selected)
                let omitted = request.orderedSubjects.filter { !selectedSet.contains($0) }
                let plan: OrderingPlan? = try OrderingPlan.makeConfigurationOrdering(
                    snapshot: current, orderedSubjects: selected
                )
                var policy: PreparedPolicyEdit?
                if model.hasDraftChanges {
                    let core = try await makeCore(scope: model.validationScope, permitsReviewedActivation: true)
                    let policyPreview = try await core.preview(
                        draft: model.draft, candidates: model.candidateInventory,
                        observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                        candidateGeneration: editorWindowController.candidateGeneration,
                        runtimeContractFingerprint: runtimeContractFingerprint
                    )
                    guard let prepared = policyPreview.1 else {
                        throw PolicyInterfaceWriteError.applyPreflightUnavailable(policyPreview.0.validationFailureSummary)
                    }
                    policy = prepared
                }
                guard editorModel?.draft == model.draft,
                      request == editorWindowController.currentOrderingConfigurationRequest,
                      generation == lifecycleGeneration else {
                    throw PolicyEditingCoreError.staleReviewedPlan
                }
                guard plan != nil || policy != nil else {
                    throw OrderingError.invalidSelection
                }
                let undoRebaseReview: OrderingUndoLedgerRebaseReview?
                if plan != nil, let receipt = try await orderingRecoveryStore.load() {
                    undoRebaseReview = try receipt.undoLedgerRebaseReview(in: current)
                } else {
                    undoRebaseReview = nil
                }
                let fingerprint = try OrderingValue.dictionary([
                    "ordering": .string(plan?.fingerprint ?? "no-addressable-ordering-keys"),
                    "policy": .string(policy?.newPolicy.policyFingerprint ?? model.acceptedPolicy.policyFingerprint),
                    "layout": .string(request.sourceLayoutGeneration.uuidString),
                    "undoRebase": .string(undoRebaseReview?.token ?? "retain-existing-undo")
                ]).canonicalFingerprint
                preparedOrderingPlan = plan
                preparedBoardPolicy = policy
                preparedBoardRequest = request
                preparedBoardFingerprint = fingerprint
                preparedUnsortedNames = omitted.filter {
                    request.originalPolicies[$0] != request.draftSubjectPolicies[$0]
                }.map { bySubject[$0]?.displayName ?? $0.boardID }
                preparedUndoRebaseToken = undoRebaseReview?.token
                let presentation = editorWindowController.orderingPresentation
                if let undoRebaseReview {
                    // Replacing stale Undo history still requires explicit consent.
                    presentation.requiresUndoReplacement = true
                    presentation.preview = DebugOrderingPreview(
                        fingerprint: fingerprint, title: "Replace previous Undo?",
                        detail: undoRebaseReview.userDescription, visibleScope: "",
                        targetBundleIdentifiers: [], beforeOrder: [], afterOrder: []
                    )
                    presentation.message = "The menu bar changed outside Blenny. Applying will replace the previous Undo history."
                    presentation.technicalDetail = undoRebaseReview.userDescription
                } else if applyWhenReady {
                    // Synchronous handoff: no user event can change the draft between gates.
                    handoffToApply = true
                    applyBoardConfiguration(fingerprint, continuingInteraction: true)
                }
            } catch { presentOrderingError(error) }
        }
    }

    private func previewBoardOrdering(_ orderedBundles: [String]) {
        guard !orderingRecoveryKnown, let previous = lastOrderingSnapshot,
              beginOrderingInteraction(message: "Reading and reviewing the requested menu-bar order…") else { return }
        discardOrderingPreview()
        let generation = lifecycleGeneration
        managementInteractionTask = Task { [weak self] in
            guard let self else { return }
            defer { finishOrderingInteraction() }
            do {
                guard try await orderingRecoveryStore.load() == nil else {
                    throw OrderingTransactionError.recoveryRequired
                }
                if case .ordinaryRevealSession = await managementLoop.state {
                    throw OrderingError.staleSnapshot("close the ordinary reveal session before ordering")
                }
                let current = try await orderingBackend.capture()
                // A drag refers to the board that was actually displayed. A new
                // snapshot may refresh values, but must not reinterpret the
                // gesture after another app, intent or selected order changed.
                let selected = Set(orderedBundles)
                func observedOrder(_ snapshot: OrderingSnapshot) -> [String] {
                    snapshot.observationsByPID.values.filter {
                        $0.process.bundleIdentifier.map(selected.contains) == true
                            && $0.axComplete && $0.itemFrames.count == 1
                    }.sorted { $0.itemFrames[0].x < $1.itemFrames[0].x }
                        .compactMap(\.process.bundleIdentifier)
                }
                guard previous.beforeProcesses == previous.afterProcesses,
                      current.beforeProcesses == current.afterProcesses,
                      previous.afterProcesses.sorted(by: { $0.pid < $1.pid })
                        == current.afterProcesses.sorted(by: { $0.pid < $1.pid }),
                      previous.policyFingerprint == current.policyFingerprint,
                      previous.displaySignature == current.displaySignature,
                      previous.lifecycleGeneration == current.lifecycleGeneration,
                      observedOrder(previous).count == selected.count,
                      observedOrder(previous) == observedOrder(current) else {
                    presentOrderingCandidates(current)
                    throw OrderingError.staleSnapshot("the displayed order or application inventory changed; review the refreshed board")
                }
                let plan = try OrderingPlan.makeReordering(
                    snapshot: current, orderedBundleIdentifiers: orderedBundles
                )
                guard generation == lifecycleGeneration, !interactionGate.isTerminating else {
                    throw OrderingTransactionError.contextInvalidated
                }
                preparedOrderingPlan = plan
                presentOrderingCandidates(current)
                let names = Dictionary(uniqueKeysWithValues: plan.targets.map {
                    ($0.bundleIdentifier, $0.displayName)
                })
                editorWindowController.orderingPresentation.preview = DebugOrderingPreview(
                    id: plan.id, fingerprint: plan.fingerprint,
                    title: "Review menu-bar order",
                    detail: "Existing preferred slots are reassigned once. Other applications and area assignments remain unchanged.",
                    visibleScope: "\(plan.targets.count) application owners · one display",
                    targetBundleIdentifiers: orderedBundles,
                    beforeOrder: observedOrder(current).compactMap { names[$0] },
                    afterOrder: orderedBundles.compactMap { names[$0] }
                )
                editorWindowController.orderingPresentation.message =
                    "Apply Order changes the real menu bar. Restore Order returns this trial to its original positions."
            } catch { presentOrderingError(error) }
        }
    }

    private func previewOrdering(_ bundles: [String]) {
        guard !orderingRecoveryKnown,
              beginOrderingInteraction(message: "Preparing the exact exchange and inverse…") else { return }
        discardOrderingPreview()
        let generation = lifecycleGeneration
        managementInteractionTask = Task { [weak self] in
            guard let self else { return }
            defer { finishOrderingInteraction() }
            do {
                if case .ordinaryRevealSession = await managementLoop.state {
                    throw OrderingError.staleSnapshot("close the ordinary reveal session before ordering")
                }
                guard try await orderingRecoveryStore.load() == nil else {
                    throw OrderingTransactionError.recoveryRequired
                }
                let snapshot = try await orderingBackend.capture()
                let plan = try OrderingPlan.make(snapshot: snapshot, bundleIdentifiers: bundles)
                guard generation == lifecycleGeneration, !interactionGate.isTerminating else {
                    throw OrderingTransactionError.contextInvalidated
                }
                preparedOrderingPlan = plan
                presentOrderingCandidates(snapshot)
                let before = plan.targets.sorted { $0.frame.x < $1.frame.x }.map(\.displayName)
                editorWindowController.orderingPresentation.preview = DebugOrderingPreview(
                    id: plan.id, fingerprint: plan.fingerprint,
                    title: "Exchange the selected positions",
                    detail: "Other icons may remain between these applications. Preferred positions do not fix absolute screen coordinates.",
                    visibleScope: "Two observable application bundles · one display · Debug session",
                    targetBundleIdentifiers: plan.targets.map(\.bundleIdentifier),
                    beforeOrder: before, afterOrder: Array(before.reversed()),
                    technicalDetails: plan.targets.map {
                        DebugOrderingTechnicalDetail(key: $0.key,
                            value: "\(orderingPositionLabel($0.before)) → \(orderingPositionLabel($0.after)); Restore returns \(orderingPositionLabel($0.before))")
                    } + [DebugOrderingTechnicalDetail(key: "Preview fingerprint", value: plan.fingerprint)]
                )
                editorWindowController.orderingPresentation.message =
                    "Review the two applications. Exchange Positions performs one real menu-bar write and one verification."
            } catch { presentOrderingError(error) }
        }
    }

    private func applyOrdering(_ fingerprint: String) {
        if preparedBoardRequest != nil {
            applyBoardConfiguration(fingerprint)
            return
        }
        guard !isReadOnlyValidation, !orderingRecoveryKnown,
              let plan = preparedOrderingPlan, plan.fingerprint == fingerprint,
              beginOrderingInteraction(message: "Checking and applying the real menu-bar order…") else { return }
        discardOrderingPreview()
        activeOrderingPlan = plan
        managementInteractionTask = Task { [weak self] in
            guard let self else { return }
            defer { finishOrderingInteraction() }
            do {
                if case .ordinaryRevealSession = await managementLoop.state {
                    throw OrderingError.staleSnapshot("close the ordinary reveal session before ordering")
                }
                let writer = try await orderingCoordinator()
                let observed = try await writer.applyOrdering(plan, confirmedFingerprint: fingerprint)
                presentOrderingCandidates(observed)
                editorWindowController.orderingPresentation.message =
                    "The real relative order was verified. Restore Order returns the original preferred positions; Stop or Quit also restores this session."
            } catch { presentOrderingError(error) }
            await updateOrderingRecoveryPresentation()
            if !orderingRecoveryKnown { activeOrderingPlan = nil }
        }
    }

    private func applyBoardConfiguration(_ fingerprint: String, continuingInteraction: Bool = false) {
        guard !isReadOnlyValidation, !orderingRecoveryKnown,
              let request = preparedBoardRequest,
              let model = editorModel,
              preparedBoardFingerprint == fingerprint,
              request == editorWindowController.currentOrderingConfigurationRequest else {
            if continuingInteraction { finishOrderingInteraction() }
            return
        }
        guard continuingInteraction || beginOrderingInteraction(message: "Applying changes…") else { return }
        let plan = preparedOrderingPlan
        let policy = preparedBoardPolicy
        let undoRebaseToken = preparedUndoRebaseToken
        let unsortedNames = preparedUnsortedNames
        let generation = lifecycleGeneration
        discardOrderingPreview()
        managementInteractionTask = Task { [weak self] in
            guard let self else { return }
            defer { finishOrderingInteraction() }
            var configurationCommitted = false
            do {
                guard let plan else { throw OrderingError.invalidSelection }
                if case .ordinaryRevealSession = await managementLoop.state,
                   let baseline = activeBaselinePlan {
                    await endOrdinaryReveal(
                        baseline: baseline,
                        persistedManagementEnabled: model.acceptedPolicy.managementEnabled
                    )
                }
                if let policy {
                    let observation = try await captureApplyPreflight()
                    let core = try await makeCore(scope: model.validationScope, permitsReviewedActivation: true)
                    let refreshed = try await core.preview(
                        draft: model.draft, candidates: observation.candidates,
                        observedRunningBundleIdentifiers: observation.runningBundleIdentifiers,
                        candidateGeneration: editorWindowController.candidateGeneration,
                        runtimeContractFingerprint: runtimeContractFingerprint
                    )
                    guard let checked = refreshed.1,
                          checked.newPolicy == policy.newPolicy,
                          checked.oldPolicy == policy.oldPolicy,
                          checked.reviewBinding == policy.reviewBinding else {
                        throw PolicyEditingCoreError.staleReviewedPlan
                    }
                }
                guard generation == lifecycleGeneration,
                      !interactionGate.isTerminating,
                      editorModel?.draft == model.draft,
                      request == editorWindowController.currentOrderingConfigurationRequest else {
                    throw PolicyEditingCoreError.staleReviewedPlan
                }
                let writer = try await orderingCoordinator()
                let result = try await writer.applyConfigurationOrdering(
                    plan, confirmedFingerprint: plan.fingerprint,
                    policyChange: policy, policyStore: persistentStore,
                    confirmedUndoRebaseToken: undoRebaseToken
                )
                configurationCommitted = true
                if let policy {
                    activeBaselinePlan = policy.report.newBaselinePlan
                    activeRevealPlan = policy.report.newRevealPlan
                    try await managementLoop.synchronizeCommittedPolicy(
                        policy.newPolicy, baseline: activeBaselinePlan
                    )
                    try await synchronizeInterfaceAfterCommit(policy.newPolicy, previousModel: model)
                }
                guard editorWindowController.installCommittedOrderingLayout(
                    from: request
                ) else {
                    throw OrderingError.staleSnapshot(
                        "the committed candidate scope changed; refresh the board"
                    )
                }
                guard generation == lifecycleGeneration, !interactionGate.isTerminating else {
                    throw ManagementLoopError.staleLifecycleGeneration
                }
                let displayedSnapshot = policy == nil ? result.snapshot : try await orderingBackend.capture()
                presentOrderingCandidates(displayedSnapshot)
                editorWindowController.initializeOrderingLayoutFromCurrentRows(force: true)
                let visual: String
                switch result.physicalVerificationStatus {
                case .verified:
                    visual = "Order verified."
                case .mismatch:
                    visual = "The menu bar does not yet match the saved order."
                case .unavailable:
                    visual = "Some on-screen positions could not be verified."
                }
                editorWindowController.orderingPresentation.message =
                    "Changes applied. \(visual)"
                    + (unsortedNames.isEmpty ? "" : " Visibility only: \(unsortedNames.joined(separator: ", ")).")
                if let failure = await updateAcceptedControlBoundary() {
                    editorWindowController.orderingPresentation.message =
                        (editorWindowController.orderingPresentation.message ?? "") + " \(failure)"
                    editorWindowController.orderingPresentation.isError = true
                }
            } catch {
                if configurationCommitted {
                    presentCommittedOrderingRefreshFailure(error)
                } else {
                    if let policy { await reconcileManagementAfterFailure(policy) }
                    presentOrderingError(error)
                }
            }
            await updateOrderingRecoveryPresentation()
        }
    }

    private func restoreOrdering() {
        guard !isReadOnlyValidation,
              beginOrderingInteraction(message: "Checking the saved order…") else { return }
        discardOrderingPreview()
        managementInteractionTask = Task { [weak self] in
            guard let self else { return }
            var needsAutomaticRefresh = false
            defer {
                finishOrderingInteraction()
                // One read-only follow-up after releasing the interaction gate.
                // Refresh does not reapply the transaction or schedule retries.
                if needsAutomaticRefresh { refresh() }
            }
            var preferencesRestored = false
            do {
                let writer = try await orderingCoordinator(forRecovery: true)
                var inverse: PreparedPolicyEdit?
                let priorModel = editorModel
                let receipt = try await orderingRecoveryStore.load()
                if receipt?.hasPendingRevisionRollback != true,
                   let undo = receipt?.undoPolicy,
                   let model = priorModel {
                    let observation = try await captureApplyPreflight()
                    let core = try await makeCore(scope: model.validationScope, permitsReviewedActivation: true)
                    inverse = try await core.previewUndoKeepingManagementState(
                        targetPolicy: undo.before,
                        candidates: observation.candidates,
                        observedRunningBundleIdentifiers: observation.runningBundleIdentifiers,
                        candidateGeneration: editorWindowController.candidateGeneration,
                        runtimeContractFingerprint: runtimeContractFingerprint
                    ).1
                    let currentPolicy = try await persistentStore?.load()
                    guard inverse != nil || currentPolicy == undo.before else {
                        throw PolicyEditingCoreError.staleReviewedPlan
                    }
                }
                let result = try await writer.restoreOrdering(policyStore: persistentStore, policyUndo: inverse)
                guard result.preferencesRestored else {
                    throw OrderingTransactionError.restorationNotVerified
                }
                preferencesRestored = true
                if let inverse, let model = priorModel {
                    activeBaselinePlan = inverse.report.newBaselinePlan
                    activeRevealPlan = inverse.report.newRevealPlan
                    try await managementLoop.synchronizeCommittedPolicy(
                        inverse.newPolicy, baseline: activeBaselinePlan)
                    try await synchronizeInterfaceAfterCommit(inverse.newPolicy, previousModel: model)
                }
                editorWindowController.setStatus("Changes undone.", isError: false)
                activeOrderingPlan = nil
                guard presentOrderingCandidates(try await orderingBackend.capture()) else {
                    needsAutomaticRefresh = true
                    await updateOrderingRecoveryPresentation()
                    return
                }
                editorWindowController.orderingPresentation.requiresObservationRefresh = false
                editorWindowController.initializeOrderingLayoutFromCurrentRows(force: true)
                editorWindowController.orderingPresentation.message = "Changes undone."
                editorWindowController.orderingPresentation.technicalDetail = result.relativeOrderVerified
                    ? nil : "Saved settings were restored and verified. On-screen positions were not independently verified."
                if let failure = await updateAcceptedControlBoundary() {
                    editorWindowController.orderingPresentation.message =
                        (editorWindowController.orderingPresentation.message ?? "") + " \(failure)"
                    editorWindowController.orderingPresentation.isError = true
                }
            } catch {
                if preferencesRestored {
                    presentCommittedOrderingRefreshFailure(error, restored: true)
                    editorWindowController.orderingPresentation.message = "Changes undone. Updating the Board…"
                    needsAutomaticRefresh = true
                } else {
                    presentOrderingError(error)
                }
            }
            await updateOrderingRecoveryPresentation()
        }
    }

    private func updateOrderingRecoveryPresentation() async {
        let presentation = editorWindowController.orderingPresentation
        do {
            let receipt = try await orderingRecoveryStore.load()
            orderingRecoveryKnown = receipt?.isPendingRestoration == true
            presentation.hasPendingRecovery = orderingRecoveryKnown
            presentation.hasRecovery = receipt?.isPendingRestoration == true
                || receipt?.hasConfigurationUndo == true
            if let receipt {
                if receipt.isPendingRestoration && (receipt.phase != .applied || activeOrderingPlan == nil) {
                    presentation.message = "An unfinished change needs recovery. Choose Recover Changes."
                }
                if receipt.isPendingRestoration { presentation.canApply = false }
            }
        } catch {
            orderingRecoveryKnown = true
            presentation.hasPendingRecovery = true
            presentation.hasRecovery = true
            presentOrderingError(error)
        }
    }

    @discardableResult
    private func presentOrderingCandidates(_ snapshot: OrderingSnapshot) -> Bool {
        do {
            let knownBundles = Set(editorModel?.candidateInventory.candidates.map(\.bundleIdentifier) ?? [])
            let candidates = try OrderingConfigurationIdentityResolver.resolve(snapshot: snapshot).filter {
                !$0.keys.isEmpty || knownBundles.contains($0.bundleIdentifier)
                    || $0.process.map { snapshot.observationsByPID[$0.pid] != nil } == true
            }
            let icons = WorkspacePolicyIconResolver()
            let observedFrames = Dictionary(uniqueKeysWithValues: candidates.compactMap { candidate -> (String, RectSnapshot)? in
                guard let process = candidate.process,
                      let observation = snapshot.observationsByPID[process.pid],
                      observation.axComplete, observation.itemFrames.count == 1,
                      let frame = observation.itemFrames.first,
                      frame.width > 0, frame.height > 0,
                      frame.x >= snapshot.displayFrame.x,
                      frame.x + frame.width <= snapshot.displayFrame.x + snapshot.displayFrame.width else { return nil }
                return (candidate.bundleIdentifier, frame)
            })
            let ambiguousObservedOwners = OrderingObservedGeometry.ambiguousOwners(frames: observedFrames)
            lastOrderingSnapshot = snapshot
            editorWindowController.orderingPresentation.hasObservation = true
            editorWindowController.orderingPresentation.rows = candidates.map { candidate in
                let frame = ambiguousObservedOwners.contains(candidate.bundleIdentifier)
                    ? nil : observedFrames[candidate.bundleIdentifier]
                let values = candidate.keys.map(\.value)
                let position = values.compactMap { value -> Double? in
                    switch value {
                    case let .integer(number): Double(number)
                    case let .real(number): number
                    default: nil
                    }
                }.max()
                let excluded = candidate.reasons.contains(.selfExcluded)
                    || candidate.reasons.contains(.systemOwnerExcluded)
                return DebugOrderingRow(
                    bundleIdentifier: candidate.bundleIdentifier, name: candidate.displayName,
                    icon: icons.applicationIcon(bundleIdentifier: candidate.bundleIdentifier).image,
                    systemKey: candidate.keys.isEmpty ? nil : candidate.keys.map(\.key).joined(separator: ", "),
                    currentPositionLabel: values.isEmpty ? nil : values.map(orderingPositionLabel).joined(separator: ", "),
                    reason: candidate.reasons.isEmpty ? nil : candidate.reasons.map(\.userDescription).joined(separator: "; "),
                    isEligible: candidate.eligible,
                    observedX: frame?.x,
                    configuredPosition: position,
                    availability: candidate.eligible ? .ready : (excluded ? .blocked : .needsMapping)
                )
            }
            let systemCandidates = try OrderingConfigurationSubjectIdentityResolver.resolve(snapshot: snapshot)
                .filter { if case .systemItem = $0.subjectID { true } else { false } }
            editorWindowController.orderingPresentation.rows += systemCandidates.map { candidate in
                guard case let .systemItem(item) = candidate.subjectID else { preconditionFailure() }
                let orderingOffered = item.isOrderingOffered
                let values = candidate.keys.map(\.value)
                let position = values.compactMap { value -> Double? in
                    switch value {
                    case let .integer(number): Double(number)
                    case let .real(number): number
                    default: nil
                    }
                }.first
                let icon = icons.systemIcon(observation: .init(
                    observationIdentifier: item.observationIdentifier,
                    ownerBundleIdentifier: item.hostBundleIdentifier,
                    displayName: item.displayName, observationCount: 0
                )).image
                return DebugOrderingRow(
                    subjectID: candidate.subjectID, name: candidate.displayName, icon: icon,
                    systemKey: candidate.keys.isEmpty ? nil : item.configurationKey,
                    currentPositionLabel: values.first.map(orderingPositionLabel),
                    reason: orderingOffered
                        ? (candidate.reasons.isEmpty ? nil : candidate.reasons.map(\.userDescription).joined(separator: "; "))
                        : "Sorting is not supported in this version; Visible, Revealable, and Hidden remain available.",
                    isEligible: orderingOffered && candidate.eligible,
                    observedX: nil, configuredPosition: position,
                    availability: orderingOffered
                        ? (candidate.eligible ? .ready : .needsMapping)
                        : .blocked,
                    policy: editorModel?.effectiveSystemItemPolicy(for: item.observationIdentifier)
                        ?? (item == .bluetooth
                            ? editorModel?.draft.bluetoothPolicy
                            : editorModel?.draft.systemItemPolicies[item.observationIdentifier])
                        ?? .visible
                )
            }
            editorWindowController.initializeOrderingLayoutFromCurrentRows()
            return true
        } catch {
            lastOrderingSnapshot = nil
            editorWindowController.orderingPresentation.hasObservation = false
            presentOrderingError(error)
            return false
        }
    }

    private func orderingPositionLabel(_ value: OrderingValue) -> String {
        switch value {
        case let .integer(number): String(number)
        case let .real(number): String(number)
        default: "Unsupported position"
        }
    }

    private func presentOrderingError(_ error: Error) {
        sessionDiagnostic("ordering-failure \(error.localizedDescription)")
        let presentation = editorWindowController.orderingPresentation
        presentation.needsDataAccess = false
        if let backendError = error as? MacOS27MenuBarOrderingBackendError {
            switch backendError {
            case let .groupFileOpenFailed(code), let .groupFileMetadataReadFailed(code),
                 let .groupFileReadFailed(code):
                presentation.needsDataAccess = code == EPERM || code == EACCES
            default: break
            }
        }
        presentation.isError = true
        presentation.message = presentation.needsDataAccess
            ? "Choose the menu bar layout file so Blenny can apply and undo your order."
            : "The operation could not finish. See Details before trying again."
        if let backendError = error as? MacOS27MenuBarOrderingBackendError,
           backendError == .runtimeUnsupported || backendError == .runtimeContractDiffers {
            presentation.message = "Ordering is unavailable on this macOS build."
        } else if case let .unavailableOrderChanges(names) = error as? OrderingError {
            presentation.message = "This draft moves items marked No sort: \(names.joined(separator: ", ")). Put them back or discard changes."
        } else if case .staleSnapshot = error as? OrderingError {
            presentation.message = "The menu bar changed. Discard changes and refresh before trying again."
        }
        presentation.technicalDetail = error.localizedDescription
        presentation.canApply = false
    }

    private func presentCommittedOrderingRefreshFailure(_ error: Error, restored: Bool = false) {
        sessionDiagnostic("ordering-committed-refresh-failure \(error.localizedDescription)")
        // A failure to refresh the Board cannot turn a verified commit into a
        // failed write or invite the user to repeat that write.
        lastOrderingSnapshot = nil
        let presentation = editorWindowController.orderingPresentation
        presentation.hasObservation = false
        presentation.isError = false
        presentation.canApply = false
        presentation.requiresObservationRefresh = true
        presentation.message = (restored ? "Changes undone." : "Changes applied.")
            + " Refresh to update the Board. Do not apply again."
        presentation.technicalDetail = error.localizedDescription
    }
}
#endif
