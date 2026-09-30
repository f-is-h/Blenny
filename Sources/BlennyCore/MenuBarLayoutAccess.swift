#if BLENNY_PRODUCT || DEBUG
import Darwin
import Foundation

public enum MenuBarLayoutAccessError: Error, Equatable, LocalizedError {
    case unexpectedSelection(String)
    case bookmarkMissing
    case bookmarkStale
    case bookmarkResolutionFailed
    case securityScopeUnavailable
    case storageUnavailable
    case invalidStorage
    case bookmarkTooLarge

    public var errorDescription: String? {
        switch self {
        case .unexpectedSelection:
            "Choose the menu bar layout file shown in the file picker."
        case .bookmarkMissing:
            "No saved menu bar layout access is available."
        case .bookmarkStale:
            "Saved menu bar layout access is no longer valid. Choose the file again."
        case .bookmarkResolutionFailed:
            "Saved menu bar layout access could not be restored. Choose the file again."
        case .securityScopeUnavailable:
            "macOS did not restore access to the menu bar layout file. Choose the file again."
        case .storageUnavailable:
            "Blenny could not save menu bar layout access."
        case .invalidStorage:
            "Blenny’s saved menu bar layout access does not satisfy its private storage checks."
        case .bookmarkTooLarge:
            "Blenny’s saved menu bar layout access exceeds the bounded storage limit."
        }
    }
}

public struct MenuBarLayoutBookmarkStore {
    public static let fileName = "layout-access.bookmark"
    private static let maximumBookmarkBytes = 64 * 1_024

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory.standardizedFileURL
    }

    public var bookmarkURL: URL {
        directory.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    public func load() throws -> Data? {
        let descriptor = open(
            directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        if descriptor < 0 {
            if errno == ENOENT { return nil }
            throw MenuBarLayoutAccessError.storageUnavailable
        }
        defer { close(descriptor) }
        try validateDirectory(descriptor)

        let bookmark = openat(
            descriptor, Self.fileName, O_RDONLY | O_NOFOLLOW | O_CLOEXEC
        )
        if bookmark < 0 {
            if errno == ENOENT { return nil }
            throw MenuBarLayoutAccessError.storageUnavailable
        }
        defer { close(bookmark) }

        var attributes = stat()
        guard fstat(bookmark, &attributes) == 0,
              attributes.st_uid == geteuid(),
              attributes.st_nlink == 1,
              attributes.st_mode & S_IFMT == S_IFREG,
              attributes.st_mode & 0o777 == 0o600,
              attributes.st_size > 0 else {
            throw MenuBarLayoutAccessError.invalidStorage
        }
        guard attributes.st_size <= Self.maximumBookmarkBytes else {
            throw MenuBarLayoutAccessError.bookmarkTooLarge
        }

        var data = Data(count: Int(attributes.st_size))
        var offset = 0
        while offset < data.count {
            let remaining = data.count - offset
            let count = data.withUnsafeMutableBytes { bytes in
                Darwin.read(bookmark, bytes.baseAddress!.advanced(by: offset), remaining)
            }
            if count < 0 {
                if errno == EINTR { continue }
                throw MenuBarLayoutAccessError.storageUnavailable
            }
            guard count > 0 else { throw MenuBarLayoutAccessError.invalidStorage }
            offset += count
        }
        return data
    }

    public func save(_ data: Data) throws {
        guard !data.isEmpty else { throw MenuBarLayoutAccessError.invalidStorage }
        guard data.count <= Self.maximumBookmarkBytes else {
            throw MenuBarLayoutAccessError.bookmarkTooLarge
        }
        do { try DurablePrivateFile.write(data, to: bookmarkURL) }
        catch { throw MenuBarLayoutAccessError.storageUnavailable }
        guard try load() == data else { throw MenuBarLayoutAccessError.invalidStorage }
    }

    private func validateDirectory(_ descriptor: Int32) throws {
        var pathAttributes = stat()
        var openedAttributes = stat()
        guard lstat(directory.path, &pathAttributes) == 0,
              fstat(descriptor, &openedAttributes) == 0,
              pathAttributes.st_dev == openedAttributes.st_dev,
              pathAttributes.st_ino == openedAttributes.st_ino,
              openedAttributes.st_uid == geteuid(),
              openedAttributes.st_mode & S_IFMT == S_IFDIR,
              openedAttributes.st_mode & 0o777 == 0o700 else {
            throw MenuBarLayoutAccessError.invalidStorage
        }
    }
}

struct MenuBarLayoutAccessOperations {
    var resolve: (Data) throws -> (url: URL, stale: Bool)
    var bookmark: (URL) throws -> Data
    var start: (URL) -> Bool
    var stop: (URL) -> Void

    static var system: Self {
        Self(resolve: { data in
            var stale = false
            let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
                              relativeTo: nil, bookmarkDataIsStale: &stale)
            return (url, stale)
        }, bookmark: { url in
            try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        }, start: { $0.startAccessingSecurityScopedResource() }, stop: { $0.stopAccessingSecurityScopedResource() })
    }
}

