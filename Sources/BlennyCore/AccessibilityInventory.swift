import ApplicationServices
import Foundation

public actor AccessibilityInventory {
    private let maximumElementsPerRefresh: Int
    private let maximumDurationMilliseconds: Int
    private let maximumDurationNanoseconds: UInt64
    private let messagingTimeoutSeconds: Float
    private let rootMessagingTimeoutSeconds: Float

    public init(
        maximumElementsPerRefresh: Int = 1_024,
        maximumDurationMilliseconds: Int = 5_000,
        messagingTimeoutSeconds: Float = 0.5,
        rootMessagingTimeoutSeconds: Float = 0.5
    ) {
        self.maximumElementsPerRefresh = max(1, maximumElementsPerRefresh)
        self.maximumDurationMilliseconds = max(1, maximumDurationMilliseconds)
        self.maximumDurationNanoseconds = UInt64(self.maximumDurationMilliseconds) * 1_000_000
        self.messagingTimeoutSeconds = max(0.1, messagingTimeoutSeconds)
        self.rootMessagingTimeoutSeconds = max(0.1, rootMessagingTimeoutSeconds)
    }

    public func capture(
        applications: [RunningApplicationDescriptor],
        accessibilityTrusted: Bool,
        includeMenuBarAgentPresentationRoots: Bool = true,
        environment: RuntimeEnvironment = .current()
    ) -> DiagnosticReport {
        let startedAt = DispatchTime.now().uptimeNanoseconds
        var notes = [
            "Read-only capture: no Accessibility attribute or system preference was changed.",
            "Scope is limited to AXExtrasMenuBar trees and MenuBarAgent; titles, descriptions, help, and identifiers are truncated to 256 characters.",
            "The report excludes process names, window contents, file paths, images, and unrelated Accessibility trees."
        ]

        guard accessibilityTrusted else {
            notes.append("Accessibility permission is not granted. Use the explicit Request Access control, enable Blenny in System Settings, then refresh manually.")
            return DiagnosticReport(
                generatedAt: Date(),
                environment: environment,
                accessibilityTrusted: false,
                durationMilliseconds: elapsedMilliseconds(since: startedAt),
                runningApplicationsChecked: 0,
                extrasMenuBarTreesFound: 0,
                menuBarAgentProcessesFound: 0,
                elementLimitReached: false,
                timeLimitReached: false,
                aggregateErrors: [:],
                notes: notes,
                items: []
            )
        }

        var aggregateErrors: [String: Int] = [:]
        var runningApplicationsChecked = 0
        var extrasMenuBarTreesFound = 0
        var menuBarAgentProcessesFound = 0
        var observations: [ElementObservation] = []
        var discoveries: [ApplicationMenuBarDiscovery] = []
        var visitedElements = Set<ElementVisitKey>()
        var elementLimitReached = false
        var timeLimitReached = false

        for application in applications {
            guard !hasExceededTimeLimit(since: startedAt) else {
                timeLimitReached = true
                break
            }
            guard observations.count < maximumElementsPerRefresh else {
                elementLimitReached = true
                break
            }

            runningApplicationsChecked += 1
            let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
            // The first cross-process AX request can take longer than leaf reads.
            // Give that one read 500 ms by default; never retry a failed root.
            let timeoutError = AXUIElementSetMessagingTimeout(applicationElement, rootMessagingTimeoutSeconds)
            if timeoutError != .success {
                increment(error: timeoutError, in: &aggregateErrors)
            }
            let normalizedBundleIdentifier = MenuBarItemIdentityResolver.normalize(application.bundleIdentifier)
            let isMenuBarAgent = normalizedBundleIdentifier == NativeOverflowClassifier.menuBarAgentBundleIdentifier
            if isMenuBarAgent {
                menuBarAgentProcessesFound += 1
            }

            let extrasResult = copyAttribute(applicationElement, name: kAXExtrasMenuBarAttribute as CFString)
            let root = axElement(from: extrasResult.value)
            let observationStart = observations.count
            AXUIElementSetMessagingTimeout(applicationElement, messagingTimeoutSeconds)
            if extrasResult.error == .success,
               let extrasMenuBar = root {
                extrasMenuBarTreesFound += 1
                traverse(
                    root: extrasMenuBar,
                    owner: application,
                    source: isMenuBarAgent ? .menuBarAgent : .applicationExtrasMenuBar,
                    scope: .extrasMenuBar,
                    startedAt: startedAt,
                    observations: &observations,
                    visitedElements: &visitedElements,
                    elementLimitReached: &elementLimitReached,
                    timeLimitReached: &timeLimitReached,
                    aggregateErrors: &aggregateErrors
                )
            } else if extrasResult.error != .attributeUnsupported && extrasResult.error != .noValue {
                increment(error: extrasResult.error, in: &aggregateErrors)
            }
            discoveries.append(ApplicationMenuBarDiscovery(
                application: application, rootReadResult: extrasResult.error.rawValue,
                hasValidRoot: root != nil,
                observationCount: observations.count - observationStart
            ))

            guard isMenuBarAgent, includeMenuBarAgentPresentationRoots else { continue }

            let childResult = copyAttribute(applicationElement, name: kAXChildrenAttribute as CFString)
            if childResult.error == .success {
                for child in axElements(from: childResult.value) {
                    let childRole = copySanitizedString(child, name: kAXRoleAttribute as CFString)
                    guard AccessibilityTraversalPolicy.isMenuBarPresentationRoot(
                        role: childRole,
                        frame: frame(of: child)
                    ) else { continue }
                    traverse(
                        root: child,
                        owner: application,
                        source: .menuBarAgent,
                        scope: .agentPresentationRoot,
                        startedAt: startedAt,
                        observations: &observations,
                        visitedElements: &visitedElements,
                        elementLimitReached: &elementLimitReached,
                        timeLimitReached: &timeLimitReached,
                        aggregateErrors: &aggregateErrors
                    )
                    if elementLimitReached || timeLimitReached { break }
                }
            } else if childResult.error != .attributeUnsupported && childResult.error != .noValue {
                increment(error: childResult.error, in: &aggregateErrors)
            }
        }

        if menuBarAgentProcessesFound == 0 {
            notes.append("No running process with bundle identifier com.apple.MenuBarAgent was visible through NSWorkspace during this refresh.")
        }
        if elementLimitReached {
            notes.append("The bounded element limit was reached; the report is intentionally truncated instead of retrying or polling.")
        }
        if timeLimitReached {
            notes.append("The \(maximumDurationMilliseconds)-millisecond wall-clock budget was reached; the report is intentionally partial and no retry was attempted.")
        }

        assignStableIdentities(to: &observations)

        return DiagnosticReport(
            generatedAt: Date(),
            environment: environment,
            accessibilityTrusted: true,
            durationMilliseconds: elapsedMilliseconds(since: startedAt),
            runningApplicationsChecked: runningApplicationsChecked,
            extrasMenuBarTreesFound: extrasMenuBarTreesFound,
            menuBarAgentProcessesFound: menuBarAgentProcessesFound,
            elementLimitReached: elementLimitReached,
            timeLimitReached: timeLimitReached,
            aggregateErrors: aggregateErrors,
            notes: notes,
            items: observations.map(\.record),
            applicationDiscoveries: discoveries
        )
    }

    private func traverse(
        root: AXUIElement,
        owner: RunningApplicationDescriptor,
        source: AccessibilityTreeSource,
        scope: AccessibilityTraversalScope,
        startedAt: UInt64,
        observations: inout [ElementObservation],
        visitedElements: inout Set<ElementVisitKey>,
        elementLimitReached: inout Bool,
        timeLimitReached: inout Bool,
        aggregateErrors: inout [String: Int]
    ) {
        var stack: [(element: AXUIElement, depth: Int)] = [(root, 0)]

        while let current = stack.popLast() {
            guard !hasExceededTimeLimit(since: startedAt) else {
                timeLimitReached = true
                return
            }
            guard observations.count < maximumElementsPerRefresh else {
                elementLimitReached = true
                return
            }

            let visitKey = ElementVisitKey(
                processIdentifier: owner.processIdentifier,
                accessibilityHash: CFHash(current.element)
            )
            guard visitedElements.insert(visitKey).inserted else { continue }

            let role = copySanitizedString(current.element, name: kAXRoleAttribute as CFString)
            guard AccessibilityTraversalPolicy.shouldInclude(role: role, in: scope) else { continue }
            let subrole = copySanitizedString(current.element, name: kAXSubroleAttribute as CFString)
            let title = copySanitizedString(current.element, name: kAXTitleAttribute as CFString)
            let itemDescription = copySanitizedString(current.element, name: kAXDescriptionAttribute as CFString)
            let itemHelp = copySanitizedString(current.element, name: kAXHelpAttribute as CFString)
            let accessibilityIdentifier = copySanitizedString(current.element, name: kAXIdentifierAttribute as CFString)
            let positionResult = copyAttribute(current.element, name: kAXPositionAttribute as CFString)
            let sizeResult = copyAttribute(current.element, name: kAXSizeAttribute as CFString)
            let position = attributeDiagnostic(
                current.element,
                name: kAXPositionAttribute as CFString,
                readResult: positionResult
            )
            let size = attributeDiagnostic(
                current.element,
                name: kAXSizeAttribute as CFString,
                readResult: sizeResult
            )
            let hidden = attributeDiagnostic(current.element, name: kAXHiddenAttribute as CFString)
            let classification = NativeOverflowClassifier.classify(
                ownerBundleIdentifier: owner.bundleIdentifier,
                role: role,
                title: title,
                itemDescription: itemDescription,
                accessibilityIdentifier: accessibilityIdentifier
            )

            let observationKey = "\(owner.processIdentifier):\(visitKey.accessibilityHash)"
            observations.append(
                ElementObservation(
                    observationKey: observationKey,
                    record: MenuBarItemRecord(
                        source: source,
                        ownerPID: owner.processIdentifier,
                        ownerBundleIdentifier: owner.bundleIdentifier,
                        depth: current.depth,
                        role: role,
                        subrole: subrole,
                        title: title,
                        itemDescription: itemDescription,
                        itemHelp: itemHelp,
                        accessibilityIdentifier: accessibilityIdentifier,
                        frame: frame(
                            positionValue: positionResult.value,
                            sizeValue: sizeResult.value
                        ),
                        actions: actionNames(of: current.element, aggregateErrors: &aggregateErrors),
                        hiddenAttribute: hidden,
                        positionAttribute: position,
                        sizeAttribute: size,
                        classification: classification.classification,
                        classificationReason: classification.reason
                    )
                )
            )

            guard AccessibilityTraversalPolicy.shouldTraverseChildren(
                of: role,
                at: current.depth,
                in: scope
            ) else { continue }

            let childResult = copyAttribute(current.element, name: kAXChildrenAttribute as CFString)
            if childResult.error == .success {
                let children = axElements(from: childResult.value)
                for child in children.reversed() {
                    stack.append((child, current.depth + 1))
                }
            } else if childResult.error != .attributeUnsupported && childResult.error != .noValue {
                increment(error: childResult.error, in: &aggregateErrors)
            }
        }
    }

    private func hasExceededTimeLimit(since startedAt: UInt64) -> Bool {
        DispatchTime.now().uptimeNanoseconds - startedAt >= maximumDurationNanoseconds
    }

    private func assignStableIdentities(to observations: inout [ElementObservation]) {
        let candidates = observations.compactMap { observation -> MenuBarItemIdentityCandidate? in
            guard observation.record.classification == .manageableCandidate else { return nil }
            return MenuBarItemIdentityCandidate(
                observationKey: observation.observationKey,
                ownerBundleIdentifier: observation.record.ownerBundleIdentifier,
                accessibilityIdentifier: observation.record.accessibilityIdentifier,
                title: observation.record.title,
                itemDescription: observation.record.itemDescription,
                role: observation.record.role,
                subrole: observation.record.subrole
            )
        }
        let resolved = Dictionary(
            uniqueKeysWithValues: MenuBarItemIdentityResolver.resolve(candidates).map {
                ($0.observationKey, $0.identity)
            }
        )

        for index in observations.indices {
            observations[index].record.identity = resolved[observations[index].observationKey]
        }
    }
}

