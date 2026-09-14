# Blenny 0.10.0: interface refinement

Status: complete as a local experimental milestone on 2026-09-15.
The owner accepts the tested runtime flow; see [the release record](RELEASE_0.10.0.md).
The chronological implementation sections below preserve intermediate decisions. The completed
0.9.0 tag and release record remain unchanged. The owner approved candidate bundle metadata 0.10.0 on 2026-09-13.

## Approved interaction

The Board itself previews the local configuration. Dragging and Move to actions
edit only the draft. One Apply prepares fresh, identity-bound plans and executes
through the existing serial writer. There is no separate ordinary preview page,
Before/After list or second Apply. Discard Changes resets both area and order.
Unchanged and cancelled drops remain quiet and do not prepare plans or write.

All controls share the combined area/order draft gate. Refresh, Resume and
previous-visibility restoration cannot silently replace a draft. Stop retains
its existing safety semantics and preserves the draft. Accepted ordering remains
through Stop/Quit. The final Undo Changes reverses the last successful Apply,
including visibility and order; this supersedes the original order-only baseline.

A stale clean Undo ledger is an exceptional case: replacing its history still
requires an explicit, concise Replace Undo & Apply choice. Internal freshness,
identity, runtime, compensation and durable-recovery checks are retained. Missing
ordering identities must not silently omit an explicit same-area reorder. Cross-area
visibility changes remain available, with any omitted sorting reported explicitly.
A verified commit followed by observation failure is shown as applied, disables
another Apply and offers a read-only Refresh rather than a repeated write.

## Presentation

Retain compact native navigation and the three horizontal icon lanes. Use short
state/action copy, a single Refresh and one Apply/Discard area. Technical failure
details and longer help are disclosed on demand. Management state is shared by
the window and status menu. Keyboard focus uses the native navigation effect.
Permission guidance names System Settings. Support places collapsed Help before
optional sponsorship. Trial visibility recovery is surfaced from Organize.

The board names its unsortable system group No sorting. Idle ordering strips
reserve no trailing icon slot; a stable slot remains throughout dragging and
settling. A short Drag & drop icons heading and faint hand-and-text artwork in
spare lane space introduce dragging without repeating the Apply instruction.
The surface is decorative and shares the existing lane drop receiver.
Selection details and Move to / arrow controls open from Item controls instead
of occupying a permanent bottom rail. Existing per-icon accessibility actions
and context menus remain available. Organize determines the shared window height from its content. Native frame
animation changes page width without a premature minimum-width jump.

Visible, Revealable and Hidden remain distinct. Ordinary expansion excludes
Hidden. Clock/Notification Center help identifies the tested build and trackpad
right-edge gesture, without automatic Stop/Resume. Siri, Time Machine and Control
Center ordering stays unsupported; no arrow adjacency or absolute placement is
promised. Ordinary Release still excludes ordering.

## Validation

Use Xcode 27 and SDK 27.0 for Debug, ordinary Release and optimized trial checks.
The fixture-only interface entry returns before NSApplication startup and does
not construct AppDelegate or a live writer. Cover draft-only dragging, shared
control gates, combined discard, no-op/cancel lifecycle and existing restoration
regressions. No real Apply, Undo, Stop/Resume or permission mutation is authorized
by this implementation task.

Owner-operated visual and keyboard acceptance remains pending: default/minimum
window sizes, light/dark appearance, VoiceOver, permission return, long errors,
continuous dragging and separately authorized live apply/restoration. No license,
signing, notarization, installation, publication or history change is included.

### Candidate checks on 2026-09-12

Xcode 27 / SDK 27.0 builds and tests pass without warnings or errors:

| Configuration | Tests | Fixture-only interface check |
| --- | --- | --- |
| Debug | 564 tests / 51 suites | passed |
| Ordinary Release | 319 tests / 33 suites | excluded by design |
| Optimized ordering trial | 564 tests / 51 suites | passed |

The compiled fixture entry is present only in the two ordering builds. The
interface check covers no-preview editing, pure-order and combined draft gates,
discard followed by immediate re-drag, and unmapped-owner visibility versus
same-area ordering. Raw logs remain under ignored LocalData. These results do
not establish visual or live-system acceptance. No app installation or ordinary
app launch was performed. HEAD and the annotated 0.9.0 milestone remain unchanged.

