# 0.11.0 technical spike

Status: **complete local permissions and interaction-stability milestone,
2026-09-25**, with owner acceptance of Build 15 native dragging and Apply.
See [the release record](RELEASE_0.11.0.md) for final evidence and limits.
Public distribution, broader permission/signature continuity and compatibility
acceptance remain 0.12.0 gates; ordering is not promoted into ordinary Release.

The dated sequence below preserves failed candidates, superseded remedies and
then-pending actions. The final implementation requires strict API/file agreement
in both directions after at most one event-driven settlement wait and read retry.
The old one-direction exception and five-second delay are no longer used.
Controlled tests ended in verified restoration; a later migrated receipt was
archived only with owner authorization to retain the current baseline. The
current accepted user configuration has a clean applied Undo receipt.

## Build identity and cross-host drag regression

The active application marketing version is `0.11.0`. `build-app.sh` allocates
each successful local app package a monotonically increasing positive
`CFBundleVersion` from ignored `LocalData/build-number.txt`, with an explicit
`BLENNY_BUILD_NUMBER` override for reproducible CI or archival builds. The main
window, status-item tooltip, Support page and Debug evidence display
`0.11.0 (Build N)`. The first verified sequence produced Builds 1, 2 and 3;
Build 3 was installed without launching it. This makes an on-disk replacement
distinguishable from a previously running process, which remains executable
from memory until terminated.

The owner-accepted 0.10 drag flow ran on macOS 27.0 build `26A5425a`. The new
host runs the formal macOS 27.0 build `26A428` on different Apple silicon.
Migration inspection found only the expected policy document and exact layout
bookmark, with management disabled and no draft or recovery receipt. Device
Control successfully populated the Board. The failure happened before payload
delivery or any ordering write: after a drag attempt, the process consumed about
54 percent CPU, repeatedly entered SwiftUI AttributeGraph updates around the
Board drag-source views and cycled drag-server connections. AppKit also reported
negative drag-preview geometry during the affected refresh. These observations
exclude ordering permission and migrated recovery state as direct causes, but
do not yet distinguish the OS runtime, SDK-compiled implementation, hardware or
the complete Blenny view hierarchy.

The tagged 0.10.0 source uses the macOS 27 typed `draggable` closure together
with a drag-preview content shape, `DragConfiguration`, a payload-bound view ID
and a Board-level drag-session observer. Stabilizing payload creation alone did
not remove the new-host loop. A public `NSItemProvider`/`onDrag` source candidate
is compiled, but it is not accepted as the root-cause fix before the regression
matrix is complete.

Two read-only comparison artifacts now exist under ignored
`LocalData/0.11.0-drag-regression-matrix/`: an exact export of tagged v0.10.0
built with the current formal Xcode 27, and a standalone DragSourceProbe with no
privacy permission or menu-bar access. The probe compares the original typed
closure, typed value, item-provider, DragConfiguration and drag-session-observer
variants. It must be exercised manually on the new host and, unchanged, on the
old host. The old host is not exposed through the current Codex host registry,
so remote comparison requires separately supplied SSH connectivity. No menu-bar
mutation is part of this matrix.

Apple's macOS 27 release notes document new SwiftUI drag-and-drop behavior and a
resolved incorrect `NSDraggingItem.draggingFrame` issue, but do not list the
observed AttributeGraph loop. The exact Apple-internal defect therefore remains
unproven; a minimized cross-build result is required before filing feedback or
assigning causality to the formal OS update.

The new-host standalone matrix subsequently delivered all six manual drops.
That includes the tagged 0.10 typed closure with drag-preview shape and
`DragConfiguration`, the typed value overload, both item-provider variants and
typed/provider sources inside a drag-session observer. The final target reported
six delivered drops and a completed data-transfer phase. This excludes a general
M6 or formal-26A428 failure in those public SwiftUI modifiers. The remaining
failure boundary is the complete Blenny Board/model interaction or a different
compiled implementation.

Read-only SSH inspection found that the old M1 iMac has also updated to macOS
27.0 build `26A428`; its Xcode is the earlier 27A5237l build. Its currently
running Blenny executable is the preserved
`drag-provider-loop-fix-candidate-20260922-1623`, not the tagged 0.10 closure
build. That process was idle, but its current unified-log interval contained no
drag-server session, so it does not prove a successful drag on the formal OS.
It also contained six negative-geometry messages, showing that message alone is
not sufficient to identify the new-host loop.

The old iMac executable is available byte-for-byte in migrated ignored evidence.
After stripping each code signature, the old artifact and the new-host diagnostic
package have the same SHA-256 and Mach-O UUID. It is installed on the new host as
the visibly identified local diagnostic `0.11.0 (Build 4)`; the changed ad-hoc
signature requires a fresh Device Control grant. The next manual step is drag
only, with no Apply. A success points to the newer formal-Xcode compilation or
later source; a failure leaves the full Board state or hardware-specific runtime
as the remaining distinction and requires an attended drag of the same binary on
the old iMac.

The canonical evidence, alternatives, permission matrix, experiment plan and
owner decisions for this milestone are recorded in
`PERMISSIONS_0.11.0_PHASE1_DRAFT.md`.

## Full-Board drag-start isolation (2026-09-23, in progress)

Builds 4, 5 and 6 all failed the new-host manual drag-start test. Build 4 used
exactly the preserved old-host Mach-O implementation; Build 5 used stable payload
registries and public item-provider sources; Build 6 suppressed drag-time hover
writes and floating names. These are failed hypotheses, not accepted fixes.
The six-source standalone probe passed all six delivered drops. Current old-host
manual drag success has not been re-established.

The Build 6 sample attributes sustained work to AttributeGraph updates and
`SystemBoardItem` evaluation. Static inspection finds no publication or token
creation in its prepared payload getters. Whole-model observation and forwarded
`DebugOrderingPresentation.objectWillChange` connect those views to Board-wide
state, but no recurring publication has yet been demonstrated. The preserved
recent Build 6 log does not repeat the Build 5 negative-geometry message. The
window disables restoration and sets its initial size explicitly; a migrated
saved window frame is not supported by the current window code.

Debug Build 7 provides one launch-selectable executable using
`BLENNY_DRAG_DIAGNOSTIC`:

- `baseline` retains the complete current Board.
- `application-sources-only` keeps system icons and their non-drag controls but
  skips their payload getter entirely and attaches no system drag-source modifier.
- `system-payload-only` evaluates the original system payload dependencies without
  attaching a system drag-source modifier, separating lookup from registration.

Application payloads, lane geometry and local draft delivery remain unchanged.
Named model and ordering-presentation publications, their first two synchronous
call stacks, forwarded object changes, interaction changes, provider requests and
native session phases are recorded to stderr only when a mode is selected.
Logging stops after 16 records per event or 600 overall and performs no polling.
No inventory or published values are logged. Reaching a log limit prevents an
absence-of-events conclusion beyond that limit. Diagnostics compile out of
ordinary Release; they add no permission, writer, Undo or recovery path.

Xcode 27.0 (`27A266a`) passes the Build 7 Debug package, strict ad-hoc signature,
616 Debug tests in 56 suites, actual interface-model lifecycle self-check and
ordinary Release compilation. The prior installed Build 6 is preserved under
ignored local evidence. Build 7 starts in `application-sources-only`; Device
Control and owner-operated drag validation are pending. No new menu-bar Apply,
Resume, Undo or recovery operation is part of this experiment. A reproducible
success/failure/success boundary remains required before claiming a fix.

The owner then reproduced failure in Build 7 `application-sources-only` with a
populated, stopped Board. Native callbacks reached initial/active and ended with
forbidden/cancel; no draft changed. CPU remained 59.2 percent and a two-second
sample still centered on `SystemBoardItem` / AttributeGraph. Removing system
source registration and its payload lookup therefore does not eliminate the loop.
The policy/bookmark/receipt file map remained byte-identical. Named publications
were quiet in the retained drag interval except that object-change and native
placement counters had already reached their limits; those capped counters cannot
exclude an ongoing publication loop.

