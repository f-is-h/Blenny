import AppKit
import BlennyCore
import Combine
import QuartzCore
import SwiftUI

@MainActor
struct ProductInterfaceActions {
    let refresh: () -> Void
    let requestAccess: () -> Void
    let resumeManaging: () -> Void
    let stopManaging: () -> Void
    let restorePreviousPolicy: () -> Void
    let draftDidChange: (PolicyEditorViewModel) -> Void
    let applyDraft: () -> Void
    let openProjectWebsite: () -> Void
    let openMonthlySponsor: () -> Void
    let openOneTimeSponsor: () -> Void
    let openKoFi: () -> Void
    let setLaunchAtLogin: (Bool) -> Void
    let openLoginItemsSettings: () -> Void
}

struct ResolvedPolicyIcon {
    let descriptor: PolicyIconDescriptor
    let displayName: String
    let image: NSImage
}

@MainActor
final class WorkspacePolicyIconResolver {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func applicationIcon(bundleIdentifier: String) -> ResolvedPolicyIcon {
        guard let applicationURL = workspace.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else {
            return fallback(displayName: fallbackDisplayName(for: bundleIdentifier))
        }

        let applicationBundle = Bundle(url: applicationURL)
        let displayName = applicationBundle?
            .object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? applicationBundle?
                .object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
            ?? FileManager.default.displayName(atPath: applicationURL.path)
        guard applicationBundle.flatMap(\.bundleIdentifier).flatMap({
            BundlePolicyIdentity.canonicalKey(for: $0)
        }) == BundlePolicyIdentity.canonicalKey(for: bundleIdentifier),
              applicationBundle.map(hasDeclaredApplicationIcon) == true else {
            return fallback(displayName: displayName)
        }
        let workspaceImage = workspace.icon(forFile: applicationURL.path)
        guard workspaceImage.isValid, !workspaceImage.representations.isEmpty else {
            return fallback(displayName: displayName)
        }
        return ResolvedPolicyIcon(
            descriptor: PolicyIconResolver.applicationDescriptor(
                bundleIdentifier: bundleIdentifier,
                installedApplicationResolved: true
            ),
            displayName: displayName,
            image: sizedCopy(of: workspaceImage)
        )
    }

    func systemIcon(observation: SystemMenuBarItemObservation) -> ResolvedPolicyIcon {
        let descriptor = PolicyIconResolver.systemItemDescriptor(
            observationIdentifier: observation.observationIdentifier
        )
        guard let symbolName = descriptor.symbolName,
              let image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: observation.displayName
              ) else {
            return fallback(displayName: observation.displayName)
        }
        return ResolvedPolicyIcon(
            descriptor: descriptor,
            displayName: observation.displayName,
            image: sizedCopy(of: image)
        )
    }

    private func fallback(displayName: String) -> ResolvedPolicyIcon {
        let image = NSImage(
            systemSymbolName: PolicyIconDescriptor.fallbackSymbolName,
            accessibilityDescription: "Unknown item icon"
        ) ?? NSImage(size: NSSize(width: 38, height: 38))
        return ResolvedPolicyIcon(
            descriptor: .fallback,
            displayName: displayName,
            image: sizedCopy(of: image)
        )
    }

    private func fallbackDisplayName(for bundleIdentifier: String) -> String {
        bundleIdentifier.split(separator: ".").last.map(String.init) ?? bundleIdentifier
    }

    private func hasDeclaredApplicationIcon(_ bundle: Bundle) -> Bool {
        let stringKeys = ["CFBundleIconName", "CFBundleIconFile"]
        if stringKeys.contains(where: {
            (bundle.object(forInfoDictionaryKey: $0) as? String)?.isEmpty == false
        }) {
            return true
        }
        if let iconFiles = bundle.object(forInfoDictionaryKey: "CFBundleIconFiles")
            as? [String], !iconFiles.isEmpty {
            return true
        }
        if let icons = bundle.object(forInfoDictionaryKey: "CFBundleIcons")
            as? [String: Any], !icons.isEmpty {
            return true
        }
        return false
    }

    private func sizedCopy(of image: NSImage) -> NSImage {
        let copy = image.copy() as? NSImage ?? image
        copy.size = NSSize(width: 38, height: 38)
        return copy
    }
}

