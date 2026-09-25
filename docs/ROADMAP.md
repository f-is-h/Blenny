# Blenny roadmap

Version 0.11.0 completed the owner-accepted local permissions and interaction
stability milestone on 2026-09-25, on macOS 27.0 build `26A428`. Build 15 native
dragging and Apply are owner-accepted; repeated mixed Apply/Undo runs verify the
preference-settlement fix. See [the release record](RELEASE_0.11.0.md).

Version 0.12.0 is the next public source and signed-binary candidate. Every
outstanding distribution gate remains required. Ordering stays in Debug or the
explicitly opted-in optimized trial; ordinary Release excludes it. Siri, Time
Machine and Control Center ordering, native-arrow adjacency and the documented
Clock/Notification Center conflict remain unresolved boundaries.

Blenny advances by verified exit criteria, not by elapsed time or commit count. Versions before `1.0.0` may use unsupported macOS behavior and are not compatibility promises.

## Versioning rules

- `0.0.x` versions are private engineering-foundation milestones. They may add bounded experimental capability, may be Debug-only, and are not public releases.
- `0.y.0` versions beginning with `0.1.0` introduce a coherent pre-release product capability built on the validated engineering foundation.
- `0.y.z` patch versions after a `0.y.0` milestone contain fixes and compatibility updates without expanding that milestone's scope.
- `0.12.x` versions are the first public, open-source release candidates. Source and signed binaries ship together.
- `1.0.0` begins the stable product contract and published macOS compatibility policy.
- A version advances only when every required exit criterion is verified and restoration is complete.
- An explicitly scoped safety-feasibility investigation may close with an evidenced no-go; that does not mean the proposed feature or its implementation gate passed.

## 0.0.1 — Technical feasibility spike

Status: **Complete on macOS 27.0 build `26A5416b`.**

Exit criteria met:

- Enumerate useful third-party status-item ownership and identity data through Accessibility.
- Observe native overflow without continuous polling.
- Keep a normally installed Blenny control visible during a private visibility restriction.
- Hard-hide and reveal an approved third-party bundle without moving the cursor.
- Replace allowlists through one serial writer with no deliberate unrestricted gap.
- Complete repeated reveal/conceal transitions without visible flicker or perceptible delay.
- Restore through explicit invalidation and process-disconnect cleanup.
- Preserve clock, Notification Center, Control Center, and native overflow in completed recovery checks.
- Keep unsupported mutation code isolated from product targets in clearly warned research probes.

Not a deliverable: no distributable app, stable bundle identity, onboarding, settings editor, or product backend.

## 0.0.2 — Revealable group technical prototype

Status: **Complete on macOS 27.0 build `26A5416b`.**

Exit criteria met:

- The installed custom control and visibility-restriction code live in a narrow Debug-only `MacOS27` backend promoted from the isolated research probe.
- One actor or equivalent serial writer owns every assertion transition.
- The experiment is limited to the Revealable group: approved Revealable bundles are hard-concealed at baseline and admitted only for a bounded user-initiated reveal session.
- When the native overflow control is present, its observed expand/collapse transition can drive that session without intercepting or synthesizing input.
- When the native overflow control is absent, Blenny's normally installed status item supplies a stable reveal/conceal control without modifying another application's menu or status item.
- The native and Blenny-owned controls never create a state in which the Revealable group has no usable reveal affordance.
- Ending either reveal path deterministically restores the concealed baseline without visible flicker, an unrestricted gap, polling, or continuous reconciliation.
- Visible, Revealable, and Hidden remain distinct bundle-level policy inputs; ordinary reveal sessions never include Hidden bundles. The fully Hidden recovery UI and shortcut are not implemented or mutation-tested in `0.0.2`.
- Any separate policy writer uses a point-to-point, session-scoped local channel that authenticates the requesting Blenny component's code identity, rejects untrusted or stale commands, and cannot accept arbitrary allowlists from a client.
- The backend fails closed when private classes, selectors, or expected encodings differ.
- Normal quit, helper disconnect, failed replacement activation, rejected peers, and replayed or out-of-order commands restore or remain safely unchanged in automated or bounded integration tests.
- No polling or reconciliation loop is introduced.

## 0.0.3 — Real Revealable and Hidden coexistence

Status: **Complete on macOS 27.0 build `26A5416b`.**

Exit criteria met:

- One bounded Debug-only session applies three distinct real bundle-level assignments at once: installed Blenny is Visible, Usage4Claude is Revealable, and CleanShot X is Hidden.
- The exact owning bundle identifiers, running processes, and menu-bar ownership of both third-party targets are established read-only before mutation. The milestone fails closed if the Revealable and Hidden identifiers are equal, overlap another policy, are absent, or cannot be attributed unambiguously.
- Baseline admits Visible, hard-conceals Revealable, and hard-conceals Hidden.
- An ordinary reveal session admits Revealable while continuing to exclude Hidden, regardless of whether the observed native overflow or the installed Blenny fallback owns the session.
- Conceal returns Revealable to the hard-concealed baseline while Hidden remains hard-concealed.
- Native overflow is preferred when it is present and observable. Blenny's reveal action is then unavailable, while the Blenny status item remains present as a diagnostics and recovery entry and may mirror native presentation with a non-writing status arrow.
- Installed Blenny owns the fallback only when native overflow is unavailable. A fallback-owned session remains stable until it ends even if revealing causes native overflow to appear.
- There is never a state with no usable reveal entry or two simultaneously actionable entries for the same session, and AX event duplication or reordering cannot create a write loop.
- Every replacement activates before the preceding safety assertion is invalidated. A failed reveal preserves the concealed baseline; a failed conceal performs complete restoration rather than retaining a stale restriction.
- The 30-second reveal-session timeout, five-minute experiment timeout, normal exit, failed activation, connection invalidation, and process disconnect restore both real targets without restarting MenuBarAgent.
- Debug and Release builds and all deterministic tests pass with Xcode 27. Release contains no private backend, real-write switch, or Debug validation UI.
- The exact dry-run and bounded real-run evidence, user visual observations, transition latency, entry ownership, restoration, and final system state are recorded in `docs/TECH_SPIKE_0.0.3.md`.

Not included: policy persistence, a formal Hidden settings or recovery UI, shortcuts, login launch, updating, or distribution work.

## 0.0.4 — Persistent policy prototype

Status: **Complete on macOS 27.0 build `26A5416b`.**

Advance when:

- Bundle-level policies persist across Blenny relaunches.
- Installed-app relaunch and update-like replacement preserve identity and control visibility.
- Unknown or ambiguous bundles are reported rather than guessed.
- A dry-run and explicit “Stop Managing and Restore” path are available.
- Backups contain only scoped menu-bar state and never enter Git.

## 0.0.5 — Policy editing core

Status: **Complete on macOS 27.0 build `26A5416b`; closed at annotated tag `v0.0.5`.**

Advance when:

- A UI-independent draft model supports bundle-level `Visible`, `Revealable`, and `Hidden` assignments without per-status-item scope.
- Every proposed edit produces a deterministic old-to-new policy diff and dry-run impact report before persistence or system mutation.
- Invalid, overlapping, unknown, missing, or ambiguous bundle assignments fail closed with explicit reports.
- Blenny remains Visible, ordinary reveal never includes Hidden, and the approved validation scope cannot be broadened accidentally.
- The persist/apply transaction has a deterministic failure and rollback contract, including restoration of the previous scoped policy.
- Relaunch and update-like PID replacement preserve an accepted edit, while a failed edit leaves a recoverable prior policy and unrestricted or previously safe system state.
- Deterministic and bounded real validation use only explicitly approved bundles and preserve the single serial writer and replacement-before-invalidation rules.
- No formal settings window, drag-and-drop interface, shortcut, login launch, updater, helper, or distribution work is introduced.

## 0.1.0 — Minimal product interface

Status: **Complete on macOS 27.0 build `26A5416b`; closed at local annotated tag `v0.1.0`, push deferred.**

Exit criteria met:

- A minimal AppKit-first editor exposes `Visible`, `Revealable`, and `Hidden` groups with clear user-facing labels.
- `Visible` means Blenny does not deliberately conceal the bundle; it does not promise a fixed physical position when macOS has insufficient menu-bar space.
- Newly observed application bundles are effectively Visible without silently adding persistent policy entries.
- Identifiable Apple system items are shown read-only in the Visible lane and remain outside the editable bundle-policy draft.
- The current policy schema and all product logic use `visible`, `revealable`, and `hidden`; schema-1 documents decode through a bounded persistence migration and re-encode as schema 2.
- UI edits remain local and smooth; system policy applies only after the interaction completes.
- Blenny's menu-bar control has stable click, keyboard, and quit behavior.
- Accessibility onboarding is clear and never repeatedly prompts.
- No themes, profiles, animation system, or unrelated preferences are added.

## 0.2.0 — Icon-first policy presentation

Status: **Complete on macOS 27.0 build `26A5416b`; closed at local annotated tag `v0.2.0`, push deferred.**

Exit criteria met:

- Every observed application-bundle candidate has an icon resolved from its owning installed application, with a deterministic generic fallback when resolution fails.
- Blenny's installed application bundle supplies its own full-color multi-resolution icon, independently from the monochrome optical-size status-item template.
- Known read-only Apple system-item observations use semantic system symbols keyed by stable observation identity, while unknown items use the same honest fallback.
- Icons are presentation only: bundle identifiers remain policy identity, icon bytes do not enter policy persistence, and refresh ordering does not change icon selection.
- The existing Visible, Revealable, and Hidden lanes become icon-first while names, policy state, bundle identity, item count, and read-only status remain available through supplementary text, tooltips, selection detail, and Accessibility labels.
- Blenny requires neither Screen Recording nor live menu-bar pixel capture, and it does not imitate dynamic status-item content that cannot be obtained through a stable source.
- Deterministic tests cover application-icon source selection, known system-symbol mapping, fallback behavior, duplicate observations, and refresh stability.
- Xcode 27 Debug and Release tests and app builds pass, and installed visual review confirms recognizable icons, fallback clarity, keyboard navigation, and unchanged policy/recovery behavior.
- The application adopts stable bundle identifier `xyz.fi5h.blenny`; accepted policy and recovery documents using the former development identifier migrate deterministically without changing assignments or management state, and collisions fail closed.

Not included: in-lane ordering, real policy writes, system-item reassignment, login launch, lifecycle/display hardening, helpers, IPC, updating, profiles, themes, decorative animation systems, or polling.

## 0.3.0 — Product interface foundation

Status: **Complete on macOS 27.0 build `27A5237l`; closed at local annotated tag `v0.3.0`, push pending.**

Exit criteria met:

- Work began with a product-layout discussion rather than implementation. Four materially different single-window directions were compared before the owner selected Direction A, then installed review refined it to symbol-and-label navigation below the title bar, compact lanes with tightly spaced borderless icon cells, one macOS read-only marker, an anchored manual-observation footer, and explicit destination widths within the same top-left-anchored window.
- The selected AppKit-shell and SwiftUI-content architecture establishes the durable main-window information architecture, visual hierarchy, typography, spacing, grouping, component states, and action placement expected to carry through the subsequent interaction milestones.
- Visible, Revealable, and Hidden remain immediately understandable, with icon-first recognition, natural-aspect read-only Apple system symbols, management status, recovery actions, and manual Refresh presented without visual competition.
- The interface remains usable at its minimum and preferred window sizes without page-level vertical scrolling in the three normal destinations. Organize retains the width needed by horizontal lanes, Settings and Support share one stable narrower width, and idle Refresh remains available to discover Accessibility granted elsewhere. The navigation band keeps one fixed title-bar inset across destinations, active refresh visibly interrupts the lanes with bounded progress, and navigation draws no persistent focus outline. Long lanes, empty lanes, fallback icons, long names, supplementary details, tooltips, and normal light and dark system appearances are verified visually.
- Organize exposes no temporary assignment, draft, Discard, or routine Review surface before dragging exists. Management and recovery Review, Resume Managing, Stop Managing, Restore Previous Policy, close, reopen, and Quit behavior remains stable.
- Settings replaces its explanatory Observation card with a native Open at Login switch backed directly by `SMAppService.mainApp`; system status remains the source of truth and no helper, IPC service, or mirrored preference is added.
- Organize places the no-pointer-movement, no-menu-bar-capture, and no-polling promise directly below its physical-placement note. Support keeps a fixed top inset, separates its project-website link from the donation group, and presents Sponsor once, Sponsor monthly, and Ko-fi in that order; GitHub links carry `metadata_project=blenny` without implementing checkout, payment storage, licensing, benefits, or entitlements inside Blenny.
- This milestone adds no drag-and-drop, within-lane ordering, policy/persistence semantics, report or fingerprint inputs, assertion path, mutable system item, polling, theme system, animation system, or unrelated preference.
- The chosen structure is documented well enough that `0.4.0` can add dragging without another fundamental layout redesign.

## 0.4.0 — Cross-lane draft dragging

Status: **Complete on macOS 27.0 build `27A5237l`; closed at local annotated tag `v0.4.0`, push deferred.**

Implemented exit criteria:

- Visible, Revealable, and Hidden are three fixed rows inside one continuous, restrained Organization Board with one quiet surface, inset internal separators, compact semantic markers, and single-row horizontal scrolling.
- Editable application-bundle icons use the native macOS drag session and `Transferable` payload. One accepted cross-lane drop produces at most one local assignment, with deterministic duplicate-token, same-lane, stale-generation, stale-source, unknown-candidate, outside-target, route-change, and discard handling.
- Dragging mutates only `BundlePolicyDraft`; persistence and assertion creation remain behind the existing deterministic in-window Review and Apply boundary. An asynchronous Review is rejected if its source Draft changes before preview completes.
- Names are absent at rest and appear in a non-reflowing floating label for hover, keyboard focus, or selection. One stable selection rail, complete Help, Bundle ID, count, policy, fallback and read-only detail, and unconditional Accessibility labels provide the full identity path.
- Selection, the `Move to…` menu, context menus, and VoiceOver actions use the same assignment coordinator as drop. Blenny remains locked Visible; Apple system observations remain read-only and non-draggable; ordinary reveal never includes Hidden.
- Drag source ghosting, pale valid-lane treatment, a non-interactive ghost at the existing automatic landing position, matched-geometry relocation, and settle feedback use short interruptible native SwiftUI motion. Returning over the source lane is a neutral no-op without a custom error frame; exceptional invalid targets use restrained local feedback. Reduce Motion removes travel and scale in favor of short opacity transitions; Reduce Transparency and Increase Contrast use adaptive opaque and strengthened system surfaces.
- Review Changes and Discard Draft reserve stable footer geometry but become visible and accessible only after local intent differs from the accepted policy. Returning every assignment to its accepted policy removes the Draft controls again.
- Returning from Accessibility settings after a false-to-true authorization transition triggers exactly one bounded read-only refresh. Repeated activation, an in-progress refresh, or a local Draft cannot start another refresh; no polling or reconciliation loop is added.
- The milestone does not promise physical menu-bar ordering or within-lane priority and adds no real assertion write, mutable system item, polling, Screen Recording, helper, IPC, theme system, or payment feature.

## 0.5.0 — Reviewed management loop

Status: **Complete on the exact Debug development boundary for macOS 27.0 build `26A5416b`; closed at local annotated tag `v0.5.0`, push deferred.**

Implemented exit criteria:

- A valid reviewed application-bundle draft can complete the intended baseline and ordinary-reveal behavior through the one serial writer on the explicitly supported development build.
- Exact diff, impact, validation, and recovery preparation remain mandatory before mutation. Ordinary users invoke Apply, Resume, Stop, and Restore directly; the full report is available only in Debug dry-run evidence.
- Stop Managing and Restore Previous Policy close the same product loop without broadening approved targets or admitting mutable Apple system items.
- Ordinary launched operation does not require a separate management switch. Once the runtime can truthfully provide that behavior, the transitional stopped-management banner leaves the routine Organize surface; deliberate Stop and Restore remain safety and recovery actions rather than everyday mode controls.
- Real validation remains bounded to explicitly approved bundles and ends in verified restoration.
- Release promotion of the unsupported backend remains a separate, deliberate compatibility decision rather than an accidental consequence of UI integration.

