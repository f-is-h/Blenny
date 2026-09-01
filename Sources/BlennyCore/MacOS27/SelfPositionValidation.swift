#if DEBUG
import AppKit
import CryptoKit
import Foundation

/// Debug-only replication of the historical own-item autosave experiment.
/// This is not a cross-application ordering backend.
public enum SelfPositionValidationError: Error, Equatable {
    case invalidScope
    case unsupportedValue
    case occupiedExperimentKey
    case unconfirmedPlan
    case staleState
    case stopped
    case unexpectedStateChange
    case restoreFailed
}

public struct SelfPositionSnapshot: Codable, Equatable, Sendable {
    public let domain: String
    public let persistent: [String: Data]
    public let registration: [String: Data]

    public init(domain: String, persistent: [String: Data], registration: [String: Data]) {
        self.domain = domain
        self.persistent = persistent
        self.registration = registration
    }

    public static func isScopedKey(_ key: String) -> Bool {
        key.hasPrefix("NSStatusItem Preferred Position ")
            || key.hasPrefix("NSStatusItem Visible ")
    }

    public func validate() throws {
        guard domain == SelfPositionPlan.bundleIdentifier,
              persistent.count <= 32, registration.count <= 32,
              persistent.keys.allSatisfy(Self.isScopedKey),
              registration.keys.allSatisfy(Self.isScopedKey) else {
            throw SelfPositionValidationError.invalidScope
        }
        for data in Array(persistent.values) + Array(registration.values) {
            _ = try Self.decodeValue(data)
        }
    }

    public var fingerprint: String { get throws { try SelfPositionPlan.digest(self) } }

    public static func encodeValue(_ value: Any) throws -> Data {
        let object = value as AnyObject
        let type = CFGetTypeID(object)
        guard type == CFStringGetTypeID() || type == CFBooleanGetTypeID()
                || (type == CFNumberGetTypeID() && (value as? NSNumber)?.doubleValue.isFinite == true) else {
            throw SelfPositionValidationError.unsupportedValue
        }
        return try PropertyListSerialization.data(fromPropertyList: ["value": value], format: .binary, options: 0)
    }

    public static func decodeValue(_ data: Data) throws -> Any {
        guard data.count <= 4096,
              let object = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              object.count == 1, let value = object["value"] else {
            throw SelfPositionValidationError.unsupportedValue
        }
        _ = try encodeValue(value)
        return value
    }
}

public struct SelfPositionPlan: Codable, Equatable, Sendable {
    public static let bundleIdentifier = "xyz.fi5h.blenny"
    public static let autosaveName = "Blenny0.7.0SelfPositionValidation"
    public static let positionKey = "NSStatusItem Preferred Position \(autosaveName)"
    public static let visibleKey = "NSStatusItem Visible \(autosaveName)"
    public static let experimentKeys: Set<String> = [positionKey, visibleKey]
    public static let position = 500
    public static let durationSeconds = 60

    public let schemaVersion: Int
    public let baseline: SelfPositionSnapshot
    public let runtime: RuntimeEnvironment

    public init(baseline: SelfPositionSnapshot, runtime: RuntimeEnvironment) throws {
        schemaVersion = 1
        self.baseline = baseline
        self.runtime = runtime
        try validate()
    }

    public func validate() throws {
        try baseline.validate()
        guard schemaVersion == 1, runtime.buildVersion == "26A5416b",
              runtime.macOSVersion == "27.0.0", runtime.architecture == "arm64" else {
            throw SelfPositionValidationError.invalidScope
        }
        guard Self.experimentKeys.allSatisfy({ baseline.persistent[$0] == nil && baseline.registration[$0] == nil }) else {
            throw SelfPositionValidationError.occupiedExperimentKey
        }
    }

    public var fingerprint: String {
        get throws {
            struct Binding: Encodable {
                let plan: SelfPositionPlan
                let position: Int
                let seconds: Int
                let autosaveName: String
            }
            return try Self.digest(Binding(plan: self, position: Self.position,
                                           seconds: Self.durationSeconds, autosaveName: Self.autosaveName))
        }
    }

    static func digest(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return SHA256.hash(data: try encoder.encode(value)).map { String(format: "%02x", $0) }.joined()
    }

    /// Only a carrier for the existing serial writer. Never sent to an assessment
    /// factory or macOS service; the exact factory below rejects every other plan.
    public static var writerToken: RevealAllowlistPlan {
        RevealAllowlistPlan(presentation: .baseline, allowedSystemItems: [],
                           allowedBundleIdentifiers: [bundleIdentifier])
    }

    public func checkApplied(_ current: SelfPositionSnapshot) throws {
        try current.validate()
        var registration = current.registration
        guard let value = registration.removeValue(forKey: Self.positionKey),
              (try SelfPositionSnapshot.decodeValue(value) as? NSNumber)?.doubleValue == Double(Self.position) else {
            throw SelfPositionValidationError.unexpectedStateChange
        }
        var persistent = current.persistent
        for key in Self.experimentKeys { persistent.removeValue(forKey: key) }
        guard registration == baseline.registration, persistent == baseline.persistent else {
            throw SelfPositionValidationError.unexpectedStateChange
        }
    }

    public func checkRecoveryScope(_ current: SelfPositionSnapshot) throws {
        try current.validate()
        let persistent = current.persistent.filter { !Self.experimentKeys.contains($0.key) }
        let registration = current.registration.filter { !Self.experimentKeys.contains($0.key) }
        guard persistent == baseline.persistent, registration == baseline.registration else {
            throw SelfPositionValidationError.unexpectedStateChange
        }
    }
}

