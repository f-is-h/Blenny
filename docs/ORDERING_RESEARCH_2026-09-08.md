# Ordering adoption control, 2026-09-08

Status: **A corrected external two-owner swap and exact inverse passed on
macOS 27.0 build `26A5425a`.** A separate controller wrote the two system-log-
verified keys through the `com.apple.MenuBar` group preferences. Both owner
processes and their own saved positions stayed unchanged; the final isolated
run used no width changes, item recreation or synthetic input. Independent AX
coordinates corroborated the swap and exact return. The complete original
48-entry group table and absent test-owner preferences were restored.

This proves a working external research route for these original test owners,
not a general third-party product backend. Earlier negative trials used
colliding or unverified system identities and cannot establish impossibility.
No product behavior, version or release state changes. Native-arrow ownership
remains outside scope.

Owner-authorized real-application follow-up: the approved Snipaste / Usage4Claude
pair subsequently passed a relative swap and inverse through the same group
preference route. The full preference baseline returned, but the final AX
coordinates had a common three-point rightward shift, also observed in 17 other
single-item owners. The owner then requested an attended repeat, confirmed
readiness, and visually confirmed both the swap and restoration as appearing
perfect. See the final section; this is not exact global coordinate restoration
or product promotion.

The observations below preserve the original chronology. Statements about
unverified remote adoption and the decision to stop global writes describe the
knowledge available at that point; see the identity correction at the end.


## Question tested

The owner authorized one further investigation with a stopping condition:
establish a positive control, separate position changes from layout refresh and
recreation, and require an observable swap and inverse. The first gate was to
make two original test applications change their own relative order, without an
external write to Apple's global position dictionary.

The environment remained macOS 27.0 build `26A5425a`, one 1600-by-900-point
display. The global group table now had 48 entries, rather than the previous
run's 47. A fresh read-only snapshot was used; the old snapshot was never restored
over this intervening external change. Neither test identity existed in the
table. No existing application was a preference-write target.

## Method

The original [Debug fixture](../Research/OrderingAdoptionProbe/README.md) uses two
distinct accessory application bundles and one AppKit item per owner. Both use
the explicit autosave identity `AdoptionProbe`. Their original own positions are
120 and 1000. Each owner accepts a bounded sequence of exact commands with
receipts, and removes its item and initially absent preferences at cleanup.

Read-only AppKit disassembly had established that
`NSSceneStatusItem._sendSavedPreferredPosition` updates its own scene settings;
the settings block obtains `_savedPreferredPosition` and calls
`setSavedPreferredPosition:`. The probe verifies the sender's `v16@0:8` and
getter's `f16@0:8` encodings before invoking them on its own item. This does not
invoke a method inside another process or prove that the remote host adopted
the value.

The controller sends owner commands serially and checks their receipts. It
changes only the owner positions first, observes after eight seconds, then
changes A's public item length by one point and observes separately. Restoring
the positions, restoring the width, and recreating the owned items are also
separate phases. An independent scoped AX reader checks the owner window
coordinates; an important initial disagreement is recorded below. There is no global writer, simulated input, continuous polling,
automatic retry, process injection or system-service restart.

## Results

The original owner PIDs remained unchanged throughout. The owner's getter
confirmed the requested values at each observation:

| Observation | Owner saved values A / B | Owner window X, A / B | Relative order |
| --- | --- | --- | --- |
| Initial creation | 120 / 1000 | 471 / 431 | A right of B |
| Send swapped values on existing items | 1000 / 120 | 609 / 609 | Coincident; order unobservable |
| Change A's width from 24 to 25 | 1000 / 120 | 1402 / 1362 | A right of B |
| Send original values, retaining changed width | 120 / 1000 | 470 / 430 | A right of B |
| Restore A's width to 24 | 120 / 1000 | 471 / 431 | A right of B |
| Recreate the test items with original values | 120 / 1000 | 1403 / 1363 | A right of B |

