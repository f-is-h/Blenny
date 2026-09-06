#if DEBUG
import AppKit
import CryptoKit
import Foundation

public enum SystemItemVisibilityValidationError: Error, Equatable, Sendable {
    case invalidScope
    case incompleteSnapshot
    case unconfirmedPlan
    case staleState
    case stopped
    case unexpectedStateChange
    case restoreFailed
}

public struct MacOS27SystemItemIdentity: Codable, Equatable, Hashable, Sendable {
    public let rawValue: Int
    public let privateName: String

    public init(rawValue: Int, privateName: String) {
        self.rawValue = rawValue
        self.privateName = privateName
    }

    public static let all: [Self] = [
        .init(rawValue: 0, privateName: "battery"),
        .init(rawValue: 1, privateName: "bluetooth"),
        .init(rawValue: 2, privateName: "clock"),
        .init(rawValue: 3, privateName: "displays"),
        .init(rawValue: 4, privateName: "keyboard"),
        .init(rawValue: 5, privateName: "volume"),
        .init(rawValue: 6, privateName: "wifi"),
        .init(rawValue: 7, privateName: "screenMirroring"),
        .init(rawValue: 8, privateName: "primaryBentoBox")
    ]
}

public enum SystemItemVisibilityTarget: String, CaseIterable, Codable, Sendable {
    case bluetooth
    case wifi

    public var identity: MacOS27SystemItemIdentity {
        switch self {
        case .bluetooth:
            MacOS27SystemItemIdentity(rawValue: 1, privateName: "bluetooth")
        case .wifi:
            MacOS27SystemItemIdentity(rawValue: 6, privateName: "wifi")
        }
    }

    public var axIdentifier: String {
        switch self {
        case .bluetooth:
            "com.apple.menuextra.bluetooth"
        case .wifi:
            "com.apple.menuextra.wifi"
        }
    }

    public var displayName: String {
        switch self {
        case .bluetooth: "Bluetooth"
        case .wifi: "Wi-Fi"
        }
    }
}

public struct SystemItemAXObservation: Codable, Equatable, Sendable {
    public let identifier: String
    public let frame: RectSnapshot?

    public init(identifier: String, frame: RectSnapshot?) {
        self.identifier = identifier.lowercased()
        self.frame = frame
    }
}

public struct ScopedPreferenceSnapshot: Codable, Equatable, Sendable {
    public let domain: String
    public let encodedValues: Data

    public init(domain: String, encodedValues: Data) {
        self.domain = domain
        self.encodedValues = encodedValues
    }

    public func validate() throws {
        guard encodedValues.count <= 1_048_576,
              let values = try PropertyListSerialization.propertyList(
                from: encodedValues, format: nil
              ) as? [String: Any], values.count <= 512,
              values.keys.allSatisfy({ key in
                key.count <= 512
                    && (key.hasPrefix("NSStatusItem ")
                        || (domain == "com.apple.MenuBarAgent"
                            && key == "TrailingItemPreferredPositions"))
              }) else {
            throw SystemItemVisibilityValidationError.invalidScope
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.domain == rhs.domain,
              let left = lhs.decodedValues,
              let right = rhs.decodedValues else {
            return lhs.domain == rhs.domain && lhs.encodedValues == rhs.encodedValues
        }
        return NSDictionary(dictionary: left).isEqual(to: right)
    }

    private var decodedValues: [String: Any]? {
        try? PropertyListSerialization.propertyList(
            from: encodedValues, format: nil
        ) as? [String: Any]
    }
}

public struct LocalFileDigest: Codable, Equatable, Sendable {
    public let relativePath: String
    public let exists: Bool
    public let byteCount: Int
    public let sha256: String?

    public init(relativePath: String, exists: Bool, byteCount: Int, sha256: String?) {
        self.relativePath = relativePath
        self.exists = exists
        self.byteCount = byteCount
        self.sha256 = sha256
    }
}

public struct SystemItemVisibilitySnapshot: Codable, Equatable, Sendable {
    public let captureComplete: Bool
    public let systemItems: [SystemItemAXObservation]
    public let nativeOverflowFrames: [RectSnapshot?]
    public let scopedPreferences: [ScopedPreferenceSnapshot]
    public let localFileDigests: [LocalFileDigest]
    public let runningBundleIdentifiers: [String]

