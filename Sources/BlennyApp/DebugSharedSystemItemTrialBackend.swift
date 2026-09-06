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
    private static let supportedBuild = "26A5425a"
    private static let siriDomain = "com.apple.Siri"
    private static let timeMachineDomain = "com.apple.systemuiserver"
    private static let nowPlayingDomain = "com.apple.controlcenter"

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
        }
    }

    func setVisibility(
        _ visible: Bool,
        for target: SharedSystemItemTrialTarget
    ) async throws {
        try validateRuntime()
        if target == .nowPlaying {
            let value = try ExactPreferenceValue(copy(
                Self.nowPlayingDomain, "NowPlaying", host: kCFPreferencesCurrentHost
            ))
            let flags = try value.unsignedFlags()
            let desired = (flags & ~UInt64(0xA)) | (visible ? UInt64(0x2) : UInt64(0x8))
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
            try await Task.sleep(for: .seconds(1))
            return
        }
        let bridge = try bridge ?? ControlCenterPreferenceBridge()
        self.bridge = bridge
        try bridge.setVisibility(visible, for: target)
        try await Task.sleep(for: .seconds(1))
    }

    func restoreExact(
        _ snapshot: SharedSystemItemPreferenceSnapshot
    ) async throws {
        try snapshot.validate()
        try await setVisibility(snapshot.effectiveVisible, for: snapshot.target)
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
        try await Task.sleep(for: .seconds(1))
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
        var bytes = [CChar](repeating: 0, count: 128)
        var size = bytes.count
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27,
              sysctlbyname("kern.osversion", &bytes, &size, nil, 0) == 0,
              String(decoding: bytes.prefix(while: { $0 != 0 }).map(UInt8.init), as: UTF8.self)
                == Self.supportedBuild else {
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
                release = unsafeBitCast(
                    try Self.symbol("swift_release", in: handle),
                    to: ReleaseFunction.self
                )
                object = blenny_swift_call_shared(shared)
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
            let getter = target == .siri ? siriGetter : timeMachineGetter
            let setter = target == .siri ? siriSetter : timeMachineSetter
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
            let getter = target == .siri ? siriGetter : timeMachineGetter
            return blenny_swift_call_bool_getter(getter, object)
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
