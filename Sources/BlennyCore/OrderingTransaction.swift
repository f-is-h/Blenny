#if DEBUG
import CryptoKit
import Foundation

/// A narrow macOS capability, invoked for mutations only by CoordinatedPolicyWriter.
/// It is not an independently scheduled or automatically reconciling writer.
public protocol MenuBarOrderingBackend: Sendable {
    func capture() async throws -> OrderingSnapshot
    func writeTable(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot
    ) async throws
    func restoreTable(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot
    ) async throws
    func writeConfigurationTable(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot,
        ownerKeys: Set<String>
    ) async throws
    func restoreConfigurationTable(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot,
        ownerKeys: Set<String>
    ) async throws
    func captureConfigurationTransition(
        from snapshot: OrderingSnapshot, to table: [String: OrderingValue]
    ) async throws -> OrderingSnapshot
}

public extension MenuBarOrderingBackend {
    func restoreTable(_ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot) async throws {
        try await writeTable(table, expecting: snapshot)
    }

    func writeConfigurationTable(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot,
        ownerKeys: Set<String>
    ) async throws {
        try snapshot.validateConfigurationProcessScope(for: ownerKeys, against: snapshot)
        try await writeTable(table, expecting: snapshot)
    }

    func restoreConfigurationTable(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot,
        ownerKeys: Set<String>
    ) async throws {
        try snapshot.validateConfigurationProcessScope(for: ownerKeys, against: snapshot)
        try await restoreTable(table, expecting: snapshot)
    }

    func captureConfigurationTransition(
        from snapshot: OrderingSnapshot, to table: [String: OrderingValue]
    ) async throws -> OrderingSnapshot {
        try await capture()
    }
}

public enum OrderingRecoveryPhase: String, Codable, Sendable {
    case applyIntent
    case applied
    case restoreIntent
    case preferencesRestored
}

public struct OrderingPolicyUndo: Codable, Equatable, Sendable {
    public let before: PersistentBundlePolicyDocument
    public let after: PersistentBundlePolicyDocument
    public let backup: PersistentBundlePolicyBackup?
    public init(before: PersistentBundlePolicyDocument, after: PersistentBundlePolicyDocument,
                backup: PersistentBundlePolicyBackup?) {
        self.before = before; self.after = after; self.backup = backup
    }
}

