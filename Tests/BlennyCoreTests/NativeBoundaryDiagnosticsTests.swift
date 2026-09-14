#if DEBUG
import Foundation
import Testing
@testable import BlennyCore

@Suite("Native boundary diagnostic evidence")
struct NativeBoundaryDiagnosticsTests {
    @Test("Only one input belongs to an armed check; late callbacks cannot replace it")
    func correlation() {
        var check = NativeControlClickCheck()
        #expect(check.begin(source: "arrow", event: "leftMouseUp") == nil)
        check.arm()
        let first = check.begin(source: "arrow", event: "leftMouseUp")
        #expect(first != nil)
        #expect(check.begin(source: "fish", event: "leftMouseUp") == nil)
        check.record(id: first, stage: "entry")
        let inFlight = check
        check.record(id: nil, stage: "unrelated background callback", finished: true)
        #expect(check == inFlight)
        check.arm()
        check.record(id: first, stage: "old transition completed", finished: true)
        #expect(check.phase == .armed)
        #expect(check.stages.isEmpty)
        let second = check.begin(source: "fish", event: "leftMouseUp")
        check.record(id: second, stage: "open editor", finished: true)
        let completed = check
        check.record(id: second, stage: "unrelated transition")
        #expect(check == completed)
    }

    @Test("Failure checks finish, remain bounded and preserve their rejection reason")
    func boundedFailure() throws {
        var check = NativeControlClickCheck()
        check.arm()
        let id = check.begin(source: "arrow", event: "leftMouseUp")
        for _ in 0..<40 { check.record(id: id, stage: String(repeating: "x", count: 1_000)) }
        check.record(id: id, stage: "finished", finished: true)
        #expect(check.phase == .finished)
        #expect(check.stages.count == 20)
        #expect(check.stages.last == "finished")
        #expect(check.stages.allSatisfy { $0.count <= 512 })
        let data = try JSONEncoder().encode(check)
        #expect(try JSONDecoder().decode(NativeControlClickCheck.self, from: data) == check)
    }

    @Test("An old fallback key must not become a live Visible item")
    func historicalOwnKeys() {
        let prefix = "status:xyz.fi5h.blenny::"
        let keys: Set<String> = [prefix + "Blenny.Fish", prefix + "Item-1",
            prefix + "OldExperiment", "status:com.example.Other::Item-1"]
        let grouped = OwnControlKeyEvidence(tableKeys: keys,
            bundleIdentifier: "xyz.fi5h.blenny", autosaveNames: ["Blenny.Fish"])
        #expect(grouped.instantiatedKeys == [prefix + "Blenny.Fish"])
        #expect(grouped.storedOwnKeysNotInstantiated == [prefix + "Item-1", prefix + "OldExperiment"])
        let separate = OwnControlKeyEvidence(tableKeys: keys,
            bundleIdentifier: "xyz.fi5h.blenny", autosaveNames: ["Blenny.Fish", "Item-1"])
        #expect(separate.storedOwnKeysNotInstantiated == [prefix + "OldExperiment"])
    }

    @Test("Missing or alternative namespace keys are not invented as confirmed identities")
    func missingKeys() {
        let evidence = OwnControlKeyEvidence(tableKeys: ["status:Blenny::Blenny.Fish"],
            bundleIdentifier: "xyz.fi5h.blenny", autosaveNames: ["Blenny.Fish"])
        #expect(evidence.instantiatedKeys.isEmpty)
        #expect(evidence.instantiatedKeysMissingFromTable == ["status:xyz.fi5h.blenny::Blenny.Fish"])
        #expect(evidence.storedOwnKeysNotInstantiated.isEmpty)
    }
}
#endif
