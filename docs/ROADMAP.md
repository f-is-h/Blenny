# Blenny roadmap

Blenny advances by verified exit criteria, not by elapsed time or commit count. Versions before `1.0.0` may use unsupported macOS behavior and are not compatibility promises.

## Versioning rules

- `0.0.x` versions are private engineering-foundation milestones. They may add bounded experimental capability, may be Debug-only, and are not public releases.
- `0.y.0` versions beginning with `0.1.0` introduce a coherent pre-release product capability built on the validated engineering foundation.
- `0.y.z` patch versions after a `0.y.0` milestone contain fixes and compatibility updates without expanding that milestone's scope.
- `0.9.x` versions are the first public, open-source release candidates. Source and signed binaries ship together.
- `1.0.0` begins the stable product contract and published macOS compatibility policy.
- A version advances only when every required exit criterion is verified and restoration is complete.

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
- The exact diff, impact report, validation state, and recovery plan remain visible before mutation.
- Stop Managing and Restore Previous Policy close the same product loop without broadening approved targets or admitting mutable Apple system items.
- Ordinary launched operation does not require a separate management switch. Once the runtime can truthfully provide that behavior, the transitional stopped-management banner leaves the routine Organize surface; deliberate Stop and Restore remain safety and recovery actions rather than everyday mode controls.
- Real validation remains bounded to explicitly approved bundles and ends in verified restoration.
- Release promotion of the unsupported backend remains a separate, deliberate compatibility decision rather than an accidental consequence of UI integration.

## 0.5.1 — Review usability and resilient Apply

Status: **Implementation and release checks audited; final compact-spacing visual acceptance and local tag pending. `v0.5.0` remains unchanged.**

- Remove the ordinary Review page. Apply, Resume, Stop and Restore prepare and validate plans internally; recovery stays durable and bounded action diagnostics remain process-local. Keep full reports in Debug dry-run evidence.
- Connect the normal Blenny status item to ordinary reveal: a smaller double-chevron left of the artwork/editor control as two compact 22-point native status items, with right-click safety access. Keep Blenny's arrow available independently of native presence and bind its native action directly to the same toggle as the menu; remove coordinate-based click splitting. Native-control integration and the reported missing Bartender candidate are explicitly deferred to 0.6.0; no repair of either is included in this patch. No polling or positioning writes.
- Audit ordinary-path wiring for native observation, timeout gating, failed reveal, read-only Refresh, and connection/termination cleanup; do not silently promote separate Debug experiments.
- Gate in-flight actions against duplicate clicks and Draft/Refresh/reveal overlap. Preserve unapplied assignments when stopping; do not silently replace a dirty Draft during Resume or Restore.
- Make a valid Draft Apply start management on the supported Debug build instead of silently persisting stopped intent.
- Keep explicit Resume available after failed startup; freshly validate and activate unchanged accepted intent without rewriting policy or rotating recovery. Missing targets are named, not silently dropped. Connection loss still requires restart.
- Bind Review to managed targets and safety inputs, not unrelated pass-through processes.
- Rebuild the exact full allow-list from one fresh bounded Apply preflight. Managed target, Draft, generation, scope, policy, runtime, or recovery changes still reject before writer access.
- Preserve the 0.5.0 serial writer, rollback, Stop, Restore, Debug/Release isolation, and all ordering exclusions.

## 0.6.0 — Native integration, discovery, and lifecycle hardening

Owner-confirmed scope after 0.5.1:

- Investigate reliable native overflow expand/collapse integration while retaining a usable Blenny control. Observing native state is not interception or ownership of Apple's button; do not promise a complete takeover.
- Diagnose missing application candidates after manual Refresh, including the reported Bartender item. Distinguish discovery, ownership attribution, and presentation failures before changing behavior; do not infer that all newly launched apps are unsupported.
- Keep discovery bounded and read-only. Candidate discovery is not mutation authorization; new real-write targets require their own exact plan and approval.
- Defer all ordering investigation, design, experiments and implementation to `0.7.0`.

The existing lifecycle and display hardening scope remains:

Advance when the supported matrix passes:

- Login, logout, lock, unlock, sleep, and wake.
- Blenny crash and serial-writer failure simulation; no helper is added merely to create a helper-crash scenario.
- Managed-app launch, quit, relaunch, and update-like replacement.
- MenuBarAgent recreation without Blenny restarting it.
- One and multiple displays, scaling changes, Spaces, full-screen apps, and menu-bar auto-hide.
- Native overflow present and absent.
- Clock, Notification Center, and Control Center remain functional after every mutation class.

## 0.7.0 — Real menu-bar ordering feasibility

Begin with a separate safety-feasibility investigation, not an implementation promise:

- Distinguish application-bundle policy, a status-item instance, and physical menu-bar position.
- Do not ship ordering that changes only the Blenny Board while leaving the real menu bar unchanged.
- Do not use synthetic pointer movement, clicks, or Command-drag.
- Decide whether to implement ordering only after exact position write, snapshot, diff, Review, restoration, and lifecycle behavior can all be proven.
- Keep all ordering design, experiments, and implementation out of `0.5.x` and `0.6.0`.
- Include the desired Blenny control location at the edge of the always-visible region beside the overflow control as a positioning question, not a guarantee implied by Visible policy.

## 0.8.0 — Distribution prototype

Moved from 0.7.0 to retain the separate ordering milestone; distribution scope is unchanged.

Advance when:

- The established `xyz.fi5h.blenny` public identifier remains unchanged through Developer ID signing, notarization, installation, and updates.
- Developer ID signing and notarization succeed without embedding personal signing data in the repository.
- Installation and LaunchServices registration behavior is reproducible.
- A compatibility kill switch can disable the private backend on unknown macOS builds.
- Privacy, diagnostics export, uninstall, and complete restore instructions are reviewed.

## 0.9.0 — First public release candidate

Publish the repository and signed prerelease together when:

- The core installed experience supports bundle-level `Visible`, `Revealable`, and `Hidden` policies.
- Reveal/conceal is fast, visually stable, and safely reversible.
- Known unsupported items are surfaced clearly.
- App updates preserve policies and the Blenny control's registration identity.
- Onboarding, update delivery, and uninstall recovery are tested.
- Performance remains effectively idle when state is unchanged.
- No known issue can leave the menu bar unrecoverable.
- The supported macOS build policy and emergency disable mechanism are final.
- Security and privacy review is complete.
- The open-source license is selected and notices are ready.
- Every reachable branch, tag, commit, and tracked research artifact passes the repository publication gate.
- A macOS build compatibility matrix and recovery instructions are published.
- Crash reports and diagnostics are opt-in and privacy-scoped.
- User documentation matches the intentionally minimal feature set.

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
