import AppKit
import Testing
import BlennyCore
@testable import BlennyApp

@MainActor
struct StatusMenuTests {
    @Test func ordinaryRevealTimingPreservesExactRecovery() {
        for target: SharedSystemItemTrialTarget in [.spotlight, .timeMachine] {
            #expect(!MacOS27SystemItemPreferenceBackend.ordinaryRevealRequiresSettlement(target))
        }
        #expect(MacOS27SystemItemPreferenceBackend.ordinaryRevealRequiresSettlement(.siri))
        #expect(MacOS27SystemItemPreferenceBackend.ordinaryRevealRequiresSettlement(.nowPlaying))
    }

    @Test func stateAndDraftGatesSurviveAppKitValidation() throws {
        _ = NSApplication.shared
        var updatesAvailable = false
        let controller = StatusItemController(
            onOpenDiagnostics: {}, onRefresh: {}, onRequestAccess: {},
            onToggleOrdinaryReveal: {}, onResumeManaging: {}, onStopManaging: {},
            onRestorePreviousPolicy: {}, onQuit: {},
            canCheckForUpdates: { updatesAvailable }
        )
        let menu = controller.menu
        func item(_ title: String) throws -> NSMenuItem {
            try #require(menu.items.first { $0.title == title })
        }
        #expect(!menu.autoenablesItems)
        func verifyImages(_ menu: NSMenu) {
            for entry in menu.items where !entry.isSeparatorItem {
                #expect(entry.image != nil)
                #expect(entry.toolTip == nil)
                #expect(entry.preferredImageVisibility == .visible)
                if let submenu = entry.submenu { verifyImages(submenu) }
            }
        }
        verifyImages(menu)
        let originalAppearance = NSApp.appearance
        defer { NSApp.appearance = originalAppearance }
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            NSApp.appearance = NSAppearance(named: appearance)
            controller.prepareMenuForPresentation()
            #expect(menu.appearance?.bestMatch(from: [.aqua, .darkAqua]) == appearance)
        }
        let update = try item("Check for Updates")
        #expect(!update.isEnabled)
        updatesAvailable = true
        controller.prepareMenuForPresentation()
        #expect(update.isEnabled)
        #expect(menu.items.allSatisfy { $0.title != "Set Up Access…" && $0.title != "Refresh Menu Bar Items" })
        #if DEBUG
        let debug = try #require(menu.items.first { $0.title == "Debug" }?.submenu)
        #expect(!debug.autoenablesItems)

        #else
        #expect(menu.items.allSatisfy { $0.title != "Debug" })
        #endif
        #expect(try item("Position Blenny Controls…").action != nil)
        #expect(try item("Undo Control Placement").action != nil)
        controller.setAccessibilityTrusted(true)
        controller.setManagementState(.stopped, persistedManagementEnabled: false, recoveryAvailable: true)
        let open = try item("Open Blenny")
        #expect(open.isEnabled && open.action != nil)
        #expect(menu.items.allSatisfy { $0.title != "Restore Previous Visibility" })
        let website = try item("Website")
        #expect((website.representedObject as? URL)?.absoluteString == ProductSupportLinks.projectWebsite)
        let sponsor = try item("GitHub Sponsors")
        #expect(sponsor.image?.isTemplate == false)
        let koFi = try item("Buy Me a Coffee")
        #expect(koFi.image?.isTemplate == true)
        #expect(menu.items.allSatisfy { $0.title != "Support Blenny" })
        #expect(menu.index(of: sponsor) + 1 == menu.index(of: koFi))
        #expect(menu.index(of: koFi) + 1 == menu.index(of: website))
        #expect((sponsor.representedObject as? URL)?.host == "github.com")
        let sponsorURL = try #require(sponsor.representedObject as? URL)
        let sponsorQuery = try #require(URLComponents(url: sponsorURL, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(sponsorQuery.first { $0.name == "frequency" }?.value == "one-time")
        #expect(sponsorQuery.first { $0.name == "metadata_project" }?.value == "blenny")
        #expect(sponsorQuery.first { $0.name == "metadata_source" }?.value == "app")
        #expect(sponsorQuery.first { $0.name == "metadata_placement" }?.value == "menu")
        #expect((koFi.representedObject as? URL)?.absoluteString == ProductSupportLinks.koFi)
        let resume = try item("Resume Managing")
        let stop = try item("Stop Managing")
        #expect(!resume.isHidden && resume.isEnabled)
        #expect(stop.isHidden)
        controller.setDraftHasChanges(true)
        menu.update()
        #expect(!resume.isEnabled && !update.isEnabled)
        controller.setDraftHasChanges(false, requiresObservationRefresh: true)
        menu.update()
        #expect(!resume.isEnabled)
        controller.setDraftHasChanges(false)
        controller.setAccessibilityTrusted(false)
        #expect(!resume.isEnabled)
        controller.setAccessibilityTrusted(true)
        controller.setManagementState(.active("test"), persistedManagementEnabled: true, recoveryAvailable: false, hasRevealableBundles: true)
        #expect(open.title == "Open Blenny" && open.isEnabled)
        #expect(resume.isHidden && !stop.isHidden && stop.isEnabled)
        #expect(try item("Expand Revealable Items").isEnabled)
        controller.setManagementState(.ordinaryRevealSession("test"), persistedManagementEnabled: true, recoveryAvailable: true, hasRevealableBundles: true)
        #expect(try item("Collapse Revealable Items").isEnabled)
        controller.setInteractionBusy(true)
        menu.update()
        #expect(!stop.isEnabled && !update.isEnabled)
        #expect(try !item("Collapse Revealable Items").isEnabled)
        #expect(try item("Quit Blenny").isEnabled)
    }
}