public struct OrderingRecoveryReceipt: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var plan: OrderingPlan
    public var phase: OrderingRecoveryPhase
    public var detail: String
    public let sessionIdentifier: UUID?
    public var revision: Int?
    public var originalValues: [String: OrderingValue]?
    public var committedValues: [String: OrderingValue]?
    public var pendingValues: [String: OrderingValue]?
    public var configurationVerified: Bool?
    public var physicalVerificationStatus: OrderingPhysicalVerificationStatus?
    public var ownerBindings: [OrderingConfigurationOwnerTarget]?
    public var subjectBindings: [OrderingConfigurationSubjectTarget]?
    public var configurationRestoreRetryCount: Int?
    public var undoPolicyWriteAttempted: Bool?
    public var undoPolicyRestoreIntent: Bool?
    public var undoPolicy: OrderingPolicyUndo?
    public var originalPolicy: PersistentBundlePolicyDocument?
    public var originalPolicyBackup: PersistentBundlePolicyBackup?
    public var proposedPolicy: PersistentBundlePolicyDocument?
    public var policyPersistenceCommitted: Bool?

    public init(plan: OrderingPlan, phase: OrderingRecoveryPhase, detail: String = "") {
        schemaVersion = 1
        self.plan = plan
        self.phase = phase
        self.detail = detail
        sessionIdentifier = nil
        revision = nil
        originalValues = nil
        committedValues = nil
        pendingValues = nil
        configurationVerified = nil
        physicalVerificationStatus = nil
        ownerBindings = nil
        subjectBindings = nil
        originalPolicy = nil
        originalPolicyBackup = nil
        proposedPolicy = nil
        policyPersistenceCommitted = nil
    }

    public init(
        configurationPlan plan: OrderingPlan,
        sessionIdentifier: UUID = UUID(),
        revision: Int = 1,
        originalValues: [String: OrderingValue],
        committedValues: [String: OrderingValue],
        pendingValues: [String: OrderingValue],
        phase: OrderingRecoveryPhase = .applyIntent,
        detail: String = ""
    ) {
        schemaVersion = plan.schemaVersion == 4 ? 3 : 2
        self.plan = plan
        self.phase = phase
        self.detail = detail
        self.sessionIdentifier = sessionIdentifier
        self.revision = revision
        self.originalValues = originalValues
        self.committedValues = committedValues
        self.pendingValues = pendingValues
        configurationVerified = false
        physicalVerificationStatus = .unavailable
        ownerBindings = plan.configurationTargets
        subjectBindings = plan.configurationSubjectTargets
        originalPolicy = nil
        originalPolicyBackup = nil
        proposedPolicy = nil
        policyPersistenceCommitted = nil
    }

    public func validate() throws {
        guard detail.utf8.count <= 4096 else {
            throw OrderingTransactionError.invalidReceipt
        }
        try plan.validate()
        if schemaVersion == 1 {
            guard sessionIdentifier == nil, revision == nil, originalValues == nil,
                  committedValues == nil, pendingValues == nil,
                  configurationVerified == nil, physicalVerificationStatus == nil,
                  ownerBindings == nil, subjectBindings == nil,
                  originalPolicy == nil, proposedPolicy == nil,
                  originalPolicyBackup == nil,
                  policyPersistenceCommitted == nil else {
                throw OrderingTransactionError.invalidReceipt
            }
            return
        }
        let bindingKeys: Set<String>
        if (schemaVersion == 2 || schemaVersion == 4), plan.schemaVersion == 3,
           let ownerBindings, subjectBindings == nil,
           Set(ownerBindings.map(\.bundleIdentifier)).count == ownerBindings.count {
            bindingKeys = Set(ownerBindings.flatMap(\.keys).map(\.key))
        } else if (schemaVersion == 3 || schemaVersion == 4), plan.schemaVersion == 4,
                  ownerBindings == nil, let subjectBindings,
                  Set(subjectBindings.map(\.subjectID)).count == subjectBindings.count {
            bindingKeys = Set(subjectBindings.flatMap(\.keys).map(\.key))
        } else {
            throw OrderingTransactionError.invalidReceipt
        }
        guard
              sessionIdentifier != nil, let revision, revision > 0,
              let originalValues, let committedValues,
              let configurationVerified, physicalVerificationStatus != nil,
              (!originalValues.isEmpty || schemaVersion == 4),
              originalValues.count <= OrderingPlan.maximumConfigurationKeys,
              Set(originalValues.keys) == Set(committedValues.keys),
              pendingValues.map({ Set($0.keys) == Set(originalValues.keys) }) != false,
              bindingKeys == Set(originalValues.keys),
              (originalPolicy == nil) == (proposedPolicy == nil),
              originalPolicy != nil || originalPolicyBackup == nil,
              (originalPolicy == nil) == (policyPersistenceCommitted == nil),
              Set(plan.configurationKeyTargets.map(\.key))
                .isSubset(of: Set(originalValues.keys)) else {
            throw OrderingTransactionError.invalidReceipt
        }
        guard (undoPolicy == nil && undoPolicyRestoreIntent == nil
                && undoPolicyWriteAttempted == nil && configurationRestoreRetryCount == nil)
                || schemaVersion == 4,
              configurationRestoreRetryCount.map({ (0...1).contains($0) }) != false else {
            throw OrderingTransactionError.invalidReceipt
        }
        try OrderingValue.dictionary(originalValues).validate()
        try OrderingValue.dictionary(committedValues).validate()
        if let pendingValues { try OrderingValue.dictionary(pendingValues).validate() }
        switch phase {
        case .applyIntent:
            guard pendingValues != nil, !configurationVerified else {
                throw OrderingTransactionError.invalidReceipt
            }
        case .applied:
            guard pendingValues == nil, configurationVerified else {
                throw OrderingTransactionError.invalidReceipt
            }
        case .restoreIntent:
            guard pendingValues != nil, !configurationVerified else {
                throw OrderingTransactionError.invalidReceipt
            }
        case .preferencesRestored:
            guard pendingValues == nil, configurationVerified,
                  committedValues == originalValues else {
                throw OrderingTransactionError.invalidReceipt
            }
        }
    }

    /// A clean configuration commit is durable user configuration with an available
    /// Undo; it is not pending cleanup merely because its receipt is retained.
    public var isPendingRestoration: Bool {
        if schemaVersion == 1 { return true }
        return phase == .applyIntent || phase == .restoreIntent
            || configurationVerified != true || originalPolicy != nil
            || originalPolicyBackup != nil || proposedPolicy != nil
            || policyPersistenceCommitted != nil
    }

    public var hasConfigurationUndo: Bool {
        schemaVersion >= 2 && !isPendingRestoration
            && phase == .applied && configurationVerified == true
            && (committedValues != originalValues || undoPolicy != nil)
    }

    /// A failed later revision has already journaled its inverse to the last
    /// clean commit. Recovery must verify that inverse before considering the
    /// older commit's separate Undo, even when an Undo policy is retained.
    public var hasPendingRevisionRollback: Bool {
        phase == .restoreIntent && pendingValues != nil
            && pendingValues == committedValues
            && originalPolicy == nil && proposedPolicy == nil
    }

    /// Describes a clean Undo ledger whose committed positions no longer match
    /// the current configuration. The token binds the complete retained ledger
    /// and every current value (including missing values), so Apply must refuse
    /// if anything changes after the user reviews this report.
    public func undoLedgerRebaseReview(
        in snapshot: OrderingSnapshot
    ) throws -> OrderingUndoLedgerRebaseReview? {
        try validate()
        try snapshot.validate()
        guard (schemaVersion == 2 || schemaVersion == 3 || schemaVersion == 4),
              !isPendingRestoration, phase == .applied, configurationVerified == true,
              pendingValues == nil, let committedValues else {
            throw OrderingTransactionError.recoveryRequired
        }
        let current = try snapshot.table()
        let observations = committedValues.keys.sorted().map {
            OrderingUndoLedgerObservedValue(key: $0, value: current[$0])
        }
        let changedKeys: [String] = observations.compactMap { observation in
            guard let value = observation.value,
                  value != committedValues[observation.key] else { return nil }
            return observation.key
        }
        let missingKeys: [String] = observations.compactMap {
            $0.value == nil ? $0.key : nil
        }
        guard !changedKeys.isEmpty || !missingKeys.isEmpty else { return nil }

        let binding = OrderingUndoLedgerRebaseBinding(
            receipt: self, observedValues: observations
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let digest = SHA256.hash(data: try encoder.encode(binding))
            .map { String(format: "%02x", $0) }.joined()
        return OrderingUndoLedgerRebaseReview(
            changedKeys: changedKeys, missingKeys: missingKeys,
            token: "ordering-undo-rebase-v1:\(digest)"
        )
    }
}

