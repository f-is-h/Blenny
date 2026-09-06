import AppKit
import ApplicationServices
import Foundation

public enum NativeOverflowPresentationState: String, Equatable, Sendable {
    case collapsed
    case expanded
    case unknown
}

public enum NativeOverflowUpdateSource: String, Equatable, Sendable {
    case discovery, sample, layout, valueChange
}

public struct NativeOverflowObservationSnapshot: Equatable, Sendable {
    public let isPresent: Bool
    public let presentationState: NativeOverflowPresentationState
    public let observationAvailable: Bool
    /// Process-local identity of one registered AX control, never a position.
    public let controlIdentifier: UUID?
    public let controlCount: Int

    public var isUsable: Bool {
        isPresent && observationAvailable && presentationState != .unknown
            && controlCount == 1 && controlIdentifier != nil
    }

    public init(
        isPresent: Bool,
        presentationState: NativeOverflowPresentationState,
        observationAvailable: Bool,
        controlIdentifier: UUID? = nil,
        controlCount: Int? = nil
    ) {
        self.isPresent = isPresent
        self.presentationState = presentationState
        self.observationAvailable = observationAvailable
        self.controlIdentifier = controlIdentifier
        self.controlCount = controlCount ?? (isPresent ? 1 : 0)
    }

    public static let unavailable = NativeOverflowObservationSnapshot(
        isPresent: false,
        presentationState: .unknown,
        observationAvailable: false
    )

    public static func observed(
        states: [NativeOverflowPresentationState], controlIdentifier: UUID?
    ) -> Self {
        Self(
            isPresent: !states.isEmpty,
            presentationState: states.count == 1 ? states[0] : .unknown,
            observationAvailable: true,
            controlIdentifier: states.count == 1 ? controlIdentifier : nil,
            controlCount: states.count
        )
    }
}

public enum NativeOverflowPresentationStateClassifier {
    static func availableState(
        _ state: NativeOverflowPresentationState, enabled: Bool?, hidden: Bool?, ownerMatches: Bool
    ) -> NativeOverflowPresentationState {
        // AXHidden is unsupported on the observed controls. Absence is not a
        // visibility guarantee; an explicit hidden value must reject the entry.
        guard enabled == true, hidden != true, ownerMatches else { return .unknown }
        return state
    }

    private static let collapsedMarkers = [
        "show hidden menu bar items",
        "show more menu bar items",
        "more menu bar items",
        "additional menu bar items",
        "显示隐藏菜单栏项目",
        "更多菜单栏项目",
        "顯示隱藏的選單列項目",
        "更多選單列項目",
        "メニューバーの項目をさらに表示"
    ]

    private static let expandedMarkers = [
        "hide hidden menu bar items",
        "hide more menu bar items",
        "隐藏菜单栏项目",
        "隱藏選單列項目",
        "メニューバーの追加項目を隠す"
    ]

    public static func classify(
        title: String?,
        itemDescription: String?,
        accessibilityIdentifier: String?
    ) -> NativeOverflowPresentationState {
        let labels = [title, itemDescription, accessibilityIdentifier]
            .compactMap(MenuBarItemIdentityResolver.normalize)
        // Substrings are unsafe: "hide more menu bar items" also contains the
        // collapsed marker "more menu bar items". Contradictory labels fail closed.
        let collapsed = labels.contains { collapsedMarkers.contains($0) }
        let expanded = labels.contains { expandedMarkers.contains($0) }
        guard collapsed != expanded else { return .unknown }
        return collapsed ? .collapsed : .expanded
    }
}

