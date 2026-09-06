import Foundation

// Unsupported, macOS-27-only research, excluded from every product target.
// Reads only statically identified keys through public CFPreferences readers.
// No private object construction, synchronize, mutation, notification, assertion,
// app launch, or UI restart. Output is raw local evidence: keep it in LocalData.
guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 else {
    fatalError("This probe is limited to the inspected macOS 27 preference model.")
}

let targets = [
    ("com.apple.controlcenter", "NowPlaying"),
    ("com.apple.Siri", "StatusMenuVisible"),
    ("com.apple.Siri", "SiriPrefStashedStatusMenuVisible"),
]
let hosts: [(String, CFString)] = [
    ("currentHost", kCFPreferencesCurrentHost),
    ("anyHost", kCFPreferencesAnyHost),
]
var samples: [[String: Any]] = []
for (domain, key) in targets {
    for (hostName, host) in hosts {
        let value = CFPreferencesCopyValue(
            key as CFString, domain as CFString, kCFPreferencesCurrentUser, host
        )
        var sample: [String: Any] = [
            "domain": domain, "key": key, "user": "currentUser", "host": hostName,
            "present": value != nil,
        ]
        if let value { sample["storedValue"] = value }
        samples.append(sample)
    }
}
let data = try PropertyListSerialization.data(
    fromPropertyList: ["readOnly": true, "samples": samples], format: .xml, options: 0
)
FileHandle.standardOutput.write(data)
