import AppKit
import BlennyCore
import SwiftUI

#if DEBUG

enum DebugOrderingAvailability: Equatable {
    case ready
    case needsMapping
    case unverified
    case blocked
}

struct DebugOrderingRow: Identifiable {
    let subjectID: OrderingSubjectID
    let name: String
    let icon: NSImage?
    let systemKey: String?
    let currentPositionLabel: String?
    let reason: String?
    let isEligible: Bool
    let observedX: Double?
    let configuredPosition: Double?
    let availability: DebugOrderingAvailability
    let policy: MenuBarBundlePolicy?

    var id: String { subjectID.boardID }

    /// Compatibility for the existing application presentation path. Exact
    /// system rows retain their explicit `system:` Board namespace here.
    var bundleIdentifier: String {
        switch subjectID {
        case let .application(bundleIdentifier): bundleIdentifier
        case .systemItem: subjectID.boardID
        }
    }

    init(
        bundleIdentifier: String,
        name: String,
        icon: NSImage? = nil,
        systemKey: String? = nil,
        currentPositionLabel: String? = nil,
        reason: String? = nil,
        isEligible: Bool,
        observedX: Double? = nil,
        configuredPosition: Double? = nil,
        availability: DebugOrderingAvailability? = nil,
        policy: MenuBarBundlePolicy? = nil
    ) {
        self.init(
            subjectID: .application(bundleIdentifier),
            name: name,
            icon: icon,
            systemKey: systemKey,
            currentPositionLabel: currentPositionLabel,
            reason: reason,
            isEligible: isEligible,
            observedX: observedX,
            configuredPosition: configuredPosition,
            availability: availability,
            policy: policy
        )
    }

    init(
        subjectID: OrderingSubjectID,
        name: String,
        icon: NSImage? = nil,
        systemKey: String? = nil,
        currentPositionLabel: String? = nil,
        reason: String? = nil,
        isEligible: Bool,
        observedX: Double? = nil,
        configuredPosition: Double? = nil,
        availability: DebugOrderingAvailability? = nil,
        policy: MenuBarBundlePolicy? = nil
    ) {
        self.subjectID = subjectID
        self.name = name
        self.icon = icon
        self.systemKey = systemKey
        self.currentPositionLabel = currentPositionLabel
        self.reason = reason
        self.isEligible = isEligible
        self.observedX = observedX
        self.configuredPosition = configuredPosition
        self.policy = policy
        self.availability = availability ?? Self.inferredAvailability(
            systemKey: systemKey,
            configuredPosition: configuredPosition ?? currentPositionLabel.flatMap(Double.init),
            isEligible: isEligible,
            observedX: observedX
        )
    }

    private static func inferredAvailability(
        systemKey: String?,
        configuredPosition: Double?,
        isEligible: Bool,
        observedX: Double?
    ) -> DebugOrderingAvailability {
        if isEligible { return .ready }
        if systemKey == nil || configuredPosition == nil { return .needsMapping }
        if observedX == nil { return .unverified }
        return .unverified
    }
}

struct DebugExactSystemBoardItem: Identifiable {
    let item: ExactSystemOrderingItem
    let observation: SystemMenuBarItemObservation
    let row: DebugOrderingRow

    var id: String { row.subjectID.boardID }
    var subjectID: OrderingSubjectID { .systemItem(item) }
}

struct DebugOrderingConfigurationRequest: Equatable {
    let orderedSubjects: [OrderingSubjectID]
    let draftPolicies: [String: MenuBarBundlePolicy]
    let draftSubjectPolicies: [OrderingSubjectID: MenuBarBundlePolicy]
    let sourceCandidateGeneration: UUID
    let sourceLayoutGeneration: UUID

    init(draft: OrderingBoardLayoutDraft) {
        orderedSubjects = draft.physicalSubjects
        draftPolicies = draft.draftPolicies
        draftSubjectPolicies = draft.draftSubjectPolicies
        sourceCandidateGeneration = draft.candidateGeneration
        sourceLayoutGeneration = draft.layoutGeneration
    }

