import Foundation

#if DEBUG

public struct OrderingBoardOwner: Equatable, Sendable {
    public let bundleIdentifier: String
    public let observedX: Double?
    public let isEligible: Bool

    public init(
        bundleIdentifier: String,
        observedX: Double?,
        isEligible: Bool
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.observedX = observedX
        self.isEligible = isEligible
    }
}

/// The editable Board order. Lanes keep the product's visibility intent while
/// `physicalOrder` exposes the one global left-to-right target used by the
/// ordering planner: Hidden, then Revealable, then Visible.
public struct OrderingBoardLayoutDraft: Equatable, Sendable {
    public let candidateGeneration: UUID
    public let layoutGeneration: UUID
    public let initialVisible: [String]
    public let initialRevealable: [String]
    public let initialHidden: [String]
    public let visible: [String]
    public let revealable: [String]
    public let hidden: [String]

    public init(
        visible: [String],
        revealable: [String],
        hidden: [String],
        candidateGeneration: UUID,
        layoutGeneration: UUID = UUID()
    ) throws {
        try Self.validate(visible: visible, revealable: revealable, hidden: hidden)
        self.candidateGeneration = candidateGeneration
        self.layoutGeneration = layoutGeneration
        self.initialVisible = visible
        self.initialRevealable = revealable
        self.initialHidden = hidden
        self.visible = visible
        self.revealable = revealable
        self.hidden = hidden
    }

    public init(
        visibleSubjects: [OrderingSubjectID],
        revealableSubjects: [OrderingSubjectID],
        hiddenSubjects: [OrderingSubjectID],
        candidateGeneration: UUID,
        layoutGeneration: UUID = UUID()
    ) throws {
        let subjects = visibleSubjects + revealableSubjects + hiddenSubjects
        guard subjects.allSatisfy(Self.validSubject) else {
            throw OrderingBoardLayoutRejection.invalidBundleIdentifier
        }
        guard Set(subjects.map(Self.canonicalSubject)).count == subjects.count else {
            throw OrderingBoardLayoutRejection.duplicateBundleIdentifier
        }
        try self.init(
            visible: visibleSubjects.map(Self.boardIdentifier),
            revealable: revealableSubjects.map(Self.boardIdentifier),
            hidden: hiddenSubjects.map(Self.boardIdentifier),
            candidateGeneration: candidateGeneration,
            layoutGeneration: layoutGeneration
        )
    }

    private init(
        candidateGeneration: UUID,
        layoutGeneration: UUID,
        initialVisible: [String],
        initialRevealable: [String],
        initialHidden: [String],
        visible: [String],
        revealable: [String],
        hidden: [String]
    ) {
        self.candidateGeneration = candidateGeneration
        self.layoutGeneration = layoutGeneration
        self.initialVisible = initialVisible
        self.initialRevealable = initialRevealable
        self.initialHidden = initialHidden
        self.visible = visible
        self.revealable = revealable
        self.hidden = hidden
    }

    public var hasChanges: Bool {
        visible != initialVisible
            || revealable != initialRevealable
            || hidden != initialHidden
    }

    public var physicalOrder: [String] {
        hidden + revealable + visible
    }

    public var physicalSubjects: [OrderingSubjectID] {
        physicalOrder.compactMap(Self.subject)
    }

    public var draftPolicies: [String: MenuBarBundlePolicy] {
        Dictionary(uniqueKeysWithValues:
            visible.map { ($0, .visible) }
                + revealable.map { ($0, .revealable) }
                + hidden.map { ($0, .hidden) }
        )
    }

    public var draftSubjectPolicies: [OrderingSubjectID: MenuBarBundlePolicy] {
        Dictionary(uniqueKeysWithValues: draftPolicies.compactMap { identifier, policy in
            Self.subject(identifier).map { ($0, policy) }
        })
    }

    public func bundleIdentifiers(in policy: MenuBarBundlePolicy) -> [String] {
        switch policy {
        case .visible: visible
        case .revealable: revealable
        case .hidden: hidden
        }
    }

    public func subjects(in policy: MenuBarBundlePolicy) -> [OrderingSubjectID] {
        bundleIdentifiers(in: policy).compactMap(Self.subject)
    }

    public func policy(of bundleIdentifier: String) -> MenuBarBundlePolicy? {
        draftPolicies[bundleIdentifier]
    }

    public func policy(of subject: OrderingSubjectID) -> MenuBarBundlePolicy? {
        policy(of: Self.boardIdentifier(subject))
    }

