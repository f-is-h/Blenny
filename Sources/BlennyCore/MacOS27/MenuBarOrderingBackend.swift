#if BLENNY_PRODUCT || DEBUG
import AppKit
import ApplicationServices
import BlennyPrivateABIShim
import CryptoKit
import Darwin
import Foundation
import ObjectiveC.runtime
import Security

public struct MacOS27MenuBarOrderingContext: Equatable, Sendable {
    public let policyFingerprint: String
    public let orderingAllowedBundleIdentifiers: Set<String>
    public let lifecycleGeneration: Int

    public init(
        policyFingerprint: String,
        orderingAllowedBundleIdentifiers: Set<String>,
        lifecycleGeneration: Int
    ) {
        self.policyFingerprint = policyFingerprint
        self.orderingAllowedBundleIdentifiers = orderingAllowedBundleIdentifiers
        self.lifecycleGeneration = lifecycleGeneration
    }

    func hasSamePolicyContext(as other: Self) -> Bool {
        policyFingerprint == other.policyFingerprint
            && lifecycleGeneration == other.lifecycleGeneration
    }
}

public enum MacOS27MenuBarOrderingBackendError: Error, Equatable, LocalizedError, Sendable {
    case runtimeUnsupported
    case runtimeContractDiffers
    case groupFileOpenFailed(Int32)
    case groupFileMetadataReadFailed(Int32)
    case groupFileMetadataInvalid
    case groupFileReadFailed(Int32)
    case groupFileReadIncomplete
    case groupFileDecodeFailed
    case groupFileTableUnavailable
    case groupContainerTableUnavailable
    case groupTooLarge
    case groupValueUnsupported
    case groupSourcesDisagree
    case groupChangedDuringCapture
    case contextChangedDuringCapture
    case displayChangedDuringCapture
    case invalidWriteScope
    case staleSnapshot
    case synchronizationFailed

    public var errorDescription: String? {
        switch self {
        case .runtimeUnsupported:
            "Ordering requires the verified macOS 27 arm64 build."
        case .runtimeContractDiffers:
            "The private menu-bar defaults contract differs from the verified runtime."
        case let .groupFileOpenFailed(errorNumber)
            where errorNumber == EPERM || errorNumber == EACCES:
            "macOS denied Blenny access to the menu-bar preference file (errno \(errorNumber))."
        case let .groupFileOpenFailed(errorNumber):
            "The menu-bar preference file could not be opened (errno \(errorNumber))."
        case let .groupFileMetadataReadFailed(errorNumber)
            where errorNumber == EPERM || errorNumber == EACCES:
            "macOS denied Blenny access while reading menu-bar preference metadata (errno \(errorNumber))."
        case let .groupFileMetadataReadFailed(errorNumber):
            "The menu-bar preference file metadata could not be read (errno \(errorNumber))."
        case .groupFileMetadataInvalid:
            "The menu-bar preference file metadata does not satisfy the bounded reader."
        case let .groupFileReadFailed(errorNumber)
            where errorNumber == EPERM || errorNumber == EACCES:
            "macOS denied Blenny access while reading the menu-bar preference file (errno \(errorNumber))."
        case let .groupFileReadFailed(errorNumber):
            "The menu-bar preference file read failed (errno \(errorNumber))."
        case .groupFileReadIncomplete:
            "The menu-bar preference file read ended before the complete file was available."
        case .groupFileDecodeFailed:
            "The complete menu-bar preference file could not be decoded."
        case .groupFileTableUnavailable:
            "The menu-bar preference file does not contain the ordering table."
        case .groupContainerTableUnavailable:
            "The menu-bar ordering table could not be read through the container preference API."
        case .groupTooLarge:
            "The menu-bar preference group exceeds the bounded capture limits."
        case .groupValueUnsupported:
            "The menu-bar preference group contains an unsupported property-list value."
        case .groupSourcesDisagree:
            "The container preference API and independent property-list read disagree."
        case .groupChangedDuringCapture:
            "The menu-bar preference group changed during capture."
        case .contextChangedDuringCapture:
            "The accepted policy or lifecycle generation changed during capture."
        case .displayChangedDuringCapture:
            "The display configuration changed during capture."
        case .invalidWriteScope:
            "The write does not preserve the bounded set of existing status-item positions."
        case .staleSnapshot:
            "The runtime, process, policy, lifecycle, display, or complete preference snapshot changed."
        case .synchronizationFailed:
            "The private group-defaults write failed or raised an exception; recovery must inspect current state."
        }
    }
}

/// Unsupported macOS 27 ordering capability. Construction and capture are
/// read-only. The existing CoordinatedPolicyWriter is the only product type
/// permitted to call writeTable after it has durably recorded recovery intent.
public final class MacOS27MenuBarOrderingBackend: MenuBarOrderingBackend, @unchecked Sendable {
    public typealias ContextProvider = @MainActor @Sendable () -> MacOS27MenuBarOrderingContext

    private static let supportedArchitecture = "arm64"
    private static let suiteName = "com.apple.MenuBar"
    private static let tableKey = "TrailingItemPreferredPositions"
    private static let initializerName = "_initWithSuiteName:container:"
    private static let initializerEncoding = "@32@0:8@16@24"
    private static let containerReadSymbol = "_CFPreferencesCopyValueWithContainer"
    private static let containerKeyListSymbol = "_CFPreferencesCopyKeyListWithContainer"
    private static let preferredPositionPrefix = "NSStatusItem Preferred Position "
    private static let maximumPlistBytes = 4 * 1_024 * 1_024
    private static let maximumTopLevelKeys = 512
    private static let maximumPositionKeys = 256
    private static let maximumOwnerPositionKeys = 64
    private static let maximumCollectionItems = 1_024
    private static let maximumValueNodes = 8_192
    private static let maximumValueDepth = 12
    private static let maximumStringBytes = 64 * 1_024
    private static let maximumDataBytes = 1 * 1_024 * 1_024
    private static let maximumMetadataBytes = 1 * 1_024 * 1_024

    static func privateWriterSupportsSystemVersionForTesting(_ version: String) -> Bool {
        blenny_menu_bar_ordering_supports_system_version(version as CFString)
    }
    private static let axCaptureDeadline = Duration.seconds(2)
    private static let layoutEventDeadline: DispatchTimeInterval = .milliseconds(800)
    // The protected plist can lag an acknowledged API write by more than six
    // seconds on macOS 27. Wait for its event, with one bounded fallback deadline.
    private static let preferenceSettlementDeadline = Duration.seconds(15)
    private static let controlCenterBinaryPath =
        "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter"
    private static let menuBarAgentBinaryPath =
        "/System/Library/CoreServices/MenuBarAgent.app/Contents/MacOS/MenuBarAgent"
    private static let controlCenterBinaryUUID = "E842FC2A-0AAB-350D-BEA6-66229257C329"
    private static let menuBarAgentBinaryUUID = "DE3CDABA-05ED-328C-88BE-41D240550156"
    private static let maximumPinnedBinaryBytes = 32 * 1_024 * 1_024

    private let contextProvider: ContextProvider
    private let fallbackIdentityProvider: (@MainActor @Sendable () -> FallbackNativeIdentity?)?

    public init(contextProvider: @escaping ContextProvider,
                fallbackIdentityProvider: (@MainActor @Sendable () -> FallbackNativeIdentity?)? = nil) {
        self.contextProvider = contextProvider
        self.fallbackIdentityProvider = fallbackIdentityProvider
    }

    static func sandboxContainerSourceIdentityForTesting(
        bundle: String, signingIdentifier: String, homeDirectoryPath: String
    ) -> String? {
        resolveSandboxContainer(
            bundle: bundle,
            signingIdentifier: signingIdentifier,
            homeDirectoryPath: homeDirectoryPath
        )?.sourceIdentity
    }

    static func sandboxPreferenceFileReadableForTesting(
        bundle: String, signingIdentifier: String, homeDirectoryPath: String
    ) -> Bool {
        guard let resolution = resolveSandboxContainer(
            bundle: bundle,
            signingIdentifier: signingIdentifier,
            homeDirectoryPath: homeDirectoryPath
        ) else { return false }
        return readSandboxPreferenceFile(
            bundle: bundle,
            expecting: resolution,
            homeDirectoryPath: homeDirectoryPath
        ) != nil
    }

    static func exactBundleApplicationIdentityForTesting(
        process: OrderingProcess,
        table: [String: OrderingValue],
        processes: [OrderingProcess],
        signingIdentifier: String,
        teamIdentifier: String? = "TEAM123456",
        designatedRequirementDigest: String = String(repeating: "a", count: 64)
    ) -> OrderingApplicationCodeIdentity? {
        exactBundleApplicationIdentity(
            seed: OwnerSeed(process: process, displayName: "Test Owner"),
            table: table, processes: processes,
            codeIdentity: CodeIdentity(
                sandboxed: true, signingIdentifier: signingIdentifier,
                teamIdentifier: teamIdentifier,
                designatedRequirementDigest: designatedRequirementDigest
            )
        )
    }

