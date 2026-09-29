import AppKit
import BlennyCore
#if DEBUG
import ObjectiveC
#endif

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
    private static let ordinaryStatusItemLength: CGFloat = 22
    private let statusItem: NSStatusItem
    private var revealStatusItem: NSStatusItem?
    #if DEBUG && BLENNY_GROUPED_FALLBACK_TRIAL
    private var groupedStatusContent: GroupedStatusItemContent?
    #endif
    #if DEBUG
    private let fallbackDiagnosticSession = UUID().uuidString
    private var fallbackCreationCount = 0
    private(set) var debugClickCheck = NativeControlClickCheck()
    private(set) var debugDispatchClickCheckID: UUID?
    private var debugBoundaryCapture: (() -> Void)?
    private var debugBoundaryDirectory: URL?
    private let debugSaveBoundaryItem = NSMenuItem(title: "Save Boundary Snapshot",
        action: #selector(debugSaveBoundarySnapshot), keyEquivalent: "")
    #endif
    private let openItem = NSMenuItem(title: "Open Blenny", action: #selector(openDiagnostics), keyEquivalent: "o")
    private let ordinaryRevealItem = NSMenuItem(title: "Expand Revealable Items", action: #selector(toggleOrdinaryReveal), keyEquivalent: "")
    #if DEBUG
    private let debugMenu = NSMenu(title: "Debug")
    private let refreshItem = NSMenuItem(title: "Refresh Menu Bar Items", action: #selector(refresh), keyEquivalent: "r")
    #endif
    private var isRefreshing = false
    private let resumeManagingItem = NSMenuItem(title: "Resume Managing", action: #selector(resumeManaging), keyEquivalent: "")
    private let stopManagingItem = NSMenuItem(title: "Stop Managing", action: #selector(stopManaging), keyEquivalent: "")
    let menu = NSMenu()
    private let checkForUpdatesItem = NSMenuItem(title: "Check for Updates", action: #selector(checkForUpdates), keyEquivalent: "")
    private let onCheckForUpdates: () -> Void
    private let canCheckForUpdates: () -> Bool
    private var hasDraftChanges = false
    private var requiresObservationRefresh = false
    private var interactionBusy = false
    private var accessibilityTrusted = false
    private var currentManagementState: ManagementLoopState = .unknown
    private var currentManagementEnabled = false
    private var currentRecoveryAvailable = false
    private var hasRevealableBundles = false
    private var nativeOverflow = NativeOverflowObservationSnapshot.unavailable
    private var fallbackSlotCompaction = NativeFallbackSlotCompaction()
    private var lastFallbackSlotAllocation: NativeFallbackSlotCompaction.Allocation?
    private var blennyImage: NSImage?
    private var normalPresentation = ManagementStatusPresentation(
        state: .unknown, hasRevealableBundles: false, isBusy: false
    )
    private var lastRenderedPresentation: ManagementStatusPresentation?
    private let onOpenDiagnostics: () -> Void
    private let onRefresh: () -> Void
    private let onRequestAccess: () -> Void
    private let onToggleOrdinaryReveal: () -> Void
    private let onResumeManaging: () -> Void
    private let onStopManaging: () -> Void
    private let onRestorePreviousPolicy: () -> Void
    private let onQuit: () -> Void
    private let onVerifyNativeOverflowAfterSlotCompaction: () -> Void
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
    private var debugStopManagingAndRestore: (() -> Void)?
    private var revealPrototypeEntryPoint: RevealEntryPoint?
    private var revealPrototypePresentation: RevealSessionPresentation = .baseline
    private var revealPrototypeEnabled = false
    private var revealPrototypeContentStack: DebugStatusItemContentStack?
    private var revealPrototypeArrowImageView: NSImageView?
    private var manualPositionCapture: (() -> Void)?
    private var manualPositionCaptureItem: NSMenuItem?
    private let fallbackSlotDiagnosticItem = NSMenuItem(
        title: "Fallback slot: checking…",
        action: nil,
        keyEquivalent: ""
    )
    private let revealPrototypeStateItem = NSMenuItem(
        title: "0.0.5 Policy Editing Core validation: inactive",
        action: nil,
        keyEquivalent: ""
    )
    #endif

    init(
        onOpenDiagnostics: @escaping () -> Void,
        onRefresh: @escaping () -> Void,
        onRequestAccess: @escaping () -> Void,
        onToggleOrdinaryReveal: @escaping () -> Void,
        onResumeManaging: @escaping () -> Void,
        onStopManaging: @escaping () -> Void,
        onRestorePreviousPolicy: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        onVerifyNativeOverflowAfterSlotCompaction: @escaping () -> Void = {},
        onCheckForUpdates: @escaping () -> Void = {},
        canCheckForUpdates: @escaping () -> Bool = { false }
    ) {
        self.onCheckForUpdates = onCheckForUpdates
        self.canCheckForUpdates = canCheckForUpdates
        self.onOpenDiagnostics = onOpenDiagnostics
        self.onRefresh = onRefresh
        self.onRequestAccess = onRequestAccess
        self.onToggleOrdinaryReveal = onToggleOrdinaryReveal
        self.onResumeManaging = onResumeManaging
        self.onStopManaging = onStopManaging
        self.onRestorePreviousPolicy = onRestorePreviousPolicy
        self.onQuit = onQuit
        self.onVerifyNativeOverflowAfterSlotCompaction =
            onVerifyNativeOverflowAfterSlotCompaction
        #if DEBUG
        let readOnlyValidation = ProcessInfo.processInfo.environment["BLENNY_0_6_0_DRY_RUN"] == "YES"
            || ProcessInfo.processInfo.environment["BLENNY_0_5_0_DRY_RUN"] == "YES"
            || ProcessInfo.processInfo.environment[DebugSelfPositionValidationDelegate.modeKey] != nil
            || ProcessInfo.processInfo.environment[DebugAgentPositionValidationDelegate.modeKey] != nil
            || ProcessInfo.processInfo.environment[DebugManualPositionCalibrationDelegate.modeKey] != nil
        let placementProbeEnabled = !readOnlyValidation && ProcessInfo.processInfo.environment[
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
        if let name = DebugSelfPositionValidationDelegate.creationAutosaveName {
            statusItem.autosaveName = name
        }
        if let name = DebugAgentPositionValidationDelegate.creationAutosaveName {
            statusItem.autosaveName = name
        }
        if let name = DebugManualPositionCalibrationDelegate.creationAutosaveName {
            statusItem.autosaveName = name
        }
        if placementProbeEnabled {
            statusItem.autosaveName = Self.placementAutosaveName
            Self.debugLog(
                "BLENNY_0_0_5 self_position=\(Self.placementValue) "
                    + "autosave=\(Self.placementAutosaveName) persistence=registration_domain"
            )
        } else if !readOnlyValidation,
                  DebugSelfPositionValidationDelegate.creationAutosaveName == nil,
                  DebugAgentPositionValidationDelegate.creationAutosaveName == nil,
                  DebugManualPositionCalibrationDelegate.creationAutosaveName == nil {
            statusItem.autosaveName = BlennyFishPlacement.autosaveName
        }
        #else
        statusItem.autosaveName = BlennyFishPlacement.autosaveName
        #endif

        configureButton()
        configureMenu()
        #if DEBUG
        // Keep the historical single-item prototype separate from ordinary UI.
        if readOnlyValidation || ProcessInfo.processInfo.environment[DebugPolicyCoexistenceController.editingActionEnvironmentKey] == nil {
            configureRevealStatusItem()
        }
        #else
        configureRevealStatusItem()
        #endif
    }

    func setAccessibilityTrusted(_ trusted: Bool) {
        accessibilityTrusted = trusted
        updateResumeAvailability()
        updateCheckAvailability()
    }

    func setRefreshing(_ refreshing: Bool) {
        isRefreshing = refreshing
        #if DEBUG
        refreshItem.isEnabled = !refreshing && !hasDraftChanges && !interactionBusy
        refreshItem.title = refreshing ? "Refreshing Menu Bar Items…" : "Refresh Menu Bar Items"
        #endif
    }

    func setDraftHasChanges(_ hasChanges: Bool, requiresObservationRefresh: Bool = false) {
        hasDraftChanges = hasChanges
        self.requiresObservationRefresh = requiresObservationRefresh
        #if DEBUG
        refreshItem.isEnabled = !isRefreshing && !hasChanges && !interactionBusy
        #endif
        updateResumeAvailability()
        updateCheckAvailability()
    }

    func setManagementState(
        _ state: ManagementLoopState,
        persistedManagementEnabled: Bool,
        recoveryAvailable: Bool,
        hasRevealableBundles: Bool = false
    ) {
        currentManagementState = state
        currentManagementEnabled = persistedManagementEnabled
        currentRecoveryAvailable = recoveryAvailable
        self.hasRevealableBundles = hasRevealableBundles
        switch state {
        case .active:
            ordinaryRevealItem.title = "Expand Revealable Items"
            setMenuIcon(ordinaryRevealItem, symbol: "chevron.left.2")
            ordinaryRevealItem.isEnabled = true
        case .ordinaryRevealSession:
            ordinaryRevealItem.title = "Collapse Revealable Items"
            setMenuIcon(ordinaryRevealItem, symbol: "chevron.right.2")
            ordinaryRevealItem.isEnabled = true
        default:
            ordinaryRevealItem.title = "Expand Revealable Items"
            setMenuIcon(ordinaryRevealItem, symbol: "chevron.left.2")
            ordinaryRevealItem.isEnabled = false
        }
        ordinaryRevealItem.isEnabled = ordinaryRevealItem.isEnabled
            && hasRevealableBundles && !interactionBusy
        updateResumeAvailability()
        updateCheckAvailability()
        stopManagingItem.isEnabled = persistedManagementEnabled && !interactionBusy
        updateNormalButton()
    }

    func setInteractionBusy(_ busy: Bool) {
        interactionBusy = busy
        #if DEBUG
        refreshItem.isEnabled = !isRefreshing && !busy && !hasDraftChanges
        #endif
        setManagementState(
            currentManagementState,
            persistedManagementEnabled: currentManagementEnabled,
            recoveryAvailable: currentRecoveryAvailable,
            hasRevealableBundles: hasRevealableBundles
        )
    }

    private func updateResumeAvailability() {
        let visibility = StatusMenuVisibility(
            state: currentManagementState,
            persistedManagementEnabled: currentManagementEnabled,
            recoveryAvailable: currentRecoveryAvailable
        )
        resumeManagingItem.isHidden = !visibility.showsResume
        stopManagingItem.isHidden = !visibility.showsStop
        resumeManagingItem.isEnabled = currentManagementState.canResume
            && accessibilityTrusted && !interactionBusy && !hasDraftChanges && !requiresObservationRefresh
    }

    #if DEBUG
    var debugResumeEnabled: Bool { resumeManagingItem.isEnabled }
    #endif

    func setNativeOverflow(_ snapshot: NativeOverflowObservationSnapshot) {
        nativeOverflow = snapshot
        updateNormalButton()
    }

    private func updateNormalButton() {
        #if DEBUG
        guard revealPrototypeToggle == nil else { return }
        #endif
        guard let button = statusItem.button else { return }
        normalPresentation = ManagementStatusPresentation(
            state: currentManagementState,
            hasRevealableBundles: hasRevealableBundles,
            isBusy: interactionBusy,
            nativeOverflow: nativeOverflow
        )
        let slotUpdate = fallbackSlotCompaction.update(
            nativeOverflowUsable: nativeOverflow.isUsable,
            mayBeginCompaction: normalPresentation.canToggleReveal
        )
        #if DEBUG
        let previousSlotAllocation = lastFallbackSlotAllocation
        #endif
        // A MenuBarAgent layout notification may result from this presentation
        // itself. Never resubmit unchanged content in response to that event.
        guard normalPresentation != lastRenderedPresentation
                || slotUpdate.allocation != lastFallbackSlotAllocation else { return }
        lastRenderedPresentation = normalPresentation
        lastFallbackSlotAllocation = slotUpdate.allocation
        #if !(DEBUG && BLENNY_GROUPED_FALLBACK_TRIAL)
        button.image = blennyImage
        button.title = blennyImage == nil ? "B" : ""
        statusItem.length = Self.ordinaryStatusItemLength
        #endif
        let arrowImage = NSImage(systemSymbolName: normalPresentation.nativeArrowSymbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: ManagementStatusPresentation.arrowPointSize, weight: .medium))
        arrowImage?.isTemplate = true
        #if DEBUG && BLENNY_GROUPED_FALLBACK_TRIAL
        let grouped = ensureGroupedStatusContent(in: button)
        let reservesArrow = slotUpdate.allocation == .reserved
        let length = reservesArrow ? Self.ordinaryStatusItemLength * 2
            : Self.ordinaryStatusItemLength
        if statusItem.length != length { statusItem.length = length }
        button.image = nil
        button.title = ""
        button.action = nil
        grouped.update(
            fishImage: blennyImage, arrowImage: arrowImage,
            reservesArrow: reservesArrow,
            showsArrow: reservesArrow && normalPresentation.showsInlineArrow,
            canToggle: normalPresentation.canToggleReveal,
            arrowHelp: normalPresentation.nativeArrowHelp
        )
        #else
        if slotUpdate.allocation == .absent {
            if let item = revealStatusItem {
                NSStatusBar.system.removeStatusItem(item)
                revealStatusItem = nil
            }
        } else {
            let item = ensureRevealStatusItem()
            let showsFallbackContent = normalPresentation.showsInlineArrow
                && slotUpdate.allocation == .reserved
            // A zero-length transition has no content or hit target. It exists
            // only as the bounded middle tier between removal and full fallback.
            item.length = slotUpdate.allocation == .reserved
                ? Self.ordinaryStatusItemLength : 0
            item.button?.image = showsFallbackContent ? arrowImage : nil
            item.button?.title = ""
            item.button?.isHidden = !showsFallbackContent
            item.button?.setAccessibilityElement(showsFallbackContent)
            item.button?.isEnabled = showsFallbackContent
                && normalPresentation.canToggleReveal
            item.button?.setAccessibilityLabel(normalPresentation.nativeArrowHelp)
            item.button?.toolTip = normalPresentation.nativeArrowHelp
        }
        #endif
        #if DEBUG
        if previousSlotAllocation != slotUpdate.allocation,
           DebugSessionTrace.shared.enabled {
            DebugSessionTrace.shared.write(
                "fallback-slot nativeUsable=\(nativeOverflow.isUsable) "
                    + debugFallbackSlotSummary
            )
        }
        #endif
        ordinaryRevealItem.isEnabled = normalPresentation.canToggleReveal
        button.setAccessibilityLabel("Open Blenny")
        button.setAccessibilityHelp("Right-click for management and recovery actions.")
        button.toolTip = "Open Blenny — right-click for menu"
        if slotUpdate.requestsVerification {
            onVerifyNativeOverflowAfterSlotCompaction()
        }
    }

    @objc private func handleNormalStatusButton(_ sender: Any?) {
        handleStatusControl(.artwork)
    }

    @objc private func handleRevealStatusButton(_ sender: Any?) {
        handleStatusControl(.arrow)
    }

    private func handleStatusControl(_ control: StatusItemControl) {
        let event = NSApp.currentEvent
        let action = StatusItemClickRouting.action(
            control: control,
            isSecondaryClick: event?.type == .rightMouseUp || event?.type == .rightMouseDown,
            canToggleReveal: normalPresentation.canToggleReveal
        )
        #if DEBUG
        if ProcessInfo.processInfo.environment["BLENNY_SESSION_DIAGNOSTICS"] == "YES" {
            DebugSessionTrace.shared.write("statusControl=\(control.rawValue) action=\(action.rawValue)")
        }
        #endif
        #if DEBUG
        let diagnosticID: UUID?
        if event?.type != .rightMouseUp && event?.type != .rightMouseDown {
            diagnosticID = debugClickCheck.begin(source: control.rawValue,
                event: String(describing: event?.type))
        } else { diagnosticID = nil }
        debugDispatchClickCheckID = diagnosticID
        defer { debugDispatchClickCheckID = nil }
        debugRecordClickStage("route=\(action.rawValue)", id: diagnosticID)
        #endif
        switch action {
        case .toggleReveal:
            // Exactly the same entry point as the working safety-menu action.
            toggleOrdinaryReveal()
        case .openMenu:
            _ = openNormalMenu()
        case .openEditor:
            onOpenDiagnostics()
            #if DEBUG
            debugRecordClickStage("editor action invoked", id: diagnosticID, finished: true)
            #endif
        case .ignore:
            #if DEBUG
            debugRecordClickStage("rejected: canToggleReveal=false", id: diagnosticID, finished: true)
            #endif
            break
        }
    }

    @objc private func openNormalMenu() -> Bool {
        guard let button = statusItem.button else { return false }
        #if DEBUG
        updateFallbackSlotDiagnosticItem()
        #endif
        prepareMenuForPresentation()
        // NSStatusBarButton coordinates need not be flipped. Anchor below the
        // button, leaving screen-edge placement to AppKit.
        let anchor = NSPoint(x: button.bounds.minX,
            y: button.isFlipped ? button.bounds.maxY : button.bounds.minY)
        menu.popUp(positioning: nil, at: anchor, in: button)
        return true
    }

    #if DEBUG
    var debugSelfPositionSummary: String {
        "fishWidth=\(statusItem.length) arrowWidth=\(revealStatusItem?.length ?? 0) "
            + "fishAutosave=\(statusItem.autosaveName ?? "none") "
            + "arrowAutosave=\(revealStatusItem?.autosaveName ?? "none") "
            + "nativeFallbackGlyph=\(debugOrdinaryRevealButtonVisible)"
    }

    func debugCurrentFishPreferredPosition() throws -> Double? {
        let selector = NSSelectorFromString("_currentPreferredPosition")
        let method = try debugCurrentFishPreferredPositionMethod(selector: selector)
        typealias Getter = @convention(c) (AnyObject, Selector) -> Float
        let getter = unsafeBitCast(method_getImplementation(method), to: Getter.self)
        let value = getter(statusItem, selector)
        guard value.isFinite else {
            throw ManualPositionCalibrationError.unexpectedStateChange
        }
        return Double(value)
    }

    func debugValidateCurrentFishPreferredPositionContract() -> Bool {
        let selector = NSSelectorFromString("_currentPreferredPosition")
        return (try? debugCurrentFishPreferredPositionMethod(selector: selector)) != nil
    }

    private func debugCurrentFishPreferredPositionMethod(selector: Selector) throws -> Method {
        guard let method = class_getInstanceMethod(type(of: statusItem), selector),
              let encoding = method_getTypeEncoding(method),
              String(cString: encoding) == "f16@0:8" else {
            throw ManualPositionCalibrationError.invalidScope
        }
        return method
    }

    func debugInstallManualPositionCapture(_ capture: @escaping () -> Void) {
        guard manualPositionCaptureItem == nil else { return }
        manualPositionCapture = capture
        let item = NSMenuItem(title: "Record Manual Position",
            action: #selector(debugRecordManualPosition), keyEquivalent: "")
        item.target = self
        manualPositionCaptureItem = item
        menu.insertItem(.separator(), at: 0)
        menu.insertItem(item, at: 0)
    }

    @objc private func debugRecordManualPosition() {
        guard let capture = manualPositionCapture else { return }
        manualPositionCapture = nil
        manualPositionCaptureItem?.isEnabled = false
        capture()
    }

    func debugRemoveOrdinaryStatusItems() {
        if let item = revealStatusItem { NSStatusBar.system.removeStatusItem(item) }
        revealStatusItem = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    /// Read-only installed validation of the actual AppKit control, not pixels.
    var debugOrdinaryRevealButtonEnabled: Bool {
        #if BLENNY_GROUPED_FALLBACK_TRIAL
        groupedStatusContent?.arrow.isEnabled == true
        #else
        revealStatusItem?.button?.isEnabled == true
        #endif
    }
    /// Local AppKit presentation only; this does not prove physical visibility
    /// outside macOS overflow.
    var debugOrdinaryRevealButtonVisible: Bool {
        #if BLENNY_GROUPED_FALLBACK_TRIAL
        statusItem.isVisible && groupedStatusContent?.arrow.isHidden == false
            && groupedStatusContent?.arrow.image != nil
        #else
        revealStatusItem?.isVisible == true && revealStatusItem?.button?.isHidden == false
            && revealStatusItem?.button?.image != nil
        #endif
    }
    var debugOrdinaryRevealButtonReservedWidth: CGFloat {
        #if BLENNY_GROUPED_FALLBACK_TRIAL
        groupedStatusContent?.reservesArrow == true ? Self.ordinaryStatusItemLength : 0
        #else
        revealStatusItem?.length ?? 0
        #endif
    }
    var debugOrdinaryRevealSlotMode: String {
        #if BLENNY_GROUPED_FALLBACK_TRIAL
        switch lastFallbackSlotAllocation {
        case .reserved: return "reserved"
        case .compact: return "compact"
        default: return "absent"
        }
        #else
        guard revealStatusItem != nil else { return "absent" }
        return revealStatusItem?.length == Self.ordinaryStatusItemLength
            ? "reserved" : "compact"
        #endif
    }
    var debugFallbackSlotSummary: String {
        #if BLENNY_GROUPED_FALLBACK_TRIAL
        return "session=\(fallbackDiagnosticSession) topology=single-status-item"
            + " nativeOverflowUsable=\(nativeOverflow.isUsable)"
            + " allocation=\(debugOrdinaryRevealSlotMode)"
            + " hostFrame=\(Self.debugFrameSummary(statusItem.button?.window?.frame))"
            + " hostAutosave=\(statusItem.autosaveName ?? "none")"
            + " arrowVisible=\(groupedStatusContent?.arrow.isHidden == false)"
            + " arrowEnabled=\(groupedStatusContent?.arrow.isEnabled == true)"
            + " arrowClicks=[\(groupedStatusContent?.arrow.clickDiagnostic ?? "none")]"
            + " fishClicks=[\(groupedStatusContent?.fish.clickDiagnostic ?? "none")]"
            + " separateFallbackCreated=\(revealStatusItem != nil)"
        #else
        let fishFrame = Self.debugFrameSummary(statusItem.button?.window?.frame)
        let fallbackFrame = Self.debugFrameSummary(revealStatusItem?.button?.window?.frame)
        return "session=\(fallbackDiagnosticSession)"
            + " fallbackCreations=\(fallbackCreationCount)"
            + " fallbackInstance=\(revealStatusItem == nil ? "none" : String(fallbackCreationCount))"
            + " nativeOverflowUsable=\(nativeOverflow.isUsable)"
            + " allocation=\(debugOrdinaryRevealSlotMode)"
            + " fishLength=\(statusItem.length) fishFrame=\(fishFrame)"
            + " fishAutosave=\(statusItem.autosaveName ?? "none")"
            + " fishPreferred=\(debugPreferredPosition(statusItem))"
            + " fallbackPreferred=\(debugPreferredPosition(revealStatusItem))"
            + " fallbackLength=\(revealStatusItem?.length ?? 0)"
            + " fallbackFrame=\(fallbackFrame)"
            + " fallbackAutosave=\(revealStatusItem?.autosaveName ?? "none")"
        #endif
    }

    func debugRecordClickStage(_ message: String, id: UUID?, finished: Bool = false) {
        debugClickCheck.record(id: id, stage: message, finished: finished)
    }

    var debugOwnControls: [DebugOwnControlEvidence] {
        var result = [DebugOwnControlEvidence(role: "fish", item: statusItem)]
        if let item = revealStatusItem {
            result.append(DebugOwnControlEvidence(role: "fallback", item: item))
        }
        return result
    }

    #if DEBUG
    var debugMoveFallback: (() -> Void)?
    var debugRestoreFallback: (() -> Void)?

    var debugFallbackNativeIdentity: FallbackNativeIdentity? {
        guard !nativeOverflow.isUsable, let item = revealStatusItem,
              item.autosaveName == "Item-1", item.length == Self.ordinaryStatusItemLength,
              item.button?.window != nil, item.button?.isHidden == false,
              statusItem.autosaveName == "Blenny.Fish",
              statusItem.length == Self.ordinaryStatusItemLength,
              statusItem.button?.window != nil, statusItem.button?.isHidden == false,
              let session = UUID(uuidString: fallbackDiagnosticSession) else { return nil }
        return FallbackNativeIdentity(pid: ProcessInfo.processInfo.processIdentifier,
            session: session, instance: fallbackCreationCount)
    }

    @objc private func debugMoveFallbackAction() { debugMoveFallback?() }
    @objc private func debugRestoreFallbackAction() { debugRestoreFallback?() }
    #endif

    func debugConfigureBoundaryCapture(directory: URL, capture: @escaping () -> Void) {
        debugBoundaryDirectory = directory
        debugBoundaryCapture = capture
    }

    func debugSetBoundaryCaptureBusy(_ busy: Bool) {
        debugSaveBoundaryItem.isEnabled = !busy
        debugSaveBoundaryItem.title = busy ? "Capturing Boundary…" : "Save Boundary Snapshot"
    }

    @objc private func debugArmClickCheck() {
        debugClickCheck.arm()
    }

    @objc private func debugSaveBoundarySnapshot() {
        debugBoundaryCapture?()
    }

    @objc private func debugOpenBoundarySnapshots() {
        guard let directory = debugBoundaryDirectory,
              FileManager.default.fileExists(atPath: directory.path) else { return }
        NSWorkspace.shared.open(directory)
    }

    private func debugPreferredPosition(_ item: NSStatusItem?) -> String {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 else {
            return "unsupported-runtime"
        }
        guard let item else { return "absent" }
        let selector = NSSelectorFromString("_currentPreferredPosition")
        guard let method = class_getInstanceMethod(type(of: item), selector),
              let encoding = method_getTypeEncoding(method),
              String(cString: encoding) == "f16@0:8" else { return "unsupported-contract" }
        typealias Getter = @convention(c) (AnyObject, Selector) -> Float
        let getter = unsafeBitCast(method_getImplementation(method), to: Getter.self)
        let value = getter(item, selector)
        return value.isFinite ? String(value) : "unavailable"
    }

    private static func debugFrameSummary(_ frame: NSRect?) -> String {
        guard let frame else { return "none" }
        return "\(frame.origin.x),\(frame.origin.y),\(frame.size.width),\(frame.size.height)"
    }

    @objc private func copyFallbackSlotDiagnostic(_ sender: NSMenuItem) {
        let summary = "Fallback slot: \(debugOrdinaryRevealSlotMode)\n\(debugFallbackSlotSummary)\n\(debugClickCheck.summary)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }

    private func updateFallbackSlotDiagnosticItem() {
        #if BLENNY_GROUPED_FALLBACK_TRIAL
        fallbackSlotDiagnosticItem.title = "Fallback slot: grouped · \(debugOrdinaryRevealSlotMode)"
        #else
        let fishFrame = Self.debugCompactFrameSummary(statusItem.button?.window?.frame)
        let fallbackFrame = Self.debugCompactFrameSummary(revealStatusItem?.button?.window?.frame)
        fallbackSlotDiagnosticItem.title = "Fallback slot: \(debugOrdinaryRevealSlotMode)"
            + " · fish=\(fishFrame) · fallback=\(fallbackFrame)"
        #endif
    }

    private static func debugCompactFrameSummary(_ frame: NSRect?) -> String {
        guard let frame else { return "none" }
        return String(
            format: "(%.1f,%.1f,%.1f,%.1f)",
            frame.origin.x,
            frame.origin.y,
            frame.size.width,
            frame.size.height
        )
    }
    /// Presentation-only fixtures run in the installed no-writer dry-run. They
    /// prove local AppKit state, not native event delivery or physical placement.
    func debugValidateNativeFallbackPresentation() -> Bool {
        let originalObservation = nativeOverflow
        let originalCompaction = fallbackSlotCompaction
        let originalManagementState = currentManagementState
        let originalHasRevealableBundles = hasRevealableBundles
        let originalInteractionBusy = interactionBusy
        defer {
            currentManagementState = originalManagementState
            hasRevealableBundles = originalHasRevealableBundles
            interactionBusy = originalInteractionBusy
            fallbackSlotCompaction = originalCompaction
            lastFallbackSlotAllocation = nil
            lastRenderedPresentation = nil
            setNativeOverflow(originalObservation)
        }
        currentManagementState = .active("appkit-fixture")
        hasRevealableBundles = true
        interactionBusy = false
        fallbackSlotCompaction = NativeFallbackSlotCompaction()
        lastFallbackSlotAllocation = nil
        lastRenderedPresentation = nil
        setNativeOverflow(.unavailable)
        let native = NativeOverflowObservationSnapshot(
            isPresent: true, presentationState: .collapsed, observationAvailable: true,
            controlIdentifier: UUID()
        )
        let fixtures: [(NativeOverflowObservationSnapshot, String)] = [
            (native, "absent"),
            (.unavailable, "compact"),
            (native, "compact"),
            (.unavailable, "reserved"),
            (native, "reserved"),
        ]
        for (snapshot, expectedMode) in fixtures {
            setNativeOverflow(snapshot)
            guard debugOrdinaryRevealSlotMode == expectedMode,
                  ordinaryRevealItem.isEnabled == normalPresentation.canToggleReveal,
                  statusItem.isVisible,
                  statusItem.button?.isHidden == false else { return false }
            #if BLENNY_GROUPED_FALLBACK_TRIAL
            let showsFallback = expectedMode == "reserved" && normalPresentation.showsInlineArrow
            guard revealStatusItem == nil, let content = groupedStatusContent,
                  content.arrow.isHidden == !showsFallback,
                  content.arrow.isEnabled == (showsFallback && normalPresentation.canToggleReveal),
                  statusItem.length == (expectedMode == "reserved" ? 44 : 22),
                  debugOrdinaryRevealHasDedicatedButton else { return false }
            #else
            if expectedMode == "absent" {
                guard revealStatusItem == nil else { return false }
            } else {
                guard let item = revealStatusItem, let button = item.button,
                      item.isVisible,
                      button.title.isEmpty else { return false }
                let showsFallback = expectedMode == "reserved"
                    && normalPresentation.showsInlineArrow
                guard button.isHidden == !showsFallback,
                      (button.image != nil) == showsFallback,
                      button.isEnabled == (showsFallback && normalPresentation.canToggleReveal)
                    else { return false }
            }
            #endif
        }
        return true
    }
    var debugOrdinaryRevealArrowOnLeft: Bool {
        #if BLENNY_GROUPED_FALLBACK_TRIAL
        guard let content = groupedStatusContent, content.reservesArrow else { return false }
        content.layoutSubtreeIfNeeded()
        return content.arrow.frame.midX < content.fish.frame.midX
        #else
        guard let arrowFrame = revealStatusItem?.button?.window?.frame,
              let artworkFrame = statusItem.button?.window?.frame else { return false }
        return arrowFrame.midX < artworkFrame.midX
        #endif
    }
    var debugOrdinaryRevealHasDedicatedButton: Bool {
        #if BLENNY_GROUPED_FALLBACK_TRIAL
        guard let content = groupedStatusContent else { return false }
        return content.arrow !== content.fish
            && content.arrow.target as? StatusItemController === self
            && content.fish.target as? StatusItemController === self
            && content.arrow.action == #selector(handleRevealStatusButton(_:))
            && content.fish.action == #selector(handleNormalStatusButton(_:))
        #else
        guard let arrow = revealStatusItem?.button else { return false }
        return arrow !== statusItem.button
            && arrow.target as? StatusItemController === self
            && arrow.action == #selector(handleRevealStatusButton(_:))
            && statusItem.button?.action == #selector(handleNormalStatusButton(_:))
        #endif
    }

    func configureDebugRevealPrototype(
        onToggle: @escaping () -> Void,
        onStopManagingAndRestore: @escaping () -> Void
    ) {
        revealPrototypeToggle = onToggle
        debugStopManagingAndRestore = onStopManagingAndRestore
        setMenuIcon(revealPrototypeStateItem, symbol: "info.circle")
        revealPrototypeStateItem.isEnabled = false
        debugMenu.insertItem(revealPrototypeStateItem, at: 0)
        debugMenu.insertItem(.separator(), at: 1)

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
        let image = Bundle.main.url(
            forResource: "BlennyMenuBarTemplate",
            withExtension: "svg"
        ).flatMap(NSImage.init(contentsOf:)) ?? NSImage(
            systemSymbolName: "rectangle.3.group",
            accessibilityDescription: "Blenny"
        )
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = true
        blennyImage = image
        button.image = image
        button.imageScaling = .scaleNone
        if image == nil {
            button.title = "B"
        }
        button.toolTip = "Blenny \(BlennyApplicationVersion.display)"
    }

    private func configureRevealStatusItem() {
        // Create the fallback before the first inventory. It is removed or
        // recreated only by the bounded native-overflow fallback tiers, never on
        // ordinary management transitions.
        #if !(DEBUG && BLENNY_GROUPED_FALLBACK_TRIAL)
        _ = ensureRevealStatusItem()
        #endif
        updateNormalButton()
    }

    #if DEBUG && BLENNY_GROUPED_FALLBACK_TRIAL
    private func ensureGroupedStatusContent(in button: NSStatusBarButton)
        -> GroupedStatusItemContent {
        if let groupedStatusContent { return groupedStatusContent }
        let content = GroupedStatusItemContent()
        content.fish.target = self
        content.fish.action = #selector(handleNormalStatusButton(_:))
        content.arrow.target = self
        content.arrow.action = #selector(handleRevealStatusButton(_:))
        for control in [content.fish, content.arrow] {
            control.setAccessibilityCustomActions([
                NSAccessibilityCustomAction(name: "Open Blenny menu", target: self,
                    selector: #selector(openNormalMenu))
            ])
        }
        button.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            content.topAnchor.constraint(equalTo: button.topAnchor),
            content.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        // Expose two native controls, not the otherwise empty host button.
        button.setAccessibilityRole(.group)
        button.setAccessibilityChildren([content.arrow, content.fish])
        groupedStatusContent = content
        return content
    }
    #endif

    private func ensureRevealStatusItem() -> NSStatusItem {
        if let revealStatusItem { return revealStatusItem }
        let item = NSStatusBar.system.statusItem(
            withLength: Self.ordinaryStatusItemLength
        )
        revealStatusItem = item
        #if DEBUG
        fallbackCreationCount += 1
        #endif
        item.button?.target = self
        item.button?.action = #selector(handleRevealStatusButton(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.imageScaling = .scaleNone
        item.button?.setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: "Open Blenny menu", target: self, selector: #selector(openNormalMenu))
        ])
        return item
    }

    private func configureMenu() {
        let quitItem = NSMenuItem(title: "Quit Blenny", action: #selector(quit), keyEquivalent: "q")

        for item in [
            openItem,
            ordinaryRevealItem,
            resumeManagingItem,
            stopManagingItem,
            quitItem,
        ] {
            item.target = self
        }
        stopManagingItem.isEnabled = false
        ordinaryRevealItem.isEnabled = false
        resumeManagingItem.isEnabled = false

        menu.autoenablesItems = false
        menu.addItem(openItem)
        if let image = blennyImage?.copy() as? NSImage {
            image.size = NSSize(width: 16, height: 16)
            openItem.image = image
            openItem.preferredImageVisibility = .visible
        }
        setMenuIcon(ordinaryRevealItem, symbol: "chevron.left.2")
        setMenuIcon(resumeManagingItem, symbol: "play")
        setMenuIcon(stopManagingItem, symbol: "stop")
        setMenuIcon(quitItem, symbol: "power")
        setMenuIcon(checkForUpdatesItem, symbol: "arrow.triangle.2.circlepath")
        checkForUpdatesItem.target = self
        menu.addItem(.separator())
        #if DEBUG
        fallbackSlotDiagnosticItem.target = self
        fallbackSlotDiagnosticItem.action = #selector(copyFallbackSlotDiagnostic(_:))
        fallbackSlotDiagnosticItem.isEnabled = true
        debugMenu.autoenablesItems = false
        refreshItem.target = self
        debugMenu.addItem(refreshItem)
        debugMenu.addItem(.separator())
        debugMenu.addItem(fallbackSlotDiagnosticItem)
        let arm = NSMenuItem(title: "Arm Next Click Check",
            action: #selector(debugArmClickCheck), keyEquivalent: "")
        let open = NSMenuItem(title: "Open Saved Snapshots",
            action: #selector(debugOpenBoundarySnapshots), keyEquivalent: "")
        for item in [arm, debugSaveBoundaryItem, open] {
            item.target = self
            debugMenu.addItem(item)
        }
        #if DEBUG
        let move = NSMenuItem(title: "Position Blenny Controls…",
            action: #selector(debugMoveFallbackAction), keyEquivalent: "")
        let restore = NSMenuItem(title: "Undo Control Placement",
            action: #selector(debugRestoreFallbackAction), keyEquivalent: "")
        for item in [move, restore] {
            item.target = self
            item.isEnabled = true
            debugMenu.addItem(item)
        }
        #endif
        let diagnosticParent = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
        diagnosticParent.submenu = debugMenu
        setMenuIcon(diagnosticParent, symbol: "ladybug")
        for (item, symbol) in zip(
            [refreshItem, fallbackSlotDiagnosticItem, arm, debugSaveBoundaryItem, open, move, restore],
            ["arrow.clockwise", "info.circle", "cursorarrow", "camera", "folder", "arrow.left.arrow.right", "arrow.uturn.backward"]
        ) { setMenuIcon(item, symbol: symbol) }
        #endif
        menu.addItem(ordinaryRevealItem)
        menu.addItem(resumeManagingItem)
        menu.addItem(stopManagingItem)
        menu.addItem(checkForUpdatesItem)
        menu.addItem(.separator())
        menu.addItem(linkItem("GitHub Sponsors", destination: ProductSupportLinks.menuSponsor))
        menu.addItem(linkItem("Buy Me a Coffee", destination: ProductSupportLinks.koFi))
        menu.addItem(linkItem("Website", destination: ProductSupportLinks.projectWebsite))
        #if DEBUG
        menu.addItem(diagnosticParent)
        #endif
        menu.addItem(.separator())
        menu.addItem(quitItem)
        updateResumeAvailability()
        updateCheckAvailability()
        statusItem.menu = nil
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleNormalStatusButton(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.setAccessibilityCustomActions([
            NSAccessibilityCustomAction(
                name: "Open Blenny menu", target: self, selector: #selector(openNormalMenu)
            )
        ])
    }

    #if DEBUG
    @objc private func handleStatusButton(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp
            || revealPrototypeEntryPoint != .blennyFallback
            || !revealPrototypeEnabled {
            _ = openNormalMenu()
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

    func prepareMenuForPresentation() {
        menu.appearance = NSApp.effectiveAppearance
        #if DEBUG
        debugMenu.appearance = menu.appearance
        #endif
        updateCheckAvailability()
    }

    private func updateCheckAvailability() {
        let available = canCheckForUpdates()
        checkForUpdatesItem.isEnabled = available && !hasDraftChanges && !interactionBusy

    }

    @objc private func checkForUpdates() {
        updateCheckAvailability()
        guard checkForUpdatesItem.isEnabled else { return }
        onCheckForUpdates()
    }

    private func setMenuIcon(_ item: NSMenuItem, symbol: String, color: NSColor? = nil) {
        var image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        if let color {
            image = image?.withSymbolConfiguration(.init(paletteColors: [color]))
        }
        image?.size = NSSize(width: 16, height: 16)
        image?.isTemplate = color == nil
        item.image = image
        item.preferredImageVisibility = .visible
    }

    private func linkItem(_ title: String, destination: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(openLink(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = URL(string: destination)
        let symbol = destination == ProductSupportLinks.koFi ? "cup.and.saucer"
            : destination == ProductSupportLinks.menuSponsor ? "heart.fill" : "globe"
        setMenuIcon(item, symbol: symbol,
            color: destination == ProductSupportLinks.menuSponsor ? .systemRed : nil)
        return item
    }

    @objc private func openLink(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openDiagnostics() {
        onOpenDiagnostics()
    }

    #if DEBUG
    @objc private func refresh() {
        onRefresh()
    }
    #endif

    @objc private func requestAccess() {
        onRequestAccess()
    }

    @objc private func toggleOrdinaryReveal() {
        #if DEBUG
        debugDispatchClickCheckID = debugDispatchClickCheckID
            ?? debugClickCheck.begin(source: "menu", event: "menu action")
        defer { debugDispatchClickCheckID = nil }
        #endif
        fallbackSlotCompaction.beginUserRevealAttempt()
        onToggleOrdinaryReveal()
    }

    @objc private func resumeManaging() {
        onResumeManaging()
    }

    @objc private func stopManaging() {
        #if DEBUG
        if let debugStopManagingAndRestore {
            debugStopManagingAndRestore()
            return
        }
        #endif
        onStopManaging()
    }

    @objc private func restorePreviousPolicy() {
        onRestorePreviousPolicy()
    }

    @objc private func quit() {
        onQuit()
    }
}