Build 8 adds launch-selectable diagnostic reductions: `no-focus` removes focus
registration; `snapshot-system-items` replaces system cells with immutable plain
icon leaves (also omitting their extra interactions, so it is not a pure
observation-only contrast); `no-view-extras` does that for application cells too;
`simple-lane` uses fixed icon cells and direct local-draft delivery;
`minimal-session` retains lane layout but uses direct typed-data delivery without
Board/session drop configuration. `BLENNY_DRAG_SOURCE=typed` selects the
Identifiable source overload for applications and plain diagnostic leaves; the
default provider path is retained for comparison. Current SDK signatures expose
item identity on this typed overload, whereas provider registration does not
explicitly supply that ID. Missing native metadata is a separate hypothesis for
forbidden drops and needs measured identity counts, not a relaxed production
delivery guard. No safety guard in the real draft model or writer is removed.
The diagnostic title identifies mode and source family. Build 8 strict signature,
interface-model self-check, 616 Debug tests and ordinary Release compilation
pass. The preceding diagnostic revision also passed 324 Release tests in 34
suites. Manual `no-focus` / typed validation remains pending at the Device Control
handoff. No signature changes are needed to switch the remaining modes.

Ignored evidence includes a compilable public-only synthetic Board reduction
harness and an unsubmitted Feedback draft. The harness has not been manually
confirmed to reproduce the loop and must not be described as a proven minimal
reproducer. The current result is an eliminated hypothesis, not a root cause or
accepted repair.

### Build 8 owner success and remaining CPU loop

The owner reports successful dragging and Apply in `no-focus` with typed
application sources. The native log independently records one payload ID in both
Board and lane callbacks, two sessions ending with `move`, and completed data
transfer. The owner-reported Apply is recorded as an observed product result;
this investigation did not initiate Apply or independently audit its receipt.

This contrast changes two factors: it removes `.focusable()`,
`.focusEffectDisabled()` and `.focused(...)` from application/system cells, and
uses the Identifiable typed application-source overload instead of item-provider
registration. It therefore establishes a working drag combination, not which
factor is necessary. The prior provider destination rejects absent typed session
identity; the new log verifies that identity is present, but a provider identity
count comparison is still needed to establish the exact rejection mechanism.

After the successful report, read-only process inspection still measured about
62 percent CPU. A fresh two-second sample remains dominated by AttributeGraph
and `SystemBoardItem` evaluation. Successful dragging does not establish that the
persistent graph-update loop is fixed. No success/failure/success isolation has
been completed, and focus removal alone is not an established root cause.
Further tests should retain the same Build 8 signature and vary one factor at a
time. Do not undo the owner's newly applied state as part of drag diagnostics.

On 2026-09-24 the owner quit Blenny completely. With no Blenny process,
whole-system CPU idle was 88–89 percent in two subsequent samples; WindowServer
remained around 43 percent of one core. The owner reopened installed Build 8
without a diagnostic mode. Accessibility confirmed `Management stopped` and a
populated Board. Before any Resume or new drag, Blenny rose from an initially
low reading to 44–60 percent of one core and whole-system idle fell to 75–79
percent in consecutive `top` intervals. A fresh two-second sample again showed
AttributeGraph updates, now prominently `ApplicationBoardItem.body` and its
ordering-state presentation. This reproduces the sustained Board CPU loop in a
stopped, freshly opened process, independent of a new drag attempt or Resume.
The no-focus/typed combination previously delivered drops, but did not make the
Board idle. The exact publication or geometry cause remains unisolated.

Further Build 8 idle trials show that onset is intermittent. A single clean
`snapshot-system-items` run stayed near zero CPU for over 72 seconds, and
`application-sources-only` and `system-payload-only` runs stayed near zero for
over 90 seconds. Another `baseline` run rose to about 59 percent only after
roughly 53 seconds, while later clean baseline and ordinary launches remained
near zero for over 100 seconds. One two-process launch was discarded as
confounded. These observations do not establish a mode-level causal boundary.
A 45-second owner hover interval had at most 2.7 percent process CPU, but the
owner action was not time-confirmed against that recording, so hover remains
unresolved.

In a later single-process Build 8 run, `application-sources-only` combined with
a typed application source rose to about 58–61 percent before any new drag.
Its five-second sample again concentrated in `SystemBoardItem` and
AttributeGraph despite the absence of a system drag-source modifier and
payload lookup. The `nativeOverflowPlacementAvailable` publisher also emitted
repeatedly at startup even when its Boolean value may have been unchanged;
the bounded diagnostic log reached its per-event limit. That publication is a
possible invalidation source, not yet a proven cause of the sustained loop.

Debug Build 9 adds a reversible contrast at that exact publication boundary.
By default, `ProductInterfaceModel` publishes native overflow availability only
when the derived Boolean changes. `BLENNY_DRAG_OVERFLOW_PUBLISH=always` restores
the prior unconditional assignment in Debug, and the diagnostic window title
shows the selected behavior. This does not alter the native observer, menu-bar
writer, policy or recovery paths. Xcode 27.0/macOS 27 SDK compilation and all
616 Debug tests in 56 suites and ordinary Release compilation pass. The new
ad-hoc identity initially lacked Device Control, so its access-gated low CPU
was discarded as a comparison. The owner then restored Device Control. The
same installed Build 9 produced a
changed → always → changed comparison with a populated Board and Management
stopped throughout. The first changed run stayed near idle for about two
minutes (99 one-second `top` samples: 0.11 percent mean, 10.6 percent brief
peak). The always run sustained about 58 percent mean across 62 samples and
reached 69.4 percent. The repeated changed run stayed near idle for over a
minute (62 samples: 0.01 percent mean, 0.2 percent peak). In the always run,
the bounded session trace recorded 497 `AXLayoutChanged` callbacks within its
first 18.6 seconds, each reporting the same unavailable native overflow
presentation; the first changed run recorded 14 such callbacks across over
124 seconds, and the repeated changed run recorded seven across its first
minute. The always-mode high-CPU sample again centered on Board cell body
evaluation under AttributeGraph. This success/failure/success contrast locates
the idle CPU feedback loop at unconditional publication of an unchanged derived
overflow Boolean: the publication invalidates the whole observed Board, its
layout produces more MenuBarAgent accessibility layout notifications, and each
notification publishes again. The equality guard breaks this observed loop.
The same feedback loop did not account for failed drag delivery, as the next
single-factor drag contrast shows.

The owner subsequently retried application dragging in Build 9 `baseline` /
provider / changed-overflow mode and reported that it still could not drag.
The native log confirms two provider requests and two native sessions. Both
Board and lane callbacks reported zero `PolicyDragPayload.ID` values throughout
the first active session. The lane ended with `forbidden` and the Board with
`cancel`; no drop changed the local draft. This separates drag delivery from
the now-fixed idle CPU loop. Static code inspection shows that the Board and
lane require exactly one typed drag identity before they can validate a local
move, while the application source's `.onDrag` item-provider overload does not
supply that identity in this observed runtime. The owner then successfully
dragged under the same installed Build 9 with only
`BLENNY_DRAG_SOURCE=typed` changed. Native Board and lane callbacks each
reported one `PolicyDragPayload.ID`; transfer completed and both sessions
ended with `move`. The interface showed the reordered local draft and
"Changes not applied" with Apply available. Post-drop process CPU returned
near zero. This establishes a same-build provider failure / typed success
boundary while retaining focus and full Board layout. The earlier Build 8
`no-focus`/typed success is consistent with it; focus removal is not required.

Build 10 makes the typed application drag source the ordinary Debug and Release
path while retaining an explicit Debug-only provider switch for regression
comparison. It also retains the overflow publication equality guard. Xcode 27
compilation, 616 Debug tests in 56 suites, ordinary Release compilation and
`git diff --check` pass. The owner restored Device Control for installed Build
10 on 2026-09-25. Accessibility confirms the full Board with Management
stopped and the default `baseline` / typed / changed-overflow configuration.
Across 120 one-second idle CPU samples, Blenny averaged 0.21 percent and
peaked at 2.4 percent. The owner then manually dragged an application icon in
Build 10. Board and lane each observed one typed drag identity; the lane
completed data transfer, both native sessions ended with `move`, and the
interface displayed a reordered local draft with "Changes not applied" and
Apply available. Twenty one-second post-drop samples averaged 0.005 percent
CPU and peaked at 0.1 percent. The owner did not authorize Apply or Resume,
and this investigation did not invoke either. The installed Build 10 bundle
passes strict signature verification. This verifies application drag-start
and local draft delivery on the new host with full Board and focus retained.
It does not claim that a physical menu-bar ordering write was tested in this
build.


