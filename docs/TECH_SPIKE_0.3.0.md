# Blenny 0.3.0 Product Interface Foundation

> Engineering record for one independently reviewable presentation milestone.

Status: **Complete locally; annotated tag pending owner evidence review.**

Last updated: 2026-08-28

## Starting boundary

Development starts from clean commit `3cfb7c9db1dfd0da1ab4e8088a6276c2c30a3591` and the existing local annotated tag `v0.2.0`. Every existing tag remains unchanged. Version `0.2.0` already provides icon-first application and system-item presentation, the three horizontal policy lanes, bounded manual observation, local drafts, deterministic review, and recovery actions.

The installed accepted policy is disabled and a scoped previous-policy backup is available. Version `0.3.0` does not authorize a real assertion write or broaden the private backend.

## Owner-selected direction

The owner selected **Direction A: native top-level product navigation with an anchored action bar** after reviewing four materially different single-window directions. On 2026-08-28, installed review refined that direction through several focused passes: navigation moves below the title bar, the policy lanes become materially denser, observation controls move to the footer, and the temporary selection/draft-assignment surface is removed before dragging exists. The later reviews remove nested white card chrome, reduce system-symbol visual weight to match application icons, collapse the unused lower region, tighten horizontal icon rhythm, present read-only state once at the macOS subsection boundary, remove unnecessary page-level vertical scrolling, keep idle Refresh available as the permission recheck action, give Organize a wide window and Settings/Support one shared narrower width, remove both the oversized and residual thin focus outlines, fix the navigation band's vertical geometry across destinations, and make an active manual refresh unmistakable with a lane-level progress overlay. Final owner refinements replace the explanatory Observation settings card with a real native Open at Login preference, add project attribution metadata to both GitHub Sponsors links, move the privacy/reliability promise into Organize, restore Support's fixed top inset, separate the project website from donation actions, prioritize one-time support, and add Ko-fi.

Blenny remains a single-window product. Its three horizontal `Visible`, `Revealable`, and `Hidden` lanes are the durable product signature and the center of the Organize page. Navigation, status presentation, observation controls, and recovery controls support those lanes rather than competing with them.

```text
+------------------------------------------------------------------+
|  Blenny                                                         |
+------------------------------------------------------------------+
|       [icon Organize]   [icon Settings]   [icon Support]         |
+------------------------------------------------------------------+
|  Management: Stopped             Resume      Restore Previous...  |
|                                                                  |
|  | Visible       [icon] [icon] [icon] [icon] ----------------->  |
|  | Revealable    [icon] --------------------------------------->  |
|  | Hidden        [icon] --------------------------------------->  |
|                                                                  |
|                                                                  |
+------------------------------------------------------------------+
|  9 apps · Manual observation                         Refresh     |
+------------------------------------------------------------------+
```

## Presentation architecture

All visible product content moves to SwiftUI in one deliberate migration. The previous AppKit editor and separate review window are not retained as parallel fallback interfaces.

AppKit remains a narrow macOS infrastructure boundary:

- `NSApplicationDelegate` continues to own application lifecycle and close, reopen, and Quit behavior.
- `NSStatusItem` remains native AppKit because Blenny requires direct status-item, placement, button, length, and menu control that `MenuBarExtra` does not expose.
- One AppKit `NSWindowController` owns the single product window and hosts one SwiftUI root hierarchy through `NSHostingController`.
- Accessibility observation, `NSWorkspace` application discovery and icon resolution, and unsupported Debug-only backend boundaries remain outside SwiftUI views.

SwiftUI owns every visible page and component:

- the top-level `Organize`, `Settings`, and `Support` destinations;
- the management and Accessibility status rows;
- all three policy lanes and icon-first item cards;
- the anchored manual-observation footer and Refresh action;
- the deterministic Review presentation inside the same window;
- empty, loading, permission, error, read-only, fallback, and minimum-size states.

No AppKit control is embedded selectively inside a SwiftUI page. Presentation state travels through one main-actor observable store; product actions return through explicit closures to the existing AppDelegate orchestration and UI-independent policy core.

## Information architecture

### Organize

Organize is the initial destination and the only policy-editing surface.