    public init(
        captureComplete: Bool,
        systemItems: [SystemItemAXObservation],
        nativeOverflowFrames: [RectSnapshot?],
        scopedPreferences: [ScopedPreferenceSnapshot],
        localFileDigests: [LocalFileDigest],
        runningBundleIdentifiers: [String]
    ) {
        self.captureComplete = captureComplete
        self.systemItems = systemItems.sorted(by: Self.axOrder)
        self.nativeOverflowFrames = nativeOverflowFrames.sorted(by: Self.frameOrder)
        self.scopedPreferences = scopedPreferences.sorted { $0.domain < $1.domain }
        self.localFileDigests = localFileDigests.sorted { $0.relativePath < $1.relativePath }
        self.runningBundleIdentifiers = Array(Set(runningBundleIdentifiers)).sorted()
    }

    public func validate() throws {
        try validateStructure()
        guard captureComplete,
              count(Self.bluetoothAXIdentifier) == 1,
              count(Self.wifiAXIdentifier) == 1,
              count(Self.clockAXIdentifier) == 1,
              count(Self.controlCenterAXIdentifier) == 1,
              (0 ... 1).contains(nativeOverflowFrames.count) else {
            throw SystemItemVisibilityValidationError.incompleteSnapshot
        }
    }

    public func validateStructure() throws {
        guard
              systemItems.count <= 128,
              systemItems.allSatisfy({
                !$0.identifier.isEmpty && $0.identifier.count <= 512
                    && $0.frame.map(Self.validFrame) == true
              }),
              nativeOverflowFrames.count <= 8,
              nativeOverflowFrames.allSatisfy({ $0.map(Self.validFrame) == true }),
              scopedPreferences.count == 3,
              scopedPreferences.map(\.domain) == scopedPreferences.map(\.domain).sorted(),
              Set(scopedPreferences.map(\.domain)) == Set(Self.preferenceDomains),
              scopedPreferences.allSatisfy({ $0.encodedValues.count <= 1_048_576 }),
              localFileDigests.count <= 32,
              localFileDigests.map(\.relativePath) == localFileDigests.map(\.relativePath).sorted(),
              Set(localFileDigests.map(\.relativePath)).count == localFileDigests.count,
              localFileDigests.allSatisfy(Self.validFileDigest),
              Set(Self.requiredFilePaths).isSubset(
                of: Set(localFileDigests.filter(\.exists).map(\.relativePath))
              ),
              runningBundleIdentifiers == Array(Set(runningBundleIdentifiers)).sorted(),
              runningBundleIdentifiers.count <= 512,
              runningBundleIdentifiers.allSatisfy({ !$0.isEmpty && $0.count <= 512 }) else {
            throw SystemItemVisibilityValidationError.incompleteSnapshot
        }
        for preference in scopedPreferences { try preference.validate() }
    }

    public func count(_ identifier: String) -> Int {
        systemItems.count { $0.identifier == identifier.lowercased() }
    }

    public var itemCounts: [String: Int] {
        Dictionary(grouping: systemItems, by: \.identifier).mapValues(\.count)
    }

    public var visibilityRelevantItemCounts: [String: Int] {
        itemCounts.filter { Self.visibilityRelevantAXIdentifiers.contains($0.key) }
    }

