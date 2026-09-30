public enum SharedSystemItemTrialTarget: String, CaseIterable, Codable, Sendable {
    case nowPlaying
    case siri
    case timeMachine
    case spotlight

    public var displayName: String {
        switch self {
        case .nowPlaying: "Now Playing"
        case .siri: "Siri"
        case .timeMachine: "Time Machine"
        case .spotlight: "Spotlight"
        }
    }

    public var observationIdentifier: String {
        switch self {
        case .nowPlaying: "com.apple.menuextra.now-playing"
        case .siri: "com.apple.menuextra.siri"
        case .timeMachine: "com.apple.menuextra.TimeMachine"
        case .spotlight: "com.apple.menuextra.spotlight"
        }
    }

    public var ownerBundleIdentifier: String {
        switch self {
        case .nowPlaying: "com.apple.controlcenter"
        case .siri, .timeMachine: "com.apple.systemuiserver"
        case .spotlight: "com.apple.campo"
        }
    }

    public static func matchingSystemItem(
        observationIdentifier: String
    ) -> SharedSystemItemTrialTarget? {
        let normalized = MenuBarItemIdentityResolver.normalize(
            observationIdentifier
        ) ?? ""
        if normalized == "com.apple.menuextra.now-playing"
            || normalized.contains(":now playing|") {
            return .nowPlaying
        }
        if normalized == "com.apple.menuextra.siri"
            || normalized.contains(":siri|") {
            return .siri
        }
        if normalized == "com.apple.menuextra.timemachine"
            || normalized.contains(":time machine|") {
            return .timeMachine
        }
        if PersistentSystemItemPolicyCatalog.controllableItem(
            forObservationIdentifier: observationIdentifier
        )?.identifier == "com.apple.menuextra.spotlight" {
            return .spotlight
        }
        return nil
    }
}

#if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
import CryptoKit
import Foundation

public enum SharedSystemItemTrialError: Error, Equatable, Sendable {
    case unsupportedRuntime
    case unsupportedValue
    case unsafeBaseline
    case staleState
    case verificationFailed
    case restorationFailed
    case malformedReceipt
}

public struct ExactPreferenceValue: Codable, Equatable, Sendable {
    public let encodedValue: Data?

    public init(_ value: Any?) throws {
        encodedValue = try value.map {
            try PropertyListSerialization.data(
                fromPropertyList: ["value": $0], format: .binary, options: 0
            )
        }
        _ = try decodedValue()
    }

    public func optionalBoolean() throws -> Bool? {
        guard let value = try decodedValue() else { return nil }
        guard let number = value as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else {
            throw SharedSystemItemTrialError.unsupportedValue
        }
        return number.boolValue
    }

    public func optionalInteger() throws -> Int64? {
        guard let value = try decodedValue() else { return nil }
        guard let number = value as? NSNumber,
              CFGetTypeID(number) == CFNumberGetTypeID(),
              number.doubleValue.isFinite,
              number.doubleValue.rounded(.towardZero) == number.doubleValue else {
            throw SharedSystemItemTrialError.unsupportedValue
        }
        return number.int64Value
    }

    public func unsignedFlags() throws -> UInt64 {
        guard let value = try decodedValue() else { return 0 }
        guard let number = value as? NSNumber,
              CFGetTypeID(number) == CFNumberGetTypeID(),
              ["c", "s", "i", "l", "q", "C", "S", "I", "L", "Q"]
                .contains(String(cString: number.objCType)),
              let flags = UInt64(number.stringValue) else {
            throw SharedSystemItemTrialError.unsupportedValue
        }
        return flags
    }

    public func stringArray() throws -> [String] {
        guard let value = try decodedValue() else { return [] }
        guard let values = value as? [String], values.count <= 256,
              Set(values).count == values.count,
              values.allSatisfy({ !$0.isEmpty && $0.count <= 1_024 }) else {
            throw SharedSystemItemTrialError.unsupportedValue
        }
        return values
    }

