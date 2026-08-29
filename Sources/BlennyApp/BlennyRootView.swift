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
                if model.navigation.isReviewPresented,
                   let review = model.reviewPresentation {
                    PolicyReviewView(
                        presentation: review,
                        onBack: { model.dismissReview() },
                        onApply: {
                            guard let prepared = review.prepared, review.canApply else { return }
                            model.dismissReview()
                            actions.apply(prepared)
                        }
                    )
                } else {
                    switch model.navigation.section {
                    case .organize:
                        OrganizeView(
                            model: model,
                            actions: actions,
                            interaction: $boardInteraction
                        )
                    case .settings:
                        SettingsView(model: model, actions: actions)
                    case .support:
                        SupportView(actions: actions)
                    }
                }
            }
        }
        .frame(
            minWidth: model.navigation.section == .organize ? 800 : 560,
            minHeight: 460
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
    static let boardRadius: CGFloat = 14
    static let laneHeight: CGFloat = 72
    static let iconFrame: CGFloat = 36
    static let itemFrame = CGSize(width: 54, height: 58)

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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(ProductInterfaceSection.allCases, id: \.self) { section in
                    Button(action: { onSelect(section) }) {
                        Label(section.title, systemImage: section.symbolName)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 112, height: 28)
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                            .background(
                                selection == section
                                    ? Color.accentColor.opacity(
                                        effectiveContrast == .increased ? 0.25 : 0.16
                                    )
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .foregroundStyle(
                        selection == section ? Color.accentColor : Color.primary
                    )
                    .accessibilityValue(
                        selection == section ? "Selected" : "Not selected"
                    )
                    .accessibilityAddTraits(selection == section ? .isSelected : [])
                }
            }
            .padding(5)
            .background(
                effectiveReduceTransparency
                    ? Color(nsColor: .controlBackgroundColor)
                    : Color.clear,
                in: Capsule()
            )
            .glassEffect(
                effectiveReduceTransparency ? .identity : .regular.interactive(),
                in: Capsule()
            )
            .overlay {
                if effectiveContrast == .increased {
                    Capsule().stroke(Color.primary.opacity(0.55), lineWidth: 1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: BlennyDesign.navigationHeight)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Blenny section")
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

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                managementStrip
                if model.statusIsError { statusMessage }
                OrganizationBoard(
                    model: model,
                    actions: actions,
                    interaction: $interaction
                )
                SelectionDetailRail(
                    model: model,
                    interaction: $interaction,
                    onMove: performMove
                )
                Label(
                    "Policy intent only — macOS owns physical placement · Manual observation, no polling",
                    systemImage: "menubar.rectangle"
                )
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.top, 9)
            .padding(.bottom, 7)

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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(managementColor)
            Text(managementTitle)
                .font(.system(size: 11.5, weight: .semibold))
            Text(managementDetail)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 10)
            if model.managementEnabled == true {
                Button("Stop…", action: actions.stopManaging)
                    .disabled(!model.controls.stopEnabled)
            } else {
                Button("Resume…", action: actions.resumeManaging)
                    .disabled(!model.controls.resumeEnabled)
            }
            Button("Restore…", action: actions.restorePreviousPolicy)
                .disabled(!model.controls.restoreEnabled)
                .help("Review and restore the scoped previous policy.")
        }
        .controlSize(.small)
        .padding(.horizontal, 10)
        .frame(height: 31)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.46))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Management and recovery")
    }

    private var statusMessage: some View {
        HStack(spacing: 7) {
            Image(systemName: "xmark.circle.fill")
            Text(model.statusMessage).lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func performMove(
        bundleIdentifier: String,
        destination: MenuBarBundlePolicy
    ) {
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
        case .rejected(let reason):
            model.setStatus(reason.interfaceReason, isError: false)
        }
    }

    private var managementTitle: String {
        switch model.managementEnabled {
        case true: "Management is on"
        case false: "Management is stopped"
        case nil: "Checking management state"
        }
    }

    private var managementDetail: String {
        switch model.managementEnabled {
        case true: "The accepted policy is active."
        case false: "The accepted policy is preserved but not active."
        case nil: "Waiting for the accepted policy."
        }
    }

    private var managementSymbol: String {
        switch model.managementEnabled {
        case true: "checkmark.circle.fill"
        case false: "pause.circle.fill"
        case nil: "circle.dotted"
        }
    }

    private var managementColor: Color {
        switch model.managementEnabled {
        case true: .green
        case false, nil: .secondary
        }
    }
}

