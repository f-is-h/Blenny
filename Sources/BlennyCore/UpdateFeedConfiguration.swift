import Foundation

/// Keeps the updater dormant until the bundle contains a complete public feed.
public enum UpdateFeedConfiguration {
    public static func isUsable(feedURL: String?, publicEDKey: String?, allowsLoopback: Bool = false) -> Bool {
        guard let feedURL,
              let components = URLComponents(string: feedURL),
              (components.scheme == "https" ||
               (allowsLoopback && components.scheme == "http" && components.host == "127.0.0.1")),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.fragment == nil,
              let publicEDKey,
              Data(base64Encoded: publicEDKey)?.count == 32 else {
            return false
        }
        return true
    }
}
