import CryptoKit
import Foundation

public enum BundlePolicyIdentity {
    public static func canonicalKey(for bundleIdentifier: String) -> String? {
        let trimmed = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard trimmed == bundleIdentifier,
              !trimmed.isEmpty,
              !trimmed.contains(where: { $0.isWhitespace }),
              components.count >= 2,
              components.allSatisfy({ !$0.isEmpty }),
              trimmed.utf8.allSatisfy({ byte in
                  (byte >= 48 && byte <= 57)
                      || (byte >= 65 && byte <= 90)
                      || (byte >= 97 && byte <= 122)
                      || byte == 45
                      || byte == 46
              }) else {
            return nil
        }
        return trimmed.lowercased()
    }
}

public struct PersistentBundlePolicyEntry: Codable, Equatable, Sendable {
    public let bundleIdentifier: String
    public let policy: MenuBarBundlePolicy

    public init(bundleIdentifier: String, policy: MenuBarBundlePolicy) {
        self.bundleIdentifier = bundleIdentifier
        self.policy = policy
    }
}

public enum PersistentBundlePolicyDocumentError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
    case invalidBundleIdentifier(String)
    case duplicateBundleIdentifier(String)
    case missingVisibleBlenny(String)
    case invalidSystemItemIdentifier(String)
    case bluetoothMustUseDedicatedPolicy
    case systemItemPoliciesUnavailable
    case invalidSystemItemPolicySchema
}