private struct OrganizationBoard: View {
    @ObservedObject var model: ProductInterfaceModel
    let actions: ProductInterfaceActions
    @Binding var interaction: PolicyBoardInteractionState
    @Namespace private var iconNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(Array(MenuBarBundlePolicy.allCases.enumerated()), id: \.element) {
                    index, policy in
                    if index > 0 { Divider() }
                    PolicyLaneRow(
                        policy: policy,
                        model: model,
                        actions: actions,
                        interaction: $interaction,
                        iconNamespace: iconNamespace,
                        reduceMotion: effectiveReduceMotion,
                        contrast: effectiveContrast,
                        onDrop: commitDrop
                    )
                }
            }
            .background(boardSurface)
            .opacity(boardIsObscured ? 0.24 : 1)
            .allowsHitTesting(!boardIsObscured)
            .accessibilityHidden(boardIsObscured)

            if model.isRefreshing {
                BoardInterruptionPanel(
                    symbol: nil,
                    title: "Refreshing menu bar items",
                    message: "Blenny is running one bounded, read-only observation.",
                    actionTitle: nil,
                    action: nil,
                    reduceTransparency: effectiveReduceTransparency
                )
            } else if !model.accessibilityTrusted {
                BoardInterruptionPanel(
                    symbol: "hand.raised.fill",
                    title: "Accessibility is required for observation",
                    message: permissionMessage,
                    actionTitle: permissionButtonTitle,
                    action: actions.requestAccess,
                    reduceTransparency: effectiveReduceTransparency
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: BlennyDesign.boardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: BlennyDesign.boardRadius)
                .stroke(
                    Color(nsColor: .separatorColor),
                    lineWidth: effectiveContrast == .increased ? 2 : 1
                )
        }
        .dropPreviewsFormation(.none)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Organization Board")
    }

    private var boardIsObscured: Bool {
        !model.accessibilityTrusted || model.isRefreshing
    }

    private var boardSurface: Color {
        Color(nsColor: .controlBackgroundColor).opacity(
            effectiveReduceTransparency ? 1 : 0.58
        )
    }

    private func commitDrop(
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
        case .rejected(let reason):
            model.setStatus(reason.interfaceReason, isError: false)
        }
    }

    private var permissionMessage: String {
        model.accessibilityPromptRequested
            ? "Enable Blenny in Device Control and Data Access, then choose Refresh."
            : "Blenny performs one bounded, read-only scan only when you choose Refresh."
    }

    private var permissionButtonTitle: String {
        model.accessibilityPromptRequested ? "Open Settings" : "Set Up…"
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
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.orange)
            } else {
                ProgressView().controlSize(.small)
            }
            Text(title).font(.system(size: 13, weight: .semibold))
            Text(message)
                .font(.system(size: 10.5))
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

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(policy.interfaceColor)
                .frame(width: isValidTarget ? 4 : 3)
                .animation(
                    reduceMotion
                        ? .easeOut(duration: 0.08)
                        : .smooth(duration: 0.14, extraBounce: 0),
                    value: isValidTarget
                )
                .accessibilityHidden(true)

            laneHeader
                .frame(width: 154, alignment: .leading)
                .padding(.horizontal, 10)

            Divider().padding(.vertical, 9)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 4) {
                    let candidates = model.candidates(in: policy)
                    if candidates.isEmpty && (policy != .visible || model.systemItems.isEmpty) {
                        emptyState
                    } else {
                        ForEach(candidates, id: \.bundleIdentifier) { candidate in
                            ApplicationBoardItem(
                                candidate: candidate,
                                policy: policy,
                                model: model,
                                interaction: $interaction,
                                iconNamespace: iconNamespace,
                                reduceMotion: reduceMotion,
                                contrast: contrast,
                                onMove: performMove
                            )
                        }

                        if policy == .visible, !model.systemItems.isEmpty {
                            Rectangle()
                                .fill(Color(nsColor: .separatorColor))
                                .frame(width: 1, height: 40)
                                .padding(.horizontal, 4)
                                .accessibilityHidden(true)

                            VStack(spacing: 2) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("macOS")
                                    .font(.system(size: 9.5, weight: .semibold))
                                Text("Read only")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 58)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("macOS system items, read only")

                            ForEach(model.systemItems, id: \.observationIdentifier) { item in
                                SystemBoardItem(
                                    observation: item,
                                    model: model,
                                    interaction: $interaction,
                                    contrast: contrast
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 7)
                .frame(height: BlennyDesign.laneHeight)
            }
            .scrollIndicators(.automatic)
        }
        .frame(height: BlennyDesign.laneHeight)
        .background(targetBackground)
        .overlay {
            if activeTarget != nil {
                Rectangle()
                    .stroke(
                        isValidTarget ? Color.accentColor : Color.red,
                        lineWidth: contrast == .increased ? 2 : 1.5
                    )
                    .padding(1)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: PolicyDragPayload.self, isEnabled: true) { items, _ in
            guard items.count == 1, let payload = items.first else {
                model.setStatus("Only one application can be moved at a time.", isError: false)
                return
            }
            onDrop(payload, policy)
        }
        .dropConfiguration { _ in
            DropConfiguration(operation: currentValidation == .changed ? .move : .forbidden)
        }
        .onDropSessionUpdated { session in
            let animation: Animation = reduceMotion
                ? .easeOut(duration: 0.08)
                : .smooth(duration: 0.15, extraBounce: 0)
            switch session.phase {
            case .entering, .active:
                withAnimation(animation) {
                    interaction.target(policy: policy, validation: currentValidation)
                }
            case .exiting, .ended, .dataTransferCompleted:
                withAnimation(animation) {
                    interaction.clearTarget(policy: policy)
                }
            @unknown default:
                interaction.clearTarget(policy: policy)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(policy.interfaceTitle), \(applicationCount) applications")
        .accessibilityHint(policy.interfaceDetail)
    }

    private var laneHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(policy.interfaceTitle)
                    .font(.system(size: 14, weight: .semibold))
                Text("\(applicationCount)")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(.quaternary, in: Capsule())
            }
            if let target = activeTarget {
                targetHeader(target)
                    .transition(.opacity)
            } else {
                Text(policy.interfaceShortDetail)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var emptyState: some View {
        Label("Drop an app here or use Move to…", systemImage: "tray")
            .font(.system(size: 10.5))
            .foregroundStyle(.tertiary)
            .frame(width: 225, height: 50)
            .accessibilityLabel("No observed applications in \(policy.interfaceTitle)")
    }

    private var applicationCount: Int {
        model.candidates(in: policy).count
    }

    private var activeTarget: PolicyBoardDropTarget? {
        guard interaction.dropTarget?.policy == policy else { return nil }
        return interaction.dropTarget
    }

    private var isValidTarget: Bool { activeTarget?.isValid == true }

    private var targetBackground: Color {
        guard activeTarget != nil else { return .clear }
        return isValidTarget
            ? Color.accentColor.opacity(0.075)
            : Color.red.opacity(0.055)
    }

    private var currentValidation: PolicyDraftAssignmentOutcome {
        guard let bundleIdentifier = interaction.draggedBundleIdentifier,
              let sourcePolicy = interaction.draggedSourcePolicy else {
            return .rejected(.unknownCandidate)
        }
        return model.validateDrag(
            bundleIdentifier: bundleIdentifier,
            sourcePolicy: sourcePolicy,
            destination: policy
        )
    }

    @ViewBuilder
    private func targetHeader(_ target: PolicyBoardDropTarget) -> some View {
        if let rejection = target.rejection {
            Label(compactReason(for: rejection), systemImage: "nosign")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.red)
                .help(rejection.interfaceReason)
        } else {
            Label("Release to move here", systemImage: "arrow.down.to.line.compact")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Color.accentColor)
        }
    }

    private func compactReason(
        for rejection: PolicyDraftAssignmentRejection
    ) -> String {
        switch rejection {
        case .duplicateDelivery: "Drop already handled"
        case .staleCandidateGeneration, .staleSourcePolicy: "Start a new drag"
        case .samePolicy: "Already in this group"
        case .blennyMustRemainVisible: "Blenny stays Visible"
        case .unknownCandidate: "No longer available"
        }
    }

    private func performMove(
        bundleIdentifier: String,
        destination: MenuBarBundlePolicy
    ) {
        guard let source = model.model?.effectivePolicy(for: bundleIdentifier) else { return }
        onDrop(
            model.dragPayload(bundleIdentifier: bundleIdentifier, sourcePolicy: source),
            destination
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
    let onMove: (String, MenuBarBundlePolicy) -> Void
    @FocusState private var isFocused: Bool

    private var itemID: PolicyBoardItemID {
        .application(candidate.bundleIdentifier)
    }

    var body: some View {
        let presentation = model.applicationIcon(for: candidate.bundleIdentifier)
        let blenny = model.isBlenny(candidate.bundleIdentifier)

        Group {
            if blenny {
                baseButton(presentation: presentation, blenny: true)
            } else {
                baseButton(presentation: presentation, blenny: false)
                    .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 12))
                    .draggable(
                        model.dragPayload(
                            bundleIdentifier: candidate.bundleIdentifier,
                            sourcePolicy: policy
                        )
                    ) {
                        DragPreview(presentation: presentation, policy: policy)
                    }
                    .dragConfiguration(Self.dragConfiguration)
                    .onDragSessionUpdated { session in
                        switch session.phase {
                        case .initial, .active:
                            withAnimation(interactionAnimation) {
                                interaction.beginDrag(
                                    bundleIdentifier: candidate.bundleIdentifier,
                                    sourcePolicy: policy
                                )
                            }
                        case .ended, .dataTransferCompleted:
                            withAnimation(interactionAnimation) {
                                if interaction.settleState == nil {
                                    interaction.endDragWithoutDrop()
                                }
                            }
                        @unknown default:
                            break
                        }
                    }
            }
        }
        .contextMenu {
            if !blenny {
                MoveToCommands(
                    bundleIdentifier: candidate.bundleIdentifier,
                    currentPolicy: policy,
                    onMove: onMove
                )
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
            }
        }
        .zIndex(showsName ? 20 : isSelected ? 10 : 0)
    }

    private func baseButton(
        presentation: ResolvedPolicyIcon,
        blenny: Bool
    ) -> some View {
        Button {
            withAnimation(interactionAnimation) {
                interaction.select(itemID)
            }
        } label: {
            policyIcon(presentation: presentation)
                .frame(width: BlennyDesign.itemFrame.width, height: BlennyDesign.itemFrame.height)
                .contentShape(RoundedRectangle(cornerRadius: 11))
                .background(itemBackground, in: RoundedRectangle(cornerRadius: 11))
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(itemOutline, lineWidth: itemOutlineWidth)
                }
                .overlay(alignment: .topTrailing) {
                    if blenny {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundStyle(BlennyDesign.coral)
                            .padding(4)
                            .accessibilityHidden(true)
                    }
                }
                .overlay(alignment: .bottom) {
                    if showsName {
                        FloatingItemName(name: presentation.displayName)
                            .offset(y: 5)
                            .transition(.opacity)
                    }
                }
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused($isFocused)
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
        .help(tooltip(for: presentation, blenny: blenny))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: presentation, blenny: blenny))
        .accessibilityHint(
            blenny
                ? "Select for details. Blenny must remain Visible."
                : "Select for details. Drag between groups or use a Move to action."
        )
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func policyIcon(presentation: ResolvedPolicyIcon) -> some View {
        let image = Image(nsImage: presentation.image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: BlennyDesign.iconFrame, height: BlennyDesign.iconFrame)
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
        if isSelected { return Color.accentColor.opacity(0.14) }
        if isFocused || interaction.hoveredItem == itemID {
            return Color.primary.opacity(0.055)
        }
        return .clear
    }

    private var itemOutline: Color {
        if interaction.settleState?.bundleIdentifier == candidate.bundleIdentifier {
            return BlennyDesign.coral
        }
        if isSelected { return Color.accentColor }
        if isFocused { return Color.primary.opacity(0.72) }
        return .clear
    }

    private var itemOutlineWidth: CGFloat {
        if contrast == .increased && (isSelected || isFocused) { return 2 }
        return (isSelected || isFocused
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
        let iconSource = presentation.descriptor.usesFallback
            ? "Fallback icon"
            : "Installed application icon"
        let editability = blenny
            ? "Locked, required recovery control"
            : "Editable application item"
        return "\(presentation.displayName), Policy: \(policy.interfaceTitle), Bundle ID: \(candidate.bundleIdentifier), \(count) menu bar \(itemWord), \(editability), \(iconSource)"
    }

    private static let dragConfiguration = DragConfiguration(
        operationsWithinApp: .init(
            allowCopy: false,
            allowMove: true,
            allowDelete: false
        ),
        operationsOutsideApp: .init(
            allowCopy: false,
            allowMove: false,
            allowDelete: false
        )
    )
}