### Included direct-control and usability follow-ups

The owner accepted the current fish/arrow presentation and folded these fixes into `0.5.0`, authorizing replacement of only the unpublished local version tag after final checks. Existing commits and every other tag remain unchanged.

- Remove the ordinary Review page. Apply, Resume, Stop and Restore prepare and validate plans internally; recovery stays durable and bounded action diagnostics remain process-local. Keep full reports in Debug dry-run evidence.
- Connect the normal Blenny status item to ordinary reveal: a smaller double-chevron left of the artwork/editor control as two compact 22-point native status items, with right-click safety access. Keep Blenny's arrow available independently of native presence and bind its native action directly to the same toggle as the menu; remove coordinate-based click splitting. Native-control integration and the reported missing Bartender candidate are explicitly deferred to 0.6.0; no repair of either is claimed complete in this version. No polling or positioning writes.
- Audit ordinary-path wiring for native observation, timeout gating, failed reveal, read-only Refresh, and connection/termination cleanup; do not silently promote separate Debug experiments.
- Gate in-flight actions against duplicate clicks and Draft/Refresh/reveal overlap. Preserve unapplied assignments when stopping; do not silently replace a dirty Draft during Resume or Restore.
- Make a valid Draft Apply start management on the supported Debug build instead of silently persisting stopped intent.
- Keep explicit Resume available after failed startup; freshly validate and activate unchanged accepted intent without rewriting policy or rotating recovery. Missing targets are named, not silently dropped. Connection loss still requires restart.
- Bind Review to managed targets and safety inputs, not unrelated pass-through processes.
- Rebuild the exact full allow-list from one fresh bounded Apply preflight. Managed target, Draft, generation, scope, policy, runtime, or recovery changes still reject before writer access.
- Preserve the 0.5.0 serial writer, rollback, Stop, Restore, Debug/Release isolation, and all ordering exclusions.

## 0.6.0 — Native integration, discovery, and lifecycle hardening

Status: **Complete as the owner-accepted native-integration investigation on macOS 27.0 build `26A5416b`, arm64, one display; local closure at `v0.6.0`, no push. Broader compatibility is not accepted.**

The owner confirmed implementation on 2026-08-31 and corrected the reported
missing application from Bartender to Coffee Buzz. Native-arrow compatibility
is this version's priority. Existing fish/arrow artwork and spacing are retained.
The implementation and actual evidence matrix are recorded in
`docs/TECH_SPIKE_0.6.0.md`; unexercised rows are not compatibility claims.

The owner accepted the final installed behavior on 2026-08-31, closing the
runtime-appearance regression as well as steady-state coordination. The accepted
scope is this native-integration investigation with bounded discovery and safety
invalidation, not a claim that the originally proposed full lifecycle/display
matrix passed. Its unexercised rows remain explicit cross-version gates below.

Implemented and accepted scope after 0.5.0:

- Investigate reliable native overflow expand/collapse integration while retaining a usable Blenny control. Observing native state is not interception or ownership of Apple's button; do not promise a complete takeover.
- Hide the fallback arrow only for a single, known, registered native control; restore it on absence, unknown state, or observation ambiguity/loss. Keep the fish and explicit safety-menu action, and retain the fallback's fixed allocation to prevent width-driven oscillation. Verify actual installed native edges separately from presentation fixtures.
- Keep read-only native observation independent of management and share ordinary/dry-run wiring. Follow fresh known layout/value state edges outside owned writes without claiming click interception. Preserve a revealed session and its original deadline across presentation loss by handing control to Blenny. Keep actual lifecycle failure separate, clear hidden status content, and bound event-triggered read recovery.
- Treat a successful empty native root followed by one newly expanded control on a layout event as the first runtime handoff edge. Do not extend this exception to startup, failed reads, explicit samples, ambiguity, identity replacement or own-write reflow.
- Discover newly created native controls independently of Blenny writer completion: retain canonical-root creation/layout subscriptions and one coalesced post-activation read. Cancel queued reads on observer teardown; discovery and read failures cannot acquire or recreate a writer.
- Diagnose missing application candidates after manual Refresh, including the corrected Coffee Buzz report. Distinguish discovery, ownership attribution, and presentation failures before changing behavior; do not infer that all newly launched apps are unsupported.
- Keep discovery bounded and read-only. Candidate discovery is not mutation authorization; new real-write targets require their own exact plan and approval.
- Defer all ordering investigation, design, experiments and implementation to `0.7.0`.

Evidence supporting closure:

- Owner-operated startup with native overflow present and absent, native expand/collapse, runtime first appearance without a preceding Blenny click, and return to fallback when native overflow disappears.
- Installed Coffee Buzz discovery, owning-bundle attribution and icon presentation; the owner's explicit assignment is preserved, not inferred from discovery.
- Xcode 27: 255 Debug tests in 27 suites, 253 Release tests in 26 suites, both arm64 app builds, strict signatures, macOS 27 deployment/SDK and Release-isolation checks.
- Structurally no-write installed preflight, real baseline activation, event-triggered frozen-scope invalidation, verified serial-writer cleanup and normal Quit; policy/backup bytes, hashes and 0600 modes unchanged. Historical failed diagnostic termination runs remain documented as failures, not normal-Quit passes.
- Deterministic lifecycle/failure/restoration coverage is distinguished from installed compatibility evidence in the spike. No new system mutation class or physical ordering path is introduced.

### Carry-forward lifecycle/display gates

The following originally planned matrix is **not completed by the 0.6.0 owner
acceptance**. Keep it as cross-version hardening work and require direct evidence
before expanding the supported matrix, promoting the private backend to Release,
or completing distribution/stable-release gates. This records the narrower
accepted milestone rather than silently converting untested rows to passes:

- Login, logout, lock, unlock, sleep, and wake.
- Blenny crash and serial-writer failure simulation; no helper is added merely to create a helper-crash scenario.
- Managed-app launch, quit, relaunch, and update-like replacement.
- MenuBarAgent recreation without Blenny restarting it.
- One and multiple displays, scaling changes, Spaces, full-screen apps, and menu-bar auto-hide.
- Native overflow present and absent on each additional claimed configuration; the current single-display configuration is owner-accepted.
- Clock, Notification Center, and Control Center remain functional after every mutation class.

## 0.7.0 — Real menu-bar ordering feasibility

Status: **Complete. Blenny does not implement third-party or Apple-item ordering. When one usable native overflow control is observed, Settings provides manual Command-drag instructions for placing the fish immediately to its right. The fish uses one stable public AppKit autosave identity so macOS can retain the user's placement. This is not an automatic or permanent arrow-relative pinning guarantee. The existing local `v0.7.0` tag is preserved and no push is authorized.**

The earlier blanket no-go understated the successful 0.0.3 self-position `500`
experiment beside Usage4Claude. Today's two-item reproduction used the exact
approved value 500 in two separately authorized runs, after deterministic tests
and installed no-write preview.
Usage4Claude and Apple items remained direct-write excluded. The owner confirmed
the fish beside Wi-Fi. After the second run, AX reverses the Wi-Fi/reference
relative order despite equal scoped preference/file hashes. This does not prove
causation or composited order, but prevents a complete physical-restoration claim.
Fresh online and local research identifies `TrailingItemPreferredPositions` in
MenuBarAgent as a plausible third-party ordering route. All ten tested preference
reads return absence; the correctly routed private utilities request is rejected
for a missing Apple entitlement. No baseline, identity mapping, exact inverse or
arrow anchor is established. The spike records candidates and attempted reads;
the later exact self-only write and its restoration are recorded in the spike;
there is no release closure or third-party write.

The subsequent nonvisual check found different ordinary and sandbox preference
values for the exact reference key. A fresh native AX root was unavailable and
the reference item returned no stable AX identifier. Historical negative position
writes do not rule out a different storage scope; neither these values nor
an incomplete AX sample supply a safe live ordering baseline. The next attended
checkpoint then completed: the owner saw the collapsed layout as
`Bluetooth | Wi-Fi | Usage4Claude | WeChat`, while a new complete AX read matched
the first three records. This is the second run's after-order rather than its
pre-order. Physical restoration therefore failed even though scoped preference
and file hashes were restored. The owner later explicitly accepted this residual
risk for one exact self-only agent-table run. Apple items and WeChat remained
observation only; no further write is authorized by that completed receipt.

