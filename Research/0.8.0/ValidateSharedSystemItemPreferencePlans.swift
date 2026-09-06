import CryptoKit
import Darwin
import Foundation

// Unsupported macOS 27 research, excluded from all product targets.
// This file contains pure proposed-state/inverse checks and one optional bounded
// snapshot mode. It has no preference setter, synchronize, notification,
// private-controller, assertion, application-launch, or executable write path.

private enum SharedItemPlanError: Error {
    case unsupportedRuntime
    case unsupportedValue
    case unsafeBaseline
    case changedSincePlan
    case failedTest(String)
}

private struct ExactPreferenceValue: Codable, Equatable {
    // nil is exact stored absence, not a default value.
    let encodedValue: Data?

    init(_ value: Any?) throws {
        encodedValue = try value.map {
            try PropertyListSerialization.data(
                fromPropertyList: ["value": $0], format: .binary, options: 0
            )
        }
    }

    func optionalBoolean() throws -> Bool? {
        guard let value = try decodedValue() else { return nil }
        guard let number = value as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else {
            throw SharedItemPlanError.unsupportedValue
        }
        return number.boolValue
    }

    func stringArray() throws -> [String] {
        guard let value = try decodedValue() else { return [] }
        guard let values = value as? [String], values.count <= 256,
              Set(values).count == values.count,
              values.allSatisfy({ !$0.isEmpty && $0.count <= 1_024 }) else {
            throw SharedItemPlanError.unsupportedValue
        }
        return values
    }

    private func decodedValue() throws -> Any? {
        guard let encodedValue else { return nil }
        guard let decoded = try PropertyListSerialization.propertyList(
            from: encodedValue, format: nil
        ) as? [String: Any], decoded.count == 1 else {
            throw SharedItemPlanError.unsupportedValue
        }
        return decoded["value"]
    }
}

private struct SiriPreferenceState: Codable, Equatable {
    let statusMenuVisible: ExactPreferenceValue
    let stashedStatusMenuVisible: ExactPreferenceValue

    init(statusMenuVisible: Any?, stashedStatusMenuVisible: Any?) throws {
        self.statusMenuVisible = try ExactPreferenceValue(statusMenuVisible)
        self.stashedStatusMenuVisible = try ExactPreferenceValue(stashedStatusMenuVisible)
        _ = try self.statusMenuVisible.optionalBoolean()
        _ = try self.stashedStatusMenuVisible.optionalBoolean()
    }
}

private struct SiriVisibilityPlan: Encodable {
    let schema = 1
    let inspectedBuild = "26A5425a"
    let domain = "com.apple.Siri"
    let user = "currentUser"
    let host = "anyHost"
    let before: SiriPreferenceState
    let proposed: SiriPreferenceState
    let show: Bool

    init(before: SiriPreferenceState, show: Bool) throws {
        self.before = before
        self.show = show
        proposed = try SiriPreferenceState(
            statusMenuVisible: NSNumber(value: show),
            stashedStatusMenuVisible: nil
        )
    }

