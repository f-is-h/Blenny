public enum ProductInterfaceSection: String, CaseIterable, Sendable {
    case organize
    case settings
    case support
}

public enum ProductSupportLinks {
    public static let projectWebsite = "https://blenny.fi5h.xyz"
    public static let monthlySponsor =
        "https://github.com/sponsors/f-is-h?frequency=recurring&metadata_project=blenny&metadata_source=app&metadata_placement=about"
    public static let oneTimeSponsor =
        "https://github.com/sponsors/f-is-h?frequency=one-time&metadata_project=blenny&metadata_source=app&metadata_placement=about"
    public static let koFi = "https://ko-fi.com/1atte"
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
        accessibilityPromptRequested: Bool
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
        applyEnabled = hasModel && idle
        resumeEnabled = hasModel && managementRuntimeState.canResume
            && accessibilityTrusted && idle && !hasDraftChanges
        stopEnabled = hasModel && managementEnabled == true && idle
        restoreEnabled = hasModel && recoveryAvailable && idle && !hasDraftChanges
    }
}
