#if DEBUG
import Testing
import Foundation
@testable import BlennyCore

@Suite("Configuration ordering backend scope")
struct OrderingConfigurationBackendScopeTests {
    @Test func exactBundleCodeIdentityRequiresExactUniqueStatusTokens() {
        let owner = OrderingProcess(
            bundleIdentifier: "example.owner", executableName: "Owner", pid: 42,
            launchTime: Date(timeIntervalSince1970: 100), isSystem: false
        )
        let exact = ["status:example.owner::first": OrderingValue.integer(3)]
        let evidence = MacOS27MenuBarOrderingBackend.exactBundleApplicationIdentityForTesting(
            process: owner, table: exact, processes: [owner],
            signingIdentifier: "example.owner"
        )
        #expect(evidence?.signingIdentifier == "example.owner")

        #expect(MacOS27MenuBarOrderingBackend.exactBundleApplicationIdentityForTesting(
            process: owner,
            table: ["status:Owner::first": .integer(3)],
            processes: [owner], signingIdentifier: "example.owner"
        ) == nil)
        #expect(MacOS27MenuBarOrderingBackend.exactBundleApplicationIdentityForTesting(
            process: owner,
            table: [
                "status:example.owner::first": .integer(3),
                "status:Owner::legacy": .integer(2),
            ],
            processes: [owner], signingIdentifier: "example.owner"
        ) != nil)
        #expect(MacOS27MenuBarOrderingBackend.exactBundleApplicationIdentityForTesting(
            process: owner, table: exact, processes: [owner],
            signingIdentifier: "different.owner"
        ) == nil)

        let collision = OrderingProcess(
            bundleIdentifier: "example.other", executableName: "example.owner", pid: 43,
            launchTime: Date(timeIntervalSince1970: 101), isSystem: false
        )
        #expect(MacOS27MenuBarOrderingBackend.exactBundleApplicationIdentityForTesting(
            process: owner, table: exact, processes: [owner, collision],
            signingIdentifier: "example.owner"
        ) == nil)
    }

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

    @Test func containerFileDisagreementGetsOneBoundedReadRetry() async throws {
        let expected = ["TrailingItemPreferredPositions": OrderingValue.dictionary([
            "status:example.owner::Item-0": .real(42)
        ])]
        var reads = 0
        var settlements = 0
        let recovered = try await MacOS27MenuBarOrderingBackend
            .readCorroboratedGroupAfterBoundedSettle(
                read: {
                    reads += 1
                    if reads == 1 {
                        throw MacOS27MenuBarOrderingBackendError.groupSourcesDisagree
                    }
                    return expected
                },
                settle: { settlements += 1 }
            )
        #expect(recovered == expected)
        #expect(reads == 2)
        #expect(settlements == 1)

        reads = 0
        settlements = 0
        await #expect(throws: MacOS27MenuBarOrderingBackendError.groupSourcesDisagree) {
            try await MacOS27MenuBarOrderingBackend.readCorroboratedGroupAfterBoundedSettle(
                read: {
                    reads += 1
                    throw MacOS27MenuBarOrderingBackendError.groupSourcesDisagree
                },
                settle: { settlements += 1 }
            )
        }
        #expect(reads == 2)
        #expect(settlements == 1)

        reads = 0
        settlements = 0
        await #expect(throws: MacOS27MenuBarOrderingBackendError.groupChangedDuringCapture) {
            try await MacOS27MenuBarOrderingBackend.readCorroboratedGroupAfterBoundedSettle(
                read: {
                    reads += 1
                    throw MacOS27MenuBarOrderingBackendError.groupChangedDuringCapture
                },
                settle: { settlements += 1 }
            )
        }
        #expect(reads == 1)
        #expect(settlements == 0)
    }

    @Test("Neither direction of a generation split is a verified configuration", arguments: [false, true])
    func generationSplitRequiresSettlement(fileLags: Bool) async throws {
        let before = [OrderingSnapshot.tableKey: OrderingValue.dictionary(["status:example.owner::one": .real(10)])]
        let after = [OrderingSnapshot.tableKey: OrderingValue.dictionary(["status:example.owner::one": .real(20)])]
        let file = fileLags ? before : after
        let api = fileLags ? after : before
        guard case let .dictionary(apiTable)? = api[OrderingSnapshot.tableKey],
              case let .dictionary(finalTable)? = after[OrderingSnapshot.tableKey] else {
            Issue.record("Missing fixture table")
            return
        }
        #expect(throws: MacOS27MenuBarOrderingBackendError.groupSourcesDisagree) {
            try MacOS27MenuBarOrderingBackend.corroboratedGroup(first: file, containerTable: apiTable, second: file)
        }
        var settled = false
        var reads = 0
        let result = try await MacOS27MenuBarOrderingBackend.readCorroboratedGroupAfterBoundedSettle(
            read: {
                reads += 1
                return try MacOS27MenuBarOrderingBackend.corroboratedGroup(
                    first: settled ? after : file,
                    containerTable: settled ? finalTable : apiTable,
                    second: settled ? after : file
                )
            }, settle: { settled = true }
        )
        #expect(result == after)
        #expect(reads == 2)
        #expect(throws: MacOS27MenuBarOrderingBackendError.groupChangedDuringCapture) {
            try MacOS27MenuBarOrderingBackend.corroboratedGroup(first: before, containerTable: finalTable, second: after)
        }
    }
}
#endif
