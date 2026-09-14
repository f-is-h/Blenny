#if DEBUG
import BlennyCore
import Foundation

@MainActor
enum OrderingBoardLifecycleSelfCheck {
    private struct CheckFailure: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func run() throws {
        #if BLENNY_GROUPED_FALLBACK_TRIAL
        guard GroupedStatusItemContent.validateDetachedLayout() else {
            throw CheckFailure(message: "Grouped native controls must retain separate, adjacent hit targets")
        }
        #endif
        let staleError = DebugOrderingPresentation()
        staleError.isError = true
        staleError.needsDataAccess = true
        staleError.technicalDetail = "Earlier file access refusal"
        staleError.finishSuccessfulRead()
        guard !staleError.isError, !staleError.needsDataAccess,
              staleError.technicalDetail == nil else {
            throw CheckFailure(message: "Successful reads must clear obsolete permission diagnostics")
        }

        let blenny = "xyz.fi5h.blenny"
        let alpha = "com.example.OrderingAlpha"
        let beta = "com.example.OrderingBeta"
        let gamma = "com.example.OrderingGamma"
        let siriObservationIdentifier = MenuBarItemIdentity(
            ownerBundleIdentifier: ExactSystemOrderingItem.siri.hostBundleIdentifier,
            accessibilityIdentifier: "Siri",
            semanticLabel: nil,
            role: "AXMenuBarItem",
            subrole: "AXMenuExtra",
            instanceOrdinal: 0,
            confidence: .strong
        ).stableKey
        let observations = [
            MenuBarPolicyOwnershipObservation(
                bundleIdentifier: blenny, processIdentifier: 10, menuBarItemCount: 1
            ),
            MenuBarPolicyOwnershipObservation(
                bundleIdentifier: alpha, processIdentifier: 11, menuBarItemCount: 1
            ),
            MenuBarPolicyOwnershipObservation(
                bundleIdentifier: beta, processIdentifier: 12, menuBarItemCount: 1
            ),
            MenuBarPolicyOwnershipObservation(
                bundleIdentifier: gamma, processIdentifier: 13, menuBarItemCount: 1
            ),
        ]
        let inventory = PolicyCandidateInventory(observations: observations)
        let accepted = try PersistentBundlePolicyDocument(
            managementEnabled: false,
            policies: [
                .init(bundleIdentifier: blenny, policy: .visible),
                .init(bundleIdentifier: alpha, policy: .visible),
                .init(bundleIdentifier: beta, policy: .visible),
                .init(bundleIdentifier: gamma, policy: .revealable),
            ]
        )
        let editor = try PolicyEditorViewModel(
            acceptedPolicy: accepted, candidateInventory: inventory,
            systemItems: [
                SystemMenuBarItemObservation(
                    observationIdentifier: siriObservationIdentifier,
                    ownerBundleIdentifier: ExactSystemOrderingItem.siri.hostBundleIdentifier,
                    displayName: ExactSystemOrderingItem.siri.displayName,
                    observationCount: 1
                ),
            ],
            blennyBundleIdentifier: blenny
        )
        let model = ProductInterfaceModel()
        model.display(
            model: editor, observationCount: observations.count,
            recoveryAvailable: false
        )

        setRows(model, alphaFirst: true)
        model.initializeOrderingLayoutFromCurrentRows(force: true)
        try require(model.orderingLayoutDraft != nil, "initial ordering layout was not created")
        try require(
            model.orderingLayoutDraft?.physicalSubjects.contains(.systemItem(.siri)) == false,
            "deferred Siri ordering unexpectedly entered the Board layout"
        )
        try require(
            Set(model.systemItemPolicyDestinations(
                for: siriObservationIdentifier
            )) == Set(MenuBarBundlePolicy.allCases),
            "deferred Siri ordering lost its three-state policy controls"
        )

        try runUnchangedDropCheck(model: model, alpha: alpha, beta: beta)
        try runUnavailableOrderChecks(blenny: blenny, alpha: alpha, beta: beta, gamma: gamma)

        try runLocalDraftChecks(
            accepted: accepted, inventory: inventory,
            observationsCount: observations.count, blenny: blenny,
            alpha: alpha, beta: beta, gamma: gamma
        )

