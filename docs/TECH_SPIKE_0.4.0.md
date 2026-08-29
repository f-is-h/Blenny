# Blenny 0.4.0 Core Interaction and Visual Refinement

> Engineering and design contract for one independently reviewable interaction milestone.

Status: **Complete locally on macOS 27.0 build `27A5237l`; owner evidence confirmation and the local annotated tag remain pending.**

Last updated: 2026-08-29

## Baseline and purpose

Version `0.4.0` starts from clean commit `a9196e547024a1f03b10a4665c4adea6df04149f`, the commit referenced by the existing annotated `v0.3.0` tag. Existing tags remain unchanged.

This milestone refines the complete single-window product interface and adds cross-lane draft assignment. It does not change policy, persistence, diff, report, recovery, fingerprint, assertion, reveal-session, or management semantics. AppKit continues to own application lifecycle, the retained `NSWindow`, `NSStatusItem`, Workspace and Service Management integration, and Accessibility inventory. SwiftUI continues to own every visible product surface.

The owner approved Direction A, **Peek Rail**, after comparing three complete visual directions. The product remains approximately 80 percent native macOS and 20 percent restrained Blenny identity. The default interface is complete without themes or paid appearance.

## Product and safety boundaries

- Keep one retained product window with `Organize`, `Settings`, and `Support` top-level navigation below the title bar.
- Keep the three horizontal `Visible`, `Revealable`, and `Hidden` regions as the product's visual and functional center.
- Treat a policy assignment as application-bundle intent, never status-item order.
- Keep each lane a single horizontally scrolling row. Do not wrap, reorder within a lane, display an insertion position, or suggest physical menu-bar order.
- Dragging changes only the local `BundlePolicyDraft`. One accepted cross-lane drop produces at most one assignment.
- Do not persist a draft, create an assertion, or mutate menu-bar system state during drag, drop, keyboard movement, discard, or visual acceptance.
- Blenny remains locked in `Visible`. Apple system items remain read-only, non-draggable, and outside the bundle draft.
- Keep manual Refresh, the missing-permission interruption, bounded refreshing interruption, Open at Login, management and recovery Review, close, reopen, Quit, and restoration behavior stable.
- Keep management status truthful. A stopped persisted state may be visually quieter but cannot be hidden or described as active.
- Do not add Screen Recording, menu-bar pixel capture, polling, automatic reconciliation, helper or IPC processes, lifecycle expansion, global shortcuts, profiles, themes, paid appearance, or decorative animation infrastructure.

## Design thesis

The interface should feel like a native macOS utility whose one memorable element is a calm organization surface cut into three policy currents. The board is the signature. Navigation, settings, support, draft controls, and status messages are quieter supporting layers.

Direction A deliberately removes the three independent rounded cards from `0.3.0`. The replacement is one continuous board with:

- one adaptive outer surface and outline;
- two internal separators;
- one narrow semantic rail for each policy;
- stable row heights and fixed lane headers;
- borderless icon positions with no persistent name row;
- one trailing, separated macOS read-only group in `Visible`.

The board receives no Liquid Glass. Native glass is limited to the top navigation and compact interactive controls where the current system supplies it. Content surfaces use adaptive system background and separator colors.

## Fixed design tokens

These are implementation constants, not a switchable theme system.

### Color

- `windowSurface`: system window background.
- `boardSurface`: system control background at a quiet adaptive level; opaque when Reduce Transparency is enabled.
- `boardOutline`: system separator; strengthened under Increase Contrast.
- `visibleAccent`: system blue.
- `revealableAccent`: system teal.
- `hiddenAccent`: secondary label color.
- `blennyCoral`: restrained dynamic brand accent, approximately `#EF5D55` in Light and `#FF756B` in Dark. It is reserved for Blenny's lock and the successful settle accent. It never replaces semantic warning, error, focus, valid-target, or policy colors.
- `warningAccent` and `errorAccent`: system orange and red, always paired with a symbol or label.

### Typography

