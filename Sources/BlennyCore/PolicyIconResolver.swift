import Foundation

/// A presentation-only icon choice. This type is intentionally neither Codable nor part of
/// any policy, draft, report, or assertion model.
public enum PolicyIconDescriptor: Equatable, Sendable {
    case installedApplication
    case namedImage(name: String)
    case systemSymbol(name: String)
    case fallback

    public static let fallbackSymbolName = "questionmark.square.dashed"

    public var usesFallback: Bool {
        if case .fallback = self { return true }
        return false
    }

    public var symbolName: String? {
        switch self {
        case .installedApplication:
            nil
        case .namedImage:
            nil
        case let .systemSymbol(name):
            name
        case .fallback:
            Self.fallbackSymbolName
        }
    }

    public var namedImageName: String? {
        if case let .namedImage(name) = self { return name }
        return nil
    }
}

public enum PolicyIconResolver {
    public static func applicationDescriptor(
        bundleIdentifier: String,
        installedApplicationResolved: Bool
    ) -> PolicyIconDescriptor {
        if ExperimentalAppleBundlePolicyCatalog.contains(bundleIdentifier) {
            return systemItemDescriptor(observationIdentifier: bundleIdentifier)
        }
        guard BundlePolicyIdentity.canonicalKey(for: bundleIdentifier) != nil,
              installedApplicationResolved else {
            return .fallback
        }
        return .installedApplication
    }

    public static func applicationDescriptors(
        candidates: [PolicyCandidate],
        resolvedBundleIdentifiers: Set<String>
    ) -> [String: PolicyIconDescriptor] {
        let resolved = Set(
            resolvedBundleIdentifiers.compactMap(BundlePolicyIdentity.canonicalKey)
        )
        return Dictionary(uniqueKeysWithValues: candidates.map { candidate in
            let canonical = BundlePolicyIdentity.canonicalKey(
                for: candidate.bundleIdentifier
            )
            return (
                candidate.bundleIdentifier,
                applicationDescriptor(
                    bundleIdentifier: candidate.bundleIdentifier,
                    installedApplicationResolved: canonical.map(resolved.contains) ?? false
                )
            )
        })
    }

    public static func systemItemDescriptor(
        observationIdentifier: String
    ) -> PolicyIconDescriptor {
        knownSystemItem(for: observationIdentifier)?.image ?? .fallback
    }

    public static func systemItemDisplayName(
        observationIdentifier: String
    ) -> String? {
        knownSystemItem(for: observationIdentifier)?.displayName
    }

    private struct KnownSystemItem {
        let displayName: String
        let image: PolicyIconDescriptor

        init(_ displayName: String, symbolName: String) {
            self.displayName = displayName
            image = .systemSymbol(name: symbolName)
        }

        init(_ displayName: String, image: PolicyIconDescriptor) {
            self.displayName = displayName
            self.image = image
        }
    }

    private static func knownSystemItem(for identifier: String) -> KnownSystemItem? {
        let normalized = MenuBarItemIdentityResolver.normalize(identifier)?.lowercased() ?? ""
        if let item = exactSystemItems[normalized] { return item }

        guard let parts = stableIdentityComponents(identifier),
              parts[4].lowercased() == "axmenubaritem",
              parts[5].lowercased() == "axmenuextra" else { return nil }
        let owner = parts[1].lowercased()
        guard owner.hasPrefix("com.apple.") else { return nil }
        if let item = exactSystemItems[parts[2].lowercased()] { return item }

        let label = parts[3].lowercased()
        switch owner {
        case "com.apple.campo", "com.apple.spotlight":
            return label == "spotlight" ? spotlight : nil
        case "com.apple.systemuiserver":
            switch label {
            case "siri": return exactSystemItems["com.apple.menuextra.siri"]
            case "time machine": return exactSystemItems["com.apple.menuextra.timemachine"]
            default: return nil
            }
        case "com.apple.textinputmenuagent":
            return exactSystemItems["com.apple.textinputmenuagent"]
        case "com.apple.weather.menu":
            return exactSystemItems["com.apple.weather.menu"]
        case "com.apple.menubaragent", "com.apple.controlcenter":
            if let canonicalIdentifier = semanticSystemItems[label] {
                return exactSystemItems[canonicalIdentifier]
            }
            return gallerySemanticItems[label]
        case "com.apple.notes.widgetextension":
            return label == "quick note" ? gallerySemanticItems[label] : nil
        case "com.apple.accessibilitysettingswidgetextension":
            return label == "color filters" ? gallerySemanticItems[label] : nil
        default:
            return nil
        }
    }

