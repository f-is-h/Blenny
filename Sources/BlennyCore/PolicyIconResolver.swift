import Foundation

/// A presentation-only icon choice. This type is intentionally neither Codable nor part of
/// any policy, draft, report, or assertion model.
public enum PolicyIconDescriptor: Equatable, Sendable {
    case installedApplication
    case systemSymbol(name: String)
    case fallback

    public static let fallbackSymbolName = "questionmark.square.dashed"

    public var usesFallback: Bool {
        if case .fallback = self { return true }
        return false
    }

    public var symbolName: String? {
        switch self {
        case .installedApplication:
            nil
        case let .systemSymbol(name):
            name
        case .fallback:
            Self.fallbackSymbolName
        }
    }
}

public enum PolicyIconResolver {
    public static func applicationDescriptor(
        bundleIdentifier: String,
        installedApplicationResolved: Bool
    ) -> PolicyIconDescriptor {
        guard BundlePolicyIdentity.canonicalKey(for: bundleIdentifier) != nil,
              installedApplicationResolved else {
            return .fallback
        }
        return .installedApplication
    }

    public static func applicationDescriptors(
        candidates: [PolicyCandidate],
        resolvedBundleIdentifiers: Set<String>
    ) -> [String: PolicyIconDescriptor] {
        let resolved = Set(
            resolvedBundleIdentifiers.compactMap(BundlePolicyIdentity.canonicalKey)
        )
        return Dictionary(uniqueKeysWithValues: candidates.map { candidate in
            let canonical = BundlePolicyIdentity.canonicalKey(
                for: candidate.bundleIdentifier
            )
            return (
                candidate.bundleIdentifier,
                applicationDescriptor(
                    bundleIdentifier: candidate.bundleIdentifier,
                    installedApplicationResolved: canonical.map(resolved.contains) ?? false
                )
            )
        })
    }

    public static func systemItemDescriptor(
        observationIdentifier: String
    ) -> PolicyIconDescriptor {
        let normalized = MenuBarItemIdentityResolver.normalize(observationIdentifier) ?? ""
        for mapping in systemMappings where mapping.matches(normalized) {
            return .systemSymbol(name: mapping.symbolName)
        }
        return .fallback
    }

    private struct SystemMapping {
        let stableIdentityTokens: [String]
        let symbolName: String

        func matches(_ normalizedIdentifier: String) -> Bool {
            stableIdentityTokens.contains { normalizedIdentifier.contains($0) }
        }
    }

    /// The tokens are stable Accessibility identifiers or normalized semantic components of a
    /// `MenuBarItemIdentity.stableKey`. Display names and current menu-bar pixels are not inputs.
    private static let systemMappings: [SystemMapping] = [
        .init(
            stableIdentityTokens: ["com.apple.menuextra.bluetooth", ":bluetooth|"],
            symbolName: "antenna.radiowaves.left.and.right"
        ),
        .init(
            stableIdentityTokens: ["com.apple.menuextra.clock", ":clock|"],
            symbolName: "clock"
        ),
        .init(
            stableIdentityTokens: ["com.apple.menuextra.controlcenter", ":control center|"],
            symbolName: "switch.2"
        ),
        .init(
            stableIdentityTokens: ["com.apple.menuextra.now-playing", ":now playing|"],
            symbolName: "play.circle"
        ),
        .init(
            stableIdentityTokens: ["com.apple.menuextra.sound", ":sound|"],
            symbolName: "speaker.wave.2"
        ),
        .init(
            stableIdentityTokens: ["com.apple.menuextra.wifi", ":wi-fi|", ":wifi|"],
            symbolName: "wifi"
        ),
        .init(
            stableIdentityTokens: ["com.apple.menuextra.siri", ":siri|"],
            symbolName: "sparkles"
        ),
        .init(
            stableIdentityTokens: ["com.apple.weather.menu", ":weather|"],
            symbolName: "cloud.sun"
        ),
        .init(
            stableIdentityTokens: [
                "com.apple.menuextra.textinput",
                "com.apple.textinputmenuagent",
                ":input source|",
            ],
            symbolName: "keyboard"
        ),
        .init(
            stableIdentityTokens: ["com.apple.menuextra.timemachine", ":time machine|"],
            symbolName: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        ),
    ]
}