        try runDeferredSystemPolicyApplyCheck(
            accepted: accepted,
            inventory: inventory,
            observationsCount: observations.count,
            blenny: blenny,
            alpha: alpha,
            beta: beta,
            siriObservationIdentifier: siriObservationIdentifier
        )

        for revision in 0..<3 {
            let alphaSubject = OrderingSubjectID.application(alpha)
            let stale = try require(
                model.beginOrderingDragPayload(
                    subjectID: alphaSubject, sourcePolicy: .visible
                ),
                "revision \(revision): current drag payload was unavailable"
            )
            let repeated = try require(
                model.beginOrderingDragPayload(
                    subjectID: alphaSubject, sourcePolicy: .visible
                ),
                "revision \(revision): repeated drag payload was unavailable"
            )
            try require(
                repeated == stale,
                "revision \(revision): one layout produced unstable drag payloads"
            )

            let alphaFirst = revision.isMultiple(of: 2)
            setRows(model, alphaFirst: alphaFirst)
            model.initializeOrderingLayoutFromCurrentRows(force: true)
            let current = try require(
                model.beginOrderingDragPayload(
                    subjectID: alphaSubject, sourcePolicy: .visible
                ),
                "revision \(revision): post-Apply payload was unavailable"
            )
            try require(
                current.id != stale.id,
                "revision \(revision): post-Apply drag retained the old transferable identity"
            )

            let destination = OrderingBoardLayoutDestination(
                policy: .visible,
                position: alphaFirst ? .after(beta) : .before(beta)
            )
            try requireRejected(
                model.requestOrderingConfigurationDrop(
                    payload: stale, destination: destination
                ),
                "revision \(revision): a payload from the preceding layout was accepted"
            )
            try requireChanged(
                model.requestOrderingConfigurationDrop(
                    payload: current, destination: destination
                ),
                expectedPolicyChange: false,
                message: "revision \(revision): the first drag after Apply was rejected"
            )
        }

        let staleCrossLane = try require(
            model.beginOrderingDragPayload(
                subjectID: .application(gamma), sourcePolicy: .revealable
            ),
            "pre-display cross-lane payload was unavailable"
        )
        let committedRequest = try require(
            model.currentOrderingConfigurationRequest,
            "committed configuration request was unavailable"
        )
        let acceptedAfterApply = try PersistentBundlePolicyDocument(
            managementEnabled: true, policies: accepted.policies,
            bluetoothPolicy: accepted.bluetoothPolicy,
            systemItemPolicies: accepted.systemItemPolicies
        )
        let synchronized = try PolicyEditorViewModel(
            acceptedPolicy: acceptedAfterApply, candidateInventory: inventory,
            blennyBundleIdentifier: blenny
        )
        model.display(
            model: synchronized, observationCount: observations.count,
            recoveryAvailable: false
        )
        try require(
            model.orderingLayoutDraft == nil,
            "accepted-model display unexpectedly retained the preceding layout"
        )
        try require(
            model.installCommittedOrderingLayout(from: committedRequest),
            "committed layout could not be rebound before post-commit observation"
        )
        _ = try require(
            model.beginOrderingDragPayload(
                subjectID: .application(alpha), sourcePolicy: .visible
            ),
            "drag was unavailable after simulated post-commit read failure"
        )
        let crossLaneDestination = OrderingBoardLayoutDestination(
            policy: .visible, position: .end
        )
        try requireRejected(
            model.requestOrderingConfigurationDrop(
                payload: staleCrossLane, destination: crossLaneDestination
            ),
            "a payload from the preceding accepted model was accepted"
        )
        let freshCrossLane = try require(
            model.beginOrderingDragPayload(
                subjectID: .application(gamma), sourcePolicy: .revealable
            ),
            "fresh cross-lane payload was unavailable"
        )
        try requireChanged(
            model.requestOrderingConfigurationDrop(
                payload: freshCrossLane, destination: crossLaneDestination
            ),
            expectedPolicyChange: true,
            message: "fresh cross-lane drag after accepted-model display was rejected"
        )

        try runManagementTransitionChecks(
            accepted: accepted,
            inventory: inventory,
            observationsCount: observations.count,
            blenny: blenny,
            alpha: alpha,
            beta: beta
        )
    }

