import Testing
@testable import BlennyCore

@Suite("Native overflow classification")
struct NativeOverflowClassifierTests {
    @Test("MenuBarAgent overflow is presentation state")
    func marksOverflowControl() {
        let result = NativeOverflowClassifier.classify(
            ownerBundleIdentifier: "com.apple.MenuBarAgent",
            role: "AXButton",
            title: nil,
            itemDescription: "Show more menu bar items",
            accessibilityIdentifier: "com.apple.menubar.overflow"
        )

        #expect(result.classification == .nativeOverflowPresentationControl)
    }

    @Test("unknown MenuBarAgent controls are never manageable")
    func excludesUnknownSystemControl() {
        let result = NativeOverflowClassifier.classify(
            ownerBundleIdentifier: "com.apple.MenuBarAgent",
            role: "AXButton",
            title: "System control",
            itemDescription: nil,
            accessibilityIdentifier: nil
        )

        #expect(result.classification == .systemOwnedPresentation)
    }

    @Test("third-party menu bar item is a candidate")
    func findsThirdPartyCandidate() {
        let result = NativeOverflowClassifier.classify(
            ownerBundleIdentifier: "com.example.StatusApp",
            role: "AXMenuBarItem",
            title: "Example",
            itemDescription: nil,
            accessibilityIdentifier: nil
        )

        #expect(result.classification == .manageableCandidate)
    }
}
