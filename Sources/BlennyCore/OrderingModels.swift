#if BLENNY_PRODUCT || DEBUG
import CoreFoundation
import CryptoKit
import Foundation

public enum OrderingPhase: String, Codable, Equatable, Sendable { case baseline, applied }
public enum OrderingRelativeOrder: String, Codable, Equatable, Sendable {
    case firstBeforeSecond
    case secondBeforeFirst

    var inverse: OrderingRelativeOrder {
        self == .firstBeforeSecond ? .secondBeforeFirst : .firstBeforeSecond
    }
}

public struct OrderingPlan: Codable, Equatable, Sendable {
    public static let maximumSnapshotAge: TimeInterval = 60
    public static let maximumReorderingTargets = 32
    public static let maximumConfigurationKeys = 128

    public let schemaVersion: Int
    public let id: UUID
    public let createdAt: Date
    public let baseline: OrderingSnapshot
    public let targets: [OrderingTarget]
    /// Present only for schema 3. Legacy schema 1/2 encoding and fingerprints
    /// remain unchanged because they continue to encode this as absent.
    public let configurationTargets: [OrderingConfigurationOwnerTarget]?
    /// Present only for schema 4. The array preserves the reviewed mixed order
    /// across whole application owners and exact Apple system items.
    public let configurationSubjectTargets: [OrderingConfigurationSubjectTarget]?
    public let fingerprint: String

    public var configurationKeyTargets: [OrderingConfigurationKeyTarget] {
        if let configurationSubjectTargets {
            return configurationSubjectTargets.flatMap(\.keys)
        }
        return configurationTargets?.flatMap(\.keys) ?? []
    }

    public var orderedConfigurationSubjects: [OrderingSubjectID]? {
        if let configurationSubjectTargets {
            return configurationSubjectTargets.map(\.subjectID)
        }
        return configurationTargets?.map { .application($0.bundleIdentifier) }
    }

    public static func make(snapshot: OrderingSnapshot, bundleIdentifiers: [String], now: Date = Date(),
                            id: UUID = UUID()) throws -> OrderingPlan {
        try snapshot.validate()
        guard bundleIdentifiers.count == 2, Set(bundleIdentifiers).count == 2 else {
            throw OrderingError.invalidSelection
        }
        try validateAge(snapshot.capturedAt, now: now)
        let targets = try deriveTargets(snapshot: snapshot, bundleIdentifiers: bundleIdentifiers)
        let plan = OrderingPlan(schemaVersion: 1, id: id, createdAt: now, baseline: snapshot,
                                targets: targets, configurationTargets: nil,
                                configurationSubjectTargets: nil, fingerprint: "")
        let fingerprint = try plan.computedFingerprint()
        return OrderingPlan(schemaVersion: 1, id: id, createdAt: now, baseline: snapshot,
                            targets: targets, configurationTargets: nil,
                            configurationSubjectTargets: nil, fingerprint: fingerprint)
    }

    /// Builds a bounded permutation from the owners' current visible slots.
    /// `orderedBundleIdentifiers` is the complete desired left-to-right order
    /// for the selected owners. Existing configured values are moved between
    /// those owners; this planner never synthesizes a numeric position.
    public static func makeReordering(
        snapshot: OrderingSnapshot,
        orderedBundleIdentifiers: [String],
        now: Date = Date(),
        id: UUID = UUID()
    ) throws -> OrderingPlan {
        try snapshot.validate()
        guard (2...maximumReorderingTargets).contains(orderedBundleIdentifiers.count),
              Set(orderedBundleIdentifiers).count == orderedBundleIdentifiers.count else {
            throw OrderingError.invalidSelection
        }
        try validateAge(snapshot.capturedAt, now: now)
        let targets = try deriveReorderingTargets(
            snapshot: snapshot,
            orderedBundleIdentifiers: orderedBundleIdentifiers
        )
        guard targets.contains(where: { $0.before != $0.after }) else {
            throw OrderingError.invalidSelection
        }
        let plan = OrderingPlan(schemaVersion: 2, id: id, createdAt: now, baseline: snapshot,
                                targets: targets, configurationTargets: nil,
                                configurationSubjectTargets: nil, fingerprint: "")
        let fingerprint = try plan.computedFingerprint()
        return OrderingPlan(schemaVersion: 2, id: id, createdAt: now, baseline: snapshot,
                            targets: targets, configurationTargets: nil,
                            configurationSubjectTargets: nil, fingerprint: fingerprint)
    }

