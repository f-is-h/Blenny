import CoreTransferable
import Foundation
import UniformTypeIdentifiers

public extension UTType {
    static let blennyPolicyBundleDrag = UTType(
        exportedAs: "xyz.fi5h.blenny.policy-bundle-drag",
        conformingTo: .data
    )
}

public struct PolicyDragPayload:
    Codable,
    Equatable,
    Hashable,
    Identifiable,
    Sendable,
    Transferable
{
    public struct ID: Codable, Equatable, Hashable, Sendable {
        public let bundleIdentifier: String
        public let sourcePolicy: MenuBarBundlePolicy
        public let candidateGeneration: UUID
        public let dragToken: UUID

        public init(
            bundleIdentifier: String,
            sourcePolicy: MenuBarBundlePolicy,
            candidateGeneration: UUID,
            dragToken: UUID
        ) {
            self.bundleIdentifier = bundleIdentifier
            self.sourcePolicy = sourcePolicy
            self.candidateGeneration = candidateGeneration
            self.dragToken = dragToken
        }
    }

    public let bundleIdentifier: String
    public let sourcePolicy: MenuBarBundlePolicy
    public let candidateGeneration: UUID
    public let dragToken: UUID

    public init(
        bundleIdentifier: String,
        sourcePolicy: MenuBarBundlePolicy,
        candidateGeneration: UUID,
        dragToken: UUID = UUID()
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.sourcePolicy = sourcePolicy
        self.candidateGeneration = candidateGeneration
        self.dragToken = dragToken
    }

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .blennyPolicyBundleDrag)
            .visibility(.ownProcess)
    }

    public var id: ID {
        ID(
            bundleIdentifier: bundleIdentifier,
            sourcePolicy: sourcePolicy,
            candidateGeneration: candidateGeneration,
            dragToken: dragToken
        )
    }
}

/// Typed delivery can follow native cleanup. Missing terminal metadata is not
/// a conflict; any still-present native or payload identity must agree. The
/// coordinator separately validates the delivered token and current generation.
public enum PolicyDragDelivery {
    public static func matches(
        delivered: PolicyDragPayload.ID,
        reported: PolicyDragPayload.ID?,
        active: PolicyDragPayload.ID?,
        nativeSessionMatches: Bool?
    ) -> Bool {
        if nativeSessionMatches == false { return false }
        if let reported, reported != delivered { return false }
        if let active, active != delivered { return false }
        return true
    }
}

public enum PolicyDragDeliveryRegistration: Equatable, Sendable {
    case first
    case duplicate
    case conflictingPayload
}

/// Remembers the one typed payload already handled for the latest native drop
/// session. Repeated delivery from that session is idempotent, while a new
/// native session remains independent even when it drags the same subject.
public struct PolicyDragDeliveryReceipt<SessionID: Hashable>: Equatable {
    public private(set) var sessionID: SessionID?
    public private(set) var payloadID: PolicyDragPayload.ID?

    public init() {}

    public func contains(
        sessionID: SessionID,
        payloadID: PolicyDragPayload.ID
    ) -> Bool {
        self.sessionID == sessionID && self.payloadID == payloadID
    }

    public mutating func register(
        sessionID: SessionID,
        payloadID: PolicyDragPayload.ID
    ) -> PolicyDragDeliveryRegistration {
        guard self.sessionID == sessionID else {
            self.sessionID = sessionID
            self.payloadID = payloadID
            return .first
        }
        return self.payloadID == payloadID ? .duplicate : .conflictingPayload
    }
}

public enum PolicyDraftAssignmentRejection: String, Equatable, Sendable {
    case duplicateDelivery
    case staleCandidateGeneration
    case staleSourcePolicy
    case samePolicy
    case blennyMustRemainVisible
    case unknownCandidate
    case interactionInProgress

    public var interfaceReason: String {
        switch self {
        case .interactionInProgress:
            "Wait for the current operation to finish."
        case .duplicateDelivery:
            "This drop was already handled."
        case .staleCandidateGeneration:
            "Refresh changed the available items. Start a new drag."
        case .staleSourcePolicy:
            "This item moved after the drag began. Start a new drag."
        case .samePolicy:
            "This item is already in this group."
        case .blennyMustRemainVisible:
            "Blenny must remain Visible."
        case .unknownCandidate:
            "This item is no longer available in the current observation."
        }
    }
}

public enum PolicyDraftAssignmentOutcome: Equatable, Sendable {
    case changed
    case rejected(PolicyDraftAssignmentRejection)

    public var changedDraft: Bool { self == .changed }
}

public struct PolicyDraftAssignmentCoordinator: Equatable, Sendable {
    public private(set) var candidateGeneration: UUID
    public private(set) var consumedDragTokens: Set<UUID>