private struct DragPreview: View {
    let presentation: ResolvedPolicyIcon
    let policy: MenuBarBundlePolicy
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: presentation.image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(presentation.displayName)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                Text("Move from \(policy.interfaceTitle)")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: 220)
        .background(
            effectiveReduceTransparency
                ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
                : AnyShapeStyle(.regularMaterial),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }

    private var effectiveReduceTransparency: Bool {
        reduceTransparency
            || debugAccessibilityFlag("BLENNY_VALIDATE_REDUCE_TRANSPARENCY")
    }
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

private struct SystemBoardItem: View {
    let observation: SystemMenuBarItemObservation
    @ObservedObject var model: ProductInterfaceModel
    @Binding var interaction: PolicyBoardInteractionState
    let contrast: ColorSchemeContrast
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var itemID: PolicyBoardItemID {
        .systemItem(observation.observationIdentifier)
    }

    var body: some View {
        let presentation = model.systemIcon(for: observation)
        Button {
            withAnimation(interactionAnimation) {
                interaction.select(itemID)
            }
        } label: {
            Image(nsImage: presentation.image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: 31, maxHeight: 27)
                .frame(width: BlennyDesign.itemFrame.width, height: BlennyDesign.itemFrame.height)
                .contentShape(RoundedRectangle(cornerRadius: 11))
                .background(itemBackground, in: RoundedRectangle(cornerRadius: 11))
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(itemOutline, lineWidth: itemOutlineWidth)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(4)
                        .accessibilityHidden(true)
                }
                .overlay(alignment: .bottom) {
                    if showsName {
                        FloatingItemName(name: presentation.displayName)
                            .offset(y: 5)
                            .transition(.opacity)
                    }
                }
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused($isFocused)
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
        .help(tooltip(for: presentation))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: presentation))
        .accessibilityHint("Select for details. This macOS item is read only.")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .zIndex(showsName ? 20 : isSelected ? 10 : 0)
    }

    private var isSelected: Bool { interaction.selectedItem == itemID }
    private var showsName: Bool { interaction.namePresentationItem == itemID }

    private var itemBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.14) }
        if isFocused || interaction.hoveredItem == itemID {
            return Color.primary.opacity(0.055)
        }
        return .clear
    }

    private var itemOutline: Color {
        if isSelected { return Color.accentColor }
        if isFocused { return Color.primary.opacity(0.72) }
        return .clear
    }

    private var itemOutlineWidth: CGFloat {
        if contrast == .increased && (isSelected || isFocused) { return 2 }
        return (isSelected || isFocused) ? 1.5 : 0
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
        "\(presentation.displayName)\n\(accessibilityLabel(for: presentation))"
    }

    private func accessibilityLabel(for presentation: ResolvedPolicyIcon) -> String {
        let count = observation.observationCount
        let occurrence = count == 1 ? "observation" : "observations"
        let iconSource = presentation.descriptor.usesFallback
            ? "Fallback icon"
            : "System symbol"
        return "\(presentation.displayName), macOS system item, Owner: \(observation.ownerBundleIdentifier), Identifier: \(observation.observationIdentifier), \(count) \(occurrence), Read only, \(iconSource)"
    }
}