    private static func runUnavailableOrderChecks(
        blenny: String, alpha: String, beta: String, gamma: String
    ) throws {
        // Pure layout fixtures only: no observation, preferences or writer.
        let layout = try OrderingBoardLayoutDraft(
            visible: [alpha, beta, blenny], revealable: [gamma], hidden: [],
            candidateGeneration: UUID()
        )
        let eligible: Set<OrderingSubjectID> = [.application(beta), .application(gamma)]
        let initialRequest = DebugOrderingConfigurationRequest(draft: layout)
        try require(initialRequest.unavailableOrderChanges(
            eligibleSubjects: eligible, blenny: blenny
        ).isEmpty, "unchanged layout reported an unsupported ordering change")

        let source = OrderingBoardLayoutItemID(
            bundleIdentifier: alpha, sourcePolicy: .visible,
            candidateGeneration: layout.candidateGeneration,
            layoutGeneration: layout.layoutGeneration
        )
        let visibilityOnly = try layout.moving(
            source, to: .init(policy: .hidden, position: .end)
        ).get()
        try require(DebugOrderingConfigurationRequest(draft: visibilityOnly)
            .unavailableOrderChanges(eligibleSubjects: eligible, blenny: blenny).isEmpty,
            "valid visibility-only move required unsupported sorting")

        let reordered = try layout.moving(
            source, to: .init(policy: .visible, position: .after(beta))
        ).get()
        try require(DebugOrderingConfigurationRequest(draft: reordered)
            .unavailableOrderChanges(eligibleSubjects: eligible, blenny: blenny)
            == [.application(alpha)],
            "unsupported same-area ordering could be silently omitted")
    }

    private static func runUnchangedDropCheck(
        model: ProductInterfaceModel,
        alpha: String,
        beta: String
    ) throws {
        let subject = OrderingSubjectID.application(alpha)
        let initialLayout = try require(
            model.orderingLayoutDraft,
            "unchanged-drop layout was unavailable"
        )
        var previewRequestCount = 0
        model.orderingPresentation.onPreviewConfiguration = { _ in
            previewRequestCount += 1
        }
        let payload = try require(
            model.beginOrderingDragPayload(subjectID: subject, sourcePolicy: .visible),
            "unchanged-drop payload was unavailable"
        )
        let sourceRevisionBeforeNoOp = model.orderingDragSourceRevision
        try requireUnchanged(
            model.requestOrderingConfigurationDrop(
                payload: payload,
                destination: .init(policy: .visible, position: .before(beta))
            ),
            "dropping into the original effective gap was reported as an error"
        )
        try require(
            model.orderingLayoutDraft == initialLayout,
            "an unchanged drop replaced or mutated the Board layout"
        )
        try require(
            model.orderingDragSourceRevision == sourceRevisionBeforeNoOp + 1,
            "an unchanged drop did not invalidate the native drag source"
        )
        try require(
            previewRequestCount == 0,
            "an unchanged drop requested an ordering preview"
        )
        try requireRejected(
            model.requestOrderingConfigurationDrop(
                payload: payload,
                destination: .init(policy: .visible, position: .after(beta))
            ),
            "an unchanged delivery token could be reused"
        )
        let fresh = try require(
            model.beginOrderingDragPayload(subjectID: subject, sourcePolicy: .visible),
            "a fresh drag was unavailable after an unchanged drop"
        )
        try require(
            fresh.id != payload.id,
            "an unchanged drop reused its completed delivery identity"
        )
        let sourceRevisionBeforeCancellation = model.orderingDragSourceRevision
        model.retireOrderingDragSession(fresh.id)
        try require(
            model.orderingDragSourceRevision == sourceRevisionBeforeCancellation + 1,
            "a cancelled native drag did not invalidate its source authority"
        )
        model.retireOrderingDragSession(fresh.id)
        try require(
            model.orderingDragSourceRevision == sourceRevisionBeforeCancellation + 1,
            "late cleanup for a cancelled native drag invalidated another source"
        )
        try requireRejected(
            model.requestOrderingConfigurationDrop(
                payload: fresh,
                destination: .init(policy: .visible, position: .after(beta))
            ),
            "a payload from a cancelled native drag could be delivered"
        )
        let freshAfterCancellation = try require(
            model.beginOrderingDragPayload(subjectID: subject, sourcePolicy: .visible),
            "a fresh drag was unavailable after native-session cancellation"
        )
        try require(
            freshAfterCancellation.id != fresh.id,
            "native-session cancellation reused the retired source identity"
        )
        try requireUnchanged(
            model.requestOrderingConfigurationDrop(
                payload: freshAfterCancellation,
                destination: .init(policy: .visible, position: .before(alpha))
            ),
            "dropping onto the dragged item was reported as an error"
        )
        try require(
            model.orderingLayoutDraft == initialLayout && previewRequestCount == 0,
            "a same-item drop changed the layout or requested a preview"
        )
        let freshAfterSameItem = try require(
            model.beginOrderingDragPayload(subjectID: subject, sourcePolicy: .visible),
            "a fresh drag was unavailable after a same-item drop"
        )
        try require(
            freshAfterSameItem.id != freshAfterCancellation.id,
            "a same-item drop reused its completed delivery identity"
        )
        try requireChanged(
            model.requestOrderingConfigurationDrop(
                payload: freshAfterSameItem,
                destination: .init(policy: .visible, position: .after(beta))
            ),
            expectedPolicyChange: false,
            message: "a real order change was rejected after an unchanged drop"
        )
        model.resetOrderingLayoutDraft()
    }

