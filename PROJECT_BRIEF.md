# Blenny

> A minimal, native menu bar organizer designed exclusively for macOS 27 and later.

## Document status

- Project name: **Blenny**
- Development directory: repository root
- Current phase: `0.0.1` technical feasibility validation
- Document date: 2026-08-21
- Product status: research only; no distributable build yet
- Source lineage decision: clean implementation, not an Ice fork
- License decision: pending; decide before the first public release

## 1. Product premise

Blenny is a small, native macOS utility for organizing menu bar status items.

Its purpose is not to become the menu bar manager with the most features. Its purpose is to add a thin, reliable policy layer to the native menu bar overflow behavior introduced in macOS 27.

The core promise is:

> Set it once. It stays set.

Supporting promises:

- No cursor hijacking.
- No dancing icons.
- No continuous background rearrangement.
- No visual customization unrelated to organization.
- Use Apple's native behavior whenever it is adequate.

## 2. Why this project exists

Existing open-source menu bar managers demonstrate strong demand, but also expose recurring reliability problems.

Observed problems in Thaw 1.x and 2.x include:

- Carefully arranged layouts later reverting or changing without an explicit user action.
- Status items moving into the wrong section after app relaunches or updates.
- Slow, visibly laggy reordering in the layout editor.
- Icons flickering, snapping back, or "dancing" during reconciliation.
- Cursor movement and synthetic dragging interfering with normal input.
- Complex interactions among polling, Accessibility, WindowServer state, screenshot caches, retries, profiles, and multiple displays.

macOS 27 introduces a native overflow control, displayed as a double-chevron button when the menu bar lacks enough space. It is visually smooth and can expand or collapse the overflowed items, but the system does not expose adequate user-facing controls for selecting which status items should be prioritized or concealed.

Blenny should fill only that missing policy gap.

## 3. Name and identity

The name **Blenny** refers to a family of small fish that commonly hide in rocks and crevices, then peek out when needed.

That behavior matches the product:

- Small and unobtrusive.
- Usually hidden in the menu bar.
- Reveals other small items on demand.
- Friendly rather than aggressively technical.

Pronunciation: `BLEN-ee`.

Potential visual direction:

- A small fish peeking through a horizontal opening.
- A restrained, geometric silhouette rather than a detailed cartoon mascot.
- The opening or fins may subtly suggest two chevrons without copying Apple's system glyph.
- The icon should work clearly at menu bar size and in monochrome template rendering.

Brand work is deliberately postponed until the technical feasibility spike succeeds.

## 4. Strategic decisions already made

### 4.1 macOS 27 and later only

Blenny will not support macOS 26 or earlier.

This is a deliberate product and architecture decision, not merely a temporary limitation. It removes the need to retain the pre-macOS-27 model based on independent per-item WindowServer windows.

The codebase should not contain:

- Legacy CGS item-window enumeration fallbacks.
- Pre-27 compatibility layers.
- Synthetic Command-drag logic.
- Migration from Ice or Thaw layouts.
- Old status-item hiding techniques kept only for historical systems.

### 4.2 Clean implementation rather than an Ice fork

Blenny does not require Ice's source code or binary at runtime.

Ice is a normal Swift/AppKit application. It is not a driver, system extension, privileged helper, or required framework. A fork would compile Ice's source into a new application; users would not need Ice installed.

However, most of Ice's difficult core logic targets the old menu bar architecture and is therefore not the right foundation for a macOS-27-only product.

Blenny may use Ice and Thaw as:

- Research material.
- Examples of private macOS behavior.
- Sources of known failure cases.
- Inputs for a regression-test matrix.

Blenny should not copy or port their non-trivial implementation code during the clean implementation.

### 4.3 Native behavior first

Blenny should let Apple own:

- Menu bar rendering.
- Overflow animation.
- Translucency and compositing.
- Notch and display geometry.
- Native click and hover behavior where possible.

Blenny should own only:

- User intent.
- Stable item identity.
- Visibility priority.
- A minimal settings interface.
- A fallback shelf only if the native overflow surface is insufficient.
- Safe application and restoration of any system state it modifies.

## 5. What the macOS 27 investigation established

### 5.1 The architecture changed