## Authorized implementation slice

The first slice improves only the Device Control onboarding path:

- keep the public `AXIsProcessTrustedWithOptions` request;
- suppress repeated prompt requests only for the current process lifetime;
- allow a fresh request after reopening or replacing the app;
- make a second setup action open the existing System Settings destination;
- refresh once after a safe untrusted-to-trusted transition;
- use the macOS 27 Device Control and Data Access label in user-facing copy.

That first slice does not itself grant access, add an app to System Settings,
alter TCC, launch or replace the installed app, change menu-bar state, add
sorting to Release, or change a data-access backend. The later exact-file slice
below remains Debug/optimized-trial-only.

## Owner-verified Device Control result

On 2026-09-19 the owner verified a fresh Device Control request on macOS 27:
when Blenny was absent from Device Control and Data Access, the public AX request
added its row in the off state. Enabling that switch granted access successfully.
Manual Remove/Add is therefore not part of the normal first-use flow. Update and
signature-transition continuity remain separate acceptance cases.

## App Data registration problem

The owner also verified that Blenny's ordering guidance opens Files & Folders,
but Blenny is absent from that page. Opening the page does not register an app.
The current button therefore cannot complete authorization from this state.

macOS 27 release notes state that access to another team's app data container or
app group container no longer prompts. Access is denied by default and managed
in Privacy & Security (161835690). The inspected Files & Folders resources say
that apps which requested file, folder or other app-data access appear there;
unlike Accessibility and Full Disk Access service definitions, the combined
App Data presentation does not expose a normal add/delete action. There is no
public application API for creating or enabling its TCC record.

Blenny already made a bounded read attempt against the protected
`com.apple.MenuBar` group file before exposing the button. Repeating that read or
adding a usage string cannot be claimed to create the missing row on macOS 27.
The Debug/ordering-trial package adds `NSAppDataUsageDescription` so that exact
candidate accurately declares why it accesses other app data; ordinary Release
removes it. The key is explanatory metadata, not an authorization API.

The leading unresolved variable is code identity. The tested bundle is ad-hoc
signed, has no TeamIdentifier and has a CDHash-bound designated requirement.
Apple DTS has separately documented that ad-hoc “Sign to Run Locally” builds can
cause TCC registration problems. This is strong diagnostic evidence, not proof
that signing alone will create the macOS 27 App Data row.

Because no stable Apple signing identity is currently available, the owner chose
the public `NSOpenPanel` route for the next experiment. An isolated ad-hoc probe
demonstrated that selecting the exact
`com.apple.MenuBar/Library/Preferences/com.apple.MenuBar.plist` changed its
direct read from `EPERM` to success. A security-scoped bookmark survived a
same-binary reopen and one same-path/same-bundle-ID rebuild with a changed CDHash.
While that scope was active, `_CFPreferencesCopyValueWithContainer` returned the
same 55-entry table as the bounded file read. No preference was written.

The Debug and optimized ordering builds now expose **Choose Layout File…** on
the existing data-access failure. They validate only the exact canonical file,
store the bookmark in the private DebugOrdering directory, restore its scope on
launch and retry the read after a successful selection. The bookmark store uses
0700/0600 modes, no-follow descriptor checks, atomic replacement, fsync and
readback verification. Debug and optimized ordering trial packages carry
`com.apple.security.files.user-selected.read-write` and the App Data purpose
string. Ordinary Release carries neither the picker code, the entitlement nor
the purpose string.

The initial Xcode 27 verification passed 597 tests in 56 suites. Debug, optimized ordering
trial and ordinary Release app bundles all built and passed strict code-signature
verification. This does not authorize or establish private setter behavior,
physical ordering, Undo, interrupted recovery, revocation/regrant, file
replacement or Developer ID/Sparkle update continuity.

## First optimized-trial preflight

On 2026-09-19 the owner authorized the prepared Snipaste/CleanShot X write and
inverse packet. The frozen optimized trial executable had bundle ID
`xyz.fi5h.blenny`, ad-hoc CDHash
`ce70edffb27cbeb835d939321293a1fff0ec8d14` and SHA-256
`34e943a7c8998e50a73bd5b55126cd474a42d4f3f84a85b9de5408b3d6f00f5a`.
The candidate did not become AX trusted after a Remove/Add attempt while it was
outside `/Applications`; this does not establish whether path, the selected copy
or stale ad-hoc identity caused that attempt to miss. The owner then placed that
exact executable at `/Applications/Blenny.app`, selected that copy in System
Settings and granted it. A clean reopen was trusted and the app remained in the
stopped management state. This is evidence for validating the exact installed
copy, not evidence that every future update must Remove/Add.

The owner selected the exact `com.apple.MenuBar.plist`. The production bookmark
store created a private 0600 bookmark and the Board refreshed from the protected
layout data without an FDA action in this flow; pre-existing TCC state was not
reset or inferred. The first read-only boundary
export was rejected because both Blenny control frames moved 16 points during
the 1.364-second capture. A second 1.707-second export had unchanged
policy/lifecycle state and identical control frames at both endpoints.

That valid export recorded overlapping observed frames: Snipaste exposed one
complete AX item at `(x: 379, width: 24)` and CleanShot X one at
`(x: 375, width: 36)`. An initial review incorrectly treated the legacy
`OrderingIdentityResolver` `geometryAmbiguous` reason as a Board write blocker
and paused before preview or Apply. The 0.10.0 configuration-first contract and
tests explicitly say otherwise: AX geometry is excluded from configuration
eligibility, overlapping proxy frames remain eligible, and automatic physical
verification may be `unavailable` while exact configuration readback and Undo
remain verifiable. Both live targets have one stable process, one complete
current-user owner namespace, one exact key and no token collision, so the
current Board path considers them eligible. The targeted 12-test
`OrderingConfigurationModelTests` suite passed on Xcode 27 after this review.
No write occurred during the mistaken pause; the same authorized packet may
continue with owner-observed physical verification. Raw snapshots and the
preflight backup remain only in ignored
`LocalData/0.11.0-live-ordering-20260919-211457/`.

After the no-write stop, the optimized trial quit normally and reopened from
`/Applications/Blenny.app`. It remained stopped, restored the saved exact-file
scope without another picker, populated the Board from the layout data and kept
the active ordering receipt absent. This passes product-path bookmark persistence
for that same installed executable; it does not cover replacement, revocation or
a future signed/Sparkle update.

## First optimized-trial write and recovery

The owner then used the same installed candidate and grant for one approved
Snipaste/CleanShot X exchange. Both targets were in Hidden, so this was a
configuration/readback experiment rather than valid visual acceptance. Resume
was neither required nor used; management remained stopped.

Apply wrote the reviewed exchanged values but its immediate independent capture
failed because the private container-preference API and the protected plist did
not yet expose the same generation. The durable schema-4 receipt remained at
`applyIntent`. A later explicit Recover capture established the applied endpoint,
recorded `restoreIntent` and issued exactly one inverse. Its immediate capture
encountered the same transient disagreement, so the receipt was retained and no
automatic retry occurred.

A separate read-only diagnostic subsequently found both complete 55-entry tables
identical and both target values at their original typed values: Snipaste
`1097.5` and CleanShot X `1135.5`. A second explicit Recover inspected that
already-restored endpoint, performed no system write, archived
`ordering-last-restored.json` and removed the active receipt. The final record is
`preferencesRestored`, `configurationVerified = true`, with physical verification
`unavailable`. This proves the exact-file route covered this write and inverse on
the tested identity. It does not establish visible movement because Hidden items
cannot provide that observation.

The first implementation fix therefore permitted one delayed repeat of the full
corroborated read only for the API/file-disagreement error. Its 750-ms delay was
subsequently shown to be insufficient by the visible-pair trial below. The system
write is never repeated and all other errors still fail immediately.

After successful ordering recovery, the app also attempted to update a separate
accepted fallback-control placement from 2026-09-15. That follow-up refused its
current identity and left its `applied` receipt and both Blenny values unchanged.
It did not invalidate ordering Undo. Source now skips this automatic fallback
follow-up when the exact AppKit fallback identity is unavailable; manual control
placement remains a separate operation and experiment.

## Visible-pair write, recovery and corrected scope

