#if BLENNY_PRODUCT || DEBUG
import Foundation
import Testing
@testable import BlennyCore

@Suite("Debug reviewed ordering model")
struct OrderingModelTests {
    private let capturedAt = Date(timeIntervalSince1970: 10_000)
    private let alpha = OrderingProcess(bundleIdentifier: "com.example.Alpha", executableName: "Alpha",
                                        pid: 101, launchTime: Date(timeIntervalSince1970: 9_000), isSystem: false)
    private let beta = OrderingProcess(bundleIdentifier: "com.example.Beta", executableName: "Beta",
                                       pid: 202, launchTime: Date(timeIntervalSince1970: 9_100), isSystem: false)

    @Test("Ordering policy scope covers every intent and management state")
    func policyScope() {
        #expect(OrderingPolicyScope.allows(intent: .visible, managementEnabled: false))
        #expect(OrderingPolicyScope.allows(intent: .visible, managementEnabled: true))
        #expect(OrderingPolicyScope.allows(intent: .revealable, managementEnabled: false))
        #expect(!OrderingPolicyScope.allows(intent: .revealable, managementEnabled: true))
        #expect(OrderingPolicyScope.allows(intent: .hidden, managementEnabled: false))
        #expect(!OrderingPolicyScope.allows(intent: .hidden, managementEnabled: true))
    }

