import AppKit
import BlennyCore
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class PolicyEditorWindowController: NSWindowController {
    private static let fixedContentHeight: CGFloat = 420
    private static let organizePreferredContentSize = NSSize(width: 980, height: fixedContentHeight)
    private static let organizeMinimumContentSize = NSSize(width: 800, height: fixedContentHeight)
    private static let compactPreferredContentSize = NSSize(width: 680, height: fixedContentHeight)
    private static let compactMinimumContentSize = NSSize(width: 560, height: fixedContentHeight)
    #if DEBUG
    private static let minimumSizeValidationEnvironmentKey =
        "BLENNY_VALIDATE_MINIMUM_WINDOW_SIZE"
    private static let darkAppearanceValidationEnvironmentKey =
        "BLENNY_VALIDATE_DARK_APPEARANCE"
    private static let initialSectionValidationEnvironmentKey =
        "BLENNY_VALIDATE_INITIAL_SECTION"
    private static let populatedValidationEnvironmentKey =
        "BLENNY_VALIDATE_POPULATED_INTERFACE"
    private static let untrustedValidationEnvironmentKey =
        "BLENNY_VALIDATE_UNTRUSTED_INTERFACE"
    private static let refreshingValidationEnvironmentKey =
        "BLENNY_VALIDATE_REFRESHING_INTERFACE"
    private static let draftValidationEnvironmentKey =
        "BLENNY_VALIDATE_DRAFT_INTERFACE"
    private static let errorValidationEnvironmentKey =
        "BLENNY_VALIDATE_ERROR_INTERFACE"
    #endif

    let interfaceModel = ProductInterfaceModel()
    private let usesPopulatedValidationFixture: Bool
    private var navigationCancellable: AnyCancellable?

    init(
        onRefresh: @escaping () -> Void,
        onRequestAccess: @escaping () -> Void,
        onResumeManaging: @escaping () -> Void,
        onStopManaging: @escaping () -> Void,
        onRestorePreviousPolicy: @escaping () -> Void,
        onDraftDidChange: @escaping (PolicyEditorViewModel) -> Void,
        onApplyDraft: @escaping () -> Void,
        onOpenProjectWebsite: @escaping () -> Void,
        onOpenMonthlySponsor: @escaping () -> Void,
        onOpenOneTimeSponsor: @escaping () -> Void,
        onOpenKoFi: @escaping () -> Void,
        onSetLaunchAtLogin: @escaping (Bool) -> Void,
        onOpenLoginItemsSettings: @escaping () -> Void,
        onCheckForUpdates: (() -> Void)?,
        onShowFishPlacementGuide: @escaping () -> Void,
        onHideSharedSystemItem: @escaping (SharedSystemItemTrialTarget) -> Void,
        onRestoreSharedSystemItem: @escaping (SharedSystemItemTrialTarget) -> Void,
        onSetAutomaticUpdateChecks: ((Bool) -> Void)? = nil
    ) {
        #if DEBUG
        usesPopulatedValidationFixture = ProcessInfo.processInfo.environment[
            Self.populatedValidationEnvironmentKey
        ] == "YES"
        if ProcessInfo.processInfo.environment[
            Self.darkAppearanceValidationEnvironmentKey
        ] == "YES" {
            NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        }
        if let rawSection = ProcessInfo.processInfo.environment[
            Self.initialSectionValidationEnvironmentKey
        ], let section = ProductInterfaceSection(rawValue: rawSection) {
            interfaceModel.navigate(to: section)
        }
        if usesPopulatedValidationFixture {
            interfaceModel.installPopulatedVisualValidationFixture(
                accessibilityTrusted: ProcessInfo.processInfo.environment[
                    Self.untrustedValidationEnvironmentKey
                ] != "YES"
            )
            if ProcessInfo.processInfo.environment[
                Self.refreshingValidationEnvironmentKey
            ] == "YES" {
                interfaceModel.setRefreshing(true)
            }
            if ProcessInfo.processInfo.environment[
                Self.draftValidationEnvironmentKey
            ] == "YES" {
                _ = interfaceModel.assign(
                    bundleIdentifier: "com.apple.Safari",
                    destination: .hidden
                )
            }
            if ProcessInfo.processInfo.environment[
                Self.errorValidationEnvironmentKey
            ] == "YES" {
                interfaceModel.setStatus(
                    "The last bounded observation was incomplete. No policy changed.",
                    isError: true
                )
            }
        }
        #else
        usesPopulatedValidationFixture = false
        #endif

        let actions = ProductInterfaceActions(
            refresh: onRefresh,
            requestAccess: onRequestAccess,
            resumeManaging: onResumeManaging,
            stopManaging: onStopManaging,
            restorePreviousPolicy: onRestorePreviousPolicy,
            draftDidChange: onDraftDidChange,
            applyDraft: onApplyDraft,
            openProjectWebsite: onOpenProjectWebsite,
            openMonthlySponsor: onOpenMonthlySponsor,
            openOneTimeSponsor: onOpenOneTimeSponsor,
            openKoFi: onOpenKoFi,
            setLaunchAtLogin: onSetLaunchAtLogin,
            openLoginItemsSettings: onOpenLoginItemsSettings,
            checkForUpdates: onCheckForUpdates,
            setAutomaticUpdateChecks: onSetAutomaticUpdateChecks,
            showFishPlacementGuide: onShowFishPlacementGuide,
            hideSharedSystemItem: onHideSharedSystemItem,
            restoreSharedSystemItem: onRestoreSharedSystemItem
        )
        let rootView = BlennyRootView(model: interfaceModel, actions: actions)
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = []

        #if DEBUG
        let initialContentSize = ProcessInfo.processInfo.environment[
            Self.minimumSizeValidationEnvironmentKey
        ] == "YES"
            ? Self.minimumContentSize(for: interfaceModel.navigation.section)
            : Self.preferredContentSize(for: interfaceModel.navigation.section)
        #else
        let initialContentSize = Self.preferredContentSize(
            for: interfaceModel.navigation.section
        )
        #endif

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let version = BlennyApplicationVersion.display
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        #if BLENNY_FALLBACK_POSITION_TRIAL
        window.title = "Blenny \(version) · Arrow Position Trial"
        #elseif BLENNY_NATIVE_BOUNDARY_TRIAL
        window.title = "Blenny \(version) · Native Boundary Trial"
        #elseif BLENNY_GROUPED_FALLBACK_TRIAL
        window.title = "Blenny \(version) · Grouped Click Trial"
        #else
        window.title = "Blenny \(version) · Experimental"
        #endif
        #else
        window.title = "Blenny \(version)"
        #endif
        #if DEBUG
        if let mode = DebugDragStartDiagnostics.mode {
            window.title = "Blenny \(version) · Drag: \(mode.rawValue) · \(DebugDragStartDiagnostics.typedSource ? "typed" : "provider") · overflow: \(DebugDragStartDiagnostics.publishUnchangedOverflow ? "always" : "changed")"
            DebugDragStartDiagnostics.record("launch.\(mode.rawValue)")
        }
        #endif
        window.toolbarStyle = .unified
        window.contentMinSize = Self.minimumContentSize(
            for: interfaceModel.navigation.section
        )
        window.contentMaxSize = NSSize(width: .greatestFiniteMagnitude, height: Self.fixedContentHeight)
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.setContentSize(initialContentSize)
        window.center()

        super.init(window: window)

        navigationCancellable = interfaceModel.$navigation
            .map(\.section)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] section in
                Task { @MainActor [weak self] in
                    self?.resizeWindow(for: section)
                }
            }
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

    func setAccessibilityTrusted(
        _ trusted: Bool,
        hasRequestedSystemPrompt: Bool
    ) {
        guard !usesPopulatedValidationFixture else { return }
        interfaceModel.setAccessibilityTrusted(
            trusted,
            hasRequestedSystemPrompt: hasRequestedSystemPrompt
        )
    }

    func setRefreshing(_ refreshing: Bool) {
        guard !usesPopulatedValidationFixture else { return }
        interfaceModel.setRefreshing(refreshing)
    }

    func display(
        model: PolicyEditorViewModel,
        observationCount: Int,
        recoveryAvailable: Bool,
        preservingOrderingLayout: Bool = false
    ) {
        guard !usesPopulatedValidationFixture else { return }
        interfaceModel.display(
            model: model,
            observationCount: observationCount,
            recoveryAvailable: recoveryAvailable,
            preservingOrderingLayout: preservingOrderingLayout
        )
    }

    var candidateGeneration: UUID {
        interfaceModel.candidateGeneration
    }

    var hasDraftChanges: Bool { interfaceModel.hasDraftChanges }
    var requiresObservationRefresh: Bool { interfaceModel.requiresObservationRefresh }

    #if BLENNY_PRODUCT || DEBUG
    var orderingPresentation: OrderingPresentation {
        interfaceModel.orderingPresentation
    }

    func initializeOrderingLayoutFromCurrentRows(force: Bool = false) {
        interfaceModel.initializeOrderingLayoutFromCurrentRows(force: force)
    }

    @discardableResult
    func installCommittedOrderingLayout(
        from request: OrderingConfigurationRequest
    ) -> Bool {
        interfaceModel.installCommittedOrderingLayout(from: request)
    }

    var currentOrderingConfigurationRequest: OrderingConfigurationRequest? {
        interfaceModel.currentOrderingConfigurationRequest
    }

    var hasOrderingLayoutChanges: Bool {
        interfaceModel.hasOrderingLayoutChanges
    }

    func discardOrderingLayoutDraft() {
        interfaceModel.discardOrderingLayoutDraft()
    }

    func resetOrderingLayoutDraft() {
        interfaceModel.resetOrderingLayoutDraft()
    }

    @discardableResult
    func discardConfigurationDraft() -> PolicyEditorViewModel? {
        interfaceModel.discardDraft()
    }
    #endif

    func setDiscoveryWarnings(_ warnings: [String]) {
        interfaceModel.discoveryWarnings = warnings
    }

    #if DEBUG
    func debugPresentationSummary(for bundleIdentifier: String) -> String {
        let icon = interfaceModel.applicationIcons.first {
            $0.key.lowercased() == bundleIdentifier.lowercased()
        }?.value
        return "presentationIcon=\(icon != nil) iconSource=\(icon.map { String(describing: $0.descriptor) } ?? "none")"
    }
    #endif

    #if DEBUG
    var debugResumeEnabled: Bool { interfaceModel.controls.resumeEnabled }
    #endif

    func setManagementRuntimeState(
        _ state: ManagementLoopState,
        managementBackendAvailable: Bool
    ) {
        guard !usesPopulatedValidationFixture else { return }
        interfaceModel.setManagementRuntimeState(
            state,
            managementBackendAvailable: managementBackendAvailable
        )
    }

    func setStatus(_ message: String, isError: Bool) {
        guard !usesPopulatedValidationFixture else { return }
        interfaceModel.setStatus(message, isError: isError)
    }

    func setLaunchAtLoginState(_ state: LaunchAtLoginPresentationState) {
        interfaceModel.setLaunchAtLoginState(state)
    }

    func setNativeOverflowPlacement(
        _ snapshot: NativeOverflowObservationSnapshot
    ) {
        interfaceModel.setNativeOverflowPlacement(snapshot)
    }

    #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    func setSharedSystemItemTrial(
        _ target: SharedSystemItemTrialTarget,
        presentation: SharedSystemItemTrialPresentation
    ) {
        interfaceModel.setSharedSystemItemTrial(target, presentation: presentation)
    }
    #endif

    func setApplying(_ applying: Bool) {
        interfaceModel.setApplying(applying)
    }

    private func restoreUsableWindowSizeIfNeeded() {
        guard let window else { return }
        window.contentMinSize = NSSize(width: 560, height: Self.fixedContentHeight)
        let size = window.contentLayoutRect.size
        if size.width < 560 || abs(size.height - Self.fixedContentHeight) > 1 {
            resizeWindow(for: interfaceModel.navigation.section)
        }
    }

    private func resizeWindow(for section: ProductInterfaceSection) {
        guard let window else { return }
        let preferredContentSize = Self.preferredContentSize(for: section)
        let oldFrame = window.frame
        let targetContentSize = NSSize(
            width: preferredContentSize.width,
            height: Self.fixedContentHeight
        )
        var contentRect = window.contentRect(forFrameRect: oldFrame)
        contentRect.size = targetContentSize
        var newFrame = window.frameRect(forContentRect: contentRect)
        newFrame.origin.x = oldFrame.origin.x
        newFrame.origin.y = oldFrame.maxY - newFrame.height
        window.contentMinSize = NSSize(width: 560, height: Self.fixedContentHeight)
        let settleMinimumSize: @Sendable () -> Void = { [weak self, weak window] in
            Task { @MainActor [weak self, weak window] in
                guard let self, let window, interfaceModel.navigation.section == section,
                      abs(window.contentLayoutRect.width - targetContentSize.width) < 1 else { return }
                window.contentMinSize = NSSize(
                    width: section == .organize ? 800 : 560, height: Self.fixedContentHeight
                )
            }
        }
        if effectiveReduceMotion {
            window.setFrame(newFrame, display: true)
            settleMinimumSize()
        } else {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.30
                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: 0.25,
                    0.10,
                    0.25,
                    1.00
                )
                window.animator().setFrame(newFrame, display: true)
            }, completionHandler: settleMinimumSize)
        }
    }

    private var effectiveReduceMotion: Bool {
        let systemPrefersReducedMotion = NSWorkspace.shared
            .accessibilityDisplayShouldReduceMotion
        #if BLENNY_PRODUCT || DEBUG
        let debugPrefersReducedMotion = ProcessInfo.processInfo.environment[
            "BLENNY_VALIDATE_REDUCE_MOTION"
        ] == "YES"
        return systemPrefersReducedMotion || debugPrefersReducedMotion
        #else
        return systemPrefersReducedMotion
        #endif
    }

    private static func preferredContentSize(
        for section: ProductInterfaceSection
    ) -> NSSize {
        switch section {
        case .organize: organizePreferredContentSize
        case .settings, .support: compactPreferredContentSize
        }
    }

    private static func minimumContentSize(
        for section: ProductInterfaceSection
    ) -> NSSize {
        switch section {
        case .organize: organizeMinimumContentSize
        case .settings, .support: compactMinimumContentSize
        }
    }
}
