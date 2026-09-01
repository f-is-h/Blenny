import AppKit

@main
@MainActor
enum BlennyMain {
    static func main() {
        let application = NSApplication.shared
        #if DEBUG
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