The one-point length change appeared in the observed window and AX widths.
This is evidence that the test command affected layout geometry. It does not
prove a relative-position update: no separated observation showed A left of B.
The original coordinates returned after restoring both owner values and width,
but that alone is not a swap-and-inverse success. The same seeds after item
recreation produced different coordinates, further limiting a deterministic
placement claim.

The independent AX reading immediately after the initial owner samples already
reported coincident X coordinates, 616 / 616, rather than the owners' separated
positions plus their seven-point button inset. Thus even the initial order was
not a stable, corroborated baseline. The swapped AX sample was also 616 / 616;
the subsequent samples matched the owner frames with the button inset. The
initial mismatch was detected during the final evidence audit, not by the
original live controller. The preserved executed controller remains in local
evidence. The retained source now rejects an unstable or coincident initial
owner/AX comparison before sending any position change; that guard was tested
deterministically and subsequently exercised by the owner-authorized isolated
follow-up below.

A subsequent bounded read-only visibility probe returned `AXEnabled = true`
for both owners, but `AXHidden` was unsupported (`-25205`). Consequently neither
enabled state nor coincident AX frames settles actual compositor visibility or
overflow membership. No pointer movement, activation, screen-recording request
or screenshot was used to force that distinction.

## Environment limits and restoration

Owner correction received after this run: **Blenny was already in its stopped
management state.** The persisted trial policy's enabled flag did not establish
an active assertion. The earlier suggestion that management was active was
unsupported and is withdrawn. No explicit policy entry named either temporary
owner. The owner subsequently quit Blenny entirely and authorized an isolated
reproduction; a fresh process check confirmed Blenny, Thaw, Ice and Bartender
were absent. The original failure remains limited to the actual observed
conditions and cannot be generalized to every private API.

Both the main control and the short visibility probe terminated their test
owners and passed the fresh owner-preference absence check. The complete group
property list remained logically equal to the fresh 48-entry baseline. This
pass performed zero external table writes. Preference equality is not a claim
that the complete unrelated compositor layout was restored.

Xcode 27 / SDK 27 built the Debug fixture. Compiling without `DEBUG` was rejected
as intended. The scope-negative CLI checks rejected an unrelated bundle and an
unknown command without posting notifications.
The four deterministic controller failure tests passed: a missing receipt
prevents the next mutation and stops both owners; foreign group drift is
preserved; and unsuccessful cleanup produces failure even without an earlier
execution error; and an unstable initial AX order prevents the first position
change. The reproducible build script also completed without launching
its output applications.

Product sources, targets and
installed executable were not changed; product tests were not rerun for this
research-only update. Raw receipts and observations remain ignored in
`LocalData/2026-09-08-ordering-adoption/`.

## Decision

The promised positive control did not pass. Proceeding to more global writes
would combine an unverified ordering signal with unverified external adoption.
Accordingly, the external-write portion of this round was deliberately not run.

For Blenny's current product plan, ordering remains deferred. Reopening should
require new discriminating evidence: for example, a verified isolated control
with current management state accounted for, a direct observation of the
agent's adopted position input, or a new runtime contract. More guessed weights
and repeated writes under the same conditions do not satisfy that gate.

## Owner-authorized isolated follow-up

The owner clarified that Blenny had already been stopped, then quit it and
authorized further experiments. Process checks before and after the isolated
sequence confirmed that Blenny, Thaw, Ice and Bartender were absent. None was
launched or controlled by this investigation. The installed MenuBarAgent image
was also byte-hash matched to the retained arm64e image used for static analysis;
the earlier traces are not from a different installed OS image.

The full control was rerun from a fresh evidence directory. The initial owner
and AX samples agreed, so the new baseline guard passed. All six phase samples
agreed with their independent AX readings, including the seven-point button
inset. The owner values again changed from 120/1000 to 1000/120 and back:

| Isolated phase | Owner window X, A / B | Result |
| --- | --- | --- |
| Initial | 1363 / 1403 | A left of B |
| Send swapped owner positions | 1363 / 1403 | No swap |
| Change A's width by one point | 510 / 551 | Both move; same relative order |
| Restore owner positions | 510 / 551 | No relative-order change |
| Restore A's width | 1363 / 1403 | Initial coordinates return |
| Recreate items with original seeds | 1403 / 1363 | Relative order changes after recreation |

This reproduces the uncontrolled behavior with the management applications
absent. It does not support attributing the earlier failure to active Blenny
management. Restoring the width and values can return coordinates, but the
requested apply never swapped the items, and recreation remains a separate
source of order changes.

### Observe the actual owner scene input

A separate settings-only control added read-only inspection of the owned
`NSSceneStatusItem._scene` object. It reads `NSStatusItemScene.clientSettings`
and `hostSettings`; these return `FBSSceneClientSettings` and `FBSSceneSettings`
objects with the status-item fields. It does not inspect memory inside the agent.
The test preserved the status-item objects and width throughout this shorter
sequence, with no recreation or layout nudge:

| Settings-only observation | Owner saved values | Scene client saved values | Owner X, A / B |
| --- | --- | --- | --- |
| Initial | 120 / 1000 | 120 / 1000 | 551 / 511 |
| Swap | 1000 / 120 | 1000 / 120 | 551 / 511 |
| Restore | 120 / 1000 | 120 / 1000 | 551 / 511 |

The AX samples corroborated these positions. Thus the requested values were
present in the local scene client configuration; a mere failure to update the
owner defaults or local client value no longer explains this control's result.
The observed host-settings `preferredPosition` stayed zero. That field is not a
direct read of `NSStatusItemHost` inside MenuBarAgent and must not be used to
claim that the agent definitely rejected, ignored or never received the input.
Transport, remote adoption, eligibility and final layout decisions remain open.

Two preliminary scene-observation attempts stopped before the position swap
because the probe expected a plain object-return encoding for `autosaveName`.
Runtime inspection showed the more specific `@"NSString"16@0:8` encoding. The
probe was corrected to validate that exact signature. This was an instrumentation
error, not evidence that the system lost the name or that its private API changed.
During the intermediate metadata run, a null field with this mismatching
signature meant the getter was skipped, not that its value was actually null.

A final snapshot-only run, with no position-change commands, successfully read
`AdoptionProbe` from both scene clients and 120/1000 from their saved-position
fields. This confirms the identity in the live local scene configuration in
addition to the previous static host-identity trace.

### Follow-up verification and boundary

Every follow-up sequence, including rejected observations, passed test-owner
cleanup and logical comparison of the complete fresh group preference baseline.
All 48 global position entries remained unchanged; no global writer was used.
The final fixture builds explicitly with Xcode 27 / SDK 27. Six deterministic
controller failure tests pass, including unavailable scene input and mismatched
scene identity before position-change commands. Product source, installed
executable, native-arrow behavior, version, tags and Git history were not changed.

Ignored evidence directories are `LocalData/2026-09-08-ordering-isolated/`,
`LocalData/2026-09-08-ordering-scene-input/`,
`LocalData/2026-09-08-ordering-scene-nullable/`,
`LocalData/2026-09-08-ordering-scene-contract/`, and
`LocalData/2026-09-08-ordering-scene-identity/`.

The additional result narrows the question: owner identity and saved values can
reach the local scene configuration without producing a controlled physical
swap. This closes those two local-input explanations. It does not establish a
working external global-table implementation or prove that every private
ordering path is impossible.

## System-log identity correction

A bounded, read-only query found 344 retained `Using legacy NSStatusItemHost
preferredPosition` events for the original fixture. All used the same system
key, `status:probe::AdoptionProbe`, with values alternating between 120 and 1000.
This is system-side evidence of legacy input, beyond the local scene fields.
Distinct `CFBundleIdentifier` values did not produce distinct sorting keys.

