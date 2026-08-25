import AppKit
import ApplicationServices
import Foundation

public enum NativeOverflowPresentationState: String, Equatable, Sendable {
    case collapsed
    case expanded
    case unknown
}

public struct NativeOverflowObservationSnapshot: Equatable, Sendable {
    public let isPresent: Bool
    public let presentationState: NativeOverflowPresentationState
    public let observationAvailable: Bool

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
    public typealias UpdateHandler = @MainActor @Sendable (
        NativeOverflowObservationSnapshot
    ) -> Void

    private let messagingTimeoutSeconds: Float
    private var observer: AXObserver?
    private var menuBarAgentElement: AXUIElement?
    private var observedElements: [AXUIElement] = []
    private var runLoopSource: CFRunLoopSource?
    private var context: NativeOverflowObserverContext?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var updateHandler: UpdateHandler?
    private var lastSnapshot: NativeOverflowObservationSnapshot?

    public init(messagingTimeoutSeconds: Float = 0.5) {
        self.messagingTimeoutSeconds = messagingTimeoutSeconds
    }

    @discardableResult
    public func start(
        onUpdate: @escaping UpdateHandler
    ) -> NativeOverflowObservationSnapshot {
        stop()
        updateHandler = onUpdate
        installWorkspaceObservers()

        guard AccessibilityAuthorization.isTrusted else {
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

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        observer = nil
        menuBarAgentElement = nil
        observedElements.removeAll()
        runLoopSource = nil
        context = nil
        updateHandler = nil
        lastSnapshot = nil
    }

    private func configureForCurrentMenuBarAgent() -> NativeOverflowObservationSnapshot {
        detachAXObserver()
        guard let application = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.MenuBarAgent"
        ).first else {
            return .unavailable
        }

        let applicationElement = AXUIElementCreateApplication(
            application.processIdentifier
        )
        guard AXUIElementSetMessagingTimeout(
            applicationElement,
            messagingTimeoutSeconds
        ) == .success else {
            return .unavailable
        }

        var createdObserver: AXObserver?
        guard AXObserverCreate(
            application.processIdentifier,
            nativeOverflowObserverCallback,
            &createdObserver
        ) == .success,
              let createdObserver else {
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
        let elements = discoverOverflowElements(applicationElement: applicationElement)
        observedElements = elements

        for element in elements {
            guard register(
                element: element,
                notification: kAXValueChangedNotification as CFString,
                context: context
            ) else {
                detachAXObserver()
                return .unavailable
            }
            _ = register(
                element: element,
                notification: kAXUIElementDestroyedNotification as CFString,
                context: context
            )
        }

        let states = elements.map(presentationState(of:))
        let state: NativeOverflowPresentationState
        if states.contains(.expanded) {
            state = .expanded
        } else if states.contains(.collapsed) {
            state = .collapsed
        } else {
            state = .unknown
        }
        return NativeOverflowObservationSnapshot(
            isPresent: !elements.isEmpty,
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
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        observer = nil
        menuBarAgentElement = nil
        observedElements.removeAll()
        runLoopSource = nil
        context = nil
    }

    fileprivate func receivedAXNotification(_ notification: String) {
        guard let context else { return }
        if notification == kAXUIElementDestroyedNotification as String
            || notification == kAXLayoutChangedNotification as String {
            publish(rescanOverflowElements(context: context))
            return
        }
        if notification == kAXValueChangedNotification as String {
            publish(rescanOverflowElements(context: context))
        }
    }

    private func installWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
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
                MainActor.assumeIsolated {
                    guard let self, AccessibilityAuthorization.isTrusted else {
                        self?.publish(.unavailable)
                        return
                    }
                    self.publish(self.configureForCurrentMenuBarAgent())
                }
            }
            workspaceObservers.append(token)
        }
    }

    private func publish(_ snapshot: NativeOverflowObservationSnapshot) {
        guard snapshot != lastSnapshot else { return }
        lastSnapshot = snapshot
        updateHandler?(snapshot)
    }

    private func discoverOverflowElements(
        applicationElement: AXUIElement
    ) -> [AXUIElement] {
        var roots: [AXUIElement] = []
        if let extras = copyAXElement(
            from: applicationElement,
            attribute: kAXExtrasMenuBarAttribute as CFString
        ) {
            roots.append(extras)
        }
        roots.append(contentsOf: copyAXElements(
            from: applicationElement,
            attribute: kAXChildrenAttribute as CFString
        ))

        var stack = roots.map { ($0, 0) }
        var visited = Set<CFHashCode>()
        var results: [AXUIElement] = []
        var inspected = 0

        while let (element, depth) = stack.popLast(), inspected < 256 {
            inspected += 1
            guard visited.insert(CFHash(element)).inserted else { continue }
            let role = copyAXString(element, attribute: kAXRoleAttribute as CFString)
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
            guard depth < 8 else { continue }
            for child in copyAXElements(
                from: element,
                attribute: kAXChildrenAttribute as CFString
            ).reversed() {
                stack.append((child, depth + 1))
            }
        }
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

private final class NativeOverflowObserverContext: @unchecked Sendable {
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
    let notificationName = notification as String
    Task { @MainActor in
        context.owner?.receivedAXNotification(notificationName)
    }
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