    public func propertyListValue() throws -> Any? {
        try decodedValue()
    }

    private func decodedValue() throws -> Any? {
        guard let encodedValue else { return nil }
        guard encodedValue.count <= 1_048_576,
              let decoded = try PropertyListSerialization.propertyList(
                from: encodedValue, format: nil
              ) as? [String: Any], decoded.count == 1 else {
            throw SharedSystemItemTrialError.unsupportedValue
        }
        return decoded["value"]
    }
}

public struct SharedSystemItemPreferenceSnapshot: Codable, Equatable, Sendable {
    public static let timeMachineMenuExtraPath =
        "/System/Library/CoreServices/Menu Extras/TimeMachine.menu"
    public static let siriKeys = [
        "SiriPrefStashedStatusMenuVisible", "StatusMenuVisible"
    ]
    public static let timeMachineKeys = [
        "NSStatusItem Preferred Position com.apple.menuextra.TimeMachine",
        "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine",
        "menuExtras",
    ]
    public static let nowPlayingKeys = ["NowPlaying"]
    public static let spotlightKeys = ["NSStatusItem VisibleCC Item-0"]

    public let target: SharedSystemItemTrialTarget
    public let values: [String: ExactPreferenceValue]
    public let effectiveVisible: Bool

    public init(
        target: SharedSystemItemTrialTarget,
        values: [String: ExactPreferenceValue],
        effectiveVisible: Bool
    ) throws {
        self.target = target
        self.values = values
        self.effectiveVisible = effectiveVisible
        try validate()
    }

    public func validate() throws {
        let expectedKeys: [String]
        switch target {
        case .nowPlaying: expectedKeys = Self.nowPlayingKeys
        case .siri: expectedKeys = Self.siriKeys
        case .timeMachine: expectedKeys = Self.timeMachineKeys
        case .spotlight: expectedKeys = Self.spotlightKeys
        }
        guard values.keys.sorted() == expectedKeys,
              values.values.allSatisfy({ $0.encodedValue?.count ?? 0 <= 1_048_576 }) else {
            throw SharedSystemItemTrialError.unsupportedValue
        }
        switch target {
        case .nowPlaying:
            let flags = try values["NowPlaying"]?.unsignedFlags() ?? 0
            guard [UInt64(0), 0x2, 0x8].contains(flags & 0xA),
                  effectiveVisible == ((flags & 0xA) != 0x8) else {
                throw SharedSystemItemTrialError.unsupportedValue
            }
        case .siri:
            _ = try values["StatusMenuVisible"]?.optionalBoolean()
            _ = try values["SiriPrefStashedStatusMenuVisible"]?.optionalBoolean()
        case .timeMachine:
            let entries = try values["menuExtras"]?.stringArray() ?? []
            guard entries.filter({ $0 == Self.timeMachineMenuExtraPath }).count <= 1 else {
                throw SharedSystemItemTrialError.unsupportedValue
            }
            _ = try values[
                "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine"
            ]?.optionalBoolean()
            _ = try values[
                "NSStatusItem Preferred Position com.apple.menuextra.TimeMachine"
            ]?.optionalInteger()
        case .spotlight:
            // The private getter is the live visibility authority. Campo may
            // retain its NSStatusItem preference while that getter reports
            // hidden, so preserve the value without treating it as a mirror.
            _ = try values["NSStatusItem VisibleCC Item-0"]?.optionalBoolean()
        }
    }

