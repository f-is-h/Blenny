# Blenny

> A minimal, native menu bar organizer for macOS 27 and later.

> Version 0.12.0 completed as a local experimental milestone on 2026-09-27.
> Public release remains a later milestone after the planned 0.13.0 iteration.

## Current status

Current phase: `0.12.0` complete as a local experimental milestone on 2026-09-27.
The 0.11.0 owner-accepted milestone was completed on 2026-09-25.

The 0.12.0 scope includes self-signed signing continuity, local Sparkle
packaging, startup Resume and Dock behavior, per-item Board capability gating,
and the owner-accepted Build 59 Resume behavior. GamePolicyAgent and Wine
menu extras may disappear during active management and remain read-only.
The disposable admission-trial preference row was removed and verified absent
after System Settings reopened. OS grant revocation and reboot persistence were
not established. See [the release record](docs/RELEASE_0.12.0.md).

Build 15 on macOS 27.0 build `26A428` is the accepted local baseline. The owner
confirms native dragging and Apply work normally, including the previously
regressed system-item drag path. One shared typed drag-source modifier now serves
application and system artwork. Redundant native-overflow state publication no
longer feeds the observed SwiftUI update loop.

Reviewed preview fingerprints are deterministic. Pure within-area swaps change
only the owners whose relative order changes; cross-area changes retain complete
partition validation. API and independent preference-file reads must agree in
both directions. A single exact-file event wait, bounded to 15 seconds, precedes
at most one fresh read after disagreement. No polling or extra write is added.
Five live Applies and three Undos exercised mixed changes, including five actual
settlement waits, and ended with independently verified full-table restoration.
The owner's later accepted configuration and clean Undo receipt remain intact.

Device Control onboarding uses the public prompt with a process-scoped retry
policy. Debug ordering uses an exact layout-file grant and bookmark; eligible
application identity can be corroborated through public code-signing evidence
without requiring access to every owner's preference container. Broader grant
revocation and stable distribution-signature continuity remain unverified.

Ordering remains available only in Debug and the explicitly opted-in optimized
trial. Ordinary Release excludes ordering. Sorting for Siri, Time Machine and
Control Center is deferred; existing three-state capabilities remain unchanged.
For the 0.12.0 system-icon follow-up, Board editing is assessed per observed
item and operation. Exact owner identity and a ready item-specific visibility
target can expose three-state policy; an eligible exact position row separately
controls sorting. Artwork and a recognized name alone confer neither ability.
The installed Debug Build 41 exposes an observed Now Playing item through its
existing target after the Apple-agent exact-ID check; Focus remains read-only.
No new physical Now Playing or Focus mutation was performed in that build.
Weather and Input Menu retain their exact-owner ordering route. The native
overflow arrow has no established writable ordering identity, so fish/arrow
adjacency is not a product guarantee. Accepted explicit Blenny control placement
and its separate Undo retain the 0.10.0 contract.

Clock clicks still cannot open Notification Center while management is active
on the tested formal build. The bounded recheck confirmed the existing native
event gate and produced no compatible fix. The earlier owner-verified trackpad
edge-swipe alternative remains documented; it was not newly tested on every
build. No automatic Stop/Resume workaround is added. See
[Known limitations](docs/KNOWN_LIMITATIONS.md) and the
[technical report](docs/NOTIFICATION_CENTER_TECHNICAL_REPORT_2026-09-12.md).

The future public release retains all outstanding gates: final onboarding and
accessibility review, stable signing and permission continuity, Release ordering
promotion, install/update/uninstall and interrupted-recovery validation, broader
compatibility, license selection, notarization and publication audit. This local
milestone does not satisfy those gates or authorize a push. Version 0.13.0 is
planned for right-click menu productization, Debug feature cleanup, and menu-bar
and application icon replacement. See [the roadmap](docs/ROADMAP.md) and
[the 0.12.0 technical spike](docs/TECH_SPIKE_0.12.0.md).

Local packages identify candidates as `0.12.0 (Build N)`. Build numbers advance
from ignored local state and do not themselves complete a milestone.

## Current product contract

Blenny manages intent at the owning application bundle level. Visible,
Revealable and Hidden remain distinct, and ordinary reveal never includes Hidden.
A selected third-party owner moves with every associated configured ordering key
as one block. Reviewed policy and ordering mutations share one serial writer,
fresh preflight, durable private recovery records, bounded verification and
bounded rollback. Unexpected identity or target drift fails closed.

Successful order changes persist through Stop and Quit; explicit Undo Changes restores
visibility and positions from immediately before the latest successful Apply. Stop and Quit release process-owned visibility
restrictions. Retained preferred positions do not guarantee visibility after
management ends or placement relative to the native overflow arrow.

The saved Resume choice survives normal Quit and is revalidated on the next
launch; explicit Stop stays stopped. A failed startup preflight releases
assertions and requires explicit Resume. The Dock icon is present while the
main window is open and disappears when it closes; the menu-bar control remains
available.

## Document map

- [README.md](README.md) is the concise public-facing project entry point.
- [docs/ROADMAP.md](docs/ROADMAP.md) defines version boundaries and exit criteria.
- [docs/SPARKLE_UPDATES_0.12.0.md](docs/SPARKLE_UPDATES_0.12.0.md) records the
  local signing and update integration and its remaining distribution checks.
- [docs/TECH_SPIKE_0.9.0.md](docs/TECH_SPIKE_0.9.0.md) is the detailed 0.9.0
  contract, evidence record and historical experiment log.
- [docs/HISTORICAL_DEVELOPMENT_NOTES.md](docs/HISTORICAL_DEVELOPMENT_NOTES.md)
  preserves the former dated README narrative.
- [Research/README.md](Research/README.md) indexes unsupported archived probes.

