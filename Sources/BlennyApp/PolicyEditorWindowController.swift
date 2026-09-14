import AppKit
import BlennyCore
import Combine
import QuartzCore
import SwiftUI

@MainActor
struct ProductInterfaceActions {
    let refresh: () -> Void
    let requestAccess: () -> Void
    let resumeManaging: () -> Void
    let stopManaging: () -> Void
    let restorePreviousPolicy: () -> Void
    let draftDidChange: (PolicyEditorViewModel) -> Void
    let applyDraft: () -> Void
    let openProjectWebsite: () -> Void
    let openMonthlySponsor: () -> Void
    let openOneTimeSponsor: () -> Void
    let openKoFi: () -> Void
    let setLaunchAtLogin: (Bool) -> Void
    let openLoginItemsSettings: () -> Void
    let showFishPlacementGuide: () -> Void
    let hideSharedSystemItem: (SharedSystemItemTrialTarget) -> Void
    let restoreSharedSystemItem: (SharedSystemItemTrialTarget) -> Void
}

#if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
enum SharedSystemItemTrialPresentation: Equatable {
    case checking
    case ready
    case hidden
    case busy
    case recoveryRequired
    case unavailable(String)
}
#endif

struct ResolvedPolicyIcon {
    let descriptor: PolicyIconDescriptor
    let displayName: String
    let image: NSImage
}

#if DEBUG
enum OrderingBoardConfigurationMutationOutcome {
    case changed(policyChanged: Bool)
    case unchanged
    case rejected(String)
}
#endif

@MainActor
final class WorkspacePolicyIconResolver {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func applicationIcon(bundleIdentifier: String) -> ResolvedPolicyIcon {
        let semanticDescriptor = PolicyIconResolver.applicationDescriptor(
            bundleIdentifier: bundleIdentifier,
            installedApplicationResolved: false
        )
        if let displayName = ExperimentalAppleBundlePolicyCatalog.displayName(
            for: bundleIdentifier
        ), let symbolName = semanticDescriptor.symbolName,
           let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: displayName
           ) {
            return ResolvedPolicyIcon(
                descriptor: semanticDescriptor,
                displayName: displayName,
                image: sizedCopy(of: image)
            )
        }
        guard let applicationURL = workspace.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else {
            return fallback(displayName: fallbackDisplayName(for: bundleIdentifier))
        }