Static inspection of the installed key builder at `0x10028433c` includes an
executable-last-path-component fallback when its bundle identity is unavailable.
The old fixtures shared both the executable basename `probe` and autosave
`AdoptionProbe`. The logs directly confirm this fallback in these runs.
Therefore the earlier physical observations remain real, but the two independent
sorting identities assumed by the control were not present. Collision is a
plausible explanation for the coupled motion and recreation-dependent order;
it does not by itself prove that every observed failure had that cause.

The corrected fixture uses `OrderingAdoptionA` / `OrderingAdoptionB` executables
and `AdoptionProbeA` / `AdoptionProbeB` autosave names. Its initial system logs
confirm `status:OrderingAdoptionA::AdoptionProbeA` and
`status:OrderingAdoptionB::AdoptionProbeB`, at 120 and 1000 respectively. This
also means external writers must resolve the actual key; substituting a bundle
ID without checking the fallback is insufficient.

The first corrected settings-only run started at X 1403 / 510. Updating the
local scene inputs to 1000 / 120 left those coordinates unchanged. No fresh
merge log was emitted during the bounded swap observation. The controller
initially treated that log absence as a failed sample and stopped both owners,
with exact preference cleanup and unchanged complete group file. Absence of
a fresh merge log is not evidence of rejection. The controller now records
that absence after a verified initial identity and continues its planned
inverse and independent refresh observations.

Raw evidence remains in `LocalData/2026-09-08-ordering-system-adoption/` and
`LocalData/2026-09-08-ordering-distinct-identity/`.

## Corrected owner control: positive with an explicit refresh

With distinct system keys, the full owner control produced:

| Phase | Own values A / B | Owner X, A / B | Fresh merge input |
| --- | --- | --- | --- |
| Initial | 120 / 1000 | 1403 / 511 | 120 / 1000 |
| Send swapped values | 1000 / 120 | 1403 / 511 | No fresh log |
| Change A width 24 to 25 | 1000 / 120 | 510 / 1403 | 1000 / 120 |
| Send original values | 120 / 1000 | 510 / 1403 | 120 / 1000 |
| Restore A width to 24 | 120 / 1000 | 1403 / 513 | 120 / 1000 |
| Recreate with original values | 120 / 1000 | 1403 / 513 | 120 / 1000 |

Independent AX readings matched these owner coordinates with a seven-point
button inset. This is a positive relative swap and inverse, although B's final
X differed by two points from its initial X. It is not exact coordinate
restoration. The extra width change distinguishes adoption of new owner input
from the final geometry update. This observation does not imply that every
ordering route requires that refresh.

## External writer: positive without owner cooperation for ordering

The original `GroupWriter.m` is a separate Debug executable. It uses the checked
`NSUserDefaults._initWithSuiteName:container:` initializer for the actual
`com.apple.MenuBar` group container, sets `TrailingItemPreferredPositions`, and
synchronizes. It does not edit the plist file directly, post guessed signals,
restart a service or invoke methods inside another process.

Before applying, the controller snapshots the complete fresh group plist. The
writer verifies the exact build and method encoding, matching container/file
reads, unchanged whole-file baseline, absent test keys, live initial owner PIDs,
and the actual two keys observed in the controller's system logs. The two added
entries are:

```text
status:OrderingAdoptionA::AdoptionProbeA = 1000
status:OrderingAdoptionB::AdoptionProbeB = 120
```

Every original table entry is preserved. The inverse removes only those two
matching test entries, exposing the owners' unchanged legacy positions again.
It preserves unrelated concurrent table drift and rejects changed test values.
Apply and inverse each have an intent receipt, one synchronization/readback and
at-most-once execution. A file lock and serial controller prevent overlapping
local writers; this is not an atomic transaction against Apple's own writers.
Interrupted-run recovery is documented in the fixture README.

