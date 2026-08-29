import CoreTransferable
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import BlennyCore

@Suite("Policy board interaction")
struct PolicyBoardInteractionTests {
    private let blenny = "xyz.fi5h.blenny"
    private let visible = "com.example.Visible"
    private let revealable = "com.example.Revealable"
    private let hidden = "com.example.Hidden"

    @Test("One drag token changes the local draft at most once")
    func dropIsIdempotent() throws {
        let generation = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let token = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        var editor = try makeEditor()
        var coordinator = PolicyDraftAssignmentCoordinator(
            candidateGeneration: generation
        )
        let payload = PolicyDragPayload(
            bundleIdentifier: revealable,
            sourcePolicy: .revealable,
            candidateGeneration: generation,
            dragToken: token
        )

        #expect(
            coordinator.assign(
                payload: payload,
                destination: .hidden,
                editor: &editor
            ) == .changed
        )
        #expect(editor.effectivePolicy(for: revealable) == .hidden)
        #expect(editor.hasDraftChanges)
        #expect(
            coordinator.assign(
                payload: payload,
                destination: .visible,
                editor: &editor
            ) == .rejected(.duplicateDelivery)
        )
        #expect(editor.effectivePolicy(for: revealable) == .hidden)
    }

    @Test("Stale, same-lane, locked, and unknown assignments fail closed")
    func invalidAssignments() throws {
        let generation = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        var editor = try makeEditor()
        var coordinator = PolicyDraftAssignmentCoordinator(
            candidateGeneration: generation
        )

        #expect(
            coordinator.assign(
                payload: payload(
                    revealable,
                    source: .revealable,
                    generation: UUID()
                ),
                destination: .hidden,
                editor: &editor
            ) == .rejected(.staleCandidateGeneration)
        )
        #expect(
            coordinator.assign(
                payload: payload(revealable, source: .revealable, generation: generation),
                destination: .revealable,
                editor: &editor
            ) == .rejected(.samePolicy)
        )
        #expect(
            coordinator.assign(
                payload: payload(blenny, source: .visible, generation: generation),
                destination: .hidden,
                editor: &editor
            ) == .rejected(.blennyMustRemainVisible)
        )
        #expect(
            coordinator.assign(
                payload: payload(
                    "com.example.Missing",
                    source: .visible,
                    generation: generation
                ),
                destination: .hidden,
                editor: &editor
            ) == .rejected(.unknownCandidate)
        )
        #expect(!editor.hasDraftChanges)
    }

    @Test("A source policy change makes an in-flight drag stale")
    func staleSourcePolicy() throws {
        let generation = UUID()
        var editor = try makeEditor()
        var coordinator = PolicyDraftAssignmentCoordinator(
            candidateGeneration: generation
        )
        let inFlight = payload(
            revealable,
            source: .revealable,
            generation: generation
        )

        #expect(
            coordinator.assign(
                bundleIdentifier: revealable,
                destination: .hidden,
                editor: &editor
            ) == .changed
        )
        #expect(
            coordinator.assign(
                payload: inFlight,
                destination: .visible,
                editor: &editor
            ) == .rejected(.staleSourcePolicy)
        )
    }

    @Test("Keyboard assignment uses the same draft command path")
    func keyboardAssignmentMatchesDrop() throws {
        var editor = try makeEditor()
        var coordinator = PolicyDraftAssignmentCoordinator(
            candidateGeneration: UUID()
        )

        #expect(
            coordinator.assign(
                bundleIdentifier: visible,
                destination: .revealable,
                editor: &editor,
                commandToken: UUID(
                    uuidString: "00000000-0000-0000-0000-000000000020"
                )!
            ) == .changed
        )
        #expect(editor.effectivePolicy(for: visible) == .revealable)

        editor.discardDraft(using: BundlePolicyDraft(acceptedPolicy: editor.acceptedPolicy))
        #expect(!editor.hasDraftChanges)
        #expect(editor.effectivePolicy(for: visible) == .visible)
        #expect(editor.effectivePolicy(for: blenny) == .visible)
    }

    @Test("Returning a bundle to its accepted group removes the draft assignment")
    func returningToAcceptedPolicyClearsAssignment() throws {
        var editor = try makeEditor()
        var coordinator = PolicyDraftAssignmentCoordinator(
            candidateGeneration: UUID()
        )

        #expect(
            coordinator.assign(
                bundleIdentifier: revealable,
                destination: .hidden,
                editor: &editor
            ) == .changed
        )
        #expect(editor.hasDraftChanges)
        #expect(
            coordinator.assign(
                bundleIdentifier: revealable,
                destination: .revealable,
                editor: &editor
            ) == .changed
        )
        #expect(!editor.hasDraftChanges)
        #expect(editor.effectivePolicy(for: revealable) == .revealable)
    }

    @Test("A forbidden target does not consume an otherwise current drag")
    func invalidTargetDoesNotConsumeDrag() throws {
        let generation = UUID()
        let drag = payload(revealable, source: .revealable, generation: generation)
        var editor = try makeEditor()
        var coordinator = PolicyDraftAssignmentCoordinator(
            candidateGeneration: generation
        )

        #expect(
            coordinator.assign(
                payload: drag,
                destination: .revealable,
                editor: &editor
            ) == .rejected(.samePolicy)
        )
        #expect(
            coordinator.assign(
                payload: drag,
                destination: .hidden,
                editor: &editor
            ) == .changed
        )
    }

    @Test("Selection, label priority, target, settle, and interruption are deterministic")
    func interactionStateLifecycle() {
        let app = PolicyBoardItemID.application(visible)
        let system = PolicyBoardItemID.systemItem("com.apple.menuextra.wifi")
        let token = UUID()
        let payload = PolicyDragPayload(
            bundleIdentifier: visible,
            sourcePolicy: .visible,
            candidateGeneration: UUID(),
            dragToken: token
        )
        var state = PolicyBoardInteractionState()

        state.setHovered(app, isHovered: true)
        #expect(state.namePresentationItem == app)
        state.setHovered(app, isHovered: false)
        state.setFocused(system, isFocused: true)
        #expect(state.namePresentationItem == system)
        state.setFocused(system, isFocused: false)
        state.select(app)
        #expect(state.namePresentationItem == app)
        state.setHovered(system, isHovered: true)
        #expect(state.namePresentationItem == system)
        state.setHovered(system, isHovered: false)
        #expect(state.namePresentationItem == app)

        state.beginDrag(bundleIdentifier: visible, sourcePolicy: .visible)
        state.target(policy: .hidden, validation: .changed)
        #expect(state.dropTarget?.isValid == true)
        state.completeDrop(payload: payload, destination: .hidden, outcome: .changed)
        #expect(state.selectedItem == app)
        #expect(state.settleState?.destination == .hidden)

        state.finishSettling(token: UUID())
        #expect(state.settleState != nil)
        state.finishSettling(token: token)
        #expect(state.settleState == nil)

        state.beginDrag(bundleIdentifier: visible, sourcePolicy: .visible)
        state.target(
            policy: .visible,
            validation: .rejected(.samePolicy)
        )
        #expect(state.dropTarget == nil)
        state.clearTransientPresentation()
        #expect(state.selectedItem == app)
        #expect(state.draggedBundleIdentifier == nil)
        #expect(state.draggedSourcePolicy == nil)
        #expect(state.dropTarget == nil)
    }

    @Test("Automatic landing feedback follows stable order without adding lane ordering")
    func automaticLandingProjection() {
        let existing = [
            "com.example.Bravo",
            "com.example.Delta",
            "com.example.Zulu",
        ]

        #expect(
            PolicyBoardLandingProjection.automaticIndex(
                for: "com.example.Alpha",
                among: existing
            ) == 0
        )
        #expect(
            PolicyBoardLandingProjection.automaticIndex(
                for: "com.example.Charlie",
                among: existing
            ) == 1
        )
        #expect(
            PolicyBoardLandingProjection.automaticIndex(
                for: "com.example.Echo",
                among: existing
            ) == 2
        )
        #expect(
            PolicyBoardLandingProjection.automaticIndex(
                for: "com.example.Zzz",
                among: existing
            ) == existing.endIndex
        )
    }

    @Test("The native drag payload preserves its identity through transfer encoding")
    func payloadCodingRoundTrip() throws {
        let payload = PolicyDragPayload(
            bundleIdentifier: revealable,
            sourcePolicy: .revealable,
            candidateGeneration: UUID(
                uuidString: "00000000-0000-0000-0000-000000000030"
            )!,
            dragToken: UUID(
                uuidString: "00000000-0000-0000-0000-000000000031"
            )!
        )

        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(PolicyDragPayload.self, from: encoded)

        #expect(decoded == payload)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                PolicyDragPayload.self,
                from: Data("{\"bundleIdentifier\":42}".utf8)
            )
        }
    }

    @Test("The native item provider delivers the transferable drag payload")
    func itemProviderTransferRoundTrip() async throws {
        let payload = PolicyDragPayload(
            bundleIdentifier: revealable,
            sourcePolicy: .revealable,
            candidateGeneration: UUID(
                uuidString: "00000000-0000-0000-0000-000000000032"
            )!,
            dragToken: UUID(
                uuidString: "00000000-0000-0000-0000-000000000033"
            )!
        )
        let provider = NSItemProvider()
        provider.register(payload)

        #expect(payload.id.bundleIdentifier == payload.bundleIdentifier)
        #expect(payload.id.sourcePolicy == payload.sourcePolicy)
        #expect(payload.id.candidateGeneration == payload.candidateGeneration)

        #expect(
            provider.hasItemConformingToTypeIdentifier(
                UTType.blennyPolicyBundleDrag.identifier
            )
        )
        #expect(
            provider.registeredTypeIdentifiers.contains(
                UTType.blennyPolicyBundleDrag.identifier
            )
        )

        let decoded: PolicyDragPayload = try await withCheckedThrowingContinuation {
            continuation in
            _ = provider.loadTransferable(type: PolicyDragPayload.self) {
                continuation.resume(with: $0)
            }
        }

        #expect(decoded == payload)
    }

    private func payload(
        _ bundleIdentifier: String,
        source: MenuBarBundlePolicy,
        generation: UUID
    ) -> PolicyDragPayload {
        PolicyDragPayload(
            bundleIdentifier: bundleIdentifier,
            sourcePolicy: source,
            candidateGeneration: generation,
            dragToken: UUID()
        )
    }

    private func makeEditor() throws -> PolicyEditorViewModel {
        let policy = try PersistentBundlePolicyDocument(
            managementEnabled: false,
            policies: [
                .init(bundleIdentifier: blenny, policy: .visible),
                .init(bundleIdentifier: visible, policy: .visible),
                .init(bundleIdentifier: revealable, policy: .revealable),
                .init(bundleIdentifier: hidden, policy: .hidden),
            ]
        )
        return try PolicyEditorViewModel(
            acceptedPolicy: policy,
            candidateInventory: PolicyCandidateInventory(observations: [
                observation(blenny, pid: 10),
                observation(visible, pid: 20),
                observation(revealable, pid: 30),
                observation(hidden, pid: 40),
            ]),
            blennyBundleIdentifier: blenny
        )
    }

    private func observation(
        _ bundleIdentifier: String,
        pid: Int32
    ) -> MenuBarPolicyOwnershipObservation {
        MenuBarPolicyOwnershipObservation(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: pid,
            menuBarItemCount: 1
        )
    }
}
