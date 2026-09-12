# Blenny 0.9.0: reviewed menu-bar ordering

Status: **Complete on 2026-09-12 as a local experimental milestone. See
[the release record](RELEASE_0.9.0.md) for final verification and restoration evidence.
This is not a distribution or public release.**

## Current milestone decision

The owner accepts the tested third-party ordering behavior and repaired drag flow
on macOS 27.0 build `26A5425a`. The Board continues to express Visible,
Revealable and Hidden intent, moves all configured keys for an attributable
third-party owner as one block, and retains successful order changes through
Stop and Quit with explicit Undo kept separate from incomplete-write recovery.

Siri, Time Machine and Control Center three-state visibility is owner-confirmed
as responsive. Sorting for those three subjects is deferred to a future version;
their presence in the visibility catalog does not imply ordering support. Weather
and Input Menu retain the exact-owner experimental ordering route already
described below. Ordering remains available only in Debug or the explicitly
opted-in optimized trial. Ordinary Release excludes it.

The native overflow arrow has no established writable ordering identity. Blenny
therefore does not promise fish/arrow or managed-item/arrow adjacency. On the
tested build, Clock clicks cannot open Notification Center while management is
active; a left swipe from the trackpad's right edge still works. The owner accepts
this limitation and rejects automatic Stop/Resume around Clock clicks.

Version 0.9.0 remains a local engineering milestone. Version 0.10.0 begins with
interface, copy and usability review, followed by approved refinement. The first
public source and binary release candidate stays in 0.11.0 with every inherited
distribution gate retained. Blenny uses one canonical repository. License adoption
and notices remain follow-up work after the interface review. Publication, a push or a repository visibility change remains a
separate explicit action.

Final test counts, binary-boundary checks, restoration evidence and tag state are
owned by [the release record](RELEASE_0.9.0.md). The dated sections below preserve
the complete progression of experiments, failures, fixes and superseded pending
items; their earlier status language is historical.

## Detailed chronological evidence

## September 12 focused compatibility investigation

The [final technical report](NOTIFICATION_CENTER_TECHNICAL_REPORT_2026-09-12.md)
closes the producer-to-Clock chain: MenuBarAgent broadcasts
`hasExternalRestrictions`, Core/client monitors forward the active state, and
ControlCenter sets `Clock.shouldIgnoreMenuExtraEvents`. Clock consumes the event
before any menu XPC request. This corrects the earlier attribution to Notification
Center's separate hot-key gate. Restriction presence is independent of the
allowlist; neither accepted external origin supplies an exception.
A read-only contract inspector is implemented outside product targets. Three
bounded rounds found no compatible replacement. The final AppKit investigation
distinguishes initialization-time visibility preferences from live owner scene
updates; no live external-defaults adoption path was found. Product behavior
remains unchanged, with the previously accepted documented limitation
in [Known limitations](KNOWN_LIMITATIONS.md). This supersedes the earlier decision
that this single issue must be fixed before 0.9.0 can close. It is not a repair,
version closure, compatibility expansion or release authorization. Further
parameter/delay trials for this issue stop for 0.9.0 pending new backend evidence;
the public-source discussion remains separate.

## Owner-confirmed trackpad entry

The owner confirms that swiping left from the right edge of the trackpad opens
Notification Center while management remains active, even though Clock clicks
fail. This establishes an alternate functioning entry on the tested setup and
supersedes the earlier unverified gesture status and Stop-only workaround.
The Clock handler is suppressed before sending its menu request; the complete
internal gesture route remains untraced. Automatic Stop/Resume around clicks is
explicitly rejected and will not be implemented. See [Known limitations](KNOWN_LIMITATIONS.md).

## Owner recovery and Clock-only reproduction

The owner restarted SystemUIServer and continued using the original no-wait
candidate, not a rollback build. Time Machine now opens and behaves normally in
all three policy states; other tested items also behave normally. Clock cannot
open Notification Center while management is active, and Stop alone immediately
restores that interaction. This narrows the remaining reported defect to Clock /
Notification Center. It does not prove the cause of the prior Time Machine host
waits or establish broader hardware/runtime support.

The precautionary adapter rollback is reversed. All 121 source files again match
the previously tested no-wait candidate, so this correction does not require a
new binary. The historical 560/560/315 test results apply to that exact source;
no new live manipulation, installation or restart is performed by the agent.

Read-only observation finds SystemUIServer, Control Center and Notification
Center in NSWorkspace's running applications. Their absence is not established
as the defect. Notification Center imports MenuBarClient's
VisibilityRestrictionMonitor and the active VisibilityRestrictionState case.
Runtime method enumeration of MBAssessmentModeConfiguration exposes only the
existing bundle and numbered-item allowlists, with no Notification Center
exception setter.

Static inspection of the installed NotificationCenter executable (UUID
`D0CFEB98-2A67-3BB6-959C-8028756DB7FF`, linked MenuBarClient version `97.0.9`)
finds its MainController starting the restriction monitor. The delegate compares
the reported state with `.active` and stores that boolean; two presentation entry
paths return immediately when it is true. This is direct evidence of interaction
suppression based on the monitor state, independent of the clock's visibility
check in Blenny. At this initial inspection stage, the exact entry selectors and
upstream allowlist semantics were not yet established. The September 12 focused
investigation first identifies the hot-key entry and allowlist-independent flags.
The final report corrects the earlier inference that this was Clock's route:
Clock is suppressed locally in ControlCenter before its distinct menu XPC request.
A blanket allowlist addition is not a fix.

At this earlier investigation stage, the owner-verified workaround was Stop before opening Notification Center,
then manually Resume after closing it. Stop releases active hiding and may expose
Revealable and Hidden applications while preserving their saved intent and accepted
ordering.
No automatic Stop/Resume, synthetic click, injected patch, hidden preference
bypass or unverified allowlist expansion is introduced. Preserving simultaneous
concealment and native Notification Center access needs a separately verified
backend capability. This remains an accepted 0.9.0 compatibility limitation, not
a delivered clock fix. Raw inspection output stays
in ignored local evidence; no Apple implementation is copied into tracked code.

## Earlier system-menu regression report and precautionary withdrawal

The owner reports that Time Machine becomes visible without delay but cannot open
its menu, retaining its highlighted state; quitting Blenny does not recover it.
The clock also cannot open Notification Center during Blenny management, but
recovers after Blenny quits. These are functional regressions, not accepted latency
tradeoffs. The Time Machine no-wait candidate is withdrawn from further testing.
Its archive remains preserved as evidence, not a recommended build. Source now
routes ordinary reveal back through the waited exact-restoration method; this is
containment, not proof of restored native menu functionality. The rollback compiles
with Xcode 27/macOS 27 SDK and passes all 23 shared-system-item fixture tests
without warnings. No replacement artifact is delivered while clock interaction
and native menu recovery remain unresolved.

A bounded read-only sample taken with Blenny absent shows Time Machine worker
threads waiting in DiskManagement connection teardown during disk enumeration.
SystemUIServer's main thread remains in its normal event loop. This supports a
host-side pending-work hypothesis but does not establish a deadlock, the cause,
or that Blenny introduced it. No host restart or preference repair was performed.
The clock's existing allowed visibility identity does not demonstrate that its
Notification Center interaction is preserved under the assessment assertion.

This section records the earlier blocker decision, which the owner's September 12
known-limitation decision supersedes for Clock/Notification Center alone. Attended
menu/popover interaction checks remain required for other claimed behavior, along
with visibility, ordering and configuration restoration in normal managed state,
ordinary reveal, conceal/reveal, Stop and Quit. Do not promote or distribute a
replacement based solely on passing preference/fixture tests. Source-publication
discussion remains pending; no release or history operations are authorized.

## Owner-requested Time Machine no-wait trial

The owner confirms responsive Siri ordinary reveal and asks to try removing Time
Machine's remaining waits. The Debug ordinary-reveal path now performs the same
visibility setter, complete baseline preference restoration and synchronization,
but skips its two fixed settlement waits. The serial writer still requires an
immediate exact snapshot match. Exact Stop/Quit cleanup and failed-operation
checkpoint restoration retain the original waited backend method. Other builds
and targets retain their prior timing behavior. This is a timing experiment, not
proof that SystemUIServer has finished asynchronous metadata normalization.
Tests cover distinct ordinary-reveal routing, exact readback failure, checkpoint
and receipt preservation, and subsequent full restoration. No agent-operated live
visibility change is performed while preparing this candidate.

The owner also reports an already-handled drop without movement. No-op payload
retirement must explicitly refresh native drag-source registration; unchanged
layout data alone does not publish that private registry mutation. Same-session
duplicate delivery must not execute another preview or write, while a subsequent
real drag must acquire fresh authority. The Board retains one bounded
last-delivery receipt, checked before transient session metadata; cancelled source
sessions retire only their own token. Source providers use the current payload
identity, and no-op retirement publishes a revision even without layout changes.
Native callback causation remains a hypothesis until attended retesting.

