# Notification Center during menu-bar management

Status: **Three bounded investigation rounds completed without a validated replacement
hiding backend. The final round identifies Clock's exact suppression point and
corrects the earlier hot-key attribution. The documented 0.9.0 limitation remains;
it is not fixed.**
Runtime: macOS 27.0 build `26A5425a`, arm64e. This is a follow-up to the
[0.9.0 spike](TECH_SPIKE_0.9.0.md), not version closure or release authorization.
The [final technical report](NOTIFICATION_CENTER_TECHNICAL_REPORT_2026-09-12.md)
contains the complete producer-to-Clock chain and the final AppKit investigation.

## Required behavior

The desired repair would let the native clock open Notification Center while
Blenny manages the menu bar. Following the second bounded search below, the owner
accepts the current interaction failure as a disclosed 0.9.0 limitation instead
of requiring a repair for this milestone. Visible, Revealable and Hidden intent
must remain distinct. Any future fix must
not silently show Hidden items, simulate input, inject or patch another process,
restart system services, poll continuously, or establish a second product writer.
Time Machine and the already accepted ordering/visibility behavior must remain
unchanged. The owner explicitly rejects automatic management suspension around Clock clicks;
it will not be implemented.

## Owner evidence

The owner restarted SystemUIServer and reused the existing no-wait test build.
Time Machine works in all three states. The clock fails to open Notification
Center during management and works immediately after Stop; quitting Blenny is
unnecessary. The owner subsequently confirms that swiping left from the trackpad
right edge opens Notification Center while management remains active. This narrows
the defect to the Clock entry rather than general panel availability. It is an
owner-operated observation; the complete gesture call chain remains untraced.
This isolates the remaining reported interaction failure from Time
Machine restoration or ordering. It does not establish multi-display coverage.

## Static chain on the installed runtime

1. Blenny holds an `MBAssessmentModeAssertion` through the existing serial writer.
   Stop invalidates that assertion. The clock's numbered visibility identity is
   already allowed by the planner.
2. MenuBarAgent resolves restriction origins independently of the assessment
   allowlist. `ResolveRestrictionsStep.Output` contains five Boolean fields and
   then a separate assessment allowlist:
   `isInAssessmentMode`, `isCampoDraggingOut`, `isUserSessionTransitioning`,
   `hasExternalRestrictions`, and `hasAnyRestriction`.
3. The resolver computes `hasExternalRestrictions` by finding any origin other
   than `campoDrag`. It computes `hasAnyRestriction` from a nonempty restriction
   dictionary. Neither computation reads the assessment allowlist. Assessment
   and user-session-transition assertions therefore make both flags true even
   with a pass-through allowlist.
4. The final audit follows `hasExternalRestrictions` through the component Output,
   `notifyVisibilityRestrictionsDidChange` action and server witness into the
   broadcast. It is not the separate `hasAnyRestriction` field. The payload carries
   no clock identity, bundle identity or allowlist. The Core monitor maps nonzero
   to active; the client monitor forwards that state to its delegate.
5. ControlCenter compares the state with `.active` and writes
   `Clock.shouldIgnoreMenuExtraEvents`. The Clock handler then consumes the event
   before sending `ncMenuMouseDown` / `ncMenuMouseUp` to Notification Center.
   Notification Center's hot-key gate is a separate consumer, not the Clock route.
   The early return is proven statically; its relationship to the brief visual
   highlight is consistent with the owner observation, not a traced drawing path.

This establishes an interaction conflict with the current restriction backend.
Changing ordering values, restoring wait delays, or adding guessed owner names
is not a supported repair for that conflict. Running-application observation also
found SystemUIServer, Control Center and Notification Center present; missing
inventory is not established as the cause.

### Reproducible static anchors

These are addresses in the inspected Apple binaries, not supported API contracts
or addresses to patch. Raw Apple disassembly is not included in Git.

- NotificationCenter UUID: `D0CFEB98-2A67-3BB6-959C-8028756DB7FF`; linked
  MenuBarClient version `97.0.9`.
- Notification Center monitor initialization: `0x10016DFD8` / `0x10016DFF0`.
  Active comparison: `0x1001766FC`–`0x100176754`.
  Presentation gates: `0x100172EC0` and `0x100172F50`.
- MenuBarAgent resolver Output nominal descriptor: `0x100399E60`; field
  descriptor: `0x1003C74B8` (six fields, 12-byte field records).
- Resolver begins at `0x1000117A8`. External-restriction helper begins at
  `0x100011D90`: origin comparison at `0x100011FC0`, skip internal drag at
  `0x100011FE8`, true at `0x100011FEC`, exhausted/false at `0x100011FF4`.
- Output construction `0x100011D2C`–`0x100011D58`: external flag uses that helper;
  any-restriction flag uses dictionary count. Allowlist folding is separate at
  `0x100012028`.
- Broadcast `0x10034CAC4` creates one NSNumber and sends it to the connection
  collection. Client delivery at `0x10034F2A8` invokes
  `visibilityRestrictionsDidChange:`.
