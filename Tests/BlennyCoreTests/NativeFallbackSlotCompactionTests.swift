import Testing
@testable import BlennyCore

@Suite("Native fallback slot compaction")
struct NativeFallbackSlotCompactionTests {
    @Test("The fallback is removed first and remains absent while native overflow is usable")
    func absenceIsFirstChoice() {
        var compaction = NativeFallbackSlotCompaction()

        #expect(compaction.update(
            nativeOverflowUsable: true, mayBeginCompaction: false
        ) == .init(allocation: .reserved, requestsVerification: false))
        #expect(compaction.update(
            nativeOverflowUsable: true, mayBeginCompaction: true
        ) == .init(allocation: .absent, requestsVerification: true))
        #expect(compaction.update(
            nativeOverflowUsable: true, mayBeginCompaction: true
        ) == .init(allocation: .absent, requestsVerification: false))
    }

    @Test("Native loss falls back through compact before reserving the full slot")
    func boundedFallbackTiers() {
        var compaction = NativeFallbackSlotCompaction()

        #expect(compaction.update(
            nativeOverflowUsable: true, mayBeginCompaction: true
        ) == .init(allocation: .absent, requestsVerification: true))
        #expect(compaction.update(
            nativeOverflowUsable: false, mayBeginCompaction: true
        ) == .init(allocation: .compact, requestsVerification: true))
        #expect(compaction.update(
            nativeOverflowUsable: false, mayBeginCompaction: true
        ) == .init(allocation: .reserved, requestsVerification: false))
        #expect(compaction.update(
            nativeOverflowUsable: true, mayBeginCompaction: true
        ) == .init(allocation: .reserved, requestsVerification: false))
    }

    @Test("A compact fallback commits when it restores native overflow")
    func compactFallbackCanCommit() {
        var compaction = NativeFallbackSlotCompaction()

        #expect(compaction.update(
            nativeOverflowUsable: true, mayBeginCompaction: true
        ).requestsVerification)
        #expect(compaction.update(
            nativeOverflowUsable: false, mayBeginCompaction: true
        ) == .init(allocation: .compact, requestsVerification: true))
        #expect(compaction.update(
            nativeOverflowUsable: true, mayBeginCompaction: true
        ) == .init(allocation: .compact, requestsVerification: false))
        #expect(compaction.update(
            nativeOverflowUsable: false, mayBeginCompaction: true
        ) == .init(allocation: .reserved, requestsVerification: false))
    }

    @Test("Only an explicit user reveal can reset a latched full fallback")
    func userRevealResetsLatch() {
        var compaction = NativeFallbackSlotCompaction()

        _ = compaction.update(
            nativeOverflowUsable: true, mayBeginCompaction: true
        )
        _ = compaction.update(
            nativeOverflowUsable: false, mayBeginCompaction: true
        )
        _ = compaction.update(
            nativeOverflowUsable: false, mayBeginCompaction: true
        )
        #expect(compaction.update(
            nativeOverflowUsable: true, mayBeginCompaction: true
        ).allocation == .reserved)

        compaction.beginUserRevealAttempt()

        #expect(compaction.update(
            nativeOverflowUsable: true, mayBeginCompaction: true
        ) == .init(allocation: .absent, requestsVerification: true))
    }
}
