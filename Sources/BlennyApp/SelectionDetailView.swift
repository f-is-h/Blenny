import AppKit
import BlennyCore
import SwiftUI

struct SelectionDetailRail: View {
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
        #if BLENNY_PRODUCT || DEBUG
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
                    #if BLENNY_PRODUCT || DEBUG
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
                    #if BLENNY_PRODUCT || DEBUG
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
                #if BLENNY_PRODUCT || DEBUG
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
                #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
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
        #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
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

    #if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
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
        #if BLENNY_PRODUCT || DEBUG
        if model.availableSystemOrderingItem(for: identifier) != nil,
           model.systemItemPolicyDestinations(for: identifier)
                == [.visible, .revealable, .hidden] {
            return "Choose Visible, Revealable or Hidden. Drag to change its menu bar order."
        }
        #endif
        if model.systemItemPolicyDestinations(for: identifier)
            == [.visible, .revealable, .hidden] {
            return "Choose Visible, Revealable or Hidden. Sorting requires a verified exact position."
        }
        #if BLENNY_PRODUCT || DEBUG
        if model.availableSystemOrderingItem(for: identifier) != nil {
            return "This exact system item can be reordered, but no three-state visibility policy is currently available."
        }
        #endif
        return model.systemItemCapabilityExplanation(for: identifier)
    }
}

struct MoveToMenu: View {
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

struct MoveToCommands: View {
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

struct ObservationAndDraftFooter: View {
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
        #if BLENNY_PRODUCT || DEBUG
        if model.orderingPresentation.requiresUndoReplacement { return "Replace Undo & Apply" }
        #endif
        return model.isApplying ? "Applying…" : "Apply"
    }

    private func applyChanges() {
        #if BLENNY_PRODUCT || DEBUG
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
            return "Device Control required · Manual observation"
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
            return "Turn on Device Control, then return to Blenny for one automatic refresh."
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