### Owner feedback on 2026-09-13

Retain permission-grant refresh intent independently of presentation reads until
one refresh starts. Protect drafts and do not add polling. Organize measures its
natural content height instead of using a vertical scroll container; other pages
use that height. Keep minimum-width changes from interrupting native frame
animation. Lane hints are faint hand-and-text artwork without boxed drop targets.
Clock is labeled Fixed, with the no-sorting/no-area-change reason in its help.
The exceptional Undo replacement action occupies the single footer Apply slot.
Move general Help to README and bring sponsorship directly below project info.
Live permission, animation and layout acceptance remains pending.

The September 13 optimized trial regression run passes 567 tests in 52 suites;
ordinary Release passes 322 tests in 34 suites. Three new deterministic cases
cover retained grant intent across repeated trust reads, revocation, and an
already-trusted launch without a duplicate grant event.

Owner-approved follow-up: remove the Apple Items status list from Settings.
Organize retains per-target restoration, in-progress feedback and disclosed
unavailability details through the existing actions. Support uses an unboxed
sponsorship group, Website, and a bottom Help & Documentation link to the
configured GitHub repository README. This does not publish the repository.

Latest owner feedback supersedes content-driven window sizing: all pages use a
fixed 500-point content height, with identical minimum and maximum heights.
Organize keeps excess error/recovery content reachable with hidden scroll
indicators, without resizing the window. Navigation has no focus border. One
faint italic Drag & Drop hint is rotated eight degrees between the lower lanes,
only when both lanes have enough spare space. The placement guide moves from
Settings to README; sponsorship buttons use the native large control size.

Compact follow-up: fixed content height is now 420 points. The experimental
marker lives in the title bar; brief completion messages share the existing
footer. The drag illustration uses a larger hand and a 13-degree tilt. An
ordering strip reserves an insertion slot only while it has a landing preview,
not merely because another lane has an active drag.

The fallback arrow investigation remains read-only. The fish has the stable
Blenny.Fish autosave name, while ensureRevealStatusItem assigns no autosave name
to the separate fallback status item. updateNormalButton may set its width to
zero, remove it, or recreate it as native-overflow availability changes. These
are candidate explanations, not proof of the owner's reported insertion point.
The existing Fallback slot diagnostic distinguishes absent, compact and reserved
states. No arrow position setter, lifecycle change or real system experiment is
included in this follow-up.

The owner supplied the existing in-process menu diagnostic during the expanded
problem state: reserved fallback, with a distinct window separated from the fish.
Raw coordinates are retained only in LocalData. This excludes the zero-width or
absent fallback explanation for that sample, but does not establish which items
lie between the windows or whether recreation preceded the separation. Historical
0.7.0 evidence records an implicit Item-1 fallback identity; lack of an explicit
autosaveName must not be described as proof that AppKit never persists position.

Next proposed attended check (not executed or authorized here): record the exact
running build and an already expanded baseline; collect one collapsed and one
expanded Fallback slot snapshot, then leave the session in its original expanded
state. No Apply, Undo, Stop/Resume, position setter or third-party order change.
If identity/recreation is implicated, a separate stable-identity trial requires
a scoped preference snapshot and exact restoration plan before authorization.

Diagnostic follow-up: successful ordering reads clear obsolete error detail and
file-access guidance. Identity presentation failures are not overwritten by a
success message. Technical details open in a bounded popover instead of expanding
the main page. The existing Fallback slot menu item is enabled and copies a fresh
read-only slot/frame/identity summary on click. A fixture regression checks that
successful reads clear stale access diagnostics. No permission or arrow-position
mutation is performed by these changes.

Main-page scrolling follow-up: Organize, Settings and Support now use static
vertical layout containers, not scroll views with hidden indicators. Horizontal
icon scrolling remains. System-item recovery/unavailability and long status
messages use bounded popovers so they cannot expand the fixed main page.

Arrow investigation instrumentation: the copied Debug fallback summary now
includes a process-local diagnostic session, monotonically increasing creation
count, current instance generation, and native-overflow usability. Counters
change only when the existing factory actually creates a status item. No status
item lifetime, ordering, preference or visibility behavior is changed.

