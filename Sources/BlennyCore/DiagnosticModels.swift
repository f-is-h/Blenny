import Foundation

public struct RuntimeEnvironment: Codable, Equatable, Sendable {
    public let macOSVersion: String
    public let buildVersion: String
    public let architecture: String

    public init(macOSVersion: String, buildVersion: String, architecture: String) {
        self.macOSVersion = macOSVersion
        self.buildVersion = buildVersion
        self.architecture = architecture
    }

    public static func current() -> RuntimeEnvironment {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let macOSVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        let buildVersion = (Bundle(path: "/System/Library/CoreServices/SystemVersion.bundle")?
            .object(forInfoDictionaryKey: "ProductBuildVersion") as? String)
            ?? (NSDictionary(contentsOfFile: "/System/Library/CoreServices/SystemVersion.plist")?["ProductBuildVersion"] as? String)
            ?? "unknown"

        #if arch(arm64)
        let architecture = "arm64"
        #elseif arch(x86_64)
        let architecture = "x86_64"
        #else
        let architecture = "unknown"
        #endif

        return RuntimeEnvironment(
            macOSVersion: macOSVersion,
            buildVersion: buildVersion,
            architecture: architecture
        )
    }
}

public struct RunningApplicationDescriptor: Equatable, Sendable {
    public let processIdentifier: Int32
    public let bundleIdentifier: String?

    public init(processIdentifier: Int32, bundleIdentifier: String?) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
    }
}

public enum AccessibilityTreeSource: String, Codable, Sendable {
    case applicationExtrasMenuBar
    case menuBarAgent
}

public enum MenuBarElementClassification: String, Codable, Sendable {
    case manageableCandidate
    case nativeOverflowPresentationControl
    case systemOwnedPresentation
    case structuralElement
}

public struct RectSnapshot: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct AXAttributeDiagnostic: Codable, Equatable, Sendable {
    public let value: String?
    public let readResult: String
    public let isSettable: Bool?
    public let settableResult: String

    public init(value: String?, readResult: String, isSettable: Bool?, settableResult: String) {
        self.value = value
        self.readResult = readResult
        self.isSettable = isSettable
        self.settableResult = settableResult
    }
}

public struct MenuBarItemRecord: Codable, Equatable, Sendable {
    public let source: AccessibilityTreeSource
    public let ownerPID: Int32
    public let ownerBundleIdentifier: String?
    public let depth: Int
    public let role: String?
    public let subrole: String?
    public let title: String?
    public let itemDescription: String?
    public let itemHelp: String?
    public let accessibilityIdentifier: String?
    public let frame: RectSnapshot?
    public let actions: [String]
    public let hiddenAttribute: AXAttributeDiagnostic
    public let positionAttribute: AXAttributeDiagnostic
    public let sizeAttribute: AXAttributeDiagnostic
    public var classification: MenuBarElementClassification
    public var classificationReason: String
    public var identity: MenuBarItemIdentity?

    public init(
        source: AccessibilityTreeSource,
        ownerPID: Int32,
        ownerBundleIdentifier: String?,
        depth: Int,
        role: String?,
        subrole: String?,
        title: String?,
        itemDescription: String?,
        itemHelp: String? = nil,
        accessibilityIdentifier: String?,
        frame: RectSnapshot?,
        actions: [String],
        hiddenAttribute: AXAttributeDiagnostic,
        positionAttribute: AXAttributeDiagnostic,
        sizeAttribute: AXAttributeDiagnostic,
        classification: MenuBarElementClassification,
        classificationReason: String,
        identity: MenuBarItemIdentity? = nil
    ) {
        self.source = source
        self.ownerPID = ownerPID
        self.ownerBundleIdentifier = ownerBundleIdentifier
        self.depth = depth
        self.role = role
        self.subrole = subrole
        self.title = title
        self.itemDescription = itemDescription
        self.itemHelp = itemHelp
        self.accessibilityIdentifier = accessibilityIdentifier
        self.frame = frame
        self.actions = actions
        self.hiddenAttribute = hiddenAttribute
        self.positionAttribute = positionAttribute
        self.sizeAttribute = sizeAttribute
        self.classification = classification
        self.classificationReason = classificationReason
        self.identity = identity
    }
}

public struct DiagnosticReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let environment: RuntimeEnvironment
    public let accessibilityTrusted: Bool
    public let durationMilliseconds: Int
    public let runningApplicationsChecked: Int
    public let extrasMenuBarTreesFound: Int
    public let menuBarAgentProcessesFound: Int
    public let elementLimitReached: Bool
    public let timeLimitReached: Bool
    public let aggregateErrors: [String: Int]
    public let notes: [String]
    public let items: [MenuBarItemRecord]
    public let applicationDiscoveries: [ApplicationMenuBarDiscovery]

    public init(
        generatedAt: Date,
        environment: RuntimeEnvironment,
        accessibilityTrusted: Bool,
        durationMilliseconds: Int,
        runningApplicationsChecked: Int,
        extrasMenuBarTreesFound: Int,
        menuBarAgentProcessesFound: Int,
        elementLimitReached: Bool,
        timeLimitReached: Bool,
        aggregateErrors: [String: Int],
        notes: [String],
        items: [MenuBarItemRecord],
        applicationDiscoveries: [ApplicationMenuBarDiscovery] = []
    ) {
        self.schemaVersion = 3
        self.generatedAt = generatedAt
        self.environment = environment
        self.accessibilityTrusted = accessibilityTrusted
        self.durationMilliseconds = durationMilliseconds
        self.runningApplicationsChecked = runningApplicationsChecked
        self.extrasMenuBarTreesFound = extrasMenuBarTreesFound
        self.menuBarAgentProcessesFound = menuBarAgentProcessesFound
        self.elementLimitReached = elementLimitReached
        self.timeLimitReached = timeLimitReached
        self.aggregateErrors = aggregateErrors
        self.notes = notes
        self.items = items
        self.applicationDiscoveries = applicationDiscoveries
    }
}
