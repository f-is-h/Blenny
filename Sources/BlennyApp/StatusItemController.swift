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
    private let permissionItem = NSMenuItem(title: "Accessibility: Checking…", action: nil, keyEquivalent: "")
    private let managementStateItem = NSMenuItem(title: "Management: Checking…", action: nil, keyEquivalent: "")
    private let ordinaryRevealItem = NSMenuItem(title: "Reveal Revealable Items", action: #selector(toggleOrdinaryReveal), keyEquivalent: "")
    private let refreshItem = NSMenuItem(title: "Refresh Menu Bar Items", action: #selector(refresh), keyEquivalent: "r")
    private let resumeManagingItem = NSMenuItem(title: "Resume Managing", action: #selector(resumeManaging), keyEquivalent: "")
    private let stopManagingItem = NSMenuItem(title: "Stop Managing", action: #selector(stopManaging), keyEquivalent: "")
    private let restorePreviousPolicyItem = NSMenuItem(title: "Restore Previous Policy", action: #selector(restorePreviousPolicy), keyEquivalent: "")
    private let menu = NSMenu()
    private var hasDraftChanges = false
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
        onVerifyNativeOverflowAfterSlotCompaction: @escaping () -> Void = {}
    ) {
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
        permissionItem.title = trusted ? "Accessibility: Granted" : "Accessibility: Not Granted"
        updateResumeAvailability()
    }

    func setRefreshing(_ refreshing: Bool) {
        refreshItem.isEnabled = !refreshing && !hasDraftChanges && !interactionBusy
        refreshItem.title = refreshing ? "Refreshing Menu Bar Items…" : "Refresh Menu Bar Items"
    }

    func setDraftHasChanges(_ hasChanges: Bool) {
        hasDraftChanges = hasChanges
        refreshItem.isEnabled = !hasChanges && !interactionBusy
        updateResumeAvailability()
        restorePreviousPolicyItem.isEnabled = currentRecoveryAvailable && !interactionBusy && !hasChanges
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
        case .active, .baselineVerified, .ordinaryRevealSession:
            managementStateItem.title = "Management: On"
        case .stopped:
            managementStateItem.title = "Management: Stopped"
        case .unsupportedRuntimeContract:
            managementStateItem.title = "Management: Unsupported"
        case .failClosedUnrestricted, .connectionInvalidated:
            managementStateItem.title = "Management: Restored"
        case .restorationFailed:
            managementStateItem.title = "Management: Cleanup Failed"
        default:
            managementStateItem.title = "Management: Preparing"
        }
        switch state {
        case .active:
            ordinaryRevealItem.title = "Reveal Revealable Items"
            ordinaryRevealItem.isEnabled = true
        case .ordinaryRevealSession:
            ordinaryRevealItem.title = "Conceal Revealable Items"
            ordinaryRevealItem.isEnabled = true
        default:
            ordinaryRevealItem.title = "Reveal Revealable Items"
            ordinaryRevealItem.isEnabled = false
        }
        ordinaryRevealItem.isEnabled = ordinaryRevealItem.isEnabled
            && hasRevealableBundles && !interactionBusy
        updateResumeAvailability()
        stopManagingItem.isEnabled = persistedManagementEnabled && !interactionBusy
        restorePreviousPolicyItem.isEnabled = recoveryAvailable && !interactionBusy && !hasDraftChanges
        updateNormalButton()
    }

    func setInteractionBusy(_ busy: Bool) {
        interactionBusy = busy
        refreshItem.isEnabled = !busy && !hasDraftChanges
        setManagementState(
            currentManagementState,
            persistedManagementEnabled: currentManagementEnabled,
            recoveryAvailable: currentRecoveryAvailable,
            hasRevealableBundles: hasRevealableBundles
        )
    }

    private func updateResumeAvailability() {
        resumeManagingItem.isEnabled = currentManagementState.canResume
            && accessibilityTrusted && !interactionBusy && !hasDraftChanges
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
        // A MenuBarAgent layout notification may result from this presentation
        // itself. Never resubmit unchanged content in response to that event.
        guard normalPresentation != lastRenderedPresentation
                || slotUpdate.allocation != lastFallbackSlotAllocation else { return }
        lastRenderedPresentation = normalPresentation
        lastFallbackSlotAllocation = slotUpdate.allocation
        button.image = blennyImage
        button.title = blennyImage == nil ? "B" : ""
        statusItem.length = Self.ordinaryStatusItemLength
        let arrowImage = NSImage(systemSymbolName: normalPresentation.nativeArrowSymbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: ManagementStatusPresentation.arrowPointSize, weight: .medium))
        arrowImage?.isTemplate = true
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
        ordinaryRevealItem.isEnabled = normalPresentation.canToggleReveal
        button.setAccessibilityLabel("Open Blenny")
        button.setAccessibilityHelp("Right-click to open Blenny, stop managing, or restore the previous policy.")
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
        switch action {
        case .toggleReveal:
            // Exactly the same entry point as the working safety-menu action.
            toggleOrdinaryReveal()
        case .openMenu:
            _ = openNormalMenu()
        case .openEditor:
            onOpenDiagnostics()
        case .ignore:
            break
        }
    }

    @objc private func openNormalMenu() -> Bool {
        guard let button = statusItem.button else { return false }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
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
    var debugOrdinaryRevealButtonEnabled: Bool { revealStatusItem?.button?.isEnabled == true }
    /// Local AppKit presentation only; this does not prove physical visibility
    /// outside macOS overflow.
    var debugOrdinaryRevealButtonVisible: Bool {
        revealStatusItem?.isVisible == true && revealStatusItem?.button?.isHidden == false
            && revealStatusItem?.button?.image != nil
    }
    var debugOrdinaryRevealButtonReservedWidth: CGFloat {
        revealStatusItem?.length ?? 0
    }
    var debugOrdinaryRevealSlotMode: String {
        guard revealStatusItem != nil else { return "absent" }
        return revealStatusItem?.length == Self.ordinaryStatusItemLength
            ? "reserved" : "compact"
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
        }
        return true
    }
    var debugOrdinaryRevealArrowOnLeft: Bool {
        guard let arrowFrame = revealStatusItem?.button?.window?.frame,
              let artworkFrame = statusItem.button?.window?.frame else { return false }
        return arrowFrame.midX < artworkFrame.midX
    }
    var debugOrdinaryRevealHasDedicatedButton: Bool {
        guard let arrow = revealStatusItem?.button else { return false }
        return arrow !== statusItem.button
            && arrow.target as? StatusItemController === self
            && arrow.action == #selector(handleRevealStatusButton(_:))
            && statusItem.button?.action == #selector(handleNormalStatusButton(_:))
    }

    func configureDebugRevealPrototype(
        onToggle: @escaping () -> Void,
        onStopManagingAndRestore: @escaping () -> Void
    ) {
        revealPrototypeToggle = onToggle
        debugStopManagingAndRestore = onStopManagingAndRestore
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
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.5.0"
        button.toolTip = "Blenny \(version)"
    }

    private func configureRevealStatusItem() {
        // Create the fallback before the first inventory. It is removed or
        // recreated only by the bounded native-overflow fallback tiers, never on
        // ordinary management transitions.
        _ = ensureRevealStatusItem()
        updateNormalButton()
    }

    private func ensureRevealStatusItem() -> NSStatusItem {
        if let revealStatusItem { return revealStatusItem }
        let item = NSStatusBar.system.statusItem(
            withLength: Self.ordinaryStatusItemLength
        )
        revealStatusItem = item
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
        let openItem = NSMenuItem(title: "Open Blenny", action: #selector(openDiagnostics), keyEquivalent: "o")
        let requestItem = NSMenuItem(title: "Accessibility Setup…", action: #selector(requestAccess), keyEquivalent: "")
        let quitItem = NSMenuItem(title: "Quit Blenny", action: #selector(quit), keyEquivalent: "q")

        for item in [
            openItem,
            refreshItem,
            requestItem,
            ordinaryRevealItem,
            resumeManagingItem,
            stopManagingItem,
            restorePreviousPolicyItem,
            quitItem,
        ] {
            item.target = self
        }
        managementStateItem.isEnabled = false
        stopManagingItem.isEnabled = false
        ordinaryRevealItem.isEnabled = false
        resumeManagingItem.isEnabled = false
        restorePreviousPolicyItem.isEnabled = false
        permissionItem.isEnabled = false

        menu.addItem(openItem)
        menu.addItem(refreshItem)
        menu.addItem(.separator())
        menu.addItem(managementStateItem)
        menu.addItem(ordinaryRevealItem)
        menu.addItem(resumeManagingItem)
        menu.addItem(stopManagingItem)
        menu.addItem(restorePreviousPolicyItem)
        menu.addItem(.separator())
        menu.addItem(permissionItem)
        menu.addItem(requestItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
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

    @objc private func toggleOrdinaryReveal() {
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