The owner's same-session samples prove unchanged fallback creation/instance
generation across collapse and expansion. A subsequent scoped, read-only
MenuBar preference sample places the owner's fallback key between the two
neighboring Revealable application keys, consistent with the reported expanded
sequence. Exact values and identities remain in LocalData. Copied diagnostics
now include current fish/fallback preferred positions using the previously
reviewed Debug-only getter and its exact ABI guard; no setter is called.


### Isolated grouped-control candidate

The latest owner-supplied getter samples return zero for both controls and do
not provide a usable placement target. No zero position is written. The old
manual calibration recovery only covers temporary experiment identities; it is
not a verified inverse for the live fallback Item-1 key. The proposed manual
repositioning experiment has therefore not been executed.

A separate Debug build flag, `BLENNY_GROUPED_FALLBACK_TRIAL`, now selects a
presentation-only alternative: one existing `Blenny.Fish` NSStatusItem hosts two
independent native NSButton controls. The arrow remains on the left, with its
own target/action, keyboard accessibility and secondary-click safety menu. The
fish opens the editor. Native overflow observation and its bounded fallback
allocation state machine remain unchanged. When the fallback is reserved, the
host content length is 44 points; otherwise it is 22 points. AppKit supplies
its own external margins. There is no coordinate-based split of one action.

This candidate creates no separate fallback item, assigns no new autosave name,
sets no preferred position and removes no saved key. It does not broaden the
ordering writer or recovery scope. The ordinary Release and the existing Debug
build remain on the previous separate-status-item implementation. Selecting
the candidate requires both DEBUG and the additional explicit compile flag.

Detached-view checks run before ordinary application startup. They cover
adjacent independent hit targets, fallback removal and reappearance, and busy
state availability. They create no status item or system writer. Live event
routing, VoiceOver, native-overflow handoff and repeated expansion remain
attended acceptance requirements. The single-host layout prevents an external
status item from appearing between its child controls by construction; that
alone does not prove the complete menu-bar interaction works on the owner's Mac.

No manual Command-drag or real ordering write is needed to evaluate this
candidate. The attended scope is the owner's normal fallback expansion and
collapse, fish click and right-click menu. Do not use Apply/Undo or Stop/Resume
as part of this check. Keep the previous archive available to revert the
presentation, and inspect any unexpected preference drift before additional
experiments. Returning to the previous binary is not claimed as an exact
preference restoration if macOS independently changes stored state.


Grouped candidate verification: Xcode 27 builds pass for the opt-in optimized
trial and ordinary Release. Eight targeted tests in the status-action and
fallback-compaction suites pass. The detached NSStatusBarButton host dispatches
hit tests to the two independent child buttons; the packaged fixture-only
interface check passes. The grouped implementation is absent from the ordinary
Release executable. Ad-hoc package signature checks and an extracted-archive
executable comparison pass. A read-only comparison finds no ordering-table key
changes from the pre-experiment baseline. No ordinary app launch, installation,
manual drag or live writer was exercised. Full live acceptance remains pending.


Grouped-control owner feedback confirms adjacency, but reports that the arrow's
left click does not expand/collapse while the menu action still works. This is
not a passing interaction result. The previous detached hit-test checks did not
exercise actual mouse delivery in the non-key menu-bar window.

The follow-up explicitly accepts the first mouse click and handles the child
button's real primary down/up events, dispatching its existing target/action
once on an inside release. Outside release, cancellation, hidden controls and
disabling during a press do not dispatch. Keyboard/accessibility activation
continues through NSButton. No event is synthesized or posted; no monitor,
position write or backend change is added. Process-local event/dispatch counters
are copied only through the existing diagnostic action to distinguish missing
event delivery from a refused action if owner testing still fails. The exact
runtime failure mechanism remains unconfirmed until that live check.


Click follow-up checks: optimized grouped and ordinary Release builds pass.
The fixture-only and packaged checks pass the primary press/release,
duplicate release, outside release, cancellation, and disabled-transition
cases in addition to detached host layout. Strict signatures and extracted
archive integrity pass. These are local control checks, not posted mouse
events or evidence of actual menu-bar event delivery. The owner must confirm
left-click expansion/collapse in the Grouped Click Trial build.


