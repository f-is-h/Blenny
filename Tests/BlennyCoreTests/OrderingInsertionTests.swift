#if BLENNY_PRODUCT || DEBUG
import Foundation
import Testing
@testable import BlennyCore

@Suite("Bounded ordering insertion plans")
struct OrderingInsertionTests {
    private let capturedAt = Date(timeIntervalSince1970: 20_000)
    private let planID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    @Test("Schema 3 uses descending numeric slots without requiring AX geometry")
    func configurationFirstDescendingSlots() throws {
        let owners = processes(count: 4)
        var observations: [Int32: OrderingOwnerObservation] = [:]
        for process in owners {
            observations[process.pid] = OrderingOwnerObservation(
                process: process, displayName: process.bundleIdentifier!,
                axComplete: false, itemFrames: [], ownerPreferencesComplete: true,
                ownerSavedPositions: [:]
            )
        }
        let snapshot = try fixture(observations: observations)
        let desired = [bundle(3), bundle(1), bundle(0), bundle(2)]
        let plan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: snapshot, orderedBundleIdentifiers: desired,
            now: capturedAt.addingTimeInterval(5), id: planID
        )

        try plan.validate()
        #expect(plan.schemaVersion == 3)
        #expect(plan.targets.isEmpty)
        #expect(plan.configurationTargets?.map(\.bundleIdentifier) == desired)
        #expect(plan.configurationTargets?.flatMap(\.keys).map(\.after)
            == [.integer(900), .integer(700), .integer(500), .real(300.5)])
        #expect(plan.physicalVerificationStatus(in: snapshot) == .unavailable)
        let decoded = try JSONDecoder().decode(OrderingPlan.self, from: JSONEncoder().encode(plan))
        try decoded.validate()
        #expect(decoded == plan)
    }

    @Test("Schema 3 groups every associated owner key and accepts empty autosave snapshots")
    func configurationFirstWholeOwnerScope() throws {
        let owners = processes(count: 4)
        var group = try fixture().group
        guard case var .dictionary(table)? = group[OrderingSnapshot.tableKey] else {
            Issue.record("Expected ordering table")
            return
        }
        table["status:\(bundle(0))::second-item"] = .integer(800)
        group[OrderingSnapshot.tableKey] = .dictionary(table)
        var observations: [Int32: OrderingOwnerObservation] = [:]
        for (index, process) in owners.enumerated() {
            observations[process.pid] = OrderingOwnerObservation(
                process: process, displayName: "Owner \(index)", axComplete: index != 0,
                itemFrames: index == 0 ? [] : [RectSnapshot(x: Double(100 + index * 50), y: 10, width: 24, height: 20)],
                ownerPreferencesComplete: true,
                ownerSavedPositions: index == 0 ? [:] : ["item": .integer(Int64(1_000 - index * 100))]
            )
        }
        let snapshot = try fixture(group: group, observations: observations)
        let plan = try OrderingPlan.makeConfigurationOrdering(
            snapshot: snapshot,
            orderedBundleIdentifiers: [bundle(0), bundle(1), bundle(2), bundle(3)],
            now: capturedAt.addingTimeInterval(5), id: planID
        )

        let first = try #require(plan.configurationTargets?.first)
        #expect(first.keys.map(\.key) == [
            "status:\(bundle(0))::second-item", key(0)
        ])
        #expect(Set(plan.configurationTargets?.flatMap(\.keys).map(\.key) ?? []).count == 5)
    }

    @Test("Equal and nested proxy frames mark only affected owners ambiguous")
    func ambiguousObservedGeometry() {
        let frames: [String: RectSnapshot] = [
            "Coffee": RectSnapshot(x: 575, y: 10, width: 43, height: 20),
            "Nested": RectSnapshot(x: 586, y: 10, width: 24, height: 20),
            "Identical": RectSnapshot(x: 586, y: 10, width: 24, height: 20),
            "Separate": RectSnapshot(x: 700, y: 10, width: 24, height: 20),
            "VerticalTouch": RectSnapshot(x: 586, y: 30, width: 24, height: 20)
        ]

        #expect(OrderingObservedGeometry.ambiguousOwners(frames: frames)
            == Set(["Coffee", "Nested", "Identical"]))
    }

    @Test("Resolver hides nested proxy positions without excluding unaffected owners")
    func resolverGeometryAmbiguity() throws {
        let owners = processes(count: 4)
        let observations = [
            owners[0].pid: observation(process: owners[0], x: 575,
                frame: RectSnapshot(x: 575, y: 10, width: 43, height: 20)),
            owners[1].pid: observation(process: owners[1], x: 586),
            owners[2].pid: observation(process: owners[2], x: 700),
            owners[3].pid: observation(process: owners[3], x: 800)
        ]
        let snapshot = try fixture(observations: observations)
        let candidates = try OrderingIdentityResolver.resolve(snapshot: snapshot)
        let first = try #require(candidates.first { $0.bundleIdentifier == bundle(0) })
        let second = try #require(candidates.first { $0.bundleIdentifier == bundle(1) })
        let third = try #require(candidates.first { $0.bundleIdentifier == bundle(2) })

        #expect(first.reasons.contains(.geometryAmbiguous))
        #expect(second.reasons.contains(.geometryAmbiguous))
        #expect(first.frame == nil)
        #expect(second.frame == nil)
        #expect(third.eligible)
        #expect(third.frame == RectSnapshot(x: 700, y: 10, width: 24, height: 20))

        #expect(throws: OrderingError.ineligibleBundle(bundle(0), [.geometryAmbiguous])) {
            try OrderingPlan.makeReordering(snapshot: snapshot,
                orderedBundleIdentifiers: [bundle(2), bundle(0)],
                now: capturedAt.addingTimeInterval(5), id: planID)
        }
        let unaffectedPlan = try OrderingPlan.makeReordering(snapshot: snapshot,
            orderedBundleIdentifiers: [bundle(3), bundle(2)],
            now: capturedAt.addingTimeInterval(5), id: planID)
        #expect(unaffectedPlan.targets.map(\.bundleIdentifier) == [bundle(3), bundle(2)])
    }

    @Test("Schema 1 accepts measured 1.5 and 2-point partial overlaps")
    func measuredPartialOverlaps() throws {
        for secondX in [122.0, 122.5] {
            let snapshot = try fixture(xPositions: [100, secondX, 300, 400])
            let candidates = try OrderingIdentityResolver.resolve(snapshot: snapshot)
            let first = try #require(candidates.first { $0.bundleIdentifier == bundle(0) })
            let second = try #require(candidates.first { $0.bundleIdentifier == bundle(1) })

            #expect(first.eligible)
            #expect(second.eligible)
            let plan = try OrderingPlan.make(snapshot: snapshot,
                bundleIdentifiers: [bundle(0), bundle(1)],
                now: capturedAt.addingTimeInterval(5), id: planID)
            #expect(plan.schemaVersion == 1)
            #expect(try plan.relativeOrder(in: snapshot) == .firstBeforeSecond)

            let applied = try fixture(
                xPositions: [secondX, 100, 300, 400],
                capturedAt: capturedAt.addingTimeInterval(10)
            )
            try plan.verifyRelativeOrder(in: applied, phase: .applied)
        }
    }

    @Test("Schema 2 maps existing visible slots to the complete desired order")
    func insertionPermutation() throws {
        let baseline = try fixture()
        let desired = [bundle(2), bundle(0), bundle(1), bundle(3)]
        let plan = try OrderingPlan.makeReordering(
            snapshot: baseline,
            orderedBundleIdentifiers: desired,
            now: capturedAt.addingTimeInterval(5),
            id: planID
        )

        try plan.validate()
        #expect(plan.schemaVersion == 2)
        #expect(plan.targets.map(\.bundleIdentifier) == desired)
        #expect(plan.targets.map(\.before) == [.integer(500), .integer(700), .real(300.5), .integer(900)])
        #expect(plan.targets.map(\.after) == [.integer(700), .real(300.5), .integer(500), .integer(900)])
        #expect(plan.targets.last?.before == plan.targets.last?.after)
        #expect(plan.targets.count == 4)

        let appliedGroup = try plan.applying(to: baseline.group)
        let beforeValues = try baseline.table().values.map { $0 }
        guard case let .dictionary(appliedTable)? = appliedGroup[OrderingSnapshot.tableKey] else {
            Issue.record("Expected applied ordering table")
            return
        }
        #expect(isPermutation(beforeValues, Array(appliedTable.values)))
        #expect(appliedTable[key(2)] == .integer(700))
        #expect(appliedTable[key(0)] == .real(300.5))
        #expect(appliedTable[key(1)] == .integer(500))
        #expect(appliedTable[key(3)] == .integer(900))

        try plan.verifyRelativeOrder(in: baseline, phase: .baseline)
        let observedApplied = try fixture(
            group: appliedGroup,
            xPositions: [200, 300, 100, 400],
            capturedAt: capturedAt.addingTimeInterval(10)
        )
        try plan.verifyRelativeOrder(in: observedApplied, phase: .applied)

        let decoded = try JSONDecoder().decode(OrderingPlan.self, from: JSONEncoder().encode(plan))
        try decoded.validate()
        #expect(decoded == plan)
    }

    @Test("Schema 2 accepts very large partial overlap without a tolerance threshold")
    func largePartialOverlap() throws {
        let owners = processes(count: 4)
        let baseline = try fixture(observations: [
            owners[0].pid: observation(process: owners[0], x: 100,
                frame: RectSnapshot(x: 100, y: 10, width: 1_000, height: 20)),
            owners[1].pid: observation(process: owners[1], x: 101,
                frame: RectSnapshot(x: 101, y: 10, width: 1_000, height: 20)),
            owners[2].pid: observation(process: owners[2], x: 1_200),
            owners[3].pid: observation(process: owners[3], x: 1_300)
        ])
        let plan = try OrderingPlan.makeReordering(
            snapshot: baseline,
            orderedBundleIdentifiers: [bundle(1), bundle(0), bundle(2)],
            now: capturedAt.addingTimeInterval(5),
            id: planID
        )

        #expect(plan.schemaVersion == 2)
        try plan.verifyRelativeOrder(in: baseline, phase: .baseline)
        let applied = try fixture(observations: [
            owners[0].pid: observation(process: owners[0], x: 101,
                frame: RectSnapshot(x: 101, y: 10, width: 1_000, height: 20)),
            owners[1].pid: observation(process: owners[1], x: 100,
                frame: RectSnapshot(x: 100, y: 10, width: 1_000, height: 20)),
            owners[2].pid: observation(process: owners[2], x: 1_200),
            owners[3].pid: observation(process: owners[3], x: 1_300)
        ], capturedAt: capturedAt.addingTimeInterval(10))
        try plan.verifyRelativeOrder(in: applied, phase: .applied)
    }

    @Test("Schema 2 verifies unchanged targets and every affected owner's actual order")
    func completeVerificationScope() throws {
        let baseline = try fixture()
        let plan = try OrderingPlan.makeReordering(
            snapshot: baseline,
            orderedBundleIdentifiers: [bundle(2), bundle(0), bundle(1), bundle(3)],
            now: capturedAt.addingTimeInterval(5), id: planID
        )
        let appliedGroup = try plan.applying(to: baseline.group)

        let unchangedTargetMoved = try fixture(
            group: appliedGroup,
            xPositions: [200, 400, 100, 300],
            capturedAt: capturedAt.addingTimeInterval(10)
        )
        #expect(throws: OrderingError.relativeOrderMismatch) {
            try plan.verifyRelativeOrder(in: unchangedTargetMoved, phase: .applied)
        }

        let partiallyOverlapping = try fixture(
            group: appliedGroup,
            xPositions: [200, 300, 100, 310],
            capturedAt: capturedAt.addingTimeInterval(10)
        )
        try plan.verifyRelativeOrder(in: partiallyOverlapping, phase: .applied)

        let owners = processes(count: 4)
        let nested = try fixture(
            group: appliedGroup,
            observations: [
                owners[0].pid: observation(process: owners[0], x: 200),
                owners[1].pid: observation(process: owners[1], x: 300,
                    frame: RectSnapshot(x: 300, y: 10, width: 40, height: 20)),
                owners[2].pid: observation(process: owners[2], x: 100),
                owners[3].pid: observation(process: owners[3], x: 310,
                    frame: RectSnapshot(x: 310, y: 10, width: 20, height: 20))
            ],
            capturedAt: capturedAt.addingTimeInterval(10)
        )
        #expect(throws: OrderingError.invalidGeometry) {
            try plan.verifyRelativeOrder(in: nested, phase: .applied)
        }

        let offscreen = try fixture(
            group: appliedGroup,
            xPositions: [200, 300, 100, 2_100],
            capturedAt: capturedAt.addingTimeInterval(10)
        )
        #expect(throws: OrderingError.invalidGeometry) {
            try plan.verifyRelativeOrder(in: offscreen, phase: .applied)
        }

        let invalid = try fixture(
            group: appliedGroup,
            observations: [
                owners[0].pid: observation(process: owners[0], x: 200),
                owners[1].pid: observation(process: owners[1], x: 300),
                owners[2].pid: observation(process: owners[2], x: 100),
                owners[3].pid: observation(process: owners[3], x: 400,
                    frame: RectSnapshot(x: 400, y: 10, width: 0, height: 20))
            ],
            capturedAt: capturedAt.addingTimeInterval(10)
        )
        #expect(throws: OrderingError.invalidGeometry) {
            try plan.verifyRelativeOrder(in: invalid, phase: .applied)
        }
    }


    @Test("Schema 2 requires one common horizontal band across every target")
    func commonHorizontalBand() throws {
        let owners = processes(count: 4)
        let verticalChain = try fixture(observations: [
            owners[0].pid: observation(process: owners[0], x: 100,
                frame: RectSnapshot(x: 100, y: 0, width: 24, height: 20)),
            owners[1].pid: observation(process: owners[1], x: 200,
                frame: RectSnapshot(x: 200, y: 10, width: 24, height: 20)),
            owners[2].pid: observation(process: owners[2], x: 300,
                frame: RectSnapshot(x: 300, y: 20, width: 24, height: 20)),
            owners[3].pid: observation(process: owners[3], x: 400)
        ])

        #expect(throws: OrderingError.invalidGeometry) {
            try OrderingPlan.makeReordering(
                snapshot: verticalChain,
                orderedBundleIdentifiers: [bundle(2), bundle(0), bundle(1)],
                now: capturedAt.addingTimeInterval(5),
                id: planID
            )
        }
    }

    @Test("Schema 2 rejects invalid bounds, identity, position and geometry")
    func invalidInputs() throws {
        let baseline = try fixture()
        #expect(throws: OrderingError.invalidSelection) {
            try OrderingPlan.makeReordering(snapshot: baseline,
                orderedBundleIdentifiers: [bundle(0)], now: capturedAt.addingTimeInterval(5), id: planID)
        }
        #expect(throws: OrderingError.invalidSelection) {
            try OrderingPlan.makeReordering(snapshot: baseline,
                orderedBundleIdentifiers: [bundle(0), bundle(0)], now: capturedAt.addingTimeInterval(5), id: planID)
        }
        #expect(throws: OrderingError.invalidSelection) {
            try OrderingPlan.makeReordering(snapshot: baseline,
                orderedBundleIdentifiers: [bundle(0), bundle(1), bundle(2), bundle(3)],
                now: capturedAt.addingTimeInterval(5), id: planID)
        }
        #expect(throws: OrderingError.ineligibleBundle("com.example.Unknown", [.missingConfiguredKey])) {
            try OrderingPlan.makeReordering(snapshot: baseline,
                orderedBundleIdentifiers: [bundle(0), "com.example.Unknown"],
                now: capturedAt.addingTimeInterval(5), id: planID)
        }

        let owners = processes(count: 4)
        let nested = try fixture(observations: [
            owners[0].pid: observation(process: owners[0], x: 100,
                frame: RectSnapshot(x: 100, y: 10, width: 40, height: 20)),
            owners[1].pid: observation(process: owners[1], x: 110,
                frame: RectSnapshot(x: 110, y: 10, width: 20, height: 20)),
            owners[2].pid: observation(process: owners[2], x: 300),
            owners[3].pid: observation(process: owners[3], x: 400)
        ])
        #expect(throws: OrderingError.ineligibleBundle(bundle(0), [.geometryAmbiguous])) {
            try OrderingPlan.makeReordering(snapshot: nested,
                orderedBundleIdentifiers: [bundle(0), bundle(1), bundle(2)],
                now: capturedAt.addingTimeInterval(5), id: planID)
        }

        var interveningObservations = baseline.observationsByPID
        let interveningOwner = processes(count: 4)[1]
        interveningObservations[interveningOwner.pid] = observation(
            process: interveningOwner, x: 200, axComplete: false
        )
        let unsupportedInterveningOwner = try fixture(observations: interveningObservations)
        #expect(throws: OrderingError.ineligibleBundle(bundle(1), [.accessibilityIncomplete])) {
            try OrderingPlan.makeReordering(snapshot: unsupportedInterveningOwner,
                orderedBundleIdentifiers: [bundle(0), bundle(1), bundle(2)],
                now: capturedAt.addingTimeInterval(5), id: planID)
        }

        let collision = OrderingProcess(bundleIdentifier: "com.example.Collision",
            executableName: bundle(0), pid: 9_999,
            launchTime: Date(timeIntervalSince1970: 19_999), isSystem: false)
        let collisionSnapshot = try fixture(
            beforeProcesses: processes(count: 4) + [collision],
            afterProcesses: processes(count: 4) + [collision]
        )
        do {
            _ = try OrderingPlan.makeReordering(snapshot: collisionSnapshot,
                orderedBundleIdentifiers: [bundle(1), bundle(0), bundle(2)],
                now: capturedAt.addingTimeInterval(5), id: planID)
            Issue.record("Expected colliding selected identity to fail closed")
        } catch let OrderingError.ineligibleBundle(failedBundle, reasons) {
            #expect(failedBundle == bundle(0))
            #expect(reasons.contains(.ownerTokenCollision))
        }

        var duplicateGroup = baseline.group
        guard case var .dictionary(table)? = duplicateGroup[OrderingSnapshot.tableKey] else { return }
        table[key(1)] = table[key(0)]
        duplicateGroup[OrderingSnapshot.tableKey] = .dictionary(table)
        let duplicatePositions = try fixture(group: duplicateGroup)
        #expect(throws: OrderingError.indistinguishablePositions) {
            try OrderingPlan.makeReordering(snapshot: duplicatePositions,
                orderedBundleIdentifiers: [bundle(0), bundle(1), bundle(2)],
                now: capturedAt.addingTimeInterval(5), id: planID)
        }

        table[key(1)] = .real(700)
        duplicateGroup[OrderingSnapshot.tableKey] = .dictionary(table)
        let crossTypeDuplicatePositions = try fixture(group: duplicateGroup)
        #expect(throws: OrderingError.indistinguishablePositions) {
            try OrderingPlan.makeReordering(snapshot: crossTypeDuplicatePositions,
                orderedBundleIdentifiers: [bundle(0), bundle(1), bundle(2)],
                now: capturedAt.addingTimeInterval(5), id: planID)
        }

        let tooMany = try largeFixture(count: 33)
        #expect(throws: OrderingError.invalidSelection) {
            try OrderingPlan.makeReordering(snapshot: tooMany,
                orderedBundleIdentifiers: (0..<33).map(bundle),
                now: capturedAt.addingTimeInterval(5), id: planID)
        }

        let maximum = try largeFixture(count: 32)
        let maximumPlan = try OrderingPlan.makeReordering(snapshot: maximum,
            orderedBundleIdentifiers: (0..<32).reversed().map(bundle),
            now: capturedAt.addingTimeInterval(5), id: planID)
        #expect(maximumPlan.targets.count == 32)
        try maximumPlan.validate()
    }

    @Test("Schema and target tampering fail validation")
    func tampering() throws {
        let plan = try OrderingPlan.makeReordering(
            snapshot: fixture(),
            orderedBundleIdentifiers: [bundle(2), bundle(0), bundle(1), bundle(3)],
            now: capturedAt.addingTimeInterval(5), id: planID
        )
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])

        object["schemaVersion"] = 99
        let unknownSchema = try JSONDecoder().decode(OrderingPlan.self,
            from: JSONSerialization.data(withJSONObject: object))
        #expect(throws: OrderingError.malformedPlan) { try unknownSchema.validate() }

        object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        object["schemaVersion"] = 1
        let changedSchema = try JSONDecoder().decode(OrderingPlan.self,
            from: JSONSerialization.data(withJSONObject: object))
        #expect(throws: OrderingError.malformedPlan) { try changedSchema.validate() }

        object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        var targets = try #require(object["targets"] as? [[String: Any]])
        targets[0]["after"] = targets[1]["after"]
        object["targets"] = targets
        let changedPermutation = try JSONDecoder().decode(OrderingPlan.self,
            from: JSONSerialization.data(withJSONObject: object))
        #expect(throws: OrderingError.malformedPlan) { try changedPermutation.validate() }
    }

    @Test("Schema 2 freshness binds the complete selected identity and baseline order")
    func freshness() throws {
        let baseline = try fixture()
        let plan = try OrderingPlan.makeReordering(
            snapshot: baseline,
            orderedBundleIdentifiers: [bundle(2), bundle(0), bundle(1), bundle(3)],
            now: capturedAt.addingTimeInterval(5), id: planID
        )
        let translated = try fixture(
            xPositions: [150, 250, 350, 450],
            capturedAt: capturedAt.addingTimeInterval(10)
        )
        try plan.validateFresh(equivalentTo: translated, now: capturedAt.addingTimeInterval(15))

        let reordered = try fixture(
            xPositions: [250, 150, 350, 450],
            capturedAt: capturedAt.addingTimeInterval(10)
        )
        #expect(throws: OrderingError.relativeOrderMismatch) {
            try plan.validateFresh(equivalentTo: reordered, now: capturedAt.addingTimeInterval(15))
        }

        var observations = baseline.observationsByPID
        let process = processes(count: 4)[3]
        observations[process.pid] = observation(process: process, x: 400, axComplete: false)
        let incompleteUnchangedTarget = try fixture(
            observations: observations,
            capturedAt: capturedAt.addingTimeInterval(10)
        )
        #expect(throws: OrderingError.staleSnapshot(
            "Accessibility completeness changed for selected target \(bundle(3))"
        )) {
            try plan.validateFresh(equivalentTo: incompleteUnchangedTarget,
                now: capturedAt.addingTimeInterval(15))
        }


        let staleScope = try fixture(
            orderingAllowed: Set([bundle(0), bundle(1), bundle(2)]),
            capturedAt: capturedAt.addingTimeInterval(10)
        )
        #expect(throws: OrderingError.staleSnapshot(
            "runtime, display, lifecycle or policy context changed"
        )) {
            try plan.validateFresh(equivalentTo: staleScope,
                now: capturedAt.addingTimeInterval(15))
        }
    }

    @Test("Partial schema 2 inverse restores exact targets and preserves unrelated drift")
    func partialInverse() throws {
        let baseline = try fixture()
        let plan = try OrderingPlan.makeReordering(
            snapshot: baseline,
            orderedBundleIdentifiers: [bundle(2), bundle(0), bundle(1), bundle(3)],
            now: capturedAt.addingTimeInterval(5), id: planID
        )
        var current = try plan.applying(to: baseline.group)
        guard case var .dictionary(table)? = current[OrderingSnapshot.tableKey] else { return }
        table[key(0)] = plan.targets.first { $0.bundleIdentifier == bundle(0) }?.before
        table["module:unrelated"] = .integer(1234)
        current[OrderingSnapshot.tableKey] = .dictionary(table)
        current["ExternalGroupChange"] = .string("preserved")

        let restored = try plan.restoring(current: current)
        guard case let .dictionary(restoredTable)? = restored[OrderingSnapshot.tableKey] else { return }
        for target in plan.targets { #expect(restoredTable[target.key] == target.before) }
        #expect(restoredTable["module:unrelated"] == .integer(1234))
        #expect(restored["ExternalGroupChange"] == .string("preserved"))
    }

    @Test("Native scope accepts at most 32 existing numeric keys")
    func nativeScope() throws {
        let previous = Dictionary(uniqueKeysWithValues: (0..<32).map {
            ("status:\(bundle($0))::Item-0", OrderingValue.integer(Int64($0 + 1)))
        })
        let proposed = Dictionary(uniqueKeysWithValues: (0..<32).map {
            ("status:\(bundle($0))::Item-0", OrderingValue.integer(Int64((($0 + 1) % 32) + 1)))
        })
        #expect(try MacOS27MenuBarOrderingBackend.validateWriteScopeForTesting(
            previous: previous, proposed: proposed).count == 32)

        var nonnumeric = proposed
        nonnumeric["status:\(bundle(0))::Item-0"] = .string("invalid")
        #expect(throws: MacOS27MenuBarOrderingBackendError.invalidWriteScope) {
            try MacOS27MenuBarOrderingBackend.validateWriteScopeForTesting(
                previous: previous, proposed: nonnumeric
            )
        }

        let previous33 = Dictionary(uniqueKeysWithValues: (0..<33).map {
            ("status:\(bundle($0))::Item-0", OrderingValue.integer(Int64($0 + 1)))
        })
        let proposed33 = Dictionary(uniqueKeysWithValues: (0..<33).map {
            ("status:\(bundle($0))::Item-0", OrderingValue.integer(Int64((($0 + 1) % 33) + 1)))
        })
        #expect(throws: MacOS27MenuBarOrderingBackendError.invalidWriteScope) {
            try MacOS27MenuBarOrderingBackend.validateWriteScopeForTesting(
                previous: previous33, proposed: proposed33
            )
        }

        var newKey = proposed
        newKey.removeValue(forKey: "status:\(bundle(31))::Item-0")
        newKey["status:com.example.New::Item-0"] = .integer(32)
        #expect(throws: MacOS27MenuBarOrderingBackendError.invalidWriteScope) {
            try MacOS27MenuBarOrderingBackend.validateWriteScopeForTesting(
                previous: previous, proposed: newKey
            )
        }
    }

    @Test("Schema 1 receipts retain their original fingerprint and behavior")
    func schemaOneFingerprintFreeze() throws {
        let baseline = try fixture()
        let plan = try OrderingPlan.make(
            snapshot: baseline,
            bundleIdentifiers: [bundle(0), bundle(1)],
            now: capturedAt.addingTimeInterval(5),
            id: planID
        )
        #expect(plan.fingerprint == "9166c721313a98db14f2d5a8e8c43d84a53865eaa6497b4e95314b83e41446cd")
        try plan.validate()
        #expect(plan.schemaVersion == 1)
        #expect(plan.targets.map(\.bundleIdentifier) == [bundle(0), bundle(1)])
        #expect(try plan.relativeOrder(in: baseline) == .firstBeforeSecond)
    }

    private func fixture(
        group: [String: OrderingValue]? = nil,
        xPositions: [Double] = [100, 200, 300, 400],
        observations suppliedObservations: [Int32: OrderingOwnerObservation]? = nil,
        beforeProcesses suppliedBeforeProcesses: [OrderingProcess]? = nil,
        afterProcesses suppliedAfterProcesses: [OrderingProcess]? = nil,
        orderingAllowed suppliedOrderingAllowed: Set<String>? = nil,
        capturedAt suppliedCapturedAt: Date? = nil
    ) throws -> OrderingSnapshot {
        let owners = processes(count: 4)
        let observations = suppliedObservations ?? Dictionary(uniqueKeysWithValues: owners.enumerated().map {
            ($0.element.pid, observation(process: $0.element, x: xPositions[$0.offset]))
        })
        let defaultTable: [String: OrderingValue] = [
            key(0): .integer(700),
            key(1): .real(300.5),
            key(2): .integer(500),
            key(3): .integer(900),
            "module:unrelated": .integer(10)
        ]
        return try OrderingSnapshot(
            group: group ?? [
                OrderingSnapshot.tableKey: .dictionary(defaultTable),
                "OtherPreference": .string("kept")
            ],
            beforeProcesses: suppliedBeforeProcesses ?? owners,
            afterProcesses: suppliedAfterProcesses ?? owners,
            observationsByPID: observations,
            osBuild: OrderingSnapshot.supportedBuild,
            architecture: OrderingSnapshot.supportedArchitecture,
            runtimeContractVerified: true,
            displaySignature: "display-one",
            displayCount: 1,
            displayFrame: RectSnapshot(x: 0, y: 0, width: 2_000, height: 1_000),
            lifecycleGeneration: 7,
            policyFingerprint: "accepted-policy",
            orderingAllowedBundleIdentifiers: suppliedOrderingAllowed
                ?? Set(owners.compactMap(\.bundleIdentifier)),
            capturedAt: suppliedCapturedAt ?? capturedAt
        )
    }

    private func largeFixture(count: Int) throws -> OrderingSnapshot {
        let owners = processes(count: count)
        let table = Dictionary(uniqueKeysWithValues: owners.enumerated().map {
            (key($0.offset), OrderingValue.integer(Int64($0.offset + 1)))
        })
        let observations = Dictionary(uniqueKeysWithValues: owners.enumerated().map {
            ($0.element.pid, observation(process: $0.element, x: Double($0.offset * 30)))
        })
        return try OrderingSnapshot(
            group: [OrderingSnapshot.tableKey: .dictionary(table)],
            beforeProcesses: owners, afterProcesses: owners,
            observationsByPID: observations,
            osBuild: OrderingSnapshot.supportedBuild,
            architecture: OrderingSnapshot.supportedArchitecture,
            runtimeContractVerified: true,
            displaySignature: "display-large", displayCount: 1,
            displayFrame: RectSnapshot(x: 0, y: 0, width: 2_000, height: 1_000),
            lifecycleGeneration: 7, policyFingerprint: "accepted-policy",
            orderingAllowedBundleIdentifiers: Set(owners.compactMap(\.bundleIdentifier)),
            capturedAt: capturedAt
        )
    }

    private func processes(count: Int) -> [OrderingProcess] {
        (0..<count).map {
            OrderingProcess(bundleIdentifier: bundle($0), executableName: "Owner\($0)",
                pid: Int32(1_000 + $0), launchTime: Date(timeIntervalSince1970: Double(19_000 + $0)),
                isSystem: false)
        }
    }

    private func observation(process: OrderingProcess, x: Double,
                             frame suppliedFrame: RectSnapshot? = nil,
                             axComplete: Bool = true) -> OrderingOwnerObservation {
        let identifier = "Item-0"
        return OrderingOwnerObservation(
            process: process,
            displayName: process.executableName ?? process.bundleIdentifier ?? "Owner",
            axComplete: axComplete,
            itemFrames: [suppliedFrame ?? RectSnapshot(x: x, y: 10, width: 24, height: 20)],
            ownerPreferencesComplete: true,
            ownerSavedPositions: [identifier: .integer(Int64(process.pid))]
        )
    }

    private func bundle(_ index: Int) -> String { "com.example.Owner\(index)" }
    private func key(_ index: Int) -> String { "status:\(bundle(index))::Item-0" }

    private func isPermutation(_ first: [OrderingValue], _ second: [OrderingValue]) -> Bool {
        guard first.count == second.count else { return false }
        var unmatched = second
        for value in first {
            guard let index = unmatched.firstIndex(of: value) else { return false }
            unmatched.remove(at: index)
        }
        return unmatched.isEmpty
    }
}
#endif