    public init(
        candidateGeneration: UUID = UUID(),
        consumedDragTokens: Set<UUID> = []
    ) {
        self.candidateGeneration = candidateGeneration
        self.consumedDragTokens = consumedDragTokens
    }

    public mutating func replaceCandidateGeneration(with generation: UUID = UUID()) {
        candidateGeneration = generation
        consumedDragTokens.removeAll(keepingCapacity: true)
    }

    public func validate(
        payload: PolicyDragPayload,
        destination: MenuBarBundlePolicy,
        editor: PolicyEditorViewModel
    ) -> PolicyDraftAssignmentOutcome {
        if consumedDragTokens.contains(payload.dragToken) {
            return .rejected(.duplicateDelivery)
        }
        guard payload.candidateGeneration == candidateGeneration else {
            return .rejected(.staleCandidateGeneration)
        }
        let isSystemItem = SystemItemPolicyCatalog.controllableItem(
            for: payload.bundleIdentifier
        ) != nil || PersistentSystemItemPolicyCatalog.controllableItem(
            for: payload.bundleIdentifier
        ) != nil
        let effectivePolicy = isSystemItem
            ? editor.effectiveSystemItemPolicy(for: payload.bundleIdentifier)
            : editor.effectivePolicy(for: payload.bundleIdentifier)
        guard effectivePolicy != nil else {
            return .rejected(.unknownCandidate)
        }
        if !isSystemItem,
           BundlePolicyIdentity.canonicalKey(for: payload.bundleIdentifier)
            == BundlePolicyIdentity.canonicalKey(for: editor.blennyBundleIdentifier),
           destination != .visible {
            return .rejected(.blennyMustRemainVisible)
        }
        guard effectivePolicy == payload.sourcePolicy else {
            return .rejected(.staleSourcePolicy)
        }
        guard payload.sourcePolicy != destination else {
            return .rejected(.samePolicy)
        }
        return .changed
    }

    @discardableResult
    public mutating func assign(
        payload: PolicyDragPayload,
        destination: MenuBarBundlePolicy,
        editor: inout PolicyEditorViewModel
    ) -> PolicyDraftAssignmentOutcome {
        let validation = validate(
            payload: payload,
            destination: destination,
            editor: editor
        )
        guard validation == .changed else { return validation }

        let assignment = SystemItemPolicyCatalog.controllableItem(
            for: payload.bundleIdentifier
        ) != nil || PersistentSystemItemPolicyCatalog.controllableItem(
            for: payload.bundleIdentifier
        ) != nil
            ? editor.assignSystemItem(identifier: payload.bundleIdentifier, to: destination)
            : editor.assign(bundleIdentifier: payload.bundleIdentifier, to: destination)
        switch assignment {
        case .changed:
            consumedDragTokens.insert(payload.dragToken)
            return .changed
        case .unchanged:
            return .rejected(.samePolicy)
        case .rejectedBlennyMustRemainVisible:
            return .rejected(.blennyMustRemainVisible)
        case .unknownCandidate:
            return .rejected(.unknownCandidate)
        }
    }

    @discardableResult
    public mutating func assign(
        bundleIdentifier: String,
        destination: MenuBarBundlePolicy,
        editor: inout PolicyEditorViewModel,
        commandToken: UUID = UUID()
    ) -> PolicyDraftAssignmentOutcome {
        guard let source = editor.effectivePolicy(for: bundleIdentifier) else {
            return .rejected(.unknownCandidate)
        }
        return assign(
            payload: PolicyDragPayload(
                bundleIdentifier: bundleIdentifier,
                sourcePolicy: source,
                candidateGeneration: candidateGeneration,
                dragToken: commandToken
            ),
            destination: destination,
            editor: &editor
        )
    }
}

public enum PolicyBoardItemID: Equatable, Hashable, Sendable {
    case application(String)
    case systemItem(String)
}

public struct PolicyBoardDropTarget: Equatable, Sendable {
    public let policy: MenuBarBundlePolicy
    public let rejection: PolicyDraftAssignmentRejection?

    public init(
        policy: MenuBarBundlePolicy,
        rejection: PolicyDraftAssignmentRejection?
    ) {
        self.policy = policy
        self.rejection = rejection
    }

    public var isValid: Bool { rejection == nil }
}

public enum PolicyBoardLandingProjection {
    /// Returns the visual landing index produced by Blenny's existing stable
    /// bundle-identifier ordering. This is destination feedback only; it does
    /// not introduce user-controlled ordering within a policy lane.
    public static func automaticIndex(
        for bundleIdentifier: String,
        among existingBundleIdentifiers: [String]
    ) -> Int {
        let draggedKey = sortKey(bundleIdentifier)
        return existingBundleIdentifiers.firstIndex {
            draggedKey < sortKey($0)
        } ?? existingBundleIdentifiers.endIndex
    }

    private static func sortKey(_ bundleIdentifier: String) -> (String, String) {
        (bundleIdentifier.lowercased(), bundleIdentifier)
    }
}