    public static let bluetoothAXIdentifier = "com.apple.menuextra.bluetooth"
    public static let batteryAXIdentifier = "com.apple.menuextra.battery"
    public static let wifiAXIdentifier = "com.apple.menuextra.wifi"
    public static let clockAXIdentifier = "com.apple.menuextra.clock"
    public static let displayAXIdentifier = "com.apple.menuextra.display"
    public static let keyboardBrightnessAXIdentifier =
        "com.apple.menuextra.keyboard-brightness"
    public static let soundAXIdentifier = "com.apple.menuextra.sound"
    public static let screenMirroringAXIdentifier =
        "com.apple.menuextra.screen-mirroring"
    public static let controlCenterAXIdentifier = "com.apple.menuextra.controlcenter"
    public static let visibilityRelevantAXIdentifiers = Set([
        batteryAXIdentifier,
        bluetoothAXIdentifier,
        clockAXIdentifier,
        displayAXIdentifier,
        keyboardBrightnessAXIdentifier,
        soundAXIdentifier,
        wifiAXIdentifier,
        screenMirroringAXIdentifier,
        controlCenterAXIdentifier,
    ])
    public static let preferenceDomains = [
        "com.apple.MenuBarAgent",
        "com.apple.controlcenter",
        "com.apple.systemuiserver"
    ]
    public static let requiredFilePaths = [
        "Library/Preferences/com.apple.MenuBarAgent.plist",
        "Library/Preferences/com.apple.controlcenter.plist",
        "Library/Preferences/com.apple.systemuiserver.plist",
        "Library/Application Support/Blenny/PersistentPolicyPrototype/bundle-policies.json",
        "Library/Application Support/Blenny/PersistentPolicyPrototype/bundle-policies.previous.blenny-backup.json"
    ]

    private static func validFileDigest(_ value: LocalFileDigest) -> Bool {
        guard !value.relativePath.hasPrefix("/"), !value.relativePath.contains(".."),
              value.relativePath.count <= 1_024, value.byteCount >= 0,
              value.byteCount <= 4_194_304 else { return false }
        if value.exists {
            return value.sha256?.count == 64
                && value.sha256?.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) == true
        }
        return value.byteCount == 0 && value.sha256 == nil
    }

    private static func validFrame(_ value: RectSnapshot) -> Bool {
        value.x.isFinite && value.y.isFinite && value.width.isFinite
            && value.height.isFinite && value.width > 0 && value.height > 0
    }

    private static func axOrder(_ lhs: SystemItemAXObservation,
                                _ rhs: SystemItemAXObservation) -> Bool {
        (lhs.identifier, lhs.frame?.x ?? -.infinity, lhs.frame?.y ?? -.infinity)
            < (rhs.identifier, rhs.frame?.x ?? -.infinity, rhs.frame?.y ?? -.infinity)
    }

    private static func frameOrder(_ lhs: RectSnapshot?, _ rhs: RectSnapshot?) -> Bool {
        let left = [lhs?.x, lhs?.y, lhs?.width, lhs?.height]
            .map { $0 ?? -.infinity }
        let right = [rhs?.x, rhs?.y, rhs?.width, rhs?.height]
            .map { $0 ?? -.infinity }
        return left.lexicographicallyPrecedes(right)
    }
}

public struct SystemItemVisibilityPlan: Codable, Equatable, Sendable {
    public static let bundleIdentifier = "xyz.fi5h.blenny"
    public static let durationSeconds = 60

    public let schemaVersion: Int
    public let runtime: RuntimeEnvironment
    public let identityCatalog: [MacOS27SystemItemIdentity]
    public let target: SystemItemVisibilityTarget
    public let allowedSystemItems: [Int]
    public let baseline: SystemItemVisibilitySnapshot

    public init(
        runtime: RuntimeEnvironment,
        baseline: SystemItemVisibilitySnapshot,
        target: SystemItemVisibilityTarget = .bluetooth
    ) throws {
        schemaVersion = 6
        self.runtime = runtime
        identityCatalog = MacOS27SystemItemIdentity.all
        self.target = target
        allowedSystemItems = identityCatalog.map(\.rawValue).filter {
            $0 != target.identity.rawValue
        }
        self.baseline = baseline
        try validate()
    }

    public func validate() throws {
        try baseline.validate()
        let expectedAllowedSystemItems = identityCatalog.map(\.rawValue).filter {
            $0 != target.identity.rawValue
        }
        guard schemaVersion == 6,
              runtime == RuntimeEnvironment(
                macOSVersion: "27.0.0", buildVersion: "26A5416b",
                architecture: "arm64"
              ),
              identityCatalog == MacOS27SystemItemIdentity.all,
              identityCatalog.map(\.rawValue) == Array(0 ... 8),
              identityCatalog[target.identity.rawValue] == target.identity,
              allowedSystemItems == expectedAllowedSystemItems,
              baseline.runningBundleIdentifiers.contains(Self.bundleIdentifier),
              baseline.runningBundleIdentifiers.contains("com.apple.MenuBarAgent") else {
            throw SystemItemVisibilityValidationError.invalidScope
        }
    }