1. A compact management row presents `On`, `Stopped`, or checking state without repeating engineering diagnostics. It contains the currently applicable Resume or Stop action and the separately labeled Restore Previous Policy action.
2. Permission or observation failures appear as one actionable banner immediately above the lanes. Routine observation counts remain supplementary rather than headline content.
3. Three compact, equal-height horizontal lanes present `Visible`, `Revealable`, and `Hidden` in that order. Each lane has a stable title, count, concise definition, leading semantic accent, and independent horizontal scrolling.
4. A two-line product-contract note explains that macOS owns final physical placement and overflow, then states that Blenny never moves the pointer, captures menu-bar pixels, or continuously polls the system.
5. The bottom observation bar presents the bounded app/system counts and manual Refresh. Organize exposes no assignment control, draft bar, Discard Draft, or routine Review entry before the `0.4.0` drag interaction exists.
6. Missing Accessibility places one unified actionable overlay over the lane stack. The dimmed lane structure remains visually explanatory, while underlying items are neither interactive nor exposed as duplicate Accessibility content.
7. An active manual refresh uses the same lane-level interruption pattern: the three lanes remain dimly legible beneath a compact progress overlay, cannot be interacted with, and are temporarily removed from the Accessibility reading order.

### Settings

The Settings destination provides a durable home for actual preferences without introducing future controls prematurely.

Version `0.3.0` presents two actual configuration groups: Accessibility permission with its explicit Set Up/Open Settings action, and a native Open at Login switch backed directly by `SMAppService.mainApp`. The previous Observation card is removed because it explained behavior rather than exposing a preference; the manual-refresh privacy contract remains visible where the Refresh action actually lives in Organize. The system service status is the sole source of truth: enabled, disabled, approval-required, not-found, and failed-update states are presented without a mirrored `UserDefaults` value. Approval-required state offers the native Login Items system-settings route. No helper, IPC service, theme system, paid appearance control, profile, automatic refresh, or placeholder toggle is introduced.

### Support

The Support destination keeps About and support information visible in the single main window. Its fixed page inset matches the Settings destination instead of allowing the About content to touch the navigation band. Version `0.3.0` presents the application name, version, restrained project status, and a quiet link-style project website action beside the About identity rather than inside the donation group. The donation row orders the lower-commitment `Sponsor once` action first, followed by `Sponsor monthly` and `Ko-fi`. The two GitHub buttons open the owner's existing `f-is-h` Sponsors profile with explicit frequency selection and `metadata_project=blenny`, so GitHub transaction exports can attribute the source project without Blenny collecting payment data. Ko-fi opens the owner's existing `https://ko-fi.com/1atte` page. Blenny does not define benefits, implement entitlements, or select a purchase, subscription, or licensing model.

### Review

Review remains a production safety boundary for management and recovery actions, not a routine organization step or Debug destination. Review replaces the Organize content inside the same window while the Organize top-level selection remains active. It presents:

- the exact action title;
- deterministic diff, impact, validation, and recovery report text;
- the existing assertion-write warning and Apply availability contract;
- Back/Cancel and Apply actions.

Closing Review returns to Organize without changing policy intent. Any action that would create or restore a real assertion remains preview-only until the installed dry-run and explicit owner authorization required by the existing policy core. Routine cross-lane dragging in a later milestone will not require this full report for every move.

## Visual system

The interface uses adaptive system materials and semantic colors rather than a custom theme:

- window and control backgrounds remain system-provided for Light and Dark appearance;
- `Visible` uses the system blue accent;
- `Revealable` uses the system teal accent;
- `Hidden` uses a neutral secondary-label accent;
- warnings and errors use system orange and red with accompanying labels or symbols;
- normal body, secondary, tertiary, and separator colors use their system semantic equivalents.

The three lanes are the one deliberate visual signature. Large decorative gradients, dense status cards, gratuitous glass, and an animation system are excluded. The compact product-navigation strip sits immediately below the native title bar and uses explicit symbols plus labels. System glass may appear only where supplied naturally by current controls and must remain legible with Reduce Transparency and Increase Contrast.

Typography uses the system UI font for navigation, headings, names, and controls. Bundle identifiers and deterministic review text use the system monospaced design. The intended hierarchy is:

- symbol-and-label product navigation;
- 15-point semibold lane titles and compact counts;
- 11- to 13-point explanatory and status text;
- 10- to 11-point item names and supplementary detail.

The base spacing rhythm is 4, 8, 12, 16, and 20 points. Page edges use 20 points at the preferred size and may compress to 16 at the minimum size. Item cards remain compact and icon-first rather than becoming settings-style rows.

## Component states

### Policy lanes and items

