import AppKit
import BlennyCore
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class ProductInterfaceModel: ObservableObject {
    @Published var automaticUpdateChecks = false
    @Published var navigation = ProductInterfaceNavigationState()
    @Published private(set) var model: PolicyEditorViewModel?
    @Published private(set) var observationCount = 0
    @Published var discoveryWarnings: [String] = []
    @Published private(set) var recoveryAvailable = false
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var accessibilityPromptRequested = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var statusMessage = "Preparing the policy editor…"
    @Published private(set) var statusIsError = false
    @Published private(set) var isApplying = false
    @Published private(set) var applicationIcons: [String: ResolvedPolicyIcon] = [:]
    @Published private(set) var systemIcons: [String: ResolvedPolicyIcon] = [:]
    @Published private(set) var launchAtLoginState = LaunchAtLoginPresentationState(
        availability: .disabled
    )
    @Published private(set) var candidateGeneration = UUID()
    @Published private(set) var policyDragSourceRevision: UInt = 0
    @Published private(set) var managementRuntimeState: ManagementLoopState = .unknown
    @Published private(set) var managementBackendAvailable = false
    @Published private(set) var nativeOverflowPlacementAvailable = false
    #if BLENNY_PRODUCT || DEBUG
    let orderingPresentation = OrderingPresentation()
    @Published private(set) var orderingLayoutDraft: OrderingBoardLayoutDraft?
    @Published private(set) var orderingDragSourceRevision: UInt = 0
    private var orderingPresentationCancellable: AnyCancellable?
    private var dragDiagnosticCancellables = Set<AnyCancellable>()
    private var orderingConsumedDragTokens: Set<UUID> = []
    private var orderingDragLayoutGenerations: [UUID: UUID] = [:]
    private var orderingDragPayloads = OrderingBoardDragPayloadRegistry()
    #endif
    #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    @Published private(set) var sharedSystemItemTrials = Dictionary(
        uniqueKeysWithValues: SharedSystemItemTrialTarget.allCases.map {
            ($0, SharedSystemItemTrialPresentation.checking)
        }
    )
    #endif

    private let iconResolver = WorkspacePolicyIconResolver()
    private var assignmentCoordinator = PolicyDraftAssignmentCoordinator()
    private var policyDragPayloads = PolicyDragPayloadRegistry()

    init() {
        #if BLENNY_PRODUCT || DEBUG
        orderingPresentationCancellable = orderingPresentation.objectWillChange
            .sink { [weak self] _ in
                DebugDragStartDiagnostics.record("orderingPresentation.forwardObjectWillChange")
                self?.objectWillChange.send()
            }
        if DebugDragStartDiagnostics.mode != nil {
            DebugDragStartDiagnostics.watch($navigation, name: "model.navigation", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($model, name: "model.model", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($observationCount, name: "model.observationCount", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($discoveryWarnings, name: "model.discoveryWarnings", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($recoveryAvailable, name: "model.recoveryAvailable", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($accessibilityTrusted, name: "model.accessibilityTrusted", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($accessibilityPromptRequested, name: "model.accessibilityPromptRequested", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($isRefreshing, name: "model.isRefreshing", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($statusMessage, name: "model.statusMessage", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($statusIsError, name: "model.statusIsError", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($isApplying, name: "model.isApplying", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($applicationIcons, name: "model.applicationIcons", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($systemIcons, name: "model.systemIcons", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($launchAtLoginState, name: "model.launchAtLoginState", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($candidateGeneration, name: "model.candidateGeneration", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($policyDragSourceRevision, name: "model.policyDragSourceRevision", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($managementRuntimeState, name: "model.managementRuntimeState", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($managementBackendAvailable, name: "model.managementBackendAvailable", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($nativeOverflowPlacementAvailable, name: "model.nativeOverflowPlacementAvailable", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($orderingLayoutDraft, name: "model.orderingLayoutDraft", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($orderingDragSourceRevision, name: "model.orderingDragSourceRevision", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch($sharedSystemItemTrials, name: "model.sharedSystemItemTrials", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch(orderingPresentation.$rows, name: "ordering.rows", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch(orderingPresentation.$preview, name: "ordering.preview", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch(orderingPresentation.$message, name: "ordering.message", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch(orderingPresentation.$technicalDetail, name: "ordering.technicalDetail", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch(orderingPresentation.$requiresUndoReplacement, name: "ordering.requiresUndoReplacement", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch(orderingPresentation.$requiresObservationRefresh, name: "ordering.requiresObservationRefresh", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch(orderingPresentation.$isError, name: "ordering.isError", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch(orderingPresentation.$isBusy, name: "ordering.isBusy", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch(orderingPresentation.$hasRecovery, name: "ordering.hasRecovery", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch(orderingPresentation.$hasPendingRecovery, name: "ordering.hasPendingRecovery", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch(orderingPresentation.$hasObservation, name: "ordering.hasObservation", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch(orderingPresentation.$needsDataAccess, name: "ordering.needsDataAccess", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch(orderingPresentation.$canRefresh, name: "ordering.canRefresh", in: &dragDiagnosticCancellables)
            DebugDragStartDiagnostics.watch(orderingPresentation.$canApply, name: "ordering.canApply", in: &dragDiagnosticCancellables)
            objectWillChange.sink { _ in
                DebugDragStartDiagnostics.record("model.objectWillChange")
            }.store(in: &dragDiagnosticCancellables)
        }
        #endif
    }

    var controls: ProductInterfaceControlState {
        ProductInterfaceControlState(
            hasModel: model != nil,
            managementEnabled: model?.acceptedPolicy.managementEnabled,
            managementRuntimeState: managementRuntimeState,
            recoveryAvailable: recoveryAvailable,
            hasDraftChanges: hasDraftChanges,
            isRefreshing: isRefreshing,
            isApplying: isApplying,
            accessibilityTrusted: accessibilityTrusted,
            accessibilityPromptRequested: accessibilityPromptRequested,
            requiresObservationRefresh: requiresObservationRefresh
        )
    }

    var managementEnabled: Bool? {
        switch managementRuntimeState {
        case .active, .baselineVerified, .ordinaryRevealSession:
            true
        case .stopped, .unsupportedRuntimeContract, .failClosedUnrestricted:
            false
        default:
            nil
        }
    }
    var requiresObservationRefresh: Bool {
        #if BLENNY_PRODUCT || DEBUG
        orderingPresentation.requiresObservationRefresh
        #else
        false
        #endif
    }

    var hasDraftChanges: Bool {
        if requiresObservationRefresh { return false }
        #if BLENNY_PRODUCT || DEBUG
        return model?.hasDraftChanges == true || hasOrderingLayoutChanges
        #else
        return model?.hasDraftChanges == true
        #endif
    }
    var unattributedMenuBarItems: [UnattributedMenuBarItemObservation] {
        model?.unattributedItems ?? []
    }

    var systemItems: [SystemMenuBarItemObservation] {
        var items = model?.systemItems ?? []
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        for target in SharedSystemItemTrialTarget.allCases {
            let presentation = sharedSystemItemTrialPresentation(for: target)
            guard presentation == .recoveryRequired,
                  !items.contains(where: {
                      SystemItemCapabilityIdentity.recoveryIdentifier(
                          for: $0, retainedWhileAbsent: $0.observationCount == 0
                      ) == target.observationIdentifier
                  }) else {
                continue
            }
            items.append(
                SystemMenuBarItemObservation(
                    observationIdentifier: target.observationIdentifier,
                    ownerBundleIdentifier: target.ownerBundleIdentifier,
                    displayName: target.displayName,
                    observationCount: 0
                )
            )
        }
        #endif
        var uniqueItems: [SystemMenuBarItemObservation] = []
        for item in items where !uniqueItems.contains(item) {
            uniqueItems.append(item)
        }
        return uniqueItems.sorted { first, second in
            let firstIsClock = first.observationIdentifier == SystemMenuBarItemObservation.clockIdentifier
            let secondIsClock = second.observationIdentifier == SystemMenuBarItemObservation.clockIdentifier
            if firstIsClock != secondIsClock { return !firstIsClock }
            return first.displayName.localizedCaseInsensitiveCompare(second.displayName)
                == .orderedAscending
        }
    }

    func systemItems(in policy: MenuBarBundlePolicy) -> [SystemMenuBarItemObservation] {
        systemItems.filter { observation in
            if let assigned = effectiveSystemItemPolicy(
                for: observation.observationIdentifier
            ) {
                return assigned == policy
            }
            return policy == .visible
        }
    }

    func isControllableSystemItem(_ observationIdentifier: String) -> Bool {
        guard let observation = systemItem(
            observationIdentifier: observationIdentifier
        ), let identifier = SystemItemCapabilityIdentity.policyIdentifier(
            for: observation,
            retainedWhileAbsent: retainedSystemItem(observation)
        ) else { return false }
        guard systemItems.filter({ candidate in
            SystemItemCapabilityIdentity.policyIdentifier(
                for: candidate,
                retainedWhileAbsent: retainedSystemItem(candidate)
            ) == identifier
        }).count == 1 else { return false }
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        if let target = SharedSystemItemTrialTarget.allCases.first(where: {
            $0.observationIdentifier == identifier
        }) {
            switch sharedSystemItemTrialPresentation(for: target) {
            case .ready:
                return true
            case .recoveryRequired:
                return effectiveSystemItemPolicy(for: identifier) != .visible
            case .checking, .hidden, .busy, .unavailable:
                return false
            }
        }
        #endif
        return true
    }

    private func retainedSystemItem(
        _ observation: SystemMenuBarItemObservation
    ) -> Bool {
        guard observation.observationCount == 0 else { return false }
        return model?.systemItems.contains(where: {
            $0.observationIdentifier == observation.observationIdentifier
                && $0.observationCount == 0
        }) == true || effectiveSystemItemPolicy(
            for: observation.observationIdentifier
        ) != .visible
    }

    func isInteractiveSystemItem(_ observationIdentifier: String) -> Bool {
        isControllableSystemItem(observationIdentifier)
    }

    /// Policy-backed system controls use the same three product intents as
    /// applications. The older manual item trial remains a recovery surface,
    /// not a second Visible/Hidden policy selector.
    func systemItemPolicyDestinations(
        for observationIdentifier: String
    ) -> [MenuBarBundlePolicy] {
        guard isControllableSystemItem(observationIdentifier),
              effectiveSystemItemPolicy(for: observationIdentifier) != nil else {
            return []
        }
        return [.visible, .revealable, .hidden]
    }

    func systemItemCapabilityExplanation(
        for observationIdentifier: String
    ) -> String {
        guard let observation = systemItem(
            observationIdentifier: observationIdentifier
        ) else { return "Refresh to check this system item." }
        #if DEBUG && BLENNY_NOW_PLAYING_LEGACY_REVEAL_TRIAL
        if observation.observationIdentifier == "com.apple.menuextra.now-playing" {
            return "Experimental 0.8.0 reveal timing trial. Verify physical display after Resume and expand; Stop restores the original setting."
        }
        #endif
        if let item = PersistentSystemItemPolicyCatalog.controllableItem(
            forObservationIdentifier: observationIdentifier
        ), !PersistentSystemItemPolicyCatalog.supportsManagement(for: item.identifier) {
            return "macOS hides Now Playing while management is on, even when expanded. Stop management to show it. Existing settings can still be restored."
        }
        if observation.observationIdentifier == SystemMenuBarItemObservation.clockIdentifier {
            return "Clock is fixed on this macOS build."
        }
        guard let identifier = SystemItemCapabilityIdentity.policyIdentifier(
            for: observation,
            retainedWhileAbsent: retainedSystemItem(observation)
        ) else {
            if observation.observationCount > 1 {
                return "Multiple instances share this identity; no unique write target."
            }
            if observation.observationCount == 0 {
                return "This item was not observed. Refresh after it appears."
            }
            return "No verified item-specific writer and recovery path for this identity."
        }
        if systemItems.filter({ candidate in
            SystemItemCapabilityIdentity.policyIdentifier(
                for: candidate,
                retainedWhileAbsent: retainedSystemItem(candidate)
            ) == identifier
        }).count != 1 {
            return "This writer target has more than one Board identity; refresh to resolve it."
        }
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        if let target = SharedSystemItemTrialTarget.allCases.first(where: {
            $0.observationIdentifier == identifier
        }) {
            switch sharedSystemItemTrialPresentation(for: target) {
            case .ready:
                break
            case .recoveryRequired:
                if effectiveSystemItemPolicy(for: identifier) == .visible {
                    return "Restore the existing item receipt before assigning a new policy."
                }
            case .checking:
                return "Checking the exact visibility target."
            case .hidden:
                return "This item is hidden outside Blenny; restore it in macOS before assigning it."
            case .busy:
                return "A system-item operation is in progress."
            case let .unavailable(reason):
                return "Exact visibility preflight failed: \(reason)"
            }
        }
        #endif
        return "Three-state visibility is available for this exact item."
    }

    func effectiveSystemItemPolicy(
        for observationIdentifier: String
    ) -> MenuBarBundlePolicy? {
        guard let policyIdentifier = systemItemPolicyIdentifier(
            for: observationIdentifier
        ) else { return nil }
        return model?.effectiveSystemItemPolicy(for: policyIdentifier)
    }

    /// Converts an already recognized live system-item identity to the exact
    /// identifier accepted by the policy editor. Accessibility observations
    /// can use a stable composite identity while the persistent policy is
    /// intentionally keyed by its canonical menu-extra identifier.
    private func systemItemPolicyIdentifier(
        for observationIdentifier: String
    ) -> String? {
        if let item = SystemItemPolicyCatalog.controllableItem(
            for: observationIdentifier
        ) {
            return item.identifier
        }
        if let item = PersistentSystemItemPolicyCatalog.controllableItem(
            forObservationIdentifier: observationIdentifier
        ) {
            return item.identifier
        }
        return nil
    }

    #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    func sharedSystemItemTrialTarget(
        for observationIdentifier: String
    ) -> SharedSystemItemTrialTarget? {
        guard let observation = systemItem(
            observationIdentifier: observationIdentifier
        ), let identifier = SystemItemCapabilityIdentity.recoveryIdentifier(
            for: observation,
            retainedWhileAbsent: observation.observationCount == 0
        ) else { return nil }
        guard let target = SharedSystemItemTrialTarget.allCases.first(where: {
            $0.observationIdentifier == identifier
        }), observation.observationCount == 1
                || sharedSystemItemTrialPresentation(for: target) == .recoveryRequired else {
            return nil
        }
        guard PersistentSystemItemPolicyCatalog.supportsManagement(for: identifier)
                || sharedSystemItemTrialPresentation(for: target) == .recoveryRequired else {
            return nil
        }
        return target
    }

    func sharedSystemItemTrialPresentation(
        for target: SharedSystemItemTrialTarget
    ) -> SharedSystemItemTrialPresentation {
        sharedSystemItemTrials[target] ?? .checking
    }

    #endif

    func navigate(to section: ProductInterfaceSection) {
        var updatedNavigation = navigation
        updatedNavigation.navigate(to: section)
        navigation = updatedNavigation
    }

    func setAccessibilityTrusted(
        _ trusted: Bool,
        hasRequestedSystemPrompt: Bool
    ) {
        accessibilityTrusted = trusted
        accessibilityPromptRequested = hasRequestedSystemPrompt
    }

    func setRefreshing(_ refreshing: Bool) {
        isRefreshing = refreshing
        if refreshing {
            applicationIcons.removeAll()
            systemIcons.removeAll()
        }
    }

    func setApplying(_ applying: Bool) {
        isApplying = applying
    }

    func display(
        model: PolicyEditorViewModel,
        observationCount: Int,
        recoveryAvailable: Bool,
        preservingOrderingLayout: Bool = false
    ) {
        #if BLENNY_PRODUCT || DEBUG
        let previousOrderingLayout = preservingOrderingLayout
            ? orderingLayoutDraft : nil
        #endif
        self.model = model
        #if BLENNY_PRODUCT || DEBUG
        orderingPresentation.requiresObservationRefresh = false
        #endif
        if !model.acceptedPolicy.managementEnabled {
            managementRuntimeState = .stopped
        }
        assignmentCoordinator.replaceCandidateGeneration()
        candidateGeneration = assignmentCoordinator.candidateGeneration
        preparePolicyDragPayloads()
        #if BLENNY_PRODUCT || DEBUG
        orderingLayoutDraft = nil
        orderingConsumedDragTokens.removeAll(keepingCapacity: true)
        orderingDragLayoutGenerations.removeAll(keepingCapacity: true)
        orderingDragPayloads.clear()
        #endif
        self.observationCount = observationCount
        self.recoveryAvailable = recoveryAvailable

        let currentIdentifiers = Set(
            model.candidateInventory.candidates.map(\.bundleIdentifier)
        )
        applicationIcons = applicationIcons.filter {
            currentIdentifiers.contains($0.key)
        }
        for candidate in model.candidateInventory.candidates
            where applicationIcons[candidate.bundleIdentifier] == nil {
            applicationIcons[candidate.bundleIdentifier] = iconResolver.applicationIcon(
                bundleIdentifier: candidate.bundleIdentifier
            )
        }

        let currentSystemIdentifiers = Set(
            model.systemItems.map(\.observationIdentifier)
        )
        systemIcons = systemIcons.filter {
            currentSystemIdentifiers.contains($0.key)
        }
        for observation in model.systemItems
            where systemIcons[observation.observationIdentifier] == nil {
            systemIcons[observation.observationIdentifier] = iconResolver.systemIcon(
                observation: observation
            )
        }

        #if BLENNY_PRODUCT || DEBUG
        if preservingOrderingLayout {
            if let previousOrderingLayout {
                if !restoreOrderingLayoutDraft(previousOrderingLayout) {
                    if !previousOrderingLayout.hasChanges {
                        // A clean layout is only a presentation baseline. Policy
                        // or capability changes may invalidate it after a commit.
                        initializeOrderingLayoutFromCurrentRows(force: true)
                        if orderingLayoutDraft == nil {
                            setOrderingStatus(
                                "Management changed successfully, but the Board could not rebuild its ordering layout. Refresh before arranging."
                            )
                        } else {
                            orderingPresentation.isError = false
                            orderingPresentation.message = ""
                        }
                    } else {
                        setOrderingStatus(
                            "Management changed successfully, but the ordering draft could not be rebound to the current Board. Refresh before arranging again."
                        )
                    }
                }
            } else if orderingPresentation.hasObservation {
                // A preceding build or interrupted transition may already have
                // discarded the layout while leaving its captured rows intact.
                // Rebuild from those rows without performing another read.
                initializeOrderingLayoutFromCurrentRows(force: true)
                if orderingLayoutDraft == nil {
                    setOrderingStatus(
                        "The captured ordering rows could not rebuild the Board. Refresh before arranging again."
                    )
                }
            } else {
                setOrderingStatus(
                    "No captured ordering rows are available after the management transition. Refresh the Board before arranging."
                )
            }
        }
        #endif

        setStatus(
            model.hasDraftChanges
                ? "Changes not applied"
                : "",
            isError: false
        )
    }

    func setStatus(_ message: String, isError: Bool) {
        statusMessage = message
        statusIsError = isError
    }

    func setLaunchAtLoginState(_ state: LaunchAtLoginPresentationState) {
        launchAtLoginState = state
    }

    func setNativeOverflowPlacement(
        _ snapshot: NativeOverflowObservationSnapshot
    ) {
        let available = BlennyFishPlacement.guideAvailable(for: snapshot)
        #if BLENNY_PRODUCT || DEBUG
        if DebugDragStartDiagnostics.publishUnchangedOverflow {
            nativeOverflowPlacementAvailable = available
            return
        }
        #endif
        guard nativeOverflowPlacementAvailable != available else { return }
        nativeOverflowPlacementAvailable = available
    }

    #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    func setSharedSystemItemTrial(
        _ target: SharedSystemItemTrialTarget,
        presentation: SharedSystemItemTrialPresentation
    ) {
        guard sharedSystemItemTrials[target] != presentation else { return }
        sharedSystemItemTrials[target] = presentation
        preparePolicyDragPayloads()
    }
    #endif

    func setManagementRuntimeState(
        _ state: ManagementLoopState,
        managementBackendAvailable: Bool
    ) {
        managementRuntimeState = state
        self.managementBackendAvailable = managementBackendAvailable
    }

    func candidates(in policy: MenuBarBundlePolicy) -> [PolicyCandidate] {
        guard let model else { return [] }
        var candidates = model.candidates(in: policy)
        if policy == .visible {
            candidates.append(contentsOf: model.implicitVisibleCandidates)
            candidates.sort {
                ($0.bundleIdentifier.lowercased(), $0.bundleIdentifier)
                    < ($1.bundleIdentifier.lowercased(), $1.bundleIdentifier)
            }
        }
        return candidates
    }

    func applicationCandidates(in policy: MenuBarBundlePolicy) -> [PolicyCandidate] {
        let candidates = baseApplicationCandidates(in: policy)
        #if BLENNY_PRODUCT || DEBUG
        if let orderingLayoutDraft {
            let rank = Dictionary(uniqueKeysWithValues:
                orderingLayoutDraft.bundleIdentifiers(in: policy).enumerated().map {
                    ($0.element, $0.offset)
                }
            )
            return candidates.sorted {
                let leftRank = rank[$0.bundleIdentifier]
                let rightRank = rank[$1.bundleIdentifier]
                switch (leftRank, rightRank) {
                case let (left?, right?): return left < right
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none):
                    return ($0.bundleIdentifier.lowercased(), $0.bundleIdentifier)
                        < ($1.bundleIdentifier.lowercased(), $1.bundleIdentifier)
                }
            }
        }
        let owners = candidates.map { candidate in
            let row = orderingRow(for: candidate.bundleIdentifier)
            return OrderingBoardOwner(
                bundleIdentifier: candidate.bundleIdentifier,
                observedX: row?.observedX,
                isEligible: row?.isEligible == true
            )
        }
        let ranks = Dictionary(uniqueKeysWithValues:
            OrderingBoardArrangement.sortedLeftToRight(owners).enumerated().map {
                ($0.element.bundleIdentifier, $0.offset)
            }
        )
        return candidates.sorted {
            ranks[$0.bundleIdentifier, default: .max]
                < ranks[$1.bundleIdentifier, default: .max]
        }
        #else
        return candidates
        #endif
    }

    private func baseApplicationCandidates(in policy: MenuBarBundlePolicy) -> [PolicyCandidate] {
        #if BLENNY_PRODUCT || DEBUG
        candidates(in: policy)
        #else
        candidates(in: policy).filter {
            !ExperimentalAppleBundlePolicyCatalog.contains($0.bundleIdentifier)
        }
        #endif
    }

    #if BLENNY_PRODUCT || DEBUG
    func orderingRow(for bundleIdentifier: String) -> OrderingRow? {
        orderingRow(for: .application(bundleIdentifier))
    }

    func orderingRow(for subjectID: OrderingSubjectID) -> OrderingRow? {
        switch subjectID {
        case let .application(bundleIdentifier):
            let canonical = BundlePolicyIdentity.canonicalKey(for: bundleIdentifier)
            return orderingPresentation.rows.first { row in
                guard case let .application(rowBundle) = row.subjectID else { return false }
                return BundlePolicyIdentity.canonicalKey(for: rowBundle) == canonical
            }
        case .systemItem:
            return orderingPresentation.rows.first { $0.subjectID == subjectID }
        }
    }

    func orderingExplanation(for bundleIdentifier: String) -> String {
        orderingExplanation(for: .application(bundleIdentifier))
    }

    func orderingExplanation(for subjectID: OrderingSubjectID) -> String {
        guard let row = orderingRow(for: subjectID) else {
            return "Refresh to check sorting availability."
        }
        switch row.availability {
        case .ready:
            return "Sorting available."
                + (row.observedX == nil ? " On-screen position could not be verified." : "")
        case .needsMapping:
            if case .systemItem = subjectID, row.systemKey == nil {
                return "Visibility can be changed, but sorting is unavailable because this system control has no verified saved position. \(row.reason ?? "")"
            }
            return "Visibility can be changed, but sorting is unavailable because Blenny cannot verify a unique saved position for this item. \(row.reason ?? "")"
        case .unverified:
            return "Mapping or observation is not fully verified yet. Its configuration position can still be arranged. \(row.reason ?? "")"
        case .blocked:
            return "Sorting unavailable. \(row.reason ?? "")"
        }
    }

    func availableSystemOrderingItem(
        for observationIdentifier: String
    ) -> ExactSystemOrderingItem? {
        guard let observation = systemItem(
            observationIdentifier: observationIdentifier
        ), let item = SystemItemCapabilityIdentity.orderingItem(
            for: observation,
            retainedWhileAbsent: retainedSystemItem(observation)
        ), item.isOrderingOffered,
           let row = orderingRow(for: .systemItem(item)),
           row.availability == .ready, row.isEligible,
           row.systemKey == item.configurationKey else { return nil }
        guard systemItems.filter({ candidate in
            SystemItemCapabilityIdentity.orderingItem(
                for: candidate,
                retainedWhileAbsent: retainedSystemItem(candidate)
            ) == item
        }).count == 1 else { return nil }
        return item
    }

    func initializeOrderingLayoutFromCurrentRows(force: Bool = false) {
        guard model != nil else {
            installOrderingLayout(nil)
            return
        }
        if !force, let orderingLayoutDraft,
           orderingLayoutDraft.candidateGeneration == candidateGeneration,
           orderingLayoutDraft.hasChanges {
            return
        }
        func orderedSubjects(in policy: MenuBarBundlePolicy) -> [OrderingSubjectID] {
            let applicationSubjects = baseApplicationCandidates(in: policy).map {
                OrderingSubjectID.application($0.bundleIdentifier)
            }
            let systemSubjects = exactSystemOrderingItems(in: policy).map(\.subjectID)
            return (applicationSubjects + systemSubjects).enumerated().sorted { lhs, rhs in
                let left = orderingSeed(for: lhs.element)
                let right = orderingSeed(for: rhs.element)
                if left.kind != right.kind { return left.kind < right.kind }
                if left.value != right.value { return left.value < right.value }
                return lhs.offset < rhs.offset
            }.map(\.element)
        }
        do {
            let layout = try OrderingBoardLayoutDraft(
                visibleSubjects: orderedSubjects(in: .visible),
                revealableSubjects: orderedSubjects(in: .revealable),
                hiddenSubjects: orderedSubjects(in: .hidden),
                candidateGeneration: candidateGeneration
            )
            installOrderingLayout(layout)
        } catch {
            installOrderingLayout(nil)
            setOrderingStatus("The observed applications could not form one unique configuration order: \(error)")
        }
    }

    /// Rebinds the configuration that was just committed to the interface's
    /// new candidate generation. This uses the reviewed target order and the
    /// synchronized accepted policy, so drag availability does not depend on
    /// the optional post-commit physical observation succeeding.
    @discardableResult
    func installCommittedOrderingLayout(
        from request: OrderingConfigurationRequest
    ) -> Bool {
        guard model != nil else { return false }

        let currentSubjects = currentOrderingSubjects()
        guard currentSubjects.count == Set(currentSubjects).count,
              request.orderedSubjects.count == Set(request.orderedSubjects).count,
              Set(currentSubjects) == Set(request.orderedSubjects),
              request.orderedSubjects.allSatisfy({ subject in
                  guard let committedPolicy = effectiveOrderingPolicy(for: subject)
                  else { return false }
                  return request.draftSubjectPolicies[subject] == committedPolicy
              }) else {
            return false
        }

        func subjects(in policy: MenuBarBundlePolicy) -> [OrderingSubjectID] {
            request.orderedSubjects.filter {
                effectiveOrderingPolicy(for: $0) == policy
            }
        }
        do {
            let layout = try OrderingBoardLayoutDraft(
                visibleSubjects: subjects(in: .visible),
                revealableSubjects: subjects(in: .revealable),
                hiddenSubjects: subjects(in: .hidden),
                candidateGeneration: candidateGeneration
            )
            installOrderingLayout(layout)
            return true
        } catch {
            installOrderingLayout(nil)
            return false
        }
    }

    /// Rebinds an uncommitted ordering draft after Resume or Stop replaces the
    /// accepted policy model. The initial lanes remain the discard baseline;
    /// the current lanes remain the user's local draft.
    private func restoreOrderingLayoutDraft(
        _ previous: OrderingBoardLayoutDraft
    ) -> Bool {
        let previousSubjects = previous.visible + previous.revealable + previous.hidden
        let currentSubjects = currentOrderingSubjects().map { dragIdentifier(for: $0) }
        guard previousSubjects.count == Set(previousSubjects).count,
              currentSubjects.count == Set(currentSubjects).count,
              Set(previousSubjects) == Set(currentSubjects),
              previousSubjects.allSatisfy({ identifier in
                  guard let subject = orderingSubject(forDragIdentifier: identifier),
                        let previousPolicy = previous.policy(of: identifier) else {
                      return false
                  }
                  return effectiveOrderingPolicy(for: subject) == previousPolicy
              }) else {
            return false
        }

        var restored: OrderingBoardLayoutDraft
        do {
            restored = try OrderingBoardLayoutDraft(
                visible: previous.initialVisible,
                revealable: previous.initialRevealable,
                hidden: previous.initialHidden,
                candidateGeneration: candidateGeneration
            )
        } catch {
            return false
        }

        for policy in MenuBarBundlePolicy.allCases {
            for identifier in previous.bundleIdentifiers(in: policy) {
                guard let sourcePolicy = restored.policy(of: identifier) else {
                    return false
                }
                let source = OrderingBoardLayoutItemID(
                    bundleIdentifier: identifier,
                    sourcePolicy: sourcePolicy,
                    candidateGeneration: candidateGeneration,
                    layoutGeneration: restored.layoutGeneration
                )
                switch restored.moving(
                    source,
                    to: OrderingBoardLayoutDestination(policy: policy, position: .end)
                ) {
                case let .success(updated):
                    restored = updated
                case .failure(.unchanged):
                    break
                case .failure:
                    return false
                }
            }
        }
        guard restored.visible == previous.visible,
              restored.revealable == previous.revealable,
              restored.hidden == previous.hidden,
              restored.hasChanges == previous.hasChanges else {
            return false
        }
        installOrderingLayout(restored)
        return true
    }

    private func currentOrderingSubjects() -> [OrderingSubjectID] {
        let applications = MenuBarBundlePolicy.allCases.flatMap { policy in
            baseApplicationCandidates(in: policy).map {
                OrderingSubjectID.application($0.bundleIdentifier)
            }
        }
        let systems = MenuBarBundlePolicy.allCases.flatMap { policy in
            exactSystemOrderingItems(in: policy).map(\.subjectID)
        }
        return applications + systems
    }

    var currentOrderingConfigurationRequest: OrderingConfigurationRequest? {
        orderingLayoutDraft.map(OrderingConfigurationRequest.init)
    }

    var hasOrderingLayoutChanges: Bool {
        orderingLayoutDraft?.hasChanges == true
    }

    func resetOrderingLayoutDraft() {
        if let layout = orderingLayoutDraft {
            installOrderingLayout(try? OrderingBoardLayoutDraft(
                visible: layout.initialVisible,
                revealable: layout.initialRevealable,
                hidden: layout.initialHidden,
                candidateGeneration: candidateGeneration
            ))
        } else {
            installOrderingLayout(nil)
        }
    }

    func discardOrderingLayoutDraft() {
        resetOrderingLayoutDraft()
    }

    func orderingLayoutItemID(
        bundleIdentifier: String,
        sourcePolicy: MenuBarBundlePolicy
    ) -> OrderingBoardLayoutItemID? {
        guard let orderingLayoutDraft else { return nil }
        return OrderingBoardLayoutItemID(
            bundleIdentifier: bundleIdentifier,
            sourcePolicy: sourcePolicy,
            candidateGeneration: candidateGeneration,
            layoutGeneration: orderingLayoutDraft.layoutGeneration
        )
    }

    func orderingLayoutItemID(
        subjectID: OrderingSubjectID,
        sourcePolicy: MenuBarBundlePolicy
    ) -> OrderingBoardLayoutItemID? {
        guard let orderingLayoutDraft else { return nil }
        return OrderingBoardLayoutItemID(
            subjectID: subjectID,
            sourcePolicy: sourcePolicy,
            candidateGeneration: candidateGeneration,
            layoutGeneration: orderingLayoutDraft.layoutGeneration
        )
    }

    func requestOrderingConfigurationDrop(
        payload: PolicyDragPayload,
        destination: OrderingBoardLayoutDestination
    ) -> OrderingBoardConfigurationMutationOutcome {
        guard !isApplying, !isRefreshing, !requiresObservationRefresh else {
            return .rejected("Wait for the current operation to finish.")
        }
        guard !orderingConsumedDragTokens.contains(payload.dragToken) else {
            return .rejected("This drop was already handled.")
        }
        guard !orderingPresentation.hasPendingRecovery else {
            return .rejected("Restore the unresolved ordering operation before changing the configuration.")
        }
        guard payload.candidateGeneration == candidateGeneration,
              let layout = orderingLayoutDraft else {
            return .rejected("Refresh changed the available items. Start a new drag.")
        }
        guard orderingDragLayoutGenerations[payload.dragToken] == layout.layoutGeneration else {
            return .rejected("The configuration changed after this drag began. Start a new drag.")
        }
        guard let subjectID = orderingSubject(forDragIdentifier: payload.bundleIdentifier) else {
            return .rejected("This item is no longer available.")
        }
        if case let .systemItem(item) = subjectID,
           !systemItems.contains(where: {
               availableSystemOrderingItem(for: $0.observationIdentifier) == item
           }) {
            return .rejected("This system item's exact sorting preflight is no longer available.")
        }
        let source = OrderingBoardLayoutItemID(
            subjectID: subjectID,
            sourcePolicy: payload.sourcePolicy,
            candidateGeneration: payload.candidateGeneration,
            layoutGeneration: layout.layoutGeneration
        )
        let updatedLayout: OrderingBoardLayoutDraft
        switch layout.moving(source, to: destination) {
        case let .success(updated):
            updatedLayout = updated
        case .failure(.sameItem), .failure(.unchanged):
            // A native drop back onto the item's effective source gap is a
            // completed delivery, but it changes neither policy nor order.
            // Retire only this payload so a later drag gets a fresh token while
            // the current layout generation remains valid.
            orderingConsumedDragTokens.insert(payload.dragToken)
            retireOrderingDragPayload(payload.id)
            return .unchanged
        case let .failure(rejection):
            return .rejected(orderingLayoutReason(rejection))
        }

        let policyChanged = payload.sourcePolicy != destination.policy
        if policyChanged {
            if case let .systemItem(item) = subjectID,
               !isControllableSystemItem(item.observationIdentifier) {
                return .rejected(
                    "Three-state visibility is unavailable for this system item."
                )
            }
            guard var editor = model else {
                return .rejected("This item is no longer available.")
            }
            switch subjectID {
            case .application:
                let assignment = assignmentCoordinator.assign(
                    payload: payload,
                    destination: destination.policy,
                    editor: &editor
                )
                guard assignment == .changed else {
                    if case let .rejected(reason) = assignment {
                        return .rejected(reason.interfaceReason)
                    }
                    return .rejected("The requested group did not change.")
                }
            case let .systemItem(item):
                switch editor.assignSystemItem(
                    identifier: item.observationIdentifier,
                    to: destination.policy
                ) {
                case .changed:
                    break
                case .unchanged:
                    return .rejected("The requested group did not change.")
                case .rejectedBlennyMustRemainVisible, .unknownCandidate:
                    return .rejected(
                        "This system item can be reordered in its current area, but its area assignment is unavailable."
                    )
                }
            }
            model = editor
            setStatus("Changes not applied", isError: false)
        }

        orderingConsumedDragTokens.insert(payload.dragToken)
        orderingDragLayoutGenerations.removeValue(forKey: payload.dragToken)
        installOrderingLayout(updatedLayout)
        orderingPresentation.isError = false
        // Editing never prepares or submits a system write. The Board is the preview.
        orderingPresentation.preview = nil
        orderingPresentation.requiresUndoReplacement = false
        orderingPresentation.message = nil
        orderingPresentation.technicalDetail = nil
        setStatus("Changes not applied", isError: false)
        if let model { orderingPresentation.onDraftChanged(model) }
        return .changed(policyChanged: policyChanged)
    }

    private func orderingSeed(for subjectID: OrderingSubjectID) -> (kind: Int, value: Double) {
        guard let row = orderingRow(for: subjectID) else {
            return (2, 0)
        }
        let configured = row.configuredPosition
            ?? row.currentPositionLabel.flatMap(Double.init)
        if let configured, configured.isFinite {
            // Preferred positions are trailing-edge priorities: larger values
            // appear farther left in the observed macOS 27 table.
            return (0, -configured)
        }
        if let observedX = row.observedX, observedX.isFinite {
            return (1, observedX)
        }
        return (2, 0)
    }

    private func orderingSeed(for bundleIdentifier: String) -> (kind: Int, value: Double) {
        orderingSeed(for: .application(bundleIdentifier))
    }

    func orderingSubject(forDragIdentifier identifier: String) -> OrderingSubjectID? {
        if let explicit = OrderingSubjectID(boardID: identifier) { return explicit }
        guard BundlePolicyIdentity.canonicalKey(for: identifier) != nil else { return nil }
        return .application(identifier)
    }

    func dragIdentifier(for subjectID: OrderingSubjectID) -> String {
        switch subjectID {
        case let .application(bundleIdentifier): bundleIdentifier
        case .systemItem: subjectID.boardID
        }
    }

    func effectiveOrderingPolicy(for subjectID: OrderingSubjectID) -> MenuBarBundlePolicy? {
        switch subjectID {
        case let .application(bundleIdentifier):
            return model?.effectivePolicy(for: bundleIdentifier)
        case let .systemItem(item):
            return effectiveSystemItemPolicy(for: item.observationIdentifier)
                ?? orderingRow(for: subjectID)?.policy
        }
    }

    func exactSystemOrderingItems(
        in policy: MenuBarBundlePolicy
    ) -> [ExactSystemBoardItem] {
        let rows = orderingPresentation.rows.compactMap { row -> ExactSystemBoardItem? in
            guard case let .systemItem(item) = row.subjectID,
                  effectiveOrderingPolicy(for: row.subjectID) == policy else { return nil }
            let observed = systemItems.first {
                availableSystemOrderingItem(
                    for: $0.observationIdentifier
                ) == item
            }
            guard let observation = observed else { return nil }
            return ExactSystemBoardItem(item: item, observation: observation, row: row)
        }
        guard let layout = orderingLayoutDraft else {
            return rows.sorted { orderingSeed(for: $0.subjectID).value < orderingSeed(for: $1.subjectID).value }
        }
        let rank = Dictionary(uniqueKeysWithValues: layout.subjects(in: policy).enumerated().map {
            ($0.element, $0.offset)
        })
        return rows.sorted {
            rank[$0.subjectID, default: .max] < rank[$1.subjectID, default: .max]
        }
    }

    func dragPayload(
        subjectID: OrderingSubjectID,
        sourcePolicy: MenuBarBundlePolicy
    ) -> PolicyDragPayload {
        dragPayload(
            bundleIdentifier: dragIdentifier(for: subjectID),
            sourcePolicy: sourcePolicy
        )
    }

    /// Resolves the current layout-bound payload when the native drag source
    /// asks for data. Repeated evaluations in one unchanged layout return the
    /// same payload; rebuilding the layout after Apply produces a new token.
    func beginOrderingDragPayload(
        subjectID: OrderingSubjectID,
        sourcePolicy: MenuBarBundlePolicy
    ) -> PolicyDragPayload? {
        // SwiftUI may evaluate its typed drag-source closure while merely
        // updating the view. Keep this lookup side-effect free; actual session
        // validation owns any user-facing refusal.
        guard !isApplying, !isRefreshing,
              !orderingPresentation.hasPendingRecovery else { return nil }
        guard let layout = orderingLayoutDraft,
              layout.candidateGeneration == candidateGeneration,
              layout.policy(of: subjectID) == sourcePolicy else { return nil }
        if case let .systemItem(item) = subjectID,
           !systemItems.contains(where: {
               availableSystemOrderingItem(for: $0.observationIdentifier) == item
           }) {
            return nil
        }
        return orderingDragPayload(
            subjectID: subjectID,
            sourcePolicy: sourcePolicy,
            layout: layout
        )
    }

    /// Ends the authority owned by one native drag session. The exact payload
    /// token keeps late cleanup from an older session from retiring a newer
    /// source, while the published revision remounts SwiftUI's drag provider
    /// even when the Board layout and policy draft did not change.
    func retireOrderingDragSession(_ identity: PolicyDragPayload.ID) {
        retireOrderingDragPayload(identity)
    }

    @discardableResult
    private func retireOrderingDragPayload(
        _ identity: PolicyDragPayload.ID
    ) -> Bool {
        orderingDragLayoutGenerations.removeValue(forKey: identity.dragToken)
        guard let replacement = orderingDragPayloads.replace(token: identity.dragToken),
              let layoutGeneration = orderingLayoutDraft?.layoutGeneration else {
            return false
        }
        orderingDragLayoutGenerations[replacement.dragToken] = layoutGeneration
        orderingDragSourceRevision &+= 1
        return true
    }

    /// Records a refusal only after the native drag/drop layer has observed a
    /// real session failure. Source payload lookup stays side-effect free.
    func rejectOrderingDrag(_ message: String) {
        guard !orderingPresentation.isError
                || orderingPresentation.message != message else { return }
        setOrderingStatus(message)
    }

    private func orderingLayoutReason(_ rejection: OrderingBoardLayoutRejection) -> String {
        switch rejection {
        case .staleCandidateGeneration, .staleLayoutGeneration:
            "The configuration changed after this drag began. Start a new drag."
        case .staleSourcePolicy:
            "This application moved after the drag began. Start a new drag."
        case let .missingDestination(bundleIdentifier):
            "The destination is no longer available: \(bundleIdentifier)."
        case .sameItem, .unchanged:
            "That drop would not change the configuration order."
        case .invalidBundleIdentifier, .duplicateBundleIdentifier:
            "The current application inventory cannot form a unique order."
        }
    }

    func requestOrderingInsertion(
        moving sourceBundleIdentifier: String,
        before targetBundleIdentifier: String,
        in policy: MenuBarBundlePolicy
    ) {
        guard let sourcePolicy = orderingLayoutDraft?.policy(of: sourceBundleIdentifier)
        else { return }
        let result = requestOrderingConfigurationDrop(
            payload: dragPayload(
                bundleIdentifier: sourceBundleIdentifier,
                sourcePolicy: sourcePolicy
            ),
            destination: OrderingBoardLayoutDestination(
                policy: policy,
                position: .before(targetBundleIdentifier)
            )
        )
        if case let .rejected(reason) = result { setOrderingStatus(reason) }
    }

    func requestOrderingMove(
        _ bundleIdentifier: String,
        direction: OrderingBoardMoveDirection,
        in policy: MenuBarBundlePolicy
    ) {
        guard let lane = orderingLayoutDraft?.bundleIdentifiers(in: policy),
              let index = lane.firstIndex(of: bundleIdentifier) else { return }
        let destination: OrderingBoardLayoutDestination
        switch direction {
        case .left:
            guard index > lane.startIndex else { return }
            destination = .init(policy: policy, position: .before(lane[index - 1]))
        case .right:
            guard index < lane.index(before: lane.endIndex) else { return }
            destination = .init(policy: policy, position: .after(lane[index + 1]))
        }
        let result = requestOrderingConfigurationDrop(
            payload: dragPayload(bundleIdentifier: bundleIdentifier, sourcePolicy: policy),
            destination: destination
        )
        if case let .rejected(reason) = result { setOrderingStatus(reason) }
    }

    func canRequestOrderingMove(
        _ bundleIdentifier: String,
        direction: OrderingBoardMoveDirection,
        in policy: MenuBarBundlePolicy
    ) -> Bool {
        guard !isApplying, !isRefreshing,
              let lane = orderingLayoutDraft?.bundleIdentifiers(in: policy),
              let index = lane.firstIndex(of: bundleIdentifier) else { return false }
        switch direction {
        case .left: return index > lane.startIndex
        case .right: return index < lane.index(before: lane.endIndex)
        }
    }

    private func orderingOwners(in policy: MenuBarBundlePolicy) -> [OrderingBoardOwner] {
        applicationCandidates(in: policy).map { candidate in
            let row = orderingRow(for: candidate.bundleIdentifier)
            return OrderingBoardOwner(
                bundleIdentifier: candidate.bundleIdentifier,
                observedX: row?.observedX,
                isEligible: row?.isEligible == true
            )
        }
    }

    private func handleOrderingArrangement(
        _ result: Result<
            OrderingBoardArrangementPlan,
            OrderingBoardArrangementRejection
        >
    ) {
        switch result {
        case let .success(plan):
            orderingPresentation.isError = false
            orderingPresentation.requestReorder(plan.desiredOrder)
        case let .failure(rejection):
            switch rejection {
            case let .ineligibleOwner(bundle), let .unverifiedOwner(bundle):
                let name = orderingRow(for: bundle)?.name ?? bundle
                setOrderingStatus("Cannot arrange this interval because of \(name). \(orderingExplanation(for: bundle))")
            default:
                setOrderingStatus(rejection.interfaceReason)
            }
        }
    }

    private func setOrderingStatus(_ message: String) {
        orderingPresentation.isError = true
        orderingPresentation.message = message
    }
    #endif

    func appleSystemCandidates(in policy: MenuBarBundlePolicy) -> [PolicyCandidate] {
        #if BLENNY_PRODUCT || DEBUG
        // Dedicated owner bundles participate in the same ordered lane. Shared
        // system modules remain in the separate policy-control presentation.
        []
        #else
        candidates(in: policy).filter {
            ExperimentalAppleBundlePolicyCatalog.contains($0.bundleIdentifier)
        }
        #endif
    }

    func candidate(bundleIdentifier: String) -> PolicyCandidate? {
        guard let canonical = BundlePolicyIdentity.canonicalKey(for: bundleIdentifier) else {
            return nil
        }
        return model?.candidateInventory.candidates.first {
            BundlePolicyIdentity.canonicalKey(for: $0.bundleIdentifier) == canonical
        }
    }

    func systemItem(observationIdentifier: String) -> SystemMenuBarItemObservation? {
        systemItems.first { $0.observationIdentifier == observationIdentifier }
    }

    func applicationIcon(for bundleIdentifier: String) -> ResolvedPolicyIcon {
        applicationIcons[bundleIdentifier]
            ?? iconResolver.applicationIcon(bundleIdentifier: bundleIdentifier)
    }

    func systemIcon(for observation: SystemMenuBarItemObservation) -> ResolvedPolicyIcon {
        systemIcons[observation.observationIdentifier]
            ?? iconResolver.systemIcon(observation: observation)
    }

    func isBlenny(_ bundleIdentifier: String) -> Bool {
        guard let model else { return false }
        return BundlePolicyIdentity.canonicalKey(for: bundleIdentifier)
            == BundlePolicyIdentity.canonicalKey(for: model.blennyBundleIdentifier)
    }

    func dragPayload(
        bundleIdentifier: String,
        sourcePolicy: MenuBarBundlePolicy
    ) -> PolicyDragPayload {
        #if BLENNY_PRODUCT || DEBUG
        if let subjectID = orderingSubject(forDragIdentifier: bundleIdentifier),
           let layout = orderingLayoutDraft,
           let payload = orderingDragPayload(
               subjectID: subjectID,
               sourcePolicy: sourcePolicy,
               layout: layout
           ) {
            return payload
        }
        #endif
        if let payload = preparedPolicyDragPayload(
            bundleIdentifier: bundleIdentifier,
            sourcePolicy: sourcePolicy
        ) {
            return payload
        }
        let payload = PolicyDragPayload(
            bundleIdentifier: bundleIdentifier,
            sourcePolicy: sourcePolicy,
            candidateGeneration: candidateGeneration
        )
        return payload
    }

    func preparedPolicyDragPayload(
        bundleIdentifier: String,
        sourcePolicy: MenuBarBundlePolicy
    ) -> PolicyDragPayload? {
        policyDragPayloads.payload(
            bundleIdentifier: bundleIdentifier,
            sourcePolicy: sourcePolicy,
            candidateGeneration: candidateGeneration
        )
    }

    private func preparePolicyDragPayloads() {
        policyDragPayloads.clear()
        guard let model else { return }

        for candidate in model.candidateInventory.candidates
            where !isBlenny(candidate.bundleIdentifier) {
            guard let policy = model.effectivePolicy(for: candidate.bundleIdentifier)
            else { continue }
            policyDragPayloads.prepare(
                bundleIdentifier: candidate.bundleIdentifier,
                sourcePolicy: policy,
                candidateGeneration: candidateGeneration
            )
        }

        for observation in systemItems {
            guard isControllableSystemItem(observation.observationIdentifier),
                  let identifier = systemItemPolicyIdentifier(
                for: observation.observationIdentifier
            ), let policy = effectiveSystemItemPolicy(
                for: observation.observationIdentifier
            ) else { continue }
            policyDragPayloads.prepare(
                bundleIdentifier: identifier,
                sourcePolicy: policy,
                candidateGeneration: candidateGeneration
            )
        }
    }

    func retireDragSession(_ identity: PolicyDragPayload.ID) {
        #if BLENNY_PRODUCT || DEBUG
        if retireOrderingDragPayload(identity) { return }
        #endif
        guard policyDragPayloads.replace(token: identity.dragToken) != nil else {
            return
        }
        policyDragSourceRevision &+= 1
    }

    #if BLENNY_PRODUCT || DEBUG
    private func installOrderingLayout(_ layout: OrderingBoardLayoutDraft?) {
        orderingLayoutDraft = layout
        orderingConsumedDragTokens.removeAll(keepingCapacity: true)
        orderingDragLayoutGenerations.removeAll(keepingCapacity: true)
        orderingDragPayloads.clear()
        preparePolicyDragPayloads()
        guard let layout else { return }

        for policy in MenuBarBundlePolicy.allCases {
            for subjectID in layout.subjects(in: policy) {
                let payload = orderingDragPayloads.prepare(
                    dragIdentifier: dragIdentifier(for: subjectID),
                    subjectID: subjectID,
                    sourcePolicy: policy,
                    candidateGeneration: candidateGeneration,
                    layoutGeneration: layout.layoutGeneration
                )
                orderingDragLayoutGenerations[payload.dragToken] = layout.layoutGeneration
            }
        }
    }

    private func orderingDragPayload(
        subjectID: OrderingSubjectID,
        sourcePolicy: MenuBarBundlePolicy,
        layout: OrderingBoardLayoutDraft
    ) -> PolicyDragPayload? {
        guard layout.candidateGeneration == candidateGeneration,
              layout.policy(of: subjectID) == sourcePolicy else { return nil }
        return orderingDragPayloads.payload(
            subjectID: subjectID,
            sourcePolicy: sourcePolicy,
            candidateGeneration: candidateGeneration,
            layoutGeneration: layout.layoutGeneration
        )
    }
    #endif

    /// Policy-only system items can be represented by a structured live
    /// observation while their draft is keyed by a canonical menu-extra ID.
    /// Keep that live identity out of the transferable payload so the shared
    /// assignment coordinator can validate and consume it normally.
    func systemPolicyDragPayload(
        for observationIdentifier: String,
        sourcePolicy: MenuBarBundlePolicy
    ) -> PolicyDragPayload? {
        guard isControllableSystemItem(observationIdentifier),
              let policyIdentifier = systemItemPolicyIdentifier(
            for: observationIdentifier
        ) else { return nil }
        return preparedPolicyDragPayload(
            bundleIdentifier: policyIdentifier,
            sourcePolicy: sourcePolicy
        )
    }

    func validateDrag(
        bundleIdentifier: String,
        sourcePolicy: MenuBarBundlePolicy,
        destination: MenuBarBundlePolicy
    ) -> PolicyDraftAssignmentOutcome {
        guard !isApplying, !isRefreshing, !requiresObservationRefresh else { return .rejected(.interactionInProgress) }
        guard let model else { return .rejected(.unknownCandidate) }
        return assignmentCoordinator.validate(
            payload: PolicyDragPayload(
                bundleIdentifier: bundleIdentifier,
                sourcePolicy: sourcePolicy,
                candidateGeneration: candidateGeneration
            ),
            destination: destination,
            editor: model
        )
    }

    @discardableResult
    func assign(
        payload: PolicyDragPayload,
        destination: MenuBarBundlePolicy
    ) -> PolicyDraftAssignmentOutcome {
        guard !isApplying, !isRefreshing, !requiresObservationRefresh else { return .rejected(.interactionInProgress) }
        guard var editor = model else { return .rejected(.unknownCandidate) }
        let outcome = assignmentCoordinator.assign(
            payload: payload,
            destination: destination,
            editor: &editor
        )
        if outcome.changedDraft {
            model = editor
            preparePolicyDragPayloads()
            #if BLENNY_PRODUCT || DEBUG
            orderingDragPayloads.clear()
            #endif
            setStatus("Changes not applied", isError: false)
        }
        return outcome
    }

    @discardableResult
    func assign(
        bundleIdentifier: String,
        destination: MenuBarBundlePolicy
    ) -> PolicyDraftAssignmentOutcome {
        guard !isApplying, !isRefreshing, !requiresObservationRefresh else { return .rejected(.interactionInProgress) }
        guard var editor = model else { return .rejected(.unknownCandidate) }
        let outcome = assignmentCoordinator.assign(
            bundleIdentifier: bundleIdentifier,
            destination: destination,
            editor: &editor
        )
        if outcome.changedDraft {
            model = editor
            preparePolicyDragPayloads()
            #if BLENNY_PRODUCT || DEBUG
            orderingDragPayloads.clear()
            #endif
            setStatus("Changes not applied", isError: false)
        }
        return outcome
    }

    @discardableResult
    func assignBluetooth(
        destination: MenuBarBundlePolicy
    ) -> PolicyDraftAssignmentOutcome {
        assignSystemItem(
            identifier: SystemMenuBarItemObservation.bluetoothIdentifier,
            destination: destination
        )
    }

    @discardableResult
    func assignSystemItem(
        identifier: String,
        destination: MenuBarBundlePolicy
    ) -> PolicyDraftAssignmentOutcome {
        guard !isApplying, !isRefreshing, !requiresObservationRefresh else {
            return .rejected(.interactionInProgress)
        }
        guard isControllableSystemItem(identifier),
              let policyIdentifier = systemItemPolicyIdentifier(for: identifier) else {
            return .rejected(.unknownCandidate)
        }
        guard var editor = model else { return .rejected(.unknownCandidate) }
        let result = editor.assignSystemItem(
            identifier: policyIdentifier,
            to: destination
        )
        let outcome: PolicyDraftAssignmentOutcome
        switch result {
        case .changed:
            outcome = .changed
        case .unchanged:
            outcome = .rejected(.samePolicy)
        case .unknownCandidate, .rejectedBlennyMustRemainVisible:
            outcome = .rejected(.unknownCandidate)
        }
        if outcome.changedDraft {
            model = editor
            preparePolicyDragPayloads()
            #if BLENNY_PRODUCT || DEBUG
            orderingDragPayloads.clear()
            #endif
            setStatus("Changes not applied", isError: false)
        }
        return outcome
    }

    @discardableResult
    func discardDraft() -> PolicyEditorViewModel? {
        guard !isApplying, !isRefreshing, !requiresObservationRefresh else { return nil }
        guard var editor = model else { return nil }
        editor.discardDraft(
            using: BundlePolicyDraft(acceptedPolicy: editor.acceptedPolicy)
        )
        assignmentCoordinator.replaceCandidateGeneration()
        candidateGeneration = assignmentCoordinator.candidateGeneration
        model = editor
        preparePolicyDragPayloads()
        #if BLENNY_PRODUCT || DEBUG
        resetOrderingLayoutDraft()
        orderingPresentation.preview = nil
        orderingPresentation.requiresUndoReplacement = false
        orderingPresentation.message = nil
        orderingPresentation.technicalDetail = nil
        #endif
        setStatus(
            "Changes discarded",
            isError: false
        )
        return editor
    }

    #if DEBUG
    func installPopulatedVisualValidationFixture(accessibilityTrusted: Bool) {
        let blenny = "xyz.fi5h.blenny"
        let safari = "com.apple.Safari"
        let fallback = "com.example.FallbackMenuAgentWithAnIntentionallyLongDisplayName"
        var observations: [MenuBarPolicyOwnershipObservation] = [
            (blenny, 10, 1),
            (safari, 20, 1),
            ("com.apple.mail", 30, 2),
            ("com.apple.Notes", 40, 1),
            ("com.apple.iCal", 50, 1),
            ("com.apple.TextEdit", 60, 1),
            ("com.apple.Preview", 70, 1),
            ("com.apple.ActivityMonitor", 80, 1),
            (fallback, 90, 3),
        ].map { bundleIdentifier, processIdentifier, itemCount in
            MenuBarPolicyOwnershipObservation(
                bundleIdentifier: bundleIdentifier,
                processIdentifier: processIdentifier,
                menuBarItemCount: itemCount
            )
        }
        if ProcessInfo.processInfo.environment["BLENNY_VALIDATE_LONG_LIST"] == "YES" {
            observations.append(contentsOf: (1...12).map { index in
                MenuBarPolicyOwnershipObservation(
                    bundleIdentifier: String(
                        format: "com.example.LongListMenuAgent%02d",
                        index
                    ),
                    processIdentifier: Int32(100 + index),
                    menuBarItemCount: index.isMultiple(of: 4) ? 2 : 1
                )
            })
        }
        let systemItems = [
            SystemMenuBarItemObservation(
                observationIdentifier: "com.apple.menuextra.wifi",
                ownerBundleIdentifier: "com.apple.controlcenter",
                displayName: "Wi-Fi",
                observationCount: 1
            ),
            SystemMenuBarItemObservation(
                observationIdentifier: "com.apple.menuextra.clock",
                ownerBundleIdentifier: "com.apple.controlcenter",
                displayName: "Clock",
                observationCount: 1
            ),
            SystemMenuBarItemObservation(
                observationIdentifier: "com.example.unknown-system-item",
                ownerBundleIdentifier: "com.apple.MenuBarAgent",
                displayName: "Unknown System Item With A Long Name",
                observationCount: 2
            ),
        ]

        do {
            let acceptedPolicy = try PersistentBundlePolicyDocument(
                managementEnabled: ProcessInfo.processInfo.environment[
                    "BLENNY_VALIDATE_MANAGEMENT_ENABLED"
                ] == "YES",
                policies: [
                    .init(bundleIdentifier: blenny, policy: .visible),
                    .init(bundleIdentifier: safari, policy: .revealable),
                    .init(bundleIdentifier: "com.apple.Notes", policy: .visible),
                    .init(bundleIdentifier: "com.apple.TextEdit", policy: .visible),
                    .init(bundleIdentifier: "com.apple.Preview", policy: .visible),
                    .init(bundleIdentifier: "com.apple.ActivityMonitor", policy: .visible),
                    .init(bundleIdentifier: "com.apple.mail", policy: .revealable),
                    .init(bundleIdentifier: "com.apple.iCal", policy: .hidden),
                ]
            )
            let fixture = try PolicyEditorViewModel(
                acceptedPolicy: acceptedPolicy,
                candidateInventory: PolicyCandidateInventory(observations: observations),
                systemItems: systemItems,
                blennyBundleIdentifier: blenny
            )
            display(
                model: fixture,
                observationCount: observations.count,
                recoveryAvailable: true
            )
            setAccessibilityTrusted(
                accessibilityTrusted,
                hasRequestedSystemPrompt: !accessibilityTrusted
            )
        } catch {
            setStatus("Visual validation fixture failed: \(error)", isError: true)
        }
    }

    #endif
}
