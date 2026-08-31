# Blenny 0.6.0 Technical Spike

## Native overflow compatibility and bounded discovery

Status: **Complete as the owner-accepted native-integration investigation on
2026-08-31, on the exact Debug development runtime recorded below.** The final
runtime first-appearance correction is accepted; broader lifecycle/display
compatibility is not. The starting clean `HEAD` and annotated `v0.5.0` both
resolve to `dc4fa616505c6ce21b210d4640c6df51e71307ef`. Existing history and tags
are preserved. No push is authorized.

The owner approved implementation after a read-only investigation. Native
overflow compatibility is the priority. The reported missing application was
corrected from Bartender to **Coffee Buzz** (`com.aaronpantling.CoffeeBuzz`).
Historical 0.5.0 reports retain their original wording; they do not constitute
a Bartender diagnosis or permission to mutate Coffee Buzz.

## Final acceptance and compatibility boundary

The owner's final installed acceptance closes the previously reported runtime
bootstrap failure: when native overflow appears after Blenny is already running,
native expand/collapse works without first clicking Blenny's fallback arrow.
Earlier owner observations also established correct startup with and without
native overflow, steady-state coordination, and fallback return when native
overflow disappears. The final acceptance is owner-observed evidence, not a new
timestamped AX trace of every click. It does not retroactively turn silent or
inactive diagnostic windows into successful native-operation experiments.

The mechanism is read-only AX state observation followed by Blenny's existing
ordinary-reveal coordinator and serial writer. Apple still owns its button,
input handling and rendering. The colloquial description of taking over the
arrows means coordinating Revealable policy with their observed state, not
intercepting input, changing Apple system items, or revealing Hidden bundles.

The final fix is upstream of the reducer: keep canonical extras-root topology
subscriptions even with no overflow child, and replace the immediate activation
read with one coalesced 200 ms sample. Newly created controls can be registered
without a preceding Blenny write. Samples/creation only discover and bind; an
eligible native layout/value state edge drives the authorized reveal plan.
The delay is a bounded event-driven heuristic, not polling or a macOS layout
completion guarantee. The earlier first-frame reducer exception alone was not
sufficient; the historical regression record below is retained.

| Area | Final evidence and limit |
| --- | --- |
| Runtime | macOS 27.0 `26A5416b`, arm64, one 1600 × 900 logical-point display at 2x; sampled native labels are Simplified Chinese |
| Native/fallback integration | Owner accepted startup in either native-presence state, steady-state edges, runtime first appearance without a Blenny click, and fallback return; no input interception or fixed positioning |
| Coffee Buzz | Installed bounded discovery, owning-app attribution and icon presentation succeeded; subsequent explicit owner assignment is separate authorization, not an effect of discovery |
| Deterministic verification | 255 Debug tests / 27 suites; 253 Release tests / 26 suites, rerun for closure with Xcode 27 `27A5237l` |
| Artifacts | Both arm64 0.6.0 builds pass strict ad-hoc signatures, plist/minimum macOS 27/SDK 27 checks; Release excludes the unsupported mutation backend and Debug validation switches |
| Installed preflight | No-writer, no-assertion, no-persistence dry-run prepared the current accepted plan; AX granted, login status `notFound`; no permission or login setting changed |
| Real cleanup | Final bounded run activated baseline, restored through the serial writer after frozen-scope invalidation, then exited normally with cleanup confirmed; file bytes/hashes/0600 modes and scoped third-party/agent identities matched |
| Failure safety | Deterministic tests cover stale generation, read failure, ambiguity, serialization and restoration; historical failed timer-termination attempts remain failures and final corrected normal Quit passed |
| Broader lifecycle/display support | Not established: full login/logout, lock/unlock, sleep/wake, real update-like replacement, natural MenuBarAgent recreation, multiple displays, scaling, Spaces, full-screen and auto-hide matrix; no new all-system-controls interaction matrix is claimed |

The owner closed the native-integration investigation, not the originally
proposed full compatibility matrix. Unexercised scenarios remain explicit
cross-version gates in the roadmap before any broader compatibility claim,
Release backend promotion or distribution milestone. Ordering, fixed fish
placement, and revealed Revealable items to the arrow's **right** remain 0.7.0.

At documentation closure the installed executable still matches the tested
artifact, and current policy/backup hashes match the final validation snapshots.
The owner has subsequently launched Blenny for ordinary use; that process is not
a leftover bounded validation run and is not stopped by this documentation task.
The restored state recorded above belongs to the completed validation window;
it is not a claim that the owner's running app currently holds no assertion.

## How to read the investigation record

The following candidate records preserve the sequence of investigation, failed
attempts and bounded checks. Statements such as "pending", "not installed",
"no commit", or "stopped" describe the state at that stage, not the final status
above. Counts and authorization snapshots likewise belong to their particular
candidate. No earlier failure or unsupported compatibility row is relabeled as
a pass by the owner's final acceptance. Raw logs, hashes, process snapshots and
recoverable app copies remain only under ignored `LocalData/0.6.0/`.

