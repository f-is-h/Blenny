# Blenny 0.0.2 Revealable Session Technical Prototype

> Engineering record for the bounded `0.0.2` Revealable-session validation. This is not a product UI or a supported public-API implementation.

Status: **Validated on the recorded macOS 27 build — dry-run, native and fallback real runs, visual checks, recovery paths, final builds, and full tests passed.**

Last updated: 2026-08-25

## Scope

Version `0.0.2` validates only one bounded Revealable session. It does not implement the product editor, policy persistence, a formal Hidden recovery surface, shortcuts, or a distributable private backend.

The policy inputs are bundle-level:

- Pinned remains admitted at baseline and during reveal.
- Revealable is excluded at baseline and admitted only during an ordinary reveal session.
- Hidden is excluded from both plans. The integrated prototype uses a deliberately nonexistent logical-only Hidden identifier and never applies Hidden policy to a real target.

The only approved real mutation target is Usage4Claude. No other third-party application or critical system item may be selected.

## Environment

| Item | Observed value |
| --- | --- |
| Hardware architecture | Apple Silicon `arm64` |
| macOS | 27.0 |
| macOS build | `26A5416b` |
| Xcode used explicitly | 27.0 beta (`27A5237l`) |
| Swift | Apple Swift 6.4 (`swiftlang-6.4.0.30.4`) |
| macOS SDK | 27.0 (`26A5406c`) |
| Deployment target | macOS 27.0 |
| Blenny Bundle ID | `com.example.BlennyProbe` |
| Approved Revealable Bundle ID | `xyz.fi5h.Usage4Claude` |
| Accessibility before dry-run | Not granted for the newly rebuilt ad-hoc identity |
| Accessibility for installed real-run bundle | Granted by the user; AX capture returned 124 elements in 1.166 seconds |

The default selected developer directory remains Xcode 26.6. Every milestone build and test command therefore sets `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` explicitly.

## Implementation boundary

- The unsupported assessment runtime is compiled only under `#if DEBUG` in `Sources/BlennyCore/MacOS27/`.
- The runtime dynamically loads `MenuBarClientCore` and requires exact class, selector, and Objective-C encoding matches before constructing a candidate assertion.
- One `RevealAssertionWriter` actor owns every assertion transition.
- A replacement must report successful activation before the preceding assertion is invalidated.
- Failed and timed-out replacement candidates are invalidated while the preceding safe assertion remains active.
- The app and writer are in one process. No local helper, distributed notification, or product IPC channel is used in `0.0.2`.
- Native overflow uses event-driven Accessibility notifications. There is no polling or reconciliation loop.
- The installed Blenny status item is established before a real baseline assertion and is required as the fallback even when native overflow exists initially.
- Real mutation is disabled by default and requires the explicit `BLENNY_ENABLE_0_0_2_REAL_WRITES=YES` process environment switch.

## Allowlist model

Both plans admit all nine observed `MBSystemItemIdentifier` raw values (`0...8`) so critical system presentation is not deliberately removed.

The bounded process freezes the set of running application bundle identifiers once at launch and adds Blenny:

- Baseline: frozen running set plus `com.example.BlennyProbe`, minus `xyz.fi5h.Usage4Claude`, minus the logical-only Hidden identifier.
- Reveal: the same frozen set plus `xyz.fi5h.Usage4Claude`, still minus the logical-only Hidden identifier.

There is no background refresh of that snapshot. A launch or quit during the five-minute bound is not reconciled.

## Time and recovery bounds

- Assertion activation timeout: 1 second.
- Reveal-session timeout: 30 seconds, followed by one baseline replacement attempt.
- Whole experiment timeout: 5 minutes, followed by explicit active-assertion invalidation.
- Normal Quit: application termination waits for explicit active-assertion invalidation.
- Failed reveal activation: invalidate only the replacement; keep the old concealed baseline.
- Failed conceal activation: explicitly invalidate the active restriction and restore unrestricted system presentation rather than leave a stale revealed session.
- Process or MenuBarAgent connection loss: rely on the process-owned assertion connection cleanup verified in `0.0.1`; the local disconnect path is also idempotently modeled and tested.

## Automated evidence

Before implementation, the existing 25 tests passed in both Debug and Release using Xcode 27.

The new automated coverage includes:

- Pinned in baseline and reveal plans.
- Revealable only in the reveal plan.
- Hidden excluded from ordinary reveal.
- native-overflow versus installed-Blenny entry selection.
- failure when neither entry is usable.
- stable fallback ownership if a fallback reveal itself creates native overflow.
- duplicate and out-of-order AX event rejection.
- inactive-entry event rejection.
- replacement activation before preceding invalidation.
- failed replacement preserving the old baseline.
- activation timeout preserving the old baseline.
- explicit restoration on normal exit and simulated connection invalidation.
- exact private runtime class, selector, encoding, and configuration round-trip checks without assertion activation.

Pre-run result:

- Debug: 48 tests in 9 suites passed.
- Release: 46 tests in 8 suites passed. The two Debug-only runtime-surface tests are intentionally absent.
- Debug and Release app bundles built with Xcode 27, validated as ad-hoc signed arm64 bundles, and recorded `minos 27.0`, `sdk 27.0`.
- Release binary string inspection found none of `MenuBarClientCore`, `MBAssessmentModeAssertion`, `MBAssessmentModeConfiguration`, the private activation selector, the real-write environment switch, or the Debug Revealable prototype label.

The same build and test checks were repeated after evidence collection, as recorded in Final verification.

## Dry-run

Status: **Passed for the no-AX fallback path.**

The final dry-run launched the rebuilt Debug app with:

- `BLENNY_0_0_2_REVEALABLE_BUNDLE_ID=xyz.fi5h.Usage4Claude`
- no `BLENNY_ENABLE_0_0_2_REAL_WRITES` value

