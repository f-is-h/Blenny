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

    private let inventory = AccessibilityInventory()
    private var isRefreshing = false
    private var persistentStore: PersistentBundlePolicyStore?
    private var interfaceStore: PolicyInterfaceStore?
    private var editingCore: PolicyEditingCore?
    private var editorModel: PolicyEditorViewModel?
    private var ownershipSnapshot: MenuBarOwnershipSnapshot?
    private var observedRunningBundleIdentifiers = Set<String>()
    private var recoveryAvailable = false
    #if DEBUG
    private var policyCoexistenceController: DebugPolicyCoexistenceController?
    private var terminationRestoreInProgress = false
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
        guard let policyCoexistenceController,
              policyCoexistenceController.isRunning else {
            return .terminateNow
        }
        guard !terminationRestoreInProgress else { return .terminateLater }
        terminationRestoreInProgress = true
        Task { @MainActor in
            await policyCoexistenceController.stop()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
        #else
        return .terminateNow
        #endif
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        updatePermissionPresentation()
        updateLaunchAtLoginPresentation()
    }

    func applicationWillTerminate(_ notification: Notification) {
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
                "Enable Accessibility, then choose Refresh. No menu bar scan has run.",
                isError: false
            )
            return
        }

        isRefreshing = true
        let descriptors = runningApplicationDescriptors()
        statusItemController.setRefreshing(true)
        editorWindowController.setRefreshing(true)
        Task { [weak self, inventory] in
            let report = await inventory.capture(
                applications: descriptors,
                accessibilityTrusted: true
            )
            guard let self else { return }
            await self.completeRefresh(report: report)
        }
    }

    private func completeRefresh(report: DiagnosticReport) async {
        isRefreshing = false
        statusItemController.setRefreshing(false)
        editorWindowController.setRefreshing(false)

        let snapshot = MenuBarOwnershipSnapshotBuilder.make(from: report)
        ownershipSnapshot = snapshot
        guard snapshot.isComplete else {
            let detail = snapshot.issues.map(\.description).joined(separator: "; ")
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
            let core = PolicyEditingCore(
                store: interfaceStore,
                blennyBundleIdentifier: blennyBundleIdentifier,
                scope: model.validationScope,
                writerProvider: {
                    throw PolicyInterfaceWriteError.installedDryRunRequired
                }
            )
            let runningIdentifiers = Set(
                NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
            ).union([blennyBundleIdentifier])
            let hasBackup = try await store.loadBackup() != nil

            self.interfaceStore = interfaceStore
            editingCore = core
            editorModel = model
            observedRunningBundleIdentifiers = runningIdentifiers
            recoveryAvailable = hasBackup
            statusItemController.setManagementEnabled(
                accepted.managementEnabled,
                recoveryAvailable: hasBackup
            )
            statusItemController.setDraftHasChanges(model.hasDraftChanges)
            editorWindowController.display(
                model: model,
                observationCount: candidateInventory.candidates.count,
                recoveryAvailable: hasBackup
            )
        } catch {
            editingCore = nil
            editorWindowController.setStatus(
                "Could not prepare the policy editor: \(error.localizedDescription)",
                isError: true
            )
        }
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
                    observedRunningBundleIdentifiers: observedRunningBundleIdentifiers
                )
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
                    observedRunningBundleIdentifiers: observedRunningBundleIdentifiers
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
                    observedRunningBundleIdentifiers: observedRunningBundleIdentifiers
                )
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
                    observedRunningBundleIdentifiers: observedRunningBundleIdentifiers
                )
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
            && (prepared.oldPolicy.managementEnabled || prepared.newPolicy.managementEnabled)
        guard !changesSystemAssertion else {
            editorWindowController.setStatus(
                PolicyInterfaceWriteError.installedDryRunRequired.localizedDescription,
                isError: true
            )
            return
        }
        guard let core = editingCore else { return }
        editorWindowController.setStatus("Applying reviewed policy intent…", isError: false)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                _ = try await core.commit(prepared)
                editorWindowController.setStatus(
                    "Reviewed policy intent applied. No system assertion was created.",
                    isError: false
                )
                refresh()
            } catch {
                editorWindowController.setStatus(
                    "Apply failed without broadening system access: \(error.localizedDescription)",
                    isError: true
                )
            }
        }
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
        return PolicyEditingCore(
            store: interfaceStore,
            blennyBundleIdentifier: try currentBundleIdentifier(),
            scope: scope,
            writerProvider: {
                throw PolicyInterfaceWriteError.installedDryRunRequired
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
                "The one-time system prompt was requested. Enable Blenny, then return and choose Refresh.",
                isError: false
            )
        case .openSystemSettings:
            openAccessibilitySettings()
            editorWindowController.setStatus(
                "The system prompt will not be repeated. Enable Blenny in Device Control and Data Access, then choose Refresh.",
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
