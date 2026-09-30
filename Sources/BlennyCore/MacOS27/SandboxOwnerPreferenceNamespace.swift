#if BLENNY_PRODUCT || DEBUG
import CryptoKit
import Foundation

/// Pure validation for the only sandbox preference namespace accepted by the
/// ordering trial. Runtime callers still have to obtain every filesystem fact
/// with descriptor-relative, no-follow reads.
struct SandboxOwnerPreferenceSourceEvidence: Equatable, Sendable {
    let bundleIdentifier: String
    let signingIdentifier: String
    let homeDirectoryPath: String
    let containerRootPath: String
    let dataDirectoryPath: String
    let metadataIdentifier: String
    let rootDevice: UInt64
    let rootInode: UInt64
    let dataDevice: UInt64
    let dataInode: UInt64
    let metadataDevice: UInt64
    let metadataInode: UInt64
    let metadataDigest: String
}

enum SandboxOwnerPreferenceNamespaceValidator {
    static func sourceIdentity(
        for evidence: SandboxOwnerPreferenceSourceEvidence
    ) -> String? {
        guard validBundleComponent(evidence.bundleIdentifier),
              evidence.signingIdentifier == evidence.bundleIdentifier,
              evidence.metadataIdentifier == evidence.bundleIdentifier,
              validCanonicalHome(evidence.homeDirectoryPath) else { return nil }

        let expectedRoot = evidence.homeDirectoryPath
            + "/Library/Containers/" + evidence.bundleIdentifier
        guard evidence.containerRootPath == expectedRoot,
              evidence.dataDirectoryPath == expectedRoot + "/Data",
              evidence.rootDevice > 0, evidence.rootInode > 0,
              evidence.dataDevice > 0, evidence.dataInode > 0,
              evidence.metadataDevice > 0, evidence.metadataInode > 0,
              isLowercaseSHA256(evidence.metadataDigest) else { return nil }

        let fields = [
            evidence.bundleIdentifier,
            evidence.signingIdentifier,
            evidence.homeDirectoryPath,
            evidence.containerRootPath,
            String(evidence.rootDevice),
            String(evidence.rootInode),
            evidence.dataDirectoryPath,
            String(evidence.dataDevice),
            String(evidence.dataInode),
            evidence.metadataIdentifier,
            String(evidence.metadataDevice),
            String(evidence.metadataInode),
            evidence.metadataDigest,
        ]
        let canonical = fields.map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
        return SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    static func validBundleComponent(_ value: String) -> Bool {
        guard !value.isEmpty, value != ".", value != "..", value.utf8.count <= 1_024,
              !value.contains("/") else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            scalar.value >= 32 && scalar.value != 127
        }
    }

    private static func validCanonicalHome(_ path: String) -> Bool {
        guard path.hasPrefix("/"), path != "/", !path.hasSuffix("/"),
              path.utf8.count <= 4_096,
              path.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) else {
            return false
        }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard components.first?.isEmpty == true else { return false }
        return components.dropFirst().allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    private static func isLowercaseSHA256(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy {
            ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102)
        }
    }
}
#endif