## Findings before implementation

- The current machine reports macOS 27.0 build `26A5416b`, arm64, one display
  at 1600 by 900 logical points and 2x scale, without a reported safe-area inset.
  Xcode 27.0 build `27A5237l` and the macOS 27 SDK are explicitly selected.
- A bounded AX sample found one native overflow `AXButton`, with the Simplified
  Chinese collapsed description. It exposed no standard action and `AXHidden`
  was not settable. This establishes observation, not input interception.
- The ordinary 0.5.0 app already wires native observation to the serial writer.
  However, layout-driven rediscovery can enter the same edge path as a value
  notification, and observations from multiple controls are merged. Neither is
  sufficient evidence of a user operating the same native control.
- Coffee Buzz 2.0 is running as an accessory application. An initial
  `AXExtrasMenuBar` read with a 100 ms messaging timeout returned `cannotComplete`.
  A separate bounded sample with a 500 ms timeout succeeded. Its tree contains
  one `AXMenuBarItem` with subrole `AXMenuExtra`, owned by the Coffee Buzz PID.
  It meets the existing ownership filter; role filtering and icon rendering are
  not established causes. The communication failure is evidence, not proof of
  the exact cause of yesterday's missing item.
- Inventory errors were aggregated without retaining per-application discovery
  outcomes. A failed root read could therefore look like an app with no item.
- The ordinary app lacks a complete event-driven lifecycle/display safety
  boundary. A frozen allow-list must not silently restrict newly launched apps
  or continue presenting stale management after its runtime context changes.
- Blenny was not running at investigation time. Saved management intent was
  enabled; normal launch could therefore activate it and was not performed.
  Scoped policy/backup bytes and 0600 permissions were unchanged.

## Accepted implementation contract

### Native observation is not ownership

- Preserve the current fish, 13-point medium arrows, two 22-point native status
  items, independent actions, and safety menu. The owner's clarified presentation
  contract hides the fallback arrow only for a single, registered, known native
  control; absent, unknown, unobservable, or ambiguous native state restores it.
  Presence alone is insufficient. Keep the explicit reveal/conceal action in
  Blenny's safety menu even while its fallback arrow is hidden.
- Clear the fallback button's image and title as well as hiding its view and
  hit target, without removing its status item
  or changing its 22-point allocation. This retains a blank slot under native
  ownership and avoids a width-driven show/hide feedback loop. Do not claim that
  retaining an NSStatusItem guarantees physical visibility outside overflow.
- Run read-only native observation independently of management availability.
  Stopped management and the read-only Release backend must not force the arrow
  visible when a usable native control exists. Permission loss, termination and
  MenuBarAgent replacement still stop observation. Observation never enables a
  writer. Installed dry-run must use this same observation wiring.
- A layout or value notification may carry a known expand/collapse edge from
  the same single registered control, outside Blenny's own in-flight write.
  Neither notification proves click provenance. Explicit samples, discovery,
  replacement identities and initial observations cannot open a reveal session.
- Bind native edges to one registered control identity. Registration replacement,
  discovery, an explicit sample, unknown state, and multiple controls cannot open
  a reveal session. A fresh known layout/value edge can do so. The first-appearance
  exception below additionally permits a layout edge directly from a successful
  no-control observation to one usable expanded control while baseline is active;
  absence must not be inferred from a read failure.
- Ambiguous or unavailable presentation selects Blenny's own control without
  closing or extending an already authorized reveal. Preserve its original
  30-second deadline. Permission, lifecycle and backend loss still restore the
  writer; a transient presentation read is not a policy-context failure.
- Consume notifications during an assertion replacement as possible own-write
  reflow. Do not queue an immediate compensating conceal/reveal. A rapid second
  click during that write is not distinguishable from reflow and requires a fresh
  edge or the retained explicit Blenny action after the write finishes.
- Keep the read-only container subscription after a failed discovery. Permit one
  later event-triggered read; a second consecutive failure requires manual Refresh.
  There is no scheduled retry, polling or automatic assertion acquisition.
- Subscribe to creation/layout changes on the application and canonical extras
  root without requiring an existing overflow child. A root replacement removes
  exactly the preceding successful root subscriptions and renews control identity.
  Replace immediate Workspace-activation sampling with one coalesced 200 ms
  post-activation sample, cancelled on observer teardown. The read is scheduled
  by activation, not failure; it never repeats itself or resets the read budget.
- Keep one pending intent and one shared interaction gate. Explicit Blenny input
  supersedes queued native intent. Own-write reflow, duplicate notifications,
  late callbacks, and conceal must not create a reopen loop.
- Never press, overlay, replace, move, or claim control of Apple's button. An AX
  notification is an observed state change, not independently proven click input.

### Discovery and authorization remain separate

- Use one bounded root read with an adequate messaging budget; retain the total
  scan deadline, element/depth limits, privacy boundary and no-retry behavior.
- Record each application's root discovery result and distinguish successful
  empty roots, unsupported attributes, communication failure, attributable items,
  and items rejected by the ownership filter.