The first external run swapped the icons at the first observation, **before**
its separate width nudge. Restoring the external table reversed their order;
after restoring the width, the original X 1403 / 511 also returned exactly.
Both owner saved values and local scene saved values stayed 120 / 1000.

A second, deliberately narrower run removed all width changes and recreation:

| Pure external phase | Owner saved values | Owner X, A / B | Independent AX X, A / B |
| --- | --- | --- | --- |
| Initial, no test overrides | 120 / 1000 | 1403 / 512 | 1410 / 519 |
| Add the two swapped overrides | 120 / 1000 | 512 / 1403 | 519 / 1410 |
| Remove the two overrides | 120 / 1000 | 1403 / 512 | 1410 / 519 |

The two owner PIDs, item widths and item objects remained unchanged during this
sequence. No owner position command, status-item recreation, pointer movement,
click, key event, process injection, private entitlement or system restart was
used. Commands to the owners between creation and cleanup only read snapshots.
Observations follow bounded eight-second holds; this does not measure animation
latency or establish a zero-flicker guarantee.

When the configured overrides were present, the test keys no longer emitted
legacy-fallback merge logs. Removing them restored logs of 120 / 1000 under the
same keys. This agrees with the statically inspected configured-first merge,
but the decisive ordering evidence is the independently corroborated geometry.
The local scene host `preferredPosition` still read zero throughout; it must not
be interpreted as the agent's effective preferred value.

## Final verification and next boundary

Both external sequences completed apply and inverse with two confirmed table
writes each, no errors and no retries. The owners exited and their preference
domains returned to absence. The whole group plist was logically equal to each
fresh baseline; all 48 original entries remained intact. The pure external run
also restored the exact initial test-item coordinates before cleanup. Equality
of the entire unrelated rendered menu bar is not asserted.

The original Debug probes and writer compile with explicit Xcode 27 / SDK 27.
Fifteen deterministic Python tests cover identity parsing, missing receipts,
foreign drift, cleanup failure, unavailable scene evidence, partial external
apply, failed inverse without retry, AX process mismatch and the distinction
between inverse order and exact coordinates. Four native pure checks cover
inverse restoration, unrelated drift preservation, target-drift rejection and
idempotent no-op restoration. Product tests were not rerun because all executable
changes are isolated research sources outside the product targets.

The implementation and evidence now justify further engineering, rather than
another blanket no-go. Remaining product work includes a reliable mapping from
real owning applications to their **actual** system persistence keys (including
fallbacks and multiple status items), safe handling of concurrent system writes,
and display/overflow/lifecycle validation. No unapproved existing third-party
or Apple item has been mutated. This successful two-owner experiment does not
yet authorize or demonstrate arbitrary application compatibility.

Raw evidence and executed source snapshots remain ignored under
`LocalData/2026-09-08-ordering-distinct-refresh/`,
`LocalData/2026-09-08-ordering-distinct-external/`, and
`LocalData/2026-09-08-ordering-external-only/`. The research change leaves the
installed Blenny executable, product targets, native-arrow implementation, tags
and Git history unchanged.


## Real-owner mapping and offline planning follow-up

The next owner-authorized development step implemented original read-only
identity discovery and an offline swap/inverse planner under
`Research/OrderingAdoptionProbe/`. It did not broaden the live writer's fixed
two-test-owner scope or modify the installed product.

`ReadOwners.swift` is a Debug-only, build-gated one-shot reader. It records
running application bundle IDs, executable basenames and process launch times;
checks only candidate owners' AX extras-menu trees within a 12-second traversal
budget; and reads only their saved status-item position preferences. Numeric
preference types, key-list completeness and a 64-position-key cap are explicit.
It captures process descriptors again, makes no AX action/attribute writes,
requests no permission, and never launches or activates applications.