On 2026-09-20 the owner authorized a second packet using visible Lark Helper and
ChatGPT targets. The frozen installed candidate was still
`/Applications/Blenny.app`, bundle ID `xyz.fi5h.blenny`, executable SHA-256
`5f6c50bc161b148091c062a996c9cff37987f566c661e29faf3c549e01bda202` and ad-hoc
CDHash `b813f6b5ccdaf7165c5ac2ef9448fc0f0cf5dd5e`. Management remained stopped and
the saved exact-file scope supplied the complete 55-entry table.

The owner observed Lark Helper and ChatGPT exchange physically after Apply.
Readback nevertheless retained `applyIntent` with the same API/file-disagreement
error. A read-only diff then found four configuration deltas rather than the two
reviewed targets: Lark Helper and ChatGPT were exchanged as requested, while
Alfred and Tailscale were also exchanged. The planner had supplied every globally
eligible subject to a pure same-area ordering plan. That made the plan normalize
unrelated cross-area values even though their Board order and policies had not
changed.

One explicit Recover restored all four values. Its ordering receipt was archived
as `preferencesRestored` with `configurationVerified = true`. The accepted
fallback-control follow-up then changed only Blenny's fish key, but its immediate
readback hit the same disagreement and retained a separate receipt. The owner
used **Undo Control Placement** once and observed only the fish and ChatGPT change
relative position. Final read-only verification found the complete 55-entry
configuration semantically equal to the pre-Apply baseline, both API and file
sources equal, and both active receipts absent. Binary plist bytes differed after
serialization, so acceptance is based on the decoded typed table rather than a
file digest.

Source now narrows a pure same-area order to subjects participating in a
pairwise relative-order inversion. Any visibility-policy change retains the
complete Hidden-to-Revealable-to-Visible partition target. Deterministic tests
cover both cases. This keeps unrelated areas out of a pure pair exchange without
weakening the existing global partition contract.

The same trial also proves 750 ms is not a sufficient settlement bound on this
host. Source now retains exactly one complete corroborated-read retry but waits
five seconds before it. It does not poll and does not repeat a system write. This
five-second value and the narrowed two-subject plan were included in the
corrected live candidate below. The evidence cannot distinguish a successful
first read from use of the one delayed retry because that branch is not logged.

## Corrected visible-pair acceptance

The corrected optimized candidate was installed at `/Applications/Blenny.app`
with executable SHA-256
`f560c4f84ed5879ef907b70cc11b5875f4dccd4babfe55519dd6494a08d86a48` and ad-hoc
CDHash `210b10f3b984a70c45f2f9d284ba746541892c7a`. The previous installed bundle was
preserved under ignored `LocalData/`. The changed identity required the owner to
enable Device Control again. The existing exact-file bookmark restored without
another picker; management remained stopped and no recovery receipt was active.

A fresh coherent boundary recorded a complete 55-entry table equal to the prior
restored baseline. The Board draft inverted only visible Lark Helper and ChatGPT.
The prepared schema-4 plan and successful receipt contained exactly those two
keys: Lark `649.5 -> 683.5` and ChatGPT `683.5 -> 649.5`. No Alfred, Tailscale or
Blenny control key changed. The owner observed the two targets exchange relative
order with the fish remaining between them. Apply completed without an
API/file-disagreement error; the receipt was `applied` and
`configurationVerified = true`.

The owner then used **Undo Changes** once. The two targets returned to their
original relative order without an error. The complete typed table had zero
differences from the fresh baseline, the active ordering and fallback receipts
were absent, and `ordering-last-restored.json` recorded `preferencesRestored`
with `configurationVerified = true`. Physical verification remained
`unavailable`, so the owner's observation is the physical result; exact
configuration and recovery are independently verified.

An accidental **Undo Control Placement** between Apply and ordering Undo had no
fallback receipt to consume and made no configuration change. Its ordering-card
status text remained at **Restoring control positions…** after the no-op even
though controls were re-enabled. This is a presentation defect for later cleanup,
not an unfinished operation or recovery failure.

After the clean Undo, the owner quit and reopened the same installed candidate.
Device Control did not require another switch action, the exact-file bookmark
restored without another picker, and the Board loaded normally. The new process
kept management stopped, both active recovery receipts absent, and the complete
55-entry typed table equal to the fresh pre-Apply baseline. This passes same-binary
reopen after a clean Apply/Undo; it does not cover revoke/regrant or a future
Developer ID/Sparkle identity transition.

## Post-reopen unsupported-order finding

A later ordinary Board drag was rejected before intent or write with the generic
**The menu bar changed** presentation. Read-only inspection showed that the
underlying condition was not a changed menu bar or lost authorization. The draft
changed the relative order of at least one application marked `needsMapping`.
Several current applications had attributable group-table keys but remained
configuration-ineligible because their owner-preference evidence was incomplete
or used an unsupported namespace; one current inventory item also had no verified
mapping. Moving an otherwise eligible item across one of these fixed subjects has
the same effect because it reverses their pairwise order.

This established an important limit on the exact-file result at that point:
selecting the menu bar layout plist was sufficient for targets such as the
accepted Lark/ChatGPT pair, but that implementation still required independent
owner-preference evidence for each application target. Exact-file access alone
therefore does not provide arbitrary application ordering. No receipt was created
by the refusal and no system value was written.

This is an authorization-scope regression relative to the owner's 0.10 trial,
not a new 0.11 eligibility restriction. `v0.10.0` and the current worktree use
the same configuration resolver requirements. Preserved 0.10 evidence records
Dato, RunCat Neo and Coffee Buzz as `sandboxContainer` owners with complete source
identity and preferences, and a configuration-verified receipt changed their
exact keys. Under the current exact-layout-file grant, those same owners are
captured as `sandboxed`, incomplete and without a source identity even though the
group-table keys still exist. The old broad App Data / Full Disk Access context
therefore supplied evidence that the selected-file bookmark does not supply.
Lark Helper and ChatGPT remain eligible because their current owner preference
capture uses the accessible `currentUserAnyHost` namespace.

The earlier statement that exact-file selection proves the minimum for Debug
ordering must consequently be read as **minimum for already eligible owners**,
not minimum for the 0.10 ordering coverage. Restoring that coverage requires
either broad App Data access, multiple owner-container grants, or a narrower
identity contract that does not make owner-container preferences mandatory when
an exact group key is independently bound to one signed bundle owner.

The source now distinguishes this condition from a stale snapshot and names the
`No sort` items in the user-facing failure. The misleading Debug-only
`link.badge.plus` marker is replaced by a neutral minus marker with an explicit
visibility-only explanation. Actual process, table, display or lifecycle drift
continues to use the discard-and-refresh message. Xcode 27 still passes 600 Debug
tests in 56 suites after this presentation/error-classification correction. The
running installed candidate has not been replaced, so live acceptance of the new
copy remains pending.

## Exact bundle code-identity replacement

The owner then authorized implementation of the narrower identity contract.
The Debug/optimized backend now obtains public Security.framework evidence for
each candidate process: strict running-code validity, signing identifier, Team
ID when present, and a SHA-256 digest of the public designated-requirement text.
It admits this route only when the signing identifier equals the process bundle
ID, at least one current `status:<bundle ID>::...` key anchors that owner, every
associated bundle/executable token resolves uniquely to the same process, the
process lifetime remains stable, and the existing whole-owner key group remains
bounded. An executable-name key without an exact bundle anchor is still refused.

When that route is available, capture does not read the owner's preference
container. The signing evidence is bound into the snapshot, reviewed plan and
recovery receipt. Freshness, post-write verification and Undo require the same
identity. A signing-identity change refuses the next write or recovery before a
system mutation. Full-table corroborated readback, serial writing, durable intent,
single inverse and unrelated-value preservation are unchanged.

Static host evidence supports the intended first live targets. Dato, RunCat Neo
and Coffee Buzz have exact bundle-token keys plus strictly valid Team-signed
designated requirements. The current Usage4Claude table has both an exact
`xyz.fi5h.Usage4Claude` anchor and one unique legacy executable-name sibling, so
the implementation groups both keys under the exact anchor. Its current local
build is ad-hoc; a replacement can change its designated requirement and must be
treated as identity drift rather than silently inheriting a retained receipt.
This inspection did not launch, replace or mutate any target.