- Long lanes remain one row and scroll horizontally; items do not wrap or reorder.
- Empty lanes retain their height and show a quiet, explanatory empty state.
- Application names use one compact line before truncation. Full names and complete supplementary detail remain in tooltips and Accessibility help.
- Resolved application icons stay full color in quiet, borderless icon cells. Known Apple items render directly from smaller semantic SF Symbols at a visual weight comparable to application icons and retain their natural width; they are never coerced into square image geometry. Unresolved candidates use the existing deterministic fallback and identify that state in tooltip and Accessibility output. Individual cells do not add a second white background and border inside the already grouped lane surface.
- Icon cells use a compact horizontal rhythm rather than reserving card-sized whitespace around every icon.
- Apple system items remain in a visibly separated, labeled read-only subsection at the trailing end of Visible. `Read only` appears once in the macOS subsection marker; individual system icons do not repeat it visually, while their tooltip and Accessibility labels retain the complete read-only state.
- Blenny remains visibly locked in Visible.
- Application cards are presentation-only in `0.3.0`; they expose no draft assignment action before dragging is introduced.

### Management, permission, and refresh

- Management checking, stopped, and on states have stable text and a state symbol.
- The management row remains an honest transitional presentation in `0.3.0`: the restored persisted state is still stopped, and Resume, Stop, Restore, Review, and assertion safety semantics are explicitly outside this presentation-only change. The intended later product behavior is ordinary always-on management with no daily management toggle or stopped banner; removing this row requires the lifecycle and management-semantic milestone to make that statement true rather than merely hiding the current state.
- Resume is enabled only for a prepared stopped policy; Stop is enabled only while management is on; Restore is enabled only when the scoped backup is available.
- Accessibility granted state remains quiet and appears only in Settings. Missing access creates one unified actionable lane overlay and never repeatedly prompts.
- Refresh is always manual and lives in the anchored observation footer. While idle it remains available even before Accessibility is granted, because choosing it first rechecks current authorization and therefore discovers permission granted elsewhere. It is disabled only while a refresh is already running or while the existing core contract protects an unpublished draft.
- While a refresh is running, the lane stack dims beneath a centered progress overlay labeled `Refreshing menu bar items`. This is a bounded state indicator, not an automatic loop or animation system. It blocks lane interaction and replaces the lane Accessibility content until the one observation completes.
- Progress, errors, and success messages occupy a stable message region so the lanes do not jump vertically.

### Observation and review

- Organize communicates that observation is manual and newly observed applications remain effectively Visible without persistence.
- Organize does not create or expose a draft in this milestone.
- Review remains available only through management and recovery actions that already require the deterministic safety report.
- Apply remains unavailable for validation failure or a plan that requires an unapproved assertion write.

### Open at Login

- Settings uses the standard macOS switch presentation and labels the preference `Open at Login`.
- `SMAppService.mainApp.status` is the source of truth. The interface does not persist or infer a second enabled flag.
- Enabling registers the main application; disabling unregisters it while leaving the currently running application open.
- If the registered service requires user approval, the switch remains on so the user can still unregister it, the status explains that launch eligibility is blocked, and a compact `Open Login Items` action uses the system-provided settings route.
- Registration and unregistration failures refresh the real service status and expose a concise error instead of leaving the switch in an optimistic state.
- The setting adds no helper executable, LaunchAgent plist, IPC boundary, polling, or automatic management behavior.

## Window behavior

- Organize preferred content size: approximately 980 by 460 points; minimum 800 by 460 points. The compact default deliberately removes the unused lower region below the three lanes.
- Settings and Support preferred content size: approximately 680 by 500 points; minimum 560 by 460 points.
- Organize, Settings, and Support fit their verified normal content without a page-level vertical scroll view or vertical scrollbar. Review retains bounded scrolling for its potentially long deterministic report.
- Switching top-level destinations adjusts the same retained window to the destination's explicit content width without opening another window or adding an animation system. Settings and Support always share the same compact width. Resizing preserves the window's top-left screen position; SwiftUI intrinsic sizing does not compete with the AppKit window controller. The navigation occupies one explicit fixed-height band, so its top and bottom inset relative to the native title bar and page content cannot vary with destination content.
- The window is resizable, closable, miniaturizable, retained after close, and restored to a usable size before reopening.
- At minimum width, the `Organize`, `Settings`, and `Support` destinations retain both their symbol and label.
- Lane descriptions may shorten before lane titles, counts, icons, names, and scrolling are compromised.
- At minimum height, each normal destination remains bounded without vertical scrolling; the observation footer stays reachable and controls do not overlap or clip.
- Closing the window does not quit the menu-bar application. Reopen and status-item Open return to the same single window. Quit terminates normally and preserves the existing restoration boundary.

## Keyboard, Accessibility, and tooltip contract