    /// A length-prefixed stable identity cannot be matched by substring: an owner or label may
    /// contain another item's name. Malformed identities keep the honest fallback icon.
    private static func stableIdentityComponents(_ key: String) -> [String]? {
        let bytes = Array(key.utf8)
        var index = 0
        var components: [String] = []
        for componentIndex in 0..<7 {
            var length = 0
            var hasDigit = false
            while index < bytes.count, (48...57).contains(bytes[index]) {
                hasDigit = true
                let digit = Int(bytes[index] - 48)
                guard length <= (Int.max - digit) / 10 else { return nil }
                length = length * 10 + digit
                index += 1
            }
            guard hasDigit, index < bytes.count, bytes[index] == 58 else { return nil }
            index += 1
            guard length <= bytes.count - index,
                  let component = String(bytes: bytes[index..<(index + length)], encoding: .utf8)
            else { return nil }
            components.append(component)
            index += length
            if componentIndex < 6 {
                guard index < bytes.count, bytes[index] == 124 else { return nil }
                index += 1
            }
        }
        guard index == bytes.count, components[0] == "blenny-identity-v2" else { return nil }
        return components
    }

    private static let spotlight = KnownSystemItem("Spotlight", symbolName: "magnifyingglass")

    /// Presentation identities found in the macOS 27 ControlCenter binary, plus exact Siri,
    /// Weather, and Input Menu paths. A binary string is a candidate, not proof of a live AX row.
    /// This grants no write authority.
    private static let exactSystemItems: [String: KnownSystemItem] = [
        "com.apple.menuextra.accessibility-shortcuts": .init("Accessibility Shortcuts", symbolName: "accessibility"),
        "com.apple.menuextra.airdrop": .init("AirDrop", symbolName: "circle.dotted.circle"),
        "com.apple.menuextra.audiovideo": .init("Audio & Video", symbolName: "video.badge.waveform"),
        "com.apple.menuextra.battery": .init("Battery", symbolName: "battery.100"),
        "com.apple.menuextra.bluetooth": .init("Bluetooth", image: .namedImage(name: "NSBluetoothTemplate")),
        "com.apple.menuextra.clock": .init("Clock", symbolName: "clock"),
        "com.apple.menuextra.controlcenter": .init("Control Center", symbolName: "switch.2"),
        "com.apple.menuextra.display": .init("Display", symbolName: "display"),
        "com.apple.menuextra.energy-mode": .init("Energy Mode", symbolName: "bolt"),
        "com.apple.menuextra.facetime": .init("FaceTime", symbolName: "video"),
        "com.apple.menuextra.focusmode": .init("Focus", symbolName: "moon.fill"),
        "com.apple.menuextra.hearing": .init("Hearing", symbolName: "ear.badge.waveform"),
        "com.apple.menuextra.keyboard-brightness": .init("Keyboard Brightness", symbolName: "sun.max"),
        "com.apple.menuextra.musicrecognition": .init("Music Recognition", symbolName: "music.note"),
        "com.apple.menuextra.now-playing": .init("Now Playing", symbolName: "play.circle"),
        "com.apple.menuextra.screen-mirroring": .init("Screen Mirroring", symbolName: "rectangle.on.rectangle"),
        "com.apple.menuextra.siri": .init("Siri", symbolName: "siri"),
        "com.apple.menuextra.spotlight": spotlight,
        "com.apple.menuextra.sound": .init("Sound", symbolName: "speaker.wave.2"),
        "com.apple.menuextra.timemachine": .init("Time Machine", symbolName: "clock.arrow.trianglehead.counterclockwise.rotate.90"),
        "com.apple.menuextra.timer": .init("Timer", symbolName: "timer"),
        "com.apple.menuextra.user": .init("Fast User Switching", symbolName: "person.crop.circle"),
        "com.apple.menuextra.voice-control": .init("Voice Control", symbolName: "waveform.badge.mic"),
        "com.apple.menuextra.vpn": .init("VPN", symbolName: "network"),
        "com.apple.menuextra.wifi": .init("Wi-Fi", symbolName: "wifi"),
        "com.apple.menuextra.textinput": .init("Input Menu", symbolName: "keyboard"),
        "com.apple.textinputmenuagent": .init("Input Menu", symbolName: "keyboard"),
        "com.apple.weather.menu": .init("Weather", symbolName: "cloud.sun"),
        "com.apple.calculator.calculatorwidget.control": .init("Calculator", symbolName: "plus.forwardslash.minus"),
        "com.apple.controls.display": .init("Display Control", symbolName: "display"),
        "com.apple.controls.display.dark-mode": .init("Dark Mode", symbolName: "circle.lefthalf.filled"),
        "com.apple.controls.display.lock": .init("Lock Screen", symbolName: "lock"),
        "com.apple.controls.display.night-shift": .init("Night Shift", symbolName: "moon.stars"),
        "com.apple.controls.display.screen-saver": .init("Screen Saver", symbolName: "display"),
        "com.apple.controls.display.sleep": .init("Put Display to Sleep", symbolName: "display.and.arrow.down"),
        "com.apple.controls.display.true-tone": .init("True Tone", symbolName: "sun.max"),
        "com.apple.controls.screenshot": .init("Screenshot", symbolName: "camera.viewfinder"),
        "com.apple.controls.screenshot.capture-screen": .init("Capture Screen", symbolName: "camera.viewfinder"),
        "com.apple.mobiletimer.control.alarm": .init("Alarm", symbolName: "alarm"),
        "com.apple.mobiletimer.control.stopwatch": .init("Stopwatch", symbolName: "stopwatch"),
        "com.apple.mobiletimer.control.timer": .init("Timer", symbolName: "timer"),
        "com.apple.notes.widgetextension.quicknotecontrol": .init("Quick Note", symbolName: "note.text"),
        "com.apple.printcenter.printcenterwidget.control": .init("Printer", symbolName: "printer"),
    ]