Xcode 27 deterministic verification now passes 605 Debug tests in 56 suites and
322 ordinary Release tests in 34 suites. The new tests cover exact-key admission
without owner preferences, executable-only refusal, unique alias grouping,
Apply/Undo and pre-write refusal after code-identity drift. Fresh Debug, optimized
trial and ordinary Release bundles under ignored `LocalData/` pass strict code
signature checks. Debug/trial contain the ordering backend and selected-file
entitlement; ordinary Release contains neither the entitlement, App Data purpose
string nor ordering-backend symbols. The installed `/Applications/Blenny.app`
remains the previous accepted candidate. The frozen optimized trial has executable
SHA-256 `a51d3ae8c3cb5b7c4931cb969574a7792d6f233de13472b1382a3be3ceb20721`
and ad-hoc CDHash `41edd7a22e49331e39cd85100a91d1fc319f654c`.
Real capture, arbitrary sorting and Undo with the new code-identity route remain
pending the prepared owner-approved packet.

Before the exact-bundle replacement, the scope and five-second-settle changes
passed 600 Debug tests in 56 suites and 322 ordinary Release tests in 34 suites. Fresh
Debug, optimized ordering-trial and ordinary Release bundles were created under ignored
`LocalData/` and passed strict signature verification. Debug/trial carry only
`com.apple.security.files.user-selected.read-write` plus the App Data purpose
string; ordinary Release carries neither and contains no ordering/picker symbols.
The optimized trial was copied to `/Applications` only after preserving the old
bundle and was launched for the corrected acceptance above. Debug and ordinary
Release were not launched.

`scripts/build-app.sh` now accepts an optional `BLENNY_CODE_SIGN_IDENTITY` for
that later owner-authorized test. Its default remains `-` (ad-hoc), so ordinary
local builds retain their existing behavior. The script does not enumerate a
keychain, select an identity, embed signing material, notarize, install or launch
the result. A non-ad-hoc build must be directed to `LocalData/` and its exact
identity, bundle hash, path and test steps reviewed before use.
# macOS 27 public-build transition (2026-09-21)

An owner-operated configuration Apply succeeded on macOS 27 build `26A5425a`
at 2026-09-21 10:48 local time. Its clean schema-4 receipt records nine changed
application keys and remains in the `applied` phase. After the host restarted,
the running OS was macOS 27.0 build `26A428`. The installed trial still admitted
only `26A5416b` / `26A5425a` for visibility management and only `26A5425a` for
ordering. `Resume` therefore failed at the assessment-runtime build gate and
ordering Undo failed at the ordering-runtime build gate. The selected-file
bookmark remained present, so this failure is not evidence that App Data access
was revoked.

A read-only `26A428` probe confirmed the exact assessment classes, selectors and
method encodings, the configuration getter round trip, the private
`NSUserDefaults` container initializer encoding, and both required container
preference symbols. The existing read-only Control Center ABI getter probe also
completed on `26A428`. The Debug/ordering trial now admits `26A428`, records the
actual admitted build in every new ordering snapshot, and compares a write-time
snapshot with the current build. Snapshot validation retains `26A5425a` so a
clean receipt can be decoded and reviewed after the update. Deterministic
coverage exercises configuration Undo from a `26A5425a` receipt against a
`26A428` current snapshot.

This static and deterministic evidence does not establish live assertion
activation, a real corroborated layout capture, or cross-build Undo on the host.
The existing receipt must remain untouched until a replacement installed build
passes read-only startup/capture checks and the owner authorizes the one inverse.
Control Center ordering remains deferred; its pinned system-binary UUIDs changed
on `26A428` and were deliberately not expanded.

The replacement then passed the read-only `26A428` capture preflight. Its exact
layout-file bookmark restored, the Board loaded 22 applications, the 55-entry
table matched all 25 committed receipt values, and management remained stopped.
The ad-hoc replacement exposed a separate Device Control identity result: the
old System Settings row remained on, but `tccd` logged `Failed to match existing
code requirement`. Switching that row off and on was insufficient. Removing the
old row, adding the current `/Applications/Blenny.app`, and enabling it made the
grant effective without restarting Blenny. This is direct evidence for the
current ad-hoc development transition only; stable Developer ID/Sparkle identity
continuity remains untested.

The one authorized cross-build **Undo Changes** attempt stopped before any plist
or recovery-record write with `The session changed during ordering`. The frozen
plist and receipt hashes remained unchanged, all nine changed keys still held
their committed values, and every unrelated key remained equal. The failure was
not a permission or build gate: the combined Apply receipt contained a visibility
Undo whose `after` policy had management enabled, while the later explicit Stop
had preserved those assignments and changed only `managementEnabled` to false.
The inverse path required the complete enabled document and therefore rejected a
valid stopped state.

Unified Undo now derives both its expected current policy and restore target
while preserving the current management state. An active Undo stays active; an
Undo after Stop restores the prior assignments and exact ordering while leaving
the writer inactive and performing no visibility transition. The original
receipt, identity, complete-table, serial-writer and one-attempt guards remain in
place. A dedicated Apply -> Stop -> Undo test and a policy-preview test cover the
regression.

The second owner-authorized attempt used that candidate after a normal quit,
replacement, changed-CDHash Device Control regrant and read-only preflight. It
also refused before mutation with the same message. The receipt, policy and
complete 55-entry table remained byte-for-byte equal to the preflight evidence.
This exposed a distinct restart boundary: stopped startup deliberately creates
no writer, so explicit recovery created a fresh inactive coordinator whose
internal `stopped` flag was false even though it had no active plan and the
persisted policy was stopped. The first fix covered same-process Stop but treated
this safe reopened state as changed context.

Recovery now accepts either a same-process stopped coordinator or a freshly
reopened inactive coordinator only when the persisted policy is stopped and the
coordinator has no active plan. It still requires the exact expected policy,
prepared inverse, full configuration identity and table values. No visibility
transition is performed. A separate Apply -> Stop -> reopen -> Undo regression
test covers this path. The full suites pass with 610 Debug tests in 56 suites and
323 ordinary Release tests in 34 suites. The next ignored optimized candidate
has executable SHA-256
`bcf0fac78736765656ef7fbdb0d968b11e646fbc9792dfd29d65661fa4f5ab7d`
and ad-hoc CDHash `f4e9d905f8340c117fd25b779b1ee33c33648648`.
A third live inverse requires installing that exact candidate, another read-only
preflight and fresh owner authorization; no failed attempt is retried
automatically.

### Third cross-build inverse and system-host recovery identity

The third owner-authorized **Undo Changes** used the exact candidate above after
a normal quit, replacement, Device Control remove/add regrant and read-only
preflight. Before the action, management was stopped; the schema-4 receipt was a
clean `applied` record; all 25 controlled values matched; the complete table had
55 entries; and the receipt, policy and plist SHA-256 digests were respectively
`e97202cf244ab6b664667272c511f695cd88f87e22f62b29167dd8f571dcf71d`,
`d93d3371183baeb9049cc0f7d05fb0264b725708ae60d3893b3f8d76d55a96de`
and `8d7122a1fe7c7082eec914a86ae7001de08001bb758f35c10db5bd0f4b3c000c`.

Undo durably recorded its policy-restore intent, then refused before either
inverse mutation with `An ordering key now conflicts with another application`.
The policy and complete configuration table remained byte-for-byte unchanged;
16 controlled keys were already at their original values and the same nine keys
remained at their committed values. The active receipt remained `applied`, with
`undoPolicyRestoreIntent = true`, `policyPersistenceCommitted = true` and no
pending configuration values. Evidence is under ignored
`LocalData/0.11.0-26A428-build/third-undo-recovery-needed-20260922-083531/`.

The refusal came from recovery identity validation comparing the complete
recorded `OrderingSystemHostBinding`, including PID and launch time. A host reboot
necessarily replaced the otherwise verified Control Center and SystemUIServer
process lifetimes. Recovery now permits that lifetime change only when the exact
system item and configuration key still resolve to one current system host, both
the recorded and current bindings are code-identity verified, the host bundle
and executable are unchanged, and the current inventory contains exactly that
verified host. Missing mappings, collisions and code-identity failures still
refuse. Fresh Apply review remains stricter and still rejects a system-host
relaunch until the user reviews a fresh snapshot.