### Grouped candidate failed attended acceptance (2026-09-14)

The owner reports that left clicks still do not toggle and several revealed
items appear to the right of the grouped control. The copied diagnostic shows
an enabled visible arrow with zero primary events, while the fish child records
primary events and successful target/action dispatch. This establishes that
an arrow action was not delivered; it does not prove which layer retargeted or
mislocated the click. The 0.5.0 own-arrow follow-up already records a similar
failure of single-item region routing despite passing local hit tests. Do not
promote the grouped candidate or describe it as a successful fix.

The initial policy/table comparison counted a Visible key to the fish's left.
Reassessment identifies that sole row as Blenny's own old Item-1 fallback key,
which is not instantiated by the grouped trial. It is not evidence of a Visible
third-party owner interleaved among Revealable owners. Excluding Blenny's own
records and including the mapped system policy keys leaves a separating scalar
interval in the archived configured data. This does not establish live identity,
physical space, or a safe write value. The earlier conclusion that moving only
Blenny cannot work is withdrawn.

Revealable keys do straddle the saved fish position, and the current fish and
original fallback values match the earlier baseline. RevealAllowlistPlan
contains allowance/persistent-visibility intent, not a layout boundary.
Grouping the controls therefore does not by itself establish the owner's
required left-side reveal boundary. Whether repositioning only Blenny's own
controls suffices remains open and should be tested before broader ordering.

The grouped trial remains gated and unsuccessful. Further work must preserve
actual native click delivery and separately validate a recoverable relative
partition boundary. Do not silently reorder during expansion, infer an absolute
position from the zero getter, or claim an exact boundary without complete live
owner/key evidence. No system position write, automatic Stop/Resume or app
replacement was performed during this read-only assessment.


### Reassessment and staged investigation plan (2026-09-14)

This is a proposed plan, not authorization for app relaunch or system mutation.
Existing UI refinements, local files and the completed 0.9.0 milestone remain
preserved. The grouped candidate stays isolated and is not promoted.

Evidence limits:

- The grouped arrow is reported enabled/visible and its primary-event counters
  remain zero. The fish counters are cumulative, so eight fish dispatches do not
  establish that eight arrow clicks were redirected. A successful sendAction
  also does not prove completion of a reveal transition.
- The 0.5.0 failure is relevant historical evidence, not proof of the same root
  cause or impossibility of every public custom-view implementation.
- Detached layout, hit-test and press-state fixtures establish local invariants;
  they do not reproduce native status-window event delivery.
- Stored positions are preferences, not screen coordinates or a complete live
  item inventory. Historical aliases and uninstantiated keys must remain in
  backups but must not be treated as currently displayed icons.

Recommended sequence:

1. Restore the separate native-button build as the comparison baseline while
   preserving current UI work and saved identities. Prepare one-shot diagnostic
   capture of control identity, action entry, rejection reason and verified
   management transition. If investigating the grouped failure is still useful,
   bind one owner click to before/after counters and actual view/window bounds;
   do not infer routing from cumulative totals. No global monitor or synthetic
   input is needed. Verify baseline left/right clicks in one attended round.
2. Read-only boundary assessment: bind active own controls to their autosave
   names, own process lifetime and frames. Bind live third-party/system items to
   owner policies and corroborated preference keys. Classify historical,
   ambiguous and unobserved keys separately without deleting them. Capture
   collapsed/expanded settled geometry in an approved bounded round; Hidden
   stays excluded. Report whether a real gap separates Revealable and Visible,
   whether own controls fit, and whether right-side items change width.
3. Implement and deterministically test a narrowly scoped own-control placement
   and recovery capability before exercising it. Preserve the generic self-owner
   exclusion. Bind only the verified fish/fallback identities and the selected
   runtime; use the existing serial coordinator with a durable intent, exact
   value/type baseline, fresh preflight and bounded verification. Restore only
   known changed own keys, preserve unrelated drift, and fail closed on target
   drift. Cover interrupted writes, restart recovery, changed identities, stale
   plans and busy-writer serialization. A plist backup alone is insufficient.
