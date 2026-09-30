import Darwin
import Foundation

/// Durable replacement of Blenny-owned files. The format remains unchanged.
enum DurablePrivateFile {
    static func write(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        var attributes = stat()
        guard lstat(directory.path, &attributes) == 0,
              attributes.st_mode & S_IFMT == S_IFDIR,
              attributes.st_uid == geteuid() else { throw failure() }
        let parent = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parent >= 0 else { throw failure() }
        defer { close(parent) }
        var opened = stat()
        guard fstat(parent, &opened) == 0,
              opened.st_dev == attributes.st_dev, opened.st_ino == attributes.st_ino,
              opened.st_uid == geteuid(), opened.st_mode & S_IFMT == S_IFDIR,
              fchmod(parent, 0o700) == 0 else { throw failure() }
        let temporary = ".blenny-\(UUID().uuidString).tmp"
        let descriptor = openat(parent, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw failure() }
        defer { close(descriptor); unlinkat(parent, temporary, 0) }
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(descriptor, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if count > 0 { offset += count }
                else if count < 0 && errno == EINTR { continue }
                else { throw failure() }
            }
        }
        guard fchmod(descriptor, 0o600) == 0, fsync(descriptor) == 0,
              renameat(parent, temporary, parent, url.lastPathComponent) == 0,
              fsync(parent) == 0 else { throw failure() }
    }

    static func remove(_ url: URL) throws {
        let parent = open(url.deletingLastPathComponent().path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parent >= 0 else { throw failure() }
        defer { close(parent) }
        guard unlinkat(parent, url.lastPathComponent, 0) == 0 || errno == ENOENT,
              fsync(parent) == 0 else { throw failure() }
    }

    private static func failure() -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno == 0 ? EIO : errno))
    }
}
