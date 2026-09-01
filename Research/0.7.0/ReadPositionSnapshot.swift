// Unsupported, one-shot, read-only macOS 27 research. No writer, status item,
// Accessibility action/attribute write, input, pixels, polling or XPC invocation.
// Pass exact bundle identifiers; raw output must stay in ignored LocalData.
import AppKit
import ApplicationServices

let bundles = Array(Set(CommandLine.arguments.dropFirst())).sorted()
guard !bundles.isEmpty, bundles.count <= 12, AXIsProcessTrusted() else {
    fputs("Pass 1...12 exact bundle IDs; existing Accessibility trust is required.\n", stderr)
    exit(1)
}
print("WARNING: unsupported read-only position snapshot; mutations=0")
print("screens=\(NSScreen.screens.map { [$0.frame.width, $0.frame.height, $0.backingScaleFactor] })")
let deadline = ProcessInfo.processInfo.systemUptime + 10
var total = 0
var complete = true

func read(_ element: AXUIElement, _ name: String) -> (AXError, CFTypeRef?) {
    guard ProcessInfo.processInfo.systemUptime < deadline else {
        complete = false
        return (.cannotComplete, nil)
    }
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return (error, value)
}
func string(_ element: AXUIElement, _ name: String) -> String? {
    (read(element, name).1 as? String).map { String($0.prefix(256)) }
}
func point(_ element: AXUIElement) -> CGPoint? {
    guard let value = read(element, "AXPosition").1,
          CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    let ax = unsafeDowncast(value, to: AXValue.self)
    var point = CGPoint.zero
    guard AXValueGetType(ax) == .cgPoint, AXValueGetValue(ax, .cgPoint, &point) else { return nil }
    return point
}
func size(_ element: AXUIElement) -> CGSize? {
    guard let value = read(element, "AXSize").1,
          CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    let ax = unsafeDowncast(value, to: AXValue.self)
    var size = CGSize.zero
    guard AXValueGetType(ax) == .cgSize, AXValueGetValue(ax, .cgSize, &size) else { return nil }
    return size
}

for bundle in bundles {
    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundle)
    print("BUNDLE \(bundle) owners=\(apps.count)")
    guard apps.count == 1 else { complete = false; continue }
    let app = apps[0]
    let root = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(root, 0.5)
    let (error, value) = read(root, "AXExtrasMenuBar")
    print("ROOT pid=\(app.processIdentifier) result=\(error.rawValue)")
    guard error == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
        complete = false; continue
    }
    AXUIElementSetMessagingTimeout(root, 0.1)
    var pending = [(unsafeDowncast(value, to: AXUIElement.self), 0)]
    var visited: [AXUIElement] = []
    while let (element, depth) = pending.popLast() {
        guard total < 256, ProcessInfo.processInfo.systemUptime < deadline else { complete = false; break }
        if visited.contains(where: { CFEqual($0, element) }) { continue }
        visited.append(element)
        total += 1
        guard let role = string(element, "AXRole") else { complete = false; continue }
        if ["AXMenuBarItem", "AXButton"].contains(role) {
            var owner: pid_t = 0
            let ownerResult = AXUIElementGetPid(element, &owner)
            var settable = DarwinBoolean(false)
            let settableResult = AXUIElementIsAttributeSettable(element, "AXPosition" as CFString, &settable)
            let position = point(element)
            let extent = size(element)
            if ownerResult != .success || owner != app.processIdentifier
                || settableResult != .success || position == nil || extent == nil {
                complete = false
            }
            let record: [String: Any] = [
                "bundle": bundle, "ownerPID": owner, "ownerRead": ownerResult.rawValue,
                "role": role, "identifier": string(element, "AXIdentifier") ?? NSNull(),
                "description": string(element, "AXDescription") ?? NSNull(),
                "x": position.map { $0.x as Any } ?? NSNull(),
                "y": position.map { $0.y as Any } ?? NSNull(),
                "width": extent.map { $0.width as Any } ?? NSNull(),
                "height": extent.map { $0.height as Any } ?? NSNull(),
                "positionSettable": settable.boolValue, "settableRead": settableResult.rawValue
            ]
            let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            print(String(decoding: data, as: UTF8.self))
        } else if ["AXMenuBar", "AXGroup"].contains(role) {
            let (childError, children) = read(element, "AXChildren")
            guard childError == .success, let children = children as? [AXUIElement] else { complete = false; continue }
            guard depth < 8 else { if !children.isEmpty { complete = false }; continue }
            guard children.count + pending.count + visited.count <= 256 else { complete = false; break }
            pending += children.map { ($0, depth + 1) }
        }
    }
}
print("DONE complete=\(complete) elements=\(total); frames are observations, not rendering or persistence proof")
exit(complete ? 0 : 2)