4. If assessment shows a valid boundary, propose one attended own-controls-only
   move with exact target keys, relative neighbors, complete baseline and
   executable inverse. Obtain that experiment's authorization. Capture baseline,
   execute once, verify left-side reveal and native clicks, then restore and
   verify the baseline before proposing a permanent placement. Do not assume
   an arithmetic midpoint of preferred values is an adoptable physical slot.
   Manual Command-drag is an optional owner-operated alternative only after
   its full possible write scope and recovery are ready; it is not automatically
   safer or necessary.
5. Only if active evidence disproves an own-controls-only solution, design an
   explicit relative partition adjustment for reviewed Apply. No reordering on
   Expand, Collapse, Refresh or startup. Review the new own-control scope,
   third-party owner-block preservation, unsupported system items and Undo
   semantics separately before implementation/real testing. Do not add it merely
   because the grouped trial failed.

Acceptance separates three properties: reliable independent controls; revealed
items entirely to the left of the fallback boundary; and no persistent boundary
shift across a reveal/collapse cycle under unchanged display, item widths and
right-side inventory. Measure settling and rounding without promising absolute
coordinates across display/app changes. Physical placement and exact preference
restoration are distinct checks. Native-overflow appearance/disappearance,
manual and timed collapse, and later owner-approved Apply/Undo or relaunch tests
remain separate lifecycle stages, not one uncontrolled experiment.


### Native baseline and read-only evidence implementation

The owner approved starting the staged implementation. The next optimized trial
uses DEBUG plus BLENNY_NATIVE_BOUNDARY_TRIAL, without the grouped-control flag.
It retains both independent native status items and their existing autosave
behavior. Current UI refinements remain; no preferred-position writer or own-key
ordering exemption is introduced.

Boundary Diagnostics provides Arm Next Click Check, Save Boundary Snapshot and
Open Saved Snapshots. A check is explicitly armed, has one UUID and one input,
and records routing, transition admission/rejection and the resulting state.
Only that explicit call chain carries its diagnostic identifier; native observer
callbacks and later clicks cannot complete or overwrite it. Rearming invalidates
late callbacks from the earlier check. These diagnostics do not monitor input,
schedule polling, or initiate a reveal themselves.

Save Boundary Snapshot performs one bounded AX inventory and one existing
corroborated ordering capture. It does not create a writer, acquire a management
interaction, suspend reveal, refresh the Board, Apply or Resume. It saves the
accepted policy, live own-control names/frames, inventory, configured preferences,
candidate evidence, runtime/process/build identity and click check. Endpoint
context changes are explicitly marked; sequential evidence is not declared an
atomic physical snapshot. Own canonical key matching is distinguished from
uninstantiated saved keys, and local AppKit visibility from physical visibility.
No boundary placement is automatically inferred or authorized by this report.

Raw exports are written only under the installed app's local evidence directory,
Library/Application Support/Blenny/LocalData/BoundaryDiagnostics, with a private
directory and file permissions. The copied value is the saved file path, not
an automatic external upload. Export failures report an error without retrying
or changing permissions. Installed export and native click acceptance are still
owner-operated; no normal app launch or system mutation was performed in the
implementation session.

The attended next round is limited to a collapsed snapshot, an explicitly armed
arrow click and expanded snapshot, and an explicitly armed collapse with a final
snapshot. A fish click and safety-menu check complete native control acceptance.
Do not use Apply, Undo, Stop/Resume or manual dragging in this round. If a click
fails, capture that state and report it instead of continuing by assumptions.
Only after analysis of these files should an own-control placement/recovery
experiment be prepared and authorized.


Native baseline validation: Xcode 27 builds pass for the optimized native trial
and ordinary Release. Twelve targeted tests in three suites pass, including
four new evidence/correlation tests. The latter were rerun after strengthening
late-callback and bounded-terminal-result assertions. The fixture-only interface
entry passes. Binary inspection confirms grouped controls are excluded from
this native trial and the new diagnostics are excluded from ordinary Release.
Package signatures and extracted executable integrity are checked separately.
These checks do not establish owner click success or a physical partition.

### Fallback-only scope and settled baseline

The owner supersedes the earlier adjacency objective: preserve the fish's saved
position and exclude its placement from acceptance. The experimental target is
only the independently instantiated fallback, with Revealable items to its left.
Do not reposition third-party owners or reinterpret the fish as a strict boundary.

