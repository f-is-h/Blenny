import AppKit
import BlennyCore
import SwiftUI

struct OrganizeView: View {
    @ObservedObject var model: ProductInterfaceModel
    let actions: ProductInterfaceActions
    @Binding var interaction: PolicyBoardInteractionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showsItemControls = false
    @State private var showsSystemDetails = false
    @State private var showsStatusDetails = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                managementStrip
                HStack {
                    Text("Drag & Drop icons")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
                    if model.sharedSystemItemTrials.values.contains(where: { state in
                        switch state {
                        case .recoveryRequired: model.managementEnabled == false
                        case .busy, .unavailable: true
                        default: false
                        }
                    }) {
                        Button(model.managementEnabled == false && model.sharedSystemItemTrials.values.contains(.recoveryRequired)
                               ? "Visibility recovery…" : "System item details…") { showsSystemDetails = true }
                            .controlSize(.small)
                            .popover(isPresented: $showsSystemDetails) {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 12) {
                #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
                ForEach(SharedSystemItemTrialTarget.allCases, id: \.self) { target in
                    switch model.sharedSystemItemTrials[target] ?? .checking {
                    case .recoveryRequired:
                        if model.managementEnabled == false {
                            HStack {
                                Label("\(target.displayName): visibility recovery needed", systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                                Spacer()
                                Button("Restore Visibility") {
                                    actions.restoreSharedSystemItem(target)
                                }
                                .disabled(model.isApplying || model.isRefreshing || model.sharedSystemItemTrials.values.contains(.busy))
                                .accessibilityLabel("Restore \(target.displayName) visibility")
                            }
                            .font(.callout)
                            .controlSize(.small)
                            .padding(.horizontal, 10)
                        }
                    case .busy:
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Updating \(target.displayName) visibility…")
                            Spacer()
                        }
                        .font(.callout)
                        .padding(.horizontal, 10)
                    case .unavailable(let detail):
                        DisclosureGroup("\(target.displayName) unavailable") {
                            Text(detail)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                        .font(.callout)
                        .padding(.horizontal, 10)
                    case .ready, .hidden, .checking:
                        EmptyView()
                    }
                }
                #endif
                                    }
                                    .padding(16)
                                }
                                .frame(width: 480, height: 280)
                            }
                    }
                    #endif
                    Button("Item controls", systemImage: "slider.horizontal.3") {
                        showsItemControls = true
                    }
                    .controlSize(.small)
                    .popover(isPresented: $showsItemControls) {
                        SelectionDetailRail(
                            model: model,
                            interaction: $interaction,
                            actions: actions,
                            onMove: performMove
                        )
                        .padding(12)
                        .frame(width: 580)
                    }
                    .help("Select an icon, then open its movement controls and details.")
                }
                OrganizationBoard(
                    model: model,
                    actions: actions,
                    interaction: $interaction
                )
                #if BLENNY_PRODUCT || DEBUG
                OrderingStatusBar(
                    presentation: model.orderingPresentation,
                    managementEnabled: model.managementEnabled,
                    hasDraftChanges: model.hasDraftChanges
                )
                #endif
                if model.statusIsError {
                    statusMessage
                }

            }
            .padding(.horizontal, 18)
            .padding(.top, 9)
            .padding(.bottom, 7)
            .fixedSize(horizontal: false, vertical: true)


            Spacer(minLength: 0)
            Divider()
            ObservationAndDraftFooter(
                model: model,
                actions: actions,
                interaction: $interaction
            )
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var managementStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: managementSymbol)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(managementColor)
            Text(managementTitle)
                .font(.system(.subheadline, weight: .medium))
            Text(managementDetail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 10)
            if model.managementEnabled == true {
                Button("Stop", action: actions.stopManaging)
                    .disabled(!model.controls.stopEnabled)
            } else {
                Button("Resume", action: actions.resumeManaging)
                    .disabled(!model.controls.resumeEnabled)
            }
            Button("Restore Visibility", action: actions.restorePreviousPolicy)
                .disabled(!model.controls.restoreEnabled)
                .help("Restore the previous visibility settings. Applied order stays unchanged.")
        }
        .controlSize(.small)
        .padding(.horizontal, 10)
        .frame(minHeight: 31)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.46))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Management and recovery")
    }

    private var statusMessage: some View {
        HStack(spacing: 7) {
            Image(systemName: "xmark.circle.fill")
            Text(model.statusMessage).lineLimit(1)
            Button("Details…") { showsStatusDetails = true }
                .controlSize(.small)
                .popover(isPresented: $showsStatusDetails) {
                    ScrollView {
                        Text(model.statusMessage)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .frame(width: 460, height: 240)
                }
            Spacer(minLength: 0)
        }
        .font(.callout)
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func performMove(
        bundleIdentifier: String,
        destination: MenuBarBundlePolicy
    ) {
        if model.isControllableSystemItem(bundleIdentifier) {
            let outcome = model.assignSystemItem(
                identifier: bundleIdentifier,
                destination: destination
            )
            handleAssignmentOutcome(outcome)
            return
        }
        guard let source = model.model?.effectivePolicy(for: bundleIdentifier) else { return }
        let payload = model.dragPayload(
            bundleIdentifier: bundleIdentifier,
            sourcePolicy: source
        )
        var outcome = PolicyDraftAssignmentOutcome.rejected(.unknownCandidate)
        withAnimation(
            assignmentAnimation,
            completionCriteria: .logicallyComplete
        ) {
            outcome = model.assign(payload: payload, destination: destination)
            interaction.completeDrop(
                payload: payload,
                destination: destination,
                outcome: outcome
            )
        } completion: {
            interaction.finishSettling(token: payload.dragToken)
        }
        handleAssignmentOutcome(outcome)
    }

    private var assignmentAnimation: Animation {
        effectiveReduceMotion
            ? .easeOut(duration: 0.10)
            : .smooth(duration: 0.23, extraBounce: 0)
    }

    private var effectiveReduceMotion: Bool {
        reduceMotion || debugAccessibilityFlag("BLENNY_VALIDATE_REDUCE_MOTION")
    }

    private func handleAssignmentOutcome(_ outcome: PolicyDraftAssignmentOutcome) {
        switch outcome {
        case .changed:
            if let editor = model.model { actions.draftDidChange(editor) }
        case .rejected(.samePolicy):
            break
        case .rejected(let reason):
            model.setStatus(reason.interfaceReason, isError: true)
        }
    }

    private var managementPresentation: ProductManagementPresentation {
        ProductManagementPresentation(state: model.managementRuntimeState)
    }
    private var managementTitle: String { managementPresentation.title }
    private var managementDetail: String { managementPresentation.detail }
    private var managementSymbol: String { managementPresentation.symbolName }
    private var managementColor: Color {
        managementPresentation.isError ? .red : .secondary
    }

    #if BLENNY_PRODUCT || DEBUG
    private var debugBoardFooter: String {
        if model.orderingLayoutDraft?.hasChanges == true {
            return "Configuration draft · Global target: Hidden → Revealable → Visible · Apply reports any owner that still needs mapping"
        }
        return "Drag before, after, or to the end of any area · Missing mapping remains informational · No polling"
    }
    #endif
}

struct OrganizationBoard: View {
    @ObservedObject var model: ProductInterfaceModel
    let actions: ProductInterfaceActions
    @Binding var interaction: PolicyBoardInteractionState
    @Namespace private var iconNamespace
    @State private var activeDragSessionID: DragSession.ID?
    @State private var activeDragIdentity: PolicyDragPayload.ID?
    @State private var deliveryReceipt = PolicyDragDeliveryReceipt<DropSession.ID>()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private func hintItemCount(in policy: MenuBarBundlePolicy) -> Int {
        model.applicationCandidates(in: policy).count
            + model.appleSystemCandidates(in: policy).count
            + model.systemItems(in: policy).count
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(Array(MenuBarBundlePolicy.allCases.enumerated()), id: \.element) {
                    index, policy in
                    if index > 0 {
                        Rectangle()
                            .fill(Color(nsColor: .separatorColor).opacity(0.34))
                            .frame(height: 0.5)
                            .padding(.horizontal, 12)
                            .accessibilityHidden(true)
                    }
                    #if BLENNY_PRODUCT || DEBUG
                    PolicyLaneRow(
                        policy: policy,
                        model: model,
                        actions: actions,
                        interaction: $interaction,
                        iconNamespace: iconNamespace,
                        reduceMotion: effectiveReduceMotion,
                        contrast: effectiveContrast,
                        onDrop: commitDrop,
                        registerDelivery: registerDelivery,
                        hasRegisteredDelivery: hasRegisteredDelivery,
                        onLayoutDrop: commitLayoutDrop
                    )
                    #else
                    PolicyLaneRow(
                        policy: policy,
                        model: model,
                        actions: actions,
                        interaction: $interaction,
                        iconNamespace: iconNamespace,
                        reduceMotion: effectiveReduceMotion,
                        contrast: effectiveContrast,
                        onDrop: commitDrop,
                        registerDelivery: registerDelivery,
                        hasRegisteredDelivery: hasRegisteredDelivery
                    )
                    #endif
                }
            }
            .background(boardSurface)
            .overlay {
                GeometryReader { geometry in
                    let count = max(hintItemCount(in: .revealable), hintItemCount(in: .hidden))
                    if geometry.size.width - 260 - CGFloat(count) * 50 >= 220 {
                        HStack(spacing: 10) {
                            Image(systemName: "hand.draw")
                                .font(.system(size: 35, weight: .ultraLight))
                            Text("Drag & Drop")
                                .font(.system(size: 16, weight: .light))
                                .italic()
                        }
                        .foregroundStyle(.secondary.opacity(0.28))
                        .rotationEffect(.degrees(-13))
                        .position(x: geometry.size.width - 115, y: geometry.size.height * 2 / 3)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .opacity(boardIsObscured ? 0.24 : 1)
            .allowsHitTesting(!boardIsObscured)
            .accessibilityHidden(boardIsObscured)

            if model.isRefreshing {
                BoardInterruptionPanel(
                    symbol: nil,
                    title: "Refreshing menu bar items",
                    message: "Updating your menu bar items…",
                    actionTitle: nil,
                    action: nil,
                    reduceTransparency: effectiveReduceTransparency
                )
            } else if model.requiresObservationRefresh {
                BoardInterruptionPanel(
                    symbol: "checkmark.circle", title: "Refresh needed",
                    message: "Choose Refresh to update the Board.",
                    actionTitle: nil, action: nil,
                    reduceTransparency: effectiveReduceTransparency
                )
            } else if !model.accessibilityTrusted {
                BoardInterruptionPanel(
                    symbol: "hand.raised.fill",
                    title: "Allow Blenny to read menu bar items",
                    message: permissionMessage,
                    actionTitle: permissionButtonTitle,
                    action: actions.requestAccess,
                    reduceTransparency: effectiveReduceTransparency
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: BlennyDesign.boardRadius))
        .overlay {
            if effectiveContrast == .increased {
                RoundedRectangle(cornerRadius: BlennyDesign.boardRadius)
                    .stroke(Color.primary.opacity(0.7), lineWidth: 1.5)
            }
        }
        .diagnosticBoardSession(updateDragSession)
        #if DEBUG
        .onChange(of: interaction) { _, _ in
            DebugDragStartDiagnostics.record("board.interaction.changed", stack: true)
        }
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Organization Board")
    }

    private func updateDragSession(_ session: DragSession) {
        #if DEBUG
        DebugDragStartDiagnostics.record("board.dragSession.\(String(describing: session.phase))")
        #endif
        let identities = session.draggedItemIDs(for: PolicyDragPayload.ID.self)
        #if DEBUG
        DebugDragStartDiagnostics.record("board.identityCount.\(identities.count)")
        #endif
        guard identities.count == 1, let identity = identities.first else {
            switch session.phase {
            case .ended(let operation) where operation != .move:
                endDragSessionIfCurrent(session.id, retirePayload: true)
            case .dataTransferCompleted:
                endDragSessionIfCurrent(session.id)
            default:
                break
            }
            return
        }

        let animation: Animation = effectiveReduceMotion
            ? .easeOut(duration: 0.08)
            : .smooth(duration: 0.14, extraBounce: 0)
        withAnimation(animation) {
            switch session.phase {
            case .initial, .active:
                if activeDragSessionID != session.id
                    || activeDragIdentity != identity {
                    activeDragSessionID = session.id
                    activeDragIdentity = identity
                }
                if interaction.draggedBundleIdentifier != identity.bundleIdentifier
                    || interaction.draggedSourcePolicy != identity.sourcePolicy {
                    interaction.beginDrag(
                        bundleIdentifier: identity.bundleIdentifier,
                        sourcePolicy: identity.sourcePolicy
                    )
                }
            case .ended(let operation):
                // Successful local moves deliver typed data after pointer end.
                // Cancellation has no later delivery and must clean up now.
                if operation != .move,
                   activeDragSessionID == session.id,
                   activeDragIdentity == identity {
                    endDragSessionIfCurrent(session.id, retirePayload: true)
                }
            case .dataTransferCompleted:
                if activeDragSessionID == session.id,
                   activeDragIdentity == identity {
                    endDragSessionIfCurrent(session.id)
                }
            @unknown default:
                endDragSessionIfCurrent(session.id, retirePayload: true)
            }
        }
    }

    private func endDragSessionIfCurrent(
        _ sessionID: DragSession.ID,
        retirePayload: Bool = false
    ) {
        guard activeDragSessionID == sessionID else { return }
        let identity = activeDragIdentity
        if interaction.settleState == nil {
            interaction.endDragWithoutDrop()
        }
        activeDragSessionID = nil
        activeDragIdentity = nil
        if retirePayload, let identity {
            model.retireDragSession(identity)
        }
    }

    private func registerDelivery(
        sessionID: DropSession.ID,
        payloadID: PolicyDragPayload.ID
    ) -> PolicyDragDeliveryRegistration {
        deliveryReceipt.register(sessionID: sessionID, payloadID: payloadID)
    }

    private func hasRegisteredDelivery(
        sessionID: DropSession.ID,
        payloadID: PolicyDragPayload.ID
    ) -> Bool {
        deliveryReceipt.contains(sessionID: sessionID, payloadID: payloadID)
    }

    private var boardIsObscured: Bool {
        !model.accessibilityTrusted || model.isRefreshing || model.isApplying || model.requiresObservationRefresh
    }

    private var boardSurface: Color {
        if effectiveReduceTransparency {
            return Color(nsColor: .controlBackgroundColor)
        }
        return Color.primary.opacity(
            effectiveContrast == .increased ? 0.06 : 0.022
        )
    }

    private func commitDrop(
        payload: PolicyDragPayload,
        destination: MenuBarBundlePolicy
    ) {
        #if BLENNY_PRODUCT || DEBUG
        if model.orderingLayoutDraft?.policy(of: payload.bundleIdentifier) != nil {
            commitLayoutDrop(
                payload: payload,
                destination: OrderingBoardLayoutDestination(
                    policy: destination,
                    position: .end
                )
            )
        } else {
            commitPolicyDrop(payload: payload, destination: destination)
        }
        #else
        commitPolicyDrop(payload: payload, destination: destination)
        #endif
    }

    private func commitPolicyDrop(
        payload: PolicyDragPayload,
        destination: MenuBarBundlePolicy
    ) {
        let animation: Animation = effectiveReduceMotion
            ? .easeOut(duration: 0.10)
            : .smooth(duration: 0.23, extraBounce: 0)
        var outcome = PolicyDraftAssignmentOutcome.rejected(.unknownCandidate)
        withAnimation(animation, completionCriteria: .logicallyComplete) {
            outcome = model.assign(payload: payload, destination: destination)
            interaction.completeDrop(
                payload: payload,
                destination: destination,
                outcome: outcome
            )
        } completion: {
            interaction.finishSettling(token: payload.dragToken)
        }
        switch outcome {
        case .changed:
            if let editor = model.model { actions.draftDidChange(editor) }
        case .rejected(.samePolicy):
            break
        case let .rejected(reason):
            model.setStatus(reason.interfaceReason, isError: true)
        }
    }

    #if BLENNY_PRODUCT || DEBUG
    private func commitLayoutDrop(
        payload: PolicyDragPayload,
        destination: OrderingBoardLayoutDestination
    ) {
        let animation: Animation = effectiveReduceMotion
            ? .easeOut(duration: 0.10)
            : .smooth(duration: 0.23, extraBounce: 0)
        var outcome = OrderingBoardConfigurationMutationOutcome.rejected(
            "This application is no longer available."
        )
        withAnimation(animation, completionCriteria: .logicallyComplete) {
            outcome = model.requestOrderingConfigurationDrop(
                payload: payload,
                destination: destination
            )
            interaction.completeDrop(
                payload: payload,
                destination: destination.policy,
                outcome: configurationAssignmentOutcome(outcome)
            )
        } completion: {
            interaction.finishSettling(token: payload.dragToken)
        }

        switch outcome {
        case .changed:
            break // The model publishes the complete local draft; Apply submits it.
        case .unchanged:
            break
        case let .rejected(reason):
            model.rejectOrderingDrag(reason)
        }
    }

    private func configurationAssignmentOutcome(
        _ outcome: OrderingBoardConfigurationMutationOutcome
    ) -> PolicyDraftAssignmentOutcome {
        switch outcome {
        case .changed: .changed
        case .unchanged: .rejected(.samePolicy)
        case .rejected: .rejected(.unknownCandidate)
        }
    }
    #endif

    private var permissionMessage: String {
        model.accessibilityPromptRequested
            ? "Turn on Blenny in Device Control and Data Access, then return here."
            : "Allow Device Control so Blenny can identify your menu bar items."
    }

    private var permissionButtonTitle: String {
        model.accessibilityPromptRequested ? "Open System Settings" : "Set Up Access…"
    }

    private var effectiveReduceMotion: Bool {
        reduceMotion || debugAccessibilityFlag("BLENNY_VALIDATE_REDUCE_MOTION")
    }

    private var effectiveReduceTransparency: Bool {
        reduceTransparency
            || debugAccessibilityFlag("BLENNY_VALIDATE_REDUCE_TRANSPARENCY")
    }

    private var effectiveContrast: ColorSchemeContrast {
        debugAccessibilityFlag("BLENNY_VALIDATE_INCREASE_CONTRAST")
            ? .increased
            : contrast
    }
}

struct BoardInterruptionPanel: View {
    let symbol: String?
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    let reduceTransparency: Bool

    var body: some View {
        VStack(spacing: 8) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(.orange)
            } else {
                ProgressView().controlSize(.small)
            }
            Text(title).font(.system(.body, weight: .medium))
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 410)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            reduceTransparency
                ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
                : AnyShapeStyle(.regularMaterial),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

struct PolicyLaneRow: View {
    let policy: MenuBarBundlePolicy
    @ObservedObject var model: ProductInterfaceModel
    let actions: ProductInterfaceActions
    @Binding var interaction: PolicyBoardInteractionState
    let iconNamespace: Namespace.ID
    let reduceMotion: Bool
    let contrast: ColorSchemeContrast
    let onDrop: (PolicyDragPayload, MenuBarBundlePolicy) -> Void
    let registerDelivery: (
        DropSession.ID,
        PolicyDragPayload.ID
    ) -> PolicyDragDeliveryRegistration
    let hasRegisteredDelivery: (DropSession.ID, PolicyDragPayload.ID) -> Bool
    @State private var activeDropSessionID: DropSession.ID?
    @State private var activeDropIdentity: PolicyDragPayload.ID?
    #if BLENNY_PRODUCT || DEBUG
    let onLayoutDrop: (PolicyDragPayload, OrderingBoardLayoutDestination) -> Void
    @State private var orderingLandingSession = OrderingBoardLandingSession()
    #endif

    var body: some View {
        #if BLENNY_PRODUCT || DEBUG
        if DebugDragStartDiagnostics.mode == .simpleLane {
            simpleLane
        } else {
            fullLane
        }
        #else
        fullLane
        #endif
    }

    private var fullLane: some View {
        HStack(spacing: 0) {
            laneHeader
                .frame(width: 154, alignment: .leading)
                .padding(.leading, 12)
                .padding(.trailing, 14)

            GeometryReader { viewport in
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                    HStack(spacing: 2) {
                    let candidates = model.applicationCandidates(in: policy)
                    let appleSystemCandidates = model.appleSystemCandidates(in: policy)
                    let systemItems = model.systemItems(in: policy)
                    let clockItems = systemItems.filter {
                        $0.observationIdentifier == SystemMenuBarItemObservation.clockIdentifier
                    }
                    #if BLENNY_PRODUCT || DEBUG
                    let exactSystemItems = model.exactSystemOrderingItems(in: policy)
                    let orderingItems = mixedOrderingItems(
                        applications: candidates,
                        systemItems: exactSystemItems
                    )
                    let orderedIdentifiers = Set(exactSystemItems.map {
                        $0.observation.observationIdentifier
                    })
                    let residualSystemItems = systemItems.filter { observation in
                        !orderedIdentifiers.contains(observation.observationIdentifier)
                            && observation.observationIdentifier
                                != SystemMenuBarItemObservation.clockIdentifier
                    }
                    let mixedLandingPreview = mixedLandingPreview(among: orderingItems)
                    #else
                    let applicationLandingPreview = landingPreview(
                        among: candidates,
                        systemPresentation: false
                    )
                    let appleSystemLandingPreview = landingPreview(
                        among: appleSystemCandidates,
                        systemPresentation: true
                    )
                    #endif
                    #if BLENNY_PRODUCT || DEBUG
                    if candidates.isEmpty && exactSystemItems.isEmpty
                        && residualSystemItems.isEmpty && clockItems.isEmpty
                        && (policy != .visible || model.unattributedMenuBarItems.isEmpty) {
                        ZStack(alignment: .leading) {
                            mixedOrderingStrip(
                                orderingItems,
                                preview: mixedLandingPreview
                            )
                            if mixedLandingPreview == nil {
                                emptyState
                                    .allowsHitTesting(false)
                            }
                        }
                    } else {
                        mixedOrderingStrip(orderingItems, preview: mixedLandingPreview)

                        if !residualSystemItems.isEmpty {
                            systemSectionHeader(items: residualSystemItems)
                            ForEach(residualSystemItems, id: \.observationIdentifier) { item in
                                systemBoardItem(item)
                            }
                        }
                        unidentifiedMenuBarItems
                        ForEach(clockItems, id: \.observationIdentifier) { item in
                            systemBoardItem(item)
                        }
                    }
                    #else
                    if candidates.isEmpty && appleSystemCandidates.isEmpty
                        && applicationLandingPreview == nil
                        && appleSystemLandingPreview == nil && systemItems.isEmpty
                        && (policy != .visible || model.unattributedMenuBarItems.isEmpty) {
                        emptyState
                    } else {
                        applicationStrip(
                            candidates,
                            preview: applicationLandingPreview
                        )

                        if !appleSystemCandidates.isEmpty || !systemItems.isEmpty {
                            Rectangle()
                                .fill(Color(nsColor: .separatorColor))
                                .frame(width: 1, height: 34)
                                .padding(.horizontal, 3)
                                .accessibilityHidden(true)

                            VStack(spacing: 2) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 13, weight: .regular))
                                Text("No sorting")
                                    .font(.caption)

                            }
                            .frame(width: 54)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Items that cannot be sorted")

                            ForEach(
                                Array(appleSystemCandidates.enumerated()),
                                id: \.element.bundleIdentifier
                            ) { index, candidate in
                                if appleSystemLandingPreview?.index == index {
                                    landingPreviewView(appleSystemLandingPreview)
                                }
                                applicationBoardItem(
                                    candidate,
                                    presentsAsSystemItem: true
                                )
                            }

                            if appleSystemLandingPreview?.index
                                == appleSystemCandidates.endIndex {
                                landingPreviewView(appleSystemLandingPreview)
                            }

                            ForEach(systemItems.filter {
                                $0.observationIdentifier
                                    != SystemMenuBarItemObservation.clockIdentifier
                            }, id: \.observationIdentifier) { item in
                                systemBoardItem(item)
                            }
                        }
                        unidentifiedMenuBarItems
                        ForEach(systemItems.filter {
                            $0.observationIdentifier
                                == SystemMenuBarItemObservation.clockIdentifier
                        }, id: \.observationIdentifier) { item in
                            systemBoardItem(item)
                        }
                    }
                    #endif
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    Color.clear
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    }
                    .frame(
                        minWidth: viewport.size.width,
                        minHeight: BlennyDesign.laneHeight,
                        alignment: .leading
                    )
                    .contentShape(Rectangle())
                    .diagnosticLaneDrop(
                        accept: acceptDrop,
                        configuration: dropConfiguration,
                        update: updateDropSession,
                        direct: acceptDiagnosticDrop
                    )
                    .padding(.horizontal, 5)
                }
                .scrollIndicators(.never)
                .scrollEdgeEffectHidden(true, for: .all)
            }
        }
        .frame(height: BlennyDesign.laneHeight)
        .contentShape(Rectangle())
        .background(targetBackground)
        .overlay {
            if activeTarget != nil, contrast == .increased {
                Rectangle()
                    .stroke(
                        isValidTarget ? Color.accentColor : Color.red,
                        lineWidth: 2
                    )
                    .padding(1)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(policy.interfaceTitle), \(applicationCount) applications")
        .accessibilityHint(policy.interfaceDetail)
    }

    @ViewBuilder
    private var unidentifiedMenuBarItems: some View {
        if policy == .visible && !model.unattributedMenuBarItems.isEmpty {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1, height: 34)
                .padding(.horizontal, 3)
                .accessibilityHidden(true)
            ForEach(model.unattributedMenuBarItems, id: \.processIdentifier) { observation in
                UnidentifiedMenuBarBoardItem(observation: observation)
            }
        }
    }

    private func acceptDiagnosticDrop(_ payloads: [PolicyDragPayload], _ location: CGPoint) -> Bool {
        guard payloads.count == 1, let payload = payloads.first else { return false }
        #if BLENNY_PRODUCT || DEBUG
        DebugDragStartDiagnostics.record("direct.drop.delivered")
        guard let subject = model.orderingSubject(forDragIdentifier: payload.bundleIdentifier),
              model.orderingLayoutDraft?.policy(of: subject) == payload.sourcePolicy else { return false }
        // The real model validates the token, candidate generation and current draft.
        let identifiers = model.orderingLayoutDraft?.subjects(in: policy).map {
            model.dragIdentifier(for: $0)
        } ?? []
        let position = OrderingBoardLandingProjection.position(
            at: location.x, itemExtent: DebugDragStartDiagnostics.mode == .simpleLane ? 48 : orderingItemExtent,
            moving: payload.bundleIdentifier, among: identifiers
        ) ?? .end
        onLayoutDrop(payload, OrderingBoardLayoutDestination(policy: policy, position: position))
        #else
        onDrop(payload, policy)
        #endif
        return true
    }

    #if BLENNY_PRODUCT || DEBUG
    private var simpleLane: some View {
        HStack(spacing: 0) {
            Text(policy.interfaceTitle).frame(width: 100)
            HStack(spacing: 0) {
                ForEach(model.orderingLayoutDraft?.subjects(in: policy) ?? [], id: \.self) { subject in
                    if let presentation = orderingLandingPresentation(for: subject) {
                        DebugPlainBoardIcon(
                            presentation: presentation,
                            payload: model.beginOrderingDragPayload(subjectID: subject, sourcePolicy: policy)
                        )
                        .frame(width: 48, height: 48)
                    }
                }
            }
            .frame(minWidth: 700, minHeight: BlennyDesign.laneHeight, alignment: .leading)
            .contentShape(Rectangle())
            .dropDestination(for: PolicyDragPayload.self, action: acceptDiagnosticDrop)
        }
        .frame(height: BlennyDesign.laneHeight)
    }
    #endif

    private func acceptDrop(
        _ payloads: [PolicyDragPayload],
        in session: DropSession
    ) {
        guard payloads.count == 1, let payload = payloads.first else {
            model.setStatus(
                "Only one application can be moved at a time.",
                isError: false
            )
            return
        }
        if hasRegisteredDelivery(session.id, payload.id) {
            // Native cleanup can remove current session metadata before a
            // repeated typed callback arrives. The exact previously handled
            // session and payload remain an idempotent acknowledgement.
            return
        }
        guard PolicyDragDelivery.matches(
            delivered: payload.id,
            reported: localIdentity(in: session),
            active: activeDropIdentity,
            nativeSessionMatches: activeDropSessionID.map { $0 == session.id }
        ) else {
            rejectDrop("The drag session changed before delivery. Start a new drag.")
            return
        }
        switch registerDelivery(session.id, payload.id) {
        case .duplicate:
            // SwiftUI can deliver the same typed value more than once for one
            // native destination session. The first callback owns the operation.
            return
        case .conflictingPayload:
            rejectDrop("The drag session changed before delivery. Start a new drag.")
            return
        case .first:
            break
        }
        #if BLENNY_PRODUCT || DEBUG
        if let subjectID = model.orderingSubject(
            forDragIdentifier: payload.bundleIdentifier
        ), model.orderingLayoutDraft?.policy(of: subjectID) != nil {
            let identifiers = currentOrderingIdentifiers
            guard let position = orderingLandingSession.consume(
                moving: payload.bundleIdentifier,
                among: identifiers
            ) ?? OrderingBoardLandingProjection.position(
                at: session.location.x,
                itemExtent: orderingItemExtent,
                moving: payload.bundleIdentifier,
                among: identifiers
            ) else {
                rejectDrop("The landing position is no longer available.")
                return
            }
            onLayoutDrop(payload, .init(policy: policy, position: position))
            return
        }
        #endif
        onDrop(payload, policy)
    }

    private func rejectDrop(_ reason: String) {
        #if BLENNY_PRODUCT || DEBUG
        model.rejectOrderingDrag(reason)
        #else
        model.setStatus(reason, isError: false)
        #endif
    }

    @ViewBuilder
    private func systemSectionHeader(
        items: [SystemMenuBarItemObservation]
    ) -> some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1, height: 34)
            .padding(.horizontal, 3)
            .accessibilityHidden(true)

        VStack(spacing: 2) {
            Image(systemName: "apple.logo")
                .font(.system(size: 13, weight: .regular))
            Text("No sorting")
                .font(.caption)

        }
        .frame(width: 54)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Items that cannot be sorted")
    }

    @ViewBuilder
    private func systemBoardItem(
        _ item: SystemMenuBarItemObservation
    ) -> some View {
        #if BLENNY_PRODUCT || DEBUG
        if DebugDragStartDiagnostics.mode == .snapshotSystemItems
            || DebugDragStartDiagnostics.mode == .noViewExtras {
            DebugPlainBoardIcon(presentation: model.systemIcon(for: item), payload: nil)
        } else {

        #if BLENNY_PRODUCT || DEBUG
        SystemBoardItem(
            observation: item,
            policy: policy,
            model: model,
            interaction: $interaction,
            contrast: contrast,
            actions: actions,
            onMove: performMove,
            orderingSubjectID: nil
        )
        #else
        SystemBoardItem(
            observation: item,
            policy: policy,
            model: model,
            interaction: $interaction,
            contrast: contrast,
            actions: actions,
            onMove: performMove
        )
        #endif
        }
        #else

        #if BLENNY_PRODUCT || DEBUG
        SystemBoardItem(
            observation: item,
            policy: policy,
            model: model,
            interaction: $interaction,
            contrast: contrast,
            actions: actions,
            onMove: performMove,
            orderingSubjectID: nil
        )
        #else
        SystemBoardItem(
            observation: item,
            policy: policy,
            model: model,
            interaction: $interaction,
            contrast: contrast,
            actions: actions,
            onMove: performMove
        )
        #endif
        #endif
    }

    #if BLENNY_PRODUCT || DEBUG
    @ViewBuilder
    private func systemBoardItem(
        _ item: SystemMenuBarItemObservation,
        orderingSubjectID: OrderingSubjectID
    ) -> some View {
        #if BLENNY_PRODUCT || DEBUG
        if DebugDragStartDiagnostics.mode == .snapshotSystemItems
            || DebugDragStartDiagnostics.mode == .noViewExtras {
            DebugPlainBoardIcon(presentation: model.systemIcon(for: item), payload: nil)
        } else {

        SystemBoardItem(
            observation: item,
            policy: policy,
            model: model,
            interaction: $interaction,
            contrast: contrast,
            actions: actions,
            onMove: performMove,
            orderingSubjectID: orderingSubjectID
        )
        }
        #else

        SystemBoardItem(
            observation: item,
            policy: policy,
            model: model,
            interaction: $interaction,
            contrast: contrast,
            actions: actions,
            onMove: performMove,
            orderingSubjectID: orderingSubjectID
        )
        #endif
    }
    #endif

    #if BLENNY_PRODUCT || DEBUG
    private enum MixedOrderingItem: Identifiable {
        case application(PolicyCandidate)
        case system(ExactSystemBoardItem)

        var subjectID: OrderingSubjectID {
            switch self {
            case let .application(candidate): .application(candidate.bundleIdentifier)
            case let .system(item): item.subjectID
            }
        }

        var id: String { subjectID.boardID }
    }

    private func mixedOrderingItems(
        applications: [PolicyCandidate],
        systemItems: [ExactSystemBoardItem]
    ) -> [MixedOrderingItem] {
        let values = applications.map(MixedOrderingItem.application)
            + systemItems.map(MixedOrderingItem.system)
        guard let layout = model.orderingLayoutDraft else { return values }
        let rank = Dictionary(uniqueKeysWithValues: layout.subjects(in: policy).enumerated().map {
            ($0.element, $0.offset)
        })
        return values.sorted {
            rank[$0.subjectID, default: .max] < rank[$1.subjectID, default: .max]
        }
    }

    private var currentOrderingIdentifiers: [String] {
        mixedOrderingItems(
            applications: model.applicationCandidates(in: policy),
            systemItems: model.exactSystemOrderingItems(in: policy)
        ).map { model.dragIdentifier(for: $0.subjectID) }
    }

    private var orderingItemExtent: Double {
        BlennyDesign.itemFrame.width + 2
    }

    @ViewBuilder
    private func mixedOrderingStrip(
        _ items: [MixedOrderingItem],
        preview: LandingPreview?
    ) -> some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 2) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    mixedOrderingItemView(item)
                        .offset(
                            x: preview.map { index >= $0.index ? orderingItemExtent : 0 }
                                ?? 0
                        )
                }
                if preview != nil {
                    Color.clear
                        .frame(
                            width: BlennyDesign.itemFrame.width,
                            height: BlennyDesign.itemFrame.height
                        )
                }
            }
            .frame(minWidth: items.isEmpty ? 225 : 0, alignment: .leading)

            if let preview {
                landingPreviewView(preview)
                    .offset(x: Double(preview.index) * orderingItemExtent)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func mixedOrderingItemView(_ item: MixedOrderingItem) -> some View {
        switch item {
        case let .application(candidate):
            applicationBoardItem(
                candidate,
                presentsAsSystemItem: ExperimentalAppleBundlePolicyCatalog.contains(
                    candidate.bundleIdentifier
                )
            )
        case let .system(systemItem):
            systemBoardItem(
                systemItem.observation,
                orderingSubjectID: systemItem.subjectID
            )
        }
    }

    private func mixedLandingPreview(
        among items: [MixedOrderingItem]
    ) -> LandingPreview? {
        guard let identifier = interaction.draggedBundleIdentifier,
              let subjectID = model.orderingSubject(forDragIdentifier: identifier),
              model.orderingLayoutDraft?.policy(of: subjectID) != nil,
              (activeTarget != nil || orderingLandingSession.position != nil),
              let index = OrderingBoardLandingProjection.insertionIndex(
                for: orderingLandingSession.position ?? .end,
                among: items.map { model.dragIdentifier(for: $0.subjectID) }
              ),
              let presentation = orderingLandingPresentation(for: subjectID)
        else { return nil }
        return LandingPreview(index: index, presentation: presentation)
    }

    private func orderingLandingPresentation(
        for subjectID: OrderingSubjectID
    ) -> ResolvedPolicyIcon? {
        switch subjectID {
        case let .application(bundleIdentifier):
            return model.applicationIcon(for: bundleIdentifier)
        case let .systemItem(item):
            return model.systemIcon(for: SystemMenuBarItemObservation(
                observationIdentifier: item.observationIdentifier,
                ownerBundleIdentifier: item.hostBundleIdentifier,
                displayName: item.displayName,
                observationCount: 0
            ))
        }
    }
    #endif

    @ViewBuilder
    private func applicationStrip(
        _ candidates: [PolicyCandidate],
        preview: LandingPreview?
    ) -> some View {
        applicationStripContent(candidates, preview: preview)
    }

    private func applicationStripContent(
        _ candidates: [PolicyCandidate],
        preview: LandingPreview?
    ) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(candidates.enumerated()), id: \.element.bundleIdentifier) {
                index, candidate in
                if preview?.index == index { landingPreviewView(preview) }
                applicationBoardItem(
                    candidate,
                    presentsAsSystemItem: ExperimentalAppleBundlePolicyCatalog.contains(
                        candidate.bundleIdentifier
                    )
                )
            }
            if preview?.index == candidates.endIndex { landingPreviewView(preview) }
        }
    }

    @ViewBuilder
    private func applicationBoardItem(
        _ candidate: PolicyCandidate,
        presentsAsSystemItem: Bool
    ) -> some View {
        #if BLENNY_PRODUCT || DEBUG
        if DebugDragStartDiagnostics.mode == .noViewExtras {
            DebugPlainBoardIcon(
                presentation: model.applicationIcon(for: candidate.bundleIdentifier),
                payload: model.isBlenny(candidate.bundleIdentifier) ? nil : model.beginOrderingDragPayload(
                    subjectID: .application(candidate.bundleIdentifier), sourcePolicy: policy
                )
            )
        } else {

        ApplicationBoardItem(
            candidate: candidate,
            policy: policy,
            model: model,
            interaction: $interaction,
            iconNamespace: iconNamespace,
            reduceMotion: reduceMotion,
            contrast: contrast,
            presentsAsSystemItem: presentsAsSystemItem,
            onMove: performMove
        )
        }
        #else

        ApplicationBoardItem(
            candidate: candidate,
            policy: policy,
            model: model,
            interaction: $interaction,
            iconNamespace: iconNamespace,
            reduceMotion: reduceMotion,
            contrast: contrast,
            presentsAsSystemItem: presentsAsSystemItem,
            onMove: performMove
        )
        #endif
    }

    private var systemControlLabel: String {
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        "System items"
        #else
        "Bluetooth enabled"
        #endif
    }

    private var systemControlHelp: String {
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        "Exact system-item capabilities determine editing and sorting. Unsupported identities remain read only."
        #else
        "Bluetooth is the only supported system-item policy control."
        #endif
    }

    private var laneHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle()
                    .fill(policy.interfaceColor)
                    .frame(width: 5, height: 5)
                    .accessibilityHidden(true)
                Text(policy.interfaceTitle)
                    .font(.body)
                Text("\(applicationCount) apps")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            if let target = activeTarget {
                targetHeader(target)
                    .transition(.opacity)
            } else {
                Text(policy.interfaceShortDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var emptyState: some View {
        Label("Drop an app here or use Move to…", systemImage: "tray")
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .frame(width: 225, height: 50)
            .accessibilityLabel("No observed applications in \(policy.interfaceTitle)")
    }

    private var applicationCount: Int {
        model.applicationCandidates(in: policy).count
    }

    private var activeTarget: PolicyBoardDropTarget? {
        guard interaction.dropTarget?.policy == policy else { return nil }
        return interaction.dropTarget
    }

    private var isValidTarget: Bool { activeTarget?.isValid == true }

    private struct LandingPreview {
        let index: Int
        let presentation: ResolvedPolicyIcon
    }

    private func landingPreview(
        among candidates: [PolicyCandidate],
        systemPresentation: Bool
    ) -> LandingPreview? {
        #if BLENNY_PRODUCT || DEBUG
        if !systemPresentation,
           let bundleIdentifier = interaction.draggedBundleIdentifier,
           model.orderingLayoutDraft?.policy(of: bundleIdentifier) != nil,
           (activeTarget != nil || orderingLandingSession.position != nil),
           let index = OrderingBoardLandingProjection.insertionIndex(
                for: orderingLandingSession.position ?? .end,
                among: candidates.map(\.bundleIdentifier)
           ) {
            return LandingPreview(
                index: index,
                presentation: model.applicationIcon(for: bundleIdentifier)
            )
        }
        #endif
        guard isValidTarget,
              let bundleIdentifier = interaction.draggedBundleIdentifier,
              interaction.draggedSourcePolicy != policy,
              model.candidate(bundleIdentifier: bundleIdentifier) != nil,
              ExperimentalAppleBundlePolicyCatalog.contains(bundleIdentifier)
                == systemPresentation else {
            return nil
        }
        return LandingPreview(
            index: PolicyBoardLandingProjection.automaticIndex(
                for: bundleIdentifier,
                among: candidates.map(\.bundleIdentifier)
            ),
            presentation: model.applicationIcon(for: bundleIdentifier)
        )
    }

    @ViewBuilder
    private func landingPreviewView(_ preview: LandingPreview?) -> some View {
        if let preview {
            PolicyLaneLandingPreview(
                presentation: preview.presentation,
                reduceMotion: reduceMotion,
                contrast: contrast
            )
        }
    }

    private var targetBackground: Color {
        guard activeTarget != nil else { return .clear }
        return isValidTarget
            ? Color.accentColor.opacity(0.055)
            : Color.red.opacity(0.035)
    }

    private func localIdentity(in session: DropSession) -> PolicyDragPayload.ID? {
        if session.itemsCount == 1, let localSession = session.localSession {
            let identities = localSession.draggedItemIDs(for: PolicyDragPayload.ID.self)
            #if DEBUG
            DebugDragStartDiagnostics.record("lane.identityCount.\(identities.count)")
            #endif
            if identities.count == 1 { return identities[0] }
            if identities.count > 1 { return nil }
        }
        // Metadata may disappear during transfer. Only reuse this exact native
        // destination session's previously established identity.
        return activeDropSessionID == session.id ? activeDropIdentity : nil
    }

    private func validation(
        for identity: PolicyDragPayload.ID
    ) -> PolicyDraftAssignmentOutcome {
        guard identity.candidateGeneration == model.candidateGeneration else {
            return .rejected(.staleCandidateGeneration)
        }
        #if BLENNY_PRODUCT || DEBUG
        if let subjectID = model.orderingSubject(
            forDragIdentifier: identity.bundleIdentifier
        ), model.orderingLayoutDraft?.policy(of: subjectID) == identity.sourcePolicy,
           model.effectiveOrderingPolicy(for: subjectID) == identity.sourcePolicy,
           !model.isApplying, !model.isRefreshing {
            if case let .application(bundleIdentifier) = subjectID,
               model.isBlenny(bundleIdentifier) {
                return .rejected(.blennyMustRemainVisible)
            }
            return .changed
        }
        #endif
        return model.validateDrag(
            bundleIdentifier: identity.bundleIdentifier,
            sourcePolicy: identity.sourcePolicy,
            destination: policy
        )
    }

    private func dropConfiguration(_ session: DropSession) -> DropConfiguration {
        guard session.suggestedOperations.contains(.move),
              let identity = localIdentity(in: session),
              validation(for: identity) == .changed else {
            return DropConfiguration(operation: .forbidden)
        }
        var configuration = DropConfiguration(operation: .move)
        configuration.acceptedItemCount = 1
        return configuration
    }

    private func updateDropSession(_ session: DropSession) {
        #if DEBUG
        DebugDragStartDiagnostics.record("lane.dropSession.\(String(describing: session.phase))")
        #endif
        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.08)
            : .smooth(duration: 0.15, extraBounce: 0)
        withAnimation(animation) {
            switch session.phase {
            case .entering, .active:
                guard let identity = localIdentity(in: session) else {
                    // Local item metadata can be temporarily unavailable while
                    // the same native session remains active. Keep its bound
                    // identity and landing gap until a terminal phase arrives.
                    return
                }
                if activeDropSessionID != session.id
                    || activeDropIdentity != identity {
                    #if BLENNY_PRODUCT || DEBUG
                    orderingLandingSession.clear()
                    #endif
                    activeDropSessionID = session.id
                    activeDropIdentity = identity
                }
                if interaction.draggedBundleIdentifier != identity.bundleIdentifier
                    || interaction.draggedSourcePolicy != identity.sourcePolicy {
                    interaction.beginDrag(
                        bundleIdentifier: identity.bundleIdentifier,
                        sourcePolicy: identity.sourcePolicy
                    )
                }
                let outcome = validation(for: identity)
                #if BLENNY_PRODUCT || DEBUG
                if outcome == .changed,
                   let subjectID = model.orderingSubject(
                    forDragIdentifier: identity.bundleIdentifier
                   ), model.orderingLayoutDraft?.policy(of: subjectID)
                    == identity.sourcePolicy,
                   let position = OrderingBoardLandingProjection.position(
                    at: session.location.x,
                    itemExtent: orderingItemExtent,
                    moving: identity.bundleIdentifier,
                    among: currentOrderingIdentifiers
                   ) {
                    if orderingLandingSession.boundPosition(
                        moving: identity.bundleIdentifier,
                        among: currentOrderingIdentifiers
                    ) != position {
                        _ = orderingLandingSession.update(
                            moving: identity.bundleIdentifier,
                            to: position,
                            among: currentOrderingIdentifiers
                        )
                    }
                } else {
                    orderingLandingSession.clear()
                }
                #endif
                interaction.target(policy: policy, validation: outcome)
            case .exiting:
                if activeDropSessionID == session.id {
                    clearCurrentDropSession()
                }
            case .ended(let operation):
                guard activeDropSessionID == session.id else { return }
                if let identity = localIdentity(in: session),
                   identity != activeDropIdentity { return }
                if operation == .move {
                    #if BLENNY_PRODUCT || DEBUG
                    orderingLandingSession.pointerEnded()
                    #endif
                    interaction.clearTarget(policy: policy)
                } else {
                    clearCurrentDropSession()
                }
            case .dataTransferCompleted:
                if activeDropSessionID == session.id {
                    if let identity = localIdentity(in: session),
                       identity != activeDropIdentity { return }
                    clearCurrentDropSession(transferCompleted: true)
                }
            @unknown default:
                if activeDropSessionID == session.id {
                    clearCurrentDropSession()
                }
            }
        }
    }

    private func clearCurrentDropSession(transferCompleted: Bool = false) {
        #if BLENNY_PRODUCT || DEBUG
        if let identity = activeDropIdentity {
            if transferCompleted {
                orderingLandingSession.transferCompleted(
                    moving: identity.bundleIdentifier
                )
            } else {
                orderingLandingSession.clear(moving: identity.bundleIdentifier)
            }
        }
        #endif
        interaction.clearTarget(policy: policy)
        activeDropSessionID = nil
        activeDropIdentity = nil
    }

    @ViewBuilder
    private func targetHeader(_ target: PolicyBoardDropTarget) -> some View {
        if target.rejection == .samePolicy {
            EmptyView()
        } else if let rejection = target.rejection {
            Label(compactReason(for: rejection), systemImage: "nosign")
                .font(.system(.footnote, weight: .medium))
                .foregroundStyle(.red)
                .help(rejection.interfaceReason)
        } else {
            Label(
                "Release into \(policy.interfaceTitle)",
                systemImage: "arrow.down.to.line.compact"
            )
                .font(.system(.footnote, weight: .medium))
                .foregroundStyle(Color.accentColor)
        }
    }

    private func compactReason(
        for rejection: PolicyDraftAssignmentRejection
    ) -> String {
        switch rejection {
        case .interactionInProgress: "Wait for the current operation"
        case .duplicateDelivery: "Drop already handled"
        case .staleCandidateGeneration, .staleSourcePolicy: "Start a new drag"
        case .samePolicy: "No change"
        case .blennyMustRemainVisible: "Blenny stays Visible"
        case .unknownCandidate: "No longer available"
        }
    }

    private func performMove(
        bundleIdentifier: String,
        destination: MenuBarBundlePolicy
    ) {
        #if BLENNY_PRODUCT || DEBUG
        if let item = model.availableSystemOrderingItem(
            for: bundleIdentifier
        ) {
            let subjectID = OrderingSubjectID.systemItem(item)
            guard let source = model.orderingLayoutDraft?.policy(of: subjectID) else {
                return
            }
            onLayoutDrop(
                model.dragPayload(subjectID: subjectID, sourcePolicy: source),
                .init(policy: destination, position: .end)
            )
            return
        }
        #endif
        if model.isControllableSystemItem(bundleIdentifier) {
            let outcome = model.assignSystemItem(
                identifier: bundleIdentifier,
                destination: destination
            )
            if outcome.changedDraft, let editor = model.model {
                actions.draftDidChange(editor)
            } else if case .rejected(let reason) = outcome {
                model.setStatus(reason.interfaceReason, isError: true)
            }
            return
        }
        guard let source = model.model?.effectivePolicy(for: bundleIdentifier) else { return }
        onDrop(
            model.dragPayload(bundleIdentifier: bundleIdentifier, sourcePolicy: source),
            destination
        )
    }
}

