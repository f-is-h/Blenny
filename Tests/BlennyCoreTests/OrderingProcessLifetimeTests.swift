#if DEBUG
import Foundation
import Testing
@testable import BlennyCore

@Suite("Ordering process lifetime fallback")
struct OrderingProcessLifetimeTests {
    @Test func validatesCompleteMatchingKernelIdentity() {
        let date = OrderingProcessLifetime.validated(
            requestedPID: 42, returnedPID: 42, returnedSize: 136, expectedSize: 136,
            seconds: 1_789_000_000, microseconds: 125_000
        )
        #expect(date == Date(timeIntervalSince1970: 1_789_000_000.125))
    }

    @Test func refusesPartialReusedOrMalformedIdentity() {
        for (pid, size, seconds, micros) in [
            (UInt32(43), 136, UInt64(1_789_000_000), UInt64(0)),
            (42, 0, 1_789_000_000, 0),
            (42, 135, 1_789_000_000, 0),
            (42, 136, 0, 0),
            (42, 136, 1_789_000_000, 1_000_000)
        ] {
            #expect(OrderingProcessLifetime.validated(
                requestedPID: 42, returnedPID: pid, returnedSize: size, expectedSize: 136,
                seconds: seconds, microseconds: micros
            ) == nil)
        }
    }
}
#endif
