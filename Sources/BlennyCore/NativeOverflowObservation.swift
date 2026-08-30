import AppKit
import ApplicationServices
import Foundation

public enum NativeOverflowPresentationState: String, Equatable, Sendable {
    case collapsed
    case expanded
    case unknown
}

public enum NativeOverflowUpdateSource: String, Sendable {
    case discovery, sample, valueChange
}

public struct NativeOverflowObservationSnapshot: Equatable, Sendable {
    public let isPresent: Bool
    public let presentationState: NativeOverflowPresentationState
    public let observationAvailable: Bool

    public var isUsable: Bool {
        isPresent && observationAvailable && presentationState != .unknown
    }

    public init(
        isPresent: Bool,
        presentationState: NativeOverflowPresentationState,
        observationAvailable: Bool
    ) {
        self.isPresent = isPresent
        self.presentationState = presentationState
        self.observationAvailable = observationAvailable
    }

    public static let unavailable = NativeOverflowObservationSnapshot(
        isPresent: false,
        presentationState: .unknown,
        observationAvailable: false
    )
}

public enum NativeOverflowPresentationStateClassifier {
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
        let searchable = [title, itemDescription, accessibilityIdentifier]
            .compactMap(MenuBarItemIdentityResolver.normalize)
            .joined(separator: " ")
        if collapsedMarkers.contains(where: searchable.contains) {
            return .collapsed
        }
        if expandedMarkers.contains(where: searchable.contains) {
            return .expanded
        }
        return .unknown
    }
}

@MainActor
public final class NativeOverflowObserver {
    public private(set) var isSamplingCurrentControl = false
    public private(set) var lastUpdateSource = NativeOverflowUpdateSource.discovery
    public private(set) var unavailabilityReason: String?
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
    private var runLoopSource: CFRunLoopSource?
    private var context: NativeOverflowObserverContext?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var updateHandler: UpdateHandler?
    private var lastSnapshot: NativeOverflowObservationSnapshot?

    public init(messagingTimeoutSeconds: Float = 0.1, reconnectOnAgentChange: Bool = true) {
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
    }

    /// One read after an explicit action or an app-activation event discovers a
    /// newly created control even when container layout notifications are absent.
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