struct PolicyLaneLandingPreview: View {
    let presentation: ResolvedPolicyIcon
    let reduceMotion: Bool
    let contrast: ColorSchemeContrast

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.accentColor.opacity(0.075))
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(
                            Color.accentColor.opacity(contrast == .increased ? 0.9 : 0.5),
                            style: StrokeStyle(
                                lineWidth: contrast == .increased ? 2 : 1,
                                dash: [3, 2]
                            )
                        )
                }
            NaturalAspectSystemIcon(
                presentation: presentation,
                pointSize: 21,
                frame: CGSize(
                    width: BlennyDesign.iconFrame,
                    height: BlennyDesign.iconFrame
                )
            )
                .opacity(contrast == .increased ? 0.48 : 0.32)
        }
        .frame(
            width: BlennyDesign.itemChromeFrame.width,
            height: BlennyDesign.itemChromeFrame.height
        )
        .frame(width: BlennyDesign.itemFrame.width, height: BlennyDesign.itemFrame.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .transition(
            reduceMotion
                ? .opacity
                : .scale(scale: 0.94).combined(with: .opacity)
        )
    }
}

struct ApplicationBoardItem: View {
    let candidate: PolicyCandidate
    let policy: MenuBarBundlePolicy
    @ObservedObject var model: ProductInterfaceModel
    @Binding var interaction: PolicyBoardInteractionState
    let iconNamespace: Namespace.ID
    let reduceMotion: Bool
    let contrast: ColorSchemeContrast
    let presentsAsSystemItem: Bool
    let onMove: (String, MenuBarBundlePolicy) -> Void
    @FocusState private var isFocused: Bool

