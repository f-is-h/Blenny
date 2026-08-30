# Blenny 0.5.1 Technical Patch

## Review usability and resilient Apply

Status: code and release checks audited on 2026-08-30; final compact-spacing visual acceptance and local tag remain pending. This patch does not modify or move `v0.5.0`.

## Problem

The 0.5.0 routine Review exposed the full engineering dry-run report. It was
auditable but poor product UI. Review authorization also included unrelated
running processes, so harmless process churn could reject Resume with a generic
`staleReviewedPlan` error. Finally, applying a Draft while management was stopped
saved the policy but did not activate it.

## Decision

- Owner decision: ordinary users do not see a Review page. Apply, Resume,
  Stop, and Restore each prepare and validate an immutable single-use plan
  internally, then commit it. Assignment itself remains Draft-only.
- Preparation and commit share an interaction gate. Duplicate clicks, Draft
  edits, Refresh and reveal transitions cannot overlap an in-flight action.
  Errors remain visible and preserve the Draft; there is no automatic retry of
  a stale plan.
- Stop remains available with a dirty Draft and preserves those unapplied
  assignments. Resume and Restore require applying or discarding that Draft
  first, so they cannot silently replace it. Termination closes the interaction
  gate, waits for the bounded in-flight action, then cleans up the writer.
- Keep bounded process-local action audit records (action, phase, binding and
  plan fingerprints). The existing atomic policy, previous-policy backup and
  transaction marker remain the durable recovery source. Do not add an
  always-on disk logger or persist unrelated process inventories. Debug dry-run
  evidence can still be redirected explicitly into ignored LocalData.
- The complete hashes, exact allow-lists, transaction details, and recovery steps
  remain available in the Debug installed dry-run and ignored local evidence.
- A valid Draft Apply proposes `managementEnabled=true` on the supported Debug
  boundary. Stop Managing remains the explicit reviewed way to persist disabled
  intent.
- Review authorization binds accepted policy, Draft, candidate generation,
  validation scope, runtime contract, recovery backup, and the candidate and
  running state of approved managed bundles.
- Unrelated pass-through processes are excluded from the authorization binding.
  Apply still performs one fresh bounded scan, rebuilds the full exact baseline
  and ordinary-reveal plans from that scan, and sends only that refreshed plan to
  the serial writer.
- A managed bundle PID, ownership, availability, assignment, scope, policy,
  runtime, backup, or generation change remains stale and fails before writer
  access.
- User-facing stale errors name the corrective action instead of exposing an enum
  number.
- A Draft edit during the bounded Apply preflight is rejected before commit.
- A no-op keeps the actual active plans and does not claim a freshly rebuilt
  pass-through plan was written. It creates no assertion and rotates no backup.
- The normal AppKit controls use two native NSStatusItems: Blenny artwork and
  13-point medium double chevrons in two compact 22-point items. Each native button has its own action;
  artwork opens the editor, while the arrow
  sits on the left and toggles a session independently of native presence.
  The inline arrow remains present throughout active/revealed states; the explicit reveal/conceal
  menu action remains reachable. Right-click and an Accessibility custom action
  retain the safety/recovery menu. Inactive, unsupported
  and busy states do not accept reveal actions. A completed reveal changes the
  direction; failed transitions retain the proven direction or disable the
  control after fail-closed cleanup. The ordinary 30-second bounded session still closes itself.
- The ordinary path now explicitly owns the previously prototype-only native
  overflow observer. A present, observable, known native state selects native
  ownership for native events, but never disables Blenny's explicit button.
  An explicit Blenny click supersedes queued native intent and can also conceal
  a native-owned session. A Blenny-opened transition retains its owner while in
  flight, even if its own reveal makes native overflow appear. Once it finishes,
  fresh native edges may continue that session. The first snapshot is not a click.
  Only known expand/collapse edges can request native-owned transitions.
- Native events coalesce into at most one pending intent and use the same
  interaction gate and serial writer as fallback actions. Duplicates do not write.
  A collapse received during reveal activation is retained; a reflow during
  conceal cannot queue an immediate reopen. Unknown or lost native observation
  closes a native-owned session and selects fallback after verified conceal.