The new recovery regression and the unchanged fresh-review refusal pass with the
full Xcode 27 suites: 611 Debug tests in 56 suites and 323 ordinary Release tests
in 34 suites. The new ignored optimized candidate is
`LocalData/0.11.0-26A428-build/system-host-recovery-fix-20260922-0846/Blenny.app`.
Its executable SHA-256 is
`6b4dfa8b02df110312aa58bc2d6e1b2ec2d932b88290818551086fb44ea8a888`, its
ad-hoc CDHash is `b31d0fe975750b097bdd42585e333653ebde174b`, strict signature
verification passes, and its only entitlement remains
`com.apple.security.files.user-selected.read-write`. The next live action is one
explicit **Recover Changes** after installation and a read-only preflight. It is
not another Undo attempt and must not be retried automatically.

### Current-build private-writer gate and bounded retry

The exact candidate above passed another read-only preflight after the owner
replaced its changed-CDHash Device Control row. The policy remained stopped, the
saved exact-file bookmark restored, the complete 55-entry table was byte-for-byte
equal to the preserved preinstall copy, and all 25 controlled values remained
16 original plus nine committed. One owner-authorized **Recover Changes** then
refused with `The private group-defaults write failed or raised an exception`.
The protected plist and policy remained byte-for-byte unchanged. The receipt
advanced to `restoreIntent`, retained all 25 original values as pending, and has
SHA-256 `fd7ceaaa48b49bfd161f904e89c765fe5b0cbaa50a2431a8b42ef01f64a8a7ef`.
Evidence is under ignored
`LocalData/0.11.0-26A428-build/recover-attempt-20260922-0936/`.

This refusal was a duplicated build gate, not a TCC or selected-file denial.
Swift capture and runtime validation admitted `26A428`, but
`MenuBarOrderingDefaults.m` still admitted only `26A5425a` and rejected before
constructing the private container defaults object.

Recovery also now persists a `configurationRestoreRetryCount`. A later explicit
Recover may retry only when a complete fresh capture proves every controlled
value still equals the committed pre-inverse table and the pending values are
the exact recorded original table. The counter is set before the retry. If that
retry fails, a third write is refused even when no value changed. No write is
retried inside one action. Tests cover both successful zero-change retry and the
terminal second failure.

Full Xcode 27 verification passes with 614 Debug tests in 56 suites and 323
ordinary Release tests in 34 suites. The next ignored optimized candidate is
`LocalData/0.11.0-26A428-build/write-gate-bounded-retry-20260922-0949/Blenny.app`.
Its executable SHA-256 is
`d7f63f24dff07b0673d362bd7b995bb7f69a38a37523f5f3a4ce131c5a2e68db`, its
ad-hoc CDHash is `44e1bd3b22dacd0c78ee936ee468661bbeb104e0`, strict signature
verification passes, and its only entitlement remains
`com.apple.security.files.user-selected.read-write`. Installation, read-only
verification and the one remaining retry require a separate owner-attended step.

The owner then selected a macOS-major compatibility policy for the formal macOS
27 release. Visibility, system-item trial, control-position diagnostics and the
ordering writer now admit the complete macOS 27 major instead of enumerating
individual build numbers. Live ordering snapshots still record the complete
build and a fresh Apply requires the write-time build to equal the reviewed
snapshot. Every write still checks arm64, the private initializer encoding, both
private container-read symbols, exact configuration structure, process/code
identity, policy/lifecycle/display context and complete API/file agreement.
Changing any of those contracts still fails closed.

Stored snapshots validate the Darwin/build major used by macOS 27 (`26`) so
existing `26A…` recovery receipts remain decodable and later `26B…`/`26C…`
updates can enter the same live contract checks. The Objective-C shim checks
`ProductVersion` major 27. Deterministic tests admit representative `27`,
`27.0`, `27.4.1` and `26A`/`26B` build forms while rejecting macOS 26/28,
Darwin/build majors 25/27 and malformed values.

The macOS-major policy passes 614 Debug tests in 56 suites and 323 ordinary
Release tests in 34 suites. The compiled ignored optimized candidate is
`LocalData/0.11.0-26A428-build/macos27-major-gate-20260922-1007/Blenny.app`.
Its executable SHA-256 is
`b209ff6fb8edfd1167b7fd526d8dc1d8671908841b13751924834f29d913a60f`, its
ad-hoc CDHash is `3dcc1c9ed3b80f30566d038dcd622ba2cff337eb`, strict signature
verification passes, and its only entitlement remains
`com.apple.security.files.user-selected.read-write`. It was installed only after
the prior bundle, active `restoreIntent` receipt, policy stores, bookmark and
protected plist were preserved under ignored
`LocalData/0.11.0-26A428-build/pre-macos27-major-install-20260922-1012/`.
Its changed ad-hoc identity requires a new Device Control remove/add grant before
read-only recovery preflight. The owner completed that exact grant without
restarting the process. The resulting preflight proved that the installed
executable digest and CDHash were exact, management remained stopped, the
`restoreIntent` receipt still had no retry count, the policy and protected plist
digests were unchanged, the complete table still contained 55 entries, and its
25 controlled keys were 16 original plus nine committed with no unknown value.

One separately authorized **Recover Changes** then completed the persisted
zero-change retry. The active receipt disappeared; the archive records
`preferencesRestored`, `configurationVerified = true` and
`configurationRestoreRetryCount = 1`. All 25 controlled keys equal their exact
recorded originals, all 30 unrelated entries equal the pre-retry table, the
policy equals the recorded original with RunCat Visible, and management remains
stopped. No fallback recovery receipt was created and no automatic Resume ran.
The UI reported **Changes undone.** Independent physical verification remains
unavailable, so this result proves the complete typed configuration and policy
inverse rather than absolute on-screen coordinates. Private evidence is under
ignored
`LocalData/0.11.0-26A428-build/macos27-major-retry-preflight-20260922-101634/`
and
`LocalData/0.11.0-26A428-build/macos27-major-retry-result-20260922-141833/`.

### Exact post-write generation split (historical, superseded below)

After that clean recovery, the owner resumed management and reviewed a pure
RunCat/Dato inversion. The menu bar visibly adopted the exchange, but the final
corroborated capture still reported that the private container reader and the
protected plist disagreed. The writer therefore performed its existing single
journaled rollback. Read-only inspection confirmed that both target keys had
returned to their exact originals (`265.5` and `418.5`), all 55 plist entries
were present, the clean receipt was `applied` and verified, and its detail
recorded that the failed revision was rolled back. This was a safe rollback, but
it rejected an observed successful endpoint. Evidence is under ignored
`LocalData/0.11.0-26A428-build/runcat-dato-disagreement-20260922-154212/`.

The post-write check is now narrower and more accurate. Every ordinary capture
and every pre-write freshness check still requires complete container API/plist
agreement. After one successful, journaled configuration write, capture still
waits once for five seconds and retries once. If the final plist is stable and
equals the complete reviewed target group while the container reader equals the
complete exact pre-write table, that sole two-generation split is accepted as a
committed endpoint. A third value, missing key, unrelated top-level change,
different previous generation or disagreement before the write still fails
closed. The change does not repeat a write, poll, broaden access or accept a
partial table. The same transition-aware readback is used after the single exact
rollback and receipt-backed inverse.

Deterministic tests cover the exact accepted split and reject third-state,
unrelated-drift and no-write cases. The full Xcode 27 suites pass with 615 Debug
tests in 56 suites and 323 ordinary Release tests in 34 suites. The compiled
ignored optimized trial is
`LocalData/0.11.0-26A428-build/runcat-dato-generation-split-candidate-20260922-1552/Blenny.app`.
Its executable SHA-256 is
`15b95fd459a591205514cb80ce7a21b8ea63d2645e9abf43c9ebc3640b8296d5`,
its ad-hoc CDHash is `8ae67ebd054a118fa66df09d13f614c66922cf7b`, strict
signature verification passes, and its only entitlement remains
`com.apple.security.files.user-selected.read-write`. It is not installed; a
stopped, draft-free preflight and a separately authorized live Apply/Undo remain.

### Undo replacement preview token stability

