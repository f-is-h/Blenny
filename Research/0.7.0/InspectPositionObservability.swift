// Unsupported macOS 27 read-only research; excluded from product targets.
// Inspect only canonical menu-bar trees of exact requested owners. No status
// items, private service connection, AX action, attribute write or pixel capture.
// Raw output must be redirected to ignored LocalData.
import AppKit
import ApplicationServices
import Darwin

alarm(15)
fputs("WARNING: unsupported one-shot AX observability probe; mutations=0\n", stderr)
let bundles = Array(Set(CommandLine.arguments.dropFirst())).sorted()
guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27,
      (1...4).contains(bundles.count), AXIsProcessTrusted() else {
    fputs("Requires macOS 27, existing AX trust and 1...4 exact bundle IDs.\n", stderr)
    exit(1)
}
let deadline = ProcessInfo.processInfo.systemUptime + 10
var complete = true
var requests = 0
var records: [[String: Any]] = []
let scalarNames = ["AXIdentifier", "AXTitle", "AXDescription", "AXValue",
                   "AXHidden", "AXExpanded", "AXEnabled", "AXPosition", "AXSize"]

func get(_ element: AXUIElement, _ name: String) -> (AXError, CFTypeRef?) {
    guard ProcessInfo.processInfo.systemUptime < deadline, requests < 512 else {
        complete = false
        return (.cannotComplete, nil)
    }
    requests += 1
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return (result, value)
}

func scalar(_ result: (AXError, CFTypeRef?)) -> [String: Any] {
    var record: [String: Any] = ["result": result.0.rawValue]
    guard result.0 == .success, let value = result.1 else { return record }
    if let string = value as? String {
        record["value"] = String(string.prefix(256))
    } else if let number = value as? NSNumber {
        record["value"] = number
    } else if CFGetTypeID(value) == AXValueGetTypeID() {
        let ax = unsafeDowncast(value, to: AXValue.self)
        switch AXValueGetType(ax) {
        case .cgPoint:
            var point = CGPoint.zero
            if AXValueGetValue(ax, .cgPoint, &point) { record["value"] = [point.x, point.y] }
        case .cgSize:
            var size = CGSize.zero
            if AXValueGetValue(ax, .cgSize, &size) { record["value"] = [size.width, size.height] }
        default: record["unsupportedValueType"] = true
        }
    } else { record["unsupportedValueType"] = true }
    return record
}

for bundle in bundles {
    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundle)
    guard apps.count == 1 else {
        complete = false
        records.append(["bundle": bundle, "owners": apps.count])
        continue
    }
    let pid = apps[0].processIdentifier
    let application = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(application, 0.15)
    let rootResult = get(application, "AXExtrasMenuBar")
    guard rootResult.0 == .success, let rawRoot = rootResult.1,
          CFGetTypeID(rawRoot) == AXUIElementGetTypeID() else {
        complete = false
        records.append(["bundle": bundle, "rootResult": rootResult.0.rawValue])
        continue
    }
    let root = unsafeDowncast(rawRoot, to: AXUIElement.self)
    var pending: [(AXUIElement, Int)] = [(root, 0)]
    var visited: [AXUIElement] = []
    while let (element, depth) = pending.popLast() {
        guard visited.count < 64, ProcessInfo.processInfo.systemUptime < deadline else {
            complete = false; break
        }
        if visited.contains(where: { CFEqual($0, element) }) { continue }
        visited.append(element)
        let roleResult = get(element, "AXRole")
        guard roleResult.0 == .success, let role = roleResult.1 as? String else {
            complete = false; continue
        }
        var owner: pid_t = 0
        guard AXUIElementGetPid(element, &owner) == .success, owner == pid else {
            complete = false; continue
        }
        guard ["AXMenuBar", "AXGroup", "AXMenuBarItem", "AXButton"].contains(role) else { continue }
        var names: CFArray?
        let namesResult = AXUIElementCopyAttributeNames(element, &names)
        var parameters: CFArray?
        let parameterResult = AXUIElementCopyParameterizedAttributeNames(element, &parameters)
        var record: [String: Any] = [
            "bundle": bundle, "pid": pid, "role": role, "depth": depth,
            "attributeNamesResult": namesResult.rawValue,
            "attributeNames": (names as? [String] ?? []).sorted(),
            "parameterNamesResult": parameterResult.rawValue,
            "parameterNames": (parameters as? [String] ?? []).sorted()
        ]
        var attributes: [String: Any] = [:]
        for name in scalarNames { attributes[name] = scalar(get(element, name)) }
        record["attributes"] = attributes
        if ["AXMenuBar", "AXGroup"].contains(role) {
            for name in ["AXVisibleChildren", "AXChildrenInNavigationOrder"] {
                let result = get(element, name)
                record[name] = ["result": result.0.rawValue,
                    "count": (result.1 as? [AXUIElement])?.count ?? -1]
            }
            let childrenResult = get(element, "AXChildren")
            if childrenResult.0 == .success, let children = childrenResult.1 as? [AXUIElement],
               depth < 6, children.count + pending.count + visited.count <= 64 {
                pending += children.map { ($0, depth + 1) }
            } else { complete = false }
        }
        records.append(record)
    }
}
let output: [String: Any] = ["complete": complete, "attributeValueRequests": requests,
    "mutations": 0, "records": records, "compositorVisibilityProven": false,
    "persistentPositionMappingProven": false]
let data = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data([10]))
exit(complete ? 0 : 2)