## Historical 0.9.0 development log

The following dated entries preserve intermediate results and superseded pending
items. Use the current status above for the accepted milestone boundary.

On macOS 27.0 build `26A5425a`, the native Clock cannot open Notification Center
while Blenny management is active. The owner accepts this backend conflict as a
known `0.9.0` limitation. The final investigation identifies ControlCenter ignoring
Clock events while an external visibility restriction is active; three bounded
rounds found no compatible replacement backend.
The owner confirms that swiping left from the trackpad right edge still opens
Notification Center while management remains active. Use that gesture on the
tested setup; automatic suspension around Clock clicks is explicitly rejected. See [Known limitations](docs/KNOWN_LIMITATIONS.md)
and [the final technical report](docs/NOTIFICATION_CENTER_TECHNICAL_REPORT_2026-09-12.md).
This acceptance removes this issue as a mandatory `0.9.0` fix; it does not close
the version or authorize distribution, publication, or release.


Latest owner feedback confirms responsive Siri reveal as well as conceal and
Control Center visibility. The owner-requested Debug trial removes only Time
Machine ordinary-reveal settlement waits, retaining exact verification and waited
cleanup. Drag-source retirement now refreshes native registration, with repeated
native delivery handled idempotently. Time Machine interaction is now owner-confirmed;
the three deferred system sorting capabilities and public-release gates remain.
Public-source discussion is pending before version closure.

Latest September 11 scope: Siri, Time Machine and Control Center sorting is
explicitly deferred to a future version, possibly after public release. Their
three-state visibility controls remain available and the UI must state that
sorting is unsupported. Resume/Stop drag continuity, system-visibility latency
and native-arrow placement remain active 0.9.0 follow-up work. The distribution
and public-release gates are unchanged. See [the 0.9.0 spike](docs/TECH_SPIKE_0.9.0.md).

Current verified owner-test archive: `build/ordering-trial/Blenny-0.9.0-time-machine-trial.zip`.
Debug and optimized builds pass 560 tests; ordinary Release passes 315. Actual
interface-model self-checks pass in both test-enabled configurations. Owner testing
of native drag-session refresh remains pending;
native-arrow placement is unresolved. The earlier Siri reveal improvement is
owner-confirmed. No version closure or publication is authorized.

> A minimal, native menu bar organizer designed exclusively for macOS 27 and later.

## Detailed chronological status (historical)