@MainActor
public final class NativeOverflowObserver {
    public private(set) var isSamplingCurrentControl = false
    public private(set) var lastUpdateSource = NativeOverflowUpdateSource.discovery
    public private(set) var unavailabilityReason: String?
    #if DEBUG
    public private(set) var debugObservationDetails: [String] = []
    /// Bounded validation telemetry, separate from the state-change callback.
    /// Duplicate or ambiguous notifications may be logged without becoming an
    /// eligible reveal edge. No handler is installed during ordinary operation.
    public var debugNotificationHandler: (@MainActor @Sendable (String) -> Void)?
    public var debugSubscriptionSummary: String {
        "applicationTopology=\(applicationTopologyRegistrationCount)"
            + " extrasTopology=\(extrasSubscriptions.registered.joined(separator: ","))"
            + " controls=\(observedElements.count)"
    }
    #endif
    public typealias UpdateHandler = @MainActor @Sendable (
        NativeOverflowObservationSnapshot
    ) -> Void

    private let messagingTimeoutSeconds: Float
    private let reconnectOnAgentChange: Bool
    private var agentConnectionLost: (@MainActor @Sendable () -> Void)?
    private var observedAgentPID: pid_t?
    private var observer: AXObserver?
    private var menuBarAgentElement: AXUIElement?
    private var observedElements: [AXUIElement] = []
    private var controlIdentifier: UUID?
    private var runLoopSource: CFRunLoopSource?
    private var context: NativeOverflowObserverContext?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var updateHandler: UpdateHandler?
    private var lastSnapshot: NativeOverflowObservationSnapshot?
    private var readRecovery = NativeOverflowReadRecovery()
    private var extrasSubscriptions = NativeOverflowRootSubscriptions<AXUIElement>()
    private var applicationTopologyRegistrationCount = 0
    private var activationSample = NativeOverflowActivationSample()
    private var activationSampleTask: Task<Void, Never>?

    public init(messagingTimeoutSeconds: Float = 0.5, reconnectOnAgentChange: Bool = true) {
        self.messagingTimeoutSeconds = messagingTimeoutSeconds
        self.reconnectOnAgentChange = reconnectOnAgentChange
    }

    @discardableResult
    public func start(
        onAgentConnectionLost: (@MainActor @Sendable () -> Void)? = nil,
        onUpdate: @escaping UpdateHandler
    ) -> NativeOverflowObservationSnapshot {
        stop()
        unavailabilityReason = nil
        updateHandler = onUpdate
        readRecovery.explicitRefresh()
        agentConnectionLost = onAgentConnectionLost
        installWorkspaceObservers()

        guard AccessibilityAuthorization.isTrusted else {
            unavailabilityReason = "accessibility-not-granted"
            publish(.unavailable)
            return .unavailable
        }
        let snapshot = configureForCurrentMenuBarAgent()
        publish(snapshot)
        return snapshot
    }

    public func stop() {
        for token in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        workspaceObservers.removeAll()

        detachAXObserver()
        observedAgentPID = nil
        agentConnectionLost = nil
        updateHandler = nil
        lastSnapshot = nil
        #if DEBUG
        debugNotificationHandler = nil
        #endif
    }

    /// One read after an explicit action or a settled app-activation event can
    /// discover a newly created control without waiting for a writer operation.
    /// Never reconnect or schedule another sample from this method.
    public func sampleCurrentControl() {
        guard let context else { return }
        isSamplingCurrentControl = true
        defer { isSamplingCurrentControl = false }
        guard AccessibilityAuthorization.isTrusted else {
            detachAXObserver()
            publish(.unavailable)
            return
        }
        publish(rescanOverflowElements(context: context), source: .sample)
    }

    /// An explicit manual Refresh may re-establish a failed read-only AX
    /// registration once. It cannot reconnect a changed MenuBarAgent or write.
    public func refreshCurrentControl() {
        guard updateHandler != nil, AccessibilityAuthorization.isTrusted,
              let observedAgentPID,
              NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent")
                .contains(where: { $0.processIdentifier == observedAgentPID }) else { return }
        isSamplingCurrentControl = true
        defer { isSamplingCurrentControl = false }
        readRecovery.explicitRefresh()
        clearExtrasSubscriptions()
        let snapshot: NativeOverflowObservationSnapshot
        if let context {
            snapshot = rescanOverflowElements(context: context)
        } else {
            snapshot = configureForCurrentMenuBarAgent()
        }
        publish(snapshot, source: .sample)
    }