- Surface incomplete reads in the interface and installed diagnostics. Do not
  fabricate a manageable item from the fact that an application is running.
- At initial investigation, Coffee Buzz is a read-only discovery target only. No new policy entry, mutable
  bundle, assertion allow/deny change, or validation approval follows discovery.
- Do not broadly remove process/role filters without direct evidence that they
  caused a supported application's omission.

### Lifecycle and display safety

- Use bounded public Workspace/AppKit notifications, not polling or automatic
  reconciliation. Invalidate stale preparations on relevant lifecycle changes.
- When a frozen plan can no longer be trusted, revoke the owned assertion through
  the one serial writer, retain accepted policy and Draft, and require explicit
  fresh Resume. Do not automatically recreate the writer or policy assertion.
- Observe sleep/wake, session/display changes, managed-app lifecycle and new
  application launches that are not in the frozen allowed/managed scope.
- MenuBarAgent loss requires a new Blenny process. Never restart MenuBarAgent
  as part of validation. A naturally observed recreation and an injected model
  event are different kinds of evidence.
- Cleanup and in-flight verification must remain generation-bound and idempotent;
  late preparation/activation cannot restore stale active UI or reacquire a writer.

## Unchanged safety boundaries

Only macOS 27 and later. Unsupported mutation remains Debug-only on the exact
existing runtime contract. All mutation uses one serial writer, replacement
activation precedes old-assertion invalidation, and failure/verification/retry
remain bounded. Blenny is Visible; ordinary reveal never includes Hidden; Apple
system items stay read-only. No helper, private entitlement, synthetic input,
pixel capture, Screen Recording, polling, automatic reconciliation, Release
backend promotion, ordering, or position investigation is added. All ordering
and fixed-position questions remain 0.7.0 work.

## Clarified native/fallback presentation follow-up

The owner confirmed: hide Blenny's fallback arrow when native overflow is usable,
and show it when native overflow disappears or is unavailable. The requested
physical grouping of revealed Revealable items is to the **right**, not the
left, of the arrow, and is deferred to 0.7.0. The desired fixed fish position
beside native overflow remains a positioning question, not a 0.6.0 guarantee.
Hidden bundles remain excluded from ordinary reveal.

Historical evidence was rechecked at tags `v0.0.2` and `v0.0.3`. Both spikes
record owner-operated native expand/collapse cycles that changed the same
Revealable assertion plan. The mechanism was AX state observation, not button
interception. Historical code rescanned on layout, value and destruction events;
its recorded states do not establish value-only notification provenance.
The 0.0.3 self-position experiment kept one Blenny status item
outside overflow on that recorded layout; it does not prove fixed placement for
the current two-item presentation and is not promoted here.

The owner's later saved policy includes Coffee Buzz as Revealable. Preserve that
explicit local intent; do not overwrite it with the earlier discovery-only
snapshot. That user change invalidates the previous validation receipt's hashes
and target scope. A fresh no-write report and separate real-run approval are
required before an agent-operated assertion with the new scope.

A later bounded read-only check again found two distinct AX handles with the
same collapsed label. Neither reported AXHidden and both reported enabled.
Root-provenance inspection found one control in AXExtrasMenuBar and an additional
control in a separate AXWindow. This does not establish that they are aliases.
The observer now discovers only within the dedicated AXExtrasMenuBar root rather
than merging controls from arbitrary presentation windows. It never chooses a
control by position, label agreement, or display geometry. Missing/unreadable
primary roots, explicitly hidden roots, multiple primary controls, mismatched
ownership, disabled controls, and unknown enabled/state reads retain fallback.
Unsupported control AXHidden remains distinct from an explicit hidden value.

The pure primary-root traversal is finite and equality-based: repeated handles
and cycles cannot duplicate candidates, unrelated application-menu subtrees are
terminal, and deadline/element/depth exhaustion rejects partial results. The
primary-root selection is a narrowed compatibility boundary, not a multi-display
claim or proof that secondary AX windows are irrelevant on every macOS build.

Debug-only per-sender value-notification telemetry records ambiguous events
without making them actionable. Installed presentation fixtures exercise AppKit
hide/restore and retained width with no writer; they are not real native-event
or physical-placement evidence. Native state values alone do not establish
user click provenance. Fresh installed observation and owner-operated native
cycles remain required for acceptance of the root-selection change.

## Verification gates

1. Deterministic Debug and Release tests cover event provenance, control identity,
   ambiguous controls, duplicate/late events, reflow, explicit-input priority,
   timeout, discovery failure classification, ownership and authorization,
   lifecycle invalidation, writer serialization, failure, and restoration.
2. Xcode 27 Debug/Release builds pass signature, deployment/SDK/version, plist,
   architecture and Release-isolation checks.
3. Install a recoverable copy and run a structurally no-write dry-run. Record
   exact policy/backup hashes, permissions, scoped processes, Accessibility and
   login status. The read-only mode must not migrate or recover persistent files.
