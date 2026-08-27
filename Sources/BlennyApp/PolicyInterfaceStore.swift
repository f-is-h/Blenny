import BlennyCore
import Foundation

actor PolicyInterfaceStore: PersistentBundlePolicyStoring {
    private let persistentStore: PersistentBundlePolicyStore
    private let initialPolicy: PersistentBundlePolicyDocument

    init(
        persistentStore: PersistentBundlePolicyStore,
        initialPolicy: PersistentBundlePolicyDocument
    ) {
        self.persistentStore = persistentStore
        self.initialPolicy = initialPolicy
    }

    func load() async throws -> PersistentBundlePolicyDocument? {
        try await persistentStore.load() ?? initialPolicy
    }

    func loadBackup() async throws -> PersistentBundlePolicyBackup? {
        try await persistentStore.loadBackup()
    }

    func save(_ document: PersistentBundlePolicyDocument) async throws {
        try await persistentStore.save(document)
    }

    func restoreBackup() async throws -> PersistentBundlePolicyDocument? {
        try await persistentStore.restoreBackup()
    }
}

enum PolicyInterfaceWriteError: LocalizedError {
    case installedDryRunRequired
    case interfaceStoreUnavailable

    var errorDescription: String? {
        switch self {
        case .installedDryRunRequired:
            return "This plan requires an installed Debug dry-run and explicit authorization before Blenny may create a macOS 27 assertion."
        case .interfaceStoreUnavailable:
            return "The policy store is unavailable. Refresh the bounded menu bar observation and try again."
        }
    }
}
