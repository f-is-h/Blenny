import Darwin
import Foundation
import ObjectiveC.runtime

public enum ExperimentalAssessmentRuntimeError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedOperatingSystem(majorVersion: Int)
    case unsupportedArchitecture
    case frameworkUnavailable
    case classUnavailable(String)
    case selectorUnavailable(className: String, selector: String)
    case methodEncodingMismatch(
        className: String,
        selector: String,
        expected: String,
        actual: String
    )
    case allocationFailed(String)
    case initializationFailed(String)
    case configurationRoundTripMismatch
    case activationFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedOperatingSystem(majorVersion):
            "This build requires macOS 27; the current major version is \(majorVersion)."
        case .unsupportedArchitecture:
            "This Blenny build requires Apple silicon."
        case .frameworkUnavailable:
            "The macOS menu bar management framework is unavailable."
        case let .classUnavailable(name):
            "The macOS menu bar management class \(name) is unavailable."
        case let .selectorUnavailable(className, selector):
            "The macOS menu bar management method \(className).\(selector) is unavailable."
        case let .methodEncodingMismatch(className, selector, expected, actual):
            "The macOS menu bar management method \(className).\(selector) changed from \(expected) to \(actual)."
        case let .allocationFailed(name):
            "The macOS menu bar management object \(name) could not be created."
        case let .initializationFailed(name):
            "The macOS menu bar management object \(name) could not be initialized."
        case .configurationRoundTripMismatch:
            "macOS returned different menu bar management settings than Blenny requested."
        case let .activationFailed(detail):
            "macOS refused the menu bar management request: \(detail)"
        }
    }
}

public final class ExperimentalMacOS27AssessmentFactory:
    RevealAssertionCandidateFactory,
    @unchecked Sendable
{
    public static let supportedOperatingSystemMajorVersion = 27
    public static let compatibilityFingerprint =
        "arm64-macos27-assessment-contract-v5"
    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore"

    private let frameworkHandle: UnsafeMutableRawPointer
    private let assertionClass: AnyClass
    private let configurationClass: AnyClass
    private let methods: RuntimeMethods

    public init() throws {
        #if !arch(arm64)
        throw ExperimentalAssessmentRuntimeError.unsupportedArchitecture
        #endif
        let majorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        guard majorVersion == Self.supportedOperatingSystemMajorVersion else {
            throw ExperimentalAssessmentRuntimeError.unsupportedOperatingSystem(
                majorVersion: majorVersion
            )
        }
        guard let frameworkHandle = dlopen(Self.frameworkPath, RTLD_NOW | RTLD_LOCAL) else {
            throw ExperimentalAssessmentRuntimeError.frameworkUnavailable
        }

        do {
            let assertionClass: AnyClass = try Self.requireClass(
                "MBAssessmentModeAssertion"
            )
            let configurationClass: AnyClass = try Self.requireClass(
                "MBAssessmentModeConfiguration"
            )
            let methods = try RuntimeMethods(
                assertionClass: assertionClass,
                configurationClass: configurationClass
            )
            self.frameworkHandle = frameworkHandle
            self.assertionClass = assertionClass
            self.configurationClass = configurationClass
            self.methods = methods
        } catch {
            dlclose(frameworkHandle)
            throw error
        }
    }

    deinit {
        dlclose(frameworkHandle)
    }

    public func makeCandidate(
        for plan: RevealAllowlistPlan
    ) throws -> any RevealAssertionCandidate {
        let systemItems = plan.allowedSystemItems.map(NSNumber.init(value:)) as NSArray
        let bundleIdentifiers = plan.allowedBundleIdentifiers as NSArray

        guard let configurationAllocation = class_createInstance(configurationClass, 0) else {
            throw ExperimentalAssessmentRuntimeError.allocationFailed(
                "MBAssessmentModeConfiguration"
            )
        }
        let configurationObject = configurationAllocation as AnyObject
        let initializeConfiguration = unsafeBitCast(
            method_getImplementation(methods.configurationInitializer),
            to: ConfigurationInitializer.self
        )
        guard let configuration = initializeConfiguration(
            configurationObject,
            methods.configurationInitializerSelector,
            systemItems,
            bundleIdentifiers
        ) else {
            throw ExperimentalAssessmentRuntimeError.initializationFailed(
                "MBAssessmentModeConfiguration"
            )
        }

        let readSystemItems = unsafeBitCast(
            method_getImplementation(methods.allowedSystemItemsGetter),
            to: ObjectGetter.self
        )
        let readBundleIdentifiers = unsafeBitCast(
            method_getImplementation(methods.allowedBundleIdentifiersGetter),
            to: ObjectGetter.self
        )
        let returnedSystemItems = readSystemItems(
            configuration,
            methods.allowedSystemItemsSelector
        ) as? [NSNumber]
        let returnedBundleIdentifiers = readBundleIdentifiers(
            configuration,
            methods.allowedBundleIdentifiersSelector
        ) as? [String]
        guard returnedSystemItems == plan.allowedSystemItems.map(NSNumber.init(value:)),
              returnedBundleIdentifiers == plan.allowedBundleIdentifiers else {
            throw ExperimentalAssessmentRuntimeError.configurationRoundTripMismatch
        }

        guard let assertionAllocation = class_createInstance(assertionClass, 0) else {
            throw ExperimentalAssessmentRuntimeError.allocationFailed(
                "MBAssessmentModeAssertion"
            )
        }
        let assertionObject = assertionAllocation as AnyObject
        let initializeAssertion = unsafeBitCast(
            method_getImplementation(methods.assertionInitializer),
            to: ObjectInitializer.self
        )
        guard let assertion = initializeAssertion(
            assertionObject,
            methods.assertionInitializerSelector
        ) else {
            throw ExperimentalAssessmentRuntimeError.initializationFailed(
                "MBAssessmentModeAssertion"
            )
        }

        return ExperimentalAssessmentCandidate(
            assertion: assertion,
            configuration: configuration,
            activationMethod: methods.activation,
            activationSelector: methods.activationSelector,
            invalidationMethod: methods.invalidation,
            invalidationSelector: methods.invalidationSelector
        )
    }

    private static func requireClass(_ name: String) throws -> AnyClass {
        guard let runtimeClass = NSClassFromString(name) else {
            throw ExperimentalAssessmentRuntimeError.classUnavailable(name)
        }
        return runtimeClass
    }

}

