import Foundation
import Testing
@testable import BlennyCore

@Suite("macOS 27 preferred-position state")
struct PreferredPositionStateTests {
    private let environment = RuntimeEnvironment(
        macOSVersion: "27.0.0",
        buildVersion: "TEST",
        architecture: "arm64"
    )

    @Test("snapshot fingerprint is stable across entry order")
    func stableFingerprint() throws {
        let first = try snapshot(entries: [entry(key: "second", value: 2), entry(key: "first", value: 1)])
        let second = try snapshot(entries: [entry(key: "first", value: 1), entry(key: "second", value: 2)])

        #expect(first.fingerprint == second.fingerprint)
        #expect(first.entries == second.entries)
    }

    @Test("identical state produces an empty restore plan")
    func emptyRestorePlan() throws {
        let backup = try snapshot(entries: [entry(key: "item", value: 42)])
        let current = try snapshot(entries: [entry(key: "item", value: 42)])
        let plan = try PreferredPositionRestorePlan.make(backup: backup, current: current)

        #expect(plan.operations.isEmpty)
    }

    @Test("restore plan sets changed and missing backup values")
    func restoreSetPlan() throws {
        let backup = try snapshot(entries: [
            entry(key: "changed", value: 10),
            entry(key: "missing", value: 20)
        ])
        let current = try snapshot(entries: [entry(key: "changed", value: 99)])
        let plan = try PreferredPositionRestorePlan.make(backup: backup, current: current)

        #expect(plan.setOperationCount == 2)
        #expect(plan.removeOperationCount == 0)
    }

    @Test("restore plan removes keys absent from the backup")
    func restoreRemovePlan() throws {
        let backup = try snapshot(entries: [])
        let current = try snapshot(entries: [entry(key: "new", value: 10)])
        let plan = try PreferredPositionRestorePlan.make(backup: backup, current: current)

        #expect(plan.setOperationCount == 0)
        #expect(plan.removeOperationCount == 1)
    }

    @Test("restore plan rejects snapshots with different domain scope")
    func rejectsScopeMismatch() throws {
        let backup = try snapshot(entries: [])
        let current = try PreferredPositionSnapshot(
            generatedAt: Date(timeIntervalSince1970: 0),
            environment: environment,
            domains: ["com.apple.controlcenter"],
            entries: []
        )

        #expect(throws: PreferredPositionStateError.self) {
            try PreferredPositionRestorePlan.make(backup: backup, current: current)
        }
    }

    @Test("JSON round trip preserves number representation metadata")
    func numberMetadataRoundTrip() throws {
        let original = try snapshot(entries: [entry(key: "fractional", value: 130.5, numberType: 5)])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PreferredPositionSnapshot.self, from: data)

        #expect(decoded == original)
        #expect(try #require(decoded.entries.first).value == .number(
            value: 130.5,
            cfNumberTypeRawValue: 5
        ))
    }

    private func snapshot(entries: [PreferredPositionEntry]) throws -> PreferredPositionSnapshot {
        try PreferredPositionSnapshot(
            generatedAt: Date(timeIntervalSince1970: 0),
            environment: environment,
            domains: ["com.apple.systemuiserver"],
            entries: entries
        )
    }

    private func entry(
        key: String,
        value: Double,
        numberType: Int = 5
    ) -> PreferredPositionEntry {
        PreferredPositionEntry(
            domain: "com.apple.systemuiserver",
            key: "NSStatusItem Preferred Position \(key)",
            value: .number(value: value, cfNumberTypeRawValue: numberType)
        )
    }
}
