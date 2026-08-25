import Foundation

public struct MenuBarElementClassificationResult: Equatable, Sendable {
    public let classification: MenuBarElementClassification
    public let reason: String

    public init(classification: MenuBarElementClassification, reason: String) {
        self.classification = classification
        self.reason = reason
    }
}

public enum NativeOverflowClassifier {
    public static let menuBarAgentBundleIdentifier = "com.apple.menubaragent"

    private static let candidateRoles = Set([
        "axbutton",
        "axmenubaritem"
    ])

    private static let overflowMarkers = [
        "overflow",
        "double chevron",
        "chevron.forward.2",
        "chevron.backward.2",
        "chevron.left.2",
        "chevron.right.2",
        "hidden menu bar items",
        "more menu bar items",
        "show more menu bar items",
        "additional menu bar items",
        "オーバーフロー",
        "メニューバーの項目をさらに表示",
        "更多菜单栏项目",
        "显示隐藏菜单栏项目",
        "隐藏菜单栏项目",
        "更多選單列項目",
        "顯示隱藏的選單列項目",
        "溢出"
    ]

    public static func classify(
        ownerBundleIdentifier: String?,
        role: String?,
        title: String?,
        itemDescription: String?,
        accessibilityIdentifier: String?
    ) -> MenuBarElementClassificationResult {
        let bundleIdentifier = MenuBarItemIdentityResolver.normalize(ownerBundleIdentifier)
        let normalizedRole = MenuBarItemIdentityResolver.normalize(role) ?? ""
        let searchableText = [accessibilityIdentifier, title, itemDescription]
            .compactMap(MenuBarItemIdentityResolver.normalize)
            .joined(separator: " ")

        if bundleIdentifier == menuBarAgentBundleIdentifier {
            if normalizedRole == "axbutton",
               overflowMarkers.contains(where: searchableText.contains) {
                return MenuBarElementClassificationResult(
                    classification: .nativeOverflowPresentationControl,
                    reason: "MenuBarAgent-owned element matched a native overflow accessibility marker."
                )
            }
            return MenuBarElementClassificationResult(
                classification: .systemOwnedPresentation,
                reason: "MenuBarAgent-owned elements are system presentation state and are never manageable candidates."
            )
        }

        if candidateRoles.contains(normalizedRole) {
            return MenuBarElementClassificationResult(
                classification: .manageableCandidate,
                reason: "Leaf-style element discovered below an application AXExtrasMenuBar."
            )
        }

        return MenuBarElementClassificationResult(
            classification: .structuralElement,
            reason: "Container or non-item element retained only to describe the Accessibility tree."
        )
    }
}