- All product UI uses the system UI typeface.
- Page title: 26-point semibold.
- Lane title: 14-point semibold.
- Navigation: 12-point medium with an SF Symbol.
- Body and controls: 12- to 13-point regular or medium.
- Counts, state labels, and supplementary text: 10- to 11-point regular or medium.
- Bundle identifiers and deterministic Review output: system monospaced design.

### Geometry and spacing

- Base spacing rhythm: 4, 6, 8, 12, 16, 20, and 24 points.
- Page edge: 20 points preferred, 16 points minimum.
- Navigation band: one fixed 54-point band in every route.
- Organization Board corner radius: 14 points.
- Board outline: 1 point normally, 2 points under Increase Contrast.
- Lane semantic rail: 3 points normally, 4 points while a valid destination is active.
- Icon image frame: 34 to 38 points without coercing natural-aspect Apple symbols into square artwork.
- Icon interaction frame: at least 52 by 52 points, with stable geometry in every state.
- Transient label width: system-font measured, clamped to 52 through 180 points, with one truncated line and full detail in Help and selection detail.
- Control radius: native system value where available; otherwise one fixed 8-point radius.

## Window and route structure

The retained AppKit window preserves its existing top-left anchor when changing route or preferred size.

- Organize preferred content size remains approximately 980 by 460 points; minimum remains 800 by 460 points.
- Settings and Support remain approximately 680 by 500 points; minimum remains 560 by 460 points.
- Settings and Support always share the same width.
- Normal routes have no page-level vertical scroll view. Review retains bounded scrolling for deterministic report content.
- Switching routes clears transient hover, drag, drop-target, and settle presentation state. It preserves the local draft until explicit Discard or successful existing Apply behavior changes it.

The SwiftUI hierarchy is organized around these visible components:

```text
BlennyRootView
├── ProductNavigationBar
├── OrganizeView
│   ├── ManagementStatusStrip
│   ├── OrganizationBoard
│   │   ├── PolicyLaneRow (Visible)
│   │   ├── PolicyLaneRow (Revealable)
│   │   └── PolicyLaneRow (Hidden)
│   ├── SelectionDetailRail
│   └── ObservationAndDraftFooter
├── SettingsView
├── SupportView
└── ReviewView
```

## Top navigation

`Organize`, `Settings`, and `Support` remain symbol-and-label controls in one fixed-height band. The controls may use native macOS 27 Liquid Glass or the corresponding system glass button style, contained as one compact control layer. Glass is interactive and subordinate to the board; it does not fill the title band or content background.

- The selected route uses the system accent and a restrained filled or glass-selected state.
- Keyboard focus uses the native focus contract without leaving a permanent border around the selected route.
- Reduce Transparency replaces translucent glass with an opaque adaptive control surface.
- Increase Contrast strengthens selection and focus outlines without relying on color alone.

## Organization Board

### Lane structure

Each lane row has a fixed header, a separator relationship shared by the whole board, and one horizontal scrolling item region. The three rows read as one surface, not three cards.

- The lane header exposes title, compact count, and a concise policy definition.
- Empty lanes retain full height and show one quiet invitation such as `Drop an app here or use Move to…`.
- Long lanes remain one row. Scroll position does not imply order and is not automatically changed after a drop.
- Visible contains editable application bundles first, followed by one divider, one `macOS · Read only` group marker, and natural-aspect Apple system items.
- Fallback application and system icons remain explicit in Help, selection detail, and Accessibility output.

### Item identity and stable geometry

The icon interaction frame never changes size when a name, selection, focus ring, drag source treatment, target feedback, lock, or fallback marker appears. No state adds a persistent text row beneath an icon.

Application and system item display names are hidden at rest. A name may appear through two coordinated surfaces:

1. A single transient floating label for the highest-priority hover or keyboard-focus item.
2. A stable `SelectionDetailRail` for the selected item.

Hover outranks keyboard focus, and focus outranks selection for the floating-label coordinator, so exploring another item does not leave the selected item's transient label over the board. At most one floating label is visible within the board, preventing overlapping labels. The label uses measured system text clamped to 52 through 180 points, truncates on one line, and never participates in lane layout. Selection detail provides the untruncated name, bundle or observation identity, count, policy, fallback state, editability, and `Move to…` alternatives.