The owner subsequently made Usage4Claude permanently visible and manually
Command-dragged Blenny's fish to a six-point gap at its left. A read-only AX sample
verified the physical adjacency. The agent table and the ordinary fish owner
preference remained absent, while the layout survived ordinary Blenny restarts;
this points to unidentified MenuBarAgent live host/scene state rather than a
documented persistence contract. In an attended Debug calibration, the dedicated
fish autosave item appeared at that existing location without a new drag, but an
explicit read found no saved value and `_currentPreferredPosition == 0.0`. A
second run that required dragging away and back timed out without recording. Both
runs restored exact policy, preference, agent-table and installation baselines.
No post-drag numeric value, exact inverse or arbitrary third-party identity mapping
has therefore been established.

Requested positioning goals and mandatory implementation gates:

- Distinguish application-bundle policy, a status-item instance, and physical menu-bar position.
- Do not ship ordering that changes only the Blenny Board while leaving the real menu bar unchanged.
- Do not use synthetic pointer movement, clicks, or Command-drag.
- Decide whether to implement ordering only after exact position write, snapshot, diff, Review, restoration, and lifecycle behavior can all be proven.
- Keep all ordering design, experiments, and implementation out of `0.5.x` and `0.6.0`.
- Include the desired Blenny control location at the edge of the always-visible region beside the overflow control as a positioning question, not a guarantee implied by Visible policy.
- Investigate the owner's clarified goal that revealed Revealable items sit to the arrow's **right**. This is physical ordering, not a lane-order change; Hidden items remain excluded from ordinary reveal.

Original tagged investigation evidence, recorded in `docs/TECH_SPIKE_0.7.0.md`
(the correction above supersedes its blanket self-placement no-go):

- SDK 27 supplies no public cross-app or arrow-relative position API. Current scoped AX items report non-settable position. Historical third-party preferred-position writes had no meaningful ordering effect despite exact preference restoration.
- Fresh private runtime metadata/export inspection identifies read/clear, item submission, internal priority and lock surfaces, but no proven exact cross-app snapshot/write/inverse or arrow anchor. No private method is invoked and no new mutation is authorized.
- The current fish can happen to be observed near the arrow's right edge; an AX frame sample is not fixed-placement, compositor, expanded-group or lifecycle evidence.
- No-go is the safety decision: keep all product source, tests, artwork, Visible / Revealable / Hidden behavior, native integration and the sole management writer unchanged. No fake Board-only ordering is introduced.
- Xcode 27 Debug 255 tests / 27 suites and Release 253 tests / 26 suites pass; both 0.7.0 builds pass signature, SDK, deployment, architecture and Release-isolation checks.
- Installed no-writer preflight prepares the unchanged saved scope, exercises existing fallback fixtures and ordinary read-only native discovery, and exits. Policy/backup bytes, hashes and 0600 modes match; scoped position preferences match with zero restore operations. Incomplete first-run/AX observations remain documented, not counted as passes.
- No real position or assertion mutation is performed for this version. The 0.6.0 accepted native-cycle evidence is preserved, not repeated or broadened by a dry-run. Lifecycle/display and Release-promotion gates remain open.

Reopen physical ordering only after exact identity, state, write, inverse and
lifecycle semantics can be proven, followed by deterministic tests, installed
dry-run and explicit authorization of a bounded experiment through one serial
writer. Do not substitute global position clearing, synthetic input or automatic
reconciliation for that missing contract.

Final product resolution:

- Do not expose ordering for third-party or Apple items. Users arrange those
  items with macOS's native Command-drag interaction.
- Give only the ordinary fish a stable, version-independent public AppKit
  autosave identity. The separate reveal/fallback item remains unchanged.
- Offer placement steps only while exactly one usable native overflow control is
  observed. Recheck availability at activation and observer updates; do not poll.
- Describe the result truthfully as a macOS-owned saved placement. Blenny does
  not move the pointer, perform a position write, verify pixels, reconcile drift
  or guarantee that the fish remains adjacent after external layout changes.
- Preserve Visible / Revealable / Hidden, keep Blenny Visible, exclude Hidden
  from ordinary reveal, and retain Apple system items as read-only observations.
- Do not revoke a verified writer for every Workspace launch notification. A
  managed launch remains an immediate invalidation. Coalesce unrelated launches
  into one delayed, bounded, read-only ownership capture: no attributable menu-bar
  item keeps the frozen plan active; menu-bar ownership or incomplete evidence
  restores and requires Resume. Never add the new bundle to the allow-list or
  automatically recreate the writer.
- Treat `didChangeScreenParameters` as a trigger for comparison, not sufficient
  proof of a changed display. Compare public display identifiers, frames and
  backing scales. Preserve management only when that signature is identical;
  real display, resolution or scale changes still restore and require Resume.
- On each explicit user Reveal, retire Blenny's fallback through one bounded
  ladder: remove the status item, try a contentless zero-length transition if
  native overflow disappears, then restore the full 22-point fallback if needed.
  Automatic layout events cannot restart the ladder; a later user Reveal may.
  This is Blenny-owned AppKit presentation only; never loop, reorder or treat the
  result as an arrow-relative placement guarantee.
- Xcode 27 verification passes 292 Debug tests / 32 suites and 261 Release tests /
  28 suites. Both 0.7.0 app configurations build; installed verification and
  exact local-state comparison are recorded in the spike.

## 0.8.0 — Apple system-item visibility feasibility

Status: **Complete. Bluetooth raw value `1` is the sole ordinary Release
promotion. The optimized trial supports every current mapped target except Clock
through one of three narrow capability families: numbered item assertion, exact
owning-bundle assertion, or item-scoped persistent transaction. The owner
validated all three families, restored Siri, Time Machine and Now Playing, and
the final installed stopped-startup regression preserved every baseline.**

Investigate whether one non-critical Apple item that System Settings itself
allows the user to hide can be concealed and restored through the existing
assessment boundary. The original trial selected Bluetooth alone. The owner
clarified that they want all mapped controls available in the Debug Board for
manual testing, not sequential automated trials. Expose raw values 0, 1, 3, 4, 5,
6, 7 and 8 through the existing serial writer and Review/Apply flow, with isolated
test policy and a stopped startup. Clock and native overflow remain read-only;
Siri, Now Playing and unknown identities await a separate implemented route.
Release still exposes only Bluetooth. Manual visibility results do not count as
automatic promotion or completion of restoration/lifecycle evidence.

Advance when:

- The exact macOS 27 private system-item catalog is mapped to fresh AX and scoped
  preference identities without invoking a private mutation method.
- One installed PREVIEW binds a complete Bluetooth-visible baseline, all protected
  system identity counts, scoped preference values, preference/policy file hashes,
  exact runtime and a frozen application allow-list to a mode-0600 receipt. Recorded
  frame reflow and application departure are benign; identity drift or any newly
  running bundle remains stale.
- Deterministic tests prove confirmation, staleness, exact-target, serial-writer,
  failure, invalidation and exact-restoration behavior. The diagnostic delegate
  remains Debug-only; Release contains only the runtime-gated writer path.
- The owner receives the exact target, allow-list delta, duration, fingerprint,
  risk and recovery contract and separately authorizes that exact receipt before
  one real write.
- A successful authorized run omits only Bluetooth raw value `1`, performs zero
  preference writes, verifies once, invalidates once and exactly restores AX
  state, scoped preferences and file hashes. There is no polling, automatic
  reconciliation, synthetic input, pixel capture, injection, private entitlement,
  SIP change, helper or system UI restart.
- Debug and Release tests/builds and installed regressions pass with Xcode 27.
  Promotion is limited to Bluetooth and does not authorize any other Apple item.

Evidence and the promotion decision are recorded in
`docs/TECH_SPIKE_0.8.0.md`.