    public func boardIdentifier(for subject: OrderingSubjectID) -> String {
        Self.boardIdentifier(subject)
    }

    public func resetting() -> Self {
        Self(
            candidateGeneration: candidateGeneration,
            layoutGeneration: UUID(),
            initialVisible: initialVisible,
            initialRevealable: initialRevealable,
            initialHidden: initialHidden,
            visible: initialVisible,
            revealable: initialRevealable,
            hidden: initialHidden
        )
    }

    public func moving(
        _ source: OrderingBoardLayoutItemID,
        to destination: OrderingBoardLayoutDestination,
        nextLayoutGeneration: UUID = UUID()
    ) -> Result<Self, OrderingBoardLayoutRejection> {
        guard source.candidateGeneration == candidateGeneration else {
            return .failure(.staleCandidateGeneration)
        }
        guard source.layoutGeneration == layoutGeneration else {
            return .failure(.staleLayoutGeneration)
        }
        guard policy(of: source.bundleIdentifier) == source.sourcePolicy else {
            return .failure(.staleSourcePolicy)
        }
        if case let .before(target) = destination.position,
           target == source.bundleIdentifier {
            return .failure(.sameItem)
        }
        if case let .after(target) = destination.position,
           target == source.bundleIdentifier {
            return .failure(.sameItem)
        }

        var lanes: [MenuBarBundlePolicy: [String]] = [
            .visible: visible,
            .revealable: revealable,
            .hidden: hidden,
        ]
        lanes[source.sourcePolicy]?.removeAll { $0 == source.bundleIdentifier }
        var destinationValues = lanes[destination.policy] ?? []
        let insertionIndex: Int
        switch destination.position {
        case let .before(target):
            guard let targetIndex = destinationValues.firstIndex(of: target) else {
                return .failure(.missingDestination(target))
            }
            insertionIndex = targetIndex
        case let .after(target):
            guard let targetIndex = destinationValues.firstIndex(of: target) else {
                return .failure(.missingDestination(target))
            }
            insertionIndex = destinationValues.index(after: targetIndex)
        case .end:
            insertionIndex = destinationValues.endIndex
        }
        destinationValues.insert(source.bundleIdentifier, at: insertionIndex)
        lanes[destination.policy] = destinationValues

        let updated = Self(
            candidateGeneration: candidateGeneration,
            layoutGeneration: nextLayoutGeneration,
            initialVisible: initialVisible,
            initialRevealable: initialRevealable,
            initialHidden: initialHidden,
            visible: lanes[.visible] ?? [],
            revealable: lanes[.revealable] ?? [],
            hidden: lanes[.hidden] ?? []
        )
        guard updated.visible != visible
                || updated.revealable != revealable
                || updated.hidden != hidden else {
            return .failure(.unchanged)
        }
        return .success(updated)
    }

    private static func validate(
        visible: [String],
        revealable: [String],
        hidden: [String]
    ) throws {
        let values = visible + revealable + hidden
        guard values.allSatisfy({ subject($0) != nil }) else {
            throw OrderingBoardLayoutRejection.invalidBundleIdentifier
        }
        let canonical = values.compactMap(canonicalSubject)
        guard Set(canonical).count == canonical.count else {
            throw OrderingBoardLayoutRejection.duplicateBundleIdentifier
        }
    }

    private static func boardIdentifier(_ subject: OrderingSubjectID) -> String {
        switch subject {
        case let .application(bundleIdentifier): bundleIdentifier
        case .systemItem: subject.boardID
        }
    }

    private static func subject(_ identifier: String) -> OrderingSubjectID? {
        OrderingSubjectID(boardID: identifier).map { parsed in
            if case .application = parsed { return parsed }
            return parsed
        } ?? BundlePolicyIdentity.canonicalKey(for: identifier).map { _ in
            .application(identifier)
        }
    }

    private static func canonicalSubject(_ identifier: String) -> OrderingSubjectID? {
        guard let subject = subject(identifier) else { return nil }
        switch subject {
        case let .application(bundleIdentifier):
            return BundlePolicyIdentity.canonicalKey(for: bundleIdentifier).map {
                .application($0)
            }
        case .systemItem:
            return subject
        }
    }

    private static func validSubject(_ subject: OrderingSubjectID) -> Bool {
        switch subject {
        case let .application(bundleIdentifier):
            return BundlePolicyIdentity.canonicalKey(for: bundleIdentifier) != nil
        case .systemItem:
            return true
        }
    }

