import AppKit
import BlennyCore
import SwiftUI

struct BlennyRootView: View {
    @ObservedObject var model: ProductInterfaceModel
    let actions: ProductInterfaceActions

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
                        OrganizeView(model: model, actions: actions)
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
    }
}

private struct ProductNavigationBar: View {
    let selection: ProductInterfaceSection
    let onSelect: (ProductInterfaceSection) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ProductInterfaceSection.allCases, id: \.self) { section in
                Button(action: { onSelect(section) }) {
                    Label(section.title, systemImage: section.symbolName)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 118, height: 28)
                        .contentShape(RoundedRectangle(cornerRadius: 7))
                        .background(
                            selection == section
                                ? Color.accentColor.opacity(0.16)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 7)
                        )
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .foregroundStyle(selection == section ? Color.accentColor : Color.primary)
                .accessibilityValue(selection == section ? "Selected" : "Not selected")
                .accessibilityAddTraits(selection == section ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 38)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Blenny section")
    }
}

private struct OrganizeView: View {
    @ObservedObject var model: ProductInterfaceModel
    let actions: ProductInterfaceActions

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                managementBar

                if model.statusIsError {
                    statusMessage
                }

                policyLaneStack

                VStack(alignment: .leading, spacing: 5) {
                    Label(
                        "macOS owns final placement. Visible means Blenny does not conceal an item; limited space can still move it into system overflow.",
                        systemImage: "menubar.rectangle"
                    )
                    Label(
                        "Blenny never moves the pointer, captures menu bar pixels, or continuously polls the system.",
                        systemImage: "checkmark.shield"
                    )
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Spacer(minLength: 0)

            Divider()
            ObservationFooter(model: model, actions: actions)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var policyLaneStack: some View {
        ZStack {
            VStack(spacing: 7) {
                ForEach(MenuBarBundlePolicy.allCases, id: \.self) { policy in
                    PolicyLane(policy: policy, model: model)
                }
            }
            .opacity(lanesAreObscured ? 0.28 : 1)
            .allowsHitTesting(!lanesAreObscured)
            .accessibilityHidden(lanesAreObscured)

            if model.isRefreshing {
                VStack(spacing: 9) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Refreshing menu bar items")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Blenny is running one bounded, read-only observation.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Refreshing menu bar items")
            } else if !model.accessibilityTrusted {
                VStack(spacing: 9) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text("Accessibility is required for observation")
                        .font(.system(size: 14, weight: .semibold))
                    Text(permissionMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                    Button(permissionButtonTitle, action: actions.requestAccess)
                        .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.32), lineWidth: 1)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Accessibility permission required")
            }
        }
    }

    private var lanesAreObscured: Bool {
        !model.accessibilityTrusted || model.isRefreshing
    }

    private var managementBar: some View {
        HStack(spacing: 12) {
            Label {
                Text(managementTitle)
                    .font(.system(size: 12.5, weight: .semibold))
            } icon: {
                Image(systemName: managementSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(managementColor)
            }

            Spacer(minLength: 12)

            if model.managementEnabled == true {
                Button("Stop Managing…", action: actions.stopManaging)
                    .disabled(!model.controls.stopEnabled)
            } else {
                Button("Resume Managing…", action: actions.resumeManaging)
                    .disabled(!model.controls.resumeEnabled)
            }

            Button("Restore Previous…", action: actions.restorePreviousPolicy)
                .disabled(!model.controls.restoreEnabled)
                .help("Review and restore the scoped previous policy.")
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Management and recovery")
    }

    private var statusMessage: some View {
        HStack(spacing: 7) {
            Image(systemName: model.statusIsError ? "xmark.circle.fill" : "info.circle")
            Text(model.statusMessage)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .font(.system(size: 11))
        .foregroundStyle(model.statusIsError ? Color.red : Color.secondary)
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var managementTitle: String {
        switch model.managementEnabled {
        case true: "Management is on"
        case false: "Management is stopped"
        case nil: "Checking management state"
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
        case false: .secondary
        case nil: .secondary
        }
    }

    private var permissionMessage: String {
        model.accessibilityPromptRequested
            ? "Enable Blenny in Device Control and Data Access, then choose Refresh. The system prompt will not repeat."
            : "Blenny performs one bounded, read-only scan only when you choose Refresh."
    }

    private var permissionButtonTitle: String {
        model.accessibilityPromptRequested ? "Open Settings" : "Set Up…"
    }
}

private struct PolicyLane: View {
    let policy: MenuBarBundlePolicy
    @ObservedObject var model: ProductInterfaceModel

    var body: some View {
        HStack(spacing: 11) {
            laneHeader
                .frame(width: 146, alignment: .leading)

            Divider()
                .padding(.vertical, 4)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 3) {
                    let candidates = model.candidates(in: policy)
                    if candidates.isEmpty && (policy != .visible || model.systemItems.isEmpty) {
                        emptyState
                    } else {
                        ForEach(candidates, id: \.bundleIdentifier) { candidate in
                            ApplicationItemCard(
                                candidate: candidate,
                                policy: policy,
                                model: model
                            )
                        }

                        if policy == .visible, !model.systemItems.isEmpty {
                            Rectangle()
                                .fill(Color(nsColor: .separatorColor))
                                .frame(width: 1, height: 46)
                                .padding(.horizontal, 3)
                                .accessibilityHidden(true)

                            VStack(spacing: 3) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("macOS")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Read only")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 56)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("macOS system items, read only")

                            ForEach(model.systemItems, id: \.observationIdentifier) { item in
                                SystemItemCard(observation: item, model: model)
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.automatic)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 88)
        .background(policy.interfaceColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(policy.interfaceColor.opacity(0.34), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(policy.interfaceTitle), \(applicationCount) applications")
        .accessibilityHint(policy.interfaceDetail)
    }

    private var laneHeader: some View {
        HStack(alignment: .top, spacing: 9) {
            RoundedRectangle(cornerRadius: 2)
                .fill(policy.interfaceColor)
                .frame(width: 4, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(policy.interfaceTitle)
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(applicationCount)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                Text(policy.interfaceDetail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyState: some View {
        Label("No observed apps in this group", systemImage: "tray")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .frame(width: 210, height: 54)
            .accessibilityLabel("No observed applications in \(policy.interfaceTitle)")
    }

    private var applicationCount: Int {
        model.candidates(in: policy).count
    }
}

private struct ApplicationItemCard: View {
    let candidate: PolicyCandidate
    let policy: MenuBarBundlePolicy
    @ObservedObject var model: ProductInterfaceModel

    var body: some View {
        let presentation = model.applicationIcon(for: candidate.bundleIdentifier)
        let blenny = model.isBlenny(candidate.bundleIdentifier)

        VStack(spacing: 4) {
            Image(nsImage: presentation.image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 32, height: 32)
            Text(presentation.displayName)
                .font(.system(size: 9.5, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(width: 68, height: 60)
        .contentShape(Rectangle())
        .overlay(alignment: .topTrailing) {
            if blenny {
                Image(systemName: "lock.fill")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(5)
                    .accessibilityHidden(true)
            }
        }
        .help(tooltip(for: presentation, blenny: blenny))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: presentation, blenny: blenny))
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
        let editability = blenny ? "Required recovery control" : "Application item"
        return "\(presentation.displayName), Policy: \(policy.interfaceTitle), Bundle ID: \(candidate.bundleIdentifier), \(count) menu bar \(itemWord), \(editability), \(iconSource)"
    }
}

private struct SystemItemCard: View {
    let observation: SystemMenuBarItemObservation
    @ObservedObject var model: ProductInterfaceModel

    var body: some View {
        let presentation = model.systemIcon(for: observation)
        VStack(spacing: 4) {
            Group {
                if let symbolName = presentation.descriptor.symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: 21, weight: .regular))
                        .symbolRenderingMode(.monochrome)
                } else {
                    Image(nsImage: presentation.image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                }
            }
            .frame(width: 34, height: 30)
            .foregroundStyle(.primary)
            Text(presentation.displayName)
                .font(.system(size: 9.5, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(width: 68, height: 60)
        .contentShape(Rectangle())
        .help("\(presentation.displayName)\n\(accessibilityText(for: presentation))")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(for: presentation))
    }

    private func accessibilityText(for presentation: ResolvedPolicyIcon) -> String {
        let count = observation.observationCount
        let observationWord = count == 1 ? "observation" : "observations"
        let fallback = presentation.descriptor.usesFallback ? ", Fallback icon" : ""
        return "\(presentation.displayName), Policy: Visible, Observation ID: \(observation.observationIdentifier), Owner: \(observation.ownerBundleIdentifier), \(count) \(observationWord), macOS system item, Read only\(fallback)"
    }
}

private struct ObservationFooter: View {
    @ObservedObject var model: ProductInterfaceModel
    let actions: ProductInterfaceActions

    var body: some View {
        HStack(spacing: 10) {
            Label(observationSummary, systemImage: "eye")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

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
        .accessibilityLabel("Manual observation controls")
    }

    private var observationSummary: String {
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
            return "Refresh is unavailable while an existing draft is present."
        }
        return "Refresh the bounded menu bar observation. Blenny never polls."
    }
}

private struct SettingsView: View {
    @ObservedObject var model: ProductInterfaceModel
    let actions: ProductInterfaceActions

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageHeader(
                title: "Settings",
                subtitle: "Blenny keeps configuration small and explicit."
            )

            SettingsSectionCard(
                title: "Permission",
                systemImage: "hand.raised"
            ) {
                HStack(spacing: 14) {
                    Image(systemName: model.accessibilityTrusted
                        ? "checkmark.shield.fill"
                        : "exclamationmark.shield.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(model.accessibilityTrusted ? .green : .orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.accessibilityTrusted
                            ? "Accessibility granted"
                            : "Accessibility not granted")
                            .font(.system(size: 13, weight: .semibold))
                        Text(permissionDescription)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 14)

                    if !model.accessibilityTrusted {
                        Button(permissionButtonTitle, action: actions.requestAccess)
                    }
                }
                .padding(6)
            }

            SettingsSectionCard(
                title: "Startup",
                systemImage: "power"
            ) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Open at Login")
                            .font(.system(size: 13, weight: .semibold))
                        Text(model.launchAtLoginState.statusDescription)
                        .font(.system(size: 11))
                            .foregroundStyle(
                                model.launchAtLoginState.failureMessage == nil
                                    ? Color.secondary
                                    : Color.red
                            )
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 14)

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
                    .help("Open Blenny automatically after you log in.")
                    .accessibilityLabel("Open Blenny at Login")
                    .accessibilityValue(
                        model.launchAtLoginState.isToggleOn ? "On" : "Off"
                    )
                }
                .padding(6)
            }
        }
        .frame(maxWidth: 700)
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var permissionDescription: String {
        if model.accessibilityTrusted {
            return "Blenny can perform its bounded, read-only observation when you choose Refresh."
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
        VStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 68, height: 68)
                .accessibilityLabel("Blenny application icon")

            VStack(spacing: 6) {
                Text("Blenny")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("Version \(applicationVersion)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("A quiet home for menu bar icons.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Button(action: actions.openProjectWebsite) {
                    Label("Open Project Website", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.link)
                .controlSize(.small)
            }

            SettingsSectionCard(
                title: "Support Blenny",
                systemImage: "heart"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Blenny is under private development for macOS 27. If it is useful to you, support its continued development through GitHub Sponsors.")
                        .font(.system(size: 12))
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }
            .frame(maxWidth: 520)
        }
        .padding(.horizontal, 18)
        .padding(.top, 28)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var applicationVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "0.3.0"
    }
}

private struct SettingsSectionCard<Content: View>: View {
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
                .font(.system(size: 13, weight: .semibold))
            Divider()
            content
        }
        .padding(14)
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.72),
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

private struct PolicyReviewView: View {
    let presentation: ProductReviewPresentation
    let onBack: () -> Void
    let onApply: () -> Void

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
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            ScrollView {
                Text(presentation.report)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: safetySymbol)
                    .foregroundStyle(safetyColor)
                Text(presentation.safetyMessage)
                    .font(.system(size: 11))
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
}

private func pageHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.system(size: 28, weight: .semibold))
        Text(subtitle)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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