- Apply, Stop and Restore suspend native intent and discard stale queued events.
  A session-specific timeout also enters through the gate, waiting behind a
  bounded Refresh instead of racing it. Termination detaches the observer and
  prevents callbacks from starting more work. Observer contexts reject callbacks
  from a previous registration; replaced AX elements are unregistered.
- Discovery is bounded by depth, element count, a one-second traversal deadline
  and per-message timeout. Native notifications do not refresh the application
  candidate inventory or authorize new bundles. There is no polling, position
  write, synthetic input, or promotion of the old placement/length experiments.
- Installed validation exposed another prototype gap: unrestricted descent into
  MenuBarAgent child menus exhausted the element limit. Native discovery now
  reuses the inventory's privacy boundary: AXExtrasMenuBar containers stop at
  buttons/status items; menu-bar-sized agent presentation roots expose only one
  child level. Unrelated application menu/window content is not traversed.
  Unavailable observation carries a scoped reason rather than claiming absence.
- One read-only sample after an explicit operation or Workspace application
  activation discovers newly created overflow controls when container layout
  notifications are absent. Discovery may close an unsafe native-owned session,
  but never interprets an expanded snapshot as a reveal request or schedules
  another sample. Subsequent registered native value edges drive the session.

## Ordinary-path integration audit

The prototype was separately launched and therefore was not inherited merely by
retaining its source. The patch explicitly checks each entry point:

| Capability | Ordinary-path result |
| --- | --- |
| Native overflow events | Connected through `OrdinaryRevealCoordinator`; same verified writer as fallback |
| Native discovery | Reuses the bounded inventory traversal policy; unrelated menus cannot exhaust the native scan |
| Session ownership and Hidden exclusion | One owner per session; immutable accepted reveal plan, never Hidden |
| Session timeout | Session identity plus shared interaction gate; no out-of-band write |
| Manual Refresh | Read-only after the first startup recovery; no silent assertion replacement and no Draft discard |
| Failed reveal | Verify and retain the preceding baseline once; failed/throwing verification fails closed |
| MenuBarAgent exit | Stop observation, invalidate writer, report unrestricted; no automatic reconnect |
| Termination | Wait for active interaction and connection cleanup; reject late callbacks and activation publication |
| Stop, Restore, persistence | Existing prepared transaction and scoped backup remain mandatory |
| Prototype placement, length, experiment timeout and fixture actions | Deliberately not promoted |

MenuBarAgent process termination is an observable connection-loss boundary, not
a newly proven private XPC invalidation callback. The private assertion contract
still exposes only activation completion and explicit invalidation. Silent
connection loss without a process-exit signal, broader lifecycle/display behavior,
and guaranteed collapsed-bar placement remain unproven and deferred. `Visible`
is an allow policy, not a guarantee that macOS cannot overflow Blenny itself.
The desired edge-adjacent location is recorded as a later positioning question;
this patch does not investigate or write positions.

## Safety boundary

The 0.5.0 Debug-only runtime boundary, single serial writer, activation and
verification rules, bounded retry, transactional persistence, rollback,
restoration, lifecycle cleanup, Apple read-only boundary, Blenny Visible rule,
Hidden exclusion, and Release isolation are unchanged.

No sorting, polling, automatic reconciliation, synthetic input, menu-bar pixel
capture, helper, IPC, daemon, mutable Apple item, or Release backend promotion is
added.

## Native-control handoff follow-up

Historical handoff attempt: the auto-hide rule below was superseded by the
own-arrow follow-up. Native-control repair is still not accepted as complete.

The owner requested arrow-left/artwork-right placement, a smaller arrow matching
the supplied crop, and no duplicate Blenny arrow when native overflow is usable.
The previous fix kept the explicit action reachable but retained the prototype's
inactive-owner rule: native edges during a Blenny-opened session were deliberately
ignored. That behavior does not meet the requested handoff.

- Use 13-point regular chevrons to reduce the oversized 16-point glyph.
- Keep a directly usable safety-menu reveal/conceal action, even when the inline
  arrow is hidden. Unknown or unavailable native observation shows the fallback.
- Hide only the inline arrow when the native control is present, observed and
  known. Reserve the same two control slots while management is active so hiding
  the arrow cannot itself create/remove overflow and cause a layout feedback loop.
- An initial snapshot, discovery, or native appearance never writes. A fresh
  known native edge may control an already revealed Blenny session once its
  transition has finished. It uses the same prepared plan, interaction gate,
  bounded session deadline and serial writer. In-flight Blenny reflow cannot
  race the operation; conceal reflow cannot immediately reopen it.