    public func acceptsAppliedHide(
        _ applied: SharedSystemItemPreferenceSnapshot
    ) throws -> Bool {
        try validate()
        try applied.validate()
        guard target == applied.target, effectiveVisible, !applied.effectiveVisible else {
            return false
        }
        switch target {
        case .nowPlaying:
            return applied == (try hidingProposal())
        case .siri:
            return applied == (try hidingProposal())
        case .spotlight:
            let key = "NSStatusItem VisibleCC Item-0"
            let value = try applied.values[key]?.optionalBoolean()
            let baselineValue = try values[key]?.optionalBoolean()
            // Accept only target-local normalization: explicit false, removal,
            // or an unchanged preference with the getter reporting hidden.
            return value == false || value == nil || value == baselineValue
        case .timeMachine:
            let baselineEntries = try values["menuExtras"]?.stringArray() ?? []
            let appliedEntries = try applied.values["menuExtras"]?.stringArray() ?? []
            guard baselineEntries.filter({
                $0 == Self.timeMachineMenuExtraPath
            }).count == 1 else {
                return false
            }
            let removedEntries = baselineEntries.filter {
                $0 != Self.timeMachineMenuExtraPath
            }
            // The current setter may retain legacy membership while its paired
            // getter reports the live item hidden. It may also normalize by
            // removing only the target path. Both forms preserve every
            // unrelated entry and its exact order.
            return appliedEntries == baselineEntries || appliedEntries == removedEntries
        }
    }

    public func hidingProposal() throws -> Self {
        try validate()
        guard effectiveVisible else { throw SharedSystemItemTrialError.unsafeBaseline }
        var proposed = values
        switch target {
        case .nowPlaying:
            let flags = try values["NowPlaying"]?.unsignedFlags() ?? 0
            proposed["NowPlaying"] = try ExactPreferenceValue(
                NSNumber(value: (flags & ~UInt64(0xA)) | UInt64(0x8))
            )
        case .siri:
            proposed["StatusMenuVisible"] = try ExactPreferenceValue(false)
            proposed["SiriPrefStashedStatusMenuVisible"] = try ExactPreferenceValue(nil)
        case .spotlight:
            proposed["NSStatusItem VisibleCC Item-0"] = try ExactPreferenceValue(false)
        case .timeMachine:
            let entries = try values["menuExtras"]?.stringArray() ?? []
            guard entries.filter({ $0 == Self.timeMachineMenuExtraPath }).count == 1 else {
                throw SharedSystemItemTrialError.unsafeBaseline
            }
            proposed["menuExtras"] = try ExactPreferenceValue(
                entries.filter { $0 != Self.timeMachineMenuExtraPath }
            )
        }
        return try Self(target: target, values: proposed, effectiveVisible: false)
    }

    /// An ordinary Now Playing reveal must keep an explicit visible override.
    /// Restoring an absent/default baseline here does not request native display.
    public func nowPlayingRevealingProposal() throws -> Self {
        try validate()
        guard target == .nowPlaying, !effectiveVisible else {
            throw SharedSystemItemTrialError.unsafeBaseline
        }
        let flags = try values["NowPlaying"]?.unsignedFlags() ?? 0
        return try Self(target: .nowPlaying, values: [
            "NowPlaying": ExactPreferenceValue(NSNumber(value: (flags & ~UInt64(0xA)) | 0x2))
        ], effectiveVisible: true)
    }

    /// The inspected Siri setter removes the stash key before changing the
    /// visible flag. This exact target-local result is narrow enough to record
    /// before an ordinary reveal setter runs. No equivalent Time Machine
    /// result has been established.
    public func siriRevealingProposal() throws -> Self {
        try validate()
        guard target == .siri, !effectiveVisible,
              try values["StatusMenuVisible"]?.optionalBoolean() == false,
              try values["SiriPrefStashedStatusMenuVisible"]?.optionalBoolean() == nil else {
            throw SharedSystemItemTrialError.unsafeBaseline
        }
        var proposed = values
        proposed["StatusMenuVisible"] = try ExactPreferenceValue(true)
        proposed["SiriPrefStashedStatusMenuVisible"] = try ExactPreferenceValue(nil)
        return try Self(target: target, values: proposed, effectiveVisible: true)
    }
}