    private var itemID: PolicyBoardItemID {
        .application(candidate.bundleIdentifier)
    }

    var body: some View {
        let presentation = model.applicationIcon(for: candidate.bundleIdentifier)
        let blenny = model.isBlenny(candidate.bundleIdentifier)

        itemSurface(
            presentation: presentation,
            blenny: blenny,
            dragPayload: blenny
                ? nil
                : currentDragPayload
        )
        .contextMenu {
            if !blenny {
                MoveToCommands(
                    bundleIdentifier: candidate.bundleIdentifier,
                    currentPolicy: policy,
                    onMove: onMove
                )
                #if BLENNY_PRODUCT || DEBUG
                Divider()
                Button("Move Left") {
                    model.requestOrderingMove(
                        candidate.bundleIdentifier,
                        direction: .left,
                        in: policy
                    )
                }
                .disabled(!model.canRequestOrderingMove(
                    candidate.bundleIdentifier,
                    direction: .left,
                    in: policy
                ))
                Button("Move Right") {
                    model.requestOrderingMove(
                        candidate.bundleIdentifier,
                        direction: .right,
                        in: policy
                    )
                }
                .disabled(!model.canRequestOrderingMove(
                    candidate.bundleIdentifier,
                    direction: .right,
                    in: policy
                ))
                #endif
            } else {
                Text("Blenny must remain Visible")
            }
        }
        .accessibilityActions {
            if !blenny {
                ForEach(MenuBarBundlePolicy.allCases, id: \.self) { destination in
                    if destination != policy {
                        Button("Move to \(destination.interfaceTitle)") {
                            onMove(candidate.bundleIdentifier, destination)
                        }
                    }
                }
                #if BLENNY_PRODUCT || DEBUG
                Button("Move Left") {
                    model.requestOrderingMove(
                        candidate.bundleIdentifier,
                        direction: .left,
                        in: policy
                    )
                }
                .disabled(!model.canRequestOrderingMove(
                    candidate.bundleIdentifier,
                    direction: .left,
                    in: policy
                ))
                Button("Move Right") {
                    model.requestOrderingMove(
                        candidate.bundleIdentifier,
                        direction: .right,
                        in: policy
                    )
                }
                .disabled(!model.canRequestOrderingMove(
                    candidate.bundleIdentifier,
                    direction: .right,
                    in: policy
                ))
                #endif
            }
        }
        .zIndex(showsName ? 20 : isSelected ? 10 : 0)
    }

