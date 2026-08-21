# macOS 27 Menu Bar Public API Research

Date: 2026-08-21

## Scope

This review looks only at Apple-published material relevant to menu bar and status-item behavior. It does not rely on Ice, Thaw, reverse-engineered implementation code, third-party binaries, or private framework headers.

Sources reviewed:

- Apple macOS 27 release notes and AppKit update index.
- Apple AppKit and Application Services API documentation.
- Apple WWDC26 AppKit sessions and transcripts.
- Apple Support documentation for menu bar settings.
- The AppKit headers in the locally installed macOS 26.5 SDK, used only as a pre-27 comparison baseline.

The test Mac runs macOS 27.0, but its installed Xcode contains only the macOS 26.5 SDK. Consequently, API declarations newly shipped in the macOS 27 SDK cannot yet be compiled locally. Conclusions below distinguish direct Apple documentation from inferences that still need confirmation against Xcode 27 headers.

## Confirmed macOS 27 status-item API

Apple introduced a public expanded-interface lifecycle for custom `NSStatusItem` UI:

- `NSStatusItem.expandedInterfaceDelegate`
- `NSStatusItem.expandedInterfaceSession`
- `NSStatusItemExpandedInterfaceDelegate`
- `NSStatusItemExpandedInterfaceSession`
- `NSStatusItemExpandedInterfaceSession.cancel()`

Apple's WWDC26 guidance says a status item that opens a custom window should use this lifecycle so AppKit knows when the expanded interface is active and can manage keyboard focus correctly. The delegate receives begin and end callbacks; the app shows or dismisses its window in those callbacks and requests dismissal by cancelling the session.

This API is important for Blenny's own status item and any future custom popover or window. It does not enumerate, hide, reorder, or otherwise control another application's item.

Official references:

- [Modernize your AppKit app](https://developer.apple.com/videos/play/wwdc2026/289/)
- [NSStatusItemExpandedInterfaceDelegate](https://developer.apple.com/documentation/appkit/nsstatusitemexpandedinterfacedelegate)
- [NSStatusItemExpandedInterfaceSession](https://developer.apple.com/documentation/appkit/nsstatusitemexpandedinterfacesession)
- [expandedInterfaceDelegate](https://developer.apple.com/documentation/appkit/nsstatusitem/expandedinterfacedelegate)
- [expandedInterfaceSession](https://developer.apple.com/documentation/appkit/nsstatusitem/expandedinterfacesession)

## Status-item API surface that appears revised

The local macOS 26.5 `NSStatusItem.h` marks direct `view`, `target`, and `action` access on `NSStatusItem` as deprecated and recommends using the standard status-bar button instead. Apple's current documentation now lists:

- `view` under active appearance configuration;
- `target` and `action` under active target-action configuration;
- only `doubleAction` and older drawing/menu helpers in the corresponding deprecated group.

WWDC26 also explicitly instructs apps with a custom status-item view to set the view on the status item and add target-action behavior to the status item so keyboard activation works.

This is strong evidence that the macOS 27 SDK revises or undeprecates these declarations as part of the new managed interaction model. It remains an inference until Xcode 27 is installed and its headers and availability annotations are inspected. Blenny must not add conditional declarations or private symbol lookups to bypass the missing SDK.

Official references:

- [NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem)
- [NSStatusItem.view](https://developer.apple.com/documentation/appkit/nsstatusitem/view)
- [NSStatusItem.target](https://developer.apple.com/documentation/appkit/nsstatusitem/target)
- [NSStatusItem.action](https://developer.apple.com/documentation/appkit/nsstatusitem/action)
- [Modernize your AppKit app](https://developer.apple.com/videos/play/wwdc2026/289/)

## Public behavior changes relevant to Blenny

### Keyboard navigation and custom expanded UI

Apple now documents keyboard navigation across status items. A normal status-item button's action fires when the user presses Return during keyboard navigation. Custom expanded UI should participate through the expanded-interface session instead of independently guessing when its window should open, receive focus, or close.

This supports an AppKit-first Phase B design: keep Blenny's status item native, use its button and menu for the 0.0.1 probe, and adopt the new session API only after the macOS 27 SDK is available.

### Menu item images

macOS 27 presents a reduced set of images in menu bar menus and context menus. SwiftUI hides most symbol images there by default unless the app opts into title-and-icon presentation. This concerns commands in menus, not status-item ownership, overflow priority, or cross-process management.

Official reference: [macOS 27 Golden Gate Beta Release Notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes)

### System-level menu bar settings

Apple Support documents a dedicated Menu Bar settings pane, including an "Allow in the Menu Bar" section for applications that provide menu bar items. This is user-facing system policy. No public developer API was located for reading or changing those per-application switches.

Official reference: [Change Menu Bar settings on Mac](https://support.apple.com/guide/mac-help/change-menu-bar-settings-mchlad96d366/mac)

## Public APIs that remain insufficient

The reviewed public surface still exposes only ownership-scoped status-item operations:

- `NSStatusBar.statusItem(withLength:)` creates an item owned by the calling app.
- `NSStatusBar.removeStatusItem(_:)` removes an item owned by the calling app.
- `NSStatusItem.length`, `menu`, `button`, `behavior`, `isVisible`, and `autosaveName` configure the calling app's item.

`NSStatusItem.isVisible` is specifically documented to remain `true` when the item is temporarily hidden because the menu bar has insufficient space. It therefore cannot serve as a public native-overflow signal, even for Blenny's own item.

The public Accessibility API still provides the generic `AXUIElement` functions and the longstanding `kAXExtrasMenuBarAttribute`. In the Apple material reviewed, no macOS 27-specific Accessibility attribute, notification, action, or identity type was added for:

- enumerating every hosted status item as a first-class public model;
- identifying the native overflow control;
- observing per-display overflow state;
- reading or changing item priority or preferred trailing position;
- hiding, moving, or reordering another application's status item.

Official references:

- [NSStatusBar](https://developer.apple.com/documentation/appkit/nsstatusbar)
- [NSStatusItem.isVisible](https://developer.apple.com/documentation/appkit/nsstatusitem/isvisible)
- [AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement)
- [kAXExtrasMenuBarAttribute](https://developer.apple.com/documentation/applicationservices/kaxextrasmenubarattribute)

## No public `MenuBarAgent` management contract found

No public Apple developer documentation, SDK symbol, entitlement, or supported service named `MenuBarAgent` was located in the sources reviewed. The running process and its Accessibility presentation tree are observable system behavior, but they are not a public management API.

Accordingly:

- Blenny may treat the Agent process and its Accessibility tree as version-sensitive diagnostic evidence.
- Blenny must not treat labels, tree shape, process lifetime, private preference keys, XPC interfaces, or hosted-control ordering as a stable contract.
- Native overflow detection must remain conservative and read-only until repeated live tests establish useful behavior.
- Preferred trailing position work remains unsupported research and must stay behind the Phase C Debug/dry-run boundary.

## Implications for the spike

1. Phase A remains necessary. Apple has not provided a public cross-application status-item inventory or overflow API, so bounded Accessibility observation is still the only public mechanism located for the read-only probe.
2. Phase B should use `NSStatusItem` exactly as a native owned item. Once Xcode 27 is installed, add a small compile-and-runtime probe for the expanded-interface session and keyboard navigation; do not emulate its behavior with mouse events.
3. A public-API-only path does not currently satisfy the product requirement to prioritize other applications' items. Phase C cannot be justified as public API work based on this review.
4. The new expanded-interface API is evidence of a more system-managed status-item interaction lifecycle, but it is not evidence that third-party layout control is feasible.
5. The next tooling prerequisite is Xcode 27 with the macOS 27 SDK. Until then, Blenny can run on macOS 27 but cannot accurately compile-test the newly documented status-item API.

## Current conclusion

Apple added a meaningful public API for lifecycle and focus management of an app's own expanded status-item UI. Apple did not publish a corresponding API for global item enumeration, native overflow observation, or cross-application priority control in the material reviewed.

This narrows the differentiated engineering path rather than proving it: use the new public lifecycle for Blenny's own control, keep discovery in a bounded Accessibility backend, and treat every layout-priority experiment as unsupported and reversible until evidence says otherwise.