On macOS 14-26, menu bar managers could generally treat individual status items as separate WindowServer windows. They could enumerate, capture, move, and push those windows off screen using a mixture of public and private behavior.

On macOS 27:

- Apple introduced `/System/Library/CoreServices/MenuBarAgent.app`.
- Status items are managed and composited through `MenuBarAgent`.
- The former `CGSGetProcessMenuBarWindowList` path no longer provides the same independent item-window model.
- `MenuBarAgent` uses private frameworks including MenuBarClient, MenuBarClientCore, MacSystemUI, and SkyLight.
- Its private XPC services include item listing, preferred trailing positions, and visibility-restriction functionality.
- Important capabilities are private or entitlement-gated.

This is a new platform backend, not a small compatibility patch.

### 5.2 The native double-chevron cannot be safely replaced

Direct inspection on macOS 27.0 build `26A5416b` found that the native overflow control:

- Belongs to `MenuBarAgent`.
- Appears through Accessibility as a read-only `AXButton`.
- Exposes no standard press action in the inspected state.
- Does not allow `AXHidden` or `AXPosition` to be set.
- Has no public API for changing its image, location, or action.

Therefore:

- Blenny must not promise to take ownership of Apple's overflow button.
- Overlaying it or injecting into `MenuBarAgent` is not a stable product strategy.
- Blenny may observe whether it exists.
- Blenny may arrange priorities so the native button appears or disappears naturally.
- Blenny may display its own `NSStatusItem` as a separate control.

### 5.3 Public APIs are insufficient for full automatic control

Public `NSStatusItem` APIs control only status items owned by Blenny itself. Accessibility can enumerate and sometimes activate other apps' status items, but on macOS 27 it does not provide a general writable hidden/position state for hosted items.

A fully automatic per-item manager will probably require some unsupported behavior, such as:

- Preferred-position state used by `MenuBarAgent`.
- Control Center preferences for selected Apple modules.
- Private visibility-restriction behavior.
- Other version-specific mechanisms discovered during the spike.

Consequences:

- A complete Blenny release is unlikely to qualify for Mac App Store distribution.
- Developer ID signing, notarization, direct downloads, and Homebrew are the likely distribution route.
- Unsupported behavior must be isolated behind a narrow backend with an emergency kill switch.

## 6. Ice and Thaw findings

### 6.1 Ice

Ice is GPL-3.0 and was developed as an independent Swift macOS application.

Important legacy techniques in Ice include:

- Creating divider `NSStatusItem` instances.
- Expanding a divider length to approximately `10,000` points to push status items out of view.
- Enumerating menu bar item windows using private CGS/SkyLight functions.
- Reordering by synthesizing Command-modified mouse events.
- Capturing status item imagery and presenting it in a separate Ice Bar.

These techniques were inventive and useful on older systems, but they are fragile around dynamic items, app relaunches, multiple displays, notches, system reflows, and macOS 27's new architecture.

### 6.2 Thaw

Thaw began as a fork of Ice and remains GPL-3.0.

Thaw added substantial machinery, including:

- Accessibility and WindowServer reconciliation.
- XPC services for ownership and process resolution.
- Move retries, timeouts, and validation.
- Layout profiles and identity caches.
- Screenshot and icon caches.
- Periodic refresh and state signatures.
- macOS 27 experimental backends.

This complexity explains why layout operations can feel slow: a visual drag may trigger cross-process calls, system moves, re-enumeration, validation, retries, and later reconciliation.

The macOS 27 preview recognizes that:

- The old WindowServer item mechanism is retired.
- Accessibility is useful primarily for enumeration.
- `AXHidden` is not writable for hosted macOS 27 status items.
- The native overflow chevron is a system placeholder to observe and exclude, not a control to replace.
- Preferred positions and visibility restrictions are used as alternative mechanisms.

At least the inspected `macos-27-preview.5` tag also references a `PlatformRuntimeKit` product from `thaw-app/prk-bin` version `0.0.11`, which was not publicly accessible during the investigation. Blenny must not depend on this binary or assume the preview backend is publicly reproducible.

## 7. GPL conclusions

