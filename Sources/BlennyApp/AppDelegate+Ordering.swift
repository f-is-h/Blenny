import AppKit
import BlennyCore
import CryptoKit
import Foundation

#if BLENNY_PRODUCT || DEBUG
extension AppDelegate {
    func orderingRuntimeContext() -> MacOS27MenuBarOrderingContext {
        let policy = editorModel?.acceptedPolicy
        let allowed = Set(NSWorkspace.shared.runningApplications.compactMap { app -> String? in
            guard let bundle = app.bundleIdentifier, let policy else { return nil }
            let assigned = policy.policies.first {
                BundlePolicyIdentity.canonicalKey(for: $0.bundleIdentifier)
                    == BundlePolicyIdentity.canonicalKey(for: bundle)
            }?.policy ?? .visible
            return OrderingPolicyScope.allows(intent: assigned, managementEnabled: policy.managementEnabled)
                ? bundle : nil
        })
        return MacOS27MenuBarOrderingContext(
            policyFingerprint: policy?.policyFingerprint ?? "policy-unavailable",
            orderingAllowedBundleIdentifiers: allowed,
            lifecycleGeneration: Int(truncatingIfNeeded: lifecycleGeneration)
        )
    }

    func configureOrderingInterface() {
        let presentation = editorWindowController.orderingPresentation
        presentation.onRefresh = { [weak self] in self?.refresh() }
        presentation.onPreview = { [weak self] bundles in self?.previewOrdering(bundles) }
        presentation.onReorder = { [weak self] bundles in self?.previewBoardOrdering(bundles) }
        presentation.onDraftChanged = { [weak self] model in self?.draftDidChange(model) }
        presentation.onPreviewConfiguration = { [weak self] request in
            self?.previewBoardConfiguration(request)
        }
        presentation.onChooseLayoutFile = { [weak self] in
            self?.requestMenuBarLayoutAccess()
        }
        presentation.onApply = { [weak self] fingerprint in self?.applyOrdering(fingerprint) }
        presentation.onRestore = { [weak self] in self?.restoreOrdering() }
        presentation.onDiscard = { [weak self] in
            guard let self else { return }
            if preparedBoardRequest != nil || editorWindowController.hasOrderingLayoutChanges,
               let discarded = editorWindowController.discardConfigurationDraft() {
                draftDidChange(discarded)
            }
            discardOrderingPreview()
        }
        presentation.message = "Reading the current menu-bar order with the application inventory…"
        Task { [weak self] in await self?.updateOrderingRecoveryPresentation() }
    }

    func discardOrderingPreview() {
        preparedOrderingPlan = nil
        preparedBoardPolicy = nil
        preparedBoardRequest = nil
        preparedBoardFingerprint = nil
        preparedUnsortedNames = []
        preparedUndoRebaseToken = nil
        let presentation = editorWindowController.orderingPresentation
        presentation.preview = nil
        presentation.requiresUndoReplacement = false
        presentation.canApply = false
    }

    func restoreSavedMenuBarLayoutAccess() {
        do {
            if try menuBarLayoutAccess.restoreSavedAccess() {
                sessionDiagnostic("layout-access restored exact-file bookmark")
            }
        } catch {
            sessionDiagnostic("layout-access restore-failure \(error.localizedDescription)")
        }
    }

    func requestMenuBarLayoutAccess() {
        let panel = NSOpenPanel()
        panel.title = "Choose the Menu Bar Layout File"
        panel.message = "Select the menu bar layout file so Blenny can apply and undo the order you choose."
        panel.prompt = "Grant Access"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.directoryURL = menuBarLayoutAccess.expectedFileURL.deletingLastPathComponent()
        panel.nameFieldStringValue = menuBarLayoutAccess.expectedFileURL.lastPathComponent
        panel.begin { [weak self] response in
            guard let self, response == .OK, let selectedURL = panel.url else { return }
            do {
                try menuBarLayoutAccess.grant(selectedURL: selectedURL)
                let presentation = editorWindowController.orderingPresentation
                presentation.needsDataAccess = false
                presentation.isError = false
                presentation.technicalDetail = nil
                presentation.message = "Access granted. Reading the current menu bar order…"
                Task { [weak self] in await self?.readOrderingForBoard() }
            } catch {
                let presentation = editorWindowController.orderingPresentation
                presentation.needsDataAccess = true
                presentation.isError = true
                presentation.message = "Choose the menu bar layout file to enable sorting and Undo."
                presentation.technicalDetail = error.localizedDescription
            }
        }
    }

    func orderingCoordinator(forRecovery: Bool = false) async throws -> CoordinatedPolicyWriter {
        try await policyCoordinator(forRecovery: forRecovery)
    }

    func beginOrderingInteraction(message: String) -> Bool {
        guard editorModel != nil,
              beginManagementInteraction() else {
            editorWindowController.orderingPresentation.message =
                "Finish the current operation before reviewing the layout."
            return false
        }
        ordinaryReveal.suspend()
        let presentation = editorWindowController.orderingPresentation
        presentation.isBusy = true
        presentation.canRefresh = false
        presentation.canApply = false
        presentation.isError = false
        presentation.technicalDetail = nil
        presentation.message = message
        editorWindowController.setStatus(message, isError: false)
        return true
    }

    func finishOrderingInteraction() {
        let presentation = editorWindowController.orderingPresentation
        presentation.isBusy = false
        presentation.canRefresh = !interactionGate.isTerminating
        presentation.canApply = (preparedOrderingPlan != nil || preparedBoardPolicy != nil) && !orderingRecoveryKnown
            && !isReadOnlyValidation && !interactionGate.isTerminating
        finishManagementInteraction()
    }

