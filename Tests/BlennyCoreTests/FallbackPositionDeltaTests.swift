#if DEBUG
import Foundation
import Testing
@testable import BlennyCore

@Suite("Fallback-only position delta")
struct FallbackPositionDeltaTests {
    private let key = FallbackPositionDelta.key

    @Test("Fish-only placement preserves the accepted arrow and recovers partial writes")
    func fishPlacement() throws {
        let fish = FallbackPositionDelta.fishKey
        let delta = try FallbackPositionDelta(original: .real(700), proposed: .real(700),
            fishOriginal: .integer(900), fishProposed: .real(680))
        let baseline: [String: OrderingValue] = [key: .real(700), fish: .integer(900), "other": .real(500)]
        let applied = try delta.applying(to: baseline)
        #expect(applied[key] == baseline[key])
        #expect(applied[fish] == .real(680))
        #expect(try delta.restoring(in: applied) == baseline)
        #expect(try JSONDecoder().decode(FallbackPositionDelta.self,
            from: JSONEncoder().encode(delta)) == delta)
        var drift = applied
        drift[fish] = .real(690)
        #expect(throws: FallbackPositionDelta.Failure.targetDrift) { try delta.restoring(in: drift) }
        let two = try FallbackPositionDelta(original: .real(800), proposed: .real(700),
            fishOriginal: .integer(900), fishProposed: .real(680))
        #expect(try two.restoring(in: [key: .real(700), fish: .integer(900)])
            == [key: .real(800), fish: .integer(900)])
    }

    @Test("Only the fallback changes; fish, historical aliases and other owners survive")
    func scope() throws {
        let baseline: [String: OrderingValue] = [key: .integer(800),
            "status:xyz.fi5h.blenny::Blenny.Fish": .real(740),
            "status:Blenny::Item-1": .real(920),
            "status:example.other::Item-0": .real(700)]
        let delta = try FallbackPositionDelta(original: .integer(800), proposed: .real(680.5))
        let applied = try delta.applying(to: baseline)
        #expect(Set(applied.keys) == Set(baseline.keys))
        #expect(baseline.keys.filter { applied[$0] != baseline[$0] } == [key])
        #expect(try delta.restoring(in: applied) == baseline)
    }

    @Test("Recovery preserves unrelated changes and exact original numeric type")
    func inverse() throws {
        let delta = try FallbackPositionDelta(original: .integer(800), proposed: .real(680.5))
        let current: [String: OrderingValue] = [key: .real(680.5), "new-key": .string("keep")]
        let restored = try delta.restoring(in: current)
        #expect(restored == [key: .integer(800), "new-key": .string("keep")])
        #expect(try delta.restoring(in: restored) == restored)
    }

    @Test("Missing, externally moved and type-changed targets fail closed")
    func drift() throws {
        let delta = try FallbackPositionDelta(original: .integer(800), proposed: .real(680.5))
        for value: OrderingValue? in [nil, .real(800), .real(810)] {
            let current = value.map { [key: $0] } ?? [:]
            #expect(throws: FallbackPositionDelta.Failure.targetDrift) {
                try delta.applying(to: current)
            }
            #expect(throws: FallbackPositionDelta.Failure.targetDrift) {
                try delta.restoring(in: current)
            }
        }
    }

    @Test("Invalid values and numeric no-ops are rejected")
    func invalid() {
        for value: OrderingValue in [.real(.nan), .real(.infinity), .real(0),
            .integer(-1), .real(1_000_001), .bool(true), .string("700")] {
            #expect(throws: FallbackPositionDelta.Failure.invalidPosition) {
                try FallbackPositionDelta(original: .integer(800), proposed: value)
            }
        }
        #expect(throws: FallbackPositionDelta.Failure.unchangedPosition) {
            try FallbackPositionDelta(original: .integer(800), proposed: .real(800))
        }
    }

    @Test("Decoded deltas retain validation and round-trip the inverse")
    func decoding() throws {
        let delta = try FallbackPositionDelta(original: .integer(800), proposed: .real(680.5))
        let data = try JSONEncoder().encode(delta)
        #expect(try JSONDecoder().decode(FallbackPositionDelta.self, from: data) == delta)
        let invalid = Data(#"{"original":{"kind":"integer","value":800},"proposed":{"kind":"real","value":0}}"#.utf8)
        #expect(throws: FallbackPositionDelta.Failure.invalidPosition) {
            try JSONDecoder().decode(FallbackPositionDelta.self, from: invalid)
        }
    }
}
#endif