Current verified implementation: 312 Debug tests / 33 suites and 267 Release tests /
28 suites pass. Both 0.8.0 app configurations build and pass architecture, SDK,
deployment and signature checks. Installed Debug no-writer dry-run prepared a
Bluetooth-visible schema-3 plan with no writer, assertion or persistence change.
The exact Release build is installed and running; startup preserved the
accepted-policy and previous-policy hashes. The owner subsequently exercised the
Visible / Revealable / Hidden Bluetooth controls and reported normal adjustment.
A presentation-only follow-up uses AppKit's native Bluetooth template and macOS
27's dedicated Siri symbol without broadening Apple-item write authority.
The subsequent read-only identifier investigation confirms the nine-value
assessment enum is complete on this build and identifies separate Siri/module
preference surfaces. Next research is exact string identity, persistence,
notification and restoration semantics; it does not promote further items.
See `Research/0.8.0/IDENTIFIER_FINDINGS.md`.

The 0.8.0 startup recovery correction also limits danger detection to mutation
scope. A previously approved bundle remains in the exact policy plan without
requiring a live ownership candidate, whether dormant or currently running, and
multiple owner PIDs consolidate under that bundle identity. Unknown ownership or
unknown input still fails closed because either could hide an unapproved item. The installed case that previously
reported inactive solely because `xyz.fi5h.Usage4Claude` was dormant now reaches
active management and restores its serial writer on normal Quit.

The 2026-09-04 lifecycle follow-up separately preserves accepted bundle policy
across launch/quit and uses accepted, not unapplied Draft, scope. Confirmed
unrestricted cleanup becomes a neutral pause notice; unconfirmed cleanup remains
an error. Local checks pass 316 Debug tests / 33 suites and 271 Release tests /
28 suites plus both builds/signatures; that checkpoint was not installed.
The owner subsequently approved an additions-only, event-triggered pass-through
update. The implementation coalesces launch identities over a fixed 250 ms,
reuses only the already-active serial writer, preserves both policy presentations
and the existing reveal deadline, and performs no AX inventory for named bundles.
No polling or retry loop is added. Tests now pass 330 Debug / 34 suites and
285 Release / 29 suites; installed no-writer regression now passes with unchanged
accepted-policy and backup hashes. Live observed performance remains pending.
Existing 0.7.0 launch-invalidation notes above are historical and superseded by
this explicit owner-authorized lifecycle exception.

The expanded Debug Bluetooth/Wi-Fi trial planner passes 333 Debug tests / 34
suites, with 285 Release tests / 29 suites unchanged. Both builds pass and an
installed Wi-Fi PREVIEW passes without a writer or state changes. Wi-Fi APPLY
was not executed. That one-item workflow is superseded by the owner's request
for manual Debug Board controls; this is not promotion.

The manual Board build passes 341 Debug tests / 35 suites, 292 Release tests /
30 suites and both builds. Installed no-writer regression covers eight controls
and 24 policy plans. After the initial Accessibility setup checkpoint, the owner
reported successful hide/show for Bluetooth, Wi-Fi, Control Center and Sound.
This is owner-observed visibility evidence, not exhaustive lifecycle/restoration
acceptance; Release stays Bluetooth-only.

The subsequent Clock-excluded investigation establishes Weather and Input Menu
dedicated-owner candidates, exact Input Menu visibility controls, a Now Playing
read/inverse model passing 95 pure checks in both optimization modes, and Siri's
distributed-notification emitter. No new system mutation or app replacement
occurred. Remaining gates are exact-owner assessment effect/restoration for
Weather/Input Menu, and installed persistent-write/refresh/recovery design for
Now Playing/Siri. See `Research/0.8.0/REMAINING_ITEMS_VALIDATION.md`.

On 2026-09-05, Weather and Input Menu were added to the owner-operated Debug
Board as exact bundle-level candidates. No preference route was added. Every
other Apple bundle remains read-only, and Release remains Bluetooth-only on its
previously validated build. The host had updated to `26A5425a`; before admitting
that build to Debug, a standalone read-only probe confirmed the unchanged
MenuBarClientCore UUID, six exact method encodings and an in-memory configuration
round trip without constructing an assertion. The complete Debug 345-test / 35-
suite and Release 296-test / 30-suite matrices and both app builds pass. Installed
dry-run observed both current owners and verified six plans with no writer,
assertion or policy/hash change. Actual hide/show and restoration are pending the
owner's manual trial.

The owner then confirmed successful hide and Reveal for both Weather and Input
Menu. Their exact Debug application identities now render with semantic Weather
and Input Menu symbols rather than generic application/fallback artwork. The
full 345 Debug / 35-suite and 296 Release / 30-suite matrices and both signed
macOS 27 builds pass after that presentation-only correction.

Siri and Time Machine are now confirmed to share `com.apple.systemuiserver`, so
bundle assessment is prohibited for both. Current-build read-only mapping
resolves Siri's two current-user/any-host keys and notification, and Time
Machine's exact ordered `menuExtras` path plus status-item metadata and private
per-item setter route. A product-excluded plan passes 15 pure checks in both
optimization modes and performs five reads with zero writes/notifications. The
remaining gate is a dedicated installed no-write receipt and serial
persistent-state writer with exact comparison/recovery; neither item is editable
or promoted yet. The current app is not replaced until the owner observes the
active state and approves releasing it.

The dedicated manual route is implemented. A
read-only ABI probe on build `26A5425a` resolved the shared
`SystemItemMenuBarPreferences` object and returned `true` from the Siri and Time
Machine getters without calling either setter. The app exposes explicit Hide and
Restore buttons in Settings. One serial operation gate prevents reentrant writes;
each hide saves a mode-0600 exact receipt before calling Apple's item-specific
setter, verifies once, and performs one bounded rollback on failure. Restore
refuses intervening changes and restores exact presence/value state. Debug passes
349 tests / 36 suites; Release remains 296 / 30 and contains neither the private
framework path, accessor symbols, ABI shim symbols nor the Debug panel. The owner
then requested a Release-configuration binary because the Debug build
was not suitable for their local permission state. A separate optimized trial
flavor passed 300 tests / 31 suites and was installed at `/Applications/Blenny.app`
with executable SHA-256
`6d580ff8a81c76954cbabffd12738776b89735934bad664b8f68f9d04da3c226`.
Its startup generated no recovery receipt, left Siri visible and Time Machine's
exact menu-extra path present, and did not change the stopped policy/backup hashes.
Normal Release still passes 296 / 30 and strips the feature. Owner-operated live
hide/restore remains pending.

The first optimized flavor was incomplete: it included the separate shared-item
panel but its Board catalog retained ordinary Release's Bluetooth-only condition.
The corrected trial flavor applies the dedicated compile flag to the full existing
manual catalog, exact Weather/Input Menu exceptions, policy validation/planning,
current-build gate and isolated stopped-on-launch store. It passes the same 300 / 31
trial matrix; Debug remains 349 / 36 and ordinary Release remains 296 / 30. The
corrected signed executable hash is
`46cb5788a209fb2d5c0381472d0c62c92bd84aa247b009f6ce8193537c135aeb`
and it is running from `/Applications/Blenny.app`. Installation/startup changed no
policy or backup hash and created no shared-item receipt. All mapped manual targets
are available to the owner; Clock and unknown identities remain read-only.

Owner UI review then corrected system presentation without broadening either
writer. Weather and Input Menu now appear in the macOS group and use the same
natural-aspect SF Symbol renderer as numbered items. Exact Siri and Time Machine
observations expose their separate Hide / receipt-backed Restore action from the
Board, while remaining outside the three-lane assertion policy. A known Time
Machine identifier is retained even without localized AX text. The unreadable
count now opens the exact bundle/error list. Debug 351/36, ordinary Release 297/30
and optimized trial 302/31 pass; installed hash `b6083ea8...`, PID 41358. Startup
again changed no policy/backup hash and created no shared-item receipt.

The owner then confirmed Siri Hide and exact Restore work without issue. The
optimized trial now presents Siri, and state-backed Time Machine when available,
as two-state draggable Board items: Visible to Hidden calls the dedicated serial
writer; Hidden to Visible restores the exact receipt. Revealable is rejected and
the shared SystemUIServer owner never enters bundle policy. The circular Clock is
not Time Machine and remains read-only. Debug 353/36, ordinary Release 298/30 and
optimized trial 304/31 pass; installed hash `d6c76f66...`, PID 47667. Startup was
stopped, created no shared-item receipt and preserved the manual policy hashes.