    private static func runLocalDraftChecks(
        accepted: PersistentBundlePolicyDocument,
        inventory: PolicyCandidateInventory,
        observationsCount: Int,
        blenny: String,
        alpha: String,
        beta: String,
        gamma: String
    ) throws {
        let editor = try PolicyEditorViewModel(
            acceptedPolicy: accepted, candidateInventory: inventory,
            blennyBundleIdentifier: blenny
        )
        let model = ProductInterfaceModel()
        model.display(model: editor, observationCount: observationsCount, recoveryAvailable: true)
        model.setAccessibilityTrusted(true, hasRequestedSystemPrompt: true)
        model.setManagementRuntimeState(.stopped, developmentMutationAvailable: true)
        setRows(model, alphaFirst: true)
        model.initializeOrderingLayoutFromCurrentRows(force: true)
        let initialLayout = try require(model.orderingLayoutDraft, "local-draft layout unavailable")
        var previewCount = 0
        var applyCount = 0
        var draftCount = 0
        model.orderingPresentation.onPreviewConfiguration = { _ in previewCount += 1 }
        model.orderingPresentation.onApply = { _ in applyCount += 1 }
        model.orderingPresentation.onDraftChanged = { _ in draftCount += 1 }
        try require(model.controls.refreshEnabled && model.controls.resumeEnabled
            && model.controls.restoreEnabled, "clean fixture controls were not available")

        let orderPayload = try require(
            model.beginOrderingDragPayload(subjectID: .application(alpha), sourcePolicy: .visible),
            "local same-area drag unavailable"
        )
        try requireChanged(
            model.requestOrderingConfigurationDrop(
                payload: orderPayload,
                destination: .init(policy: .visible, position: .after(beta))
            ),
            expectedPolicyChange: false, message: "local same-area drop rejected"
        )
        try require(model.model?.hasDraftChanges == false && model.hasDraftChanges,
            "pure ordering was not represented as an unapplied draft")
        try requireDraftControls(model)
        try require(previewCount == 0 && applyCount == 0 && draftCount == 1,
            "same-area drop requested preview or Apply instead of a local draft update")

        let crossPayload = try require(
            model.beginOrderingDragPayload(subjectID: .application(gamma), sourcePolicy: .revealable),
            "local cross-area drag unavailable"
        )
        try requireChanged(
            model.requestOrderingConfigurationDrop(
                payload: crossPayload,
                destination: .init(policy: .visible, position: .end)
            ),
            expectedPolicyChange: true, message: "local cross-area drop rejected"
        )
        try require(model.model?.hasDraftChanges == true && model.hasDraftChanges,
            "cross-area drop did not retain a combined draft")
        try requireDraftControls(model)
        try require(previewCount == 0 && applyCount == 0 && draftCount == 2,
            "cross-area drop requested preview or Apply instead of a local draft update")

        _ = try require(model.discardDraft(), "combined draft could not be discarded")
        try require(!model.hasDraftChanges && model.model?.hasDraftChanges == false,
            "Discard left policy or ordering changes pending")
        try require(model.orderingLayoutDraft?.visible == initialLayout.visible
            && model.orderingLayoutDraft?.revealable == initialLayout.revealable
            && model.orderingLayoutDraft?.hidden == initialLayout.hidden,
            "Discard did not restore the original Board layout")
        try require(model.controls.refreshEnabled && model.controls.resumeEnabled
            && model.controls.restoreEnabled && !model.controls.discardDraftEnabled,
            "Discard did not restore clean-state controls")
        try require(previewCount == 0 && applyCount == 0,
            "Discard requested a preview or system Apply")

        let afterDiscard = try require(
            model.beginOrderingDragPayload(subjectID: .application(alpha), sourcePolicy: .visible),
            "Discard did not restore a fresh drag authority"
        )
        try requireChanged(
            model.requestOrderingConfigurationDrop(
                payload: afterDiscard,
                destination: .init(policy: .visible, position: .after(beta))
            ),
            expectedPolicyChange: false,
            message: "first same-area drag immediately after Discard was rejected"
        )
        try requireDraftControls(model)
        try require(previewCount == 0 && applyCount == 0 && draftCount == 3,
            "post-Discard drag did not remain a local draft update")
    }