    func inverseIfUnchanged(current: SiriPreferenceState) throws -> SiriPreferenceState {
        guard current == before || current == proposed else {
            throw SharedItemPlanError.changedSincePlan
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

private struct TimeMachinePreferenceState: Codable, Equatable {
    let menuExtras: ExactPreferenceValue
    let statusItemVisibleCC: ExactPreferenceValue
    let preferredPosition: ExactPreferenceValue
}

private struct TimeMachineHidePlan: Encodable {
    static let menuExtraPath = "/System/Library/CoreServices/Menu Extras/TimeMachine.menu"

    let schema = 1
    let inspectedBuild = "26A5425a"
    let domain = "com.apple.systemuiserver"
    let user = "currentUser"
    let host = "anyHost"
    let before: TimeMachinePreferenceState
    let proposedMenuExtras: ExactPreferenceValue

    init(before: TimeMachinePreferenceState) throws {
        let entries = try before.menuExtras.stringArray()
        guard entries.filter({ $0 == Self.menuExtraPath }).count == 1 else {
            throw SharedItemPlanError.unsafeBaseline
        }
        proposedMenuExtras = try ExactPreferenceValue(
            entries.filter { $0 != Self.menuExtraPath }
        )
        self.before = before
    }

    func inverseIfUnchanged(currentMenuExtras: ExactPreferenceValue) throws
        -> TimeMachinePreferenceState {
        guard currentMenuExtras == before.menuExtras || currentMenuExtras == proposedMenuExtras else {
            throw SharedItemPlanError.changedSincePlan
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
private enum ValidateSharedSystemItemPreferencePlans {
    static func main() throws {
        var buildBytes = [CChar](repeating: 0, count: 128)
        var buildSize = buildBytes.count
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27,
              sysctlbyname("kern.osversion", &buildBytes, &buildSize, nil, 0) == 0,
              String(cString: buildBytes) == "26A5425a" else {
            throw SharedItemPlanError.unsupportedRuntime
        }

        var checks = 0
        func check(_ condition: Bool, _ label: String) throws {
            guard condition else { throw SharedItemPlanError.failedTest(label) }
            checks += 1
        }
        func rejects(_ label: String, _ body: () throws -> Void) throws {
            do { try body() } catch is SharedItemPlanError { checks += 1; return }
            throw SharedItemPlanError.failedTest(label)
        }

        let siriBefore = try SiriPreferenceState(
            statusMenuVisible: true,
            stashedStatusMenuVisible: false
        )
        let siriHide = try SiriVisibilityPlan(before: siriBefore, show: false)
        try check(try siriHide.proposed.statusMenuVisible.optionalBoolean() == false,
                  "Siri hide writes exact false")
        try check(siriHide.proposed.stashedStatusMenuVisible.encodedValue == nil,
                  "Siri setter semantics remove stash")
        try check(try siriHide.inverseIfUnchanged(current: siriHide.proposed) == siriBefore,
                  "Siri inverse restores both exact keys")
        try check(try siriHide.inverseIfUnchanged(current: siriBefore) == siriBefore,
                  "Siri inverse is idempotent")
        let absentSiri = try SiriPreferenceState(
            statusMenuVisible: nil,
            stashedStatusMenuVisible: nil
        )
        let absentSiriHide = try SiriVisibilityPlan(before: absentSiri, show: false)
        try check(try absentSiriHide.inverseIfUnchanged(current: absentSiriHide.proposed) == absentSiri,
                  "Siri inverse preserves original absence")
        try check(try siriHide.fingerprint != absentSiriHide.fingerprint,
                  "Siri fingerprint binds absence and stash")
        try rejects("Siri rejects a non-Boolean status value") {
            _ = try SiriPreferenceState(statusMenuVisible: 1, stashedStatusMenuVisible: nil)
        }
        try rejects("Siri restore rejects an intervening change") {
            _ = try siriHide.inverseIfUnchanged(current: SiriPreferenceState(
                statusMenuVisible: true, stashedStatusMenuVisible: true
            ))
        }

        let path = TimeMachineHidePlan.menuExtraPath
        let timeMachineBefore = TimeMachinePreferenceState(
            menuExtras: try ExactPreferenceValue(["first.menu", path, "last.menu"]),
            statusItemVisibleCC: try ExactPreferenceValue(true),
            preferredPosition: try ExactPreferenceValue(NSNumber(value: 86))
        )
        let timeMachineHide = try TimeMachineHidePlan(before: timeMachineBefore)
        try check(try timeMachineHide.proposedMenuExtras.stringArray() == ["first.menu", "last.menu"],
                  "Time Machine hide removes only the exact path and preserves order")
        try check(try timeMachineHide.inverseIfUnchanged(
            currentMenuExtras: timeMachineHide.proposedMenuExtras
        ) == timeMachineBefore, "Time Machine inverse restores the complete exact state")
        try check(try timeMachineHide.inverseIfUnchanged(
            currentMenuExtras: timeMachineBefore.menuExtras
        ) == timeMachineBefore, "Time Machine inverse is idempotent")
        try rejects("Time Machine requires exactly one target entry") {
            _ = try TimeMachineHidePlan(before: TimeMachinePreferenceState(
                menuExtras: try ExactPreferenceValue(["first.menu"]),
                statusItemVisibleCC: try ExactPreferenceValue(true),
                preferredPosition: try ExactPreferenceValue(86)
            ))
        }
        try rejects("Time Machine rejects duplicate menu-extra entries") {
            _ = try TimeMachineHidePlan(before: TimeMachinePreferenceState(
                menuExtras: try ExactPreferenceValue([path, path]),
                statusItemVisibleCC: try ExactPreferenceValue(true),
                preferredPosition: try ExactPreferenceValue(86)
            ))
        }
        try rejects("Time Machine restore rejects an intervening array change") {
            _ = try timeMachineHide.inverseIfUnchanged(
                currentMenuExtras: ExactPreferenceValue([path, "external.menu"])
            )
        }
        try check(try timeMachineHide.fingerprint.count == 64,
                  "Time Machine plan has a stable SHA-256 identity")

        FileHandle.standardError.write(Data(
            "PURE PLAN PASS checks=\(checks) preferenceWrites=0 synchronizeCalls=0 notifications=0\n".utf8
        ))

        guard CommandLine.arguments.dropFirst().elementsEqual(["--snapshot"]) else {
            guard CommandLine.arguments.count == 1 else {
                throw SharedItemPlanError.failedTest("Only --snapshot is supported; no write mode exists")
            }
            return
        }

        func copy(_ domain: String, _ key: String) -> Any? {
            CFPreferencesCopyValue(
                key as CFString, domain as CFString,
                kCFPreferencesCurrentUser, kCFPreferencesAnyHost
            )
        }
        let siri = try SiriPreferenceState(
            statusMenuVisible: copy("com.apple.Siri", "StatusMenuVisible"),
            stashedStatusMenuVisible: copy("com.apple.Siri", "SiriPrefStashedStatusMenuVisible")
        )
        let timeMachine = TimeMachinePreferenceState(
            menuExtras: try ExactPreferenceValue(copy("com.apple.systemuiserver", "menuExtras")),
            statusItemVisibleCC: try ExactPreferenceValue(copy(
                "com.apple.systemuiserver", "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine"
            )),
            preferredPosition: try ExactPreferenceValue(copy(
                "com.apple.systemuiserver", "NSStatusItem Preferred Position com.apple.menuextra.TimeMachine"
            ))
        )
        let siriPlan = try SiriVisibilityPlan(before: siri, show: false)
        let timeMachinePlan = try TimeMachineHidePlan(before: timeMachine)
        let report: [String: Any] = [
            "readOnly": true,
            "preferenceReads": 5,
            "preferenceWrites": 0,
            "synchronizeCalls": 0,
            "notifications": 0,
            "executableWritePath": false,
            "siriHideFingerprint": try siriPlan.fingerprint,
            "timeMachineHideFingerprint": try timeMachinePlan.fingerprint,
            "siriState": try JSONEncoder().encode(siri),
            "timeMachineState": try JSONEncoder().encode(timeMachine),
        ]
        FileHandle.standardOutput.write(try PropertyListSerialization.data(
            fromPropertyList: report, format: .xml, options: 0
        ))
    }
}
