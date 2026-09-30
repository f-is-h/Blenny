import Foundation
import Testing

@testable import BlennyCore

@Suite("Sparkle feed configuration")
struct UpdateFeedConfigurationTests {
    private let publicKey = Data(repeating: 0x42, count: 32).base64EncodedString()

    @Test("A complete HTTPS feed and Ed25519 public key enable manual checks")
    func completeConfiguration() {
        #expect(UpdateFeedConfiguration.isUsable(
            feedURL: "https://example.org/blenny/appcast.xml",
            publicEDKey: publicKey
        ))
    }

    @Test("Loopback is confined to explicitly enabled fixtures")
    func loopbackFixture() {
        let feed = "http://127.0.0.1:8765/appcast.xml"
        #expect(!UpdateFeedConfiguration.isUsable(feedURL: feed, publicEDKey: publicKey))
        #expect(UpdateFeedConfiguration.isUsable(feedURL: feed, publicEDKey: publicKey, allowsLoopback: true))
        for invalid in ["http://localhost:8765/appcast.xml", "http://example.org/appcast.xml", "http://127.0.0.2/appcast.xml"] {
            #expect(!UpdateFeedConfiguration.isUsable(feedURL: invalid, publicEDKey: publicKey, allowsLoopback: true))
        }
    }

    @Test("Absent, insecure or malformed feeds leave the updater dormant")
    func incompleteConfiguration() {
        for feed in [
            nil, "", "http://example.org/appcast.xml", "https://",
            "https://user:pass@example.org/appcast.xml",
            "https://example.org/appcast.xml#fragment"
        ] as [String?] {
            #expect(!UpdateFeedConfiguration.isUsable(
                feedURL: feed, publicEDKey: publicKey
            ))
        }
        #expect(!UpdateFeedConfiguration.isUsable(
            feedURL: "https://example.org/appcast.xml", publicEDKey: nil
        ))
        #expect(!UpdateFeedConfiguration.isUsable(
            feedURL: "https://example.org/appcast.xml", publicEDKey: "not-a-key"
        ))
    }
}
