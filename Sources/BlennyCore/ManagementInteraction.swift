import Foundation

/// Main-actor callers acquire this gate before any asynchronous preparation.
public struct ManagementInteractionGate: Sendable {
    public private(set) var isBusy = false
    public private(set) var isTerminating = false

    public init() {}

    public mutating func begin() -> Bool {
        guard !isBusy, !isTerminating else { return false }
        isBusy = true
        return true
    }

    public mutating func finish() { isBusy = false }
    public mutating func terminate() { isTerminating = true }
}

public struct ManagementStatusPresentation: Equatable, Sendable {
    public let arrowSymbolName: String?
    public let canToggleReveal: Bool
    public let accessibilityLabel: String
    public let showsInlineArrow: Bool
    public static let arrowPointSize = 13.0
    // Native item identity stays stable even while management is unavailable.
    public var nativeArrowSymbolName: String { arrowSymbolName ?? "chevron.right.2" }
    public var nativeArrowHelp: String {
        arrowSymbolName == nil
            ? "Blenny reveal is unavailable — open Blenny to check management."
            : accessibilityLabel
    }

    public init(
        state: ManagementLoopState, hasRevealableBundles: Bool, isBusy: Bool,
        nativeOverflow: NativeOverflowObservationSnapshot = .unavailable
    ) {
        switch state {
        case .active where hasRevealableBundles:
            arrowSymbolName = "chevron.right.2"
            accessibilityLabel = "Blenny — Reveal Revealable menu bar items"
        case .ordinaryRevealSession where hasRevealableBundles:
            arrowSymbolName = "chevron.left.2"
            accessibilityLabel = "Blenny — Conceal Revealable menu bar items"
        default:
            arrowSymbolName = nil
            accessibilityLabel = "Blenny — Open menu"
        }
        canToggleReveal = arrowSymbolName != nil && !isBusy
        // Presence alone is insufficient: a known, single, registered control
        // is required. Only the fallback button's presentation is hidden; the
        // explicit action in Blenny's safety menu stays available.
        showsInlineArrow = !nativeOverflow.isUsable
    }

    public func opensMenu(isSecondaryClick: Bool) -> Bool {
        isSecondaryClick || !canToggleReveal
    }
}

/// Bounded process-local diagnostics. Durable recovery belongs to the policy
/// store's atomic transaction marker and scoped backup, not this journal.
public struct PolicyActionAuditTrail: Sendable {
    public enum Action: String, Sendable { case apply, resume, stop, restore }
    public enum Phase: String, Sendable { case preparing, prepared, committed, unchanged, failed }
    public struct Entry: Equatable, Sendable {
        public let action: Action
        public let phase: Phase
        public let bindingFingerprint: String?
        public let baselineFingerprint: String?
        public let failureStage: PolicyEditingTransactionStage?
        public let systemState: PolicyEditingSystemState?
    }
    public private(set) var entries: [Entry] = []
    public init() {}

    public mutating func record(
        _ action: Action,
        phase: Phase,
        prepared: PreparedPolicyEdit? = nil,
        failure: PolicyEditingTransactionFailure? = nil
    ) {
        entries.append(Entry(
            action: action,
            phase: phase,
            bindingFingerprint: prepared?.reviewBinding.fingerprint,
            baselineFingerprint: prepared?.report.newBaselinePlan?.fingerprint,
            failureStage: failure?.stage,
            systemState: failure?.systemState
        ))
        if entries.count > 32 { entries.removeFirst(entries.count - 32) }
    }
}