Attended native click checks now record both successful reveal and conceal
transitions. An older grouped trial was also running during the first capture;
it was normally terminated with explicit owner authorization. Subsequent settled
expanded and collapsed captures contain one Blenny process, the same executable,
accepted policy and ordering table. The fallback remains interleaved among
Revealable items when expanded. A capture whose state changed during collection
is excluded from the settled comparison. Raw captures remain in LocalData.

The configured and observed boundary includes Revealable system items; moving
past only the adjacent application would not meet the acceptance criterion.
Preferred-position interpolation is a candidate experiment input, not evidence
of an adoptable physical slot. The live owner's autosave preference map is empty;
canonical table-name matching alone must not bypass runtime identity admission.

FallbackPositionDelta implements only a pure, Debug-only single-key value change
and inverse. Its target is fixed to the existing canonical Item-1 key. It retains
the exact original value type, preserves unrelated changes during inverse, and
rejects missing or externally changed targets. Decoding repeats validation.
It is not a durable receipt, an identity proof, or a callable system writer.
Serial coordinator integration, independent durable recovery, fresh native
identity admission and an attended move/inverse remain required before a real
position experiment. No position write has been executed by this addition.

The next implementation adds an independent FallbackPositionRecoveryStore and
receipt state machine, retaining the existing store's private descriptor-bound
I/O, exclusive lease, durable atomic writes and bounded reads. It never reuses
the ordinary ordering receipt filename or supersedes a user's Undo ledger.

CoordinatedPolicyWriter now has an opt-in fallback transaction and inverse under
its existing FIFO gate. The ordinary ordering lease is also held during an
outstanding experiment. Apply/Undo refuse an outstanding fallback journal.
Write intent precedes mutation, a capture verifies the resulting table, and a
failed apply receives at most one inverse attempt. A retained restoreIntent
permits inspection and completion at the original value, but not another blind
write. Temporary experimental placement is subject to cleanup; this does not
change the persistence contract for accepted ordinary ordering.

The macOS backend adds a single-key entry that retains existing runtime, table,
owner namespace and process preflight. It additionally requires a native-instance
identity provider, checked synchronously immediately before the write. The
provider defaults to absent. Generic Blenny self-exclusion remains intact.

The separately selected BLENNY_FALLBACK_POSITION_TRIAL now supplies that provider
from the actual reserved native fallback instance. The window title identifies
Arrow Position Trial. Boundary Diagnostics offers Review Arrow Position
Experiment and Restore Arrow Position. Review captures fresh configuration and
prepares a scalar gap between the configured Revealable and Visible envelopes,
including exact mapped system items and excluding the fish. This is an
experimental candidate, not a proof of complete physical inventory or adoption.
The confirmation dialog discloses the neighboring keys, single-key scope,
uncertain physical placement and inverse. Cancellation does not write. Accepted
reviews expire after 60 seconds and fresh state/instance drift is rejected.

The experiment journal is stored under the app's LocalData/FallbackPositionExperiment
directory. It is injected only in this build flavor. A successful temporary move
remains pending until explicit restoration; Stop/Quit attempts its cleanup as
well. Ordinary accepted ordering is not undone. Keep the trial and its recovery
record available until restoration succeeds, including after a restart; other
build flavors do not provide this experiment's recovery UI. No move runs on
startup, Refresh, Expand or Collapse.

Validation: 49 tests in six suites pass with Xcode 27, including the single-key
delta, independent durable journal, failed-write inverse, native-instance drift,
system boundary selection and existing ordering/coordinator regressions. An
explicitly supplied private settled export passes candidate calculation and
pure inverse checks without launching the application. Debug trial, optimized
trial and ordinary Release builds pass. The fixture-only interface check passes.
The real move, macOS adoption, native click continuity and live inverse remain
owner-operated acceptance; automated tests do not establish these results.

### Accepted fallback placement integration

