import AppKit
import BlennyCore
import Darwin
import ServiceManagement
import Sparkle
#if BLENNY_PRODUCT || DEBUG
import CryptoKit
#endif

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let legacyBlennyBundleIdentifier = "com.example.BlennyProbe"
    static let readOnlySystemMenuBarOwners = Set([
        "com.apple.controlcenter",
        "com.apple.menubaragent",
        "com.apple.systemuiserver",
        "com.apple.textinputmenuagent",
        "com.apple.weather.menu",
    ])

    let inventory = AccessibilityInventory(
        maximumDurationMilliseconds: 10_000,
        messagingTimeoutSeconds: 0.1
    )
    var isRefreshing = false
    let applicationUpdater = ApplicationUpdater()
    var hasUpdateFeed: Bool { applicationUpdater.isConfigured }
    var lastKnownAccessibilityTrust: Bool?
    var accessibilityOnboarding = AccessibilityOnboardingState()
    var accessibilityGrantRefresh = AccessibilityGrantRefreshState()
    var persistentStore: PersistentBundlePolicyStore?
    var interfaceStore: PolicyInterfaceStore?
    var editorModel: PolicyEditorViewModel?
    var ownershipSnapshot: MenuBarOwnershipSnapshot?
    var observedRunningBundleIdentifiers = Set<String>()
    // Session-only pass-through memory, never a persisted policy assignment.
    var admittedPassThroughBundleIdentifiers = Set<String>()
    var recoveryAvailable = false
    var managementBackendAvailable = false
    var terminationRestoreInProgress = false
    var terminateImmediatelyToReleaseConnection = false
    var activeBaselinePlan: RevealAllowlistPlan?
    var activeRevealPlan: RevealAllowlistPlan?
    var ordinaryRevealTimeoutTask: Task<Void, Never>?
    var interactionGate = ManagementInteractionGate()
    var actionAudit = PolicyActionAuditTrail()
    var managementInteractionTask: Task<Void, Never>?
    let nativeOverflowObserver = NativeOverflowObserver(reconnectOnAgentChange: false)
    var nativeObservationStarted = false
    var ordinaryReveal = OrdinaryRevealCoordinator()
    var attemptedStartupRecovery = false
    var connectionInvalidationTask: Task<Void, Never>?
    var lifecycleGeneration: UInt64 = 0
    var lifecycleObservers: [(NotificationCenter, NSObjectProtocol)] = []
    var lifecycleRestartRequired = false
    var displayConfiguration = DisplayConfigurationSignature(displays: [])
    var pendingApplicationLaunchAssessments: [String: RunningApplicationDescriptor] = [:]
    var applicationLaunchAssessmentTask: Task<Void, Never>?
    var fallbackSlotVerificationTask: Task<Void, Never>?
    lazy var managementLoop: ManagementLoopController = {
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
            #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
            let persistentWriter = await self.sharedSystemItemTrialWriter
            #if BLENNY_PRODUCT || DEBUG
            let backend = await self.orderingBackend
            let recovery = await self.orderingRecoveryStore
            let orderingPolicyStore = await self.interfaceStore
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
    var isReadOnlyValidation: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["BLENNY_0_6_0_DRY_RUN"] == "YES"
            || ProcessInfo.processInfo.environment["BLENNY_0_5_0_DRY_RUN"] == "YES"
            || ProcessInfo.processInfo.environment["BLENNY_0_9_0_ORDERING_DRY_RUN"] == "YES"
        #else
        false
        #endif
    }
    #if BLENNY_PRODUCT || DEBUG
    #if DEBUG
    var policyCoexistenceController: DebugPolicyCoexistenceController?
    var validationDeadlineTask: Task<Void, Never>?
    #endif
    var preparedOrderingPlan: OrderingPlan?
    var preparedBoardPolicy: PreparedPolicyEdit?
    var preparedBoardRequest: OrderingConfigurationRequest?
    var preparedBoardFingerprint: String?
    var preparedUnsortedNames: [String] = []
    var preparedUndoRebaseToken: String?
    var lastOrderingSnapshot: OrderingSnapshot?
    var boundaryCaptureInProgress = false
    var boundaryCaptureTask: Task<Void, Never>?
    var boundaryEvidenceDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Blenny/LocalData/BoundaryDiagnostics")
    }
    var activeOrderingPlan: OrderingPlan?
    var orderingRecoveryKnown = false
    lazy var fallbackRecoveryStore = FallbackPositionRecoveryStore(
        directory: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Blenny/LocalData/FallbackPositionExperiment")
    )
    var fallbackTrialRecovery: (any FallbackPositionRecoveryStoring)? {
        fallbackRecoveryStore
    }
    lazy var orderingRecoveryStore = OrderingRecoveryStore(
        directory: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Blenny/DebugOrdering")
    )
    lazy var menuBarLayoutAccess = MenuBarLayoutAccessSession(
        store: MenuBarLayoutBookmarkStore(
            directory: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Blenny/DebugOrdering")
        )
    )
    lazy var orderingBackend = MacOS27MenuBarOrderingBackend(
        contextProvider: { [weak self] in
            self?.orderingRuntimeContext() ?? MacOS27MenuBarOrderingContext(
                policyFingerprint: "unavailable", orderingAllowedBundleIdentifiers: [], lifecycleGeneration: 0
            )
        },
        fallbackIdentityProvider: { [weak self] in
            self?.statusItemController.fallbackNativeIdentity
        }
    )
    #endif
    #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    lazy var sharedSystemItemTrialWriter = SharedSystemItemManualTrialWriter(
        backend: MacOS27SystemItemPreferenceBackend(),
        receiptDirectory: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Blenny")
            .appendingPathComponent("DebugSharedSystemItemTrials")
    )
    #endif

    lazy var editorWindowController: PolicyEditorWindowController = PolicyEditorWindowController(
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
        onCheckForUpdates: hasUpdateFeed ? { [weak self] in self?.checkForUpdates(nil) } : nil,
        onShowFishPlacementGuide: { [weak self] in self?.showFishPlacementGuide() },
        onHideSharedSystemItem: { [weak self] target in
            self?.hideSharedSystemItem(target)
        },
        onRestoreSharedSystemItem: { [weak self] target in
            self?.restoreSharedSystemItem(target)
        },
        onSetAutomaticUpdateChecks: { [weak self] enabled in
            self?.applicationUpdater.setAutomaticChecks(enabled)
            self?.editorWindowController.interfaceModel.automaticUpdateChecks = enabled
        }
    )

    lazy var statusItemController = StatusItemController(
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
        },
        onCheckForUpdates: { [weak self] in self?.checkForUpdates(nil) },
        canCheckForUpdates: { [weak self] in
            self?.applicationUpdater.canCheck == true
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(permissionWindowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(editorWindowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: editorWindowController.window
        )
        configureMainMenu()
        applicationUpdater.permitsInteraction = { [weak self] in
            guard let self else { return false }
            return UpdateInteractionPolicy.allowsCheck(
                hasDraft: self.editorWindowController.hasDraftChanges,
                isBusy: self.interactionGate.isBusy || self.isRefreshing || self.interactionGate.isTerminating,
                recoveryPending: self.editorWindowController.interfaceModel.orderingPresentation.hasPendingRecovery
            )
        }
        applicationUpdater.start()
        editorWindowController.interfaceModel.automaticUpdateChecks = applicationUpdater.automaticallyChecks
        #if BLENNY_PRODUCT || DEBUG
        configureOrderingInterface()
        restoreSavedMenuBarLayoutAccess()
        #if DEBUG
        statusItemController.debugConfigureBoundaryCapture(directory: boundaryEvidenceDirectory) { [weak self] in
            self?.captureBoundaryEvidence()
        }
        #endif
        statusItemController.onPositionControls = { [weak self] in self?.positionRevealArrow(restoring: false) }
        statusItemController.onUndoControlPlacement = { [weak self] in self?.positionRevealArrow(restoring: true) }
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
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        refreshSharedSystemItemTrialPresentation()
        #endif
        refresh()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if !terminateImmediatelyToReleaseConnection,
           editorWindowController.hasDraftChanges {
            showEditor()
            editorWindowController.setStatus(
                "Apply or discard the local Draft before quitting or installing an update.",
                isError: true
            )
            return .terminateCancel
        }
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

    @objc func permissionWindowDidBecomeKey(_ notification: Notification) {
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

    @objc func editorWindowWillClose(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    func showEditor() {
        NSApplication.shared.setActivationPolicy(.regular)
        editorWindowController.showEditor()
    }

    func configureMainMenu() {
        let mainMenu = NSMenu()

        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Blenny")
        if hasUpdateFeed {
            let updateItem = NSMenuItem(
                title: "Check for Updates…",
                action: #selector(checkForUpdates(_:)),
                keyEquivalent: ""
            )
            updateItem.target = self
            applicationMenu.addItem(updateItem)
            applicationMenu.addItem(.separator())
        }
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

    @objc func checkForUpdates(_ sender: Any?) {
        if editorWindowController.hasDraftChanges {
            showEditor()
            editorWindowController.setStatus(
                "Apply or discard the local Draft before checking for updates.",
                isError: true
            )
            return
        }
        applicationUpdater.check(sender)
    }

    func refresh() {
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

    func completeRefresh(
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
            let accepted = try loadedPolicy ?? initialPolicy(
                blennyBundleIdentifier: blennyBundleIdentifier
            )
            let candidateInventory = PolicyCandidateInventory(
                observations: snapshot.observations
            )
            let model = try PolicyEditorViewModel(
                acceptedPolicy: accepted,
                candidateInventory: candidateInventory,
                systemItems: snapshot.systemItems,
                unattributedItems: snapshot.unattributedItems,
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
            managementBackendAvailable = backendCompatibilityAvailable(
                bundleIdentifier: blennyBundleIdentifier
            )
            let managementState = await recoverManagement(
                accepted: accepted,
                backup: backup,
                model: model,
                snapshot: snapshot,
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
            #if BLENNY_PRODUCT || DEBUG
            // The board reads physical order with its ordinary bounded refresh.
            // This stays inside the existing interaction gate and never creates
            // an ordering writer, even when startup has a recovery receipt.
            if !isReadOnlyValidation {
                presentBoardGeometry(report: report, candidates: candidateInventory.candidates)
                await readOrderingForBoard()
            }
            #if DEBUG
            await runInstalledDryRunIfRequested(model: model)
            #endif
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

    func recoverManagement(
        accepted: PersistentBundlePolicyDocument,
        backup: PersistentBundlePolicyBackup?,
        model: PolicyEditorViewModel,
        snapshot: MenuBarOwnershipSnapshot,
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
        guard managementBackendAvailable else {
            await managementLoop.failClosed(
                "Grant Accessibility and choose Resume in the supported installed app."
            )
            return await managementLoop.state
        }
        let backupCompatible = backup.map { backup in
            (try? backup.previousPolicy.validated(
                forBlennyBundleIdentifier: model.blennyBundleIdentifier
            )) != nil && !backup.previousPolicy.policies.contains(where: {
                $0.bundleIdentifier.lowercased().hasPrefix("com.apple.")
            })
        } ?? accepted.isInitialVisiblePolicy(forBlennyBundleIdentifier: model.blennyBundleIdentifier)
        guard backupCompatible else {
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
                recoveryBackupFingerprint: backup?.backupFingerprint
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

    func presentManagementState(
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
                || model.acceptedPolicy.systemItemPolicies.contains { identifier, policy in
                    policy == .revealable
                        && PersistentSystemItemPolicyCatalog.supportsManagement(for: identifier)
                }
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
            managementBackendAvailable: managementBackendAvailable
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

    #if !BLENNY_PRODUCT && !DEBUG && !BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    func hideSharedSystemItem(_ target: SharedSystemItemTrialTarget) {}
    func restoreSharedSystemItem(_ target: SharedSystemItemTrialTarget) {}
    #endif

    var runtimeContractFingerprint: String {
        ExperimentalMacOS27AssessmentFactory.compatibilityFingerprint
    }

    func backendCompatibilityAvailable(
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

    func resumeManaging() { performPolicyAction(.resume) }
    func applyDraftChanges() {
        #if BLENNY_PRODUCT || DEBUG
        if let request = editorWindowController.currentOrderingConfigurationRequest {
            previewBoardConfiguration(request, applyWhenReady: true)
            return
        }
        #endif
        performPolicyAction(.apply)
    }
    func stopManaging() { performPolicyAction(.stop) }
    func restorePreviousPolicy() { performPolicyAction(.restore) }

    func draftDidChange(_ model: PolicyEditorViewModel) {
        guard !interactionGate.isBusy, !interactionGate.isTerminating else { return }
        editorModel = model
        #if BLENNY_PRODUCT || DEBUG
        discardOrderingPreview()
        #endif
        statusItemController.setDraftHasChanges(
            editorWindowController.hasDraftChanges,
            requiresObservationRefresh: editorWindowController.requiresObservationRefresh
        )
    }

    func beginManagementInteraction() -> Bool {
        guard !isRefreshing, connectionInvalidationTask == nil, interactionGate.begin() else { return false }
        editorWindowController.setApplying(true)
        statusItemController.setInteractionBusy(true)
        return true
    }

    func finishManagementInteraction(refreshNativeObservation: Bool = false) {
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
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
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

    func performPolicyAction(_ action: PolicyActionAuditTrail.Action) {
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
                #if BLENNY_PRODUCT || DEBUG
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
                        unattributedItems: observation.unattributedItems,
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
                #if BLENNY_PRODUCT || DEBUG
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
                showEditor()
            }
        }
    }

    func apply(
        _ prepared: PreparedPolicyEdit,
        using core: PolicyEditingCore,
        previousModel model: PolicyEditorViewModel,
        action: PolicyActionAuditTrail.Action
    ) async throws -> PolicyEditingCommitOutcome {
        let generation = lifecycleGeneration
        managementBackendAvailable = backendCompatibilityAvailable(
            bundleIdentifier: model.blennyBundleIdentifier
        )
        guard !prepared.newPolicy.managementEnabled || managementBackendAvailable else {
            throw PolicyInterfaceWriteError.installedDryRunRequired
        }
        do {
            let currentObservation: (
                candidates: PolicyCandidateInventory,
                runningBundleIdentifiers: Set<String>,
                unattributedItems: [UnattributedMenuBarItemObservation]
            )
            if prepared.newPolicy.managementEnabled {
                editorWindowController.setStatus("Checking managed apps…", isError: false)
                currentObservation = try await captureApplyPreflight()
            } else {
                // A disabling action cannot create an assertion. Unrelated
                // process churn must never obstruct this safety cleanup.
                currentObservation = (
                    candidates: model.candidateInventory,
                    runningBundleIdentifiers: observedRunningBundleIdentifiers,
                    unattributedItems: model.unattributedItems
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

    func captureApplyPreflight() async throws -> (
        candidates: PolicyCandidateInventory,
        runningBundleIdentifiers: Set<String>,
        unattributedItems: [UnattributedMenuBarItemObservation]
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
                .union([blennyBundleIdentifier]),
            snapshot.unattributedItems
        )
    }

    func synchronizeInterfaceAfterCommit(
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

    func reconcileManagementAfterFailure(
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

    func toggleOrdinaryReveal() {
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

    func drainOrdinaryRevealRequest(diagnosticID: UUID? = nil) {
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

    func updateNativeOverflowObservation() {
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

    func nativeAgentConnectionLost() {
        handleLifecycleEvent(.menuBarAgentChanged)
    }

    func scheduleFallbackSlotVerification() {
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

    func installLifecycleObservers() {
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

    func handleDisplayConfigurationNotification() {
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

    func currentDisplayConfiguration() -> DisplayConfigurationSignature {
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

    func handleWorkspaceApplicationLaunch(
        _ application: NSRunningApplication
    ) {
        let identifier = application.bundleIdentifier
        #if BLENNY_PRODUCT || DEBUG
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

    func scheduleApplicationLaunchAssessment() {
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

    func assessPendingApplicationLaunches(
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

    func verifyUnidentifiedLaunchesHaveNoExtras(
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
            let itemCount = ownership.observedMenuBarItemCount(
                forProcessIdentifier: descriptor.processIdentifier
            )
            let assessment = ManagementLifecyclePolicy.assessApplicationLaunch(
                discovery: discovery,
                observedMenuBarItemCount: itemCount,
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

    func handleLifecycleEvent(_ event: ManagementLifecycleEvent) {
        guard !interactionGate.isTerminating else { return }
        let managed = Set(editorModel?.acceptedPolicyScope.approvedBundleIdentifiers ?? [])
        let allowed = activeBaselinePlan.map { Set($0.allowedBundleIdentifiers) }
            ?? observedRunningBundleIdentifiers
        let visibilityInvalidated = ManagementLifecyclePolicy.invalidates(
            event, managedBundleIdentifiers: managed, allowedBundleIdentifiers: allowed,
            blennyBundleIdentifier: Bundle.main.bundleIdentifier ?? "xyz.fi5h.blenny"
        )
        #if BLENNY_PRODUCT || DEBUG
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
                managementBackendAvailable = false
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
            #if BLENNY_PRODUCT || DEBUG
            activeOrderingPlan = nil
            await updateOrderingRecoveryPresentation()
            #endif
            let restored = await managementLoop.activePlanSnapshot() == nil
            sessionDiagnostic("lifecycle restored=\(restored) reason=\(event.reason)")
        }
    }

    /// Explicit local validation only; no normal disk logger or inventory dump.
    func sessionDiagnostic(_ message: @autoclosure () -> String) {
        #if DEBUG
        guard DebugSessionTrace.shared.enabled else { return }
        DebugSessionTrace.shared.write(message())
        #endif
    }

    func endOrdinaryReveal(
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

    func makeCore(
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

    func permitsWriterUse(generation: UInt64) -> Bool {
        generation == lifecycleGeneration && !interactionGate.isTerminating
            && connectionInvalidationTask == nil && !isReadOnlyValidation
    }

    func requestAccessibilityAccess() {
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
    func openAccessibilitySettings() -> Bool {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return false }
        return NSWorkspace.shared.open(url)
    }

    func openProjectWebsite() {
        openExternalURL(ProductSupportLinks.projectWebsite)
    }

    func openMonthlySponsor() {
        openExternalURL(ProductSupportLinks.monthlySponsor)
    }

    func openOneTimeSponsor() {
        openExternalURL(ProductSupportLinks.oneTimeSponsor)
    }

    func openKoFi() {
        openExternalURL(ProductSupportLinks.koFi)
    }

    func openExternalURL(_ rawValue: String) {
        guard let url = URL(string: rawValue) else { return }
        NSWorkspace.shared.open(url)
    }

    func updatePermissionPresentation() {
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

    func setLaunchAtLogin(_ enabled: Bool) {
        guard !isReadOnlyValidation else { return }
        do {
            try ApplicationLoginService.setEnabled(enabled)
            updateLaunchAtLoginPresentation()
        } catch {
            updateLaunchAtLoginPresentation(failureMessage: error.localizedDescription)
        }
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func showFishPlacementGuide() {
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

    #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    func policyCoordinator(forRecovery: Bool = false) async throws -> CoordinatedPolicyWriter {
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

    func refreshSharedSystemItemTrialPresentation() {
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

    func hideSharedSystemItem(_ target: SharedSystemItemTrialTarget) {
        guard PersistentSystemItemPolicyCatalog.supportsManagement(
            for: target.observationIdentifier
        ) else { return }
        guard !isReadOnlyValidation, beginManagementInteraction() else { return }
        editorWindowController.setSharedSystemItemTrial(target, presentation: .busy)
        editorWindowController.setStatus(
            "Applying the selected \(target.displayName) visibility change…",
            isError: false
        )
        managementInteractionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { finishManagementInteraction() }
            do {
                let writer = try await policyCoordinator()
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

    func restoreSharedSystemItem(_ target: SharedSystemItemTrialTarget) {
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
                let writer = try await policyCoordinator(forRecovery: true)
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

    func updateLaunchAtLoginPresentation(failureMessage: String? = nil) {
        editorWindowController.setLaunchAtLoginState(
            ApplicationLoginService.presentation(failureMessage: failureMessage)
        )
    }

    func makePersistentStore() throws -> PersistentBundlePolicyStore {
        if let persistentStore { return persistentStore }
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: !isReadOnlyValidation
        )
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
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

    func initialPolicy(
        blennyBundleIdentifier: String
    ) throws -> PersistentBundlePolicyDocument {
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
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

    func currentBundleIdentifier() throws -> String {
        guard let identifier = Bundle.main.bundleIdentifier else {
            throw PersistentBundlePolicyDocumentError.invalidBundleIdentifier(
                "Blenny bundle identifier is unavailable"
            )
        }
        return identifier
    }

    func runningApplicationDescriptors() -> [RunningApplicationDescriptor] {
        var applications = NSWorkspace.shared.runningApplications
        applications.append(
            contentsOf: NSRunningApplication.runningApplications(
                withBundleIdentifier: "com.apple.MenuBarAgent"
            )
        )
        applications = applications.filter { application in
            application.activationPolicy != .prohibited
                || isReadOnlySystemMenuBarOwner(application.bundleIdentifier)
                || application.bundleIdentifier == nil
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

    func requiresApplicationLaunchAssessment(_ application: NSRunningApplication) -> Bool {
        ManagementLifecyclePolicy.requiresLaunchAssessment(
            bundleIdentifier: application.bundleIdentifier,
            acceptedBundleIdentifiers: Set(editorModel?.acceptedPolicyScope.approvedBundleIdentifiers ?? []),
            allowedBundleIdentifiers: Set(activeBaselinePlan?.allowedBundleIdentifiers ?? []),
            blennyBundleIdentifier: Bundle.main.bundleIdentifier ?? "xyz.fi5h.blenny"
        )
    }

    func scanPriority(for application: NSRunningApplication) -> Int {
        if application.bundleIdentifier?.lowercased() == "com.apple.menubaragent" {
            return 0
        }
        if isReadOnlySystemMenuBarOwner(application.bundleIdentifier) { return 1 }
        if application.processIdentifier == ProcessInfo.processInfo.processIdentifier { return 2 }
        if application.activationPolicy == .prohibited { return 4 }
        return 3
    }

    func isReadOnlySystemMenuBarOwner(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return Self.readOnlySystemMenuBarOwners.contains(bundleIdentifier.lowercased())
    }
}
