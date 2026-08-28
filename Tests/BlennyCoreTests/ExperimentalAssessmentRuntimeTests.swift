#if DEBUG
import Testing
@testable import BlennyCore

@Suite("Debug-only macOS 27 assessment runtime")
struct ExperimentalAssessmentRuntimeTests {
    @Test("Expected classes, selectors, and exact encodings are available")
    func runtimeSurfaceMatches() throws {
        _ = try ExperimentalMacOS27AssessmentFactory()
    }

    @Test("Configuration round-trips without activating an assertion")
    func configurationRoundTrips() throws {
        let factory = try ExperimentalMacOS27AssessmentFactory()
        let candidate = try factory.makeCandidate(
            for: RevealAllowlistPlan(
                presentation: .baseline,
                allowedSystemItems: Array(0 ..< 9),
                allowedBundleIdentifiers: ["xyz.fi5h.blenny"]
            )
        )
        _ = candidate
    }
}
#endif
