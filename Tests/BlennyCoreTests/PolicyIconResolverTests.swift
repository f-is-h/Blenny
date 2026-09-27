import AppKit
import Foundation
import Testing
@testable import BlennyCore

@Suite("Icon-first policy presentation")
struct PolicyIconResolverTests {
    @Test("Installed application eligibility selects an application icon or the shared fallback")
    func applicationSourceSelection() {
        #expect(
            PolicyIconResolver.applicationDescriptor(
                bundleIdentifier: "com.example.Resolved",
                installedApplicationResolved: true
            ) == .installedApplication
        )
        #expect(
            PolicyIconResolver.applicationDescriptor(
                bundleIdentifier: "com.example.Missing",
                installedApplicationResolved: false
            ) == .fallback
        )
        #expect(
            PolicyIconResolver.applicationDescriptor(
                bundleIdentifier: "not a bundle identifier",
                installedApplicationResolved: true
            ) == .fallback
        )
        #expect(PolicyIconDescriptor.fallback.symbolName == "questionmark.square.dashed")

        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        #expect(
            PolicyIconResolver.applicationDescriptor(
                bundleIdentifier: "com.apple.weather.menu",
                installedApplicationResolved: true
            ) == .systemSymbol(name: "cloud.sun")
        )
        #expect(
            PolicyIconResolver.applicationDescriptor(
                bundleIdentifier: "com.apple.TextInputMenuAgent",
                installedApplicationResolved: false
            ) == .systemSymbol(name: "keyboard")
        )
        #expect(ExperimentalAppleBundlePolicyCatalog.displayName(
            for: "COM.APPLE.WEATHER.MENU"
        ) == "Weather")
        #expect(ExperimentalAppleBundlePolicyCatalog.displayName(
            for: "com.apple.TextInputMenuAgent"
        ) == "Input Menu")
        #else
        #expect(ExperimentalAppleBundlePolicyCatalog.displayName(
            for: "com.apple.weather.menu"
        ) == nil)
        #endif
    }

    @Test("Known system observation identities map to semantic SF Symbols")
    func knownSystemSymbols() {
        let expected = [
            "com.apple.menuextra.clock": "clock",
            "com.apple.menuextra.controlcenter": "switch.2",
            "com.apple.menuextra.now-playing": "play.circle",
            "com.apple.menuextra.sound": "speaker.wave.2",
            "com.apple.menuextra.wifi": "wifi",
            "com.apple.menuextra.siri": "siri",
        ]

        #expect(
            PolicyIconResolver.systemItemDescriptor(
                observationIdentifier: "COM.APPLE.MENUEXTRA.BLUETOOTH"
            ) == .namedImage(name: "NSBluetoothTemplate")
        )

        for (identifier, symbolName) in expected {
            #expect(
                PolicyIconResolver.systemItemDescriptor(
                    observationIdentifier: identifier.uppercased()
                ) == .systemSymbol(name: symbolName)
            )
        }

        let stableSiriIdentity = MenuBarItemIdentity(
            ownerBundleIdentifier: "com.apple.systemuiserver",
            accessibilityIdentifier: nil,
            semanticLabel: "siri",
            role: "axmenubaritem",
            subrole: "axmenuextra",
            instanceOrdinal: 0,
            confidence: .moderate
        )
        #expect(
            PolicyIconResolver.systemItemDescriptor(
                observationIdentifier: stableSiriIdentity.stableKey
            ) == .systemSymbol(name: "siri")
        )
        let stableInputSourceIdentity = MenuBarItemIdentity(
            ownerBundleIdentifier: "com.apple.textinputmenuagent",
            accessibilityIdentifier: nil,
            semanticLabel: "简体五笔",
            role: "axmenubaritem",
            subrole: "axmenuextra",
            instanceOrdinal: 0,
            confidence: .moderate
        )
        #expect(
            PolicyIconResolver.systemItemDescriptor(
                observationIdentifier: stableInputSourceIdentity.stableKey
            ) == .systemSymbol(name: "keyboard")
        )
    }

    @Test("macOS 27 built-in menu items have names and loadable presentation images")
    @MainActor
    func macOS27BuiltInImages() {
        let expectedSymbols: [String: (String, String)] = [
            "com.apple.menuextra.accessibility-shortcuts": ("Accessibility Shortcuts", "accessibility"),
            "com.apple.menuextra.airdrop": ("AirDrop", "circle.dotted.circle"),
            "com.apple.menuextra.audiovideo": ("Audio & Video", "video.badge.waveform"),
            "com.apple.menuextra.battery": ("Battery", "battery.100"),
            "com.apple.menuextra.clock": ("Clock", "clock"),
            "com.apple.menuextra.controlcenter": ("Control Center", "switch.2"),
            "com.apple.menuextra.display": ("Display", "display"),
            "com.apple.menuextra.energy-mode": ("Energy Mode", "bolt"),
            "com.apple.menuextra.faceTime": ("FaceTime", "video"),
            "com.apple.menuextra.focusmode": ("Focus", "moon.fill"),
            "com.apple.menuextra.hearing": ("Hearing", "ear.badge.waveform"),
            "com.apple.menuextra.keyboard-brightness": ("Keyboard Brightness", "sun.max"),
            "com.apple.menuextra.musicrecognition": ("Music Recognition", "music.note"),
            "com.apple.menuextra.now-playing": ("Now Playing", "play.circle"),
            "com.apple.menuextra.screen-mirroring": ("Screen Mirroring", "rectangle.on.rectangle"),
            "com.apple.menuextra.siri": ("Siri", "siri"),
            "com.apple.menuextra.sound": ("Sound", "speaker.wave.2"),
            "com.apple.menuextra.TimeMachine": ("Time Machine", "clock.arrow.trianglehead.counterclockwise.rotate.90"),
            "com.apple.menuextra.timer": ("Timer", "timer"),
            "com.apple.menuextra.user": ("Fast User Switching", "person.crop.circle"),
            "com.apple.menuextra.voice-control": ("Voice Control", "waveform.badge.mic"),
            "com.apple.menuextra.vpn": ("VPN", "network"),
            "com.apple.menuextra.wifi": ("Wi-Fi", "wifi"),
            "com.apple.menuextra.textinput": ("Input Menu", "keyboard"),
            "com.apple.textinputmenuagent": ("Input Menu", "keyboard"),
            "com.apple.weather.menu": ("Weather", "cloud.sun"),
            "com.apple.calculator.CalculatorWidget.control": ("Calculator", "plus.forwardslash.minus"),
            "com.apple.controls.display": ("Display Control", "display"),
            "com.apple.controls.display.dark-mode": ("Dark Mode", "circle.lefthalf.filled"),
            "com.apple.controls.display.lock": ("Lock Screen", "lock"),
            "com.apple.controls.display.night-shift": ("Night Shift", "moon.stars"),
            "com.apple.controls.display.screen-saver": ("Screen Saver", "display"),
            "com.apple.controls.display.sleep": ("Put Display to Sleep", "display.and.arrow.down"),
            "com.apple.controls.display.true-tone": ("True Tone", "sun.max"),
            "com.apple.controls.screenshot": ("Screenshot", "camera.viewfinder"),
            "com.apple.controls.screenshot.capture-screen": ("Capture Screen", "camera.viewfinder"),
            "com.apple.mobiletimer.control.alarm": ("Alarm", "alarm"),
            "com.apple.mobiletimer.control.stopwatch": ("Stopwatch", "stopwatch"),
            "com.apple.mobiletimer.control.timer": ("Timer", "timer"),
            "com.apple.notes.widgetextension.quicknotecontrol": ("Quick Note", "note.text"),
            "com.apple.printcenter.PrintCenterWidget.control": ("Printer", "printer"),
        ]
        for (identifier, expected) in expectedSymbols {
            let descriptor = PolicyIconResolver.systemItemDescriptor(
                observationIdentifier: identifier
            )
            #expect(descriptor == .systemSymbol(name: expected.1))
            #expect(PolicyIconResolver.systemItemDisplayName(
                observationIdentifier: identifier
            ) == expected.0)
            #expect(NSImage(systemSymbolName: expected.1, accessibilityDescription: nil) != nil)
        }
        #expect(PolicyIconResolver.systemItemDisplayName(
            observationIdentifier: "com.apple.menuextra.bluetooth"
        ) == "Bluetooth")
        #expect(NSImage(named: NSImage.Name("NSBluetoothTemplate")) != nil)
    }

    @Test("Spotlight uses its observed owner and semantic identity, without substring guesses")
    func spotlightIdentity() {
        let spotlight = MenuBarItemIdentity(
            ownerBundleIdentifier: "com.apple.campo",
            accessibilityIdentifier: nil,
            semanticLabel: "spotlight",
            role: "axmenubaritem",
            subrole: "axmenuextra",
            instanceOrdinal: 0,
            confidence: .moderate
        )
        #expect(PolicyIconResolver.systemItemDescriptor(
            observationIdentifier: spotlight.stableKey
        ) == .systemSymbol(name: "magnifyingglass"))
        #expect(PolicyIconResolver.systemItemDisplayName(
            observationIdentifier: spotlight.stableKey
        ) == "Spotlight")

        let unrelatedOwner = MenuBarItemIdentity(
            ownerBundleIdentifier: "com.example.spotlight-helper",
            accessibilityIdentifier: nil,
            semanticLabel: "spotlight",
            role: "axmenubaritem",
            subrole: "axmenuextra",
            instanceOrdinal: 0,
            confidence: .moderate
        )
        #expect(PolicyIconResolver.systemItemDescriptor(
            observationIdentifier: unrelatedOwner.stableKey
        ) == .fallback)
        #expect(PolicyIconResolver.systemItemDescriptor(
            observationIdentifier: "prefix-com.apple.menuextra.battery-suffix"
        ) == .fallback)
        #expect(PolicyIconResolver.systemItemDescriptor(
            observationIdentifier: spotlight.stableKey + "x"
        ) == .fallback)

        let colorFilters = MenuBarItemIdentity(
            ownerBundleIdentifier: "com.apple.ControlCenter",
            accessibilityIdentifier: nil,
            semanticLabel: "color filters",
            role: "axmenubaritem",
            subrole: "axmenuextra",
            instanceOrdinal: 0,
            confidence: .moderate
        )
        #expect(PolicyIconResolver.systemItemDescriptor(
            observationIdentifier: colorFilters.stableKey
        ) == .systemSymbol(name: "circle.lefthalf.filled"))

        let labelOnly = MenuBarItemIdentity(
            ownerBundleIdentifier: "com.apple.MenuBarAgent",
            accessibilityIdentifier: nil,
            semanticLabel: "energy mode",
            role: "axmenubaritem",
            subrole: "axmenuextra",
            instanceOrdinal: 0,
            confidence: .moderate
        )
        #expect(PolicyIconResolver.systemItemDescriptor(
            observationIdentifier: labelOnly.stableKey
        ) == .systemSymbol(name: "bolt"))

        let timeMachine = MenuBarItemIdentity(
            ownerBundleIdentifier: "com.apple.systemuiserver",
            accessibilityIdentifier: nil,
            semanticLabel: "time machine",
            role: "axmenubaritem",
            subrole: "axmenuextra",
            instanceOrdinal: 0,
            confidence: .moderate
        )
        #expect(PolicyIconResolver.systemItemDisplayName(
            observationIdentifier: timeMachine.stableKey
        ) == "Time Machine")
    }

    @Test("Unknown application and system items use one honest fallback")
    func sharedFallback() {
        let application = PolicyIconResolver.applicationDescriptor(
            bundleIdentifier: "com.example.Missing",
            installedApplicationResolved: false
        )
        let system = PolicyIconResolver.systemItemDescriptor(
            observationIdentifier: "com.apple.menuextra.future-item"
        )

        #expect(application == .fallback)
        #expect(system == .fallback)
        #expect(application.symbolName == system.symbolName)
        #expect(application.usesFallback)
        #expect(system.usesFallback)
    }

    @Test("Candidate ordering and duplicate observations do not change icon selection")
    func refreshOrderingStability() {
        let observations = [
            MenuBarPolicyOwnershipObservation(
                bundleIdentifier: "com.example.First",
                processIdentifier: 10,
                menuBarItemCount: 1
            ),
            MenuBarPolicyOwnershipObservation(
                bundleIdentifier: "com.example.First",
                processIdentifier: 10,
                menuBarItemCount: 1
            ),
            MenuBarPolicyOwnershipObservation(
                bundleIdentifier: "com.example.Second",
                processIdentifier: 30,
                menuBarItemCount: 1
            ),
        ]
        let forwardInventory = PolicyCandidateInventory(observations: observations)
        let reversedInventory = PolicyCandidateInventory(
            observations: Array(observations.reversed())
        )
        let first = forwardInventory.candidates[0]
        let second = forwardInventory.candidates[1]
        let resolved = Set(["COM.EXAMPLE.FIRST"])

        let forward = PolicyIconResolver.applicationDescriptors(
            candidates: forwardInventory.candidates,
            resolvedBundleIdentifiers: resolved
        )
        let reversed = PolicyIconResolver.applicationDescriptors(
            candidates: reversedInventory.candidates,
            resolvedBundleIdentifiers: resolved
        )

        #expect(forward == reversed)
        #expect(forwardInventory.candidates.count == 2)
        #expect(forward[first.bundleIdentifier] == .installedApplication)
        #expect(forward[second.bundleIdentifier] == .fallback)
        #expect(first.processIdentifiers == [10])
        #expect(first.menuBarItemCount == 2)
    }

    @Test("Icon resolution cannot alter persistence, draft, diff, report, or fingerprints")
    func iconResolutionIsPresentationOnly() throws {
        let blenny = "xyz.fi5h.blenny"
        let revealable = "com.example.Revealable"
        let hidden = "com.example.Hidden"
        let document = try PersistentBundlePolicyDocument(
            managementEnabled: false,
            policies: [
                .init(bundleIdentifier: blenny, policy: .visible),
                .init(bundleIdentifier: revealable, policy: .revealable),
                .init(bundleIdentifier: hidden, policy: .hidden),
            ]
        )
        let draft = BundlePolicyDraft(acceptedPolicy: document)
        let assignments = try BundlePolicyAssignments(
            visible: [blenny],
            revealable: [revealable],
            hidden: [hidden]
        )
        let baseline = try RevealAllowlistPlanner.plan(
            presentation: .baseline,
            assignments: assignments,
            observedRunningBundleIdentifiers: [blenny, revealable, hidden],
            blennyBundleIdentifier: blenny
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encodedBefore = try encoder.encode(document)
        let fingerprintBefore = baseline.managedPolicyFingerprint(assignments: assignments)
        let inventory = PolicyCandidateInventory(
            observations: [blenny, revealable, hidden].enumerated().map { offset, identifier in
                MenuBarPolicyOwnershipObservation(
                    bundleIdentifier: identifier,
                    processIdentifier: Int32(offset + 1),
                    menuBarItemCount: 1
                )
            }
        )
        let scope = PolicyValidationScope(
            approvedBundleIdentifiers: [blenny, revealable, hidden]
        )
        let dryRunBefore = try PolicyDryRunner.prepare(
            oldPolicy: document,
            draft: draft,
            managementEnabled: false,
            candidates: inventory,
            observedRunningBundleIdentifiers: [blenny, revealable, hidden],
            scope: scope,
            blennyBundleIdentifier: blenny
        )

        _ = PolicyIconResolver.applicationDescriptor(
            bundleIdentifier: revealable,
            installedApplicationResolved: true
        )
        _ = PolicyIconResolver.systemItemDescriptor(
            observationIdentifier: "com.apple.menuextra.wifi"
        )

        #expect(try encoder.encode(document) == encodedBefore)
        #expect(BundlePolicyDraft(acceptedPolicy: document) == draft)
        #expect(baseline.managedPolicyFingerprint(assignments: assignments) == fingerprintBefore)
        let dryRunAfter = try PolicyDryRunner.prepare(
            oldPolicy: document,
            draft: draft,
            managementEnabled: false,
            candidates: inventory,
            observedRunningBundleIdentifiers: [blenny, revealable, hidden],
            scope: scope,
            blennyBundleIdentifier: blenny
        )
        #expect(dryRunAfter.report.diff == dryRunBefore.report.diff)
        #expect(dryRunAfter.report.text == dryRunBefore.report.text)
        #expect(dryRunAfter.report.fingerprint == dryRunBefore.report.fingerprint)
    }
}