The owner reports that the attended move places the double arrow to the right
of all Revealable items, while the fish may remain among them. The saved samples
are both settled collapsed states, so expanded geometry is owner-reported rather
than independently captured. Comparison with the receipt baseline confirms that
only the fallback value changes; the fish and all other table values are unchanged.
After inverse, the complete configured group matches the baseline and no active
experiment receipt remains. Visual displacement of the fish is not a preference
swap. These observations support the narrow relative-position route, not a fixed
screen coordinate or universal lifecycle compatibility.

The owner authorized implementation. Position Reveal Arrow and Undo Arrow
Placement are now explicit menu actions in the existing ordering-enabled build.
Accepted placement persists through Stop/Quit and does not block ordinary
Apply/Undo. The independent receipt marks persistence explicitly; absent fields
in old trial records retain temporary-recovery semantics. A repeated placement
archives the previous clean arrow ledger before saving its new intent; Undo
restores the most recent previous placement. External target drift is refused.
An already separating saved position is a no-op. There is no automatic placement
on startup, Expand, Collapse, Refresh or ordinary Apply. After a later group/order
change the owner can explicitly position the arrow again. Generic owner policy,
third-party order and native-overflow behavior are unchanged.

Full Debug regression: 588 tests in 55 suites pass with Xcode 27. New cases cover
Stop retention, a new coordinator's independent Undo, repeated placement/archive
and legacy temporary receipt decoding. These are deterministic lifecycle checks;
real restart adoption and the new menu actions still require attended acceptance.

### Owner-approved fish boundary placement

The owner confirms that the explicit persistent arrow action reaches the desired
boundary, then supersedes the earlier fish exclusion: the fish should share that
boundary. Position Blenny Controls now proposes Revealable, arrow, fish, Visible
from left to right. An arrow already inside the separating interval retains its
exact saved value; only the fish moves when needed. The controls remain separate
native status items with independent click behavior. No third-party value changes.

The scoped delta admits only the existing canonical arrow and fish keys. Its
inverse handles either known endpoint independently after a partial write and
rejects external drift. Receipts containing fish use schema 2, so older binaries
fail closed rather than silently restoring only half the scope. Existing clean
arrow-only receipts can be archived and superseded by the reviewed two-control
placement. Undo Control Placement restores the immediately preceding saved
positions. Stop/Quit persistence and the absence of automatic reconciliation are
unchanged. Actual two-control placement still requires owner acceptance.

Validation of this extension: 590 tests in 55 suites pass, including a fish-only
delta with an unchanged arrow, partial inverse, schema upgrade, archive and exact
Undo to the prior arrow-only state. The optimized ordering-enabled build passes.
No live placement was performed during implementation.

### Follow applied partition changes

The owner accepts the two-control placement but reports that cross-area Apply
leaves newly Revealable items to the controls' right. The previous standalone
placement retained old scalar positions while the application slot permutation
changed the partition boundary. The owner-requested follow-up supersedes the
earlier exclusion of ordinary Apply as a placement trigger.

After successful configuration Apply, policy-only Apply or ordering Undo, an
existing accepted persistent control placement is recalculated from the current
table and accepted policy. Without that accepted placement record, no automatic
placement is enabled. An unchanged boundary is a no-op; an empty Revealable set
does not force a move. Expand, Collapse, Refresh and startup remain non-triggers.
Explicit control Undo removes the active placement record and disables following
until the owner positions controls again.

This is a bounded follow-up within the UI's explicit operation, routed through
the same serial writer with fresh preflight and independent recovery. It is not
an atomic transaction with the preceding application/policy commit. If placement
fails, the successful application changes remain committed and the interface
reports the control-placement failure separately. Recovery reverses only known
control changes; it does not undo the already accepted application changes.

Regression verification passes 591 tests in 55 suites. The added case shifts a
configured boundary by one and two slots, checks both controls inside the new
gap, preserves all non-control values, verifies the no-op path, and verifies
that a failed control write preserves preceding application changes after inverse.
Live cross-area acceptance remains pending.

### Single-level ordering Undo

The owner replaces cumulative-session Undo with single-level Undo of the latest
successful ordering Apply. A verified commit advances original values to the
preceding committed positions. Pending writes retain the previous Undo baseline,
so a failed revision rolls back without consuming that Undo. Newly included keys
use their pre-Apply values. Stop/Quit retain the receipt; successful Undo consumes
it. Existing receipts retain their recorded baseline until the next successful
Apply; no older per-step history is invented. Visibility policy is unchanged by
clean ordering Undo. Control placement remains independently journaled.

