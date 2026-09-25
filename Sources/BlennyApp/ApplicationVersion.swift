import Foundation

enum BlennyApplicationVersion {
    static var marketingVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.11.0"
    }

    static var buildNumber: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "unknown"
    }

    static var display: String {
        "\(marketingVersion) (Build \(buildNumber))"
    }
}
