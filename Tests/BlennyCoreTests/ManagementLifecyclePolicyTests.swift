import Testing
@testable import BlennyCore

@Suite("Lifecycle safety invalidation")
struct ManagementLifecyclePolicyTests {
    private let blenny = "xyz.fi5h.blenny"
    private let managed: Set<String> = ["xyz.fi5h.blenny", "com.example.Revealable", "com.example.Hidden"]
    private let allowed: Set<String> = ["xyz.fi5h.blenny", "com.example.PassThrough"]

    @Test("System context transitions invalidate without producing a replacement plan", arguments: [
        ManagementLifecycleEvent.willSleep, .didWake, .sessionChanged,
        .displayChanged, .spaceChanged, .permissionLost, .menuBarAgentChanged
    ])
    func contextChange(_ event: ManagementLifecycleEvent) {
        #expect(invalidates(event))
        #expect(!event.reason.isEmpty)
    }

    @Test("New applications cannot be silently restricted by the frozen allow-list")
    func newApp() {
        #expect(invalidates(.applicationLaunched("com.example.NewApp")))
        #expect(invalidates(.applicationLaunched(nil)))
        #expect(!invalidates(.applicationLaunched("com.example.PassThrough")))
        #expect(!invalidates(.applicationTerminated("com.example.PassThrough")))
    }

    @Test("Managed quit and replacement invalidate while Blenny does not invalidate itself")
    func managedReplacement() {
        #expect(invalidates(.applicationTerminated("com.example.Revealable")))
        #expect(invalidates(.applicationLaunched("com.example.Hidden")))
        #expect(invalidates(.applicationLaunched("COM.EXAMPLE.REVEALABLE")))
        #expect(!invalidates(.applicationLaunched(blenny)))
        #expect(!invalidates(.applicationTerminated(blenny)))
        #expect(!invalidates(.applicationTerminated(nil)))
    }

    private func invalidates(_ event: ManagementLifecycleEvent) -> Bool {
        ManagementLifecyclePolicy.invalidates(
            event, managedBundleIdentifiers: managed, allowedBundleIdentifiers: allowed,
            blennyBundleIdentifier: blenny
        )
    }
}