    private static func requireDraftControls(_ model: ProductInterfaceModel) throws {
        try require(!model.controls.refreshEnabled && !model.controls.resumeEnabled
            && !model.controls.restoreEnabled && model.controls.applyEnabled
            && model.controls.discardDraftEnabled,
            "unapplied changes did not consistently gate the editor controls")
    }

    private static func runDeferredSystemPolicyApplyCheck(
        accepted: PersistentBundlePolicyDocument,
        inventory: PolicyCandidateInventory,
        observationsCount: Int,
        blenny: String,
        alpha: String,
        beta: String,
        siriObservationIdentifier: String
    ) throws {
        let siri = ExactSystemOrderingItem.siri
        let editor = try PolicyEditorViewModel(
            acceptedPolicy: accepted,
            candidateInventory: inventory,
            systemItems: [.init(
                observationIdentifier: siriObservationIdentifier,
                ownerBundleIdentifier: siri.hostBundleIdentifier,
                displayName: siri.displayName,
                observationCount: 1
            )],
            blennyBundleIdentifier: blenny
        )
        let model = ProductInterfaceModel()
        model.display(
            model: editor,
            observationCount: observationsCount,
            recoveryAvailable: false
        )
        setRows(model, alphaFirst: true)
        model.initializeOrderingLayoutFromCurrentRows(force: true)
        let oldPayload = try require(
            model.beginOrderingDragPayload(
                subjectID: .application(alpha), sourcePolicy: .visible
            ),
            "pre-Siri-Apply drag payload was unavailable"
        )
        let siriPayload = try require(
            model.systemPolicyDragPayload(
                for: siriObservationIdentifier,
                sourcePolicy: .visible
            ),
            "composite Siri observation did not produce a policy drag payload"
        )
        try require(
            siriPayload.bundleIdentifier == siri.observationIdentifier,
            "composite Siri payload did not use the canonical policy identity"
        )
        try require(
            model.assign(payload: siriPayload, destination: .revealable) == .changed,
            "composite Siri payload could not create a cross-area policy draft"
        )
        try require(
            model.assign(payload: siriPayload, destination: .hidden)
                == .rejected(.duplicateDelivery),
            "composite Siri payload was accepted for repeated delivery"
        )
        var appliedSystemPolicies = accepted.systemItemPolicies
        appliedSystemPolicies[siri.observationIdentifier] = .revealable
        let applied = try PersistentBundlePolicyDocument(
            managementEnabled: accepted.managementEnabled,
            policies: accepted.policies,
            bluetoothPolicy: accepted.bluetoothPolicy,
            systemItemPolicies: appliedSystemPolicies
        )
        let edited = try require(model.model, "Siri-only editor model was unavailable")
        let synchronized = try edited.synchronizingAcceptedPolicy(
            applied, preservingDraft: false
        )
        model.display(
            model: synchronized,
            observationCount: observationsCount,
            recoveryAvailable: false,
            preservingOrderingLayout: true
        )
        try requireRejected(
            model.requestOrderingConfigurationDrop(
                payload: oldPayload,
                destination: .init(policy: .visible, position: .after(beta))
            ),
            "Siri-only Apply accepted its pre-Apply drag token"
        )
        let freshPayload = try require(
            model.beginOrderingDragPayload(
                subjectID: .application(alpha), sourcePolicy: .visible
            ),
            "Siri-only Apply did not preserve Board dragging"
        )
        try requireChanged(
            model.requestOrderingConfigurationDrop(
                payload: freshPayload,
                destination: .init(policy: .visible, position: .after(beta))
            ),
            expectedPolicyChange: false,
            message: "first ordering drag after Siri-only Apply was rejected"
        )
    }