public struct OrderingUndoLedgerRebaseReview: Equatable, Sendable {
    public let changedKeys: [String]
    public let missingKeys: [String]
    public let token: String

    public init(changedKeys: [String], missingKeys: [String], token: String) {
        self.changedKeys = changedKeys.sorted()
        self.missingKeys = missingKeys.sorted()
        self.token = token
    }

    public var userDescription: String {
        var parts: [String] = []
        if !changedKeys.isEmpty {
            parts.append("\(changedKeys.count) retained ordering value(s) changed externally")
        }
        if !missingKeys.isEmpty {
            parts.append("\(missingKeys.count) retained ordering value(s) are now missing")
        }
        return "The previous clean Undo baseline no longer matches the current configuration (\(parts.joined(separator: ", "))). Applying this reviewed order will archive that Undo record and use the current selected positions as a new Undo baseline."
    }
}

private struct OrderingUndoLedgerObservedValue: Codable, Equatable, Sendable {
    let key: String
    let value: OrderingValue?
}

private struct OrderingUndoLedgerRebaseBinding: Codable, Sendable {
    let receipt: OrderingRecoveryReceipt
    let observedValues: [OrderingUndoLedgerObservedValue]
}

public struct OrderingConfigurationCommitResult: Sendable, Equatable {
    public let snapshot: OrderingSnapshot
    public let configurationVerified: Bool
    public let physicalVerificationStatus: OrderingPhysicalVerificationStatus
    public let revision: Int