    public var writerPlan: RevealAllowlistPlan {
        RevealAllowlistPlan(
            presentation: .baseline,
            allowedSystemItems: allowedSystemItems,
            allowedBundleIdentifiers: baseline.runningBundleIdentifiers
        )
    }

    public func validateApplied(_ current: SystemItemVisibilitySnapshot) throws {
        try current.validateStructure()
        guard current.captureComplete,
              current.count(target.axIdentifier) == 0,
              current.scopedPreferences == baseline.scopedPreferences,
              current.localFileDigests == baseline.localFileDigests,
              runningBundlesDidNotExpand(in: current),
              current.nativeOverflowFrames.count <= 1 else {
            throw SystemItemVisibilityValidationError.unexpectedStateChange
        }
        var expected = baseline.visibilityRelevantItemCounts
        expected.removeValue(forKey: target.axIdentifier)
        var observed = current.visibilityRelevantItemCounts
        observed.removeValue(forKey: target.axIdentifier)
        guard observed == expected else {
            throw SystemItemVisibilityValidationError.unexpectedStateChange
        }
    }

    public func validateFresh(_ current: SystemItemVisibilitySnapshot) throws {
        try current.validate()
        guard current.captureComplete == baseline.captureComplete,
              current.visibilityRelevantItemCounts == baseline.visibilityRelevantItemCounts,
              current.scopedPreferences == baseline.scopedPreferences,
              current.localFileDigests == baseline.localFileDigests,
              runningBundlesDidNotExpand(in: current) else {
            throw SystemItemVisibilityValidationError.staleState
        }
    }

    public func validateRestored(_ current: SystemItemVisibilitySnapshot) throws {
        do {
            try validateFresh(current)
        } catch {
            throw SystemItemVisibilityValidationError.restoreFailed
        }
    }

    private func runningBundlesDidNotExpand(
        in current: SystemItemVisibilitySnapshot
    ) -> Bool {
        let baselineBundles = Set(baseline.runningBundleIdentifiers)
        let currentBundles = Set(current.runningBundleIdentifiers)
        return currentBundles.isSubset(of: baselineBundles)
            && currentBundles.contains(Self.bundleIdentifier)
            && currentBundles.contains("com.apple.MenuBarAgent")
    }

    public var fingerprint: String {
        get throws {
            struct Binding: Encodable {
                let plan: SystemItemVisibilityPlan
                let target: SystemItemVisibilityTarget
                let targetAXIdentifier: String
                let allowedSystemItems: [Int]
                let durationSeconds: Int
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let binding = Binding(
                plan: self,
                target: target,
                targetAXIdentifier: target.axIdentifier,
                allowedSystemItems: allowedSystemItems,
                durationSeconds: Self.durationSeconds
            )
            return SHA256.hash(data: try encoder.encode(binding))
                .map { String(format: "%02x", $0) }.joined()
        }
    }
}

@MainActor
public protocol SystemItemVisibilitySnapshotCapturing: AnyObject, Sendable {
    func capture() async throws -> SystemItemVisibilitySnapshot
}

@MainActor
public final class SystemItemVisibilityValidationCandidate: RevealAssertionCandidate {
    private let backend: any SystemItemVisibilitySnapshotCapturing
    private let inner: any RevealAssertionCandidate
    private let plan: SystemItemVisibilityPlan
    private let confirmation: String
    private let settleDelay: Duration
    private var stopped = false
    private var touched = false
    public private(set) var appliedVerified = false
    public private(set) var restoreVerified = false
    public private(set) var observedNativeOverflowCount = -1
    public private(set) var failure: String?