4. Present the exact targets, managed policy/plan fingerprints, allow-lists,
   operations, bounds, cleanup and restoration receipt. Real assertions require
   owner authority, including normal enabled-policy launch. The owner's later
   standing approval covers the reviewed unchanged saved scope; it does not
   authorize newly discovered targets, a new mutation class, or bypassing preflight.
5. Owner-operated native and Blenny controls validate real event delivery without
   synthetic input or menu-bar screenshots. Restore and compare state and hashes.
6. Run `$blenny-release`. Only accepted, directly evidenced exit criteria permit
   an annotated `v0.6.0` tag. Do not push or replace an existing tag.

## Compatibility evidence matrix

| Scenario | Evidence at implementation start |
| --- | --- |
| Exact macOS build / arm64 / one display | Read-only environment sample |
| Native control present, collapsed | Read-only AX sample; no click experiment |
| Native expansion/collapse and Blenny handoff | Pending installed owner-operated validation |
| Native absent / replaced / ambiguous controls | Pending deterministic and applicable installed validation |
| Coffee Buzz ownership | Bounded read-only success after earlier communication failure |
| Permission loss and stale/failed reads | Pending deterministic and installed validation |
| Blenny quit / crash / writer failure | Existing historical evidence; new-version validation pending |
| Managed-app launch/quit/relaunch/update-like replacement | Pending; simulation is not a real app update |
| Login/logout/lock/unlock/sleep/wake | Pending; notification handling alone is not installed compatibility |
| MenuBarAgent recreation | Pending natural occurrence; never force-restarted |
| Multiple displays, scaling, Spaces, full-screen, auto-hide | Pending available hardware and owner-operated checks |
| Clock, Notification Center, Control Center after mutation | Pending owner-operated checks after approved writes |

Unexercised rows remain unverified, not passed. A narrower accepted compatibility
boundary must be explicit; neither deterministic tests nor this table silently
satisfies the entire roadmap matrix. Raw evidence belongs only in ignored
`LocalData/0.6.0/`.

## Implementation and no-write verification record

The implementation now binds ordinary native edges to a single registration UUID
and an explicit value-notification source. Discovery and samples cannot open a
session, and replacement identities cannot inherit an edge. Identical samples
can discard queued native reveal intent without creating a write. Multiple
observations remain ambiguous, even when their states agree. Manual Refresh may
re-establish a failed read-only registration once on the same MenuBarAgent PID;
it never reconnects a changed agent or recreates an assertion automatically.

The English expanded label previously contained a shorter collapsed marker and
was classified as collapsed. Exact known-label matching now avoids that overlap;
contradictory or unfamiliar labels remain unknown. English-label tests are not
an English-locale runtime compatibility claim.

The first application AX root read now has a 500 ms messaging budget while leaf
reads retain the configured shorter budget and the complete inventory retains
its finite deadline. There is no retry. Diagnostic schema 3 records per-process
root outcomes; policy schema 2 is unchanged. The existing footer reports
unreadable applications and exposes the scoped reason through Help. No running
application is fabricated into a candidate. No broad process/role filter was
removed because Coffee Buzz's successful observation fits the existing filter.

Workspace/AppKit lifecycle signals invalidate preparations and the owned writer
when their frozen scope is no longer valid. Late writer acquisition is bound to
the lifecycle generation. Cleanup verifies the writer's local plan is absent
before publishing unrestricted state. Unconfirmed cleanup is terminal, disables
new acquisition, and permits only one final termination cleanup attempt before
process disconnect. These are local writer-contract checks, not pixel or private
server-state verification.

Installed dry-run now uses a read-only persistent store, cannot perform migration
or interrupted-transaction recovery, and cannot construct a writer. Historical
Debug prototype and placement switches cannot override this mode. An optional
1–300-second event-only observation window has one expiry, no polling, and no
writer. It preserves the user's frontmost application instead of opening the
editor and changing the native overflow layout before sampling.

Verification on 2026-08-31:

- Xcode 27 Debug: **225 tests in 24 suites passed**.
- Xcode 27 Release: **223 tests in 23 suites passed**.
- Both arm64 0.6.0 app builds passed strict signatures and plist checks, with
  minimum macOS 27.0 and SDK 27.0. Release private/backend/validation-string
  scans found no prohibited surfaces.
- Installed no-write plans passed for the unchanged accepted policy. Coffee Buzz
  produced one attributable item, an implicit Visible candidate and an installed
  application icon. It remained outside the accepted authorization scope.
- One early sample reported two native AX controls on this single display and
  correctly refused to merge them. Later samples reported no native control.
  The 30-second event-only window captured no native expand/collapse value edge.
  Whether the earlier pair represents duplicated presentation is **unresolved**;
  no geometry-based deduplication or multi-display support is inferred.
- The dry-runs reported Accessibility granted and Service Management status
  `notFound`. No permission or login-registration API was invoked to change them.
