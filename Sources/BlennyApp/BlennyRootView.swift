import AppKit
import BlennyCore
import SwiftUI

struct BlennyRootView: View {
    @ObservedObject var model: ProductInterfaceModel
    let actions: ProductInterfaceActions
    @State private var boardInteraction = PolicyBoardInteractionState()

    init(model: ProductInterfaceModel, actions: ProductInterfaceActions) {
        self.model = model
        self.actions = actions
        var initialInteraction = PolicyBoardInteractionState()
        #if DEBUG
        switch ProcessInfo.processInfo.environment["BLENNY_VALIDATE_BOARD_STATE"] {
        case "hover":
            initialInteraction.setHovered(
                .application(
                    "com.example.FallbackMenuAgentWithAnIntentionallyLongDisplayName"
                ),
                isHovered: true
            )
        case "selected":
            initialInteraction.select(.application("com.apple.Notes"))
        case "drag-valid":
            initialInteraction.beginDrag(
                bundleIdentifier: "com.apple.mail",
                sourcePolicy: .revealable
            )
            initialInteraction.target(policy: .hidden, validation: .changed)
        case "drag-invalid":
            initialInteraction.beginDrag(
                bundleIdentifier: "com.apple.Notes",
                sourcePolicy: .visible
            )
            initialInteraction.target(
                policy: .visible,
                validation: .rejected(.samePolicy)
            )
        case "settled":
            initialInteraction.completeDrop(
                payload: PolicyDragPayload(
                    bundleIdentifier: "com.apple.Safari",
                    sourcePolicy: .revealable,
                    candidateGeneration: UUID()
                ),
                destination: .hidden,
                outcome: .changed
            )
        default:
            break
        }
        #endif
        _boardInteraction = State(initialValue: initialInteraction)
    }

    var body: some View {
        VStack(spacing: 0) {
            ProductNavigationBar(
                selection: model.navigation.section,
                onSelect: { model.navigate(to: $0) }
            )
            Divider()
            Group {
                switch model.navigation.section {
                case .organize:
                    OrganizeView(model: model, actions: actions, interaction: $boardInteraction)
                case .settings:
                    SettingsView(model: model, actions: actions)
                case .support:
                    SupportView(actions: actions)
                }
            }
        }
        .frame(
            minWidth: 560,
            minHeight: 360
        )
        .onChange(of: model.navigation.section) {
            boardInteraction.clearTransientPresentation()
        }
        .onChange(of: model.isRefreshing) {
            if model.isRefreshing {
                boardInteraction.clearTransientPresentation()
            }
        }
        .onChange(of: model.candidateGeneration) {
            boardInteraction.clearAll()
        }
    }
}

private func debugAccessibilityFlag(_ key: String) -> Bool {
    #if DEBUG
    ProcessInfo.processInfo.environment[key] == "YES"
    #else
    false
    #endif
}

private enum BlennyDesign {
    static let navigationHeight: CGFloat = 54
    static let boardRadius: CGFloat = 10
    static let laneHeight: CGFloat = 60
    static let iconFrame: CGFloat = 34
    static let itemFrame = CGSize(width: 48, height: 50)
    static let itemChromeFrame = CGSize(width: 40, height: 40)

    static let coral = Color(nsColor: NSColor(
        name: NSColor.Name("BlennyCoral")
    ) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(srgbRed: 1.00, green: 0.46, blue: 0.42, alpha: 1)
            : NSColor(srgbRed: 0.94, green: 0.36, blue: 0.33, alpha: 1)
    })
}

private struct ProductNavigationBar: View {
    let selection: ProductInterfaceSection
    let onSelect: (ProductInterfaceSection) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast


    var body: some View {
        HStack(spacing: navigationItemSpacing) {
            ForEach(ProductInterfaceSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(navigationAnimation) {
                        onSelect(section)
                    }
                } label: {
                    navigationLabel(section)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .foregroundStyle(
                    selection == section ? Color.primary : Color.secondary
                )
                .accessibilityValue(
                    selection == section ? "Selected" : "Not selected"
                )
                .accessibilityAddTraits(selection == section ? .isSelected : [])
            }
        }
        .padding(navigationTrackPadding)
        .background { navigationTrack }
        .frame(maxWidth: .infinity)
        .frame(height: BlennyDesign.navigationHeight)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Blenny section")
    }

    private var navigationTrack: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(
                    effectiveReduceTransparency
                        ? Color(nsColor: .controlBackgroundColor)
                        : Color.primary.opacity(0.045)
                )