Help always exposes the complete name, bundle ID or observation ID, count, policy, fallback state, and read-only state. VoiceOver always receives the complete name and state without requiring hover or selection.

### Visual item states

- Default: full-color application icon or semantic Apple symbol, no name, no border, stable interaction frame.
- Hover: quiet background wash and the coordinated floating label.
- Keyboard focus: native focus affordance plus the same floating-label contract.
- Selected: a clear but restrained selection ring and complete selection detail.
- Drag source: the original frame remains as a low-opacity ghost; the system drag preview carries the icon and one compact name label.
- Valid destination: the entire lane receives a pale semantic wash, stronger semantic rail, outline, and a short `Move to …` label.
- Invalid destination: system forbidden operation plus a symbol-and-label explanation. No shake, flashing, or color-only state.
- Settling: the source ghost resolves toward the destination when both endpoints are onscreen, followed by one short destination confirmation ring.
- Locked Blenny: a small coral lock marker in `Visible`; it remains selectable but has no drag source and no move action.
- Read-only system item: selectable for detail, never draggable, and has no move action.

## Drag-and-drop architecture

### Native transport

Use the current SwiftUI and Core Transferable drag-and-drop APIs on macOS 27:

- a private application-local transferable representation;
- `draggable` with a custom system preview;
- a drag-preview content shape;
- drag configuration that proposes move only within Blenny and proposes no operation outside the application;
- `dropDestination(for:isEnabled:action:)` on complete lane rows;
- `onDragSessionUpdated` and `onDropSessionUpdated` for presentation lifecycle;
- `dropConfiguration` to return exactly `.move` or `.forbidden` from cached, deterministic validation.

Do not replace the system drag with a custom `DragGesture`, direct AppKit dragging session, or third-party reordering package. Do not use the SwiftUI reorderable-container APIs because their insertion placeholders and item displacement imply within-lane order.

### Payload and idempotency

The local payload contains only:

- canonical bundle identifier;
- source policy;
- candidate-generation identifier;
- unique drag token.

The bundle identifier is the product identity. The session identifier drives ephemeral presentation. The unique drag token guards duplicate delivery. No display name, icon bitmap, policy document, assertion data, or system-item identity is transferred.

The drop handler validates, in order:

1. exactly one local payload is present;
2. the drag token has not been consumed;
3. the candidate generation still matches the current bounded inventory;
4. the candidate still exists and is editable;
5. the canonical bundle is not Blenny;
6. the destination differs from the current effective policy;
7. the destination is one of the three application-bundle policies;
8. the existing policy-editor assignment accepts the change.

Only a `.changed` assignment consumes the token and produces a completion animation. Repeated delivery, same-lane delivery, stale inventory, unknown candidates, route changes, invalid areas, Blenny, and system items leave the draft unchanged.

### Motion contract

The system owns pointer tracking, drag preview movement, operation cursor, cancellation, and failed-drop return. Blenny animates only state changes around the system session.

- Floating name: 100 to 120 milliseconds, opacity with at most 2 points of vertical travel.
- Source ghost: `.smooth(duration: 0.14)`.
- Destination enter and exit: `.smooth(duration: 0.14...0.16)`.
- Successful onscreen cross-lane settle: `.smooth(duration: 0.22...0.24, extraBounce: 0)`.
- Completion ring: approximately 160 milliseconds, ease-out opacity.
- Invalid state: approximately 100 milliseconds, outline and opacity only.

The matching application icon may use `matchedGeometryEffect` across lanes when both source and resolved destination endpoints are onscreen. This is enhancement-only. A lazy or offscreen destination falls back to the native preview disappearance, destination-lane confirmation, and selection detail. Blenny never auto-scrolls or builds a full-window drag proxy to force a spatial animation.

Animation state is keyed by drag session and generation. A newer drag, route change, refresh interruption, discard, or window close cancels the older presentation state. Animations use replaceable SwiftUI transactions with no sleeps, unbounded tasks, or non-interruptible chains. Completion cleanup verifies the same generation before clearing state.