- All dry-run processes exited. Scoped target PIDs and MenuBarAgent matched the
  pre-install snapshot, and no Blenny process remained. Policy and backup bytes
  were unchanged, both at 0600, with saved management intent still enabled.
- The prior installed app is preserved in ignored local evidence. Current fish,
  arrows, optical weight, spacing and artwork sources are unchanged. No ordering
  or position experiment, history rewrite, commit, tag change, or push occurred.

This is not release acceptance. Real native/fallback coordination, ordinary
timeout, new-version real Quit cleanup, and the outstanding lifecycle/display
matrix require separate owner-approved validation. The release skill must not
close or tag this milestone while those evidence gates remain open.

### Canonical-root and fallback-presentation follow-up verification

- Xcode 27 Debug: **235 tests in 25 suites passed**.
- Xcode 27 Release: **233 tests in 24 suites passed**.
- Both final 0.6.0 arm64 bundles built and passed strict signature verification,
  with minimum macOS 27.0 and SDK 27.0. The Release private/validation-string scan
  found none of the prohibited surfaces.
- New traversal tests reject incomplete node/children reads and missing roles,
  as well as deadline, queue, element and depth exhaustion. Partial discovery
  cannot turn multiple possible controls into one apparently usable control.
- Fish and arrow artwork assets are unchanged. The source implements fallback
  view/hit-target hiding with a retained fixed slot, not position manipulation.
- The earlier installed candidate remained running during this follow-up. It
  was not terminated or overwritten. The newer builds have **not** yet received
  installed dry-run, AppKit-fixture, native-event, or owner visual acceptance.
- The owner's current policy and backup hashes matched the preceding read-only
  check after the Coffee Buzz assignment. No agent-operated assertion, policy
  edit, position write, commit, tag creation/change, or push was performed.

Next: owner normal Quit, a recoverable installation, a fresh no-writer dry-run
and bounded native-event observation, followed by a separately reviewed exact
real-run scope. The initial no-write record above is historical evidence for the
earlier artifact, not acceptance of this follow-up.

### Installed canonical-root no-write validation

The owner authorized agent-operated normal Quit, recoverable installation, and
read-only validation without repeating that operational confirmation. This does
not introduce new mutable targets, positioning work, Release backend promotion,
or permission to bypass the separately scoped real-write gate.

The preceding installed Blenny process accepted normal termination and exited.
No force termination or MenuBarAgent restart was needed. Its bundle was retained
as a recoverable local copy before the tested candidate was installed. The
installed candidate's executable hash matched the final tested Debug build and
its strict signature verification passed.

Two installed no-writer runs then passed:

- Current explicit policy, including the owner's Coffee Buzz Revealable choice,
  produced a valid unchanged Resume preview. No writer or assertion was created,
  no migration or recovery write ran, and management was not re-enabled.
- Local AppKit fixtures passed hide/restore, disabled hidden hit-target, retained
  22-point allocation, and retained fish/safety-menu checks. These fixtures do
  not independently establish physical placement or owner visual acceptance.
- The canonical extras root yielded one registered collapsed native control.
  The local fallback view was hidden with its width retained. This replaces the
  earlier all-window ambiguity with a directly observed single primary control,
  not a claim that all secondary windows have been identified or deduplicated.
- A 30-second event-only window received discovery notifications for the same
  registered control, but no expand/collapse value edge. User-operation timing
  and native value delivery were not established. Real native coordination is
  still unaccepted, and absence/failure visual fallback remains to be observed.
- Both runs reported Accessibility granted and login status `notFound`; neither
  permission nor login registration was changed by Blenny.
- Both dry-run processes exited. Scoped before/after process comparison differs
  only by removal of the original Blenny process: Coffee Buzz, the other managed
  apps, and MenuBarAgent retain their identifiers and paths.
- Current policy and backup match their pre-Quit snapshots byte-for-byte and by
  SHA-256; both retain 0600 modes and enabled saved intent. This verifies scoped
  files and process cleanup, not an independent read of private server state.

The new candidate remains installed but is not running. No new real management
assertion, policy/position write, commit, tag change, or push occurred. The exact
updated real-run proposal and all raw receipts are in ignored local evidence;
the earlier pre-Coffee-Buzz proposal must not be reused.

### Ordinary-path observation and hosted-content correction

The preceding artifact did not establish either requested user-visible result.
Code inspection found that ordinary observation was disabled unless management
was active, while installed dry-run started its own observer unconditionally.
Consequently, a successful dry-run was not evidence of ordinary launch behavior.
The new wiring starts observation independently of management/backend availability
and shares the same callback and lifecycle between ordinary launch and dry-run.
Management coordination remains disabled without a verified active policy.

Fallback presentation now clears the actual status-button image and title in
addition to its local hidden/disabled state. It keeps the fixed allocation and
does not resubmit unchanged presentation on native layout notifications. This
uses AppKit content APIs; it is not pixel evidence or fixed-position control.