- External origin decoder `0x10034E1F4` accepts assessment and user-session
  transition origins. It does not accept the separately exported internal
  `campoDrag` origin; unknown input becomes a missing/invalid origin.

Further Objective-C metadata resolves the hot-key open thunk
`hotKeyRequestCenterOpenOnDisplay:` at `0x100172FAC`; it directly calls the gated
entry at `0x100172F50`, returning at `0x100172F6C` while restricted. The adjacent
gated close entry belongs to this presentation path. The earlier attribution of
this thunk to Clock was incorrect: final ControlCenter inspection finds the native
Clock suppression before its distinct menu XPC request. No claim is made about future macOS
builds, all private interfaces, or a generally supported restriction override.

### Alternative entry checks

- The native Clock menu endpoint `com.apple.notificationcenterui.menu` checks
  `com.apple.private.notificationcenter.menu` on the incoming connection and
  rejects absent, false or non-NSNumber values. Final inspection proves this
  listener branch, not merely the presence of an entitlement string. It is not
  a replacement entry available to Blenny.
- NotificationCenter's Info.plist declares no URL or document handlers. Outbound
  notification-content URL actions are not an inbound open-center API.
- The Dock-to-Notification-Center path includes `ncToggleNotificationCenterOnDisplay:`
  but uses a private entitlement channel. Dock's connection acceptance checks
  `com.apple.private.notificationcenter` before configuring the connection
  (inspected acceptance path at `0x1000754C4`). This is not available to Blenny
  under the repository's no-private-entitlements requirement.
- The remote-alert host route likewise checks
  `com.apple.private.notificationcenterui.nchostable`. No host launch was attempted.
- The inspected distributed-notification strings did not establish an open/toggle
  request. `com.apple.notificationcenter.opened` appears in notification/analytics
  context and is not evidence of a command. No notification was posted.

These checks narrow the plausible alternatives; they do not prove the absence
of every possible private route. No usable, permitted alternate entry was found.

## Evaluated paths

| Path | Evidence and disposition |
| --- | --- |
| Allow the clock or its host | Clock already allowed; changing the allowlist does not change either aggregate restriction flag. |
| Use an all-pass-through allowlist | Still retains an assessment restriction. Not a hidden-items-preserving fix; no new live assertion was issued. |
| Switch to user-session-transition origin | Also creates an external restriction. Not a compatible alternative. |
| Submit internal drag origin | External decoder rejects it. Do not invent origin values or emulate native drag state. |
| Use a dedicated Notification Center exception | None on the inspected assessment configuration; it only exposes bundle and system-item allowlists. |
| Use another public status-item visibility API | Apple's NSStatusItem API controls status-item instances; no cross-owner replacement is established by its documentation. |
| Call another open-center entry | Native Clock events are suppressed in ControlCenter; the separate hot-key path is gated. The inspected Dock path requires private entitlement, and no inbound URL/distributed-command route was established. |
| Suspend management around Notification Center | Explicitly rejected by the owner; suspension can expose Revealable and Hidden applications and will not be implemented. |
| Replace the restriction hiding backend | Preserves the desired goal in principle, but no working replacement is established by this investigation. This is further backend work, not a small parameter fix. |