The process constructed a baseline plan containing 156 frozen running bundle identifiers and system items `0...8`. It recorded `revealable_allowed=false` and `hidden_allowed=false`. Accessibility observation was unavailable for that newly signed identity, so the reducer selected `blennyFallback` before constructing the baseline plan. No transient `entry=none` state occurred after plan construction. The app window identified itself as the 0.0.2 Debug Revealable prototype.

No assertion candidate was activated, no third-party or system state changed, and the dry-run processes were terminated after evidence collection. Generated logs were kept only under ignored `LocalData/0.0.2/` until the results below were distilled, then removed before commit.

## Bounded real run

Status: **Passed.**

Before any real write, the user was shown and approved:

- Revealable target: `xyz.fi5h.Usage4Claude` only.
- Pinned target: the installed `com.example.BlennyProbe` status item.
- Hidden target: nonexistent logical-only `com.example.Blenny.Hidden.LogicalOnly`; no real application received Hidden policy.
- Baseline: frozen launch bundle set plus Blenny, minus Usage4Claude and the logical-only Hidden identifier.
- Reveal: baseline plus Usage4Claude, still excluding the logical-only Hidden identifier.
- System allowlist for both states: raw identifiers `0...8`.
- 1-second activation, 30-second reveal, and 5-minute whole-experiment bounds, with explicit normal-exit restoration and process-owned disconnect cleanup.

The tested Debug bundle was copied to `/Applications` and registered temporarily so the fallback was a real installed Blenny status item. Its executable SHA-256 matched the tested build before launch. No other third-party target or critical system item was selected.

### Blenny fallback entry

Concealing Usage4Claude removed the native overflow control in this menu-bar layout. AX reported that disappearance and the reducer selected the already-installed Blenny status item without an `entry=none` transition after baseline construction.

The user completed multiple reveal/conceal cycles with Blenny's double arrow and reported that Usage4Claude showed and hid normally and that the response was very fast. Four representative assertion replacements completed in 26.9-36.2 milliseconds (30.0 milliseconds mean). The fallback retained session ownership when reveal caused the native overflow control to reappear, preventing an entry handoff loop.

### Native overflow entry

In a later clean single-process run, the native overflow control remained present after the baseline assertion. The user operated only the native macOS double arrow for two full cycles. AXObserver delivered `expanded`, `collapsed`, `expanded`, and `collapsed` in order. The matching assertion replacements completed in 1.891, 1.976, 1.507, and 1.415 milliseconds. Every expanded plan added exactly one bundle identifier (Usage4Claude), and every collapsed plan removed it; the logical Hidden identifier remained excluded throughout.

The observer later reported native overflow disappearance and selected Blenny fallback while the baseline was already safe. There was no write during that entry-only transition.

### Timeout, exit, and disconnect

- A fallback reveal completed in 21.4 milliseconds. With no further input, the 30-second deadline issued exactly one baseline replacement, completing in 2.3 milliseconds. The user confirmed Usage4Claude hid normally at the deadline.
- After a normal Blenny termination, the user confirmed Usage4Claude returned normally.
- In a separate run, Blenny was killed abruptly while its assertion connection was active. Blenny disappeared, Usage4Claude returned automatically, and the existing Usage4Claude and MenuBarAgent processes remained alive. This validates process-connection cleanup for the tested macOS build without restarting MenuBarAgent.
- Failure and activation-timeout paths were not deliberately induced against the real target. Deterministic writer tests cover them and verify that the old safe assertion is not invalidated early.

## User visual checks

Status: **Passed.**

The user reported all of the following directly:

- Blenny's fallback double arrow showed and hid Usage4Claude normally and very quickly.
- The 30-second automatic conceal looked normal.
- Normal Blenny exit restored Usage4Claude.
- Abrupt Blenny disappearance restored Usage4Claude.
- Two native-overflow expand/collapse cycles showed no visible anomaly: no flicker, perceptible delay, or layout jump was observed.

Hidden had no real target and therefore no visual representation in this milestone.

## Restoration state

Every bounded real run ended with Usage4Claude visible. The final validation instance was terminated normally. Usage4Claude and MenuBarAgent retained their original process identifiers across that termination; no MenuBarAgent restart or system-preference mutation was used. The temporary installed bundle, LaunchServices registration, Accessibility grant, and ignored raw logs were removed during final cleanup, and the pre-existing Blenny registrations were restored.

## Final verification

- Xcode 27 Debug tests: 48 tests in 9 suites passed.
- Xcode 27 Release tests: 46 tests in 8 suites passed; the two runtime-surface tests are Debug-only by design.
- Xcode 27 Debug and Release app builds passed.
- Both app executables are arm64, record `minos 27.0` and `sdk 27.0`, report version `0.0.2`, and pass strict deep signature verification.
- Release binary inspection found no private framework path, private class names, private activation selector, real-write environment switch, or Debug prototype label. The Debug binary retained the expected isolated private backend.
- `git diff --check` passed. Tracked and staged-content scans found no diagnostics, backup files, signing material, personal absolute paths, or build products.
- No Blenny validation process remained. Usage4Claude and MenuBarAgent remained running with their pre-run process identifiers after final restoration.

## Unresolved issues

- Native overflow event reliability across display changes, sleep/wake, MenuBarAgent recreation, other languages, and later macOS 27 builds remains outside this milestone.
- The installed-and-registered visibility prerequisite is treated as one safety condition; this milestone does not isolate which part is causally required.
- Crash cleanup remains a build-specific process-connection observation rather than a public Apple contract.
- Real activation-failure injection was intentionally not performed against Usage4Claude; the fail-closed replacement behavior is validated by the serialized-writer test double.
