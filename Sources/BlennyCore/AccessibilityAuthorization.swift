@preconcurrency import ApplicationServices
import Foundation

public enum AccessibilityAuthorization {
    public static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    public static func requestSystemPrompt() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
