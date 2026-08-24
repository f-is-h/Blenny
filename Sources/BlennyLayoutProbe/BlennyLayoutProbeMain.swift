import BlennyCore
import Foundation

private enum LayoutProbeError: Error, LocalizedError {
    case invalidArguments
    case staleBackup
    case targetEntryCount(Int)
    case targetValueIsNotNumeric

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            "Invalid command arguments."
        case .staleBackup:
            "Current preferred-position state differs from the backup. Capture a fresh backup first."
        case let .targetEntryCount(count):
            "Expected exactly one preferred-position key in the target domain, found \(count)."
        case .targetValueIsNotNumeric:
            "The target preferred-position value is not numeric."
        }
    }
}

@main
enum BlennyLayoutProbeMain {
    static func main() async {
        do {
            try await run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
            Foundation.exit(1)
        }
    }

    private static func run(arguments: [String]) async throws {
        guard let command = arguments.first else {
            printUsage()
            return
        }

        switch command {
        case "snapshot":
            guard arguments.count >= 2 else { return printUsage() }
            let additionalDomains = try parseAdditionalDomains(Array(arguments.dropFirst(2)))
            let domains = MacOS27PreferredPositionReader.supportedDomains + additionalDomains
            let snapshot = try await MacOS27PreferredPositionReader().capture(domains: domains)
            let destination = URL(fileURLWithPath: arguments[1])
            try encode(snapshot).write(
                to: destination,
                options: .atomic
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: destination.path
            )
            printSummary(
                action: "snapshot",
                entryCount: snapshot.entries.count,
                fingerprint: snapshot.fingerprint
            )

        case "preview-restore":
            guard arguments.count == 2 else { return printUsage() }
            let backup = try decodeSnapshot(at: arguments[1])
            let current = try await MacOS27PreferredPositionReader().capture(domains: backup.domains)
            let plan = try PreferredPositionRestorePlan.make(backup: backup, current: current)
            print("action=preview-restore")
            print("backupFingerprint=\(plan.backupFingerprint)")
            print("currentFingerprint=\(plan.currentFingerprint)")
            print("setOperations=\(plan.setOperationCount)")
            print("removeOperations=\(plan.removeOperationCount)")

        case "preview-set":
            guard arguments.count == 6,
                  arguments[2] == "--domain",
                  arguments[4] == "--position",
                  let proposedPosition = Double(arguments[5]) else {
                return printUsage()
            }
            let backup = try decodeSnapshot(at: arguments[1])
            let current = try await MacOS27PreferredPositionReader().capture(domains: backup.domains)
            guard current.fingerprint == backup.fingerprint else {
                throw LayoutProbeError.staleBackup
            }
            let proposal = try makeProposal(
                current: current,
                domain: arguments[3],
                position: proposedPosition
            )
            print("action=preview-set")
            print("backupFingerprint=\(backup.fingerprint)")
            print("currentFingerprint=\(current.fingerprint)")
            print("proposedFingerprint=\(proposal.snapshot.fingerprint)")
            print("targetDomain=\(arguments[3])")
            print("currentPosition=\(proposal.currentPosition)")
            print("proposedPosition=\(proposedPosition)")
            print("operations=1")
            print("warning=unsupported macOS 27 behavior; no state was written")

        #if DEBUG
        case "apply-set":
            guard arguments.count == 10,
                  arguments[2] == "--domain",
                  arguments[4] == "--position",
                  let proposedPosition = Double(arguments[5]),
                  arguments[6] == "--confirm-backup",
                  arguments[8] == "--confirm-proposed" else {
                return printUsage()
            }
            let backup = try decodeSnapshot(at: arguments[1])
            let proposal = try makeProposal(
                current: backup,
                domain: arguments[3],
                position: proposedPosition
            )
            FileHandle.standardError.write(Data(
                "WARNING: unsupported macOS 27 experiment; applying one preferred-position value.\n".utf8
            ))
            let verification = try await ExperimentalMacOS27PreferredPositionWriter.shared.apply(
                baseline: backup,
                proposed: proposal.snapshot,
                confirmedBaselineFingerprint: arguments[7],
                confirmedProposedFingerprint: arguments[9]
            )
            printSummary(
                action: "apply-set-verified",
                entryCount: verification.entries.count,
                fingerprint: verification.fingerprint
            )

        case "restore":
            guard arguments.count == 6,
                  arguments[2] == "--confirm-backup",
                  arguments[4] == "--confirm-current" else {
                return printUsage()
            }
            FileHandle.standardError.write(Data(
                "WARNING: unsupported macOS 27 experiment; restoring preferred-position state.\n".utf8
            ))
            let backup = try decodeSnapshot(at: arguments[1])
            let verification = try await ExperimentalMacOS27PreferredPositionWriter.shared.restore(
                backup: backup,
                confirmedBackupFingerprint: arguments[3],
                confirmedCurrentFingerprint: arguments[5]
            )
            printSummary(
                action: "restore-verified",
                entryCount: verification.entries.count,
                fingerprint: verification.fingerprint
            )
        #endif

        default:
            printUsage()
        }
    }

