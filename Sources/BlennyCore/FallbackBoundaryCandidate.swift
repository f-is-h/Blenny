#if BLENNY_PRODUCT || DEBUG
import Foundation

/// A configured scalar gap for an attended trial, not a physical-layout promise.
public struct FallbackBoundaryCandidate: Sendable {
    public let delta: FallbackPositionDelta
    public let revealableKey: String
    public let visibleKey: String

    public enum Failure: Error, LocalizedError {
        case noRevealableItems
        case noBoundary
        case unattributedItems
        public var errorDescription: String? {
            switch self {
            case .noRevealableItems: "No running Revealable items need an arrow boundary."
            case .noBoundary: "Revealable and Visible items do not have a clear saved boundary. Arrange the groups in Organize, choose Apply, then try again."
            case .unattributedItems: "A menu bar item without verified application ownership is present. Blenny cannot establish a complete control boundary for this layout."
            }
        }
    }

    public static func make(snapshot: OrderingSnapshot,
                            policy: PersistentBundlePolicyDocument,
                            includeFish: Bool = false) throws -> Self {
        let table = try snapshot.table()
        guard !snapshot.afterProcesses.contains(where: { process in
            process.bundleIdentifier == nil
                && snapshot.observationsByPID[process.pid]?.itemFrames.isEmpty == false
        }) else { throw Failure.unattributedItems }
        var classified: [String: MenuBarBundlePolicy] = [:]
        let policies = Dictionary(uniqueKeysWithValues: policy.policies.map {
            ($0.bundleIdentifier.lowercased(), $0.policy)
        })
        for process in snapshot.afterProcesses {
            guard let bundle = process.bundleIdentifier, bundle != "xyz.fi5h.blenny",
                  !process.isSystem || bundle == "com.apple.weather.menu"
                    || bundle == "com.apple.TextInputMenuAgent",
                  let observation = snapshot.observationsByPID[process.pid],
                  !observation.itemFrames.isEmpty else { continue }
            guard observation.axComplete else { throw OrderingTransactionError.contextInvalidated }
            let prefix = "status:\(bundle)::"
            let keys = table.keys.filter { $0.hasPrefix(prefix) }
            guard !keys.isEmpty else { throw OrderingTransactionError.recoveryIdentityConflict }
            for key in keys { classified[key] = policies[bundle.lowercased()] ?? .visible }
        }
        // Visibility-only system controls have no validated sortable position.
        // Their stored values cannot constrain the configurable ordering gap.
        for item in ExactSystemOrderingItem.allCases where item.isOrderingOffered
            && table[item.configurationKey] != nil {
            classified[item.configurationKey] = item == .bluetooth ? policy.bluetoothPolicy
                : policy.systemItemPolicies[item.observationIdentifier] ?? .visible
        }
        let revealable = try classified.filter { $0.value == .revealable }.map {
            ($0.key, try position(table[$0.key]))
        }
        let visible = try classified.filter { $0.value == .visible }.map {
            ($0.key, try position(table[$0.key]))
        }
        guard let left = revealable.min(by: { $0.1 < $1.1 }) else {
            throw Failure.noRevealableItems
        }
        guard let right = visible.max(by: { $0.1 < $1.1 }), right.1 < left.1,
              let original = table[FallbackPositionDelta.key] else {
            throw Failure.noBoundary
        }
        let proposed = right.1 + (left.1 - right.1) / 2
        let current = try position(original)
        if includeFish {
            guard let fishOriginal = table[FallbackPositionDelta.fishKey] else {
                throw OrderingTransactionError.recoveryIdentityConflict
            }
            let fish = try position(fishOriginal)
            let arrow = current > right.1 && current < left.1 ? current
                : right.1 + (left.1 - right.1) * 2 / 3
            if current == arrow && fish > right.1 && fish < arrow {
                throw FallbackPositionDelta.Failure.unchangedPosition
            }
            let fishTarget = right.1 + (arrow - right.1) / 2
            guard right.1 < fishTarget, fishTarget < arrow, arrow < left.1 else {
                throw Failure.noBoundary
            }
            return try Self(delta: FallbackPositionDelta(original: original,
                proposed: current == arrow ? original : .real(arrow),
                fishOriginal: fishOriginal, fishProposed: .real(fishTarget)),
                revealableKey: left.0, visibleKey: right.0)
        }
        if current > right.1 && current < left.1 {
            throw FallbackPositionDelta.Failure.unchangedPosition
        }
        guard proposed > right.1 && proposed < left.1 else {
            throw OrderingTransactionError.movementNotVerified
        }
        return try Self(delta: FallbackPositionDelta(original: original, proposed: .real(proposed)),
                        revealableKey: left.0, visibleKey: right.0)
    }

    private static func position(_ value: OrderingValue?) throws -> Double {
        let number: Double
        switch value {
        case let .integer(value): number = Double(value)
        case let .real(value): number = value
        default: throw OrderingTransactionError.invalidReceipt
        }
        guard number.isFinite, number > 0, number <= 1_000_000 else {
            throw OrderingTransactionError.invalidReceipt
        }
        return number
    }
}
#endif