    private var currentDragPayload: PolicyDragPayload? {
        #if BLENNY_PRODUCT || DEBUG
        guard let subjectID = model.orderingSubject(
            forDragIdentifier: candidate.bundleIdentifier
        ) else { return nil }
        return model.beginOrderingDragPayload(
            subjectID: subjectID,
            sourcePolicy: policy
        )
        #else
        return model.preparedPolicyDragPayload(
            bundleIdentifier: candidate.bundleIdentifier,
            sourcePolicy: policy
        )
        #endif
    }

    private func itemSurface(
        presentation: ResolvedPolicyIcon,
        blenny: Bool,
        dragPayload: PolicyDragPayload?
    ) -> some View {
        let inputSurface = AnyView(
            itemArtwork(
                presentation: presentation,
                blenny: blenny,
                dragPayload: dragPayload
            )
            .onTapGesture(perform: select)
            .diagnosticFocusable($isFocused)
            .onKeyPress(keys: [.return, .space], action: handleSelectionKey)
        )
        let visualSurface = AnyView(
            inputSurface
            .opacity(isDragSource ? 0.28 : 1)
            .scaleEffect(isDragSource && !effectiveReduceMotion ? 0.96 : 1)
            .animation(interactionAnimation, value: isDragSource)
            .onChange(of: isFocused) {
                withAnimation(.easeOut(duration: 0.10)) {
                    interaction.setFocused(itemID, isFocused: isFocused)
                }
            }
            .onHover { hovering in
                updateHover(hovering)
            }
        )
        return AnyView(
            visualSurface
                .help(tooltip(for: presentation, blenny: blenny))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    accessibilityLabel(for: presentation, blenny: blenny)
                )
                .accessibilityHint(
                    blenny
                        ? "Select, then open Item controls for details. Blenny must remain Visible."
                        : "Select, then open Item controls for details. Drag between groups or use a Move to action."
                )
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
                .accessibilityAddTraits(.isButton)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityAction(.default) {
                    select()
                }
        )
    }

    private func itemArtwork(
        presentation: ResolvedPolicyIcon,
        blenny: Bool,
        dragPayload: PolicyDragPayload?
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(itemBackground)
                .frame(
                    width: BlennyDesign.itemChromeFrame.width,
                    height: BlennyDesign.itemChromeFrame.height
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(itemOutline, lineWidth: itemOutlineWidth)
                }
            draggableIcon(
                presentation: presentation,
                payload: dragPayload
            )
        }
        .frame(width: BlennyDesign.itemFrame.width, height: BlennyDesign.itemFrame.height)
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .overlay(alignment: .topTrailing) {
            if blenny {
                Image(systemName: "lock.fill")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(BlennyDesign.coral)
                    .padding(3)
                    .accessibilityHidden(true)
            } else if presentsAsSystemItem {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(3)
                    .accessibilityHidden(true)
            }
        }
        #if BLENNY_PRODUCT || DEBUG
        .overlay(alignment: .topLeading) {
            if let symbol = orderingStateSymbol {
                Image(systemName: symbol)
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(orderingStateColor)
                    .padding(3)
                    .accessibilityHidden(true)
            }
        }
        #endif
        .overlay(alignment: .bottom) {
            #if BLENNY_PRODUCT || DEBUG
            if showsName {
                FloatingItemName(name: presentation.displayName)
                    .offset(y: 5)
                    .transition(.opacity)
            } else if !blenny, let orderingStatusLabel {
                Text(orderingStatusLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            #else
            if showsName {
                FloatingItemName(name: presentation.displayName)
                    .offset(y: 5)
                    .transition(.opacity)
            }
            #endif
        }
    }

    @ViewBuilder
    private func draggableIcon(
        presentation: ResolvedPolicyIcon,
        payload: PolicyDragPayload?
    ) -> some View {
        if let payload {
            policyIcon(presentation: presentation)
                .policyBoardDragSource(payload)
        } else {
            policyIcon(presentation: presentation)
        }
    }

    private func select() {
        withAnimation(interactionAnimation) {
            interaction.select(itemID)
        }
    }

    private func updateHover(_ hovering: Bool) {
        // Native drag startup clears the hover presentation while the pointer
        // is still over the source. Writing that hover straight back can
        // remount the source and cancel the session, producing a layout loop.
        guard interaction.draggedBundleIdentifier == nil else { return }
        interaction.setHovered(itemID, isHovered: hovering)
    }

    #if BLENNY_PRODUCT || DEBUG
    private var orderingStateSymbol: String? {
        guard !model.isBlenny(candidate.bundleIdentifier),
              let row = model.orderingRow(for: candidate.bundleIdentifier) else {
            return "questionmark.circle"
        }
        switch row.availability {
        case .ready: return nil
        case .needsMapping: return "minus.circle"
        case .unverified: return "info.circle"
        case .blocked: return "nosign"
        }
    }

    private var orderingStateColor: Color {
        guard let row = model.orderingRow(for: candidate.bundleIdentifier) else {
            return .secondary
        }
        return row.availability == .blocked ? .red : .secondary
    }

    private var orderingStatusLabel: String? {
        guard let row = model.orderingRow(for: candidate.bundleIdentifier) else {
            return "Unverified"
        }
        switch row.availability {
        case .ready: return nil
        case .needsMapping: return "No sort"
        case .unverified: return "Unverified"
        case .blocked: return "No sort"
        }
    }
    #endif

    private func handleSelectionKey(_ keyPress: KeyPress) -> KeyPress.Result {
        select()
        return .handled
    }

    @ViewBuilder
    private func policyIcon(presentation: ResolvedPolicyIcon) -> some View {
        let image = NaturalAspectSystemIcon(
            presentation: presentation,
            pointSize: 21,
            frame: CGSize(
                width: BlennyDesign.iconFrame,
                height: BlennyDesign.iconFrame
            )
        )
        if effectiveReduceMotion {
            image
        } else {
            image.matchedGeometryEffect(
                id: candidate.bundleIdentifier,
                in: iconNamespace,
                properties: .position
            )
        }
    }

    private var isSelected: Bool { interaction.selectedItem == itemID }
    private var showsName: Bool {
        interaction.draggedBundleIdentifier == nil
            && interaction.namePresentationItem == itemID
    }
    private var isDragSource: Bool {
        interaction.draggedBundleIdentifier == candidate.bundleIdentifier
    }

    private var itemBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.07) }
        if isFocused || interaction.hoveredItem == itemID {
            return Color.primary.opacity(0.055)
        }
        return .clear
    }

    private var itemOutline: Color {
        if interaction.settleState?.bundleIdentifier == candidate.bundleIdentifier {
            return BlennyDesign.coral
        }
        if isFocused { return Color.primary.opacity(0.72) }
        if contrast == .increased && isSelected { return Color.accentColor }
        return .clear
    }

    private var itemOutlineWidth: CGFloat {
        if contrast == .increased && (isSelected || isFocused) { return 2 }
        return (isFocused
            || interaction.settleState?.bundleIdentifier == candidate.bundleIdentifier) ? 1.5 : 0
    }

    private var interactionAnimation: Animation {
        effectiveReduceMotion
            ? .easeOut(duration: 0.08)
            : .smooth(duration: 0.14, extraBounce: 0)
    }

    private var effectiveReduceMotion: Bool {
        reduceMotion || debugAccessibilityFlag("BLENNY_VALIDATE_REDUCE_MOTION")
    }

    private func tooltip(
        for presentation: ResolvedPolicyIcon,
        blenny: Bool
    ) -> String {
        "\(presentation.displayName)\n\(accessibilityLabel(for: presentation, blenny: blenny))"
    }

    private func accessibilityLabel(
        for presentation: ResolvedPolicyIcon,
        blenny: Bool
    ) -> String {
        let count = candidate.menuBarItemCount
        let itemWord = count == 1 ? "item" : "items"
        let iconSource = presentation.descriptor.symbolName != nil
            ? "System symbol"
            : presentation.descriptor.usesFallback
                ? "Fallback icon"
                : "Installed application icon"
        let editability = blenny
            ? "Locked, required recovery control"
            : "Editable application item"
        #if BLENNY_PRODUCT || DEBUG
        let ordering = orderingAccessibilityDescription
        #else
        let ordering = ""
        #endif
        return "\(presentation.displayName), Policy: \(policy.interfaceTitle), Bundle ID: \(candidate.bundleIdentifier), \(count) menu bar \(itemWord), \(editability), \(iconSource)\(ordering)"
    }

    #if BLENNY_PRODUCT || DEBUG
    private var orderingAccessibilityDescription: String {
        guard let row = model.orderingRow(for: candidate.bundleIdentifier) else {
            return ", configuration position unverified"
        }
        switch row.availability {
        case .ready:
            return ", mapped for physical ordering"
        case .needsMapping:
            return ", visibility can be changed, sorting is unavailable"
        case .unverified:
            return ", configurable, mapping or observation unverified"
        case .blocked:
            return ", physical ordering unavailable: \(row.reason ?? "no supported ordering mapping")"
        }
    }
    #endif

}