            selectionLens
                .offset(x: selectionLensOffset)
                .animation(navigationAnimation, value: selection)
        }
        .overlay {
            Capsule().stroke(
                Color(nsColor: .separatorColor).opacity(
                    effectiveContrast == .increased ? 0.9 : 0.45
                ),
                lineWidth: effectiveContrast == .increased ? 1.25 : 0.5
            )
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var selectionLens: some View {
        if effectiveReduceTransparency {
            Capsule()
                .fill(Color.accentColor.opacity(
                    effectiveContrast == .increased ? 0.16 : 0.08
                ))
                .overlay {
                    if effectiveContrast == .increased {
                        Capsule().stroke(Color.accentColor, lineWidth: 1.25)
                    }
                }
                .frame(width: navigationItemWidth, height: navigationItemHeight)
        } else {
            GlassEffectContainer(spacing: 0) {
                Color.clear
                    .frame(width: navigationItemWidth, height: navigationItemHeight)
                    .glassEffect(
                        .regular
                            .tint(Color.accentColor.opacity(
                                effectiveContrast == .increased ? 0.16 : 0.09
                            )),
                        in: Capsule()
                    )
            }
            .frame(width: navigationItemWidth, height: navigationItemHeight)
            .allowsHitTesting(false)
        }
    }

    private func navigationLabel(
        _ section: ProductInterfaceSection
    ) -> some View {
        Label(section.title, systemImage: section.symbolName)
            .font(
                .system(
                    .callout,
                    design: .default,
                    weight: selection == section ? .medium : .regular
                )
            )
            .frame(width: navigationItemWidth, height: navigationItemHeight)
            .contentShape(Capsule())
    }

    private var selectionLensOffset: CGFloat {
        let index = ProductInterfaceSection.allCases.firstIndex(of: selection) ?? 0
        return navigationTrackPadding
            + CGFloat(index) * (navigationItemWidth + navigationItemSpacing)
    }

    private var navigationItemWidth: CGFloat { 112 }
    private var navigationItemHeight: CGFloat { 28 }
    private var navigationItemSpacing: CGFloat { 4 }
    private var navigationTrackPadding: CGFloat { 5 }

    private var navigationAnimation: Animation {
        effectiveReduceMotion
            ? .easeOut(duration: 0.08)
            : .spring(duration: 0.30, bounce: 0.06)
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

private struct OrganizeView: View {
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
                    #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
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
                #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
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
                #if DEBUG
                DebugOrderingStatusBar(
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

    #if DEBUG
    private var debugBoardFooter: String {
        if model.orderingLayoutDraft?.hasChanges == true {
            return "Configuration draft · Global target: Hidden → Revealable → Visible · Apply reports any owner that still needs mapping"
        }
        return "Drag before, after, or to the end of any area · Missing mapping remains informational · No polling"
    }
    #endif
}

private struct OrganizationBoard: View {
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
                    #if DEBUG
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
        .dropPreviewsFormation(.none)
        .onDragSessionUpdated(updateDragSession)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Organization Board")
    }

    private func updateDragSession(_ session: DragSession) {
        let identities = session.draggedItemIDs(for: PolicyDragPayload.ID.self)
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
        #if DEBUG
        if retirePayload, let identity {
            model.retireOrderingDragSession(identity)
        }
        #endif
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
        #if DEBUG
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

    #if DEBUG
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
            ? "Enable Blenny in System Settings, then return here."
            : "Allow Accessibility so Blenny can identify your menu bar items."
    }

    private var permissionButtonTitle: String {
        model.accessibilityPromptRequested ? "Open System Settings" : "Set Up Accessibility…"
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

private struct BoardInterruptionPanel: View {
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

private struct PolicyLaneRow: View {
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
    #if DEBUG
    let onLayoutDrop: (PolicyDragPayload, OrderingBoardLayoutDestination) -> Void
    @State private var orderingLandingSession = OrderingBoardLandingSession()
    #endif

    var body: some View {
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
                    #if DEBUG
                    let exactSystemItems = model.exactSystemOrderingItems(in: policy)
                    let orderingItems = mixedOrderingItems(
                        applications: candidates,
                        systemItems: exactSystemItems
                    )
                    let residualSystemItems = systemItems.filter { observation in
                        ExactSystemOrderingItem(
                            observationIdentifier: observation.observationIdentifier
                        )?.isOrderingOffered != true
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
                    #if DEBUG
                    if candidates.isEmpty && exactSystemItems.isEmpty
                        && residualSystemItems.isEmpty {
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
                    }
                    #else
                    if candidates.isEmpty && appleSystemCandidates.isEmpty
                        && applicationLandingPreview == nil
                        && appleSystemLandingPreview == nil && systemItems.isEmpty {
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

                            ForEach(systemItems, id: \.observationIdentifier) { item in
                                systemBoardItem(item)
                            }
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
                    .dropDestination(for: PolicyDragPayload.self) { payloads, session in
                        acceptDrop(payloads, in: session)
                    }
                    .dropConfiguration(dropConfiguration)
                    .onDropSessionUpdated(updateDropSession)
                    .padding(.horizontal, 5)
                }
                .scrollIndicators(.hidden)
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
        #if DEBUG
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
        #if DEBUG
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

    private func systemBoardItem(
        _ item: SystemMenuBarItemObservation
    ) -> some View {
        #if DEBUG
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

    #if DEBUG
    private func systemBoardItem(
        _ item: SystemMenuBarItemObservation,
        orderingSubjectID: OrderingSubjectID
    ) -> some View {
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
    #endif

    #if DEBUG
    private enum MixedOrderingItem: Identifiable {
        case application(PolicyCandidate)
        case system(DebugExactSystemBoardItem)

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
        systemItems: [DebugExactSystemBoardItem]
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

    private var systemControlLabel: String {
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        "Experimental"
        #else
        "Bluetooth enabled"
        #endif
    }

    private var systemControlHelp: String {
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        "Experimental Debug-only system-item policy controls. Unsupported identities remain read only."
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
        #if DEBUG
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
        #if DEBUG
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
                    #if DEBUG
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
                #if DEBUG
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
                    #if DEBUG
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
        #if DEBUG
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
        #if DEBUG
        if let item = ExactSystemOrderingItem(
            observationIdentifier: bundleIdentifier
        ), item.isOrderingOffered {
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

private struct PolicyLaneLandingPreview: View {
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

private struct ApplicationBoardItem: View {
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
                : model.dragPayload(
                    bundleIdentifier: candidate.bundleIdentifier,
                    sourcePolicy: policy
                )
        )
        .contextMenu {
            if !blenny {
                MoveToCommands(
                    bundleIdentifier: candidate.bundleIdentifier,
                    currentPolicy: policy,
                    onMove: onMove
                )
                #if DEBUG
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
                #if DEBUG
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
            .focusable()
            .focusEffectDisabled()
            .focused($isFocused)
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
                withAnimation(.easeOut(duration: 0.10)) {
                    interaction.setHovered(itemID, isHovered: hovering)
                }
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
        #if DEBUG
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
            #if DEBUG
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
                .contentShape(
                    .dragPreview,
                    RoundedRectangle(cornerRadius: 8)
                )
                .draggable(PolicyDragPayload.self) {
                    currentDragPayload(fallback: payload)
                }
                .dragConfiguration(DragConfiguration(allowMove: true))
                .id(payload.id)
        } else {
            policyIcon(presentation: presentation)
        }
    }

    private func currentDragPayload(fallback: PolicyDragPayload) -> PolicyDragPayload? {
        #if DEBUG
        guard let subjectID = model.orderingSubject(
            forDragIdentifier: candidate.bundleIdentifier
        ) else { return nil }
        return model.beginOrderingDragPayload(
            subjectID: subjectID,
            sourcePolicy: policy
        )
        #else
        return fallback
        #endif
    }

    private func select() {
        withAnimation(interactionAnimation) {
            interaction.select(itemID)
        }
    }

    #if DEBUG
    private var orderingStateSymbol: String? {
        guard !model.isBlenny(candidate.bundleIdentifier),
              let row = model.orderingRow(for: candidate.bundleIdentifier) else {
            return "questionmark.circle"
        }
        switch row.availability {
        case .ready: return nil
        case .needsMapping: return "link.badge.plus"
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
    private var showsName: Bool { interaction.namePresentationItem == itemID }
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
        #if DEBUG
        let ordering = orderingAccessibilityDescription
        #else
        let ordering = ""
        #endif
        return "\(presentation.displayName), Policy: \(policy.interfaceTitle), Bundle ID: \(candidate.bundleIdentifier), \(count) menu bar \(itemWord), \(editability), \(iconSource)\(ordering)"
    }

    #if DEBUG
    private var orderingAccessibilityDescription: String {
        guard let row = model.orderingRow(for: candidate.bundleIdentifier) else {
            return ", configuration position unverified"
        }
        switch row.availability {
        case .ready:
            return ", mapped for physical ordering"
        case .needsMapping:
            return ", configurable, needs physical ordering mapping"
        case .unverified:
            return ", configurable, mapping or observation unverified"
        case .blocked:
            return ", physical ordering unavailable: \(row.reason ?? "no supported ordering mapping")"
        }
    }
    #endif

}

private struct FloatingItemName: View {
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

private struct NaturalAspectSystemIcon: View {
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

private struct SystemBoardItem: View {
    let observation: SystemMenuBarItemObservation
    let policy: MenuBarBundlePolicy
    @ObservedObject var model: ProductInterfaceModel
    @Binding var interaction: PolicyBoardInteractionState
    let contrast: ColorSchemeContrast
    let actions: ProductInterfaceActions
    let onMove: (String, MenuBarBundlePolicy) -> Void
    #if DEBUG
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
                #if DEBUG
                orderingMoveActions
                #endif
                #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
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
                .focusable()
                .focusEffectDisabled()
                .focused($isFocused)
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
                    withAnimation(.easeOut(duration: 0.10)) {
                        interaction.setHovered(itemID, isHovered: hovering)
                    }
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
            if let dragPayload {
                NaturalAspectSystemIcon(
                    presentation: presentation,
                    pointSize: 21,
                    frame: CGSize(width: 29, height: 25)
                )
                .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 8))
                .draggable(PolicyDragPayload.self) {
                    currentSystemDragPayload()
                }
                .dragConfiguration(DragConfiguration(allowMove: true))
                .id(dragPayload.id)
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
        #if DEBUG
        ExactSystemOrderingItem(observationIdentifier: observation.observationIdentifier)?.isOrderingOffered == false
        #else
        false
        #endif
    }

    private func select() {
        withAnimation(interactionAnimation) {
            interaction.select(itemID)
        }
    }

    private func handleSelectionKey(_ keyPress: KeyPress) -> KeyPress.Result {
        select()
        return .handled
    }

    private var isSelected: Bool { interaction.selectedItem == itemID }
    private var isDragSource: Bool {
        #if DEBUG
        guard let orderingSubjectID else { return false }
        return interaction.draggedBundleIdentifier
            == model.dragIdentifier(for: orderingSubjectID)
        #else
        return false
        #endif
    }
    private func currentSystemDragPayload() -> PolicyDragPayload? {
        #if DEBUG
        if let orderingSubjectID {
            return model.beginOrderingDragPayload(subjectID: orderingSubjectID, sourcePolicy: policy)
        }
        #endif
        return model.systemPolicyDragPayload(
            for: observation.observationIdentifier,
            sourcePolicy: policy
        )
    }
    private var dragPayload: PolicyDragPayload? {
        #if DEBUG
        if let orderingSubjectID {
            return model.dragPayload(subjectID: orderingSubjectID, sourcePolicy: policy)
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
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
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

    #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
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
            #if DEBUG
            Divider()
            orderingMoveActions
            #endif
        } else {
            #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
            if let target = sharedTrialTarget {
                sharedTrialButton(target)
            } else {
                Text("This macOS item is read only")
            }
            #else
            Text("This macOS item is read only")
            #endif
        }
    }

    #if DEBUG
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
    private var showsName: Bool { interaction.namePresentationItem == itemID }

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
        #if DEBUG
        if ExactSystemOrderingItem(observationIdentifier: observation.observationIdentifier)?.isOrderingOffered == false {
            return description + "\nSorting is not supported in this version. Moving between Visible, Revealable, and Hidden remains available."
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
            if observation.observationIdentifier == SystemMenuBarItemObservation.clockIdentifier {
                return "Read only; Clock is fixed by macOS"
            }
            return "Read only; no verified policy interface"
        }
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        return isControllable
            ? "Three-state Visible, Revealable, and Hidden policy control"
            : "Experimental manual hide and exact restore control"
        #else
        return "Policy control enabled"
        #endif
    }
}

private struct SelectionDetailRail: View {
    @ObservedObject var model: ProductInterfaceModel
    @Binding var interaction: PolicyBoardInteractionState
    let actions: ProductInterfaceActions
    let onMove: (String, MenuBarBundlePolicy) -> Void

    var body: some View {
        HStack(spacing: 9) {
            selectionContent
            Spacer(minLength: 8)
            selectionAction
        }
        .padding(.horizontal, 10)
        #if DEBUG
        .frame(minHeight: 42)
        #else
        .frame(height: 42)
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selection details")
    }

    @ViewBuilder
    private var selectionContent: some View {
        switch interaction.selectedItem {
        case .application(let bundleIdentifier):
            if let candidate = model.candidate(bundleIdentifier: bundleIdentifier),
               let policy = model.model?.effectivePolicy(for: bundleIdentifier) {
                let presentation = model.applicationIcon(for: bundleIdentifier)
                NaturalAspectSystemIcon(
                    presentation: presentation,
                    pointSize: 17,
                    frame: CGSize(width: 24, height: 24)
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(presentation.displayName)
                        .font(.system(.subheadline, weight: .medium))
                        .lineLimit(1)
                    Text(applicationDetail(candidate, policy: policy, presentation: presentation))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(applicationDetail(candidate, policy: policy, presentation: presentation))
                    #if DEBUG
                    Text(model.orderingExplanation(for: bundleIdentifier))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    #endif
                }
                if model.isBlenny(bundleIdentifier) {
                    Label("Locked Visible", systemImage: "lock.fill")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(BlennyDesign.coral)
                }
            } else {
                unavailableSelection
            }
        case .systemItem(let observationIdentifier):
            if let observation = model.systemItem(observationIdentifier: observationIdentifier) {
                let presentation = model.systemIcon(for: observation)
                NaturalAspectSystemIcon(
                    presentation: presentation,
                    pointSize: 17,
                    frame: CGSize(width: 22, height: 22)
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(presentation.displayName)
                        .font(.system(.subheadline, weight: .medium))
                    Text(systemItemDetail(observation))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    #if DEBUG
                    Text(systemPolicyDetail(for: observationIdentifier))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    #endif
                }
                if let policy = model.effectiveSystemItemPolicy(
                    for: observationIdentifier
                ) {
                    Label(policy.interfaceTitle, systemImage: "checkmark.shield")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(BlennyDesign.coral)
                } else if hasSharedTrialControl(for: observationIdentifier) {
                    Label("Manual control", systemImage: "checkmark.shield")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(BlennyDesign.coral)
                } else {
                    Label("Read only", systemImage: "lock.fill")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } else {
                unavailableSelection
            }
        case nil:
            Image(systemName: "cursorarrow.click.2")
                .foregroundStyle(.secondary)
            Text("Select an item for details, or drag to arrange.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var selectionAction: some View {
        switch interaction.selectedItem {
        case .application(let bundleIdentifier):
            if let policy = model.model?.effectivePolicy(for: bundleIdentifier),
               !model.isBlenny(bundleIdentifier) {
                #if DEBUG
                Button {
                    model.requestOrderingMove(bundleIdentifier, direction: .left, in: policy)
                } label: {
                    Image(systemName: "arrow.left")
                }
                .help("Move one position left.")
                .accessibilityLabel("Move Left")
                .disabled(!model.canRequestOrderingMove(bundleIdentifier, direction: .left, in: policy))
                Button {
                    model.requestOrderingMove(bundleIdentifier, direction: .right, in: policy)
                } label: {
                    Image(systemName: "arrow.right")
                }
                .help("Move one position right.")
                .accessibilityLabel("Move Right")
                .disabled(!model.canRequestOrderingMove(bundleIdentifier, direction: .right, in: policy))
                #endif
                MoveToMenu(
                    bundleIdentifier: bundleIdentifier,
                    currentPolicy: policy,
                    onMove: onMove
                )
            }
        case .systemItem(let identifier):
            if let policy = model.effectiveSystemItemPolicy(for: identifier) {
                MoveToMenu(
                    bundleIdentifier: identifier,
                    currentPolicy: policy,
                    destinations: model.systemItemPolicyDestinations(for: identifier),
                    onMove: onMove
                )
            } else {
                #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
                if let target = model.sharedSystemItemTrialTarget(for: identifier) {
                    sharedTrialButton(target)
                }
                #endif
            }
        case nil:
            EmptyView()
        }
    }

    private func hasSharedTrialControl(for identifier: String) -> Bool {
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        guard let target = model.sharedSystemItemTrialTarget(for: identifier) else {
            return false
        }
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

    #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    @ViewBuilder
    private func sharedTrialButton(_ target: SharedSystemItemTrialTarget) -> some View {
        switch model.sharedSystemItemTrialPresentation(for: target) {
        case .ready:
            Button("Hide", action: { actions.hideSharedSystemItem(target) })
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        case .recoveryRequired:
            Button("Restore", action: { actions.restoreSharedSystemItem(target) })
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        case .busy:
            ProgressView().controlSize(.small)
        case .checking, .hidden, .unavailable:
            EmptyView()
        }
    }
    #endif

    private var unavailableSelection: some View {
        Label("The selected item is no longer in this observation.", systemImage: "questionmark.circle")
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
    }

    private func applicationDetail(
        _ candidate: PolicyCandidate,
        policy: MenuBarBundlePolicy,
        presentation: ResolvedPolicyIcon
    ) -> String {
        let itemWord = candidate.menuBarItemCount == 1 ? "item" : "items"
        let fallback = presentation.descriptor.usesFallback ? " · fallback icon" : ""
        return "\(candidate.menuBarItemCount) menu bar \(itemWord) · \(policy.interfaceTitle)\(fallback)"
    }

    private func systemItemDetail(_ observation: SystemMenuBarItemObservation) -> String {
        observation.observationCount == 0 ? "Not seen in the last refresh." : "macOS item"
    }

    private func systemPolicyDetail(for identifier: String) -> String {
        if identifier == SystemMenuBarItemObservation.clockIdentifier {
            return "Clock clicks may not open Notification Center while managing visibility. See Support for the trackpad gesture."
        }
        #if DEBUG
        if ExactSystemOrderingItem(observationIdentifier: identifier)?.isOrderingOffered == false {
            return "Visibility can change. Sorting is not supported."
        }
        #endif
        if model.systemItemPolicyDestinations(for: identifier)
            == [.visible, .revealable, .hidden] {
            return "Choose Visible, Revealable or Hidden. macOS controls on-screen placement."
        }
        #if DEBUG
        if let item = ExactSystemOrderingItem(observationIdentifier: identifier),
           model.orderingRow(for: .systemItem(item)) != nil {
            return "This exact system item can be reordered, but no three-state visibility policy is currently available."
        }
        #endif
        return "This macOS item does not expose a three-state Blenny policy."
    }
}

private struct MoveToMenu: View {
    let bundleIdentifier: String
    let currentPolicy: MenuBarBundlePolicy
    let destinations: [MenuBarBundlePolicy]
    let onMove: (String, MenuBarBundlePolicy) -> Void

    init(
        bundleIdentifier: String,
        currentPolicy: MenuBarBundlePolicy,
        destinations: [MenuBarBundlePolicy] = MenuBarBundlePolicy.allCases,
        onMove: @escaping (String, MenuBarBundlePolicy) -> Void
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.currentPolicy = currentPolicy
        self.destinations = destinations
        self.onMove = onMove
    }

    var body: some View {
        Menu {
            MoveToCommands(
                bundleIdentifier: bundleIdentifier,
                currentPolicy: currentPolicy,
                destinations: destinations,
                onMove: onMove
            )
        } label: {
            Label("Move to…", systemImage: "arrow.right.circle")
        }
        .controlSize(.small)
        .accessibilityHint("Moves the selected application without dragging")
    }
}

private struct MoveToCommands: View {
    let bundleIdentifier: String
    let currentPolicy: MenuBarBundlePolicy
    let destinations: [MenuBarBundlePolicy]
    let onMove: (String, MenuBarBundlePolicy) -> Void

    init(
        bundleIdentifier: String,
        currentPolicy: MenuBarBundlePolicy,
        destinations: [MenuBarBundlePolicy] = MenuBarBundlePolicy.allCases,
        onMove: @escaping (String, MenuBarBundlePolicy) -> Void
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.currentPolicy = currentPolicy
        self.destinations = destinations
        self.onMove = onMove
    }

    var body: some View {
        ForEach(destinations, id: \.self) { destination in
            Button {
                onMove(bundleIdentifier, destination)
            } label: {
                if destination == currentPolicy {
                    Label(destination.interfaceTitle, systemImage: "checkmark")
                } else {
                    Text(destination.interfaceTitle)
                }
            }
            .disabled(destination == currentPolicy)
        }
    }
}

private struct ObservationAndDraftFooter: View {
    @ObservedObject var model: ProductInterfaceModel
    let actions: ProductInterfaceActions
    @Binding var interaction: PolicyBoardInteractionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingDiscoveryWarnings = false

    var body: some View {
        HStack(spacing: 10) {
            observationStatus
            if !model.statusIsError, !model.hasDraftChanges,
               ["Changes applied", "Changes discarded", "Done"].contains(model.statusMessage) {
                Text(model.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }


            Spacer(minLength: 10)

            HStack(spacing: 6) {
                Button("Discard Changes") {
                    var discardedEditor: PolicyEditorViewModel?
                    withAnimation(discardAnimation) {
                        discardedEditor = model.discardDraft()
                        interaction.clearAll()
                    }
                    guard let editor = discardedEditor else { return }
                    actions.draftDidChange(editor)
                }
                .disabled(!model.controls.discardDraftEnabled)

                Button(applyTitle, action: applyChanges)
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.controls.applyEnabled || !model.hasDraftChanges)
                    .keyboardShortcut(.defaultAction)
            }
            .frame(minWidth: 216, alignment: .trailing)
            .opacity(model.hasDraftChanges ? 1 : 0)
            .allowsHitTesting(model.hasDraftChanges)
            .accessibilityHidden(!model.hasDraftChanges)

            Button(action: actions.refresh) {
                Label(
                    model.isRefreshing ? "Refreshing" : "Refresh",
                    systemImage: model.isRefreshing
                        ? "arrow.clockwise.circle.fill"
                        : "arrow.clockwise"
                )
            }
            .disabled(!model.controls.refreshEnabled)
            .help(refreshHelp)
        }
        .controlSize(.small)
        .padding(.horizontal, 18)
        .frame(height: 46)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Draft and manual observation controls")
    }

    private var applyTitle: String {
        #if DEBUG
        if model.orderingPresentation.requiresUndoReplacement { return "Replace Undo & Apply" }
        #endif
        return model.isApplying ? "Applying…" : "Apply"
    }

    private func applyChanges() {
        #if DEBUG
        let presentation = model.orderingPresentation
        if presentation.requiresUndoReplacement {
            guard presentation.canApply, let preview = presentation.preview else { return }
            presentation.requestApply(fingerprint: preview.fingerprint)
            return
        }
        #endif
        actions.applyDraft()
    }

    @ViewBuilder
    private var observationStatus: some View {
        if model.discoveryWarnings.isEmpty {
            Label(
                observationSummary,
                systemImage: model.hasDraftChanges ? "pencil.line" : "eye"
            )
            .font(.system(size: 10.5))
            .foregroundStyle(model.hasDraftChanges ? Color.primary : Color.secondary)
            .lineLimit(1)
            .help("Only successfully attributed menu-bar applications are candidates.")
        } else {
            Button {
                showingDiscoveryWarnings.toggle()
            } label: {
                Label(observationSummary, systemImage: "exclamationmark.circle")
                    .font(.system(size: 10.5))
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Show the exact applications whose menu-bar roots were unreadable.")
            .popover(isPresented: $showingDiscoveryWarnings, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Some apps could not be read")
                        .font(.system(.headline, weight: .medium))
                    Text("Some apps could not be checked. Details are listed below.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(
                                Array(model.discoveryWarnings.enumerated()),
                                id: \.offset
                            ) { _, warning in
                                Text(warning)
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
                .padding(16)
                .frame(width: 510)
            }
        }
    }

    private var observationSummary: String {
        if model.isApplying { return "Applying changes…" }
        if model.hasDraftChanges {
            return "Changes not applied"
        }
        guard model.accessibilityTrusted else {
            return "Accessibility required · Manual observation"
        }
        guard model.model != nil else {
            return "No completed observation · Manual refresh only"
        }
        let appSuffix = model.observationCount == 1 ? "" : "s"
        let systemSuffix = model.systemItems.count == 1 ? "" : "s"
        if !model.discoveryWarnings.isEmpty {
            return "\(model.observationCount) app\(appSuffix) · Some apps could not be read"
        }
        return "\(model.observationCount) app\(appSuffix) · \(model.systemItems.count) system item\(systemSuffix)"
    }

    private var refreshHelp: String {
        if !model.accessibilityTrusted {
            return "Grant Accessibility, then return to Blenny for one automatic refresh."
        }
        if model.hasDraftChanges {
            return "Apply or discard your changes before refreshing."
        }
        return "Update the menu bar items."
    }

    private var discardAnimation: Animation {
        effectiveReduceMotion
            ? .easeOut(duration: 0.08)
            : .smooth(duration: 0.18, extraBounce: 0)
    }

    private var effectiveReduceMotion: Bool {
        reduceMotion || debugAccessibilityFlag("BLENNY_VALIDATE_REDUCE_MOTION")
    }
}

private struct SettingsView: View {
    @ObservedObject var model: ProductInterfaceModel
    let actions: ProductInterfaceActions

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 22) {
                ProductPageHeader(
                    title: "Settings",
                    subtitle: "Permissions and startup."
                )

            ProductPageSection(title: "Permission", systemImage: "hand.raised") {
                SettingsGridRow {
                    Label(
                        model.accessibilityTrusted
                            ? "Accessibility granted"
                            : "Accessibility not granted",
                        systemImage: model.accessibilityTrusted
                            ? "checkmark.shield.fill"
                            : "exclamationmark.shield.fill"
                    )
                    .foregroundStyle(model.accessibilityTrusted ? .green : .orange)
                } detail: {
                    Text(permissionDescription)
                } control: {
                    if !model.accessibilityTrusted {
                        Button(permissionButtonTitle, action: actions.requestAccess)
                            .controlSize(.small)
                    }
                }
            }

            ProductPageSection(title: "Startup", systemImage: "power") {
                SettingsGridRow {
                    Text("Open at Login")
                } detail: {
                    Text(model.launchAtLoginState.statusDescription)
                        .foregroundStyle(
                            model.launchAtLoginState.failureMessage == nil
                                ? Color.secondary
                                : Color.red
                        )
                } control: {
                    HStack(spacing: 8) {
                        if model.launchAtLoginState.requiresApproval {
                            Button("Open Login Items", action: actions.openLoginItemsSettings)
                                .controlSize(.small)
                        }
                        Toggle(
                            "Open Blenny at Login",
                            isOn: Binding(
                                get: { model.launchAtLoginState.isToggleOn },
                                set: { enabled in
                                    actions.setLaunchAtLogin(enabled)
                                }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityLabel("Open Blenny at Login")
                        .accessibilityValue(
                            model.launchAtLoginState.isToggleOn ? "On" : "Off"
                        )
                    }
                }
            }

            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var permissionDescription: String {
        if model.accessibilityTrusted {
            return "Allows Blenny to read menu bar items."
        }
        if model.accessibilityPromptRequested {
            return "Enable Blenny in System Settings, then return here."
        }
        return "Allow Blenny to read menu bar items."
    }

    private var permissionButtonTitle: String {
        model.accessibilityPromptRequested ? "Open System Settings" : "Set Up Accessibility…"
    }

}

private struct SupportView: View {
    let actions: ProductInterfaceActions

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 22) {
                ProductPageHeader(
                    title: "Support",
                    subtitle: "Project information and support."
                )

                HStack(alignment: .center, spacing: 15) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 58, height: 58)
                        .accessibilityLabel("Blenny application icon")
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Blenny")
                            .font(.system(.title2, design: .rounded, weight: .medium))
                        Text("Version \(applicationVersion) · A quiet home for menu bar icons.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button(action: actions.openProjectWebsite) {
                            Label("Website", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.link)
                        .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                        Text("If Blenny is useful to you, help support its development.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 12) {
                            Button(action: actions.openOneTimeSponsor) {
                                Label("Sponsor once", systemImage: "heart")
                            }
                            Button(action: actions.openMonthlySponsor) {
                                Label("Sponsor monthly", systemImage: "heart.fill")
                            }
                            Button(action: actions.openKoFi) {
                                Label("Ko-fi", systemImage: "cup.and.saucer.fill")
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Link(destination: URL(string: ProductSupportLinks.documentation)!) {
                Label("Help & Documentation", systemImage: "arrow.up.right.square")
            }
            .font(.callout)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var applicationVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "0.5.0"
    }
}

private struct ProductPageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.largeTitle)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProductPageSection<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.system(.callout, weight: .medium))
                .foregroundStyle(.secondary)
            Divider()
            content
                .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

private struct SettingsGridRow<Title: View, Detail: View, Control: View>: View {
    let title: Title
    let detail: Detail
    let control: Control

    init(
        @ViewBuilder title: () -> Title,
        @ViewBuilder detail: () -> Detail,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title()
        self.detail = detail()
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                title
                    .font(.system(.callout, weight: .medium))
                detail
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 18)
            control
        }
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
    }
}

private extension ProductInterfaceSection {
    var title: String {
        switch self {
        case .organize: "Organize"
        case .settings: "Settings"
        case .support: "Support"
        }
    }

    var symbolName: String {
        switch self {
        case .organize: "rectangle.3.group"
        case .settings: "gearshape"
        case .support: "heart"
        }
    }
}

private extension MenuBarBundlePolicy {
    var interfaceTitle: String {
        switch self {
        case .visible: "Visible"
        case .revealable: "Revealable"
        case .hidden: "Hidden"
        }
    }

    var interfaceShortDetail: String {
        switch self {
        case .visible: "Not concealed by Blenny"
        case .revealable: "Shown when you expand"
        case .hidden: "Stays hidden when you expand"
        }
    }

    var interfaceDetail: String {
        switch self {
        case .visible:
            "Not concealed by Blenny. macOS may still use overflow."
        case .revealable:
            "Hidden until you expand Revealable items."
        case .hidden:
            "Stays hidden when you expand Revealable items."
        }
    }

    var interfaceColor: Color {
        switch self {
        case .visible: .blue
        case .revealable: .teal
        case .hidden: Color(nsColor: .secondaryLabelColor)
        }
    }
}