private final class ExperimentalAssessmentCandidate:
    RevealAssertionCandidate,
    @unchecked Sendable
{
    private let assertion: AnyObject
    private let configuration: AnyObject
    private let activationMethod: Method
    private let activationSelector: Selector
    private let invalidationMethod: Method
    private let invalidationSelector: Selector
    private let lock = NSLock()
    private var invalidated = false

    init(
        assertion: AnyObject,
        configuration: AnyObject,
        activationMethod: Method,
        activationSelector: Selector,
        invalidationMethod: Method,
        invalidationSelector: Selector
    ) {
        self.assertion = assertion
        self.configuration = configuration
        self.activationMethod = activationMethod
        self.activationSelector = activationSelector
        self.invalidationMethod = invalidationMethod
        self.invalidationSelector = invalidationSelector
    }

    func activate() async throws {
        let completion = ActivationCompletion()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                completion.install(continuation)
                let activate = unsafeBitCast(
                    method_getImplementation(activationMethod),
                    to: AssertionActivator.self
                )
                let block: @convention(block) (NSError?) -> Void = { error in
                    if let error {
                        completion.finish(
                            .failure(
                                ExperimentalAssessmentRuntimeError.activationFailed(
                                    error.localizedDescription
                                )
                            )
                        )
                    } else {
                        completion.finish(.success(()))
                    }
                }
                activate(assertion, activationSelector, configuration, block)
            }
        } onCancel: {
            completion.finish(.failure(CancellationError()))
        }
    }

    func invalidate() async {
        let shouldInvalidate = lock.withLock {
            guard !invalidated else { return false }
            invalidated = true
            return true
        }
        guard shouldInvalidate else { return }

        let invalidate = unsafeBitCast(
            method_getImplementation(invalidationMethod),
            to: AssertionInvalidator.self
        )
        invalidate(assertion, invalidationSelector)
    }
}

private final class ActivationCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var terminalResult: Result<Void, Error>?

    func install(_ continuation: CheckedContinuation<Void, Error>) {
        let terminalResult = lock.withLock { () -> Result<Void, Error>? in
            if let terminalResult = self.terminalResult { return terminalResult }
            self.continuation = continuation
            return nil
        }
        if let terminalResult {
            continuation.resume(with: terminalResult)
        }
    }

    func finish(_ result: Result<Void, Error>) {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Error>? in
            guard terminalResult == nil else { return nil }
            terminalResult = result
            let continuation = self.continuation
            self.continuation = nil
            return continuation
        }
        continuation?.resume(with: result)
    }
}

