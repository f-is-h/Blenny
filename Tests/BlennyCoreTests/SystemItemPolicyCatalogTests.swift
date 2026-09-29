import Foundation
import Testing
@testable import BlennyCore

@Suite("System-item policy catalog")
struct SystemItemPolicyCatalogTests {
    private let blenny = "xyz.fi5h.blenny"

    @Test("Assessment runtime admits the complete macOS 27 major")
    func runtimeMajorVersionAdmission() {
        #expect(ExperimentalMacOS27AssessmentFactory.supportedOperatingSystemMajorVersion == 27)
        #expect(ExperimentalMacOS27AssessmentFactory.compatibilityFingerprint
            == "arm64-macos27-assessment-contract-v5")
    }

    @Test("Debug catalog contains only the eight exact writable mappings")
    func exactDebugCatalog() {
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        #expect(SystemItemPolicyCatalog.items == [
            .init(identifier: "com.apple.menuextra.battery", rawValue: 0, displayName: "Battery"),
            .init(identifier: "com.apple.menuextra.bluetooth", rawValue: 1, displayName: "Bluetooth"),
            .init(identifier: "com.apple.menuextra.display", rawValue: 3, displayName: "Display"),
            .init(identifier: "com.apple.menuextra.keyboard-brightness", rawValue: 4, displayName: "Keyboard Brightness"),
            .init(identifier: "com.apple.menuextra.sound", rawValue: 5, displayName: "Sound"),
            .init(identifier: "com.apple.menuextra.wifi", rawValue: 6, displayName: "Wi-Fi"),
            .init(identifier: "com.apple.menuextra.screen-mirroring", rawValue: 7, displayName: "Screen Mirroring"),
            .init(identifier: "com.apple.menuextra.controlcenter", rawValue: 8, displayName: "Control Center"),
        ])
        #expect(SystemItemPolicyCatalog.controllableItem(
            for: "com.apple.menuextra.clock"
        ) == nil)
        #else
        #expect(SystemItemPolicyCatalog.items.map(\.rawValue) == [1])
        #endif
    }

    @Test("Additional policy keys are exact, validated, and schema-gated")
    func strictPersistenceValidation() throws {
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        let empty = try document()
        #expect(empty.schemaVersion == 3)
        let sound = "com.apple.menuextra.sound"
        let configured = try document(systemItemPolicies: [sound: .hidden])
        #expect(configured.schemaVersion == 4)
        #expect(configured.systemItemPolicies == [sound: .hidden])

        for identifier in [
            "com.apple.menuextra.clock",
            "com.apple.menuextra.bluetooth",
            "com.apple.menuextra.unknown",
            "COM.APPLE.MENUEXTRA.SOUND",
        ] {
            #expect(throws: PersistentBundlePolicyDocumentError.self) {
                _ = try document(systemItemPolicies: [identifier: .hidden])
            }
        }
        #else
        #expect(throws: PersistentBundlePolicyDocumentError.systemItemPoliciesUnavailable) {
            _ = try document(systemItemPolicies: [
                "com.apple.menuextra.sound": .hidden,
            ])
        }
        #endif
    }

    @Test("Persistent policy identities accept only trusted live composites")
    func persistentPolicyObservationMapping() throws {
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        let observations = [
            "com.apple.systemuiserver|:siri|axmenubaritem":
                "com.apple.menuextra.siri",
            "com.apple.systemuiserver|:time machine|axmenubaritem":
                "com.apple.menuextra.TimeMachine",
            "com.apple.controlcenter|:now playing|axmenubaritem":
                "com.apple.menuextra.now-playing",
        ]
        for (observation, expectedIdentifier) in observations {
            let item = try #require(PersistentSystemItemPolicyCatalog.controllableItem(
                forObservationIdentifier: observation
            ))
            #expect(item.identifier == expectedIdentifier)
        }

        let stableSiri = MenuBarItemIdentity(
            ownerBundleIdentifier: "com.apple.systemuiserver",
            accessibilityIdentifier: "Siri",
            semanticLabel: nil,
            role: "AXMenuBarItem",
            subrole: "AXMenuExtra",
            instanceOrdinal: 0,
            confidence: .strong
        ).stableKey
        #expect(PersistentSystemItemPolicyCatalog.controllableItem(
            forObservationIdentifier: stableSiri
        )?.identifier == "com.apple.menuextra.siri")
        let semanticStableSiri = MenuBarItemIdentity(
            ownerBundleIdentifier: "com.apple.systemuiserver",
            accessibilityIdentifier: nil,
            semanticLabel: "Siri",
            role: "AXMenuBarItem",
            subrole: nil,
            instanceOrdinal: 0,
            confidence: .moderate
        ).stableKey
        #expect(PersistentSystemItemPolicyCatalog.controllableItem(
            forObservationIdentifier: semanticStableSiri
        )?.identifier == "com.apple.menuextra.siri")

        for rejected in [
            "com.example.statusapp|:siri|axmenubaritem",
            "com.apple.systemuiserver|:siri settings|axmenubaritem",
            "com.apple.systemuiserver|:siri|axbutton",
            "com.apple.menuextra.siri-settings",
        ] {
            #expect(PersistentSystemItemPolicyCatalog.controllableItem(
                forObservationIdentifier: rejected
            ) == nil)
        }
        #else
        #expect(PersistentSystemItemPolicyCatalog.controllableItem(
            forObservationIdentifier: "com.apple.systemuiserver|:siri|axmenubaritem"
        ) == nil)
        #endif
    }

    @Test("System control capabilities require a unique exact owner and writer target")
    func observedCapabilityIdentity() {
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        let wifi = SystemMenuBarItemObservation(
            observationIdentifier: "com.apple.menuextra.wifi",
            ownerBundleIdentifier: "com.apple.controlcenter",
            displayName: "Wi-Fi", observationCount: 1
        )
        #expect(SystemItemCapabilityIdentity.policyIdentifier(for: wifi)
            == "com.apple.menuextra.wifi")
        #expect(SystemItemCapabilityIdentity.orderingItem(for: wifi) == .wifi)

        let spotlight = SystemMenuBarItemObservation(
            observationIdentifier: MenuBarItemIdentity(
                ownerBundleIdentifier: "com.apple.campo",
                accessibilityIdentifier: nil,
                semanticLabel: "Spotlight",
                role: "AXMenuBarItem", subrole: "AXMenuExtra",
                instanceOrdinal: 0, confidence: .moderate
            ).stableKey,
            ownerBundleIdentifier: "com.apple.campo",
            displayName: "Spotlight", observationCount: 1
        )
        #expect(SystemItemCapabilityIdentity.policyIdentifier(for: spotlight)
            == "com.apple.menuextra.spotlight")
        #expect(SystemItemCapabilityIdentity.orderingItem(for: spotlight) == .spotlight)

        let agentNowPlaying = SystemMenuBarItemObservation(
            observationIdentifier: "com.apple.menuextra.now-playing",
            ownerBundleIdentifier: "com.apple.MenuBarAgent",
            displayName: "Now Playing", observationCount: 1
        )
        #expect(SystemItemCapabilityIdentity.recoveryIdentifier(for: agentNowPlaying)
            == agentNowPlaying.observationIdentifier)
        #expect(SystemItemCapabilityIdentity.policyIdentifier(for: agentNowPlaying)
            == nil)
        #expect(SystemItemCapabilityIdentity.orderingItem(for: agentNowPlaying)
            == nil)

        for observation in [
            SystemMenuBarItemObservation(
                observationIdentifier: wifi.observationIdentifier,
                ownerBundleIdentifier: "com.example.Impersonator",
                displayName: "Wi-Fi", observationCount: 1
            ),
            SystemMenuBarItemObservation(
                observationIdentifier: wifi.observationIdentifier,
                ownerBundleIdentifier: wifi.ownerBundleIdentifier,
                displayName: "Wi-Fi", observationCount: 2
            ),
            SystemMenuBarItemObservation(
                observationIdentifier: "com.apple.menuextra.focusmode",
                ownerBundleIdentifier: "com.apple.controlcenter",
                displayName: "Focus", observationCount: 1
            ),
            SystemMenuBarItemObservation(
                observationIdentifier: spotlight.observationIdentifier,
                ownerBundleIdentifier: "com.example.Impersonator",
                displayName: "Spotlight", observationCount: 1
            ),
            SystemMenuBarItemObservation(
                observationIdentifier: "com.apple.MenuBarAgent|:now playing|axmenubaritem",
                ownerBundleIdentifier: "com.apple.MenuBarAgent",
                displayName: "Now Playing", observationCount: 1
            ),
        ] {
            #expect(SystemItemCapabilityIdentity.policyIdentifier(for: observation) == nil)
            #expect(SystemItemCapabilityIdentity.orderingItem(for: observation) == nil)
        }

        let absent = SystemMenuBarItemObservation(
            observationIdentifier: wifi.observationIdentifier,
            ownerBundleIdentifier: "com.apple.MenuBarAgent",
            displayName: "Wi-Fi", observationCount: 0
        )
        #expect(SystemItemCapabilityIdentity.policyIdentifier(for: absent) == nil)
        #expect(SystemItemCapabilityIdentity.policyIdentifier(
            for: absent, retainedWhileAbsent: true
        ) == wifi.observationIdentifier)
        #else
        #expect(SystemItemCapabilityIdentity.policyIdentifier(for: .init(
            observationIdentifier: "com.apple.menuextra.clock",
            ownerBundleIdentifier: "com.apple.controlcenter",
            displayName: "Clock", observationCount: 1
        )) == nil)
        #endif
    }

    @Test("Tampered receipt keys cannot decode into a writable policy")
    func tamperedPersistenceDecodeFailsClosed() throws {
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        let source = try document(systemItemPolicies: [
            "com.apple.menuextra.sound": .hidden,
        ])
        let encoded = try JSONEncoder().encode(source)
        let object = try #require(JSONSerialization.jsonObject(with: encoded)
            as? [String: Any])

        for identifier in [
            "com.apple.menuextra.clock",
            "com.apple.menuextra.bluetooth",
            "com.apple.menuextra.unknown",
        ] {
            var tampered = object
            tampered["systemItemPolicies"] = [identifier: MenuBarBundlePolicy.hidden.rawValue]
            let data = try JSONSerialization.data(withJSONObject: tampered)
            #expect(throws: PersistentBundlePolicyDocumentError.self) {
                _ = try JSONDecoder().decode(PersistentBundlePolicyDocument.self, from: data)
            }
        }
        #else
        let source = try document()
        var tampered = try #require(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(source)
        ) as? [String: Any])
        tampered["schemaVersion"] = 4
        tampered["systemItemPolicies"] = [
            "com.apple.menuextra.sound": MenuBarBundlePolicy.hidden.rawValue,
        ]
        #expect(throws: PersistentBundlePolicyDocumentError.systemItemPoliciesUnavailable) {
            _ = try JSONDecoder().decode(
                PersistentBundlePolicyDocument.self,
                from: JSONSerialization.data(withJSONObject: tampered)
            )
        }
        #endif
    }

    @Test("Draft, persistence transforms, diff, and plans preserve item intent")
    func policyFlowsCarrySystemItemPolicies() throws {
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        let sound = "com.apple.menuextra.sound"
        let wifi = "com.apple.menuextra.wifi"
        let accepted = try document(systemItemPolicies: [sound: .hidden])
        let draft = BundlePolicyDraft(acceptedPolicy: accepted)
            .assigningSystemItem(identifier: wifi, to: .revealable)
        #expect(draft.systemItemPolicies == [sound: .hidden, wifi: .revealable])
        #expect(try accepted.settingManagementEnabled(false).systemItemPolicies
            == accepted.systemItemPolicies)
        #expect(try accepted.replacingBundleIdentifier(
            from: blenny, with: "xyz.fi5h.relocated"
        ).systemItemPolicies == accepted.systemItemPolicies)

        let changed = try document(systemItemPolicies: draft.systemItemPolicies)
        let diff = BundlePolicyDiff.between(old: accepted, new: changed)
        #expect(diff.changes.map(\.description).contains("ADD Wi-Fi -> revealable"))
        #expect(accepted.policyFingerprint != changed.policyFingerprint)
        #expect(draft.fingerprint != BundlePolicyDraft(acceptedPolicy: accepted).fingerprint)

        let assignments = try BundlePolicyAssignments(
            visible: [blenny], revealable: [], hidden: []
        )
        let baseline = try RevealAllowlistPlanner.plan(
            presentation: .baseline,
            assignments: assignments,
            observedRunningBundleIdentifiers: [blenny],
            blennyBundleIdentifier: blenny,
            systemItemPolicies: draft.systemItemPolicies
        )
        let revealed = try RevealAllowlistPlanner.plan(
            presentation: .revealed,
            assignments: assignments,
            observedRunningBundleIdentifiers: [blenny],
            blennyBundleIdentifier: blenny,
            systemItemPolicies: draft.systemItemPolicies
        )
        #expect(!baseline.allowedSystemItems.contains(5))
        #expect(!revealed.allowedSystemItems.contains(5))
        #expect(!baseline.allowedSystemItems.contains(6))
        #expect(revealed.allowedSystemItems.contains(6))
        #else
        let assignments = try BundlePolicyAssignments(
            visible: [blenny], revealable: [], hidden: []
        )
        #expect(throws: RevealAllowlistPlannerError.systemItemPoliciesUnavailable) {
            _ = try RevealAllowlistPlanner.plan(
                presentation: .baseline,
                assignments: assignments,
                observedRunningBundleIdentifiers: [blenny],
                blennyBundleIdentifier: blenny,
                systemItemPolicies: ["com.apple.menuextra.sound": .hidden]
            )
        }
        #endif
    }

    private func document(
        systemItemPolicies: [String: MenuBarBundlePolicy] = [:]
    ) throws -> PersistentBundlePolicyDocument {
        try PersistentBundlePolicyDocument(
            managementEnabled: true,
            policies: [.init(bundleIdentifier: blenny, policy: .visible)],
            systemItemPolicies: systemItemPolicies
        )
    }
}
