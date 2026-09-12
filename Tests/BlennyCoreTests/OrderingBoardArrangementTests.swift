import Foundation
import Testing
@testable import BlennyCore

#if DEBUG

@Suite("Ordering Board arrangement")
struct OrderingBoardArrangementTests {
    private let candidateGeneration = UUID(
        uuidString: "11111111-1111-1111-1111-111111111111"
    )!
    private let layoutGeneration = UUID(
        uuidString: "22222222-2222-2222-2222-222222222222"
    )!
    private let nextLayoutGeneration = UUID(
        uuidString: "33333333-3333-3333-3333-333333333333"
    )!

    @Test("Ordered draft exposes Hidden, Revealable, Visible physical order")
    func physicalOrder() throws {
        let draft = try layoutDraft()

        #expect(draft.physicalOrder == [
            bundle("h1"), bundle("r1"), bundle("r2"), bundle("v1"), bundle("v2"),
        ])
        #expect(draft.draftPolicies[bundle("h1")] == .hidden)
        #expect(draft.draftPolicies[bundle("r2")] == .revealable)
        #expect(draft.draftPolicies[bundle("v1")] == .visible)
    }

    @Test("Mixed draft preserves exact system subjects between application owners")
    func mixedPhysicalOrder() throws {
        let draft = try OrderingBoardLayoutDraft(
            visibleSubjects: [
                .application(bundle("v1")),
                .systemItem(.wifi),
                .application(bundle("v2")),
            ],
            revealableSubjects: [.systemItem(.sound)],
            hiddenSubjects: [.application(bundle("h1"))],
            candidateGeneration: candidateGeneration,
            layoutGeneration: layoutGeneration
        )

        #expect(draft.physicalSubjects == [
            .application(bundle("h1")),
            .systemItem(.sound),
            .application(bundle("v1")),
            .systemItem(.wifi),
            .application(bundle("v2")),
        ])
        #expect(draft.policy(of: .systemItem(.wifi)) == .visible)
        #expect(draft.policy(of: .systemItem(.sound)) == .revealable)
        #expect(draft.draftSubjectPolicies[.systemItem(.wifi)] == .visible)
    }

    @Test("Exact system subject moves independently from its shared host")
    func exactSystemSubjectMove() throws {
        let draft = try OrderingBoardLayoutDraft(
            visibleSubjects: [
                .systemItem(.bluetooth),
                .systemItem(.wifi),
                .application("com.apple.controlcenter"),
            ],
            revealableSubjects: [],
            hiddenSubjects: [],
            candidateGeneration: candidateGeneration,
            layoutGeneration: layoutGeneration
        )
        let moved = try draft.moving(
            OrderingBoardLayoutItemID(
                subjectID: .systemItem(.wifi),
                sourcePolicy: .visible,
                candidateGeneration: candidateGeneration,
                layoutGeneration: layoutGeneration
            ),
            to: .init(
                policy: .visible,
                position: .before(OrderingSubjectID.systemItem(.bluetooth).boardID)
            ),
            nextLayoutGeneration: nextLayoutGeneration
        ).get()

        #expect(moved.physicalSubjects == [
            .systemItem(.wifi),
            .systemItem(.bluetooth),
            .application("com.apple.controlcenter"),
        ])
    }

    @Test("Exact system subject can cross areas without moving shared-host siblings")
    func exactSystemSubjectCrossAreaMove() throws {
        let draft = try OrderingBoardLayoutDraft(
            visibleSubjects: [
                .systemItem(.bluetooth),
                .systemItem(.wifi),
                .application("com.apple.controlcenter"),
            ],
            revealableSubjects: [.systemItem(.sound)],
            hiddenSubjects: [],
            candidateGeneration: candidateGeneration,
            layoutGeneration: layoutGeneration
        )
        let moved = try draft.moving(
            OrderingBoardLayoutItemID(
                subjectID: .systemItem(.wifi),
                sourcePolicy: .visible,
                candidateGeneration: candidateGeneration,
                layoutGeneration: layoutGeneration
            ),
            to: .init(policy: .hidden, position: .end),
            nextLayoutGeneration: nextLayoutGeneration
        ).get()

        #expect(moved.hidden == [OrderingSubjectID.systemItem(.wifi).boardID])
        #expect(moved.visible == [
            OrderingSubjectID.systemItem(.bluetooth).boardID,
            "com.apple.controlcenter",
        ])
        #expect(moved.revealable == [OrderingSubjectID.systemItem(.sound).boardID])
    }

    @Test("Typed application identities cannot enter the system Board namespace")
    func subjectNamespacesRemainDistinct() {
        #expect(throws: OrderingBoardLayoutRejection.invalidBundleIdentifier) {
            try OrderingBoardLayoutDraft(
                visibleSubjects: [.application("system:wifi")],
                revealableSubjects: [], hiddenSubjects: [],
                candidateGeneration: candidateGeneration
            )
        }
    }

    @Test("Both edges of every adjacent pair resolve to one landing slot")
    func canonicalAdjacentLandingSlots() {
        let owners = ["a", "b", "c", "d"]
        for source in owners + ["external"] {
            for index in 0..<(owners.count - 1) {
                #expect(OrderingBoardLandingProjection.canonicalPosition(
                    .after(owners[index]), moving: source, among: owners
                ) == OrderingBoardLandingProjection.canonicalPosition(
                    .before(owners[index + 1]), moving: source, among: owners
                ))
            }
            #expect(OrderingBoardLandingProjection.canonicalPosition(
                .after("d"), moving: source, among: owners
            ) == .end)
        }
    }

    @Test("Dragged owners cannot split one logical gap into two destinations")
    func sourceDoesNotSplitLandingSlot() {
        let owners = ["a", "source", "b"]
        for edge: OrderingBoardLayoutDestination.Position in [
            .after("a"), .before("source"), .after("source"), .before("b"),
        ] {
            #expect(OrderingBoardLandingProjection.canonicalPosition(
                edge, moving: "source", among: owners
            ) == .before("b"))
        }
        #expect(OrderingBoardLandingProjection.canonicalPosition(
            .before("missing"), moving: "source", among: owners
        ) == nil)
    }

    @Test("Fixed receiver geometry keeps a stationary pointer on one slot")
    func stationaryPointerRemainsStable() {
        let owners = ["a", "b", "c"]
        for _ in 0 ..< 100 {
            #expect(OrderingBoardLandingProjection.position(
                at: 70, itemExtent: 50, moving: "external", among: owners
            ) == .before("b"))
        }
        #expect(OrderingBoardLandingProjection.position(
            at: 80, itemExtent: 50, moving: "external", among: owners
        ) == .before("c"))
    }

    @Test("Pointer end preserves the canonical destination until data delivery")
    func pointerEndPreservesDestination() {
        var session = OrderingBoardLandingSession()
        let didUpdate = session.update(
            moving: "source",
            to: .after("a"),
            among: ["a", "source", "b"]
        )
        #expect(didUpdate)
        #expect(session.position == .before("b"))

        session.pointerEnded()

        #expect(session.boundPosition(
            moving: "source",
            among: ["a", "source", "b"]
        ) == .before("b"))
        #expect(session.consume(
            moving: "source",
            among: ["a", "source", "b"]
        ) == .before("b"))
        #expect(session.position == nil)
    }

    @Test("Completed or mismatched delivery cannot reuse a landing destination")
    func landingDestinationHasOneDelivery() {
        var session = OrderingBoardLandingSession()
        let didUpdateEnd = session.update(
            moving: "source",
            to: .end,
            among: ["a", "source", "b"]
        )
        #expect(didUpdateEnd)
        #expect(session.consume(
            moving: "other",
            among: ["a", "source", "b"]
        ) == nil)
        #expect(session.position == .end)
        #expect(session.consume(
            moving: "source",
            among: ["a", "source", "b"]
        ) == .end)
        #expect(session.position == nil)

        let didUpdateBefore = session.update(
            moving: "source",
            to: .before("b"),
            among: ["a", "source", "b"]
        )
        #expect(didUpdateBefore)
        session.transferCompleted()
        #expect(!session.showsPreview)
        #expect(session.consume(
            moving: "source",
            among: ["a", "source", "b"]
        ) == .before("b"))
        #expect(session.position == nil)
    }

    @Test("Typed delivery can consume a landing before transfer completion")
    func landingDeliveryBeforeTransferCompletion() {
        var session = OrderingBoardLandingSession()
        _ = session.update(
            moving: "source",
            to: .end,
            among: ["a", "source", "b"]
        )

        #expect(session.consume(
            moving: "source",
            among: ["a", "source", "b"]
        ) == .end)
        session.transferCompleted(moving: "source")
        #expect(session.position == nil)
        #expect(!session.showsPreview)
    }

    @Test("Late cleanup from an older drag cannot clear a newer landing")
    func staleLandingCleanupIsIgnored() {
        var session = OrderingBoardLandingSession()
        let didUpdate = session.update(
            moving: "new",
            to: .before("b"),
            among: ["a", "b"]
        )
        #expect(didUpdate)

        session.clear(moving: "old")
        session.transferCompleted(moving: "old")

        #expect(session.boundPosition(
            moving: "new",
            among: ["a", "b"]
        ) == .before("b"))
    }

    @Test("Hover recomputation retains one drag token for one Board generation")
    func dragPayloadRemainsStableWithinLayoutGeneration() {
        var registry = OrderingBoardDragPayloadRegistry()
        let subject = OrderingSubjectID.application("com.example.source")
        let first = registry.payload(
            dragIdentifier: "com.example.source",
            subjectID: subject,
            sourcePolicy: .visible,
            candidateGeneration: candidateGeneration,
            layoutGeneration: layoutGeneration
        )
        for _ in 0 ..< 1_000 {
            let repeated = registry.payload(
                dragIdentifier: "com.example.source",
                subjectID: subject,
                sourcePolicy: .visible,
                candidateGeneration: candidateGeneration,
                layoutGeneration: layoutGeneration
            )
            #expect(repeated.dragToken == first.dragToken)
            #expect(repeated.id == first.id)
        }

        let nextLayout = registry.payload(
            dragIdentifier: "com.example.source",
            subjectID: subject,
            sourcePolicy: .visible,
            candidateGeneration: candidateGeneration,
            layoutGeneration: nextLayoutGeneration
        )
        #expect(nextLayout.dragToken != first.dragToken)
        #expect(nextLayout.id != first.id)

        let unknownRetired = registry.discard(token: UUID())
        #expect(!unknownRetired)
        let currentRetired = registry.discard(token: nextLayout.dragToken)
        #expect(currentRetired)
        let alreadyRetired = registry.discard(token: nextLayout.dragToken)
        #expect(!alreadyRetired)
        let afterDeliveredNoOp = registry.payload(
            dragIdentifier: "com.example.source",
            subjectID: subject,
            sourcePolicy: .visible,
            candidateGeneration: candidateGeneration,
            layoutGeneration: nextLayoutGeneration
        )
        #expect(afterDeliveredNoOp.dragToken != nextLayout.dragToken)
        #expect(afterDeliveredNoOp.id != nextLayout.id)

        registry.clear()
        let afterClear = registry.payload(
            dragIdentifier: "com.example.source",
            subjectID: subject,
            sourcePolicy: .visible,
            candidateGeneration: candidateGeneration,
            layoutGeneration: layoutGeneration
        )
        #expect(afterClear.dragToken != first.dragToken)
        #expect(afterClear.id != first.id)
    }

    @Test("Landing projection handles empty lanes, both ends, and invalid geometry")
    func landingProjectionBoundaries() {
        #expect(OrderingBoardLandingProjection.position(
            at: -10, itemExtent: 50, moving: "source", among: ["a"]
        ) == .before("a"))
        #expect(OrderingBoardLandingProjection.position(
            at: .greatestFiniteMagnitude, itemExtent: 50, moving: "source", among: ["a"]
        ) == .end)
        #expect(OrderingBoardLandingProjection.position(
            at: 0, itemExtent: 50, moving: "source", among: []
        ) == .end)
        #expect(OrderingBoardLandingProjection.position(
            at: .nan, itemExtent: 50, moving: "source", among: ["a"]
        ) == nil)
        #expect(OrderingBoardLandingProjection.position(
            at: 0, itemExtent: 0, moving: "source", among: ["a"]
        ) == nil)
    }

    @Test("Ordered draft inserts before and after within one lane")
    func orderedDraftInsertionEdges() throws {
        let draft = try layoutDraft()
        let before = try draft.moving(
            layoutItem("v2", policy: .visible),
            to: .init(policy: .visible, position: .before(bundle("v1"))),
            nextLayoutGeneration: nextLayoutGeneration
        ).get()
        #expect(before.visible == [bundle("v2"), bundle("v1")])

        let after = try draft.moving(
            layoutItem("v1", policy: .visible),
            to: .init(policy: .visible, position: .after(bundle("v2"))),
            nextLayoutGeneration: nextLayoutGeneration
        ).get()
        #expect(after.visible == [bundle("v2"), bundle("v1")])
    }

    @Test("Ordered draft moves across lanes and supports the lane end")
    func orderedDraftCrossLaneEnd() throws {
        let draft = try layoutDraft()
        let moved = try draft.moving(
            layoutItem("r1", policy: .revealable),
            to: .init(policy: .hidden, position: .end),
            nextLayoutGeneration: nextLayoutGeneration
        ).get()

        #expect(moved.hidden == [bundle("h1"), bundle("r1")])
        #expect(moved.revealable == [bundle("r2")])
        #expect(moved.policy(of: bundle("r1")) == .hidden)
        #expect(moved.physicalOrder == [
            bundle("h1"), bundle("r1"), bundle("r2"), bundle("v1"), bundle("v2"),
        ])
        #expect(moved.hasChanges)
        #expect(moved.resetting().physicalOrder == draft.physicalOrder)
        #expect(!moved.resetting().hasChanges)
    }

    @Test("Ordered draft rejects stale candidate, layout, and source policy")
    func orderedDraftStaleInputs() throws {
        let draft = try layoutDraft()
        let staleCandidate = OrderingBoardLayoutItemID(
            bundleIdentifier: bundle("v1"), sourcePolicy: .visible,
            candidateGeneration: UUID(), layoutGeneration: layoutGeneration
        )
        #expect(draft.moving(
            staleCandidate,
            to: .init(policy: .hidden, position: .end)
        ) == .failure(.staleCandidateGeneration))

        let staleLayout = OrderingBoardLayoutItemID(
            bundleIdentifier: bundle("v1"), sourcePolicy: .visible,
            candidateGeneration: candidateGeneration, layoutGeneration: UUID()
        )
        #expect(draft.moving(
            staleLayout,
            to: .init(policy: .hidden, position: .end)
        ) == .failure(.staleLayoutGeneration))

        let stalePolicy = OrderingBoardLayoutItemID(
            bundleIdentifier: bundle("v1"), sourcePolicy: .hidden,
            candidateGeneration: candidateGeneration, layoutGeneration: layoutGeneration
        )
        #expect(draft.moving(
            stalePolicy,
            to: .init(policy: .hidden, position: .end)
        ) == .failure(.staleSourcePolicy))
    }

    @Test("Ordered draft rejects duplicate identities across lanes")
    func orderedDraftRejectsDuplicates() {
        #expect(throws: OrderingBoardLayoutRejection.duplicateBundleIdentifier) {
            try OrderingBoardLayoutDraft(
                visible: ["com.example.same"],
                revealable: ["COM.EXAMPLE.SAME"],
                hidden: [],
                candidateGeneration: candidateGeneration,
                layoutGeneration: layoutGeneration
            )
        }
    }

    @Test("Observed geometry sorts owners from left to right and retains unknown owners")
    func observedSorting() {
        let sorted = OrderingBoardArrangement.sortedLeftToRight([
            owner("unknown-one", x: nil),
            owner("right", x: 40),
            owner("left", x: 10, eligible: false),
            owner("unknown-two", x: nil),
        ])
        #expect(sorted.map(\.bundleIdentifier) == [
            "left", "right", "unknown-one", "unknown-two",
        ])
    }

    @Test("Insertion before a later target excludes the stationary target")
    func insertBeforeLaterTarget() throws {
        let plan = try OrderingBoardArrangement.inserting(
            moving: "b",
            before: "d",
            in: lane()
        ).get()
        #expect(plan.affectedBundleIdentifiers == ["b", "c"])
        #expect(plan.beforeOrder == ["b", "c"])
        #expect(plan.desiredOrder == ["c", "b"])
    }

    @Test("Insertion before an earlier target rotates the complete affected interval")
    func insertBeforeEarlierTarget() throws {
        let plan = try OrderingBoardArrangement.inserting(
            moving: "d",
            before: "b",
            in: lane()
        ).get()
        #expect(plan.affectedBundleIdentifiers == ["b", "c", "d"])
        #expect(plan.beforeOrder == ["b", "c", "d"])
        #expect(plan.desiredOrder == ["d", "b", "c"])
    }

    @Test("Dropping onto the next icon is an explicit no-op")
    func adjacentInsertionNoOp() {
        #expect(OrderingBoardArrangement.inserting(
            moving: "b",
            before: "c",
            in: lane()
        ) == .failure(.unchanged))
    }

    @Test("An adjacent unknown target remains an explicit no-op")
    func adjacentUnknownTargetNoOp() {
        #expect(OrderingBoardArrangement.inserting(
            moving: "known",
            before: "unknown",
            in: [
                owner("known", x: 10),
                owner("unknown", x: nil, eligible: false),
            ]
        ) == .failure(.unchanged))
    }

    @Test("Move Right advances exactly one observed position")
    func moveRight() throws {
        let plan = try OrderingBoardArrangement.movingOnePosition(
            "b",
            direction: .right,
            in: lane()
        ).get()
        #expect(plan.affectedBundleIdentifiers == ["b", "c"])
        #expect(plan.desiredOrder == ["c", "b"])
    }

    @Test("Move Left advances exactly one observed position")
    func moveLeft() throws {
        let plan = try OrderingBoardArrangement.movingOnePosition(
            "c",
            direction: .left,
            in: lane()
        ).get()
        #expect(plan.affectedBundleIdentifiers == ["b", "c"])
        #expect(plan.desiredOrder == ["c", "b"])
    }

    @Test("An unrelated unknown owner stays visible without blocking a known interval")
    func unrelatedUnknownGeometryIsPreserved() throws {
        var owners = lane()
        owners.append(owner("unknown", x: nil))
        let plan = try OrderingBoardArrangement.inserting(
            moving: "a",
            before: "c",
            in: owners
        ).get()
        #expect(plan.affectedBundleIdentifiers == ["a", "b"])
        #expect(plan.beforeOrder == ["a", "b"])
        #expect(plan.desiredOrder == ["b", "a"])
    }

    @Test("Selecting or crossing an unknown owner refuses the interval")
    func affectedUnknownGeometryRefuses() {
        var owners = lane()
        owners.append(owner("unknown", x: nil))
        #expect(OrderingBoardArrangement.inserting(
            moving: "a",
            before: "unknown",
            in: owners
        ) == .failure(.unverifiedOwner("unknown")))
        #expect(OrderingBoardArrangement.movingOnePosition(
            "d",
            direction: .right,
            in: owners
        ) == .failure(.unverifiedOwner("unknown")))
    }

    @Test("An unsupported owner in the contiguous interval refuses the move")
    func unsupportedIntervalRefuses() {
        let owners = [
            owner("a", x: 10),
            owner("b", x: 20),
            owner("c", x: 30, eligible: false),
            owner("d", x: 40),
        ]
        #expect(OrderingBoardArrangement.inserting(
            moving: "b",
            before: "d",
            in: owners
        ) == .failure(.ineligibleOwner("c")))
    }

    @Test("A stationary unsupported rightward target does not block changed owners")
    func unsupportedStationaryTargetDoesNotRefuse() throws {
        let owners = [
            owner("a", x: 10),
            owner("b", x: 20),
            owner("c", x: 30),
            owner("d", x: 40, eligible: false),
        ]
        let plan = try OrderingBoardArrangement.inserting(
            moving: "b",
            before: "d",
            in: owners
        ).get()
        #expect(plan.affectedBundleIdentifiers == ["b", "c"])
        #expect(plan.beforeOrder == ["b", "c"])
        #expect(plan.desiredOrder == ["c", "b"])
    }

    @Test("An unverified rightward target cannot anchor a verified insertion")
    func unverifiedStationaryTargetRefuses() {
        var owners = lane()
        owners.append(owner("unknown", x: nil, eligible: false))
        #expect(OrderingBoardArrangement.inserting(
            moving: "b",
            before: "unknown",
            in: owners
        ) == .failure(.unverifiedOwner("unknown")))
    }

    @Test("Draft, recovery, and busy gates refuse ordering")
    func stateGatesRefuse() {
        #expect(OrderingBoardArrangement.inserting(
            moving: "a", before: "c", in: lane(), hasPendingPolicyDraft: true
        ) == .failure(.pendingPolicyDraft))
        #expect(OrderingBoardArrangement.inserting(
            moving: "a", before: "c", in: lane(), hasRecovery: true
        ) == .failure(.recoveryRequired))
        #expect(OrderingBoardArrangement.inserting(
            moving: "a", before: "c", in: lane(), isBusy: true
        ) == .failure(.operationInProgress))
    }

    @Test("Move controls refuse lane edges")
    func edgeControlsRefuse() {
        #expect(OrderingBoardArrangement.movingOnePosition(
            "a", direction: .left, in: lane()
        ) == .failure(.edgeReached(.left)))
        #expect(OrderingBoardArrangement.movingOnePosition(
            "d", direction: .right, in: lane()
        ) == .failure(.edgeReached(.right)))
    }

    private func lane() -> [OrderingBoardOwner] {
        [
            owner("a", x: 10),
            owner("b", x: 20),
            owner("c", x: 30),
            owner("d", x: 40),
        ]
    }

    private func layoutDraft() throws -> OrderingBoardLayoutDraft {
        try OrderingBoardLayoutDraft(
            visible: ["v1", "v2"].map { "com.example.\($0)" },
            revealable: ["r1", "r2"].map { "com.example.\($0)" },
            hidden: ["h1"].map { "com.example.\($0)" },
            candidateGeneration: candidateGeneration,
            layoutGeneration: layoutGeneration
        )
    }

    private func layoutItem(
        _ shortName: String,
        policy: MenuBarBundlePolicy
    ) -> OrderingBoardLayoutItemID {
        OrderingBoardLayoutItemID(
            bundleIdentifier: bundle(shortName),
            sourcePolicy: policy,
            candidateGeneration: candidateGeneration,
            layoutGeneration: layoutGeneration
        )
    }

    private func bundle(_ shortName: String) -> String {
        "com.example.\(shortName)"
    }

    private func owner(
        _ bundleIdentifier: String,
        x: Double?,
        eligible: Bool = true
    ) -> OrderingBoardOwner {
        OrderingBoardOwner(
            bundleIdentifier: bundleIdentifier,
            observedX: x,
            isEligible: eligible
        )
    }
}

#endif
