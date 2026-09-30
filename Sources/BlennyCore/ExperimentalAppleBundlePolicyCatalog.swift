import Foundation

/// Exact owning bundles admitted only by the owner-operated Debug trial.
/// These are application-level assertion identities, not system-item numbers.
public enum ExperimentalAppleBundlePolicyCatalog {
    #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    private static let displayNames: [String: String] = [
        "com.apple.textinputmenuagent": "Input Menu",
        "com.apple.weather.menu": "Weather",
    ]
    public static let bundleIdentifiers = Set(displayNames.keys)
    #else
    public static let bundleIdentifiers: Set<String> = []
    #endif

    public static func contains(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier,
              let canonical = BundlePolicyIdentity.canonicalKey(for: bundleIdentifier) else {
            return false
        }
        return bundleIdentifiers.contains(canonical)
    }

    public static func displayName(for bundleIdentifier: String?) -> String? {
        guard let bundleIdentifier,
              let canonical = BundlePolicyIdentity.canonicalKey(for: bundleIdentifier) else {
            return nil
        }
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        return displayNames[canonical]
        #else
        return nil
        #endif
    }
}