- Top-level destinations retain an explicit selected state, button semantics, and keyboard focus order. Both the oversized blue system focus effect and the residual custom one-point focus outline are suppressed; the selected destination remains unambiguous through its accent fill and color without a border that appears permanently attached to Organize.
- Each lane is an Accessibility group with its title, definition, and count.
- Each application exposes name, policy, bundle identifier, item count, fallback state, and its future editability without advertising an unavailable action.
- Each Apple system item exposes name, Visible policy, stable observation and owner detail, count, fallback state, and read-only status without advertising an unavailable action.
- Icon-only status controls receive complete labels and help. Every truncated name and every icon-only control has a matching tooltip.
- The reading and focus order follows top-level navigation, management/permission status, Visible, Revealable, Hidden, observation controls, and recovery actions.

## `0.4.0` compatibility

The lane frames remain stable and independently addressable so `0.4.0` can add cross-lane drop targets without changing the main-window hierarchy. Version `0.3.0` adds no draggable source, drop destination, hover target, within-lane ordering, or persistence change. Keyboard and VoiceOver assignment alternatives are deliberately deferred until the drag interaction is designed.

## Deterministic verification

Presentation-focused tests must cover at least:

- observable UI-state projection from the existing editor model;
- management, permission, refresh, draft, recovery, review, fallback, and read-only component states;
- stable item ordering and group counts without changing policy identity;
- Blenny's Visible invariant and the absence of an assignment action;
- Review entering and leaving the single-window route without changing the prepared report;
- Settings and Support routing without affecting policy state;
- Open at Login presentation for enabled, disabled, approval-required, not-found, and failed-update states without a mirrored preference;
- version and support presentation without policy-persistence inputs;
- the project website, both GitHub Sponsors frequency-and-project-metadata links, and Ko-fi without in-app payment handling.

Installed visual and interaction review must exercise:

- preferred and minimum sizes in normal Light and Dark system appearances;
- a long Visible lane, non-empty Revealable and Hidden lanes, and deterministic empty-lane fixtures where practical;
- long names, fallback application and system icons, read-only Apple items, and Blenny's required Visible state;
- natural-aspect system symbols, tooltips, focus traversal without a visible navigation outline, and Accessibility labels;
- manual Refresh, the Open at Login switch and approval presentation without changing its installed state during visual review, management/recovery Review, Cancel/Back, Resume, Stop, Restore, close, reopen, and Quit;
- no real assertion write, Screen Recording request, menu-bar pixel capture, polling, or automatic refresh.

Xcode 27 Debug and Release tests and application builds must pass. The installed Debug app must be built with the macOS 27 SDK, use the declared minimum system version, and leave management disabled and the scoped policy/recovery state fully restored after acceptance.

## Implementation and verification record

Direction A is implemented as one AppKit `NSWindowController` hosting one SwiftUI root view. The former programmatic AppKit editor hierarchy and separate AppKit Review window were removed. The product now has native top-level `Organize`, `Settings`, and `Support` destinations, with Review presented as an Organize route in the same retained window.

The implementation preserves the existing policy editor and transaction boundaries. New core presentation types project navigation, permission, native login-item status, support links, and deterministic control enablement without entering policy persistence, draft serialization, diff, report, recovery, fingerprint, or assertion inputs. The existing AppDelegate remains the only action bridge. It maps `SMAppService.mainApp.status` into the presentation, performs bounded register/unregister requests, opens the system-provided Login Items pane when approval is required, and refreshes the system status on launch and application activation. No helper, IPC service, mirrored login preference, or real menu-bar assertion was created or restored during this milestone.

Verification used Xcode 27.0 build `27A5237l` and the macOS 27.0 SDK:

