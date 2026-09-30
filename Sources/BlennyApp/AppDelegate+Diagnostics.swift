import AppKit
import BlennyCore
import Foundation

extension AppDelegate {
#if DEBUG
    func runInstalledDryRunIfRequested(
        model: PolicyEditorViewModel
    ) async {
        guard isReadOnlyValidation
        else { return }
        if ProcessInfo.processInfo.environment["BLENNY_0_9_0_ORDERING_DRY_RUN"] == "YES" {
            // Let the ordinary refresh finish its UI interaction before the
            // separately bounded, read-only ordering inspection starts.
            Task { @MainActor [weak self] in await self?.runInstalledOrderingDryRun() }
            return
        }
        do {
            guard statusItemController.debugValidateNativeFallbackPresentation() else {
                throw NSError(domain: "Blenny.InstalledDryRun", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Local AppKit fallback-presentation fixtures failed."
                ])
            }
            Self.writeDryRunOutput(
                "APPKIT PRESENTATION FIXTURES passed=true"
                    + " nativeEventEvidence=false writerCreated=false"
            )
            let core = try await makeCore(scope: model.acceptedPolicyScope)
            let preview = try await core.previewResumeManaging(
                candidates: model.candidateInventory,
                observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                candidateGeneration: editorWindowController.candidateGeneration,
                runtimeContractFingerprint: runtimeContractFingerprint
            )
            guard let baseline = preview.0.newBaselinePlan,
                  let reveal = preview.0.newRevealPlan,
                  let expansion = try PassThroughExpansion.prepare(
                    baseline: baseline, reveal: reveal,
                    acceptedBundleIdentifiers: Set(model.acceptedPolicyScope.approvedBundleIdentifiers),
                    launchedBundleIdentifiers: ["xyz.fi5h.blenny.validation.passthrough"]
                  ) else {
                throw PolicyInterfaceWriteError.applyPreflightUnavailable("Pass-through dry-run plan is unavailable")
            }
            try PassThroughExpansion.validateReplacement(
                from: baseline, to: expansion.baseline,
                addedBundleIdentifiers: Set(expansion.addedBundleIdentifiers)
            )
            try PassThroughExpansion.validateReplacement(
                from: reveal, to: expansion.reveal,
                addedBundleIdentifiers: Set(expansion.addedBundleIdentifiers)
            )
            Self.writeDryRunOutput(
                "PASS-THROUGH PREVIEW additions=\(expansion.addedBundleIdentifiers.count)"
                    + " systemItemsUnchanged=true policyUnchanged=true"
                    + " writerCreated=false assertionCreated=false persistenceChanged=false"
            )
            var manualPlansVerified = 0
            for item in SystemItemPolicyCatalog.items {
                for policy in MenuBarBundlePolicy.allCases {
                    let originalDraft = BundlePolicyDraft(acceptedPolicy: model.acceptedPolicy)
                    let trialDraft = item.rawValue == RevealAllowlistPlanner.bluetoothSystemItem
                        ? originalDraft.assigningBluetooth(to: policy)
                        : originalDraft.assigningSystemItem(identifier: item.identifier, to: policy)
                    let trial = try PolicyDryRunner.prepare(
                        oldPolicy: model.acceptedPolicy, draft: trialDraft,
                        managementEnabled: true, candidates: model.candidateInventory,
                        observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                        scope: model.acceptedPolicyScope,
                        blennyBundleIdentifier: model.blennyBundleIdentifier,
                        candidateGeneration: editorWindowController.candidateGeneration,
                        runtimeContractFingerprint: runtimeContractFingerprint
                    )
                    guard trial.prepared != nil,
                          let baseline = trial.report.newBaselinePlan,
                          let reveal = trial.report.newRevealPlan,
                          baseline.allowedSystemItems.contains(2),
                          reveal.allowedSystemItems.contains(2),
                          baseline.allowedSystemItems.contains(item.rawValue) == (policy == .visible),
                          reveal.allowedSystemItems.contains(item.rawValue) == (policy != .hidden) else {
                        throw PolicyInterfaceWriteError.applyPreflightUnavailable(
                            "Manual system-item policy fixture failed for \(item.displayName)"
                        )
                    }
                    manualPlansVerified += 1
                }
            }
            Self.writeDryRunOutput(
                "MANUAL SYSTEM-ITEM PREVIEW controls=\(SystemItemPolicyCatalog.items.count)"
                    + " policyPlans=\(manualPlansVerified) clockAlwaysAllowed=true"
                    + " startsStopped=\(!model.acceptedPolicy.managementEnabled)"
                    + " isolatedPolicyStore=true writerCreated=false assertionCreated=false"
                    + " persistenceChanged=false"
            )
            var appleOwnerPlansVerified = 0
            for catalogIdentifier in ExperimentalAppleBundlePolicyCatalog.bundleIdentifiers.sorted() {
                guard let currentOwner = model.candidateInventory.candidates.first(where: {
                    $0.bundleIdentifier.lowercased() == catalogIdentifier
                }) else {
                    throw PolicyInterfaceWriteError.applyPreflightUnavailable(
                        "Experimental Apple owner is not an exact current menu-bar candidate: \(catalogIdentifier)"
                    )
                }
                let bundleIdentifier = currentOwner.bundleIdentifier
                for policy in MenuBarBundlePolicy.allCases {
                    let trialDraft = BundlePolicyDraft(acceptedPolicy: model.acceptedPolicy)
                        .assigning(bundleIdentifier, to: policy)
                    let trialScope = PolicyValidationScope(
                        approvedBundleIdentifiers:
                            trialDraft.visible + trialDraft.revealable + trialDraft.hidden
                    )
                    let trial = try PolicyDryRunner.prepare(
                        oldPolicy: model.acceptedPolicy, draft: trialDraft,
                        managementEnabled: true, candidates: model.candidateInventory,
                        observedRunningBundleIdentifiers: observedRunningBundleIdentifiers,
                        scope: trialScope,
                        blennyBundleIdentifier: model.blennyBundleIdentifier,
                        candidateGeneration: editorWindowController.candidateGeneration,
                        runtimeContractFingerprint: runtimeContractFingerprint
                    )
                    guard trial.prepared != nil,
                          let baseline = trial.report.newBaselinePlan,
                          let reveal = trial.report.newRevealPlan,
                          baseline.allowedBundleIdentifiers.contains(bundleIdentifier)
                            == (policy == .visible),
                          reveal.allowedBundleIdentifiers.contains(bundleIdentifier)
                            == (policy != .hidden) else {
                        throw PolicyInterfaceWriteError.applyPreflightUnavailable(
                            "Experimental Apple owner fixture failed for \(bundleIdentifier)"
                        )
                    }
                    appleOwnerPlansVerified += 1
                }
            }
            Self.writeDryRunOutput(
                "EXPERIMENTAL APPLE-OWNER PREVIEW controls="
                    + "\(ExperimentalAppleBundlePolicyCatalog.bundleIdentifiers.count)"
                    + " policyPlans=\(appleOwnerPlansVerified) exactCurrentOwners=true"
                    + " writerCreated=false assertionCreated=false persistenceChanged=false"
            )
            // The ordinary app already started this observer, independently of
            // management. Do not create a second, dry-run-only observation path.
            let native = ordinaryReveal.observation
            let nativeFailure = nativeOverflowObserver.unavailabilityReason ?? "none"
            let nativeDetails = nativeOverflowObserver.debugObservationDetails.joined(separator: "\n- ")
            Self.writeDryRunOutput(
                preview.0.text
                    + "\nNATIVE OBSERVATION (READ ONLY)"
                    + "\n- present=\(native.isPresent) observable=\(native.observationAvailable) state=\(native.presentationState.rawValue) failure=\(nativeFailure)"
                    + "\n- controls=\(native.controlCount) usable=\(native.isUsable)"
                    + "\n- \(nativeDetails)"
                    + "\nDRY-RUN GUARANTEES"
                    + "\n- installedBundle=\(Bundle.main.bundleURL.path)"
                    + "\n- writerCreated=false"
                    + "\n- assertionCreated=false"
                    + "\n- persistenceChanged=false"
                    + "\n- managementEnabledChanged=false"
                    + "\n- readOnlyStore=true"
                    + "\n- planPrepared=\(preview.1 != nil)"
            )
            if let raw = ProcessInfo.processInfo.environment["BLENNY_0_6_0_OBSERVE_SECONDS"],
               let seconds = Int(raw), (1...300).contains(seconds) {
                Self.writeDryRunOutput("READ-ONLY OBSERVATION WINDOW seconds=\(seconds); no writer is available")
                try await Task.sleep(for: .seconds(seconds))
            }
            nativeOverflowObserver.stop()
            statusItemController.setNativeOverflow(.unavailable)
            editorWindowController.setNativeOverflowPlacement(.unavailable)
        } catch {
            nativeOverflowObserver.stop()
            statusItemController.setNativeOverflow(.unavailable)
            editorWindowController.setNativeOverflowPlacement(.unavailable)
            Self.writeDryRunOutput("DRY-RUN FAILED: \(error)")
        }
        NSApplication.shared.terminate(nil)
    }

    static func writeDryRunOutput(_ text: String) {
        guard let data = "\(text)\n".data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
    }

    /// Exercises the installed product reader and planner with the ordinary
    /// read-only policy store. The writer provider rejects this entire launch.
    func runInstalledOrderingDryRun() async {
        do {
            let snapshot = try await orderingBackend.capture()
            let candidates = try OrderingIdentityResolver.resolve(snapshot: snapshot)
            presentOrderingCandidates(snapshot)
            await updateOrderingRecoveryPresentation()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let receipt = try await orderingRecoveryStore.load(),
               let review = try receipt.undoLedgerRebaseReview(in: snapshot) {
                Self.writeDryRunOutput("ORDERING READ-ONLY UNDO REBASE REVIEW: " + review.userDescription)
            }
            Self.writeDryRunOutput("ORDERING READ-ONLY SNAPSHOT")
            FileHandle.standardOutput.write(try encoder.encode(snapshot))
            Self.writeDryRunOutput("\nORDERING CANDIDATES")
            for candidate in candidates where candidate.key != nil
                || snapshot.observationsByPID.values.contains(where: {
                    $0.process.bundleIdentifier == candidate.bundleIdentifier
                }) {
                Self.writeDryRunOutput(
                    "\(candidate.bundleIdentifier): eligible=\(candidate.eligible) "
                        + candidate.reasons.map(\.userDescription).joined(separator: "; ")
                )
            }
            let insertion = ProcessInfo.processInfo.environment["BLENNY_ORDERING_REORDER_BUNDLES"]
            let previewPlan: OrderingPlan?
            if let selection = ProcessInfo.processInfo.environment["BLENNY_ORDERING_PREVIEW_SUBJECTS"] {
                let identifiers = selection.split(separator: ",").map(String.init)
                let subjects = identifiers.compactMap { OrderingSubjectID(boardID: $0) }
                guard !subjects.isEmpty, subjects.count == identifiers.count else {
                    throw OrderingError.invalidSelection
                }
                previewPlan = try OrderingPlan.makeConfigurationOrdering(
                    snapshot: snapshot, orderedSubjects: subjects
                )
            } else if let selection = insertion
                ?? ProcessInfo.processInfo.environment["BLENNY_ORDERING_PREVIEW_BUNDLES"] {
                let bundles = selection.split(separator: ",").map(String.init)
                previewPlan = try insertion == nil
                    ? OrderingPlan.make(snapshot: snapshot, bundleIdentifiers: bundles)
                    : OrderingPlan.makeReordering(snapshot: snapshot, orderedBundleIdentifiers: bundles)
            } else {
                previewPlan = nil
            }
            if let plan = previewPlan {
                Self.writeDryRunOutput("ORDERING READ-ONLY PREVIEW")
                FileHandle.standardOutput.write(try encoder.encode(plan))
                if ProcessInfo.processInfo.environment["BLENNY_ORDERING_VERIFY_PREFLIGHT"] == "YES" {
                    // One additional read diagnoses freshness without creating a
                    // writer, sleeping, retrying or changing the reviewed plan.
                    let current = try await orderingBackend.capture()
                    Self.writeDryRunOutput("\nORDERING READ-ONLY PREFLIGHT SNAPSHOT")
                    FileHandle.standardOutput.write(try encoder.encode(current))
                    do {
                        try plan.validateFresh(equivalentTo: current)
                        Self.writeDryRunOutput("\nORDERING READ-ONLY PREFLIGHT equivalent=true")
                    } catch {
                        Self.writeDryRunOutput("\nORDERING READ-ONLY PREFLIGHT rejected: \(error.localizedDescription)")
                    }
                }
            }
            Self.writeDryRunOutput(
                "\nORDERING DRY-RUN PASSED writerCreated=false orderingWrite=false"
                    + " receiptWritten=false policyStoreReadOnly=true"
            )
            if let raw = ProcessInfo.processInfo.environment["BLENNY_0_9_0_OBSERVE_SECONDS"],
               let seconds = Int(raw), (1...60).contains(seconds) {
                showEditor()
                Self.writeDryRunOutput("ORDERING READ-ONLY UI WINDOW seconds=\(seconds)")
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds)) {
                    Self.writeDryRunOutput("ORDERING READ-ONLY UI WINDOW finished")
                    NSApplication.shared.terminate(nil)
                }
                return
            }
        } catch {
            Self.writeDryRunOutput("ORDERING DRY-RUN FAILED: \(error)")
        }
        // Exit from an AppKit run-loop turn, outside this Swift task's job.
        RunLoop.main.perform(inModes: [.common]) {
            MainActor.assumeIsolated { NSApplication.shared.terminate(nil) }
        }
    }
    #endif

    }