Notification-order inspection also found a deterministic dropped-edge case:
layout could update the stored state before a matching value notification, which
was then suppressed as a duplicate. Layout now updates presentation without
consuming the value-edge anchor for the same known registration. It cannot open
a session. Explicit samples, unavailable or replaced controls, suspension and
inactive management reset the anchor. A later matching direct value notification
is delivered; ordinary coordination still rejects duplicate writes and own-write
reflow. This fixes an evidenced code path, not proof of this machine's click
notification order.

Xcode 27 verification: **240 Debug tests in 26 suites** and **238 Release tests
in 25 suites** passed. Both app builds and strict signatures passed; minimum OS
and SDK are 27.0 and Release still excludes Debug validation/private surfaces.
The corrected Debug artifact was installed recoverably after normal Quit. Its
installed executable hash equals the tested build. The installed no-writer
preview passed with the owner's existing Coffee Buzz assignment preserved.
Ordinary observation produced a single known native control while management
was inactive, and the fallback glyph was absent from local AppKit content.
Actual visual handoff and owner-operated value events still require evidence.

The five-minute installed no-writer session completed and exited. It recorded
layout and explicit event-triggered samples, all collapsed, but no native value
edge. A separate bounded read-only probe registered both distinct root-provenance
controls for three minutes and also captured only layout notifications. There
is no owner confirmation that clicks occurred within these windows, so neither
silence nor the primary-root choice is declared a demonstrated delivery failure.
No input was synthesized and no pixels or positions were inspected.

Both validation processes exited. Policy/backup bytes, SHA-256 hashes and 0600
modes remained unchanged, including Coffee Buzz's existing assignment. Scoped
third-party and MenuBarAgent process identities matched before/after; only the
original Blenny process was removed by normal Quit. The corrected app remains
installed but stopped, with the prior bundle retained locally. No new assertion,
policy/position write, commit, tag change or push occurred. Release acceptance
and the final release-skill audit remain pending real native/fallback evidence.

### Owner-approved regression correction

The owner reported first-expansion flash/re-conceal and requested investigation,
then implementation of its findings. The older sections above record superseded
candidate behavior, not acceptance. Pure replay confirmed that presentation loss
after native reveal requested baseline, and that a transient loss followed by
recovery could leave a sticky baseline request. Historical 0.0.2/0.0.3 observation
did not require value-only notification provenance.

The corrected coordinator now:

- follows fresh known layout or value edges for one registered control outside
  its own in-flight replacement, without interpreting first/discovery/sample
  snapshots as commands;
- hands an authorized revealed session to the explicit Blenny control on unknown,
  unavailable, ambiguous or replaced presentation, without another write or a
  new deadline;
- consumes in-flight native state changes as possible own-write reflow, requiring
  a fresh post-write edge to act;
- preserves explicit input and timeout intent against observation cancellation.

This is not an unrestricted state or a Hidden reveal. The original accepted
reveal plan and deadline are retained; permission and lifecycle invalidation
still restore through the existing serial writer. Actual post-write notification
timing remains subject to installed evidence, not assumed from model tests.

Native reads use the historical 500 ms messaging budget with finite traversal.
Failure clears control registrations but retains the container observer. Only
one subsequent event-triggered recovery read is allowed after failure; two
consecutive failures require explicit Refresh. No retry timer or polling runs.

Managed startup no longer activates the editor and changes leading-menu width.
Setup/failure still opens it, and fish/reopen actions remain explicit editor
entry points. The private backend has not been promoted to Release.

Opt-in Debug tracing gives MainActor and the serial writer one monotonic sequence
covering notification/source/identity, coordinator decisions, exact plan hashes,
activation, preceding invalidation and restoration. It is capped at 1,024 records
and writes stdout only, redirected by local validation into ignored LocalData.
An optional Debug-only normal-run deadline (1–300 seconds) invokes normal Quit;
it neither authorizes new targets nor bypasses the management gates.

### Regression-candidate installation results

The corrected candidate passed **245 Debug tests in 26 suites** and **243 Release
tests in 25 suites**, plus both Xcode 27 app builds and strict signature checks.
Both binaries declare macOS 27.0 minimum and SDK. Release excludes the Debug
session/dry-run switches and the checked private mutation surfaces. The Debug
candidate was installed with its predecessor retained recoverably; the installed
executable SHA-256 equals the tested build.

Two installed no-writer checks were performed. The first exhausted the bounded
inventory deadline and stopped. The second completed the report but rejected
the saved management plan: a managed bundle had two running application owners
(installed and development builds), so no unique target could be authorized.
Neither run created a writer or assertion, and no target was silently removed
from policy to obtain a passing plan. The other applications were not closed.

The installed ordinary observation wiring identified one registered collapsed
native control and cleared Blenny's local fallback glyph. The AppKit presentation
fixtures passed. Coffee Buzz discovery, owning-app attribution and installed-icon
resolution succeeded, preserving its existing explicit assignment. These results
do not establish owner-operated native state edges, hosted visual handoff or
successful real assertion coordination. The duplicate owner must be resolved
and a fresh complete preflight obtained before real validation can proceed.