        let applicationBundle = Bundle(url: applicationURL)
        let displayName = applicationBundle?
            .object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? applicationBundle?
                .object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
            ?? FileManager.default.displayName(atPath: applicationURL.path)
        guard applicationBundle.flatMap(\.bundleIdentifier).flatMap({
            BundlePolicyIdentity.canonicalKey(for: $0)
        }) == BundlePolicyIdentity.canonicalKey(for: bundleIdentifier),
              applicationBundle.map(hasDeclaredApplicationIcon) == true else {
            return fallback(displayName: displayName)
        }
        let workspaceImage = workspace.icon(forFile: applicationURL.path)
        guard workspaceImage.isValid, !workspaceImage.representations.isEmpty else {
            return fallback(displayName: displayName)
        }
        return ResolvedPolicyIcon(
            descriptor: PolicyIconResolver.applicationDescriptor(
                bundleIdentifier: bundleIdentifier,
                installedApplicationResolved: true
            ),
            displayName: displayName,
            image: sizedCopy(of: workspaceImage)
        )
    }

    func systemIcon(observation: SystemMenuBarItemObservation) -> ResolvedPolicyIcon {
        let descriptor = PolicyIconResolver.systemItemDescriptor(
            observationIdentifier: observation.observationIdentifier
        )
        let image: NSImage?
        if let symbolName = descriptor.symbolName {
            image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: observation.displayName
            )
        } else if let namedImageName = descriptor.namedImageName {
            image = NSImage(named: NSImage.Name(namedImageName))
        } else {
            image = nil
        }
        guard let image else {
            return fallback(displayName: observation.displayName)
        }
        return ResolvedPolicyIcon(
            descriptor: descriptor,
            displayName: observation.displayName,
            image: sizedCopy(of: image)
        )
    }

    private func fallback(displayName: String) -> ResolvedPolicyIcon {
        let image = NSImage(
            systemSymbolName: PolicyIconDescriptor.fallbackSymbolName,
            accessibilityDescription: "Unknown item icon"
        ) ?? NSImage(size: NSSize(width: 38, height: 38))
        return ResolvedPolicyIcon(
            descriptor: .fallback,
            displayName: displayName,
            image: sizedCopy(of: image)
        )
    }

    private func fallbackDisplayName(for bundleIdentifier: String) -> String {
        bundleIdentifier.split(separator: ".").last.map(String.init) ?? bundleIdentifier
    }

    private func hasDeclaredApplicationIcon(_ bundle: Bundle) -> Bool {
        let stringKeys = ["CFBundleIconName", "CFBundleIconFile"]
        if stringKeys.contains(where: {
            (bundle.object(forInfoDictionaryKey: $0) as? String)?.isEmpty == false
        }) {
            return true
        }
        if let iconFiles = bundle.object(forInfoDictionaryKey: "CFBundleIconFiles")
            as? [String], !iconFiles.isEmpty {
            return true
        }
        if let icons = bundle.object(forInfoDictionaryKey: "CFBundleIcons")
            as? [String: Any], !icons.isEmpty {
            return true
        }
        return false
    }

    private func sizedCopy(of image: NSImage) -> NSImage {
        let copy = image.copy() as? NSImage ?? image
        copy.size = NSSize(width: 38, height: 38)
        return copy
    }
}