struct FloatingItemName: View {
    let name: String
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Text(name)
            .font(.system(size: 9.5, weight: .medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .frame(width: labelWidth)
            .background(
                effectiveReduceTransparency
                    ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
                    : AnyShapeStyle(.regularMaterial),
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(Color(nsColor: .separatorColor), lineWidth: 0.75)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var labelWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: 9.5, weight: .medium)
        let measured = (name as NSString).size(withAttributes: [.font: font]).width + 12
        return min(max(52, ceil(measured)), 180)
    }

    private var effectiveReduceTransparency: Bool {
        reduceTransparency
            || debugAccessibilityFlag("BLENNY_VALIDATE_REDUCE_TRANSPARENCY")
    }
}

struct NaturalAspectSystemIcon: View {
    let presentation: ResolvedPolicyIcon
    let pointSize: CGFloat
    let frame: CGSize

    var body: some View {
        Group {
            if let symbolName = presentation.descriptor.symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: pointSize, weight: .regular))
                    .symbolRenderingMode(.monochrome)
            } else {
                Image(nsImage: presentation.image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            }
        }
        .frame(width: frame.width, height: frame.height)
        .foregroundStyle(.primary)
    }
}

struct UnidentifiedMenuBarBoardItem: View {
    let observation: UnattributedMenuBarItemObservation

