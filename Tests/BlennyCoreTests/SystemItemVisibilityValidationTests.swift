#if DEBUG
import Foundation
import Testing
@testable import BlennyCore

@MainActor
@Suite("Debug-only Apple system-item visibility validation")
struct SystemItemVisibilityValidationTests {
    private let runtime = RuntimeEnvironment(
        macOSVersion: "27.0.0", buildVersion: "26A5416b", architecture: "arm64"
    )

    @Test("The catalog and each exact trial exclusion are immutable")
    func exactTarget() throws {
        let bluetoothPlan = try makePlan(target: .bluetooth)
        let wifiPlan = try makePlan(target: .wifi)
        #expect(MacOS27SystemItemIdentity.all.map(\.privateName) == [
            "battery", "bluetooth", "clock", "displays", "keyboard",
            "volume", "wifi", "screenMirroring", "primaryBentoBox"
        ])
        #expect(bluetoothPlan.target.identity == MacOS27SystemItemIdentity(
            rawValue: 1, privateName: "bluetooth"
        ))
        #expect(bluetoothPlan.target.axIdentifier ==
            SystemItemVisibilitySnapshot.bluetoothAXIdentifier)
        #expect(bluetoothPlan.writerPlan.allowedSystemItems == [0, 2, 3, 4, 5, 6, 7, 8])
        #expect(wifiPlan.target.identity == MacOS27SystemItemIdentity(
            rawValue: 6, privateName: "wifi"
        ))
        #expect(wifiPlan.target.axIdentifier == SystemItemVisibilitySnapshot.wifiAXIdentifier)
        #expect(wifiPlan.writerPlan.allowedSystemItems == [0, 1, 2, 3, 4, 5, 7, 8])
        #expect(wifiPlan.writerPlan.allowedSystemItems.contains(1))
        #expect(wifiPlan.writerPlan.allowedSystemItems.contains(2))
        #expect(wifiPlan.writerPlan.allowedSystemItems.contains(8))
        #expect(bluetoothPlan.writerPlan.allowedBundleIdentifiers
            == bluetoothPlan.baseline.runningBundleIdentifiers)
        #expect(SystemItemVisibilityPlan.durationSeconds == 60)
        #expect(try bluetoothPlan.fingerprint.count == 64)
        #expect(try bluetoothPlan.fingerprint != wifiPlan.fingerprint)
    }

    @Test("Missing protected observations, hashes and exact runtime fail closed")
    func invalidScope() throws {
        let baseline = makeSnapshot()
        let missingBluetooth = makeSnapshot(systemItems: baseline.systemItems.filter {
            $0.identifier != SystemItemVisibilitySnapshot.bluetoothAXIdentifier
        })
        #expect(throws: SystemItemVisibilityValidationError.incompleteSnapshot) {
            try SystemItemVisibilityPlan(runtime: runtime, baseline: missingBluetooth)
        }
        let noArrow = SystemItemVisibilitySnapshot(
            captureComplete: true, systemItems: baseline.systemItems,
            nativeOverflowFrames: [], scopedPreferences: baseline.scopedPreferences,
            localFileDigests: baseline.localFileDigests,
            runningBundleIdentifiers: baseline.runningBundleIdentifiers
        )
        _ = try SystemItemVisibilityPlan(runtime: runtime, baseline: noArrow)
        let twoArrows = SystemItemVisibilitySnapshot(
            captureComplete: true, systemItems: baseline.systemItems,
            nativeOverflowFrames: baseline.nativeOverflowFrames + baseline.nativeOverflowFrames,
            scopedPreferences: baseline.scopedPreferences,
            localFileDigests: baseline.localFileDigests,
            runningBundleIdentifiers: baseline.runningBundleIdentifiers
        )
        #expect(throws: SystemItemVisibilityValidationError.incompleteSnapshot) {
            try SystemItemVisibilityPlan(runtime: runtime, baseline: twoArrows)
        }
        let noHashes = SystemItemVisibilitySnapshot(
            captureComplete: true, systemItems: baseline.systemItems,
            nativeOverflowFrames: baseline.nativeOverflowFrames,
            scopedPreferences: baseline.scopedPreferences, localFileDigests: [],
            runningBundleIdentifiers: baseline.runningBundleIdentifiers
        )
        #expect(throws: SystemItemVisibilityValidationError.incompleteSnapshot) {
            try SystemItemVisibilityPlan(runtime: runtime, baseline: noHashes)
        }
        #expect(throws: SystemItemVisibilityValidationError.invalidScope) {
            try SystemItemVisibilityPlan(
                runtime: RuntimeEnvironment(
                    macOSVersion: "27.0.0", buildVersion: "other", architecture: "arm64"
                ), baseline: baseline
            )
        }
        #expect(throws: SystemItemVisibilityValidationError.invalidScope) {
            try ScopedPreferenceSnapshot(
                domain: "com.apple.controlcenter", encodedValues: Data("invalid".utf8)
            ).validate()
        }
    }

    @Test("Plan construction is a read-only capture with no assertion")
    func preview() async throws {
        let backend = FakeSystemItemBackend(state: makeSnapshot())
        _ = try SystemItemVisibilityPlan(runtime: runtime, baseline: backend.capture())
        #expect(backend.captureCount == 1)
    }

    @Test("Scoped preference equality is semantic while changed values remain stale")
    func semanticPreferenceEquality() throws {
        let values = [
            "NSStatusItem VisibleCC Bluetooth": 1,
            "NSStatusItem Preferred Position Bluetooth": 5781,
        ]
        let binary = try PropertyListSerialization.data(
            fromPropertyList: values, format: .binary, options: 0
        )
        let xml = try PropertyListSerialization.data(
            fromPropertyList: values, format: .xml, options: 0
        )
        let baseline = ScopedPreferenceSnapshot(
            domain: "com.apple.controlcenter", encodedValues: binary
        )
        let sameValues = ScopedPreferenceSnapshot(
            domain: "com.apple.controlcenter", encodedValues: xml
        )
        let changed = ScopedPreferenceSnapshot(
            domain: "com.apple.controlcenter",
            encodedValues: try PropertyListSerialization.data(
                fromPropertyList: [
                    "NSStatusItem VisibleCC Bluetooth": 0,
                    "NSStatusItem Preferred Position Bluetooth": 5781,
                ],
                format: .binary,
                options: 0
            )
        )

        #expect(binary != xml)
        #expect(baseline == sameValues)
        #expect(baseline != changed)
    }

    @Test("Malformed and schema-five receipts are rejected before mutation")
    func receiptSchemaAndTargetValidation() throws {
        let plan = try makePlan()
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        var oldReceipt = try #require(JSONSerialization.jsonObject(
            with: encoder.encode(plan)
        ) as? [String: Any])
        oldReceipt["schemaVersion"] = 5
        let oldData = try JSONSerialization.data(withJSONObject: oldReceipt)
        let decodedOldReceipt = try decoder.decode(
            SystemItemVisibilityPlan.self, from: oldData
        )
        #expect(throws: SystemItemVisibilityValidationError.invalidScope) {
            try decodedOldReceipt.validate()
        }

        var malformedReceipt = oldReceipt
        malformedReceipt["schemaVersion"] = 6
        malformedReceipt["target"] = "clock"
        let malformedData = try JSONSerialization.data(withJSONObject: malformedReceipt)
        #expect(throws: (any Error).self) {
            _ = try decoder.decode(SystemItemVisibilityPlan.self, from: malformedData)
        }
    }

    @Test("Confirmation and new running bundles reject before activation")
    func gates() async throws {
        let plan = try makePlan()
        for stale in [false, true] {
            let backend = FakeSystemItemBackend(state: plan.baseline)
            if stale { backend.state = makeSnapshot(running: [
                "com.apple.MenuBarAgent", "com.example.changed", "xyz.fi5h.blenny"
            ]) }
            let inner = FakeSystemItemAssertion(
                backend: backend, applied: appliedSnapshot(for: plan), baseline: plan.baseline
            )
            let candidate = SystemItemVisibilityValidationCandidate(
                backend: backend, inner: inner, plan: plan,
                confirmation: stale ? try plan.fingerprint : "wrong", settleDelay: .zero
            )
            let writer = RevealAssertionWriter(factory: SystemItemVisibilityValidationFactory(
                candidate: candidate, expectedPlan: plan.writerPlan
            ))
            await #expect(throws: stale
                ? SystemItemVisibilityValidationError.staleState
                : .unconfirmedPlan) {
                try await writer.replace(with: plan.writerPlan)
            }
            #expect(inner.activationCount == 0)
            #expect(inner.invalidationCount == 0)
        }
    }

    @Test("An authorized bundle may exit without expanding the writer scope")
    func bundleExitIsSafe() async throws {
        let plan = try makePlan()
        let departed = makeSnapshot(running: [
            "com.apple.MenuBarAgent", "xyz.fi5h.blenny"
        ])
        try plan.validateFresh(departed)

        let backend = FakeSystemItemBackend(state: departed)
        let applied = appliedSnapshot(for: plan, running: departed.runningBundleIdentifiers)
        let inner = FakeSystemItemAssertion(
            backend: backend, applied: applied, baseline: departed
        )
        let candidate = SystemItemVisibilityValidationCandidate(
            backend: backend, inner: inner, plan: plan,
            confirmation: try plan.fingerprint, settleDelay: .zero
        )
        let writer = RevealAssertionWriter(factory: SystemItemVisibilityValidationFactory(
            candidate: candidate, expectedPlan: plan.writerPlan
        ))

        try await writer.replace(with: plan.writerPlan)
        #expect(candidate.appliedVerified)
        await writer.restoreAndStop()
        #expect(candidate.restoreVerified)
        #expect(backend.state == departed)
        #expect(plan.writerPlan.allowedBundleIdentifiers.contains("com.example.Visible"))
    }

    @Test("Any newly running bundle still fails closed")
    func bundleAdditionIsStale() throws {
        let plan = try makePlan()
        let expanded = makeSnapshot(running: [
            "com.apple.MenuBarAgent", "com.example.NewlyLaunched",
            "com.example.Visible", "xyz.fi5h.blenny"
        ])
        #expect(throws: SystemItemVisibilityValidationError.staleState) {
            try plan.validateFresh(expanded)
        }
    }

    @Test("Reflow is benign while a protected identity drift stays stale")
    func layoutDriftIsBenign() throws {
        let plan = try makePlan()
        let reflowed = makeSnapshot(systemItems: plan.baseline.systemItems.map { item in
            SystemItemAXObservation(
                identifier: item.identifier,
                frame: item.frame.map {
                    RectSnapshot(
                        x: $0.x + 37, y: $0.y, width: $0.width, height: $0.height
                    )
                }
            )
        })
        try plan.validateFresh(reflowed)

        let missingDynamicItem = makeSnapshot(systemItems: plan.baseline.systemItems.filter {
            $0.identifier != SystemItemVisibilitySnapshot.soundAXIdentifier
        })
        #expect(throws: SystemItemVisibilityValidationError.staleState) {
            try plan.validateFresh(missingDynamicItem)
        }

        let missingWiFi = makeSnapshot(systemItems: plan.baseline.systemItems.filter {
            $0.identifier != SystemItemVisibilitySnapshot.wifiAXIdentifier
        })
        #expect(throws: SystemItemVisibilityValidationError.incompleteSnapshot) {
            try plan.validateFresh(missingWiFi)
        }
    }

    @Test("A target-hidden capture is structurally valid for applied verification")
    func appliedCaptureDoesNotRequireTarget() throws {
        let plan = try makePlan(target: .wifi)
        let applied = appliedSnapshot(for: plan)

        try applied.validateStructure()
        try plan.validateApplied(applied)
        #expect(throws: SystemItemVisibilityValidationError.incompleteSnapshot) {
            try applied.validate()
        }
    }

    @Test("Observation hold permits native overflow reflow but protects other identities")
    func observationHoldScope() throws {
        let plan = try makePlan(target: .wifi)
        let withoutOverflow = SystemItemVisibilitySnapshot(
            captureComplete: true,
            systemItems: appliedSnapshot(for: plan).systemItems,
            nativeOverflowFrames: [],
            scopedPreferences: plan.baseline.scopedPreferences,
            localFileDigests: plan.baseline.localFileDigests,
            runningBundleIdentifiers: plan.baseline.runningBundleIdentifiers
        )
        try plan.validateApplied(withoutOverflow)

        let wrongTargetAbsent = SystemItemVisibilitySnapshot(
            captureComplete: true,
            systemItems: plan.baseline.systemItems.filter {
                $0.identifier != SystemItemVisibilitySnapshot.bluetoothAXIdentifier
            },
            nativeOverflowFrames: [],
            scopedPreferences: plan.baseline.scopedPreferences,
            localFileDigests: plan.baseline.localFileDigests,
            runningBundleIdentifiers: plan.baseline.runningBundleIdentifiers
        )
        #expect(throws: SystemItemVisibilityValidationError.unexpectedStateChange) {
            try plan.validateApplied(wrongTargetAbsent)
        }
        let missingClock = SystemItemVisibilitySnapshot(
            captureComplete: true,
            systemItems: withoutOverflow.systemItems.filter {
                $0.identifier != SystemItemVisibilitySnapshot.clockAXIdentifier
            },
            nativeOverflowFrames: [],
            scopedPreferences: plan.baseline.scopedPreferences,
            localFileDigests: plan.baseline.localFileDigests,
            runningBundleIdentifiers: plan.baseline.runningBundleIdentifiers
        )
        #expect(throws: SystemItemVisibilityValidationError.unexpectedStateChange) {
            try plan.validateApplied(missingClock)
        }
    }

    @Test("Wi-Fi trial preserves every other mapped identity when it was observed")
    func wifiTrialPreservesOptionalMappedIdentities() throws {
        let baseline = makeSnapshot()
        let optionalMappedItems = [
            ax(SystemItemVisibilitySnapshot.displayAXIdentifier, x: 760),
            ax(SystemItemVisibilitySnapshot.keyboardBrightnessAXIdentifier, x: 780),
            ax(SystemItemVisibilitySnapshot.screenMirroringAXIdentifier, x: 800),
        ]
        let plan = try SystemItemVisibilityPlan(
            runtime: runtime,
            baseline: makeSnapshot(systemItems: baseline.systemItems + optionalMappedItems),
            target: .wifi
        )
        let applied = appliedSnapshot(for: plan)
        try plan.validateApplied(applied)

        let protectedOtherThanTarget = [
            SystemItemVisibilitySnapshot.batteryAXIdentifier,
            SystemItemVisibilitySnapshot.bluetoothAXIdentifier,
            SystemItemVisibilitySnapshot.clockAXIdentifier,
            SystemItemVisibilitySnapshot.displayAXIdentifier,
            SystemItemVisibilitySnapshot.keyboardBrightnessAXIdentifier,
            SystemItemVisibilitySnapshot.soundAXIdentifier,
            SystemItemVisibilitySnapshot.screenMirroringAXIdentifier,
            SystemItemVisibilitySnapshot.controlCenterAXIdentifier,
        ]
        for identifier in protectedOtherThanTarget where applied.count(identifier) > 0 {
            let drifted = SystemItemVisibilitySnapshot(
                captureComplete: true,
                systemItems: applied.systemItems.filter { $0.identifier != identifier },
                nativeOverflowFrames: [],
                scopedPreferences: plan.baseline.scopedPreferences,
                localFileDigests: plan.baseline.localFileDigests,
                runningBundleIdentifiers: plan.baseline.runningBundleIdentifiers
            )
            #expect(throws: SystemItemVisibilityValidationError.unexpectedStateChange) {
                try plan.validateApplied(drifted)
            }
        }
    }

    @Test("Restoration requires exact preference values and file hashes")
    func restorationRequiresExactPreferencesAndHashes() throws {
        let plan = try makePlan()
        let changedPreferences = SystemItemVisibilitySnapshot(
            captureComplete: true, systemItems: plan.baseline.systemItems,
            nativeOverflowFrames: [],
            scopedPreferences: SystemItemVisibilitySnapshot.preferenceDomains.map { domain in
                ScopedPreferenceSnapshot(
                    domain: domain,
                    encodedValues: try! PropertyListSerialization.data(
                        fromPropertyList: ["NSStatusItem VisibleCC Bluetooth": 0],
                        format: .binary, options: 0
                    )
                )
            },
            localFileDigests: plan.baseline.localFileDigests,
            runningBundleIdentifiers: plan.baseline.runningBundleIdentifiers
        )
        #expect(throws: SystemItemVisibilityValidationError.restoreFailed) {
            try plan.validateRestored(changedPreferences)
        }
        let changedDigest = SystemItemVisibilitySnapshot(
            captureComplete: true, systemItems: plan.baseline.systemItems,
            nativeOverflowFrames: [],
            scopedPreferences: plan.baseline.scopedPreferences,
            localFileDigests: plan.baseline.localFileDigests.enumerated().map { index, value in
                LocalFileDigest(
                    relativePath: value.relativePath,
                    exists: value.exists,
                    byteCount: value.byteCount + (index == 0 ? 1 : 0),
                    sha256: index == 0 ? String(repeating: "b", count: 64) : value.sha256
                )
            },
            runningBundleIdentifiers: plan.baseline.runningBundleIdentifiers
        )
        #expect(throws: SystemItemVisibilityValidationError.restoreFailed) {
            try plan.validateRestored(changedDigest)
        }
    }

    @Test("The one serial writer verifies hide and exact restoration once")
    func serialRestoration() async throws {
        let plan = try makePlan()
        let backend = FakeSystemItemBackend(state: plan.baseline)
        let inner = FakeSystemItemAssertion(
            backend: backend, applied: appliedSnapshot(for: plan), baseline: plan.baseline
        )
        let candidate = SystemItemVisibilityValidationCandidate(
            backend: backend, inner: inner, plan: plan,
            confirmation: try plan.fingerprint, settleDelay: .zero
        )
        let writer = RevealAssertionWriter(factory: SystemItemVisibilityValidationFactory(
            candidate: candidate, expectedPlan: plan.writerPlan
        ))
        try await writer.replace(with: plan.writerPlan)
        #expect(candidate.appliedVerified)
        #expect(backend.state.count(plan.target.axIdentifier) == 0)
        await writer.restoreAndStop()
        await writer.restoreAndStop()
        #expect(candidate.restoreVerified)
        #expect(backend.state == plan.baseline)
        #expect(inner.activationCount == 1)
        #expect(inner.invalidationCount == 1)
    }

    @Test("Unexpected apply state rolls back once without retry")
    func failedVerification() async throws {
        let plan = try makePlan()
        let backend = FakeSystemItemBackend(state: plan.baseline)
        let inner = FakeSystemItemAssertion(
            backend: backend, applied: plan.baseline, baseline: plan.baseline
        )
        let candidate = SystemItemVisibilityValidationCandidate(
            backend: backend, inner: inner, plan: plan,
            confirmation: try plan.fingerprint, settleDelay: .zero
        )
        let writer = RevealAssertionWriter(factory: SystemItemVisibilityValidationFactory(
            candidate: candidate, expectedPlan: plan.writerPlan
        ))
        await #expect(throws: SystemItemVisibilityValidationError.unexpectedStateChange) {
            try await writer.replace(with: plan.writerPlan)
        }
        #expect(inner.activationCount == 1)
        #expect(inner.invalidationCount == 1)
        #expect(candidate.restoreVerified)
        #expect(backend.state == plan.baseline)
    }

    @Test("A restoration mismatch stays terminal and visible")
    func restoreFailure() async throws {
        let plan = try makePlan()
        let backend = FakeSystemItemBackend(state: plan.baseline)
        let inner = FakeSystemItemAssertion(
            backend: backend, applied: appliedSnapshot(for: plan), baseline: plan.baseline,
            restoreCorrectly: false
        )
        let candidate = SystemItemVisibilityValidationCandidate(
            backend: backend, inner: inner, plan: plan,
            confirmation: try plan.fingerprint, settleDelay: .zero
        )
        let writer = RevealAssertionWriter(factory: SystemItemVisibilityValidationFactory(
            candidate: candidate, expectedPlan: plan.writerPlan
        ))
        try await writer.replace(with: plan.writerPlan)
        await writer.restoreAndStop()
        #expect(!candidate.restoreVerified)
        #expect(candidate.failure != nil)
        #expect(inner.invalidationCount == 1)
    }

    @Test("The validation factory rejects every broader or different plan")
    func factoryScope() throws {
        let plan = try makePlan()
        let backend = FakeSystemItemBackend(state: plan.baseline)
        let inner = FakeSystemItemAssertion(
            backend: backend, applied: appliedSnapshot(for: plan), baseline: plan.baseline
        )
        let candidate = SystemItemVisibilityValidationCandidate(
            backend: backend, inner: inner, plan: plan,
            confirmation: try plan.fingerprint, settleDelay: .zero
        )
        let factory = SystemItemVisibilityValidationFactory(
            candidate: candidate, expectedPlan: plan.writerPlan
        )
        for other in [
            RevealAllowlistPlan(
                presentation: .revealed,
                allowedSystemItems: plan.allowedSystemItems,
                allowedBundleIdentifiers: plan.baseline.runningBundleIdentifiers
            ),
            RevealAllowlistPlan(
                presentation: .baseline, allowedSystemItems: Array(0 ... 8),
                allowedBundleIdentifiers: plan.baseline.runningBundleIdentifiers
            ),
            RevealAllowlistPlan(
                presentation: .baseline,
                allowedSystemItems: plan.allowedSystemItems,
                allowedBundleIdentifiers: [SystemItemVisibilityPlan.bundleIdentifier]
            )
        ] {
            #expect(throws: SystemItemVisibilityValidationError.invalidScope) {
                try factory.makeCandidate(for: other)
            }
        }
    }

    private func makePlan(
        target: SystemItemVisibilityTarget = .bluetooth
    ) throws -> SystemItemVisibilityPlan {
        try SystemItemVisibilityPlan(
            runtime: runtime, baseline: makeSnapshot(), target: target
        )
    }

    private func makeSnapshot(
        systemItems: [SystemItemAXObservation]? = nil,
        running: [String] = [
            "com.apple.MenuBarAgent", "com.example.Visible", "xyz.fi5h.blenny"
        ]
    ) -> SystemItemVisibilitySnapshot {
        let items = systemItems ?? [
            ax(SystemItemVisibilitySnapshot.bluetoothAXIdentifier, x: 820),
            ax(SystemItemVisibilitySnapshot.wifiAXIdentifier, x: 850),
            ax(SystemItemVisibilitySnapshot.clockAXIdentifier, x: 1_500),
            ax(SystemItemVisibilitySnapshot.controlCenterAXIdentifier, x: 900),
            ax(SystemItemVisibilitySnapshot.soundAXIdentifier, x: 880)
        ]
        let preferences = SystemItemVisibilitySnapshot.preferenceDomains.map { domain in
            ScopedPreferenceSnapshot(
                domain: domain,
                encodedValues: try! PropertyListSerialization.data(
                    fromPropertyList: ["NSStatusItem VisibleCC Bluetooth": 1],
                    format: .binary, options: 0
                )
            )
        }
        let digests = SystemItemVisibilitySnapshot.requiredFilePaths.map {
            LocalFileDigest(relativePath: $0, exists: true, byteCount: 1,
                            sha256: String(repeating: "a", count: 64))
        }
        return SystemItemVisibilitySnapshot(
            captureComplete: true, systemItems: items,
            nativeOverflowFrames: [RectSnapshot(x: 790, y: 0, width: 22, height: 24)],
            scopedPreferences: preferences, localFileDigests: digests,
            runningBundleIdentifiers: running
        )
    }

    private func appliedSnapshot(
        for plan: SystemItemVisibilityPlan,
        running: [String]? = nil
    ) -> SystemItemVisibilitySnapshot {
        SystemItemVisibilitySnapshot(
            captureComplete: true,
            systemItems: plan.baseline.systemItems.compactMap { item in
                guard item.identifier != plan.target.axIdentifier else {
                    return nil
                }
                return SystemItemAXObservation(
                    identifier: item.identifier,
                    frame: item.frame.map {
                        RectSnapshot(x: $0.x - 20, y: $0.y,
                                     width: $0.width, height: $0.height)
                    }
                )
            },
            nativeOverflowFrames: plan.baseline.nativeOverflowFrames,
            scopedPreferences: plan.baseline.scopedPreferences,
            localFileDigests: plan.baseline.localFileDigests,
            runningBundleIdentifiers: running ?? plan.baseline.runningBundleIdentifiers
        )
    }

    private func ax(_ identifier: String, x: Double) -> SystemItemAXObservation {
        SystemItemAXObservation(
            identifier: identifier,
            frame: RectSnapshot(x: x, y: 0, width: 22, height: 24)
        )
    }
}