### Reduced motion and appearance

When Reduce Motion is enabled:

- keep direct system drag tracking;
- remove lift scaling, simulated depth, matched-geometry travel, and expanding rings;
- replace the successful move with an approximately 100-millisecond cross-fade and persistent destination outline;
- keep all text, symbol, focus, valid, invalid, and completion meaning.

When Reduce Transparency is enabled, floating labels, navigation controls, and overlays use opaque system surfaces. Increase Contrast strengthens the board, focus, selection, valid-target, and invalid-target outlines and preserves symbols and labels so color is never the only distinction. Light and Dark use semantic system colors plus the dynamic Blenny coral token.

## Keyboard, menu, and VoiceOver equivalence

Every editable application item is focusable and selectable. The selection detail and context menu provide `Move to Visible`, `Move to Revealable`, and `Move to Hidden`, disabling the current policy. The keyboard path invokes the same validated assignment function and creates the same one-assignment local draft as drag-and-drop.

VoiceOver exposes named custom actions for the same valid destinations. It announces the complete item name, current policy, count, fallback state, editability, and successful destination. It never depends on a floating hover label.

Blenny and Apple system items expose their complete state but no unavailable move actions. Keyboard and VoiceOver movement produces the same completion feedback without simulating a pointer or drag.

## Draft, Review, and discard

Before the first changed assignment, Organize shows no draft action controls. The footer reserves stable action geometry so the board and observation status do not jump when the controls appear.

After the first changed assignment:

- a restrained coral `Draft` status appears;
- `Review Changes` and `Discard Draft` appear in the reserved footer action position;
- manual Refresh remains disabled under the existing unpublished-draft contract;
- changing another assignment updates the same local draft;
- moving an item back may remove the draft state if the complete draft again equals the accepted draft.

`Review Changes` calls the existing deterministic `PolicyEditingCore.preview(draft:)` boundary and opens Review within the same window while Organize remains the selected top-level route. Review displays the existing exact diff, impact, validation, recovery, assertion-warning, and Apply-availability contract. This milestone does not authorize a real assertion write.

`Discard Draft` deterministically restores the accepted draft plus Blenny's existing Visible invariant, clears consumed-token and transient selection state as appropriate, and returns the footer to its quiet pre-draft presentation. Leaving Organize, closing the window, or reopening the retained window does not silently discard a draft.

## Management, permission, refresh, and errors

- The stopped-management presentation remains honest and is visually reduced to one compact status strip with the existing recovery action path.
- Missing Accessibility replaces board interaction with one unified authorization interruption. It does not obscure the route navigation or duplicate prompts.
- Active manual Refresh dims and disables the board, clears drag and target presentation, and presents one centered bounded progress group.
- Refresh completion does not silently apply, discard, or reinterpret an existing draft.
- Errors occupy a stable message region, use system red with a symbol and recovery action where available, and never shift lane geometry.
- Normal observation, permission, refreshing, stopped, and error states remain distinguishable without relying only on color.

## Settings and Support refinement

Settings and Support share one page grid, top inset, section-header style, label width, control alignment, separator treatment, and compact width.

Settings uses flat native grouping rather than nested cards:

- Permission presents current Accessibility state and the existing system-settings action.
- Startup presents the native `Open at Login` switch, approval state, error state, and existing system-settings action.

Support uses the same grid:

- About presents version and the project website.
- Support Blenny presents Sponsor once, Sponsor monthly, and Ko-fi with concise external-link treatment.

Liquid Glass may appear on the navigation and individual interactive buttons where supplied by the system. Section content itself remains an adaptive opaque surface with separators, not a field of glass cards.

## Implemented structure

The approved contract is implemented without a dependency or a custom dragging engine:

- `PolicyDragPayload` is a local `Codable`, `Transferable` bundle assignment using one exported Blenny UTI, source policy, candidate-generation UUID, and unique delivery token.
- `PolicyDraftAssignmentCoordinator` owns validation and idempotency. It consumes a token only after `PolicyEditorViewModel.assign` changes the Draft; same-lane and forbidden attempts do not consume a current drag.
- `PolicyBoardInteractionState` owns selection, hover, focus, drag source, destination, and settle presentation independently from accepted policy and persistence.
- `OrganizationBoard` uses native `draggable`, `DragConfiguration`, `dropDestination`, `dropConfiguration`, drag/drop session callbacks, `.smooth(..., extraBounce: 0)`, and enhancement-only `matchedGeometryEffect`.
- `Move to…`, context-menu commands, and Accessibility custom actions call the same coordinator. There is no parallel keyboard or VoiceOver mutation path.
- `AppDelegate` receives only the updated local editor model. Review creates the existing deterministic preview with an expanded validation scope and rejects the result if the source Draft changed while asynchronous preparation was in flight.
- Debug-only visual fixtures expose populated, long-list, empty, missing-permission, refreshing, error, Draft, Review, management-on, hover, selection, valid-target, invalid-target, settle, minimum-size, Dark, Increase Contrast, Reduce Transparency, and Reduce Motion states. They do not exist in the Release branch of the compiled interface and cannot create an assertion.

No policy document format, persistence transaction, diff, report, fingerprint, recovery, assertion, reveal-session, or management semantic changed.

## Deterministic verification

Core and presentation tests must cover at least:

- application-local drag payload round-trip and rejection of malformed data;
- one changed assignment per unique drop token;
- duplicate token, same-lane, stale-generation, unknown-candidate, Blenny, system-item, and invalid-destination rejection;
- drag, keyboard, context-menu, and VoiceOver movement reaching the same assignment result;
- discard restoring the accepted draft and Blenny invariant;
- Review Changes using the existing deterministic preview boundary without persistence or assertion creation;
- names hidden at rest and exposed for hover, focus, selection detail, Help, and Accessibility projection;
- target-state and completion-state reducers, including route change, refresh, discard, and interrupted animation cleanup;
- stable candidate ordering, single-row lanes, empty lanes, fallback items, long names, multiple counts, and read-only macOS grouping;
- Light, Dark, Increase Contrast, Reduce Transparency, and Reduce Motion presentation projection;
- unchanged permission, manual Refresh, Open at Login, management, recovery, navigation, close, reopen, Quit, and restoration state.

Installed visual and interaction review must exercise:

- Organize, Settings, Support, and Review at preferred and minimum window sizes;
- default, hover, keyboard focus, selection, drag source, valid target, invalid target, successful drop, failed drop, and discard;
- visible and offscreen destinations in long horizontally scrolling lanes;
- empty groups, fallback icons, long names, multiple status items, locked Blenny, and natural-aspect read-only Apple items;
- missing Accessibility, active Refresh, stopped management, error, and normal states;
- draft absent, draft present, Review Changes, Back, and Discard Draft;
- complete keyboard and VoiceOver cross-lane assignment;
- Light, Dark, Increase Contrast, Reduce Transparency, and Reduce Motion;
- stable navigation padding, compact route widths, Organize width, and top-left window position;
- no real assertion write, mutable Apple system action, menu-bar pixel capture, Screen Recording request, polling, or automatic refresh.

Use Xcode 27 and the macOS 27 SDK explicitly for Debug and Release tests and application builds. Install the Debug app for final acceptance. Store screenshots, logs, test artifacts, and state copies only under ignored `LocalData/`. Preserve and compare the accepted policy, scoped recovery backup, management state, Accessibility state, and login-item state before and after installed validation.

## Implementation sequence

