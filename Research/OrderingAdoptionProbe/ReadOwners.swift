// Original, one-shot, Debug-only research. No system preferences or AX writes.
#if !DEBUG
#error("DEBUG required")
#endif
import AppKit
import ApplicationServices

func reject(_ message: String) -> Never { fputs(message + "\n", stderr); exit(2) }
let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 1 else { reject("Pass one JSON list of exact observed owner tokens") }
guard let info = NSDictionary(contentsOfFile: "/System/Library/CoreServices/SystemVersion.plist"),
      info["ProductBuildVersion"] as? String == "26A5425a" else { reject("OS build differs") }
let tokens = Set(try JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: arguments[0]))))
guard tokens.count <= 256 else { reject("Too many tokens") }
let start = Date()
let deadline = ProcessInfo.processInfo.systemUptime + 12
let trusted = AXIsProcessTrusted()

func descriptors() -> [[String: Any]] {
    NSWorkspace.shared.runningApplications.map { app in
        ["pid": app.processIdentifier,
         "bundle": app.bundleIdentifier as Any? ?? NSNull(),
         "executable": app.executableURL?.lastPathComponent as Any? ?? NSNull(),
         "name": app.localizedName as Any? ?? NSNull(),
         "launchTime": app.launchDate?.timeIntervalSince1970 as Any? ?? NSNull(),
         "system": (app.bundleIdentifier?.hasPrefix("com.apple.") ?? false)
            || (app.executableURL?.path.hasPrefix("/System/") ?? false)]
    }.sorted { ($0["pid"] as! Int32) < ($1["pid"] as! Int32) }
}
func attribute(_ element: AXUIElement, _ name: String) -> (AXError, CFTypeRef?) {
    guard ProcessInfo.processInfo.systemUptime < deadline else { return (.cannotComplete, nil) }
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return (error, value)
}
func observe(_ pid: Int32) -> [String: Any] {
    guard trusted else { return ["complete": false, "reason": "AX not trusted", "items": []] }
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 0.2)
    let (error, value) = attribute(app, "AXExtrasMenuBar")
    guard error == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
        return ["complete": false, "rootError": error.rawValue, "items": []]
    }
    var pending = [(unsafeDowncast(value, to: AXUIElement.self), 0)]
    var visited: [AXUIElement] = []
    var items: [[String: Any]] = []
    var complete = true
    while let (element, depth) = pending.popLast() {
        guard visited.count < 128, ProcessInfo.processInfo.systemUptime < deadline else { complete = false; break }
        if visited.contains(where: { CFEqual($0, element) }) { continue }
        visited.append(element)
        AXUIElementSetMessagingTimeout(element, 0.1)
        guard let role = attribute(element, "AXRole").1 as? String else { complete = false; continue }
        if ["AXMenuBarItem", "AXButton"].contains(role) {
            var owner: pid_t = 0
            guard AXUIElementGetPid(element, &owner) == .success, owner == pid else { complete = false; continue }
            guard let point = attribute(element, "AXPosition").1, CFGetTypeID(point) == AXValueGetTypeID() else { complete = false; continue }
            let ax = unsafeDowncast(point, to: AXValue.self)
            var position = CGPoint.zero
            guard AXValueGetType(ax) == .cgPoint, AXValueGetValue(ax, .cgPoint, &position) else { complete = false; continue }
            items.append(["ownerPID": owner, "x": position.x, "y": position.y, "role": role])
        } else if ["AXMenuBar", "AXGroup"].contains(role) {
            let (childError, children) = attribute(element, "AXChildren")
            guard childError == .success, let children = children as? [AXUIElement], depth < 8,
                  children.count + pending.count + visited.count <= 128 else { complete = false; continue }
            pending += children.map { ($0, depth + 1) }
        } else { complete = false }
    }
    return ["complete": complete, "items": items]
}

let before = descriptors()
var observations: [String: Any] = [:]
var preferences: [String: Any] = [:]
for app in before {
    guard (app["bundle"] as? String).map(tokens.contains) == true
            || (app["executable"] as? String).map(tokens.contains) == true else { continue }
    let pid = app["pid"] as! Int32
    observations[String(pid)] = observe(pid)
    if let bundle = app["bundle"] as? String {
        let prefix = "NSStatusItem Preferred Position "
        let keys = CFPreferencesCopyKeyList(bundle as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String]
        let positionKeys = (keys ?? []).filter { $0.hasPrefix(prefix) }
        var positions: [String: Double] = [:]
        for key in positionKeys.prefix(64) {
            guard let value = CFPreferencesCopyValue(key as CFString, bundle as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost),
                  CFGetTypeID(value) == CFNumberGetTypeID(), let number = value as? NSNumber,
                  number.doubleValue.isFinite else { continue }
            positions[String(key.dropFirst(prefix.count))] = number.doubleValue
        }
        preferences[bundle] = ["keyListObserved": keys != nil, "positions": positions,
                               "positionsComplete": keys != nil && positionKeys.count <= 64 && positions.count == positionKeys.count]
    }
}
let result: [String: Any] = [
    "warning": "Unsupported Debug read-only identity capture; mutations=0",
    "startedAt": start.timeIntervalSince1970, "finishedAt": Date().timeIntervalSince1970,
    "trusted": trusted, "before": before, "after": descriptors(), "observations": observations,
    "ownerPreferences": preferences,
]
print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), as: UTF8.self))
