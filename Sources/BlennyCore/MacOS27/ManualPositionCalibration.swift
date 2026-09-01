#if DEBUG
import CryptoKit
import Foundation

public enum ManualPositionCalibrationError: Error, Equatable {
    case invalidScope
    case occupiedExperimentKey
    case unconfirmedPlan
    case staleState
    case stopped
    case unexpectedStateChange
    case restoreFailed
}

public struct ManualPositionCalibrationObservation: Codable, Equatable, Sendable {
    public let savedPosition: Double?
    public let runtimePreferredPosition: Double

    public init(savedPosition: Double?, runtimePreferredPosition: Double) throws {
        guard savedPosition?.isFinite != false,
              runtimePreferredPosition.isFinite else {
            throw ManualPositionCalibrationError.invalidScope
        }
        self.savedPosition = savedPosition
        self.runtimePreferredPosition = runtimePreferredPosition
    }
}

public struct ManualPositionCalibrationPlan: Codable, Equatable, Sendable {
    public static let bundleIdentifier = "xyz.fi5h.blenny"
    public static let autosaveName = "Blenny0.7.0ManualPositionCalibration"
    public static let positionKey = "NSStatusItem Preferred Position \(autosaveName)"
    public static let visibleKey = "NSStatusItem Visible \(autosaveName)"
    public static let experimentKeys: Set<String> = [positionKey, visibleKey]
    public static let durationSeconds = 120

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
        guard schemaVersion == 1,
              baseline.domain == Self.bundleIdentifier,
              runtime.buildVersion == "26A5416b",
              runtime.macOSVersion == "27.0.0",
              runtime.architecture == "arm64" else {
            throw ManualPositionCalibrationError.invalidScope
        }
        guard Self.experimentKeys.allSatisfy({
            baseline.persistent[$0] == nil && baseline.registration[$0] == nil
        }) else {
            throw ManualPositionCalibrationError.occupiedExperimentKey
        }
    }

    public var fingerprint: String {
        get throws {
            struct Binding: Encodable {
                let plan: ManualPositionCalibrationPlan
                let autosaveName: String
                let seconds: Int
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(Binding(plan: self,
                autosaveName: Self.autosaveName, seconds: Self.durationSeconds))
            return SHA256.hash(data: data)
                .map { String(format: "%02x", $0) }.joined()
        }
    }

    public static var writerToken: RevealAllowlistPlan {
        RevealAllowlistPlan(presentation: .baseline, allowedSystemItems: [],
            allowedBundleIdentifiers: [bundleIdentifier])
    }

    public func validateLiveScope(_ current: SelfPositionSnapshot) throws {
        try current.validate()
        var persistent = current.persistent
        var registration = current.registration
        for key in Self.experimentKeys {
            persistent.removeValue(forKey: key)
            registration.removeValue(forKey: key)
        }
        guard persistent == baseline.persistent,
              registration == baseline.registration else {
            throw ManualPositionCalibrationError.unexpectedStateChange
        }
    }

    public func position(in snapshot: SelfPositionSnapshot) throws -> Double? {
        try validateLiveScope(snapshot)
        guard let data = snapshot.persistent[Self.positionKey]
                ?? snapshot.registration[Self.positionKey] else { return nil }
        guard let number = try SelfPositionSnapshot.decodeValue(data) as? NSNumber,
              number.doubleValue.isFinite else {
            throw ManualPositionCalibrationError.unexpectedStateChange
        }
        return number.doubleValue
    }
}

public struct ManualPositionCalibrationReceipt: Codable, Equatable, Sendable {
    public let plan: ManualPositionCalibrationPlan
    public let observation: ManualPositionCalibrationObservation?

    public init(plan: ManualPositionCalibrationPlan,
                observation: ManualPositionCalibrationObservation? = nil) {
        self.plan = plan
        self.observation = observation
    }
}

@MainActor
public protocol ManualPositionCalibrationBackend: AnyObject, Sendable {
    func capture() throws -> SelfPositionSnapshot
    func start() throws
    func currentPreferredPosition() throws -> Double?
    func restore() throws
}

@MainActor
public final class ManualPositionCalibrationLease: RevealAssertionCandidate {
    private let backend: any ManualPositionCalibrationBackend
    private let plan: ManualPositionCalibrationPlan
    private let confirmation: String
    private let recoveryOnly: Bool
    private var stopped = false
    private var touched = false
    private var recoveryAttempted = false
    public private(set) var observation: ManualPositionCalibrationObservation?
    public private(set) var restoreVerified = false
    public private(set) var failure: String?

    public init(backend: any ManualPositionCalibrationBackend,
                plan: ManualPositionCalibrationPlan, confirmation: String,
                recoveryOnly: Bool = false) {
        self.backend = backend
        self.plan = plan
        self.confirmation = confirmation
        self.recoveryOnly = recoveryOnly
    }

    public nonisolated func activate() async throws { try await activateOnMain() }