    private static let semanticSystemItems: [String: String] = [
        "accessibility shortcuts": "com.apple.menuextra.accessibility-shortcuts",
        "airdrop": "com.apple.menuextra.airdrop",
        "audio & video": "com.apple.menuextra.audiovideo",
        "battery": "com.apple.menuextra.battery",
        "bluetooth": "com.apple.menuextra.bluetooth",
        "clock": "com.apple.menuextra.clock",
        "control center": "com.apple.menuextra.controlcenter",
        "display": "com.apple.menuextra.display",
        "energy mode": "com.apple.menuextra.energy-mode",
        "facetime": "com.apple.menuextra.facetime",
        "focus": "com.apple.menuextra.focusmode",
        "hearing": "com.apple.menuextra.hearing",
        "keyboard brightness": "com.apple.menuextra.keyboard-brightness",
        "music recognition": "com.apple.menuextra.musicrecognition",
        "now playing": "com.apple.menuextra.now-playing",
        "screen mirroring": "com.apple.menuextra.screen-mirroring",
        "sound": "com.apple.menuextra.sound",
        "time machine": "com.apple.menuextra.timemachine",
        "timer": "com.apple.menuextra.timer",
        "fast user switching": "com.apple.menuextra.user",
        "voice control": "com.apple.menuextra.voice-control",
        "vpn": "com.apple.menuextra.vpn",
        "wi-fi": "com.apple.menuextra.wifi",
    ]

    private static let gallerySemanticItems: [String: KnownSystemItem] = [
        "color filters": .init("Color Filters", symbolName: "circle.lefthalf.filled"),
        "put display to sleep": .init("Put Display to Sleep", symbolName: "display.and.arrow.down"),
        "quick note": .init("Quick Note", symbolName: "note.text"),
    ]
}
