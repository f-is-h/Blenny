#if BLENNY_PRODUCT || DEBUG
import Darwin
import Foundation

/// A single operation-scoped notification, not a preference polling loop.
/// Atomic plist replacement is observed on the old vnode via rename/delete.
final class OrderingPreferenceFileChange: @unchecked Sendable {
    private let source: DispatchSourceFileSystemObject
    private let queue = DispatchQueue(label: "xyz.fi5h.blenny.ordering-file-settle")
    private let lock = NSLock()
    private var finished = false
    private var changed = false
    private var continuation: CheckedContinuation<Void, Never>?

    init?(url: URL) {
        let descriptor = open(url.path, O_EVTONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { return nil }
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: queue
        )
        source.setEventHandler { [weak self] in self?.finish(changed: true) }
        source.setCancelHandler { close(descriptor) }
        source.resume()
    }

    deinit { source.cancel() }

    func wait(timeout: DispatchTimeInterval = .seconds(15)) async throws -> Bool {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let alreadyFinished = lock.withLock {
                    if finished { return true }
                    self.continuation = continuation
                    return false
                }
                if alreadyFinished { continuation.resume() }
                else { queue.asyncAfter(deadline: .now() + timeout) { [weak self] in self?.finish() } }
            }
        } onCancel: { self.cancel() }
        try Task.checkCancellation()
        return lock.withLock { changed }
    }

    func cancel() {
        finish()
        source.cancel()
    }

    private func finish(changed: Bool = false) {
        let pending: CheckedContinuation<Void, Never>? = lock.withLock {
            guard !finished else { return nil }
            finished = true
            self.changed = changed
            let pending = continuation
            continuation = nil
            return pending
        }
        pending?.resume()
    }
}
#endif