@MainActor
private final class FakeSystemItemBackend: SystemItemVisibilitySnapshotCapturing {
    var state: SystemItemVisibilitySnapshot
    var captureCount = 0

    init(state: SystemItemVisibilitySnapshot) { self.state = state }

    func capture() -> SystemItemVisibilitySnapshot {
        captureCount += 1
        return state
    }
}

@MainActor
private final class FakeSystemItemAssertion: RevealAssertionCandidate {
    private let backend: FakeSystemItemBackend
    private let applied: SystemItemVisibilitySnapshot
    private let baseline: SystemItemVisibilitySnapshot
    private let restoreCorrectly: Bool
    private(set) var activationCount = 0
    private(set) var invalidationCount = 0

    init(
        backend: FakeSystemItemBackend,
        applied: SystemItemVisibilitySnapshot,
        baseline: SystemItemVisibilitySnapshot,
        restoreCorrectly: Bool = true
    ) {
        self.backend = backend
        self.applied = applied
        self.baseline = baseline
        self.restoreCorrectly = restoreCorrectly
    }

    nonisolated func activate() async throws { await activateOnMainActor() }

    private func activateOnMainActor() {
        activationCount += 1
        backend.state = applied
    }

    nonisolated func invalidate() async { await invalidateOnMainActor() }

    private func invalidateOnMainActor() {
        invalidationCount += 1
        if restoreCorrectly { backend.state = baseline }
    }
}
#endif