[Apple's NSStatusItem documentation](https://developer.apple.com/documentation/appkit/nsstatusitem)
describes item-instance visibility; it does not establish a replacement cross-app
hiding capability for this task.

## Implemented research and verification

[The read-only contract inspector](../Research/NotificationCenterCompatibilityProbe/README.md)
is excluded from product build targets. It enumerates class/protocol contracts
without creating assertions or XPC connections. The investigation used Xcode 27
and the macOS 27 SDK explicitly.

A separate ignored passive XPC observer was compiled and run once with a five-second
deadline. It timed out without a callback. It did not request a remote proxy or
invoke any server method. This result is not evidence of an inactive restriction:
only the absence of an observed callback was established. The final static audit
finds an initial-state delivery scheduled on the configured-client acceptance
path; the timeout does not prove that the server lacks initial-state delivery.
No retries,
real visibility/order writes, process restarts, installation, or input automation
were performed.

Product source still matches the preceding tested candidate. Its automated tests
remain fixture evidence and cannot establish a new native interaction fix. No
replacement app is claimed or shipped as a repair. The original research, dirty
workspace and existing recovery data remain preserved.

## Second bounded search and owner disposition

The owner requested one further search for a replacement hiding backend, with
explicit acceptance of a documented limitation if none was established. This
supersedes the previous pending choice about automatically suspending management.
The second round examined additional ownership contracts, saved item visibility,
spatial hiding, native overflow, and independently controlled system preferences.
It found no validated replacement within the current product constraints.

| Candidate | Additional evidence and remaining gap |
| --- | --- |
| Item-manager registration and global visibility | `MBMenuBarItemXPCServer` exposes `setItems:` and `setGloballyHidden:`. The inspected server associates requests with their client connection and its process identity; these calls do not establish authority to conceal another application's items. A selector name alone is not a cross-owner API. |
| Owner autosave visibility preferences | The macOS 27 SDK documents visibility persistence by `autosaveName`. This does not establish that external preference changes are adopted by live third-party items, or that exact restoration survives owner relaunch and replacement. No such preference was written in this investigation. |
| Spacer length and preferred order | AppKit can allocate space to Blenny's own items, but that is not a target-specific concealment contract. Preferred order is relative, not a clipping boundary. No current-runtime implementation guarantees both ordinary Reveal and continued exclusion of Hidden owners. |
| Native overflow alone | Available width and system layout determine overflow. It does not supply separate Revealable and Hidden exclusion sets. Using it as the only hiding backend would change the product semantics. |
| Individual system preferences | The existing exact adapters cover selected Apple items. They supply no general visibility interface for third-party bundles, so they cannot replace the bundle backend. |
| Expanded interfaces, sessions and whole-menu-bar controls | Own-item popup lifecycle or whole-bar visibility is not selective third-party concealment. |

Connection-scope anchors in the existing MenuBarAgent disassembly are
`0x100037DB0` onward (remote token/PID and application-session resolution),
`0x100038D2C` / `0x10003919C` (`setItems:` forwarding), and
`0x10003B5DC` / `0x10003BB28` (`setGloballyHidden:` forwarding). The calls carry
client-connection context rather than an arbitrary foreign application selector.
These anchors support the scoped conclusion above, not a claim that every
uninspected server implementation has been proved inaccessible.

The public documentation cross-check also supplied no independent replacement:

- [Hidden Bar's architecture](https://github.com/dwarvesf/hidden/blob/develop/docs/ARCHITECTURE.md)
  describes spacer-based hiding and reports that macOS 27 breaks that mechanism.
  This is upstream evidence, not a new live test of every possible spacer design.
- [Pelmet's README](https://github.com/fif7y/pelmet) describes assessment-based
  hiding. Its [FAQ](https://github.com/fif7y/pelmet/blob/main/docs/FAQ.md) describes
  briefly revealing all items around Clock clicks. That changes concealment
  semantics rather than providing a replacement backend. The trackpad route was untested at this stage; the owner subsequently verified
  that it opens Notification Center during Blenny management on the tested setup.
- [Thaw's macOS 27 Preview 3 notes](https://github.com/thaw-app/Thaw/releases/tag/macos-27-preview.3)
  describe item compatibility improvements but do not establish a separate backend
  preserving Clock interaction. No implementation or binary was copied or run.

These are bounded negative findings, not proof that a future backend is impossible.
There is no new live mutation, system restart, assertion, or preference experiment
in this round. Raw evidence stays under ignored local research output. Product
code and the installed candidate remain unchanged; no new repair build is claimed.

The [functional limitation](KNOWN_LIMITATIONS.md) now states the affected native
Clock action, tested runtime and explicit Stop / manual Resume workaround. Stop
releases concealment, including Hidden items; Blenny does not do this automatically.
The issue is accepted for 0.9.0 and is no longer, by itself, a mandatory-fix blocker.
It is not marked repaired, and no new runtime coverage or release authorization
follows from that acceptance. Publication still requires the repository's complete
compatibility, recovery, disclosure and distribution gates.

## Final causal and alternative-backend audit

The owner requested a final investigation prioritizing an exact technical cause
even if no compatible repair could be found. The
[technical report](NOTIFICATION_CENTER_TECHNICAL_REPORT_2026-09-12.md) closes the
producer flag selection, Core/client state conversion and ControlCenter's Clock
event gate. It explicitly corrects the earlier Clock-to-hot-key inference.
The Clock handler returns a consumed result before any menu XPC request; this
explains why no remote error or timeout accompanies the missing panel.

The final AppKit scan also finds the concrete distinction between saved visibility
and live visibility. Saved `Visible` / `VisibleCC` preferences are restored during
owner-side autosave-name initialization or reset. Live host updates instead follow
owner scene settings through `clientRequestsVisibility` KVO. No external-defaults
adoption trigger was found in that path, and the host's visibility-key getters
return `nil`. External preference editing therefore remains unsuitable as a proved
live cross-owner backend.

This final round performed no real assertion, preference write, remote invocation,
process restart or installation. It changes the precision of the diagnosis, not
product behavior. Stop further parameter/delay trials for this issue in 0.9.0;
retain the disclosure and the subsequently owner-verified trackpad alternative. This does not
discard existing work, close the version, or decide the pending public-source
discussion.

## Future repair acceptance gate

Before any replacement is called a fix, verify native clock interaction during
management, after ordinary reveal/conceal, after policy/order Apply and after
Stop/Resume, while confirming Hidden owners do not leak into an ordinary reveal.
Include failure, interrupted transition and recovery coverage in the sole writer.
Any real experiment needs a concrete target scope and restoration plan. A future
repair must retain the three-state contract unless the owner explicitly changes
it. A failed native Clock interaction on the recorded runtime remains an expected
known limitation, never a passing interaction test. The other version-completion
and publication gates are unchanged.
