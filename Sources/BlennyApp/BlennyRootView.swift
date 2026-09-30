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
