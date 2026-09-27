import Foundation

public enum ManagementLifecycleEvent: Equatable, Sendable {
    case willSleep, didWake, sessionChanged, displayChanged, spaceChanged, permissionLost
    case applicationLaunched(String?)
    case applicationTerminated(String?)
    case menuBarAgentChanged

    public var reason: String {
        switch self {
        case .willSleep: "System sleep invalidated the management context."
        case .didWake: "System wake requires fresh management validation."
        case .sessionChanged: "The active login or display session changed."
        case .displayChanged: "The display configuration changed."
        case .spaceChanged: "The active Space changed."
        case .permissionLost: "Accessibility permission is no longer granted."
        case let .applicationLaunched(identifier):
            "A new application (\(identifier ?? "unidentified")) needs a visibility check. Choose Resume to include it."
        case .applicationTerminated: "A managed application exited."
        case .menuBarAgentChanged: "The MenuBarAgent connection changed. Quit and reopen Blenny."
        }
    }
}

/// A safety invalidation policy, not a reconciliation planner. It produces no
/// new allow-list and never grants authority to a newly observed application.
public enum ManagementLifecyclePolicy {
    public enum ApplicationLaunchAssessment: Equatable, Sendable {
        case noMenuBarItems
        case menuBarItemsPresent
        case unavailable
    }

    public static func assessApplicationLaunch(
        discovery: ApplicationMenuBarDiscovery?,
        observedMenuBarItemCount: Int,
        captureComplete: Bool
    ) -> ApplicationLaunchAssessment {
        guard let discovery else { return .unavailable }
        switch discovery.outcome {
        case .noExtrasMenuBar:
            return .noMenuBarItems
        case .unavailable:
            return .unavailable
        case .observed:
            guard captureComplete else { return .unavailable }
            return observedMenuBarItemCount > 0
                ? .menuBarItemsPresent : .noMenuBarItems
        }
    }

    public static func invalidates(
        applicationLaunchAssessment assessment: ApplicationLaunchAssessment
    ) -> Bool {
        assessment != .noMenuBarItems
    }

    public static func invalidates(
        _ event: ManagementLifecycleEvent,
        managedBundleIdentifiers: Set<String>,
        allowedBundleIdentifiers: Set<String>,
        blennyBundleIdentifier: String
    ) -> Bool {
        let managed = Set(managedBundleIdentifiers.map { $0.lowercased() })
        let allowed = Set(allowedBundleIdentifiers.map { $0.lowercased() })
        switch event {
        case let .applicationLaunched(identifier):
            guard let identifier else { return true }
            let key = identifier.lowercased()
            if key == blennyBundleIdentifier.lowercased() { return false }
            // Assertions and accepted policy are bundle-scoped, not PID-scoped.
            // A known bundle returning does not change either allow/deny plan.
            return !managed.contains(key) && !allowed.contains(key)
        case .applicationTerminated:
            // Retain accepted intent across absence and multi-process churn.
            // MenuBarAgent loss is classified separately by the caller.
            return false
        default:
            return true
        }
    }

    /// Only accepted policy or an existing pass-through allowance can exempt a
    /// launch. Activation policy alone does not prove absence of a status item.
    public static func requiresLaunchAssessment(
        bundleIdentifier: String?,
        acceptedBundleIdentifiers: Set<String>,
        allowedBundleIdentifiers: Set<String>,
        blennyBundleIdentifier: String
    ) -> Bool {
        invalidates(
            .applicationLaunched(bundleIdentifier),
            managedBundleIdentifiers: acceptedBundleIdentifiers,
            allowedBundleIdentifiers: allowedBundleIdentifiers,
            blennyBundleIdentifier: blennyBundleIdentifier
        )
    }
}