public final class MenuBarLayoutAccessSession {
    public let expectedFileURL: URL
    private let store: MenuBarLayoutBookmarkStore
    private var activeURL: URL?
    private let operations: MenuBarLayoutAccessOperations

    public init(
        store: MenuBarLayoutBookmarkStore,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.store = store
        operations = .system
        expectedFileURL = Self.expectedLayoutFileURL(homeDirectory: homeDirectory)
    }

    init(store: MenuBarLayoutBookmarkStore, homeDirectory: URL, operations: MenuBarLayoutAccessOperations) {
        self.store = store
        self.operations = operations
        expectedFileURL = Self.expectedLayoutFileURL(homeDirectory: homeDirectory)
    }

    deinit {
        if let activeURL { operations.stop(activeURL) }
    }

    public var isActive: Bool { activeURL != nil }

    public static func expectedLayoutFileURL(homeDirectory: URL) -> URL {
        homeDirectory
            .appendingPathComponent("Library/Group Containers/com.apple.MenuBar", isDirectory: true)
            .appendingPathComponent("Library/Preferences", isDirectory: true)
            .appendingPathComponent("com.apple.MenuBar.plist", isDirectory: false)
            .standardizedFileURL
    }

    public func validateSelection(_ selectedURL: URL) throws {
        let selected = selectedURL.standardizedFileURL.resolvingSymlinksInPath()
        let expected = expectedFileURL.resolvingSymlinksInPath()
        guard selected.path == expected.path else {
            throw MenuBarLayoutAccessError.unexpectedSelection(selected.path)
        }
    }

    @discardableResult
    public func restoreSavedAccess() throws -> Bool {
        guard let bookmark = try store.load() else { return false }
        try activate(bookmark: bookmark)
        return true
    }

    public func grant(selectedURL: URL) throws {
        try validateSelection(selectedURL)
        let bookmark = try operations.bookmark(selectedURL)
        try activate(bookmark: bookmark, persist: true)
    }

    private func activate(bookmark: Data, persist: Bool = false) throws {
        let resolution: (url: URL, stale: Bool)
        do { resolution = try operations.resolve(bookmark) }
        catch { throw MenuBarLayoutAccessError.bookmarkResolutionFailed }
        let resolved = resolution.url
        try validateSelection(resolved)
        guard operations.start(resolved) else {
            throw MenuBarLayoutAccessError.securityScopeUnavailable
        }
        do {
            if resolution.stale {
                // Renew once only after validating and entering the existing exact-file grant.
                try store.save(operations.bookmark(resolved))
            } else if persist {
                try store.save(bookmark)
            }
        } catch {
            operations.stop(resolved)
            throw error
        }
        let previous = activeURL
        activeURL = resolved
        if let previous { operations.stop(previous) }
    }
}
#endif