The first owner-operated Time Machine Hide exposed an incorrect post-write
visibility check: Apple's setter removed the live target successfully while its
legacy `menuExtras` membership could remain. Blenny rejected that snapshot, rolled
back exactly, and then hid the safely restored card as unavailable. Verification
now requires the paired getter to report hidden, permits the ordered `menuExtras`
array to remain exact or remove only the Time Machine path, and permits target-local
Boolean/position normalization only during write verification,
records the actual applied snapshot, and restores only from that exact snapshot or
the exact baseline. Safe rollback re-reads and restores the card presentation.
Debug 357/36, ordinary Release 298/30 and optimized trial 308/31 pass. After the
owner restored Siri and its receipt disappeared, the signed `412ca1ad...` build was
installed as PID 52867. Startup remained stopped, created no receipt, preserved all
four policy/backup hashes and the exact Time Machine baseline, and performed no
automatic Hide.

Writable presentation is now explicitly capability-based. A recognized AX identity
is interactive only when its current-build descriptor also supplies an isolated
setter, authoritative state, bounded verification and an exact inverse. This avoids
per-item duplicate machinery without converting every recognizable system icon into
an unsafe write probe. Now Playing remains recognized but read-only until its packed
current-host preference capability is revalidated and manually exercised on the
current build.

The three-state follow-up removes the old two-state Siri/Time Machine exception.
Visible, Revealable and Hidden are product intent, not backend API shapes. For a
persistent item whose exact visible baseline has been captured, Revealable applies
the verified hidden state at baseline, restores that exact baseline during an
ordinary reveal, and reapplies the verified hidden state on conceal. Hidden stays
hidden in both presentations; Visible retains the exact visible baseline. Policy
edits, reveal transitions, Stop, Quit and invalidation all pass through one
coordinator that serializes persistent transitions with assertion replacement.
If reveal rollback fails, management stops and every owned assertion and receipt
is restored; no transition polls or retries.
If a restored older policy omits a persistent item entirely, omission means exact
restore and receipt removal after commit, never “leave the previous hidden state.”

The persistent capability catalog contains only exact Siri, Time Machine and Now
Playing identities. Siri and Time Machine use the already owner-validated paired
setters. Now Playing uses current-user/current-host `com.apple.controlcenter` key
`NowPlaying`: visibility mask `0xA`, visible value `0x2`, hidden value `0x8`, with
all unrelated bits preserved and an absent baseline restored as absence. A target
is not made writable merely because AX recognizes it; identity, current-build
state reading, isolated mutation, bounded verification and exact restoration are
all required. Clock, native overflow and unknown/incomplete identities remain
read-only.

Deterministic coverage now includes all three persistent states, exact Now Playing
bit preservation and absence restoration, multi-target batch rollback, ordinary
three-lane dragging, fingerprint binding, pass-through preservation, combined
assertion/persistent verification, failed-reveal rollback and failed-conceal full
cleanup. Xcode 27 passes 369 Debug tests / 37 suites, 307 ordinary Release tests /
31 suites and 320 optimized trial tests / 32 suites. Debug, ordinary Release and
optimized trial app bundles build, sign and verify. No Now Playing live write has
occurred. After confirming stopped management, an empty shared-item receipt
directory and unchanged policy/backup hashes, the prior app was preserved under
ignored LocalData and optimized trial `ffc7f6dd...` was installed at
`/Applications/Blenny.app` as PID 61869. Startup kept all four hashes exact, left
Siri and Time Machine unchanged, kept Now Playing absent, and created no receipt.
No Release audit, commit, tag or push is authorized.

The first owner-operated Siri Revealable Apply exposed delayed Time Machine
normalization from a prior receipt. Siri hid, but the batch then rejected Time
Machine's later target-local hidden representation and rolled Siri back exactly.
Siri was confirmed visible with no receipt; the policy remained stopped. Receipt
ownership now accepts only states satisfying the same per-target bounded hide
predicate: Siri and Now Playing remain exact, while Time Machine may normalize only
its own fields and the known path representation while preserving every unrelated
menu-extra entry and order. A deterministic regression restores this second
normalization exactly and still rejects unrelated drift. The matrix passes Debug
370/37, ordinary Release 307/31 and optimized trial 321/32; all three arm64 app
bundles pass strict signature verification. An installed read-only PREVIEW then
validated the sole Time Machine receipt; the same serial writer restored its exact
path / `VisibleCC = true` / position 86 baseline once and removed the receipt.
Siri and all policy/backup hashes remained unchanged. Corrected optimized build
`9978eafd...` is installed and running stopped as PID 67676. Ordinary Release
still strips this route. A final follow-up also removes the terminal-cleanup Quit
self-wait; candidate `befc3b7e...` passes the same matrix and signature checks but
is not installed while owner testing is active. No release audit, commit, tag or
push ran.

Final closure on 2026-09-06 supersedes those candidate notes. The owner observed
Siri, Time Machine and Now Playing hidden and then manually restored all three.
Read-only comparison found an empty receipt directory, an absent Now Playing
current-host key, and Time Machine restored to its exact menu-extra path,
`VisibleCC = true` and preferred position 86. The four isolated/production policy
and backup hashes matched the accepted post-restoration baseline. Xcode 27 passes
370 Debug tests / 37 suites, 307 ordinary Release tests / 31 suites and 321
optimized-trial tests / 32 suites. All three arm64 bundles build and pass strict
signature verification. The final optimized trial installed at
`/Applications/Blenny.app` has SHA-256
`8795e401166f8efb5ab7e19a19d25aeff420340db1fe4e49f07ee55262e37768`;
its stopped startup created no receipt and changed no preference or policy hash.
Ordinary Release remains Bluetooth-only. The local version is closed without a
push.

## 0.9.0 — Reviewed menu-bar ordering

Status: **Complete on 2026-09-12 as a local experimental milestone. See
[the release record](RELEASE_0.9.0.md). This is not a distribution or public release.**

Accepted scope:

- The Organize Board retains reviewed preferred-position changes for attributable
  third-party owners across Visible, Revealable and Hidden, with all associated
  configured keys moving as one owner block.
- Owner-operated testing confirms the repaired drag path and tested third-party
  ordering on build `26A5425a`.
- Siri, Time Machine and Control Center retain responsive three-state visibility.
  Their sorting is deferred to a future version.
- Weather and Input Menu retain their exact-owner experimental ordering path.
- Ordering is available only in Debug or the explicit optimized trial. Ordinary
  Release excludes the ordering implementation.
- The native overflow arrow is not a writable ordering anchor, so adjacency is
  not guaranteed.
- The Clock/Notification Center conflict is accepted as a known limitation. The
  tested workaround is a left swipe from the trackpad's right edge; automatic
  Stop/Resume around Clock clicks is rejected.
- One canonical repository remains the publication model. License adoption and
  notices remain follow-up work after the 0.10.0 interface review; the first
  public source and binary candidate was then 0.11.0; the accepted schedule
  now assigns that work to 0.12.0.

Final test counts, binary checks and restored-state evidence are recorded in
[the release record](RELEASE_0.9.0.md); the local annotated tag is `v0.9.0`.

### Historical 0.9.0 development record

The dated material below preserves intermediate requirements, failures, candidate
results and superseded pending items. It remains evidence for the technical
history, not the current milestone status above.

The September 9 owner decision replaces the initial exchange scope below with
configuration-backed ordered areas. Current acceptance requires arbitrary
insertion within and between Visible, Revealable and Hidden, a reviewed global
Hidden → Revealable → Visible owner order, all associated configured keys per
owner, and separate configuration and visual verification. Folded state, AX
overlap and absent autosave records alone must not block an attributable write.
Successful commits permit further edits and persist through Stop/Quit, with
explicit undo and durable recovery for incomplete writes. The initial
restore-between-every-change restriction is superseded. Native-arrow anchoring
and invisibility after management ends remain unproven, not product guarantees.

The owner-feedback revision unifies equivalent drop gaps with one translucent
icon preview, refreshes configuration when preparing a review, and scopes process
freshness to selected owners and collision evidence. It includes the exact
Weather/Input Menu owning bundles in Debug ordering. Shared-host and `module:`
system controls need a separate item identity/recovery contract; their existing
visibility controls do not prove sorting support.