public struct SharedSystemItemTrialReceipt: Codable, Equatable, Sendable {
    public private(set) var schemaVersion: Int
    public let runtime: RuntimeEnvironment
    public let baseline: SharedSystemItemPreferenceSnapshot
    public let proposed: SharedSystemItemPreferenceSnapshot
    public var applied: SharedSystemItemPreferenceSnapshot?
    public private(set) var revealIntent: SharedSystemItemPreferenceSnapshot?

    public init(
        runtime: RuntimeEnvironment,
        baseline: SharedSystemItemPreferenceSnapshot
    ) throws {
        schemaVersion = 1
        self.runtime = runtime
        self.baseline = baseline
        proposed = try baseline.hidingProposal()
        applied = nil
        revealIntent = nil
        try validate()
    }

    public mutating func recordApplied(
        _ snapshot: SharedSystemItemPreferenceSnapshot
    ) throws {
        guard try baseline.acceptsAppliedHide(snapshot) else {
            throw SharedSystemItemTrialError.verificationFailed
        }
        applied = snapshot
        revealIntent = nil
    }

    /// Persist the complete Siri result authorized for an ordinary reveal
    /// before invoking its setter. A crash on either side of the setter can
    /// then distinguish Blenny's exact visible state from external drift.
    public mutating func recordSiriRevealIntent(
        from current: SharedSystemItemPreferenceSnapshot
    ) throws {
        try validate()
        guard baseline.target == .siri,
              try baseline.acceptsAppliedHide(current) else {
            throw SharedSystemItemTrialError.staleState
        }
        schemaVersion = 2
        revealIntent = try current.siriRevealingProposal()
        try validate()
    }

    /// Schema 3 binds the temporary visible flags before their write. Older
    /// readers reject this schema instead of guessing ownership during recovery.
    public mutating func recordNowPlayingRevealIntent(
        from current: SharedSystemItemPreferenceSnapshot
    ) throws {
        try validate()
        guard baseline.target == .nowPlaying,
              try baseline.acceptsAppliedHide(current) else {
            throw SharedSystemItemTrialError.staleState
        }
        schemaVersion = 3
        revealIntent = try current.nowPlayingRevealingProposal()
        try validate()
    }

    public func validate() throws {
        try baseline.validate()
        try proposed.validate()
        let appliedIsValid: Bool
        if let applied {
            appliedIsValid = try baseline.acceptsAppliedHide(applied)
        } else {
            appliedIsValid = true
        }
        let revealIntentIsValid: Bool
        if let revealIntent, baseline.target == .siri {
            let expected = try proposed.siriRevealingProposal()
            revealIntentIsValid = revealIntent == expected
        } else if let revealIntent, baseline.target == .nowPlaying, schemaVersion == 3 {
            revealIntentIsValid = revealIntent == (try proposed.nowPlayingRevealingProposal())
        } else {
            revealIntentIsValid = revealIntent == nil
        }
        guard [1, 2, 3].contains(schemaVersion),
              (schemaVersion >= 2 || revealIntent == nil),
              (schemaVersion != 3 || baseline.target == .nowPlaying),
              runtime == .current(),
              baseline.target == proposed.target,
              baseline.effectiveVisible,
              proposed == (try baseline.hidingProposal()),
              appliedIsValid,
              revealIntentIsValid else {
            throw SharedSystemItemTrialError.malformedReceipt
        }
    }

    public func acceptsRestoreCurrent(
        _ current: SharedSystemItemPreferenceSnapshot
    ) throws -> Bool {
        try validate()
        if current == baseline { return true }
        if try acceptsOwnedHiddenCurrent(current) { return true }
        return try acceptsOwnedRevealedCurrent(current)
    }

    /// SystemUIServer may normalize target-owned keys again after the setter
    /// returned. The receipt still owns that state when the complete snapshot
    /// satisfies the target's bounded hide contract. For Time Machine this
    /// requires every unrelated menu-extra entry and its order to remain exact;
    /// Siri and Now Playing continue to require their single exact proposal.
    public func acceptsOwnedHiddenCurrent(
        _ current: SharedSystemItemPreferenceSnapshot
    ) throws -> Bool {
        try validate()
        return try baseline.acceptsAppliedHide(current)
    }