    /// Creates a configuration-first bundle ordering. The identifiers are the
    /// desired physical left-to-right bundle order. macOS 27 ranks larger
    /// preferred-position values farther left, so existing exact numeric slots
    /// are assigned in descending order without deriving values from AX frames.
    public static func makeConfigurationOrdering(
        snapshot: OrderingSnapshot,
        orderedBundleIdentifiers: [String],
        now: Date = Date(),
        id: UUID = UUID()
    ) throws -> OrderingPlan {
        try snapshot.validate()
        guard (1...maximumReorderingTargets).contains(orderedBundleIdentifiers.count),
              Set(orderedBundleIdentifiers).count == orderedBundleIdentifiers.count else {
            throw OrderingError.invalidSelection
        }
        try validateAge(snapshot.capturedAt, now: now)
        let ownerTargets = try deriveConfigurationTargets(
            snapshot: snapshot,
            orderedBundleIdentifiers: orderedBundleIdentifiers
        )
        let plan = OrderingPlan(
            schemaVersion: 3, id: id, createdAt: now, baseline: snapshot,
            targets: [], configurationTargets: ownerTargets,
            configurationSubjectTargets: nil, fingerprint: ""
        )
        let fingerprint = try plan.computedFingerprint()
        return OrderingPlan(
            schemaVersion: 3, id: id, createdAt: now, baseline: snapshot,
            targets: [], configurationTargets: ownerTargets,
            configurationSubjectTargets: nil, fingerprint: fingerprint
        )
    }

    public static func makeConfigurationOrdering(
        snapshot: OrderingSnapshot,
        orderedSubjects: [OrderingSubjectID],
        now: Date = Date(),
        id: UUID = UUID()
    ) throws -> OrderingPlan {
        try snapshot.validate()
        guard (0...maximumReorderingTargets).contains(orderedSubjects.count),
              Set(orderedSubjects).count == orderedSubjects.count else {
            throw OrderingError.invalidSelection
        }
        try validateAge(snapshot.capturedAt, now: now)
        let subjectTargets = try deriveConfigurationSubjectTargets(
            snapshot: snapshot, orderedSubjects: orderedSubjects
        )
        let plan = OrderingPlan(
            schemaVersion: 4, id: id, createdAt: now, baseline: snapshot,
            targets: [], configurationTargets: nil,
            configurationSubjectTargets: subjectTargets, fingerprint: ""
        )
        let fingerprint = try plan.computedFingerprint()
        return OrderingPlan(
            schemaVersion: 4, id: id, createdAt: now, baseline: snapshot,
            targets: [], configurationTargets: nil,
            configurationSubjectTargets: subjectTargets, fingerprint: fingerprint
        )
    }

