import AppKit
import BlennyCore

#if DEBUG
enum DebugLengthExperimentUpdate {
    case applied(length: CGFloat, durationSeconds: Int)
    case restored
}

private final class DebugStatusItemContentStack: NSStackView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
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
    private static let placementEnvironmentKey = "BLENNY_ENABLE_0_0_5_SELF_POSITION"
    private static let placementAutosaveName = "Blenny0.0.5Validation"
    private static let placementPreferenceKey =
        "NSStatusItem Preferred Position \(placementAutosaveName)"
    private static let placementValue = 500

    private let placementProbeEnabled: Bool
    private let originalPersistentPlacement: Any?
    private var placementRestored = false
    private var lengthExperimentTask: Task<Void, Never>?
    private var revealPrototypeToggle: (() -> Void)?
    private var stopManagingAndRestore: (() -> Void)?
    private var revealPrototypeEntryPoint: RevealEntryPoint?
    private var revealPrototypePresentation: RevealSessionPresentation = .baseline
    private var revealPrototypeEnabled = false
    private var revealPrototypeContentStack: DebugStatusItemContentStack?
    private var revealPrototypeArrowImageView: NSImageView?
    private let revealPrototypeStateItem = NSMenuItem(
        title: "0.0.5 Policy Editing Core validation: inactive",
        action: nil,
        keyEquivalent: ""
    )
    private let stopManagingItem = NSMenuItem(
        title: "Stop Managing and Restore",
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
        #if DEBUG
        let placementProbeEnabled = ProcessInfo.processInfo.environment[
            Self.placementEnvironmentKey
        ] == "YES"
        self.placementProbeEnabled = placementProbeEnabled
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            self.originalPersistentPlacement = UserDefaults.standard
                .persistentDomain(forName: bundleIdentifier)?[
                    Self.placementPreferenceKey
                ]
        } else {
            self.originalPersistentPlacement = nil
        }
        if placementProbeEnabled {
            // Registration-domain defaults are process-scoped. The explicit
            // cleanup below also removes any same-name value AppKit may persist.
            UserDefaults.standard.register(defaults: [
                Self.placementPreferenceKey: Self.placementValue
            ])
        }
        #endif
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        #if DEBUG
        if placementProbeEnabled {
            statusItem.autosaveName = Self.placementAutosaveName
            Self.debugLog(
                "BLENNY_0_0_5 self_position=\(Self.placementValue) "
                    + "autosave=\(Self.placementAutosaveName) persistence=registration_domain"
            )
        }
        #endif

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
    func configureDebugRevealPrototype(
        onToggle: @escaping () -> Void,
        onStopManagingAndRestore: @escaping () -> Void
    ) {
        revealPrototypeToggle = onToggle
        stopManagingAndRestore = onStopManagingAndRestore
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
        revealPrototypeStateItem.title = "0.0.5: \(status)"
        updateDebugRevealPrototypeButton()
    }

    func setDebugStopManagingEnabled(_ enabled: Bool) {
        stopManagingItem.isEnabled = enabled
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

    func restoreDebugStatusItemPlacement() {
        guard placementProbeEnabled, !placementRestored else { return }
        placementRestored = true
        if let originalPersistentPlacement {
            UserDefaults.standard.set(
                originalPersistentPlacement,
                forKey: Self.placementPreferenceKey
            )
        } else {
            UserDefaults.standard.removeObject(forKey: Self.placementPreferenceKey)
        }
        _ = UserDefaults.standard.synchronize()
        Self.debugLog("BLENNY_0_0_5 self_position_restored=true")
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
        #if DEBUG
        button.toolTip = "Blenny 0.0.5 Policy Editing Core technical validation"
        #else
        button.toolTip = "Blenny 0.0.5 read-only Accessibility probe"
        #endif
    }

    private func configureMenu() {
        let openItem = NSMenuItem(title: "Open Diagnostics", action: #selector(openDiagnostics), keyEquivalent: "d")
        let requestItem = NSMenuItem(title: "Request Accessibility Access…", action: #selector(requestAccess), keyEquivalent: "")
        let quitItem = NSMenuItem(title: "Quit Blenny", action: #selector(quit), keyEquivalent: "q")

        for item in [openItem, refreshItem, requestItem, quitItem] {
            item.target = self
        }
        #if DEBUG
        stopManagingItem.target = self
        stopManagingItem.action = #selector(stopManaging)
        stopManagingItem.isEnabled = false
        #endif
        permissionItem.isEnabled = false

        menu.addItem(openItem)
        menu.addItem(refreshItem)
        menu.addItem(.separator())
        menu.addItem(permissionItem)
        menu.addItem(requestItem)
        #if DEBUG
        menu.addItem(.separator())
        menu.addItem(stopManagingItem)
        #endif
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
        let arrowSymbolName: String?
        let accessibilityDescription: String
        if revealPrototypeEntryPoint == .blennyFallback {
            if revealPrototypePresentation == .baseline {
                arrowSymbolName = "chevron.right.2"
                accessibilityDescription = "Reveal Revealable menu bar items"
            } else {
                arrowSymbolName = "chevron.left.2"
                accessibilityDescription = "Conceal Revealable menu bar items"
            }
        } else if revealPrototypeEntryPoint == .nativeOverflow {
            if revealPrototypePresentation == .baseline {
                arrowSymbolName = "chevron.right.2"
                accessibilityDescription =
                    "Blenny status: native overflow controls reveal; currently collapsed"
            } else {
                arrowSymbolName = "chevron.left.2"
                accessibilityDescription =
                    "Blenny status: native overflow controls reveal; currently expanded"
            }
        } else {
            arrowSymbolName = nil
            accessibilityDescription = "Blenny diagnostics"
        }
        if let arrowSymbolName {
            let arrowImageView = ensureDebugPrototypeContent(in: button)
            let arrowImage = NSImage(
                systemSymbolName: arrowSymbolName,
                accessibilityDescription: nil
            )
            arrowImage?.isTemplate = true
            arrowImageView.image = arrowImage
            statusItem.length = 48
        } else {
            removeDebugPrototypeContent()
            let blennyImage = NSImage(
                systemSymbolName: "rectangle.3.group",
                accessibilityDescription: "Blenny"
            )
            blennyImage?.isTemplate = true
            button.image = blennyImage
            button.imageScaling = .scaleNone
            button.imagePosition = .imageOnly
            statusItem.length = NSStatusItem.variableLength
        }
        button.isEnabled = true
        button.toolTip = revealPrototypeStateItem.title
        button.setAccessibilityLabel(accessibilityDescription)
        Self.debugLog(
            "BLENNY_0_0_5 status_item_length=\(statusItem.length) "
                + "arrow=\(arrowSymbolName ?? "none") native_symbol_views=true"
        )
    }

    private func ensureDebugPrototypeContent(
        in button: NSStatusBarButton
    ) -> NSImageView {
        if let revealPrototypeArrowImageView {
            return revealPrototypeArrowImageView
        }

        let blennyImage = NSImage(
            systemSymbolName: "rectangle.3.group",
            accessibilityDescription: nil
        )
        blennyImage?.isTemplate = true
        let blennyImageView = NSImageView(image: blennyImage ?? NSImage())
        blennyImageView.imageScaling = .scaleNone
        blennyImageView.contentTintColor = .controlTextColor

        let arrowImageView = NSImageView()
        arrowImageView.imageScaling = .scaleNone
        arrowImageView.contentTintColor = .controlTextColor

        let stack = DebugStatusItemContentStack(
            views: [blennyImageView, arrowImageView]
        )
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setAccessibilityElement(false)

        button.image = nil
        button.attributedTitle = NSAttributedString()
        button.title = ""
        button.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])

        revealPrototypeContentStack = stack
        revealPrototypeArrowImageView = arrowImageView
        return arrowImageView
    }

    private func removeDebugPrototypeContent() {
        revealPrototypeContentStack?.removeFromSuperview()
        revealPrototypeContentStack = nil
        revealPrototypeArrowImageView = nil
    }

    private static func debugLog(_ message: String) {
        guard let data = "\(message)\n".data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
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

    #if DEBUG
    @objc private func stopManaging() {
        stopManagingAndRestore?()
    }
    #endif

    @objc private func quit() {
        onQuit()
    }
}