public struct PersistentBundlePolicyDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 4

    public let schemaVersion: Int
    public let managementEnabled: Bool
    public let policies: [PersistentBundlePolicyEntry]
    public let bluetoothPolicy: MenuBarBundlePolicy
    public let systemItemPolicies: [String: MenuBarBundlePolicy]

    public init(
        managementEnabled: Bool,
        policies: [PersistentBundlePolicyEntry],
        bluetoothPolicy: MenuBarBundlePolicy = .visible,
        systemItemPolicies: [String: MenuBarBundlePolicy] = [:]
    ) throws {
        var canonicalIdentifiers = Set<String>()
        for entry in policies {
            guard let canonical = BundlePolicyIdentity.canonicalKey(
                for: entry.bundleIdentifier
            ) else {
                throw PersistentBundlePolicyDocumentError.invalidBundleIdentifier(
                    entry.bundleIdentifier
                )
            }
            guard canonicalIdentifiers.insert(canonical).inserted else {
                throw PersistentBundlePolicyDocumentError.duplicateBundleIdentifier(
                    entry.bundleIdentifier
                )
            }
        }

        try Self.validateSystemItemPolicies(systemItemPolicies)

        self.schemaVersion = systemItemPolicies.isEmpty ? 3 : Self.currentSchemaVersion
        self.managementEnabled = managementEnabled
        self.bluetoothPolicy = bluetoothPolicy
        self.systemItemPolicies = systemItemPolicies
        self.policies = policies.sorted {
            ($0.bundleIdentifier.lowercased(), $0.policy.rawValue)
                < ($1.bundleIdentifier.lowercased(), $1.policy.rawValue)
        }
    }

    public func validated(forBlennyBundleIdentifier blennyBundleIdentifier: String) throws -> Self {
        guard let blennyKey = BundlePolicyIdentity.canonicalKey(
            for: blennyBundleIdentifier
        ) else {
            throw PersistentBundlePolicyDocumentError.invalidBundleIdentifier(
                blennyBundleIdentifier
            )
        }
        guard policies.contains(where: { entry in
            entry.policy == .visible
                && BundlePolicyIdentity.canonicalKey(for: entry.bundleIdentifier) == blennyKey
        }) else {
            throw PersistentBundlePolicyDocumentError.missingVisibleBlenny(
                blennyBundleIdentifier
            )
        }
        return self
    }

    public func settingManagementEnabled(_ enabled: Bool) throws -> Self {
        try Self(
            managementEnabled: enabled,
            policies: policies,
            bluetoothPolicy: bluetoothPolicy,
            systemItemPolicies: systemItemPolicies
        )
    }

    public func replacingBundleIdentifier(
        from oldIdentifier: String,
        with newIdentifier: String
    ) throws -> Self {
        guard let oldKey = BundlePolicyIdentity.canonicalKey(for: oldIdentifier) else {
            throw PersistentBundlePolicyDocumentError.invalidBundleIdentifier(oldIdentifier)
        }
        guard let newKey = BundlePolicyIdentity.canonicalKey(for: newIdentifier) else {
            throw PersistentBundlePolicyDocumentError.invalidBundleIdentifier(newIdentifier)
        }
        guard oldKey != newKey else { return self }

        let containsOldIdentifier = policies.contains {
            BundlePolicyIdentity.canonicalKey(for: $0.bundleIdentifier) == oldKey
        }
        guard containsOldIdentifier else { return self }
        guard !policies.contains(where: {
            BundlePolicyIdentity.canonicalKey(for: $0.bundleIdentifier) == newKey
        }) else {
            throw PersistentBundlePolicyDocumentError.duplicateBundleIdentifier(newIdentifier)
        }

        return try Self(
            managementEnabled: managementEnabled,
            policies: policies.map { entry in
                guard BundlePolicyIdentity.canonicalKey(for: entry.bundleIdentifier) == oldKey else {
                    return entry
                }
                return PersistentBundlePolicyEntry(
                    bundleIdentifier: newIdentifier,
                    policy: entry.policy
                )
            },
            bluetoothPolicy: bluetoothPolicy,
            systemItemPolicies: systemItemPolicies
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case managementEnabled
        case policies
        case bluetoothPolicy
        case systemItemPolicies
    }

    private enum LegacyPolicy: String, Decodable {
        case pinned
        case revealable
        case hidden

        var current: MenuBarBundlePolicy {
            switch self {
            case .pinned: .visible
            case .revealable: .revealable
            case .hidden: .hidden
            }
        }
    }

    private struct LegacyEntry: Decodable {
        let bundleIdentifier: String
        let policy: LegacyPolicy
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard (1 ... Self.currentSchemaVersion).contains(schemaVersion) else {
            throw PersistentBundlePolicyDocumentError.unsupportedSchemaVersion(schemaVersion)
        }
        let managementEnabled = try container.decode(Bool.self, forKey: .managementEnabled)
        let policies: [PersistentBundlePolicyEntry]
        if schemaVersion == 1 {
            policies = try container.decode([LegacyEntry].self, forKey: .policies).map {
                PersistentBundlePolicyEntry(
                    bundleIdentifier: $0.bundleIdentifier,
                    policy: $0.policy.current
                )
            }
        } else {
            policies = try container.decode(
                [PersistentBundlePolicyEntry].self,
                forKey: .policies
            )
        }
        let systemItemPolicies = try container.decodeIfPresent(
            [String: MenuBarBundlePolicy].self,
            forKey: .systemItemPolicies
        ) ?? [:]
        guard (schemaVersion == 4) == !systemItemPolicies.isEmpty else {
            throw PersistentBundlePolicyDocumentError.invalidSystemItemPolicySchema
        }
        self = try Self(
            managementEnabled: managementEnabled,
            policies: policies,
            bluetoothPolicy: schemaVersion >= 3
                ? try container.decode(MenuBarBundlePolicy.self, forKey: .bluetoothPolicy)
                : .visible,
            systemItemPolicies: systemItemPolicies
        )
    }

    private static func validateSystemItemPolicies(
        _ policies: [String: MenuBarBundlePolicy]
    ) throws {
        guard !policies.keys.contains("com.apple.menuextra.bluetooth") else {
            throw PersistentBundlePolicyDocumentError.bluetoothMustUseDedicatedPolicy
        }
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        for identifier in policies.keys {
            guard SystemItemPolicyCatalog.controllableItem(for: identifier) != nil
                    || PersistentSystemItemPolicyCatalog.controllableItem(for: identifier) != nil else {
                throw PersistentBundlePolicyDocumentError.invalidSystemItemIdentifier(identifier)
            }
        }
        #else
        guard policies.isEmpty else {
            throw PersistentBundlePolicyDocumentError.systemItemPoliciesUnavailable
        }
        #endif
    }
}

public struct PersistentBundlePolicyBackup: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let previousPolicy: PersistentBundlePolicyDocument

    public init(previousPolicy: PersistentBundlePolicyDocument) {
        self.schemaVersion = Self.currentSchemaVersion
        self.previousPolicy = previousPolicy
    }
}

public enum PersistentBundlePolicyStoreError: Error, Equatable, Sendable {
    case readOnlyStore
    case interruptedCommitRequiresRecovery
    case policyAndBackupPathsMustDiffer
    case unsupportedBackupSchemaVersion(Int)
    case interruptedTransactionCorrupt
    case interruptedTransactionStateMismatch
}