    public init(
        backend: any SystemItemVisibilitySnapshotCapturing,
        inner: any RevealAssertionCandidate,
        plan: SystemItemVisibilityPlan,
        confirmation: String,
        settleDelay: Duration = .seconds(1)
    ) {
        self.backend = backend
        self.inner = inner
        self.plan = plan
        self.confirmation = confirmation
        self.settleDelay = settleDelay
    }

    public nonisolated func activate() async throws { try await activateOnMainActor() }

    private func activateOnMainActor() async throws {
        guard !stopped else { throw SystemItemVisibilityValidationError.stopped }
        try plan.validate()
        guard confirmation == (try plan.fingerprint) else {
            throw SystemItemVisibilityValidationError.unconfirmedPlan
        }
        try plan.validateFresh(await backend.capture())
        touched = true
        try await inner.activate()
        try await Task.sleep(for: settleDelay)
        let applied = try await backend.capture()
        observedNativeOverflowCount = applied.nativeOverflowFrames.count
        try plan.validateApplied(applied)
        appliedVerified = true
    }

    public nonisolated func invalidate() async { await restoreOnMainActor() }

    private func restoreOnMainActor() async {
        guard !stopped else { return }
        stopped = true
        guard touched else {
            restoreVerified = true
            return
        }
        await inner.invalidate()
        do {
            try await Task.sleep(for: settleDelay)
            try plan.validateRestored(await backend.capture())
            restoreVerified = true
        } catch {
            failure = String(describing: error)
            restoreVerified = false
        }
    }
}

public struct SystemItemVisibilityValidationFactory: RevealAssertionCandidateFactory {
    public let candidate: SystemItemVisibilityValidationCandidate
    public let expectedPlan: RevealAllowlistPlan

    public init(candidate: SystemItemVisibilityValidationCandidate,
                expectedPlan: RevealAllowlistPlan) {
        self.candidate = candidate
        self.expectedPlan = expectedPlan
    }

    public func makeCandidate(
        for plan: RevealAllowlistPlan
    ) throws -> any RevealAssertionCandidate {
        guard plan == expectedPlan else {
            throw SystemItemVisibilityValidationError.invalidScope
        }
        return candidate
    }
}

@MainActor
public final class MacOS27SystemItemVisibilityBackend:
    SystemItemVisibilitySnapshotCapturing
{
    private let inventory: AccessibilityInventory
    private let diagnostic: (@MainActor (String) -> Void)?

    public init(
        inventory: AccessibilityInventory = AccessibilityInventory(),
        diagnostic: (@MainActor (String) -> Void)? = nil
    ) {
        self.inventory = inventory
        self.diagnostic = diagnostic
    }

    public func capture() async throws -> SystemItemVisibilitySnapshot {
        guard Bundle.main.bundleIdentifier == SystemItemVisibilityPlan.bundleIdentifier,
              AccessibilityAuthorization.isTrusted else {
            throw SystemItemVisibilityValidationError.invalidScope
        }
        let applications = runningApplications()
        let menuBarAgentApplications = applications.filter {
            $0.bundleIdentifier?.lowercased() == "com.apple.menubaragent"
        }
        let report = await inventory.capture(
            applications: menuBarAgentApplications,
            accessibilityTrusted: true,
            includeMenuBarAgentPresentationRoots: false
        )
        let systemItems = report.items.compactMap { record -> SystemItemAXObservation? in
            guard record.source == .menuBarAgent,
                  record.role == "AXMenuBarItem", record.subrole == "AXMenuExtra",
                  record.classification != .nativeOverflowPresentationControl,
                  let identifier = record.accessibilityIdentifier, !identifier.isEmpty else {
                return nil
            }
            return SystemItemAXObservation(identifier: identifier, frame: record.frame)
        }
        let nativeOverflowFrames = report.items.compactMap { record -> RectSnapshot?? in
            guard record.source == .menuBarAgent,
                  record.classification == .nativeOverflowPresentationControl else {
                return nil
            }
            return .some(record.frame)
        }
        let bundleIdentifiers = Array(Set(applications.compactMap(\.bundleIdentifier))).sorted()
        let snapshot = SystemItemVisibilitySnapshot(
            captureComplete: report.accessibilityTrusted
                && !report.elementLimitReached
                && !report.timeLimitReached
                && report.menuBarAgentProcessesFound == 1,
            systemItems: systemItems,
            nativeOverflowFrames: nativeOverflowFrames,
            scopedPreferences: try capturePreferences(),
            localFileDigests: try captureFiles(),
            runningBundleIdentifiers: bundleIdentifiers
        )
        diagnostic?(
            "capture agentProcesses=\(report.menuBarAgentProcessesFound)"
                + " trees=\(report.extrasMenuBarTreesFound)"
                + " limited=\(report.elementLimitReached || report.timeLimitReached)"
                + " errors=\(report.aggregateErrors.sorted { $0.key < $1.key })"
                + " systemIDs=\(snapshot.itemCounts.sorted { $0.key < $1.key })"
                + " nativeOverflow=\(snapshot.nativeOverflowFrames.count)"
                + " preferences=\(snapshot.scopedPreferences.count)"
                + " files=\(snapshot.localFileDigests.count)"
                + " bundles=\(snapshot.runningBundleIdentifiers.count)"
        )
        try snapshot.validateStructure()
        return snapshot
    }

    private func runningApplications() -> [RunningApplicationDescriptor] {
        var applications = NSWorkspace.shared.runningApplications
        applications.append(contentsOf: NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.MenuBarAgent"
        ))
        var seen = Set<pid_t>()
        return applications.compactMap { application in
            guard application.processIdentifier > 0,
                  seen.insert(application.processIdentifier).inserted else { return nil }
            return RunningApplicationDescriptor(
                processIdentifier: application.processIdentifier,
                bundleIdentifier: application.bundleIdentifier
            )
        }.sorted {
            (($0.bundleIdentifier ?? "").lowercased(), $0.processIdentifier)
                < (($1.bundleIdentifier ?? "").lowercased(), $1.processIdentifier)
        }
    }