Both checks exited. Policy and backup match their pre-install snapshots
byte-for-byte and by SHA-256, retain 0600 modes, and preserve saved enabled intent.
Scoped managed-app and MenuBarAgent process identities are unchanged. Blenny is
installed but stopped; no new real assertion or independent server restoration
measurement is claimed.

### First-appearance handoff correction

Owner-operated validation subsequently established that steady-state native
expand/collapse and launch with an already-present native control both coordinate
correctly. One transition remained: after a successful observation with no
native control, opening an application with a sufficiently wide menu could make
the control appear, but the first native expansion did not reveal Blenny's
Revealable bundles. A later explicit Blenny reveal established normal native
coordination.

One matching dropped-edge path is deterministic; the owner's actual callback
sequence still requires a causal trace. The first container layout callback can discover the
new control only after it is already expanded. The coordinator rejected that
state because the newly registered control had no preceding identity anchor; a
following collapse then requested the baseline that was already active. This was
the intended startup/replacement safeguard applied too broadly to a witnessed
runtime appearance.

The correction accepts one narrower topology edge: while management is active
and baseline is verified, a layout update from a successful empty-root snapshot
to one usable newly registered **expanded** control requests the ordinary reveal
plan. A collapsed appearance only establishes the normal anchor. Initial startup,
explicit samples, failed/unavailable reads, ambiguous controls, identity
replacement, own-write reflow, and already-revealed sessions cannot use this
exception. It remains observed AX state, not a claim that Blenny intercepted the
system button.

The first-appearance candidate passed **248 Debug tests in 26 suites** and **246
Release tests in 25 suites**, including both first-appearance and established
control entry into the fake-writer restoration sequence. Both Xcode 27 app builds
and strict signatures passed. Its predecessor was retained and the corrected
Debug app installed with an executable hash matching the tested artifact. Fresh
installed dry-run reports before and after the change prepared valid plans for
the same explicitly saved managed scope without creating a writer.

A real, opt-in predecessor diagnostic activated the existing baseline. At about
198 seconds, an application-launch event invalidated its frozen scope; the serial
writer logged complete restoration before native overflow appeared. Consequently,
that appearance occurred with management inactive and is not evidence for the
reported active first-handoff failure. No owner-confirmed active expansion was
captured, and the first-appearance fix remains pending runtime acceptance. The
lifecycle protection was not bypassed or changed into automatic reconciliation.

That diagnostic also exposed a Debug deadline-termination deadlock: a stack
sample placed the MainActor timer job inside AppKit's nested termination loop,
preventing the deferred asynchronous cleanup job from completing. The already
restored validation process was terminated by its exact PID after normal Quit
failed; no third-party process was terminated. An intermediate main-dispatch-queue
handoff still blocked its queue drain in the nested loop; that exact validation
process was also terminated, using process disconnect as the final assertion
release boundary. Neither failed run is recorded as normal termination success.
The Debug timer now schedules AppKit termination through the main run loop after
returning from both the Swift task and dispatch queue. This changes no writer or
policy authorization. Timer scheduling is not a strict wall-clock guarantee.

The final installed artifact repeated a valid no-writer preflight and then a
15-second requested normal-run diagnostic using the same saved managed scope.
It verified baseline activation, timer dispatch at about 16.15 seconds, serial
writer restoration to no active assertion, `termination writerRestored=true`,
and process exit with status zero. Policy/backup bytes, SHA-256 and 0600 modes
remain unchanged. Scoped managed-app and MenuBarAgent process identities match.
This verifies the corrected diagnostic termination path, not the pending native
first-appearance edge. The final Debug app remains installed but stopped, with
the prior working artifact retained. No history, tag or remote ref was changed.

The requested release skill was invoked for a dirty-tree preparation audit.
Its checks found no forbidden artifact paths, checked secret patterns, personal
absolute paths or Mach-O candidates; Git integrity passed. Closure correctly
failed because the version range has no new commit and the documents retain
in-development rather than completed status. This is not a completed release
audit: real native/fallback acceptance and the documented compatibility matrix
remain open. No commit, tag creation/replacement or push occurred.

### Discovery and subscription bootstrap correction

The owner reported that every native click after runtime appearance was ignored
until one explicit Blenny arrow operation, regardless of the prior revealed or
baseline state. The earlier reducer-only first-frame exception did not address
this report. Inspection found that only the application root had an opportunistic
layout subscription, Workspace activation read immediately, and completion of a
Blenny operation performed the rescan that could finally register the new control.

A bounded read-only investigation confirmed successful application/extras-root
layout and creation registration, plus one usable collapsed control. Its window
captured no owner-confirmed operation, so notification delivery and the exact
failing activation sequence were not claimed reproduced. The owner authorized
implementation of the upstream discovery repair.

The observer now keeps one canonical extras root subscribed to layout, creation
and destruction, including while the root has zero overflow controls. Application
creation/layout subscriptions cover root discovery. Successful subscriptions are
tracked and removed exactly on replacement or stop; unsupported registrations are
not retried on every scan. Explicit refresh can establish a new binding. Root or
control destruction renews registration even if an AX handle is later reused.
Arbitrary AX windows are still not merged with the canonical root.