struct PersistentBundlePolicyTransactionMarker: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let oldPolicyData: Data
    let newPolicyHash: String
    let oldBackupData: Data?
    let newBackupData: Data

    init(
        oldPolicyData: Data,
        newPolicyHash: String,
        oldBackupData: Data?,
        newBackupData: Data
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.oldPolicyData = oldPolicyData
        self.newPolicyHash = newPolicyHash
        self.oldBackupData = oldBackupData
        self.newBackupData = newBackupData
    }
}

public actor PersistentBundlePolicyStore {
    public let policyURL: URL
    public let backupURL: URL
    let transactionURL: URL
    private let readOnly: Bool

    public init(policyURL: URL, backupURL: URL, readOnly: Bool = false) throws {
        guard policyURL.standardizedFileURL != backupURL.standardizedFileURL else {
            throw PersistentBundlePolicyStoreError.policyAndBackupPathsMustDiffer
        }
        self.policyURL = policyURL
        self.backupURL = backupURL
        self.readOnly = readOnly
        self.transactionURL = policyURL.deletingLastPathComponent().appendingPathComponent(
            ".\(policyURL.lastPathComponent).transaction"
        )
        if readOnly {
            guard !FileManager.default.fileExists(atPath: transactionURL.path) else {
                throw PersistentBundlePolicyStoreError.interruptedCommitRequiresRecovery
            }
        } else {
            try Self.recoverInterruptedCommit(
                policyURL: policyURL, backupURL: backupURL, transactionURL: transactionURL
            )
        }
    }

    public func load() throws -> PersistentBundlePolicyDocument? {
        guard FileManager.default.fileExists(atPath: policyURL.path) else {
            return nil
        }
        return try Self.makeDecoder().decode(
            PersistentBundlePolicyDocument.self,
            from: Data(contentsOf: policyURL)
        )
    }

    public func loadBackup() throws -> PersistentBundlePolicyBackup? {
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            return nil
        }
        let backup = try Self.makeDecoder().decode(
            PersistentBundlePolicyBackup.self,
            from: Data(contentsOf: backupURL)
        )
        guard backup.schemaVersion == PersistentBundlePolicyBackup.currentSchemaVersion else {
            throw PersistentBundlePolicyStoreError.unsupportedBackupSchemaVersion(
                backup.schemaVersion
            )
        }
        return backup
    }

    public func save(_ document: PersistentBundlePolicyDocument) throws {
        guard !readOnly else { throw PersistentBundlePolicyStoreError.readOnlyStore }
        guard let existing = try load() else {
            try write(Self.makeEncoder().encode(document), to: policyURL)
            return
        }
        guard existing != document else { return }

        let oldPolicyData = try Data(contentsOf: policyURL)
        let newPolicyData = try Self.makeEncoder().encode(document)
        let newBackupData = try Self.makeEncoder().encode(
            PersistentBundlePolicyBackup(previousPolicy: existing)
        )
        let oldBackupData = FileManager.default.fileExists(atPath: backupURL.path)
            ? try Data(contentsOf: backupURL) : nil
        let marker = PersistentBundlePolicyTransactionMarker(
            oldPolicyData: oldPolicyData,
            newPolicyHash: Self.hash(newPolicyData),
            oldBackupData: oldBackupData,
            newBackupData: newBackupData
        )
        try write(Self.makeEncoder().encode(marker), to: transactionURL)

        do {
            try write(newBackupData, to: backupURL)
            try write(newPolicyData, to: policyURL)
            guard try load() == document,
                  try loadBackup()?.previousPolicy == existing,
                  try Self.permissions(of: policyURL) == 0o600,
                  try Self.permissions(of: backupURL) == 0o600 else {
                throw PersistentBundlePolicyStoreError.interruptedTransactionCorrupt
            }
            try removeTransactionMarker()
        } catch {
            try Self.recoverInterruptedCommit(
                policyURL: policyURL,
                backupURL: backupURL,
                transactionURL: transactionURL
            )
            if try load() == document,
               try loadBackup()?.previousPolicy == existing {
                return
            }
            throw error
        }
    }

    @discardableResult
    public func migrateBundleIdentifier(
        from oldIdentifier: String,
        to newIdentifier: String
    ) throws -> Bool {
        guard !readOnly else { throw PersistentBundlePolicyStoreError.readOnlyStore }
        guard BundlePolicyIdentity.canonicalKey(for: oldIdentifier) != nil else {
            throw PersistentBundlePolicyDocumentError.invalidBundleIdentifier(oldIdentifier)
        }
        guard BundlePolicyIdentity.canonicalKey(for: newIdentifier) != nil else {
            throw PersistentBundlePolicyDocumentError.invalidBundleIdentifier(newIdentifier)
        }
        let existingPolicy = try load()
        let existingBackup = try loadBackup()
        let migratedPolicy = try existingPolicy?.replacingBundleIdentifier(
            from: oldIdentifier,
            with: newIdentifier
        )
        let migratedBackupPolicy = try existingBackup?.previousPolicy.replacingBundleIdentifier(
            from: oldIdentifier,
            with: newIdentifier
        )

        let policyChanged = migratedPolicy != existingPolicy
        let backupChanged = migratedBackupPolicy != existingBackup?.previousPolicy
        guard policyChanged || backupChanged else { return false }

        if backupChanged, let migratedBackupPolicy {
            try write(
                Self.makeEncoder().encode(
                    PersistentBundlePolicyBackup(previousPolicy: migratedBackupPolicy)
                ),
                to: backupURL
            )
        }
        if policyChanged, let migratedPolicy {
            try write(Self.makeEncoder().encode(migratedPolicy), to: policyURL)
        }
        return true
    }

    @discardableResult
    public func disableManagement() throws -> PersistentBundlePolicyDocument? {
        guard let existing = try load() else { return nil }
        let disabled = try existing.settingManagementEnabled(false)
        try save(disabled)
        return disabled
    }

    #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    /// Disables only the isolated manual system-item trial document without
    /// rotating its reviewed recovery backup.
    @discardableResult
    public func disableManualTrialManagementPreservingBackup() throws
        -> PersistentBundlePolicyDocument? {
        guard !readOnly else { throw PersistentBundlePolicyStoreError.readOnlyStore }
        guard let existing = try load() else { return nil }
        guard existing.managementEnabled else { return existing }
        let disabled = try existing.settingManagementEnabled(false)
        try write(Self.makeEncoder().encode(disabled), to: policyURL)
        guard try load() == disabled,
              try Self.permissions(of: policyURL) == 0o600 else {
            throw PersistentBundlePolicyStoreError.interruptedTransactionCorrupt
        }
        return disabled
    }
    #endif

    @discardableResult
    public func restoreBackup() throws -> PersistentBundlePolicyDocument? {
        guard !readOnly else { throw PersistentBundlePolicyStoreError.readOnlyStore }
        guard let backup = try loadBackup() else { return nil }
        try write(Self.makeEncoder().encode(backup.previousPolicy), to: policyURL)
        return backup.previousPolicy
    }

    private func write(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    private func removeTransactionMarker() throws {
        guard FileManager.default.fileExists(atPath: transactionURL.path) else { return }
        try FileManager.default.removeItem(at: transactionURL)
    }

    private static func recoverInterruptedCommit(
        policyURL: URL,
        backupURL: URL,
        transactionURL: URL
    ) throws {
        guard FileManager.default.fileExists(atPath: transactionURL.path) else { return }
        let marker = try makeDecoder().decode(
            PersistentBundlePolicyTransactionMarker.self,
            from: Data(contentsOf: transactionURL)
        )
        guard marker.schemaVersion
            == PersistentBundlePolicyTransactionMarker.currentSchemaVersion,
              hash(marker.oldPolicyData) != marker.newPolicyHash else {
            throw PersistentBundlePolicyStoreError.interruptedTransactionCorrupt
        }

        let policyData = FileManager.default.fileExists(atPath: policyURL.path)
            ? try Data(contentsOf: policyURL) : nil
        switch policyData.map(hash) {
        case marker.newPolicyHash:
            try writeRecovered(marker.newBackupData, to: backupURL)
        case hash(marker.oldPolicyData):
            try restorePreviousBackup(marker.oldBackupData, at: backupURL)
        case nil:
            try writeRecovered(marker.oldPolicyData, to: policyURL)
            try restorePreviousBackup(marker.oldBackupData, at: backupURL)
        default:
            throw PersistentBundlePolicyStoreError.interruptedTransactionStateMismatch
        }
        try FileManager.default.removeItem(at: transactionURL)
    }

    private static func restorePreviousBackup(_ data: Data?, at url: URL) throws {
        if let data {
            try writeRecovered(data, to: url)
        } else if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private static func writeRecovered(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func permissions(of url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }
}
