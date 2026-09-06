import Foundation

public struct SystemItemPolicyCatalogItem: Hashable, Sendable {
    public let identifier: String
    public let rawValue: Int
    public let displayName: String

    public init(identifier: String, rawValue: Int, displayName: String) {
        self.identifier = identifier
        self.rawValue = rawValue
        self.displayName = displayName
    }
}

public enum SystemItemPolicyCatalog {
    #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    public static let items: [SystemItemPolicyCatalogItem] = [
        .init(identifier: "com.apple.menuextra.battery", rawValue: 0, displayName: "Battery"),
        .init(identifier: "com.apple.menuextra.bluetooth", rawValue: 1, displayName: "Bluetooth"),
        .init(identifier: "com.apple.menuextra.display", rawValue: 3, displayName: "Display"),
        .init(identifier: "com.apple.menuextra.keyboard-brightness", rawValue: 4, displayName: "Keyboard Brightness"),
        .init(identifier: "com.apple.menuextra.sound", rawValue: 5, displayName: "Sound"),
        .init(identifier: "com.apple.menuextra.wifi", rawValue: 6, displayName: "Wi-Fi"),
        .init(identifier: "com.apple.menuextra.screen-mirroring", rawValue: 7, displayName: "Screen Mirroring"),
        .init(identifier: "com.apple.menuextra.controlcenter", rawValue: 8, displayName: "Control Center"),
    ]
    #else
    public static let items: [SystemItemPolicyCatalogItem] = [
        .init(identifier: "com.apple.menuextra.bluetooth", rawValue: 1, displayName: "Bluetooth"),
    ]
    #endif

    public static func controllableItem(
        for identifier: String
    ) -> SystemItemPolicyCatalogItem? {
        items.first { $0.identifier == identifier }
    }
}
