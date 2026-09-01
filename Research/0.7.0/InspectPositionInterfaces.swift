// Unsupported macOS 27 research; excluded from all package/product targets.
// Reads Objective-C metadata only. Does not instantiate private classes, invoke
// their methods, connect to XPC, create status items or modify preferences.
import AppKit
import ObjectiveC
import Darwin
import MachO

print("WARNING: unsupported read-only macOS 27 interface inspection; mutations=0")
for framework in ["MenuBarClient", "MenuBarClientCore", "MacSystemUI"] {
    let path = "/System/Library/PrivateFrameworks/\(framework).framework/\(framework)"
    print("load \(framework)=\(dlopen(path, RTLD_LAZY | RTLD_LOCAL) != nil)")
}

func methods(_ cls: AnyClass, prefix: String) {
    var count: UInt32 = 0
    guard let list = class_copyMethodList(cls, &count) else { return }
    defer { free(list) }
    for index in 0..<Int(count) {
        let name = NSStringFromSelector(method_getName(list[index]))
        let lower = name.lowercased()
        guard NSStringFromClass(cls).contains("BSService") || NSStringFromClass(cls).contains("BSNSXPC") || ["position", "order", "item", "overflow", "priorit", "autosave", "trailing", "prefer", "drag", "tag", "identifier", "scene"].contains(where: lower.contains) else { continue }
        let encoding = method_getTypeEncoding(list[index]).map { String(cString: $0) } ?? "unknown"
        print("\(prefix)\(name) \(encoding)")
        if name.hasPrefix("NSXPCConnectionWithEndpoint") {
            let implementation = method_getImplementation(list[index])
            var info = Dl_info()
            if dladdr(unsafeBitCast(implementation, to: UnsafeRawPointer.self), &info) != 0,
               let imagePath = info.dli_fname {
                for imageIndex in 0..<_dyld_image_count() {
                    guard let path = _dyld_get_image_name(imageIndex), strcmp(path, imagePath) == 0 else { continue }
                    let address = unsafeBitCast(implementation, to: UInt.self)
                    print("UNSLID \(String(address - UInt(_dyld_get_image_vmaddr_slide(imageIndex)), radix: 16))")
                }
            }
        }
    }
}

var count: UInt32 = 0
if let classes = objc_copyClassList(&count) {
    defer { free(UnsafeMutableRawPointer(classes)) }
    for cls in UnsafeBufferPointer(start: classes, count: Int(count)) {
        let name = NSStringFromClass(cls)
        guard name.contains("StatusItem") || name == "NSStatusBar"
            || name.hasPrefix("BSServiceConnection") || name == "BSServiceInterface"
            || name == "BSServiceQuality" || name.hasPrefix("BSServiceInitiating")
            || name == "BSNSXPCTransport"
            || name.hasPrefix("MB") || name.contains("MenuBarItem") else { continue }
        print("CLASS \(name)")
        if let path = class_getImageName(cls) { print("IMAGE \(String(cString: path))") }
        methods(cls, prefix: "- ")
        if let meta = object_getClass(cls) { methods(meta, prefix: "+ ") }
    }
}

var protocolCount: UInt32 = 0
if let protocols = objc_copyProtocolList(&protocolCount) {
    defer { free(UnsafeMutableRawPointer(protocols)) }
    for proto in UnsafeBufferPointer(start: protocols, count: Int(protocolCount)) {
        let name = String(cString: protocol_getName(proto))
        guard name.hasPrefix("MB") else { continue }
        for required in [true, false] {
            var methodCount: UInt32 = 0
            guard let list = protocol_copyMethodDescriptionList(proto, required, true, &methodCount) else { continue }
            defer { free(list) }
            for method in UnsafeBufferPointer(start: list, count: Int(methodCount)) {
                guard let selector = method.name else { continue }
                let methodName = NSStringFromSelector(selector)
                guard ["position", "order", "overflow"].contains(where: methodName.lowercased().contains) else { continue }
                print("PROTOCOL \(name) \(methodName) \(method.types.map { String(cString: $0) } ?? "unknown")")
            }
        }
    }
}
print("DONE metadata only; no private method invocation")