    var orderedBundleIdentifiers: [String] {
        orderedSubjects.compactMap { subject in
            guard case let .application(bundleIdentifier) = subject else { return nil }
            return bundleIdentifier
        }
    }
}

struct DebugOrderingTechnicalDetail: Identifiable, Equatable {
    let key: String
    let value: String

    var id: String { key }

    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

struct DebugOrderingPreview: Identifiable, Equatable {
    let id: UUID
    let fingerprint: String
    let title: String
    let detail: String
    let visibleScope: String
    let targetBundleIdentifiers: [String]
    let beforeOrder: [String]
    let afterOrder: [String]
    let technicalDetails: [DebugOrderingTechnicalDetail]

    init(
        id: UUID = UUID(),
        fingerprint: String,
        title: String,
        detail: String,
        visibleScope: String,
        targetBundleIdentifiers: [String],
        beforeOrder: [String],
        afterOrder: [String],
        technicalDetails: [DebugOrderingTechnicalDetail] = []
    ) {
        self.id = id
        self.fingerprint = fingerprint
        self.title = title
        self.detail = detail
        self.visibleScope = visibleScope
        self.targetBundleIdentifiers = targetBundleIdentifiers
        self.beforeOrder = beforeOrder
        self.afterOrder = afterOrder
        self.technicalDetails = technicalDetails
    }
}

@MainActor
final class DebugOrderingPresentation: ObservableObject {
    @Published var rows: [DebugOrderingRow] = []
    @Published var preview: DebugOrderingPreview?
    @Published var message: String?
    @Published var isError = false
    @Published var isBusy = false
    @Published var hasRecovery = false
    @Published var hasPendingRecovery = false
    @Published var hasObservation = false
    @Published var needsDataAccess = false
    @Published var canRefresh = true
    @Published var canApply = false

    var onRefresh: () -> Void = {}
    var onPreview: ([String]) -> Void = { _ in }
    var onReorder: ([String]) -> Void = { _ in }
    var onPreviewConfiguration: (DebugOrderingConfigurationRequest) -> Void = { _ in }
    var onApply: (String) -> Void = { _ in }
    var onRestore: () -> Void = {}
    var onDiscard: () -> Void = {}
    var onOpenDataAccess: () -> Void = {}

    func requestRefresh() { onRefresh() }
    func requestPreview(for bundleIdentifiers: [String]) { onPreview(bundleIdentifiers) }
    func requestReorder(_ desiredLeftToRightOwnerIdentifiers: [String]) {
        onReorder(desiredLeftToRightOwnerIdentifiers)
    }
    func requestConfigurationPreview(_ request: DebugOrderingConfigurationRequest) {
        onPreviewConfiguration(request)
    }
    func requestApply(fingerprint: String) { onApply(fingerprint) }
    func requestRestore() { onRestore() }

    func discardPreview() {
        preview = nil
        canApply = false
        onDiscard()
    }
}

/// Compact ordering review and recovery controls embedded beneath the Board.
/// The Board stays visible when an ordering read fails.
struct DebugOrderingStatusBar: View {
    @ObservedObject var presentation: DebugOrderingPresentation
    var managementEnabled: Bool? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                statusSymbol.frame(width: 14)
                Text(statusTitle)
                    .font(.system(.footnote, weight: .medium))
                if presentation.isBusy {
                    ProgressView().controlSize(.small)
                }
                Spacer(minLength: 8)
                orderingButtons
            }