- Retain subscriptions for unchanged AX elements. Read the notifying native
  element for value changes instead of unregistering and rediscovering the whole
  control tree on every edge; topology changes still get one bounded discovery.
- This observes and follows native state; it does not intercept, suppress or
  replace Apple's input, layout or animation.
- The historical self-position-500 receipt in the 0.0.3 spike proves only its
  bounded test. Ordinary self-placement promotion remains a separate owner
  decision; no position write is added by this handoff fix.

## Own-arrow click and visibility follow-up

Historical coordinate-routing attempt: the owner subsequently confirmed that
visibility and direction were correct but physical left clicks still did not
toggle. The hit-test checks below did not prove real action delivery. This path
is replaced by the dedicated native buttons described next.

The owner reports that the safety-menu toggle works, while Blenny's arrow
disappears after expansion and its physical click is unreliable. Native-control
repair is a separate undecided scope item and is not attempted here.

- Remove native presence from inline-arrow visibility. A native AX snapshot is
  not proof that the native control can replace Blenny's own working action.
- Keep the arrow left and artwork right in stable 26-point hit regions. The
  parent NSStatusBarButton owns physical tracking; its child presentation stack
  passes hit testing through. Route the left region to exactly the same toggle
  as the menu, and the right region to the editor. A busy left region is a no-op,
  not an accidental editor click. Secondary click retains the safety menu.
- Preserve separate child accessibility actions and labels. No system-wide
  event monitor, synthetic event, new writer path or position write is added.
- Verify local AppKit hit testing without creating a status item or displaying a
  window, and test repeated reveal/conceal with changing native presence. Debug
  installed diagnostics record action names and the own-arrow hit-route result,
  not pointer coordinates or pixels.
- Existing native observer/session code is unchanged. Its installed behavior
  remains unresolved; this fix neither claims to intercept native clicks nor
  guarantees Blenny a physical position outside macOS overflow.

## Dedicated native buttons follow-up

- Use two normal NSStatusItems with independent NSStatusBarButton actions.
  The arrow invokes the same toggle as the working menu; the artwork opens the
  editor. No NSApp.currentEvent location, subview hit test, pointer sampling,
  event injection, global monitor or preferred-position write is involved.
- Create both 26-point items before the first inventory and retain them until
  Quit (the final spacing follow-up reduces each item to 22 points). Inactive/unavailable management leaves the native arrow visibly disabled
  with an explanatory label; it is not removed and re-created during management
  transitions. This keeps Blenny's own candidate item count stable for prepared
  policy bindings. The artwork and safety menu remain available.
- Busy state disables the arrow. Direction follows only the verified baseline
  or reveal state, independently of native overflow presence. Each native
  button exposes its own accessibility label and action.
- The historical explicitly launched Debug policy prototype keeps its separate
  single-item control. Release still has no mutation backend or diagnostic switch.
- Test sender-identity routing, unavailable/busy guards and repeated toggle
  direction. Installed acceptance must capture an actual arrow action followed
  by the verified state transition; geometry or action-binding inspection alone
  does not establish physical click success.
- This replaces only Blenny's own click path. Native system-arrow behavior,
  ordering/own-position promotion, policy, writer and recovery scope are unchanged.

## Failed-startup Resume follow-up

Persisted `managementEnabled=true` is intent, not proof of an active assertion.
The editor and status menu enable explicit Resume from inactive/fail-closed
states after Accessibility is granted, while busy actions and dirty Drafts still
block it. Stop stays available to persist disabled intent. Refresh remains
read-only and never retries startup in the background.

Resume captures current candidate ownership for internal preparation, then checks
the fresh runtime and observation again at commit. The prepared persistence mode
explicitly identifies Resume. If accepted enabled intent is unchanged but no
assertion exists, the transaction acquires a fresh writer, activates the exact
baseline and verifies it without saving policy or rotating backup. A repeated
Resume with the same verified active plan is a no-op. Missing/incompatible or
changed recovery backup rejects before writer access. Activation/verification
failure restores unrestricted state: persisted enabled intent must not be used
to invent a previously active baseline. Termination and connection invalidation
still require a new process, not an in-process reconnection.