    private func activateOnMain() throws {
        guard !stopped else { throw ManualPositionCalibrationError.stopped }
        try plan.validate()
        let expected = try plan.fingerprint + (recoveryOnly ? ":restore" : "")
        guard confirmation == expected else {
            throw ManualPositionCalibrationError.unconfirmedPlan
        }
        let current = try backend.capture()
        if recoveryOnly {
            try plan.validateLiveScope(current)
            recoveryAttempted = true
            do {
                try backend.restore()
                guard try backend.capture() == plan.baseline else {
                    throw ManualPositionCalibrationError.restoreFailed
                }
                restoreVerified = true
            } catch {
                failure = String(describing: error)
                throw error
            }
            return
        }
        guard current == plan.baseline else {
            throw ManualPositionCalibrationError.staleState
        }
        touched = true
        try backend.start()
        let started = try backend.capture()
        try plan.validateLiveScope(started)
    }

    /// Called once by the owner's explicit Debug menu action after the native
    /// drag. It performs no retry or scheduled read.
    public func recordCurrent() throws -> ManualPositionCalibrationObservation {
        guard !stopped, touched, !recoveryOnly else {
            throw ManualPositionCalibrationError.stopped
        }
        if let observation { return observation }
        let current = try backend.capture()
        guard let runtimePosition = try backend.currentPreferredPosition() else {
            throw ManualPositionCalibrationError.unexpectedStateChange
        }
        let result = try ManualPositionCalibrationObservation(
            savedPosition: try plan.position(in: current),
            runtimePreferredPosition: runtimePosition)
        observation = result
        return result
    }

    public nonisolated func invalidate() async { await restoreOnMain() }

    private func restoreOnMain() {
        guard !stopped else { return }
        stopped = true
        if recoveryAttempted { return }
        guard touched else { restoreVerified = true; return }
        do {
            try backend.restore()
            guard try backend.capture() == plan.baseline else {
                throw ManualPositionCalibrationError.restoreFailed
            }
            restoreVerified = true
        } catch {
            failure = String(describing: error)
            restoreVerified = false
        }
    }
}

public struct ManualPositionCalibrationFactory: RevealAssertionCandidateFactory {
    public let lease: ManualPositionCalibrationLease

    public init(lease: ManualPositionCalibrationLease) { self.lease = lease }

    public func makeCandidate(for plan: RevealAllowlistPlan) throws
        -> any RevealAssertionCandidate {
        guard plan == ManualPositionCalibrationPlan.writerToken else {
            throw ManualPositionCalibrationError.invalidScope
        }
        return lease
    }
}

@MainActor
public final class MacOS27ManualPositionCalibrationBackend:
    ManualPositionCalibrationBackend {
    private let createItems: @MainActor (String) throws -> Void
    private let removeItems: @MainActor () -> Void
    private let readCurrentPreferredPosition: @MainActor () throws -> Double?

    public init(createItems: @escaping @MainActor (String) throws -> Void,
                removeItems: @escaping @MainActor () -> Void,
                readCurrentPreferredPosition:
                    @escaping @MainActor () throws -> Double?) {
        self.createItems = createItems
        self.removeItems = removeItems
        self.readCurrentPreferredPosition = readCurrentPreferredPosition
    }

    public func capture() throws -> SelfPositionSnapshot {
        guard Bundle.main.bundleIdentifier
                == ManualPositionCalibrationPlan.bundleIdentifier else {
            throw ManualPositionCalibrationError.invalidScope
        }
        func scoped(_ domain: [String: Any]) throws -> [String: Data] {
            try domain.filter { SelfPositionSnapshot.isScopedKey($0.key) }
                .mapValues(SelfPositionSnapshot.encodeValue)
        }
        return try SelfPositionSnapshot(
            domain: ManualPositionCalibrationPlan.bundleIdentifier,
            persistent: scoped(UserDefaults.standard.persistentDomain(
                forName: ManualPositionCalibrationPlan.bundleIdentifier) ?? [:]),
            registration: scoped(UserDefaults.standard.volatileDomain(
                forName: UserDefaults.registrationDomain)))
    }

    public func start() throws {
        try createItems(ManualPositionCalibrationPlan.autosaveName)
    }

    public func currentPreferredPosition() throws -> Double? {
        try readCurrentPreferredPosition()
    }

    public func restore() throws {
        removeItems()
        for key in ManualPositionCalibrationPlan.experimentKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        var registration = UserDefaults.standard.volatileDomain(
            forName: UserDefaults.registrationDomain)
        for key in ManualPositionCalibrationPlan.experimentKeys {
            registration.removeValue(forKey: key)
        }
        UserDefaults.standard.setVolatileDomain(registration,
            forName: UserDefaults.registrationDomain)
        guard UserDefaults.standard.synchronize() else {
            throw ManualPositionCalibrationError.restoreFailed
        }
    }
}
#endif
