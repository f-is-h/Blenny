import AppKit
import BlennyCore

#if DEBUG
enum DebugLengthExperimentUpdate {
    case applied(length: CGFloat, durationSeconds: Int)
    case restored
}
#endif

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let permissionItem = NSMenuItem(title: "Accessibility: Checking…", action: nil, keyEquivalent: "")
    private let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
    private let menu = NSMenu()
    private let onOpenDiagnostics: () -> Void
    private let onRefresh: () -> Void
    private let onRequestAccess: () -> Void
    private let onQuit: () -> Void
    #if DEBUG
    private var lengthExperimentTask: Task<Void, Never>?
    private var revealPrototypeToggle: (() -> Void)?
    private var revealPrototypeEntryPoint: RevealEntryPoint?
    private var revealPrototypePresentation: RevealSessionPresentation = .baseline
    private var revealPrototypeEnabled = false
    private let revealPrototypeStateItem = NSMenuItem(
        title: "0.0.2 Revealable prototype: inactive",
        action: nil,
        keyEquivalent: ""
    )
    #endif

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

    #if DEBUG
    func configureDebugRevealPrototype(onToggle: @escaping () -> Void) {
        revealPrototypeToggle = onToggle
        revealPrototypeStateItem.isEnabled = false
        menu.insertItem(revealPrototypeStateItem, at: 0)
        menu.insertItem(.separator(), at: 1)

        guard let button = statusItem.button else { return }
        statusItem.menu = nil
        button.target = self
        button.action = #selector(handleStatusButton(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func updateDebugRevealPrototype(
        entryPoint: RevealEntryPoint?,
        presentation: RevealSessionPresentation,
        enabled: Bool,
        status: String
    ) {
        revealPrototypeEntryPoint = entryPoint
        revealPrototypePresentation = presentation
        revealPrototypeEnabled = enabled
        revealPrototypeStateItem.title = "0.0.2: \(status)"
        updateDebugRevealPrototypeButton()
    }

    func runDebugLengthExperiment(
        length: CGFloat,
        durationSeconds: Int = 8,
        onUpdate: @escaping (DebugLengthExperimentUpdate) -> Void
    ) {
        restoreStandardLength()
        statusItem.length = length
        onUpdate(.applied(length: length, durationSeconds: durationSeconds))

        lengthExperimentTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(durationSeconds))
            } catch {
                return
            }
            guard let self else { return }
            self.statusItem.length = NSStatusItem.variableLength
            self.lengthExperimentTask = nil
            onUpdate(.restored)
        }
    }

    func restoreDebugLengthExperiment(
        onUpdate: (DebugLengthExperimentUpdate) -> Void
    ) {
        restoreStandardLength()
        onUpdate(.restored)
    }

    private func restoreStandardLength() {
        lengthExperimentTask?.cancel()
        lengthExperimentTask = nil
        statusItem.length = NSStatusItem.variableLength
    }
    #endif

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
        button.toolTip = "Blenny 0.0.2 Revealable technical prototype"
    }

    private func configureMenu() {
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

    #if DEBUG
    @objc private func handleStatusButton(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp
            || revealPrototypeEntryPoint != .blennyFallback
            || !revealPrototypeEnabled {
            menu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: statusItem.button?.bounds.height ?? 0),
                in: statusItem.button
            )
            return
        }
        revealPrototypeToggle?()
    }

    private func updateDebugRevealPrototypeButton() {
        guard let button = statusItem.button else { return }
        let symbolName: String
        let accessibilityDescription: String
        if revealPrototypeEntryPoint == .blennyFallback {
            if revealPrototypePresentation == .baseline {
                symbolName = "chevron.right.2"
                accessibilityDescription = "Reveal Revealable menu bar items"
            } else {
                symbolName = "chevron.left.2"
                accessibilityDescription = "Conceal Revealable menu bar items"
            }
        } else {
            symbolName = "rectangle.3.group"
            accessibilityDescription = "Blenny diagnostics; use native overflow"
        }
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityDescription
        )
        image?.isTemplate = true
        button.image = image
        button.isEnabled = true
        button.toolTip = revealPrototypeStateItem.title
        button.setAccessibilityLabel(accessibilityDescription)
    }
    #endif

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
