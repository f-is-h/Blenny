import ApplicationServices
import Foundation
import Testing
@testable import BlennyCore

@Suite("Application discovery evidence")
struct ApplicationMenuBarDiscoveryTests {
    private let application = RunningApplicationDescriptor(
        processIdentifier: 42, bundleIdentifier: "com.example.StatusApp"
    )

    @Test("Communication failure is not evidence that an application has no item")
    func failedRoot() {
        let result = discovery(.cannotComplete, root: false)
        #expect(result.outcome == .unavailable)
        #expect(result.failureDescription?.contains("AX -25204") == true)
    }

    @Test("Absent and unsupported roots are distinguished from failed reads", arguments: [
        AXError.noValue, .attributeUnsupported
    ])
    func noRoot(_ error: AXError) {
        let result = discovery(error, root: false)
        #expect(result.outcome == .noExtrasMenuBar)
        #expect(result.failureDescription == nil)
    }

    @Test("A malformed successful root does not become a discovery success")
    func malformedRoot() {
        #expect(discovery(.success, root: false).outcome == .unavailable)
    }

    @Test("Successful discovery records evidence but creates no ownership or authorization")
    func successIsNotAuthorization() throws {
        let result = discovery(.success, root: true)
        #expect(result.outcome == .observed)
        #expect(result.observationCount == 0)
        let report = DiagnosticReport(
            generatedAt: Date(timeIntervalSince1970: 0),
            environment: .init(macOSVersion: "27.0", buildVersion: "test", architecture: "arm64"),
            accessibilityTrusted: true, durationMilliseconds: 1,
            runningApplicationsChecked: 1, extrasMenuBarTreesFound: 1, menuBarAgentProcessesFound: 0,
            elementLimitReached: false, timeLimitReached: false, aggregateErrors: [:], notes: [],
            items: [], applicationDiscoveries: [result]
        )
        let snapshot = MenuBarOwnershipSnapshotBuilder.make(from: report)
        #expect(snapshot.observations.isEmpty)
        #expect(PolicyCandidateInventory(observations: snapshot.observations).candidates.isEmpty)
        let encoded = try JSONEncoder().encode(report)
        #expect(try JSONDecoder().decode(DiagnosticReport.self, from: encoded) == report)
    }

    private func discovery(_ error: AXError, root: Bool) -> ApplicationMenuBarDiscovery {
        ApplicationMenuBarDiscovery(application: application, rootReadResult: error.rawValue,
                                    hasValidRoot: root, observationCount: 0)
    }
}
