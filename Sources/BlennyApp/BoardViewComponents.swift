import AppKit
import BlennyCore
import SwiftUI

struct ProductPageHeader: View {
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

struct ProductPageSection<Content: View>: View {
    let title: String
    let systemImage: String
    let spacing: CGFloat
    let content: Content

    init(
        title: String,
        systemImage: String,
        spacing: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
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

struct SettingsGridRow<Title: View, Detail: View, Control: View>: View {
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
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
    }
}

extension ProductInterfaceSection {
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

extension MenuBarBundlePolicy {
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


extension View {
    /// Both application and system sources must expose the typed identity used
    /// by the Board and lane session validators. A provider alone does not.
    @ViewBuilder
    func policyBoardDragSource(_ payload: PolicyDragPayload) -> some View {
        #if BLENNY_PRODUCT || DEBUG
        if DebugDragStartDiagnostics.typedSource {
            self.draggable(PolicyDragPayload.self) { payload }
                .dragConfiguration(DragConfiguration(allowMove: true))
        } else {
            self.onDrag { policyDragItemProvider(for: payload) }
                .dragConfiguration(DragConfiguration(allowMove: true))
        }
        #else
        self.draggable(PolicyDragPayload.self) { payload }
            .dragConfiguration(DragConfiguration(allowMove: true))
        #endif
    }

    @ViewBuilder
    func diagnosticFocusable(_ focus: FocusState<Bool>.Binding) -> some View {
        #if BLENNY_PRODUCT || DEBUG
        if DebugDragStartDiagnostics.mode == .noFocus {
            self
        } else {
            self.focusable().focusEffectDisabled().focused(focus)
        }
        #else
        self.focusable().focusEffectDisabled().focused(focus)
        #endif
    }

    @ViewBuilder
    func diagnosticBoardSession(_ update: @escaping (DragSession) -> Void) -> some View {
        #if BLENNY_PRODUCT || DEBUG
        if DebugDragStartDiagnostics.mode == .minimalSession || DebugDragStartDiagnostics.mode == .simpleLane {
            self
        } else {
            self.dropPreviewsFormation(.none).onDragSessionUpdated(update)
        }
        #else
        self.dropPreviewsFormation(.none).onDragSessionUpdated(update)
        #endif
    }

    @ViewBuilder
    func diagnosticLaneDrop(
        accept: @escaping ([PolicyDragPayload], DropSession) -> Void,
        configuration: @escaping (DropSession) -> DropConfiguration,
        update: @escaping (DropSession) -> Void,
        direct: @escaping ([PolicyDragPayload], CGPoint) -> Bool
    ) -> some View {
        #if BLENNY_PRODUCT || DEBUG
        if DebugDragStartDiagnostics.mode == .minimalSession {
            self.dropDestination(for: PolicyDragPayload.self, action: direct)
        } else {
            self.dropDestination(for: PolicyDragPayload.self, action: accept)
                .dropConfiguration(configuration).onDropSessionUpdated(update)
        }
        #else
        self.dropDestination(for: PolicyDragPayload.self, action: accept)
            .dropConfiguration(configuration).onDropSessionUpdated(update)
        #endif
    }
}

#if BLENNY_PRODUCT || DEBUG
/// Immutable source leaf; deliberately omits all selection and focus machinery.
struct DebugPlainBoardIcon: View {
    let presentation: ResolvedPolicyIcon
    let payload: PolicyDragPayload?

    var body: some View {
        Group {
            if let payload {
                icon.policyBoardDragSource(payload)
            } else {
                icon
            }
        }
        .frame(width: BlennyDesign.itemFrame.width, height: BlennyDesign.itemFrame.height)
    }

    private var icon: some View {
        NaturalAspectSystemIcon(presentation: presentation, pointSize: 21, frame: CGSize(width: 29, height: 25))
    }
}
#endif
