/// One pending read per external activation burst. Consuming a ticket never
/// schedules another read; cancellation also invalidates already-queued work.
struct NativeOverflowActivationSample {
    private var generation: UInt64 = 0
    private var pending: UInt64?

    mutating func schedule() -> UInt64 {
        generation &+= 1
        pending = generation
        return generation
    }

    mutating func consume(_ ticket: UInt64) -> Bool {
        guard pending == ticket else { return false }
        pending = nil
        return true
    }

    mutating func cancel() { pending = nil }
}

/// Retain discovery subscriptions even when a root has no overflow child.
/// Root replacement removes exactly the preceding successful subscriptions.
/// An unsupported notification is attempted once, not retried on every scan.
struct NativeOverflowRootSubscriptions<Element> {
    private(set) var root: Element?
    private(set) var registered: [String] = []
    let notifications = ["AXLayoutChanged", "AXCreated", "AXUIElementDestroyed"]

    func contains(_ element: Element, sameElement: (Element, Element) -> Bool) -> Bool {
        root.map { sameElement($0, element) } ?? false
    }

    @discardableResult
    mutating func update(
        to next: Element,
        sameElement: (Element, Element) -> Bool,
        register: (Element, String) -> Bool,
        unregister: (Element, String) -> Void
    ) -> Bool {
        guard !contains(next, sameElement: sameElement) else { return false }
        clear(unregister: unregister)
        root = next
        for name in notifications where register(next, name) { registered.append(name) }
        return true
    }

    mutating func clear(unregister: (Element, String) -> Void) {
        if let root {
            for name in registered { unregister(root, name) }
        }
        registered.removeAll()
        root = nil
    }
}
