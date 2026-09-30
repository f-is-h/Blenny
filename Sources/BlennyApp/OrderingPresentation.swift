import AppKit
import BlennyCore
import SwiftUI

#if BLENNY_PRODUCT || DEBUG

enum OrderingAvailability: Equatable {
    case ready
    case needsMapping
    case unverified
    case blocked
}

struct OrderingRow: Identifiable {
    let subjectID: OrderingSubjectID
    let name: String
    let icon: NSImage?
    let systemKey: String?
    let currentPositionLabel: String?
    let reason: String?
    let isEligible: Bool
    let observedX: Double?
    let configuredPosition: Double?
    let availability: OrderingAvailability
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
        availability: OrderingAvailability? = nil,
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
        availability: OrderingAvailability? = nil,
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
    ) -> OrderingAvailability {
        if isEligible { return .ready }
        if systemKey == nil || configuredPosition == nil { return .needsMapping }
        if observedX == nil { return .unverified }
        return .unverified
    }
}

struct ExactSystemBoardItem: Identifiable {
    let item: ExactSystemOrderingItem
    let observation: SystemMenuBarItemObservation
    let row: OrderingRow

    var id: String { row.subjectID.boardID }
    var subjectID: OrderingSubjectID { .systemItem(item) }
}

struct OrderingConfigurationRequest: Equatable {
    let orderedSubjects: [OrderingSubjectID]
    let originalOrderedSubjects: [OrderingSubjectID]
    let originalPolicies: [OrderingSubjectID: MenuBarBundlePolicy]
    let draftPolicies: [String: MenuBarBundlePolicy]
    let draftSubjectPolicies: [OrderingSubjectID: MenuBarBundlePolicy]
    let sourceCandidateGeneration: UUID
    let sourceLayoutGeneration: UUID

    init(draft: OrderingBoardLayoutDraft) {
        orderedSubjects = draft.physicalSubjects
        originalOrderedSubjects = draft.resetting().physicalSubjects
        originalPolicies = draft.resetting().draftSubjectPolicies
        draftPolicies = draft.draftPolicies
        draftSubjectPolicies = draft.draftSubjectPolicies
        sourceCandidateGeneration = draft.candidateGeneration
        sourceLayoutGeneration = draft.layoutGeneration
    }

    /// Cross-area visibility changes remain valid for an owner without sorting support.
    /// Only an explicitly changed relative order within one unchanged area needs keys.
    func unavailableOrderChanges(eligibleSubjects: Set<OrderingSubjectID>, blenny: String) -> [OrderingSubjectID] {
        orderedSubjects.filter { subject in
            guard !eligibleSubjects.contains(subject), subject != .application(blenny),
                  originalPolicies[subject] == draftSubjectPolicies[subject],
                  let before = originalOrderedSubjects.firstIndex(of: subject),
                  let after = orderedSubjects.firstIndex(of: subject) else { return false }
            return orderedSubjects.contains { other in
                guard other != .application(blenny),
                      originalPolicies[other] == originalPolicies[subject],
                      draftSubjectPolicies[other] == draftSubjectPolicies[subject],
                      let old = originalOrderedSubjects.firstIndex(of: other),
                      let new = orderedSubjects.firstIndex(of: other) else { return false }
                return (before < old) != (after < new)
            }
        }
    }

    var orderedBundleIdentifiers: [String] {
        orderedSubjects.compactMap { subject in
            guard case let .application(bundleIdentifier) = subject else { return nil }
            return bundleIdentifier
        }
    }

    var subjectsRequiringConfiguration: [OrderingSubjectID] {
        OrderingBoardConfigurationScope.subjectsRequiringConfiguration(
            original: originalOrderedSubjects,
            draft: orderedSubjects,
            originalPolicies: originalPolicies,
            draftPolicies: draftSubjectPolicies
        )
    }
}

struct OrderingTechnicalDetail: Identifiable, Equatable {
    let key: String
    let value: String

    var id: String { key }

    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

struct OrderingPreview: Identifiable, Equatable {
    let id: UUID
    let fingerprint: String
    let title: String
    let detail: String
    let visibleScope: String
    let targetBundleIdentifiers: [String]
    let beforeOrder: [String]
    let afterOrder: [String]
    let technicalDetails: [OrderingTechnicalDetail]