private struct RuntimeMethods {
    let assertionInitializerSelector = NSSelectorFromString("init")
    let activationSelector = NSSelectorFromString(
        "activateWithConfiguration:completionHandler:"
    )
    let invalidationSelector = NSSelectorFromString("invalidate")
    let configurationInitializerSelector = NSSelectorFromString(
        "initWithAllowedSystemItems:allowedBundleIdentifiers:"
    )
    let allowedSystemItemsSelector = NSSelectorFromString("allowedSystemItems")
    let allowedBundleIdentifiersSelector = NSSelectorFromString(
        "allowedBundleIdentifiers"
    )

    let assertionInitializer: Method
    let activation: Method
    let invalidation: Method
    let configurationInitializer: Method
    let allowedSystemItemsGetter: Method
    let allowedBundleIdentifiersGetter: Method

    init(assertionClass: AnyClass, configurationClass: AnyClass) throws {
        assertionInitializer = try Self.requireMethod(
            runtimeClass: assertionClass,
            className: "MBAssessmentModeAssertion",
            selector: assertionInitializerSelector,
            expectedEncoding: "@16@0:8"
        )
        activation = try Self.requireMethod(
            runtimeClass: assertionClass,
            className: "MBAssessmentModeAssertion",
            selector: activationSelector,
            expectedEncoding: "v32@0:8@16@?24"
        )
        invalidation = try Self.requireMethod(
            runtimeClass: assertionClass,
            className: "MBAssessmentModeAssertion",
            selector: invalidationSelector,
            expectedEncoding: "v16@0:8"
        )
        configurationInitializer = try Self.requireMethod(
            runtimeClass: configurationClass,
            className: "MBAssessmentModeConfiguration",
            selector: configurationInitializerSelector,
            expectedEncoding: "@32@0:8@16@24"
        )
        allowedSystemItemsGetter = try Self.requireMethod(
            runtimeClass: configurationClass,
            className: "MBAssessmentModeConfiguration",
            selector: allowedSystemItemsSelector,
            expectedEncoding: "@16@0:8"
        )
        allowedBundleIdentifiersGetter = try Self.requireMethod(
            runtimeClass: configurationClass,
            className: "MBAssessmentModeConfiguration",
            selector: allowedBundleIdentifiersSelector,
            expectedEncoding: "@16@0:8"
        )
    }

    private static func requireMethod(
        runtimeClass: AnyClass,
        className: String,
        selector: Selector,
        expectedEncoding: String
    ) throws -> Method {
        guard let method = class_getInstanceMethod(runtimeClass, selector) else {
            throw ExperimentalAssessmentRuntimeError.selectorUnavailable(
                className: className,
                selector: NSStringFromSelector(selector)
            )
        }
        guard let typeEncoding = method_getTypeEncoding(method) else {
            throw ExperimentalAssessmentRuntimeError.methodEncodingMismatch(
                className: className,
                selector: NSStringFromSelector(selector),
                expected: expectedEncoding,
                actual: "<nil>"
            )
        }
        let actualEncoding = String(cString: typeEncoding)
        guard actualEncoding == expectedEncoding else {
            throw ExperimentalAssessmentRuntimeError.methodEncodingMismatch(
                className: className,
                selector: NSStringFromSelector(selector),
                expected: expectedEncoding,
                actual: actualEncoding
            )
        }
        return method
    }
}

private typealias ObjectInitializer = @convention(c) (
    AnyObject,
    Selector
) -> AnyObject?

private typealias ConfigurationInitializer = @convention(c) (
    AnyObject,
    Selector,
    NSArray,
    NSArray
) -> AnyObject?

private typealias ObjectGetter = @convention(c) (
    AnyObject,
    Selector
) -> AnyObject?

private typealias AssertionActivator = @convention(c) (
    AnyObject,
    Selector,
    AnyObject,
    @convention(block) (NSError?) -> Void
) -> Void

private typealias AssertionInvalidator = @convention(c) (
    AnyObject,
    Selector
) -> Void