public struct PolicyBoardSettleState: Equatable, Sendable {
    public let bundleIdentifier: String
    public let destination: MenuBarBundlePolicy
    public let token: UUID

    public init(
        bundleIdentifier: String,
        destination: MenuBarBundlePolicy,
        token: UUID
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.destination = destination
        self.token = token
    }
}

public struct PolicyBoardInteractionState: Equatable, Sendable {
    public private(set) var selectedItem: PolicyBoardItemID?
    public private(set) var hoveredItem: PolicyBoardItemID?
    public private(set) var focusedItem: PolicyBoardItemID?
    public private(set) var draggedBundleIdentifier: String?
    public private(set) var draggedSourcePolicy: MenuBarBundlePolicy?
    public private(set) var dropTarget: PolicyBoardDropTarget?
    public private(set) var settleState: PolicyBoardSettleState?

    public init(
        selectedItem: PolicyBoardItemID? = nil,
        hoveredItem: PolicyBoardItemID? = nil,
        focusedItem: PolicyBoardItemID? = nil,
        draggedBundleIdentifier: String? = nil,
        draggedSourcePolicy: MenuBarBundlePolicy? = nil,
        dropTarget: PolicyBoardDropTarget? = nil,
        settleState: PolicyBoardSettleState? = nil
    ) {
        self.selectedItem = selectedItem
        self.hoveredItem = hoveredItem
        self.focusedItem = focusedItem
        self.draggedBundleIdentifier = draggedBundleIdentifier
        self.draggedSourcePolicy = draggedSourcePolicy
        self.dropTarget = dropTarget
        self.settleState = settleState
    }

    public var namePresentationItem: PolicyBoardItemID? {
        hoveredItem ?? focusedItem ?? selectedItem
    }

    public mutating func select(_ item: PolicyBoardItemID?) {
        selectedItem = item
    }

    public mutating func setHovered(_ item: PolicyBoardItemID?, isHovered: Bool) {
        if isHovered {
            hoveredItem = item
        } else if hoveredItem == item {
            hoveredItem = nil
        }
    }

    public mutating func setFocused(_ item: PolicyBoardItemID?, isFocused: Bool) {
        if isFocused {
            focusedItem = item
        } else if focusedItem == item {
            focusedItem = nil
        }
    }

    public mutating func beginDrag(
        bundleIdentifier: String,
        sourcePolicy: MenuBarBundlePolicy
    ) {
        draggedBundleIdentifier = bundleIdentifier
        draggedSourcePolicy = sourcePolicy
        hoveredItem = nil
        dropTarget = nil
        settleState = nil
    }

    public mutating func target(
        policy: MenuBarBundlePolicy,
        validation: PolicyDraftAssignmentOutcome
    ) {
        let rejection: PolicyDraftAssignmentRejection?
        switch validation {
        case .changed:
            rejection = nil
        case .rejected(.samePolicy):
            // Returning over the source lane is an ordinary no-op, not an
            // error that warrants destination styling or warning copy.
            dropTarget = nil
            return
        case .rejected(let reason):
            rejection = reason
        }
        dropTarget = PolicyBoardDropTarget(policy: policy, rejection: rejection)
    }

    public mutating func clearTarget(policy: MenuBarBundlePolicy? = nil) {
        guard policy == nil || dropTarget?.policy == policy else { return }
        dropTarget = nil
    }

    public mutating func completeDrop(
        payload: PolicyDragPayload,
        destination: MenuBarBundlePolicy,
        outcome: PolicyDraftAssignmentOutcome
    ) {
        draggedBundleIdentifier = nil
        draggedSourcePolicy = nil
        dropTarget = nil
        guard outcome == .changed else {
            settleState = nil
            return
        }
        selectedItem = SystemItemPolicyCatalog.controllableItem(
            for: payload.bundleIdentifier
        ) != nil || SharedSystemItemTrialTarget.matchingSystemItem(
            observationIdentifier: payload.bundleIdentifier
        ) != nil
            ? .systemItem(payload.bundleIdentifier)
            : .application(payload.bundleIdentifier)
        settleState = PolicyBoardSettleState(
            bundleIdentifier: payload.bundleIdentifier,
            destination: destination,
            token: payload.dragToken
        )
    }

    public mutating func finishSettling(token: UUID) {
        guard settleState?.token == token else { return }
        settleState = nil
    }

    public mutating func endDragWithoutDrop() {
        draggedBundleIdentifier = nil
        draggedSourcePolicy = nil
        dropTarget = nil
    }

    public mutating func clearTransientPresentation() {
        hoveredItem = nil
        focusedItem = nil
        draggedBundleIdentifier = nil
        draggedSourcePolicy = nil
        dropTarget = nil
        settleState = nil
    }

    public mutating func clearAll() {
        self = PolicyBoardInteractionState()
    }
}