The owner observed a Board Apply that offered **Replace Undo & Apply** and then
failed with **The selected preview changed. Prepare and review it again.** The
retained clean Undo receipt predates the current layout and contains two
committed positions. The writer's confirmation mismatch occurs before any
configuration write. A deterministic test reproduced the failure with an
unchanged snapshot: repeatedly decoding the same receipt changed the rebase
token. The token encoded the complete receipt with JSON `sortedKeys`, but its
embedded snapshot contained both a `Set<String>` and an integer-keyed
observation dictionary. Those encode as arrays whose order `sortedKeys` does
not stabilize.

Snapshot encoding now sorts the allowed-owner set and emits observation pairs
by ascending PID. The receipt schema and decoder remain compatible with
existing stored receipts. The rebase token still binds the complete receipt
and all retained current values, so a real change after review remains a
pre-write rejection. The serialization regression test and the existing
reviewed-rebase and stale-token tests cover both sides of this boundary.
The owner quit Build 10 before replacement. Debug Build 11 includes this
change and was installed at `/Applications/Blenny.app` after strict signature,
binary digest and recovery-receipt preservation checks. Its only entitlement
is `com.apple.security.files.user-selected.read-write`. Subsequent owner tests
are recorded below.

### Post-Undo container read in the same process

The owner verified a visible-area exchange in Build 11, then prepared Snipaste
as Revealable and Paste as Hidden. Apply reported that the private container
preference API and the independent plist read disagreed. The prior Undo had
completed and archived a verified `preferencesRestored` receipt; there was no
active recovery receipt. The protected plist's size and modification time did
not change during the failed Apply or the following investigation. The Board
kept the unapplied draft, and no second Apply was attempted by the investigator.

The current backend accepts only an exact previous-generation container value
against the exact reviewed post-write plist during a journaled post-write
readback. Ordinary capture and pre-write checks remain strict. After the owner
authorized a controlled restart, the same installed Build 11 immediately read
the configuration and passed an additional read-only Refresh without a plist
change. The investigator reconstructed the two-area draft and left Apply to the
owner. This is consistent with a process-lifetime stale container-preference
view after the earlier write/Undo boundary, but it does not isolate that cause:
the failing process's raw API table was not saved for comparison. The exact
CoreFoundation cache mechanism is not yet proven, so the reader contract must not be weakened or a
private synchronization function invoked without a separate bounded test.

The owner then applied the reconstructed draft successfully in Build 11.
Read-only follow-up found a clean schema-4 `applied` receipt with configuration
verification true, no pending values, one Revealable and one Hidden application
policy, and an enabled management policy. The Board showed Undo Changes and no
unapplied draft. Physical verification remained `unavailable`, so this is an
accepted configuration commit rather than a verified absolute screen position.
An additional read-only Refresh in the same process succeeded. Thus the
post-Undo mismatch is not reproduced after every successful Apply.

### WeChat cross-area failure and interrupted revision rollback

In the same Build 11 process, the owner next dragged WeChat toward Revealable
and Apply failed with the container API/plist disagreement. This attempt passed
the pre-write gates: its durable schema-4 receipt reached revision 2 and then
`restoreIntent`, recording an inverse to the last committed configuration.
The protected plist was modified after that intent was saved, but the app could
not corroborate the inverse and retained the pending receipt. The Board shows
**Recovery needed**; its recovery button is disabled while the local draft is
present. The previously accepted Snipaste/Paste policy remains persisted. The
investigator did not retry Apply, invoke Recover, quit, or restart this process.
Private copies of the receipt and accepted policy are in ignored
`LocalData/0.11.0-wechat-cross-area-failure/`.

A deterministic recovery test exposed another boundary before touching the
live receipt: a failed later revision that retains the previous commit's policy
Undo tried to prepare that older policy Undo before inspecting its already
journaled rollback. It failed without a policy store even when the inverse was
already at the committed configuration. Recovery now identifies this pending
revision rollback first, checks its configuration endpoint without preparing
the older policy inverse, and retains the older Undo for a separate later
action. The application also skips its old-policy inverse preflight for this
exact receipt state. The test failed before this correction and passes after it;
the full Debug suite passes. Build 11 does not contain the recovery correction.
The live rollback is still unverified, and no replacement or recovery action
has been taken yet.

The correction is packaged as ignored Debug Build 12 under
`LocalData/0.11.0-wechat-cross-area-failure/build12/Blenny.app`. Its executable
SHA-256 is `f3684492331beedfde1163fc2a4c0775c365741396333b3df6ee0a673f9ca030`;
strict signature verification passes and its only entitlement is
`com.apple.security.files.user-selected.read-write`. The installed Build 11
is backed up under the same ignored incident directory. Build 12 remains
uninstalled while the owner decides whether to interrupt active management and
discard the local WeChat draft for controlled recovery.

### September 25 readback contract re-audit

The owner requested stable repeated drag, ordering and Apply operations rather
than another restart workaround. The installed Build 11 remains running with
the same pending revision-2 receipt. The investigation has not applied, recovered,
discarded the draft, stopped management or replaced that process.

The durable failed plan contains an ordering change for two application owners,
with no pending policy change. Therefore it proves an ordering-write failure;
it does not by itself prove that the intended cross-area policy assignment was
accepted by the Board. A subsequent attended trial must inspect the local draft
before Apply as well as inspect the committed result.

The existing post-write exception does not establish a reusable read baseline.
It can accept an exact target file with an exact previous API generation, while
the next ordinary capture still requires those sources to agree. Increasing the
settlement delay or accepting a known split once does not resolve repeated
operation stability. Build 12's interrupted-rollback correction addresses a
separate recovery bug; it is not a fix for the source disagreement.

An isolated Objective-C probe uses a unique synthetic preference domain and a
temporary container below ignored `LocalData/0.11.0-preference-contract/`.
On this host, four alternating writes through the same private defaults
initializer plus `setObject`/`synchronize` kept the private CF reader and file
in agreement, including number types. A second-process API writer also remained
consistent. Directly changing only the synthetic plist reproduced a stale API
view, including through a new `NSUserDefaults` object. This is a control for
source divergence, not evidence that MenuBarAgent directly rewrote the live
file. Restricting the synthetic Preferences directory caused a null API read
and failed synchronization instead; restricting only its container root did
not reproduce the live mismatch.

The live failure's unified log contains `NSUserDefaults` sandbox-extension
`EPERM` errors at both the first write and its rollback. The earlier successful
Apply contains the same warning. It is relevant authorization evidence but is
not a discriminating cause; the redacted path must not be guessed. Neither a
permission redesign nor a private cache-flush/synchronization call is justified
by this warning alone.

Debug Build 13 adds opt-in readback evidence, retaining the existing write and
verification decisions. `BLENNY_ORDERING_DIAGNOSTICS_DIRECTORY` names a private
ignored local directory. At most 128 event files per process record typed
file/API/file reads, the known transition when present, writer intent and
acknowledgement, and separate original-commit and rollback failures. There are
no timers, preference synchronization calls or extra system writes. The explicit
`--ordering-preference-read-only` executable mode restores only the existing
exact-file bookmark and reads these sources without creating an AppDelegate,
status items, management writer, policy store or recovery lease. Its output
retains source-specific access errors instead of treating missing data as empty.

The 617 Debug tests pass, ordinary Release builds, and Build 13 passes strict
signature verification with only the existing user-selected-file entitlement.
Its executable SHA-256 is
`40efcf0103bf8bf1331a71ed849cd03403ff519daa81aeb9f7b0f4203b5c49ef`.
Running the fresh-reader mode from the uninstalled candidate was denied by
macOS and its saved bookmark was stale, so that run establishes no live table
comparison. Build 13 is a diagnostic candidate with the prior recovery fix,
not a claimed resolution. Installed-app authorization and a controlled restart
are still needed for the next real comparison. The current receipt and policy
remain preserved; no real preference mutation occurred in this re-audit.

The owner subsequently authorized replacing and reopening the app for **read-only
diagnosis**, explicitly excluding Apply and Recover. Build 13 was installed after
the old process exited, with Build 11 preserved in the ignored pre-install
directory. The pending receipt's SHA-256 remained unchanged. The new app displays
Build 13 and requests Device Control again; the uninstalled and installed fresh
readers both returned permission errors before that grant. These denials are
distinct from the original live source-disagreement failure.

