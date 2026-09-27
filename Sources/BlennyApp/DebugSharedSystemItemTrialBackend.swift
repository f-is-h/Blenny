#if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
import BlennyCore
import BlennyPrivateABIShim
import Darwin
import Foundation

@MainActor
final class DebugSharedSystemItemTrialBackend: SharedSystemItemTrialBackend,
    @unchecked Sendable
{
    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/ControlCenter.framework/ControlCenter"
    private static let siriDomain = "com.apple.Siri"
    private static let timeMachineDomain = "com.apple.systemuiserver"
    private static let nowPlayingDomain = "com.apple.controlcenter"
    private static let spotlightDomain = "com.apple.campo"

    private var bridge: ControlCenterPreferenceBridge?

    func capture(_ target: SharedSystemItemTrialTarget) throws
        -> SharedSystemItemPreferenceSnapshot {
        try validateRuntime()
        switch target {
        case .nowPlaying:
            let value = try ExactPreferenceValue(copy(
                Self.nowPlayingDomain, "NowPlaying", host: kCFPreferencesCurrentHost
            ))
            let flags = try value.unsignedFlags()
            return try SharedSystemItemPreferenceSnapshot(
                target: target,
                values: ["NowPlaying": value],
                effectiveVisible: (flags & 0xA) != 0x8
            )
        case .siri:
            let status = copy(Self.siriDomain, "StatusMenuVisible")
            let stash = copy(Self.siriDomain, "SiriPrefStashedStatusMenuVisible")
            let statusValue = try ExactPreferenceValue(status)
            let effective = try statusValue.optionalBoolean() ?? true
            return try SharedSystemItemPreferenceSnapshot(
                target: target,
                values: [
                    "StatusMenuVisible": statusValue,
                    "SiriPrefStashedStatusMenuVisible": try ExactPreferenceValue(stash),
                ],
                effectiveVisible: effective
            )
        case .timeMachine:
            let bridge = try bridge ?? ControlCenterPreferenceBridge()
            self.bridge = bridge
            let menuExtras = try ExactPreferenceValue(copy(Self.timeMachineDomain, "menuExtras"))
            return try SharedSystemItemPreferenceSnapshot(
                target: target,
                values: [
                    "menuExtras": menuExtras,
                    "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine":
                        try ExactPreferenceValue(copy(
                            Self.timeMachineDomain,
                            "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine"
                        )),
                    "NSStatusItem Preferred Position com.apple.menuextra.TimeMachine":
                        try ExactPreferenceValue(copy(
                            Self.timeMachineDomain,
                            "NSStatusItem Preferred Position com.apple.menuextra.TimeMachine"
                        )),
                ],
                // The macOS 27 setter can remove the live item while retaining
                // its legacy menuExtras membership. Its paired getter is the
                // authoritative visibility state; the persisted values remain
                // part of the exact recovery snapshot.
                effectiveVisible: bridge.visibility(for: .timeMachine)
            )
        case .spotlight:
            let bridge = try bridge ?? ControlCenterPreferenceBridge()
            self.bridge = bridge
            let key = "NSStatusItem VisibleCC Item-0"
            return try SharedSystemItemPreferenceSnapshot(
                target: target,
                values: [key: try ExactPreferenceValue(copy(Self.spotlightDomain, key))],
                effectiveVisible: bridge.visibility(for: .spotlight)
            )
        }
    }

    func setVisibility(
        _ visible: Bool,
        for target: SharedSystemItemTrialTarget
    ) async throws {
        let started = ProcessInfo.processInfo.systemUptime
        defer { recordTiming("set-visibility", target: target, started: started) }
        try commitVisibility(visible, for: target)
    }

    /// Commits the target-local preference change and verifies the strongest
    /// synchronous evidence available for that target. The writer performs the
    /// independent post-commit capture and receipt update. A fixed delay here
    /// did not observe physical adoption and made a multi-item plan wait once
    /// per serial target.
    private func commitVisibility(
        _ visible: Bool,
        for target: SharedSystemItemTrialTarget
    ) throws {
        try validateRuntime()
        if target == .nowPlaying {
            let value = try ExactPreferenceValue(copy(
                Self.nowPlayingDomain, "NowPlaying", host: kCFPreferencesCurrentHost
            ))
            let flags = try value.unsignedFlags()
            let desired = (flags & ~UInt64(0xA)) | (visible ? UInt64(0x2) : UInt64(0x8))
            guard desired != flags else { return }
            CFPreferencesSetValue(
                "NowPlaying" as CFString,
                NSNumber(value: desired),
                Self.nowPlayingDomain as CFString,
                kCFPreferencesCurrentUser,
                kCFPreferencesCurrentHost
            )
            guard CFPreferencesSynchronize(
                Self.nowPlayingDomain as CFString,
                kCFPreferencesCurrentUser,
                kCFPreferencesCurrentHost
            ) else {
                throw SharedSystemItemTrialError.verificationFailed
            }
            return
        }
        let bridge = try bridge ?? ControlCenterPreferenceBridge()
        self.bridge = bridge
        try bridge.setVisibility(visible, for: target)
    }

    func restoreExact(
        _ snapshot: SharedSystemItemPreferenceSnapshot
    ) async throws {
        try await restoreSnapshot(snapshot, waitsForSettlement: true)
    }

    func restoreForOrdinaryReveal(
        _ snapshot: SharedSystemItemPreferenceSnapshot
    ) async throws {
        #if DEBUG
        // Ordinary Time Machine and Spotlight reveal use immediate exact
        // readback. Exact cleanup and compensation retain both recovery waits.
        try await restoreSnapshot(
            snapshot,
            waitsForSettlement: snapshot.target != .timeMachine
                && snapshot.target != .spotlight
        )
        #else
        try await restoreExact(snapshot)
        #endif
    }

    private func restoreSnapshot(
        _ snapshot: SharedSystemItemPreferenceSnapshot,
        waitsForSettlement: Bool
    ) async throws {
        let started = ProcessInfo.processInfo.systemUptime
        defer {
            recordTiming(
                waitsForSettlement ? "restore-exact" : "ordinary-reveal-no-wait",
                target: snapshot.target, started: started
            )
        }
        try snapshot.validate()
        try commitVisibility(snapshot.effectiveVisible, for: snapshot.target)
        // The system owner may normalize its target-local preferences after
        // its setter returns, including after a setter reports failure. Preserve
        // the established bounded barrier before restoring exact bytes so a
        // late setter write cannot immediately overwrite the recovery baseline.
        if waitsForSettlement {
            try await waitForOwnerNormalization(snapshot.target)
        }
        let domain: String
        let host: CFString
        switch snapshot.target {
        case .nowPlaying:
            domain = Self.nowPlayingDomain
            host = kCFPreferencesCurrentHost
        case .siri:
            domain = Self.siriDomain
            host = kCFPreferencesAnyHost
        case .timeMachine:
            domain = Self.timeMachineDomain
            host = kCFPreferencesAnyHost
        case .spotlight:
            domain = Self.spotlightDomain
            host = kCFPreferencesAnyHost
        }
        for (key, exactValue) in snapshot.values {
            CFPreferencesSetValue(
                key as CFString,
                try exactValue.propertyListValue() as CFPropertyList?,
                domain as CFString,
                kCFPreferencesCurrentUser,
                host
            )
        }
        guard CFPreferencesSynchronize(
            domain as CFString,
            kCFPreferencesCurrentUser,
            host
        ) else {
            throw SharedSystemItemTrialError.restorationFailed
        }
        if snapshot.target == .siri {
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("com.apple.Siri.StatusMenuVisibilityChanged"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }
        // Retain the established post-write recovery settlement until native
        // host behavior can be measured independently. The writer's following
        // capture remains the exact restoration check.
        if waitsForSettlement {
            try await waitForExactRestorationSettlement(snapshot.target)
        }
    }

    // No proven cross-target notification acknowledges owner normalization on
    // this build. Keep the existing bounded recovery barrier rather than
    // replacing it with a shorter magic delay or polling.
    private func waitForOwnerNormalization(_ target: SharedSystemItemTrialTarget) async throws {
        let started = ProcessInfo.processInfo.systemUptime
        defer { recordTiming("owner-normalization-wait", target: target, started: started) }
        try await Task.sleep(for: .seconds(1))
    }

    private func waitForExactRestorationSettlement(
        _ target: SharedSystemItemTrialTarget
    ) async throws {
        let started = ProcessInfo.processInfo.systemUptime
        defer { recordTiming("exact-restoration-wait", target: target, started: started) }
        try await Task.sleep(for: .seconds(1))
    }

    private func recordTiming(
        _ stage: String, target: SharedSystemItemTrialTarget, started: TimeInterval
    ) {
        #if DEBUG
        let milliseconds = (ProcessInfo.processInfo.systemUptime - started) * 1_000
        DebugSessionTrace.shared.write(
            "system-item-timing target=\(target.rawValue) stage=\(stage) milliseconds=\(String(format: "%.1f", milliseconds))"
        )
        #endif
    }

    private func copy(
        _ domain: String,
        _ key: String,
        host: CFString = kCFPreferencesAnyHost
    ) -> Any? {
        CFPreferencesCopyValue(
            key as CFString,
            domain as CFString,
            kCFPreferencesCurrentUser,
            host
        )
    }

    private func validateRuntime() throws {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 else {
            throw SharedSystemItemTrialError.unsupportedRuntime
        }
    }

    private final class ControlCenterPreferenceBridge {
        private typealias ReleaseFunction = @convention(c) (UnsafeMutableRawPointer) -> Void

        private let handle: UnsafeMutableRawPointer
        private let object: UnsafeMutableRawPointer
        private let release: ReleaseFunction
        private let siriGetter: UnsafeMutableRawPointer
        private let siriSetter: UnsafeMutableRawPointer
        private let timeMachineGetter: UnsafeMutableRawPointer
        private let timeMachineSetter: UnsafeMutableRawPointer
        private let spotlightGetter: UnsafeMutableRawPointer
        private let spotlightSetter: UnsafeMutableRawPointer

        init() throws {
            guard let handle = dlopen(Self.frameworkPath, RTLD_NOW | RTLD_LOCAL) else {
                throw SharedSystemItemTrialError.unsupportedRuntime
            }
            self.handle = handle
            do {
                let shared = try Self.symbol(
                    "$s13ControlCenter28SystemItemMenuBarPreferencesC6sharedACvgZ",
                    in: handle
                )
                siriGetter = try Self.symbol(
                    "$s13ControlCenter28SystemItemMenuBarPreferencesC8showSiriSbvg",
                    in: handle
                )
                siriSetter = try Self.symbol(
                    "$s13ControlCenter28SystemItemMenuBarPreferencesC8showSiriSbvs",
                    in: handle
                )
                timeMachineGetter = try Self.symbol(
                    "$s13ControlCenter28SystemItemMenuBarPreferencesC15showTimeMachineSbvg",
                    in: handle
                )
                timeMachineSetter = try Self.symbol(
                    "$s13ControlCenter28SystemItemMenuBarPreferencesC15showTimeMachineSbvs",
                    in: handle
                )
                spotlightGetter = try Self.symbol(
                    "$s13ControlCenter28SystemItemMenuBarPreferencesC13showSpotlightSbvg",
                    in: handle
                )
                spotlightSetter = try Self.symbol(
                    "$s13ControlCenter28SystemItemMenuBarPreferencesC13showSpotlightSbvs",
                    in: handle
                )
                release = unsafeBitCast(
                    try Self.symbol("swift_release", in: handle),
                    to: ReleaseFunction.self
                )
                guard let sharedObject = blenny_swift_call_shared(shared) else {
                    throw SharedSystemItemTrialError.unsupportedRuntime
                }
                object = sharedObject
            } catch {
                dlclose(handle)
                throw error
            }
        }

        func setVisibility(
            _ visible: Bool,
            for target: SharedSystemItemTrialTarget
        ) throws {
            guard target != .nowPlaying else {
                throw SharedSystemItemTrialError.unsupportedRuntime
            }
            let (getter, setter) = functions(for: target)
            let before = blenny_swift_call_bool_getter(getter, object)
            if before != visible {
                blenny_swift_call_bool_setter(setter, object, visible)
            }
            guard blenny_swift_call_bool_getter(getter, object) == visible else {
                throw SharedSystemItemTrialError.verificationFailed
            }
        }

        func visibility(for target: SharedSystemItemTrialTarget) -> Bool {
            precondition(target != .nowPlaying)
            let (getter, _) = functions(for: target)
            return blenny_swift_call_bool_getter(getter, object)
        }

        private func functions(
            for target: SharedSystemItemTrialTarget
        ) -> (UnsafeMutableRawPointer, UnsafeMutableRawPointer) {
            switch target {
            case .nowPlaying: preconditionFailure("Now Playing has a separate preference path")
            case .siri: (siriGetter, siriSetter)
            case .timeMachine: (timeMachineGetter, timeMachineSetter)
            case .spotlight: (spotlightGetter, spotlightSetter)
            }
        }

        deinit {
            release(object)
            dlclose(handle)
        }

        private static func symbol(
            _ name: String,
            in handle: UnsafeMutableRawPointer
        ) throws -> UnsafeMutableRawPointer {
            guard let value = dlsym(handle, name) else {
                throw SharedSystemItemTrialError.unsupportedRuntime
            }
            return value
        }

        private static var frameworkPath: String {
            "/System/Library/PrivateFrameworks/ControlCenter.framework/ControlCenter"
        }
    }
}
#endif
