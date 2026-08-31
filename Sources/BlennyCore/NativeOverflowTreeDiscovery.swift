/// Discover controls only inside the caller's canonical AXExtrasMenuBar root.
/// Other MenuBarAgent windows are intentionally not discovery roots: a second
/// presentation window is not evidence of another usable menu-bar entry.
enum NativeOverflowTreeDiscovery {
    struct Description {
        let role: String?
        let isOverflowControl: Bool
    }

    enum Failure: String, Error {
        case deadline = "traversal-deadline"
        case elementLimit = "traversal-element-limit"
        case depthLimit = "traversal-depth-limit"
        case readFailure = "traversal-read-failed"
    }

    static func discover<Node>(
        in root: Node,
        maximumElements: Int = 256,
        withinDeadline: () -> Bool,
        sameElement: (Node, Node) -> Bool,
        describe: (Node) throws -> Description,
        children: (Node) throws -> [Node]
    ) throws -> [Node] {
        var stack = [(root, 0)]
        var visited: [Node] = []
        var controls: [Node] = []
        var inspected = 0
        while let (element, depth) = stack.popLast() {
            guard withinDeadline() else { throw Failure.deadline }
            guard inspected < maximumElements else { throw Failure.elementLimit }
            inspected += 1
            guard !visited.contains(where: { sameElement($0, element) }) else { continue }
            visited.append(element)
            let description = try describe(element)
            guard description.role != nil else { throw Failure.readFailure }
            guard AccessibilityTraversalPolicy.shouldInclude(
                role: description.role, in: .extrasMenuBar
            ) else { continue }
            if description.isOverflowControl {
                controls.append(element)
                continue
            }
            // Buttons and application menus are terminal; unrelated menu trees
            // must not consume the bounded native-control scan.
            guard description.role != "AXButton", description.role != "AXMenuBarItem" else { continue }
            guard depth < 8 else { throw Failure.depthLimit }
            let descendants = try children(element)
            guard descendants.count <= maximumElements,
                  stack.count + descendants.count <= maximumElements else { throw Failure.elementLimit }
            stack.append(contentsOf: descendants.reversed().map { ($0, depth + 1) })
        }
        guard withinDeadline() else { throw Failure.deadline }
        return controls
    }
}
