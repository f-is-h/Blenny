#if BLENNY_PRODUCT || DEBUG
import Darwin
import Foundation

/// AppKit can omit launchDate for background helpers. libproc supplies the
/// kernel start time without opening, signalling or changing that process.
enum OrderingProcessLifetime {
    static func read(pid: pid_t) -> Date? {
        guard pid > 0 else { return nil }
        var info = proc_bsdinfo()
        let expectedSize = MemoryLayout<proc_bsdinfo>.size
        let returnedSize = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(expectedSize))
        return validated(
            requestedPID: pid, returnedPID: info.pbi_pid,
            returnedSize: Int(returnedSize), expectedSize: expectedSize,
            seconds: info.pbi_start_tvsec, microseconds: info.pbi_start_tvusec
        )
    }

    static func validated(
        requestedPID: pid_t, returnedPID: UInt32,
        returnedSize: Int, expectedSize: Int,
        seconds: UInt64, microseconds: UInt64
    ) -> Date? {
        guard requestedPID > 0, returnedPID == UInt32(requestedPID),
              returnedSize == expectedSize, expectedSize > 0,
              seconds > 0, seconds < 253_402_300_800,
              microseconds < 1_000_000 else { return nil }
        return Date(timeIntervalSince1970: Double(seconds) + Double(microseconds) / 1_000_000)
    }
}
#endif
