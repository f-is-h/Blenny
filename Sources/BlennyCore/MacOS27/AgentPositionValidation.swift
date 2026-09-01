#if DEBUG
import CryptoKit
import Foundation

public enum AgentPositionValidationError: Error, Equatable {
    case invalidScope, occupiedTarget, unconfirmedPlan, staleState, stopped
    case unexpectedStateChange, restoreFailed
}

public struct AgentPositionSnapshot: Codable, Equatable, Sendable {
    public let encodedDictionary: Data?

    public init(encodedDictionary: Data?) throws {
        self.encodedDictionary = encodedDictionary
        _ = try dictionary()
    }

    public func dictionary() throws -> [String: Double]? {
        guard let encodedDictionary else { return nil }
        guard encodedDictionary.count <= 65_536,
              let raw = try PropertyListSerialization.propertyList(
                from: encodedDictionary, format: nil
              ) as? [String: Any], raw.count <= 512 else {
            throw AgentPositionValidationError.invalidScope
        }
        var result: [String: Double] = [:]
        for (key, value) in raw {
            guard key.count <= 512, let number = value as? NSNumber,
                  number.doubleValue.isFinite else {
                throw AgentPositionValidationError.invalidScope
            }
            result[key] = number.doubleValue
        }
        return result
    }

    public static func encode(_ dictionary: [String: Double]) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: dictionary, format: .binary, options: 0
        )
    }
}

public struct AgentPositionPlan: Codable, Equatable, Sendable {
    public static let domain = "com.apple.MenuBarAgent"
    public static let preferenceKey = "TrailingItemPreferredPositions"
    public static let bundleIdentifier = "xyz.fi5h.blenny"
    public static let autosaveName = "Blenny0.7.0AgentPositionValidation"
    public static let targetIdentifier = "status:\(bundleIdentifier)::\(autosaveName)"
    public static let weight = 700.0
    public static let durationSeconds = 60

    public let schemaVersion: Int
    public let baseline: AgentPositionSnapshot
    public let runtime: RuntimeEnvironment

    public init(baseline: AgentPositionSnapshot, runtime: RuntimeEnvironment) throws {
        schemaVersion = 1
        self.baseline = baseline
        self.runtime = runtime
        try validate()
    }

    public func validate() throws {
        guard schemaVersion == 1, runtime.buildVersion == "26A5416b",
              runtime.macOSVersion == "27.0.0", runtime.architecture == "arm64",
              try baseline.dictionary()?[Self.targetIdentifier] == nil else {
            throw AgentPositionValidationError.invalidScope
        }
    }

    public var applied: AgentPositionSnapshot {
        get throws {
            var dictionary = try baseline.dictionary() ?? [:]
            dictionary[Self.targetIdentifier] = Self.weight
            return try AgentPositionSnapshot(encodedDictionary:
                AgentPositionSnapshot.encode(dictionary))
        }
    }

    public var fingerprint: String {
        get throws {
            struct Binding: Encodable {
                let plan: AgentPositionPlan
                let domain: String
                let key: String
                let target: String
                let weight: Double
                let seconds: Int
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let binding = Binding(plan: self, domain: Self.domain,
                key: Self.preferenceKey, target: Self.targetIdentifier,
                weight: Self.weight, seconds: Self.durationSeconds)
            return SHA256.hash(data: try encoder.encode(binding))
                .map { String(format: "%02x", $0) }.joined()
        }
    }

    public static var writerToken: RevealAllowlistPlan {
        RevealAllowlistPlan(presentation: .baseline, allowedSystemItems: [],
            allowedBundleIdentifiers: [bundleIdentifier])
    }
}

@MainActor
public protocol AgentPositionValidationBackend: AnyObject, Sendable {
    func capture() throws -> AgentPositionSnapshot
    func apply(_ snapshot: AgentPositionSnapshot) throws
    func restore(_ snapshot: AgentPositionSnapshot) throws
}

@MainActor
public final class AgentPositionValidationLease: RevealAssertionCandidate {
    private let backend: any AgentPositionValidationBackend
    private let plan: AgentPositionPlan
    private let confirmation: String
    private let recoveryOnly: Bool
    private var stopped = false
    private var touched = false
    private var recoveryAttempted = false
    public private(set) var restoreVerified = false
    public private(set) var failure: String?