The current revision fixes premature drag-release cleanup and adds an exact system-item
exception for Bluetooth, Wi-Fi, Sound, Now Playing, Siri and Time Machine.
Application owners remain whole blocks; system subjects bind individual existing
keys, signed host identities and their own recovery scope through the same serial
coordinator. Unknown modules, Clock and native overflow are excluded. The owner
reaffirms that accepted order persists through Stop/Quit, with separate explicit
Undo. New system ordering requires deterministic mixed-subject/recovery tests and
owner-operated adoption/inverse evidence before compatibility is claimed.

The owner subsequently reports that all currently offered items sort correctly.
The controls follow-up canonicalizes Siri observations for the three-state policy
UI and adds conditional Control Center ordering only for the pinned current
binary/table contract. Primary-to-`BentoBox-0` remains a build-specific inference,
not universal suffix semantics; adoption and inverse are pending. Native-arrow
position has no established writable key, so the requested arrow/fish adjacency
remains an explicit gap. No automatic placement correction is added.

The later drag/Undo regression requires stable landing geometry and explicit
clean-history replacement when current positions differ from the retained ledger.
The new review must bind the replacement decision, archive the superseded clean
record, and preserve external configuration as the new selected-key Undo baseline.
Pending writes remain a separate recovery requirement. Startup drag availability,
stationary hover, cross-lane moves and release delivery need deterministic and
manual acceptance; earlier passing tests do not establish these interactions.

The September 10 owner regression keeps drag acceptance open. Exposed payload identity, layout-bound delivery and native-session cleanup must agree across repeated Apply; a fixture check must exercise the actual interface model before another handoff.

The September 10 revision passes 549 tests / 50 suites in Debug and optimized builds, plus 314 tests / 32 suites in ordinary Release, without warnings. The actual interface-model fixture passes in both executables; native hover and repeated-Apply acceptance remain open.

The drag/Undo revision passes 547 tests / 50 suites in Debug and optimized owner-test builds, and 313 tests / 32 suites in ordinary Release, without warnings. Manual drag acceptance remains open.

The following records describe the earlier exchange integration and its evidence;
the current revision's detailed acceptance is in the 0.9.0 spike.

The preceding controls revision passed 538 Debug/optimized tests across 50
suites and 313 ordinary Release tests across 32 suites under Xcode 27. The
owner has accepted ordering of the offered items; detailed drag interaction,
system inverse/lifecycle behavior, the new Control Center trial and arrow-relative
placement remain separate manual acceptance items.
The owner has confirmed the dedicated Weather/Input Menu owners. Neither this
matrix nor the new test build closes the version.

The earlier automated September 8 product attempt was refused by freshness checks
before writing and its environment restoration passed. Subsequent owner testing
reports successful exchanges among the four presented applications except the
AltServer/SwitchResX Daemon pair, refused at preview geometry checks. The last
archived AltServer/CleanShot X Restore and current preferences corroborate its
recovery. Per-combination attended restoration confirmation is still pending.

At the owner's request, a separate `BLENNY_ORDERING_TRIAL=YES` build uses Release
optimization with the existing Debug capability gates for manual testing. It does
not promote ordering into ordinary Release or waive installed acceptance.

The owner subsequently requested broader manual coverage. The expanded trial
admits fully observable single-item third-party owners from all intent groups while
management is stopped, plus sandbox namespaces only after signed owner/container
identity and complete API/file preference corroboration. No grouping or ordinary
Reveal rule changes; indistinguishable positions and incomplete owner scope remain
unsupported. The September 9 owner-requested observer accepts partially overlapping
AX bounds without a size threshold and permits OS-driven dimension changes when
the same owners retain a distinguishable relative order. Broader compatibility is experimental until separately observed.

The corrected September 8 external group-preference research passed an attended
relative swap and inverse for one approved, non-adjacent pair. It supersedes the
historical broad no-go, without proving every application or display scenario.

Advance when:

- The existing Organize Board reads configured order at initialization, reports
  actual observation separately, and supports free insertion across all areas.
  An ordering-read failure keeps application inventory visible with its reason.
- Debug exposes a bounded preferred-slot permutation for uniquely attributable
  owning bundles on build `26A5425a`, arm64, one display. All three intent groups
  can be arranged while management runs. Every associated key of a selected
  owner participates; Hidden remains excluded from ordinary Reveal.
- The UI previews actual system keys, existing position inputs and relative order;
  incomplete multi-item scope, identity collisions, missing configured positions,
  Apple owners, Blenny and unknown runtimes are explicitly unsupported.
- All mutation uses the existing serial coordinator with durable private receipts,
  fresh preflight, one verification, bounded rollback and exact target restoration.
- Unrelated external changes are preserved; unexpected target drift fails closed.
  Stop, Quit, lifecycle invalidation and explicit crash recovery are tested.
- Identity, staleness, partial failure, serialization, external drift and restoration
  tests pass, along with Debug/Release/optimized-trial builds and isolation checks.
- An installed read-only preview and a separately authorized attended product
  swap/Restore pass. Historical research and unit tests are recorded separately.
- Normal-launch App Data access and actionable permission-denial presentation are
  verified independently of inherited development-tool access. No automatic grant
  or Full Disk Access requirement is implied by the trial build.
- The Clock/Notification Center limitation and trackpad edge-swipe workaround are
  accurate for the claimed compatibility matrix. Acceptance removes only this
  issue's mandatory-fix gate; it does not count as a passing interaction test.
- Version documentation, restored system state, repository audit and annotated tag
  meet the repository completion rules. No history rewrite or push is implied.

Repeated configuration commits and explicit undo replace the initial single
session order, with bounded owner/key counts and backward-compatible legacy
swap/insertion recovery. No automatic ordering replay,
absolute-coordinate pinning, native-arrow takeover, synthetic input, continuous
polling, automatic repair or ordinary Release promotion is included. See
[the 0.9.0 spike](TECH_SPIKE_0.9.0.md) for the full contract and pending evidence.

## 0.10.0 — Interface, supported ordering and unified Undo

Status: **Complete** as a local experimental milestone on 2026-09-15.

The owner accepts the tested compact Organize/Settings/Support flow, three-state
management, supported ordering, native arrow/fish boundary placement and unified
last-Apply Undo. Automatic post-Undo refresh is owner-confirmed. Successful Undo
now uses concise primary feedback; independent physical-verification limits stay
in Details. See [the release record](RELEASE_0.10.0.md) and
[the technical spike](TECH_SPIKE_0.10.0.md) for evidence and superseded experiments.

Exit evidence:

- Before/after UI revisions and runtime behavior were repeatedly owner-tested.
- Deterministic coverage includes draft/drag gates, permissions-return refresh,
  independent control recovery, stale-record review, and unified visibility/order
  inverse with real durable stores, including Siri visibility.
- The attended arrow-only experiment has an exact recorded inverse. Accepted
  persistent placements are user configuration, not outstanding experiments.
- Release checks cover Debug/Release builds, tests, privacy/history and build gates.

This closes the approved local functional scope, not distribution readiness or
universal compatibility. Remaining onboarding, accessibility acceptance, final
UI polish, restart/update lifecycle matrix and Release ordering promotion belong
to 0.11.0 at that closure; remaining gates now belong to 0.12.0. No new sorting
support is claimed for Siri, Time Machine or Control Center; the Clock limitation
remains accepted. License drafts remain excluded.

## 0.11.0 — Permissions and interaction stability

Status: **Complete** as a local experimental milestone on 2026-09-25.

The owner approved closing the accepted local behavior and moving the remaining
public-release work to 0.12.0. This supersedes the earlier 0.11.0 distribution
schedule, not any safety or publication gate. See
[the release record](RELEASE_0.11.0.md) and
[the technical spike](TECH_SPIKE_0.11.0.md).

Exit evidence:

- Device Control's public setup request created the absent row; the owner enabled
  it. Exact layout-file access passed read, reviewed write, inverse and same-binary
  reopen. Broader signature/regrant coverage is explicitly deferred.