@MainActor
final class ProductInterfaceModel: ObservableObject {
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
    @Published private(set) var managementRuntimeState: ManagementLoopState = .unknown
    @Published private(set) var developmentMutationAvailable = false
    @Published private(set) var nativeOverflowPlacementAvailable = false
    #if DEBUG
    let orderingPresentation = DebugOrderingPresentation()
    @Published private(set) var orderingLayoutDraft: OrderingBoardLayoutDraft?
    @Published private(set) var orderingDragSourceRevision: UInt = 0
    private var orderingPresentationCancellable: AnyCancellable?
    private var orderingConsumedDragTokens: Set<UUID> = []
    private var orderingDragLayoutGenerations: [UUID: UUID] = [:]
    private var orderingDragPayloads = OrderingBoardDragPayloadRegistry()
    #endif
    #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    @Published private(set) var sharedSystemItemTrials = Dictionary(
        uniqueKeysWithValues: SharedSystemItemTrialTarget.allCases.map {
            ($0, SharedSystemItemTrialPresentation.checking)
        }
    )
    #endif

    private let iconResolver = WorkspacePolicyIconResolver()
    private var assignmentCoordinator = PolicyDraftAssignmentCoordinator()

    init() {
        #if DEBUG
        orderingPresentationCancellable = orderingPresentation.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
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
        #if DEBUG
        orderingPresentation.requiresObservationRefresh
        #else
        false
        #endif
    }

    var hasDraftChanges: Bool {
        if requiresObservationRefresh { return false }
        #if DEBUG
        return model?.hasDraftChanges == true || hasOrderingLayoutChanges
        #else
        return model?.hasDraftChanges == true
        #endif
    }
    var systemItems: [SystemMenuBarItemObservation] {
        var items = model?.systemItems ?? []
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        for target in SharedSystemItemTrialTarget.allCases {
            let presentation = sharedSystemItemTrialPresentation(for: target)
            guard presentation == .ready || presentation == .recoveryRequired,
                  !items.contains(where: {
                      sharedSystemItemTrialTarget(for: $0.observationIdentifier) == target
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
        return items.sorted {
            ($0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending)
        }
    }

    func systemItems(in policy: MenuBarBundlePolicy) -> [SystemMenuBarItemObservation] {
        systemItems.filter { observation in
            if isControllableSystemItem(observation.observationIdentifier) {
                return effectiveSystemItemPolicy(
                    for: observation.observationIdentifier
                ) == policy
            }
            return policy == .visible
        }
    }

    func isControllableSystemItem(_ observationIdentifier: String) -> Bool {
        systemItemPolicyIdentifier(for: observationIdentifier) != nil
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

    #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    func sharedSystemItemTrialTarget(
        for observationIdentifier: String
    ) -> SharedSystemItemTrialTarget? {
        SharedSystemItemTrialTarget.matchingSystemItem(
            observationIdentifier: observationIdentifier
        )
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
        #if DEBUG
        let previousOrderingLayout = preservingOrderingLayout
            ? orderingLayoutDraft : nil
        #endif
        self.model = model
        #if DEBUG
        orderingPresentation.requiresObservationRefresh = false
        #endif
        if !model.acceptedPolicy.managementEnabled {
            managementRuntimeState = .stopped
        }
        assignmentCoordinator.replaceCandidateGeneration()
        candidateGeneration = assignmentCoordinator.candidateGeneration
        #if DEBUG
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

        #if DEBUG
        if preservingOrderingLayout {
            if let previousOrderingLayout {
                if !restoreOrderingLayoutDraft(previousOrderingLayout) {
                    setOrderingStatus(
                        "The application scope changed during the management transition. Refresh the Board before arranging again."
                    )
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
        nativeOverflowPlacementAvailable = BlennyFishPlacement.guideAvailable(
            for: snapshot
        )
    }

    #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    func setSharedSystemItemTrial(
        _ target: SharedSystemItemTrialTarget,
        presentation: SharedSystemItemTrialPresentation
    ) {
        sharedSystemItemTrials[target] = presentation
    }
    #endif

    func setManagementRuntimeState(
        _ state: ManagementLoopState,
        developmentMutationAvailable: Bool
    ) {
        managementRuntimeState = state
        self.developmentMutationAvailable = developmentMutationAvailable
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
        #if DEBUG
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
        #if DEBUG
        candidates(in: policy)
        #else
        candidates(in: policy).filter {
            !ExperimentalAppleBundlePolicyCatalog.contains($0.bundleIdentifier)
        }
        #endif
    }

    #if DEBUG
    func orderingRow(for bundleIdentifier: String) -> DebugOrderingRow? {
        orderingRow(for: .application(bundleIdentifier))
    }

    func orderingRow(for subjectID: OrderingSubjectID) -> DebugOrderingRow? {
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
                return "This system control has no current preferred-position key, so it is not added to the ordered lane. \(row.reason ?? "")"
            }
            return "Its area can be edited, but its preferred position remains unchanged until the configuration key is identified. \(row.reason ?? "")"
        case .unverified:
            return "Mapping or observation is not fully verified yet. Its configuration position can still be arranged. \(row.reason ?? "")"
        case .blocked:
            return "Sorting unavailable. \(row.reason ?? "")"
        }
    }

    func initializeOrderingLayoutFromCurrentRows(force: Bool = false) {
        guard model != nil else {
            orderingLayoutDraft = nil
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
            orderingLayoutDraft = try OrderingBoardLayoutDraft(
                visibleSubjects: orderedSubjects(in: .visible),
                revealableSubjects: orderedSubjects(in: .revealable),
                hiddenSubjects: orderedSubjects(in: .hidden),
                candidateGeneration: candidateGeneration
            )
            orderingConsumedDragTokens.removeAll(keepingCapacity: true)
            orderingDragLayoutGenerations.removeAll(keepingCapacity: true)
            orderingDragPayloads.clear()
        } catch {
            orderingLayoutDraft = nil
            orderingConsumedDragTokens.removeAll(keepingCapacity: true)
            orderingDragLayoutGenerations.removeAll(keepingCapacity: true)
            orderingDragPayloads.clear()
            setOrderingStatus("The observed applications could not form one unique configuration order: \(error)")
        }
    }

    /// Rebinds the configuration that was just committed to the interface's
    /// new candidate generation. This uses the reviewed target order and the
    /// synchronized accepted policy, so drag availability does not depend on
    /// the optional post-commit physical observation succeeding.
    @discardableResult
    func installCommittedOrderingLayout(
        from request: DebugOrderingConfigurationRequest
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
            orderingLayoutDraft = try OrderingBoardLayoutDraft(
                visibleSubjects: subjects(in: .visible),
                revealableSubjects: subjects(in: .revealable),
                hiddenSubjects: subjects(in: .hidden),
                candidateGeneration: candidateGeneration
            )
            orderingConsumedDragTokens.removeAll(keepingCapacity: true)
            orderingDragLayoutGenerations.removeAll(keepingCapacity: true)
            orderingDragPayloads.clear()
            return true
        } catch {
            orderingLayoutDraft = nil
            orderingConsumedDragTokens.removeAll(keepingCapacity: true)
            orderingDragLayoutGenerations.removeAll(keepingCapacity: true)
            orderingDragPayloads.clear()
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
        orderingLayoutDraft = restored
        orderingConsumedDragTokens.removeAll(keepingCapacity: true)
        orderingDragLayoutGenerations.removeAll(keepingCapacity: true)
        orderingDragPayloads.clear()
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

    var currentOrderingConfigurationRequest: DebugOrderingConfigurationRequest? {
        orderingLayoutDraft.map(DebugOrderingConfigurationRequest.init)
    }

    var hasOrderingLayoutChanges: Bool {
        orderingLayoutDraft?.hasChanges == true
    }

    func resetOrderingLayoutDraft() {
        if let layout = orderingLayoutDraft {
            orderingLayoutDraft = try? OrderingBoardLayoutDraft(
                visible: layout.initialVisible,
                revealable: layout.initialRevealable,
                hidden: layout.initialHidden,
                candidateGeneration: candidateGeneration
            )
        }
        orderingConsumedDragTokens.removeAll(keepingCapacity: true)
        orderingDragLayoutGenerations.removeAll(keepingCapacity: true)
        orderingDragPayloads.clear()
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
        orderingLayoutDraft = updatedLayout
        orderingDragPayloads.clear()
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
    ) -> [DebugExactSystemBoardItem] {
        let rows = orderingPresentation.rows.compactMap { row -> DebugExactSystemBoardItem? in
            guard case let .systemItem(item) = row.subjectID,
                  item.isOrderingOffered,
                  effectiveOrderingPolicy(for: row.subjectID) == policy else { return nil }
            let observed = systemItems.first {
                ExactSystemOrderingItem(
                    observationIdentifier: $0.observationIdentifier
                ) == item
            }
            guard row.systemKey != nil || observed != nil else { return nil }
            let observation = observed ?? SystemMenuBarItemObservation(
                observationIdentifier: item.observationIdentifier,
                ownerBundleIdentifier: item.hostBundleIdentifier,
                displayName: item.displayName,
                observationCount: 0
            )
            return DebugExactSystemBoardItem(item: item, observation: observation, row: row)
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
        return dragPayload(subjectID: subjectID, sourcePolicy: sourcePolicy)
    }

    /// Ends the authority owned by one native drag session. The exact payload
    /// token keeps late cleanup from an older session from retiring a newer
    /// source, while the published revision remounts SwiftUI's drag provider
    /// even when the Board layout and policy draft did not change.
    func retireOrderingDragSession(_ identity: PolicyDragPayload.ID) {
        retireOrderingDragPayload(identity)
    }

    private func retireOrderingDragPayload(_ identity: PolicyDragPayload.ID) {
        orderingDragLayoutGenerations.removeValue(forKey: identity.dragToken)
        guard orderingDragPayloads.discard(token: identity.dragToken) else { return }
        orderingDragSourceRevision &+= 1
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
        #if DEBUG
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
        #if DEBUG
        if let subjectID = orderingSubject(forDragIdentifier: bundleIdentifier) {
            let layoutGeneration = orderingLayoutDraft?.layoutGeneration
                ?? candidateGeneration
            let payload = orderingDragPayloads.payload(
                dragIdentifier: bundleIdentifier,
                subjectID: subjectID,
                sourcePolicy: sourcePolicy,
                candidateGeneration: candidateGeneration,
                layoutGeneration: layoutGeneration
            )
            if orderingLayoutDraft?.policy(of: subjectID) == sourcePolicy {
                orderingDragLayoutGenerations[payload.dragToken] = layoutGeneration
            }
            return payload
        }
        #endif
        let payload = PolicyDragPayload(
            bundleIdentifier: bundleIdentifier,
            sourcePolicy: sourcePolicy,
            candidateGeneration: candidateGeneration
        )
        return payload
    }

    /// Policy-only system items can be represented by a structured live
    /// observation while their draft is keyed by a canonical menu-extra ID.
    /// Keep that live identity out of the transferable payload so the shared
    /// assignment coordinator can validate and consume it normally.
    func systemPolicyDragPayload(
        for observationIdentifier: String,
        sourcePolicy: MenuBarBundlePolicy
    ) -> PolicyDragPayload? {
        guard let policyIdentifier = systemItemPolicyIdentifier(
            for: observationIdentifier
        ) else { return nil }
        return dragPayload(
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
            #if DEBUG
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
            #if DEBUG
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
        guard let policyIdentifier = systemItemPolicyIdentifier(for: identifier) else {
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
            #if DEBUG
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
        #if DEBUG
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

@MainActor
final class PolicyEditorWindowController: NSWindowController {
    private static let fixedContentHeight: CGFloat = 420
    private static let organizePreferredContentSize = NSSize(width: 980, height: fixedContentHeight)
    private static let organizeMinimumContentSize = NSSize(width: 800, height: fixedContentHeight)
    private static let compactPreferredContentSize = NSSize(width: 680, height: fixedContentHeight)
    private static let compactMinimumContentSize = NSSize(width: 560, height: fixedContentHeight)
    #if DEBUG
    private static let minimumSizeValidationEnvironmentKey =
        "BLENNY_VALIDATE_MINIMUM_WINDOW_SIZE"
    private static let darkAppearanceValidationEnvironmentKey =
        "BLENNY_VALIDATE_DARK_APPEARANCE"
    private static let initialSectionValidationEnvironmentKey =
        "BLENNY_VALIDATE_INITIAL_SECTION"
    private static let populatedValidationEnvironmentKey =
        "BLENNY_VALIDATE_POPULATED_INTERFACE"
    private static let untrustedValidationEnvironmentKey =
        "BLENNY_VALIDATE_UNTRUSTED_INTERFACE"
    private static let refreshingValidationEnvironmentKey =
        "BLENNY_VALIDATE_REFRESHING_INTERFACE"
    private static let draftValidationEnvironmentKey =
        "BLENNY_VALIDATE_DRAFT_INTERFACE"
    private static let errorValidationEnvironmentKey =
        "BLENNY_VALIDATE_ERROR_INTERFACE"
    #endif

    private let interfaceModel = ProductInterfaceModel()
    private let usesPopulatedValidationFixture: Bool
    private var navigationCancellable: AnyCancellable?

    init(
        onRefresh: @escaping () -> Void,
        onRequestAccess: @escaping () -> Void,
        onResumeManaging: @escaping () -> Void,
        onStopManaging: @escaping () -> Void,
        onRestorePreviousPolicy: @escaping () -> Void,
        onDraftDidChange: @escaping (PolicyEditorViewModel) -> Void,
        onApplyDraft: @escaping () -> Void,
        onOpenProjectWebsite: @escaping () -> Void,
        onOpenMonthlySponsor: @escaping () -> Void,
        onOpenOneTimeSponsor: @escaping () -> Void,
        onOpenKoFi: @escaping () -> Void,
        onSetLaunchAtLogin: @escaping (Bool) -> Void,
        onOpenLoginItemsSettings: @escaping () -> Void,
        onShowFishPlacementGuide: @escaping () -> Void,
        onHideSharedSystemItem: @escaping (SharedSystemItemTrialTarget) -> Void,
        onRestoreSharedSystemItem: @escaping (SharedSystemItemTrialTarget) -> Void
    ) {
        #if DEBUG
        usesPopulatedValidationFixture = ProcessInfo.processInfo.environment[
            Self.populatedValidationEnvironmentKey
        ] == "YES"
        if ProcessInfo.processInfo.environment[
            Self.darkAppearanceValidationEnvironmentKey
        ] == "YES" {
            NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        }
        if let rawSection = ProcessInfo.processInfo.environment[
            Self.initialSectionValidationEnvironmentKey
        ], let section = ProductInterfaceSection(rawValue: rawSection) {
            interfaceModel.navigate(to: section)
        }
        if usesPopulatedValidationFixture {
            interfaceModel.installPopulatedVisualValidationFixture(
                accessibilityTrusted: ProcessInfo.processInfo.environment[
                    Self.untrustedValidationEnvironmentKey
                ] != "YES"
            )
            if ProcessInfo.processInfo.environment[
                Self.refreshingValidationEnvironmentKey
            ] == "YES" {
                interfaceModel.setRefreshing(true)
            }
            if ProcessInfo.processInfo.environment[
                Self.draftValidationEnvironmentKey
            ] == "YES" {
                _ = interfaceModel.assign(
                    bundleIdentifier: "com.apple.Safari",
                    destination: .hidden
                )
            }
            if ProcessInfo.processInfo.environment[
                Self.errorValidationEnvironmentKey
            ] == "YES" {
                interfaceModel.setStatus(
                    "The last bounded observation was incomplete. No policy changed.",
                    isError: true
                )
            }
        }
        #else
        usesPopulatedValidationFixture = false
        #endif

        let actions = ProductInterfaceActions(
            refresh: onRefresh,
            requestAccess: onRequestAccess,
            resumeManaging: onResumeManaging,
            stopManaging: onStopManaging,
            restorePreviousPolicy: onRestorePreviousPolicy,
            draftDidChange: onDraftDidChange,
            applyDraft: onApplyDraft,
            openProjectWebsite: onOpenProjectWebsite,
            openMonthlySponsor: onOpenMonthlySponsor,
            openOneTimeSponsor: onOpenOneTimeSponsor,
            openKoFi: onOpenKoFi,
            setLaunchAtLogin: onSetLaunchAtLogin,
            openLoginItemsSettings: onOpenLoginItemsSettings,
            showFishPlacementGuide: onShowFishPlacementGuide,
            hideSharedSystemItem: onHideSharedSystemItem,
            restoreSharedSystemItem: onRestoreSharedSystemItem
        )
        let rootView = BlennyRootView(model: interfaceModel, actions: actions)
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = []

        #if DEBUG
        let initialContentSize = ProcessInfo.processInfo.environment[
            Self.minimumSizeValidationEnvironmentKey
        ] == "YES"
            ? Self.minimumContentSize(for: interfaceModel.navigation.section)
            : Self.preferredContentSize(for: interfaceModel.navigation.section)
        #else
        let initialContentSize = Self.preferredContentSize(
            for: interfaceModel.navigation.section
        )
        #endif

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.5.0"
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        #if BLENNY_FALLBACK_POSITION_TRIAL
        window.title = "Blenny \(version) · Arrow Position Trial"
        #elseif BLENNY_NATIVE_BOUNDARY_TRIAL
        window.title = "Blenny \(version) · Native Boundary Trial"
        #elseif BLENNY_GROUPED_FALLBACK_TRIAL
        window.title = "Blenny \(version) · Grouped Click Trial"
        #else
        window.title = "Blenny \(version) · Experimental"
        #endif
        #else
        window.title = "Blenny \(version)"
        #endif
        window.toolbarStyle = .unified
        window.contentMinSize = Self.minimumContentSize(
            for: interfaceModel.navigation.section
        )
        window.contentMaxSize = NSSize(width: .greatestFiniteMagnitude, height: Self.fixedContentHeight)
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.setContentSize(initialContentSize)
        window.center()

        super.init(window: window)

        navigationCancellable = interfaceModel.$navigation
            .map(\.section)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] section in
                Task { @MainActor [weak self] in
                    self?.resizeWindow(for: section)
                }
            }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showEditor() {
        showWindow(nil)
        restoreUsableWindowSizeIfNeeded()
        window?.orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func setAccessibilityTrusted(
        _ trusted: Bool,
        hasRequestedSystemPrompt: Bool
    ) {
        guard !usesPopulatedValidationFixture else { return }
        interfaceModel.setAccessibilityTrusted(
            trusted,
            hasRequestedSystemPrompt: hasRequestedSystemPrompt
        )
    }

    func setRefreshing(_ refreshing: Bool) {
        guard !usesPopulatedValidationFixture else { return }
        interfaceModel.setRefreshing(refreshing)
    }

    func display(
        model: PolicyEditorViewModel,
        observationCount: Int,
        recoveryAvailable: Bool,
        preservingOrderingLayout: Bool = false
    ) {
        guard !usesPopulatedValidationFixture else { return }
        interfaceModel.display(
            model: model,
            observationCount: observationCount,
            recoveryAvailable: recoveryAvailable,
            preservingOrderingLayout: preservingOrderingLayout
        )
    }

    var candidateGeneration: UUID {
        interfaceModel.candidateGeneration
    }

    var hasDraftChanges: Bool { interfaceModel.hasDraftChanges }
    var requiresObservationRefresh: Bool { interfaceModel.requiresObservationRefresh }

    #if DEBUG
    var orderingPresentation: DebugOrderingPresentation {
        interfaceModel.orderingPresentation
    }

    func initializeOrderingLayoutFromCurrentRows(force: Bool = false) {
        interfaceModel.initializeOrderingLayoutFromCurrentRows(force: force)
    }

    @discardableResult
    func installCommittedOrderingLayout(
        from request: DebugOrderingConfigurationRequest
    ) -> Bool {
        interfaceModel.installCommittedOrderingLayout(from: request)
    }

    var currentOrderingConfigurationRequest: DebugOrderingConfigurationRequest? {
        interfaceModel.currentOrderingConfigurationRequest
    }

    var hasOrderingLayoutChanges: Bool {
        interfaceModel.hasOrderingLayoutChanges
    }

    func discardOrderingLayoutDraft() {
        interfaceModel.discardOrderingLayoutDraft()
    }

    func resetOrderingLayoutDraft() {
        interfaceModel.resetOrderingLayoutDraft()
    }

    @discardableResult
    func discardConfigurationDraft() -> PolicyEditorViewModel? {
        interfaceModel.discardDraft()
    }
    #endif

    func setDiscoveryWarnings(_ warnings: [String]) {
        interfaceModel.discoveryWarnings = warnings
    }

    #if DEBUG
    func debugPresentationSummary(for bundleIdentifier: String) -> String {
        let icon = interfaceModel.applicationIcons.first {
            $0.key.lowercased() == bundleIdentifier.lowercased()
        }?.value
        return "presentationIcon=\(icon != nil) iconSource=\(icon.map { String(describing: $0.descriptor) } ?? "none")"
    }
    #endif

    #if DEBUG
    var debugResumeEnabled: Bool { interfaceModel.controls.resumeEnabled }
    #endif

    func setManagementRuntimeState(
        _ state: ManagementLoopState,
        developmentMutationAvailable: Bool
    ) {
        guard !usesPopulatedValidationFixture else { return }
        interfaceModel.setManagementRuntimeState(
            state,
            developmentMutationAvailable: developmentMutationAvailable
        )
    }

    func setStatus(_ message: String, isError: Bool) {
        guard !usesPopulatedValidationFixture else { return }
        interfaceModel.setStatus(message, isError: isError)
    }

    func setLaunchAtLoginState(_ state: LaunchAtLoginPresentationState) {
        interfaceModel.setLaunchAtLoginState(state)
    }

    func setNativeOverflowPlacement(
        _ snapshot: NativeOverflowObservationSnapshot
    ) {
        interfaceModel.setNativeOverflowPlacement(snapshot)
    }

    #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    func setSharedSystemItemTrial(
        _ target: SharedSystemItemTrialTarget,
        presentation: SharedSystemItemTrialPresentation
    ) {
        interfaceModel.setSharedSystemItemTrial(target, presentation: presentation)
    }
    #endif

    func setApplying(_ applying: Bool) {
        interfaceModel.setApplying(applying)
    }

    private func restoreUsableWindowSizeIfNeeded() {
        guard let window else { return }
        window.contentMinSize = NSSize(width: 560, height: Self.fixedContentHeight)
        let size = window.contentLayoutRect.size
        if size.width < 560 || abs(size.height - Self.fixedContentHeight) > 1 {
            resizeWindow(for: interfaceModel.navigation.section)
        }
    }

    private func resizeWindow(for section: ProductInterfaceSection) {
        guard let window else { return }
        let preferredContentSize = Self.preferredContentSize(for: section)
        let oldFrame = window.frame
        let targetContentSize = NSSize(
            width: preferredContentSize.width,
            height: Self.fixedContentHeight
        )
        var contentRect = window.contentRect(forFrameRect: oldFrame)
        contentRect.size = targetContentSize
        var newFrame = window.frameRect(forContentRect: contentRect)
        newFrame.origin.x = oldFrame.origin.x
        newFrame.origin.y = oldFrame.maxY - newFrame.height
        window.contentMinSize = NSSize(width: 560, height: Self.fixedContentHeight)
        let settleMinimumSize: @Sendable () -> Void = { [weak self, weak window] in
            Task { @MainActor [weak self, weak window] in
                guard let self, let window, interfaceModel.navigation.section == section,
                      abs(window.contentLayoutRect.width - targetContentSize.width) < 1 else { return }
                window.contentMinSize = NSSize(
                    width: section == .organize ? 800 : 560, height: Self.fixedContentHeight
                )
            }
        }
        if effectiveReduceMotion {
            window.setFrame(newFrame, display: true)
            settleMinimumSize()
        } else {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.30
                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: 0.25,
                    0.10,
                    0.25,
                    1.00
                )
                window.animator().setFrame(newFrame, display: true)
            }, completionHandler: settleMinimumSize)
        }
    }

    private var effectiveReduceMotion: Bool {
        let systemPrefersReducedMotion = NSWorkspace.shared
            .accessibilityDisplayShouldReduceMotion
        #if DEBUG
        let debugPrefersReducedMotion = ProcessInfo.processInfo.environment[
            "BLENNY_VALIDATE_REDUCE_MOTION"
        ] == "YES"
        return systemPrefersReducedMotion || debugPrefersReducedMotion
        #else
        return systemPrefersReducedMotion
        #endif
    }

    private static func preferredContentSize(
        for section: ProductInterfaceSection
    ) -> NSSize {
        switch section {
        case .organize: organizePreferredContentSize
        case .settings, .support: compactPreferredContentSize
        }
    }

    private static func minimumContentSize(
        for section: ProductInterfaceSection
    ) -> NSSize {
        switch section {
        case .organize: organizeMinimumContentSize
        case .settings, .support: compactMinimumContentSize
        }
    }
}
