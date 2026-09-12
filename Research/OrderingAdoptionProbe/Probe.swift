// Original unsupported research. Excluded from all product targets.
#if !DEBUG
#error("This unsupported probe requires DEBUG")
#endif
import AppKit
import ObjectiveC
import Darwin

let ownerIDs = ["xyz.fi5h.blenny.research.adoption20260908a", "xyz.fi5h.blenny.research.adoption20260908b"]
let notification = Notification.Name("xyz.fi5h.blenny.research.adoption20260908.command")
let actions = ["swap", "restore", "nudge-swap", "nudge-restore", "recreate", "stop"]
let samples = ["initial", "swapped", "nudged", "restored", "restore-nudged", "recreated"]
struct Rejected: Error { let message: String }
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw Rejected(message: message) }
}
func record(_ value: [String: Any], at url: URL) throws {
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
}

@MainActor final class Owner: NSObject, NSApplicationDelegate {
    let identity: String
    var autosave: String { identity == ownerIDs[0] ? "AdoptionProbeA" : "AdoptionProbeB" }
    var preference: String { "NSStatusItem Preferred Position \(autosave)" }
    let output: URL
    var item: NSStatusItem?
    var executed = Set<String>()
    var seed: Float
    init(identity: String, output: URL) {
        self.identity = identity; self.output = output
        seed = identity == ownerIDs[0] ? 120 : 1000
    }
    func applicationDidFinishLaunching(_ note: Notification) {
        guard (UserDefaults.standard.persistentDomain(forName: identity) ?? [:]).isEmpty else { NSApp.terminate(nil); return }
        create()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(command(_:)), name: notification, object: identity, suspensionBehavior: .deliverImmediately)
        DispatchQueue.main.asyncAfter(deadline: .now() + 150) { [weak self] in self?.stop() }
    }
    func create() {
        UserDefaults.standard.set(seed, forKey: preference)
        item = NSStatusBar.system.statusItem(withLength: 24)
        item?.autosaveName = autosave
        item?.button?.title = identity == ownerIDs[0] ? "P1" : "P2"
    }
    func sendSavedPosition() throws {
        guard let item else { throw Rejected(message: "missing owned item") }
        let selector = NSSelectorFromString("_sendSavedPreferredPosition")
        guard let method = class_getInstanceMethod(type(of: item), selector),
              let type = method_getTypeEncoding(method), String(cString: type) == "v16@0:8"
        else { throw Rejected(message: "private sender contract differs") }
        typealias Sender = @convention(c) (AnyObject, Selector) -> Void
        unsafeBitCast(method_getImplementation(method), to: Sender.self)(item, selector)
    }
    func sceneSnapshot(_ item: NSStatusItem) throws -> [String: Any] {
        guard let ivar = class_getInstanceVariable(type(of: item), "_scene"),
              let encoding = ivar_getTypeEncoding(ivar), String(cString: encoding) == "@\"NSStatusItemScene\"",
              let scene = object_getIvar(item, ivar) as? NSObject else {
            throw Rejected(message: "owned scene contract differs or scene absent")
        }
        func object(_ owner: NSObject, _ name: String) throws -> NSObject? {
            let selector = NSSelectorFromString(name)
            let expected = name == "autosaveName" ? "@\"NSString\"16@0:8" : "@16@0:8"
            guard let method = class_getInstanceMethod(type(of: owner), selector),
                  let encoding = method_getTypeEncoding(method), String(cString: encoding) == expected else {
                throw Rejected(message: "scene object getter differs: " + name)
            }
            return owner.perform(selector)?.takeUnretainedValue() as? NSObject
        }
        func number(_ owner: NSObject, _ name: String) throws -> Float {
            let selector = NSSelectorFromString(name)
            guard let method = class_getInstanceMethod(type(of: owner), selector),
                  let encoding = method_getTypeEncoding(method), String(cString: encoding) == "f16@0:8" else {
                throw Rejected(message: "scene number getter differs: " + name)
            }
            typealias Getter = @convention(c) (AnyObject, Selector) -> Float
            return unsafeBitCast(method_getImplementation(method), to: Getter.self)(owner, selector)
        }
        guard let client = try object(scene, "clientSettings"),
              let host = try object(scene, "hostSettings") else {
            throw Rejected(message: "owned scene settings absent")
        }
        var result: [String: Any] = ["sceneClass": NSStringFromClass(type(of: scene)),
                                   "clientClass": NSStringFromClass(type(of: client)),
                                   "hostClass": NSStringFromClass(type(of: host))]
        for (owner, selectorName, key, expected) in [(client, "autosaveName", "clientAutosave", "@\"NSString\"16@0:8"),
                                                   (client, "savedPreferredPosition", "clientSaved", "f16@0:8"),
                                                   (host, "preferredPosition", "hostPreferred", "f16@0:8")] {
            let selector = NSSelectorFromString(selectorName)
            let encoding = class_getInstanceMethod(type(of: owner), selector).flatMap { method_getTypeEncoding($0) }.map { String(cString: $0) } ?? "missing"
            result[key + "Encoding"] = encoding
            if encoding != expected { result[key] = NSNull(); continue }
            if selectorName == "autosaveName" { result[key] = try object(owner, selectorName)?.description ?? NSNull() as Any }
            else { result[key] = try number(owner, selectorName) }
        }
        return result
    }
    @objc func command(_ note: Notification) {
        guard let command = note.userInfo?["command"] as? String,
              actions.contains(command) || samples.contains(command) else { return }
        if command == "stop" { stop(); return }
        let receipt = output.appendingPathComponent(identity + "-" + command + ".json")
        do {
            try require(executed.insert(command).inserted && !FileManager.default.fileExists(atPath: receipt.path), "command already attempted")
            try record(["intent": command, "pid": getpid()], at: receipt)
            if command == "swap" || command == "restore" {
                let swapped = command == "swap"
                seed = (identity == ownerIDs[0]) != swapped ? 120 : 1000
                UserDefaults.standard.set(seed, forKey: preference)
                try sendSavedPosition()
            } else if command.hasPrefix("nudge-") {
                // Only A performs one public width change; its inverse is separate.
                if identity == ownerIDs[0] { item?.length = command == "nudge-swap" ? 25 : 24 }
            } else if command == "recreate" {
                if let item { NSStatusBar.system.removeStatusItem(item) }
                item = nil; create()
            }
            guard let item else { throw Rejected(message: "missing item") }
            let selector = NSSelectorFromString("_savedPreferredPosition")
            guard let method = class_getInstanceMethod(type(of: item), selector), let type = method_getTypeEncoding(method), String(cString: type) == "f16@0:8" else { throw Rejected(message: "getter contract differs") }
            typealias Getter = @convention(c) (AnyObject, Selector) -> Float
            let saved = unsafeBitCast(method_getImplementation(method), to: Getter.self)(item, selector)
            var result: [String: Any] = ["command": command, "completed": true, "bundle": identity, "pid": getpid(), "saved": saved, "seed": seed, "length": item.length, "autosave": item.autosaveName ?? "", "itemObject": String(describing: Unmanaged.passUnretained(item).toOpaque()), "uptime": ProcessInfo.processInfo.systemUptime]
            if samples.contains(command) { result["scene"] = try sceneSnapshot(item) }
            if let frame = item.button?.window?.frame { result["frame"] = [frame.minX, frame.minY, frame.width, frame.height] }
            try record(result, at: receipt)
        } catch { try? record(["error": String(describing: error), "pid": getpid()], at: receipt) }
    }
    func stop() {
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
        UserDefaults.standard.removePersistentDomain(forName: identity)
        UserDefaults.standard.synchronize()
        NSApp.terminate(nil)
    }
}

