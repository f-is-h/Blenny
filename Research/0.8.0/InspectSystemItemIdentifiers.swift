import Foundation

// This read-only probe links the private macOS 27 framework only in an excluded
// Research target. It does not create a visibility assertion or contact a
// MenuBarAgent service.

private struct SystemItemIdentifierStorage {
    let bits: UInt64
}

@_silgen_name("$s17MenuBarClientCore22MBSystemItemIdentifierO8allCasesSayACGvgZ")
private func allSystemItemIdentifiers() -> [SystemItemIdentifierStorage]

@_silgen_name("$s17MenuBarClientCore22MBSystemItemIdentifierO8rawValueSivg")
private func rawValue(_ identifier: SystemItemIdentifierStorage) -> Int

@_silgen_name("$s17MenuBarClientCore22MBSystemItemIdentifierO11stringValueSSvg")
private func stringValue(_ identifier: SystemItemIdentifierStorage) -> String

for identifier in allSystemItemIdentifiers() {
    print("\(rawValue(identifier))\t\(stringValue(identifier))")
}