If Blenny copied or modified non-trivial Ice code and distributed the result, it would normally need to remain GPL-3.0 and satisfy the GPL's corresponding-source and notice requirements.

Those requirements generally include:

- Preserve applicable copyright and license notices.
- State that the work was modified and provide a relevant date.
- License the distributed derivative work as a whole under GPL-3.0.
- Give binary recipients access to the complete corresponding source.
- Include build and installation material required to modify and rebuild it.

GPL does not require a fork to:

- Send telemetry or business information to the upstream author.
- Report user counts, download counts, or donation totals.
- Submit pull requests upstream.
- Transfer copyright in newly written code.
- Pay royalties.
- Publish private/internal modifications that are never distributed outside an organization.

Because Blenny will be a clean implementation, it may choose a new license. Candidates to decide later:

- GPL-3.0, to keep distributed derivatives open.
- MPL-2.0, to keep modified project files open while allowing clearer module boundaries.
- Apache-2.0, for permissive reuse with an explicit patent grant.
- MIT, for maximum simplicity and adoption.

Do not add a license file until the project owner chooses one.

## 8. Product scope

### 8.1 Proposed user model

Each manageable item has one of three policies:

1. **Pinned** — keep visible whenever possible.
2. **Automatic** — allow the system to overflow it when space is needed.
3. **Hidden** — prefer it to remain out of the primary menu bar and make it accessible on demand.

The initial settings interface may present these as three columns with drag and drop.

The system remains the source of truth for the currently rendered layout. Blenny remains the source of truth for user intent.

### 8.2 MVP features after the spike

- One native menu bar item owned by Blenny.
- A minimal layout editor.
- Pinned, Automatic, and Hidden policies.
- Stable persistence across app relaunches and login sessions.
- Observation of the native overflow state.
- A simple on-demand shelf only where necessary.
- Search and keyboard access if a shelf is included.
- A one-click "Stop Managing and Restore" safety action.
- Clear reporting when an item cannot be managed safely.

### 8.3 Explicit non-goals through version 1.0

- macOS 26 or earlier support.
- Menu bar tinting, borders, shadows, gradients, or custom shapes.
- Theme marketplace or extensive visual customization.
- Multiple profiles.
- Focus, Wi-Fi, battery, app-launch, or schedule-based rules.
- Hover, scroll, swipe, and empty-space gesture variants.
- Live status-item screenshot capture by default.
- Continuous high-frame-rate thumbnail refresh.
- Automatic migration from Ice, Thaw, or Bartender.
- Dozens of advanced settings.
- Any implementation that moves the user's cursor.

## 9. Proposed architecture

Keep product logic independent from unsupported system mechanisms.

```text
BlennyApp
├── StatusItemController
├── AccessibilityInventory
├── NativeOverflowObserver
├── ItemIdentityStore
├── MenuBarPolicyEngine
├── MacOS27LayoutBackend
├── RestoreCoordinator
└── ShelfPanel (optional after validation)
```

### Responsibilities

`StatusItemController`

- Own only Blenny's `NSStatusItem`.
- Present a minimal menu or settings surface.

`AccessibilityInventory`

- Enumerate menu bar items without mutating them.
- Attribute items to their owning app or `MenuBarAgent`.
- Collect candidate identity attributes and frames.

`NativeOverflowObserver`

- Detect whether the system overflow control is present on each display.
- Treat the result as presentation state only.

`ItemIdentityStore`

- Persist user intent using the most stable available identity.
- Never use PID, transient window ID, image bytes, or current x-coordinate as the sole permanent identity.

Candidate identity components:

- Owning bundle identifier.
- `NSStatusItem` autosave/preference identifier where discoverable.
- Accessibility identifier or stable title.
- Role/subrole.
- Instance ordinal for multiple items from one app.
- A migration strategy when an app changes one component.

`MenuBarPolicyEngine`

- Convert Pinned/Automatic/Hidden user intent into an ordered desired state.
- Remain deterministic and testable without macOS private APIs.

`MacOS27LayoutBackend`

- Be the only component allowed to mutate system layout state.
- Serialize all writes through one actor or equivalent single writer.
- Batch and debounce changes.
- Apply after a drag ends, never during every pointer movement.
- Verify at most once and retry at most once.
- Stop and report a failure instead of entering a reconciliation loop.
- Keep private and version-sensitive code isolated.