1. Add deterministic drag payload, interaction-state, assignment-command, and presentation tests without changing persistence semantics.
2. Refactor the three cards into the continuous Organization Board and introduce the fixed visual tokens.
3. Implement hidden-at-rest labels, selection detail, Help, focus, context menu, and Accessibility actions.
4. Add native drag source, lane destination, move/forbidden validation, idempotent assignment, and reduced-motion behavior.
5. Connect conditional Draft, Review Changes, and Discard Draft to the existing editor and preview boundary.
6. Refine navigation, management status, Settings, Support, permission, refresh, and error presentation within the approved system.
7. Run deterministic Debug and Release verification, build and install Debug, complete visual and interaction acceptance, and verify restoration.
8. Align `PROJECT_BRIEF.md`, `README.md`, `docs/ROADMAP.md`, this document, and `Config/Info.plist` only after implementation evidence exists.
9. Invoke `$blenny-release` for the required local audit and commit. Do not push. Do not create `v0.4.0` until the owner confirms the final evidence.

## Final local verification

The completed implementation was verified on 2026-08-29 with `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`, Xcode 27.0 build `27A5237l`, and the macOS 27.0 SDK:

- Debug: 134 tests in 18 suites passed.
- Release: 132 tests in 17 suites passed. Debug-only assessment and visual-fixture surfaces were absent, as intended.
- Debug and Release application bundles built successfully as ad-hoc-signed arm64 Mach-O applications with bundle identifier `xyz.fi5h.blenny`, short version `0.4.0`, and minimum system version `27.0`.
- The installed Debug validation binary at `/Applications/Blenny 0.4.0 Validation.app` matched the final Debug build at SHA-256 `d2e4d0235e5791a4710d999a022afba530738b725e88a3efacbcd68129749373`. The final Release binary SHA-256 was `0df2b99103bd1d459a199c900da4d5da941ddef133ddab667ea492ebae39395e`.
- The Release executable contained none of the `BLENNY_VALIDATE_*` visual-fixture environment keys. The Debug executable retained the fixtures used for bounded presentation review.
- Ignored application-window evidence under `LocalData/0.4.0-ui-acceptance/` covers Organize default, hover with a long name, selection, valid and invalid drag targets, settled Draft, minimum-size long list, missing Accessibility, active Refresh, stopped and active management presentation, error, Review, Settings, Support, Dark, Increase Contrast, Reduce Transparency, and Reduce Motion. No real menu-bar pixels were captured or persisted.
- Static Debug fixtures exercised source, target, invalid, and settle frames without synthesizing pointer movement or Command-drag. Native transport, payload idempotency, stale-session rejection, keyboard equivalence, and interaction-state cleanup were verified deterministically. Final subjective pointer-motion confirmation remains part of the owner's evidence review before tagging.
- The installed non-fixture app performed only its bounded read-only observation path and failed closed on timeout. No real assertion write, Apple system-item mutation, policy persistence, automatic refresh, polling, or reconciliation occurred.
- The accepted policy file remained mode `0600`, schema 2, with `managementEnabled` false. Its SHA-256 was `b896c26e0031984d8c857b7f71e0f67bdb4625c53adf49a17675b523981a3dee`; the scoped recovery backup remained present at SHA-256 `0e880b34e925c7d808d58d3c6f915e95bbbd4bfb9001c85f948f1541d13afce3`.
- Open at Login remained unregistered and was not toggled. All validation instances were terminated, and no Blenny process or active assertion remained after review.

## Explicit exclusions

Version `0.4.0` does not include:

- within-lane ordering, insertion-position UI, or physical menu-bar ordering;
- policy, persistence, diff, report, recovery, fingerprint, assertion, reveal-session, or management semantic changes;
- a real assertion write or backend promotion;
- mutable Apple system items;
- Screen Recording or live menu-bar pixel capture;
- polling, automatic refresh, reconciliation, or unbounded retry;
- lifecycle, multi-display, login-startup capability, or recovery expansion;
- helper, IPC, updater, global shortcut, profiles, themes, automatic rules, or decorative animation systems;
- paid themes, purchase, subscription, entitlement, licensing, or payment processing.

## Exit boundary

The milestone is complete only when the approved interface and motion contract are implemented, deterministic and installed acceptance passes under Xcode 27, required documentation and `Config/Info.plist` agree on `0.4.0`, the working tree contains no raw evidence, local system state is fully restored, and `$blenny-release` has audited and committed the milestone. Do not push. Do not create `v0.4.0` until the owner reviews the final evidence and explicitly authorizes the tag.
