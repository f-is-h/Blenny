#if DEBUG
import Testing
import Foundation
@testable import BlennyCore

@Suite("Configuration ordering backend scope")
struct OrderingConfigurationBackendScopeTests {
    @Test func onlyExactMappedSystemModulesAreAdmittedToConfigurationWrites() throws {
        let before: [String: OrderingValue] = [
            "module:Bluetooth": .integer(3), "module:WiFi": .integer(2), "module:Clock": .integer(1)
        ]
        let after: [String: OrderingValue] = [
            "module:Bluetooth": .integer(2), "module:WiFi": .integer(3), "module:Clock": .integer(1)
        ]
        #expect(try MacOS27MenuBarOrderingBackend.validateWriteScopeForTesting(
            previous: before, proposed: after, configurationMode: true
        ) == ["module:Bluetooth", "module:WiFi"])
        #expect(throws: MacOS27MenuBarOrderingBackendError.invalidWriteScope) {
            try MacOS27MenuBarOrderingBackend.validateWriteScopeForTesting(previous: before, proposed: after)
        }
        for key in ["module:Clock", "module:AudioVideoModule", "module:BentoBox", "module:Unknown"] {
            #expect(throws: MacOS27MenuBarOrderingBackendError.invalidWriteScope) {
                try MacOS27MenuBarOrderingBackend.validateWriteScopeForTesting(
                    previous: [key: .integer(1)], proposed: [key: .integer(2)], configurationMode: true
                )
            }
        }
    }

    @Test func exactSystemItemScopeDoesNotExpandToSharedHostSiblings() {
        let host = OrderingProcess(
            bundleIdentifier: "com.apple.systemuiserver", executableName: "SystemUIServer", pid: 99,
            launchTime: Date(timeIntervalSince1970: 100), isSystem: true
        )
        let siri = ExactSystemOrderingItem.siri.configurationKey
        let timeMachine = ExactSystemOrderingItem.timeMachine.configurationKey
        let table: [String: OrderingValue] = [siri: .integer(1), timeMachine: .integer(2)]
        #expect(MacOS27MenuBarOrderingBackend.configurationOwnerKeys(
            for: [siri], table: table, processes: [host]
        ) == [siri])
    }

    @Test func finalProcessCheckIncludesUnchangedKeysOfAnAffectedOwner() {
        let owner = OrderingProcess(
            bundleIdentifier: "example.owner", executableName: "Owner", pid: 42,
            launchTime: Date(timeIntervalSince1970: 100), isSystem: false
        )
        let table: [String: OrderingValue] = [
            "status:example.owner::first": .integer(3),
            "status:Owner::second": .integer(2),
            "status:example.unrelated::first": .integer(1)
        ]
        #expect(MacOS27MenuBarOrderingBackend.configurationOwnerKeys(
            for: ["status:example.owner::first"], table: table, processes: [owner]
        ) == ["status:example.owner::first", "status:Owner::second"])
    }

    @Test func inventoryDerivedAllowlistIsNotAPolicyChangeDuringCapture() {
        let before = MacOS27MenuBarOrderingContext(
            policyFingerprint: "accepted", orderingAllowedBundleIdentifiers: ["example.alpha"],
            lifecycleGeneration: 2
        )
        let unrelatedLaunch = MacOS27MenuBarOrderingContext(
            policyFingerprint: "accepted", orderingAllowedBundleIdentifiers: ["example.alpha", "example.helper"],
            lifecycleGeneration: 2
        )
        #expect(before.hasSamePolicyContext(as: unrelatedLaunch))
        #expect(!before.hasSamePolicyContext(as: .init(
            policyFingerprint: "edited", orderingAllowedBundleIdentifiers: ["example.alpha"],
            lifecycleGeneration: 2
        )))
        #expect(!before.hasSamePolicyContext(as: .init(
            policyFingerprint: "accepted", orderingAllowedBundleIdentifiers: ["example.alpha"],
            lifecycleGeneration: 3
        )))
    }

    @Test func wholeOwnerBlocksCanExceedLegacySingleItemLimit() throws {
        let count = 40
        let before = Dictionary(uniqueKeysWithValues: (0..<count).map {
            ("status:example.owner::Item-\($0)", OrderingValue.integer(Int64($0 + 1)))
        })
        let after = Dictionary(uniqueKeysWithValues: (0..<count).map {
            ("status:example.owner::Item-\($0)", OrderingValue.integer(Int64(count - $0)))
        })
        #expect(throws: MacOS27MenuBarOrderingBackendError.invalidWriteScope) {
            try MacOS27MenuBarOrderingBackend.validateWriteScopeForTesting(
                previous: before, proposed: after
            )
        }
        #expect(try MacOS27MenuBarOrderingBackend.validateWriteScopeForTesting(
            previous: before, proposed: after, configurationMode: true
        ).count == count)
    }

    @Test func configurationModeStillRefusesKeyCreationAndNonStatusMutation() {
        #expect(throws: MacOS27MenuBarOrderingBackendError.invalidWriteScope) {
            try MacOS27MenuBarOrderingBackend.validateWriteScopeForTesting(
                previous: ["status:example.owner::Item-0": .integer(1)],
                proposed: ["status:example.owner::Item-1": .integer(1)],
                configurationMode: true
            )
        }
        #expect(throws: MacOS27MenuBarOrderingBackendError.invalidWriteScope) {
            try MacOS27MenuBarOrderingBackend.validateWriteScopeForTesting(
                previous: ["unknown-control": .integer(1)],
                proposed: ["unknown-control": .integer(2)],
                configurationMode: true
            )
        }
    }
}
#endif