private struct ElementObservation {
    let observationKey: String
    var record: MenuBarItemRecord
}

private struct ElementVisitKey: Hashable {
    let processIdentifier: Int32
    let accessibilityHash: CFHashCode
}

private struct AttributeCopyResult {
    let value: CFTypeRef?
    let error: AXError
}

private func copyAttribute(_ element: AXUIElement, name: CFString) -> AttributeCopyResult {
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(element, name, &value)
    return AttributeCopyResult(value: value, error: error)
}

private func copySanitizedString(_ element: AXUIElement, name: CFString) -> String? {
    let result = copyAttribute(element, name: name)
    guard result.error == .success, let string = result.value as? String else { return nil }

    let printableString = string.unicodeScalars.map { scalar -> String in
        let isDisallowedControl = CharacterSet.controlCharacters.contains(scalar)
            && !CharacterSet.whitespacesAndNewlines.contains(scalar)
        return isDisallowedControl ? "�" : String(scalar)
    }.joined()
    let collapsed = printableString
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    return collapsed.isEmpty ? nil : String(collapsed.prefix(256))
}

private func axElement(from value: CFTypeRef?) -> AXUIElement? {
    guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return unsafeDowncast(value, to: AXUIElement.self)
}

private func axElements(from value: CFTypeRef?) -> [AXUIElement] {
    guard let values = value as? [AnyObject] else { return [] }
    return values.compactMap { value in
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }
}