    static func configurationOwnerKeys(
        for changedKeys: [String], table: [String: OrderingValue], processes: [OrderingProcess]
    ) -> Set<String> {
        let systemKeys = Set(changedKeys.filter { exactSystemItem(for: $0) != nil })
        let applicationKeys = changedKeys.filter { !systemKeys.contains($0) }
        let affectedPIDs = Set(ownerPIDs(for: applicationKeys, in: processes))
        let tokens = Set(processes.filter { affectedPIDs.contains($0.pid) }.flatMap {
            [$0.bundleIdentifier, $0.executableName].compactMap { $0 }
        })
        // Even an owner's unchanged sibling key remains part of its identity.
        // A collision on that key must be refused before any sibling is written.
        return Set(table.keys.filter {
            exactSystemItem(for: $0) == nil
                && parseStatusKey($0).map { tokens.contains($0.ownerToken) } == true
        }).union(systemKeys)
    }

    static func validateWriteScopeForTesting(
        previous: [String: OrderingValue], proposed: [String: OrderingValue],
        configurationMode: Bool = false
    ) throws -> [String] {
        try validateWriteScope(
            previous: previous, proposed: proposed,
            maximumChangedKeys: configurationMode
                ? OrderingPlan.maximumConfigurationKeys : OrderingPlan.maximumReorderingTargets,
            allowsExactSystemItems: configurationMode
        )
    }

    static func controlCenterNamespaceEligibleForTesting(
        _ table: [String: OrderingValue]
    ) -> Bool {
        ExactSystemOrderingItem.controlCenter.admitsConfigurationTable(table)
    }

    static func controlCenterBinaryUUIDsMatchForTesting(
        controlCenter: String?, menuBarAgent: String?
    ) -> Bool {
        pinnedControlCenterBinaryUUIDsMatch(
            controlCenter: controlCenter, menuBarAgent: menuBarAgent
        )
    }

    public func capture() async throws -> OrderingSnapshot {
        try await capture(transition: nil)
    }

    /// Explicit diagnostic entry point for a fresh instance of the installed
    /// executable. It creates no status items, writer, policy store, or recovery
    /// lease, and does not synchronize the preference domain.
    public static func preferenceReadDiagnostic(bookmarkError: String? = nil) throws -> Data {
        struct Report: Encodable {
            let process: Int32
            let groups: [String: [String: OrderingValue]]
            let errors: [String: String]
        }
        var groups: [String: [String: OrderingValue]] = [:]
        var errors: [String: String] = [:]
        if let bookmarkError { errors["bookmark"] = bookmarkError }
        for source in ["fileBefore", "container", "fileAfter"] {
            do {
                groups[source] = source == "container"
                    ? [tableKey: .dictionary(try tableFromContainerRead())]
                    : try decodeGroup(readPlistRoot())
            } catch { errors[source] = error.localizedDescription }
        }
        OrderingPreferenceDiagnostics.record("explicit-fresh-read", groups: groups,
                                             detail: errors.description)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Report(process: getpid(), groups: groups, errors: errors))
    }

    public func captureConfigurationTransition(
        from snapshot: OrderingSnapshot, to table: [String: OrderingValue]
    ) async throws -> OrderingSnapshot {
        try snapshot.validate()
        var expectedGroup = snapshot.group
        expectedGroup[Self.tableKey] = .dictionary(table)
        return try await capture(transition: PostWriteReadback(
            previousGroup: snapshot.group, expectedGroup: expectedGroup
        ))
    }

    private func capture(transition postWriteReadback: PostWriteReadback?) async throws
        -> OrderingSnapshot {
        let firstBuild = try Self.validateRuntimeContract()
        let firstGroup = try await Self.readCorroboratedGroupAfterBoundedSettle(
            transition: postWriteReadback
        )
        let firstTable = try Self.table(in: firstGroup)
        let firstPlatform = await MainActor.run {
            Self.capturePlatform(context: contextProvider())
        }
        let firstSystemBindings = Self.captureSystemHostBindings(
            in: firstPlatform.processes, table: firstTable
        )
        let candidateSeeds = Self.candidateSeeds(
            in: firstPlatform.ownerSeeds, table: firstTable
        )
        let deadline = ContinuousClock.now.advanced(by: Self.axCaptureDeadline)
        let observations = await Task.detached(priority: .utility) {
            var result: [Int32: OrderingOwnerObservation] = [:]
            var axByPID: [Int32: AXCapture] = [:]
            for seed in candidateSeeds {
                axByPID[seed.process.pid] = Self.captureAXItems(
                    pid: seed.process.pid, deadline: deadline
                )
            }
            for seed in candidateSeeds {
                let ax = axByPID[seed.process.pid]
                    ?? AXCapture(complete: false, frames: [])
                let codeIdentity = Self.codeIdentity(pid: seed.process.pid)
                let exactBundleCodeIdentity = Self.exactBundleApplicationIdentity(
                    seed: seed, table: firstTable, processes: firstPlatform.processes,
                    codeIdentity: codeIdentity
                )
                let preferences = exactBundleCodeIdentity == nil
                    ? Self.captureOwnerPreferences(seed: seed)
                    : PreferenceCapture(
                        complete: false, positions: [:], namespace: .unknown,
                        sourceIdentity: nil
                    )
                result[seed.process.pid] = OrderingOwnerObservation(
                    process: seed.process,
                    displayName: seed.displayName,
                    axComplete: ax.complete,
                    itemFrames: ax.frames,
                    ownerPreferencesComplete: preferences.complete,
                    ownerSavedPositions: preferences.positions,
                    ownerPreferenceNamespace: preferences.namespace,
                    ownerPreferenceSourceIdentity: preferences.sourceIdentity,
                    applicationCodeIdentity: exactBundleCodeIdentity
                )
            }
            return result
        }.value
        let secondPlatform = await MainActor.run {
            Self.capturePlatform(context: contextProvider())
        }
        let secondBuild = try Self.validateRuntimeContract()
        let secondGroup = try await Self.readCorroboratedGroupAfterBoundedSettle(
            transition: postWriteReadback
        )
        let secondSystemBindings = Self.captureSystemHostBindings(
            in: secondPlatform.processes, table: try Self.table(in: secondGroup)
        )

        guard firstBuild == secondBuild else {
            throw MacOS27MenuBarOrderingBackendError.runtimeContractDiffers
        }
        guard firstGroup == secondGroup else {
            throw MacOS27MenuBarOrderingBackendError.groupChangedDuringCapture
        }
        // Running pass-through owners are inventory evidence, not a policy
        // revision. Selected lifetimes and token collisions are checked from
        // both inventories; unrelated launches must not invalidate a read.
        guard firstPlatform.context.hasSamePolicyContext(as: secondPlatform.context) else {
            throw MacOS27MenuBarOrderingBackendError.contextChangedDuringCapture
        }
        guard firstPlatform.display == secondPlatform.display else {
            throw MacOS27MenuBarOrderingBackendError.displayChangedDuringCapture
        }

        return try OrderingSnapshot(
            group: secondGroup,
            beforeProcesses: firstPlatform.processes,
            afterProcesses: secondPlatform.processes,
            observationsByPID: observations,
            osBuild: secondBuild,
            architecture: Self.supportedArchitecture,
            runtimeContractVerified: true,
            displaySignature: secondPlatform.display.signature,
            displayCount: secondPlatform.display.count,
            displayFrame: secondPlatform.display.frame,
            lifecycleGeneration: secondPlatform.context.lifecycleGeneration,
            policyFingerprint: secondPlatform.context.policyFingerprint,
            orderingAllowedBundleIdentifiers: secondPlatform.context.orderingAllowedBundleIdentifiers,
            systemHostBindings: secondSystemBindings.filter { firstSystemBindings.contains($0) },
            capturedAt: Date()
        )
    }

    static func readCorroboratedGroupAfterBoundedSettle(
        read: () throws -> [String: OrderingValue],
        settle: () async throws -> Void
    ) async throws -> [String: OrderingValue] {
        do {
            return try read()
        } catch let error as MacOS27MenuBarOrderingBackendError
            where error == .groupSourcesDisagree {
            // cfprefsd may acknowledge a synchronized container write before
            // its container API and on-disk plist expose the same generation.
            // Wait once and repeat the complete corroborated read; never poll
            // and never repeat the system write.
            try await settle()
            return try read()
        }
    }

    static func corroboratedGroup(
        first: [String: OrderingValue], containerTable: [String: OrderingValue],
        second: [String: OrderingValue]
    ) throws -> [String: OrderingValue] {
        guard first == second else {
            throw MacOS27MenuBarOrderingBackendError.groupChangedDuringCapture
        }
        guard try table(in: second) == containerTable else {
            throw MacOS27MenuBarOrderingBackendError.groupSourcesDisagree
        }
        return second
    }

    public func writeTable(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot
    ) async throws {
        try await performWrite(table, expecting: snapshot, requiresSingleDisplay: true)
    }

    public func writeConfigurationTable(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot,
        ownerKeys: Set<String>
    ) async throws {
        try await performWrite(
            table, expecting: snapshot, requiresSingleDisplay: true,
            requiresGeometry: false, configurationKeys: ownerKeys
        )
    }

    public func restoreConfigurationTable(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot,
        ownerKeys: Set<String>
    ) async throws {
        try await performWrite(
            table, expecting: snapshot, requiresSingleDisplay: false,
            requiresGeometry: false, configurationKeys: ownerKeys
        )
    }

    /// Receipt-backed inverse path. The coordinator validates the exact known
    /// target transition before invoking this after lifecycle/display change.
    public func restoreTable(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot
    ) async throws {
        try await performWrite(table, expecting: snapshot, requiresSingleDisplay: false)
    }

    private func performWrite(
        _ table: [String: OrderingValue],
        expecting snapshot: OrderingSnapshot,
        requiresSingleDisplay: Bool,
        requiresGeometry: Bool = true,
        configurationKeys: Set<String>? = nil,
        fallbackIdentity: FallbackNativeIdentity? = nil
    ) async throws {
        try snapshot.validate()
        let previous = try snapshot.table()
        let changedKeys = try Self.validateWriteScope(
            previous: previous, proposed: table,
            maximumChangedKeys: requiresGeometry
                ? OrderingPlan.maximumReorderingTargets : OrderingPlan.maximumConfigurationKeys,
            allowsExactSystemItems: !requiresGeometry
        )
        if changedKeys.isEmpty { return }

        let completeChangedOwnerKeys = Self.configurationOwnerKeys(
            for: changedKeys, table: previous, processes: snapshot.afterProcesses
        )
        let ownerKeyScope = configurationKeys ?? completeChangedOwnerKeys
        if !requiresGeometry {
            guard completeChangedOwnerKeys.isSubset(of: ownerKeyScope),
                  Set(changedKeys).isSubset(of: ownerKeyScope) else {
                throw MacOS27MenuBarOrderingBackendError.invalidWriteScope
            }
            try snapshot.validateConfigurationProcessScope(
                for: ownerKeyScope, against: snapshot.afterProcesses,
                systemHostBindings: snapshot.systemHostBindings ?? []
            )
        }
        let applicationScope = ownerKeyScope.filter { Self.exactSystemItem(for: $0) == nil }
        let applicationPIDs = Self.ownerPIDs(for: Array(applicationScope), in: snapshot.afterProcesses)
        let ownerPIDs = Self.ownerPIDs(
            for: requiresGeometry ? changedKeys : Array(ownerKeyScope),
            in: snapshot.afterProcesses
        )
        try await Self.validateOwnerEvidence(
            snapshot: snapshot, ownerPIDs: requiresGeometry ? ownerPIDs : applicationPIDs,
            requiresGeometry: requiresGeometry
        )
        let observation = await MainActor.run {
            LayoutChangeObservation.arm(ownerPIDs: ownerPIDs)
        }

        do {
            try await MainActor.run {
                let currentBuild = try Self.validateRuntimeContract()
                guard snapshot.runtimeContractVerified,
                      snapshot.osBuild == currentBuild,
                      snapshot.architecture == Self.supportedArchitecture,
                      (!requiresSingleDisplay || snapshot.displayCount == 1),
                      (1...16).contains(snapshot.displayCount) else {
                    throw MacOS27MenuBarOrderingBackendError.runtimeContractDiffers
                }
                let platform = Self.capturePlatform(context: contextProvider())
                if requiresGeometry {
                    guard platform.processes == snapshot.afterProcesses,
                          platform.context.orderingAllowedBundleIdentifiers == snapshot.orderingAllowedBundleIdentifiers else {
                        throw MacOS27MenuBarOrderingBackendError.staleSnapshot
                    }
                } else {
                    try snapshot.validateConfigurationProcessScope(
                        for: ownerKeyScope, against: platform.processes,
                        systemHostBindings: Self.captureSystemHostBindings(
                            in: platform.processes, table: previous
                        )
                    )
                }
                guard platform.context.lifecycleGeneration == snapshot.lifecycleGeneration,
                      platform.context.policyFingerprint == snapshot.policyFingerprint,
                      platform.display.signature == snapshot.displaySignature,
                      platform.display.count == snapshot.displayCount,
                      platform.display.frame == snapshot.displayFrame else {
                    throw MacOS27MenuBarOrderingBackendError.staleSnapshot
                }
                guard try Self.readCorroboratedGroup() == snapshot.group else {
                    throw MacOS27MenuBarOrderingBackendError.staleSnapshot
                }
                if let fallbackIdentity {
                    guard self.fallbackIdentityProvider?() == fallbackIdentity,
                          platform.processes.filter({ $0.bundleIdentifier == "xyz.fi5h.blenny" }).count == 1,
                          platform.processes.contains(where: {
                              $0.bundleIdentifier == "xyz.fi5h.blenny" && $0.pid == fallbackIdentity.pid
                          }) else {
                        throw OrderingTransactionError.recoveryIdentityConflict
                    }
                }
                observation.resetForWrite()
                try Self.write(table: table)
            }
        } catch {
            await observation.cancel()
            throw error
        }

        // A layout event normally ends this wait early. The deadline is only a
        // bounded handoff to the coordinator's single independent capture.
        await observation.wait(until: Self.layoutEventDeadline)
    }
}

