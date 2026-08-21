import AppKit
import Testing

private final class ExpandedInterfaceDelegateProbe: NSObject, NSStatusItemExpandedInterfaceDelegate {
    func statusItem(
        _ statusItem: NSStatusItem,
        didBegin expandedInterfaceSession: NSStatusItemExpandedInterfaceSession
    ) {}

    func statusItemDidEndExpandedInterfaceSession(
        _ statusItem: NSStatusItem,
        animated: Bool
    ) {}
}

@Suite("macOS 27 public status-item API")
struct MacOS27StatusItemAPITests {
    @Test("expanded-interface delegate surface compiles with SDK 27")
    func expandedInterfaceDelegateSurfaceCompiles() {
        let delegate = ExpandedInterfaceDelegateProbe()
        let protocolValue: any NSStatusItemExpandedInterfaceDelegate = delegate

        #expect(protocolValue is ExpandedInterfaceDelegateProbe)
    }

    private func compileExpandedInterfaceOperations(
        statusItem: NSStatusItem,
        delegate: ExpandedInterfaceDelegateProbe
    ) {
        statusItem.expandedInterfaceDelegate = delegate
        statusItem.expandedInterfaceSession?.cancel()
    }
}