    private static func canonicalSubject(_ subject: OrderingSubjectID) -> OrderingSubjectID {
        switch subject {
        case let .application(bundleIdentifier):
            return .application(
                BundlePolicyIdentity.canonicalKey(for: bundleIdentifier)
                    ?? bundleIdentifier
            )
        case .systemItem:
            return subject
        }
    }
}

public struct OrderingBoardLayoutItemID: Equatable, Hashable, Sendable {
    public let bundleIdentifier: String
    public let sourcePolicy: MenuBarBundlePolicy
    public let candidateGeneration: UUID
    public let layoutGeneration: UUID

    public init(
        bundleIdentifier: String,
        sourcePolicy: MenuBarBundlePolicy,
        candidateGeneration: UUID,
        layoutGeneration: UUID
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.sourcePolicy = sourcePolicy
        self.candidateGeneration = candidateGeneration
        self.layoutGeneration = layoutGeneration
    }

    public init(
        subjectID: OrderingSubjectID,
        sourcePolicy: MenuBarBundlePolicy,
        candidateGeneration: UUID,
        layoutGeneration: UUID
    ) {
        switch subjectID {
        case let .application(bundleIdentifier):
            self.bundleIdentifier = bundleIdentifier
        case .systemItem:
            self.bundleIdentifier = subjectID.boardID
        }
        self.sourcePolicy = sourcePolicy
        self.candidateGeneration = candidateGeneration
        self.layoutGeneration = layoutGeneration
    }

    public var subjectID: OrderingSubjectID? {
        OrderingSubjectID(boardID: bundleIdentifier) ?? .application(bundleIdentifier)
    }
}

public struct OrderingBoardLayoutDestination: Equatable, Sendable {
    public enum Position: Equatable, Sendable {
        case before(String)
        case after(String)
        case end
    }

    public let policy: MenuBarBundlePolicy
    public let position: Position

    public init(policy: MenuBarBundlePolicy, position: Position) {
        self.policy = policy
        self.position = position
    }
}

/// One logical gap per lane. The dragged owner never becomes its own anchor.
/// The caller keeps the receiver geometry fixed while rendering a landing
/// preview, so identical pointer coordinates always resolve identically.
public enum OrderingBoardLandingProjection {
    public static func canonicalPosition(
        _ position: OrderingBoardLayoutDestination.Position,
        moving source: String,
        among owners: [String]
    ) -> OrderingBoardLayoutDestination.Position? {
        let rawIndex: Int
        switch position {
        case let .before(target):
            guard let index = owners.firstIndex(of: target) else { return nil }
            rawIndex = index
        case let .after(target):
            guard let index = owners.firstIndex(of: target) else { return nil }
            rawIndex = index + 1
        case .end:
            rawIndex = owners.count
        }
        return owners.dropFirst(rawIndex).first(where: { $0 != source })
            .map(OrderingBoardLayoutDestination.Position.before) ?? .end
    }

    public static func insertionIndex(
        for position: OrderingBoardLayoutDestination.Position,
        among owners: [String]
    ) -> Int? {
        switch position {
        case let .before(target): owners.firstIndex(of: target)
        case let .after(target): owners.firstIndex(of: target).map { $0 + 1 }
        case .end: owners.count
        }
    }

    public static func position(
        at horizontalLocation: Double,
        itemExtent: Double,
        moving source: String,
        among owners: [String]
    ) -> OrderingBoardLayoutDestination.Position? {
        guard horizontalLocation.isFinite, itemExtent.isFinite, itemExtent > 0 else {
            return nil
        }
        let location = max(0, horizontalLocation)
        let boundedIndex = min(Double(owners.count), floor(location / itemExtent + 0.5))
        let index = Int(boundedIndex)
        let position: OrderingBoardLayoutDestination.Position = index == owners.count
            ? .end : .before(owners[index])
        return canonicalPosition(position, moving: source, among: owners)
    }
}

/// Keeps the last canonical landing gap alive while AppKit finishes delivering
/// a local drag payload. A drag session can report that the pointer ended before
/// SwiftUI invokes the typed drop destination, so pointer end alone must not
/// discard the destination or remove its preview from the view tree.
public struct OrderingBoardLandingSession: Equatable, Sendable {
    public private(set) var movingIdentifier: String?
    public private(set) var position: OrderingBoardLayoutDestination.Position?
    public private(set) var showsPreview = false

    public init() {}