@MainActor
final class ProductInterfaceModel: ObservableObject {
    @Published var navigation = ProductInterfaceNavigationState()
    @Published private(set) var model: PolicyEditorViewModel?
    @Published private(set) var observationCount = 0
    @Published var discoveryWarnings: [String] = []
    @Published private(set) var recoveryAvailable = false
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var accessibilityPromptRequested = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var statusMessage = "Preparing the policy editor…"
    @Published private(set) var statusIsError = false
    @Published private(set) var isApplying = false
    @Published private(set) var applicationIcons: [String: ResolvedPolicyIcon] = [:]
    @Published private(set) var systemIcons: [String: ResolvedPolicyIcon] = [:]
    @Published private(set) var launchAtLoginState = LaunchAtLoginPresentationState(
        availability: .disabled
    )
    @Published private(set) var candidateGeneration = UUID()
    @Published private(set) var managementRuntimeState: ManagementLoopState = .unknown
    @Published private(set) var developmentMutationAvailable = false

    private let iconResolver = WorkspacePolicyIconResolver()
    private var assignmentCoordinator = PolicyDraftAssignmentCoordinator()

    var controls: ProductInterfaceControlState {
        ProductInterfaceControlState(
            hasModel: model != nil,
            managementEnabled: model?.acceptedPolicy.managementEnabled,
            managementRuntimeState: managementRuntimeState,
            recoveryAvailable: recoveryAvailable,
            hasDraftChanges: model?.hasDraftChanges == true,
            isRefreshing: isRefreshing,
            isApplying: isApplying,
            accessibilityTrusted: accessibilityTrusted,
            accessibilityPromptRequested: accessibilityPromptRequested
        )
    }

    var managementEnabled: Bool? {
        switch managementRuntimeState {
        case .active, .baselineVerified, .ordinaryRevealSession:
            true
        case .stopped, .unsupportedRuntimeContract, .failClosedUnrestricted:
            false
        default:
            nil
        }
    }
    var hasDraftChanges: Bool { model?.hasDraftChanges == true }
    var systemItems: [SystemMenuBarItemObservation] { model?.systemItems ?? [] }

    func navigate(to section: ProductInterfaceSection) {
        var updatedNavigation = navigation
        updatedNavigation.navigate(to: section)
        navigation = updatedNavigation
    }

    func setAccessibilityTrusted(
        _ trusted: Bool,
        hasRequestedSystemPrompt: Bool
    ) {
        accessibilityTrusted = trusted
        accessibilityPromptRequested = hasRequestedSystemPrompt
    }

    func setRefreshing(_ refreshing: Bool) {
        isRefreshing = refreshing
        if refreshing {
            applicationIcons.removeAll()
            systemIcons.removeAll()
        }
    }

    func setApplying(_ applying: Bool) {
        isApplying = applying
    }

    func display(
        model: PolicyEditorViewModel,
        observationCount: Int,
        recoveryAvailable: Bool
    ) {
        self.model = model
        if !model.acceptedPolicy.managementEnabled {
            managementRuntimeState = .stopped
        }
        assignmentCoordinator.replaceCandidateGeneration()
        candidateGeneration = assignmentCoordinator.candidateGeneration
        self.observationCount = observationCount
        self.recoveryAvailable = recoveryAvailable

        let currentIdentifiers = Set(
            model.candidateInventory.candidates.map(\.bundleIdentifier)
        )
        applicationIcons = applicationIcons.filter {
            currentIdentifiers.contains($0.key)
        }
        for candidate in model.candidateInventory.candidates
            where applicationIcons[candidate.bundleIdentifier] == nil {
            applicationIcons[candidate.bundleIdentifier] = iconResolver.applicationIcon(
                bundleIdentifier: candidate.bundleIdentifier
            )
        }

        let currentSystemIdentifiers = Set(
            model.systemItems.map(\.observationIdentifier)
        )
        systemIcons = systemIcons.filter {
            currentSystemIdentifiers.contains($0.key)
        }
        for observation in model.systemItems
            where systemIcons[observation.observationIdentifier] == nil {
            systemIcons[observation.observationIdentifier] = iconResolver.systemIcon(
                observation: observation
            )
        }

        setStatus(
            model.hasDraftChanges
                ? "Draft changes are local and unapplied."
                : "No policy changes. Newly observed apps remain effectively Visible.",
            isError: false
        )
    }