The durable store admits baseline advancement only for a matching pending plan,
revision, session and verified result. Arbitrary replacement of a clean baseline
remains rejected. External drift still requires explicit reviewed supersession.
The observed stale control-placement ledger is not resolved by this semantic
change; its safety checks remain in force.

### Reviewed stale control placement recovery

A clean control receipt can disagree with the current saved control values. This
is target drift, not an outstanding ordinary ordering transaction. Automatic
Apply/Undo follow-up still rejects it. Explicit Position Blenny Controls discloses
replacement of the stale Undo baseline and binds confirmation to the complete
previous receipt, fresh candidate and native identity. Under the serial writer
and both leases, the matching clean receipt is archived before the new intent.
Undo returns to the fresh pre-operation control positions; third-party values
remain untouched. Pending recovery is never eligible for this replacement.

Ordering actions now clear the separate footer feedback as well as the ordering
card; successful Undo reports Order restored rather than retaining old Apply
feedback. This does not prove the cause of macOS position changes or guarantee
that later changes cannot make the new receipt stale again. Live recovery and
subsequent Apply/Undo boundary acceptance remain owner-operated.

### Visibility-only system controls and boundary candidates

Siri visibility changes exposed an incorrect boundary constraint: candidate
classification included unproven system ordering keys. Candidate calculation now
uses only system items whose ordering is offered. Siri, Time Machine and Control
Center saved positions are not evidence of a configurable boundary. This is a
configured gap among supported ordering subjects, not a physical guarantee for
excluded controls. The regression includes a Revealable Siri value that would
otherwise overlap the Visible envelope. Undo Order retains its order-only scope;
its help now explicitly states that visibility settings are unchanged.

### Unified last-Apply Undo Changes

The owner supersedes the single-level order-only decision. The ordering-enabled
Board now routes policy-only and mixed Apply through the serial configuration
transaction. A policy-only plan has no position keys and cannot write positions;
the coordinator requires a prepared policy change for this empty scope.

Schema 4 recovery records retain the before/after policy and previous backup
separately from unfinished-write metadata. Clean accepted changes survive Stop
and Quit. Only a successful Apply advances the last-change baseline; failed
commits retain prior Undo. Old order-only receipts keep their original scope
until replaced by a new Apply. Older binaries reject the new receipt format.

Undo obtains a fresh validated inverse policy plan, records recovery intent,
restores positions and the live visibility plan, restores policy persistence,
then consumes the receipt. Intermediate failure keeps recovery metadata. An
interrupted policy inverse is verified instead of blindly repeated. Changed
accepted policy or unavailable fresh identity fails closed; Undo never silently
resumes a stopped coordinator. The existing control-boundary follow-up runs
after interface policy synchronization and remains separately recoverable.

The button reads Undo Changes and its help identifies both visibility and order.
Siri remains visibility-only; this does not add unsupported Apple ordering.
Actual adoption and inverse still require owner testing with the new package.

Unified Undo validation: 594 tests in 55 suites pass without warnings, including
real recovery-file round trips for third-party and Siri visibility with and
without ordering. The optimized ordering build and ordinary Release build pass;
the packaged fixture-only interface check and archive/signature checks pass.
A lost final-save acknowledgement is accepted only when the exact verified
committed receipt can be read back; otherwise failure recovery remains required.
No normal app launch, system write, installation, commit or publication occurred.

### Bounded automatic refresh after Undo

Undo marks its commit result before interface synchronization. A successful
ordering read clears the stale-observation flag. If interface synchronization or
the post-Undo read fails, one existing read-only Refresh is invoked after the
interaction gate is released. No transaction is reapplied, and no polling or
unbounded retry is introduced. A failed follow-up still exposes its failure.

### Closure (2026-09-15)

The owner reports that the final Undo auto-refresh candidate operates normally
and authorizes closing 0.10.0. Successful Undo now says Changes undone.; details
retain the distinction between verified saved settings and unavailable independent
physical verification. Genuine inverse and control-placement failures remain
visible. The release record defines tested scope and 0.11.0 follow-up boundaries.
