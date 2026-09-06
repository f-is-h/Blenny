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
            minWidth: model.navigation.section == .organize ? 800 : 560,
            minHeight: 410
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

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                managementStrip
                #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
                debugSystemItemTrialNotice
                #endif
                OrganizationBoard(
                    model: model,
                    actions: actions,
                    interaction: $interaction
                )
                SelectionDetailRail(
                    model: model,
                    interaction: $interaction,
                    actions: actions,
                    onMove: performMove
                )
                if model.statusIsError {
                    statusMessage
                } else {
                    Label(
                        "Policy intent only — macOS owns physical placement · Manual observation, no polling",
                        systemImage: "menubar.rectangle"
                    )
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
                }
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
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(managementColor)
            Text(managementTitle)
                .font(.system(.subheadline, weight: .medium))
            Text(managementDetail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 10)
            if model.managementEnabled == true {
                Button("Stop", action: actions.stopManaging)
                    .disabled(!model.controls.stopEnabled)
            } else {
                Button("Resume", action: actions.resumeManaging)
                    .disabled(!model.controls.resumeEnabled)
            }
            Button("Restore", action: actions.restorePreviousPolicy)
                .disabled(!model.controls.restoreEnabled)
                .help("Restore the previous policy using the scoped recovery backup.")
        }
        .controlSize(.small)
        .padding(.horizontal, 10)
        .frame(height: 31)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.46))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Management and recovery")
    }

    #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    private var debugSystemItemTrialNotice: some View {
        Label(
            "Debug manual system-item testing: policies are isolated and start stopped. Apply or Resume is required; Stop or Quit releases restrictions. This is not a timed rollback.",
            systemImage: "exclamationmark.triangle"
        )
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Debug manual system-item testing warning")
    }
    #endif

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
                    if index > 0 {
                        Rectangle()
                            .fill(Color(nsColor: .separatorColor).opacity(0.34))
                            .frame(height: 0.5)
                            .padding(.horizontal, 12)
                            .accessibilityHidden(true)
                    }
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
            if case .ended = session.phase {
                interaction.endDragWithoutDrop()
            }
            return
        }

        let animation: Animation = effectiveReduceMotion
            ? .easeOut(duration: 0.08)
            : .smooth(duration: 0.14, extraBounce: 0)
        withAnimation(animation) {
            switch session.phase {
            case .initial, .active:
                if interaction.draggedBundleIdentifier != identity.bundleIdentifier
                    || interaction.draggedSourcePolicy != identity.sourcePolicy {
                    interaction.beginDrag(
                        bundleIdentifier: identity.bundleIdentifier,
                        sourcePolicy: identity.sourcePolicy
                    )
                }
            case .ended, .dataTransferCompleted:
                if interaction.settleState == nil {
                    interaction.endDragWithoutDrop()
                }
            @unknown default:
                interaction.endDragWithoutDrop()
            }
        }
    }

    private var boardIsObscured: Bool {
        !model.accessibilityTrusted || model.isRefreshing || model.isApplying
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
            ? "Enable Blenny in Device Control and Data Access, then return for one automatic refresh."
            : "Choose Set Up once. After authorization, Blenny runs one bounded refresh automatically."
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

    var body: some View {
        HStack(spacing: 0) {
            laneHeader
                .frame(width: 154, alignment: .leading)
                .padding(.leading, 12)
                .padding(.trailing, 14)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 2) {
                    let candidates = model.applicationCandidates(in: policy)
                    let appleSystemCandidates = model.appleSystemCandidates(in: policy)
                    let systemItems = model.systemItems(in: policy)
                    let applicationLandingPreview = landingPreview(
                        among: candidates,
                        systemPresentation: false
                    )
                    let appleSystemLandingPreview = landingPreview(
                        among: appleSystemCandidates,
                        systemPresentation: true
                    )
                    if candidates.isEmpty
                        && appleSystemCandidates.isEmpty
                        && applicationLandingPreview == nil
                        && appleSystemLandingPreview == nil
                        && systemItems.isEmpty {
                        emptyState
                    } else {
                        ForEach(
                            Array(candidates.enumerated()),
                            id: \.element.bundleIdentifier
                        ) { index, candidate in
                            if applicationLandingPreview?.index == index {
                                landingPreviewView(applicationLandingPreview)
                            }
                            ApplicationBoardItem(
                                candidate: candidate,
                                policy: policy,
                                model: model,
                                interaction: $interaction,
                                iconNamespace: iconNamespace,
                                reduceMotion: reduceMotion,
                                contrast: contrast,
                                presentsAsSystemItem: false,
                                onMove: performMove
                            )
                        }

                        if applicationLandingPreview?.index == candidates.endIndex {
                            landingPreviewView(applicationLandingPreview)
                        }

                        if !appleSystemCandidates.isEmpty || !systemItems.isEmpty {
                            Rectangle()
                                .fill(Color(nsColor: .separatorColor))
                                .frame(width: 1, height: 34)
                                .padding(.horizontal, 3)
                                .accessibilityHidden(true)

                            VStack(spacing: 2) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 13, weight: .regular))
                                Text("macOS")
                                    .font(.caption)
                                Text(systemItems.contains(where: {
                                    model.isInteractiveSystemItem(
                                        $0.observationIdentifier
                                    )
                                }) ? systemControlLabel : "Read only")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .help(systemControlHelp)
                            }
                            .frame(width: 54)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("macOS system items")

                            ForEach(
                                Array(appleSystemCandidates.enumerated()),
                                id: \.element.bundleIdentifier
                            ) { index, candidate in
                                if appleSystemLandingPreview?.index == index {
                                    landingPreviewView(appleSystemLandingPreview)
                                }
                                ApplicationBoardItem(
                                    candidate: candidate,
                                    policy: policy,
                                    model: model,
                                    interaction: $interaction,
                                    iconNamespace: iconNamespace,
                                    reduceMotion: reduceMotion,
                                    contrast: contrast,
                                    presentsAsSystemItem: true,
                                    onMove: performMove
                                )
                            }

                            if appleSystemLandingPreview?.index
                                == appleSystemCandidates.endIndex {
                                landingPreviewView(appleSystemLandingPreview)
                            }

                            ForEach(systemItems, id: \.observationIdentifier) { item in
                                SystemBoardItem(
                                    observation: item,
                                    policy: policy,
                                    model: model,
                                    interaction: $interaction,
                                    contrast: contrast,
                                    actions: actions,
                                    onMove: performMove
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 5)
                .frame(height: BlennyDesign.laneHeight)
            }
            .scrollIndicators(.automatic)
            .scrollEdgeEffectHidden(true, for: .all)
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
        .dropDestination(for: PolicyDragPayload.self) { payloads, session in
            guard payloads.count == 1, let payload = payloads.first else {
                model.setStatus(
                    "Only one application can be moved at a time.",
                    isError: false
                )
                return
            }
            onDrop(payload, policy)
        }
        .dropConfiguration(dropConfiguration)
        .onDropSessionUpdated(updateDropSession)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(policy.interfaceTitle), \(applicationCount) applications")
        .accessibilityHint(policy.interfaceDetail)
    }

    private var systemControlLabel: String {
        #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
        "Experimental controls"
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
                Text("\(applicationCount)")
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
        guard session.itemsCount == 1, let localSession = session.localSession else {
            return nil
        }
        let identities = localSession.draggedItemIDs(for: PolicyDragPayload.ID.self)
        guard identities.count == 1 else { return nil }
        return identities[0]
    }

    private func validation(
        for identity: PolicyDragPayload.ID
    ) -> PolicyDraftAssignmentOutcome {
        guard identity.candidateGeneration == model.candidateGeneration else {
            return .rejected(.staleCandidateGeneration)
        }
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
                    interaction.clearTarget(policy: policy)
                    return
                }
                if interaction.draggedBundleIdentifier != identity.bundleIdentifier
                    || interaction.draggedSourcePolicy != identity.sourcePolicy {
                    interaction.beginDrag(
                        bundleIdentifier: identity.bundleIdentifier,
                        sourcePolicy: identity.sourcePolicy
                    )
                }
                interaction.target(
                    policy: policy,
                    validation: validation(for: identity)
                )
            case .exiting, .ended, .dataTransferCompleted:
                interaction.clearTarget(policy: policy)
            @unknown default:
                interaction.clearTarget(policy: policy)
            }
        }
    }

    @ViewBuilder
    private func targetHeader(_ target: PolicyBoardDropTarget) -> some View {
        if let rejection = target.rejection {
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
        if model.isControllableSystemItem(bundleIdentifier) {
            let outcome = model.assignSystemItem(
                identifier: bundleIdentifier,
                destination: destination
            )
            if outcome.changedDraft, let editor = model.model {
                actions.draftDidChange(editor)
            } else if case .rejected(let reason) = outcome {
                model.setStatus(reason.interfaceReason, isError: false)
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
                        ? "Select for details. Blenny must remain Visible."
                        : "Select for details. Drag between groups or use a Move to action."
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
        .overlay(alignment: .bottom) {
            if showsName {
                FloatingItemName(name: presentation.displayName)
                    .offset(y: 5)
                    .transition(.opacity)
            }
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
                .draggable(item: payload)
                .dragConfiguration(DragConfiguration(allowMove: true))
        } else {
            policyIcon(presentation: presentation)
        }
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
        return "\(presentation.displayName), Policy: \(policy.interfaceTitle), Bundle ID: \(candidate.bundleIdentifier), \(count) menu bar \(itemWord), \(editability), \(iconSource)"
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
                if isControllable {
                    ForEach(MenuBarBundlePolicy.allCases, id: \.self) { destination in
                        if destination != policy {
                            Button("Move to \(destination.interfaceTitle)") {
                                onMove(observation.observationIdentifier, destination)
                            }
                        }
                    }
                }
                #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
                if let target = sharedTrialTarget {
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
                    isControllable || hasSharedTrialControl
                        ? "Select for details and use a Move to action."
                        : "Select for details. This macOS item is read only."
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
            if isControllable {
                NaturalAspectSystemIcon(
                    presentation: presentation,
                    pointSize: 21,
                    frame: CGSize(width: 29, height: 25)
                )
                .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 8))
                .draggable(
                    item: model.dragPayload(
                        bundleIdentifier: observation.observationIdentifier,
                        sourcePolicy: policy
                    )
                )
                .dragConfiguration(DragConfiguration(allowMove: true))
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
            }
        }
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
    private var isControllable: Bool {
        model.isControllableSystemItem(observation.observationIdentifier)
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
            Button("Hide (target.displayName)") {
                actions.hideSharedSystemItem(target)
            }
        case .recoveryRequired:
            Button("Restore (target.displayName)") {
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
                onMove: onMove
            )
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
        "\(presentation.displayName)\n\(accessibilityLabel(for: presentation))"
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
            ? "Experimental policy control"
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
        .frame(height: 42)
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
                NaturalAspectSystemIcon(
                    presentation: presentation,
                    pointSize: 17,
                    frame: CGSize(width: 22, height: 22)
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(presentation.displayName)
                        .font(.system(.subheadline, weight: .medium))
                    Text(systemItemDetail(observation))
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let policy = model.model?.effectiveSystemItemPolicy(
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
            Text("Select an item for its full identity and Move to… actions.")
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
                MoveToMenu(
                    bundleIdentifier: bundleIdentifier,
                    currentPolicy: policy,
                    onMove: onMove
                )
            }
        case .systemItem(let identifier):
            if let policy = model.model?.effectiveSystemItemPolicy(for: identifier) {
                MoveToMenu(
                    bundleIdentifier: identifier,
                    currentPolicy: policy,
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
        return "\(candidate.bundleIdentifier) · \(candidate.menuBarItemCount) menu bar \(itemWord) · \(policy.interfaceTitle)\(fallback)"
    }

    private func systemItemDetail(_ observation: SystemMenuBarItemObservation) -> String {
        let source = observation.observationCount == 0
            ? "verified system state"
            : "\(observation.observationCount) observed"
        return "\(observation.ownerBundleIdentifier) · \(source) · macOS group"
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
    @State private var showingDiscoveryWarnings = false

    var body: some View {
        HStack(spacing: 10) {
            observationStatus

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

                Button(model.isApplying ? "Applying…" : "Apply", action: actions.applyDraft)
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.controls.applyEnabled || !model.hasDraftChanges)
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
                    Text("Unreadable menu-bar roots")
                        .font(.system(.headline, weight: .medium))
                    Text("These processes returned an Accessibility read error. They are not counted as manageable menu-bar items.")
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
        if !model.discoveryWarnings.isEmpty {
            return "\(model.observationCount) app\(appSuffix) · \(model.discoveryWarnings.count) unreadable · Manual refresh"
        }
        return "\(model.observationCount) app\(appSuffix), \(model.systemItems.count) read-only system item\(systemSuffix) · Manual refresh"
    }

    private var refreshHelp: String {
        if !model.accessibilityTrusted {
            return "Grant Accessibility, then return to Blenny for one automatic refresh."
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
        ScrollView {
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

            ProductPageSection(title: "Menu Bar", systemImage: "menubar.rectangle") {
                SettingsGridRow {
                    Text("Place Blenny beside System Arrow")
                } detail: {
                    Text(placementDescription)
                } control: {
                    Button("Show Steps…", action: actions.showFishPlacementGuide)
                        .controlSize(.small)
                        .disabled(!model.nativeOverflowPlacementAvailable)
                }
            }

            #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
            ProductPageSection(
                title: "Shared Apple Items (Debug)",
                systemImage: "wrench.and.screwdriver"
            ) {
                VStack(spacing: 12) {
                    ForEach(SharedSystemItemTrialTarget.allCases, id: \.self) { target in
                        SettingsGridRow {
                            Label(target.displayName, systemImage: trialSymbol(target))
                        } detail: {
                            Text(trialDescription(target))
                                .foregroundStyle(trialDescriptionColor(target))
                        } control: {
                            trialControl(target)
                        }
                    }
                }
            }
            #endif
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var permissionDescription: String {
        if model.accessibilityTrusted {
            return "Used for one bounded observation after authorization, then only when you choose Refresh."
        }
        if model.accessibilityPromptRequested {
            return "Enable Blenny, then return for one bounded automatic refresh. The prompt will not repeat."
        }
        return "Permission is requested only after you explicitly choose Set Up."
    }

    private var permissionButtonTitle: String {
        model.accessibilityPromptRequested ? "Open Settings" : "Set Up…"
    }

    private var placementDescription: String {
        if model.nativeOverflowPlacementAvailable {
            return "Use macOS Command-drag once. Blenny never moves the pointer or reorders other apps."
        }
        return "Available when macOS shows one usable overflow arrow. Refresh after it appears."
    }

    #if DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
    @ViewBuilder
    private func trialControl(_ target: SharedSystemItemTrialTarget) -> some View {
        switch model.sharedSystemItemTrials[target] ?? .checking {
        case .ready:
            EmptyView()
        case .recoveryRequired:
            if model.managementEnabled == false {
                Button("Restore", action: { actions.restoreSharedSystemItem(target) })
                    .controlSize(.small)
            }
        case .busy:
            ProgressView().controlSize(.small)
        case .checking, .hidden, .unavailable:
            EmptyView()
        }
    }

    private func trialDescription(_ target: SharedSystemItemTrialTarget) -> String {
        switch model.sharedSystemItemTrials[target] ?? .checking {
        case .checking:
            "Reading the exact current-user state."
        case .ready:
            "Available for Visible, Revealable, and Hidden policy on the Board."
        case .hidden:
            "Already hidden outside this trial; no recovery receipt was created."
        case .busy:
            "One serial operation is running; verification is bounded to one read."
        case .recoveryRequired:
            model.managementEnabled == true
                ? "Managed policy receipt is active. Stop restores the exact original state."
                : "Recovery is pending. Restore compares current state before writing."
        case .unavailable(let detail):
            "Unavailable on this runtime: \(detail)"
        }
    }

    private func trialDescriptionColor(
        _ target: SharedSystemItemTrialTarget
    ) -> Color {
        switch model.sharedSystemItemTrials[target] ?? .checking {
        case .unavailable: .red
        case .recoveryRequired: .orange
        default: .secondary
        }
    }

    private func trialSymbol(_ target: SharedSystemItemTrialTarget) -> String {
        switch target {
        case .nowPlaying: "play.circle"
        case .siri: "siri"
        case .timeMachine: "externaldrive.badge.timemachine"
        }
    }
    #endif
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
                        .font(.system(.title2, design: .rounded, weight: .medium))
                    Text("Version \(applicationVersion) · A quiet home for menu bar icons.")
                        .font(.subheadline)
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
                        .font(.subheadline)
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