After the owner enabled Device Control, a normal LaunchServices launch of the
fresh-reader mode read all three sources successfully. A direct shell launch
of the same executable was still denied. Thus that shell-launch denial must not
be used as evidence that the authorized application cannot read preferences.
The explicit LaunchServices diagnostic creates no management or status items.
The saved exact-file bookmark reported stale, but the authorized application's
direct file and container reads succeeded independently.

The stable live file and container API agreed on all 30 entries. Compared with
the failed plan's 28-entry baseline, two later status keys had been added and
13 of the receipt's 18 retained committed values had changed. The plist's last
modification was at 14:42, after the failure and before the replacement. These
are third-state values, not an exact recorded rollback endpoint. The failure's
receipt remained byte-for-byte unchanged. No Recover action was taken, and
these later changes cannot be attributed to the failed Apply from this evidence.

The stopped, draft-free GUI was reopened through LaunchServices with the
diagnostic environment enabled. Its two normal corroborated reads agreed with
each other and with the fresh-reader report. This confirms the current readable
baseline across processes; it does not establish what the old process read at
the failed write. Continuing from a new baseline requires the owner's explicit
choice between preserving the current arrangement and reconstructing the former
arrangement; an unknown endpoint must not be silently marked restored.

### Reproduced delayed disk commit and bounded event-driven verification

The owner explicitly abandoned the old transaction, authorized continuing to
restore normal functionality, and reported a machine migration. With management
stopped and no draft, the old receipt was preserved and renamed under its storage
lease; its decision record and the complete current configuration were archived
under ignored `LocalData/0.11.0-preference-contract/owner-accepted-baseline/`.
This was abandonment by owner choice, not a claim that the unknown endpoint had
been restored. No system preference was changed by archival.

In a single Build 13 process, the investigator resumed the saved policy, moved
WeChat to Revealable using the Board's exposed action, applied, swapped WeChat
and Snipaste within Revealable, applied again, then invoked Undo. Both Applies
had complete API/file agreement. Undo reproduced the fault from this clean
transaction baseline: the API immediately held the exact requested inverse,
while the stable disk file still held the exact pre-Undo table. The final old
check ran approximately 5.92 seconds after the acknowledged write and failed;
the file adopted the complete inverse approximately 6.37 seconds after the
write. A fresh LaunchServices reader then confirmed full API/file agreement with
that inverse. Explicit Recover finalized the already-restored receipt with no
additional write intent. Three writes total were recorded: two Applies and Undo.

This is the opposite direction from the historical exception's assumption. It
establishes that the five-second check can reject a valid in-flight disk commit,
independently of a migrated recovery ledger. It does not establish the internal
reason for cfprefsd's scheduling or a universal flush-time bound. Apple's public
[UserDefaults documentation](https://developer.apple.com/documentation/foundation/userdefaults)
describes immediate memory updates and asynchronous disk writes; the observed
private-container path did not provide an immediate file-generation barrier
after its `synchronize` acknowledgement.

Build 14 replaces the fixed five-second wait with an exact-file filesystem
notification armed before the initial read. If sources disagree, the operation
waits once for write/rename/delete, with a 15-second deadline, then repeats the
complete file/API/file read once. An event is a wake-up only; it never proves
success. If event registration is unavailable, the same bounded deadline
precedes the one retry. Observation is cancelled at the end of that capture;
there is no continuous watcher, polling, preference synchronization call, or
extra system write. Both directions of generation split now fail verification
until the sources actually agree. The previous one-direction acceptance is
removed so an uncorroborated snapshot cannot become the next operation's base.

Deterministic tests reject both split directions and file changes during a read,
allow one read retry after settlement, and cover atomic replacement before the
wait, deadline expiry without an event, and cancellation without a suspended
continuation. All 620 Debug tests in 57 suites pass; ordinary Release builds.
Build 14 was installed and verified after the owner enabled Device Control.
Its executable SHA-256 is
`65998d984b3624257b32d723bfe0e199645b5ead42cf79394c7dbcd38f5f8bfa`.
In one uninterrupted GUI process, five Applies and three Undos succeeded:
WeChat Revealable-to-Visible and Undo; a WeChat/Snipaste swap followed by a
WeChat-to-Hidden Apply and Undo; then two consecutive opposite swaps and Undo.
Every saved Apply receipt was `applied` with `configurationVerified == true`;
every saved inverse was `preferencesRestored` with verification true. Six
preference writes were acknowledged; the remaining two actions needed only
policy changes. There were no recovery actions or additional write retries.

Five actual source disagreements exercised the new event wait, lasting 2.948,
8.176, 5.777, 7.924 and 1.609 seconds. Each ended on a file event and the single
subsequent read established full source agreement. Three exceeded the old
five-second settlement interval. The trace contains 87 events, including all
six write intents and acknowledgements; no diagnostic truncation occurred.
The final fresh LaunchServices reader independently confirmed file/API/file
agreement and exact equality with the complete pre-test table. No active
ordering recovery receipt remained. Management stayed on, with Snipaste then
WeChat in Revealable and Paste in Hidden. An idle process snapshot reported
0.0% CPU and approximately 96 MiB RSS.

These were the Board's exposed movement actions, exercising its draft, Apply
and Undo pipeline, not a new manual pointer-drag acceptance. The UI continued
to distinguish verified preferences from unverified on-screen coordinates.
The stale saved-bookmark diagnostic did not prevent the authorized fresh
reader's direct file/API reads. The first Resume following the permission
change rejected a changed lifecycle generation; an explicit second Resume
succeeded before testing. Neither observation was treated as the ordering
source-disagreement failure. This run validates the reproduced delayed-commit
boundary on this host, not an unlimited delay guarantee or release completion.
Raw traces and receipts remain ignored under
`LocalData/0.11.0-preference-contract/`.

### System drag-source parity regression (Build 15)

After Build 14's Apply/Undo acceptance, the owner reported that previously
movable icons had lost drag-based sorting and three-state changes. Read-only
inspection still exposed movement actions for the supported system items and
ordinary applications. Source comparison with the accepted 0.10 tag found a
missed branch in the earlier drag repair: `ApplicationBoardItem` had returned
to typed `draggable`, while `SystemBoardItem` still registered `onDrag` with an
`NSItemProvider`. The latter does not expose the typed session identity required
by the Board and lane validators in the previously reproduced failure. The tag
used typed sources for both. Thus the system-source regression is introduced by
the investigation changes, not a new intentional capability or permission limit.
This does not establish that every reported icon has the same cause without an
identified failing example.

Build 15 routes application, system and plain diagnostic artwork through one
`policyBoardDragSource` modifier. Normal Debug and Release use typed identity;
the provider variant requires the existing explicit Debug environment override.
Existing payload generation, retirement, policy admission, deferred system
sorting and the Build 14 preference-settlement fix are unchanged. The only
remaining `onDrag` registration is inside that diagnostic branch.

With Xcode 27 and the macOS 27 SDK, 71 relevant tests in four suites pass, the
packaged actual-interface lifecycle self-check passes, Debug packaging and
ordinary Release compilation succeed, and strict signature verification passes.
The installed executable SHA-256 is
`ef31b9cebc70b0000daa78d12fbb7b1be1f251c5890e2cbfd1d386cc4a1edfa2`.
Build 14 and the current applied Undo receipt were backed up before replacement;
no draft was present. Build 15 starts in typed-source diagnostic mode and needs
Device Control reauthorization for its changed ad-hoc signature. Native system
drag/drop acceptance is pending that grant and an owner-operated drag; a model
self-check or exposed Accessibility movement action is not proof of a native
drag session. Evidence remains ignored in `LocalData/0.11.0-system-drag/`.


### Final owner acceptance and local closure (2026-09-25)

After enabling Device Control, the owner confirmed that Build 15 native dragging
and Apply work normally in response to the system-item drag acceptance request.
This closes the missing native-session acceptance above; it does not enumerate
an individually witnessed test for every icon or imply unsupported sorting.
The installed Build 15 code remains the accepted baseline during closure.

Full final validation passes 620 Debug tests in 57 suites and 324 ordinary Release
tests in 34 suites, with Xcode 27.0 (27A266a) and macOS SDK 27.0. Final app,
fixture, signature, build-isolation, state and history evidence is consolidated
in [the release record](RELEASE_0.11.0.md). The owner assigned the remaining
pre-publication gates to 0.12.0. No additional feature or Clock workaround is
included in this closure.