extension MacOS27MenuBarOrderingBackend: FallbackPositionWriting {
    public func fallbackIdentity() async throws -> FallbackNativeIdentity {
        guard let identity = await fallbackIdentityProvider?() else {
            throw OrderingTransactionError.recoveryIdentityConflict
        }
        return identity
    }

    public func writeFallbackPosition(
        _ table: [String: OrderingValue], expecting snapshot: OrderingSnapshot,
        identity: FallbackNativeIdentity
    ) async throws {
        let previous = try snapshot.table()
        let changed = Set(previous.keys.filter { previous[$0] != table[$0] })
        guard Set(previous.keys) == Set(table.keys),
              !changed.isEmpty,
              changed.isSubset(of: [FallbackPositionDelta.key, FallbackPositionDelta.fishKey]) else {
            throw MacOS27MenuBarOrderingBackendError.invalidWriteScope
        }
        for key in changed {
            guard let original = previous[key], let proposed = table[key] else {
                throw MacOS27MenuBarOrderingBackendError.invalidWriteScope
            }
            _ = try FallbackPositionDelta(original: original, proposed: proposed)
        }
        let owners = snapshot.afterProcesses.filter { $0.bundleIdentifier == "xyz.fi5h.blenny" }
        guard owners.count == 1, owners[0].pid == identity.pid,
              snapshot.beforeProcesses.contains(owners[0]) else {
            throw OrderingTransactionError.recoveryIdentityConflict
        }
        let scope = Self.configurationOwnerKeys(for: Array(changed),
            table: previous, processes: snapshot.afterProcesses)
        try await performWrite(table, expecting: snapshot, requiresSingleDisplay: true,
            requiresGeometry: false, configurationKeys: scope, fallbackIdentity: identity)
    }
}

private extension MacOS27MenuBarOrderingBackend {
    struct PostWriteReadback: Sendable {
        let previousGroup: [String: OrderingValue]
        let expectedGroup: [String: OrderingValue]
    }

    struct OwnerSeed: Sendable {
        let process: OrderingProcess
        let displayName: String
    }

    struct DisplayState: Equatable, Sendable {
        let signature: String
        let count: Int
        let frame: RectSnapshot
    }

    struct PlatformState: Sendable {
        let processes: [OrderingProcess]
        let ownerSeeds: [OwnerSeed]
        let context: MacOS27MenuBarOrderingContext
        let display: DisplayState
    }

    struct AXCapture: Sendable {
        let complete: Bool
        let frames: [RectSnapshot]
    }

    struct PreferenceCapture: Sendable {
        let complete: Bool
        let positions: [String: OrderingValue]
        let namespace: OrderingOwnerPreferenceNamespace
        let sourceIdentity: String?
    }

    struct CodeIdentity: Sendable {
        let sandboxed: Bool
        let signingIdentifier: String?
        let teamIdentifier: String?
        let designatedRequirementDigest: String?

        var applicationIdentity: OrderingApplicationCodeIdentity? {
            guard let signingIdentifier, let designatedRequirementDigest else { return nil }
            return OrderingApplicationCodeIdentity(
                signingIdentifier: signingIdentifier,
                teamIdentifier: teamIdentifier,
                designatedRequirementDigest: designatedRequirementDigest
            )
        }
    }

    struct SandboxContainerResolution: Equatable, Sendable {
        let rootPath: String
        let dataPath: String
        let sourceIdentity: String
        let rootDevice: UInt64
        let rootInode: UInt64
        let dataDevice: UInt64
        let dataInode: UInt64
    }

    struct FileFacts: Equatable, Sendable {
        let device: UInt64
        let inode: UInt64
        let size: Int64
        let modifiedSeconds: Int
        let modifiedNanoseconds: Int
        let changedSeconds: Int
        let changedNanoseconds: Int
    }

    final class SandboxDirectoryHandles {
        let root: Int32
        let data: Int32
        let rootPath: String
        let dataPath: String
        let rootStatus: stat
        let dataStatus: stat

        init(
            root: Int32, data: Int32, rootPath: String, dataPath: String,
            rootStatus: stat, dataStatus: stat
        ) {
            self.root = root
            self.data = data
            self.rootPath = rootPath
            self.dataPath = dataPath
            self.rootStatus = rootStatus
            self.dataStatus = dataStatus
        }

        deinit {
            close(data)
            close(root)
        }
    }

    typealias ContainerRead = @convention(c) (
        CFString, CFString, CFString, CFString, CFString
    ) -> Unmanaged<CFPropertyList>?

