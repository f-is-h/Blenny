import AppKit
import BlennyCore

@MainActor
final class PolicyReviewWindowController: NSWindowController {
    private let actionLabel = NSTextField(labelWithString: "")
    private let reportView = NSTextView()
    private let safetyLabel = NSTextField(wrappingLabelWithString: "")
    private let applyButton = NSButton(title: "Apply", target: nil, action: nil)
    private var prepared: PreparedPolicyEdit?
    private var onApply: ((PreparedPolicyEdit) -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Review Policy Plan"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        configureContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(
        actionTitle: String,
        report: PolicyDryRunImpactReport,
        prepared: PreparedPolicyEdit?,
        onApply: @escaping (PreparedPolicyEdit) -> Void
    ) {
        self.prepared = prepared
        self.onApply = onApply
        actionLabel.stringValue = actionTitle
        reportView.string = report.text
        reportView.scrollRangeToVisible(NSRange(location: 0, length: 0))

        let requiresAssertion = prepared.map { edit in
            edit.newPolicy != edit.oldPolicy
                && (edit.oldPolicy.managementEnabled || edit.newPolicy.managementEnabled)
        } ?? false
        applyButton.isEnabled = prepared != nil && !requiresAssertion
        if prepared == nil {
            safetyLabel.stringValue = "Apply is unavailable because validation failed. Review every FAIL line above, refresh the bounded observation, and try again."
            safetyLabel.textColor = .systemRed
        } else if requiresAssertion {
            safetyLabel.stringValue = "Preview only — this plan would create or restore a macOS 27 assertion. Run the installed Debug dry-run, review the exact fingerprints and recovery plan, then provide explicit authorization before any real write."
            safetyLabel.textColor = .systemOrange
        } else {
            safetyLabel.stringValue = "Ready to apply. This plan does not create a system assertion; it only saves disabled policy intent or confirms a no-op."
            safetyLabel.textColor = .secondaryLabelColor
        }

        showWindow(nil)
        window?.orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        actionLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        actionLabel.textColor = .labelColor

        reportView.isEditable = false
        reportView.isRichText = false
        reportView.isAutomaticQuoteSubstitutionEnabled = false
        reportView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        reportView.textColor = .labelColor
        reportView.backgroundColor = .textBackgroundColor
        reportView.textContainerInset = NSSize(width: 12, height: 12)
        reportView.setAccessibilityLabel("Deterministic policy diff, impact report, validation, and recovery plan")

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = reportView

        safetyLabel.maximumNumberOfLines = 3

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        applyButton.target = self
        applyButton.action = #selector(apply)
        applyButton.keyEquivalent = "\r"
        let buttonRow = NSStackView(views: [NSView(), cancelButton, applyButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8

        let stack = NSStackView(views: [actionLabel, scrollView, safetyLabel, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 430),
            safetyLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    @objc private func cancel() {
        close()
    }

    @objc private func apply() {
        guard let prepared else { return }
        close()
        onApply?(prepared)
    }
}