    private static func runManagementTransitionChecks(
        accepted: PersistentBundlePolicyDocument,
        inventory: PolicyCandidateInventory,
        observationsCount: Int,
        blenny: String,
        alpha: String,
        beta: String
    ) throws {
        let model = ProductInterfaceModel()
        let stoppedEditor = try PolicyEditorViewModel(
            acceptedPolicy: accepted,
            candidateInventory: inventory,
            blennyBundleIdentifier: blenny
        )
        model.display(
            model: stoppedEditor,
            observationCount: observationsCount,
            recoveryAvailable: false
        )
        setRows(model, alphaFirst: true)
        model.initializeOrderingLayoutFromCurrentRows(force: true)

        let beforeFailedResume = try require(
            model.beginOrderingDragPayload(
                subjectID: .application(alpha), sourcePolicy: .visible
            ),
            "pre-failure Resume payload was unavailable"
        )
        model.setApplying(true)
        model.setApplying(false)
        let afterFailedResume = try require(
            model.beginOrderingDragPayload(
                subjectID: .application(alpha), sourcePolicy: .visible
            ),
            "failed Resume discarded the existing layout"
        )
        try require(
            afterFailedResume == beforeFailedResume,
            "failed Resume replaced a still-current drag authority"
        )

        let resumedPolicy = try PersistentBundlePolicyDocument(
            managementEnabled: true,
            policies: accepted.policies,
            bluetoothPolicy: accepted.bluetoothPolicy,
            systemItemPolicies: accepted.systemItemPolicies
        )
        let resumedEditor = try stoppedEditor.synchronizingAcceptedPolicy(
            resumedPolicy,
            preservingDraft: false
        )
        model.display(
            model: resumedEditor,
            observationCount: observationsCount,
            recoveryAvailable: false,
            preservingOrderingLayout: true
        )
        try requireRejected(
            model.requestOrderingConfigurationDrop(
                payload: beforeFailedResume,
                destination: .init(policy: .visible, position: .after(beta))
            ),
            "successful Resume accepted a pre-transition drag token"
        )
        let afterResume = try require(
            model.beginOrderingDragPayload(
                subjectID: .application(alpha), sourcePolicy: .visible
            ),
            "successful Resume did not restore dragging"
        )
        try require(
            afterResume.id != beforeFailedResume.id,
            "successful Resume reused its pre-transition drag identity"
        )
        try requireChanged(
            model.requestOrderingConfigurationDrop(
                payload: afterResume,
                destination: .init(policy: .visible, position: .after(beta))
            ),
            expectedPolicyChange: false,
            message: "first ordering drag after Resume was rejected"
        )

        let pendingLayout = try require(
            model.orderingLayoutDraft,
            "pending ordering draft disappeared before Stop"
        )
        let beforeStop = try require(
            model.beginOrderingDragPayload(
                subjectID: .application(alpha), sourcePolicy: .visible
            ),
            "pre-Stop payload was unavailable"
        )
        let stoppedPolicy = try PersistentBundlePolicyDocument(
            managementEnabled: false,
            policies: resumedPolicy.policies,
            bluetoothPolicy: resumedPolicy.bluetoothPolicy,
            systemItemPolicies: resumedPolicy.systemItemPolicies
        )
        let stoppedAgain = try require(model.model, "resumed editor model was unavailable")
            .synchronizingAcceptedPolicy(stoppedPolicy, preservingDraft: true)
        model.display(
            model: stoppedAgain,
            observationCount: observationsCount,
            recoveryAvailable: false,
            preservingOrderingLayout: true
        )
        try require(
            model.orderingLayoutDraft?.visible == pendingLayout.visible
                && model.orderingLayoutDraft?.revealable == pendingLayout.revealable
                && model.orderingLayoutDraft?.hidden == pendingLayout.hidden
                && model.orderingLayoutDraft?.hasChanges == pendingLayout.hasChanges,
            "Stop did not preserve the local ordering draft and discard baseline"
        )
        try requireRejected(
            model.requestOrderingConfigurationDrop(
                payload: beforeStop,
                destination: .init(policy: .visible, position: .before(beta))
            ),
            "successful Stop accepted a pre-transition drag token"
        )
        let afterStop = try require(
            model.beginOrderingDragPayload(
                subjectID: .application(alpha), sourcePolicy: .visible
            ),
            "successful Stop did not restore dragging"
        )
        try require(
            afterStop.id != beforeStop.id,
            "successful Stop reused its pre-transition drag identity"
        )

        model.setApplying(true)
        model.setApplying(false)
        let afterFailedStop = try require(
            model.beginOrderingDragPayload(
                subjectID: .application(alpha), sourcePolicy: .visible
            ),
            "failed Stop discarded the restored layout"
        )
        try require(
            afterFailedStop == afterStop,
            "failed Stop replaced a still-current drag authority"
        )

        // A build upgrade or interrupted older transition can leave the
        // captured rows available after its layout was cleared. Resume/Stop
        // must reconstruct a fresh drag authority from those rows without a
        // second ordering read.
        model.display(
            model: stoppedAgain,
            observationCount: observationsCount,
            recoveryAvailable: false
        )
        try require(
            model.orderingLayoutDraft == nil,
            "legacy missing-layout setup unexpectedly retained a layout"
        )
        model.display(
            model: resumedEditor,
            observationCount: observationsCount,
            recoveryAvailable: false,
            preservingOrderingLayout: true
        )
        let rebuiltAfterMissingLayout = try require(
            model.beginOrderingDragPayload(
                subjectID: .application(alpha), sourcePolicy: .visible
            ),
            "Resume did not rebuild dragging from reliable captured rows"
        )
        try requireChanged(
            model.requestOrderingConfigurationDrop(
                payload: rebuiltAfterMissingLayout,
                destination: .init(policy: .visible, position: .after(beta))
            ),
            expectedPolicyChange: false,
            message: "first ordering drag after missing-layout recovery was rejected"
        )
    }