- Debug tests: 126 tests in 17 suites passed.
- Release tests: 124 tests in 16 suites passed.
- Debug and Release application builds passed through `scripts/build-app.sh`.
- The final installed Debug app reports version `0.3.0`, bundle identifier `xyz.fi5h.blenny`, and minimum system version `27.0`; its signature verifies successfully.
- Installed Light and Dark review covered Organize at its refined preferred 980-by-460 and minimum 800-by-460 content sizes, plus Settings and Support at the shared 680-point compact width. Keyboard activation verified the exact Organize → Settings → Support → Settings sequence: captured window widths were 980, 680, 680, and 680 pixels, while the window's reported top-left screen coordinate remained unchanged. The final navigation band is 54 points high in every destination, with its 38-point control group centered inside that band, so the title-bar and page insets remain fixed. At the compact Organize height the former unused lower region is absent while the observation footer stays anchored; each policy lane retains independent horizontal scrolling.
- A Debug-only, environment-gated presentation fixture verified a long Visible lane, non-empty Revealable and Hidden lanes, installed icons, one application fallback, one system-item fallback, long names, multiple item counts, a separated read-only macOS subsection, Blenny's locked Visible state, recovery controls, and the absence of assignment/draft UI. The fixture performs no observation, persistence, or system mutation and is absent from Release behavior.
- Installed Accessibility inspection verified complete names, policies, bundle identifiers, counts, fallback status, tooltips/help, symbol-and-label navigation, lane grouping, natural-aspect read-only system symbols at application-icon visual weight, and the anchored manual Refresh action. The individual system-item presentation no longer repeats `Read only`; the macOS subsection marker provides the single visual label while each system item's tooltip and Accessibility label retain the state. Keyboard inspection verified retained focus traversal and selected-state semantics without either the blue focus frame or a residual custom outline. Organize, Settings, and Support expose no page-level vertical scroll area. A forced missing-permission fixture verified that one overlay replaces the lane Accessibility content while idle Refresh remains available to recheck authorization. A separate forced-refresh fixture verified that the lanes dim, become noninteractive, leave the Accessibility reading order, and are replaced by one `Refreshing menu bar items` progress group until completion. The Review report appears once in the Accessibility tree after removing text-selection duplication.
- Settings and Support were reviewed in the same window. Settings contains Permission and Startup only; the explanatory Observation card is absent. The standard Open at Login switch, complete Accessibility label/help, disabled, enabled, approval-required, not-found, and failure presentation are deterministic. The ad-hoc installed Debug validation bundle reported the system's honest not-found state; its switch remained available for a standard registration attempt, but acceptance did not toggle it or create a login item. Support retains a fixed 28-point page inset below the navigation band, reports the installed version, places `Open Project Website` as a quiet About link, and presents `Sponsor once`, `Sponsor monthly`, and `Ko-fi` in that order. The GitHub URLs preserve their explicit frequency and include `metadata_project=blenny`; Ko-fi uses the owner's existing `https://ko-fi.com/1atte` page. All actions are keyboard- and Accessibility-readable, and Blenny performs no checkout or payment handling.
- Review remains in the main window, exposes Back and Apply, keeps Apply disabled for the unapproved assertion fixture, and preserves the exact safety warning.
- Command-W closed the product window while the menu-bar application remained running; reopening the installed application recreated one usable product window; Command-Q terminated normally.
- Organize presents the no-pointer-movement, no-menu-bar-capture, and no-polling promise as a separate line directly below the macOS placement note. No Accessibility authorization, login-item registration, Screen Recording setting, menu-bar pixel, polling behavior, or automatic refresh changed during acceptance. Application-window screenshots and pre-state copies remain only under ignored `LocalData/`.

The accepted policy and scoped recovery backup remained byte-for-byte unchanged after installed review. Their final SHA-256 values match the pre-state copies:

- accepted policy: `b896c26e0031984d8c857b7f71e0f67bdb4625c53adf49a17675b523981a3dee`;
- recovery backup: `0e880b34e925c7d808d58d3c6f915e95bbbd4bfb9001c85f948f1541d13afce3`.

Both files remain mode `0600`; management remains disabled; Blenny remains Visible; Usage4Claude remains Revealable; and CleanShot X remains Hidden. The obsolete `0.2.0` validation app is not recreated after final review; it was an untracked local validation artifact rather than required product state. The separate installed `0.3.0` Debug validation app is not a distribution artifact.

## Explicit exclusions

Version `0.3.0` does not include:

- drag-and-drop or within-lane ordering;
- policy, persistence, draft, diff, report, recovery, or fingerprint semantic changes;
- a real assertion write or backend promotion;
- mutable Apple system items;
- Screen Recording or live menu-bar pixel capture;
- polling, automatic refresh, or reconciliation;
- lifecycle or multi-display hardening;
- global shortcuts, helper/IPC, updater, or distribution work;
- profiles, themes, animation systems, automatic rules, paid appearance, donation processing, licensing, or other product features.

## Exit boundary

The milestone is complete only when the selected SwiftUI interface is installed and visually accepted, all preserved interaction and recovery paths pass, Debug and Release verification succeeds under Xcode 27, required documentation and `Config/Info.plist` agree on `0.3.0`, the working tree contains no raw evidence, restoration is complete, and `$blenny-release` has audited and committed the milestone. Do not push, and do not create `v0.3.0` until the owner reviews the final evidence and explicitly authorizes the tag.
