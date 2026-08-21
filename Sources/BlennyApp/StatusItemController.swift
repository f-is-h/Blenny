import AppKit

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let permissionItem = NSMenuItem(title: "Accessibility: Checking…", action: nil, keyEquivalent: "")
    private let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
    private let onOpenDiagnostics: () -> Void
    private let onRefresh: () -> Void
    private let onRequestAccess: () -> Void
    private let onQuit: () -> Void

    init(
        onOpenDiagnostics: @escaping () -> Void,
        onRefresh: @escaping () -> Void,
        onRequestAccess: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onOpenDiagnostics = onOpenDiagnostics
        self.onRefresh = onRefresh
        self.onRequestAccess = onRequestAccess
        self.onQuit = onQuit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureButton()
        configureMenu()
    }

    func setAccessibilityTrusted(_ trusted: Bool) {
        permissionItem.title = trusted ? "Accessibility: Granted" : "Accessibility: Not Granted"
    }

    func setRefreshing(_ refreshing: Bool) {
        refreshItem.isEnabled = !refreshing
        refreshItem.title = refreshing ? "Refreshing…" : "Refresh"
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(
            systemSymbolName: "rectangle.3.group",
            accessibilityDescription: "Blenny diagnostics"
        )
        image?.isTemplate = true
        button.image = image
        if image == nil {
            button.title = "B"
        }
        button.toolTip = "Blenny 0.0.1 Accessibility probe"
    }

    private func configureMenu() {
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open Diagnostics", action: #selector(openDiagnostics), keyEquivalent: "d")
        let requestItem = NSMenuItem(title: "Request Accessibility Access…", action: #selector(requestAccess), keyEquivalent: "")
        let quitItem = NSMenuItem(title: "Quit Blenny", action: #selector(quit), keyEquivalent: "q")

        for item in [openItem, refreshItem, requestItem, quitItem] {
            item.target = self
        }
        permissionItem.isEnabled = false

        menu.addItem(openItem)
        menu.addItem(refreshItem)
        menu.addItem(.separator())
        menu.addItem(permissionItem)
        menu.addItem(requestItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func openDiagnostics() {
        onOpenDiagnostics()
    }

    @objc private func refresh() {
        onRefresh()
    }

    @objc private func requestAccess() {
        onRequestAccess()
    }

    @objc private func quit() {
        onQuit()
    }
}
