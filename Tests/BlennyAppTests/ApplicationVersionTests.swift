import Testing
@testable import BlennyApp

struct ApplicationVersionTests {
    @Test func publicDisplayAndRecoveryIdentityHaveDifferentPurposes() {
        #expect(BlennyApplicationVersion.display == BlennyApplicationVersion.marketingVersion)
        #expect(!BlennyApplicationVersion.display.contains("(Build "))
        #expect(BlennyApplicationVersion.diagnosticIdentity ==
            "\(BlennyApplicationVersion.marketingVersion) (Build \(BlennyApplicationVersion.buildNumber))")
    }
}