`capture_identity.py` combines these observations with the actual group table
and a bounded read of the last 60 seconds of retained legacy merge logs. Raw
inputs remain in a new private local evidence directory. The whole group plist
is compared again after capture. This is a one-shot diagnostic entry point,
not a scheduled scan or continuous reconciliation loop.

The original `identity.py` associates exact tokens without case folding or
Unicode normalization. It considers bundle and executable matches together;
an apparent exact bundle match cannot hide a colliding executable in another
process. Missing owners, ambiguous tokens or bundles, unavailable launch times,
changed processes, incomplete AX observations, multiple live items and extra
historical keys all prevent single-item candidate selection. System owners
remain excluded. Multi-item bundle coverage is intentionally unresolved; the
resolver never silently selects a convenient subset of an application's keys.

### Evidence levels and observed limits

A current-lifetime legacy merge event can corroborate a live system key. An
entry in the configured table alone cannot: it may be stale. Conversely, a
configured override suppresses the legacy-fallback log, so no recent legacy
message is not evidence that the owner is absent or the override ineffective.
The read-only pass did not manufacture refresh events to obtain logs.

For configured entries, the reader cross-checks the exact persistent suffix
against the owner's sole saved-position autosave name, alongside one AX item
and a stable unique owning process. These are **configured review candidates**,
not directly observed live remote-host identities or write authorization.
A preliminary gate required equal saved and configured values; that was too
restrictive because the configured position intentionally overrides the legacy
owner value. The corrected gate corroborates names and reports the position
values independently. An incomplete/unknown preference read never passes.

The final read-only sample contained 48 configured entries: seven module keys
and 41 status keys. **26 keys associated with current processes; 11 non-system
single-item candidates passed the configured-name/AX/lifetime cross-checks.**
An earlier sample associated 25 keys; the captures are separate observations of
a changing process inventory, not a stable count of 25 or 26 applications.
There were zero recent-log review candidates in these samples. Neither evidence
level enables automatic writes. The unrelated application inventory stays local.

### Offline preview implementation

`preview_order.py` selects exactly two distinct, corroborated owning bundles,
preserves their exact observed keys and process identities, and serializes a
fingerprinted `previewOnly` plan. A pure transition evaluator swaps the existing
configured inputs, or a corroborated legacy input when originally absent. It
then demonstrates the inverse in memory. Existing values return to their saved
values; newly introduced keys return to absence. A stale apply baseline,
modified plan or unexpected target drift rejects. Inverse evaluation preserves
unrelated table changes and supports a partially applied known pair without
mutating its input dictionary on failure.

An offline preview was generated for two installed non-system single-item
owners with configured positions 995 and 581. The proposed swap and exact
in-memory inverse passed. **Neither real application was moved.** The plan is
not accepted by the existing fixed-scope native writer and is not an execution
capability. Its recorded snapshot is historical evidence: a live implementation
must reacquire identity, process and preference state before applying anything.

### Validation and remaining integration

Explicit Xcode 27 / SDK 27 builds pass for the Debug readers and retained
research helpers. The Python suite now passes **40 tests**: the original 15,
17 identity cases and eight offline plan cases. Coverage includes executable
collisions across bundles, bundle/executable cross-collisions, PID lifetime
changes, stale/future logs, missing/multiple AX items, incomplete owner
preferences, existing/absent inverse state, partial apply, foreign drift,
modified plans and duplicate/system scope rejection.

This follow-up performs **zero system mutations**. The complete group plist
remains logically equal to its pre-read snapshot and the installed Blenny
executable retains its accepted hash. Product targets, normal/Release behavior,
visibility policy, native-arrow implementation, version and Git history remain
unchanged. These readers and the offline planner are still research modules;
they are not yet integrated into the Blenny Debug application's writer or UI.

The next live integration requires a serial, receipt-backed backend for the
reviewed real-owner plan, fresh preflight checks, explicit approval of the exact
third-party scope, and attended icon identity/swap/restoration verification.
The repository rule against mutating an unapproved third-party bundle remains
in force. No claim of general application compatibility follows from a token
association or offline round trip.

