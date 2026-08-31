import Testing
@testable import BlennyCore

@Suite("Canonical native overflow discovery")
struct NativeOverflowTreeDiscoveryTests {
    private struct Node {
        let role: String
        var isControl = false
        var children: [Int] = []
    }

    private func discover(_ nodes: [Int: Node], root: Int = 0, maximumElements: Int = 256) throws -> [Int] {
        try NativeOverflowTreeDiscovery.discover(
            in: root, maximumElements: maximumElements, withinDeadline: { true },
            sameElement: ==,
            describe: { .init(role: nodes[$0]?.role, isOverflowControl: nodes[$0]?.isControl == true) },
            children: { nodes[$0]?.children ?? [] }
        )
    }

    @Test("Separate application-window presentations cannot create primary-root ambiguity")
    func onlyCanonicalRoot() throws {
        let nodes = [
            0: Node(role: "AXMenuBar", children: [1]),
            1: Node(role: "AXButton", isControl: true),
            2: Node(role: "AXWindow", children: [3]),
            3: Node(role: "AXButton", isControl: true)
        ]
        #expect(try discover(nodes) == [1])
        #expect(try discover([0: Node(role: "AXMenuBar"), 2: nodes[2]!, 3: nodes[3]!]).isEmpty)
    }

    @Test("True multiple controls in the extras root remain ambiguous")
    func multiplePrimaryControls() throws {
        let nodes = [
            0: Node(role: "AXMenuBar", children: [1, 2]),
            1: Node(role: "AXButton", isControl: true),
            2: Node(role: "AXButton", isControl: true)
        ]
        let controls = try discover(nodes)
        #expect(controls == [1, 2])
        let snapshot = NativeOverflowObservationSnapshot.observed(
            states: controls.map { _ in .collapsed }, controlIdentifier: nil
        )
        #expect(!snapshot.isUsable)
    }

    @Test("Repeated handles and cycles do not duplicate a control")
    func repeatedHandles() throws {
        #expect(try discover([
            0: Node(role: "AXMenuBar", children: [1, 1, 2]),
            1: Node(role: "AXButton", isControl: true),
            2: Node(role: "AXGroup", children: [0, 1])
        ]) == [1])
    }

    @Test("Application menus, unrelated windows and non-control buttons are terminal")
    func unrelatedSubtreesAreSkipped() throws {
        #expect(try discover([
            0: Node(role: "AXMenuBar", children: [1, 2, 3, 4]),
            1: Node(role: "AXMenuBarItem", children: [5]),
            2: Node(role: "AXWindow", children: [5]),
            3: Node(role: "AXButton", children: [5]),
            4: Node(role: "AXButton", isControl: true),
            5: Node(role: "AXButton", isControl: true)
        ]) == [4])
    }

    @Test("Element, queue and depth limits fail rather than return partial discovery")
    func finiteTraversal() {
        #expect(throws: NativeOverflowTreeDiscovery.Failure.elementLimit) {
            try discover([0: Node(role: "AXMenuBar", children: [1, 2, 3])], maximumElements: 2)
        }
        #expect(throws: NativeOverflowTreeDiscovery.Failure.elementLimit) {
            try discover([0: Node(role: "AXMenuBar", children: [1]), 1: Node(role: "AXButton", isControl: true)], maximumElements: 1)
        }
        let chain = Dictionary(uniqueKeysWithValues: (0...9).map {
            ($0, Node(role: "AXGroup", children: $0 < 9 ? [$0 + 1] : []))
        })
        #expect(throws: NativeOverflowTreeDiscovery.Failure.depthLimit) { try discover(chain) }
    }

    @Test("An expired deadline cannot return a partially observed control")
    func deadlineIsNotAbsence() {
        var checks = 0
        let withinDeadline: () -> Bool = {
            checks += 1
            return checks < 3
        }
        let description: (Int) -> NativeOverflowTreeDiscovery.Description = { node in
            .init(role: node == 0 ? "AXMenuBar" : "AXButton", isOverflowControl: node == 1)
        }
        let children: (Int) -> [Int] = { $0 == 0 ? [1] : [] }
        #expect(throws: NativeOverflowTreeDiscovery.Failure.deadline) {
            let _: [Int] = try NativeOverflowTreeDiscovery.discover(
                in: 0,
                withinDeadline: withinDeadline,
                sameElement: { $0 == $1 }, describe: description, children: children
            )
        }
    }

    @Test("Disabled, explicitly hidden, unreadable-enabled or foreign controls cannot hide fallback")
    func controlAvailability() {
        for enabled in [true, false, nil] as [Bool?] {
            for hidden in [true, false, nil] as [Bool?] {
                for matches in [true, false] {
                    let state = NativeOverflowPresentationStateClassifier.availableState(
                        .collapsed, enabled: enabled, hidden: hidden, ownerMatches: matches
                    )
                    #expect(state == (enabled == true && hidden != true && matches ? .collapsed : .unknown))
                }
            }
        }
        #expect(NativeOverflowPresentationStateClassifier.availableState(
            .unknown, enabled: true, hidden: false, ownerMatches: true
        ) == .unknown)
    }

    @Test("Unreadable nodes reject partial results instead of selecting a sole known control")
    func incompleteReadsFailClosed() {
        #expect(throws: NativeOverflowTreeDiscovery.Failure.readFailure) {
            try discover([0: Node(role: "AXMenuBar", children: [1, 2]),
                          1: Node(role: "AXButton", isControl: true)])
        }
        let describe: (Int) throws -> NativeOverflowTreeDiscovery.Description = { node in
            if node == 2 { throw NativeOverflowTreeDiscovery.Failure.readFailure }
            return .init(role: node == 0 ? "AXMenuBar" : "AXButton", isOverflowControl: node == 1)
        }
        #expect(throws: NativeOverflowTreeDiscovery.Failure.readFailure) {
            let _: [Int] = try NativeOverflowTreeDiscovery.discover(
                in: 0, withinDeadline: { true }, sameElement: { $0 == $1 },
                describe: describe, children: { $0 == 0 ? [1, 2] : [] }
            )
        }
        #expect(throws: NativeOverflowTreeDiscovery.Failure.readFailure) {
            let _: [Int] = try NativeOverflowTreeDiscovery.discover(
                in: 0, withinDeadline: { true }, sameElement: { $0 == $1 },
                describe: { _ in .init(role: "AXMenuBar", isOverflowControl: false) },
                children: { _ in throw NativeOverflowTreeDiscovery.Failure.readFailure }
            )
        }
    }
}