Automated verification passes 560 tests in 50 suites in Debug and optimized
Debug-capability builds, and 315 tests in 32 suites in ordinary Release. Actual
interface-model self-checks pass in both test-enabled builds. The no-wait behavior
and native callback behavior still require owner-operated acceptance.

The signed optimized candidate is
`build/ordering-trial/Blenny-0.9.0-time-machine-trial.zip`. Packaged interface-model
self-check and archive/signature verification pass; ten watched state files are
byte-identical. All 121 frozen source files and 21 initial research files match;
the installed app, prior archive and Git history are unchanged. Ordinary Release
excludes experimental ordering and fixture-entry markers. All three final test
logs are warning-free. No live visibility or ordering write was performed.
Executable SHA-256: `0981fd794c40f70fd1a9fed153c7c1a134a9d58718628d90ba4e560185e1ddc3`.
Archive SHA-256: `ff7fe6c6547388b9d328826160022ab018f477a306796afc05ef50d8152c1356`.

The owner wishes to discuss public source before version closure. No 0.9.0
completion, tag, history rewrite, push or publication is authorized. Existing
licensing, privacy/history audit, distribution and public-release gates remain.

## Owner feedback after the Resume/Stop candidate

The owner reports that dragging now appears fixed, conceal is responsive and
Control Center visibility no longer has a performance problem. This is owner
acceptance of those observed interactions, not renewed Control Center sorting
support. Siri and Time Machine still reveal slowly. An unchanged drop at the
original location should be silent, with no review or write; genuine stale or
invalid delivery must remain distinguishable.

The no-op outcome consumes only its delivery token and clears transient drag
presentation. It does not change the layout generation, area draft, current
review or backend state. Same-item and equivalent-gap drops are covered by the
actual interface-model fixture; normal policy-only same-area drops also remain
silent. Subsequent fresh drags remain available, while stale and duplicate
payloads still fail validation.

Ordinary Siri reveal now uses the existing setter after a durable exact reveal
intent is saved in the same recovery receipt. Schema 2 adds that optional intent;
schema 1 receipts remain readable and are upgraded only when fast Siri reveal is
needed. Older readers reject schema 2 rather than silently dropping recovery.
The allowed temporary result is exactly `StatusMenuVisible=true` with the stash
key absent, not any visible state. Verification and cleanup reject other drift.
Conceal clears the intent after verified hiding; Stop, Quit, return-to-Visible and
failure compensation retain exact restoration. The serial writer and checkpoints
remain the only mutation path. Tests use an implicit-visible baseline with an
absent status key and a stored stash to distinguish temporary reveal from exact
restoration, including restart after the setter and failed intent persistence.

Time Machine and Now Playing keep their exact-recovery reveal path. Time Machine's
post-setter metadata contract is not established well enough to infer a reversible
fast reveal from its hide behavior. Its remaining reveal delay is a known limit;
no new live experiment or arbitrary reduction of recovery waits was performed.

Automated follow-up verification passes 557 tests in 50 suites in both Debug and
the optimized owner-test configuration, plus 314 tests in 32 suites in ordinary
Release, with no warnings under Xcode 27/macOS 27 SDK. Actual interface-model
self-checks pass in both test-enabled executables. These establish no-op and
recovery behavior with fixtures, not native Siri reveal timing or Time Machine
compatibility. New installed adoption remains owner-operated acceptance.

The signed optimized follow-up archive is `build/ordering-trial/Blenny-0.9.0-reveal-noop.zip`.
The packaged interface-model fixture and archive integrity pass; ten watched state
files remain byte-identical. The 121 source files match the tested freeze, all
21 original research files are preserved, and the installed app, preceding archive
and Git history are unchanged. No live visibility/order mutation was performed.
Executable SHA-256: `c22f611801d41c59c321a4ea9e05457ae9672736181ae6006f7acfafbaf94cd5`.
Archive SHA-256: `3ff5f894bba0dd36b9f3502cef5b53da0e1724ffcbb3572a4ea2205426f0996d`.

## September 11 scope and lifecycle follow-up

The owner accepts deferring sorting for Siri, Time Machine and Control Center to
an unspecified later version, including after public release if necessary. This
supersedes the prior requirement to resolve or negotiate those three sorting
capabilities before closing 0.9.0. Do not claim them as working sorting targets.
The Board separates them from ordered subjects, labels them `Area only`, and
explains that three-state visibility does not set their menu-bar position.
New product reviews omit their keys; historical identities and receipt recovery
remain intact. This does not defer their existing visibility controls or waive
restoration, lifecycle, signing, licensing or other public-release requirements.

The latest precise reproduction is that Resume or Stop makes ordering unavailable
until Refresh. Resume, Stop and policy-only Apply now preserve and rebind an
unchanged-scope layout with fresh drag tokens, including its unapplied order and
discard baseline. Existing captured rows can reconstruct an already missing layout
without a read. The actual-model fixture covers those transitions, a Siri-only
policy Apply, old-token refusal, next-drag success, failure return and draft
preservation. Review no longer silently requires an old snapshot: it obtains fresh
configuration itself before the existing reviewed write checks.

Deferred system controls use the policy-only move route. Their live composite
observation identifiers are resolved to canonical policy identifiers before a
three-state drag is created. Native drag startup resolves a fresh payload, and
normal generation/source-policy/duplicate-delivery checks still apply. Ordering
availability must not prevent a supported three-state move.

Normal visibility commits no longer wait one fixed second per persistent target.
Siri/Time Machine retain the paired synchronous getter check; Now Playing retains
preference synchronization, and the serial writer still captures and verifies the
applied state before recording it. A regression simulates Time Machine's delayed
target-local normalization after the first applied capture and verifies recovery.
This improves the conceal path; ordinary reveal and return-to-Visible use exact
restoration and still retain both existing one-second recovery barriers. Full
reveal performance is not claimed fixed. No polling, parallel writer, guessed
notification acknowledgement or new live system trial is introduced.

Arrow investigation found no proven fallback state-machine off-by-one. Compact
fallback items deliberately hide their button from Accessibility, so a single
observed Blenny item does not distinguish compact from absent. The Debug fish
context menu now reads the actual in-process fallback allocation and AppKit frames
when opened (`Fallback slot: ...`); this is local read-only diagnosis, not a
position setter. Absent excludes the fallback hypothesis; compact leaves the
zero-width displayable/count hypothesis open; reserved also consumes width. No
native-arrow position fix is claimed without that distinguishing observation.

Final September 11 automated verification passes 551 tests in 50 suites in Debug
and the optimized owner-test configuration, plus 314 tests in 32 suites in ordinary
Release, without warnings under explicit Xcode 27/macOS 27 SDK. The real interface
model fixture passes in both test-enabled executables, including composite Siri
policy dragging and management transitions. Earlier pre-final and failed compile
logs are retained separately under ignored local evidence. Native pointer behavior,
conceal performance and the arrow boundary still require owner observation.

The final owner-test archive is `build/ordering-trial/Blenny-0.9.0-resume-stop.zip`. Its packaged
interface-model check, strict signature and archive integrity pass. Ten watched
state files remain byte-identical. The 121-file source freeze, 21 original research
files, current installation, preceding archive and Git history are preserved.
No live ordering, restoration or installation occurred. Ordinary Release excludes
the ordering-table literal and fixture entry point.
Executable SHA-256: `537b8ca1a6d90bc190dcbba25f8064d27642c79d2ce6e519ec0fd29cb82995f5`.
Archive SHA-256: `3d421ac49ddf42fa697b798f0e15396e9c257d96d017f3a13f6273f9ec2614af`.

## September 10 follow-up: committed layout and unresolved system adoption

The post-commit UI path clears the ordering draft while synchronizing accepted
policy, then depends on an optional backend capture to recreate it. A capture
failure therefore leaves every ordering source unavailable until Refresh. The
follow-up installs the reviewed committed order against the new candidate
generation and accepted policy before that capture. It checks exact subject scope
and policy equality, rejects old drag tokens, and retains configuration editing
when physical observation fails. The actual interface-model fixture covers this
missing-observation path. This does not weaken write preflight or claim physical
verification. Footer `Review Changes…` prepares the combined review; `Apply Changes`
commits area assignments and order through the existing serial coordinator.

Read-only inspection finds Siri and Time Machine's committed preferred values
still present, with unchanged host lifetimes. Control Center's value did not
change in the active revision, so that receipt does not establish its adoption.
Mixed system plans have unavailable physical verification: configuration success
cannot establish that either host dynamically adopted the new order. Their
working visibility APIs are a separate contract. Do not add speculative reloads,
key aliases, process restarts or automatic correction to disguise this gap.

The visibility backend has an explicit one-second wait per Siri, Time Machine or
Now Playing setter; exact restoration also has a second one-second wait. These
operations precede application assertions in the serial coordinator. Control
Center uses a different assertion path. The delay is implementation debt, not
proof that macOS needs that duration. This candidate preserves settlement behavior
and adds opt-in `BLENNY_SESSION_DIAGNOSTICS=YES` stage timings. Removing or batching
settlement requires exact restoration and failure validation before promotion.
No performance improvement is claimed for this candidate.