    func setStatus(_ message: String, isError: Bool) {
        statusMessage = message
        statusIsError = isError
    }

    func setLaunchAtLoginState(_ state: LaunchAtLoginPresentationState) {
        launchAtLoginState = state
    }

    func setManagementRuntimeState(
        _ state: ManagementLoopState,
        developmentMutationAvailable: Bool
    ) {
        managementRuntimeState = state
        self.developmentMutationAvailable = developmentMutationAvailable
    }

    func candidates(in policy: MenuBarBundlePolicy) -> [PolicyCandidate] {
        guard let model else { return [] }
        var candidates = model.candidates(in: policy)
        if policy == .visible {
            candidates.append(contentsOf: model.implicitVisibleCandidates)
            candidates.sort {
                ($0.bundleIdentifier.lowercased(), $0.bundleIdentifier)
                    < ($1.bundleIdentifier.lowercased(), $1.bundleIdentifier)
            }
        }
        return candidates
    }

    func candidate(bundleIdentifier: String) -> PolicyCandidate? {
        guard let canonical = BundlePolicyIdentity.canonicalKey(for: bundleIdentifier) else {
            return nil
        }
        return model?.candidateInventory.candidates.first {
            BundlePolicyIdentity.canonicalKey(for: $0.bundleIdentifier) == canonical
        }
    }

    func systemItem(observationIdentifier: String) -> SystemMenuBarItemObservation? {
        systemItems.first { $0.observationIdentifier == observationIdentifier }
    }

    func applicationIcon(for bundleIdentifier: String) -> ResolvedPolicyIcon {
        applicationIcons[bundleIdentifier]
            ?? iconResolver.applicationIcon(bundleIdentifier: bundleIdentifier)
    }

    func systemIcon(for observation: SystemMenuBarItemObservation) -> ResolvedPolicyIcon {
        systemIcons[observation.observationIdentifier]
            ?? iconResolver.systemIcon(observation: observation)
    }

    func isBlenny(_ bundleIdentifier: String) -> Bool {
        guard let model else { return false }
        return BundlePolicyIdentity.canonicalKey(for: bundleIdentifier)
            == BundlePolicyIdentity.canonicalKey(for: model.blennyBundleIdentifier)
    }

    func dragPayload(
        bundleIdentifier: String,
        sourcePolicy: MenuBarBundlePolicy
    ) -> PolicyDragPayload {
        PolicyDragPayload(
            bundleIdentifier: bundleIdentifier,
            sourcePolicy: sourcePolicy,
            candidateGeneration: candidateGeneration
        )
    }

    func validateDrag(
        bundleIdentifier: String,
        sourcePolicy: MenuBarBundlePolicy,
        destination: MenuBarBundlePolicy
    ) -> PolicyDraftAssignmentOutcome {
        guard !isApplying, !isRefreshing else { return .rejected(.interactionInProgress) }
        guard let model else { return .rejected(.unknownCandidate) }
        return assignmentCoordinator.validate(
            payload: PolicyDragPayload(
                bundleIdentifier: bundleIdentifier,
                sourcePolicy: sourcePolicy,
                candidateGeneration: candidateGeneration
            ),
            destination: destination,
            editor: model
        )
    }

    @discardableResult
    func assign(
        payload: PolicyDragPayload,
        destination: MenuBarBundlePolicy
    ) -> PolicyDraftAssignmentOutcome {
        guard !isApplying, !isRefreshing else { return .rejected(.interactionInProgress) }
        guard var editor = model else { return .rejected(.unknownCandidate) }
        let outcome = assignmentCoordinator.assign(
            payload: payload,
            destination: destination,
            editor: &editor
        )
        if outcome.changedDraft {
            model = editor
            setStatus("Draft changes are local and unapplied.", isError: false)
        }
        return outcome
    }

    @discardableResult
    func assign(
        bundleIdentifier: String,
        destination: MenuBarBundlePolicy
    ) -> PolicyDraftAssignmentOutcome {
        guard !isApplying, !isRefreshing else { return .rejected(.interactionInProgress) }
        guard var editor = model else { return .rejected(.unknownCandidate) }
        let outcome = assignmentCoordinator.assign(
            bundleIdentifier: bundleIdentifier,
            destination: destination,
            editor: &editor
        )
        if outcome.changedDraft {
            model = editor
            setStatus("Draft changes are local and unapplied.", isError: false)
        }
        return outcome
    }