    @discardableResult
    public mutating func update(
        moving identifier: String,
        to proposedPosition: OrderingBoardLayoutDestination.Position,
        among identifiers: [String]
    ) -> Bool {
        guard let canonical = OrderingBoardLandingProjection.canonicalPosition(
            proposedPosition,
            moving: identifier,
            among: identifiers
        ) else {
            return false
        }
        movingIdentifier = identifier
        position = canonical
        showsPreview = true
        return true
    }

    public func boundPosition(
        moving identifier: String,
        among identifiers: [String]
    ) -> OrderingBoardLayoutDestination.Position? {
        guard movingIdentifier == identifier, let position else { return nil }
        return OrderingBoardLandingProjection.canonicalPosition(
            position,
            moving: identifier,
            among: identifiers
        )
    }

    public mutating func consume(
        moving identifier: String,
        among identifiers: [String]
    ) -> OrderingBoardLayoutDestination.Position? {
        guard movingIdentifier == identifier else { return nil }
        let result = boundPosition(moving: identifier, among: identifiers)
        clear()
        return result
    }

    /// Pointer release precedes typed payload delivery on macOS 27. Preserve
    /// the bound gap until the destination consumes it or transfer completes.
    public mutating func pointerEnded() {}

    public mutating func transferCompleted() {
        // Typed delivery can be observed on either side of this terminal
        // phase. Hide the visual feedback, but retain the canonical landing
        // until delivery consumes it or another session replaces it.
        showsPreview = false
    }

    public mutating func transferCompleted(moving identifier: String) {
        clear(moving: identifier)
    }

    public mutating func clear(moving identifier: String) {
        guard movingIdentifier == identifier else { return }
        clear()
    }

    public mutating func clear() {
        movingIdentifier = nil
        position = nil
        showsPreview = false
    }
}

/// Keeps the transferable value mounted on an ordering item stable while
/// SwiftUI recomputes hover and landing presentation. A new candidate or layout
/// generation receives a new delivery token, and an explicit reset discards all
/// values from the preceding Board state.
public struct OrderingBoardDragPayloadRegistry: Sendable {
    private struct Key: Hashable, Sendable {
        let subjectID: OrderingSubjectID
        let sourcePolicy: MenuBarBundlePolicy
        let candidateGeneration: UUID
        let layoutGeneration: UUID
    }

    private var payloads: [Key: PolicyDragPayload] = [:]

    public init() {}

    public mutating func payload(
        dragIdentifier: String,
        subjectID: OrderingSubjectID,
        sourcePolicy: MenuBarBundlePolicy,
        candidateGeneration: UUID,
        layoutGeneration: UUID
    ) -> PolicyDragPayload {
        let key = Key(
            subjectID: subjectID,
            sourcePolicy: sourcePolicy,
            candidateGeneration: candidateGeneration,
            layoutGeneration: layoutGeneration
        )
        if let payload = payloads[key] { return payload }
        let payload = PolicyDragPayload(
            bundleIdentifier: dragIdentifier,
            sourcePolicy: sourcePolicy,
            candidateGeneration: candidateGeneration
        )
        payloads[key] = payload
        return payload
    }

    @discardableResult
    public mutating func clear() -> Bool {
        let removedPayload = !payloads.isEmpty
        payloads.removeAll(keepingCapacity: true)
        return removedPayload
    }

    /// Retires one delivered payload without invalidating the unchanged Board
    /// layout. A later drag of the same item must receive a fresh delivery token
    /// so a late duplicate callback cannot be mistaken for the new session.
    @discardableResult
    public mutating func discard(token: UUID) -> Bool {
        let previousCount = payloads.count
        payloads = payloads.filter { $0.value.dragToken != token }
        return payloads.count != previousCount
    }
}

public enum OrderingBoardLayoutRejection: Error, Equatable, Sendable {
    case invalidBundleIdentifier
    case duplicateBundleIdentifier
    case staleCandidateGeneration
    case staleLayoutGeneration
    case staleSourcePolicy
    case missingDestination(String)
    case sameItem
    case unchanged
}

public struct OrderingBoardArrangementPlan: Equatable, Sendable {
    public let affectedBundleIdentifiers: [String]
    public let beforeOrder: [String]
    public let desiredOrder: [String]

    public init(
        affectedBundleIdentifiers: [String],
        beforeOrder: [String],
        desiredOrder: [String]
    ) {
        self.affectedBundleIdentifiers = affectedBundleIdentifiers
        self.beforeOrder = beforeOrder
        self.desiredOrder = desiredOrder
    }
}

public enum OrderingBoardMoveDirection: Equatable, Sendable {
    case left
    case right
}