Startup validation errors name missing managed bundles and ask the user to open
them before Resume. This development boundary still requires all scoped targets
to be running and attributable; launching only some targets is not partial
authorization to change the plan. No candidate is silently removed from policy.

## Deterministic acceptance

- Unrelated running-process churn keeps the reviewed authorization valid.
- Apply rebuilds the exact plan and includes the current unrelated pass-through
  process before writer access.
- Managed candidate PID replacement still invalidates Review.
- Draft, generation, scope, runtime, policy, and backup changes remain stale.
- Draft Apply from stopped management proposes an active policy.
- Routine Apply has no visible Review route and still requires a validated plan.
- Busy gating prevents duplicate actions and Draft/Refresh/reveal overlap.
- Status chevrons, click routing, no-Revealable policy, busy, stopped,
  unsupported, failure and termination presentations are deterministic.
- Native known-state edges, duplicate/initial snapshots, collapse during
  activation, fallback ownership during activation, later native handoff, observer unavailability,
  suspended policy actions, stale timeout generations, conceal reflow, and
  direct clicks with native overflow present, direct conceal of native sessions,
  direct-intent priority, and startup/Stop/Resume arrow availability are deterministic.
- Native events and ordinary fallback use the same fake-writer integration test;
  reveal failure retains the verified baseline and throwing verification cleans up.
- A native collapse after a completed Blenny reveal closes the same session;
  native appearance and post-write discovery cannot immediately undo that reveal.
- Native presence, absence and expansion do not hide Blenny's native arrow.
  Dedicated sender actions, busy rejection and disabled inactive presentation are deterministic.
- A delayed successful verification after connection invalidation cannot publish
  active management again; the lifecycle generation must still match.
- Audit records are bounded, contain no raw bundle inventory, and do not replace
  the atomic recovery files.
- Debug and Release test suites pass; Release still lacks the Debug backend.

## Installed acceptance

Build and install the final Debug app, confirm direct Apply and status chevrons,
validate the current owner-selected policy through Apply and Stop, then restore and compare the
pre-validation policy, backup, permissions, process, assertion, Accessibility,
and Open at Login state. Store all evidence under ignored `LocalData/` and capture
no menu-bar pixels.

For explicit installed sessions, Debug-only `BLENNY_SESSION_DIAGNOSTICS=YES`
emits compact launch, management, native-state and termination receipts to stdout.
It enables no mutation path and changes no authorization. Redirect it only into
ignored `LocalData/`; normal launches do not create a log file. The switch and
private backend remain absent from Release.

The earlier native-control integration passed 186 Debug tests in 21 suites and 184
Release tests in 20 suites with Xcode 27/macOS 27 SDK. Both arm64 app builds pass
strict codesign validation and declare minimum macOS 27.0. Release contains no
private assessment factory, mutation switch, placement switch, or session-log
switch. The installed Debug dry-run passed without writer, assertion or
persistence. Final read-only observation found the native control collapsed and
successfully registered its state notifications. Explicit normal startup reported
verified active management with native ownership; normal termination confirmed
writer cleanup. Policy and backup bytes and 0600 permissions were unchanged,
Accessibility remained granted, and Open at Login remained unregistered.
These receipts do not establish installed native-click or split-button visual
acceptance; those remain pending owner validation, and this patch is not closed
or tagged.

Owner follow-up exposed a UI arbitration error in that validation build: native
presence disabled Blenny's button even when the native control was no longer
usable on screen. Stop/Resume could change the observation and mask the error.
The patch removes native presence from button enablement; verified management,
Revealable scope and the shared busy gate remain mandatory. It also changes
the chevron weight from semibold to regular without shrinking its optical size.
Installed diagnostics now report the actual AppKit arrow's enabled property
after the interaction gate is released, without reading or capturing pixels.

The follow-up passed 189 Debug tests in 21 suites and 187 Release tests in 20
suites, both arm64 app builds and strict codesign checks. The installed no-write
dry-run passed. Normal startup verified active management with observable native
overflow and the actual AppKit arrow enabled after the gate released. Normal Quit
reported writer cleanup, no Blenny process remained, and policy/backup bytes and
0600 permissions matched the pre-install copies. Accessibility remained granted.
Service Management reported `notFound` in this run, rather than the earlier
`notRegistered`; no login registration/unregistration was invoked, and this is
not evidence of unchanged login registration status. Actual click feel and glyph
weight remain owner visual acceptance, without pixel capture. No tag is created
by this incremental check.