- Project name: **Blenny**
- Development directory: repository root
- Current phase: `0.9.0` is in development: Debug integration of reviewed, recoverable menu-bar slot permutations through the existing serial coordinator. The latest research proves one approved non-adjacent pair on macOS 27 build `26A5425a`; general application, multi-item, display and lifecycle support is not established. `0.8.0` remains the latest completed local milestone. Distribution moves to `0.10.0`; the first public source/binary release candidate moves to `0.11.0`. No push is authorized.
- Document date: 2026-09-11
- 2026-09-10 drag lifecycle artifact: `build/ordering-trial/Blenny-0.9.0-drag-lifecycle.zip` is signed and integrity-verified. Its packaged interface-model check passes with ten watched state files unchanged. The existing installation, previous archive, 21 original research files and history remain preserved; no live sorting or Undo was performed.
- 2026-09-10 drag lifecycle verification: token-bearing transferable identity, current-source resolution, native-session cleanup and delivery-order tolerance pass 549 tests / 50 suites in Debug and optimized builds and 314 tests / 32 suites in ordinary Release, without warnings. A synthetic check of the actual interface model passes repeated post-Apply and cross-area drags in both executables. Native long-hover and repeated-Apply acceptance remain pending.
- 2026-09-10 drag lifecycle regression: the owner reports long-hover drop loss and unavailable same-area ordering after Apply while cross-area moves still work. The installed prior candidate and ready/saved live UI are confirmed read-only. The follow-up aligns exposed drag identity with the layout-bound token, resolves payloads from current model state and scopes cleanup to native sessions. Actual interface-model lifecycle checks and attended retesting are required; prior test counts do not establish a fix.
- 2026-09-09 drag/Undo artifact: the signed optimized candidate is `build/ordering-trial/Blenny-0.9.0-drag-stability.zip`. Packaged read-only validation recognizes the actual stale clean ledger, passes an eight-subject schema 4 preview and fresh preflight, and leaves nine state files unchanged without a writer. Installed application, original research and Git history remain preserved; live drag and Apply/Undo acceptance are pending.
- 2026-09-09 drag/Undo verification: fixed destination geometry and stable drag identity, plus explicitly reviewed supersession of clean stale Undo history, pass 547 tests / 50 suites in Debug and optimized owner-test builds and 313 tests / 32 suites in ordinary Release, with no warnings. Live drag acceptance remains pending; existing installation and system state are preserved.
- 2026-09-09 drag/Undo regression: the owner reports restore-required errors for every new order and unstable or unavailable drag previews. Read-only inspection finds a clean applied schema 3 receipt whose committed positions differ from current configuration, rather than an unfinished write. The follow-up must support explicitly reviewed replacement of stale clean Undo history while preserving an archived ledger and external changes; pending writes remain recoverable. Drag landing geometry and startup availability require a separate fix and manual acceptance. Existing live receipt and system settings are preserved during diagnosis.
- 2026-09-09 controls artifact: the optimized owner-test app (executable SHA-256 prefix `3015dd59`) passes strict signature checks and a read-only schema 4 preview for Weather plus seven system subjects, including Control Center, followed by one fresh preflight. Nine watched state files remain byte-identical; no ordering writer or receipt was created. The new archive matches the packaged executable. The installed preceding build, preceding archive, 21 original research files and Git history remain unchanged. Live Control Center adoption/inverse and arrow/fish adjacency are still outstanding.
- 2026-09-09 controls verification: Xcode 27/macOS 27 SDK passes 538 tests / 50 suites in Debug and the optimized ordering flavor, plus 313 tests / 32 suites in ordinary Release, without warnings. Siri composite-to-policy regressions and conditional Control Center namespace, binary-version, final-scope and Undo tests pass. Ordinary Release still contains no ordering-table literal. These deterministic checks do not establish live Control Center adoption or native-arrow adjacency.
- 2026-09-09 controls follow-up: the owner reports that all currently offered items now sort correctly. This is owner-operated adoption evidence for the presented scope, not a complete per-item inverse or lifecycle matrix. The remaining requests are native-arrow/fish adjacency, Control Center ordering and Siri three-state UI. Siri live composite identities must resolve to their canonical persistent-policy identity rather than falling back to the old manual Hide/Restore controls. Control Center is being added as a conditional build-specific Debug trial, requiring the sole exact BentoBox key, attested host and pinned Apple binaries; its primary-key relationship remains a bounded inference pending owner adoption. Clock remains excluded. Native-arrow adjacency is not yet a demonstrated product capability.
- 2026-09-09 optimized artifact verification: the new app passes strict signature checks and a real read-only schema 4 preview for Weather plus six exact system controls, followed by one successful fresh preflight. All nine watched state files are unchanged; no ordering writer or receipt was created. The archive matches the packaged executable, while the installed prior build, previous test archive, original 21 research files and Git history are preserved. Physical system adoption and inverse remain owner-operated acceptance work.
- 2026-09-09 exact-system revision verification: the Board now mixes whole application owners with six independently bound system controls, and retains the drag source/landing slot until typed data delivery. Xcode 27/macOS 27 SDK passes 531 tests / 50 suites in Debug and the optimized ordering flavor, plus 311 tests / 32 suites in ordinary Release, without warnings. Coverage includes signed-host lifetime and token conflicts, system-only display scope, shared-host sibling preservation, mixed multi-key owners, old-receipt migration, post-policy drift compensation and exact inverse verification. The new optimized owner-test bundle awaits physical system ordering, drag-feel and Stop/Quit acceptance; these checks do not close 0.9.0.
- 2026-09-09 owner acceptance and next revision: the owner reports correct ordering for all third-party items they tested, correct combined area/order changes, and successful Weather/Input Menu ordering without observed anomalies. The remaining drag-release bounce is a UX defect to resolve. The owner confirms that submitted ordering is a user setting and should persist through Stop/Quit; explicit Undo remains separate. The next Debug revision adds exact individual system ordering for Bluetooth, Wi-Fi, Sound, Now Playing, Siri and Time Machine through the existing serial coordinator, as a narrow exception for already identified system controls. This does not enable per-icon control within third-party owners, Clock, native overflow or unmapped modules. New system sorting and inverse remain owner-operated acceptance items.
- 2026-09-09 owner follow-up: the owner reports successful configuration-first ordering for most icons. The follow-up unifies equivalent drag gaps with a translucent icon preview, prepares reviews from fresh configuration, and limits process freshness to participating owners and their collision evidence. Verified commits must remain reported as saved if a later UI refresh fails. Exact Weather/Input Menu owners join Debug ordering lanes; module and shared-host system ordering require separate identity/recovery work and are not yet enabled. No new agent-operated system write or version closure is claimed.
- 2026-09-09 drag follow-up verification: Xcode 27/macOS 27 SDK passes 511 tests / 49 suites in Debug and the optimized ordering flavor, plus 311 tests / 32 suites in ordinary Release. New regressions cover canonical landing gaps, preview-width stability, unrelated process/configuration drift, exact Apple owner eligibility and complete final-write scope including unchanged reviewed owners. A new optimized test bundle is prepared for owner acceptance; the installed prior configuration build remains untouched.
- 2026-09-09 configuration revision verification: Xcode 27/macOS 27 SDK passes 500 tests / 49 suites in Debug and the optimized ordering flavor, plus 311 tests / 32 suites in ordinary Release. This includes whole-owner multi-key plans, missing visual evidence, free lane insertion, repeated commits, partial failure, ambiguous receipt persistence, Stop races, external drift, exact policy/backup compensation and crash recovery. The optimized manual-test build is prepared separately; the active installed exchange build is preserved. The 21 original research files remain byte-identical. New installed adoption and native-arrow placement remain unverified; 0.9.0 is not closed.
- 2026-09-09 product direction: replace the restrictive exchange-session model with configuration-backed ordering across all three areas. Free insertion within and between lanes produces a reviewed global Hidden → Revealable → Visible order. AX overlap, missing visual positions, enabled management and empty owner autosave records are not, by themselves, reasons to reject a uniquely attributable configuration change. Include every associated key of each selected owner as a block; never select only one convenient icon. Verify exact configuration independently from optional visual evidence. Successful committed positions persist through Stop/Quit, with explicit undo; unfinished writes remain recoverable. Native-arrow anchoring and continued invisibility after releasing management are not established. This decision supersedes the earlier narrow scope and restore-between-every-change rules below; implementation and new acceptance are in progress.
- 2026-09-09 owner result after overlap relaxation: the owner reports normal ordering among the four offered applications, and read-only inspection confirms the new candidate is installed. The latest WeChat/Usage4Claude receipt is archived as restored, with no active ordering receipt. Coverage diagnosis finds eight additional third-party owners excluded only by the enabled-management scope rule, with seven other third-party owners limited by lifetime, autosave identity, multi-key scope or position evidence. These are explicit productization gaps; no broader compatibility or version closure is claimed.
- 2026-09-09 overlap decision: at the owner’s request, remove zero-overlap and frozen-dimension requirements from the ordering observer. The product verifies relative order using agreeing horizontal edges in a common vertical band, with no overlap-size threshold. Indistinguishable equal/nested proxy frames, unknown identity and incomplete owner scope remain unsupported. OS rendering is not controlled by Blenny; fresh identity/configuration checks, serial writes and exact recovery remain required. Debug and optimized configurations each pass 463 tests / 45 suites; the optimized candidate was built and signed, then subsequently found installed as recorded above. These checks do not establish additional live application compatibility.
- 2026-09-09 integrated Board follow-up: the owner requested initial observed ordering and same-area insertion in the existing Organize Board, alongside cross-area policy moves, replacing the separate exchange editor. The implementation preserves bounded reviewed writes and one outstanding recoverable trial order. Normally launched app preference-read failure must be diagnosed independently from successful development-context reads; failed ordering reads must preserve the Board's applications. The normal-launch failure is an App Data permission denial; the Board now retains applications and exposes its concrete cause. Collapsed native-overflow proxy geometry is explicitly unverified. The integrated core passes 456 tests / 45 suites in both Debug and optimized configurations; installed three-owner read-only preflight passes with no writer. A later owner screenshot confirms normal-launch ordering reads now succeed; live insertion acceptance remains pending.
- 2026-09-08 expanded manual-test scope: at the owner's request, broaden the optimized ordering trial to fully observable third-party single-item owners across all intent groups while management is stopped, and positively corroborated standard sandbox preference containers. While management runs, only Visible intent is eligible. Restore still precedes Resume, Hidden remains excluded from ordinary Reveal, and incomplete owners, system items, unresolved identities and overlapping pair geometry remain unsupported. Both Debug and optimized trial pass 430 tests / 42 suites. The installed read-only scan finds 15 eligible owners, and a Snipaste/Usage4Claude preview plus fresh preflight passes without a writer or receipt. Expanded compatibility requires new owner-operated evidence; earlier successes do not prove it.
- 2026-09-08 owner result: in the optimized ordering trial, the owner reports successful exchanges among the four presented applications except AltServer/SwitchResX Daemon, which is refused at Preview Exchange for non-separate geometry. The last AltServer/CleanShot X receipt records verified restoration; read-only comparison confirms no active receipt, the complete group matches the pretrial contents, and both target owner-position sets match that receipt. Per-combination attended restoration confirmation remains pending. This is product-path evidence, not universal compatibility or version closure.
- 2026-09-08 manual testing build: the owner requested a Release-configuration ordering binary. The explicit `BLENNY_ORDERING_TRIAL=YES` build uses optimization while retaining the existing Debug capability gates, isolated stopped-on-launch policy and exact recovery contract. This owner-test flavor is not ordinary Release promotion or version completion.
- 2026-09-08 earlier automated acceptance attempt: the owner authorized an AltServer/CleanShot X exchange and inverse. Both automated submissions were refused before writing (expired review window, then changed owner observation). No product ordering write or active recovery receipt resulted from that attempt; the original installation and all eight watched files were verified restored. The subsequent owner-operated results are recorded above; version closure remains pending.
- 2026-09-06 closure: the owner confirmed Siri, Time Machine and Now Playing
  hidden states and then manually restored all three. Read-only post-restoration
  checks found no recovery receipt, an absent Now Playing current-host key, the
  exact Time Machine menu-extra path, `VisibleCC = true` and preferred position
  86. The four isolated/production policy and backup hashes became the accepted
  restored baseline. Final Xcode 27 verification passes 370 Debug tests / 37
  suites, 307 ordinary Release tests / 31 suites and 321 optimized-trial tests /
  32 suites. All three arm64 app bundles build and pass strict signature checks.
  The final optimized trial executable is installed at `/Applications/Blenny.app`
  with SHA-256 `8795e401166f8efb5ab7e19a19d25aeff420340db1fe4e49f07ee55262e37768`;
  a stopped startup created no receipt and changed no preference or policy hash.
  Ordinary Release still strips the wider trial route.
