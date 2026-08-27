import AppKit
import BlennyCore

private final class PolicyBundleButton: NSButton {
    let bundleIdentifier: String

    init(bundleIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
final class PolicyEditorWindowController: NSWindowController {
    typealias AssignmentHandler = (String, MenuBarBundlePolicy) -> Void

    private static let preferredContentSize = NSSize(width: 820, height: 720)
    private static let minimumContentSize = NSSize(width: 760, height: 620)

    private let titleLabel = NSTextField(labelWithString: "Blenny")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "Set bundle-level menu bar intent. Changes stay local until you review and apply them.")
    private let managementLabel = NSTextField(labelWithString: "Management: Checking…")
    private let observationLabel = NSTextField(labelWithString: "No menu bar observation yet.")
    private let permissionBox = NSBox()
    private let permissionLabel = NSTextField(wrappingLabelWithString: "")
    private let permissionButton = NSButton(title: "Set Up Accessibility…", target: nil, action: nil)
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let moveLabel = NSTextField(labelWithString: "Select a bundle to change its group.")
    private let moveControl = NSSegmentedControl(
        labels: ["Pinned", "Revealable", "Hidden"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let discardButton = NSButton(title: "Discard Draft", target: nil, action: nil)
    private let reviewButton = NSButton(title: "Review Changes…", target: nil, action: nil)
    private let resumeButton = NSButton(title: "Resume Managing…", target: nil, action: nil)
    private let stopButton = NSButton(title: "Stop Managing…", target: nil, action: nil)
    private let restoreButton = NSButton(title: "Restore Previous Policy…", target: nil, action: nil)
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private var groupStacks: [MenuBarBundlePolicy: NSStackView] = [:]
    private var groupScrollViews: [MenuBarBundlePolicy: NSScrollView] = [:]
    private var model: PolicyEditorViewModel?
    private var selectedBundleIdentifier: String?
    private var isRefreshing = false
    private var isRecoveryAvailable = false

    private let onAssign: AssignmentHandler
    private let onReview: () -> Void
    private let onDiscard: () -> Void
    private let onRefresh: () -> Void
    private let onRequestAccess: () -> Void
    private let onResumeManaging: () -> Void
    private let onStopManaging: () -> Void
    private let onRestorePreviousPolicy: () -> Void

    init(
        onAssign: @escaping AssignmentHandler,
        onReview: @escaping () -> Void,
        onDiscard: @escaping () -> Void,
        onRefresh: @escaping () -> Void,
        onRequestAccess: @escaping () -> Void,
        onResumeManaging: @escaping () -> Void,
        onStopManaging: @escaping () -> Void,
        onRestorePreviousPolicy: @escaping () -> Void
    ) {
        self.onAssign = onAssign
        self.onReview = onReview
        self.onDiscard = onDiscard
        self.onRefresh = onRefresh
        self.onRequestAccess = onRequestAccess
        self.onResumeManaging = onResumeManaging
        self.onStopManaging = onStopManaging
        self.onRestorePreviousPolicy = onRestorePreviousPolicy

        let window = NSWindow(
            contentRect: NSRect(
                origin: .zero,
                size: Self.preferredContentSize
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Blenny 0.1.0"
        window.contentMinSize = Self.minimumContentSize
        window.isRestorable = false
        let contentViewController = NSViewController()
        contentViewController.view = NSView(
            frame: NSRect(origin: .zero, size: Self.preferredContentSize)
        )
        contentViewController.preferredContentSize = Self.preferredContentSize
        window.contentViewController = contentViewController
        window.setContentSize(Self.preferredContentSize)
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        configureContent()
        updateControls()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showEditor() {
        showWindow(nil)
        restoreUsableWindowSizeIfNeeded()
        window?.orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func restoreUsableWindowSizeIfNeeded() {
        guard let window else { return }
        window.contentMinSize = Self.minimumContentSize
        let contentSize = window.contentLayoutRect.size
        let needsWindowReset = contentSize.width < Self.minimumContentSize.width
            || contentSize.height < Self.minimumContentSize.height

        if needsWindowReset {
            let visibleSize = (window.screen ?? NSScreen.main)?.visibleFrame.size
            let targetSize = NSSize(
                width: min(
                    Self.preferredContentSize.width,
                    max(Self.minimumContentSize.width, (visibleSize?.width ?? 900) - 80)
                ),
                height: min(
                    Self.preferredContentSize.height,
                    max(Self.minimumContentSize.height, (visibleSize?.height ?? 800) - 80)
                )
            )
            window.setContentSize(targetSize)
            window.center()
        }
    }

    func setAccessibilityTrusted(
        _ trusted: Bool,
        hasRequestedSystemPrompt: Bool
    ) {
        permissionBox.isHidden = trusted
        if trusted {
            permissionLabel.stringValue = ""
        } else if hasRequestedSystemPrompt {
            permissionLabel.stringValue = "Accessibility access is still off. Blenny will not repeat the system prompt; open Device Control and Data Access, enable Blenny, then refresh."
            permissionButton.title = "Open Settings"
        } else {
            permissionLabel.stringValue = "Blenny needs Accessibility only for a bounded, read-only scan of current menu bar ownership. It never scans continuously."
            permissionButton.title = "Set Up Accessibility…"
        }
        updateControls()
    }

    func setRefreshing(_ refreshing: Bool) {
        isRefreshing = refreshing
        refreshButton.title = refreshing ? "Refreshing…" : "Refresh"
        updateControls()
    }

    func display(
        model: PolicyEditorViewModel,
        observationCount: Int,
        recoveryAvailable: Bool
    ) {
        self.model = model
        isRecoveryAvailable = recoveryAvailable
        if let selectedBundleIdentifier,
           !model.candidateInventory.bundleIdentifiers.contains(selectedBundleIdentifier) {
            self.selectedBundleIdentifier = nil
        }
        managementLabel.stringValue = model.acceptedPolicy.managementEnabled
            ? "Management: On"
            : "Management: Stopped — draft edits are safe and local"
        managementLabel.textColor = model.acceptedPolicy.managementEnabled
            ? .systemGreen : .secondaryLabelColor
        observationLabel.stringValue = "Bounded read-only observation: \(observationCount) bundle owner\(observationCount == 1 ? "" : "s"). Manual refresh only; no polling."
        renderGroups()
        setStatus(
            model.hasDraftChanges
                ? "Draft has unapplied changes."
                : "Draft matches the accepted policy and current candidate defaults.",
            isError: false
        )
        updateControls()
    }

    func setStatus(_ message: String, isError: Bool) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(
                greaterThanOrEqualToConstant: Self.minimumContentSize.width
            ),
            contentView.heightAnchor.constraint(
                greaterThanOrEqualToConstant: Self.minimumContentSize.height
            ),
        ])

        titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 2
        managementLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        observationLabel.font = .systemFont(ofSize: 11, weight: .regular)
        observationLabel.textColor = .tertiaryLabelColor

        permissionBox.boxType = .custom
        permissionBox.cornerRadius = 8
        permissionBox.borderWidth = 1
        permissionBox.borderColor = .systemOrange.withAlphaComponent(0.45)
        permissionBox.fillColor = .systemOrange.withAlphaComponent(0.08)
        permissionLabel.maximumNumberOfLines = 3
        permissionButton.target = self
        permissionButton.action = #selector(requestAccess)
        let permissionStack = NSStackView(views: [permissionLabel, permissionButton])
        permissionStack.orientation = .vertical
        permissionStack.alignment = .leading
        permissionStack.spacing = 8
        permissionStack.translatesAutoresizingMaskIntoConstraints = false
        permissionBox.contentView?.addSubview(permissionStack)
        if let permissionContent = permissionBox.contentView {
            NSLayoutConstraint.activate([
                permissionStack.leadingAnchor.constraint(equalTo: permissionContent.leadingAnchor, constant: 12),
                permissionStack.trailingAnchor.constraint(equalTo: permissionContent.trailingAnchor, constant: -12),
                permissionStack.topAnchor.constraint(equalTo: permissionContent.topAnchor, constant: 10),
                permissionStack.bottomAnchor.constraint(equalTo: permissionContent.bottomAnchor, constant: -10),
                permissionLabel.widthAnchor.constraint(equalTo: permissionStack.widthAnchor),
            ])
        }

        let policyLanes = NSStackView(views: MenuBarBundlePolicy.allCases.map(makeLane))
        policyLanes.orientation = .vertical
        policyLanes.alignment = .leading
        policyLanes.distribution = .fillEqually
        policyLanes.spacing = 10

        moveControl.target = self
        moveControl.action = #selector(moveSelection)
        moveControl.setAccessibilityLabel("Move selected bundle to policy group")
        let moveRow = NSStackView(views: [moveLabel, moveControl])
        moveRow.orientation = .horizontal
        moveRow.alignment = .centerY
        moveRow.spacing = 12

        refreshButton.target = self
        refreshButton.action = #selector(refresh)
        discardButton.target = self
        discardButton.action = #selector(discardDraft)
        reviewButton.target = self
        reviewButton.action = #selector(reviewChanges)
        reviewButton.keyEquivalent = "\r"
        let draftActions = NSStackView(views: [refreshButton, NSView(), discardButton, reviewButton])
        draftActions.orientation = .horizontal
        draftActions.alignment = .centerY
        draftActions.spacing = 8

        let recoveryTitle = NSTextField(labelWithString: "Management recovery")
        recoveryTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        let recoveryHelp = NSTextField(wrappingLabelWithString: "Resume, stop, and restore always open the same deterministic review used by the 0.0.5 policy core.")
        recoveryHelp.textColor = .secondaryLabelColor
        recoveryHelp.maximumNumberOfLines = 2
        for (button, action) in [
            (resumeButton, #selector(resumeManaging)),
            (stopButton, #selector(stopManaging)),
            (restoreButton, #selector(restorePreviousPolicy)),
        ] {
            button.target = self
            button.action = action
        }
        let recoveryButtons = NSStackView(views: [resumeButton, stopButton, restoreButton])
        recoveryButtons.orientation = .horizontal
        recoveryButtons.alignment = .centerY
        recoveryButtons.spacing = 8
        let recoveryStack = NSStackView(views: [recoveryTitle, recoveryHelp, recoveryButtons])
        recoveryStack.orientation = .vertical
        recoveryStack.alignment = .leading
        recoveryStack.spacing = 6

        statusLabel.maximumNumberOfLines = 2
        let header = NSStackView(views: [titleLabel, subtitleLabel, managementLabel, observationLabel])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 4

        let separator = NSBox()
        separator.boxType = .separator
        let mainStack = NSStackView(views: [
            header,
            permissionBox,
            policyLanes,
            moveRow,
            statusLabel,
            draftActions,
            separator,
            recoveryStack,
        ])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        permissionBox.translatesAutoresizingMaskIntoConstraints = false
        policyLanes.translatesAutoresizingMaskIntoConstraints = false
        draftActions.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            mainStack.widthAnchor.constraint(
                greaterThanOrEqualToConstant: Self.minimumContentSize.width - 44
            ),
            header.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            permissionBox.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            policyLanes.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            policyLanes.heightAnchor.constraint(greaterThanOrEqualToConstant: 320),
            statusLabel.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            draftActions.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            recoveryHelp.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
        ])
    }

    private func makeLane(for policy: MenuBarBundlePolicy) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 10
        box.borderWidth = 1
        box.borderColor = color(for: policy).withAlphaComponent(0.45)
        box.fillColor = color(for: policy).withAlphaComponent(0.055)

        let accent = NSView()
        accent.wantsLayer = true
        accent.layer?.backgroundColor = color(for: policy).cgColor
        accent.layer?.cornerRadius = 2

        let heading = NSTextField(labelWithString: title(for: policy))
        heading.font = .systemFont(ofSize: 15, weight: .semibold)
        let detail = NSTextField(wrappingLabelWithString: detail(for: policy))
        detail.font = .systemFont(ofSize: 11, weight: .regular)
        detail.textColor = .secondaryLabelColor
        detail.maximumNumberOfLines = 3

        let itemStack = NSStackView()
        itemStack.orientation = .horizontal
        itemStack.alignment = .centerY
        itemStack.spacing = 8
        itemStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        itemStack.translatesAutoresizingMaskIntoConstraints = true
        groupStacks[policy] = itemStack

        let scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.horizontalScrollElasticity = .automatic
        scrollView.verticalScrollElasticity = .none
        scrollView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        scrollView.documentView = itemStack
        groupScrollViews[policy] = scrollView

        let headerRow = NSStackView(views: [accent, heading])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 8
        let descriptionStack = NSStackView(views: [headerRow, detail])
        descriptionStack.orientation = .vertical
        descriptionStack.alignment = .leading
        descriptionStack.spacing = 6
        descriptionStack.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )

        let stack = NSStackView(views: [descriptionStack, scrollView])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.contentView?.addSubview(stack)

        guard let boxContent = box.contentView else { return box }
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: boxContent.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: boxContent.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: boxContent.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: boxContent.bottomAnchor, constant: -12),
            accent.widthAnchor.constraint(equalToConstant: 5),
            accent.heightAnchor.constraint(equalToConstant: 20),
            descriptionStack.widthAnchor.constraint(equalToConstant: 210),
            detail.widthAnchor.constraint(equalTo: descriptionStack.widthAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 74),
            box.heightAnchor.constraint(equalToConstant: 100),
        ])
        return box
    }

