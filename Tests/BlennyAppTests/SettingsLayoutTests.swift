import AppKit
import SwiftUI
import Testing
import BlennyCore
@testable import BlennyApp

@MainActor
struct SettingsLayoutTests {
    @Test func settingsFitsFixedWindowWithAndWithoutUpdates() throws {
        _ = NSApplication.shared
        let startupStates: [LaunchAtLoginPresentationState] = [
            .init(availability: .disabled),
            .init(availability: .enabled),
            .init(availability: .requiresApproval),
            .init(availability: .notFound),
            .init(availability: .disabled, failureMessage:
                "Login item registration was denied. Check Login Items in System Settings before trying again."),
        ]
        var heights: [CGFloat] = []
        for width in [560.0, 680.0] {
            for trusted in [false, true] {
                for updates in [false, true] {
                    for startup in startupStates {
                        for dark in [false, true] {
                            let model = ProductInterfaceModel()
                            model.navigate(to: .settings)
                            model.setAccessibilityTrusted(trusted, hasRequestedSystemPrompt: !trusted)
                            model.setLaunchAtLoginState(startup)
                            var invokedActions = 0
                            let actions = ProductInterfaceActions(
                                refresh: {}, requestAccess: { invokedActions += 1 },
                                resumeManaging: {}, stopManaging: {}, restorePreviousPolicy: {},
                                draftDidChange: { _ in }, applyDraft: {},
                                openProjectWebsite: {}, openMonthlySponsor: {},
                                openOneTimeSponsor: {}, openKoFi: {},
                                setLaunchAtLogin: { _ in invokedActions += 1 },
                                openLoginItemsSettings: { invokedActions += 1 },
                                checkForUpdates: updates ? { invokedActions += 1 } : nil,
                                setAutomaticUpdateChecks: updates ? { _ in invokedActions += 1 } : nil,
                                showFishPlacementGuide: {}, hideSharedSystemItem: { _ in },
                                restoreSharedSystemItem: { _ in }
                            )
                            let root = BlennyRootView(model: model, actions: actions)
                                .environment(\.colorScheme, dark ? .dark : .light)
                                .frame(width: width)
                                .fixedSize(horizontal: false, vertical: true)
                            let hosting = NSHostingView(rootView: root)
                            hosting.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                            let natural = hosting.fittingSize
                            heights.append(natural.height)
                            #expect(natural.height <= 420,
                                "Settings must fit: width=\(width), trusted=\(trusted), updates=\(updates), startup=\(startup), dark=\(dark)")
                            #expect(invokedActions == 0)

                            if let destination = ProcessInfo.processInfo.environment[
                                "BLENNY_SETTINGS_LAYOUT_CAPTURE_DIR"
                            ], startup.requiresApproval, !trusted, updates {
                                hosting.frame = NSRect(x: 0, y: 0, width: width, height: natural.height)
                                hosting.layoutSubtreeIfNeeded()
                                let rep = try #require(
                                    hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
                                )
                                hosting.cacheDisplay(in: hosting.bounds, to: rep)
                                let png = try #require(rep.representation(using: .png, properties: [:]))
                                try png.write(to: URL(fileURLWithPath: destination)
                                    .appendingPathComponent(
                                        "settings-\(Int(width))-\(dark ? "dark" : "light")-approval-updates.png"
                                    ))
                            }
                        }
                    }
                }
            }
        }
        print("settings-layout cases=\(heights.count) natural-height=\(heights.min()!)...\(heights.max()!)")
    }
}