    private var owner: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            $0.processIdentifier == observation.processIdentifier
        }
    }

    private var presentation: (name: String, symbol: String, detail: String) {
        let path = owner?.executableURL?.path ?? ""
        if path == "/usr/libexec/GamePolicyAgent" {
            return ("Game", "gamecontroller.fill",
                    "Apple GamePolicyAgent owns this menu extra. Its exact item identity is unverified.")
        }
        if path.contains(".app/Contents/SharedSupport/Wine/")
            && owner?.executableURL?.lastPathComponent == "wine" {
            if observation.itemHelp == "战网" || observation.itemHelp == "Battle.net" {
                return ("Battle.net", "wineglass.fill",
                        "A Wine loader owns this menu extra; its Accessibility help identifies Battle.net. The Windows process is not a Blenny writer target.")
            }
            return ("Wine", "wineglass.fill",
                    "A Wine loader owns this menu extra. The Windows program behind it is unverified.")
        }
        return (owner?.localizedName ?? "Unknown", "questionmark.app",
                "This process owns a menu extra but has no application Bundle ID.")
    }

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: presentation.symbol)
                .font(.system(size: 20))
                .frame(width: BlennyDesign.itemFrame.width,
                       height: BlennyDesign.itemFrame.height)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 7.5))
                        .foregroundStyle(.secondary)
                        .padding(3)
                }
            Text(presentation.name)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(width: 54)
        .help("\(presentation.detail) Blenny cannot manage it without an exact recovery-backed target. Refresh after the application changes.")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(presentation.name) menu bar item, process \(observation.processIdentifier), read only; \(presentation.detail)")
    }
}