    private func renderGroups() {
        guard let model else { return }
        for policy in MenuBarBundlePolicy.allCases {
            guard let stack = groupStacks[policy] else { continue }
            stack.arrangedSubviews.forEach { view in
                stack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            let candidates = model.candidates(in: policy)
            if candidates.isEmpty {
                let empty = NSTextField(labelWithString: "No observed bundles")
                empty.textColor = .tertiaryLabelColor
                empty.font = .systemFont(ofSize: 11, weight: .regular)
                stack.addArrangedSubview(empty)
                empty.widthAnchor.constraint(equalToConstant: 150).isActive = true
                empty.heightAnchor.constraint(equalToConstant: 48).isActive = true
                sizeItemStrip(for: policy)
                continue
            }
            for candidate in candidates {
                let button = makeBundleButton(candidate, policy: policy)
                stack.addArrangedSubview(button)
                button.widthAnchor.constraint(equalToConstant: 220).isActive = true
            }
            sizeItemStrip(for: policy)
        }
        updateSelectionControls()
    }

    private func sizeItemStrip(for policy: MenuBarBundlePolicy) {
        guard let stack = groupStacks[policy],
              let scrollView = groupScrollViews[policy] else { return }
        let itemWidths = stack.arrangedSubviews.reduce(CGFloat.zero) { total, view in
            total + max(view.fittingSize.width, view.frame.width)
        }
        let spacing = CGFloat(max(0, stack.arrangedSubviews.count - 1)) * stack.spacing
        let horizontalInsets = stack.edgeInsets.left + stack.edgeInsets.right
        let contentWidth = max(
            scrollView.contentSize.width,
            itemWidths + spacing + horizontalInsets
        )
        stack.frame = NSRect(
            origin: .zero,
            size: NSSize(width: contentWidth, height: scrollView.contentSize.height)
        )
    }

    private func makeBundleButton(
        _ candidate: PolicyCandidate,
        policy: MenuBarBundlePolicy
    ) -> NSButton {
        let button = PolicyBundleButton(bundleIdentifier: candidate.bundleIdentifier)
        let isBlenny = BundlePolicyIdentity.canonicalKey(for: candidate.bundleIdentifier)
            == model.flatMap {
                BundlePolicyIdentity.canonicalKey(for: $0.blennyBundleIdentifier)
            }
        let displayName = candidate.bundleIdentifier.split(separator: ".").last
            .map(String.init) ?? candidate.bundleIdentifier
        let subtitle = isBlenny
            ? "Always pinned · \(candidate.bundleIdentifier)"
            : "\(candidate.bundleIdentifier) · \(candidate.menuBarItemCount) item\(candidate.menuBarItemCount == 1 ? "" : "s")"
        let title = NSMutableAttributedString(
            string: "\(displayName)\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ]
        )
        title.append(
            NSAttributedString(
                string: subtitle,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]
            )
        )
        button.attributedTitle = title
        button.alignment = .left
        button.bezelStyle = .regularSquare
        button.setButtonType(.toggle)
        button.target = self
        button.action = #selector(selectBundle(_:))
        button.toolTip = candidate.bundleIdentifier
        button.setAccessibilityLabel("\(displayName), \(policy.rawValue), \(subtitle)")
        button.state = selectedBundleIdentifier == candidate.bundleIdentifier ? .on : .off
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        return button
    }