- The CPU loop's redundant state publication is guarded. Prepared payload lookup
  is nonmutating, and application/system sources share the typed drag contract.
  The owner confirms Build 15 dragging and Apply are normal.
- Canonical preview serialization prevents equivalent sets and integer-keyed
  dictionaries from changing the reviewed fingerprint. Within-area order changes
  scope only inversion participants; cross-area validation remains complete.
- Eligible third-party owner proof uses exact bundle-key anchoring and fresh
  public code identity, with collision and identity-drift refusal.
- Both API/file disagreement directions fail closed. One event-driven wait and
  one fresh read handle asynchronous disk commits without a write retry or
  continuous observer. Five live Applies and three Undos passed in one process;
  all five actual source disagreements settled, with exact final full-table inverse.
- Cross-build recovery, stopped Undo, journal-first rollback and the one explicit
  zero-change inverse retry have deterministic coverage and bounded live evidence.
- Xcode 27 Debug/Release tests, app builds, packaged fixture checks, signatures,
  isolation and history/privacy audits pass. Raw evidence remains ignored.
- Controlled experiments were restored. A separately owner-abandoned migrated
  receipt was archived without changing live order. The later user-accepted
  applied receipt is verified and retained for ordinary Undo, not pending recovery.

No new ordering support is claimed for Siri, Time Machine or Control Center.
Clock remains an accepted limitation after the formal-build recheck. Broader
hardware/display coverage and public distribution are not claimed complete.

## 0.12.0 — First public release candidate

Status: **Planned.** Remaining pre-publication work moves here from 0.11.0.

Publish the repository and signed prerelease together only when:

- Explicitly review ordering promotion into ordinary Release, including all
  required access, failure, recovery and lifecycle behavior. Debug acceptance
  alone does not promote a private implementation.
- Keep the established `xyz.fi5h.blenny` identifier stable through signing,
  installation and updates. Validate Developer ID identity, Device Control and
  exact-file grant continuity, including revocation and regrant.
- Complete onboarding, final UI, keyboard and VoiceOver acceptance for the
  intentionally minimal bundle-level Visible, Revealable and Hidden experience.
- Validate installation, LaunchServices registration, update delivery, restart,
  interrupted recovery, uninstall and complete restoration. Preserve accepted
  policy and Blenny control identity; no known issue may leave the bar unrecoverable.
- Validate supported hardware, display and macOS configurations, effectively idle
  unchanged-state performance, responsive reveal/conceal and unsupported-item copy.
- Finalize supported-build policy and an emergency private-backend disable
  mechanism. The current major-version/ABI checks are not a completed public
  compatibility matrix.
- Complete Developer ID signing and notarization without storing signing material
  in Git, and reproduce every distributed binary from the published source.
- Complete security/privacy review, opt-in scoped diagnostics, recovery/uninstall
  instructions and user documentation.
- Select and adopt the license, copyright attribution, LICENSE and NOTICE files
  and app-resource packaging before distribution.
- Audit every reachable branch, tag, commit and research artifact against the
  repository publication gate; publish source and the first binary together.
- Disclose the Clock/Notification Center limitation for every affected supported
  build until a replacement backend passes the full interaction, three-state,
  failure and recovery matrix. Do not add automatic Stop/Resume around clicks.

## 1.0.0 — Stable release

Release when:

- “Set it once. It stays set.” is supported by the compatibility and lifecycle evidence.
- The supported hardware/display matrix passes without cursor movement or continuous rewriting.
- Restore, uninstall, and private-backend disable paths are dependable.
- Public distribution, signing, notarization, update, support, and license processes are operational.

## Explicitly deferred beyond 1.0

- Per-status-item control within one application bundle.
- Profiles, themes, visual customization, and automation rules.
- macOS 26 or earlier compatibility.
- Synthetic mouse movement or Command-drag reordering.

0.10.0 owner-approved refinement: Undo Order is single-level and reverses the
latest successful ordering Apply, preserving visibility policy. Failed Apply
retains the previous Undo. Existing receipts are preserved until a new commit.

The owner supersedes order-only Undo: Undo Changes reverses the latest successful
Apply as one unit, including supported third-party and Apple visibility changes
and offered ordering. This does not enable ordering for unsupported Apple items.
### Historical macOS 27 public-build follow-up (2026-09-21)

These entries retain the investigation sequence. Their pending actions and the
one-direction API/file exception are superseded by the completed 0.11.0 record
and strict two-direction corroboration described above.

- The host rebooted from tested build `26A5425a` into public build `26A428`
  after a successful ordering Apply. The old trial correctly failed closed, but
  exposed only an opaque runtime error for Resume and could not enter ordering
  Undo.
- Read-only ABI checks on `26A428` match the existing assessment and container
  preference contracts. Debug and the optimized ordering trial admit the new
  build, preserve the actual build in snapshots, and retain old-build receipt
  decoding for reviewed cross-build recovery.
- Live assertion activation, corroborated layout capture, and the existing
  receipt's single Undo remain owner-attended acceptance work. Control Center
  ordering stays deferred because its pinned system binary identities changed.
- The replacement passed read-only capture on `26A428`. A changed ad-hoc CDHash
  required removing and re-adding the Device Control row; toggle-only regrant
  did not update TCC's stored code requirement, while the exact-file bookmark
  remained usable.
- The first authorized cross-build Undo stopped before mutation because the
  unified policy receipt recorded management enabled and the later Stop changed
  only that flag. Unified Undo now preserves the current management state, so a
  stopped Undo restores assignments and order without resuming visibility
  management.
- The second authorized attempt also stopped before mutation. After a quit and
  reopen, recovery created a fresh inactive coordinator rather than retaining
  the same stopped coordinator. Source now accepts that lifecycle only when the
  persisted policy is stopped and the new coordinator has no active plan; all
  exact policy, identity, table and one-attempt guards remain.
- The third authorized Undo passed those lifecycle guards and durably recorded
  recovery intent, then refused before inverse writes because recovery compared
  obsolete system-host PID and launch-time values across the reboot. Policy and
  the complete 55-entry table remained byte-for-byte unchanged. Recovery now
  accepts a replacement system-host lifetime only after exact item/key mapping,
  stable host bundle/executable identity and fresh code-identity verification;
  fresh Apply review remains strict. Debug 611/56 and ordinary Release 323/34
  pass. One explicit Recover Changes with the frozen receipt remains
  owner-attended and is never automatic.
- That Recover passed identity validation but the Objective-C writer still
  hard-coded only `26A5425a`; it rejected current build `26A428` before invoking
  the private container defaults API. Policy and all 55 table values remained
  unchanged while the receipt retained `restoreIntent`. The C and Swift build
  gates now admit the same exact builds. A complete zero-change capture may arm
  one explicit retry, with a persisted counter that prevents any third write.
  Debug 614/56 and ordinary Release 323/34 pass; the remaining retry is
  owner-attended.
- For the formal macOS 27 release, the owner replaced exact build enumeration
  with a macOS 27 major-version gate. Complete build identity remains in every
  ordering snapshot and must match for a fresh write; private ABI, symbols,
  configuration namespace, code identity and corroborated readback still fail
  closed at runtime. Representative 27.x and Darwin/build-major tests pass.
  The new optimized trial was installed after an exact backup. After the owner
  re-added and enabled its changed ad-hoc identity under Device Control, a
  read-only preflight proved the frozen 55-entry state and unused retry counter.
  One separately authorized Recover Changes restored all 25 controlled values
  and the original policy, preserved all 30 unrelated entries, archived
  `configurationVerified = true` with retry count 1, cleared the active receipt
  and kept management stopped. No automatic Resume or fallback mutation ran;
  physical coordinates remain independently unverified.
- A later reviewed RunCat/Dato inversion visibly applied, but the low-level
  container reader remained on the exact pre-write generation while the stable
  protected plist contained the complete target. The former universal agreement
  rule rolled the two keys back once and verified their originals. Post-write
  capture now accepts only this exact previous-API/target-file split after its
  single bounded wait; ordinary and pre-write reads, third states, missing keys
  and unrelated drift remain strict. Debug 615/56 and ordinary Release 323/34
  pass. The optimized candidate is built but not installed; attended Apply/Undo
  acceptance remains pending.