    private init(schemaVersion: Int, id: UUID, createdAt: Date, baseline: OrderingSnapshot,
                 targets: [OrderingTarget], configurationTargets: [OrderingConfigurationOwnerTarget]?,
                 configurationSubjectTargets: [OrderingConfigurationSubjectTarget]?,
                 fingerprint: String) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.createdAt = createdAt
        self.baseline = baseline
        self.targets = targets
        self.configurationTargets = configurationTargets
        self.configurationSubjectTargets = configurationSubjectTargets
        self.fingerprint = fingerprint
    }

    public func validate() throws {
        let validTargetCount = switch schemaVersion {
        case 1: targets.count == 2
        case 2: (2...Self.maximumReorderingTargets).contains(targets.count)
            && targets.contains(where: { $0.before != $0.after })
        case 3:
            targets.isEmpty
                && configurationTargets.map {
                    (1...Self.maximumReorderingTargets).contains($0.count)
                        && !$0.isEmpty
                        && $0.flatMap(\.keys).count <= Self.maximumConfigurationKeys
                } == true
        case 4:
            targets.isEmpty && configurationTargets == nil
                && configurationSubjectTargets.map {
                    (0...Self.maximumReorderingTargets).contains($0.count)
                        && $0.flatMap(\.keys).count <= Self.maximumConfigurationKeys
                } == true
        default: false
        }
        guard validTargetCount,
              createdAt >= baseline.capturedAt,
              createdAt.timeIntervalSince(baseline.capturedAt) <= Self.maximumSnapshotAge else {
            throw OrderingError.malformedPlan
        }
        try baseline.validate()
        if schemaVersion == 3 {
            guard configurationSubjectTargets == nil, let configurationTargets,
                  Set(configurationTargets.map(\.bundleIdentifier)).count == configurationTargets.count,
                  Set(configurationTargets.map(\.process.pid)).count == configurationTargets.count,
                  Set(configurationTargets.flatMap(\.keys).map(\.key)).count
                    == configurationTargets.flatMap(\.keys).count,
                  configurationTargets.allSatisfy({ !$0.keys.isEmpty }),
                  configurationTargets.flatMap(\.keys).allSatisfy({
                      $0.before.positivePosition != nil && $0.after.positivePosition != nil
                  }) else {
                throw OrderingError.malformedPlan
            }
            let derived = try Self.deriveConfigurationTargets(
                snapshot: baseline,
                orderedBundleIdentifiers: configurationTargets.map(\.bundleIdentifier)
            )
            guard derived == configurationTargets, fingerprint == (try computedFingerprint()) else {
                throw OrderingError.malformedPlan
            }
            return
        }
        if schemaVersion == 4 {
            guard let configurationSubjectTargets,
                  Set(configurationSubjectTargets.map(\.subjectID)).count
                    == configurationSubjectTargets.count,
                  Set(configurationSubjectTargets.flatMap(\.keys).map(\.key)).count
                    == configurationSubjectTargets.flatMap(\.keys).count,
                  configurationSubjectTargets.allSatisfy({ !$0.keys.isEmpty }),
                  configurationSubjectTargets.flatMap(\.keys).allSatisfy({
                      $0.before.positivePosition != nil && $0.after.positivePosition != nil
                  }) else {
                throw OrderingError.malformedPlan
            }
            let derived = try Self.deriveConfigurationSubjectTargets(
                snapshot: baseline,
                orderedSubjects: configurationSubjectTargets.map(\.subjectID)
            )
            guard derived == configurationSubjectTargets,
                  fingerprint == (try computedFingerprint()) else {
                throw OrderingError.malformedPlan
            }
            return
        }
        guard configurationTargets == nil,
              configurationSubjectTargets == nil,
              Set(targets.map(\.bundleIdentifier)).count == targets.count,
              Set(targets.map(\.key)).count == targets.count,
              Set(targets.map(\.process.pid)).count == targets.count else {
            throw OrderingError.malformedPlan
        }
        let derived: [OrderingTarget]
        switch schemaVersion {
        case 1:
            derived = try Self.deriveTargets(snapshot: baseline,
                                             bundleIdentifiers: targets.map(\.bundleIdentifier))
        case 2:
            derived = try Self.deriveReorderingTargets(
                snapshot: baseline,
                orderedBundleIdentifiers: targets.map(\.bundleIdentifier)
            )
        default:
            throw OrderingError.malformedPlan
        }
        guard derived == targets, fingerprint == (try computedFingerprint()) else {
            throw OrderingError.malformedPlan
        }
    }

    public func validateFresh(equivalentTo snapshot: OrderingSnapshot, now: Date = Date()) throws {
        try validate()
        try snapshot.validate()
        try Self.validateAge(createdAt, now: now)
        try Self.validateAge(snapshot.capturedAt, now: now)
        let configurationPlan = schemaVersion == 3 || schemaVersion == 4
        if !configurationPlan, baseline.group != snapshot.group {
            throw OrderingError.staleSnapshot("group preferences changed")
        }
        guard baseline.osBuild == snapshot.osBuild, baseline.architecture == snapshot.architecture,
              baseline.runtimeContractVerified == snapshot.runtimeContractVerified,
              baseline.displaySignature == snapshot.displaySignature,
              baseline.displayCount == snapshot.displayCount, baseline.displayFrame == snapshot.displayFrame,
              baseline.lifecycleGeneration == snapshot.lifecycleGeneration,
              baseline.policyFingerprint == snapshot.policyFingerprint else {
            throw OrderingError.staleSnapshot("runtime, display, lifecycle or policy context changed")
        }
        if !configurationPlan,
           baseline.orderingAllowedBundleIdentifiers != snapshot.orderingAllowedBundleIdentifiers {
            throw OrderingError.staleSnapshot("runtime, display, lifecycle or policy context changed")
        }
        // The complete process inventory below establishes token uniqueness.
        // AX/pref evidence belongs to the selected owners; unrelated dynamic
        // icons cannot change any target's identity or reviewed positions.
        let selectedPIDs: Set<Int32> = if schemaVersion == 3 {
            Set((configurationTargets ?? []).map(\.process.pid))
        } else if schemaVersion == 4 {
            Set((configurationSubjectTargets ?? []).compactMap { target in
                if case let .application(owner) = target { return owner.process.pid }
                return nil
            })
        } else {
            Set(targets.map(\.process.pid))
        }
        let exactCodeIdentitiesByPID: [Int32: OrderingApplicationCodeIdentity] = if schemaVersion == 3 {
            Dictionary(uniqueKeysWithValues: (configurationTargets ?? []).compactMap { target in
                target.exactBundleCodeIdentity.map { (target.process.pid, $0) }
            })
        } else if schemaVersion == 4 {
            Dictionary(uniqueKeysWithValues: (configurationSubjectTargets ?? []).compactMap { target in
                guard case let .application(owner) = target,
                      let identity = owner.exactBundleCodeIdentity else { return nil }
                return (owner.process.pid, identity)
            })
        } else {
            [:]
        }
        if let difference = Self.observationDifference(
            baseline.observationsByPID.filter { selectedPIDs.contains($0.key) },
            snapshot.observationsByPID.filter { selectedPIDs.contains($0.key) },
            selectedPIDs: selectedPIDs,
            includeGeometryEvidence: !configurationPlan,
            exactCodeIdentitiesByPID: exactCodeIdentitiesByPID
        ) {
            throw OrderingError.staleSnapshot(difference)
        }
        if configurationPlan {
            let targetKeys = Set(configurationKeyTargets.map(\.key))
            if !targetKeys.isEmpty {
                try baseline.validateConfigurationProcessScope(for: targetKeys, against: snapshot)
            }
            if schemaVersion == 3 {
                let resolved = try OrderingConfigurationIdentityResolver.resolve(snapshot: snapshot)
                for target in configurationTargets ?? [] {
                    guard let candidate = resolved.first(where: { $0.bundleIdentifier == target.bundleIdentifier }),
                          candidate.eligible,
                          candidate.process == target.process,
                          candidate.keys.map(\.key) == target.keys.map(\.key),
                          Dictionary(uniqueKeysWithValues: candidate.keys.map { ($0.key, $0.value) })
                            == Dictionary(uniqueKeysWithValues: target.keys.map { ($0.key, $0.before) }) else {
                        throw OrderingError.staleSnapshot("target identity is no longer eligible")
                    }
                }
            } else {
                let derived = try Self.deriveConfigurationSubjectTargets(
                    snapshot: snapshot,
                    orderedSubjects: (configurationSubjectTargets ?? []).map(\.subjectID)
                )
                guard derived == configurationSubjectTargets else {
                    throw OrderingError.staleSnapshot("target identity is no longer eligible")
                }
            }
        } else {
            guard Self.sorted(baseline.beforeProcesses) == Self.sorted(snapshot.beforeProcesses),
                  Self.sorted(baseline.afterProcesses) == Self.sorted(snapshot.afterProcesses) else {
                throw OrderingError.staleSnapshot("the process inventory changed")
            }
            try verifyRelativeOrder(in: snapshot, phase: .baseline)
            let resolved = try OrderingIdentityResolver.resolve(snapshot: snapshot)
            for target in targets {
                guard let candidate = resolved.first(where: { $0.bundleIdentifier == target.bundleIdentifier }),
                      candidate.eligible else {
                    throw OrderingError.staleSnapshot("target identity is no longer eligible")
                }
            }
        }
    }

    public func isFresh(equivalentTo snapshot: OrderingSnapshot, now: Date = Date()) -> Bool {
        do { try validateFresh(equivalentTo: snapshot, now: now); return true }
        catch { return false }
    }

    public func applying(to currentGroup: [String: OrderingValue]) throws -> [String: OrderingValue] {
        try validate()
        try OrderingValue.dictionary(currentGroup).validate()
        if schemaVersion != 3 && schemaVersion != 4, currentGroup != baseline.group {
            throw OrderingError.staleSnapshot("the complete baseline group changed")
        }
        var result = currentGroup
        var table = try table(in: currentGroup)
        if schemaVersion == 3 || schemaVersion == 4 {
            for target in configurationKeyTargets {
                guard table[target.key] == target.before else { throw OrderingError.targetDrift(target.key) }
                table[target.key] = target.after
            }
        } else {
            for target in targets {
                guard table[target.key] == target.before else { throw OrderingError.targetDrift(target.key) }
                table[target.key] = target.after
            }
        }
        result[OrderingSnapshot.tableKey] = .dictionary(table)
        return result
    }

    public var configurationBeforeValues: [String: OrderingValue]? {
        guard schemaVersion == 3 || schemaVersion == 4 else { return nil }
        return Dictionary(uniqueKeysWithValues: configurationKeyTargets.map {
            ($0.key, $0.before)
        })
    }

    public var configurationAfterValues: [String: OrderingValue]? {
        guard schemaVersion == 3 || schemaVersion == 4 else { return nil }
        return Dictionary(uniqueKeysWithValues: configurationKeyTargets.map {
            ($0.key, $0.after)
        })
    }

    public func restoring(current currentGroup: [String: OrderingValue]) throws -> [String: OrderingValue] {
        try validate()
        try OrderingValue.dictionary(currentGroup).validate()
        var result = currentGroup
        var table = try table(in: currentGroup)
        if schemaVersion == 3 || schemaVersion == 4 {
            let values = configurationKeyTargets
            for target in values {
                guard let value = table[target.key], value == target.before || value == target.after else {
                    throw OrderingError.targetDrift(target.key)
                }
            }
            for target in values { table[target.key] = target.before }
        } else {
            for target in targets {
                guard let value = table[target.key], value == target.before || value == target.after else {
                    throw OrderingError.targetDrift(target.key)
                }
            }
            for target in targets { table[target.key] = target.before }
        }
        result[OrderingSnapshot.tableKey] = .dictionary(table)
        return result
    }

    public func relativeOrder(in snapshot: OrderingSnapshot) throws -> OrderingRelativeOrder {
        guard targets.count == 2,
              let first = snapshot.observationsByPID[targets[0].process.pid],
              let second = snapshot.observationsByPID[targets[1].process.pid],
              first.process == targets[0].process, second.process == targets[1].process,
              first.axComplete, second.axComplete,
              first.itemFrames.count == 1, second.itemFrames.count == 1 else {
            throw OrderingError.invalidGeometry
        }
        return try Self.relativeOrder(first.itemFrames[0], second.itemFrames[0])
    }

    public func verifyRelativeOrder(in snapshot: OrderingSnapshot, phase: OrderingPhase) throws {
        try snapshot.validate()
        guard snapshot.displaySignature == baseline.displaySignature,
              snapshot.displayCount == baseline.displayCount,
              snapshot.displayFrame == baseline.displayFrame else {
            throw OrderingError.invalidGeometry
        }

        if schemaVersion == 3 {
            guard physicalVerificationStatus(in: snapshot, phase: phase) == .verified else {
                throw OrderingError.relativeOrderMismatch
            }
            return
        }

        var observedFrames: [(bundleIdentifier: String, frame: RectSnapshot)] = []
        for target in targets {
            guard let observation = snapshot.observationsByPID[target.process.pid],
                  observation.process == target.process, observation.axComplete,
                  observation.itemFrames.count == 1 else {
                throw OrderingError.invalidGeometry
            }
            let frame = observation.itemFrames[0]
            guard Self.visible(frame, in: snapshot.displayFrame) else {
                throw OrderingError.invalidGeometry
            }
            observedFrames.append((target.bundleIdentifier, frame))
        }

        let observed = try Self.leftToRightBundleIdentifiers(observedFrames)
        let baselineOrder = try Self.leftToRightBundleIdentifiers(targets.map {
            ($0.bundleIdentifier, $0.frame)
        })
        let appliedOrder: [String]
        switch schemaVersion {
        case 1: appliedOrder = baselineOrder.reversed()
        case 2: appliedOrder = targets.map(\.bundleIdentifier)
        default: throw OrderingError.malformedPlan
        }
        let expected = phase == .baseline ? baselineOrder : appliedOrder
        guard observed == expected else { throw OrderingError.relativeOrderMismatch }
    }

    public func physicalVerificationStatus(
        in snapshot: OrderingSnapshot, phase: OrderingPhase = .applied
    ) -> OrderingPhysicalVerificationStatus {
        guard schemaVersion == 3, let configurationTargets else { return .unavailable }
        var values: [(bundleIdentifier: String, frame: RectSnapshot)] = []
        for target in configurationTargets {
            guard let observation = snapshot.observationsByPID[target.process.pid],
                  observation.process == target.process, observation.axComplete,
                  observation.itemFrames.count == 1,
                  Self.visible(observation.itemFrames[0], in: snapshot.displayFrame) else {
                return .unavailable
            }
            values.append((target.bundleIdentifier, observation.itemFrames[0]))
        }
        guard let observed = try? Self.leftToRightBundleIdentifiers(values) else {
            return .unavailable
        }
        let desired = configurationTargets.map(\.bundleIdentifier)
        let baseline: [String]
        let candidates = try? OrderingConfigurationIdentityResolver.resolve(snapshot: self.baseline)
        let baselineFrames = configurationTargets.compactMap { target -> (String, RectSnapshot)? in
            guard let process = candidates?.first(where: { $0.bundleIdentifier == target.bundleIdentifier })?.process,
                  let observation = self.baseline.observationsByPID[process.pid],
                  observation.itemFrames.count == 1 else { return nil }
            return (target.bundleIdentifier, observation.itemFrames[0])
        }
        baseline = (try? Self.leftToRightBundleIdentifiers(baselineFrames)) ?? []
        let expected = phase == .applied ? desired : baseline
        guard expected.count == desired.count else { return .unavailable }
        return observed == expected ? .verified : .mismatch
    }

    private static func deriveTargets(snapshot: OrderingSnapshot,
                                      bundleIdentifiers: [String]) throws -> [OrderingTarget] {
        let candidates = try OrderingIdentityResolver.resolve(snapshot: snapshot)
        var selected: [OrderingBundleCandidate] = []
        for bundle in bundleIdentifiers.sorted() {
            guard let candidate = candidates.first(where: { $0.bundleIdentifier == bundle }) else {
                throw OrderingError.ineligibleBundle(bundle, [.missingConfiguredKey])
            }
            guard candidate.eligible else { throw OrderingError.ineligibleBundle(bundle, candidate.reasons) }
            selected.append(candidate)
        }
        guard let firstPosition = selected[0].configuredValue?.positivePosition,
              let secondPosition = selected[1].configuredValue?.positivePosition,
              firstPosition != secondPosition,
              let firstFrame = selected[0].frame, let secondFrame = selected[1].frame else {
            throw OrderingError.indistinguishablePositions
        }
        _ = try relativeOrder(firstFrame, secondFrame)
        return [
            OrderingTarget(bundleIdentifier: selected[0].bundleIdentifier,
                           displayName: selected[0].displayName, key: selected[0].key!,
                           before: selected[0].configuredValue!, after: selected[1].configuredValue!,
                           process: selected[0].process!, frame: firstFrame),
            OrderingTarget(bundleIdentifier: selected[1].bundleIdentifier,
                           displayName: selected[1].displayName, key: selected[1].key!,
                           before: selected[1].configuredValue!, after: selected[0].configuredValue!,
                           process: selected[1].process!, frame: secondFrame)
        ]
    }

    private static func deriveReorderingTargets(
        snapshot: OrderingSnapshot,
        orderedBundleIdentifiers: [String]
    ) throws -> [OrderingTarget] {
        guard (2...maximumReorderingTargets).contains(orderedBundleIdentifiers.count),
              Set(orderedBundleIdentifiers).count == orderedBundleIdentifiers.count else {
            throw OrderingError.invalidSelection
        }
        let candidates = try OrderingIdentityResolver.resolve(snapshot: snapshot)
        var selected: [OrderingBundleCandidate] = []
        for bundle in orderedBundleIdentifiers {
            guard let candidate = candidates.first(where: { $0.bundleIdentifier == bundle }) else {
                throw OrderingError.ineligibleBundle(bundle, [.missingConfiguredKey])
            }
            guard candidate.eligible else { throw OrderingError.ineligibleBundle(bundle, candidate.reasons) }
            selected.append(candidate)
        }

        let configuredValues = selected.compactMap(\.configuredValue)
        let configuredPositions = configuredValues.compactMap(\.positivePosition)
        guard selected.allSatisfy({ $0.configuredValue?.positivePosition != nil && $0.frame != nil }),
              configuredValues.count == selected.count,
              configuredPositions.count == selected.count,
              Set(configuredPositions).count == selected.count else {
            throw OrderingError.indistinguishablePositions
        }
        let currentOrder = try leftToRightBundleIdentifiers(selected.map {
            ($0.bundleIdentifier, $0.frame!)
        })
        let selectedByBundle = Dictionary(uniqueKeysWithValues: selected.map {
            ($0.bundleIdentifier, $0)
        })
        let currentSlots = currentOrder.compactMap { selectedByBundle[$0] }
        guard currentSlots.count == selected.count else { throw OrderingError.invalidGeometry }
        let slotValues = currentSlots.map { $0.configuredValue! }

        return selected.enumerated().map { index, candidate in
            OrderingTarget(bundleIdentifier: candidate.bundleIdentifier,
                           displayName: candidate.displayName, key: candidate.key!,
                           before: candidate.configuredValue!, after: slotValues[index],
                           process: candidate.process!, frame: candidate.frame!)
        }
    }

    private static func deriveConfigurationTargets(
        snapshot: OrderingSnapshot,
        orderedBundleIdentifiers: [String]
    ) throws -> [OrderingConfigurationOwnerTarget] {
        guard (1...maximumReorderingTargets).contains(orderedBundleIdentifiers.count),
              Set(orderedBundleIdentifiers).count == orderedBundleIdentifiers.count else {
            throw OrderingError.invalidSelection
        }
        let candidates = try OrderingConfigurationIdentityResolver.resolve(snapshot: snapshot)
        var selected: [OrderingConfigurationBundleCandidate] = []
        for bundle in orderedBundleIdentifiers {
            guard let candidate = candidates.first(where: { $0.bundleIdentifier == bundle }) else {
                throw OrderingError.ineligibleBundle(bundle, [.missingConfiguredKey])
            }
            guard candidate.eligible else {
                throw OrderingError.ineligibleBundle(bundle, candidate.reasons)
            }
            selected.append(candidate)
        }
        let keyCount = selected.reduce(0) { $0 + $1.keys.count }
        guard keyCount >= 1, keyCount <= maximumConfigurationKeys else {
            throw OrderingError.invalidSelection
        }
        let slots = selected.flatMap(\.keys).sorted {
            let lhs = $0.value.positivePosition!
            let rhs = $1.value.positivePosition!
            if lhs != rhs { return lhs > rhs }
            return $0.key < $1.key
        }.map(\.value)
        var slotIndex = 0
        return selected.map { candidate in
            let targets = candidate.keys.map { key in
                defer { slotIndex += 1 }
                return OrderingConfigurationKeyTarget(
                    key: key.key, persistentIdentifier: key.persistentIdentifier,
                    before: key.value, after: slots[slotIndex]
                )
            }
            return OrderingConfigurationOwnerTarget(
                bundleIdentifier: candidate.bundleIdentifier,
                displayName: candidate.displayName,
                process: candidate.process!, keys: targets,
                ownerSavedPositions: candidate.ownerSavedPositions,
                ownerPreferenceNamespace: candidate.exactBundleCodeIdentity == nil
                    ? snapshot.observationsByPID[candidate.process!.pid]!.ownerPreferenceNamespace : .unknown,
                ownerPreferenceSourceIdentity: candidate.exactBundleCodeIdentity == nil
                    ? snapshot.observationsByPID[candidate.process!.pid]!.ownerPreferenceSourceIdentity : nil,
                exactBundleCodeIdentity: candidate.exactBundleCodeIdentity
            )
        }
    }

    private static func deriveConfigurationSubjectTargets(
        snapshot: OrderingSnapshot,
        orderedSubjects: [OrderingSubjectID]
    ) throws -> [OrderingConfigurationSubjectTarget] {
        guard (0...maximumReorderingTargets).contains(orderedSubjects.count),
              Set(orderedSubjects).count == orderedSubjects.count else {
            throw OrderingError.invalidSelection
        }
        if orderedSubjects.isEmpty { return [] }
        let applications = try OrderingConfigurationIdentityResolver.resolve(snapshot: snapshot)
        let systems = try OrderingSystemConfigurationIdentityResolver.resolve(snapshot: snapshot)

        enum Selected {
            case application(OrderingConfigurationBundleCandidate)
            case system(OrderingConfigurationSystemCandidate)

            var values: [OrderingValue] {
                switch self {
                case let .application(candidate): candidate.keys.map(\.value)
                case let .system(candidate): candidate.value.map { [$0] } ?? []
                }
            }
        }

        var selected: [Selected] = []
        for subject in orderedSubjects {
            switch subject {
            case let .application(bundleIdentifier):
                guard let candidate = applications.first(where: {
                    $0.bundleIdentifier == bundleIdentifier
                }) else {
                    throw OrderingError.ineligibleBundle(
                        bundleIdentifier, [.missingConfiguredKey]
                    )
                }
                guard candidate.eligible else {
                    throw OrderingError.ineligibleBundle(bundleIdentifier, candidate.reasons)
                }
                selected.append(.application(candidate))
            case let .systemItem(item):
                guard let candidate = systems.first(where: { $0.item == item }) else {
                    throw OrderingError.ineligibleBundle(
                        item.displayName, [.missingConfiguredKey]
                    )
                }
                guard candidate.eligible else {
                    throw OrderingError.ineligibleBundle(item.displayName, candidate.reasons)
                }
                selected.append(.system(candidate))
            }
        }

        let keyCount = selected.reduce(0) { $0 + $1.values.count }
        guard keyCount >= 1, keyCount <= maximumConfigurationKeys else {
            throw OrderingError.invalidSelection
        }
        let slots = selected.flatMap(\.values).sorted {
            let lhs = $0.positivePosition!
            let rhs = $1.positivePosition!
            if lhs != rhs { return lhs > rhs }
            let leftFingerprint = (try? $0.canonicalFingerprint) ?? ""
            let rightFingerprint = (try? $1.canonicalFingerprint) ?? ""
            return leftFingerprint < rightFingerprint
        }
        var slotIndex = 0
        return selected.map { selected in
            switch selected {
            case let .application(candidate):
                let keys = candidate.keys.map { source in
                    defer { slotIndex += 1 }
                    return OrderingConfigurationKeyTarget(
                        key: source.key, persistentIdentifier: source.persistentIdentifier,
                        before: source.value, after: slots[slotIndex]
                    )
                }
                let process = candidate.process!
                let observation = snapshot.observationsByPID[process.pid]!
                return .application(OrderingConfigurationOwnerTarget(
                    bundleIdentifier: candidate.bundleIdentifier,
                    displayName: candidate.displayName, process: process, keys: keys,
                    ownerSavedPositions: candidate.ownerSavedPositions,
                    ownerPreferenceNamespace: candidate.exactBundleCodeIdentity == nil
                        ? observation.ownerPreferenceNamespace : .unknown,
                    ownerPreferenceSourceIdentity: candidate.exactBundleCodeIdentity == nil
                        ? observation.ownerPreferenceSourceIdentity : nil,
                    exactBundleCodeIdentity: candidate.exactBundleCodeIdentity
                ))
            case let .system(candidate):
                let value = candidate.value!
                let key = OrderingConfigurationKeyTarget(
                    key: candidate.key, persistentIdentifier: candidate.item.rawValue,
                    before: value, after: slots[slotIndex]
                )
                slotIndex += 1
                return .systemItem(OrderingConfigurationSystemTarget(
                    item: candidate.item, displayName: candidate.displayName,
                    hostBinding: candidate.hostBinding!, key: key
                ))
            }
        }
    }

    private static func leftToRightBundleIdentifiers(
        _ values: [(bundleIdentifier: String, frame: RectSnapshot)]
    ) throws -> [String] {
        guard let first = values.first else { return [] }
        let commonMinimumY = values.reduce(first.frame.y) { max($0, $1.frame.y) }
        let commonMaximumY = values.reduce(first.frame.y + first.frame.height) {
            min($0, $1.frame.y + $1.frame.height)
        }
        guard commonMinimumY < commonMaximumY else { throw OrderingError.invalidGeometry }
        for firstIndex in values.indices {
            for secondIndex in values.index(after: firstIndex)..<values.endIndex {
                _ = try relativeOrder(values[firstIndex].frame, values[secondIndex].frame)
            }
        }
        let sorted = values.sorted { $0.frame.x < $1.frame.x }
        return sorted.map(\.bundleIdentifier)
    }

    private static func visible(_ frame: RectSnapshot, in display: RectSnapshot) -> Bool {
        guard OrderingSnapshot.valid(frame), OrderingSnapshot.valid(display),
              frame.width > 0, frame.height > 0, display.width > 0, display.height > 0 else {
            return false
        }
        return frame.x >= display.x && frame.y >= display.y
            && frame.x + frame.width <= display.x + display.width
            && frame.y + frame.height <= display.y + display.height
    }

    private static func relativeOrder(_ first: RectSnapshot,
                                      _ second: RectSnapshot) throws -> OrderingRelativeOrder {
        guard OrderingSnapshot.valid(first), OrderingSnapshot.valid(second),
              first.width > 0, first.height > 0, second.width > 0, second.height > 0 else {
            throw OrderingError.invalidGeometry
        }
        guard max(first.y, second.y) < min(first.y + first.height, second.y + second.height) else {
            throw OrderingError.invalidGeometry
        }
        let firstMaxX = first.x + first.width
        let secondMaxX = second.x + second.width
        if first.x < second.x, firstMaxX < secondMaxX { return .firstBeforeSecond }
        if second.x < first.x, secondMaxX < firstMaxX { return .secondBeforeFirst }
        throw OrderingError.invalidGeometry
    }

    private static func validateAge(_ capturedAt: Date, now: Date) throws {
        let age = now.timeIntervalSince(capturedAt)
        guard age >= 0, age <= maximumSnapshotAge else {
            throw OrderingError.staleSnapshot("capture is older than the bounded review window")
        }
    }

    private func computedFingerprint() throws -> String {
        if schemaVersion == 4 {
            struct SubjectConfigurationBinding: Codable {
                let schemaVersion: Int
                let id: UUID
                let createdAt: Date
                let baselineFingerprint: String
                let configurationSubjectTargets: [OrderingConfigurationSubjectTarget]
            }
            return try OrderingDigest.hash(SubjectConfigurationBinding(
                schemaVersion: schemaVersion, id: id, createdAt: createdAt,
                baselineFingerprint: try baseline.canonicalFingerprint,
                configurationSubjectTargets: configurationSubjectTargets ?? []
            ))
        }
        if schemaVersion == 3 {
            struct ConfigurationBinding: Codable {
                let schemaVersion: Int
                let id: UUID
                let createdAt: Date
                let baselineFingerprint: String
                let configurationTargets: [OrderingConfigurationOwnerTarget]
            }
            return try OrderingDigest.hash(ConfigurationBinding(
                schemaVersion: schemaVersion, id: id, createdAt: createdAt,
                baselineFingerprint: try baseline.canonicalFingerprint,
                configurationTargets: configurationTargets ?? []
            ))
        }
        struct Binding: Codable {
            let schemaVersion: Int
            let id: UUID
            let createdAt: Date
            let baselineFingerprint: String
            let targets: [OrderingTarget]
        }
        return try OrderingDigest.hash(Binding(schemaVersion: schemaVersion, id: id,
            createdAt: createdAt, baselineFingerprint: try baseline.canonicalFingerprint,
            targets: targets))
    }

    private func table(in group: [String: OrderingValue]) throws -> [String: OrderingValue] {
        guard case let .dictionary(table)? = group[OrderingSnapshot.tableKey] else {
            throw OrderingError.invalidSnapshot("the complete preferred-position table is missing")
        }
        return table
    }

    private static func sorted(_ values: [OrderingProcess]) -> [OrderingProcess] {
        OrderingSnapshot.sortedProcesses(values)
    }

    private static func observationDifference(
        _ lhs: [Int32: OrderingOwnerObservation],
        _ rhs: [Int32: OrderingOwnerObservation],
        selectedPIDs: Set<Int32>,
        includeGeometryEvidence: Bool,
        exactCodeIdentitiesByPID: [Int32: OrderingApplicationCodeIdentity] = [:]
    ) -> String? {
        let allPIDs = Set(lhs.keys).union(rhs.keys)
        if let pid = allPIDs.sorted().first(where: { (lhs[$0] == nil) != (rhs[$0] == nil) }) {
            let owner = observationOwnerDescription(
                pid: pid, lhs: lhs, rhs: rhs, selectedPIDs: selectedPIDs
            )
            return "observation inventory changed for \(owner)"
        }
        for pid in allPIDs.sorted() {
            guard let first = lhs[pid], let second = rhs[pid] else { continue }
            let owner = observationOwnerDescription(
                pid: pid, lhs: lhs, rhs: rhs, selectedPIDs: selectedPIDs
            )
            if first.process != second.process { return "owner process metadata changed for \(owner)" }
            if includeGeometryEvidence, first.displayName != second.displayName {
                return "owner name changed for \(owner)"
            }
            if includeGeometryEvidence, first.axComplete != second.axComplete {
                return "Accessibility completeness changed for \(owner)"
            }
            if let expectedIdentity = exactCodeIdentitiesByPID[pid] {
                if first.applicationCodeIdentity != expectedIdentity
                    || second.applicationCodeIdentity != expectedIdentity {
                    return "application code identity changed for \(owner)"
                }
                continue
            }
            if first.ownerPreferencesComplete != second.ownerPreferencesComplete {
                return "owner preference completeness changed for \(owner)"
            }
            if first.ownerPreferenceNamespace != second.ownerPreferenceNamespace {
                return "owner preference namespace changed for \(owner)"
            }
            if first.ownerPreferenceSourceIdentity != second.ownerPreferenceSourceIdentity {
                return "owner preference source identity changed for \(owner)"
            }
            if first.ownerSavedPositions != second.ownerSavedPositions {
                return "owner saved-position set changed for \(owner)"
            }
            if includeGeometryEvidence, first.itemFrames.count != second.itemFrames.count {
                return "Accessibility item cardinality changed for \(owner)"
            }
        }
        return nil
    }

    private static func observationOwnerDescription(
        pid: Int32,
        lhs: [Int32: OrderingOwnerObservation],
        rhs: [Int32: OrderingOwnerObservation],
        selectedPIDs: Set<Int32>
    ) -> String {
        let bundle = lhs[pid]?.process.bundleIdentifier
            ?? rhs[pid]?.process.bundleIdentifier
            ?? "unknown bundle"
        let scope = selectedPIDs.contains(pid) ? "selected target" : "unrelated owner"
        return "\(scope) \(bundle)"
    }
}

enum OrderingDigest {
    static func hash(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .secondsSince1970
        return SHA256.hash(data: try encoder.encode(value)).map { String(format: "%02x", $0) }.joined()
    }
}
#endif