`RestoreCoordinator`

- Snapshot every system value before Blenny changes it.
- Restore values after failed experiments.
- Support an explicit reset action.
- Avoid leaving the menu bar damaged after a crash wherever possible.

## 10. Performance and reliability requirements

- Dragging in Blenny's UI must update only local state and remain frame-smooth.
- System changes must be applied asynchronously after the user completes an action.
- No synthetic mouse movement on macOS 27.
- No permanent one-second polling loop.
- Idle CPU should be effectively zero when the observed item set is unchanged.
- Avoid Screen Recording permission in the baseline design.
- Prefer owning-app icons over live captured status-item images.
- Limit failed system writes to one retry.
- Use event-driven observation where reliable; provide manual refresh during the spike.
- If state cannot be verified, preserve the user's menu bar rather than forcing the desired layout.

Longer-term targets:

- Local drag feedback below 8-16 ms per frame.
- No main-thread cross-process Accessibility calls.
- Modest memory usage, with a tentative target below 40 MB in normal idle use.
- No recurring layout writes when the user has made no change.

## 11. Version 0.0.1 technical spike

Version `0.0.1` is an engineering probe, not a product release.

### 11.1 Questions it must answer

1. Can a normally signed third-party app enumerate macOS 27 status items reliably through Accessibility?
2. Which attributes are stable across app relaunch, menu bar reflow, sleep/wake, and display changes?
3. Can the native overflow control be detected per display without polling continuously?
4. Can Blenny create its own status item without destabilizing the native overflow layout?
5. Does changing Blenny's own status item length predictably influence native overflow?
6. Can preferred trailing positions be read, safely changed in one transaction, observed, and restored?
7. Can selected third-party items be made to overflow first without synthetic mouse input?
8. Which Apple system items resist this model?
9. Does any tested operation cause the clock, Notification Center, Control Center, or native overflow button to stop responding?
10. Can every mutation be automatically rolled back?

### 11.2 Required phases

#### Phase A: read-only probe

- Detect macOS version and build.
- Check Accessibility trust and provide a clear permission path.
- Enumerate application `AXExtrasMenuBar` trees.
- Enumerate `MenuBarAgent`'s relevant Accessibility tree.
- Print or display role, subrole, title, description, identifier, owner PID, bundle ID, frame, actions, and attribute-settable results.
- Identify the native overflow control without treating it as a normal managed status item.
- Record candidate stable identities.
- Repeat enumeration after relaunching several status-item apps.

#### Phase B: Blenny-owned item

- Create one template-rendered `NSStatusItem`.
- Verify native clicking, menu presentation, and removal.
- Test a controlled range of lengths for Blenny's own item.
- Observe whether and how native overflow changes.
- Restore the standard length after each test.

#### Phase C: reversible layout mutation

Begin only after read-only enumeration and a restore mechanism work.

- Snapshot relevant `MenuBarAgent` preference state.
- Investigate preferred trailing positions.
- Apply a minimal one-item or two-item change.
- Avoid synthetic mouse events.
- Verify the result once.
- Restore the exact prior state.
- Repeat across an app relaunch and a `MenuBarAgent` restart only if it is safe.

Private mutation experiments must remain debug-only and clearly labeled.

### 11.3 Go/no-go criteria

Proceed toward a product MVP only if:

- Third-party status items can be enumerated with useful ownership and identity data.
- Native overflow can be observed reliably.
- A meaningful visibility priority can be applied without moving the cursor.
- Mutations can be restored deterministically.
- The backend does not need continuous rewriting to keep a simple layout stable.
- Clock, Notification Center, Control Center, and multiple displays remain functional.

Pause or redesign if:

- Stable identity requires image matching or current coordinates alone.
- MenuBarAgent overwrites every change unless Blenny continuously fights it.
- Hiding one item requires whole-bar recomposition on every interaction.
- Restoring the original state is unreliable.
- Normal use repeatedly requires restarting system UI processes.

## 12. Test matrix

The feasibility spike should record the exact OS build and hardware configuration for every result.

Priority scenarios:

- Built-in display with a notch.
- Built-in display without a notch, if available.
- One external display.
- Multiple displays with different scaling.
- App launch and quit.
- Status-item app relaunch and update-like replacement.
- Multiple status items from one bundle.
- Dynamic items such as Focus, Now Playing, VPN, microphone/camera indicators, and system monitoring apps.
- Sleep and wake.
- Lock and unlock.
- Spaces and full-screen apps.
- Menu bar auto-hide enabled and disabled.
- Native overflow present and absent.
- Clock and Notification Center interaction after every mutation experiment.

## 13. Market and positioning notes

As of 2026-08-21, approximate public GitHub figures observed during research were:

- Ice: 29,332 stars, 847 forks.
- Thaw: 9,944 stars, 238 forks.
- Thaw 1.2.0's principal ZIP asset: approximately 79,000 downloads.

These counts validate user interest but do not represent unique active users or donation conversion.

Current competition includes:

- Ice and its forks.
- Thaw.
- Bartender's macOS 27 preview.
- Tuck's macOS 27 preview.
- BetterTouchTool menu bar functionality.
- Other smaller shelf and notch utilities.

Apple's native overflow commoditizes basic hiding. Blenny's differentiation must therefore be reliability, restraint, and native integration rather than feature count.

Possible positioning:

- “Set it once. It stays set.”
- “A quiet home for menu bar icons.”
- “Native menu bar organization for macOS 27.”
- “No cursor hijacking. No dancing icons.”

## 14. Distribution and sustainability

Probable distribution if private mechanisms remain necessary:

- GitHub Releases.
- Developer ID signed and Apple-notarized builds.
- Homebrew Cask.
- Reproducible or well-documented builds where practical.

Possible sustainability model:

- GitHub Sponsors or similar donations.
- Transparent development roadmap and compatibility status.
- Optional payment for convenient signed builds or support, depending on the final license.
- No aggressive donation prompts inside the core interaction.

Stars, downloads, and donations should be treated as outcomes of trust and reliability, not primary product requirements.

## 15. Principal risks

1. Apple may change private `MenuBarAgent` behavior in any macOS update.
2. Apple may later expose native per-item management and reduce the need for Blenny.
3. Accessibility identity may remain ambiguous for multiple items from one app.
4. Some Apple system items may be impossible to manage individually.
5. Direct distribution and Accessibility permission may reduce onboarding conversion.
6. Attempting to control every edge case could recreate Thaw's complexity.

Mitigation:

- Keep the backend narrow and replaceable.
- Publish an exact compatibility matrix per macOS build.
- Make unsupported items visible in the UI rather than silently retrying.
- Maintain a safe mode and a complete restore path.
- Keep product scope intentionally small.

## 16. Research sources

- Ice repository: <https://github.com/jordanbaird/Ice>
- Thaw repository: <https://github.com/thaw-app/Thaw>
- Thaw macOS 27 tracking: <https://github.com/thaw-app/Thaw/issues/687>
- Thaw frequent issues: <https://github.com/thaw-app/Thaw/blob/development/FREQUENT_ISSUES.md>
- Thaw macOS 27 AX provider: <https://github.com/thaw-app/Thaw/blob/macos-27-preview.5/Thaw/MenuBar/MenuBarItems/MenuBarItemAXProvider.swift>
- BetterTouchTool macOS 27 investigation: <https://community.folivora.ai/t/macos-27-golden-gate-menu-bar-management-broken-solutions-ice-thaw-bartender-barbee-etc/47232>
- Bartender for macOS 27: <https://www.macbartender.com/goldengate/>
- Tuck: <https://usetuck.com/>
- Apple `NSStatusItem`: <https://developer.apple.com/documentation/appkit/nsstatusitem>
- Apple App Review Guidelines: <https://developer.apple.com/app-store/review/guidelines/>
- GPLv3 text: <https://www.gnu.org/licenses/gpl-3.0.html>
- GNU GPL FAQ: <https://www.gnu.org/licenses/gpl-faq.en.html>

## 17. Immediate next action

Use [`NEXT_SESSION_PROMPT.md`](NEXT_SESSION_PROMPT.md) to begin the `0.0.1` technical feasibility spike in a new development session.
