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

    @Test("localized macOS 27 overflow label is recognized")
    func marksLocalizedOverflowControl() {
        let result = NativeOverflowClassifier.classify(
            ownerBundleIdentifier: "com.apple.MenuBarAgent",
            role: "AXButton",
            title: nil,
            itemDescription: "显示隐藏菜单栏项目",
            accessibilityIdentifier: nil
        )

        #expect(result.classification == .nativeOverflowPresentationControl)
    }

    @Test("All resource locale pairs classify exactly and reject ambiguity", arguments: NativeOverflowLocaleFixture.all)
    func resourceLocalePair(labels: NativeOverflowLocaleFixture.Labels) {
        for (label, state) in [(labels.collapsed, NativeOverflowPresentationState.collapsed), (labels.expanded, .expanded)] {
            #expect(NativeOverflowClassifier.classify(
                ownerBundleIdentifier: "com.apple.MenuBarAgent", role: "AXButton",
                title: label, itemDescription: nil, accessibilityIdentifier: nil
            ).classification == .nativeOverflowPresentationControl)
            #expect(NativeOverflowPresentationStateClassifier.classify(
                title: nil, itemDescription: label, accessibilityIdentifier: nil
            ) == state)
            #expect(NativeOverflowClassifier.classify(
                ownerBundleIdentifier: "com.apple.MenuBarAgent", role: "AXGroup",
                title: label, itemDescription: nil, accessibilityIdentifier: nil
            ).classification == .systemOwnedPresentation)
            #expect(NativeOverflowClassifier.classify(
                ownerBundleIdentifier: "com.example.StatusApp", role: "AXButton",
                title: label, itemDescription: nil, accessibilityIdentifier: nil
            ).classification == .manageableCandidate)
            #expect(NativeOverflowPresentationStateClassifier.classify(
                title: nil, itemDescription: label + " unexpected suffix", accessibilityIdentifier: nil
            ) == .unknown)
        }
        #expect(NativeOverflowPresentationStateClassifier.classify(
            title: labels.collapsed, itemDescription: labels.expanded, accessibilityIdentifier: nil
        ) == .unknown)
    }

    @Test("overflow text on a non-button remains generic system presentation")
    func rejectsNonButtonOverflowMarker() {
        let result = NativeOverflowClassifier.classify(
            ownerBundleIdentifier: "com.apple.MenuBarAgent",
            role: "AXGroup",
            title: nil,
            itemDescription: "显示隐藏菜单栏项目",
            accessibilityIdentifier: nil
        )

        #expect(result.classification == .systemOwnedPresentation)
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

@Suite("Native overflow presentation state")
struct NativeOverflowPresentationStateTests {
    @Test("Live Simplified Chinese collapsed label is recognized")
    func collapsedLabel() {
        #expect(
            NativeOverflowPresentationStateClassifier.classify(
                title: nil,
                itemDescription: "显示隐藏菜单栏项目",
                accessibilityIdentifier: nil
            ) == .collapsed
        )
    }

    @Test("Live Simplified Chinese expanded label is recognized")
    func expandedLabel() {
        #expect(
            NativeOverflowPresentationStateClassifier.classify(
                title: nil,
                itemDescription: "隐藏菜单栏项目",
                accessibilityIdentifier: nil
            ) == .expanded
        )
    }

    @Test("Unknown labels never guess an expanded state")
    func unknownLabel() {
        #expect(
            NativeOverflowPresentationStateClassifier.classify(
                title: nil,
                itemDescription: "Unrelated control",
                accessibilityIdentifier: nil
            ) == .unknown
        )
    }

    @Test("English expanded labels cannot match a shorter collapsed substring", arguments: [
        "Hide more menu bar items", "Hide hidden menu bar items"
    ])
    func englishExpanded(_ description: String) {
        #expect(NativeOverflowPresentationStateClassifier.classify(
            title: nil, itemDescription: description, accessibilityIdentifier: nil
        ) == .expanded)
    }

    @Test("Contradictory or extended labels remain unknown")
    func ambiguousLabels() {
        #expect(NativeOverflowPresentationStateClassifier.classify(
            title: "Show more menu bar items", itemDescription: "Hide more menu bar items",
            accessibilityIdentifier: nil
        ) == .unknown)
        #expect(NativeOverflowPresentationStateClassifier.classify(
            title: nil, itemDescription: "Unexpected show more menu bar items behavior",
            accessibilityIdentifier: nil
        ) == .unknown)
    }
}