    @discardableResult
    func discardDraft() -> PolicyEditorViewModel? {
        guard !isApplying, !isRefreshing else { return nil }
        guard var editor = model else { return nil }
        editor.discardDraft(
            using: BundlePolicyDraft(acceptedPolicy: editor.acceptedPolicy)
        )
        assignmentCoordinator.replaceCandidateGeneration()
        candidateGeneration = assignmentCoordinator.candidateGeneration
        model = editor
        setStatus(
            "Draft discarded. Newly observed apps remain effectively Visible.",
            isError: false
        )
        return editor
    }

    #if DEBUG
    func installPopulatedVisualValidationFixture(accessibilityTrusted: Bool) {
        let blenny = "xyz.fi5h.blenny"
        let safari = "com.apple.Safari"
        let fallback = "com.example.FallbackMenuAgentWithAnIntentionallyLongDisplayName"
        var observations: [MenuBarPolicyOwnershipObservation] = [
            (blenny, 10, 1),
            (safari, 20, 1),
            ("com.apple.mail", 30, 2),
            ("com.apple.Notes", 40, 1),
            ("com.apple.iCal", 50, 1),
            ("com.apple.TextEdit", 60, 1),
            ("com.apple.Preview", 70, 1),
            ("com.apple.ActivityMonitor", 80, 1),
            (fallback, 90, 3),
        ].map { bundleIdentifier, processIdentifier, itemCount in
            MenuBarPolicyOwnershipObservation(
                bundleIdentifier: bundleIdentifier,
                processIdentifier: processIdentifier,
                menuBarItemCount: itemCount
            )
        }
        if ProcessInfo.processInfo.environment["BLENNY_VALIDATE_LONG_LIST"] == "YES" {
            observations.append(contentsOf: (1...12).map { index in
                MenuBarPolicyOwnershipObservation(
                    bundleIdentifier: String(
                        format: "com.example.LongListMenuAgent%02d",
                        index
                    ),
                    processIdentifier: Int32(100 + index),
                    menuBarItemCount: index.isMultiple(of: 4) ? 2 : 1
                )
            })
        }
        let systemItems = [
            SystemMenuBarItemObservation(
                observationIdentifier: "com.apple.menuextra.wifi",
                ownerBundleIdentifier: "com.apple.controlcenter",
                displayName: "Wi-Fi",
                observationCount: 1
            ),
            SystemMenuBarItemObservation(
                observationIdentifier: "com.apple.menuextra.clock",
                ownerBundleIdentifier: "com.apple.controlcenter",
                displayName: "Clock",
                observationCount: 1
            ),
            SystemMenuBarItemObservation(
                observationIdentifier: "com.example.unknown-system-item",
                ownerBundleIdentifier: "com.apple.MenuBarAgent",
                displayName: "Unknown System Item With A Long Name",
                observationCount: 2
            ),
        ]

        do {
            let acceptedPolicy = try PersistentBundlePolicyDocument(
                managementEnabled: ProcessInfo.processInfo.environment[
                    "BLENNY_VALIDATE_MANAGEMENT_ENABLED"
                ] == "YES",
                policies: [
                    .init(bundleIdentifier: blenny, policy: .visible),
                    .init(bundleIdentifier: safari, policy: .revealable),
                    .init(bundleIdentifier: "com.apple.Notes", policy: .visible),
                    .init(bundleIdentifier: "com.apple.TextEdit", policy: .visible),
                    .init(bundleIdentifier: "com.apple.Preview", policy: .visible),
                    .init(bundleIdentifier: "com.apple.ActivityMonitor", policy: .visible),
                    .init(bundleIdentifier: "com.apple.mail", policy: .revealable),
                    .init(bundleIdentifier: "com.apple.iCal", policy: .hidden),
                ]
            )
            let fixture = try PolicyEditorViewModel(
                acceptedPolicy: acceptedPolicy,
                candidateInventory: PolicyCandidateInventory(observations: observations),
                systemItems: systemItems,
                blennyBundleIdentifier: blenny
            )
            display(
                model: fixture,
                observationCount: observations.count,
                recoveryAvailable: true
            )
            setAccessibilityTrusted(
                accessibilityTrusted,
                hasRequestedSystemPrompt: !accessibilityTrusted
            )
        } catch {
            setStatus("Visual validation fixture failed: \(error)", isError: true)
        }
    }

