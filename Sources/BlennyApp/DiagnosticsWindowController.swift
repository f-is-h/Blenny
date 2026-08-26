import AppKit
import BlennyCore

@MainActor
final class DiagnosticsWindowController: NSWindowController {
    private let permissionLabel = NSTextField(labelWithString: "Accessibility: Checking…")
    private let guidanceLabel = NSTextField(wrappingLabelWithString: "Choose Refresh to run one bounded, read-only scan. No polling is used.")
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private let requestAccessButton = NSButton(title: "Request Access…", target: nil, action: nil)
    private let openSettingsButton = NSButton(title: "Open Device Control Settings", target: nil, action: nil)
    private let exportButton = NSButton(title: "Export JSON…", target: nil, action: nil)
    private let textView = NSTextView()
    private let onRefresh: () -> Void
    private let onRequestAccess: () -> Void
    private let onOpenSystemSettings: () -> Void
    private var currentReport: DiagnosticReport?
    #if DEBUG
    private let debugLengthPopup = NSPopUpButton()
    private let debugRunLengthButton = NSButton(title: "Run 8-Second Pulse", target: nil, action: nil)
    private let debugRestoreLengthButton = NSButton(title: "Restore Now", target: nil, action: nil)
    private let debugLengthStatusLabel = NSTextField(labelWithString: "Standard variable length is active.")
    private var onRunDebugLengthExperiment: ((CGFloat) -> Void)?
    private var onRestoreDebugLengthExperiment: (() -> Void)?
    private let debugLengths: [CGFloat] = [80, 160, 320]
    #endif

    init(
        onRefresh: @escaping () -> Void,
        onRequestAccess: @escaping () -> Void,
        onOpenSystemSettings: @escaping () -> Void
    ) {
        self.onRefresh = onRefresh
        self.onRequestAccess = onRequestAccess
        self.onOpenSystemSettings = onOpenSystemSettings

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        #if DEBUG
        window.title = "Blenny 0.0.3 — Revealable + Hidden Coexistence (Debug)"
        #else
        window.title = "Blenny 0.0.3 — Read-only Accessibility Probe"
        #endif
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)

        configureContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setAccessibilityTrusted(_ trusted: Bool) {
        permissionLabel.stringValue = trusted ? "Accessibility: Granted" : "Accessibility: Not Granted"
        permissionLabel.textColor = trusted ? .systemGreen : .systemOrange
        requestAccessButton.isEnabled = !trusted
        if trusted, currentReport == nil {
            guidanceLabel.stringValue = "Ready. Choose Refresh to run one bounded, read-only scan."
        }
    }

    func showPermissionMessage(_ message: String) {
        guidanceLabel.stringValue = message
    }

    func setRefreshing(_ refreshing: Bool) {
        refreshButton.isEnabled = !refreshing
        refreshButton.title = refreshing ? "Refreshing…" : "Refresh"
    }

