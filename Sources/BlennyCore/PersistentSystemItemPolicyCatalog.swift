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
    ]
    #else
    public static let items: [PersistentSystemItemPolicyCatalogItem] = []
    #endif

    public static func controllableItem(
        for identifier: String
    ) -> PersistentSystemItemPolicyCatalogItem? {
        items.first { $0.identifier.lowercased() == identifier.lowercased() }
    }
}
