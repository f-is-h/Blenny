#if BLENNY_PRODUCT || DEBUG
import Darwin
import Foundation

/// Private recovery storage only. This actor never calls a system-layout API.
public actor FallbackPositionRecoveryStore: FallbackPositionRecoveryStoring {
    private let directory: URL
    private var directoryDescriptor: Int32 = -1
    private var lease: Int32 = -1
    private let maximumReceiptBytes = 8 * 1024 * 1024

    public init(directory: URL) { self.directory = directory }

    deinit {
        if lease >= 0 { close(lease) }
        if directoryDescriptor >= 0 { close(directoryDescriptor) }
    }

    public func acquireLease() throws {
        if lease >= 0 {
            try validateDirectory(descriptor: directoryDescriptor)
            return
        }
        guard let boundDirectory = try openDirectory(create: true) else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        var closesDirectory = true
        defer { if closesDirectory { close(boundDirectory) } }

        let descriptor = openat(
            boundDirectory, "fallback.lock",
            O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600
        )
        guard descriptor >= 0 else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        var closesLease = true
        defer { if closesLease { close(descriptor) } }
        var attributes = stat()
        guard fstat(descriptor, &attributes) == 0,
              attributes.st_uid == geteuid(), attributes.st_nlink == 1,
              attributes.st_mode & S_IFMT == S_IFREG,
              attributes.st_mode & 0o777 == 0o600 else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            throw OrderingTransactionError.writerOccupied
        }
        try validateDirectory(descriptor: boundDirectory)
        directoryDescriptor = boundDirectory
        lease = descriptor
        closesDirectory = false
        closesLease = false
    }

    public func releaseLease() {
        if lease >= 0 { close(lease); lease = -1 }
        if directoryDescriptor >= 0 {
            close(directoryDescriptor)
            directoryDescriptor = -1
        }
    }

    public func load() throws -> FallbackPositionReceipt? {
        let descriptor: Int32
        let closesAfterRead: Bool
        if directoryDescriptor >= 0 {
            try validateDirectory(descriptor: directoryDescriptor)
            descriptor = directoryDescriptor
            closesAfterRead = false
        } else {
            guard let opened = try openDirectory(create: false) else { return nil }
            descriptor = opened
            closesAfterRead = true
        }
        defer { if closesAfterRead { close(descriptor) } }
        return try loadReceipt(directoryDescriptor: descriptor)
    }

    public func save(_ receipt: FallbackPositionReceipt) throws {
        guard lease >= 0, directoryDescriptor >= 0 else {
            throw OrderingTransactionError.writerOccupied
        }
        try validateDirectory(descriptor: directoryDescriptor)
        try receipt.validate()
        if let existing = try loadReceipt(directoryDescriptor: directoryDescriptor) {
            guard existing.permitsSuccessor(receipt) else {
                throw OrderingTransactionError.recoveryRequired
            }
        } else if receipt.phase != .applyIntent {
            throw OrderingTransactionError.invalidReceipt
        }
        try write(
            receipt, name: "fallback-recovery.json",
            directoryDescriptor: directoryDescriptor
        )
        guard try loadReceipt(directoryDescriptor: directoryDescriptor) == receipt else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
    }

    public func supersedeCommitted(_ existing: FallbackPositionReceipt,
                                   with replacement: FallbackPositionReceipt, reviewedDrift: Bool) throws {
        guard lease >= 0, directoryDescriptor >= 0 else {
            throw OrderingTransactionError.writerOccupied
        }
        try existing.validate()
        try replacement.validate()
        guard existing.phase == .applied, !existing.isPendingRestoration,
              replacement.phase == .applyIntent, replacement.persistsAfterQuit == true,
              existing.id != replacement.id,
              (reviewedDrift || existing.delta.canBeReplaced(by: replacement.delta)),
              try loadReceipt(directoryDescriptor: directoryDescriptor) == existing else {
            throw OrderingTransactionError.recoveryRequired
        }
        try write(existing, name: "fallback-last-superseded.json", directoryDescriptor: directoryDescriptor)
        guard try loadReceipt(name: "fallback-last-superseded.json",
                              directoryDescriptor: directoryDescriptor) == existing else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        try write(replacement, name: "fallback-recovery.json", directoryDescriptor: directoryDescriptor)
        guard try loadReceipt(directoryDescriptor: directoryDescriptor) == replacement else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
    }

    public func complete(_ receipt: FallbackPositionReceipt) throws {
        guard lease >= 0, directoryDescriptor >= 0,
              receipt.phase == .restored,
              try completionMatches(receipt, existing: loadReceipt(directoryDescriptor: directoryDescriptor)) else {
            throw OrderingTransactionError.invalidReceipt
        }
        try validateDirectory(descriptor: directoryDescriptor)
        try write(
            receipt, name: "fallback-last-restored.json",
            directoryDescriptor: directoryDescriptor
        )
        guard unlinkat(directoryDescriptor, "fallback-recovery.json", 0) == 0 else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        try synchronizeDirectory(descriptor: directoryDescriptor)
    }

    private func completionMatches(
        _ receipt: FallbackPositionReceipt,
        existing: FallbackPositionReceipt?
    ) -> Bool {
        guard let existing else { return false }
        return existing.phase == .restored && existing == receipt
    }

    private func openDirectory(create: Bool) throws -> Int32? {
        if create && !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        let descriptor = open(
            directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        if descriptor < 0 {
            if !create && errno == ENOENT { return nil }
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        do { try validateDirectory(descriptor: descriptor) }
        catch {
            close(descriptor)
            throw error
        }
        return descriptor
    }

    private func validateDirectory(descriptor: Int32) throws {
        guard descriptor >= 0 else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        var pathAttributes = stat()
        var openedAttributes = stat()
        guard lstat(directory.path, &pathAttributes) == 0,
              fstat(descriptor, &openedAttributes) == 0,
              pathAttributes.st_uid == geteuid(), pathAttributes.st_mode & S_IFMT == S_IFDIR,
              pathAttributes.st_mode & 0o777 == 0o700,
              openedAttributes.st_uid == geteuid(), openedAttributes.st_mode & S_IFMT == S_IFDIR,
              openedAttributes.st_mode & 0o777 == 0o700,
              openedAttributes.st_dev == pathAttributes.st_dev,
              openedAttributes.st_ino == pathAttributes.st_ino else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
    }

    private func loadReceipt(
        directoryDescriptor: Int32
    ) throws -> FallbackPositionReceipt? {
        try loadReceipt(
            name: "fallback-recovery.json",
            directoryDescriptor: directoryDescriptor
        )
    }

    private func loadReceipt(
        name: String,
        directoryDescriptor: Int32
    ) throws -> FallbackPositionReceipt? {
        try validateDirectory(descriptor: directoryDescriptor)
        var attributes = stat()
        if fstatat(
            directoryDescriptor, name, &attributes, AT_SYMLINK_NOFOLLOW
        ) != 0 {
            if errno == ENOENT { return nil }
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        guard attributes.st_uid == geteuid(), attributes.st_nlink == 1,
              attributes.st_mode & S_IFMT == S_IFREG,
              attributes.st_mode & 0o777 == 0o600,
              attributes.st_size > 0, attributes.st_size <= maximumReceiptBytes else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        let descriptor = openat(
            directoryDescriptor, name,
            O_RDONLY | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0 else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        defer { close(descriptor) }
        var opened = stat()
        guard fstat(descriptor, &opened) == 0,
              opened.st_ino == attributes.st_ino,
              opened.st_dev == attributes.st_dev,
              opened.st_size == attributes.st_size else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        var data = Data(count: Int(opened.st_size))
        guard readAll(data: &data, descriptor: descriptor) else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        try validateDirectory(descriptor: directoryDescriptor)
        do {
            let receipt = try JSONDecoder().decode(FallbackPositionReceipt.self, from: data)
            try receipt.validate()
            return receipt
        } catch {
            throw OrderingTransactionError.invalidReceipt
        }
    }

    private func write(
        _ receipt: FallbackPositionReceipt,
        name: String,
        directoryDescriptor: Int32
    ) throws {
        try validateDirectory(descriptor: directoryDescriptor)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(receipt)
        guard data.count <= maximumReceiptBytes else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        let temporary = ".fallback-\(UUID().uuidString).tmp"
        let descriptor = openat(
            directoryDescriptor, temporary,
            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600
        )
        guard descriptor >= 0 else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        defer {
            close(descriptor)
            unlinkat(directoryDescriptor, temporary, 0)
        }
        guard fchmod(descriptor, 0o600) == 0,
              writeAll(data: data, descriptor: descriptor),
              fsync(descriptor) == 0,
              renameat(directoryDescriptor, temporary, directoryDescriptor, name) == 0 else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        try synchronizeDirectory(descriptor: directoryDescriptor)
    }

    private func synchronizeDirectory(descriptor: Int32) throws {
        try validateDirectory(descriptor: descriptor)
        guard fsync(descriptor) == 0 else {
            throw OrderingTransactionError.receiptStorageUnavailable
        }
        try validateDirectory(descriptor: descriptor)
    }

    private func readAll(data: inout Data, descriptor: Int32) -> Bool {
        data.withUnsafeMutableBytes { bytes in
            guard let base = bytes.baseAddress else { return bytes.isEmpty }
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.read(
                    descriptor, base.advanced(by: offset), bytes.count - offset
                )
                if count > 0 { offset += count; continue }
                if count < 0 && errno == EINTR { continue }
                return false
            }
            return true
        }
    }

    private func writeAll(data: Data, descriptor: Int32) -> Bool {
        data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return bytes.isEmpty }
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(
                    descriptor, base.advanced(by: offset), bytes.count - offset
                )
                if count > 0 { offset += count; continue }
                if count < 0 && errno == EINTR { continue }
                return false
            }
            return true
        }
    }
}
#endif
