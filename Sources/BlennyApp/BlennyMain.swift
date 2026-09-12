import AppKit
import Darwin
import Foundation

@main
@MainActor
enum BlennyMain {
    static func main() {
        #if DEBUG
        if ProcessInfo.processInfo.environment[
            "BLENNY_ORDERING_BOARD_LIFECYCLE_CHECK"
        ] == "YES" {
            do {
                try OrderingBoardLifecycleSelfCheck.run()
                print("ordering-board-lifecycle-check: PASS")
                return
            } catch {
                FileHandle.standardError.write(Data(
                    "ordering-board-lifecycle-check: FAIL: \(error.localizedDescription)\n".utf8
                ))
                Darwin.exit(1)
            }
        }
        #endif
        let application = NSApplication.shared
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        if ProcessInfo.processInfo.environment[
            SharedSystemItemRecoveryDelegate.modeKey
        ] != nil {
            let delegate = SharedSystemItemRecoveryDelegate()
            application.delegate = delegate
            application.setActivationPolicy(.accessory)
            withExtendedLifetime(delegate) { application.run() }
            return
        }
        #endif
        #if DEBUG
        if ProcessInfo.processInfo.environment[
            DebugSystemItemVisibilityValidationDelegate.modeKey
        ] != nil {
            let delegate = DebugSystemItemVisibilityValidationDelegate()
            application.delegate = delegate
            application.setActivationPolicy(.accessory)
            withExtendedLifetime(delegate) { application.run() }
            return
        }
        if ProcessInfo.processInfo.environment[DebugAgentPositionValidationDelegate.modeKey] != nil {
            let delegate = DebugAgentPositionValidationDelegate()
            application.delegate = delegate
            application.setActivationPolicy(.accessory)
            withExtendedLifetime(delegate) { application.run() }
            return
        }
        if ProcessInfo.processInfo.environment[DebugManualPositionCalibrationDelegate.modeKey] != nil {
            let delegate = DebugManualPositionCalibrationDelegate()
            application.delegate = delegate
            application.setActivationPolicy(.accessory)
            withExtendedLifetime(delegate) { application.run() }
            return
        }
        if ProcessInfo.processInfo.environment[DebugSelfPositionValidationDelegate.modeKey] != nil {
            let delegate = DebugSelfPositionValidationDelegate()
            application.delegate = delegate
            application.setActivationPolicy(.accessory)
            withExtendedLifetime(delegate) { application.run() }
            return
        }
        #endif
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)

        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