    private func updateControls() {
        let hasModel = model != nil
        refreshButton.isEnabled = !isRefreshing && model?.hasDraftChanges != true
        reviewButton.isEnabled = hasModel && !isRefreshing
        discardButton.isEnabled = model?.hasDraftChanges == true && !isRefreshing
        resumeButton.isEnabled = hasModel
            && model?.acceptedPolicy.managementEnabled == false
            && !isRefreshing
        stopButton.isEnabled = hasModel
            && model?.acceptedPolicy.managementEnabled == true
            && !isRefreshing
        restoreButton.isEnabled = hasModel && isRecoveryAvailable && !isRefreshing
        moveControl.isEnabled = selectedBundleIdentifier != nil && !isRefreshing
    }

    private func updateSelectionControls() {
        guard let model, let selectedBundleIdentifier else {
            moveLabel.stringValue = "Select a bundle to change its group."
            moveControl.selectedSegment = -1
            moveControl.isEnabled = false
            return
        }
        moveLabel.stringValue = "Move \(selectedBundleIdentifier) to"
        let currentPolicy = MenuBarBundlePolicy.allCases.first { policy in
            model.candidates(in: policy).contains {
                $0.bundleIdentifier == selectedBundleIdentifier
            }
        }
        moveControl.selectedSegment = currentPolicy.flatMap {
            MenuBarBundlePolicy.allCases.firstIndex(of: $0)
        } ?? -1
        let isBlenny = BundlePolicyIdentity.canonicalKey(for: selectedBundleIdentifier)
            == BundlePolicyIdentity.canonicalKey(for: model.blennyBundleIdentifier)
        moveControl.setEnabled(true, forSegment: 0)
        moveControl.setEnabled(!isBlenny, forSegment: 1)
        moveControl.setEnabled(!isBlenny, forSegment: 2)
        moveControl.isEnabled = !isRefreshing
    }