public enum OrderingBoardArrangementRejection: Error, Equatable, Sendable {
    case operationInProgress
    case pendingPolicyDraft
    case recoveryRequired
    case duplicateOwner(String)
    case missingOwner(String)
    case sameOwner
    case unverifiedOwner(String)
    case ambiguousObservedPosition([String])
    case ineligibleOwner(String)
    case unchanged
    case edgeReached(OrderingBoardMoveDirection)

    public var interfaceReason: String {
        switch self {
        case .operationInProgress:
            "Wait for the current operation to finish."
        case .pendingPolicyDraft:
            "Apply or discard the policy draft before arranging menu-bar order."
        case .recoveryRequired:
            "Restore the recorded order before arranging another interval."
        case let .duplicateOwner(bundleIdentifier):
            "The current observation contains the owner more than once: \(bundleIdentifier)."
        case let .missingOwner(bundleIdentifier):
            "The application is no longer present in this lane: \(bundleIdentifier)."
        case .sameOwner:
            "Choose a different insertion target."
        case let .unverifiedOwner(bundleIdentifier):
            "The lane order is unverified because this application has no observed position: \(bundleIdentifier). Refresh before arranging."
        case let .ambiguousObservedPosition(bundleIdentifiers):
            "The lane order is ambiguous for: \(bundleIdentifiers.joined(separator: ", ")). Refresh before arranging."
        case let .ineligibleOwner(bundleIdentifier):
            "The affected interval includes an application that cannot be arranged: \(bundleIdentifier)."
        case .unchanged:
            "That insertion would not change the observed order."
        case .edgeReached(.left):
            "This application is already the leftmost item in its group."
        case .edgeReached(.right):
            "This application is already the rightmost item in its group."
        }
    }
}

public enum OrderingBoardArrangement {
    /// Keeps known AX geometry in true screen order. Unknown owners retain their
    /// existing relative order after the verified owners so the Board can keep
    /// displaying them without implying a measured position.
    public static func sortedLeftToRight(
        _ owners: [OrderingBoardOwner]
    ) -> [OrderingBoardOwner] {
        owners.enumerated().sorted { lhs, rhs in
            let leftX = finiteX(lhs.element.observedX)
            let rightX = finiteX(rhs.element.observedX)
            switch (leftX, rightX) {
            case let (left?, right?):
                if left != right { return left < right }
                return lhs.offset < rhs.offset
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.offset < rhs.offset
            }
        }.map(\.element)
    }

    /// Produces the desired left-to-right identifiers for the contiguous owners
    /// whose relative order changes. The moving owner is inserted directly before
    /// the target owner; a stationary target is excluded when moving right.
    public static func inserting(
        moving sourceBundleIdentifier: String,
        before targetBundleIdentifier: String,
        in owners: [OrderingBoardOwner],
        hasPendingPolicyDraft: Bool = false,
        hasRecovery: Bool = false,
        isBusy: Bool = false
    ) -> Result<OrderingBoardArrangementPlan, OrderingBoardArrangementRejection> {
        switch validatedOrder(
            owners,
            hasPendingPolicyDraft: hasPendingPolicyDraft,
            hasRecovery: hasRecovery,
            isBusy: isBusy
        ) {
        case let .failure(rejection):
            return .failure(rejection)
        case let .success(orderedOwners):
            guard sourceBundleIdentifier != targetBundleIdentifier else {
                return .failure(.sameOwner)
            }
            guard let sourceIndex = orderedOwners.firstIndex(where: {
                $0.bundleIdentifier == sourceBundleIdentifier
            }) else {
                return .failure(.missingOwner(sourceBundleIdentifier))
            }
            guard let targetIndex = orderedOwners.firstIndex(where: {
                $0.bundleIdentifier == targetBundleIdentifier
            }) else {
                return .failure(.missingOwner(targetBundleIdentifier))
            }
            var desiredOwners = orderedOwners
            let movingOwner = desiredOwners.remove(at: sourceIndex)
            guard let adjustedTargetIndex = desiredOwners.firstIndex(where: {
                $0.bundleIdentifier == targetBundleIdentifier
            }) else {
                return .failure(.missingOwner(targetBundleIdentifier))
            }
            desiredOwners.insert(movingOwner, at: adjustedTargetIndex)
            guard desiredOwners != orderedOwners else {
                return .failure(.unchanged)
            }
            guard finiteX(orderedOwners[targetIndex].observedX) != nil else {
                // Even when a rightward move leaves the target in place, an
                // unobserved target cannot anchor a verified physical insertion.
                return .failure(.unverifiedOwner(targetBundleIdentifier))
            }
            let affectedRange: ClosedRange<Int>
            if sourceIndex < targetIndex {
                // Inserting before a later target shifts only the owners before
                // that target. The target itself keeps its relative position.
                affectedRange = sourceIndex...(targetIndex - 1)
            } else {
                // Inserting before an earlier target shifts that target and every
                // intervening owner one position to the right.
                affectedRange = targetIndex...sourceIndex
            }
            return plan(
                before: orderedOwners,
                after: desiredOwners,
                affectedRange: affectedRange
            )
        }
    }