    private static func setRows(
        _ model: ProductInterfaceModel,
        alphaFirst: Bool
    ) {
        let positions: [(String, Double)] = alphaFirst
            ? [("com.example.OrderingAlpha", 900), ("com.example.OrderingBeta", 700)]
            : [("com.example.OrderingBeta", 900), ("com.example.OrderingAlpha", 700)]
        model.orderingPresentation.rows = positions.map { identifier, position in
            DebugOrderingRow(
                bundleIdentifier: identifier, name: identifier,
                systemKey: "status:\(identifier)::item",
                currentPositionLabel: String(position), isEligible: true,
                configuredPosition: position, availability: .ready
            )
        } + [
            DebugOrderingRow(
                bundleIdentifier: "com.example.OrderingGamma",
                name: "com.example.OrderingGamma",
                systemKey: "status:com.example.OrderingGamma::item",
                currentPositionLabel: "500", isEligible: true,
                configuredPosition: 500, availability: .ready
            ),
            DebugOrderingRow(
                subjectID: .systemItem(.siri),
                name: ExactSystemOrderingItem.siri.displayName,
                systemKey: ExactSystemOrderingItem.siri.configurationKey,
                currentPositionLabel: "300",
                reason: "Sorting is not supported in this version.",
                isEligible: false,
                configuredPosition: 300,
                availability: .blocked,
                policy: .visible
            ),
        ]
        model.orderingPresentation.hasObservation = true
    }

    private static func require<T>(
        _ value: T?, _ message: String
    ) throws -> T {
        guard let value else { throw CheckFailure(message: message) }
        return value
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        guard condition() else { throw CheckFailure(message: message) }
    }

    private static func requireRejected(
        _ outcome: OrderingBoardConfigurationMutationOutcome,
        _ message: String
    ) throws {
        guard case .rejected = outcome else { throw CheckFailure(message: message) }
    }

    private static func requireChanged(
        _ outcome: OrderingBoardConfigurationMutationOutcome,
        expectedPolicyChange: Bool,
        message: String
    ) throws {
        guard case let .changed(policyChanged) = outcome,
              policyChanged == expectedPolicyChange else {
            throw CheckFailure(message: message)
        }
    }

    private static func requireUnchanged(
        _ outcome: OrderingBoardConfigurationMutationOutcome,
        _ message: String
    ) throws {
        guard case .unchanged = outcome else { throw CheckFailure(message: message) }
    }
}
#endif