            if let preview = presentation.preview {
                VStack(alignment: .leading, spacing: 3) {
                    Text(preview.visibleScope)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    orderLine("Before", values: preview.beforeOrder)
                    orderLine("After", values: preview.afterOrder)
                    Text(preview.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "Ordering preview. Before: \(preview.beforeOrder.joined(separator: ", ")). After: \(preview.afterOrder.joined(separator: ", "))."
                )
            }

            if let message = presentation.message, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(presentation.isError ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityLabel(message)
            }
            if presentation.hasObservation {
                Text(managementEnabled == true
                    ? "All areas can be arranged as a local configuration. Apply checks which mapped owners can be written and reports the rest."
                    : "All areas can be arranged as a local configuration. Missing mapping and unverified observation stay informational until Apply.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(statusBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(statusOutline, lineWidth: 0.75)
        }
    }

    @ViewBuilder
    private var statusSymbol: some View {
        if presentation.isBusy {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
        } else if presentation.hasPendingRecovery {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        } else if presentation.isError || !presentation.hasObservation {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(presentation.isError ? .red : .secondary)
        } else if presentation.preview != nil {
            Image(systemName: "arrow.right")
                .foregroundStyle(Color.accentColor)
        } else {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.secondary)
        }
    }

    private var statusTitle: String {
        if presentation.hasPendingRecovery {
            return "Restore needed before another order or policy apply"
        }
        if presentation.preview != nil {
            return "Review one combined area and order change"
        }
        if presentation.hasObservation {
            let mapped = presentation.rows.filter {
                $0.isEligible
            }.count
            return "Configuration order ready · \(mapped) applications available to arrange"
        }
        if presentation.rows.contains(where: { $0.observedX != nil }) {
            return "Observed placement shown; ordering eligibility is unverified"
        }
        return "Menu-bar placement and ordering eligibility are unverified"
    }

    @ViewBuilder
    private var orderingButtons: some View {
        if presentation.preview != nil {
            Button("Cancel", action: presentation.discardPreview)
                .disabled(presentation.isBusy)
            Button("Apply Changes", action: applyPreview)
                .buttonStyle(.borderedProminent)
                .disabled(!canApply)
        }
        if presentation.hasRecovery {
            Button(presentation.hasPendingRecovery ? "Restore Order" : "Undo Order", action: presentation.requestRestore)
                .disabled(presentation.isBusy)
                .help("Restore the exact preferred-position values in the ordering recovery receipt.")
        }
        if presentation.needsDataAccess {
            Button("Data Access…", action: presentation.onOpenDataAccess)
                .help("Open Privacy & Security > Files & Folders so Blenny can read the menu-bar preference container used for ordering review.")
        }
        Button("Refresh", action: presentation.requestRefresh)
            .disabled(!presentation.canRefresh || presentation.isBusy)
            .help("Run one bounded, read-only observation of the current menu-bar order.")
    }

    private func orderLine(_ label: String, values: [String]) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(label):").foregroundStyle(.secondary)
                Text(values.isEmpty ? "Unavailable" : values.joined(separator: "  →  "))
                    .fixedSize(horizontal: true, vertical: false)
                    .textSelection(.enabled)
            }
        }
        .scrollIndicators(.automatic)
        .font(.caption.monospaced())
    }

    private var canApply: Bool {
        presentation.canApply
            && presentation.preview != nil
            && !presentation.isBusy
            && !presentation.hasPendingRecovery
    }

    private var statusBackground: Color {
        if presentation.hasPendingRecovery { return .orange.opacity(0.07) }
        if presentation.isError { return .red.opacity(0.055) }
        if presentation.preview != nil { return Color.accentColor.opacity(0.055) }
        return Color(nsColor: .controlBackgroundColor).opacity(0.40)
    }

    private var statusOutline: Color {
        if presentation.hasPendingRecovery { return .orange.opacity(0.45) }
        if presentation.isError { return .red.opacity(0.35) }
        if presentation.preview != nil { return Color.accentColor.opacity(0.32) }
        return Color(nsColor: .separatorColor).opacity(0.5)
    }

    private func applyPreview() {
        guard let preview = presentation.preview, canApply else { return }
        presentation.requestApply(fingerprint: preview.fingerprint)
    }
}

#endif