    typealias ContainerKeyList = @convention(c) (
        CFString, CFString, CFString, CFString
    ) -> Unmanaged<CFArray>?

    static var groupContainerURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/com.apple.MenuBar", isDirectory: true)
    }

    static var groupPlistURL: URL {
        groupContainerURL
            .appendingPathComponent("Library/Preferences", isDirectory: true)
            .appendingPathComponent("com.apple.MenuBar.plist", isDirectory: false)
    }

    @discardableResult
    static func validateRuntimeContract() throws -> String {
        #if arch(arm64)
        let compileArchitecture = supportedArchitecture
        #else
        let compileArchitecture = "unsupported"
        #endif
        guard compileArchitecture == supportedArchitecture,
              runtimeArchitecture() == supportedArchitecture,
              ProcessInfo.processInfo.operatingSystemVersion.majorVersion
                == OrderingSnapshot.supportedOperatingSystemMajorVersion,
              let currentBuild = systemBuild(),
              OrderingSnapshot.supportsBuild(currentBuild) else {
            throw MacOS27MenuBarOrderingBackendError.runtimeUnsupported
        }
        let selector = NSSelectorFromString(initializerName)
        guard let method = class_getInstanceMethod(UserDefaults.self, selector),
              let encoding = method_getTypeEncoding(method),
              String(cString: encoding) == initializerEncoding,
              dlsym(UnsafeMutableRawPointer(bitPattern: -2), containerReadSymbol) != nil,
              dlsym(UnsafeMutableRawPointer(bitPattern: -2), containerKeyListSymbol) != nil else {
            throw MacOS27MenuBarOrderingBackendError.runtimeContractDiffers
        }
        return currentBuild
    }

    static func systemBuild() -> String? {
        guard let data = try? Data(
            contentsOf: URL(fileURLWithPath: "/System/Library/CoreServices/SystemVersion.plist")
        ), let root = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = root as? [String: Any] else { return nil }
        return dictionary["ProductBuildVersion"] as? String
    }

    static func runtimeArchitecture() -> String {
        var value = utsname()
        guard uname(&value) == 0 else { return "unknown" }
        return withUnsafePointer(to: &value.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    static func capturePlatform(context: MacOS27MenuBarOrderingContext) -> PlatformState {
        let applications = NSWorkspace.shared.runningApplications
        let seeds = applications.map { application -> OwnerSeed in
            let executablePath = application.executableURL?.standardizedFileURL.path
            let bundleIdentifier = application.bundleIdentifier
            let process = OrderingProcess(
                bundleIdentifier: bundleIdentifier,
                executableName: application.executableURL?.lastPathComponent,
                pid: application.processIdentifier,
                launchTime: application.launchDate
                    ?? OrderingProcessLifetime.read(pid: application.processIdentifier),
                isSystem: (bundleIdentifier?.hasPrefix("com.apple.") ?? false)
                    || (executablePath?.hasPrefix("/System/") ?? false)
            )
            return OwnerSeed(
                process: process,
                displayName: application.localizedName
                    ?? application.executableURL?.deletingPathExtension().lastPathComponent
                    ?? bundleIdentifier ?? "Unknown application"
            )
        }.sorted { lhs, rhs in
            if lhs.process.pid != rhs.process.pid { return lhs.process.pid < rhs.process.pid }
            return (lhs.process.bundleIdentifier ?? "") < (rhs.process.bundleIdentifier ?? "")
        }
        return PlatformState(
            processes: seeds.map(\.process), ownerSeeds: seeds,
            context: context, display: captureDisplay()
        )
    }

    static func codeIdentity(pid: pid_t) -> CodeIdentity? {
        var code: SecCode?
        let attributes = [kSecGuestAttributePid as String: NSNumber(value: pid)] as CFDictionary
        guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
              let code else { return nil }
        guard SecCodeCheckValidity(
            code, SecCSFlags(rawValue: kSecCSStrictValidate), nil
        ) == errSecSuccess else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
              let staticCode else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information
        )
                == errSecSuccess,
              let dictionary = information as? [String: Any] else { return nil }
        let entitlements = dictionary[kSecCodeInfoEntitlementsDict as String] as? [String: Any] ?? [:]
        var designatedRequirementDigest: String?
        var designatedRequirement: SecRequirement?
        if SecCodeCopyDesignatedRequirement(
            staticCode, [], &designatedRequirement
        ) == errSecSuccess, let designatedRequirement {
            var requirementText: CFString?
            if SecRequirementCopyString(
                designatedRequirement, [], &requirementText
            ) == errSecSuccess,
               let requirementText {
                designatedRequirementDigest = SHA256.hash(
                    data: Data((requirementText as String).utf8)
                ).map { String(format: "%02x", $0) }.joined()
            }
        }
        return CodeIdentity(
            sandboxed: entitlements["com.apple.security.app-sandbox"] as? Bool ?? false,
            signingIdentifier: dictionary[kSecCodeInfoIdentifier as String] as? String,
            teamIdentifier: dictionary[kSecCodeInfoTeamIdentifier as String] as? String,
            designatedRequirementDigest: designatedRequirementDigest
        )
    }

    static func captureDisplay() -> DisplayState {
        let screens = NSScreen.screens
        let records = screens.map { screen in
            (
                identifier: (screen.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")
                ] as? NSNumber)?.uint32Value ?? 0,
                frame: screen.frame,
                scale: screen.backingScaleFactor
            )
        }.sorted { lhs, rhs in
            if lhs.identifier != rhs.identifier { return lhs.identifier < rhs.identifier }
            if lhs.frame.origin.x != rhs.frame.origin.x { return lhs.frame.origin.x < rhs.frame.origin.x }
            return lhs.frame.origin.y < rhs.frame.origin.y
        }
        let signatureEntries = records.map { record in
            String(
                format: "id=%u,frame=%.6f,%.6f,%.6f,%.6f,scale=%.6f",
                locale: Locale(identifier: "en_US_POSIX"),
                record.identifier, record.frame.origin.x, record.frame.origin.y,
                record.frame.size.width, record.frame.size.height, record.scale
            )
        }
        let signature = "count=\(records.count)|" + signatureEntries.joined(separator: "|")
        let frame = records.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        let boundedFrame = frame.isNull ? .zero : frame
        return DisplayState(
            signature: signature,
            count: screens.count,
            frame: RectSnapshot(
                x: boundedFrame.origin.x, y: boundedFrame.origin.y,
                width: boundedFrame.size.width, height: boundedFrame.size.height
            )
        )
    }

    static func candidateSeeds(
        in seeds: [OwnerSeed], table: [String: OrderingValue]
    ) -> [OwnerSeed] {
        let tokens = Set(table.keys.compactMap(parseStatusKey).map(\.ownerToken))
        return seeds.filter { seed in
            guard !tokens.isEmpty else { return false }
            return [seed.process.bundleIdentifier, seed.process.executableName]
                .compactMap { $0 }.contains(where: tokens.contains)
        }
    }

    static func exactBundleApplicationIdentity(
        seed: OwnerSeed,
        table: [String: OrderingValue],
        processes: [OrderingProcess],
        codeIdentity: CodeIdentity?
    ) -> OrderingApplicationCodeIdentity? {
        guard let bundle = seed.process.bundleIdentifier,
              let codeIdentity,
              codeIdentity.signingIdentifier == bundle,
              let applicationIdentity = codeIdentity.applicationIdentity else { return nil }
        let associated = table.keys.compactMap(parseStatusKey).filter { parsed in
            parsed.ownerToken == seed.process.bundleIdentifier
                || parsed.ownerToken == seed.process.executableName
        }
        guard associated.contains(where: { $0.ownerToken == bundle }) else { return nil }
        for parsed in associated {
            guard processes.filter({ process in
                      parsed.ownerToken == process.bundleIdentifier
                          || parsed.ownerToken == process.executableName
                  }) == [seed.process] else { return nil }
        }
        return applicationIdentity
    }

    static func parseStatusKey(_ key: String) -> (ownerToken: String, persistentIdentifier: String)? {
        guard key.hasPrefix("status:"), key.utf8.count <= maximumStringBytes else { return nil }
        let body = key.dropFirst("status:".count)
        let components = body.components(separatedBy: "::")
        guard components.count == 2, !components[0].isEmpty, !components[1].isEmpty,
              key.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) else {
            return nil
        }
        return (components[0], components[1])
    }

    static func ownerPIDs(for keys: [String], in processes: [OrderingProcess]) -> [pid_t] {
        let tokens = Set(keys.compactMap(parseStatusKey).map(\.ownerToken))
        let systemHosts = Set(keys.compactMap(exactSystemItem).map(\.hostBundleIdentifier))
        return Set(processes.compactMap { process -> pid_t? in
            let matches = [process.bundleIdentifier, process.executableName]
                .compactMap { $0 }.contains(where: tokens.contains)
            return matches || process.bundleIdentifier.map(systemHosts.contains) == true ? process.pid : nil
        }).sorted()
    }

    static func exactSystemItem(for key: String) -> ExactSystemOrderingItem? {
        ExactSystemOrderingItem.allCases.first { $0.configurationKey == key }
    }

    static func captureSystemHostBindings(
        in processes: [OrderingProcess], table: [String: OrderingValue]
    ) -> [OrderingSystemHostBinding] {
        var verifiedHosts: [String: OrderingProcess] = [:]
        for bundle in Set(ExactSystemOrderingItem.allCases.map(\.hostBundleIdentifier)) {
            let owners = processes.filter { $0.bundleIdentifier == bundle }
            guard owners.count == 1, let owner = owners.first,
                  owner.isSystem, owner.launchTime != nil,
                  verifyAppleSystemHost(owner) else { continue }
            verifiedHosts[bundle] = owner
        }
        // This is intentionally read only and scoped to the one experimental
        // primary BentoBox mapping. The other exact items retain their existing
        // signed-host contract and do not depend on these additional pins.
        let controlCenterBinaryContract: Bool
        if ExactSystemOrderingItem.controlCenter.admitsConfigurationTable(table),
           verifiedHosts[ExactSystemOrderingItem.controlCenter.hostBundleIdentifier] != nil {
            controlCenterBinaryContract = pinnedControlCenterBinaryUUIDsMatch(
                controlCenter: machOUUID(atPath: controlCenterBinaryPath),
                menuBarAgent: machOUUID(atPath: menuBarAgentBinaryPath)
            )
        } else {
            controlCenterBinaryContract = false
        }
        return ExactSystemOrderingItem.allCases.compactMap { item in
            guard item.admitsConfigurationTable(table),
                  (item != .controlCenter || controlCenterBinaryContract),
                  let host = verifiedHosts[item.hostBundleIdentifier],
                  (item != .spotlight || host.executableName == "Siri AI") else {
                return nil
            }
            return OrderingSystemHostBinding(
                item: item, configurationKey: item.configurationKey,
                hostProcess: host, codeIdentityVerified: true
            )
        }
    }

    static func verifyAppleSystemHost(_ process: OrderingProcess) -> Bool {
        guard let bundle = process.bundleIdentifier,
              ExactSystemOrderingItem.allCases.contains(where: { $0.hostBundleIdentifier == bundle }) else {
            return false
        }
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(
            "anchor apple and identifier \"\(bundle)\"" as CFString, [], &requirement
        ) == errSecSuccess, let requirement else { return false }
        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil,
            [kSecGuestAttributePid as String: NSNumber(value: process.pid)] as CFDictionary,
            [], &code
        ) == errSecSuccess, let code else { return false }
        return SecCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), requirement) == errSecSuccess
    }

    static func pinnedControlCenterBinaryUUIDsMatch(
        controlCenter: String?, menuBarAgent: String?
    ) -> Bool {
        controlCenter?.uppercased() == controlCenterBinaryUUID
            && menuBarAgent?.uppercased() == menuBarAgentBinaryUUID
    }

    /// Reads only the bounded Mach-O load-command region and accepts the thin
    /// little-endian arm64 form used by both binaries on the pinned build.
    static func machOUUID(atPath path: String) -> String? {
        let descriptor = open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }
        var status = stat()
        guard fstat(descriptor, &status) == 0,
              status.st_uid == 0, status.st_mode & S_IFMT == S_IFREG,
              status.st_size >= 32,
              status.st_size <= Int64(maximumPinnedBinaryBytes) else {
            return nil
        }
        var header = Data(count: 32)
        guard readExactly(header: &header, descriptor: descriptor, offset: 0),
              readUInt32(header, at: 0) == 0xFEEDFACF,
              let commandCount = readUInt32(header, at: 16), commandCount <= 4_096,
              let commandBytes = readUInt32(header, at: 20), commandBytes <= 4 * 1_024 * 1_024,
              Int64(32 + commandBytes) <= status.st_size else { return nil }
        var commands = Data(count: Int(commandBytes))
        guard readExactly(header: &commands, descriptor: descriptor, offset: 32) else {
            return nil
        }
        var offset = 0
        for _ in 0..<commandCount {
            guard let command = readUInt32(commands, at: offset),
                  let size = readUInt32(commands, at: offset + 4),
                  size >= 8, offset + Int(size) <= commands.count else { return nil }
            if command == UInt32(LC_UUID) {
                guard size >= 24 else { return nil }
                let bytes = [UInt8](commands[(offset + 8)..<(offset + 24)])
                let hex = bytes.map { String(format: "%02X", $0) }.joined()
                return "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-"
                    + "\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-"
                    + "\(hex.dropFirst(20).prefix(12))"
            }
            offset += Int(size)
        }
        return nil
    }

    static func readUInt32(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        return data.withUnsafeBytes { bytes in
            let base = bytes.bindMemory(to: UInt8.self)
            return UInt32(base[offset])
                | UInt32(base[offset + 1]) << 8
                | UInt32(base[offset + 2]) << 16
                | UInt32(base[offset + 3]) << 24
        }
    }

    static func readExactly(
        header data: inout Data, descriptor: Int32, offset: Int64
    ) -> Bool {
        data.withUnsafeMutableBytes { bytes in
            guard let base = bytes.baseAddress else { return bytes.isEmpty }
            var completed = 0
            while completed < bytes.count {
                let count = pread(
                    descriptor, base.advanced(by: completed), bytes.count - completed,
                    off_t(offset + Int64(completed))
                )
                if count > 0 { completed += count; continue }
                if count < 0 && errno == EINTR { continue }
                return false
            }
            return true
        }
    }

    static func captureAXItems(pid: pid_t, deadline: ContinuousClock.Instant) -> AXCapture {
        guard AXIsProcessTrusted(), ContinuousClock.now < deadline else {
            return AXCapture(complete: false, frames: [])
        }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.15)
        guard let root = copyAXElement(application, attribute: kAXExtrasMenuBarAttribute as CFString)
        else { return AXCapture(complete: false, frames: []) }

        var pending: [(AXUIElement, Int)] = [(root, 0)]
        var visited: [AXUIElement] = []
        var frames: [RectSnapshot] = []
        var complete = true
        while let (element, depth) = pending.popLast() {
            guard ContinuousClock.now < deadline, visited.count < 128 else {
                complete = false
                break
            }
            if visited.contains(where: { CFEqual($0, element) }) { continue }
            visited.append(element)
            AXUIElementSetMessagingTimeout(element, 0.1)
            guard let role = copyAXString(element, attribute: kAXRoleAttribute as CFString) else {
                complete = false
                continue
            }
            if role == kAXMenuBarItemRole as String || role == kAXButtonRole as String {
                var owner: pid_t = 0
                guard AXUIElementGetPid(element, &owner) == .success, owner == pid,
                      let frame = copyAXFrame(element) else {
                    complete = false
                    continue
                }
                frames.append(frame)
            } else if role == kAXMenuBarRole as String || role == kAXGroupRole as String {
                guard depth < 8, let children = copyAXChildren(element),
                      children.count + pending.count + visited.count <= 128 else {
                    complete = false
                    continue
                }
                pending += children.map { ($0, depth + 1) }
            } else {
                complete = false
            }
        }
        frames.sort {
            if $0.x != $1.x { return $0.x < $1.x }
            if $0.y != $1.y { return $0.y < $1.y }
            if $0.width != $1.width { return $0.width < $1.width }
            return $0.height < $1.height
        }
        return AXCapture(complete: complete, frames: frames)
    }

    static func copyAXElement(_ element: AXUIElement, attribute: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    static func copyAXString(_ element: AXUIElement, attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    static func copyAXChildren(_ element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXChildrenAttribute as CFString, &value
        ) == .success else { return nil }
        return value as? [AXUIElement]
    }

    static func copyAXFrame(_ element: AXUIElement) -> RectSnapshot? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXPositionAttribute as CFString, &positionValue
        ) == .success,
              AXUIElementCopyAttributeValue(
                element, kAXSizeAttribute as CFString, &sizeValue
              ) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        let positionAX = unsafeDowncast(positionValue, to: AXValue.self)
        let sizeAX = unsafeDowncast(sizeValue, to: AXValue.self)
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetType(positionAX) == .cgPoint,
              AXValueGetType(sizeAX) == .cgSize,
              AXValueGetValue(positionAX, .cgPoint, &position),
              AXValueGetValue(sizeAX, .cgSize, &size),
              position.x.isFinite, position.y.isFinite,
              size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return nil }
        return RectSnapshot(
            x: position.x, y: position.y, width: size.width, height: size.height
        )
    }

    static func captureOwnerPreferences(seed: OwnerSeed) -> PreferenceCapture {
        guard let identity = codeIdentity(pid: seed.process.pid),
              let bundle = seed.process.bundleIdentifier else {
            return PreferenceCapture(
                complete: false, positions: [:], namespace: .unknown, sourceIdentity: nil
            )
        }
        if identity.sandboxed {
            guard identity.signingIdentifier == bundle,
                  let result = captureSandboxOwnerPreferences(
                    bundle: bundle, signingIdentifier: identity.signingIdentifier!
                  ) else {
                return PreferenceCapture(
                    complete: false, positions: [:], namespace: .sandboxed,
                    sourceIdentity: nil
                )
            }
            return result
        }

        let namespace = OrderingOwnerPreferenceNamespace.currentUserAnyHost
        guard let keys = CFPreferencesCopyKeyList(
            bundle as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost
        ) as? [String], keys.count <= maximumCollectionItems else {
            return PreferenceCapture(
                complete: false, positions: [:], namespace: namespace, sourceIdentity: nil
            )
        }
        let positionKeys = keys.filter { $0.hasPrefix(preferredPositionPrefix) }
        guard positionKeys.count <= maximumOwnerPositionKeys else {
            return PreferenceCapture(
                complete: false, positions: [:], namespace: namespace, sourceIdentity: nil
            )
        }
        var values: [String: OrderingValue] = [:]
        for key in positionKeys {
            guard let raw = CFPreferencesCopyValue(
                key as CFString, bundle as CFString,
                kCFPreferencesCurrentUser, kCFPreferencesAnyHost
            ), let value = try? OrderingValue.fromFoundation(raw) else {
                return PreferenceCapture(
                    complete: false, positions: values, namespace: namespace,
                    sourceIdentity: nil
                )
            }
            let autosave = String(key.dropFirst(preferredPositionPrefix.count))
            guard !autosave.isEmpty, autosave.utf8.count <= maximumStringBytes else {
                return PreferenceCapture(
                    complete: false, positions: values, namespace: namespace,
                    sourceIdentity: nil
                )
            }
            values[autosave] = value
        }
        return PreferenceCapture(
            complete: true, positions: values, namespace: namespace, sourceIdentity: nil
        )
    }

    static func captureSandboxOwnerPreferences(
        bundle: String, signingIdentifier: String
    ) -> PreferenceCapture? {
        guard let firstResolution = resolveSandboxContainer(
            bundle: bundle, signingIdentifier: signingIdentifier
        ), let firstFile = readSandboxPreferenceFile(
            bundle: bundle, expecting: firstResolution
        ), let apiDomain = readSandboxPreferenceDomain(
            bundle: bundle, dataPath: firstResolution.dataPath
        ), let secondFile = readSandboxPreferenceFile(
            bundle: bundle, expecting: firstResolution
        ), let secondResolution = resolveSandboxContainer(
            bundle: bundle, signingIdentifier: signingIdentifier
        ), firstResolution == secondResolution,
              firstFile == apiDomain, apiDomain == secondFile else { return nil }

        let positionEntries = apiDomain.filter { entry in
            entry.key.hasPrefix(preferredPositionPrefix)
        }
        guard positionEntries.count <= maximumOwnerPositionKeys else { return nil }
        var positions: [String: OrderingValue] = [:]
        for (key, value) in positionEntries {
            let autosave = String(key.dropFirst(preferredPositionPrefix.count))
            guard !autosave.isEmpty, autosave.utf8.count <= maximumStringBytes,
                  positions.updateValue(value, forKey: autosave) == nil else { return nil }
        }
        return PreferenceCapture(
            complete: true,
            positions: positions,
            namespace: .sandboxContainer,
            sourceIdentity: secondResolution.sourceIdentity
        )
    }

    static func readSandboxPreferenceDomain(
        bundle: String, dataPath: String
    ) -> [String: OrderingValue]? {
        // The four-argument key-list variant and the Data-directory container
        // mapping were verified read-only on the supported build. Supplying the
        // container root returns the wrong namespace for sandbox applications.
        guard let keySymbol = dlsym(
            UnsafeMutableRawPointer(bitPattern: -2), containerKeyListSymbol
        ), let valueSymbol = dlsym(
            UnsafeMutableRawPointer(bitPattern: -2), containerReadSymbol
        ) else { return nil }
        let copyKeys = unsafeBitCast(keySymbol, to: ContainerKeyList.self)
        let copyValue = unsafeBitCast(valueSymbol, to: ContainerRead.self)
        guard let rawKeys = copyKeys(
            bundle as CFString, kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost, dataPath as CFString
        )?.takeRetainedValue() as? [String],
              rawKeys.count <= maximumTopLevelKeys,
              Set(rawKeys).count == rawKeys.count,
              rawKeys.allSatisfy(validPreferenceKey) else { return nil }

        var foundation: [String: Any] = [:]
        var nodeBudget = maximumValueNodes
        var aggregateBytes = 0
        for key in rawKeys.sorted() {
            guard let raw = copyValue(
                key as CFString, bundle as CFString,
                kCFPreferencesCurrentUser, kCFPreferencesAnyHost,
                dataPath as CFString
            )?.takeRetainedValue() else { return nil }
            do {
                try validateFoundationValue(raw, depth: 1, budget: &nodeBudget)
                let encoded = try PropertyListSerialization.data(
                    fromPropertyList: [key: raw], format: .binary, options: 0
                )
                guard encoded.count <= maximumPlistBytes - aggregateBytes else { return nil }
                aggregateBytes += encoded.count
            } catch {
                return nil
            }
            foundation[key] = raw
        }
        return decodePreferenceDomain(foundation)
    }

    static func validPreferenceKey(_ key: String) -> Bool {
        !key.isEmpty && key.utf8.count <= maximumStringBytes
            && key.unicodeScalars.allSatisfy { $0.value >= 32 && $0.value != 127 }
    }

    static func resolveSandboxContainer(
        bundle: String, signingIdentifier: String,
        homeDirectoryPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> SandboxContainerResolution? {
        guard let handles = openStandardSandboxContainer(
            bundle: bundle, homeDirectoryPath: homeDirectoryPath
        ),
              let metadata = readOwnedRegularFile(
                at: handles.root,
                name: ".com.apple.containermanagerd.metadata.plist",
                maximumBytes: maximumMetadataBytes
              ), let root = try? PropertyListSerialization.propertyList(
                from: metadata.data, format: nil
              ) as? [String: Any],
              let metadataIdentifier = root["MCMMetadataIdentifier"] as? String else {
            return nil
        }
        let metadataDigest = SHA256.hash(data: metadata.data)
            .map { String(format: "%02x", $0) }.joined()
        let evidence = SandboxOwnerPreferenceSourceEvidence(
            bundleIdentifier: bundle,
            signingIdentifier: signingIdentifier,
            homeDirectoryPath: homeDirectoryPath,
            containerRootPath: handles.rootPath,
            dataDirectoryPath: handles.dataPath,
            metadataIdentifier: metadataIdentifier,
            rootDevice: device(handles.rootStatus),
            rootInode: inode(handles.rootStatus),
            dataDevice: device(handles.dataStatus),
            dataInode: inode(handles.dataStatus),
            metadataDevice: metadata.facts.device,
            metadataInode: metadata.facts.inode,
            metadataDigest: metadataDigest
        )
        guard let sourceIdentity = SandboxOwnerPreferenceNamespaceValidator.sourceIdentity(
            for: evidence
        ) else { return nil }
        return SandboxContainerResolution(
            rootPath: handles.rootPath,
            dataPath: handles.dataPath,
            sourceIdentity: sourceIdentity,
            rootDevice: evidence.rootDevice,
            rootInode: evidence.rootInode,
            dataDevice: evidence.dataDevice,
            dataInode: evidence.dataInode
        )
    }

    static func readSandboxPreferenceFile(
        bundle: String, expecting resolution: SandboxContainerResolution,
        homeDirectoryPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> [String: OrderingValue]? {
        guard let handles = openStandardSandboxContainer(
            bundle: bundle, homeDirectoryPath: homeDirectoryPath
        ),
              handles.rootPath == resolution.rootPath,
              handles.dataPath == resolution.dataPath,
              device(handles.rootStatus) == resolution.rootDevice,
              inode(handles.rootStatus) == resolution.rootInode,
              device(handles.dataStatus) == resolution.dataDevice,
              inode(handles.dataStatus) == resolution.dataInode,
              let library = openOwnedDirectory(name: "Library", relativeTo: handles.data)
        else { return nil }
        defer { close(library) }
        guard let preferences = openOwnedDirectory(name: "Preferences", relativeTo: library)
        else { return nil }
        defer { close(preferences) }
        guard let file = readOwnedRegularFile(
            at: preferences, name: bundle + ".plist", maximumBytes: maximumPlistBytes
        ), let root = try? PropertyListSerialization.propertyList(
            from: file.data, format: nil
        ) as? [String: Any] else { return nil }
        return decodePreferenceDomain(root)
    }

    static func decodePreferenceDomain(_ root: [String: Any]) -> [String: OrderingValue]? {
        guard root.count <= maximumTopLevelKeys,
              root.keys.allSatisfy(validPreferenceKey) else { return nil }
        var budget = maximumValueNodes
        guard (try? validateFoundationValue(root, depth: 0, budget: &budget)) != nil else {
            return nil
        }
        do {
            let values = try root.mapValues(OrderingValue.fromFoundation)
            try OrderingValue.dictionary(values).validate()
            return values
        } catch {
            return nil
        }
    }

    static func openStandardSandboxContainer(
        bundle: String,
        homeDirectoryPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> SandboxDirectoryHandles? {
        guard SandboxOwnerPreferenceNamespaceValidator.validBundleComponent(bundle) else {
            return nil
        }
        let homePath = homeDirectoryPath
        guard let home = openOwnedDirectory(path: homePath) else { return nil }
        defer { close(home) }
        guard let library = openOwnedDirectory(name: "Library", relativeTo: home) else { return nil }
        defer { close(library) }
        guard let containers = openOwnedDirectory(name: "Containers", relativeTo: library) else {
            return nil
        }
        defer { close(containers) }
        guard let root = openOwnedDirectory(name: bundle, relativeTo: containers) else { return nil }
        var keepRoot = false
        defer { if !keepRoot { close(root) } }
        guard let data = openOwnedDirectory(name: "Data", relativeTo: root) else { return nil }
        var keepData = false
        defer { if !keepData { close(data) } }
        guard let rootStatus = ownedDirectoryStatus(root),
              let dataStatus = ownedDirectoryStatus(data) else { return nil }
        keepRoot = true
        keepData = true
        let rootPath = homePath + "/Library/Containers/" + bundle
        return SandboxDirectoryHandles(
            root: root,
            data: data,
            rootPath: rootPath,
            dataPath: rootPath + "/Data",
            rootStatus: rootStatus,
            dataStatus: dataStatus
        )
    }

    static func openOwnedDirectory(path: String) -> Int32? {
        let descriptor = open(path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0, ownedDirectoryStatus(descriptor) != nil else {
            if descriptor >= 0 { close(descriptor) }
            return nil
        }
        return descriptor
    }

    static func openOwnedDirectory(name: String, relativeTo parent: Int32) -> Int32? {
        guard !name.isEmpty, !name.contains("/"), name != ".", name != ".." else { return nil }
        let descriptor = openat(
            parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0, ownedDirectoryStatus(descriptor) != nil else {
            if descriptor >= 0 { close(descriptor) }
            return nil
        }
        return descriptor
    }

    static func ownedDirectoryStatus(_ descriptor: Int32) -> stat? {
        var status = stat()
        guard fstat(descriptor, &status) == 0,
              status.st_uid == geteuid(), status.st_mode & S_IFMT == S_IFDIR else { return nil }
        return status
    }

    static func readOwnedRegularFile(
        at parent: Int32, name: String, maximumBytes: Int
    ) -> (data: Data, facts: FileFacts)? {
        guard !name.isEmpty, !name.contains("/"), name != ".", name != ".." else { return nil }
        let descriptor = openat(parent, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }
        var before = stat()
        guard fstat(descriptor, &before) == 0,
              before.st_uid == geteuid(), before.st_nlink == 1,
              before.st_mode & S_IFMT == S_IFREG,
              before.st_size > 0, before.st_size <= maximumBytes else { return nil }

        var data = Data(count: Int(before.st_size))
        var offset = 0
        var iterations = 0
        var interruptions = 0
        while offset < data.count {
            guard iterations < 1_024 else { return nil }
            iterations += 1
            let amount = data.withUnsafeMutableBytes { bytes -> Int in
                guard let base = bytes.baseAddress else { return -1 }
                return Darwin.read(
                    descriptor, base.advanced(by: offset), bytes.count - offset
                )
            }
            if amount < 0 && errno == EINTR {
                interruptions += 1
                guard interruptions <= 4 else { return nil }
                continue
            }
            guard amount > 0 else { return nil }
            offset += amount
        }
        var after = stat()
        guard fstat(descriptor, &after) == 0,
              fileFacts(before) == fileFacts(after) else { return nil }
        return (data, fileFacts(after))
    }

    static func fileFacts(_ status: stat) -> FileFacts {
        FileFacts(
            device: device(status), inode: inode(status), size: status.st_size,
            modifiedSeconds: status.st_mtimespec.tv_sec,
            modifiedNanoseconds: status.st_mtimespec.tv_nsec,
            changedSeconds: status.st_ctimespec.tv_sec,
            changedNanoseconds: status.st_ctimespec.tv_nsec
        )
    }

    static func device(_ status: stat) -> UInt64 {
        UInt64(bitPattern: Int64(status.st_dev))
    }

    static func inode(_ status: stat) -> UInt64 {
        UInt64(status.st_ino)
    }

    static func validateOwnerEvidence(
        snapshot: OrderingSnapshot, ownerPIDs: [pid_t], requiresGeometry: Bool
    ) async throws {
        let expected = ownerPIDs.compactMap { snapshot.observationsByPID[$0] }
        guard expected.count == ownerPIDs.count else {
            // A former owner may be absent during receipt-backed recovery. A
            // currently matched process must always have a captured record.
            if ownerPIDs.isEmpty { return }
            throw MacOS27MenuBarOrderingBackendError.staleSnapshot
        }
        let table = try snapshot.table()
        let processes = snapshot.afterProcesses
        let unchanged = await Task.detached(priority: .utility) {
            let deadline = ContinuousClock.now.advanced(by: axCaptureDeadline)
            return expected.allSatisfy { observation in
                let seed = OwnerSeed(
                    process: observation.process,
                    displayName: observation.displayName
                )
                let geometryUnchanged: Bool
                if requiresGeometry {
                    let ax = captureAXItems(pid: observation.process.pid, deadline: deadline)
                    geometryUnchanged = ax.complete == observation.axComplete
                        && ax.frames == observation.itemFrames
                } else {
                    geometryUnchanged = true
                }
                guard geometryUnchanged else { return false }
                if let expectedIdentity = observation.applicationCodeIdentity {
                    return exactBundleApplicationIdentity(
                        seed: seed, table: table, processes: processes,
                        codeIdentity: codeIdentity(pid: observation.process.pid)
                    ) == expectedIdentity
                }
                let preferences = captureOwnerPreferences(seed: seed)
                return preferences.complete == observation.ownerPreferencesComplete
                    && preferences.positions == observation.ownerSavedPositions
                    && preferences.namespace == observation.ownerPreferenceNamespace
                    && preferences.sourceIdentity == observation.ownerPreferenceSourceIdentity
            }
        }.value
        guard unchanged else { throw MacOS27MenuBarOrderingBackendError.staleSnapshot }
    }

    static func readCorroboratedGroup(
        transition postWriteReadback: PostWriteReadback? = nil
    ) throws -> [String: OrderingValue] {
        let firstRoot = try readPlistRoot()
        let group = try decodeGroup(firstRoot)
        let fileTable = try table(in: group)
        let containerTable: [String: OrderingValue]
        do {
            containerTable = try tableFromContainerRead()
        } catch let error as MacOS27MenuBarOrderingBackendError {
            throw error
        } catch {
            throw MacOS27MenuBarOrderingBackendError.groupContainerTableUnavailable
        }
        let secondRoot = try readPlistRoot()
        let secondGroup = try decodeGroup(secondRoot)
        if OrderingPreferenceDiagnostics.enabled {
            var groups = ["fileBefore": group, "fileAfter": secondGroup,
                          "container": [tableKey: OrderingValue.dictionary(containerTable)]]
            if let postWriteReadback {
                groups["transitionBefore"] = postWriteReadback.previousGroup
                groups["transitionExpected"] = postWriteReadback.expectedGroup
            }
            OrderingPreferenceDiagnostics.record("corroborated-read", groups: groups,
                detail: fileTable == containerTable ? "sources-agree" : "sources-disagree")
        }
        return try corroboratedGroup(first: group, containerTable: containerTable, second: secondGroup)
    }

    static func readCorroboratedGroupAfterBoundedSettle(
        transition postWriteReadback: PostWriteReadback? = nil
    ) async throws -> [String: OrderingValue] {
        // Arm before reading so a replacement between the first read and the
        // wait cannot be missed. An event is only a wake-up, never verification.
        let observation = OrderingPreferenceFileChange(url: groupPlistURL)
        defer { observation?.cancel() }
        return try await readCorroboratedGroupAfterBoundedSettle(
            read: { try readCorroboratedGroup(transition: postWriteReadback) },
            settle: {
                OrderingPreferenceDiagnostics.record("readback-settlement-start")
                let changed: Bool
                if let observation { changed = try await observation.wait() }
                else {
                    try await Task.sleep(for: preferenceSettlementDeadline)
                    changed = false
                }
                OrderingPreferenceDiagnostics.record("readback-settlement-end",
                    detail: changed ? "file-event" : "bounded-deadline")
            }
        )
    }

    static func decodeGroup(_ root: [String: Any]) throws -> [String: OrderingValue] {
        guard root.count <= maximumTopLevelKeys else {
            throw MacOS27MenuBarOrderingBackendError.groupTooLarge
        }
        var budget = maximumValueNodes
        try validateFoundationValue(root, depth: 0, budget: &budget)
        let group: [String: OrderingValue]
        do {
            group = try root.reduce(into: [:]) { result, entry in
                result[entry.key] = try OrderingValue.fromFoundation(entry.value)
            }
            try group.values.forEach { try $0.validate() }
        } catch {
            throw MacOS27MenuBarOrderingBackendError.groupValueUnsupported
        }
        let fileTable = try table(in: group)
        guard fileTable.count <= maximumPositionKeys else {
            throw MacOS27MenuBarOrderingBackendError.groupTooLarge
        }
        return group
    }

    static func table(in group: [String: OrderingValue]) throws -> [String: OrderingValue] {
        guard case let .dictionary(table)? = group[tableKey] else {
            throw MacOS27MenuBarOrderingBackendError.groupFileTableUnavailable
        }
        return table
    }

    static func tableFromContainerRead() throws -> [String: OrderingValue] {
        guard let symbol = dlsym(
            UnsafeMutableRawPointer(bitPattern: -2), containerReadSymbol
        ) else { throw MacOS27MenuBarOrderingBackendError.runtimeContractDiffers }
        let read = unsafeBitCast(symbol, to: ContainerRead.self)
        guard let raw = read(
            tableKey as CFString, suiteName as CFString,
            kCFPreferencesCurrentUser, kCFPreferencesAnyHost,
            groupContainerURL.path as CFString
        )?.takeRetainedValue() else {
            throw MacOS27MenuBarOrderingBackendError.groupContainerTableUnavailable
        }
        let value: OrderingValue
        do { value = try OrderingValue.fromFoundation(raw) }
        catch { throw MacOS27MenuBarOrderingBackendError.groupValueUnsupported }
        guard case let .dictionary(table) = value else {
            throw MacOS27MenuBarOrderingBackendError.groupContainerTableUnavailable
        }
        return table
    }

    static func readPlistRoot() throws -> [String: Any] {
        let descriptor = open(groupPlistURL.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else {
            throw MacOS27MenuBarOrderingBackendError.groupFileOpenFailed(errno)
        }
        defer { close(descriptor) }
        var status = stat()
        guard fstat(descriptor, &status) == 0 else {
            throw MacOS27MenuBarOrderingBackendError.groupFileMetadataReadFailed(errno)
        }
        guard status.st_uid == geteuid(), status.st_nlink == 1,
              status.st_mode & S_IFMT == S_IFREG,
              status.st_size > 0, status.st_size <= maximumPlistBytes else {
            throw MacOS27MenuBarOrderingBackendError.groupFileMetadataInvalid
        }
        var data = Data(count: Int(status.st_size))
        var offset = 0
        var iterations = 0
        var interruptions = 0
        while offset < data.count {
            guard iterations < 1_024 else {
                throw MacOS27MenuBarOrderingBackendError.groupFileReadIncomplete
            }
            iterations += 1
            let count = data.withUnsafeMutableBytes { bytes -> Int in
                guard let base = bytes.baseAddress else { return -1 }
                return Darwin.read(
                    descriptor, base.advanced(by: offset), bytes.count - offset
                )
            }
            if count < 0 && errno == EINTR {
                interruptions += 1
                guard interruptions <= 4 else {
                    throw MacOS27MenuBarOrderingBackendError.groupFileReadFailed(EINTR)
                }
                continue
            }
            guard count >= 0 else {
                throw MacOS27MenuBarOrderingBackendError.groupFileReadFailed(errno)
            }
            guard count > 0 else {
                throw MacOS27MenuBarOrderingBackendError.groupFileReadIncomplete
            }
            offset += count
        }
        var after = stat()
        guard fstat(descriptor, &after) == 0 else {
            throw MacOS27MenuBarOrderingBackendError.groupFileMetadataReadFailed(errno)
        }
        guard fileFacts(status) == fileFacts(after) else {
            throw MacOS27MenuBarOrderingBackendError.groupChangedDuringCapture
        }
        guard let value = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = value as? [String: Any] else {
            throw MacOS27MenuBarOrderingBackendError.groupFileDecodeFailed
        }
        return dictionary
    }

    static func validateFoundationValue(
        _ value: Any, depth: Int, budget: inout Int
    ) throws {
        guard depth <= maximumValueDepth, budget > 0 else {
            throw MacOS27MenuBarOrderingBackendError.groupTooLarge
        }
        budget -= 1
        switch value {
        case let string as String:
            guard string.utf8.count <= maximumStringBytes else {
                throw MacOS27MenuBarOrderingBackendError.groupTooLarge
            }
        case let data as Data:
            guard data.count <= maximumDataBytes else {
                throw MacOS27MenuBarOrderingBackendError.groupTooLarge
            }
        case is NSNumber, is Date:
            break
        case let array as [Any]:
            guard array.count <= maximumCollectionItems else {
                throw MacOS27MenuBarOrderingBackendError.groupTooLarge
            }
            for child in array {
                try validateFoundationValue(child, depth: depth + 1, budget: &budget)
            }
        case let dictionary as [String: Any]:
            guard dictionary.count <= maximumCollectionItems,
                  dictionary.keys.allSatisfy({ $0.utf8.count <= maximumStringBytes }) else {
                throw MacOS27MenuBarOrderingBackendError.groupTooLarge
            }
            for child in dictionary.values {
                try validateFoundationValue(child, depth: depth + 1, budget: &budget)
            }
        default:
            throw MacOS27MenuBarOrderingBackendError.groupValueUnsupported
        }
    }

    static func validateWriteScope(
        previous: [String: OrderingValue], proposed: [String: OrderingValue],
        maximumChangedKeys: Int, allowsExactSystemItems: Bool = false
    ) throws -> [String] {
        guard previous.count == proposed.count, Set(previous.keys) == Set(proposed.keys),
              proposed.count <= maximumPositionKeys else {
            throw MacOS27MenuBarOrderingBackendError.invalidWriteScope
        }
        for value in proposed.values { try value.validate() }
        let changed = previous.keys.filter { previous[$0] != proposed[$0] }.sorted()
        guard changed.count <= maximumChangedKeys,
              changed.allSatisfy({ parseStatusKey($0) != nil
                  || (allowsExactSystemItems && exactSystemItem(for: $0) != nil) }),
              changed.allSatisfy({ isValidPosition(previous[$0]) && isValidPosition(proposed[$0]) }) else {
            throw MacOS27MenuBarOrderingBackendError.invalidWriteScope
        }
        return changed
    }

    static func isValidPosition(_ value: OrderingValue?) -> Bool {
        switch value {
        case let .integer(number): return number > 0 && number <= 1_000_000
        case let .real(number): return number.isFinite && number > 0 && number <= 1_000_000
        default: return false
        }
    }

    static func write(table: [String: OrderingValue]) throws {
        let foundation = try table.reduce(into: [String: Any]()) { result, entry in
            result[entry.key] = try entry.value.toFoundation()
        }
        var writeError: Unmanaged<CFError>?
        OrderingPreferenceDiagnostics.record("write-intent", groups: ["target": [tableKey: .dictionary(table)]])
        guard blenny_write_menu_bar_ordering_table(
            foundation as CFDictionary,
            groupContainerURL.path as CFString,
            &writeError
        ) else {
            _ = writeError?.takeRetainedValue()
            OrderingPreferenceDiagnostics.record("write-rejected")
            throw MacOS27MenuBarOrderingBackendError.synchronizationFailed
        }
        OrderingPreferenceDiagnostics.record("write-acknowledged")
    }
}

@MainActor
private final class LayoutChangeObservation {
    fileprivate final class Context: @unchecked Sendable {
        nonisolated(unsafe) weak var owner: LayoutChangeObservation?
        init(owner: LayoutChangeObservation) { self.owner = owner }
    }

    private var observers: [AXObserver] = []
    private var roots: [AXUIElement] = []
    private var context: Context?
    private var continuation: CheckedContinuation<Void, Never>?
    private var observed = false

    static func arm(ownerPIDs: [pid_t]) -> LayoutChangeObservation {
        let observation = LayoutChangeObservation()
        guard AXIsProcessTrusted(), !ownerPIDs.isEmpty else { return observation }
        let context = Context(owner: observation)
        observation.context = context
        for pid in ownerPIDs.prefix(2) {
            let application = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(application, 0.1)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                application, kAXExtrasMenuBarAttribute as CFString, &value
            ) == .success, let value,
                  CFGetTypeID(value) == AXUIElementGetTypeID() else { continue }
            let root = unsafeDowncast(value, to: AXUIElement.self)
            var observer: AXObserver?
            guard AXObserverCreate(pid, layoutChangeCallback, &observer) == .success,
                  let observer else { continue }
            let result = AXObserverAddNotification(
                observer, root, kAXLayoutChangedNotification as CFString,
                Unmanaged.passUnretained(context).toOpaque()
            )
            guard result == .success || result == .notificationAlreadyRegistered else { continue }
            CFRunLoopAddSource(
                CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes
            )
            observation.observers.append(observer)
            observation.roots.append(root)
        }
        return observation
    }

    func wait(until deadline: DispatchTimeInterval) async {
        guard !observed, !observers.isEmpty else {
            detach()
            return
        }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            DispatchQueue.main.asyncAfter(deadline: .now() + deadline) { [weak self] in
                self?.finish()
            }
        }
    }

    func resetForWrite() {
        observed = false
    }

    func cancel() {
        finish()
    }

    fileprivate func receivedLayoutChange() {
        observed = true
        finish()
    }

    private func finish() {
        let pending = continuation
        continuation = nil
        detach()
        pending?.resume()
    }

    private func detach() {
        for (observer, root) in zip(observers, roots) {
            AXObserverRemoveNotification(
                observer, root, kAXLayoutChangedNotification as CFString
            )
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes
            )
        }
        observers.removeAll()
        roots.removeAll()
        context?.owner = nil
        context = nil
    }
}

private func layoutChangeCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ reference: UnsafeMutableRawPointer?
) {
    guard notification as String == kAXLayoutChangedNotification as String,
          let reference else { return }
    let context = Unmanaged<LayoutChangeObservation.Context>
        .fromOpaque(reference).takeUnretainedValue()
    Task { @MainActor in context.owner?.receivedLayoutChange() }
}
#endif
