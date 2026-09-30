import BlennyCore
import Foundation

/// Reads system preferences only; may renew an existing exact-file bookmark.
/// Omits inventories and preference values.
enum AccessDiagnostic {
    struct Capture: Decodable {
        let groups: [String: [String: OrderingValue]]
        let errors: [String: String]
    }
    static func run() throws -> Data {
        let access = MenuBarLayoutAccessSession(store: MenuBarLayoutBookmarkStore(
            directory: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Blenny/DebugOrdering")
        ))
        var bookmarkError: String?
        do { try access.restoreSavedAccess() }
        catch { bookmarkError = error.localizedDescription }
        let data = try withExtendedLifetime(access) {
            try MacOS27MenuBarOrderingBackend.preferenceReadDiagnostic(bookmarkError: bookmarkError)
        }
        let capture = try JSONDecoder().decode(Capture.self, from: data)
        let before = capture.groups["fileBefore"]
        let api = capture.groups["container"]
        let after = capture.groups["fileAfter"]
        let agree = before != nil && before == api && api == after
        let report: [String: Any] = [
            "deviceControlGranted": AccessibilityAuthorization.isTrusted,
            "layoutBookmarkActive": access.isActive,
            "completeLayoutReadsAgree": agree,
            "errors": capture.errors,
            "systemVersion": ProcessInfo.processInfo.operatingSystemVersionString,
        ]
        return try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    }
}
