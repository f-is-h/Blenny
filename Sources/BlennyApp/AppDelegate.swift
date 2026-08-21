import AppKit
import BlennyCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let inventory = AccessibilityInventory()
    private var isRefreshing = false
    private var requestedAccessibilityThisLaunch = false

    private lazy var diagnosticsWindowController = DiagnosticsWindowController(
        onRefresh: { [weak self] in self?.refresh() },
        onRequestAccess: { [weak self] in self?.requestAccessibilityAccess() },
        onOpenSystemSettings: { [weak self] in self?.openAccessibilitySettings() }
    )

    private lazy var statusItemController = StatusItemController(
        onOpenDiagnostics: { [weak self] in self?.showDiagnostics() },
        onRefresh: { [weak self] in self?.refresh() },
        onRequestAccess: { [weak self] in self?.requestAccessibilityAccess() },
        onQuit: { NSApplication.shared.terminate(nil) }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = statusItemController
        updatePermissionPresentation()
        showDiagnostics()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func showDiagnostics() {
        diagnosticsWindowController.showWindow(nil)
        diagnosticsWindowController.window?.orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func refresh() {
        guard !isRefreshing else { return }

        isRefreshing = true
        let trusted = AccessibilityAuthorization.isTrusted
        let descriptors = runningApplicationDescriptors()
        diagnosticsWindowController.setRefreshing(true)
        statusItemController.setRefreshing(true)
        updatePermissionPresentation()

        Task { [weak self, inventory] in
            let report = await inventory.capture(
                applications: descriptors,
                accessibilityTrusted: trusted
            )
            guard let self else { return }
            self.isRefreshing = false
            self.diagnosticsWindowController.setRefreshing(false)
            self.statusItemController.setRefreshing(false)
            self.diagnosticsWindowController.display(report: report)
            self.updatePermissionPresentation()
        }
    }

    private func requestAccessibilityAccess() {
        if AccessibilityAuthorization.isTrusted {
            updatePermissionPresentation()
            return
        }

        guard !requestedAccessibilityThisLaunch else {
            openAccessibilitySettings()
            diagnosticsWindowController.showPermissionMessage(
                "The system prompt was already requested during this launch. Enable Blenny under Privacy & Security › Accessibility, then return and choose Refresh."
            )
            return
        }

        requestedAccessibilityThisLaunch = true
        _ = AccessibilityAuthorization.requestSystemPrompt()
        updatePermissionPresentation()
        diagnosticsWindowController.showPermissionMessage(
            "Enable Blenny under Privacy & Security › Accessibility. The probe will not keep prompting; return here and choose Refresh after granting access."
        )
    }

    private func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func updatePermissionPresentation() {
        let trusted = AccessibilityAuthorization.isTrusted
        diagnosticsWindowController.setAccessibilityTrusted(trusted)
        statusItemController.setAccessibilityTrusted(trusted)
    }

    private func runningApplicationDescriptors() -> [RunningApplicationDescriptor] {
        var applications = NSWorkspace.shared.runningApplications
        applications.append(
            contentsOf: NSRunningApplication.runningApplications(
                withBundleIdentifier: "com.apple.MenuBarAgent"
            )
        )

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
}