    /// Moves one observed position. Moving right swaps with the next owner;
    /// expressing it as insertion before that adjacent owner would be a no-op.
    public static func movingOnePosition(
        _ sourceBundleIdentifier: String,
        direction: OrderingBoardMoveDirection,
        in owners: [OrderingBoardOwner],
        hasPendingPolicyDraft: Bool = false,
        hasRecovery: Bool = false,
        isBusy: Bool = false
    ) -> Result<OrderingBoardArrangementPlan, OrderingBoardArrangementRejection> {
        switch validatedOrder(
            owners,
            hasPendingPolicyDraft: hasPendingPolicyDraft,
            hasRecovery: hasRecovery,
            isBusy: isBusy
        ) {
        case let .failure(rejection):
            return .failure(rejection)
        case let .success(orderedOwners):
            guard let sourceIndex = orderedOwners.firstIndex(where: {
                $0.bundleIdentifier == sourceBundleIdentifier
            }) else {
                return .failure(.missingOwner(sourceBundleIdentifier))
            }
            let destinationIndex: Int
            switch direction {
            case .left:
                guard sourceIndex > orderedOwners.startIndex else {
                    return .failure(.edgeReached(.left))
                }
                destinationIndex = sourceIndex - 1
            case .right:
                guard sourceIndex < orderedOwners.index(before: orderedOwners.endIndex) else {
                    return .failure(.edgeReached(.right))
                }
                destinationIndex = sourceIndex + 1
            }
            var desiredOwners = orderedOwners
            desiredOwners.swapAt(sourceIndex, destinationIndex)
            return plan(
                before: orderedOwners,
                after: desiredOwners,
                affectedRange: min(sourceIndex, destinationIndex)...max(sourceIndex, destinationIndex)
            )
        }
    }

    private static func validatedOrder(
        _ owners: [OrderingBoardOwner],
        hasPendingPolicyDraft: Bool,
        hasRecovery: Bool,
        isBusy: Bool
    ) -> Result<[OrderingBoardOwner], OrderingBoardArrangementRejection> {
        if isBusy { return .failure(.operationInProgress) }
        if hasPendingPolicyDraft { return .failure(.pendingPolicyDraft) }
        if hasRecovery { return .failure(.recoveryRequired) }

        var identifiers = Set<String>()
        for owner in owners where !identifiers.insert(owner.bundleIdentifier).inserted {
            return .failure(.duplicateOwner(owner.bundleIdentifier))
        }
        return .success(sortedLeftToRight(owners))
    }

    private static func plan(
        before: [OrderingBoardOwner],
        after: [OrderingBoardOwner],
        affectedRange: ClosedRange<Int>
    ) -> Result<OrderingBoardArrangementPlan, OrderingBoardArrangementRejection> {
        let affectedBefore = Array(before[affectedRange])
        if let unverified = affectedBefore.first(where: {
            finiteX($0.observedX) == nil
        }) {
            return .failure(.unverifiedOwner(unverified.bundleIdentifier))
        }
        let positionGroups = Dictionary(grouping: affectedBefore) {
            finiteX($0.observedX)!
        }
        if let ambiguous = positionGroups.values.first(where: { $0.count > 1 }) {
            return .failure(.ambiguousObservedPosition(
                ambiguous.map(\.bundleIdentifier).sorted()
            ))
        }
        if let unsupported = affectedBefore.first(where: { !$0.isEligible }) {
            return .failure(.ineligibleOwner(unsupported.bundleIdentifier))
        }
        return .success(OrderingBoardArrangementPlan(
            affectedBundleIdentifiers: affectedBefore.map(\.bundleIdentifier),
            beforeOrder: affectedBefore.map(\.bundleIdentifier),
            desiredOrder: Array(after[affectedRange]).map(\.bundleIdentifier)
        ))
    }

    private static func finiteX(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }
}

#endif