struct SystemBoardItem: View {
    let observation: SystemMenuBarItemObservation
    let policy: MenuBarBundlePolicy
    @ObservedObject var model: ProductInterfaceModel
    @Binding var interaction: PolicyBoardInteractionState
    let contrast: ColorSchemeContrast
    let actions: ProductInterfaceActions
    let onMove: (String, MenuBarBundlePolicy) -> Void
    #if BLENNY_PRODUCT || DEBUG
    let orderingSubjectID: OrderingSubjectID?
    #endif
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var itemID: PolicyBoardItemID {
        .systemItem(observation.observationIdentifier)
    }

    var body: some View {
        let presentation = model.systemIcon(for: observation)
        systemItemSurface(presentation: presentation)
            .contextMenu {
                contextMenuContent
            }
            .accessibilityActions {
                if !policyDestinations.isEmpty {
                    ForEach(policyDestinations, id: \.self) { destination in
                        if destination != policy {
                            Button("Move to \(destination.interfaceTitle)") {
                                onMove(observation.observationIdentifier, destination)
                            }
                        }
                    }
                }
                #if BLENNY_PRODUCT || DEBUG
                orderingMoveActions
                #endif
                #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
                if !isControllable, let target = sharedTrialTarget {
                    sharedTrialButton(target)
                }
                #endif
            }
            .zIndex(showsName ? 20 : isSelected ? 10 : 0)
    }

