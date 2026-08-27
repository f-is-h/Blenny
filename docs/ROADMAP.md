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
- Pinned, Revealable, and Hidden remain distinct bundle-level policy inputs; ordinary reveal sessions never include Hidden bundles. The fully Hidden recovery UI and shortcut are not implemented or mutation-tested in `0.0.2`.
- Any separate policy writer uses a point-to-point, session-scoped local channel that authenticates the requesting Blenny component's code identity, rejects untrusted or stale commands, and cannot accept arbitrary allowlists from a client.
- The backend fails closed when private classes, selectors, or expected encodings differ.
- Normal quit, helper disconnect, failed replacement activation, rejected peers, and replayed or out-of-order commands restore or remain safely unchanged in automated or bounded integration tests.
- No polling or reconciliation loop is introduced.

## 0.0.3 — Real Revealable and Hidden coexistence

Status: **Complete on macOS 27.0 build `26A5416b`.**

Exit criteria met:

- One bounded Debug-only session applies three distinct real bundle-level assignments at once: installed Blenny is Pinned, Usage4Claude is Revealable, and CleanShot X is Hidden.
- The exact owning bundle identifiers, running processes, and menu-bar ownership of both third-party targets are established read-only before mutation. The milestone fails closed if the Revealable and Hidden identifiers are equal, overlap another policy, are absent, or cannot be attributed unambiguously.
- Baseline admits Pinned, hard-conceals Revealable, and hard-conceals Hidden.
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

Advance when:

- A UI-independent draft model supports bundle-level `Pinned`, `Revealable`, and `Hidden` assignments without per-status-item scope.
- Every proposed edit produces a deterministic old-to-new policy diff and dry-run impact report before persistence or system mutation.
- Invalid, overlapping, unknown, missing, or ambiguous bundle assignments fail closed with explicit reports.
- Blenny remains Pinned, ordinary reveal never includes Hidden, and the approved validation scope cannot be broadened accidentally.
- The persist/apply transaction has a deterministic failure and rollback contract, including restoration of the previous scoped policy.
- Relaunch and update-like PID replacement preserve an accepted edit, while a failed edit leaves a recoverable prior policy and unrestricted or previously safe system state.
- Deterministic and bounded real validation use only explicitly approved bundles and preserve the single serial writer and replacement-before-invalidation rules.
- No formal settings window, drag-and-drop interface, shortcut, login launch, updater, helper, or distribution work is introduced.

## 0.1.0 — Minimal product interface

Advance when:

- A minimal AppKit-first editor exposes `Pinned`, `Revealable`, and `Hidden` groups with clear user-facing labels.
- UI edits remain local and smooth; system policy applies only after the interaction completes.
- Blenny's menu-bar control has stable click, keyboard, and quit behavior.
- Accessibility onboarding is clear and never repeatedly prompts.
- No themes, profiles, animation system, or unrelated preferences are added.

## 0.2.0 — Lifecycle and display hardening

Advance when the supported matrix passes:

- Login, logout, lock, unlock, sleep, and wake.
- Blenny crash and policy-helper crash.
- Managed-app launch, quit, relaunch, and update-like replacement.
- MenuBarAgent recreation without Blenny restarting it.
- One and multiple displays, scaling changes, Spaces, full-screen apps, and menu-bar auto-hide.
- Native overflow present and absent.
- Clock, Notification Center, and Control Center remain functional after every mutation class.

## 0.3.0 — Distribution prototype

Advance when:

- The temporary bundle identifier is replaced by a stable public identifier.
- Developer ID signing and notarization succeed without embedding personal signing data in the repository.
- Installation and LaunchServices registration behavior is reproducible.
- A compatibility kill switch can disable the private backend on unknown macOS builds.
- Privacy, diagnostics export, uninstall, and complete restore instructions are reviewed.

## 0.9.0 — First public release candidate

Publish the repository and signed prerelease together when:

- The core installed experience supports bundle-level `Pinned`, `Revealable`, and `Hidden` policies.
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