    #endif
}

@MainActor
final class PolicyEditorWindowController: NSWindowController {
    private static let organizePreferredContentSize = NSSize(width: 980, height: 410)
    private static let organizeMinimumContentSize = NSSize(width: 800, height: 410)
    private static let compactPreferredContentSize = NSSize(width: 680, height: 410)
    private static let compactMinimumContentSize = NSSize(width: 560, height: 410)
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

    private let interfaceModel = ProductInterfaceModel()
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
        onOpenLoginItemsSettings: @escaping () -> Void
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
            openLoginItemsSettings: onOpenLoginItemsSettings
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
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.5.0"
        window.title = "Blenny \(version)"
        window.toolbarStyle = .unified
        window.contentMinSize = Self.minimumContentSize(
            for: interfaceModel.navigation.section
        )
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
                self?.resizeWindow(for: section)
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
        recoveryAvailable: Bool
    ) {
        guard !usesPopulatedValidationFixture else { return }
        interfaceModel.display(
            model: model,
            observationCount: observationCount,
            recoveryAvailable: recoveryAvailable
        )
    }

    var candidateGeneration: UUID {
        interfaceModel.candidateGeneration
    }

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
        developmentMutationAvailable: Bool
    ) {
        guard !usesPopulatedValidationFixture else { return }
        interfaceModel.setManagementRuntimeState(
            state,
            developmentMutationAvailable: developmentMutationAvailable
        )
    }

    func setStatus(_ message: String, isError: Bool) {
        guard !usesPopulatedValidationFixture else { return }
        interfaceModel.setStatus(message, isError: isError)
    }

    func setLaunchAtLoginState(_ state: LaunchAtLoginPresentationState) {
        interfaceModel.setLaunchAtLoginState(state)
    }

    func setApplying(_ applying: Bool) {
        interfaceModel.setApplying(applying)
    }

    private func restoreUsableWindowSizeIfNeeded() {
        guard let window else { return }
        let section = interfaceModel.navigation.section
        let minimumContentSize = Self.minimumContentSize(for: section)
        let preferredContentSize = Self.preferredContentSize(for: section)
        window.contentMinSize = minimumContentSize
        let contentSize = window.contentLayoutRect.size
        guard contentSize.width < minimumContentSize.width
                || contentSize.height < minimumContentSize.height else {
            return
        }

        let visibleSize = (window.screen ?? NSScreen.main)?.visibleFrame.size
        let targetSize = NSSize(
            width: min(
                preferredContentSize.width,
                max(minimumContentSize.width, (visibleSize?.width ?? 980) - 80)
            ),
            height: min(
                preferredContentSize.height,
                max(minimumContentSize.height, (visibleSize?.height ?? 500) - 80)
            )
        )
        window.setContentSize(targetSize)
        window.center()
    }

    private func resizeWindow(for section: ProductInterfaceSection) {
        guard let window else { return }
        let minimumContentSize = Self.minimumContentSize(for: section)
        let preferredContentSize = Self.preferredContentSize(for: section)
        let oldFrame = window.frame
        let targetContentSize = NSSize(
            width: preferredContentSize.width,
            height: preferredContentSize.height
        )
        var contentRect = window.contentRect(forFrameRect: oldFrame)
        contentRect.size = targetContentSize
        var newFrame = window.frameRect(forContentRect: contentRect)
        newFrame.origin.x = oldFrame.origin.x
        newFrame.origin.y = oldFrame.maxY - newFrame.height
        window.contentMinSize = minimumContentSize
        if effectiveReduceMotion {
            window.setFrame(newFrame, display: true)
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.30
                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: 0.25,
                    0.10,
                    0.25,
                    1.00
                )
                window.animator().setFrame(newFrame, display: true)
            }
        }
    }

    private var effectiveReduceMotion: Bool {
        let systemPrefersReducedMotion = NSWorkspace.shared
            .accessibilityDisplayShouldReduceMotion
        #if DEBUG
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