Apple static evidence separates preferred-position sorting from overflow-group
resolution and its indicator insertion location. No native-arrow position key is
known. Blenny is excluded from Board permutations; its status item still occupies
22 points. The fallback slot may be absent, zero-width compact or 22-point reserved;
zero width alone does not prove exclusion from overflow item counts. A repeatable
arrow boundary is not proof of an off-by-one error. Before any new mutation trial,
identify the native indicator owner, fallback slot mode and adjacent identities.
A separately authorized two-neighbor exchange and exact inverse could distinguish
an ordinal capacity boundary from an item-associated boundary. It cannot by itself
establish arbitrary arrow control.

Version closure remains blocked on repeated-Apply manual acceptance and an
explicitly accepted system-ordering/performance/arrow scope. Do not silently claim
these behaviors supported or move them out of scope. Distribution remains 0.10.0
and first public release preparation 0.11.0. This follow-up performs no live system
mutation, installation, history rewrite, tag or publication.

Follow-up verification: Debug and optimized owner-test builds pass 549 tests in
50 suites; ordinary Release passes 314 tests in 32 suites, without warnings using
explicit Xcode 27 and macOS 27 SDK. The actual interface-model fixture passes in
both test-enabled executables. This is automated configuration-lifecycle evidence,
not native drag, system adoption or performance acceptance.


The follow-up optimized owner-test artifact is `build/ordering-trial/Blenny-0.9.0-commit-followup.zip`. Its packaged
interface-model self-check and strict signature pass; ten watched state files,
the installed app, previous archive, original research and Git history are unchanged.
Executable SHA-256: `d40dc0a91a960883f4c38672f4a7d23cb338dacc2bcffa1a014653b965e36cc2`.
Archive SHA-256: `3010954dbcdf73627a788cb6b2af864048bc0c800f58c87b06a8fbe790366f00`.
Ordinary Release excludes the ordering-table literal and fixture entry point.

## Current product contract: three ordered areas

### September 10: post-Apply drag identity and delayed session cleanup

Owner testing of the drag-stability candidate still finds that a long hover can
lose its drop and that all same-area ordering becomes unavailable after one Apply,
while area moves remain possible. The installed candidate is confirmed by its
executable hash. Read-only inspection of the live window shows ready configuration,
a successful save and no busy or pending-recovery state; those observations do not
reveal the internal native drag callbacks.

The UI exposes an identity containing owner, policy and candidate generation,
while delivery validates a separate token bound to the ordering-layout generation.
An order-only Apply changes the layout/token without changing the exposed identity.
Sources must resolve the current payload when requested, and the exposed identity
must include its token. Repeated evaluation within one layout must remain stable.
Cleanup must bind the native session and complete payload identity; a late event
from an earlier same-owner drag must not clear a newer landing. Cached framework
payloads and callback ordering are plausible runtime contributors, not directly
observed proof. Rejected delivery must explain why it was refused.

Acceptance adds a read-only executable check of the actual ProductInterfaceModel:
repeated drops, simulated order-only Apply/reinitialization, combined policy commit,
and the next drag. It uses synthetic fixtures before application startup, without
a status item, private backend, persistence or input simulation. These checks
supplement native-session regressions; attended hover and repeated Apply acceptance
remain required. The previous 547 passing tests did not establish these behaviors.

The final September 10 source passes 549 tests / 50 suites in both Debug and
optimized owner-test builds, plus 314 tests / 32 suites in ordinary Release,
without warnings under explicit Xcode 27/macOS 27 SDK. The real interface-model
self-check passes in both executable configurations. The initial follow-up compile
failure and subsequent passing logs remain in ignored local evidence. This does
not verify native pointer interaction; attended long-hover and repeated-Apply
acceptance remain open.

Run the fixture check with `BLENNY_ORDERING_BOARD_LIFECYCLE_CHECK=YES` when launching
the Debug or optimized owner-test executable. It exits before normal application
startup and does not create a system writer or touch recovery storage.

The signed optimized candidate is `build/ordering-trial/Blenny-0.9.0-drag-lifecycle.zip`.
Executable SHA-256: `2aad1c5fd73b2fde6eacc08e87afe6a22f3f7df9eb1758e4b4d9613951af36b4`.
Archive SHA-256: `15c24ebecf79157fb97d97a59d74afd7a5d4703437a5b6ae128e663afe6f6d67`.
The packaged interface-model check passes while all ten watched state files remain
byte-identical. Strict signature, archive integrity, the 121-file source freeze,
21 original research files, installed prior executable, preceding archive and Git
history checks pass. No live sorting, Undo or installation occurs. Ordinary Release
excludes the private ordering-table literal and the fixture entry point.

### Follow-up: clean Undo history and unstable drag destinations

The owner reports that subsequent ordering is blocked by a restore-required
message and that drag previews either fail to appear or oscillate while hovering.
Read-only diagnosis finds an applied, configuration-verified schema 3 receipt with
no pending values. Its recorded positions differ from current configuration;
the relative order also differs, so this cannot be assumed to be only numerical
normalization. The implementation previously classified every such difference as
pending restoration and prevented a fresh reviewed operation.

A clean retained Undo ledger must be distinguished from an incomplete write.
When outside configuration changes invalidate that ledger, a new review must
explain that its Undo baseline will use the current selected positions. Apply
must bind that decision to the exact old receipt and fresh configuration, archive
the old ledger as superseded, and start the new intent durably. It must preserve
unselected external changes. A pending or unverified receipt still requires real
recovery; records are never deleted to unblock the UI. This is a change to clean
history handling, not an automatic system rewrite or reconciliation loop.

Drag destinations must remain geometrically stable while the translucent landing
preview moves. Apple's `DropSession.location` is local to the destination, and
`dataTransferCompleted` is the cleanup phase; changing the hit region underneath
a stationary pointer can invalidate a hand-computed insertion point. The follow-up
must test stationary hover, lane transitions, release/data delivery and startup
availability separately from system ordering. Manual drag acceptance remains
necessary after deterministic tests pass.

The concrete UI failure chain combines nested lane/strip destinations, insertion
of the ghost as a layout child, and a new random payload token on every body
recomputation. The prior token map cleared after 512 entries and could evict an
active drag. The replacement uses one lane-content destination, a viewport-width
minimum with stable scrolling coordinates, a reserved trailing slot, an overlay
ghost and visual item offsets. Payload identity is stable for a subject, policy,
candidate generation and layout generation. A successful move retains the landing
until data delivery; cancel/forbidden completion clears it immediately, and late
old-session cleanup must not erase a newer drag. A failed startup configuration
read remains an explicit unavailable state; the fix does not bypass that read.

