import Foundation

enum AccessibilityTraversalScope {
    case extrasMenuBar
    case agentPresentationRoot
}

enum AccessibilityTraversalPolicy {
    private static let extrasMenuBarRoles = Set([
        "AXButton",
        "AXGroup",
        "AXMenuBar",
        "AXMenuBarItem",
        "AXUnknown"
    ])

    static func shouldInclude(role: String?, in scope: AccessibilityTraversalScope) -> Bool {
        switch scope {
        case .extrasMenuBar:
            guard let role else { return true }
            return extrasMenuBarRoles.contains(role)
        case .agentPresentationRoot:
            return true
        }
    }

    static func shouldTraverseChildren(
        of role: String?,
        at depth: Int,
        in scope: AccessibilityTraversalScope
    ) -> Bool {
        switch scope {
        case .extrasMenuBar:
            guard depth < 8 else { return false }
            return role != "AXMenuBarItem" && role != "AXButton"
        case .agentPresentationRoot:
            return depth < 1
        }
    }

    static func isMenuBarPresentationRoot(role: String?, frame: RectSnapshot?) -> Bool {
        guard role == "AXWindow" || role == "AXMenuBar",
              let frame else {
            return false
        }
        return frame.height > 0 && frame.height <= 64 && frame.width >= 100
    }
}
