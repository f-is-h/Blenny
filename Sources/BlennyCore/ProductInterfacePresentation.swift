public enum ProductInterfaceSection: String, CaseIterable, Sendable {
    case organize
    case settings
    case support
}

public enum ProductSupportLinks {
    public static let documentation = "https://github.com/f-is-h/Blenny#readme"
    public static let projectWebsite = "https://blenny.fi5h.xyz"
    public static let monthlySponsor =
        "https://github.com/sponsors/f-is-h?frequency=recurring&metadata_project=blenny&metadata_source=app&metadata_placement=about"
    public static let oneTimeSponsor =
        "https://github.com/sponsors/f-is-h?frequency=one-time&metadata_project=blenny&metadata_source=app&metadata_placement=about"
    public static let menuSponsor =
        "https://github.com/sponsors/f-is-h?metadata_project=blenny&metadata_source=app&metadata_placement=menu"
    public static let koFi = "https://ko-fi.com/blenny"
}

public enum BlennyFishPlacement {
    /// Stable AppKit identity for the fish only. It must not contain a version
    /// number because macOS owns persistence across Blenny updates.
    public static let autosaveName = "Blenny.Fish"

    public static func guideAvailable(
        for snapshot: NativeOverflowObservationSnapshot
    ) -> Bool {
        snapshot.isUsable
    }
}

public struct ProductInterfaceNavigationState: Equatable, Sendable {
    public private(set) var section: ProductInterfaceSection

    public init(
        section: ProductInterfaceSection = .organize
    ) {
        self.section = section
    }

    public mutating func navigate(to section: ProductInterfaceSection) {
        self.section = section
    }
}

public enum ProductInterfacePermissionState: Equatable, Sendable {
    case granted
    case notRequested
    case requestedButNotGranted
}

public enum LaunchAtLoginAvailability: Equatable, Sendable {
    case disabled
    case enabled
    case requiresApproval
    case notFound
}

public struct LaunchAtLoginPresentationState: Equatable, Sendable {
    public let availability: LaunchAtLoginAvailability
    public let failureMessage: String?

    public init(
        availability: LaunchAtLoginAvailability,
        failureMessage: String? = nil
    ) {
        self.availability = availability
        self.failureMessage = failureMessage
    }

    public var isEnabled: Bool {
        availability == .enabled
    }

    public var isToggleOn: Bool {
        availability == .enabled || availability == .requiresApproval
    }

    public var requiresApproval: Bool {
        availability == .requiresApproval
    }

    public var statusDescription: String {
        if let failureMessage {
            return "Could not update this setting: \(failureMessage)"
        }
        switch availability {
        case .disabled:
            return "Blenny will open only when you launch it."
        case .enabled:
            return "Blenny opens automatically after you log in."
        case .requiresApproval:
            return "Approval is required in System Settings before Blenny can open at login."
        case .notFound:
            return "Blenny is not registered as a login item for this installation."
        }
    }
}

public struct ProductInterfaceControlState: Equatable, Sendable {
    public let permission: ProductInterfacePermissionState
    public let refreshEnabled: Bool
    public let discardDraftEnabled: Bool
    public let applyEnabled: Bool
    public let resumeEnabled: Bool
    public let stopEnabled: Bool
    public let restoreEnabled: Bool

    public init(
        hasModel: Bool,
        managementEnabled: Bool?,
        managementRuntimeState: ManagementLoopState,
        recoveryAvailable: Bool,
        hasDraftChanges: Bool,
        isRefreshing: Bool,
        isApplying: Bool = false,
        accessibilityTrusted: Bool,
        accessibilityPromptRequested: Bool,
        requiresObservationRefresh: Bool = false
    ) {
        if accessibilityTrusted {
            permission = .granted
        } else if accessibilityPromptRequested {
            permission = .requestedButNotGranted
        } else {
            permission = .notRequested
        }

        let idle = !isRefreshing && !isApplying
        refreshEnabled = idle && !hasDraftChanges
        discardDraftEnabled = hasDraftChanges && idle
        applyEnabled = hasModel && idle && !requiresObservationRefresh
        resumeEnabled = hasModel && managementRuntimeState.canResume
            && accessibilityTrusted && idle && !hasDraftChanges && !requiresObservationRefresh
        stopEnabled = hasModel && managementEnabled == true && idle
        restoreEnabled = hasModel && recoveryAvailable && idle && !hasDraftChanges && !requiresObservationRefresh
    }
}

/// Shared user-facing management state. Presentation never changes availability
/// or initiates recovery; those decisions remain with the management controller.
public struct ProductManagementPresentation: Equatable, Sendable {
    public let title: String
    public let detail: String
    public let symbolName: String
    public let isError: Bool

    public init(state: ManagementLoopState) {
        switch state {
        case .unknown:
            title = "Checking management…"
            detail = "Checking your saved settings."
            symbolName = "ellipsis.circle"
            isError = false
        case .stopped, .acceptedPolicyLoadedInactive:
            title = "Management stopped"
            detail = "Resume to use your saved visibility settings. Applied order is unchanged."
            symbolName = "pause.circle"
            isError = false
        case .writerActivating:
            title = "Starting management…"
            detail = "Checking and applying your saved visibility settings."
            symbolName = "ellipsis.circle"
            isError = false
        case .baselineVerified, .active:
            title = "Management on"
            detail = "Expand to show Revealable items. Hidden items stay hidden."
            symbolName = "checkmark.circle.fill"
            isError = false
        case .ordinaryRevealSession:
            title = "Revealable items expanded"
            detail = "Collapse to hide Revealable items again. Hidden items stay hidden."
            symbolName = "eye"
            isError = false
        case .applying:
            title = "Applying changes…"
            detail = "Wait for your changes to finish."
            symbolName = "ellipsis.circle"
            isError = false
        case .stopping:
            title = "Stopping management…"
            detail = "Releasing visibility restrictions. Applied order stays unchanged."
            symbolName = "ellipsis.circle"
            isError = false
        case .restoring:
            title = "Restoring visibility…"
            detail = "Wait for visibility restoration to finish."
            symbolName = "arrow.counterclockwise"
            isError = false
        case .terminating:
            title = "Quitting Blenny…"
            detail = "Releasing visibility restrictions. Applied order stays unchanged."
            symbolName = "ellipsis.circle"
            isError = false
        case .unsupportedRuntimeContract:
            title = "Management unavailable"
            detail = "This macOS build is not supported. No visibility restrictions were applied."
            symbolName = "exclamationmark.circle"
            isError = false
        case .connectionInvalidated:
            title = "Connection ended"
            detail = "Quit and reopen Blenny before resuming management."
            symbolName = "exclamationmark.circle"
            isError = true
        case .failClosedUnrestricted:
            title = "Management paused"
            detail = "Visibility restrictions were removed. Check the reported issue before resuming."
            symbolName = "pause.circle"
            isError = false
        case .restorationFailed:
            title = "Recovery needs attention"
            detail = "Visibility restoration could not be confirmed. Blenny will quit to release its connection."
            symbolName = "exclamationmark.triangle.fill"
            isError = true
        }
    }
}
