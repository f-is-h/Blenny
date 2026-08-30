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
    private var editingCore: PolicyEditingCore?
    private var editorModel: PolicyEditorViewModel?
    private var ownershipSnapshot: MenuBarOwnershipSnapshot?
    private var observedRunningBundleIdentifiers = Set<String>()
    private var recoveryAvailable = false
    private var developmentMutationAvailable = false
    private var terminationRestoreInProgress = false
    private var activeBaselinePlan: RevealAllowlistPlan?
    private var activeRevealPlan: RevealAllowlistPlan?
    private var ordinaryRevealTimeoutTask: Task<Void, Never>?
    private lazy var managementLoop = ManagementLoopController(
        writerProvider: {
            #if DEBUG
            let factory = try ExperimentalMacOS27AssessmentFactory()
            return RevealAssertionWriter(factory: factory)
            #else
            throw PolicyInterfaceWriteError.releaseBackendUnavailable
            #endif
        }
    )
    #if DEBUG
    private var policyCoexistenceController: DebugPolicyCoexistenceController?
    #endif

    private lazy var editorWindowController = PolicyEditorWindowController(
        onRefresh: { [weak self] in self?.refresh() },
        onRequestAccess: { [weak self] in self?.requestAccessibilityAccess() },
        onResumeManaging: { [weak self] in self?.reviewResumeManaging() },
        onStopManaging: { [weak self] in self?.reviewStopManaging() },
        onRestorePreviousPolicy: { [weak self] in self?.reviewRestorePreviousPolicy() },
        onDraftDidChange: { [weak self] model in self?.draftDidChange(model) },
        onReviewDraft: { [weak self] in self?.reviewDraftChanges() },
        onApply: { [weak self] prepared in self?.apply(prepared) },
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
        onResumeManaging: { [weak self] in self?.reviewResumeManaging() },
        onStopManaging: { [weak self] in self?.reviewStopManaging() },
        onRestorePreviousPolicy: { [weak self] in self?.reviewRestorePreviousPolicy() },
        onQuit: { NSApplication.shared.terminate(nil) }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        _ = statusItemController
        updatePermissionPresentation()
        updateLaunchAtLoginPresentation()

        #if DEBUG
        if ProcessInfo.processInfo.environment["BLENNY_0_5_0_DRY_RUN"] == "YES",
           !AccessibilityAuthorization.isTrusted {
            Self.writeDryRunOutput(
                "DRY-RUN FAILED: Accessibility is not granted to the installed 0.5.0 Debug app."
            )
            NSApplication.shared.terminate(nil)
            return
        }
        #endif

        #if DEBUG
        if ProcessInfo.processInfo.environment[
            DebugPolicyCoexistenceController.editingActionEnvironmentKey
        ] != nil {
            policyCoexistenceController = DebugPolicyCoexistenceController(
                statusItemController: statusItemController
            )
            policyCoexistenceController?.start()
            return
        }
        #endif

        showEditor()
        refresh()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        #if DEBUG
        if ProcessInfo.processInfo.environment["BLENNY_0_5_0_DRY_RUN"] == "YES" {
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
        Task { @MainActor in
            await managementLoop.terminate()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        let previouslyTrusted = lastKnownAccessibilityTrust
        updatePermissionPresentation()
        updateLaunchAtLoginPresentation()
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
                "Accessibility is granted. Review or discard the local Draft before refreshing.",
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
        guard !isRefreshing else { return }
        updatePermissionPresentation()
        guard AccessibilityAuthorization.isTrusted else {
            editorWindowController.setStatus(
                "Enable Accessibility, then return to Blenny. One bounded refresh will run automatically.",
                isError: false
            )
            return
        }

        isRefreshing = true
        let descriptors = runningApplicationDescriptors()
        let runningIdentifiers = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        ).union(Bundle.main.bundleIdentifier.map { [$0] } ?? [])
        statusItemController.setRefreshing(true)
        editorWindowController.setRefreshing(true)
        Task { [weak self, inventory] in
            let report = await inventory.capture(
                applications: descriptors,
                accessibilityTrusted: true
            )
            guard let self else { return }
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
        isRefreshing = false
        statusItemController.setRefreshing(false)
        editorWindowController.setRefreshing(false)

        let snapshot = MenuBarOwnershipSnapshotBuilder.make(from: report)
        ownershipSnapshot = snapshot
        guard snapshot.isComplete else {
            let detail = snapshot.issues.map(\.description).joined(separator: "; ")
            #if DEBUG
            if ProcessInfo.processInfo.environment["BLENNY_0_5_0_DRY_RUN"] == "YES" {
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
            editingCore = nil
            return
        }

        do {
            let blennyBundleIdentifier = try currentBundleIdentifier()
            let store = try makePersistentStore()
            persistentStore = store
            _ = try await store.migrateBundleIdentifier(
                from: Self.legacyBlennyBundleIdentifier,
                to: blennyBundleIdentifier
            )
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
            let managementLoop = self.managementLoop
            let core = PolicyEditingCore(
                store: interfaceStore,
                blennyBundleIdentifier: blennyBundleIdentifier,
                scope: model.validationScope,
                writerProvider: {
                    try await managementLoop.writerForTransaction()
                }
            )
            let runningIdentifiers = runningBundleIdentifiers.union([blennyBundleIdentifier])
            let backup = try await store.loadBackup()
            let hasBackup = backup != nil

            self.interfaceStore = interfaceStore
            editingCore = core
            editorModel = model
            observedRunningBundleIdentifiers = runningIdentifiers
            recoveryAvailable = hasBackup
            statusItemController.setDraftHasChanges(model.hasDraftChanges)
            editorWindowController.display(
                model: model,
                observationCount: candidateInventory.candidates.count,
                recoveryAvailable: hasBackup
            )
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
            #if DEBUG
            await runInstalledDryRunIfRequested(model: model)
            #endif
        } catch {
            editingCore = nil
            editorWindowController.setStatus(
                "Could not prepare the policy editor: \(error.localizedDescription)",
                isError: true
            )
        }
    }

    private func recoverManagement(
        accepted: PersistentBundlePolicyDocument,
        backup: PersistentBundlePolicyBackup?,
        model: PolicyEditorViewModel,
        candidateGeneration: UUID
    ) async -> ManagementLoopState {
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
                "development runtime compatibility is unavailable"
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
                    "accepted policy could not produce a valid startup baseline"
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
        statusItemController.setManagementState(
            state,
            persistedManagementEnabled: persistedManagementEnabled,
            recoveryAvailable: recoveryAvailable
        )
        editorWindowController.setManagementRuntimeState(
            state,
            developmentMutationAvailable: developmentMutationAvailable
        )
        switch state {
        case .active:
            editorWindowController.setStatus(
                "Management is active for the verified policy baseline.",
                isError: false
            )
        case .stopped:
            editorWindowController.setStatus(
                "Management is stopped. Draft changes remain local until Review and Apply.",
                isError: false
            )
        case .unsupportedRuntimeContract:
            editorWindowController.setStatus(
                "Management is unavailable because this runtime contract is unsupported. No assertion was created.",
                isError: true
            )
        case .failClosedUnrestricted where persistedManagementEnabled:
            editorWindowController.setStatus(
                "Management could not be safely restored. Blenny is unrestricted and is not reporting management as active.",
                isError: true
            )
        default:
            break
        }
    }

    #if DEBUG
    private func runInstalledDryRunIfRequested(
        model: PolicyEditorViewModel
    ) async {
        guard ProcessInfo.processInfo.environment["BLENNY_0_5_0_DRY_RUN"] == "YES"
        else { return }
        do {
            let core = try makeCore(scope: model.acceptedPolicyScope)
            let preview = try await core.previewResumeManaging(
                candidates: model.candidateInventory,
                observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                candidateGeneration: editorWindowController.candidateGeneration,
                runtimeContractFingerprint: runtimeContractFingerprint
            )
            Self.writeDryRunOutput(
                preview.0.text
                    + "\nDRY-RUN GUARANTEES"
                    + "\n- installedBundle=\(Bundle.main.bundleURL.path)"
                    + "\n- writerCreated=false"
                    + "\n- assertionCreated=false"
                    + "\n- persistenceChanged=false"
                    + "\n- managementEnabledChanged=false"
            )
        } catch {
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
        guard ProcessInfo.processInfo.environment["BLENNY_0_5_0_DRY_RUN"] != "YES",
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

    private func reviewResumeManaging() {
        guard let model = editorModel else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let core = try makeCore(
                    scope: model.acceptedPolicyScope
                )
                let preview = try await core.previewResumeManaging(
                    candidates: model.candidateInventory,
                    observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                    candidateGeneration: editorWindowController.candidateGeneration,
                    runtimeContractFingerprint: runtimeContractFingerprint
                )
                editingCore = core
                presentReview(
                    title: "Review Resume Managing",
                    report: preview.0,
                    prepared: preview.1
                )
            } catch {
                showPreviewError("Resume Managing", error: error)
            }
        }
    }

    private func draftDidChange(_ model: PolicyEditorViewModel) {
        editorModel = model
        statusItemController.setDraftHasChanges(model.hasDraftChanges)
    }

    private func reviewDraftChanges() {
        guard let model = editorModel, model.hasDraftChanges else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let core = try makeCore(scope: model.validationScope)
                let preview = try await core.preview(
                    draft: model.draft,
                    candidates: model.candidateInventory,
                    observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                    candidateGeneration: editorWindowController.candidateGeneration,
                    runtimeContractFingerprint: runtimeContractFingerprint
                )
                guard editorModel?.draft == model.draft else {
                    editorWindowController.setStatus(
                        "The draft changed while Review was preparing. Review the current draft again.",
                        isError: false
                    )
                    return
                }
                editingCore = core
                presentReview(
                    title: "Review Draft Changes",
                    report: preview.0,
                    prepared: preview.1
                )
            } catch {
                showPreviewError("Draft Changes", error: error)
            }
        }
    }

    private func reviewStopManaging() {
        guard let model = editorModel else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let core = try makeCore(
                    scope: model.acceptedPolicyScope
                )
                let preview = try await core.previewStopManaging(
                    candidates: model.candidateInventory,
                    observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                    candidateGeneration: editorWindowController.candidateGeneration,
                    runtimeContractFingerprint: runtimeContractFingerprint
                )
                editingCore = core
                presentReview(
                    title: "Review Stop Managing and Restore",
                    report: preview.0,
                    prepared: preview.1
                )
            } catch {
                showPreviewError("Stop Managing", error: error)
            }
        }
    }

    private func reviewRestorePreviousPolicy() {
        guard let model = editorModel, let persistentStore else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let backup = try await persistentStore.loadBackup() else {
                    throw PolicyEditingCoreError.previousPolicyBackupMissing
                }
                let core = try makeCore(
                    scope: PolicyValidationScope(
                        approvedBundleIdentifiers: backup.previousPolicy.policies.map(
                            \.bundleIdentifier
                        )
                    )
                )
                let preview = try await core.previewRestorePreviousPolicy(
                    candidates: model.candidateInventory,
                    observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                    candidateGeneration: editorWindowController.candidateGeneration,
                    runtimeContractFingerprint: runtimeContractFingerprint
                )
                editingCore = core
                presentReview(
                    title: "Review Restore Previous Policy",
                    report: preview.0,
                    prepared: preview.1
                )
            } catch {
                showPreviewError("Restore Previous Policy", error: error)
            }
        }
    }

    private func presentReview(
        title: String,
        report: PolicyDryRunImpactReport,
        prepared: PreparedPolicyEdit?
    ) {
        editorWindowController.presentReview(
            actionTitle: title,
            report: report,
            prepared: prepared
        )
    }

    private func apply(_ prepared: PreparedPolicyEdit) {
        let changesSystemAssertion = prepared.newPolicy != prepared.oldPolicy
            && prepared.newPolicy.managementEnabled
        guard !changesSystemAssertion || developmentMutationAvailable else {
            editorWindowController.setStatus(
                PolicyInterfaceWriteError.installedDryRunRequired.localizedDescription,
                isError: true
            )
            return
        }
        guard let core = editingCore else { return }
        guard let model = editorModel else { return }
        editorWindowController.setStatus("Applying the exact reviewed plan…", isError: false)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if case .ordinaryRevealSession = await managementLoop.state,
                   let baseline = activeBaselinePlan {
                    await endOrdinaryReveal(
                        baseline: baseline,
                        persistedManagementEnabled: prepared.oldPolicy.managementEnabled
                    )
                    guard case .active = await managementLoop.state else {
                        throw ManagementLoopError.managementIsNotActive
                    }
                }
                let currentObservation: (
                    candidates: PolicyCandidateInventory,
                    runningBundleIdentifiers: Set<String>
                )
                if prepared.newPolicy.managementEnabled {
                    editorWindowController.setStatus(
                        "Revalidating the exact reviewed observation…",
                        isError: false
                    )
                    currentObservation = try await captureApplyPreflight()
                } else {
                    // A reviewed Stop never creates or replaces an assertion. Keep it
                    // bound to the reviewed snapshot so unrelated process churn cannot
                    // prevent the safety action. Draft and generation changes still
                    // invalidate the prepared review in PolicyEditingCore.
                    currentObservation = (
                        candidates: model.candidateInventory,
                        runningBundleIdentifiers: observedRunningBundleIdentifiers
                    )
                }
                await managementLoop.beginTransaction()
                presentManagementState(
                    await managementLoop.state,
                    persistedManagementEnabled: prepared.oldPolicy.managementEnabled
                )
                _ = try await core.commit(
                    prepared,
                    currentDraft: prepared.persistenceMode == .restorePreviousPolicy
                        ? prepared.report.rawDraft : model.draft,
                    candidates: currentObservation.candidates,
                    observedRunningBundleIdentifiers: currentObservation.runningBundleIdentifiers,
                    candidateGeneration: editorWindowController.candidateGeneration,
                    runtimeContractFingerprint: runtimeContractFingerprint
                )
                activeBaselinePlan = prepared.newPolicy.managementEnabled
                    ? prepared.report.newBaselinePlan : nil
                activeRevealPlan = prepared.newPolicy.managementEnabled
                    ? prepared.report.newRevealPlan : nil
                try await managementLoop.synchronizeCommittedPolicy(
                    prepared.newPolicy,
                    baseline: prepared.report.newBaselinePlan
                )
                try await synchronizeInterfaceAfterCommit(
                    prepared.newPolicy,
                    previousModel: model
                )
            } catch {
                await reconcileManagementAfterFailure(prepared)
                editorWindowController.setStatus(
                    "Apply failed without broadening the reviewed scope: \(error.localizedDescription)",
                    isError: true
                )
            }
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
        previousModel: PolicyEditorViewModel
    ) async throws {
        let synchronized = try PolicyEditorViewModel(
            acceptedPolicy: accepted,
            candidateInventory: previousModel.candidateInventory,
            systemItems: previousModel.systemItems,
            blennyBundleIdentifier: previousModel.blennyBundleIdentifier
        )
        let hasBackup = try await persistentStore?.loadBackup() != nil
        editorModel = synchronized
        editingCore = nil
        recoveryAvailable = hasBackup
        statusItemController.setDraftHasChanges(false)
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
        guard let baseline = activeBaselinePlan,
              let reveal = activeRevealPlan,
              let accepted = editorModel?.acceptedPolicy else { return }
        ordinaryRevealTimeoutTask?.cancel()
        ordinaryRevealTimeoutTask = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                switch await managementLoop.state {
                case .active:
                    try await managementLoop.beginOrdinaryReveal(reveal)
                    presentManagementState(
                        await managementLoop.state,
                        persistedManagementEnabled: accepted.managementEnabled
                    )
                    ordinaryRevealTimeoutTask = Task { @MainActor [weak self] in
                        do {
                            try await Task.sleep(for: .seconds(30))
                        } catch {
                            return
                        }
                        await self?.endOrdinaryReveal(
                            baseline: baseline,
                            persistedManagementEnabled: accepted.managementEnabled
                        )
                    }
                case .ordinaryRevealSession:
                    await endOrdinaryReveal(
                        baseline: baseline,
                        persistedManagementEnabled: accepted.managementEnabled
                    )
                default:
                    break
                }
            } catch {
                await managementLoop.failClosed("ordinary reveal activation failed")
                presentManagementState(
                    await managementLoop.state,
                    persistedManagementEnabled: accepted.managementEnabled
                )
            }
        }
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

    private func showPreviewError(_ action: String, error: Error) {
        editorWindowController.setStatus(
            "Could not prepare \(action): \(error.localizedDescription)",
            isError: true
        )
    }

    private func makeCore(scope: PolicyValidationScope) throws -> PolicyEditingCore {
        guard let interfaceStore else {
            throw PolicyInterfaceWriteError.interfaceStoreUnavailable
        }
        let managementLoop = self.managementLoop
        return PolicyEditingCore(
            store: interfaceStore,
            blennyBundleIdentifier: try currentBundleIdentifier(),
            scope: scope,
            writerProvider: {
                try await managementLoop.writerForTransaction()
            }
        )
    }

    private func requestAccessibilityAccess() {
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
            create: true
        )
        let directory = applicationSupport
            .appendingPathComponent("Blenny", isDirectory: true)
            .appendingPathComponent("PersistentPolicyPrototype", isDirectory: true)
        return try PersistentBundlePolicyStore(
            policyURL: directory.appendingPathComponent("bundle-policies.json"),
            backupURL: directory.appendingPathComponent(
                "bundle-policies.previous.blenny-backup.json"
            )
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
