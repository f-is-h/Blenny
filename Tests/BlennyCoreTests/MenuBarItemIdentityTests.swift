import Testing
@testable import BlennyCore

@Suite("MenuBar item identity")
struct MenuBarItemIdentityTests {
    @Test("normalization folds case, diacritics, and whitespace")
    func normalization() {
        #expect(MenuBarItemIdentityResolver.normalize("  Ménu\u{00A0}  Item\n") == "menu item")
        #expect(MenuBarItemIdentityResolver.normalize(" \t\n ") == nil)
        #expect(MenuBarItemIdentityResolver.normalizeSemanticLabel("CPU 42%") == "cpu {number}%")
    }

    @Test("an Accessibility identifier takes precedence over a changing title")
    func identifierTakesPrecedence() throws {
        let first = MenuBarItemIdentityResolver.resolve([
            candidate(observationKey: "one", identifier: "Status.Main", title: "Connected")
        ])
        let second = MenuBarItemIdentityResolver.resolve([
            candidate(observationKey: "two", identifier: "status.main", title: "Disconnected")
        ])

        #expect(try #require(first.first).identity == #require(second.first).identity)
        #expect(try #require(first.first).identity.confidence == .strong)
    }

    @Test("changing numeric status text does not change identity")
    func masksVolatileNumericText() throws {
        let first = MenuBarItemIdentityResolver.resolve([
            candidate(observationKey: "one", title: "Usage 41%")
        ])
        let second = MenuBarItemIdentityResolver.resolve([
            candidate(observationKey: "two", title: "Usage 42%")
        ])

        #expect(try #require(first.first).identity == #require(second.first).identity)
        #expect(try #require(first.first).identity.semanticLabel == "usage {number}%")
        #expect(try #require(first.first).identity.confidence == .weak)
    }

    @Test("numeric Accessibility identifiers remain distinct")
    func preservesNumbersInIdentifiers() throws {
        let first = MenuBarItemIdentityResolver.resolve([
            candidate(observationKey: "one", identifier: "status.1")
        ])
        let second = MenuBarItemIdentityResolver.resolve([
            candidate(observationKey: "two", identifier: "status.2")
        ])

        #expect(try #require(first.first).identity != #require(second.first).identity)
    }

    @Test("duplicate observations are removed before identities are assigned")
    func duplicateObservations() {
        let resolved = MenuBarItemIdentityResolver.resolve([
            candidate(observationKey: "same", identifier: "status.main"),
            candidate(observationKey: "same", identifier: "status.main")
        ])

        #expect(resolved.count == 1)
    }

    @Test("multiple semantic matches receive deterministic instance ordinals")
    func ordinals() {
        let resolved = MenuBarItemIdentityResolver.resolve([
            candidate(observationKey: "first", title: "Monitor"),
            candidate(observationKey: "second", title: "Monitor")
        ])

        #expect(resolved.map(\.identity.instanceOrdinal) == [0, 1])
        #expect(resolved[0].identity.stableKey != resolved[1].identity.stableKey)
    }

    @Test("identity contains neither PID nor position")
    func excludesTransientCoordinates() throws {
        let resolved = MenuBarItemIdentityResolver.resolve([
            candidate(observationKey: "session-a", identifier: nil, title: "Example")
        ])
        let identity = try #require(resolved.first).identity

        #expect(!identity.stableKey.contains("pid"))
        #expect(!identity.stableKey.contains("position"))
        #expect(identity.confidence == .moderate)
    }

    private func candidate(
        observationKey: String,
        identifier: String? = nil,
        title: String? = nil
    ) -> MenuBarItemIdentityCandidate {
        MenuBarItemIdentityCandidate(
            observationKey: observationKey,
            ownerBundleIdentifier: "COM.Example.StatusApp",
            accessibilityIdentifier: identifier,
            title: title,
            itemDescription: nil,
            role: "AXMenuBarItem",
            subrole: "AXApplicationDockItem"
        )
    }
}