- 2026-09-04 follow-up: local lifecycle fixes preserve accepted bundle intent across application launch/quit, use accepted rather than unapplied Draft scope, and present confirmed unrestricted cleanup as a neutral pause. The owner authorized bounded, event-triggered additions to the pass-through allowlist through the existing serial writer. A fixed 250 ms batch coalesces new bundle identities; known identities do not write, accepted Hidden/Revealable and system-item allowances are unchanged, and existing reveal deadlines are preserved. No polling, drift-repair loop, preference write or retry is added. Installation and observed performance validation remain pending. System API research continues only on macOS 27, with concrete Now Playing packed preferences and Siri stash restoration semantics recorded in the 0.8.0 identifier report.
- Product status: the AppKit-hosted SwiftUI product connects reviewed Drafts to one runtime-gated serial writer with bounded verification, transactional persistence, rollback, Stop, Restore, ordinary Reveal and lifecycle cleanup. The installed owner trial is an optimized Release-configuration flavor with the explicit trial gate; ordinary Release keeps the Bluetooth-only system policy boundary.
- Source lineage decision: clean implementation, not an Ice fork
- License decision at this historical checkpoint: pending; superseded by the
  current deferral of license adoption to 0.10.0 above
- Repository decision: one canonical repository; private until source and binary become public together with the first `0.11.x` release candidate

The owner-operated optimized trial Board exposes the eight exactly mapped
assessment items except Clock, the exact Weather/Input Menu owners, and the
dedicated Siri, Time Machine and Now Playing identities. All use the same Draft,
Review, Apply and Visible / Revealable / Hidden presentation even though their
backend capabilities differ. One coordinator serializes assertion replacement
and persistent writes as a single logical transition. The isolated trial policy
starts stopped on each launch. No polling, synthetic input, automatic
reconciliation or timed rollback is added. Bluetooth remains the only ordinary
Release promotion; the wider capabilities remain isolated in the optimized
owner-trial flavor.