    private func capturePreferences() throws -> [ScopedPreferenceSnapshot] {
        try SystemItemVisibilitySnapshot.preferenceDomains.map { domain in
            let copied = CFPreferencesCopyMultiple(
                nil, domain as CFString, kCFPreferencesCurrentUser,
                kCFPreferencesAnyHost
            ) as? [String: Any] ?? [:]
            let scoped = copied.filter { key, _ in
                key.hasPrefix("NSStatusItem ")
                    || (domain == "com.apple.MenuBarAgent"
                        && key == "TrailingItemPreferredPositions")
            }
            let encoded = try PropertyListSerialization.data(
                fromPropertyList: scoped, format: .binary, options: 0
            )
            return ScopedPreferenceSnapshot(domain: domain, encodedValues: encoded)
        }
    }

    private func captureFiles() throws -> [LocalFileDigest] {
        let manager = FileManager.default
        let home = manager.homeDirectoryForCurrentUser
        var relativePaths = SystemItemVisibilitySnapshot.requiredFilePaths
        let byHostRelativePath = "Library/Preferences/ByHost"
        let byHostURL = home.appendingPathComponent(byHostRelativePath, isDirectory: true)
        if let names = try? manager.contentsOfDirectory(atPath: byHostURL.path) {
            relativePaths.append(contentsOf: names.filter { name in
                name.hasPrefix("com.apple.controlcenter.")
                    || name.hasPrefix("com.apple.systemuiserver.")
                    || name.hasPrefix("com.apple.MenuBarAgent.")
            }.map { "\(byHostRelativePath)/\($0)" })
        }
        return try Array(Set(relativePaths)).sorted().map { relativePath in
            let url = home.appendingPathComponent(relativePath)
            guard manager.fileExists(atPath: url.path) else {
                return LocalFileDigest(relativePath: relativePath, exists: false,
                                       byteCount: 0, sha256: nil)
            }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard data.count <= 4_194_304 else {
                throw SystemItemVisibilityValidationError.invalidScope
            }
            let digest = SHA256.hash(data: data)
                .map { String(format: "%02x", $0) }.joined()
            return LocalFileDigest(relativePath: relativePath, exists: true,
                                   byteCount: data.count, sha256: digest)
        }
    }
}
#endif
