import Foundation
import Testing
@testable import BlennyCore

@Suite("Event-driven native discovery bootstrap")
struct NativeOverflowDiscoveryEventsTests {
    @Test("Activation bursts consume only the latest sample and never self-repeat")
    func coalescedSingleRead() {
        var sampling = NativeOverflowActivationSample()
        let first = sampling.schedule()
        let latest = sampling.schedule()
        #expect(sampling.consume(first) == false)
        #expect(sampling.consume(latest) == true)
        #expect(sampling.consume(latest) == false)
    }

    @Test("Stop or context loss rejects a late queued sample across restart")
    func cancellation() {
        var sampling = NativeOverflowActivationSample()
        let stopped = sampling.schedule()
        sampling.cancel()
        #expect(sampling.consume(stopped) == false)
        let restarted = sampling.schedule()
        #expect(sampling.consume(stopped) == false)
        #expect(sampling.consume(restarted) == true)
    }

    @Test("An empty root stays subscribed without registration churn")
    func emptyRootKeepsDiscovery() {
        var subscriptions = NativeOverflowRootSubscriptions<Int>()
        var added: [String] = []
        var removed: [String] = []
        #expect(subscriptions.update(to: 1, sameElement: ==,
            register: { _, name in added.append(name); return true },
            unregister: { _, name in removed.append(name) }) == true)
        for _ in 0..<5 {
            #expect(subscriptions.update(to: 1, sameElement: ==,
                register: { _, name in added.append(name); return true },
                unregister: { _, name in removed.append(name) }) == false)
        }
        #expect(added == ["AXLayoutChanged", "AXCreated", "AXUIElementDestroyed"])
        #expect(removed.isEmpty)
        #expect(subscriptions.root == 1)
    }

    @Test("Root replacement and stop remove only successful old subscriptions")
    func rootReplacementAndCleanup() {
        var subscriptions = NativeOverflowRootSubscriptions<Int>()
        var actions: [String] = []
        subscriptions.update(to: 1, sameElement: ==,
            register: { _, name in name != "AXCreated" }, unregister: { _, _ in })
        #expect(subscriptions.registered == ["AXLayoutChanged", "AXUIElementDestroyed"])
        #expect(subscriptions.update(to: 2, sameElement: ==,
            register: { root, name in actions.append("add-\(root)-\(name)"); return true },
            unregister: { root, name in actions.append("remove-\(root)-\(name)") }) == true)
        #expect(Array(actions.prefix(2)) == ["remove-1-AXLayoutChanged", "remove-1-AXUIElementDestroyed"])
        #expect(actions.count == 5)
        subscriptions.clear { root, name in actions.append("remove-\(root)-\(name)") }
        subscriptions.clear { _, _ in Issue.record("Cleanup must be idempotent") }
        #expect(actions.count == 8)
        #expect(subscriptions.root == nil)
        #expect(subscriptions.registered.isEmpty)
    }

    @Test("Failed root registration is bounded until a new binding or explicit refresh")
    func registrationFailureDoesNotLoop() {
        var subscriptions = NativeOverflowRootSubscriptions<Int>()
        var attempts = 0
        for _ in 0..<5 {
            subscriptions.update(to: 1, sameElement: ==,
                register: { _, _ in attempts += 1; return false },
                unregister: { _, _ in Issue.record("Unsuccessful registration is not owned") })
        }
        #expect(attempts == 3)
        #expect(subscriptions.registered.isEmpty)
        subscriptions.clear { _, _ in Issue.record("Nothing was registered") }
        subscriptions.update(to: 1, sameElement: ==,
            register: { _, _ in attempts += 1; return true }, unregister: { _, _ in })
        #expect(attempts == 6)
    }

    @Test("Settled discovery binds a late control without needing a Blenny click", arguments: [false, true])
    func lateControlBootstrap(alreadyRevealed: Bool) throws {
        var sampling = NativeOverflowActivationSample()
        var controls = OrdinaryRevealCoordinator()
        controls.synchronize(.active("baseline"), hasRevealableBundles: true)
        controls.observe(.observed(states: [], controlIdentifier: nil))
        if alreadyRevealed {
            controls.requestBlennyToggle()
            _ = controls.takePendingTransition()
            controls.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        }
        let originalSession = controls.sessionIdentifier
        let ticket = sampling.schedule()
        // The canonical root acquires a control after activation, before the
        // single scheduled sample. No writer completion drives this discovery.
        let identifier = UUID()
        #expect(sampling.consume(ticket) == true)
        controls.observe(.observed(states: [.collapsed], controlIdentifier: identifier), source: .sample)
        #expect(controls.takePendingTransition() == nil)
        #expect(controls.sessionIdentifier == originalSession)
        #expect(controls.observation.isUsable)
        controls.observe(.observed(states: [.expanded], controlIdentifier: identifier), source: .valueChange)
        if !alreadyRevealed {
            #expect(controls.takePendingTransition()?.presentation == .revealed)
            controls.synchronize(.ordinaryRevealSession("reveal"), hasRevealableBundles: true)
        } else {
            #expect(controls.takePendingTransition() == nil)
        }
        controls.observe(.observed(states: [.collapsed], controlIdentifier: identifier), source: .valueChange)
        #expect(controls.takePendingTransition()?.presentation == .baseline)
        #expect(sampling.consume(ticket) == false)
    }

    @Test("Scheduled samples do not reset failed-read budget or activate inactive management")
    func failureAndStoppedSafety() {
        var sampling = NativeOverflowActivationSample()
        var recovery = NativeOverflowReadRecovery()
        recovery.failed()
        recovery.failed()
        let ticket = sampling.schedule()
        #expect(sampling.consume(ticket) == true)
        #expect(!recovery.allowsEventRead)
        var controls = OrdinaryRevealCoordinator()
        controls.observe(.observed(states: [.expanded], controlIdentifier: UUID()), source: .sample)
        #expect(!controls.canToggleBlenny)
        #expect(controls.takePendingTransition() == nil)
    }
}