The owner confirmed successful hide/show for Bluetooth, Wi-Fi, Control Center,
Sound, Weather and Input Menu, plus hidden-state and exact-restoration behavior
for Siri, Time Machine and Now Playing. Clock remains excluded. See
`Research/0.8.0/REMAINING_ITEMS_VALIDATION.md`.

- 2026-09-05 Debug trial: the exact dedicated owners
  `com.apple.weather.menu` and `com.apple.TextInputMenuAgent` are editable
  application-level candidates. No other Apple bundle exception exists. After
  the host updated to build `26A5425a`, an excluded read-only probe confirmed the
  unchanged MenuBarClientCore UUID, all six required Objective-C encodings and an
  in-memory configuration round trip. Only Debug admits the new build; Release
  remains gated to the previously validated build. Debug 345/35 and Release
  296/30 tests, both app builds, signatures and an installed no-writer dry-run
  pass. The running installed Debug app starts stopped for owner testing.

- 2026-09-05 owner result and shared-host follow-up: Weather and Input Menu both
  hide and reappear normally through their exact Debug bundle policies. Their
  Board presentation now uses semantic system symbols (`cloud.sun` and
  `keyboard`), independent of the application-level control identity. A bounded
  AX sample shows Siri and Time Machine under the same `com.apple.systemuiserver`
  owner, making owner-bundle assessment unsafe for either item. Current-user /
  any-host reads resolve Siri's two exact keys and Time Machine's ordered
  `menuExtras` membership plus status-item metadata. The product-excluded shared
  item plan passes 15 pure checks in both optimization modes and performs five
  reads with zero writes or notifications. A later Debug-only implementation uses
  Apple's exact per-item controller accessors behind a build gate, one serial writer,
  mode-0600 receipts, one verification and compare-before-restore. At the owner's
  request, an optimized Release-configuration trial flavor was tested and installed
  at `/Applications/Blenny.app`; normal Release still strips the entire route. The
  installed flavor performed only startup reads and has not executed a live hide.

- 2026-09-05 optimized-trial correction: the first Release-configuration trial
  accidentally included only the new Siri/Time Machine panel while retaining the
  ordinary Release Board's Bluetooth-only catalog. The corrected dedicated flavor
  includes all eight exact manual numbered controls, the Weather/Input Menu owner
  exceptions, their validation/planning path, the current-build runtime gate and
  the isolated stopped-on-launch manual store. Debug 349/36, ordinary Release
  296/30 and optimized trial 300/31 pass. The corrected executable hash is
  `46cb5788a...`; it is running from `/Applications/Blenny.app`. Startup changed no
  production/manual policy or backup hash and created no shared-item receipt.
  Ordinary Release remains Bluetooth-only; this is not a promotion.

- 2026-09-05 system-presentation correction: Weather/Input Menu are visually in
  the macOS group and use natural-aspect SF Symbols while preserving their exact
  bundle-level writer identity. Exact Siri/Time Machine Board observations expose
  the dedicated Hide / receipt-backed Restore route, not three-lane assertion
  policy. Time Machine's known AX identifier survives absent localized text. The
  unreadable count opens the exact bundle/error list and still creates no
  candidate. Debug 351/36, ordinary Release 297/30 and optimized trial 302/31
  pass; installed hash `b6083ea8...`, PID 41358, with no startup mutation.

## Historical design record

The numbered sections below preserve the original product investigation and
architecture narrative. Statements framed as proposals, future work or earlier
version boundaries are historical where they conflict with the current status,
0.9.0 spike or roadmap above.

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

Project website: <https://blenny.fi5h.xyz>.

Stable application bundle identifier: `xyz.fi5h.blenny`. Local policy and recovery documents created by the earlier development identifier `com.example.BlennyProbe` are migrated in place through a bounded, deterministic identity replacement. The migration preserves the assigned policy and management state, updates the accepted document and its one scoped backup without rotating recovery history, is idempotent, and fails closed on an identity collision.

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

Ice is GPL-3.0-or-later and was developed as an independent Swift macOS application.

Important legacy techniques in Ice include:

- Creating divider `NSStatusItem` instances.
- Expanding a divider length to approximately `10,000` points to push status items out of view.
- Enumerating menu bar item windows using private CGS/SkyLight functions.
- Reordering by synthesizing Command-modified mouse events.
- Capturing status item imagery and presenting it in a separate Ice Bar.

These techniques were inventive and useful on older systems, but they are fragile around dynamic items, app relaunches, multiple displays, notches, system reflows, and macOS 27's new architecture.

### 6.2 Thaw

Thaw began as a fork of Ice and remains GPL-3.0-or-later.

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

The owner prefers Apache License 2.0, but has deferred license adoption,
repository notices and app resource packaging until after the 0.10.0 interface
review. The 0.9.0 Git tree does not include LICENSE or NOTICE; local drafts may
remain untracked and excluded. Referenced third-party projects retain their separate
licenses; this does not permit copied implementation code.

## 8. Product scope

### 8.1 Proposed user model

Blenny's ordinary management unit is an owning application bundle, not an individual status-item instance. Every status item exposed by the same third-party bundle inherits one policy; Blenny does not offer per-icon control within one app. Bluetooth is the sole separately identified Apple system-item policy candidate validated for macOS 27.

Each manageable application has one of three effective states. A newly observed application is effectively Visible without adding a persistent policy entry; persistence records only explicit user intent. The names are deliberately distinct from Accessibility's `AXHidden` attribute and the native overflow control's collapsed state:

1. **Visible** — Blenny does not deliberately conceal the bundle. macOS remains free to place it in native overflow when space is limited.
2. **Revealable** — keep normally concealed through Blenny's bundle-level visibility policy, then include it only during a user-initiated reveal session.
3. **Hidden** — keep excluded from ordinary reveal sessions; it must still be discoverable and temporarily recoverable from Blenny's main interface, with a global shortcut as a possible later convenience.

The settings interface presents these as three horizontal lanes. `Visible` is an allow state, not a fixed position or a guarantee that an item remains physically present in the collapsed menu bar.

Current Apple system items with stable Accessibility observations appear in the Board. The completed 0.8.0 installed validation promotes only Bluetooth raw value `1` / `com.apple.menuextra.bluetooth` into Visible, Revealable and Hidden intent. The owner confirmed that native overflow absence in the applied sample was normal active-application reflow: switching applications restored it while Bluetooth remained hidden. Independent recovery matched exact AX state, semantic preferences and file hashes. Wi-Fi, Battery, Clock, Control Center and native overflow remain immutable and visibly read-only. A private/AX mapping by itself remains insufficient promotion evidence for any other item.

Revealable and Hidden are not two different low-level hiding mechanisms. Both use the reversible bundle-level concealment path validated by the spike. The difference is which bundles Blenny admits into an ordinary reveal session.

When the native overflow control is already present and its state transition can be observed safely, Blenny may treat the user's native expand/collapse action as the reveal-session trigger. Hard concealment can free enough width that the native control disappears; in that state Blenny must provide its own separate, normally installed status-item control. Blenny must not synthesize a click on, overlay, replace, or claim ownership of Apple's control.

Opening an ordinary reveal session includes Revealable bundles but not Hidden bundles. Closing it returns Revealable bundles to the concealed baseline. Hidden bundles require a separate, explicit recovery surface so that no policy makes them practically unreachable.

The system remains the source of truth for the currently rendered layout. Blenny remains the source of truth for user intent.

### 8.2 Incremental product sequence

Blenny develops through small, independently reviewable product increments. A roadmap entry records the current product judgment; it is not an obligation to preserve an earlier planning suggestion when the product has not reached that need.