Final raw evidence is retained only under
`LocalData/2026-09-08-ordering-real-identity-final/`; the original read-only
observations and the rejected overly restrictive value-equality check remain
in their separate ignored identity-capture directories for audit.


## Owner-authorized Snipaste / Usage4Claude trial

The owner explicitly authorized executing the proposed next step and asked to
be notified when visual confirmation was needed. This authorized the exact pair
from the preceding preview: Snipaste (`com.Snipaste`) and Usage4Claude
(`xyz.fi5h.Usage4Claude`). No additional third-party or system item became a
mutation target.

### Implemented live entry point

The original Debug-only `ApprovedPairWriter.m` uses the previously exercised
private group-preference access path. Its scope is hardcoded to exactly:

```text
status:com.Snipaste::Item-0             995 → 581 → 995
status:xyz.fi5h.Usage4Claude::Item-0    581 → 995 → 581
```

It does not accept arbitrary bundle/key input or silently update a different
baseline. It verifies build `26A5425a`, the container initializer encoding,
container/file agreement, the complete unchanged group snapshot, a corroborated
single-key mapping for both owners, a capture younger than 60 seconds, and the
current process IDs and launch times. The inverse restores the original
**existing values**, unlike the temporary-owner control's removal of initially
absent keys. It preserves unrelated table drift and rejects an unexpected target
value or type.

`run_approved_pair.py` serializes apply and inverse, records intent/completion
receipts, independently samples AX, and compares group and owner preferences
afterward. It holds the swapped state for 65 seconds after the first during-run
sample. A separate process performs one recovery check at a 100-second deadline
if the main controller disappears. A completed inverse is not repeated; an
incomplete inverse receipt is reported for inspection rather than blindly
retried. Native file locking and at-most-once receipt checks prevent duplicate
writes. Recovery uses the same exact-scope native writer.

### Observed outcome

A fresh capture still contained 48 group entries, and both approved owners
passed the configured-key, autosave-name, single-AX-item and stable-process
checks. Blenny, Ice, Thaw and Bartender were absent; this trial launched or
terminated none of them. No application or system process was restarted.

| Phase | Snipaste AX X / width | Usage4Claude AX X / width | Relative order |
| --- | --- | --- | --- |
| Initial | 599 / 24 | 879 / 121.5 | Snipaste left |
| External swap | 969 / 24 | 591 / 121.5 | Snipaste right |
| External inverse | 602 / 24 | 882 / 121.5 | Snipaste left |

Both AX owner PIDs remained unchanged. Different item widths mean that swapping
preferred positions does not imply exchanging their exact left-edge coordinates.
The independent observations establish a relative-order swap and inverse. No
owner position command, width change, item recreation, synthetic input, process
injection, Screen Recording or system-service restart was used.

A separate during-run read confirmed that exactly the two approved group values
changed. Both applications' own saved-position preference snapshots remained
unchanged during the swap and after the inverse. The complete group plist
returned logically to the original 48-entry snapshot, including all unrelated
entries. Native receipts confirm one apply and one inverse; the independent
watchdog later found recovery complete and did not repeat the write.

**Exact absolute AX geometry did not return:** both target X values were three
points to the right of their initial coordinates. Their widths and original
280-point X separation returned unchanged. Comparing the already-captured
before/after owner observations found the same three-point translation in
19 single-item owners (including the targets), while two others had no X shift.
This supports a shared layout translation observation, not a target-specific
relative-order failure. Its cause was not determined, and exact restoration of
the entire unrelated rendered menu bar is not claimed. No extra mutation was
attempted to chase those three points.

The owner was prompted during the swapped interval to visually confirm whether
Snipaste moved to the right of Usage4Claude. The interval ended and the inverse
completed automatically without requiring an answer. At the time this result
was recorded, human visual confirmation was unavailable. The owner later
explained that they had not been watching and explicitly requested the attended
repeat below. The initial unattended run remains machine evidence only.