    public init(
        snapshot: OrderingSnapshot, configurationVerified: Bool,
        physicalVerificationStatus: OrderingPhysicalVerificationStatus,
        revision: Int
    ) {
        self.snapshot = snapshot
        self.configurationVerified = configurationVerified
        self.physicalVerificationStatus = physicalVerificationStatus
        self.revision = revision
    }
}

public protocol OrderingRecoveryStoring: Sendable {
    /// Hold a nonblocking, process-wide lease until releaseLease. Read-only load
    /// must neither acquire this lease nor create a directory or receipt.
    func acquireLease() async throws
    func releaseLease() async
    func load() async throws -> OrderingRecoveryReceipt?
    func save(_ receipt: OrderingRecoveryReceipt) async throws
    /// Archives an exact clean Undo ledger before installing a new reviewed
    /// apply intent. Implementations must never discard the old ledger merely
    /// because they cannot perform this transition.
    func supersedeClean(
        _ existing: OrderingRecoveryReceipt,
        with replacement: OrderingRecoveryReceipt
    ) async throws
    /// Retain one completed receipt for inspection, then remove the active one.
    func complete(_ receipt: OrderingRecoveryReceipt) async throws
}

public extension OrderingRecoveryStoring {
    func supersedeClean(
        _ existing: OrderingRecoveryReceipt,
        with replacement: OrderingRecoveryReceipt
    ) async throws {
        throw OrderingTransactionError.receiptStorageUnavailable
    }
}

public enum OrderingTransactionError: Error, Equatable, LocalizedError, Sendable {
    case unavailable
    case confirmationMismatch
    case alreadyConsumed
    case recoveryRequired
    case invalidReceipt
    case receiptStorageUnavailable
    case writerOccupied
    case contextInvalidated
    case movementNotVerified
    case restorationNotVerified
    case restorationAlreadyAttempted
    case recoveryIdentityConflict
    case policyRecoveryRequired

    public var errorDescription: String? {
        switch self {
        case .unavailable: "Menu-bar ordering is unavailable in this build or session."
        case .confirmationMismatch: "The selected preview changed. Prepare and review it again."
        case .alreadyConsumed: "This preview has already been used. Prepare a new preview."
        case .recoveryRequired: "Restore the outstanding ordering transaction before another order change."
        case .invalidReceipt: "The ordering recovery record is invalid. It has been preserved for inspection."
        case .receiptStorageUnavailable: "A private durable ordering recovery record could not be verified."
        case .writerOccupied: "Another Blenny process owns ordering recovery."
        case .contextInvalidated: "The session changed during ordering. The original positions require restoration."
        case .movementNotVerified: "The real menu-bar order could not be verified."
        case .restorationNotVerified: "Preferred positions were restored, but the original relative order could not be verified. The recovery record is retained."
        case .restorationAlreadyAttempted: "Restoration was already attempted without confirmation. Blenny will inspect the state but will not repeat the write."
        case .recoveryIdentityConflict: "An ordering key now conflicts with another application. Restoration was refused."
        case .policyRecoveryRequired: "The combined policy change could not be recovered completely. Its journal was retained."
        }
    }
}

public struct OrderingRestoreResult: Sendable, Equatable {
    public let preferencesRestored: Bool
    public let relativeOrderVerified: Bool
}
#endif
