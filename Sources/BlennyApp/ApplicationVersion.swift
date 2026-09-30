import Foundation

enum BlennyApplicationVersion {
    static var marketingVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "unknown"
    }

    static var buildNumber: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "unknown"
    }

    static var display: String {
        marketingVersion
    }

    static var diagnosticIdentity: String {
        "\(marketingVersion) (Build \(buildNumber))"
    }
}
