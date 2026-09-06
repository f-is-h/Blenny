import CryptoKit
import Darwin
import Foundation

// Unsupported macOS 27 research, excluded from all product targets.
// Pure proposed-value/inverse tests and optional exact-key reads only.
// This file has no preference setter, synchronize, private controller,
// notification, assertion, application launch or executable mutation path.

enum PlanError: Error { case unsupportedValue, changedSincePlan, failedTest(String) }

struct StoredPreference: Codable, Equatable {
    // nil means the key is absent, not an explicit zero or a default Boolean.
    let encodedValue: Data?

    init(_ value: Any?) throws {
        encodedValue = try value.map {
            try PropertyListSerialization.data(
                fromPropertyList: ["value": $0], format: .binary, options: 0
            )
        }
    }

    func unsignedFlags() throws -> UInt64 {
        guard let encodedValue else { return 0 }
        let decoded = try PropertyListSerialization.propertyList(
            from: encodedValue, format: nil
        ) as? [String: Any]
        guard let number = decoded?["value"] as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              ["c", "s", "i", "l", "q", "C", "S", "I", "L", "Q"]
                .contains(String(cString: number.objCType)),
              let flags = UInt64(number.stringValue) else {
            throw PlanError.unsupportedValue
        }
        return flags
    }
}

enum VisibilityOverride: String, Codable, CaseIterable {
    case show, hide, systemDefault
    var setBits: UInt64 {
        switch self {
        case .show: 0x2
        case .hide: 0x8
        case .systemDefault: 0
        }
    }
}

struct NowPlayingPlan: Encodable {
    let schema = 1
    let inspectedBuild = "26A5416b"
    let domain = "com.apple.controlcenter"
    let user = "currentUser"
    let host = "currentHost"
    let key = "NowPlaying"
    let before: StoredPreference
    let proposed: StoredPreference
    let visibility: VisibilityOverride

    init(before: StoredPreference, visibility: VisibilityOverride) throws {
        self.before = before
        self.visibility = visibility
        let flags = try before.unsignedFlags()
        proposed = try StoredPreference(NSNumber(value: (flags & ~UInt64(0xA)) | visibility.setBits))
    }

    // A plan description only: no caller in this research file executes it.
    func inverseIfUnchanged(current: StoredPreference) throws -> StoredPreference {
        guard current == before || current == proposed else {
            throw PlanError.changedSincePlan
        }
        return before
    }

    var fingerprint: String {
        get throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return SHA256.hash(data: try encoder.encode(self))
                .map { String(format: "%02x", $0) }.joined()
        }
    }
}

@main
enum ValidateNowPlayingPreferencePlan {
    static func main() throws {
        var buildBytes = [CChar](repeating: 0, count: 128)
        var buildSize = buildBytes.count
        let buildRead = sysctlbyname("kern.osversion", &buildBytes, &buildSize, nil, 0)
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27,
              buildRead == 0, String(cString: buildBytes) == "26A5416b" else {
            throw PlanError.failedTest("This probe requires inspected macOS 27 build 26A5416b")
        }
        var checks = 0
        func check(_ condition: Bool, _ label: String) throws {
            guard condition else { throw PlanError.failedTest(label) }
            checks += 1
        }
        func rejects(_ label: String, _ body: () throws -> Void) throws {
            do { try body() } catch is PlanError { checks += 1; return }
            throw PlanError.failedTest(label)
        }

        let absent = try StoredPreference(nil)
        let zero = try StoredPreference(NSNumber(value: 0))
        try check(absent != zero, "Absent and explicit zero differ")
        for original in [UInt64(0), 2, 8, 10, 16, 255, 1 << 50] {
            let before = try StoredPreference(NSNumber(value: original))
            for visibility in VisibilityOverride.allCases {
                let plan = try NowPlayingPlan(before: before, visibility: visibility)
                let result = try plan.proposed.unsignedFlags()
                try check(result & ~UInt64(0xA) == original & ~UInt64(0xA), "Other flags preserved")
                try check(result & 0xA == visibility.setBits, "Exact visibility mask")
                try check(try plan.inverseIfUnchanged(current: plan.proposed) == before, "Exact stored inverse")
                try check(try plan.inverseIfUnchanged(current: before) == before, "Inverse is idempotent")
            }
        }
        let hiddenAbsent = try NowPlayingPlan(before: absent, visibility: .hide)
        let hiddenZero = try NowPlayingPlan(before: zero, visibility: .hide)
        try check(try hiddenAbsent.proposed.unsignedFlags() == 8, "Absent flags start at zero")
        try check(try hiddenAbsent.inverseIfUnchanged(current: hiddenAbsent.proposed) == absent,
                  "Inverse removes an originally absent key")
        try check(try hiddenAbsent.fingerprint != hiddenZero.fingerprint, "Fingerprint binds absence")
        let defaultPlan = try NowPlayingPlan(before: absent, visibility: .systemDefault)
        try check(defaultPlan.proposed != absent, "Setting default is not key deletion")
        for invalid: Any in [true, -1, 1.5, "8", ["flags": 8]] {
            try rejects("Reject non-unsigned-integer preference") {
                _ = try NowPlayingPlan(before: StoredPreference(invalid), visibility: .hide)
            }
        }
        try rejects("Never overwrite a later external change during restore") {
            _ = try hiddenAbsent.inverseIfUnchanged(current: StoredPreference(NSNumber(value: 24)))
        }
        FileHandle.standardError.write(Data(
            "PURE PLAN PASS checks=\(checks) preferenceWrites=0 synchronizeCalls=0\n".utf8
        ))

        guard CommandLine.arguments.dropFirst().elementsEqual(["--snapshot"]) else {
            guard CommandLine.arguments.count == 1 else {
                throw PlanError.failedTest("Only --snapshot is supported; no write mode exists")
            }
            return
        }
        var samples: [[String: Any]] = []
        for (name, host) in [("currentHost", kCFPreferencesCurrentHost), ("anyHost", kCFPreferencesAnyHost)] {
            let value = CFPreferencesCopyValue(
                "NowPlaying" as CFString, "com.apple.controlcenter" as CFString,
                kCFPreferencesCurrentUser, host
            )
            let snapshot = try StoredPreference(value)
            var sample: [String: Any] = ["host": name, "present": value != nil]
            if let encoded = snapshot.encodedValue { sample["encodedValue"] = encoded }
            if name == "currentHost" {
                do {
                    let plan = try NowPlayingPlan(before: snapshot, visibility: .hide)
                    sample["proposedFlags"] = try plan.proposed.unsignedFlags()
                    sample["fingerprint"] = try plan.fingerprint
                    sample["inverse"] = snapshot.encodedValue == nil ? "removeExactKey" : "restoreExactValue"
                    sample["planPrepared"] = true
                } catch {
                    sample["planPrepared"] = false
                    sample["failure"] = String(describing: error)
                }
            }
            samples.append(sample)
        }
        let report: [String: Any] = [
            "readOnly": true, "preferenceReads": 2, "preferenceWrites": 0,
            "synchronizeCalls": 0, "executableWritePath": false,
            "liveVisibilityValidated": false, "samples": samples,
        ]
        FileHandle.standardOutput.write(try PropertyListSerialization.data(
            fromPropertyList: report, format: .xml, options: 0
        ))
    }
}