    public func acceptsOwnedRevealedCurrent(
        _ current: SharedSystemItemPreferenceSnapshot
    ) throws -> Bool {
        try validate()
        try current.validate()
        guard current.target == baseline.target, current.effectiveVisible else {
            return false
        }
        return current == baseline || current == revealIntent
    }

    public var fingerprint: String {
        get throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            return SHA256.hash(data: try encoder.encode(self))
                .map { String(format: "%02x", $0) }.joined()
        }
    }
}

@MainActor
public protocol SharedSystemItemTrialBackend: AnyObject, Sendable {
    func capture(_ target: SharedSystemItemTrialTarget) throws
        -> SharedSystemItemPreferenceSnapshot
    func setVisibility(_ visible: Bool, for target: SharedSystemItemTrialTarget) async throws
    func restoreExact(_ snapshot: SharedSystemItemPreferenceSnapshot) async throws
    func restoreForOrdinaryReveal(_ snapshot: SharedSystemItemPreferenceSnapshot) async throws
}

extension SharedSystemItemTrialBackend {
    public func restoreForOrdinaryReveal(
        _ snapshot: SharedSystemItemPreferenceSnapshot
    ) async throws {
        try await restoreExact(snapshot)
    }
}

/// Explicit owner-trial operations routed through Blenny's sole mutation
/// coordinator. The lower-level preference backend remains private to its writer.
public protocol ManualSystemItemTrialWriting: Sendable {
    func hide(_ target: SharedSystemItemTrialTarget) async throws
        -> SharedSystemItemTrialReceipt
    func restore(_ target: SharedSystemItemTrialTarget) async throws
}

