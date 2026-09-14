import Testing
@testable import BlennyCore

@Suite("Permission grant refresh intent")
struct AccessibilityGrantRefreshTests {
    @Test("Presentation reads do not consume a grant before activation")
    func grantSurvivesPresentationReads() {
        var state = AccessibilityGrantRefreshState()
        state.observe(trusted: false)
        state.observe(trusted: true)
        state.observe(trusted: true)
        #expect(state.pending)
        state.didBeginRefresh()
        state.observe(trusted: true)
        #expect(!state.pending)
    }

    @Test("Blocked refresh retains intent and revocation cancels it")
    func deferredAndRevoked() {
        var state = AccessibilityGrantRefreshState()
        state.observe(trusted: false)
        state.observe(trusted: true)
        #expect(state.pending)
        state.observe(trusted: false)
        #expect(!state.pending)
        state.observe(trusted: true)
        #expect(state.pending)
    }

    @Test("Initially trusted launch does not schedule a duplicate refresh")
    func initiallyTrusted() {
        var state = AccessibilityGrantRefreshState()
        state.observe(trusted: true)
        #expect(!state.pending)
    }
}