private func frame(of element: AXUIElement) -> RectSnapshot? {
    let positionResult = copyAttribute(element, name: kAXPositionAttribute as CFString)
    let sizeResult = copyAttribute(element, name: kAXSizeAttribute as CFString)
    return frame(positionValue: positionResult.value, sizeValue: sizeResult.value)
}

private func frame(positionValue: CFTypeRef?, sizeValue: CFTypeRef?) -> RectSnapshot? {
    guard let point = point(from: positionValue),
          let size = size(from: sizeValue) else {
        return nil
    }
    return RectSnapshot(
        x: Double(point.x),
        y: Double(point.y),
        width: Double(size.width),
        height: Double(size.height)
    )
}

private func point(from value: CFTypeRef?) -> CGPoint? {
    guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    let axValue = unsafeDowncast(value, to: AXValue.self)
    guard AXValueGetType(axValue) == .cgPoint else { return nil }
    var point = CGPoint.zero
    return AXValueGetValue(axValue, .cgPoint, &point) ? point : nil
}

private func size(from value: CFTypeRef?) -> CGSize? {
    guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    let axValue = unsafeDowncast(value, to: AXValue.self)
    guard AXValueGetType(axValue) == .cgSize else { return nil }
    var size = CGSize.zero
    return AXValueGetValue(axValue, .cgSize, &size) ? size : nil
}