private struct SelectionDetailRail: View {
    @ObservedObject var model: ProductInterfaceModel
    @Binding var interaction: PolicyBoardInteractionState
    let onMove: (String, MenuBarBundlePolicy) -> Void

    var body: some View {
        HStack(spacing: 9) {
            selectionContent
            Spacer(minLength: 8)
            if case .application(let bundleIdentifier) = interaction.selectedItem,
               let policy = model.model?.effectivePolicy(for: bundleIdentifier),
               !model.isBlenny(bundleIdentifier) {
                MoveToMenu(
                    bundleIdentifier: bundleIdentifier,
                    currentPolicy: policy,
                    onMove: onMove
                )
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .overlay(alignment: .top) { Divider() }
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
                Image(nsImage: presentation.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(presentation.displayName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                    Text(applicationDetail(candidate, policy: policy, presentation: presentation))
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(applicationDetail(candidate, policy: policy, presentation: presentation))
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
                Image(nsImage: presentation.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(presentation.displayName)
                        .font(.system(size: 11.5, weight: .semibold))
                    Text("\(observation.ownerBundleIdentifier) · \(observation.observationCount) observed · macOS group")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Label("Read only", systemImage: "lock.fill")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                unavailableSelection
            }
        case nil:
            Image(systemName: "cursorarrow.click.2")
                .foregroundStyle(.secondary)
            Text("Select an item for its full identity and Move to… actions.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }

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
        return "\(candidate.bundleIdentifier) · \(candidate.menuBarItemCount) menu bar \(itemWord) · \(policy.interfaceTitle)\(fallback)"
    }
}

private struct MoveToMenu: View {
    let bundleIdentifier: String
    let currentPolicy: MenuBarBundlePolicy
    let onMove: (String, MenuBarBundlePolicy) -> Void

    var body: some View {
        Menu {
            MoveToCommands(
                bundleIdentifier: bundleIdentifier,
                currentPolicy: currentPolicy,
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
    let onMove: (String, MenuBarBundlePolicy) -> Void

    var body: some View {
        ForEach(MenuBarBundlePolicy.allCases, id: \.self) { destination in
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

    var body: some View {
        HStack(spacing: 10) {
            Label(observationSummary, systemImage: model.hasDraftChanges ? "pencil.line" : "eye")
                .font(.system(size: 10.5))
                .foregroundStyle(model.hasDraftChanges ? Color.primary : Color.secondary)
                .lineLimit(1)

            Spacer(minLength: 10)

            HStack(spacing: 6) {
                Button("Discard Draft") {
                    var discardedEditor: PolicyEditorViewModel?
                    withAnimation(discardAnimation) {
                        discardedEditor = model.discardDraft()
                        interaction.clearAll()
                    }
                    guard let editor = discardedEditor else { return }
                    actions.draftDidChange(editor)
                }
                .disabled(!model.controls.discardDraftEnabled)

                Button("Review Changes", action: actions.reviewDraft)
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.controls.reviewEnabled || !model.hasDraftChanges)
                    .keyboardShortcut(.defaultAction)
            }
            .frame(width: 216, alignment: .trailing)
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

    private var observationSummary: String {
        if model.hasDraftChanges {
            return "Draft changes are local and unapplied"
        }
        guard model.accessibilityTrusted else {
            return "Accessibility required · Manual observation"
        }
        guard model.model != nil else {
            return "No completed observation · Manual refresh only"
        }
        let appSuffix = model.observationCount == 1 ? "" : "s"
        let systemSuffix = model.systemItems.count == 1 ? "" : "s"
        return "\(model.observationCount) app\(appSuffix), \(model.systemItems.count) read-only system item\(systemSuffix) · Manual refresh"
    }

    private var refreshHelp: String {
        if !model.accessibilityTrusted {
            return "Recheck Accessibility and run the bounded observation if permission is now granted."
        }
        if model.hasDraftChanges {
            return "Refresh is unavailable while a local draft is present."
        }
        return "Refresh the bounded menu bar observation. Blenny never polls."
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
        VStack(alignment: .leading, spacing: 22) {
            ProductPageHeader(
                title: "Settings",
                subtitle: "A small set of explicit system integrations."
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var permissionDescription: String {
        if model.accessibilityTrusted {
            return "Used only for a bounded, read-only observation when you choose Refresh."
        }
        if model.accessibilityPromptRequested {
            return "Enable Blenny in Device Control and Data Access. The system prompt will not repeat."
        }
        return "Permission is requested only after you explicitly choose Set Up."
    }

    private var permissionButtonTitle: String {
        model.accessibilityPromptRequested ? "Open Settings" : "Set Up…"
    }
}

private struct SupportView: View {
    let actions: ProductInterfaceActions

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ProductPageHeader(
                title: "Support",
                subtitle: "Project information and ways to support Blenny."
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
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("Version \(applicationVersion) · A quiet home for menu bar icons.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button(action: actions.openProjectWebsite) {
                        Label("Open Project Website", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)
                }
            }

            ProductPageSection(title: "Support Blenny", systemImage: "heart") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("The complete default interface is part of Blenny. If the project is useful to you, you can support its continued development.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
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
                    .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var applicationVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "0.4.0"
    }
}

private struct ProductPageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 26, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 12))
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
                .font(.system(size: 12, weight: .semibold))
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
                    .font(.system(size: 12, weight: .semibold))
                detail
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 18)
            control
        }
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
    }
}

private struct PolicyReviewView: View {
    let presentation: ProductReviewPresentation
    let onBack: () -> Void
    let onApply: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                }
                .keyboardShortcut(.cancelAction)

                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.title)
                        .font(.system(size: 18, weight: .semibold))
                    Text("Review the exact diff, impact, validation, and recovery plan.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)

            Divider()

            ScrollView {
                Text(presentation.report)
                    .font(.system(size: 10.5, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
            }
            .background(
                effectiveReduceTransparency
                    ? AnyShapeStyle(Color(nsColor: .textBackgroundColor))
                    : AnyShapeStyle(.background.secondary)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .padding(.horizontal, 20)
            .padding(.top, 16)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: safetySymbol)
                    .foregroundStyle(safetyColor)
                Text(presentation.safetyMessage)
                    .font(.system(size: 10.5))
                    .foregroundStyle(safetyColor)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Button("Apply", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .disabled(!presentation.canApply)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
    }

    private var safetyColor: Color {
        switch presentation.safetyTone {
        case .neutral: .secondary
        case .warning: .orange
        case .error: .red
        }
    }

    private var safetySymbol: String {
        switch presentation.safetyTone {
        case .neutral: "checkmark.shield"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    private var effectiveReduceTransparency: Bool {
        reduceTransparency
            || debugAccessibilityFlag("BLENNY_VALIDATE_REDUCE_TRANSPARENCY")
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
        case .revealable: "Included in ordinary reveal"
        case .hidden: "Excluded from ordinary reveal"
        }
    }

    var interfaceDetail: String {
        switch self {
        case .visible:
            "Not concealed by Blenny. macOS may still use overflow."
        case .revealable:
            "Concealed at baseline and included in an ordinary reveal."
        case .hidden:
            "Concealed at baseline and excluded from ordinary reveals."
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