The native-handoff follow-up passed 194 Debug tests in 21 suites and 192 Release
tests in 20 suites; both arm64 app builds and strict signature checks passed.
Its first installed dry-run correctly rejected a missing running approved target.
After temporarily starting that already-approved application, a fresh dry-run
passed without a writer or persistence. Normal startup verified active fallback
management, an enabled inline arrow and arrow-left/artwork-right arrangement.
No actual native expand/collapse click occurred during this installed session,
so native-event delivery, automatic hiding in the live native-present layout and
glyph visual parity remain pending owner acceptance, not claimed as passed by
the deterministic handoff tests. Normal Quit confirmed writer cleanup; policy
and backup bytes and 0600 permissions were unchanged. The temporarily started
target was returned to its original stopped state. Self-position promotion
remains unapproved and disabled; this patch is not closed or tagged.

The failed-startup Resume follow-up passed 202 Debug tests in 21 suites and 200
Release tests in 20 suites, both app builds and strict codesign checks. The final
installed dry-run rejected the absent approved target without creating a writer,
assertion or persistence change. Normal startup remained honestly unrestricted,
named that missing target and reported both the editor and AppKit menu Resume
controls enabled. Normal Quit confirmed cleanup, with no Blenny process left.
Policy/backup bytes and 0600 permissions were unchanged; Accessibility was granted
and Service Management reported `notFound`. No real Resume activation or native
click was exercised in this follow-up: unchanged reactivation, failure cleanup,
staleness and backup preservation are deterministic-test evidence. No position
write, new authorization target, tag or push was added.

The own-arrow follow-up passed 206 Debug tests in 22 suites and 204 Release tests
in 21 suites, both app builds and strict signature checks. Local AppKit tests
confirm parent-owned hit testing with retained accessibility elements, left/right
action routing, busy rejection and repeated reveal/conceal presentation across
native appearance. Installed dry-run passed without mutation. Owner-authorized
normal startup activated the unchanged accepted baseline and reported an enabled,
visible left arrow whose real AppKit hit region routes to the shared toggle.
No physical user click occurred in the bounded installed session, so repeated
installed click behavior remains owner acceptance rather than a claimed real-run
result. Normal Quit confirmed assertion cleanup; no Blenny process remained.
Approved target processes, policy/backup bytes and 0600 permissions were unchanged.
Accessibility remained granted and Open at Login reported `notFound`. Native
control repair and own-position promotion remain outside this follow-up.

The dedicated-native-buttons follow-up passed 206 Debug tests in 22 suites and
204 Release tests in 21 suites. Both arm64 app builds, strict signatures and the
installed no-write dry-run passed. The installed normal session activated the
unchanged accepted baseline, reported an enabled, visible arrow and confirmed
distinct native button targets/actions. No actual arrow action arrived during
this bounded session; physical left-click behavior is therefore still pending
owner acceptance, not established by the action-binding check. The read-only
window-frame diagnostic does not establish relative physical placement. Normal
Quit reported writer cleanup and no Blenny process remained. The approved target
processes, policy/backup bytes and 0600 permissions were unchanged. Accessibility
was granted; installed startup reported Open at Login `notFound`, and no login or
permission setting was changed. The prior installed app is recoverable in ignored
local evidence. Native system-arrow repair, positioning and release closure
remain outside this follow-up.

## Owner acceptance and optical-weight follow-up

The owner subsequently confirmed that the dedicated native arrow now expands
and conceals correctly, and accepted keeping the artwork and arrow as separate
status items. This is owner-reported installed click acceptance, separate from
the earlier bounded diagnostic session, which captured no physical click.

The arrow appeared slightly thinner than the native control. Change only its
symbol weight from regular to medium, retaining the 13-point size, two stable
26-point native items, action bindings and verified-state direction. Exact
visual parity is not claimed and no menu-bar pixels are captured.

The owner also reports an unlisted Bartender item that remains missing after
manual Refresh. Its cause is not yet diagnosed; this is a known discovery issue,
not evidence that all newly launched applications are unsupported. No Bartender
mutation or inventory change is authorized by this optical adjustment. The owner
subsequently approved deferring that investigation and native-overflow integration
to 0.6.0. This is not a completed fix or a promise to intercept Apple's button.

