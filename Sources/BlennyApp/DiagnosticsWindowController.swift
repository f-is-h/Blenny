import AppKit
import BlennyCore

@MainActor
final class DiagnosticsWindowController: NSWindowController {
    private let permissionLabel = NSTextField(labelWithString: "Accessibility: Checking…")
    private let guidanceLabel = NSTextField(wrappingLabelWithString: "Choose Refresh to run one bounded, read-only scan. No polling is used.")
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private let requestAccessButton = NSButton(title: "Request Access…", target: nil, action: nil)
    private let openSettingsButton = NSButton(title: "Open Accessibility Settings", target: nil, action: nil)
    private let exportButton = NSButton(title: "Export JSON…", target: nil, action: nil)
    private let textView = NSTextView()
    private let onRefresh: () -> Void
    private let onRequestAccess: () -> Void
    private let onOpenSystemSettings: () -> Void
    private var currentReport: DiagnosticReport?

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
        window.title = "Blenny 0.0.1 — Read-only Accessibility Probe"
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
        if trusted {
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
            guidanceLabel.stringValue = "Captured \(report.items.count) relevant AX elements in \(report.durationMilliseconds) ms."
        } catch {
            textView.string = "Could not render diagnostic JSON: \(error.localizedDescription)"
        }
    }

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
        textView.string = "No scan has run yet. Grant Accessibility access if needed, then choose Refresh."
        textView.textContainerInset = NSSize(width: 10, height: 10)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = textView

        let contentStack = NSStackView(views: [permissionLabel, guidanceLabel, buttonRow, scrollView])
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
        panel.nameFieldStringValue = "Blenny-0.0.1-\(Self.fileTimestamp()).blenny-diagnostics.json"
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