### Verification and remaining boundary

The Debug tools build explicitly with Xcode 27 / SDK 27. The research suite
passes **44 Python tests**, including four new controller cases for successful
swap/inverse, incomplete initial AX preventing a write, apply failure followed
by inverse, and a failed inverse not being blindly retried by the watchdog.
Four native pure inverse/preservation checks also pass. The result and watchdog
report contain no execution errors. The installed Blenny executable retains
its accepted hash; product targets, normal/Release behavior, native-arrow
implementation, version and Git history are unchanged.

This supplies the first successful **approved real-application pair** evidence,
beyond original test owners, with exact scoped preference restoration. It does
not establish arbitrary application support, multi-item bundle ordering,
independence from overflow/display changes, visual smoothness, or exact global
coordinate restoration. No further live write or product promotion follows
automatically from this completed experiment.

Executed sources and binaries are retained under ignored
`LocalData/2026-09-08-approved-pair-tools/`; the fresh baseline, phase observations,
receipts and recovery evidence are in
`LocalData/2026-09-08-approved-pair-live/`.


## Explicitly requested attended repeat: visual confirmation passed

The owner reported missing the first real-pair observation and explicitly
requested one repeat. They also clarified that the two applications' icons are
not adjacent. The experiment exchanges their configured preferred positions;
it does not assume adjacency or attempt to place them next to one another.
Other icons may remain between the selected pair.

The assistant first asked the owner to locate both icons and confirm readiness.
The owner confirmed that both were found and observation could begin. The
repeat then used the **same previously tested binaries and sequence**, with a
fresh 48-entry group snapshot and fresh identity/lifetime checks. Both approved
keys still had exactly the original 995 / 581 values. No competing menu-bar
manager was present. This was one newly authorized repeat, not an automatic
retry or a change of scope.

| Repeat phase | Snipaste AX X / width | Usage4Claude AX X / width |
| --- | --- | --- |
| Initial | 600 / 24 | 880 / 121.5 |
| Swapped | 970 / 24 | 592 / 121.5 |
| Restored | 598 / 24 | 878 / 121.5 |

During the bounded swapped interval the owner explicitly confirmed that the
left/right order had exchanged. After the automatic inverse, the owner
confirmed that the original positions had returned and that both the exchange
and restoration looked perfect. These are positive **human visual observations
of this attended run**, in addition to the independent AX relative-order data.
They are not a general animation or compatibility guarantee.

The native receipts again confirm one apply and one inverse, with no errors.
The complete original group property list, all 48 entries, and both applications'
saved-position preference snapshots returned unchanged. Both owner PIDs and
widths remained unchanged. The independent watchdog found recovery completed
and did not repeat the write. The installed Blenny executable retained its
accepted hash. No pointer movement, simulated input, item recreation, app or
system restart, or native-arrow ownership change occurred.

As a separate measurement, both restored target X values were two points left
of their initial X values, while their original 280-point separation returned.
The controller therefore correctly retains `exactAXGeometryRestored: false`.
The owner-confirmed visual success and exact scoped preference restoration must
not be rewritten as exact global absolute-coordinate equality.

The updated conclusion is that this private group-position path has passed
**real-application relative swap, inverse, scoped state restoration and attended
visual verification for this approved, non-adjacent pair**. This removes the
remaining visual-confirmation gap in this pair's feasibility result. General
bundle discovery, multi-item owners, display/lifecycle behavior and product
integration remain separate work. No product version is closed or promoted by
this research result.

Evidence, including explicit readiness, swap and restoration confirmations,
remains only in ignored `LocalData/2026-09-08-approved-pair-repeat/`. No source
behavior changed for the repeat, so the preceding 44 Python tests and four
native pure checks were not redundantly rerun. Historical source and executable
snapshots remain in the existing approved-pair tools directory.
