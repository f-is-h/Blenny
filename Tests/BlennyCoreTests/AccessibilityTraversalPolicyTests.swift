import Testing
@testable import BlennyCore

@Suite("Accessibility traversal privacy boundary")
struct AccessibilityTraversalPolicyTests {
    @Test("menu bar structures are included")
    func includesMenuBarStructures() {
        #expect(AccessibilityTraversalPolicy.shouldInclude(role: "AXMenuBar", in: .extrasMenuBar))
        #expect(AccessibilityTraversalPolicy.shouldInclude(role: "AXMenuBarItem", in: .extrasMenuBar))
        #expect(AccessibilityTraversalPolicy.shouldInclude(role: "AXButton", in: .extrasMenuBar))
    }

    @Test("application menus and windows are excluded")
    func excludesUnrelatedApplicationUI() {
        #expect(!AccessibilityTraversalPolicy.shouldInclude(role: "AXMenu", in: .extrasMenuBar))
        #expect(!AccessibilityTraversalPolicy.shouldInclude(role: "AXMenuItem", in: .extrasMenuBar))
        #expect(!AccessibilityTraversalPolicy.shouldInclude(role: "AXApplication", in: .extrasMenuBar))
        #expect(!AccessibilityTraversalPolicy.shouldInclude(role: "AXWindow", in: .extrasMenuBar))
    }

    @Test("status item children are not traversed")
    func stopsAtStatusItem() {
        #expect(!AccessibilityTraversalPolicy.shouldTraverseChildren(
            of: "AXMenuBarItem",
            at: 1,
            in: .extrasMenuBar
        ))
        #expect(!AccessibilityTraversalPolicy.shouldTraverseChildren(
            of: "AXButton",
            at: 1,
            in: .extrasMenuBar
        ))
    }

    @Test("agent presentation roots expose only one child level")
    func boundsAgentPresentationTree() {
        #expect(AccessibilityTraversalPolicy.shouldTraverseChildren(
            of: "AXWindow",
            at: 0,
            in: .agentPresentationRoot
        ))
        #expect(!AccessibilityTraversalPolicy.shouldTraverseChildren(
            of: "AXGroup",
            at: 1,
            in: .agentPresentationRoot
        ))
    }

    @Test("only menu-bar-sized agent roots are accepted")
    func validatesPresentationRootGeometry() {
        let menuBarFrame = RectSnapshot(x: 0, y: 0, width: 1_600, height: 30)
        let ordinaryWindowFrame = RectSnapshot(x: 100, y: 100, width: 900, height: 700)

        #expect(AccessibilityTraversalPolicy.isMenuBarPresentationRoot(
            role: "AXWindow",
            frame: menuBarFrame
        ))
        #expect(!AccessibilityTraversalPolicy.isMenuBarPresentationRoot(
            role: "AXWindow",
            frame: ordinaryWindowFrame
        ))
    }

    @Test("custom action metadata is reduced to its semantic first line")
    func sanitizesCustomActionMetadata() {
        #expect(sanitizeActionName(
            "Name:Remove from menu bar\nTarget:0xDEADBEEF\nSelector:privateAction:"
        ) == "Name:Remove from menu bar")
    }
}