@main struct Main {
    @MainActor static func main() {
        umask(0o077)
        fputs("WARNING: unsupported DEBUG owner-only position probe; no external table writer.\n", stderr)
        do {
            let version = try Data(contentsOf: URL(fileURLWithPath: "/System/Library/CoreServices/SystemVersion.plist"))
            let info = try PropertyListSerialization.propertyList(from: version, format: nil) as? [String: Any]
            try require(info?["ProductBuildVersion"] as? String == "26A5425a", "runtime differs")
            let args = Array(CommandLine.arguments.dropFirst())
            if args.count == 2 && args[0] == "--owner" {
                let identity = Bundle.main.bundleIdentifier ?? ""
                try require(ownerIDs.contains(identity), "unapproved owner")
                let app = NSApplication.shared; app.setActivationPolicy(.accessory)
                let delegate = Owner(identity: identity, output: URL(fileURLWithPath: args[1]))
                app.delegate = delegate; app.run(); withExtendedLifetime(delegate) {}; return
            }
            if args.count == 3 && args[0] == "--signal" {
                try require(ownerIDs.contains(args[1]) && (actions.contains(args[2]) || samples.contains(args[2])), "unapproved command")
                DistributedNotificationCenter.default().postNotificationName(notification, object: args[1], userInfo: ["command": args[2]], deliverImmediately: true); return
            }
            if args == ["--preflight"] {
                for identity in ownerIDs {
                    try require(NSRunningApplication.runningApplications(withBundleIdentifier: identity).isEmpty, "owner already running")
                    try require(CFPreferencesCopyKeyList(identity as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) == nil, "owner preferences occupied")
                }
                print("owner preflight passed"); return
            }
            throw Rejected(message: "unknown command")
        } catch { fputs("REJECTED: \(error)\n", stderr); exit(2) }
    }
}
