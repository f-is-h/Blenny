#if DEBUG
import Foundation

/// A separate experiment journal; never replaces the user's ordinary Undo ledger.
public struct FallbackPositionReceipt: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable {
        case applyIntent, applied, restoreIntent, restored
    }
    public let schemaVersion: Int
    public let id: UUID
    public let delta: FallbackPositionDelta
    public let baseline: OrderingSnapshot
    public let persistsAfterQuit: Bool?
    public var phase: Phase

    public init(delta: FallbackPositionDelta, baseline: OrderingSnapshot,
                persistsAfterQuit: Bool = false) throws {
        schemaVersion = delta.fishOriginal == nil ? 1 : 2
        id = UUID()
        self.delta = delta
        self.baseline = baseline
        self.persistsAfterQuit = persistsAfterQuit
        phase = .applyIntent
        try validate()
    }

    public func validate() throws {
        guard (schemaVersion == 1 && delta.fishOriginal == nil)
                || (schemaVersion == 2 && delta.fishOriginal != nil) else {
            throw OrderingTransactionError.invalidReceipt
        }
        try baseline.validate()
        let table = try baseline.table()
        guard delta.originalValues.allSatisfy({ table[$0.key] == $0.value }) else {
            throw OrderingTransactionError.invalidReceipt
        }
        _ = try FallbackPositionDelta(original: delta.original, proposed: delta.proposed,
            fishOriginal: delta.fishOriginal, fishProposed: delta.fishProposed)
        let owners = baseline.afterProcesses.filter { $0.bundleIdentifier == "xyz.fi5h.blenny" }
        guard owners.count == 1, baseline.beforeProcesses.contains(owners[0]),
              baseline.runtimeContractVerified, baseline.osBuild == "26A5425a",
              baseline.architecture == "arm64", baseline.displayCount == 1 else {
            throw OrderingTransactionError.recoveryIdentityConflict
        }
    }

    public func sameTransaction(as other: Self) -> Bool {
        schemaVersion == other.schemaVersion && id == other.id
            && delta == other.delta && baseline == other.baseline
            && persistsAfterQuit == other.persistsAfterQuit
    }

    public var isPendingRestoration: Bool {
        phase != .restored && !(persistsAfterQuit == true && phase == .applied)
    }

    public func permitsSuccessor(_ next: Self) -> Bool {
        guard sameTransaction(as: next) else { return false }
        if phase == next.phase { return true }
        switch (phase, next.phase) {
        case (.applyIntent, .applied), (.applyIntent, .restoreIntent),
             (.applied, .restoreIntent), (.restoreIntent, .restored): return true
        default: return false
        }
    }
}

public protocol FallbackPositionRecoveryStoring: Sendable {
    func acquireLease() async throws
    func releaseLease() async
    func load() async throws -> FallbackPositionReceipt?
    func save(_ receipt: FallbackPositionReceipt) async throws
    func complete(_ receipt: FallbackPositionReceipt) async throws
    func supersedeCommitted(_ existing: FallbackPositionReceipt,
                            with replacement: FallbackPositionReceipt, reviewedDrift: Bool) async throws
}

public extension FallbackPositionRecoveryStoring {
    func supersedeCommitted(_ existing: FallbackPositionReceipt,
                            with replacement: FallbackPositionReceipt, reviewedDrift: Bool) async throws {
        throw OrderingTransactionError.receiptStorageUnavailable
    }
}

/// Obtained from the actual native status-item instance, never from table names.
public struct FallbackNativeIdentity: Equatable, Sendable {
    public let pid: Int32
    public let session: UUID
    public let instance: Int
    public init(pid: Int32, session: UUID, instance: Int) {
        self.pid = pid
        self.session = session
        self.instance = instance
    }
}

public protocol FallbackPositionWriting: MenuBarOrderingBackend {
    func fallbackIdentity() async throws -> FallbackNativeIdentity
    func writeFallbackPosition(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot,
        identity: FallbackNativeIdentity
    ) async throws
}
#endif