    func display(report: DiagnosticReport) {
        currentReport = report
        exportButton.isEnabled = true
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(report)
            textView.string = String(decoding: data, as: UTF8.self)
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            guidanceLabel.stringValue = "Captured \(report.items.count) relevant AX elements in \(report.durationMilliseconds) ms."
        } catch {
            textView.string = "Could not render diagnostic JSON: \(error.localizedDescription)"
        }
    }

    #if DEBUG
    func configureDebugLengthExperiment(
        onRun: @escaping (CGFloat) -> Void,
        onRestore: @escaping () -> Void
    ) {
        onRunDebugLengthExperiment = onRun
        onRestoreDebugLengthExperiment = onRestore
    }

    func displayDebugLengthUpdate(_ update: DebugLengthExperimentUpdate) {
        switch update {
        case let .applied(length, durationSeconds):
            debugLengthStatusLabel.stringValue = "Applied \(Int(length)) pt to Blenny only; automatic restore in \(durationSeconds) seconds."
            debugRunLengthButton.isEnabled = false
            debugLengthPopup.isEnabled = false
            debugRestoreLengthButton.isEnabled = true
        case .restored:
            debugLengthStatusLabel.stringValue = "Restored NSStatusItem.variableLength."
            debugRunLengthButton.isEnabled = true
            debugLengthPopup.isEnabled = true
            debugRestoreLengthButton.isEnabled = false
        }
    }
    #endif

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        permissionLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        guidanceLabel.textColor = .secondaryLabelColor
        guidanceLabel.maximumNumberOfLines = 3

        refreshButton.target = self
        refreshButton.action = #selector(refresh)
        refreshButton.keyEquivalent = "\r"
        requestAccessButton.target = self
        requestAccessButton.action = #selector(requestAccess)
        openSettingsButton.target = self
        openSettingsButton.action = #selector(openSettings)
        exportButton.target = self
        exportButton.action = #selector(exportJSON)
        exportButton.isEnabled = false

        let buttonRow = NSStackView(views: [
            refreshButton,
            requestAccessButton,
            openSettingsButton,
            exportButton
        ])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8

        textView.isEditable = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.string = "No scan has run yet. Grant Device Control and Data Access if needed, then choose Refresh."
        textView.textContainerInset = NSSize(width: 10, height: 10)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let initialTextSize = NSSize(width: 860, height: 500)
        textView.frame = NSRect(origin: .zero, size: initialTextSize)
        textView.minSize = NSSize(width: 0, height: initialTextSize.height)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: initialTextSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView

        var contentViews: [NSView] = [permissionLabel, guidanceLabel, buttonRow]
        #if DEBUG
        contentViews.append(makeDebugLengthExperimentView())
        #endif
        contentViews.append(scrollView)

        let contentStack = NSStackView(views: contentViews)
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentStack)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            guidanceLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 420)
        ])
    }

    #if DEBUG
    private func makeDebugLengthExperimentView() -> NSView {
        let warningLabel = NSTextField(wrappingLabelWithString: "DEBUG EXPERIMENT — Changes only Blenny's own NSStatusItem.length. Each pulse is bounded and automatically restores the standard variable length.")
        warningLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        warningLabel.textColor = .systemOrange
        warningLabel.maximumNumberOfLines = 2

        debugLengthPopup.addItems(withTitles: debugLengths.map { "\(Int($0)) pt" })
        debugLengthPopup.selectItem(at: 1)
        debugRunLengthButton.target = self
        debugRunLengthButton.action = #selector(runDebugLengthExperiment)
        debugRestoreLengthButton.target = self
        debugRestoreLengthButton.action = #selector(restoreDebugLengthExperiment)
        debugRestoreLengthButton.isEnabled = false
        debugLengthStatusLabel.textColor = .secondaryLabelColor

        let controls = NSStackView(views: [
            debugLengthPopup,
            debugRunLengthButton,
            debugRestoreLengthButton,
            debugLengthStatusLabel
        ])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 8

        let stack = NSStackView(views: [warningLabel, controls])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
    }

    @objc private func runDebugLengthExperiment() {
        let index = debugLengthPopup.indexOfSelectedItem
        guard debugLengths.indices.contains(index) else { return }
        onRunDebugLengthExperiment?(debugLengths[index])
    }

    @objc private func restoreDebugLengthExperiment() {
        onRestoreDebugLengthExperiment?()
    }
    #endif

    @objc private func refresh() {
        onRefresh()
    }

    @objc private func requestAccess() {
        onRequestAccess()
    }

    @objc private func openSettings() {
        onOpenSystemSettings()
    }

    @objc private func exportJSON() {
        guard let report = currentReport, let window else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Blenny-0.0.3-\(Self.fileTimestamp()).blenny-diagnostics.json"
        panel.message = "Exports only menu-bar Accessibility metadata shown in this window."
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let destination = panel.url else { return }
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                try encoder.encode(report).write(to: destination, options: .atomic)
                self?.guidanceLabel.stringValue = "Diagnostic JSON exported successfully."
            } catch {
                self?.presentExportError(error)
            }
        }
    }

    private func presentExportError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could Not Export Diagnostics"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    private static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