    private static func encode(_ snapshot: PreferredPositionSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(snapshot)
    }

    private static func decodeSnapshot(at path: String) throws -> PreferredPositionSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(
            PreferredPositionSnapshot.self,
            from: Data(contentsOf: URL(fileURLWithPath: path))
        )
        try snapshot.validateFingerprint()
        return snapshot
    }

    private static func printSummary(action: String, entryCount: Int, fingerprint: String) {
        print("action=\(action)")
        print("entryCount=\(entryCount)")
        print("fingerprint=\(fingerprint)")
    }

    private static func parseAdditionalDomains(_ arguments: [String]) throws -> [String] {
        guard arguments.count.isMultiple(of: 2) else {
            throw LayoutProbeError.invalidArguments
        }
        var domains: [String] = []
        for index in stride(from: 0, to: arguments.count, by: 2) {
            guard arguments[index] == "--include-domain",
                  !arguments[index + 1].isEmpty else {
                throw LayoutProbeError.invalidArguments
            }
            domains.append(arguments[index + 1])
        }
        return domains
    }

    private static func makeProposal(
        current: PreferredPositionSnapshot,
        domain: String,
        position: Double
    ) throws -> (snapshot: PreferredPositionSnapshot, currentPosition: Double) {
        let matches = current.entries.filter { $0.domain == domain }
        guard matches.count == 1, let entry = matches.first else {
            throw LayoutProbeError.targetEntryCount(matches.count)
        }
        guard case let .number(currentPosition, numberType) = entry.value else {
            throw LayoutProbeError.targetValueIsNotNumeric
        }
        let proposedEntries = current.entries.map { candidate in
            guard candidate == entry else { return candidate }
            return PreferredPositionEntry(
                domain: candidate.domain,
                key: candidate.key,
                value: .number(
                    value: position,
                    cfNumberTypeRawValue: numberType
                )
            )
        }
        let snapshot = try PreferredPositionSnapshot(
            environment: current.environment,
            domains: current.domains,
            entries: proposedEntries
        )
        return (snapshot, currentPosition)
    }

    private static func printUsage() {
        print("Usage:")
        print("  BlennyLayoutProbe snapshot <backup.json> [--include-domain <bundle-id>]…")
        print("  BlennyLayoutProbe preview-restore <backup.json>")
        print("  BlennyLayoutProbe preview-set <backup.json> --domain <bundle-id> --position <number>")
        #if DEBUG
        print("  BlennyLayoutProbe apply-set <backup.json> --domain <bundle-id> --position <number> --confirm-backup <hash> --confirm-proposed <hash>")
        print("  BlennyLayoutProbe restore <backup.json> --confirm-backup <hash> --confirm-current <hash>")
        #endif
    }
}