References: [Apple DropSession](https://developer.apple.com/documentation/swiftui/dropsession)
and [drop phases](https://developer.apple.com/documentation/swiftui/dropsession/phase-swift.enum).

The follow-up validation also exercises the file-backed store through the same
protocol used by the coordinator, so a protocol default cannot silently replace
the concrete archive operation. No live ordering or Undo operation is used for
this regression check.

The drag/Undo follow-up passes **547 tests / 50 suites** in both Debug and the optimized owner-test flavor, and **313 tests / 32 suites** in ordinary Release, using explicit Xcode 27/macOS 27 SDK with no warnings. The new regressions cover fixed hover projection, stable payload identity, cancellation and late delivery, clean-ledger drift, post-review changes, exact new-baseline Undo, mixed system subjects, durable supersession and persistence failures. Initial test-declaration and protocol-witness failures are retained in ignored local evidence; the complete matrix passes after correction. This does not establish live drag feel or exercise a new system write.

The signed optimized candidate is `build/ordering-trial/Blenny-0.9.0-drag-stability.zip` (executable SHA-256 `35d4b99721480c25ab387c944d948f595f658aba7ad0afe767ae4be5b29822cb`; archive SHA-256 `b116a284e99682e5f96e343b23c1d99c02ce58119610c8dccebc43509163f205`). Its packaged read-only run identifies the actual clean-ledger drift and produces an eight-subject schema 4 preview with fresh preflight equivalence. All nine watched state files remain identical; no writer, ordering write or receipt write occurs. Strict signing and archive integrity pass. The installed controls build, previous archive, 21 original research files and Git history remain unchanged. Ordinary Release retains no ordering-table literal. This candidate still requires attended drag and Apply/Undo acceptance.

### Controls follow-up after owner adoption

The owner reports that all currently offered items sort correctly. This supersedes
"system adoption pending" for that presented scope, while exact per-item inverse,
Stop/Quit behavior and changing-capacity coverage remain separate acceptance work.

Siri's live AX observation can be a composite SystemUIServer identity. The
ordering and old manual-trial surfaces recognized that identity, but the policy
editor expected the canonical menu-extra identifier. The resulting fallback
showed only Hide/Restore. The follow-up resolves recognized observations to exact
persistent-policy identifiers before reading or assigning intent, so the Board,
context menu and selection actions use Visible, Revealable and Hidden together.
The legacy manual controls remain only where no ordinary policy route exists.

Control Center is a conditional Debug trial, distinct from the six system
controls whose ordering the owner has now accepted. Apple code distinguishes
`primaryBentoBox` from ordinary `bentoBox`, and the existing catalog identifies
primary Control Center as raw value 8. The current complete group table has one
BentoBox-shaped key, `module:BentoBox-0`. There is no proved universal rule that
suffix `0` means primary: this mapping is an inference limited to the admitted
build, pinned ControlCenter/MenuBarAgent binaries, a unique Apple-signed host,
and a complete table containing that sole exact BentoBox key. A missing key,
invalid value or additional BentoBox key refuses this trial. It does not create
positions or target ordinary BentoBoxes, the add button or native overflow.
Preview, final write and recovery retain the existing exact-scope protections.
Live Control Center adoption and inverse require owner-operated validation.

The macOS 27 backend pins Mach-O UUIDs `E842FC2A-0AAB-350D-BEA6-66229257C329`
(ControlCenter) and `DE3CDABA-05ED-328C-88BE-41D240550156` (MenuBarAgent).
These are local Apple binary-version anchors, not personal paths or generalized
compatibility claims. The catalog evidence is recorded in
`Research/0.8.0/IDENTIFIER_FINDINGS.md`; read-only static analysis confirms the
primary/ordinary BentoBox distinction on the current binaries. Only the bounded
Mach-O metadata is read; no code is injected or native controller restarted.

The native arrow/fish adjacency request remains unimplemented. Existing Apple
static evidence shows an overflow insertion location and layout priorities
separate from persisted preferred positions; no native-arrow group key or
recoverable setter has been established. The current planner orders semantic
Hidden → Revealable → Visible subjects, while macOS computes its overflow
boundary from its own layout. One Visible item on the arrow's left is therefore
not evidence that a numeric position should simply be decremented. The fish is
excluded from whole-owner sorting and has several historical self keys; those
must not be swept into a placement operation. A future exact `Blenny.Fish`
transaction could place the fish at the semantic boundary, but that alone would
not establish native-arrow adjacency across capacity or frontmost-app changes.
The native MenuBarAgent button and Blenny's fallback chevron also need separate
identification. This follow-up adds no arrow setter, self-position write, polling
or correction loop. The original placement guide remains available.

The controls-follow-up optimized app passes strict signature verification and a
read-only schema 4 preview for Weather plus all seven configured system subjects,
including Control Center, followed by one fresh preflight. Nine watched state
files remain byte-identical. No ordering writer or recovery receipt is created.
The packaged executable begins with SHA-256 `3015dd59`; the owner-test archive is
`build/ordering-trial/Blenny-0.9.0-controls-followup.zip`. Its executable matches
the packaged app. The installed preceding app, preceding archive, 21 original
research files and Git history remain unchanged. This is read-only integration
evidence, not live Control Center sorting or a new third-party experiment.

The new deterministic regressions cover recognized composite identities reaching
Revealable, rejection of foreign hosts/similar labels, Control Center singleton
and binary-version checks, sibling appearance after review, exact write scope,
missing recovery identity and successful explicit Undo. Test doubles use explicit
async configuration methods so the final-scope guard is exercised rather than
falling through the protocol's default implementation.

### System-item integration and retained user order

The owner confirms that ordering remains correct for the tested third-party
items and for Weather/Input Menu, including simultaneous area and order changes.
They also confirm the product decision that accepted order persists through
Stop/Quit. Stopping management releases visibility restrictions; it does not undo
the user's preferred order. Explicit Undo and recovery of an incomplete write
remain distinct operations. No new agent-operated sorting experiment is implied
by this owner report.

The drag-release follow-up retains the local source and canonical translucent
landing slot through pointer end, until typed drag data is delivered or transfer
completion confirms cancellation. Clearing them at pointer end could remove the
drop destination before delivery and make the icon spring back. The draft changes
once on delivery; no system write is triggered by pointer movement or release.
Deterministic gesture-sequence tests complement, rather than replace, manual
acceptance of the resulting interaction.

This Debug revision introduces separate exact system subjects for Bluetooth,
Wi-Fi, Sound, Now Playing, Siri and Time Machine. This is a narrow exception for
known system controls, not a change to whole-owner third-party scope. Module
subjects bind an existing exact `module:` key; Siri and Time Machine bind their
individual existing `status:` keys under SystemUIServer. They may interleave
with application owners without moving other keys of their shared host.
Each binding requires a unique live expected host, verified Apple code identity,
the admitted runtime and complete configuration evidence. Shared-host autosave
records or visible AX geometry are not fabricated as per-item evidence.
Unsupported display scope and status-key token collisions are reported during
eligibility and preview, before Apply can create a pending operation.

The mixed plan, durable recovery receipt and complete final-write scope remain
within the existing serial coordinator. Old application-only plans and recovery
records retain their original decoding and semantics. System targets require
their own bindings through review, Apply, inverse, repeated edits and lifecycle
cleanup. A combined system area/order operation must verify its ordering after
the visibility transition as well as after the initial ordering write.
Owner acceptance must also check system order after Stop/Quit releases active
visibility controls. The deterministic coordinator tests establish that clean
ordering receipts are retained; they do not establish every native controller's
response to releasing or restoring its visibility state. No corrective sorting
loop is added to conceal such a lifecycle difference.

The read-only Security check finds one ControlCenter and one SystemUIServer host;
both pass strict `anchor apple` and exact signing-identifier requirements. This
establishes reader identity evidence, not live ordering adoption. Clock and the
native overflow arrow remain excluded. `AudioVideoModule` is an activity-driven
camera/microphone/system-audio indicator, distinct from Screen Mirroring;
`BentoBox-0` has only the conditional experimental binding described above. Battery, Display,
Keyboard Brightness and Screen Mirroring have no current configured group key in
the observed setup. These controls are not enabled by guessing a key or creating
a preferred position.

### Earlier drag follow-up on September 9

The owner reports that most application icons now reorder successfully. This is
owner-operated product evidence, not a per-application compatibility matrix.
The next revision replaces the two visually distinct representations of one
insertion gap with a single translucent icon landing preview. A fresh review
uses current numeric configuration and retains the user's desired bundle order;
it does not require unrelated running applications to match an older Board read.
Execution still binds the reviewed values, selected lifetimes, namespaces,
complete token-collision evidence, policy, runtime and display context. A verified
commit followed by a failed UI refresh must be reported as saved, with a read-only
Refresh action, rather than as an invitation to repeat the write.

Configuration preflight tolerates unrelated table entries and root preferences
changing after the review. The proposed group is derived from the fresh capture,
preserving those values; any changed selected position or associated key still
requires a new review. The backend's final check receives the complete selected
key scope, including unchanged owners and sibling keys, instead of reconstructing
the scope from the numeric diff. Writes and inverse operations still compare the
current complete group immediately before writing; successful commit verification
compares the full expected group afterward. Legacy exchange freshness is unchanged.

Read-only inspection finds dedicated `status:` keys for Weather and Input Menu.
These exact owners already have separate bundle-policy identities and can use
the whole-owner configuration planner. The Debug Board includes them in its
ordered owner lanes, preserving their semantic system icons. Their live sorting
and inverse have not been exercised by the agent.

At this earlier stage, shared-host and module controls remained a separate capability gap. The
table contains `module:` entries for Bluetooth, Wi-Fi, Sound, Now Playing and
other controls, and separate Siri/Time Machine keys under SystemUIServer.
Key presence does not establish adoption or an independently recoverable item
identity. The application resolver must not move all shared-host siblings to
simulate one system-item move. Module-specific identity, preview and recovery
bindings would need an explicit extension to the same serial coordinator, plus
attended adoption and inverse checks. Clock and the native overflow anchor are
not admitted. That earlier revision added no module or shared-host ordering write;
the exact-system integration above supersedes this implementation gap, while live
adoption and inverse verification remain outstanding.

### Configuration and recovery semantics

The September 9 owner decision supersedes the initial exchange-session scope
documented below. Organize edits one ordered configuration across all three areas,
with arbitrary insertion within a lane and across lane boundaries. Its desired
left-to-right owner order is **Hidden → Revealable → Visible**. Application owners
remain the unit of control; every associated configured key moves as one block,
preserving the owner's internal configured order.

Configuration eligibility no longer depends on visible AX geometry, lack of
overlap, the current area, or exactly one saved autosave position. A complete,
attributable configuration snapshot and an exact inverse remain necessary. Missing
mapping, conflicting ownership and unreadable configuration are distinct from
known system exclusions. An unknown visual result is reported as such, rather
than being treated as a failed configuration write.

The corrected real-pair experiment establishes that larger preferred-position
inputs rank farther left on the admitted runtime: the owner originally assigned
995 was left of the owner assigned 581; exchanging those values exchanged their
relative positions. Configuration planning reuses selected owners' existing
numeric slots in descending order. Those experimental numbers are evidence only,
not product constants, coordinates or a spacing prescription.

Successful reviewed configuration commits retain their order through Stop and
Quit and permit further edits. Explicit undo is separate from recovery of an
unfinished write. Legacy exchange receipts must retain their original restoration
semantics. All writes, policy transitions and rollback still use the existing
serial coordinator, exact preflight and durable recovery records.

The native overflow arrow is not an addressable ordering anchor established by
this research. Grouping Revealable to the left of Visible expresses the requested
relative order; it does not prove every Revealable icon will lie to the left of
the arrow under every menu-bar capacity. Stop/Quit release visibility assertions;
retaining order does not guarantee a formerly Hidden icon remains invisible.
No arrow takeover, automatic position correction or synthetic input is added.

Acceptance for this revision requires deterministic configuration-only identity,
multi-key grouping, arbitrary cross-lane insertion, repeated commits, partial
failure, external drift, undo and lifecycle coverage; Debug and optimized builds;
and separately authorized owner-operated live verification. Earlier four-owner
success does not validate these newly broadened capabilities.

Application-only schema 3 plans remain supported. The current Board uses schema 4
plans for one through 32 mixed subjects and at most 128 existing keys. One owner
can bind an area-only review without inventing a numeric
move. When no owner has attributable ordering keys, a policy-only review remains
available and explicitly states that preferred positions are unchanged. Unmapped
owners are named in the preview rather than silently treated as moved.

Schema 2 application recovery receipts and schema 3 mixed recovery receipts
distinguish clean user commits from pending writes. Advancing an application-only
receipt into mixed ordering preserves its first-seen originals and session identity.
Successive commits merge the first-seen original value of each participating key
and retain the latest committed values. A failed revision rolls back only that
revision; explicit Undo restores the accumulated original preferred positions.
Clean Undo does not undo accepted area assignments. Pending combined operations
retain old/new policy documents and the exact previous backup, and ordering, baseline transition, persistence
and rollback run through the existing FIFO writer gate. Successful commits remove
the temporary policy rollback metadata.

Compensation restores both accepted policy and its prior backup, including an
absent backup, rather than rotating the rejected policy into recovery history.
The policy store's schema 2 transaction marker supports this exact compensation
and interrupted backup restoration while retaining schema 1 compatibility.

Controls-follow-up automated matrix (explicit Xcode 27 and macOS 27 SDK): **538 tests / 50
suites** in Debug and the optimized ordering flavor; **313 tests / 32 suites** in
ordinary Release. Coverage includes configuration identity without AX/autosaves,
whole-owner multi-key permutations, arbitrary lane insertion and stale gestures,
continuous user commits, partial writes, final receipt failure before and after
persistence, Stop during intent/write, foreign policy/target/backup changes,
exact policy and prior-backup compensation, and interrupted inverse inspection
without a repeated write. Legacy plan fingerprints and recovery tests still pass.
The system revision adds mixed-subject and whole-owner permutations, independent
shared-host scope, code identity and host-relaunch refusal, system-only display
scope, legacy receipt migration, post-policy drift compensation, full-group inverse
verification and drag-delivery lifecycle coverage. Both ordering builds and ordinary
Release complete without compiler warnings; the ordinary Release binary contains
no ordering-table literal.
The preceding six-system packaged app also passed a read-only seven-subject preview (Weather
plus the six exact system controls) and one fresh preflight. Nine watched state
files remain byte-identical; no ordering writer or recovery receipt is created.
The bundle passes strict signature verification and the archive executable matches
the packaged executable. The installed prior build, previous test archive, all 21
original research files and Git history remain unchanged. This is integration
evidence, not a new live sorting or inverse experiment.
The original 21 research files remain unchanged. These tests use deterministic
backends and temporary stores; they are not new third-party application trials.

AppKit launch dates remain preferred for legacy receipt continuity. If AppKit
omits a helper's launch date, a bounded `proc_pidinfo(PROC_PIDTBSDINFO)` read supplies
the kernel start time after validating structure size, PID and timestamp fields.
This is read-only process identity evidence, not process injection or monitoring.

The following initial-scope transaction and implementation notes describe legacy
schema 1/2 exchange plans, retained for recovery compatibility. The current
configuration contract above takes precedence over their narrower eligibility
and automatic session-restoration rules.

## Initial exchange scope and evidence (historical)

The September 8 research supersedes the earlier broad ordering no-go. The
`com.apple.MenuBar` group-container `TrailingItemPreferredPositions` path passed
external relative swap, inverse, exact scoped preference restoration and attended
visual verification for one non-adjacent real-application pair on macOS 27.0
build `26A5425a`, arm64, one display. See
[the research](ORDERING_RESEARCH_2026-09-08.md). Earlier colliding identities are
not evidence against correctly resolved keys. Preferred positions are layout
inputs, not absolute screen coordinates or a native-arrow anchor.

The first product integration is Debug-gated. The owner may explicitly build those
same gates with Release optimization for the manual trial described below. It exchanges existing configured
positions of distinct, currently running, corroborated single-item
owning bundles. Selection is application-level. It never selects one convenient
item from an unresolved multi-item owner. All targets must have an observable,
distinguishable relative order on the one current display. While management runs, only Visible
accepted intent is eligible. In the owner-requested expanded manual trial, all
three intent groups may be arranged while management is stopped and the selected
icons are fully observable. An outstanding exchange is restored before Resume can
apply a visibility baseline. Arranging an owner never changes its lane, and Hidden
remains excluded from ordinary Reveal.
Missing
configured positions, extra historical keys, multiple owner processes, token
collisions, incomplete reads, Apple owners and Blenny itself are unsupported.
Executable-name fallback keys are considered alongside bundle tokens; a bundle
match must not conceal a colliding executable match.

The initial owner-preference reader supported positively identified,
non-sandboxed current-user/any-host namespaces only. The expanded trial adds only
positively verified standard application sandbox containers, with signed owner
identity, exact container metadata and complete independent API/file reads. Unknown
or uncorroborated namespaces remain unavailable; historical success does not
substitute for that product-side identity check. Configured group positions need not equal
the owner's saved value, but the autosave identity must be unique and its complete
saved-position set must remain unchanged through Apply and Restore.

One outstanding reviewed ordering transaction is supported. The integrated Board
adds bounded insertion within an area, affecting two through 32 fully supported
owners and reusing only their existing slots. Legacy two-owner swap receipts remain
compatible. Restore returns exact preferred position values before another order
change. This session scope deliberately excludes
unproved persistence/replay across owner replacement, display changes, sleep or
MenuBarAgent recreation. There is no automatic position repair. Existing
Visible / Revealable / Hidden policy and ordinary reveal semantics are retained.
No sorting is promoted to ordinary Release or the optimized 0.8.0 system trial.

## Transaction contract

- Read and snapshot the complete group property list, exact target owner saved
  positions, complete bundle/executable collision inventory, owner process
  lifetimes, AX cardinality/geometry, runtime and display/lifecycle context.
- Preview the selected bundles, actual system keys, original/proposed inputs,
  observed relative order and exact inverse. Bind all meaningful inputs to a
  deterministic fingerprint. A preview grants no execution authority.
- Apply only after a fresh equivalent preflight and an explicit confirmation of
  that preview. Real third-party experiments require separate owner authorization
  of the exact pair, operation and recovery before the agent invokes Apply.
- Extend `CoordinatedPolicyWriter`, the existing policy mutation coordinator.
  Ordering is a narrow backend capability, never a second product writer. Serialize
  it with assertion and persistent-item transitions across suspension points.
- Persist a private, durable recovery intent before a write. Perform one table
  update through the runtime-checked group defaults access path. Never write an
  owner's position preference, clear the global table or restart a system service.
- Use bounded observation and one independent verification. No automatic retry,
  continuous polling, synthetic input, width nudge or item recreation.
- Restore exact target presence/value from a known original or applied state,
  including partial known application. Preserve unrelated current changes and
  reject unexpected target changes. A failed inverse remains recovery-required.
  Do not erase a receipt or claim restored physical order from preference equality.
- Stop, Quit and lifecycle invalidation use the same serialized cleanup. Crash
  recovery is receipt-backed and explicit; no startup position replay or repair.

The group API has no atomic compare-and-swap with Apple's writers. Fresh checks
and post-write verification bound and detect observable conflicts; they cannot
prove the absence of a system write in the final read/write gap. This remains a
Debug limitation and a gate for broader promotion.

## Implementation

`OrderingModels` owns typed property-list snapshots, bounded identity resolution,
deterministic preview fingerprints, freshness and pure swap/inverse plans.
`MacOS27MenuBarOrderingBackend` owns the exact runtime contract, corroborated
container/file reads, bounded AX captures and the exception-safe defaults bridge.
It waits for one operation-scoped AX layout notification or an 800 ms deadline,
then yields to the coordinator's independent verification. The deadline is a
production observation bound, not an assertion that layout must have completed.

`CoordinatedPolicyWriter` holds one FIFO operation gate across suspension points
for assertions, persistent system items, legacy manual system-item controls and
ordering. A concurrent Stop marks the writer stopped before waiting for this
gate. Writer creation in `ManagementLoopController` is coalesced, and cleanup
checks pending recovery as well as active assertions. A failed ordering inverse
cannot prevent Stop from releasing visibility management.

`OrderingRecoveryStore` keeps private receipts under the application's Debug
ordering support directory. A nonblocking lease, a retained verified directory
descriptor, relative file operations, atomic replacement and synchronization
precede the system write. An uncertain intent save retains recovery-required
state. Interrupted inverse intent cannot authorize another inverse attempt.
Successful completion archives the last restored receipt locally. A changed
display or absent/replaced owner may allow exact preference restoration while
leaving physical order unverified; the active receipt then remains visible.

Organize reads current left-to-right placement during its initial bounded refresh.
Same-area insertion and accessible move actions prepare an inline reviewed order;
cross-area drag retains the existing visibility Draft/Review/Apply flow. Apply
Order and Restore Order live in the same interface. Unsupported or unobserved
owners are not silently omitted from an affected insertion interval. The Board's
lanes retain visibility intent. Policy drafts invalidate ordering
previews, and accepted visibility changes first finish an outstanding exchange.
Unknown runtimes, multiple displays and unresolved identities never show Apply
as a supported capability. No launch performs an automatic ordering write.

## Owner-requested overlap relaxation on September 9

The owner notes that rendering belongs to macOS and asks to relax ordering
restrictions as far as possible. This supersedes the earlier zero-overlap
acceptance predicate described in the historical entries below. That predicate
was a Blenny observation restriction, not a requirement of the preferred-position
write API. Saved observations show several otherwise resolvable pairs with 1.5
or 2 point intersections, explaining why adjacent insertion was often refused.

The observer now accepts any amount of partial horizontal overlap when both
leading and trailing edges agree on the same strict left-to-right order and the
rectangles share a vertical band. No pixel or percentage tolerance is introduced.
Equal or horizontally nested rectangles still cannot establish that order; native
overflow was observed to return such proxy frames for different owners. Invalid,
zero-size and off-display observations remain unavailable. Blenny does not inspect
or control rendered pixels, set icon dimensions, or impose a minimum gap.

Exact width, height and vertical-coordinate equality is removed from selected
observation freshness and post-write visual verification. Positive on-display
frames, distinguishable order in a common vertical band, the same display context,
complete owner cardinality and identity, exact preferences, runtime, policy and
lifecycle checks remain required. Dynamic rendering cannot excuse reversed order,
indistinguishable proxy positions, preference drift or an owner replacement.
Receipt serialization and existing fingerprints remain unchanged; both legacy
swaps and multi-owner insertions use the revised observer and the same serial
writer and exact inverse. These changes require new automated verification and
separately authorized attended acceptance; no new live experiment is implied.

Verification now passes **463 tests in 45 suites** in both Debug and the optimized
ordering configuration under Xcode 27 / macOS 27 SDK. Cases include observed
1.5/2-point intersections, a 999-point partial overlap, schema-1/schema-2 planning
and verification, OS-driven render changes, equal/nested ambiguity, full-set
vertical-band failure, incorrect order, invalid/off-display geometry, preference
and identity drift, rollback and the existing schema-1 fingerprint. The optimized
app builds and passes strict signature verification with executable SHA-256
`1d6ed7825844a3bcbb0c764cb0e79c5defd7175de4ec1e3223bdaea3cab93808`.
It is a built candidate, not an installed or live-tested promotion. Read-only UI
inspection confirms the existing installed version is still managing its accepted
policy. Its executable, watched group/policy files and all 21 original research
files remain unchanged; no new ordering receipt exists.

## Owner result and coverage diagnosis after overlap relaxation

The owner subsequently reports normal ordering among the four offered owners
with the overlap-relaxed candidate. Read-only inspection confirms that exact
candidate is running, management is active, and the latest archived WeChat /
Usage4Claude operation is `preferencesRestored` with no active ordering receipt.
This is new owner-reported product evidence, not confirmation of every combination
or every owner's attended restoration.

The current 22-application Board comprises 19 third-party owners, Blenny itself,
and two dedicated Apple owners. Four third-party owners are individually eligible.
Of the remaining 15 third-party owners, eight are rejected only by the enabled
management scope rule, one only lacks verified process lifetime, two have owner
position-autosave identity mismatch plus scope exclusion, one has multiple global
keys plus lifetime/autosave gaps, and three lack a distinguishable observed
position as well as being outside enabled management scope. This snapshot is not
a permanent compatibility list: visibility and observations may change on refresh.

The eight scope-only rejections are a workflow limitation of the current
Visible-only predicate while management is enabled, not an API compatibility
finding. A future explicit, bounded arrangement session could make the selected
owners observable through the existing serial coordinator and restore the same
accepted intent after ordering. This is distinct from ordinary Reveal, which must
still exclude Hidden. Such a session is not implemented or authorized as a live
experiment by this diagnosis. Clearing scope exclusion alone does not prove that
all eight will retain valid position evidence in the new state.

Process lifetime currently depends exclusively on `NSRunningApplication.launchDate`.
A missing date triggers refusal even when the owner is otherwise resolved. The
macOS SDK exposes process start-time data through libproc; a checked fallback with
before/after PID-and-start-time validation is an implementation avenue, not yet a
verified replacement. Autosave mismatch similarly conflates missing matching names
with extra saved names. These need separate diagnostics and evidence; the global
write API does not itself require exactly one owner-saved position. Multiple global
keys require proof of the whole active owner scope rather than choosing one key.
No policy, visibility, ordering, permission or installation changes were made in
this read-only coverage diagnosis.

## Integrated Board follow-up on September 9

The owner rejected the separate exchange editor and requested one interface for
observed ordering and area moves. The new UI uses current AX geometry for display,
independently of whether private ordering eligibility can be established. Unknown
placement remains labeled as unverified. A failed ordering read preserves the
ordinary Board inventory and displays its concrete failure. No preference value
is interpreted as an absolute screen coordinate, and no refresh writes an order.

A September 9 installed read-only three-owner preview was refused for invalid
geometry. With native overflow collapsed, multiple owners exposed identical or
nested AX rectangles at the overflow location. These rectangles cannot establish
an actual owner order. Both the identity resolver and public-AX Board fallback
now withhold their observed positions, retain the applications as unverified and
refuse affected ordering plans. Ordinary small partial overlaps do not hide an
owner's observation. Initially the selected plan still required zero overlap;
that condition is superseded by the owner-requested relative-order observer above.
No automatic overflow expansion is introduced.

An insertion previews the complete affected interval within one area. Schema-2
plans permute those owners' existing configured values once, verify every affected
owner's proposed relative order, and use the same durable intent, serial writer,
partial-failure inverse and recovery checks as legacy schema-1 swaps. Multiple
owner insertion remains a manual-trial capability pending attended evidence.
Cross-area policy changes and ordering remain separately reviewed operations;
an outstanding trial order must be restored before another transaction. This
does not introduce joint order/policy atomicity or durable ordering replay.

The owner's current installed application reproduced a retained error stating
that the complete group or ordering table could not be read. Its main Board had
applications and stopped management; the exact runtime remained supported and no
active ordering receipt existed. Standalone reads in the development tool's
context succeeded, which does not prove access from the normally launched app.
That distinction must be verified during installed acceptance, not dismissed as
a transient error or bypassed by weakening preference corroboration.

The system log subsequently confirmed `kTCCServiceSystemPolicyAppDataDetailed`
denial with `EPERM` for the normally launched Blenny during the failed Refresh.
The raw group-file read precedes API corroboration. Backend errors now identify
file open, metadata, bounded complete read, decode, missing file table and missing
container table separately. The file reader handles bounded short/interrupted
reads and checks unchanged file identity; it does not retry a capture or weaken
source agreement. App Data denial exposes a **Data Access…** button. Local macOS
27 resources map this service to **Files & Folders**; no Full Disk Access grant or
automatic permission change is introduced. The owner must review any grant in
System Settings. Development-context success is explicitly insufficient for
normal-launch acceptance.

A subsequent owner launch confirms the inline unverified-placement status and
Data Access button, but Files & Folders contains no Blenny row. The link alone is
therefore insufficient onboarding. The latest normal-launch log records an App
Data Detailed preflight with user interaction disallowed and a background-session
`auditon` failure (`EPERM`); this establishes a denied read without a usable
prompt, not the underlying cause of the session classification. As an explicit
owner-operated diagnostic alternative, Full Disk Access can be manually granted
to the installed app, followed by a complete restart and read-only Refresh. This
broader permission is optional for the local trial, has not been granted or
verified by the agent, and is not an established baseline-product requirement.
Apple documents that Full Disk Access covers other apps' protected data and
permits adding an application manually in that settings pane. A successful
permission check still does not authorize an ordering experiment.

The next owner screenshot shows a successful ordering observation with management
active and four individually eligible owners. This clears the earlier read-error
symptom, but does not establish which permission grant caused the change. The
reported drag is refused because its computed interval contains an unsupported
owner. Review found an overly broad rightward insert-before interval: the
stationary destination was included even though its slot does not change. The
Board planner is corrected to exclude that stationary boundary while preserving
its verified placement requirement and rejecting unsupported owners that really
move. No identity or separate-geometry check is relaxed. The UI now distinguishes
individual eligibility from available moves, explains the active-management
Visible-only restriction, exposes selected-owner reasons, and provides visible
Move Left / Move Right preview buttons. The owner is asked to Stop and Refresh
before trying other areas. The active installed session is left intact while the
corrected optimized candidate is prepared for a later handoff. The focused Board
suite passes 14 tests under Xcode 27 / macOS 27 SDK; the optimized app builds and
passes strict signature verification with executable SHA-256
`65066d41d3d763d489b9cb6e445e81ce675cdb364b93e04aa2d461b9e8c00370`.
The active installed executable, watched group/policy files and original research
remain unchanged. This candidate is built but not installed; no new live sorting
or visibility experiment was performed.

The integrated core passes **456 tests in 45 suites** in Debug and the
Release-optimized ordering configuration under explicit Xcode 27 / macOS 27 SDK.
Coverage includes observed Board ranking, unknown owners outside and inside a
requested interval, same-area insertion, move-right semantics, schema-1 receipt
fingerprints, schema-2 numeric distinctness and bounds, every affected owner's
relative order, partial failure and exact inverse with unrelated external drift.
Additional geometry regressions cover identical/nested overflow proxies, vertical
separation, preserved partial overlap and unaffected owner eligibility.
The ordinary Release app builds, passes strict signature verification and excludes
ordering table, insertion dry-run and inline ordering-control markers. These
automated results do not establish normally launched access or live multi-owner
insertion compatibility.

The integrated optimized trial is installed with executable SHA-256
`c0b8d220d277ba2c9444bac5bdae2b8c3faa8d1688a59d1456b87d82381d567f`
and passes strict signature verification. An installed three-owner schema-2
read-only preview and fresh preflight pass with no writer, receipt or mutation.
That bounded planner check uses separately observable owners; it does not claim
a live contiguous Board insertion or normal-launch permission acceptance. The
six watched group/policy/recovery files and all 21 original research files remain
byte-identical. Final Finder launch and visual inspection are blocked by the
locked desktop and remain pending owner unlock. No permission was changed.

The Debug-only `BLENNY_0_9_0_ORDERING_DRY_RUN=YES` launch exercises the installed
reader and planner with the ordinary read-only policy-store guard. An optional
`BLENNY_ORDERING_PREVIEW_BUNDLES` comma-separated exact pair requests a pure plan;
it grants no write authority. `BLENNY_ORDERING_REORDER_BUNDLES` instead supplies
the desired left-to-right affected interval for a schema-2 read-only preview.
Diagnostic output contains local process and
preference evidence and must be redirected to ignored `LocalData/`.

## Historical initial acceptance checklist

This checklist records the original exchange-oriented gates at that point in the
development cycle. The configuration-backed owner workflow and current closure
state are summarized above; final verification is tracked in
[the release record](RELEASE_0.9.0.md).

- [x] Pure identity and planning tests: executable/bundle cross-collisions,
  duplicate owners, incomplete AX/preferences, multi-item scope, stale lifetimes,
  invalid values, changed plans and exact inverse.
- [x] Transaction tests: shared serialization, durable intent failure, partial
  write, verification failure, bounded rollback, target/unrelated external drift,
  Stop/Quit/invalidation racing suspension, crash receipt and recovery failure.
- [x] Product UI exposes eligibility and rejection reasons, reviewed real swaps,
  independent observed outcomes and receipt-backed Restore without editing lanes.
- [x] Explicit Xcode 27 / macOS 27 SDK Debug, Release and existing optimized-trial
  tests/builds/signatures pass. Ordering entry points require the Debug capability
  gates, including the explicitly opted-in optimized ordering trial.
- [x] Installed read-only preview preserves existing policy, backup, group and
  target-owner preference state and creates no ordering writer or write receipt.
- [ ] Separately authorized attended product swap/Restore passes exact scoped
  preference restoration and independently observed relative order. Unit tests
  and historical research do not count as this installed acceptance.
- [ ] Documentation and version values agree, all local system state is restored,
  the repository release audit passes and the final tree/tag satisfy its gates.

## Owner-operated Release-configuration ordering trial

The owner requested an optimized binary for manual testing after the refused
automated acceptance attempt. `BLENNY_ORDERING_TRIAL=YES` is an explicit build
opt-in: the configuration is `release`, with the existing Swift/C `DEBUG`
capability gates retained. This exercises the same experimental implementation
under optimization, including the isolated stopped-on-launch policy, runtime
refusals, serial writer and recovery records. It retains the existing experimental
UI/diagnostic surfaces; it is not an ordinary Release promotion. No ordering
predicate, retry limit or supported-owner boundary changes for this build.

Build with Xcode 27 and the macOS 27 SDK:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
SDKROOT=/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk \
BLENNY_ORDERING_TRIAL=YES ./scripts/build-app.sh release
```

The default output is `build/ordering-trial/Blenny.app`; an explicit
`BLENNY_BUILD_ROOT` overrides it. Debug configuration and combining this switch
with `BLENNY_SHARED_SYSTEM_ITEM_TRIAL=YES` are rejected. Ordinary Release and the
separate 0.8.0 optimized system-item trial retain their previous boundaries.

The owner can open **Menu Bar Order**, Refresh, select two eligible applications,
Preview Exchange and confirm Exchange Positions within the 60-second review
window. Restore Order returns the recorded preferred values and verifies relative
order. Stop and normal Quit also use the receipt-backed cleanup. A refusal remains
a refusal; the build does not bypass the still-unresolved observation freshness
issue. Installation/startup checks do not count as an attended exchange/Restore.

The optimized ordering trial passed **413 tests in 41 suites**, with no compiler
warnings. Its arm64 macOS-27-only bundle passed strict signature verification and
was installed at `/Applications/Blenny.app` with executable SHA-256
`64ac38e2c68df6cc99c6847ff5224e615db00c1dfca533cf1cb06e0f70b8b831`.
An installed read-only preview exited normally and preserved all eight baseline
files without creating a writer or receipt. Normal startup confirmed Accessibility
trust and stopped management; only the expected isolated management-enabled flag
changed, with policy lanes, group and owner preferences unchanged. The original
installation and control-file snapshots are retained under ignored
`LocalData/0.9.0-manual-ordering-release/`. The app remains running at the refreshed
Menu Bar Order sheet for owner testing. No agent-operated Exchange occurred.

## Expanded manual trial requested by the owner

The owner asked to enable true ordering for most icons and operate the next trial
manually. This expands eligibility evidence, not the two-owner transaction or
its restoration contract. There is no fixed application allowlist. While
management is stopped, any fully observable third-party single-item owner may
qualify regardless of Visible / Revealable / Hidden intent. While management is
enabled, only Visible qualifies. The groups themselves, ordinary Reveal exclusion
of Hidden, and restore-before-Resume behavior do not change.

Standard sandbox containers require a live sandbox code identity matching the
owning bundle, exact container metadata identity, descriptor-relative no-follow
filesystem reads, and corroborated complete API/file preferences. Read-only
investigation on the gated build verified the four-argument
`_CFPreferencesCopyKeyListWithContainer` with the standard container's `Data`
directory, together with the existing container copy-value function. The
NSUserDefaults `persistentDomainForName:` alternative returned a different
namespace in that investigation and is not used. Missing or disagreeing sources
remain incomplete; no shared-container, ordinary-domain or guessed-key fallback
is introduced. Runtime absence of the added symbol fails closed.

Sandbox provenance fingerprints bind root/Data directory and metadata identity.
Changing that source invalidates a preview, and restoration cannot be declared
complete from matching position values in a replacement namespace. The optional
provenance field preserves decoding and fingerprints of prior non-sandbox receipts.

Preflight compares AX/preferences/provenance for the selected owners. The complete
group, full before/after process inventories and runtime/display/policy/lifecycle
context remain exact, including all bundle/executable token collision checks.
Unrelated dynamic icon dimensions or observation availability do not invalidate a
pair. This does not retroactively identify the cause of the earlier generic stale
error. Selected-owner changes still refuse before writing.

Apple/system owners, Blenny, incomplete multi-item scope, ambiguous identities,
missing positions, inaccessible containers and overlapping pair geometry remain
unsupported. Broader availability must be measured by the new installed read-only
scan; broader ordering compatibility remains unvalidated until owner testing.

The expanded build passed **430 tests in 42 suites** in both Debug and the
Release-optimized ordering configuration, using Xcode 27 and the macOS 27 SDK.
Both app configurations built without compiler warnings and passed strict
signature verification. The ordinary Release binary excludes the ordering table,
container key-list and read-only ordering entry-point markers. The optimized
manual-trial executable has SHA-256
`4b3a0650e84af991130a2203505ec978205b7f95347014ad31b67299102ab3ba` and is installed
at `/Applications/Blenny.app`; its minimum OS and SDK are both 27.0.

An installed read-only scan found **15 eligible owners among 24 observed owners**,
up from four in the earlier trial. Five eligible owners resolved through the
corroborated sandbox namespace. A Snipaste/Usage4Claude read-only preview and one
fresh preflight passed, covering a Hidden-intent owner while management is stopped
and a sandbox owner. These checks created no writer or recovery receipt, and all
eight watched group/policy/owner files remained byte-identical. The previous
installed trial, snapshots and logs are retained under ignored
`LocalData/0.9.0-expanded-ordering-trial/`; the earlier original installation
backup remains intact. No agent-operated exchange was performed. The expanded
trial is for owner-operated Exchange/Restore checks, not a compatibility claim or
a completed release.

Normal startup and a manual UI Refresh subsequently presented all 15 candidates
with zero selections and Restore Order disabled. Management was stopped, no
active ordering receipt existed, and all eight watched files remained
byte-identical. The expanded app was left open at that sheet for the owner.

## Owner-reported product result on September 8

The four presented eligible owners were AltServer, SwitchResX Daemon, Tailscale
and CleanShot X. The owner reports that AltServer/SwitchResX Daemon alone failed
at **Preview Exchange**, with the separate-visible-geometry error, while the
other combinations exchanged successfully. This is attended evidence of actual
product behavior under Release optimization. Individual execution order and run
counts were not captured, and the statement does not establish every application,
display or lifecycle scenario.

The geometry rejection occurs in the pure planner before a receipt or table
write. At that point, the relative-order predicate required non-overlapping horizontal
AX bounds, not merely distinct centers. The saved last-restored baseline has a
two-point horizontal intersection between this pair's AX bounds, consistent with
the earlier read-only observations. The refusal does not demonstrate a
failure of the private ordering path for that pair, nor does it establish that
weakening the geometry check would be safe. No guard was relaxed and the running
manual-test app was not replaced in response to this report.

A read-only post-report check found no active recovery receipt. The last archived
receipt covers AltServer/CleanShot X, has phase `preferencesRestored` and records
successful exact target-preference and original-relative-order verification.
The current complete group matches that receipt's baseline, and the complete
target owner saved-position sets match the recorded baseline. The complete group
also matches the pre-manual-trial contents including property-list value types.
Its serialized file hash differs, so the evidence is value/type equality, not
byte-for-byte file restoration. Earlier combinations' receipts are not all retained
by the last-restored archive; do not infer individual restore results from this
one record. The owner has been asked to confirm attended restoration for the
successful combinations. Evidence remains in ignored `LocalData/0.9.0-owner-results/`.

## Verification on September 8

Explicit Xcode 27 (`27A5237l`) and the macOS 27 SDK produced arm64 macOS-27-only
builds. The consolidated Debug suite passed **411 tests in 41 suites**; ordinary
Release passed **307 tests in 31 suites**; the optimized existing system-item
trial passed **321 tests in 32 suites**. All three app bundles built and passed
strict ad-hoc signature verification. Ordering initializer/table/write markers
are present in Debug and absent from ordinary Release and the optimized trial.
The unchanged research suite passed 44 Python tests and four native pure inverse
checks. These are automated checks, not live ordering evidence.

The installed Debug reader produced a pure plan for AltServer
(`com.rileytestut.AltServer`, Visible) and CleanShot X
(`pl.maketheweb.cleanshotx`, Revealable while management is stopped). Their current
single-item keys, owner autosaves and separate non-adjacent AX geometry resolved.
The native sheet was inspected using Accessibility and a screenshot: two selected
applications, actual before/proposed relative order, scoped details and a disabled
Exchange control in read-only mode. No system write capability was created and no
ordering recovery directory or receipt appeared. Raw snapshots, previews and
checksums remain in ignored `LocalData/`.

Final local cleanup verified all eight watched files unchanged (the complete
group, four Blenny policy/backup files and three scoped owner preference files,
including the two preview targets). The original installed app was restored
byte-for-byte at its executable and passed strict signature verification. No
validation process remains. The optional read-only UI window now uses one AppKit
queue deadline outside the Swift task; a final bounded launch printed its deadline
completion and exited normally. This is harness/UI validation, not live ordering
lifecycle acceptance. All 21 files captured from the initial uncommitted research
workspace retain their original checksums.

The installed scan also exercised truthful refusals: the currently Hidden
Snipaste owner is excluded; Usage4Claude's sandbox preference namespace is
unsupported; and the initially eligible AltServer/SwitchResX pair is rejected
when combined because its AX bounding rectangles overlap. No position or identity
predicate was relaxed to make these pairs pass. Revealable eligibility while
management is stopped is a pure policy rule, covered for all six combinations
of intent and management state; Resume restores the swap before activating policy.

The release preparation audit found no forbidden artifacts, private keys, tokens,
personal absolute paths or prohibited attribution in candidate content/reachable
history. The original first commit and all existing refs are preserved. The full
release audit deliberately remains unsuccessful: no 0.9.0 completion commit exists
and the documents correctly retain in-development status pending live acceptance.
No completed version tag, history rewrite, push or publication is authorized.

## Authorized attended acceptance — preflight refused

The owner authorized one Debug product exchange of **AltServer and
CleanShot X**, followed by one exact product Restore of the same pair. Fresh
preflight must still resolve `status:com.rileytestut.AltServer::Item-0` and
`status:pl.maketheweb.cleanshotx::Item-0`, complete single-item owner scope,
unchanged accepted intent and separate geometry. Capture the current configured
values afresh; the proposal does not authorize stale numeric inputs or another
pair. The observed left-to-right order should reverse and then return. No
adjacency or fixed screen coordinate is promised.

Before Apply, preserve the complete group, both owner saved-position sets, current
Blenny control files and installed app. The Debug launch may clear the isolated
manual-trial management-enabled flag as designed; do not Resume or change any
lane during this acceptance. Restore the original Blenny control files and
installation after normal cleanup and exit, without activating their policy.
Observe the real menu bar after Exchange and after Restore; compare complete
group and target position state independently. An apply/verification failure may
perform only its one recorded inverse. Target drift, failed inverse or incomplete
restoration ends the experiment with the receipt retained and no repeated Apply.

The explicit authorization covered this pair and its inverse; historical
Snipaste/Usage4Claude authorization was not reused. The installed Debug app
started with management stopped and valid Accessibility trust. The first
submission exceeded the 60-second review window and was rejected before a
receipt or system write. A newly generated preview reached fresh preflight but
was rejected for changed owner metadata, preferences or item geometry. The
generic error did not identify the changed observation; its cause must not be
inferred from the refusal alone. Neither submission reached the table writer.

The attempt ended without another Apply. Normal Quit exited successfully. The
complete group, both target preference files, the additional read-only rejection
baseline and all four Blenny policy/backup files match their original hashes.
Only the expected stopped-on-launch flag needed local control-file restoration;
no lane changed and Resume was not invoked. The original installed executable
was restored and passed strict signature verification. No active recovery receipt
exists; the empty, unlocked lease file is retained with local evidence and the
previously absent ordering support directory is absent again. Raw evidence remains under ignored
`LocalData/0.9.0-acceptance/`. This is verified preflight refusal and environment
cleanup, **not** successful product swap/Restore acceptance.

A Debug-only diagnostic refinement preserves the rejection predicates and makes
observation drift reasons specific. With `BLENNY_ORDERING_VERIFY_PREFLIGHT=YES`,
the existing read-only dry-run takes one additional snapshot and compares the
preview against it. It creates no writer, performs no delay/retry and exports raw
snapshots only to the caller's local output. A broader owner/display/lifecycle
matrix remains a separate promotion gate even after a successful attended pair
test.

The installed diagnostic candidate returned `equivalent=true` for its two
consecutive snapshots and exited normally with no writer, receipt or preference
changes. That run did not reproduce the earlier observation drift and does not
identify its cause. The original app and eight watched files were again verified
unchanged. Diagnostic regression coverage raises Debug verification to **413 tests
in 41 suites**. All three app bundles rebuild and pass strict signatures; ordering
and the additional diagnostic switch remain absent outside Debug. The previous
ordinary Release **307/31** and optimized-trial **321/32** test results remain the
non-Debug baseline. The release preparation audit still correctly reports the
missing completion commit and incomplete version status; no tag was created.

Distribution moves to **0.10.0**. The first public source/binary release candidate
moves to **0.11.0**, retaining every existing publication, licensing, signing,
notarization, privacy, lifecycle/display, update and recovery requirement.
