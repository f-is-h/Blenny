#if DEBUG
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
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        guard chmod(directory.path, 0o700) == 0 else {
            throw MenuBarLayoutAccessError.storageUnavailable
        }
        let directoryDescriptor = open(
            directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard directoryDescriptor >= 0 else {
            throw MenuBarLayoutAccessError.storageUnavailable
        }
        defer { close(directoryDescriptor) }
        try validateDirectory(directoryDescriptor)

        let temporaryName = ".layout-access.\(UUID().uuidString).tmp"
        let temporary = openat(
            directoryDescriptor,
            temporaryName,
            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
            0o600
        )
        guard temporary >= 0 else { throw MenuBarLayoutAccessError.storageUnavailable }
        var keepTemporary = true
        defer {
            close(temporary)
            if keepTemporary { unlinkat(directoryDescriptor, temporaryName, 0) }
        }

        var offset = 0
        while offset < data.count {
            let remaining = data.count - offset
            let count = data.withUnsafeBytes { bytes in
                Darwin.write(temporary, bytes.baseAddress!.advanced(by: offset), remaining)
            }
            if count < 0 {
                if errno == EINTR { continue }
                throw MenuBarLayoutAccessError.storageUnavailable
            }
            guard count > 0 else { throw MenuBarLayoutAccessError.storageUnavailable }
            offset += count
        }
        guard fsync(temporary) == 0,
              renameat(
                directoryDescriptor, temporaryName,
                directoryDescriptor, Self.fileName
              ) == 0,
              fsync(directoryDescriptor) == 0 else {
            throw MenuBarLayoutAccessError.storageUnavailable
        }
        keepTemporary = false
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

public final class MenuBarLayoutAccessSession {
    public let expectedFileURL: URL
    private let store: MenuBarLayoutBookmarkStore
    private var activeURL: URL?

    public init(
        store: MenuBarLayoutBookmarkStore,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.store = store
        expectedFileURL = Self.expectedLayoutFileURL(homeDirectory: homeDirectory)
    }

    deinit {
        activeURL?.stopAccessingSecurityScopedResource()
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
        let bookmark = try selectedURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        try store.save(bookmark)
        try activate(bookmark: bookmark)
    }

    private func activate(bookmark: Data) throws {
        var stale = false
        let resolved: URL
        do {
            resolved = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
        } catch {
            throw MenuBarLayoutAccessError.bookmarkResolutionFailed
        }
        guard !stale else { throw MenuBarLayoutAccessError.bookmarkStale }
        try validateSelection(resolved)
        guard resolved.startAccessingSecurityScopedResource() else {
            throw MenuBarLayoutAccessError.securityScopeUnavailable
        }
        let previous = activeURL
        activeURL = resolved
        previous?.stopAccessingSecurityScopedResource()
    }
}
#endif