The weight-only change passed 206 Debug and 204 Release deterministic tests,
both app builds, strict signature validation and the installed no-write dry-run.
The prior running validation app was quit normally before replacement. The new
app was not launched for real management validation: no new assertion was
created, policy and backup remained byte-identical with 0600 permissions, and
no Blenny process remained. The owner-confirmed click behavior above applies to
the previous regular-weight build; the new weight awaits visual acceptance.

## Compact spacing and confirmed milestone sequence

The final spacing adjustment retains both working native buttons and reduces
each item's public AppKit length from 26 to 22 points. Neither the 18-point fish
artwork nor the 13-point medium chevrons shrink; only surrounding whitespace is
reduced. No image offset, custom hit region, positional preference or system
spacing setting is changed. The two item identities, action targets, direction
and management gates remain unchanged. Actual visual spacing remains installed
owner acceptance, not a guarantee about macOS placement.

The owner approved moving native-overflow integration and missing-application
discovery work to 0.6.0, alongside the existing lifecycle/display hardening.
Real menu-bar ordering investigation moves from 0.6.0 to 0.7.0 with every original
safety gate intact. Distribution preparation follows at 0.8.0; public release
candidates remain 0.9.x. No work on those deferred capabilities is included here.

The compact-spacing build passed 206 Debug and 204 Release tests, both arm64 app
builds, strict signatures and the installed no-write dry-run using Xcode 27 and
the macOS 27 SDK. The previous running app quit normally before replacement; no
new real management session was started. Policy/backup bytes and 0600 permissions
match this run's pre-install copies, and no Blenny process remained. Accessibility
was granted; Open at Login reported `notFound`, with neither setting changed.
Visual spacing remains owner acceptance before release closure.

## Release audit and remaining gate

The complete patch from `v0.5.0` / `9ccffa08` was reviewed, including every new
source/test file. The coupled implementation is organized as a forward fix
commit, followed by the version record and roadmap. No existing commit, tag,
author or timestamp is rewritten. The original first commit is preserved.

| Patch criterion | Evidence and boundary |
| --- | --- |
| Internal preparation instead of a routine Review page | Ordinary UI route removed; navigation, action gate and Draft tests pass; owner requested this behavior |
| Apply and failed-startup Resume | Exact managed authorization and fresh pass-through plan tests; unchanged Resume activates without saving or rotating backup; owner reported working management |
| Safe Stop and Restore | Dirty-Draft preservation and recovery/control tests; inherited atomic store and serialized transaction tests remain passing |
| Independent arrow and artwork | Owner confirmed real reveal/conceal clicks; sender-identity and repeated-direction tests pass; final 22-point spacing still needs visual confirmation |
| Staleness, verification and cleanup | Deterministic stale scope/PID/runtime/backup, activation, verification, rollback, termination and connection-loss tests |
| Final build boundary | Xcode 27, macOS 27 SDK, arm64, minimum macOS 27.0; Debug 206 tests in 22 suites, Release 204 tests in 21 suites; both app builds and strict signatures pass |
| Release isolation | Final Release string scan contains no Debug fixture, assessment classes, mutation, placement or session-diagnostic switches |
| Installed no-write validation | First run correctly rejected an absent approved target; temporary launch of that already-approved target allowed a fresh dry-run to pass without writer, assertion or persistence |
| State preservation | Running Blenny quit normally before installation; temporary target returned to its original stopped state; policy/backup bytes and 0600 permissions unchanged |
| History and privacy | All reachable objects and current candidate paths audited; no credentials, private paths, raw diagnostics, generated binaries or copied dependency trees found; the sole binary asset is the tracked application icon source |

Final Accessibility was granted and Open at Login reported `notFound`; neither
setting was changed. No new real assertion session was started during this
release audit. Earlier owner-approved baseline activations and normal Quit
cleanup are recorded above; fake-writer tests are not claimed as real failure
injection. Native-arrow takeover, missing Bartender discovery and ordering are
not accepted capabilities of this patch and retain their explicit later scopes.

The release skill's final clean audit must not be reported as passing until the
owner confirms the final installed spacing/click behavior and all completion
documents are aligned. Until then, preserve the audited commits without a
`v0.5.1` tag. No push is authorized or performed. Raw receipts remain ignored.
