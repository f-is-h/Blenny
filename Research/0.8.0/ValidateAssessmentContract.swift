import Darwin
import Foundation
import ObjectiveC.runtime

// Read-only compatibility probe. It loads the framework, checks exact Objective-C
// encodings, and round-trips an in-memory configuration. It never constructs an
// assertion or calls activation/invalidation.

private enum ProbeError: Error {
    case unsupportedBuild(String)
    case unavailable(String)
    case mismatch(String)
}

@main
enum ValidateAssessmentContract {
    static func main() throws {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 else {
            throw ProbeError.unsupportedBuild("not macOS 27")
        }
        let build = try operatingSystemBuild()
        guard ["26A5416b", "26A5425a"].contains(build) else {
            throw ProbeError.unsupportedBuild(build)
        }
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore",
            RTLD_NOW | RTLD_LOCAL
        ) else { throw ProbeError.unavailable("framework") }
        defer { dlclose(handle) }

        let assertionClass: AnyClass = try runtimeClass("MBAssessmentModeAssertion")
        let configurationClass: AnyClass = try runtimeClass("MBAssessmentModeConfiguration")
        try check(assertionClass, "init", "@16@0:8")
        try check(
            assertionClass, "activateWithConfiguration:completionHandler:",
            "v32@0:8@16@?24"
        )
        try check(assertionClass, "invalidate", "v16@0:8")
        let initializer = try check(
            configurationClass,
            "initWithAllowedSystemItems:allowedBundleIdentifiers:",
            "@32@0:8@16@24"
        )
        let systemGetter = try check(configurationClass, "allowedSystemItems", "@16@0:8")
        let bundleGetter = try check(
            configurationClass, "allowedBundleIdentifiers", "@16@0:8"
        )

        guard let allocation = class_createInstance(configurationClass, 0) else {
            throw ProbeError.unavailable("configuration allocation")
        }
        typealias Initializer = @convention(c) (
            AnyObject, Selector, NSArray, NSArray
        ) -> AnyObject?
        typealias Getter = @convention(c) (AnyObject, Selector) -> AnyObject?
        let systemItems = (0 ... 8).map(NSNumber.init(value:)) as NSArray
        let bundles = [
            "com.apple.TextInputMenuAgent", "com.apple.weather.menu", "xyz.fi5h.blenny",
        ] as NSArray
        let initialize = unsafeBitCast(
            method_getImplementation(initializer), to: Initializer.self
        )
        guard let configuration = initialize(
            allocation as AnyObject,
            method_getName(initializer),
            systemItems,
            bundles
        ) else { throw ProbeError.unavailable("configuration initialization") }
        let getSystemItems = unsafeBitCast(
            method_getImplementation(systemGetter), to: Getter.self
        )
        let getBundles = unsafeBitCast(
            method_getImplementation(bundleGetter), to: Getter.self
        )
        guard getSystemItems(configuration, method_getName(systemGetter)) as? [NSNumber]
                == systemItems as? [NSNumber],
              getBundles(configuration, method_getName(bundleGetter)) as? [String]
                == bundles as? [String] else {
            throw ProbeError.mismatch("configuration round trip")
        }
        print("PASS build=\(build) exactEncodings=6 configurationRoundTrip=true assertions=0 mutations=0")
    }

    private static func runtimeClass(_ name: String) throws -> AnyClass {
        guard let value = NSClassFromString(name) else {
            throw ProbeError.unavailable(name)
        }
        return value
    }

    @discardableResult
    private static func check(
        _ runtimeClass: AnyClass,
        _ selectorName: String,
        _ expected: String
    ) throws -> Method {
        let selector = NSSelectorFromString(selectorName)
        guard let method = class_getInstanceMethod(runtimeClass, selector),
              let encoding = method_getTypeEncoding(method) else {
            throw ProbeError.unavailable(selectorName)
        }
        let actual = String(cString: encoding)
        guard actual == expected else {
            throw ProbeError.mismatch("\(selectorName): \(actual)")
        }
        return method
    }

    private static func operatingSystemBuild() throws -> String {
        var size = 0
        guard sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0 else {
            throw ProbeError.unavailable("kern.osversion")
        }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.osversion", &bytes, &size, nil, 0) == 0 else {
            throw ProbeError.unavailable("kern.osversion")
        }
        return String(cString: bytes)
    }
}