    @Test("A sandbox-container source proof makes a single-item owner eligible")
    func sandboxContainerSourceProof() throws {
        var observations = defaultObservations
        observations[alpha.pid] = observation(
            for: alpha,
            namespace: .sandboxContainer,
            sourceIdentity: String(repeating: "a", count: 64)
        )
        let candidate = try #require(try OrderingIdentityResolver.resolve(
            snapshot: fixture(observations: observations)
        ).first { $0.bundleIdentifier == alpha.bundleIdentifier })
        #expect(candidate.eligible)
    }

    @Test("A sandbox-container owner without source proof remains unavailable")
    func sandboxContainerMissingSourceProof() throws {
        var observations = defaultObservations
        observations[alpha.pid] = observation(for: alpha, namespace: .sandboxContainer)
        let candidate = try #require(try OrderingIdentityResolver.resolve(
            snapshot: fixture(observations: observations)
        ).first { $0.bundleIdentifier == alpha.bundleIdentifier })
        #expect(candidate.reasons.contains(.ownerPreferenceNamespaceUnsupported))
    }

    @Test("Legacy sandbox namespaces remain unavailable even with source proof")
    func legacySandboxNamespacesRemainUnavailable() throws {
        let sourceIdentity = String(repeating: "b", count: 64)
        for namespace in [
            OrderingOwnerPreferenceNamespace.sandboxed,
            .unknown
        ] {
            var observations = defaultObservations
            observations[alpha.pid] = observation(
                for: alpha,
                namespace: namespace,
                sourceIdentity: sourceIdentity
            )
            let candidate = try #require(try OrderingIdentityResolver.resolve(
                snapshot: fixture(observations: observations)
            ).first { $0.bundleIdentifier == alpha.bundleIdentifier })
            #expect(candidate.reasons.contains(.ownerPreferenceNamespaceUnsupported))
        }
    }

    @Test("Malformed source proof rejects a snapshot")
    func malformedSourceProofRejectsSnapshot() throws {
        var observations = defaultObservations
        observations[alpha.pid] = observation(
            for: alpha,
            namespace: .sandboxContainer,
            sourceIdentity: "not-a-sha256"
        )
        #expect(throws: OrderingError.invalidSnapshot(
            "owner preference source identity is invalid"
        )) {
            try fixture(observations: observations)
        }
    }

    @Test("Changed source proof makes a selected target stale")
    func changedSourceProofIsStale() throws {
        var observations = defaultObservations
        observations[alpha.pid] = observation(
            for: alpha,
            namespace: .sandboxContainer,
            sourceIdentity: String(repeating: "a", count: 64)
        )
        let baseline = try fixture(observations: observations)
        let plan = try OrderingPlan.make(
            snapshot: baseline,
            bundleIdentifiers: [alpha.bundleIdentifier!, beta.bundleIdentifier!],
            now: capturedAt.addingTimeInterval(5),
            id: fixedID
        )
        observations[alpha.pid] = observation(
            for: alpha,
            namespace: .sandboxContainer,
            sourceIdentity: String(repeating: "c", count: 64)
        )
        let changed = try fixture(
            observations: observations,
            capturedAt: capturedAt.addingTimeInterval(10)
        )
        #expect(throws: OrderingError.staleSnapshot(
            "owner preference source identity changed for selected target com.example.Alpha"
        )) {
            try plan.validateFresh(equivalentTo: changed, now: capturedAt.addingTimeInterval(15))
        }
    }

    @Test("Legacy non-sandbox snapshots decode without source proof and preserve fingerprints")
    func legacySnapshotWithoutSourceProof() throws {
        let baseline = try fixture()
        let legacyData = try JSONEncoder().encode(baseline)
        let legacyJSON = try #require(String(data: legacyData, encoding: .utf8))
        #expect(!legacyJSON.contains("ownerPreferenceSourceIdentity"))
        #expect(!legacyJSON.contains("applicationCodeIdentity"))
        let decoded = try JSONDecoder().decode(OrderingSnapshot.self, from: legacyData)
        #expect(decoded == baseline)
        #expect(try decoded.canonicalFingerprint == baseline.canonicalFingerprint)
    }

    @Test("Property-list values preserve integer, real and Boolean identity")
    func propertyListRoundTrip() throws {
        let date = Date(timeIntervalSinceReferenceDate: 123.25)
        let raw: NSDictionary = [
            "integer": NSNumber(value: Int64(42)),
            "real": NSNumber(value: 42.5),
            "bool": NSNumber(value: true),
            "string": "value",
            "data": Data([1, 2, 3]),
            "date": date,
            "array": [NSNumber(value: Int64(-3)), NSNumber(value: false)]
        ]
        let value = try OrderingValue.fromFoundation(raw)
        guard case let .dictionary(values) = value else { Issue.record("Expected dictionary"); return }
        #expect(values["integer"] == .integer(42))
        #expect(values["real"] == .real(42.5))
        #expect(values["bool"] == .bool(true))
        #expect(try OrderingValue.fromFoundation(value.toFoundation()) == value)

        let reordered = OrderingValue.dictionary(Dictionary(uniqueKeysWithValues: values.keys.sorted(by: >).map {
            ($0, values[$0]!)
        }))
        #expect(try value.canonicalFingerprint == reordered.canonicalFingerprint)
        #expect(throws: OrderingError.unsupportedPropertyListValue) {
            try OrderingValue.real(.infinity).validate()
        }
    }

    @Test("Resolver returns exact configured keys while allowing a different saved value")
    func exactIdentity() throws {
        let snapshot = try fixture()
        let candidates = try OrderingIdentityResolver.resolve(snapshot: snapshot)
        let alphaCandidate = try #require(candidates.first { $0.bundleIdentifier == alpha.bundleIdentifier })
        #expect(alphaCandidate.eligible)
        #expect(alphaCandidate.reasons.isEmpty)
        #expect(alphaCandidate.key == "status:com.example.Alpha::Item-0")
        #expect(alphaCandidate.persistentIdentifier == "Item-0")
        #expect(alphaCandidate.configuredValue == .integer(700))
        #expect(alphaCandidate.ownerSavedValue == .real(111.5))
    }

    @Test("Bundle and executable collisions include processes added during capture")
    func collisionAndAfterAddition() throws {
        let collision = OrderingProcess(bundleIdentifier: "com.example.NewArrival",
            executableName: "com.example.Alpha", pid: 303,
            launchTime: Date(timeIntervalSince1970: 9_500), isSystem: false)
        let snapshot = try fixture(afterProcesses: [alpha, beta, collision])
        let candidate = try #require(try OrderingIdentityResolver.resolve(snapshot: snapshot)
            .first { $0.bundleIdentifier == alpha.bundleIdentifier })
        #expect(!candidate.eligible)
        #expect(candidate.reasons.contains(.ownerTokenCollision))

        let duplicate = OrderingProcess(bundleIdentifier: "com.example.Alpha", executableName: "OtherAlpha",
            pid: 304, launchTime: Date(timeIntervalSince1970: 9_600), isSystem: false)
        let duplicateSnapshot = try fixture(afterProcesses: [alpha, beta, duplicate])
        let duplicateCandidate = try #require(try OrderingIdentityResolver.resolve(snapshot: duplicateSnapshot)
            .first { $0.bundleIdentifier == alpha.bundleIdentifier })
        #expect(duplicateCandidate.reasons.contains(.duplicateBundleOwner))
    }

    @Test("Changed PID lifetime and owner metadata make identity stale")
    func lifetimeAndMetadataDrift() throws {
        let replacement = OrderingProcess(bundleIdentifier: alpha.bundleIdentifier,
            executableName: alpha.executableName, pid: alpha.pid,
            launchTime: Date(timeIntervalSince1970: 9_999), isSystem: false)
        let lifetimeSnapshot = try fixture(afterProcesses: [replacement, beta])
        let candidate = try #require(try OrderingIdentityResolver.resolve(snapshot: lifetimeSnapshot)
            .first { $0.bundleIdentifier == alpha.bundleIdentifier })
        #expect(candidate.reasons.contains(.ownerLifetimeUnverified))

        let baseline = try fixture()
        let plan = try OrderingPlan.make(snapshot: baseline,
            bundleIdentifiers: [alpha.bundleIdentifier!, beta.bundleIdentifier!],
            now: capturedAt.addingTimeInterval(5), id: fixedID)
        var observations = baseline.observationsByPID
        observations[alpha.pid] = observation(for: alpha, displayName: "Renamed Alpha")
        let changed = try fixture(observations: observations)
        #expect(!plan.isFresh(equivalentTo: changed, now: capturedAt.addingTimeInterval(10)))
    }

    @Test("Freshness diagnostics identify selected-target observation drift without raw values")
    func selectedTargetObservationDiagnostics() throws {
        let baseline = try fixture()
        let plan = try OrderingPlan.make(snapshot: baseline,
            bundleIdentifiers: [alpha.bundleIdentifier!, beta.bundleIdentifier!],
            now: capturedAt.addingTimeInterval(5), id: fixedID)
        let selectedOwner = "selected target com.example.Alpha"
        let alphaObservation = try #require(baseline.observationsByPID[alpha.pid])
        let variants: [(String, OrderingOwnerObservation)] = [
            ("owner name changed for \(selectedOwner)",
             OrderingOwnerObservation(process: alpha, displayName: "Changed Alpha",
                axComplete: true, itemFrames: alphaObservation.itemFrames,
                ownerPreferencesComplete: true, ownerSavedPositions: alphaObservation.ownerSavedPositions)),
            ("Accessibility completeness changed for \(selectedOwner)",
             OrderingOwnerObservation(process: alpha, displayName: alphaObservation.displayName,
                axComplete: false, itemFrames: alphaObservation.itemFrames,
                ownerPreferencesComplete: true, ownerSavedPositions: alphaObservation.ownerSavedPositions)),
            ("owner preference completeness changed for \(selectedOwner)",
             OrderingOwnerObservation(process: alpha, displayName: alphaObservation.displayName,
                axComplete: true, itemFrames: alphaObservation.itemFrames,
                ownerPreferencesComplete: false, ownerSavedPositions: alphaObservation.ownerSavedPositions)),
            ("owner preference namespace changed for \(selectedOwner)",
             OrderingOwnerObservation(process: alpha, displayName: alphaObservation.displayName,
                axComplete: true, itemFrames: alphaObservation.itemFrames,
                ownerPreferencesComplete: true, ownerSavedPositions: alphaObservation.ownerSavedPositions,
                ownerPreferenceNamespace: .unknown)),
            ("owner saved-position set changed for \(selectedOwner)",
             OrderingOwnerObservation(process: alpha, displayName: alphaObservation.displayName,
                axComplete: true, itemFrames: alphaObservation.itemFrames,
                ownerPreferencesComplete: true, ownerSavedPositions: ["Item-0": .integer(333)])),
            ("Accessibility item cardinality changed for \(selectedOwner)",
             OrderingOwnerObservation(process: alpha, displayName: alphaObservation.displayName,
                axComplete: true, itemFrames: [frame(x: 100), frame(x: 140)],
                ownerPreferencesComplete: true, ownerSavedPositions: alphaObservation.ownerSavedPositions))
        ]

        for (reason, observation) in variants {
            var observations = baseline.observationsByPID
            observations[alpha.pid] = observation
            let changed = try fixture(observations: observations,
                capturedAt: capturedAt.addingTimeInterval(10))
            #expect(throws: OrderingError.staleSnapshot(reason)) {
                try plan.validateFresh(equivalentTo: changed, now: capturedAt.addingTimeInterval(15))
            }
        }

        var missing = baseline.observationsByPID
        missing.removeValue(forKey: alpha.pid)
        let missingSnapshot = try fixture(observations: missing,
            capturedAt: capturedAt.addingTimeInterval(10))
        #expect(throws: OrderingError.staleSnapshot(
            "observation inventory changed for \(selectedOwner)"
        )) {
            try plan.validateFresh(equivalentTo: missingSnapshot, now: capturedAt.addingTimeInterval(15))
        }

        let replacement = OrderingProcess(bundleIdentifier: alpha.bundleIdentifier,
            executableName: alpha.executableName, pid: alpha.pid,
            launchTime: Date(timeIntervalSince1970: 9_999), isSystem: false)
        var replacementObservations = baseline.observationsByPID
        replacementObservations[replacement.pid] = observation(for: replacement)
        let replaced = try fixture(beforeProcesses: [replacement, beta], afterProcesses: [replacement, beta],
            observations: replacementObservations, capturedAt: capturedAt.addingTimeInterval(10))
        #expect(throws: OrderingError.staleSnapshot(
            "owner process metadata changed for \(selectedOwner)"
        )) {
            try plan.validateFresh(equivalentTo: replaced, now: capturedAt.addingTimeInterval(15))
        }
    }

    @Test("Freshness ignores unrelated observation churn")
    func unrelatedOwnerObservationChurnDoesNotStalePlan() throws {
        let gamma = OrderingProcess(bundleIdentifier: "com.example.Gamma", executableName: "Gamma",
            pid: 303, launchTime: Date(timeIntervalSince1970: 9_200), isSystem: false)
        var group = defaultGroup
        guard case var .dictionary(table)? = group[OrderingSnapshot.tableKey] else { return }
        table["status:com.example.Gamma::Item-0"] = .integer(500)
        group[OrderingSnapshot.tableKey] = .dictionary(table)
        let gammaObservation = OrderingOwnerObservation(process: gamma, displayName: "Gamma",
            axComplete: true, itemFrames: [RectSnapshot(x: 500, y: 10, width: 24, height: 20)],
            ownerPreferencesComplete: true, ownerSavedPositions: ["Item-0": .integer(500)])
        var observations = defaultObservations
        observations[gamma.pid] = gammaObservation
        let baseline = try fixture(group: group, beforeProcesses: [alpha, beta, gamma],
            afterProcesses: [alpha, beta, gamma], observations: observations)
        let plan = try OrderingPlan.make(snapshot: baseline,
            bundleIdentifiers: [alpha.bundleIdentifier!, beta.bundleIdentifier!],
            now: capturedAt.addingTimeInterval(5), id: fixedID)

        observations[gamma.pid] = OrderingOwnerObservation(process: gamma, displayName: "Gamma",
            axComplete: true, itemFrames: [RectSnapshot(x: 500, y: 10, width: 26, height: 20)],
            ownerPreferencesComplete: true, ownerSavedPositions: ["Item-0": .integer(500)])
        let changedDimensions = try fixture(group: group, beforeProcesses: [alpha, beta, gamma],
            afterProcesses: [alpha, beta, gamma], observations: observations,
            capturedAt: capturedAt.addingTimeInterval(10))
        #expect(plan.isFresh(equivalentTo: changedDimensions, now: capturedAt.addingTimeInterval(15)))

        observations.removeValue(forKey: gamma.pid)
        let missingObservation = try fixture(group: group, beforeProcesses: [alpha, beta, gamma],
            afterProcesses: [alpha, beta, gamma], observations: observations,
            capturedAt: capturedAt.addingTimeInterval(10))
        #expect(plan.isFresh(equivalentTo: missingObservation, now: capturedAt.addingTimeInterval(15)))

        observations[gamma.pid] = OrderingOwnerObservation(process: gamma, displayName: "Renamed Gamma",
            axComplete: true, itemFrames: [frame(x: 500)],
            ownerPreferencesComplete: true, ownerSavedPositions: ["Item-0": .integer(501)])
        let changedMetadata = try fixture(group: group, beforeProcesses: [alpha, beta, gamma],
            afterProcesses: [alpha, beta, gamma], observations: observations,
            capturedAt: capturedAt.addingTimeInterval(10))
        #expect(plan.isFresh(equivalentTo: changedMetadata, now: capturedAt.addingTimeInterval(15)))
    }

    @Test("Freshness still rejects unrelated group and process inventory changes")
    func unrelatedGroupAndProcessInventoryChangesStalePlan() throws {
        let baseline = try fixture()
        let plan = try OrderingPlan.make(snapshot: baseline,
            bundleIdentifiers: [alpha.bundleIdentifier!, beta.bundleIdentifier!],
            now: capturedAt.addingTimeInterval(5), id: fixedID)

        var changedGroup = baseline.group
        changedGroup["UnrelatedPreference"] = .integer(999)
        let groupChanged = try fixture(group: changedGroup,
            capturedAt: capturedAt.addingTimeInterval(10))
        #expect(throws: OrderingError.staleSnapshot("group preferences changed")) {
            try plan.validateFresh(equivalentTo: groupChanged, now: capturedAt.addingTimeInterval(15))
        }

        let collidingOwner = OrderingProcess(bundleIdentifier: "com.example.Gamma",
            executableName: "com.example.Alpha", pid: 303,
            launchTime: Date(timeIntervalSince1970: 9_200), isSystem: false)
        let inventoryChanged = try fixture(
            beforeProcesses: [alpha, beta, collidingOwner],
            afterProcesses: [alpha, beta, collidingOwner],
            capturedAt: capturedAt.addingTimeInterval(10)
        )
        #expect(throws: OrderingError.staleSnapshot("the process inventory changed")) {
            try plan.validateFresh(equivalentTo: inventoryChanged, now: capturedAt.addingTimeInterval(15))
        }
    }

    @Test("Incomplete reads, multiple items and multiple keys are reported together")
    func cardinalityAndCompleteness() throws {
        var observations = defaultObservations
        observations[alpha.pid] = OrderingOwnerObservation(process: alpha, displayName: "Alpha",
            axComplete: false,
            itemFrames: [frame(x: 100), frame(x: 150)],
            ownerPreferencesComplete: false,
            ownerSavedPositions: ["Item-0": .integer(100)],
            ownerPreferenceNamespace: .sandboxed)
        var group = defaultGroup
        guard case var .dictionary(table)? = group[OrderingSnapshot.tableKey] else { return }
        table["status:Alpha::Second"] = .integer(800)
        group[OrderingSnapshot.tableKey] = .dictionary(table)
        let snapshot = try fixture(group: group, observations: observations)
        let candidate = try #require(try OrderingIdentityResolver.resolve(snapshot: snapshot)
            .first { $0.bundleIdentifier == alpha.bundleIdentifier })
        #expect(candidate.reasons.contains(.multipleAssociatedKeys))
        #expect(candidate.reasons.contains(.accessibilityIncomplete))
        #expect(candidate.reasons.contains(.singleItemNotEstablished))
        #expect(candidate.reasons.contains(.ownerPreferencesIncomplete))
        #expect(candidate.reasons.contains(.ownerPreferenceNamespaceUnsupported))
    }

    @Test("Boolean positions are rejected while integer positions remain exact")
    func boolIsNotInteger() throws {
        var group = defaultGroup
        guard case var .dictionary(table)? = group[OrderingSnapshot.tableKey] else { return }
        table["status:com.example.Alpha::Item-0"] = .bool(true)
        group[OrderingSnapshot.tableKey] = .dictionary(table)
        let snapshot = try fixture(group: group)
        let candidate = try #require(try OrderingIdentityResolver.resolve(snapshot: snapshot)
            .first { $0.bundleIdentifier == alpha.bundleIdentifier })
        #expect(candidate.reasons.contains(.configuredPositionInvalid))
        #expect(try OrderingIdentityResolver.resolve(snapshot: fixture())
            .first { $0.bundleIdentifier == alpha.bundleIdentifier }?.configuredValue == .integer(700))
    }

    @Test("Plans are deterministic, Codable and reject modified receipts")
    func planIntegrity() throws {
        let snapshot = try fixture()
        let plan = try OrderingPlan.make(snapshot: snapshot,
            bundleIdentifiers: [beta.bundleIdentifier!, alpha.bundleIdentifier!],
            now: capturedAt.addingTimeInterval(5), id: fixedID)
        try plan.validate()
        #expect(plan.targets.map(\.bundleIdentifier) == ["com.example.Alpha", "com.example.Beta"])
        #expect(plan.targets[0].before == .integer(700))
        #expect(plan.targets[0].after == .real(300.5))
        let decoded = try JSONDecoder().decode(OrderingPlan.self, from: JSONEncoder().encode(plan))
        try decoded.validate()
        #expect(decoded == plan)

        let reorderedSnapshot = try fixture(beforeProcesses: [beta, alpha], afterProcesses: [beta, alpha],
            observations: [beta.pid: defaultObservations[beta.pid]!, alpha.pid: defaultObservations[alpha.pid]!])
        let reorderedPlan = try OrderingPlan.make(snapshot: reorderedSnapshot,
            bundleIdentifiers: [alpha.bundleIdentifier!, beta.bundleIdentifier!],
            now: capturedAt.addingTimeInterval(5), id: fixedID)
        #expect(reorderedPlan.fingerprint == plan.fingerprint)

        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        object["fingerprint"] = String(repeating: "0", count: 64)
        let corrupted = try JSONDecoder().decode(OrderingPlan.self,
            from: JSONSerialization.data(withJSONObject: object))
        #expect(throws: OrderingError.malformedPlan) { try corrupted.validate() }
    }

    @Test("Apply requires the whole baseline; partial inverse preserves unrelated drift")
    func applyAndPartialInverse() throws {
        let snapshot = try fixture()
        let plan = try OrderingPlan.make(snapshot: snapshot,
            bundleIdentifiers: [alpha.bundleIdentifier!, beta.bundleIdentifier!],
            now: capturedAt.addingTimeInterval(5), id: fixedID)
        let applied = try plan.applying(to: snapshot.group)
        var partial = applied
        guard case var .dictionary(table)? = partial[OrderingSnapshot.tableKey] else { return }
        table[plan.targets[0].key] = plan.targets[0].before
        table["status:com.example.Unrelated::Item-0"] = .integer(999)
        partial[OrderingSnapshot.tableKey] = .dictionary(table)
        partial["ExternalGroupChange"] = .string("preserve")
        let restored = try plan.restoring(current: partial)
        guard case let .dictionary(restoredTable)? = restored[OrderingSnapshot.tableKey] else { return }
        #expect(restoredTable[plan.targets[0].key] == plan.targets[0].before)
        #expect(restoredTable[plan.targets[1].key] == plan.targets[1].before)
        #expect(restoredTable["status:com.example.Unrelated::Item-0"] == .integer(999))
        #expect(restored["ExternalGroupChange"] == .string("preserve"))

        var externalTargetChange = partial
        guard case var .dictionary(changedTable)? = externalTargetChange[OrderingSnapshot.tableKey] else { return }
        changedTable[plan.targets[1].key] = .integer(1_234)
        externalTargetChange[OrderingSnapshot.tableKey] = .dictionary(changedTable)
        #expect(throws: OrderingError.targetDrift(plan.targets[1].key)) {
            try plan.restoring(current: externalTargetChange)
        }
        var staleGroup = snapshot.group
        staleGroup["unrelated"] = .bool(false)
        #expect(throws: OrderingError.staleSnapshot("the complete baseline group changed")) {
            try plan.applying(to: staleGroup)
        }
    }

    @Test("Fresh checks tolerate common X translation but enforce baseline relative order")
    func translationAndRelativeOrder() throws {
        let baseline = try fixture()
        let plan = try OrderingPlan.make(snapshot: baseline,
            bundleIdentifiers: [alpha.bundleIdentifier!, beta.bundleIdentifier!],
            now: capturedAt.addingTimeInterval(5), id: fixedID)
        let translated = try fixture(observations: [
            alpha.pid: observation(for: alpha, frame: frame(x: 150)),
            beta.pid: observation(for: beta, frame: frame(x: 350))
        ], capturedAt: capturedAt.addingTimeInterval(10))
        #expect(plan.isFresh(equivalentTo: translated, now: capturedAt.addingTimeInterval(15)))
        try plan.verifyRelativeOrder(in: translated, phase: .baseline)

        let swapped = try fixture(observations: [
            alpha.pid: observation(for: alpha, frame: frame(x: 350)),
            beta.pid: observation(for: beta, frame: frame(x: 100))
        ], capturedAt: capturedAt.addingTimeInterval(10))
        #expect(!plan.isFresh(equivalentTo: swapped, now: capturedAt.addingTimeInterval(15)))
        try plan.verifyRelativeOrder(in: swapped, phase: .applied)
        #expect(!plan.isFresh(equivalentTo: translated, now: capturedAt.addingTimeInterval(70)))
    }

    @Test("Fresh checks and verification accept changed render geometry in the same band")
    func renderGeometryChanges() throws {
        let baseline = try fixture(observations: [
            alpha.pid: observation(for: alpha,
                frame: RectSnapshot(x: 100, y: 10, width: 400, height: 20)),
            beta.pid: observation(for: beta,
                frame: RectSnapshot(x: 101, y: 10, width: 400, height: 20))
        ])
        let plan = try OrderingPlan.make(snapshot: baseline,
            bundleIdentifiers: [alpha.bundleIdentifier!, beta.bundleIdentifier!],
            now: capturedAt.addingTimeInterval(5), id: fixedID)

        let fresh = try fixture(observations: [
            alpha.pid: observation(for: alpha,
                frame: RectSnapshot(x: 120, y: 14, width: 350, height: 18)),
            beta.pid: observation(for: beta,
                frame: RectSnapshot(x: 130, y: 9, width: 400, height: 30))
        ], capturedAt: capturedAt.addingTimeInterval(10))
        try plan.validateFresh(equivalentTo: fresh, now: capturedAt.addingTimeInterval(15))
        try plan.verifyRelativeOrder(in: fresh, phase: .baseline)

        let applied = try fixture(observations: [
            alpha.pid: observation(for: alpha,
                frame: RectSnapshot(x: 130, y: 14, width: 400, height: 18)),
            beta.pid: observation(for: beta,
                frame: RectSnapshot(x: 120, y: 9, width: 350, height: 30))
        ], capturedAt: capturedAt.addingTimeInterval(10))
        try plan.verifyRelativeOrder(in: applied, phase: .applied)
    }

    @Test("Geometry without a common horizontal band fails closed")
    func differentVerticalBands() throws {
        let separatedBands = try fixture(observations: [
            alpha.pid: observation(for: alpha,
                frame: RectSnapshot(x: 100, y: 0, width: 24, height: 10)),
            beta.pid: observation(for: beta,
                frame: RectSnapshot(x: 300, y: 20, width: 24, height: 20))
        ])
        #expect(throws: OrderingError.invalidGeometry) {
            try OrderingPlan.make(snapshot: separatedBands,
                bundleIdentifiers: [alpha.bundleIdentifier!, beta.bundleIdentifier!],
                now: capturedAt.addingTimeInterval(5), id: fixedID)
        }
    }

    @Test("Self scope, Apple scope and non-visible intent fail closed")
    func excludedScope() throws {
        let hidden = try fixture(orderingAllowed: [alpha.bundleIdentifier!])
        let betaCandidate = try #require(try OrderingIdentityResolver.resolve(snapshot: hidden)
            .first { $0.bundleIdentifier == beta.bundleIdentifier })
        #expect(betaCandidate.reasons.contains(.policyScopeExcluded))

        let multipleDisplays = try fixture(displayCount: 2)
        let displayCandidate = try #require(try OrderingIdentityResolver.resolve(snapshot: multipleDisplays)
            .first { $0.bundleIdentifier == alpha.bundleIdentifier })
        #expect(displayCandidate.reasons.contains(.singleDisplayRequired))
        #expect(throws: OrderingError.ineligibleBundle("com.example.Alpha", [.singleDisplayRequired])) {
            try OrderingPlan.make(snapshot: multipleDisplays,
                bundleIdentifiers: [alpha.bundleIdentifier!, beta.bundleIdentifier!],
                now: capturedAt.addingTimeInterval(5), id: fixedID)
        }

        let selfProcess = OrderingProcess(bundleIdentifier: "xyz.fi5h.blenny", executableName: "Blenny",
            pid: 401, launchTime: Date(timeIntervalSince1970: 9_000), isSystem: false)
        let appleProcess = OrderingProcess(bundleIdentifier: "com.apple.Example", executableName: "AppleItem",
            pid: 402, launchTime: Date(timeIntervalSince1970: 9_000), isSystem: true)
        let excludedGroup: [String: OrderingValue] = [OrderingSnapshot.tableKey: .dictionary([
            "status:xyz.fi5h.blenny::Item-0": .integer(100),
            "status:com.apple.Example::Item-0": .integer(200)
        ])]
        let excluded = try fixture(group: excludedGroup,
            beforeProcesses: [selfProcess, appleProcess], afterProcesses: [selfProcess, appleProcess],
            observations: [
                selfProcess.pid: OrderingOwnerObservation(process: selfProcess, displayName: "Blenny",
                    axComplete: true, itemFrames: [frame(x: 100)], ownerPreferencesComplete: true,
                    ownerSavedPositions: ["Item-0": .integer(100)]),
                appleProcess.pid: OrderingOwnerObservation(process: appleProcess, displayName: "Apple",
                    axComplete: true, itemFrames: [frame(x: 300)], ownerPreferencesComplete: true,
                    ownerSavedPositions: ["Item-0": .integer(200)])
            ], orderingAllowed: ["xyz.fi5h.blenny", "com.apple.Example"])
        let excludedCandidates = try OrderingIdentityResolver.resolve(snapshot: excluded)
        #expect(excludedCandidates.first { $0.bundleIdentifier == "xyz.fi5h.blenny" }?.reasons.contains(.selfExcluded) == true)
        #expect(excludedCandidates.first { $0.bundleIdentifier == "com.apple.Example" }?.reasons.contains(.systemOwnerExcluded) == true)
    }

    private var fixedID: UUID { UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")! }

    private var defaultGroup: [String: OrderingValue] {
        [
            OrderingSnapshot.tableKey: .dictionary([
                "status:com.example.Alpha::Item-0": .integer(700),
                "status:com.example.Beta::Item-0": .real(300.5),
                "module:unrelated": .integer(10)
            ]),
            "OtherPreference": .array([.string("kept"), .bool(true)])
        ]
    }

    private var defaultObservations: [Int32: OrderingOwnerObservation] {
        [
            alpha.pid: observation(for: alpha),
            beta.pid: observation(for: beta)
        ]
    }

    private func frame(x: Double) -> RectSnapshot {
        RectSnapshot(x: x, y: 10, width: 24, height: 20)
    }

    private func observation(for process: OrderingProcess, displayName: String? = nil,
                             frame suppliedFrame: RectSnapshot? = nil,
                             namespace: OrderingOwnerPreferenceNamespace = .currentUserAnyHost,
                             sourceIdentity: String? = nil) -> OrderingOwnerObservation {
        let isAlpha = process.bundleIdentifier == alpha.bundleIdentifier
        return OrderingOwnerObservation(process: process,
            displayName: displayName ?? (isAlpha ? "Alpha" : "Beta"), axComplete: true,
            itemFrames: [suppliedFrame ?? frame(x: isAlpha ? 100 : 300)],
            ownerPreferencesComplete: true,
            ownerSavedPositions: ["Item-0": isAlpha ? .real(111.5) : .integer(222)],
            ownerPreferenceNamespace: namespace,
            ownerPreferenceSourceIdentity: sourceIdentity)
    }

    private func fixture(group: [String: OrderingValue]? = nil,
                         beforeProcesses: [OrderingProcess]? = nil,
                         afterProcesses: [OrderingProcess]? = nil,
                         observations: [Int32: OrderingOwnerObservation]? = nil,
                         orderingAllowed: Set<String>? = nil,
                         displayCount: Int = 1,
                         capturedAt suppliedCapturedAt: Date? = nil) throws -> OrderingSnapshot {
        try OrderingSnapshot(group: group ?? defaultGroup,
            beforeProcesses: beforeProcesses ?? [alpha, beta],
            afterProcesses: afterProcesses ?? [alpha, beta],
            observationsByPID: observations ?? defaultObservations,
            osBuild: OrderingSnapshot.supportedBuild,
            architecture: OrderingSnapshot.supportedArchitecture,
            runtimeContractVerified: true,
            displaySignature: "display-\(displayCount):0,0,1000,40@2",
            displayCount: displayCount,
            displayFrame: RectSnapshot(x: 0, y: 0, width: 1_000, height: 40),
            lifecycleGeneration: 7,
            policyFingerprint: "visible-policy",
            orderingAllowedBundleIdentifiers: orderingAllowed ?? [alpha.bundleIdentifier!, beta.bundleIdentifier!],
            capturedAt: suppliedCapturedAt ?? capturedAt)
    }
}
#endif