    func refreshOrdering() {
        guard beginOrderingInteraction(message: "Reading current ordering identities…") else { return }
        discardOrderingPreview()
        managementInteractionTask = Task { [weak self] in
            guard let self else { return }
            defer { finishOrderingInteraction() }
            await readOrderingForBoard()
        }
    }

    #if DEBUG
    func captureBoundaryEvidence() {
        guard !boundaryCaptureInProgress, !isReadOnlyValidation,
              !interactionGate.isBusy, !interactionGate.isTerminating, !isRefreshing,
              connectionInvalidationTask == nil, let model = editorModel,
              AccessibilityAuthorization.isTrusted else {
            editorWindowController.setStatus("Snapshot unavailable. Finish the current operation and check Accessibility.", isError: true)
            return
        }
        boundaryCaptureInProgress = true
        statusItemController.debugSetBoundaryCaptureBusy(true)
        let policy = model.acceptedPolicy
        let generation = lifecycleGeneration
        let ownBefore = statusItemController.debugOwnControls
        let startedAt = Date()
        let descriptors = runningApplicationDescriptors()
        boundaryCaptureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                boundaryCaptureInProgress = false
                boundaryCaptureTask = nil
                statusItemController.debugSetBoundaryCaptureBusy(false)
            }
            let stateBefore = String(describing: await managementLoop.state)
            do {
                // This does not enter the management gate, suspend a reveal,
                // refresh the Board, create a coordinator, or touch recovery.
                let report = await inventory.capture(applications: descriptors, accessibilityTrusted: true)
                let snapshot = try await orderingBackend.capture()
                guard !Task.isCancelled, !interactionGate.isTerminating else { return }
                let ownAfter = statusItemController.debugOwnControls
                let stateAfter = String(describing: await managementLoop.state)
                let unchanged = generation == lifecycleGeneration
                    && policy == editorModel?.acceptedPolicy
                    && ownBefore == ownAfter && stateBefore == stateAfter
                    && !interactionGate.isBusy && !isRefreshing
                guard let executable = Bundle.main.executableURL else {
                    throw OrderingError.invalidSnapshot("missing executable identity")
                }
                let digest = SHA256.hash(data: try Data(contentsOf: executable))
                    .map { String(format: "%02x", $0) }.joined()
                let evidence = DebugBoundaryEvidence(
                    id: UUID(), startedAt: startedAt, finishedAt: Date(),
                    appVersion: BlennyApplicationVersion.diagnosticIdentity,
                    appPath: Bundle.main.bundleURL.path, executableSHA256: digest,
                    processIdentifier: ProcessInfo.processInfo.processIdentifier,
                    stateBefore: stateBefore, stateAfter: stateAfter, contextUnchanged: unchanged,
                    ownControlsBefore: ownBefore, ownControlsAfter: ownAfter,
                    ownKeyEvidence: OwnControlKeyEvidence(
                        tableKeys: Set(try snapshot.table().keys),
                        bundleIdentifier: Bundle.main.bundleIdentifier ?? "unknown",
                        autosaveNames: ownAfter.compactMap(\.autosaveName)),
                    clickCheck: statusItemController.debugClickCheck,
                    acceptedPolicy: policy, inventory: report, ordering: snapshot,
                    singleItemCandidates: try OrderingIdentityResolver.resolve(snapshot: snapshot),
                    notes: [
                        "Read-only evidence, not a placement plan or restoration receipt.",
                        "Own frames use AppKit screen coordinates; AX inventory frames use Accessibility coordinates. Do not compare Y without conversion.",
                        "Inventory and preference captures are sequential, not an atomic screen snapshot.",
                        "Stored keys and configuration eligibility do not establish a live per-item identity; retain unresolved and historical keys separately.",
                        "Own key evidence matches canonical bundle keys to instantiated autosave names; alternative namespaces still require verification.",
                        "localContentVisible is AppKit content state, not proof of physical screen visibility.",
                        "No complete physical partition or write eligibility is claimed by this export.",
                        unchanged ? "Context unchanged at sampled endpoints." : "Context changed during capture; do not use for boundary conclusions."
                    ])
                let directory = boundaryEvidenceDirectory
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700])
                guard directory.resolvingSymlinksInPath().pathComponents.contains("LocalData") else {
                    throw OrderingError.invalidSnapshot("evidence destination must remain inside LocalData")
                }
                let url = directory.appendingPathComponent("boundary-\(evidence.id.uuidString).json")
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(evidence)
                guard data.count <= 16 * 1_024 * 1_024 else { throw OrderingError.propertyListLimitExceeded }
                try data.write(to: url, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
                editorWindowController.setStatus(unchanged
                    ? "Boundary snapshot saved. File path copied."
                    : "Snapshot saved, but state changed during capture. File path copied.", isError: !unchanged)
            } catch {
                editorWindowController.setStatus("Could not save boundary snapshot: \(error.localizedDescription)", isError: true)
            }
        }
    }

    #endif
    func positionRevealArrow(restoring: Bool) {
        guard !boundaryCaptureInProgress, !isReadOnlyValidation, !isRefreshing,
              !interactionGate.isTerminating, AccessibilityAuthorization.isTrusted,
              let model = editorModel,
              (restoring || !editorWindowController.hasDraftChanges),
              beginOrderingInteraction(message: restoring ? "Restoring control positions…" : "Preparing control positions…") else { return }
        let policy = model.acceptedPolicy
        managementInteractionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { finishOrderingInteraction() }
            do {
                let coordinator = try await orderingCoordinator(forRecovery: restoring)
                if restoring {
                    let result = try await coordinator.restoreFallbackPosition()
                    editorWindowController.setStatus(result == nil ? "No control placement to undo." : "Previous control positions restored.", isError: false)
                    return
                }
                let previousReceipt = try await fallbackRecoveryStore.load()
                guard previousReceipt?.isPendingRestoration != true else {
                    throw OrderingTransactionError.recoveryRequired
                }
                let snapshot = try await orderingBackend.capture()
                let identity = try await orderingBackend.fallbackIdentity()
                let candidate = try FallbackBoundaryCandidate.make(snapshot: snapshot, policy: policy, includeFish: true)
                let alert = NSAlert()
                alert.messageText = "Position Blenny’s controls?"
                alert.informativeText = "Place the double arrow and fish between Revealable and Visible items, with the arrow on the left. Other apps’ saved positions stay unchanged.\n\nThis placement stays after Stop or Quit and follows changes you apply in Organize. Undo Control Placement restores the previous positions and turns off automatic adjustment."
                if let previousReceipt, !previousReceipt.delta.canBeReplaced(by: candidate.delta) {
                    alert.informativeText += "\n\nThe saved control positions have changed. This replaces the old control Undo record with the current positions. The old record is archived; Undo Control Placement will return to the positions before this operation."
                }
                alert.addButton(withTitle: "Position Controls")
                alert.addButton(withTitle: "Cancel")
                guard alert.runModal() == .alertFirstButtonReturn else { return }
                _ = try await coordinator.applyFallbackPosition(candidate.delta,
                    baseline: snapshot, identity: identity, persistsAfterQuit: true,
                    reviewedPreviousReceipt: previousReceipt)
                editorWindowController.setStatus("Control positions saved.", isError: false)
            } catch FallbackPositionDelta.Failure.unchangedPosition {
                editorWindowController.setStatus("Blenny’s controls are already positioned.", isError: false)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Couldn’t update Blenny’s controls"
                alert.informativeText = error.localizedDescription
                    + "\n\nIf restoration is needed, choose Undo Control Placement."
                alert.addButton(withTitle: "OK")
                alert.runModal()
                editorWindowController.setStatus("Control positions could not be updated.", isError: true)
            }
        }
    }

    func updateAcceptedControlBoundary() async -> String? {
        guard let policy = editorModel?.acceptedPolicy, !interactionGate.isTerminating else { return nil }
        do {
            guard try await fallbackRecoveryStore.load() != nil else { return nil }
            // Persistent fallback placement is dormant while the native
            // overflow control is usable (or its exact AppKit identity is not
            // currently available). An unrelated Apply or Undo must leave that
            // older placement unchanged instead of reporting the completed
            // primary operation as a failure.
            guard statusItemController.fallbackNativeIdentity != nil else { return nil }
            let coordinator = try await orderingCoordinator()
            _ = try await coordinator.updateAcceptedControlBoundary(policy: policy)
            return nil
        } catch {
            return "Blenny’s controls could not be positioned: \(error.localizedDescription) Use Position Blenny Controls to review the placement."
        }
    }

    func readOrderingForBoard() async {
        discardOrderingPreview()
        do {
            let snapshot = try await orderingBackend.capture()
            guard !interactionGate.isTerminating else { return }
            guard presentOrderingCandidates(snapshot) else {
                await updateOrderingRecoveryPresentation()
                return
            }
            editorWindowController.orderingPresentation.finishSuccessfulRead()
        } catch {
            lastOrderingSnapshot = nil
            editorWindowController.orderingPresentation.hasObservation = false
            presentOrderingError(error)
        }
        await updateOrderingRecoveryPresentation()
    }

    func presentBoardGeometry(report: DiagnosticReport, candidates: [PolicyCandidate]) {
        // Public AX placement can still be displayed when preferences
        // are unavailable. This observation never grants ordering eligibility.
        let records = Dictionary(grouping: report.items.filter {
            $0.source == .applicationExtrasMenuBar && $0.classification == .manageableCandidate
                && $0.role == "AXMenuBarItem" && $0.subrole == "AXMenuExtra"
        }, by: { $0.ownerBundleIdentifier ?? "" })
        let singleFrames = records.compactMapValues { owned -> RectSnapshot? in
            owned.count == 1 ? owned.first?.frame : nil
        }
        let ambiguousOwners = OrderingObservedGeometry.ambiguousOwners(frames: singleFrames)
        let icons = WorkspacePolicyIconResolver()
        editorWindowController.orderingPresentation.rows = candidates.map { candidate in
            let icon = icons.applicationIcon(bundleIdentifier: candidate.bundleIdentifier)
            let owned = records[candidate.bundleIdentifier] ?? []
            let frame = owned.count == 1 && candidate.menuBarItemCount == 1
                && NSScreen.screens.count == 1
                && !ambiguousOwners.contains(candidate.bundleIdentifier) ? owned.first?.frame : nil
            let x = frame.flatMap { frame -> Double? in
                guard frame.x.isFinite, frame.y.isFinite, frame.width.isFinite,
                      frame.height.isFinite, frame.width > 0, frame.height > 0,
                      frame.x >= 0, frame.x + frame.width <= (NSScreen.screens.first?.frame.width ?? 0)
                else { return nil }
                return frame.x
            }
            return OrderingRow(
                bundleIdentifier: candidate.bundleIdentifier, name: icon.displayName, icon: icon.image,
                reason: ambiguousOwners.contains(candidate.bundleIdentifier)
                    ? "The current menu-bar observation does not expose a separate position for this application."
                    : "Ordering identity and preferences are not verified.",
                isEligible: false, observedX: x
            )
        }
        editorWindowController.orderingPresentation.hasObservation = false
    }

    func previewBoardConfiguration(_ request: OrderingConfigurationRequest, applyWhenReady: Bool = false) {
        guard !orderingRecoveryKnown,
              let model = editorModel,
              request.sourceCandidateGeneration == editorWindowController.candidateGeneration,
              beginOrderingInteraction(message: "Checking changes…") else { return }
        discardOrderingPreview()
        let generation = lifecycleGeneration
        managementInteractionTask = Task { [weak self] in
            guard let self else { return }
            var handoffToApply = false
            defer { if !handoffToApply { finishOrderingInteraction() } }
            do {
                let current = try await orderingBackend.capture()
                guard generation == lifecycleGeneration,
                      !interactionGate.isTerminating,
                      request == editorWindowController.currentOrderingConfigurationRequest,
                      model.acceptedPolicy.policyFingerprint == current.policyFingerprint,
                      Int(truncatingIfNeeded: generation) == current.lifecycleGeneration else {
                    throw OrderingError.staleSnapshot("the area draft or management context changed while preparing the review")
                }
                // This creates a new review from current configuration. The
                // Board supplies desired owner order, not stale numeric inputs.
                // Execution still checks the resulting plan against a fresh
                // snapshot before the serial writer can change anything.
                let candidates = try OrderingConfigurationSubjectIdentityResolver.resolve(snapshot: current)
                let bySubject = Dictionary(uniqueKeysWithValues: candidates.map { ($0.subjectID, $0) })
                let allEligible = request.orderedSubjects.filter { subject in
                    guard bySubject[subject]?.eligible == true else { return false }
                    if case let .systemItem(item) = subject {
                        return item.isOrderingOffered
                    }
                    return true
                }
                let allEligibleSet = Set(allEligible)
                let unavailable = request.unavailableOrderChanges(
                    eligibleSubjects: allEligibleSet, blenny: model.blennyBundleIdentifier
                )
                guard unavailable.isEmpty else {
                    let names = unavailable.map { bySubject[$0]?.displayName ?? $0.boardID }
                    throw OrderingError.unavailableOrderChanges(names)
                }
                let required = Set(request.subjectsRequiringConfiguration)
                let selected = allEligible.filter { required.contains($0) }
                let selectedSet = Set(selected)
                let omitted = request.orderedSubjects.filter { !selectedSet.contains($0) }
                let plan: OrderingPlan? = try OrderingPlan.makeConfigurationOrdering(
                    snapshot: current, orderedSubjects: selected
                )
                var policy: PreparedPolicyEdit?
                if model.hasDraftChanges {
                    let core = try await makeCore(scope: model.validationScope, permitsReviewedActivation: true)
                    let policyPreview = try await core.preview(
                        draft: model.draft, candidates: model.candidateInventory,
                        observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                        candidateGeneration: editorWindowController.candidateGeneration,
                        runtimeContractFingerprint: runtimeContractFingerprint
                    )
                    guard let prepared = policyPreview.1 else {
                        throw PolicyInterfaceWriteError.applyPreflightUnavailable(policyPreview.0.validationFailureSummary)
                    }
                    policy = prepared
                }
                guard editorModel?.draft == model.draft,
                      request == editorWindowController.currentOrderingConfigurationRequest,
                      generation == lifecycleGeneration else {
                    throw PolicyEditingCoreError.staleReviewedPlan
                }
                guard plan != nil || policy != nil else {
                    throw OrderingError.invalidSelection
                }
                let undoRebaseReview: OrderingUndoLedgerRebaseReview?
                if plan != nil, let receipt = try await orderingRecoveryStore.load() {
                    undoRebaseReview = try receipt.undoLedgerRebaseReview(in: current)
                } else {
                    undoRebaseReview = nil
                }
                let fingerprint = try OrderingValue.dictionary([
                    "ordering": .string(plan?.fingerprint ?? "no-addressable-ordering-keys"),
                    "policy": .string(policy?.newPolicy.policyFingerprint ?? model.acceptedPolicy.policyFingerprint),
                    "layout": .string(request.sourceLayoutGeneration.uuidString),
                    "undoRebase": .string(undoRebaseReview?.token ?? "retain-existing-undo")
                ]).canonicalFingerprint
                preparedOrderingPlan = plan
                preparedBoardPolicy = policy
                preparedBoardRequest = request
                preparedBoardFingerprint = fingerprint
                preparedUnsortedNames = omitted.filter {
                    request.originalPolicies[$0] != request.draftSubjectPolicies[$0]
                }.map { bySubject[$0]?.displayName ?? $0.boardID }
                preparedUndoRebaseToken = undoRebaseReview?.token
                let presentation = editorWindowController.orderingPresentation
                if let undoRebaseReview {
                    // Replacing stale Undo history still requires explicit consent.
                    presentation.requiresUndoReplacement = true
                    presentation.preview = OrderingPreview(
                        fingerprint: fingerprint, title: "Replace previous Undo?",
                        detail: undoRebaseReview.userDescription, visibleScope: "",
                        targetBundleIdentifiers: [], beforeOrder: [], afterOrder: []
                    )
                    presentation.message = "The menu bar changed outside Blenny. Applying will replace the previous Undo history."
                    presentation.technicalDetail = undoRebaseReview.userDescription
                } else if applyWhenReady {
                    // Synchronous handoff: no user event can change the draft between gates.
                    handoffToApply = true
                    applyBoardConfiguration(fingerprint, continuingInteraction: true)
                }
            } catch { presentOrderingError(error) }
        }
    }

    func previewBoardOrdering(_ orderedBundles: [String]) {
        guard !orderingRecoveryKnown, let previous = lastOrderingSnapshot,
              beginOrderingInteraction(message: "Reading and reviewing the requested menu-bar order…") else { return }
        discardOrderingPreview()
        let generation = lifecycleGeneration
        managementInteractionTask = Task { [weak self] in
            guard let self else { return }
            defer { finishOrderingInteraction() }
            do {
                guard try await orderingRecoveryStore.load() == nil else {
                    throw OrderingTransactionError.recoveryRequired
                }
                if case .ordinaryRevealSession = await managementLoop.state {
                    throw OrderingError.staleSnapshot("close the ordinary reveal session before ordering")
                }
                let current = try await orderingBackend.capture()
                // A drag refers to the board that was actually displayed. A new
                // snapshot may refresh values, but must not reinterpret the
                // gesture after another app, intent or selected order changed.
                let selected = Set(orderedBundles)
                func observedOrder(_ snapshot: OrderingSnapshot) -> [String] {
                    snapshot.observationsByPID.values.filter {
                        $0.process.bundleIdentifier.map(selected.contains) == true
                            && $0.axComplete && $0.itemFrames.count == 1
                    }.sorted { $0.itemFrames[0].x < $1.itemFrames[0].x }
                        .compactMap(\.process.bundleIdentifier)
                }
                guard previous.beforeProcesses == previous.afterProcesses,
                      current.beforeProcesses == current.afterProcesses,
                      previous.afterProcesses.sorted(by: { $0.pid < $1.pid })
                        == current.afterProcesses.sorted(by: { $0.pid < $1.pid }),
                      previous.policyFingerprint == current.policyFingerprint,
                      previous.displaySignature == current.displaySignature,
                      previous.lifecycleGeneration == current.lifecycleGeneration,
                      observedOrder(previous).count == selected.count,
                      observedOrder(previous) == observedOrder(current) else {
                    presentOrderingCandidates(current)
                    throw OrderingError.staleSnapshot("the displayed order or application inventory changed; review the refreshed board")
                }
                let plan = try OrderingPlan.makeReordering(
                    snapshot: current, orderedBundleIdentifiers: orderedBundles
                )
                guard generation == lifecycleGeneration, !interactionGate.isTerminating else {
                    throw OrderingTransactionError.contextInvalidated
                }
                preparedOrderingPlan = plan
                presentOrderingCandidates(current)
                let names = Dictionary(uniqueKeysWithValues: plan.targets.map {
                    ($0.bundleIdentifier, $0.displayName)
                })
                editorWindowController.orderingPresentation.preview = OrderingPreview(
                    id: plan.id, fingerprint: plan.fingerprint,
                    title: "Review menu-bar order",
                    detail: "Existing preferred slots are reassigned once. Other applications and area assignments remain unchanged.",
                    visibleScope: "\(plan.targets.count) application owners · one display",
                    targetBundleIdentifiers: orderedBundles,
                    beforeOrder: observedOrder(current).compactMap { names[$0] },
                    afterOrder: orderedBundles.compactMap { names[$0] }
                )
                editorWindowController.orderingPresentation.message =
                    "Apply Order changes the real menu bar. Restore Order returns this trial to its original positions."
            } catch { presentOrderingError(error) }
        }
    }

    func previewOrdering(_ bundles: [String]) {
        guard !orderingRecoveryKnown,
              beginOrderingInteraction(message: "Preparing the exact exchange and inverse…") else { return }
        discardOrderingPreview()
        let generation = lifecycleGeneration
        managementInteractionTask = Task { [weak self] in
            guard let self else { return }
            defer { finishOrderingInteraction() }
            do {
                if case .ordinaryRevealSession = await managementLoop.state {
                    throw OrderingError.staleSnapshot("close the ordinary reveal session before ordering")
                }
                guard try await orderingRecoveryStore.load() == nil else {
                    throw OrderingTransactionError.recoveryRequired
                }
                let snapshot = try await orderingBackend.capture()
                let plan = try OrderingPlan.make(snapshot: snapshot, bundleIdentifiers: bundles)
                guard generation == lifecycleGeneration, !interactionGate.isTerminating else {
                    throw OrderingTransactionError.contextInvalidated
                }
                preparedOrderingPlan = plan
                presentOrderingCandidates(snapshot)
                let before = plan.targets.sorted { $0.frame.x < $1.frame.x }.map(\.displayName)
                editorWindowController.orderingPresentation.preview = OrderingPreview(
                    id: plan.id, fingerprint: plan.fingerprint,
                    title: "Exchange the selected positions",
                    detail: "Other icons may remain between these applications. Preferred positions do not fix absolute screen coordinates.",
                    visibleScope: "Two observable application bundles · one display",
                    targetBundleIdentifiers: plan.targets.map(\.bundleIdentifier),
                    beforeOrder: before, afterOrder: Array(before.reversed()),
                    technicalDetails: plan.targets.map {
                        OrderingTechnicalDetail(key: $0.key,
                            value: "\(orderingPositionLabel($0.before)) → \(orderingPositionLabel($0.after)); Restore returns \(orderingPositionLabel($0.before))")
                    } + [OrderingTechnicalDetail(key: "Preview fingerprint", value: plan.fingerprint)]
                )
                editorWindowController.orderingPresentation.message =
                    "Review the two applications. Exchange Positions performs one real menu-bar write and one verification."
            } catch { presentOrderingError(error) }
        }
    }

    func applyOrdering(_ fingerprint: String) {
        if preparedBoardRequest != nil {
            applyBoardConfiguration(fingerprint)
            return
        }
        guard !isReadOnlyValidation, !orderingRecoveryKnown,
              let plan = preparedOrderingPlan, plan.fingerprint == fingerprint,
              beginOrderingInteraction(message: "Checking and applying the real menu-bar order…") else { return }
        discardOrderingPreview()
        activeOrderingPlan = plan
        managementInteractionTask = Task { [weak self] in
            guard let self else { return }
            defer { finishOrderingInteraction() }
            do {
                if case .ordinaryRevealSession = await managementLoop.state {
                    throw OrderingError.staleSnapshot("close the ordinary reveal session before ordering")
                }
                let writer = try await orderingCoordinator()
                let observed = try await writer.applyOrdering(plan, confirmedFingerprint: fingerprint)
                presentOrderingCandidates(observed)
                editorWindowController.orderingPresentation.message =
                    "The real relative order was verified. Restore Order returns the original preferred positions; Stop or Quit also restores this session."
            } catch { presentOrderingError(error) }
            await updateOrderingRecoveryPresentation()
            if !orderingRecoveryKnown { activeOrderingPlan = nil }
        }
    }

    func applyBoardConfiguration(_ fingerprint: String, continuingInteraction: Bool = false) {
        guard !isReadOnlyValidation, !orderingRecoveryKnown,
              let request = preparedBoardRequest,
              let model = editorModel,
              preparedBoardFingerprint == fingerprint,
              request == editorWindowController.currentOrderingConfigurationRequest else {
            if continuingInteraction { finishOrderingInteraction() }
            return
        }
        guard continuingInteraction || beginOrderingInteraction(message: "Applying changes…") else { return }
        let plan = preparedOrderingPlan
        let policy = preparedBoardPolicy
        let undoRebaseToken = preparedUndoRebaseToken
        let unsortedNames = preparedUnsortedNames
        let generation = lifecycleGeneration
        discardOrderingPreview()
        managementInteractionTask = Task { [weak self] in
            guard let self else { return }
            defer { finishOrderingInteraction() }
            var configurationCommitted = false
            do {
                guard let plan else { throw OrderingError.invalidSelection }
                if case .ordinaryRevealSession = await managementLoop.state,
                   let baseline = activeBaselinePlan {
                    await endOrdinaryReveal(
                        baseline: baseline,
                        persistedManagementEnabled: model.acceptedPolicy.managementEnabled
                    )
                }
                if let policy {
                    let observation = try await captureApplyPreflight()
                    let core = try await makeCore(scope: model.validationScope, permitsReviewedActivation: true)
                    let refreshed = try await core.preview(
                        draft: model.draft, candidates: observation.candidates,
                        observedRunningBundleIdentifiers: observation.runningBundleIdentifiers,
                        candidateGeneration: editorWindowController.candidateGeneration,
                        runtimeContractFingerprint: runtimeContractFingerprint
                    )
                    guard let checked = refreshed.1,
                          checked.newPolicy == policy.newPolicy,
                          checked.oldPolicy == policy.oldPolicy,
                          checked.reviewBinding == policy.reviewBinding else {
                        throw PolicyEditingCoreError.staleReviewedPlan
                    }
                }
                guard generation == lifecycleGeneration,
                      !interactionGate.isTerminating,
                      editorModel?.draft == model.draft,
                      request == editorWindowController.currentOrderingConfigurationRequest else {
                    throw PolicyEditingCoreError.staleReviewedPlan
                }
                let writer = try await orderingCoordinator()
                let result = try await writer.applyConfigurationOrdering(
                    plan, confirmedFingerprint: plan.fingerprint,
                    policyChange: policy, policyStore: interfaceStore,
                    confirmedUndoRebaseToken: undoRebaseToken
                )
                configurationCommitted = true
                if let policy {
                    activeBaselinePlan = policy.report.newBaselinePlan
                    activeRevealPlan = policy.report.newRevealPlan
                    try await managementLoop.synchronizeCommittedPolicy(
                        policy.newPolicy, baseline: activeBaselinePlan
                    )
                    try await synchronizeInterfaceAfterCommit(policy.newPolicy, previousModel: model)
                }
                guard editorWindowController.installCommittedOrderingLayout(
                    from: request
                ) else {
                    throw OrderingError.staleSnapshot(
                        "the committed candidate scope changed; refresh the board"
                    )
                }
                guard generation == lifecycleGeneration, !interactionGate.isTerminating else {
                    throw ManagementLoopError.staleLifecycleGeneration
                }
                let displayedSnapshot = policy == nil ? result.snapshot : try await orderingBackend.capture()
                presentOrderingCandidates(displayedSnapshot)
                editorWindowController.initializeOrderingLayoutFromCurrentRows(force: true)
                let visual: String
                switch result.physicalVerificationStatus {
                case .verified:
                    visual = "Order verified."
                case .mismatch:
                    visual = "The menu bar does not yet match the saved order."
                case .unavailable:
                    visual = "Some on-screen positions could not be verified."
                }
                editorWindowController.orderingPresentation.message =
                    "Changes applied. \(visual)"
                    + (unsortedNames.isEmpty ? "" : " Visibility only: \(unsortedNames.joined(separator: ", ")).")
                if let failure = await updateAcceptedControlBoundary() {
                    editorWindowController.orderingPresentation.message =
                        (editorWindowController.orderingPresentation.message ?? "") + " \(failure)"
                    editorWindowController.orderingPresentation.isError = true
                }
            } catch {
                if configurationCommitted {
                    presentCommittedOrderingRefreshFailure(error)
                } else {
                    if let policy { await reconcileManagementAfterFailure(policy) }
                    presentOrderingError(error)
                }
            }
            await updateOrderingRecoveryPresentation()
        }
    }

    func restoreOrdering() {
        guard !isReadOnlyValidation,
              beginOrderingInteraction(message: "Checking the saved order…") else { return }
        discardOrderingPreview()
        managementInteractionTask = Task { [weak self] in
            guard let self else { return }
            var needsAutomaticRefresh = false
            defer {
                finishOrderingInteraction()
                // One read-only follow-up after releasing the interaction gate.
                // Refresh does not reapply the transaction or schedule retries.
                if needsAutomaticRefresh { refresh() }
            }
            var preferencesRestored = false
            do {
                let writer = try await orderingCoordinator(forRecovery: true)
                var inverse: PreparedPolicyEdit?
                let priorModel = editorModel
                let receipt = try await orderingRecoveryStore.load()
                if receipt?.hasPendingRevisionRollback != true,
                   let undo = receipt?.undoPolicy,
                   let model = priorModel {
                    let observation = try await captureApplyPreflight()
                    let core = try await makeCore(scope: model.validationScope, permitsReviewedActivation: true)
                    inverse = try await core.previewUndoKeepingManagementState(
                        targetPolicy: undo.before,
                        candidates: observation.candidates,
                        observedRunningBundleIdentifiers: observation.runningBundleIdentifiers,
                        candidateGeneration: editorWindowController.candidateGeneration,
                        runtimeContractFingerprint: runtimeContractFingerprint
                    ).1
                    let currentPolicy = try await interfaceStore?.load()
                    guard inverse != nil || currentPolicy == undo.before else {
                        throw PolicyEditingCoreError.staleReviewedPlan
                    }
                }
                let result = try await writer.restoreOrdering(policyStore: interfaceStore, policyUndo: inverse)
                guard result.preferencesRestored else {
                    throw OrderingTransactionError.restorationNotVerified
                }
                preferencesRestored = true
                if let inverse, let model = priorModel {
                    activeBaselinePlan = inverse.report.newBaselinePlan
                    activeRevealPlan = inverse.report.newRevealPlan
                    try await managementLoop.synchronizeCommittedPolicy(
                        inverse.newPolicy, baseline: activeBaselinePlan)
                    try await synchronizeInterfaceAfterCommit(inverse.newPolicy, previousModel: model)
                }
                editorWindowController.setStatus("Changes undone.", isError: false)
                activeOrderingPlan = nil
                guard presentOrderingCandidates(try await orderingBackend.capture()) else {
                    needsAutomaticRefresh = true
                    await updateOrderingRecoveryPresentation()
                    return
                }
                editorWindowController.orderingPresentation.requiresObservationRefresh = false
                editorWindowController.initializeOrderingLayoutFromCurrentRows(force: true)
                editorWindowController.orderingPresentation.message = "Changes undone."
                editorWindowController.orderingPresentation.technicalDetail = result.relativeOrderVerified
                    ? nil : "Saved settings were restored and verified. On-screen positions were not independently verified."
                if let failure = await updateAcceptedControlBoundary() {
                    editorWindowController.orderingPresentation.message =
                        (editorWindowController.orderingPresentation.message ?? "") + " \(failure)"
                    editorWindowController.orderingPresentation.isError = true
                }
            } catch {
                if preferencesRestored {
                    presentCommittedOrderingRefreshFailure(error, restored: true)
                    editorWindowController.orderingPresentation.message = "Changes undone. Updating the Board…"
                    needsAutomaticRefresh = true
                } else {
                    presentOrderingError(error)
                }
            }
            await updateOrderingRecoveryPresentation()
        }
    }

    func updateOrderingRecoveryPresentation() async {
        let presentation = editorWindowController.orderingPresentation
        do {
            let receipt = try await orderingRecoveryStore.load()
            orderingRecoveryKnown = receipt?.isPendingRestoration == true
            presentation.hasPendingRecovery = orderingRecoveryKnown
            presentation.hasRecovery = receipt?.isPendingRestoration == true
                || receipt?.hasConfigurationUndo == true
            if let receipt {
                if receipt.isPendingRestoration && (receipt.phase != .applied || activeOrderingPlan == nil) {
                    presentation.message = "An unfinished change needs recovery. Choose Recover Changes."
                }
                if receipt.isPendingRestoration { presentation.canApply = false }
            }
        } catch {
            orderingRecoveryKnown = true
            presentation.hasPendingRecovery = true
            presentation.hasRecovery = true
            presentOrderingError(error)
        }
    }

    @discardableResult
    func presentOrderingCandidates(_ snapshot: OrderingSnapshot) -> Bool {
        do {
            let knownBundles = Set(editorModel?.candidateInventory.candidates.map(\.bundleIdentifier) ?? [])
            let candidates = try OrderingConfigurationIdentityResolver.resolve(snapshot: snapshot).filter {
                !$0.keys.isEmpty || knownBundles.contains($0.bundleIdentifier)
                    || $0.process.map { snapshot.observationsByPID[$0.pid] != nil } == true
            }
            let icons = WorkspacePolicyIconResolver()
            let observedFrames = Dictionary(uniqueKeysWithValues: candidates.compactMap { candidate -> (String, RectSnapshot)? in
                guard let process = candidate.process,
                      let observation = snapshot.observationsByPID[process.pid],
                      observation.axComplete, observation.itemFrames.count == 1,
                      let frame = observation.itemFrames.first,
                      frame.width > 0, frame.height > 0,
                      frame.x >= snapshot.displayFrame.x,
                      frame.x + frame.width <= snapshot.displayFrame.x + snapshot.displayFrame.width else { return nil }
                return (candidate.bundleIdentifier, frame)
            })
            let ambiguousObservedOwners = OrderingObservedGeometry.ambiguousOwners(frames: observedFrames)
            lastOrderingSnapshot = snapshot
            editorWindowController.orderingPresentation.hasObservation = true
            editorWindowController.orderingPresentation.rows = candidates.map { candidate in
                let frame = ambiguousObservedOwners.contains(candidate.bundleIdentifier)
                    ? nil : observedFrames[candidate.bundleIdentifier]
                let values = candidate.keys.map(\.value)
                let position = values.compactMap { value -> Double? in
                    switch value {
                    case let .integer(number): Double(number)
                    case let .real(number): number
                    default: nil
                    }
                }.max()
                let excluded = candidate.reasons.contains(.selfExcluded)
                    || candidate.reasons.contains(.systemOwnerExcluded)
                return OrderingRow(
                    bundleIdentifier: candidate.bundleIdentifier, name: candidate.displayName,
                    icon: icons.applicationIcon(bundleIdentifier: candidate.bundleIdentifier).image,
                    systemKey: candidate.keys.isEmpty ? nil : candidate.keys.map(\.key).joined(separator: ", "),
                    currentPositionLabel: values.isEmpty ? nil : values.map(orderingPositionLabel).joined(separator: ", "),
                    reason: candidate.reasons.isEmpty ? nil : candidate.reasons.map(\.userDescription).joined(separator: "; "),
                    isEligible: candidate.eligible,
                    observedX: frame?.x,
                    configuredPosition: position,
                    availability: candidate.eligible ? .ready : (excluded ? .blocked : .needsMapping)
                )
            }
            let systemCandidates = try OrderingConfigurationSubjectIdentityResolver.resolve(snapshot: snapshot)
                .filter { if case .systemItem = $0.subjectID { true } else { false } }
            editorWindowController.orderingPresentation.rows += systemCandidates.map { candidate in
                guard case let .systemItem(item) = candidate.subjectID else { preconditionFailure() }
                let orderingOffered = item.isOrderingOffered
                let values = candidate.keys.map(\.value)
                let position = values.compactMap { value -> Double? in
                    switch value {
                    case let .integer(number): Double(number)
                    case let .real(number): number
                    default: nil
                    }
                }.first
                let icon = icons.systemIcon(observation: .init(
                    observationIdentifier: item.observationIdentifier,
                    ownerBundleIdentifier: item.hostBundleIdentifier,
                    displayName: item.displayName, observationCount: 0
                )).image
                return OrderingRow(
                    subjectID: candidate.subjectID, name: candidate.displayName, icon: icon,
                    systemKey: candidate.keys.isEmpty ? nil : item.configurationKey,
                    currentPositionLabel: values.first.map(orderingPositionLabel),
                    reason: orderingOffered
                        ? (candidate.reasons.isEmpty ? nil : candidate.reasons.map(\.userDescription).joined(separator: "; "))
                        : "Sorting is not supported in this version; Visible, Revealable, and Hidden remain available.",
                    isEligible: orderingOffered && candidate.eligible,
                    observedX: nil, configuredPosition: position,
                    availability: orderingOffered
                        ? (candidate.eligible ? .ready : .needsMapping)
                        : .blocked,
                    policy: editorModel?.effectiveSystemItemPolicy(for: item.observationIdentifier)
                        ?? (item == .bluetooth
                            ? editorModel?.draft.bluetoothPolicy
                            : editorModel?.draft.systemItemPolicies[item.observationIdentifier])
                        ?? .visible
                )
            }
            editorWindowController.initializeOrderingLayoutFromCurrentRows()
            return true
        } catch {
            lastOrderingSnapshot = nil
            editorWindowController.orderingPresentation.hasObservation = false
            presentOrderingError(error)
            return false
        }
    }

    func orderingPositionLabel(_ value: OrderingValue) -> String {
        switch value {
        case let .integer(number): String(number)
        case let .real(number): String(number)
        default: "Unsupported position"
        }
    }

    func presentOrderingError(_ error: Error) {
        sessionDiagnostic("ordering-failure \(error.localizedDescription)")
        let presentation = editorWindowController.orderingPresentation
        presentation.needsDataAccess = false
        if let backendError = error as? MacOS27MenuBarOrderingBackendError {
            switch backendError {
            case let .groupFileOpenFailed(code), let .groupFileMetadataReadFailed(code),
                 let .groupFileReadFailed(code):
                presentation.needsDataAccess = code == EPERM || code == EACCES
            default: break
            }
        }
        presentation.isError = true
        presentation.message = presentation.needsDataAccess
            ? "Choose the menu bar layout file so Blenny can apply and undo your order."
            : "The operation could not finish. See Details before trying again."
        if let backendError = error as? MacOS27MenuBarOrderingBackendError,
           backendError == .runtimeUnsupported || backendError == .runtimeContractDiffers {
            presentation.message = "Ordering is unavailable on this macOS build."
        } else if case let .unavailableOrderChanges(names) = error as? OrderingError {
            presentation.message = "This draft moves items marked No sort: \(names.joined(separator: ", ")). Put them back or discard changes."
        } else if case .staleSnapshot = error as? OrderingError {
            presentation.message = "The menu bar changed. Discard changes and refresh before trying again."
        }
        presentation.technicalDetail = error.localizedDescription
        presentation.canApply = false
    }

    func presentCommittedOrderingRefreshFailure(_ error: Error, restored: Bool = false) {
        sessionDiagnostic("ordering-committed-refresh-failure \(error.localizedDescription)")
        // A failure to refresh the Board cannot turn a verified commit into a
        // failed write or invite the user to repeat that write.
        lastOrderingSnapshot = nil
        let presentation = editorWindowController.orderingPresentation
        presentation.hasObservation = false
        presentation.isError = false
        presentation.canApply = false
        presentation.requiresObservationRefresh = true
        presentation.message = (restored ? "Changes undone." : "Changes applied.")
            + " Refresh to update the Board. Do not apply again."
        presentation.technicalDetail = error.localizedDescription
    }
}
#endif
