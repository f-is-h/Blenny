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
        case .applicationLaunched: "Application launch changed the frozen management scope."
        case .applicationTerminated: "A managed application exited."
        case .menuBarAgentChanged: "The MenuBarAgent connection changed. Quit and reopen Blenny."
        }
    }
}

/// A safety invalidation policy, not a reconciliation planner. It produces no
/// new allow-list and never grants authority to a newly observed application.
public enum ManagementLifecyclePolicy {
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
            return managed.contains(key) || !allowed.contains(key)
        case let .applicationTerminated(identifier):
            guard let identifier else { return false }
            let key = identifier.lowercased()
            return key != blennyBundleIdentifier.lowercased() && managed.contains(key)
        default:
            return true
        }
    }
}