Workspace activation schedules one 200 ms read after the latest activation event,
replacing the immediate read rather than adding a retry loop. A generation-bound
ticket coalesces bursts, consumes at most once, and is invalidated by stop/context
replacement. Permission loss and the existing two-failure read budget still fail
closed. The delay addresses a stale-layout timing window but is not a macOS
layout-completion contract; actual runtime appearance remains subject to evidence.

Creation/discovery and the delayed sample only establish the observation and
fallback presentation. They cannot activate an ordinary reveal or enable inactive
management. A subsequent eligible native edge follows the existing coordinator
and single writer. No mutation backend, policy, lifecycle restoration behavior,
ordering, physical allocation, artwork or Release promotion changed.

Deterministic tests cover empty-root subscription lifetime, root replacement,
partial/failed registration cleanup, idempotence, activation coalescing, stale
ticket cancellation, unchanged failed-read budget and late-control discovery
from both baseline and revealed states without a Blenny completion callback.
Opt-in Debug diagnostics now include registration outcomes, root subscription
summary and activation ticket scheduling/firing for installed verification.

The discovery-bootstrap candidate passed **255 Debug tests in 27 suites** and
**253 Release tests in 26 suites**, both Xcode 27 app builds, strict signatures,
macOS 27 minimum/SDK and Release private/debug-string isolation. The old installed
process quit normally; its bundle was preserved before installing the tested
Debug artifact. The installed executable hash matches the build.

Installed no-writer preflight prepared a valid plan, confirmed Accessibility,
unchanged login status, two application topology registrations, three canonical
root registrations and one usable collapsed native control. The fallback's local
glyph was absent. The existing Coffee Buzz assignment remained attributable.

A 60-second requested diagnostic activated the unchanged accepted baseline.
At about 9.16 seconds an application-launch event invalidated the frozen scope;
the serial writer restored and management stopped. The new observer then received
actual `AXCreated` notifications and rescanned without recreating the writer.
This proves creation-notification delivery, not that the particular delivered
event was the owner's reported overflow appearance or that an active first native
click coordinated correctly. No Workspace-activation ticket firing or confirmed
owner-operated first-appearance cycle was captured in this window.

Normal termination completed at about 64.17 seconds with `writerRestored=true`
and process exit zero. Policy and backup match pre-install bytes and SHA-256,
retain 0600 modes, and preserve saved enabled intent. Scoped managed-app and
MenuBarAgent identities are unchanged. The corrected app remains installed but
stopped; raw logs and the predecessor are ignored local evidence. No commit,
tag change or push occurred at that stage. Runtime-appearance acceptance was
subsequently supplied by the owner as recorded in the final acceptance section.

## Local release audit — 2026-08-31

The owner requested version closure and synchronization of both canonical English
documents and the ignored Chinese guide after accepting the installed behavior.
The accepted compatibility boundary is stated at the top of this document and
in the roadmap; the unexercised full matrix is explicitly carried forward.

- Implementation and deterministic tests are recorded in forward commit
  `9ebf71c11d72f6b9b9f61bd0b3cf152a824d154c`; no earlier commit is rewritten.
- Xcode 27 closure reruns passed 255 Debug tests in 27 suites and 253 Release
  tests in 26 suites, both app builds, strict signatures, arm64, 0.6.0 version,
  minimum OS/SDK 27.0, public linked-framework checks and Release private/debug
  string isolation. The installed executable matches the tested Debug build.
- Completed installed dry-run and real-run receipts were reviewed, including
  final normal Quit and restoration, without rerunning a live mutation during
  documentation work. Current policy/backup bytes, hashes and 0600 permissions
  still match the final validation snapshots. The owner's ordinary running app
  is left untouched; no bounded validation process is retained.
- The release skill's preparation audit passes. Reachable-history and candidate
  reviews found no prohibited artifact paths, checked secret patterns, personal
  absolute paths, generated executables or files exceeding the size gate.
  Author/committer metadata is the approved public identity. Historical research
  remains explicitly unsupported, excluded from product targets and unexecuted;
  no third-party implementation or binary dependency was added. Artwork and
  ordering research are unchanged from v0.5.0.
- The original first commit and all existing annotated tags are preserved.
  Read-only remote inspection matches the existing main/v0.5.0 boundary; it is
  not an empty remote and is not changed by this task.
- The Chinese owner guide is synchronized and remains ignored. Its preceding
  contents were backed up privately before updating outdated Pinned terminology,
  product-interface status and recovery explanations. All maintenance-critical
  conclusions are also in tracked English documents.

The local closure tag is `v0.6.0`, created only after the final clean-tree release
audit passes and pointing to the audited documentation-closure commit. No push,
existing-tag replacement, Release backend promotion or distribution is authorized
or performed. Exact command logs, artifact hashes and local recovery copies
remain in ignored evidence, not in Git.
