#if DEBUG
import AppKit
import BlennyCore
import Foundation

struct DebugOwnControlEvidence: Codable, Equatable {
    let role: String
    let autosaveName: String?
    let length: Double
    let frame: RectSnapshot?
    let localContentVisible: Bool
    let enabled: Bool

    @MainActor init(role: String, item: NSStatusItem) {
        self.role = role
        autosaveName = item.autosaveName
        length = Double(item.length)
        frame = item.button?.window?.frame.mapToBoundaryRect
        localContentVisible = item.isVisible && item.button?.isHidden == false
        enabled = item.button?.isEnabled == true
    }
}

private extension NSRect {
    var mapToBoundaryRect: RectSnapshot {
        RectSnapshot(x: Double(minX), y: Double(minY),
            width: Double(width), height: Double(height))
    }
}

/// Raw, local evidence only. No field is a write authorization or a placement
/// proposal. Sequential captures retain timestamps and explicit coherence limits.
struct DebugBoundaryEvidence: Encodable {
    let schemaVersion = 1
    let id: UUID
    let startedAt: Date
    let finishedAt: Date
    let appVersion: String
    let appPath: String
    let executableSHA256: String
    let processIdentifier: Int32
    let stateBefore: String
    let stateAfter: String
    let contextUnchanged: Bool
    let ownControlsBefore: [DebugOwnControlEvidence]
    let ownControlsAfter: [DebugOwnControlEvidence]
    let ownKeyEvidence: OwnControlKeyEvidence
    let clickCheck: NativeControlClickCheck
    let acceptedPolicy: PersistentBundlePolicyDocument
    let inventory: DiagnosticReport
    let ordering: OrderingSnapshot
    let singleItemCandidates: [OrderingBundleCandidate]
    let notes: [String]
}
#endif