private func attributeDiagnostic(
    _ element: AXUIElement,
    name: CFString,
    readResult: AttributeCopyResult? = nil
) -> AXAttributeDiagnostic {
    let readResult = readResult ?? copyAttribute(element, name: name)
    var settable = DarwinBoolean(false)
    let settableError = AXUIElementIsAttributeSettable(element, name, &settable)

    return AXAttributeDiagnostic(
        value: readResult.error == .success ? summarizeAXValue(readResult.value) : nil,
        readResult: describe(readResult.error),
        isSettable: settableError == .success ? settable.boolValue : nil,
        settableResult: describe(settableError)
    )
}

private func summarizeAXValue(_ value: CFTypeRef?) -> String? {
    guard let value else { return nil }

    if let string = value as? String {
        return String(string.prefix(256))
    }
    if let number = value as? NSNumber {
        return number.stringValue
    }
    if let point = point(from: value) {
        return "{x:\(Double(point.x)), y:\(Double(point.y))}"
    }
    if let size = size(from: value) {
        return "{width:\(Double(size.width)), height:\(Double(size.height))}"
    }
    return "CFTypeID:\(CFGetTypeID(value))"
}

private func actionNames(
    of element: AXUIElement,
    aggregateErrors: inout [String: Int]
) -> [String] {
    var names: CFArray?
    let error = AXUIElementCopyActionNames(element, &names)
    guard error == .success else {
        if error != .actionUnsupported && error != .noValue {
            increment(error: error, in: &aggregateErrors)
        }
        return []
    }
    return (names as? [String] ?? [])
        .compactMap(sanitizeActionName)
        .sorted()
}

func sanitizeActionName(_ name: String) -> String? {
    guard let firstLine = name.components(separatedBy: .newlines).first else { return nil }
    let normalized = firstLine
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    return normalized.isEmpty ? nil : String(normalized.prefix(128))
}

private func describe(_ error: AXError) -> String {
    error == .success ? "success" : "AXError(\(error.rawValue))"
}

private func increment(error: AXError, in aggregateErrors: inout [String: Int]) {
    aggregateErrors[describe(error), default: 0] += 1
}

private func elapsedMilliseconds(since startedAt: UInt64) -> Int {
    let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
    return Int(elapsed / 1_000_000)
}