        // MenuBarAgent does not promise container-level layout notifications.
        // Register opportunistically; direct value observation remains usable
        // when this notification is unsupported on the current build.
        _ = register(
            element: applicationElement,
            notification: kAXLayoutChangedNotification as CFString,
            context: context
        )
        return rescanOverflowElements(context: context)
    }

    private func rescanOverflowElements(
        context: NativeOverflowObserverContext
    ) -> NativeOverflowObservationSnapshot {
        guard let applicationElement = menuBarAgentElement else { return .unavailable }
        guard let elements = discoverOverflowElements(applicationElement: applicationElement) else {
            detachAXObserver()
            return .unavailable
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
                detachAXObserver()
                return .unavailable
            }
            _ = register(
                element: element,
                notification: kAXUIElementDestroyedNotification as CFString,
                context: context
            )
        }
        observedElements = elements
        return snapshotOfObservedElements()
    }

    private func snapshotOfObservedElements() -> NativeOverflowObservationSnapshot {
        let states = observedElements.map(presentationState(of:))
        let state: NativeOverflowPresentationState
        if states.contains(.expanded) {
            state = .expanded
        } else if states.contains(.collapsed) {
            state = .collapsed
        } else {
            state = .unknown
        }
        return NativeOverflowObservationSnapshot(
            isPresent: !observedElements.isEmpty,
            presentationState: state,
            observationAvailable: true
        )
    }

    private func register(
        element: AXUIElement,
        notification: CFString,
        context: NativeOverflowObserverContext
    ) -> Bool {
        guard let observer else { return false }
        let result = AXObserverAddNotification(
            observer,
            element,
            notification,
            Unmanaged.passUnretained(context).toOpaque()
        )
        return result == .success || result == .notificationAlreadyRegistered
    }

    private func detachAXObserver() {
        context?.owner = nil
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        observer = nil
        menuBarAgentElement = nil
        observedElements.removeAll()
        runLoopSource = nil
        context = nil
    }

    fileprivate func receivedAXNotification(
        _ notification: String, element: AXUIElement, source: NativeOverflowObserverContext
    ) {
        guard let context, context === source else { return }
        if notification == kAXUIElementDestroyedNotification as String
            || notification == kAXLayoutChangedNotification as String {
            publish(rescanOverflowElements(context: context))
            return
        }
        if notification == kAXValueChangedNotification as String {
            guard observedElements.contains(where: { CFEqual($0, element) }) else { return }
            // This is a registered native control, not a topology change.
            // Keep its subscription intact across expand/collapse edges.
            publish(snapshotOfObservedElements(), source: .valueChange)
        }
    }

    private func installWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.sampleCurrentControl() }
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

    private func publish(
        _ snapshot: NativeOverflowObservationSnapshot,
        source: NativeOverflowUpdateSource = .discovery
    ) {
        guard snapshot != lastSnapshot else { return }
        lastUpdateSource = source
        lastSnapshot = snapshot
        updateHandler?(snapshot)
    }

    private func discoverOverflowElements(
        applicationElement: AXUIElement
    ) -> [AXUIElement]? {
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        var roots: [(AXUIElement, Int, AccessibilityTraversalScope)] = []
        if let extras = copyAXElement(
            from: applicationElement,
            attribute: kAXExtrasMenuBarAttribute as CFString
        ) {
            roots.append((extras, 0, .extrasMenuBar))
        }
        let applicationChildren = copyAXElements(
            from: applicationElement,
            attribute: kAXChildrenAttribute as CFString
        )
        guard applicationChildren.count <= 256 else {
            unavailabilityReason = "traversal-root-limit"
            return nil
        }
        for child in applicationChildren {
            guard ContinuousClock.now < deadline else {
                unavailabilityReason = "traversal-deadline"
                return nil
            }
            let role = copyAXString(child, attribute: kAXRoleAttribute as CFString)
            guard role == "AXWindow" || role == "AXMenuBar" else { continue }
            guard AccessibilityTraversalPolicy.isMenuBarPresentationRoot(
                role: role, frame: nativePresentationExtent(of: child)
            ) else { continue }
            roots.append((child, 0, .agentPresentationRoot))
        }

        var stack = roots
        var visited = Set<CFHashCode>()
        var results: [AXUIElement] = []
        var inspected = 0

        while let (element, depth, scope) = stack.popLast(), inspected < 256 {
            guard ContinuousClock.now < deadline else {
                unavailabilityReason = "traversal-deadline"
                return nil
            }
            inspected += 1
            guard visited.insert(CFHash(element)).inserted else { continue }
            let role = copyAXString(element, attribute: kAXRoleAttribute as CFString)
            guard AccessibilityTraversalPolicy.shouldInclude(role: role, in: scope) else { continue }
            let title = copyAXString(element, attribute: kAXTitleAttribute as CFString)
            let description = copyAXString(
                element,
                attribute: kAXDescriptionAttribute as CFString
            )
            let identifier = copyAXString(
                element,
                attribute: kAXIdentifierAttribute as CFString
            )
            let classification = NativeOverflowClassifier.classify(
                ownerBundleIdentifier: "com.apple.MenuBarAgent",
                role: role,
                title: title,
                itemDescription: description,
                accessibilityIdentifier: identifier
            )
            if classification.classification == .nativeOverflowPresentationControl {
                results.append(element)
                continue
            }
            guard AccessibilityTraversalPolicy.shouldTraverseChildren(
                of: role, at: depth, in: scope
            ) else { continue }
            for child in copyAXElements(
                from: element,
                attribute: kAXChildrenAttribute as CFString
            ).reversed() {
                stack.append((child, depth + 1, scope))
            }
        }
        guard stack.isEmpty else {
            unavailabilityReason = "traversal-element-limit"
            return nil
        }
        unavailabilityReason = nil
        return results
    }

    private func presentationState(
        of element: AXUIElement
    ) -> NativeOverflowPresentationState {
        NativeOverflowPresentationStateClassifier.classify(
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
    }
}

/// Only size is needed to reuse the inventory's presentation-root boundary.
/// No position, content pixels, or application-menu subtree is inspected.
private func nativePresentationExtent(of element: AXUIElement) -> RectSnapshot? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success,
          let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var size = CGSize.zero
    guard AXValueGetValue(unsafeDowncast(value, to: AXValue.self), .cgSize, &size) else { return nil }
    return RectSnapshot(x: 0, y: 0, width: size.width, height: size.height)
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

private func copyAXElement(
    from element: AXUIElement,
    attribute: CFString
) -> AXUIElement? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
          let value,
          CFGetTypeID(value) == AXUIElementGetTypeID() else {
        return nil
    }
    return unsafeDowncast(value, to: AXUIElement.self)
}

private func copyAXElements(
    from element: AXUIElement,
    attribute: CFString
) -> [AXUIElement] {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
          let values = value as? [AnyObject] else {
        return []
    }
    return values.compactMap { value in
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }
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