@MainActor
public protocol SelfPositionValidationBackend: AnyObject, Sendable {
    func capture() throws -> SelfPositionSnapshot
    func apply() throws
    func restore() throws
}

/// This local lease uses the existing serial writer's candidate lifecycle. It
/// never constructs a private assertion, supplies an allow-list to macOS or
/// runs concurrently with the ordinary management controller.
@MainActor
public final class SelfPositionValidationLease: RevealAssertionCandidate {
    private let backend: any SelfPositionValidationBackend
    private let plan: SelfPositionPlan
    private let confirmation: String
    private let recoveryOnly: Bool
    private var stopped = false
    private var touched = false
    private var recoveryAttempted = false
    public private(set) var restoreVerified = false
    public private(set) var failure: String?

    public init(backend: any SelfPositionValidationBackend, plan: SelfPositionPlan, confirmation: String,
                recoveryOnly: Bool = false) {
        self.backend = backend
        self.plan = plan
        self.confirmation = confirmation
        self.recoveryOnly = recoveryOnly
    }

    public nonisolated func activate() async throws { try await applyOnMainActor() }

    private func applyOnMainActor() throws {
        guard !stopped else { throw SelfPositionValidationError.stopped }
        try plan.validate()
        let expectedConfirmation = try plan.fingerprint + (recoveryOnly ? ":restore" : "")
        guard confirmation == expectedConfirmation else { throw SelfPositionValidationError.unconfirmedPlan }
        let current = try backend.capture()
        if recoveryOnly {
            try plan.checkRecoveryScope(current)
            recoveryAttempted = true
            do {
                try backend.restore()
                guard try backend.capture() == plan.baseline else { throw SelfPositionValidationError.restoreFailed }
                restoreVerified = true
            } catch {
                failure = String(describing: error)
                throw error
            }
            return
        }
        guard current == plan.baseline else { throw SelfPositionValidationError.staleState }
        guard !touched else { throw SelfPositionValidationError.stopped }
        // Set before the first mutation, so even a partially failed apply is
        // restored by the serial writer's failed-candidate invalidation.
        touched = true
        try backend.apply()
        try plan.checkApplied(backend.capture())
    }

    public nonisolated func invalidate() async { await restoreOnMainActor() }

    private func restoreOnMainActor() {
        guard !stopped else { return }
        stopped = true
        // A failed explicit recovery must never be reported as a successful
        // no-op or retried by failed-candidate invalidation.
        if recoveryAttempted { return }
        guard touched else { restoreVerified = true; return }
        do {
            try backend.restore()
            guard try backend.capture() == plan.baseline else { throw SelfPositionValidationError.restoreFailed }
            restoreVerified = true
        } catch {
            failure = String(describing: error)
            restoreVerified = false
        }
    }
}

public struct SelfPositionValidationFactory: RevealAssertionCandidateFactory {
    public let lease: SelfPositionValidationLease
    public init(lease: SelfPositionValidationLease) { self.lease = lease }
    public func makeCandidate(for plan: RevealAllowlistPlan) throws -> any RevealAssertionCandidate {
        guard plan == SelfPositionPlan.writerToken else { throw SelfPositionValidationError.invalidScope }
        return lease
    }
}

@MainActor
public final class MacOS27SelfPositionBackend: SelfPositionValidationBackend {
    private let createItems: @MainActor (String) throws -> Void
    private let removeItems: @MainActor () -> Void

    public init(createItems: @escaping @MainActor (String) throws -> Void,
                removeItems: @escaping @MainActor () -> Void) {
        self.createItems = createItems
        self.removeItems = removeItems
    }

    public func capture() throws -> SelfPositionSnapshot {
        guard Bundle.main.bundleIdentifier == SelfPositionPlan.bundleIdentifier else {
            throw SelfPositionValidationError.invalidScope
        }
        func scoped(_ domain: [String: Any]) throws -> [String: Data] {
            try domain.filter { SelfPositionSnapshot.isScopedKey($0.key) }
                .mapValues(SelfPositionSnapshot.encodeValue)
        }
        return try SelfPositionSnapshot(domain: SelfPositionPlan.bundleIdentifier,
            persistent: scoped(UserDefaults.standard.persistentDomain(forName: SelfPositionPlan.bundleIdentifier) ?? [:]),
            registration: scoped(UserDefaults.standard.volatileDomain(forName: UserDefaults.registrationDomain)))
    }

    public func apply() throws {
        UserDefaults.standard.register(defaults: [SelfPositionPlan.positionKey: SelfPositionPlan.position])
        // Match the historical sequence: register before constructing the item,
        // assign the unique autosave name immediately after creation.
        try createItems(SelfPositionPlan.autosaveName)
    }

    public func restore() throws {
        // Remove both process-owned controls before removing experimental keys,
        // preventing AppKit teardown from saving the experimental position again.
        removeItems()
        for key in SelfPositionPlan.experimentKeys { UserDefaults.standard.removeObject(forKey: key) }
        var registration = UserDefaults.standard.volatileDomain(forName: UserDefaults.registrationDomain)
        for key in SelfPositionPlan.experimentKeys { registration.removeValue(forKey: key) }
        UserDefaults.standard.setVolatileDomain(registration, forName: UserDefaults.registrationDomain)
        guard UserDefaults.standard.synchronize() else { throw SelfPositionValidationError.restoreFailed }
    }
}
#endif
