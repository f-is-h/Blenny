#if DEBUG && BLENNY_GROUPED_FALLBACK_TRIAL
import AppKit

/// An opt-in presentation experiment. Both controls occupy one AppKit status
/// item, so other status items cannot be placed between them. No preference
/// setter, synthesized input, or coordinate-based action routing is involved.
@MainActor
final class GroupedStatusItemContent: NSView {
    final class Control: NSButton {
        private var primaryPressed = false
        private(set) var primaryDownCount = 0
        private(set) var primaryUpCount = 0
        private(set) var primaryDispatchCount = 0
        private(set) var lastPrimaryDispatchSucceeded = false

        // A menu-bar window does not become an ordinary key window. Accept its
        // first click and track real events explicitly instead of relying on
        // NSButtonCell's ordinary-window tracking inside NSStatusBarButton.
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            beginPrimaryPress()
        }

        override func mouseDragged(with event: NSEvent) {
            highlight(primaryPressed && isEnabled && contains(event))
        }

        override func mouseUp(with event: NSEvent) {
            guard finishPrimaryPress(inside: contains(event)) else { return }
            primaryDispatchCount += 1
            lastPrimaryDispatchSucceeded = sendAction(action, to: target)
        }

        override func cancelOperation(_ sender: Any?) {
            primaryPressed = false
            highlight(false)
        }

        private func contains(_ event: NSEvent) -> Bool {
            bounds.contains(convert(event.locationInWindow, from: nil))
        }

        // These transitions are also checked without posting any input event.
        func beginPrimaryPress() {
            primaryDownCount += 1
            primaryPressed = isEnabled && !isHidden
            highlight(primaryPressed)
        }

        func finishPrimaryPress(inside: Bool) -> Bool {
            primaryUpCount += 1
            let shouldDispatch = primaryPressed && inside && isEnabled && !isHidden
            primaryPressed = false
            highlight(false)
            return shouldDispatch
        }

        // Keyboard and accessibility activation retain NSButton's target/action.
        override func rightMouseDown(with event: NSEvent) {
            cancelOperation(nil)
        }
        override func rightMouseUp(with event: NSEvent) {
            guard isEnabled, contains(event) else { return }
            _ = sendAction(action, to: target)
        }

        var clickDiagnostic: String {
            "down=\(primaryDownCount),up=\(primaryUpCount),dispatch=\(primaryDispatchCount),sent=\(lastPrimaryDispatchSucceeded)"
        }
    }

    let fish = Control()
    let arrow = Control()
    private(set) var reservesArrow = false
    private var fishLeading: NSLayoutConstraint!
    private var sharedWidth: NSLayoutConstraint!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        for control in [arrow, fish] {
            control.translatesAutoresizingMaskIntoConstraints = false
            control.isBordered = false
            control.setButtonType(.momentaryChange)
            control.imagePosition = .imageOnly
            control.imageScaling = .scaleNone
            control.title = ""
            addSubview(control)
            NSLayoutConstraint.activate([
                control.topAnchor.constraint(equalTo: topAnchor),
                control.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
        fishLeading = fish.leadingAnchor.constraint(equalTo: leadingAnchor)
        sharedWidth = arrow.widthAnchor.constraint(equalTo: fish.widthAnchor)
        NSLayoutConstraint.activate([
            arrow.leadingAnchor.constraint(equalTo: leadingAnchor),
            arrow.trailingAnchor.constraint(equalTo: fish.leadingAnchor),
            fish.trailingAnchor.constraint(equalTo: trailingAnchor),
            fishLeading
        ])
        fish.setAccessibilityLabel("Open Blenny")
        fish.setAccessibilityHelp("Right-click for management and recovery actions.")
        fish.toolTip = "Open Blenny — right-click for menu"
        arrow.isHidden = true
    }

    required init?(coder: NSCoder) { nil }

    func update(fishImage: NSImage?, arrowImage: NSImage?, reservesArrow: Bool,
                showsArrow: Bool, canToggle: Bool, arrowHelp: String) {
        self.reservesArrow = reservesArrow
        // Deactivate before activating the alternative to avoid an intermediate
        // contradictory constraint set when the native overflow takes over.
        fishLeading.isActive = false
        sharedWidth.isActive = false
        if reservesArrow { sharedWidth.isActive = true }
        else { fishLeading.isActive = true }
        fish.image = fishImage
        fish.title = fishImage == nil ? "B" : ""
        fish.imagePosition = fishImage == nil ? .noImage : .imageOnly
        arrow.image = arrowImage
        arrow.isHidden = !showsArrow
        arrow.isEnabled = canToggle && showsArrow
        arrow.setAccessibilityElement(showsArrow)
        arrow.setAccessibilityLabel(arrowHelp)
        arrow.toolTip = arrowHelp
    }

    /// Detached-view validation: no NSStatusItem, window, or writer is created.
    static func validateDetachedLayout() -> Bool {
        let content = GroupedStatusItemContent(frame: NSRect(x: 0, y: 0, width: 60, height: 24))
        let host = NSStatusBarButton(frame: content.frame)
        host.addSubview(content)
        content.update(fishImage: nil, arrowImage: nil, reservesArrow: true,
            showsArrow: true, canToggle: true, arrowHelp: "Collapse Revealable Items")
        content.layoutSubtreeIfNeeded()
        guard content.arrow.frame.width == 30, content.fish.frame.width == 30,
              content.arrow.frame.maxX == content.fish.frame.minX,
              !content.arrow.isHidden, content.arrow.isEnabled,
              content.arrow !== content.fish,
              content.hitTest(NSPoint(x: 15, y: 12)) === content.arrow,
              content.hitTest(NSPoint(x: 45, y: 12)) === content.fish,
              host.hitTest(NSPoint(x: 15, y: 12)) === content.arrow,
              host.hitTest(NSPoint(x: 45, y: 12)) === content.fish else { return false }
        guard content.arrow.acceptsFirstMouse(for: nil),
              !content.arrow.finishPrimaryPress(inside: true) else { return false }
        content.arrow.beginPrimaryPress()
        guard content.arrow.finishPrimaryPress(inside: true),
              !content.arrow.finishPrimaryPress(inside: true) else { return false }
        content.arrow.beginPrimaryPress()
        guard !content.arrow.finishPrimaryPress(inside: false) else { return false }
        content.arrow.beginPrimaryPress()
        content.arrow.cancelOperation(nil)
        guard !content.arrow.finishPrimaryPress(inside: true) else { return false }
        content.arrow.beginPrimaryPress()
        content.arrow.isEnabled = false
        guard !content.arrow.finishPrimaryPress(inside: true) else { return false }
        content.arrow.beginPrimaryPress()
        content.arrow.isEnabled = true
        guard !content.arrow.finishPrimaryPress(inside: true) else { return false }
        content.update(fishImage: nil, arrowImage: nil, reservesArrow: false,
            showsArrow: false, canToggle: true, arrowHelp: "Expand Revealable Items")
        content.frame.size.width = 38
        content.layoutSubtreeIfNeeded()
        guard content.arrow.isHidden, !content.arrow.isEnabled,
              content.fish.frame.width == 38,
              content.fish.frame.minX == 0 else { return false }
        content.update(fishImage: nil, arrowImage: nil, reservesArrow: true,
            showsArrow: true, canToggle: false, arrowHelp: "Please wait")
        content.frame.size.width = 60
        content.layoutSubtreeIfNeeded()
        return content.arrow.frame.maxX == content.fish.frame.minX
            && content.fish.frame.width == 30 && !content.arrow.isEnabled
            && content.fish.isEnabled
    }
}
#endif