    private func configureForCurrentMenuBarAgent() -> NativeOverflowObservationSnapshot {
        detachAXObserver()
        guard let application = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.MenuBarAgent"
        ).first else {
            unavailabilityReason = "agent-not-running"
            return .unavailable
        }
        observedAgentPID = application.processIdentifier

        let applicationElement = AXUIElementCreateApplication(
            application.processIdentifier
        )
        guard AXUIElementSetMessagingTimeout(
            applicationElement,
            messagingTimeoutSeconds
        ) == .success else {
            unavailabilityReason = "messaging-timeout-unavailable"
            return .unavailable
        }

        var createdObserver: AXObserver?
        guard AXObserverCreate(
            application.processIdentifier,
            nativeOverflowObserverCallback,
            &createdObserver
        ) == .success,
              let createdObserver else {
            unavailabilityReason = "observer-registration-failed"
            return .unavailable
        }

        let context = NativeOverflowObserverContext(owner: self)
        self.context = context
        self.observer = createdObserver
        self.menuBarAgentElement = applicationElement
        let source = AXObserverGetRunLoopSource(createdObserver)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        // Discovery cannot depend on an already-registered overflow child.
        // Application notifications cover root creation/replacement; the
        // canonical extras root is also subscribed during each root binding.
        for name in [kAXLayoutChangedNotification, kAXCreatedNotification] {
            if register(element: applicationElement, notification: name as CFString,
                        context: context, target: "application") {
                applicationTopologyRegistrationCount += 1
            }
        }
        return rescanOverflowElements(context: context)
    }

    private func rescanOverflowElements(
        context: NativeOverflowObserverContext
    ) -> NativeOverflowObservationSnapshot {
        guard let applicationElement = menuBarAgentElement else { return .unavailable }
        guard readRecovery.allowsEventRead else {
            unavailabilityReason = "native-read-recovery-exhausted-use-refresh"
            return .unavailable
        }
        guard let elements = discoverOverflowElements(applicationElement: applicationElement, context: context) else {
            readRecovery.failed()
            clearControlRegistrations()
            // Keep the application layout subscription. One later notification
            // can recover observation; never recreate the management writer.
            return .unavailable
        }
        let retainsSingleControl = elements.count == 1 && observedElements.count == 1
            && CFEqual(elements[0], observedElements[0])
        if !retainsSingleControl || controlIdentifier == nil {
            controlIdentifier = elements.count == 1 ? UUID() : nil
        }
        if let observer {
            for element in observedElements where !elements.contains(where: { CFEqual($0, element) }) {
                AXObserverRemoveNotification(observer, element, kAXValueChangedNotification as CFString)
                AXObserverRemoveNotification(observer, element, kAXUIElementDestroyedNotification as CFString)
            }
        }

        for element in elements where !observedElements.contains(where: { CFEqual($0, element) }) {
            guard register(
                element: element,
                notification: kAXValueChangedNotification as CFString,
                context: context
            ) else {
                unavailabilityReason = "value-notification-unavailable"
                readRecovery.failed()
                clearControlRegistrations(additionalElements: elements)
                return .unavailable
            }
            _ = register(
                element: element,
                notification: kAXUIElementDestroyedNotification as CFString,
                context: context
            )
        }
        observedElements = elements
        readRecovery.succeeded()
        return snapshotOfObservedElements()
    }

    private func clearControlRegistrations(additionalElements: [AXUIElement] = []) {
        if let observer {
            for element in observedElements + additionalElements {
                AXObserverRemoveNotification(observer, element, kAXValueChangedNotification as CFString)
                AXObserverRemoveNotification(observer, element, kAXUIElementDestroyedNotification as CFString)
            }
        }
        observedElements.removeAll()
        controlIdentifier = nil
    }

    private func snapshotOfObservedElements() -> NativeOverflowObservationSnapshot {
        let states = observedElements.map(presentationState(of:))
        return .observed(
            states: states, controlIdentifier: controlIdentifier
        )
    }

    private func register(
        element: AXUIElement,
        notification: CFString,
        context: NativeOverflowObserverContext,
        target: String = "control"
    ) -> Bool {
        guard let observer else { return false }
        let result = AXObserverAddNotification(
            observer,
            element,
            notification,
            Unmanaged.passUnretained(context).toOpaque()
        )
        #if DEBUG
        debugNotificationHandler?("register target=\(target) name=\(notification) result=\(result.rawValue)")
        #endif
        return result == .success || result == .notificationAlreadyRegistered
    }

    private func clearExtrasSubscriptions() {
        let currentObserver = observer
        extrasSubscriptions.clear { element, name in
            if let currentObserver { AXObserverRemoveNotification(currentObserver, element, name as CFString) }
        }
    }

    private func detachAXObserver() {
        activationSampleTask?.cancel()
        activationSampleTask = nil
        activationSample.cancel()
        clearExtrasSubscriptions()
        applicationTopologyRegistrationCount = 0
        context?.owner = nil
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        observer = nil
        menuBarAgentElement = nil
        observedElements.removeAll()
        controlIdentifier = nil
        runLoopSource = nil
        context = nil
    }

    fileprivate func receivedAXNotification(
        _ notification: String, element: AXUIElement, source: NativeOverflowObserverContext
    ) {
        guard let context, context === source else { return }
        #if DEBUG
        let sender = observedElements.firstIndex(where: { CFEqual($0, element) })
        debugNotificationHandler?("received name=\(notification) sender=\(sender.map(String.init) ?? "container")")
        #endif
        if notification == kAXUIElementDestroyedNotification as String
            || notification == kAXLayoutChangedNotification as String
            || notification == kAXCreatedNotification as String {
            if notification == kAXUIElementDestroyedNotification as String {
                // An AX handle may compare equal after recreation. A destruction
                // notification still ends its registration identity.
                controlIdentifier = nil
                if extrasSubscriptions.contains(element, sameElement: { CFEqual($0, $1) }) {
                    clearExtrasSubscriptions()
                    clearControlRegistrations()
                } else if observedElements.contains(where: { CFEqual($0, element) }) {
                    // Even an equal reused handle needs a new registration.
                    clearControlRegistrations()
                }
            }
            publish(
                rescanOverflowElements(context: context),
                source: notification == kAXLayoutChangedNotification as String ? .layout : .discovery
            )
            return
        }
        if notification == kAXValueChangedNotification as String {
            guard observedElements.contains(where: { CFEqual($0, element) }) else { return }
            // This is a registered native control, not a topology change.
            // Keep its subscription intact across expand/collapse edges.
            let states = observedElements.map(presentationState(of:))
            #if DEBUG
            let sender = observedElements.firstIndex(where: { CFEqual($0, element) })
            let stateDetail = states.enumerated().map { "\($0.offset)=\($0.element.rawValue)" }.joined(separator: ",")
            debugNotificationHandler?("name=\(notification) sender=\(sender.map(String.init) ?? "none") states=\(stateDetail)")
            #endif
            publish(.observed(states: states, controlIdentifier: controlIdentifier), source: .valueChange)
        }
    }

    private func installWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleActivationSample() }
        })
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ] {
            let token = center.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let application = notification.userInfo?[
                    NSWorkspace.applicationUserInfoKey
                ] as? NSRunningApplication,
                      application.bundleIdentifier == "com.apple.MenuBarAgent" else {
                    return
                }
                let didTerminate = notification.name == NSWorkspace.didTerminateApplicationNotification
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if !self.reconnectOnAgentChange {
                        guard didTerminate,
                              application.processIdentifier == self.observedAgentPID else { return }
                        let onLost = self.agentConnectionLost
                        self.stop()
                        onLost?()
                        return
                    }
                    guard AccessibilityAuthorization.isTrusted else {
                        self.publish(.unavailable)
                        return
                    }
                    self.publish(self.configureForCurrentMenuBarAgent())
                }
            }
            workspaceObservers.append(token)
        }
    }

    private func scheduleActivationSample() {
        guard let context else { return }
        activationSampleTask?.cancel()
        let ticket = activationSample.schedule()
        #if DEBUG
        debugNotificationHandler?("workspace activation sample-scheduled ticket=\(ticket) delayMs=200")
        #endif
        // One coalesced read per external activation, not an immediate read
        // followed by a retry. AX creation/layout events still act immediately.
        activationSampleTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            guard let self, self.context === context,
                  self.activationSample.consume(ticket) else { return }
            self.activationSampleTask = nil
            #if DEBUG
            self.debugNotificationHandler?("workspace activation sample-fired ticket=\(ticket)")
            #endif
            self.sampleCurrentControl()
        }
    }

    private func publish(
        _ snapshot: NativeOverflowObservationSnapshot,
        source: NativeOverflowUpdateSource = .discovery
    ) {
        // A manual sample also cancels stale queued native intent, even when
        // the values are unchanged. Duplicate value notifications are no-ops.
        guard source != .valueChange || lastUpdateSource != .valueChange || snapshot != lastSnapshot else { return }
        lastUpdateSource = source
        lastSnapshot = snapshot
        updateHandler?(snapshot)
    }

    private func discoverOverflowElements(
        applicationElement: AXUIElement,
        context: NativeOverflowObserverContext
    ) -> [AXUIElement]? {
        #if DEBUG
        debugObservationDetails.removeAll()
        #endif
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        var extrasValue: CFTypeRef?
        let extrasError = AXUIElementCopyAttributeValue(
            applicationElement, kAXExtrasMenuBarAttribute as CFString, &extrasValue
        )
        guard extrasError == .success else {
            unavailabilityReason = "extras-root-read-failed-\(extrasError.rawValue)"
            return nil
        }
        guard let extrasValue, CFGetTypeID(extrasValue) == AXUIElementGetTypeID() else {
            unavailabilityReason = "invalid-extras-root"
            return nil
        }
        let root = unsafeDowncast(extrasValue, to: AXUIElement.self)
        guard copyAXString(root, attribute: kAXRoleAttribute as CFString) == "AXMenuBar" else {
            unavailabilityReason = "invalid-extras-root-role"
            return nil
        }
        let currentObserver = observer
        let rootChanged = extrasSubscriptions.update(
            to: root, sameElement: { CFEqual($0, $1) },
            register: { [self] element, name in
                register(element: element, notification: name as CFString,
                         context: context, target: "extras-root")
            },
            unregister: { element, name in
                if let currentObserver { AXObserverRemoveNotification(currentObserver, element, name as CFString) }
            }
        )
        if rootChanged { clearControlRegistrations() }
        if copyAXBool(root, attribute: kAXHiddenAttribute as CFString) == true {
            unavailabilityReason = "extras-root-hidden"
            return nil
        }
        do {
            // Do not enumerate arbitrary application windows alongside the
            // canonical extras root. Read-only evidence found distinct window
            // presentations that otherwise made one menu-bar entry ambiguous.
            let controls = try NativeOverflowTreeDiscovery.discover(
                in: root,
                withinDeadline: { ContinuousClock.now < deadline },
                sameElement: { CFEqual($0, $1) },
                describe: { element in
                    let role = try copyNativeDiscoveryString(element, attribute: kAXRoleAttribute as CFString)
                    guard AccessibilityTraversalPolicy.shouldInclude(role: role, in: .extrasMenuBar) else {
                        return .init(role: role, isOverflowControl: false)
                    }
                    let title = try copyNativeDiscoveryString(element, attribute: kAXTitleAttribute as CFString)
                    let description = try copyNativeDiscoveryString(element, attribute: kAXDescriptionAttribute as CFString)
                    let identifier = try copyNativeDiscoveryString(element, attribute: kAXIdentifierAttribute as CFString)
                    let classification = NativeOverflowClassifier.classify(
                        ownerBundleIdentifier: "com.apple.MenuBarAgent", role: role,
                        title: title, itemDescription: description, accessibilityIdentifier: identifier
                    )
                    let isControl = classification.classification == .nativeOverflowPresentationControl
                    #if DEBUG
                    if isControl {
                        debugObservationDetails.append(
                            "source=extrasMenuBar title=\(title ?? "none")"
                                + " description=\(description ?? "none") identifier=\(identifier ?? "none")"
                        )
                    }
                    #endif
                    return .init(role: role, isOverflowControl: isControl)
                },
                children: { try copyNativeDiscoveryChildren($0) }
            )
            unavailabilityReason = nil
            return controls
        } catch let failure as NativeOverflowTreeDiscovery.Failure {
            unavailabilityReason = failure.rawValue
            return nil
        } catch {
            unavailabilityReason = "native-discovery-failed"
            return nil
        }
    }

    private func presentationState(
        of element: AXUIElement
    ) -> NativeOverflowPresentationState {
        var ownerPID: pid_t = 0
        let ownerResult = AXUIElementGetPid(element, &ownerPID)
        let state = NativeOverflowPresentationStateClassifier.classify(
            title: copyAXString(element, attribute: kAXTitleAttribute as CFString),
            itemDescription: copyAXString(
                element,
                attribute: kAXDescriptionAttribute as CFString
            ),
            accessibilityIdentifier: copyAXString(
                element,
                attribute: kAXIdentifierAttribute as CFString
            )
        )
        return NativeOverflowPresentationStateClassifier.availableState(
            state, enabled: copyAXBool(element, attribute: kAXEnabledAttribute as CFString),
            hidden: copyAXBool(element, attribute: kAXHiddenAttribute as CFString),
            ownerMatches: ownerResult == .success && ownerPID == observedAgentPID
        )
    }
}