    private func systemItemSurface(
        presentation: ResolvedPolicyIcon
    ) -> some View {
        let inputSurface = AnyView(
            systemArtwork(presentation: presentation)
                .onTapGesture(perform: select)
                .diagnosticFocusable($isFocused)
                .onKeyPress(
                    keys: [.return, .space],
                    action: handleSelectionKey
                )
        )
        let hoverSurface = AnyView(
            inputSurface
                .opacity(isDragSource ? 0.28 : 1)
                .scaleEffect(isDragSource && !effectiveReduceMotion ? 0.96 : 1)
                .animation(interactionAnimation, value: isDragSource)
            .onChange(of: isFocused) {
                withAnimation(.easeOut(duration: 0.10)) {
                    interaction.setFocused(itemID, isFocused: isFocused)
                }
            }
            .onHover { hovering in
                updateHover(hovering)
            }
        )
        return AnyView(
            hoverSurface
                .help(tooltip(for: presentation))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(for: presentation))
                .accessibilityHint(
                    isControllable
                        ? "Select, then open Item controls for details. Move between Visible, Revealable, and Hidden."
                        : hasSharedTrialControl
                        ? "Select for details and use the manual recovery action."
                        : "Select, then open Item controls for details. This macOS item is read only."
                )
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
                .accessibilityAddTraits(.isButton)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityAction(.default) {
                    select()
                }
        )
    }

    private func systemArtwork(
        presentation: ResolvedPolicyIcon
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(itemBackground)
                .frame(
                    width: BlennyDesign.itemChromeFrame.width,
                    height: BlennyDesign.itemChromeFrame.height
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(itemOutline, lineWidth: itemOutlineWidth)
                }
            if let dragPayload = sourcePayload {
                NaturalAspectSystemIcon(
                    presentation: presentation,
                    pointSize: 21,
                    frame: CGSize(width: 29, height: 25)
                )
                .policyBoardDragSource(dragPayload)
            } else {
                NaturalAspectSystemIcon(
                    presentation: presentation,
                    pointSize: 21,
                    frame: CGSize(width: 29, height: 25)
                )
            }
        }
        .frame(width: BlennyDesign.itemFrame.width, height: BlennyDesign.itemFrame.height)
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .overlay(alignment: .topTrailing) {
            Image(
                systemName: isControllable || hasSharedTrialControl
                    ? "checkmark.shield"
                    : "lock.fill"
            )
                .font(.system(size: 7.5, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(3)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .bottom) {
            if showsName {
                FloatingItemName(name: presentation.displayName)
                    .offset(y: 5)
                    .transition(.opacity)
            } else if observation.observationIdentifier == SystemMenuBarItemObservation.clockIdentifier {
                Text("Fixed")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .help("Clock cannot be sorted or moved to another group.")
            } else if isOrderingDeferred {
                Text("No sort")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
        }
    }

    private var isOrderingDeferred: Bool {
        #if BLENNY_PRODUCT || DEBUG
        model.availableSystemOrderingItem(
            for: observation.observationIdentifier
        ) == nil
        #else
        false
        #endif
    }

    private func select() {
        withAnimation(interactionAnimation) {
            interaction.select(itemID)
        }
    }

    private func updateHover(_ hovering: Bool) {
        guard interaction.draggedBundleIdentifier == nil else { return }
        interaction.setHovered(itemID, isHovered: hovering)
    }

    private func handleSelectionKey(_ keyPress: KeyPress) -> KeyPress.Result {
        select()
        return .handled
    }

    private var isSelected: Bool { interaction.selectedItem == itemID }
    private var isDragSource: Bool {
        #if BLENNY_PRODUCT || DEBUG
        guard let orderingSubjectID else { return false }
        return interaction.draggedBundleIdentifier
            == model.dragIdentifier(for: orderingSubjectID)
        #else
        return false
        #endif
    }
    private var sourcePayload: PolicyDragPayload? {
        #if BLENNY_PRODUCT || DEBUG
        switch DebugDragStartDiagnostics.mode {
        case .applicationSourcesOnly:
            return nil
        case .systemPayloadOnly:
            // Evaluate the original dependencies without registering a source.
            let payload = dragPayload
            DebugDragStartDiagnostics.record(payload == nil
                ? "system.payload.absent" : "system.payload.present")
            return nil
        default:
            break
        }
        #endif
        return dragPayload
    }

    private var dragPayload: PolicyDragPayload? {
        #if BLENNY_PRODUCT || DEBUG
        if let orderingSubjectID {
            return model.beginOrderingDragPayload(
                subjectID: orderingSubjectID,
                sourcePolicy: policy
            )
        }
        #endif
        guard isControllable else { return nil }
        return model.systemPolicyDragPayload(
            for: observation.observationIdentifier,
            sourcePolicy: policy
        )
    }
    private var isControllable: Bool {
        !policyDestinations.isEmpty
    }
    private var policyDestinations: [MenuBarBundlePolicy] {
        model.systemItemPolicyDestinations(
            for: observation.observationIdentifier
        )
    }

    private var hasSharedTrialControl: Bool {
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        guard let target = sharedTrialTarget else { return false }
        switch model.sharedSystemItemTrialPresentation(for: target) {
        case .ready, .busy, .recoveryRequired:
            return true
        case .checking, .hidden, .unavailable:
            return false
        }
        #else
        return false
        #endif
    }

    #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    private var sharedTrialTarget: SharedSystemItemTrialTarget? {
        model.sharedSystemItemTrialTarget(
            for: observation.observationIdentifier
        )
    }

    @ViewBuilder
    private func sharedTrialButton(_ target: SharedSystemItemTrialTarget) -> some View {
        switch model.sharedSystemItemTrialPresentation(for: target) {
        case .ready:
            Button("Hide \(target.displayName)") {
                actions.hideSharedSystemItem(target)
            }
        case .recoveryRequired:
            Button("Restore \(target.displayName)") {
                actions.restoreSharedSystemItem(target)
            }
        case .busy:
            Text("(target.displayName) operation in progress")
        case .checking:
            Text("Checking (target.displayName) state")
        case .hidden:
            Text("(target.displayName) is already hidden outside this trial")
        case .unavailable:
            Text("(target.displayName) control is unavailable")
        }
    }
    #endif

    @ViewBuilder
    private var contextMenuContent: some View {
        if isControllable {
            MoveToCommands(
                bundleIdentifier: observation.observationIdentifier,
                currentPolicy: policy,
                destinations: policyDestinations,
                onMove: onMove
            )
        } else {
            #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
            if let target = sharedTrialTarget {
                sharedTrialButton(target)
            } else {
                #if BLENNY_PRODUCT || DEBUG
                Text(orderingSubjectID == nil
                    ? "This macOS item is read only"
                    : "Visibility is unavailable")
                #else
                Text("This macOS item is read only")
                #endif
            }
            #else
            Text("This macOS item is read only")
            #endif
        }
        #if BLENNY_PRODUCT || DEBUG
        if orderingSubjectID != nil {
            Divider()
            orderingMoveActions
        }
        #endif
    }

    #if BLENNY_PRODUCT || DEBUG
    @ViewBuilder
    private var orderingMoveActions: some View {
        if let orderingSubjectID {
            let identifier = model.dragIdentifier(for: orderingSubjectID)
            Button("Move Left") {
                model.requestOrderingMove(identifier, direction: .left, in: policy)
            }
            .disabled(!model.canRequestOrderingMove(
                identifier, direction: .left, in: policy
            ))
            Button("Move Right") {
                model.requestOrderingMove(identifier, direction: .right, in: policy)
            }
            .disabled(!model.canRequestOrderingMove(
                identifier, direction: .right, in: policy
            ))
        }
    }
    #endif
    private var showsName: Bool {
        interaction.draggedBundleIdentifier == nil
            && interaction.namePresentationItem == itemID
    }

    private var itemBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.07) }
        if isFocused || interaction.hoveredItem == itemID {
            return Color.primary.opacity(0.055)
        }
        return .clear
    }

    private var itemOutline: Color {
        if isFocused { return Color.primary.opacity(0.72) }
        if contrast == .increased && isSelected { return Color.accentColor }
        return .clear
    }

    private var itemOutlineWidth: CGFloat {
        if contrast == .increased && (isSelected || isFocused) { return 2 }
        return isFocused ? 1.5 : 0
    }

    private var interactionAnimation: Animation {
        effectiveReduceMotion
            ? .easeOut(duration: 0.08)
            : .smooth(duration: 0.14, extraBounce: 0)
    }

    private var effectiveReduceMotion: Bool {
        reduceMotion || debugAccessibilityFlag("BLENNY_VALIDATE_REDUCE_MOTION")
    }

    private func tooltip(for presentation: ResolvedPolicyIcon) -> String {
        let description = "\(presentation.displayName)\n\(accessibilityLabel(for: presentation))"
        if observation.observationIdentifier == SystemMenuBarItemObservation.clockIdentifier {
            return "Clock is fixed: it cannot be sorted or moved to another group. While Blenny manages visibility, open Notification Center by swiping left from the trackpad’s right edge; clicking Clock is unavailable on the tested macOS build."
        }
        #if BLENNY_PRODUCT || DEBUG
        if model.availableSystemOrderingItem(
            for: observation.observationIdentifier
        ) == nil {
            return description + "\n" + model.systemItemCapabilityExplanation(
                for: observation.observationIdentifier
            ) + "\nSorting is unavailable until its exact position preflight succeeds."
        }
        if orderingSubjectID != nil {
            return description + "\nThis exact system control participates independently in the reviewed configuration order."
        }
        return description + "\nThis system control has no exact ordering mapping."
        #else
        return description
        #endif
    }

    private func accessibilityLabel(for presentation: ResolvedPolicyIcon) -> String {
        let count = observation.observationCount
        let occurrence = count == 1 ? "observation" : "observations"
        let iconSource = presentation.descriptor.usesFallback
            ? "Fallback icon"
            : "System symbol"
        let access = controllabilityDescription
        return "\(presentation.displayName), macOS system item, Owner: \(observation.ownerBundleIdentifier), Identifier: \(observation.observationIdentifier), \(count) \(occurrence), \(access), \(iconSource)"
    }

    private var controllabilityDescription: String {
        guard isControllable || hasSharedTrialControl else {
            #if BLENNY_PRODUCT || DEBUG
            if orderingSubjectID != nil {
                return "Exact sorting available; three-state visibility unavailable"
            }
            #endif
            if observation.observationIdentifier == SystemMenuBarItemObservation.clockIdentifier {
                return "Read only; Clock is fixed by macOS"
            }
            if observation.observationIdentifier == "com.apple.menuextra.now-playing" {
                return "Read only; macOS hides Now Playing while management is on, including when expanded"
            }
            return "Read only; no verified policy interface"
        }
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        return isControllable
            ? "Three-state Visible, Revealable, and Hidden policy control"
            : "Experimental manual hide and exact restore control"
        #else
        return "Policy control enabled"
        #endif
    }
}

#if BLENNY_PRODUCT || DEBUG
@MainActor
func policyDragItemProvider(
    for payload: PolicyDragPayload
) -> NSItemProvider {
    #if BLENNY_PRODUCT || DEBUG
    DebugDragStartDiagnostics.beginAttempt()
    DebugDragStartDiagnostics.record("provider.request", stack: true)
    #endif
    let provider = NSItemProvider()
    provider.register(payload)
    return provider
}
#endif
