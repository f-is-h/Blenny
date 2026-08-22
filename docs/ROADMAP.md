# Blenny roadmap

Blenny advances by verified exit criteria, not by elapsed time or commit count. Versions before `1.0.0` may use unsupported macOS behavior and are not compatibility promises.

## Versioning rules

- `0.0.x` versions are engineering milestones. They may be Debug-only and are not public releases.
- `0.x.0` versions are user-testable prereleases. Each minor version adds a coherent product capability.
- Patch versions such as `0.1.1` contain fixes and compatibility updates without expanding scope.
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
- Keep all unsupported mutation code in ignored Debug experiments.

Not a deliverable: no distributable app, stable bundle identity, onboarding, settings editor, or product backend.

## 0.0.2 — Integrated backend prototype

Advance when:

- The installed custom control and visibility-restriction code live in a narrow Debug-only `MacOS27` backend rather than ignored one-off probes.
- One actor or equivalent serial writer owns every assertion transition.
- Bundle-level `Pinned`, `Automatic`, and `Hidden` intent maps deterministically to allowlists.
- The backend fails closed when private classes, selectors, or expected encodings differ.
- Normal quit, helper disconnect, and failed replacement activation restore safely in automated or bounded integration tests.
- No polling or reconciliation loop is introduced.

## 0.0.3 — Persistent policy prototype

Advance when:

- Bundle-level policies persist across Blenny relaunches.
- Installed-app relaunch and update-like replacement preserve identity and control visibility.
- Unknown or ambiguous bundles are reported rather than guessed.
- A dry-run and explicit “Stop Managing and Restore” path are available.
- Backups contain only scoped menu-bar state and never enter Git.

## 0.0.4 — Minimal product interface

Advance when:

- A minimal AppKit-first editor exposes `Pinned`, `Automatic`, and `Hidden` groups.
- UI edits remain local and smooth; system policy applies only after the interaction completes.
- Blenny's menu-bar control has stable click, keyboard, and quit behavior.
- Accessibility onboarding is clear and never repeatedly prompts.
- No themes, profiles, animation system, or unrelated preferences are added.

## 0.0.5 — Lifecycle and display hardening

Advance when the supported matrix passes:

- Login, logout, lock, unlock, sleep, and wake.
- Blenny crash and policy-helper crash.
- Managed-app launch, quit, relaunch, and update-like replacement.
- MenuBarAgent recreation without Blenny restarting it.
- One and multiple displays, scaling changes, Spaces, full-screen apps, and menu-bar auto-hide.
- Native overflow present and absent.
- Clock, Notification Center, and Control Center remain functional after every mutation class.

## 0.0.6 — Distribution prototype

Advance when:

- The temporary bundle identifier is replaced by a stable public identifier.
- Developer ID signing and notarization succeed without embedding personal signing data in the repository.
- Installation and LaunchServices registration behavior is reproducible.
- A compatibility kill switch can disable the private backend on unknown macOS builds.
- Privacy, diagnostics export, uninstall, and complete restore instructions are reviewed.

## 0.1.0 — First public alpha

Ship to a small test group when:

- The core installed experience supports bundle-level `Pinned`, `Automatic`, and `Hidden` policies.
- Reveal/conceal is fast, visually stable, and safely reversible.
- Known unsupported items are surfaced clearly.
- A macOS build compatibility matrix and recovery instructions are published.
- Crash reports and diagnostics are opt-in and privacy-scoped.

## 0.2.0 — Public beta

Advance when:

- The lifecycle and multi-display matrix is reliable across a wider hardware sample.
- App updates preserve policies and the Blenny control's registration identity.
- Onboarding, update delivery, Homebrew Cask installation, and uninstall recovery are tested.
- Performance remains effectively idle when state is unchanged.

## 0.9.0 — Release candidate

Advance when:

- No known issue can leave the menu bar unrecoverable.
- The supported macOS build policy and emergency disable mechanism are final.
- Security and privacy review is complete.
- The open-source license is selected and notices are ready.
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