fileprivate final class NativeOverflowObserverContext: @unchecked Sendable {
    weak var owner: NativeOverflowObserver?

    init(owner: NativeOverflowObserver) {
        self.owner = owner
    }
}

private func nativeOverflowObserverCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ reference: UnsafeMutableRawPointer?
) {
    guard let reference else { return }
    let context = Unmanaged<NativeOverflowObserverContext>
        .fromOpaque(reference)
        .takeUnretainedValue()
    let event = NativeOverflowNotification(element: element, name: notification as String)
    Task { @MainActor in
        context.owner?.receivedAXNotification(event.name, element: event.element, source: context)
    }
}

/// Retains an opaque immutable CF handle across the C callback hop. All AX
/// access and observer state remain on MainActor; the callback only packages it.
private struct NativeOverflowNotification: @unchecked Sendable {
    let element: AXUIElement
    let name: String
}

private func copyNativeDiscoveryChildren(_ element: AXUIElement) throws -> [AXUIElement] {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
    if result == .noValue || result == .attributeUnsupported { return [] }
    guard result == .success else { throw NativeOverflowTreeDiscovery.Failure.readFailure }
    guard let value else { return [] }
    guard let values = value as? [AXUIElement] else {
        throw NativeOverflowTreeDiscovery.Failure.readFailure
    }
    return values
}

private func copyNativeDiscoveryString(_ element: AXUIElement, attribute: CFString) throws -> String? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute, &value)
    if result == .noValue || result == .attributeUnsupported { return nil }
    guard result == .success else { throw NativeOverflowTreeDiscovery.Failure.readFailure }
    guard let value else { return nil }
    guard let string = value as? String else {
        throw NativeOverflowTreeDiscovery.Failure.readFailure
    }
    return string
}

private func copyAXString(
    _ element: AXUIElement,
    attribute: CFString
) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
        return nil
    }
    return value as? String
}

private func copyAXBool(_ element: AXUIElement, attribute: CFString) -> Bool? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
          let value, CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
    return CFBooleanGetValue(unsafeDowncast(value, to: CFBoolean.self))
}