    private func color(for policy: MenuBarBundlePolicy) -> NSColor {
        switch policy {
        case .pinned: .systemBlue
        case .revealable: .systemTeal
        case .hidden: .secondaryLabelColor
        }
    }

    private func title(for policy: MenuBarBundlePolicy) -> String {
        switch policy {
        case .pinned: "Pinned"
        case .revealable: "Revealable"
        case .hidden: "Hidden"
        }
    }

    private func detail(for policy: MenuBarBundlePolicy) -> String {
        switch policy {
        case .pinned:
            "Kept visible whenever possible. Blenny always stays here."
        case .revealable:
            "Concealed at baseline and included in an ordinary reveal."
        case .hidden:
            "Concealed at baseline and excluded from every ordinary reveal."
        }
    }

    @objc private func selectBundle(_ sender: PolicyBundleButton) {
        selectedBundleIdentifier = sender.bundleIdentifier
        renderGroups()
    }

    @objc private func moveSelection() {
        guard let selectedBundleIdentifier,
              MenuBarBundlePolicy.allCases.indices.contains(moveControl.selectedSegment) else {
            return
        }
        onAssign(
            selectedBundleIdentifier,
            MenuBarBundlePolicy.allCases[moveControl.selectedSegment]
        )
    }

    @objc private func reviewChanges() { onReview() }
    @objc private func discardDraft() { onDiscard() }
    @objc private func refresh() { onRefresh() }
    @objc private func requestAccess() { onRequestAccess() }
    @objc private func resumeManaging() { onResumeManaging() }
    @objc private func stopManaging() { onStopManaging() }
    @objc private func restorePreviousPolicy() { onRestorePreviousPolicy() }
}
