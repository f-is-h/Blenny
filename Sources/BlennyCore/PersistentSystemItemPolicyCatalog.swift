import Foundation

public struct PersistentSystemItemPolicyCatalogItem: Hashable, Sendable {
    public let identifier: String
    public let displayName: String

    public init(identifier: String, displayName: String) {
        self.identifier = identifier
        self.displayName = displayName
    }
}

/// Exact system-item identities whose visibility is controlled by a durable,
/// item-scoped preference transaction rather than the assessment allowlist.
public enum PersistentSystemItemPolicyCatalog {
    #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    public static let items: [PersistentSystemItemPolicyCatalogItem] = [
        .init(identifier: "com.apple.menuextra.now-playing", displayName: "Now Playing"),
        .init(identifier: "com.apple.menuextra.siri", displayName: "Siri"),
        .init(identifier: "com.apple.menuextra.TimeMachine", displayName: "Time Machine"),
        .init(identifier: "com.apple.menuextra.spotlight", displayName: "Spotlight"),
    ]
    #else
    public static let items: [PersistentSystemItemPolicyCatalogItem] = []
    #endif

    public static func controllableItem(
        for identifier: String
    ) -> PersistentSystemItemPolicyCatalogItem? {
        items.first { $0.identifier.lowercased() == identifier.lowercased() }
    }

    /// Resolves the exact persistent-policy item represented by either its
    /// canonical menu-extra identifier or a structured live observation.
    /// Composite observations must name the expected Apple host, exact item
    /// label, and menu-bar-item role; similar labels from another owner remain
    /// ineligible for policy writes.
    public static func controllableItem(
        forObservationIdentifier observationIdentifier: String
    ) -> PersistentSystemItemPolicyCatalogItem? {
        if let exact = controllableItem(for: observationIdentifier) {
            return exact
        }
        guard let observed = liveObservationIdentity(observationIdentifier) else {
            return nil
        }
        return expectedLiveObservations.first { expected in
            expected.ownerBundleIdentifier == observed.ownerBundleIdentifier
                && expected.semanticLabel == observed.semanticLabel
        }.flatMap { controllableItem(for: $0.policyIdentifier) }
    }

    private struct LiveObservationIdentity {
        let ownerBundleIdentifier: String
        let semanticLabel: String
    }

    private struct ExpectedLiveObservation {
        let policyIdentifier: String
        let ownerBundleIdentifier: String
        let semanticLabel: String
    }

    private static let expectedLiveObservations: [ExpectedLiveObservation] = [
        .init(
            policyIdentifier: "com.apple.menuextra.now-playing",
            ownerBundleIdentifier: "com.apple.controlcenter",
            semanticLabel: "now playing"
        ),
        .init(
            policyIdentifier: "com.apple.menuextra.siri",
            ownerBundleIdentifier: "com.apple.systemuiserver",
            semanticLabel: "siri"
        ),
        .init(
            policyIdentifier: "com.apple.menuextra.TimeMachine",
            ownerBundleIdentifier: "com.apple.systemuiserver",
            semanticLabel: "time machine"
        ),
        .init(
            policyIdentifier: "com.apple.menuextra.spotlight",
            ownerBundleIdentifier: "com.apple.campo",
            semanticLabel: "spotlight"
        ),
    ]

    private static func liveObservationIdentity(
        _ observationIdentifier: String
    ) -> LiveObservationIdentity? {
        if let stableComponents = stableIdentityComponents(observationIdentifier) {
            guard stableComponents.count == 7,
                  MenuBarItemIdentityResolver.normalize(stableComponents[0])
                    == "blenny-identity-v2",
                  let owner = MenuBarItemIdentityResolver.normalize(stableComponents[1]),
                  MenuBarItemIdentityResolver.normalize(stableComponents[4])
                    == "axmenubaritem",
                  Int(stableComponents[6]) != nil else { return nil }
            let subrole = MenuBarItemIdentityResolver.normalize(stableComponents[5])
            guard subrole == nil || subrole == "axmenuextra" else { return nil }
            let accessibilityIdentifier = MenuBarItemIdentityResolver.normalize(
                stableComponents[2]
            ) ?? ""
            let semanticLabel = MenuBarItemIdentityResolver.normalize(
                stableComponents[3]
            ) ?? ""
            let label = accessibilityIdentifier.isEmpty
                ? semanticLabel
                : accessibilityIdentifier
            guard !label.isEmpty else { return nil }
            return LiveObservationIdentity(
                ownerBundleIdentifier: owner,
                semanticLabel: label
            )
        }

        guard let normalized = MenuBarItemIdentityResolver.normalize(
            observationIdentifier
        ) else { return nil }
        let components = normalized.split(
            separator: "|",
            omittingEmptySubsequences: false
        ).map(String.init)
        guard components.count == 3,
              components[1].first == ":",
              components[2] == "axmenubaritem" else { return nil }
        return LiveObservationIdentity(
            ownerBundleIdentifier: components[0],
            semanticLabel: String(components[1].dropFirst())
        )
    }

    private static func stableIdentityComponents(_ value: String) -> [String]? {
        let bytes = Array(value.utf8)
        guard bytes.count <= 4_096 else { return nil }
        var index = 0
        var components: [String] = []
        while index < bytes.count {
            guard components.count < 7 else { return nil }
            let lengthStart = index
            while index < bytes.count, bytes[index] >= 48, bytes[index] <= 57 {
                index += 1
            }
            guard index > lengthStart, index < bytes.count, bytes[index] == 58,
                  let length = Int(String(decoding: bytes[lengthStart ..< index], as: UTF8.self))
            else { return nil }
            index += 1
            guard length <= bytes.count - index else { return nil }
            components.append(String(decoding: bytes[index ..< index + length], as: UTF8.self))
            index += length
            if index < bytes.count {
                guard bytes[index] == 124 else { return nil }
                index += 1
            }
        }
        return components.isEmpty ? nil : components
    }
}