- `0.1.0` established the minimal text-first AppKit interface and deterministic review boundary.
- `0.2.0` replaces text-dominant candidate presentation with installed application icons obtained through public AppKit/Workspace APIs, semantic system symbols keyed by stable observation identifiers, and an explicit shared fallback. Blenny's v12 color application artwork is packaged as the bundle icon, while its detailed menu-bar vector master remains a design source and its bundled monochrome template SVG remains a separate 18-point optical-size production asset for the app's own status item. Icon descriptors remain presentation-only and do not add drag-and-drop or system mutation.
- The local `0.2.0` application adopts the stable `xyz.fi5h.blenny` identity associated with <https://blenny.fi5h.xyz>; only the former Blenny self-identifier is migrated, and no third-party policy identity is guessed or rewritten.
- `0.3.0` establishes the main product interface before adding another interaction model. After comparing four materially different single-window directions and reviewing the installed result, the owner selected symbol-and-label navigation in one fixed-height band below the title bar, compact horizontal lanes with tightly spaced borderless icon cells, one read-only marker for the macOS subsection, one unified missing-permission overlay, and an anchored manual-observation footer whose idle Refresh action can recheck externally granted permission. Active refresh uses the same lane-level interruption pattern with a clear bounded-progress overlay, and navigation has no persistent focus outline. Organize uses the wide retained-window presentation needed by the horizontal lanes and places its privacy/reliability promise directly below the macOS placement note. Settings and Support use one stable narrower width in that same top-left-anchored window and retain fixed top insets. Settings contains real Permission and native Open at Login controls rather than an explanatory Observation card; Service Management remains the sole login-item source of truth and adds no helper or IPC. Support separates the project website from the donation group, then presents Sponsor once, Sponsor monthly, and Ko-fi in that order; GitHub links carry `metadata_project=blenny`, while checkout, payment, and benefits remain with the external providers. The three normal destinations fit without page-level vertical scrolling. AppKit retains lifecycle, status-item, window, Workspace, Service Management, and Accessibility infrastructure; one SwiftUI hierarchy owns all visible Organize, Settings, Support, and in-window safety Review content. Organize deliberately exposes no temporary assignment or draft-creation path before dragging exists, without changing any policy boundary or core semantic. The stopped-management row remains a truthful transitional view of the disabled persisted state; the later reviewed management loop should remove it from routine use once ordinary always-on behavior exists, while retaining deliberate safety and restoration actions.
- `0.4.0` consolidates the three policy lanes into one continuous Organization Board and adds native cross-lane assignment for editable application bundles. Names are hidden at rest and appear without reflow for hover, focus, or selection; a stable selection rail, context menu, and VoiceOver actions provide the complete non-drag path. Native drag sessions use short interruptible system motion, source and destination feedback, and Reduce Motion fallbacks. Each accepted move changes only `BundlePolicyDraft`; conditional Review Changes and Discard Draft preserve the existing preview, persistence, assertion, and recovery boundaries. A newly granted Accessibility permission triggers exactly one bounded read-only refresh when Blenny becomes active; later observation remains manual with no polling. Blenny stays locked Visible and Apple system observations stay read-only.
- `0.5.0` closes the reviewed end-to-end management loop on the supported development build without broadening system-item scope. It removes the ordinary Review page at the owner's request, keeping plan preparation, safety checks, bounded diagnostics and atomic recovery internal. Apply starts management; Stop preserves an unapplied Draft. A smaller double-chevron button sits left of the artwork/editor button as two compact 22-point native status items, with right-click safety access. The arrow remains available throughout verified management and ordinary reveal, independently of native overflow presence. The arrow and menu toggles share one action; the artwork has a separate native editor action. Native-control integration and missing-application discovery, including the reported Bartender issue, are deferred to 0.6.0 by owner decision. Session timeouts share the interaction gate, and Refresh stays read-only after initial recovery. No polling or placement write is added.
- `0.6.0` completes the owner-accepted native overflow investigation on macOS 27.0 build `26A5416b`, arm64, one display. Startup with and without native overflow, steady-state coordination, runtime first appearance without an intervening Blenny click, and fallback return are owner-observed successes. Canonical-root topology subscriptions and one coalesced post-activation read remove the discovery dependency on Blenny writer completion. Hide the fallback arrow only for a single known registered native control, restore it when unavailable or ambiguous, and retain the fish, explicit safety-menu action, and fixed allocation against layout feedback. Coffee Buzz discovery, ownership and icon presentation succeed without granting mutation authority. Lifecycle/display safety invalidation is implemented and deterministically tested; broader installed compatibility remains an explicit carry-forward gate, not a completed matrix. No interception of Apple's button, new authorization, Release backend promotion or ordering is implied.
- The original `v0.7.0` tag records the separate real physical menu-bar ordering feasibility investigation with a no-go for implementation on the inspected runtime. SDK 27, current scoped AX and runtime metadata, and historical preference experiments do not establish an exact reversible arrow-relative ordering contract. The desired fish position near the native arrow's right edge and revealed Revealable items to its right remain unimplemented guarantees. Product source, Board behavior, native integration, policy, writer and artwork stay unchanged. No position write is performed; tests, both builds and installed no-writer regression pass with unchanged policy/backup hashes and zero scoped preferred-position restore operations. Reopening requires stable owner/instance identity, exact snapshot/write/inverse semantics, deterministic serial failure/restoration tests, installed dry-run and separate exact-target authorization. No synthetic input, Board-only sorting, reconciliation or Release backend promotion is permitted.
- Post-tag presentation correction: each explicit user Reveal may run one bounded Blenny-owned fallback ladder. A usable native overflow control first removes the fallback status item entirely. If native overflow disappears, Blenny recreates a contentless zero-length transition; if that also fails, the fixed 22-point fallback returns and automatic layout events cannot retry. A later explicit Reveal may begin a fresh ladder. This performs no ordering or system write and cannot oscillate without a new user action. Event-driven confirmation can leave a brief empty transition between system rendering and AX notification; Blenny does not preemptively remove the only reveal control before native ownership is confirmed.
- `0.8.0` closes the Apple system-item visibility investigation on the exact macOS 27 development build and promotes Bluetooth only to ordinary Release. The optimized owner trial unifies Visible / Revealable / Hidden across numbered MenuBarClientCore items, exact Weather/Input Menu owners, and item-scoped Siri/Time Machine/Now Playing transactions. The single coordinator serializes all mutation; item receipts preserve exact inverse state and bounded target-local Time Machine normalization. The owner validated every capability family and manually restored Siri, Time Machine and Now Playing. Final read-only comparison found no receipts and matched the accepted preferences and four policy/backup hashes. Clock, native overflow and identities without complete descriptors remain read-only. The same milestone corrects startup recovery so an approved dormant bundle does not force inactive management, consolidates multiple owner PIDs at bundle scope, and admits new harmless bundle identities through a bounded additions-only event batch. Details are in `docs/TECH_SPIKE_0.8.0.md`.
- `0.9.0` integrates reviewed real ordering in Debug through the existing serial coordinator. The initial capability swaps the existing positions of two uniquely corroborated, observable single-item application bundles on the exact tested runtime and one display, with snapshots, preview, durable recovery, bounded verification and explicit Restore. Multiple items, missing configured inputs and unknown identities remain unsupported. Visible intent is eligible; Revealable is eligible only while management is disabled, and Hidden is always excluded. Resume first restores an outstanding exchange. No absolute-coordinate or native-arrow anchor is promised. See `docs/TECH_SPIKE_0.9.0.md`.
- `0.10.0` inherits the complete distribution prototype, retaining signing, notarization, installation, compatibility-disable, privacy and recovery requirements.
- `0.11.0` is the first public release-candidate line, retaining all publication gates.

### 8.3 Explicit non-goals through version 1.0

- macOS 26 or earlier support.
- Menu bar tinting, borders, shadows, gradients, or custom shapes.
- Theme marketplace or extensive visual customization.
- Multiple profiles.
- Focus, Wi-Fi, battery, app-launch, or schedule-based rules.
- Status-item hover, scroll, swipe, and empty-space gesture variants.
- Live status-item screenshot capture by default.
- Continuous high-frame-rate thumbnail refresh.
- Automatic migration from Ice, Thaw, or Bartender.
- Dozens of advanced settings.
- Any implementation that moves the user's cursor.
- Independent identification, ordering, or hiding of multiple status items from the same application bundle.

## 9. Proposed architecture

Keep product logic independent from unsupported system mechanisms.

```text
BlennyApp
├── StatusItemController
├── PolicyEditorWindowController (AppKit shell)
├── BlennyRootView (SwiftUI product interface)
├── AccessibilityInventory
├── PolicyIconResolver
├── NativeOverflowObserver
├── ItemIdentityStore
├── MenuBarPolicyEngine
├── MacOS27LayoutBackend
├── RestoreCoordinator
└── ShelfPanel (optional after validation)
```

### Responsibilities

`StatusItemController`

- Own only Blenny's native status items, with independent arrow and artwork actions.
- Present a minimal menu or settings surface.

`PolicyEditorWindowController` and `BlennyRootView`

