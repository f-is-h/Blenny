import ApplicationServices
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

    @Test("Accepted bundle policy survives launch, quit and replacement without a new writer")
    func managedReplacement() {
        #expect(!invalidates(.applicationTerminated("com.example.Revealable")))
        #expect(!invalidates(.applicationLaunched("com.example.Hidden")))
        #expect(!invalidates(.applicationLaunched("COM.EXAMPLE.REVEALABLE")))
        #expect(!invalidates(.applicationTerminated("com.example.Hidden")))
        #expect(!invalidates(.applicationLaunched(blenny)))
        #expect(!invalidates(.applicationTerminated(blenny)))
        #expect(!invalidates(.applicationTerminated(nil)))
    }

    @Test("An unrelated launch invalidates only with menu-bar ownership or incomplete evidence")
    func assessedUnrelatedLaunch() {
        let application = RunningApplicationDescriptor(
            processIdentifier: 42,
            bundleIdentifier: "com.example.NewApp"
        )
        let noRoot = ApplicationMenuBarDiscovery(
            application: application,
            rootReadResult: AXError.noValue.rawValue,
            hasValidRoot: false,
            observationCount: 0
        )
        let emptyRoot = ApplicationMenuBarDiscovery(
            application: application,
            rootReadResult: AXError.success.rawValue,
            hasValidRoot: true,
            observationCount: 1
        )
        let failed = ApplicationMenuBarDiscovery(
            application: application,
            rootReadResult: AXError.cannotComplete.rawValue,
            hasValidRoot: false,
            observationCount: 0
        )

        #expect(!invalidates(assessment(noRoot, itemCount: 0)))
        #expect(!invalidates(assessment(emptyRoot, itemCount: 0)))
        #expect(invalidates(assessment(emptyRoot, itemCount: 1)))
        #expect(invalidates(assessment(failed, itemCount: 0)))
        #expect(invalidates(assessment(nil, itemCount: 0)))
        #expect(!invalidates(assessment(noRoot, itemCount: 0, complete: false)))
        #expect(invalidates(assessment(emptyRoot, itemCount: 0, complete: false)))
    }

    @Test("Draft-only identity does not inherit accepted-policy lifecycle authority")
    func draftIsNotAcceptedScope() {
        #expect(invalidates(.applicationLaunched("com.example.DraftOnly")))
        #expect(!invalidates(.applicationTerminated("com.example.DraftOnly")))
        // Removing an accepted entry in the unapplied draft cannot revoke it.
        #expect(!invalidates(.applicationLaunched("com.example.Hidden")))
    }

    @Test("Only accepted or pass-through identity exempts a launch, never background process status")
    func launchEligibility() {
        func assess(_ identifier: String?) -> Bool {
            ManagementLifecyclePolicy.requiresLaunchAssessment(
                bundleIdentifier: identifier,
                acceptedBundleIdentifiers: managed,
                allowedBundleIdentifiers: allowed,
                blennyBundleIdentifier: blenny
            )
        }
        #expect(assess("com.example.BackgroundWorker"))
        #expect(!assess("com.example.Hidden"))
        #expect(!assess("COM.EXAMPLE.PASSTHROUGH"))
        #expect(assess("com.example.NewMenuBarApp"))
        #expect(assess(nil))
        #expect(assess("com.apple.controlcenter"))
    }

    private func invalidates(_ event: ManagementLifecycleEvent) -> Bool {
        ManagementLifecyclePolicy.invalidates(
            event, managedBundleIdentifiers: managed, allowedBundleIdentifiers: allowed,
            blennyBundleIdentifier: blenny
        )
    }

    private func assessment(
        _ discovery: ApplicationMenuBarDiscovery?,
        itemCount: Int,
        complete: Bool = true
    ) -> ManagementLifecyclePolicy.ApplicationLaunchAssessment {
        ManagementLifecyclePolicy.assessApplicationLaunch(
            discovery: discovery,
            observedMenuBarItemCount: itemCount,
            captureComplete: complete
        )
    }

    private func invalidates(
        _ assessment: ManagementLifecyclePolicy.ApplicationLaunchAssessment
    ) -> Bool {
        ManagementLifecyclePolicy.invalidates(
            applicationLaunchAssessment: assessment
        )
    }
}