public actor SharedSystemItemManualTrialWriter {
    private struct ManagedCheckpoint {
        let snapshot: SharedSystemItemPreferenceSnapshot
        let receipt: SharedSystemItemTrialReceipt?
    }

    private let backend: any SharedSystemItemTrialBackend
    private let receiptDirectory: URL
    private let operationGate = SharedSystemItemTrialOperationGate()

    public init(
        backend: any SharedSystemItemTrialBackend,
        receiptDirectory: URL
    ) {
        self.backend = backend
        self.receiptDirectory = receiptDirectory
    }

    public func hasRecoveryReceipt(for target: SharedSystemItemTrialTarget) -> Bool {
        FileManager.default.fileExists(atPath: receiptURL(for: target).path)
    }

    public func hide(_ target: SharedSystemItemTrialTarget) async throws
        -> SharedSystemItemTrialReceipt {
        await operationGate.acquire()
        do {
            let receipt = try await hideLocked(target)
            await operationGate.release()
            return receipt
        } catch {
            await operationGate.release()
            throw error
        }
    }

    private func hideLocked(_ target: SharedSystemItemTrialTarget) async throws
        -> SharedSystemItemTrialReceipt {
        guard !hasRecoveryReceipt(for: target) else {
            throw SharedSystemItemTrialError.staleState
        }
        let baseline = try await backend.capture(target)
        var receipt = try SharedSystemItemTrialReceipt(
            runtime: .current(), baseline: baseline
        )
        try writeReceipt(receipt, for: target, withoutOverwriting: true)
        do {
            try await backend.setVisibility(false, for: target)
            let applied = try await backend.capture(target)
            try receipt.recordApplied(applied)
            try writeReceipt(receipt, for: target, withoutOverwriting: false)
            return receipt
        } catch {
            do {
                try await backend.restoreExact(baseline)
                let restored = try await backend.capture(target)
                guard restored == baseline else {
                    throw SharedSystemItemTrialError.restorationFailed
                }
                try removeReceipt(for: target)
            } catch {
                throw SharedSystemItemTrialError.restorationFailed
            }
            throw error
        }
    }

    public func restore(_ target: SharedSystemItemTrialTarget) async throws {
        await operationGate.acquire()
        do {
            try await restoreLocked(target)
            await operationGate.release()
        } catch {
            await operationGate.release()
            throw error
        }
    }

    private func restoreLocked(_ target: SharedSystemItemTrialTarget) async throws {
        let receipt = try readReceipt(for: target)
        let current = try await backend.capture(target)
        guard try receipt.acceptsRestoreCurrent(current) else {
            throw SharedSystemItemTrialError.staleState
        }
        if current != receipt.baseline {
            try await backend.restoreExact(receipt.baseline)
            guard try await backend.capture(target) == receipt.baseline else {
                throw SharedSystemItemTrialError.restorationFailed
            }
        }
        try removeReceipt(for: target)
    }

    public func applyManagedPlan(
        _ plan: [String: PersistentSystemItemPresentation]
    ) async throws {
        await operationGate.acquire()
        do {
            let desired = try managedTargets(in: plan)
            var checkpoints: [SharedSystemItemTrialTarget: ManagedCheckpoint] = [:]
            for target in desired.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
                checkpoints[target] = try await ManagedCheckpoint(
                    snapshot: backend.capture(target),
                    receipt: hasRecoveryReceipt(for: target) ? readReceipt(for: target) : nil
                )
            }
            do {
                for target in desired.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
                    guard let presentation = desired[target] else { continue }
                    try await transitionLocked(target, to: presentation)
                }
            } catch {
                do {
                    try await restore(checkpoints)
                } catch {
                    throw SharedSystemItemTrialError.restorationFailed
                }
                throw error
            }
            await operationGate.release()
        } catch {
            await operationGate.release()
            throw error
        }
    }

    public func verifyManagedPlan(
        _ plan: [String: PersistentSystemItemPresentation]
    ) async throws -> Bool {
        await operationGate.acquire()
        do {
            let desired = try managedTargets(in: plan)
            for target in desired.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard let presentation = desired[target] else { continue }
                let current = try await backend.capture(target)
                let receipt = hasRecoveryReceipt(for: target)
                    ? try readReceipt(for: target) : nil
                switch presentation {
                case .restored:
                    if let receipt {
                        guard current == receipt.baseline else {
                            await operationGate.release()
                            return false
                        }
                    } else if PersistentSystemItemPolicyCatalog.supportsManagement(
                        for: target.observationIdentifier
                    ), !current.effectiveVisible {
                        await operationGate.release()
                        return false
                    }
                case .revealed:
                    guard let receipt,
                          try receipt.acceptsOwnedRevealedCurrent(current) else {
                        await operationGate.release()
                        return false
                    }
                case .hidden:
                    guard let receipt,
                          try receipt.acceptsOwnedHiddenCurrent(current) else {
                        await operationGate.release()
                        return false
                    }
                }
            }
            await operationGate.release()
            return true
        } catch {
            await operationGate.release()
            throw error
        }
    }

    public func finalizeCommittedPlan(
        _ plan: [String: PersistentSystemItemPresentation]
    ) async {
        await operationGate.acquire()
        if let desired = try? managedTargets(in: plan) {
            for (target, presentation) in desired where presentation == .restored {
                guard let receipt = try? readReceipt(for: target),
                      let current = try? await backend.capture(target),
                      current == receipt.baseline else {
                    continue
                }
                try? removeReceipt(for: target)
            }
        }
        await operationGate.release()
    }

    public func restoreAllManagedItems() async -> Bool {
        await operationGate.acquire()
        var restored = true
        for target in SharedSystemItemTrialTarget.allCases where hasRecoveryReceipt(for: target) {
            do {
                try await restoreLocked(target)
            } catch {
                restored = false
            }
        }
        await operationGate.release()
        return restored
    }

    /// Read-only preflight for an explicit recovery process. This uses the same
    /// receipt and ownership predicate as restore, but performs no setter,
    /// preference synchronization, notification or receipt removal.
    public func verifyAllManagedItemsAreRestorable() async -> Bool {
        await operationGate.acquire()
        var verified = true
        for target in SharedSystemItemTrialTarget.allCases where hasRecoveryReceipt(for: target) {
            do {
                let receipt = try readReceipt(for: target)
                let current = try await backend.capture(target)
                guard try receipt.acceptsRestoreCurrent(current) else {
                    verified = false
                    continue
                }
            } catch {
                verified = false
            }
        }
        await operationGate.release()
        return verified
    }

    public func snapshot(_ target: SharedSystemItemTrialTarget) async throws
        -> SharedSystemItemPreferenceSnapshot {
        await operationGate.acquire()
        do {
            let snapshot = try await backend.capture(target)
            await operationGate.release()
            return snapshot
        } catch {
            await operationGate.release()
            throw error
        }
    }

    private func transitionLocked(
        _ target: SharedSystemItemTrialTarget,
        to presentation: PersistentSystemItemPresentation
    ) async throws {
        switch presentation {
        case .restored:
            guard hasRecoveryReceipt(for: target) else {
                return
            }
            let receipt = try readReceipt(for: target)
            let current = try await backend.capture(target)
            guard try receipt.acceptsRestoreCurrent(current) else {
                throw SharedSystemItemTrialError.staleState
            }
            if current != receipt.baseline {
                try await backend.restoreExact(receipt.baseline)
                guard try await backend.capture(target) == receipt.baseline else {
                    throw SharedSystemItemTrialError.restorationFailed
                }
            }
        case .revealed:
            guard hasRecoveryReceipt(for: target) else {
                throw SharedSystemItemTrialError.staleState
            }
            var receipt = try readReceipt(for: target)
            let current = try await backend.capture(target)
            guard try receipt.acceptsRestoreCurrent(current) else {
                throw SharedSystemItemTrialError.staleState
            }
            if try receipt.acceptsOwnedRevealedCurrent(current) { return }
            #if DEBUG && BLENNY_NOW_PLAYING_LEGACY_REVEAL_TRIAL
            if target == .nowPlaying {
                // Reproduce the 0.8.0 ordinary reveal: the backend requests
                // visible, waits for settlement, then restores the exact
                // pre-hide value. The existing receipt owns both transitions.
                try await backend.restoreExact(receipt.baseline)
                guard try await backend.capture(target) == receipt.baseline else {
                    throw SharedSystemItemTrialError.restorationFailed
                }
                return
            }
            #endif
            guard target == .siri || target == .nowPlaying else {
                try await backend.restoreForOrdinaryReveal(receipt.baseline)
                guard try await backend.capture(target) == receipt.baseline else {
                    throw SharedSystemItemTrialError.restorationFailed
                }
                return
            }
            if target == .nowPlaying {
                try receipt.recordNowPlayingRevealIntent(from: current)
            } else {
                try receipt.recordSiriRevealIntent(from: current)
            }
            // This receipt write is the crash boundary: it records the sole
            // non-baseline visible state cleanup may later take ownership of.
            try writeReceipt(receipt, for: target, withoutOverwriting: false)
            try await backend.setVisibility(true, for: target)
            let revealed = try await backend.capture(target)
            guard try receipt.acceptsOwnedRevealedCurrent(revealed) else {
                throw SharedSystemItemTrialError.verificationFailed
            }
        case .hidden:
            guard hasRecoveryReceipt(for: target) else {
                _ = try await hideLocked(target)
                return
            }
            var receipt = try readReceipt(for: target)
            let current = try await backend.capture(target)
            if try receipt.acceptsOwnedHiddenCurrent(current) { return }
            guard try receipt.acceptsOwnedRevealedCurrent(current) else {
                throw SharedSystemItemTrialError.staleState
            }
            do {
                try await backend.setVisibility(false, for: target)
                let applied = try await backend.capture(target)
                try receipt.recordApplied(applied)
                try writeReceipt(receipt, for: target, withoutOverwriting: false)
            } catch {
                try await backend.restoreExact(receipt.baseline)
                guard try await backend.capture(target) == receipt.baseline else {
                    throw SharedSystemItemTrialError.restorationFailed
                }
                throw error
            }
        }
    }

    private func managedTargets(
        in plan: [String: PersistentSystemItemPresentation]
    ) throws -> [SharedSystemItemTrialTarget: PersistentSystemItemPresentation] {
        var result: [SharedSystemItemTrialTarget: PersistentSystemItemPresentation] = [:]
        for (identifier, presentation) in plan {
            guard PersistentSystemItemPolicyCatalog.controllableItem(for: identifier) != nil,
                  let target = SharedSystemItemTrialTarget.matchingSystemItem(
                    observationIdentifier: identifier
                  ), result[target] == nil else {
                throw SharedSystemItemTrialError.unsupportedValue
            }
            result[target] = presentation
        }
        // Omission means this policy no longer manages the item. A receipt from
        // the preceding plan must therefore be restored and relinquished rather
        // than silently surviving a backup restore or policy downgrade.
        for target in SharedSystemItemTrialTarget.allCases
        where result[target] == nil && hasRecoveryReceipt(for: target) {
            result[target] = .restored
        }
        return result
    }

    private func restore(
        _ checkpoints: [SharedSystemItemTrialTarget: ManagedCheckpoint]
    ) async throws {
        for target in checkpoints.keys.sorted(by: { $0.rawValue > $1.rawValue }) {
            guard let checkpoint = checkpoints[target] else { continue }
            try await backend.restoreExact(checkpoint.snapshot)
            guard try await backend.capture(target) == checkpoint.snapshot else {
                throw SharedSystemItemTrialError.restorationFailed
            }
            if let receipt = checkpoint.receipt {
                try writeReceipt(receipt, for: target, withoutOverwriting: false)
            } else {
                try removeReceipt(for: target)
            }
        }
    }

    private func receiptURL(for target: SharedSystemItemTrialTarget) -> URL {
        receiptDirectory.appendingPathComponent("\(target.rawValue).json")
    }

    private func writeReceipt(
        _ receipt: SharedSystemItemTrialReceipt,
        for target: SharedSystemItemTrialTarget,
        withoutOverwriting: Bool
    ) throws {
        try receipt.validate()
        try FileManager.default.createDirectory(
            at: receiptDirectory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(receipt)
        if withoutOverwriting {
            guard FileManager.default.createFile(
                atPath: receiptURL(for: target).path,
                contents: data,
                attributes: [.posixPermissions: 0o600]
            ) else {
                throw SharedSystemItemTrialError.staleState
            }
        } else {
            try data.write(to: receiptURL(for: target), options: [.atomic])
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: receiptURL(for: target).path
        )
    }

    private func readReceipt(
        for target: SharedSystemItemTrialTarget
    ) throws -> SharedSystemItemTrialReceipt {
        let url = receiptURL(for: target)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 4_194_304,
              (attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600 else {
            throw SharedSystemItemTrialError.malformedReceipt
        }
        let receipt = try JSONDecoder().decode(
            SharedSystemItemTrialReceipt.self, from: Data(contentsOf: url)
        )
        try receipt.validate()
        guard receipt.baseline.target == target else {
            throw SharedSystemItemTrialError.malformedReceipt
        }
        return receipt
    }

    private func removeReceipt(for target: SharedSystemItemTrialTarget) throws {
        let url = receiptURL(for: target)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

extension SharedSystemItemManualTrialWriter:
    PersistentSystemItemPlanWriting, ManualSystemItemTrialWriting {}

private actor SharedSystemItemTrialOperationGate {
    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isHeld {
            isHeld = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isHeld = false
            return
        }
        waiters.removeFirst().resume()
    }
}
#endif