- Retain one closable, resizable AppKit product window hosted through `NSHostingController`.
- Present Organize, Settings, and Support inside one SwiftUI hierarchy; prepare and validate safety actions internally without an ordinary Review page.
- Keep the three horizontal policy lanes and icon-first cards as the primary interaction surface.
- Project model state into explicit component enablement without changing policy, persistence, diff, report, recovery, or fingerprint semantics.

`AccessibilityInventory`

- Enumerate menu bar items without mutating them.
- Attribute items to their owning app or `MenuBarAgent`.
- Collect candidate identity attributes and frames.
- Keep identifiable Apple system items visible as read-only presentation records rather than editable bundle candidates.

`PolicyIconResolver`

- Resolve application presentation from the owning bundle's installed icon without changing policy identity.
- Map stable, known Apple system-item observations to semantic system symbols.
- Produce an explicit generic fallback when no trustworthy icon source exists.
- Never require Screen Recording, capture live menu-bar pixels, or persist icon image bytes as policy data.

`NativeOverflowObserver`

- Observe native overflow presence and known expand/collapse edges within the validated development boundary.
- Route eligible edges through the ordinary reveal coordinator; never authorize bundles, write directly, or claim broader per-display support from an AX snapshot.
- Retain canonical extras-root topology subscriptions without requiring an overflow child, and perform one coalesced read after application activation. Discovery and registration do not depend on a Blenny write and do not authorize one.
- In 0.6.0, eligible layout/value edges exclude own-write reflow. A successful absent snapshot followed by one newly expanded control on a layout event can establish the first runtime handoff. Transient presentation loss hands an existing reveal to Blenny without another assertion or a renewed deadline; lifecycle/permission loss still restores through the writer. The owner accepted steady-state and runtime first-appearance coordination on the recorded single-display runtime. Broader compatibility remains unverified; an AX edge is not proof of intercepted input.

`ItemIdentityStore`

- Persist user intent using the most stable available identity.
- Never use PID, transient window ID, image bytes, or current x-coordinate as the sole permanent identity.

Candidate identity components:

- Owning bundle identifier as the persisted policy identity.
- A migration strategy when an app changes its bundle identifier.
- `NSStatusItem` autosave/preference identifiers, Accessibility identifiers, stable labels, and role/subrole only as diagnostic observations or backend key-resolution hints.
- An explicit many-observations-to-one-policy mapping when one bundle exposes multiple status items.

`MenuBarPolicyEngine`

- Convert Visible/Revealable/Hidden user intent into deterministic baseline and reveal-session states.
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
- Apps with multiple status items, as a compatibility check that every item receives the same bundle-level policy; independent per-item behavior is out of scope.
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

Blenny's in-app GitHub Sponsors links use the cross-project transaction-attribution schema in a fixed order after `frequency`: `metadata_project=blenny`, `metadata_source=app`, and `metadata_placement=about`. They omit `metadata_lang` because the URLs are application literals rather than localized document or website links. The frequency selects only the initial one-time or recurring view; GitHub retains the metadata if the sponsor changes frequency or tier.

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

## 17. Historical immediate actions

The 0.5.0 failed-startup follow-up distinguishes saved enabled intent from actual
management: explicit Resume rechecks current targets and runtime, then activates
an unchanged accepted policy without a persistence write or backup rotation.
Missing managed apps are named; no target is silently removed. Refresh remains
read-only, and connection loss still requires a new process.

Version `0.6.0` closes the native-integration investigation accepted by the owner
on 2026-08-31. The final discovery repair registers a newly appearing native
control without waiting for a Blenny operation; eligible observed state edges
then drive the existing ordinary-reveal coordinator and serial writer. The
first-appearance failure is accepted as resolved on the recorded runtime, not
as a promise to intercept Apple's button or support every display configuration.
Coffee Buzz discovery and its later explicit policy assignment remain separate.
Installed dry-run, bounded real baseline cleanup, unchanged policy/backup checks
and owner visual acceptance have distinct evidence in `docs/TECH_SPIKE_0.6.0.md`.

Version `0.7.0` closes the separate ordering investigation without cross-app
ordering. Blenny gives the ordinary fish a stable AppKit autosave identity and,
when one usable system overflow control is observed, explains the user's native
Command-drag placement. macOS owns the saved order; fixed arrow-relative placement
and Revealable-item ordering remain unsupported. Broader lifecycle/display checks
remain mandatory before expanding compatibility or promoting the unsupported
backend to Release.
Relevant lifecycle changes revoke the frozen context and require explicit fresh
Resume, never automatic reconciliation. Preserve existing history and tags; do
not push.

Version `0.8.0` isolates and closes the Apple system-item visibility question.
Owner-authorized Debug assertions proved that omitting Bluetooth raw value `1`
hides it. The final owner-observed run established that native overflow absence
was ordinary active-application reflow, not loss of the protected item; switching
applications restored it. Independent RECOVER matched exact state, preferences
and file hashes. Bluetooth is promoted to formal policy and Release; every other
Apple item remains read-only.
The current 0.9.0 work integrates the September 8 ordering result under the
explicit scope and acceptance gates in `docs/TECH_SPIKE_0.9.0.md`. Distribution
is deferred to `0.10.0` and the first public release candidate to `0.11.0`.
The Clock/Notification Center conflict on the recorded runtime is an accepted
known limitation for 0.9.0. The owner-verified current workaround is a left swipe
from the trackpad's right edge; automatic Stop/Resume around Clock clicks is
rejected. This decision supersedes the earlier mandatory-fix gate for that one
issue and does not waive any other version or publication gate.

## 18. Current next action

Complete the checks tracked in
[the 0.9.0 release record](docs/RELEASE_0.9.0.md): finish every required build and
test configuration, verify the current system is restored without undoing the
owner's accepted order, reconcile version documents and create the authorized
local annotated tag. Distribution, publication, repository visibility changes
and pushes remain outside this milestone.