    public init(backend: any AgentPositionValidationBackend, plan: AgentPositionPlan,
                confirmation: String, recoveryOnly: Bool = false) {
        self.backend = backend
        self.plan = plan
        self.confirmation = confirmation
        self.recoveryOnly = recoveryOnly
    }

    public nonisolated func activate() async throws { try await applyOnMain() }

    private func applyOnMain() throws {
        guard !stopped else { throw AgentPositionValidationError.stopped }
        try plan.validate()
        let expected = try plan.fingerprint + (recoveryOnly ? ":restore" : "")
        guard confirmation == expected else { throw AgentPositionValidationError.unconfirmedPlan }
        let current = try backend.capture()
        if recoveryOnly {
            guard current == (try plan.applied) else { throw AgentPositionValidationError.staleState }
            recoveryAttempted = true
            try backend.restore(plan.baseline)
            guard try backend.capture() == plan.baseline else {
                throw AgentPositionValidationError.restoreFailed
            }
            restoreVerified = true
            return
        }
        guard current == plan.baseline else { throw AgentPositionValidationError.staleState }
        touched = true
        try backend.apply(plan.applied)
        guard try backend.capture() == plan.applied else {
            throw AgentPositionValidationError.unexpectedStateChange
        }
    }

    public nonisolated func invalidate() async { await restoreOnMain() }

    private func restoreOnMain() {
        guard !stopped else { return }
        stopped = true
        if recoveryAttempted { return }
        guard touched else {
            restoreVerified = true
            return
        }
        do {
            try backend.restore(plan.baseline)
            guard try backend.capture() == plan.baseline else {
                throw AgentPositionValidationError.restoreFailed
            }
            restoreVerified = true
        } catch {
            failure = String(describing: error)
            restoreVerified = false
        }
    }
}

public struct AgentPositionValidationFactory: RevealAssertionCandidateFactory {
    public let lease: AgentPositionValidationLease
    public init(lease: AgentPositionValidationLease) { self.lease = lease }
    public func makeCandidate(for plan: RevealAllowlistPlan) throws -> any RevealAssertionCandidate {
        guard plan == AgentPositionPlan.writerToken else {
            throw AgentPositionValidationError.invalidScope
        }
        return lease
    }
}

@MainActor
public final class MacOS27AgentPositionBackend: AgentPositionValidationBackend {
    private let createItems: @MainActor (String) throws -> Void
    private let removeItems: @MainActor () -> Void
    private var created = false

    public init(createItems: @escaping @MainActor (String) throws -> Void,
                removeItems: @escaping @MainActor () -> Void) {
        self.createItems = createItems
        self.removeItems = removeItems
    }

    public func capture() throws -> AgentPositionSnapshot {
        guard Bundle.main.bundleIdentifier == AgentPositionPlan.bundleIdentifier else {
            throw AgentPositionValidationError.invalidScope
        }
        let raw = CFPreferencesCopyValue(AgentPositionPlan.preferenceKey as CFString,
            AgentPositionPlan.domain as CFString, kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost)
        guard let raw else { return try AgentPositionSnapshot(encodedDictionary: nil) }
        guard let dictionary = raw as? [String: Any] else {
            throw AgentPositionValidationError.invalidScope
        }
        return try AgentPositionSnapshot(encodedDictionary:
            PropertyListSerialization.data(fromPropertyList: dictionary, format: .binary, options: 0))
    }

    public func apply(_ snapshot: AgentPositionSnapshot) throws {
        try createItems(AgentPositionPlan.autosaveName)
        created = true
        try write(snapshot)
    }

    public func restore(_ snapshot: AgentPositionSnapshot) throws {
        if created {
            removeItems()
            created = false
        }
        try write(snapshot)
    }

    private func write(_ snapshot: AgentPositionSnapshot) throws {
        let value = try snapshot.dictionary()
        CFPreferencesSetValue(AgentPositionPlan.preferenceKey as CFString,
            value as CFPropertyList?, AgentPositionPlan.domain as CFString,
            kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(AgentPositionPlan.domain as CFString,
            kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            throw AgentPositionValidationError.restoreFailed
        }
    }
}
#endif