    init(
        id: UUID = UUID(),
        fingerprint: String,
        title: String,
        detail: String,
        visibleScope: String,
        targetBundleIdentifiers: [String],
        beforeOrder: [String],
        afterOrder: [String],
        technicalDetails: [OrderingTechnicalDetail] = []
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
final class OrderingPresentation: ObservableObject {
    @Published var rows: [OrderingRow] = []
    @Published var preview: OrderingPreview?
    @Published var message: String?
    @Published var technicalDetail: String?
    @Published var requiresUndoReplacement = false
    @Published var requiresObservationRefresh = false
    @Published var isError = false
    @Published var isBusy = false
    @Published var hasRecovery = false
    @Published var hasPendingRecovery = false
    @Published var hasObservation = false
    @Published var needsDataAccess = false
    @Published var canRefresh = true
    @Published var canApply = false

    var onDraftChanged: (PolicyEditorViewModel) -> Void = { _ in }
    var onRefresh: () -> Void = {}
    var onPreview: ([String]) -> Void = { _ in }
    var onReorder: ([String]) -> Void = { _ in }
    var onPreviewConfiguration: (OrderingConfigurationRequest) -> Void = { _ in }
    var onApply: (String) -> Void = { _ in }
    var onRestore: () -> Void = {}
    var onDiscard: () -> Void = {}
    var onChooseLayoutFile: () -> Void = {}

    func finishSuccessfulRead() {
        isError = false
        needsDataAccess = false
        technicalDetail = nil
        message = "Drag to arrange, then choose Apply."
    }

    func requestRefresh() { onRefresh() }
    func requestPreview(for bundleIdentifiers: [String]) { onPreview(bundleIdentifiers) }
    func requestReorder(_ desiredLeftToRightOwnerIdentifiers: [String]) {
        onReorder(desiredLeftToRightOwnerIdentifiers)
    }
    func requestConfigurationPreview(_ request: OrderingConfigurationRequest) {
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
struct OrderingStatusBar: View {
    @ObservedObject var presentation: OrderingPresentation
    var managementEnabled: Bool? = nil
    var hasDraftChanges = false
    @State private var showsDetails = false

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
                if let detail = presentation.technicalDetail, !detail.isEmpty {
                    Button("Details…") { showsDetails = true }
                        .popover(isPresented: $showsDetails) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Menu bar order details").font(.headline)
                                ScrollView {
                                    Text(detail)
                                        .font(.callout)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxHeight: 240)
                                Button("Copy details") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(detail, forType: .string)
                                }
                            }
                            .padding(16)
                            .frame(width: 440)
                        }
                }
            }

            Text(statusMessage)
                .font(.callout)
                .lineLimit(2)
                .help(statusMessage)
                .foregroundStyle(presentation.isError ? .red : .secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 17, alignment: .leading)
                .textSelection(.enabled)

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

    private var statusMessage: String {
        if let message = presentation.message, !message.isEmpty { return message }
        if hasDraftChanges { return "Changes not applied." }
        if presentation.hasObservation { return "No pending changes." }
        return "Refresh to read the current order."
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
        if presentation.isBusy { return "Working…" }
        if presentation.requiresObservationRefresh { return "Refresh needed" }
        if presentation.hasPendingRecovery { return "Recovery needed" }
        if presentation.isError { return "Needs attention" }
        if presentation.requiresUndoReplacement { return "Replace previous Undo?" }
        return presentation.hasObservation ? "Menu bar order" : "Order unavailable"
    }

    @ViewBuilder
    private var orderingButtons: some View {
        if presentation.hasRecovery {
            Button(presentation.hasPendingRecovery ? "Recover Changes" : "Undo Changes", action: presentation.requestRestore)
                .disabled(presentation.isBusy || hasDraftChanges)
                .help(presentation.hasPendingRecovery
                    ? "Recover an unfinished change."
                    : "Undo the last Apply, including visibility and order changes.")
        }
        if presentation.needsDataAccess {
            Button("Choose Layout File…", action: presentation.onChooseLayoutFile)
        }
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
