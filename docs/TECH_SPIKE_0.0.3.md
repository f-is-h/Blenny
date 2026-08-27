# Blenny 0.0.3 Real Revealable and Hidden Coexistence

> Engineering record for the bounded `0.0.3` validation. This is not a product UI, a persistence prototype, or a supported public-API implementation.

Status: **Complete on the tested macOS 27 build. Automated checks, dry-runs, real native/fallback Revealable-and-Hidden coexistence, visible restoration, and experiment cleanup pass. Annotated tag `v0.0.3` identifies commit `2cc67a73e7f441cba6a2daad88e234920d9f595d`.**

Last updated: 2026-08-26

## Scope

Version `0.0.3` validates one bounded session with three distinct real bundle-level assignments:

- Pinned: the installed Blenny status item, bundle identifier `com.example.BlennyProbe`.
- Revealable: Usage4Claude, bundle identifier `xyz.fi5h.Usage4Claude`.
- Hidden: CleanShot X, bundle identifier `pl.maketheweb.cleanshotx`.

The assignments are at the owning application bundle level. The read-only preflight observed one top-level `AXMenuBarItem` in each third-party bundle's `AXExtrasMenuBar` on this machine. This does not establish per-status-item control, which remains out of scope even if a later version of either application creates multiple items.

Policy persistence, a formal settings or Hidden recovery UI, shortcuts, login launch, updating, helper processes, product IPC, and distribution work are explicitly excluded. Persistent Policy Prototype moves to `0.0.4`.

## Environment and read-only preflight

| Item | Observed value |
| --- | --- |
| Hardware architecture | Apple Silicon `arm64` |
| macOS | 27.0 |
| macOS build | `26A5416b` |
| Default Xcode | 26.6 (`17F113`) |
| Xcode used explicitly | 27.0 beta (`27A5237l`) |
| Swift | Apple Swift 6.4 (`swiftlang-6.4.0.30.4`) |
| macOS SDK | 27.0 (`26A5406c`) |
| Deployment target | macOS 27.0 |
| Blenny Bundle ID | `com.example.BlennyProbe` |
| Revealable Bundle ID | `xyz.fi5h.Usage4Claude` |
| Hidden Bundle ID | `pl.maketheweb.cleanshotx` |

At preflight, MenuBarAgent, Usage4Claude, and CleanShot X were running from their expected system or `/Applications` bundle paths. Read-only Accessibility calls succeeded for all three `AXExtrasMenuBar` roots. Usage4Claude and CleanShot X each exposed one top-level `AXMenuBarItem` with subrole `AXMenuExtra`. The current Blenny Debug identity reported Accessibility as granted.

The repository began at clean `v0.0.2` commit `ebf0ccf81c7b0730e4345198bf08d186e77855e4`. Baseline Xcode 27 results before implementation were 50 Debug tests and 48 Release tests passing. Both app configurations built as ad-hoc signed arm64 bundles with `minos 27.0` and `sdk 27.0`.

## Safety boundary

- The unsupported assessment runtime remains Debug-only under `Sources/BlennyCore/MacOS27/`.
- One actor owns every assertion transition.
- A replacement must activate successfully before the preceding assertion is invalidated.
- Private classes, selectors, encodings, or configuration round trips that differ from the expected macOS 27 contract fail closed.
- The real-write switch is disabled by default and is not present in Release.
- No mouse or keyboard input is synthesized. There is no Screen Recording dependency, injection, SIP change, system-item mutation, polling loop, or automatic reconciliation.
- The experiment freezes its bounded running-bundle input; it does not implement persistence or background lifecycle management.
- Activation is bounded to one second, an ordinary reveal session to 30 seconds, and the whole experiment to five minutes.
- Real mutation may begin only after automated tests and a dry-run pass, the exact plans below are shown to the owner, and the owner gives a second explicit confirmation.

## Planned allowlists

Bundle counts varied with the frozen set of running applications in each bounded launch. Every dry-run and real run logged its exact sorted plan before activation; representative authorized counts and all invariant assignments are recorded below.

- System item allowlist in every state: the nine observed raw identifiers `0...8`.
- Frozen application input: the bounded set of running bundle identifiers captured at process launch, plus Blenny.
- Baseline: frozen input plus Pinned, minus Revealable, minus Hidden.
- Ordinary reveal: baseline plus Revealable; Hidden remains excluded.
- Restored state: no assessment assertion remains, so neither third-party bundle is restricted by Blenny.

The planner must reject empty identities and any overlap among Pinned, Revealable, and Hidden, including identical Revealable and Hidden bundle identifiers.

## Entry ownership rules

- If native overflow is present and AX observation is available at baseline, native overflow owns the ordinary session. Blenny's status item remains present for diagnostics and recovery. Its base icon remains visible and its double arrow mirrors the observed collapsed or expanded presentation, but clicking Blenny cannot write Revealable policy under native ownership.
- If native overflow is unavailable, the installed and registered Blenny status item owns the fallback session and shows the applicable double arrow.
- If a fallback reveal causes native overflow to appear, fallback ownership remains stable until that session ends.
- A baseline availability change may select a new usable owner without writing policy state.
- Duplicate, stale, out-of-order, or inactive-owner AX events do not write.
- Failure to establish either usable entry fails closed and restores.

## Dry-run

Status: **Passed without activating an assertion.**

The tested Debug bundle was copied byte-for-byte to `/Applications/Blenny 0.0.3 Validation.app`, passed strict deep signature verification, and was registered as the current `com.example.BlennyProbe` application. Its executable SHA-256 matched the Xcode 27-tested Debug build.

The final installed dry-run used the two exact approved environment values and omitted the real-write switch. Its read-only preflight reported:

- Usage4Claude: `xyz.fi5h.Usage4Claude`, PID 21837, one top-level menu-bar item.
- CleanShot X: `pl.maketheweb.cleanshotx`, PID 3438, one top-level menu-bar item.
- Pinned: installed Blenny, `com.example.BlennyProbe`.

The planner froze 145 relevant launch observations before policy subtraction and emitted:

- Baseline: 143 allowed bundle identifiers; Pinned allowed, Usage4Claude excluded, CleanShot X excluded.
- Ordinary reveal: 144 allowed bundle identifiers; Pinned allowed, Usage4Claude allowed, CleanShot X excluded.
- Both plans: system item raw identifiers `0...8`.

Native overflow was present and observable, so it owned the dry-run entry. The installed Blenny status item remained available but did not present or accept a reveal action under native ownership. The real-write environment key was absent, the writer and assertion factory were not created, and no assertion candidate activated.

The dry-run process then quit normally. No Blenny process remained, and the MenuBarAgent, Usage4Claude, and CleanShot X process identifiers were unchanged.

After the failed interactive round trip, Debug-only lifecycle-reason telemetry was added without changing policy, assertion, or AX behavior. The replacement binary passed 62 Debug and 60 Release tests, both app builds, signature checks, and the Release private-surface scan. Its installed executable SHA-256 is `bfe48cc1b52603c090d7811f113b7a82e1807c05ab263337c1ad944c819e80df`. A new installed dry-run completed normal start and exit with explicit elapsed time and stop-reason logging. Its frozen plans contained 136 baseline bundles and 137 ordinary-reveal bundles; both admitted Blenny and excluded CleanShot X, while only the ordinary-reveal plan admitted Usage4Claude. No assertion candidate was created or activated.

The fallback-presentation failure led to one narrower Debug-only dry-run. The installed main Blenny bundle registered its own unique `NSStatusItem` autosave position as process-scoped value `500`, combining the earlier owner-side position evidence with the already-proven installed presentation identity. It did not write another bundle or a system-item position. The tested and installed Debug executable SHA-256 was `5419abe309ee5ed02cac792b17110b2329f57985b60bfdfc288f383ff29ed4a8`. The owner confirmed that Blenny was visibly adjacent to Usage4Claude and that both were on the native overflow control's persistently visible side. The dry-run then exited normally, logged explicit placement restoration, and a read-back confirmed that the unique position key was absent from the persistent application domain. No assertion candidate was created or activated.

To preserve a wide leading-menu layout for a true native-owner run, the Debug validation launch stopped automatically activating Blenny's diagnostics window. With Xcode already frontmost, the resulting installed dry-run retained native overflow, selected `nativeOverflow`, and initially presented Blenny as a non-reveal diagnostics icon. The owner confirmed that the system double arrow remained visible and Blenny was not an actionable fallback arrow. The installed Debug executable SHA-256 for that policy-owning behavior was `1c6623ca1febefd8abfec88bc573d740a0bde4f1de155dc62ff9ee7279eaf3c6`. No assertion candidate was created or activated; normal exit again removed the process-scoped placement and left no persistent key.

After the real policy runs passed, the owner requested a display-only refinement: Blenny's base icon must remain visible throughout a bounded validation session, while a separate double arrow mirrors the observed presentation. Under native ownership the arrow is status-only and clicking Blenny opens diagnostics rather than writing; under fallback ownership the same arrow remains actionable. The final Debug implementation keeps both symbols in one status-item button as two independent AppKit `NSImageView` instances, so neither symbol is pre-rendered into a composite bitmap and the whole button remains one click target. A passthrough content stack preserves the existing button action routing.

Across the display-only dry-runs, the owner confirmed that the double arrow changed direction opposite the system overflow arrow as the observed state changed. The final display dry-run used installed executable SHA-256 `dc3096fb72829adf61a72bdfae5d927652899a0c20386431e88140d265627edb`, selected `nativeOverflow`, and created no assertion candidate. In that final rendering pass, the owner confirmed that the base icon and double arrow were simultaneously visible and substantially matched native menu-bar rendering, then accepted a small remaining weight difference between the embedded views and AppKit's single primary status-button image. This is a Debug-only technical affordance, not final product artwork.

## Bounded real runs

Status: **Passed. Bounded real runs exercised baseline, native and fallback reveal/conceal, repeated inactive native-overflow events, the 30-second session bound, the five-minute experiment bound, normal exit, and abrupt disconnect.**

### Native overflow entry

The first authorized run repeated the exact target preflight immediately before launch. The installed executable hash still matched the tested Debug build, LaunchServices resolved the installed validation bundle, Accessibility was granted, and MenuBarAgent plus both third-party targets retained the expected unique processes and bundle paths.

Native overflow was initially present and observable, so it owned the entry before baseline activation. The real 144-bundle baseline assertion activated with Pinned allowed and both real third-party targets excluded. Native overflow then disappeared because the admitted presentation no longer required it. AX reported that disappearance, and the reducer changed ownership directly to the already-installed Blenny fallback without another assertion write or an entryless intermediate state.

No user native expand/collapse operation occurred in this first run.

The final native-owner build did not activate Blenny's diagnostics window, preserving the user's frontmost application and its leading menu width. During the real baseline, switching to a sufficiently wide existing application caused native overflow to appear collapsed. AXObserver selected `nativeOverflow`; Blenny displayed its ordinary diagnostics icon and its fallback action was unavailable. Merely switching between layouts caused direct native/fallback ownership changes without an assertion write or an entryless intermediate state.

The owner completed two native expand/collapse cycles without returning to a narrower foreground layout between clicks. AX delivered `collapsed`, `expanded`, `collapsed`, `expanded`, and `collapsed` in order. The assertion replacements activated in 5.588, 1.480, 1.646, and 0.938 ms. Both reveal plans admitted Usage4Claude and excluded CleanShot X; both baseline plans excluded both targets. The owner reported that every visible result matched those assignments. Returning to Codex removed native overflow and selected the already-visible Blenny fallback without a policy write.

### Blenny fallback entry

Read-only AX inspection during the active baseline found exactly one Blenny status item with accessibility description `Reveal Revealable menu bar items`, confirming that the fallback control existed and was actionable while both targets were restricted.

No fallback click occurred before the five-minute experiment bound in the first real run.

In a second fresh real run, baseline activation excluded both real third-party targets and AX reported native-overflow disappearance, selecting the already-installed Blenny fallback. A user-triggered fallback reveal activated a replacement plan in 25.647 ms. The plan admitted Blenny and Usage4Claude while continuing to exclude CleanShot X. The user confirmed that Usage4Claude appeared, CleanShot X remained absent, and there was no flicker, perceptible delay, or layout jump. This is positive evidence for the first fallback reveal only.

The 30-second session deadline then issued a baseline replacement in 3.900 ms. A second user-triggered fallback reveal activated in 31.925 ms. After that reveal, the user reported that the Blenny double arrow was replaced by the system double arrow. Clicking the remaining system control performed only the system behavior: it did not provide an effective Blenny-controlled round trip, and CleanShot X became visible. This violates the stable usable-entry and Hidden requirements. The fallback conceal path is therefore failed, not passed.

The existing logical reducer retained `blennyFallback` ownership when AX reported native overflow reappearing during the fallback reveal. The observed UI therefore could not be explained merely as the intended reducer handoff. That run was stopped, restored, and treated as failed until a fresh preflight, explicit authorization, and lifecycle-reason telemetry could distinguish timeout restoration, physical fallback presentation loss, and native-overflow semantics.

A fresh run with explicit monotonic lifecycle telemetry isolated the behavior. The owner confirmed the initial managed baseline, then confirmed that the first fallback reveal showed Usage4Claude, kept CleanShot X absent, and showed no flicker, perceptible delay, or layout jump. That reveal activated in 26.485 ms. Native overflow reappeared in its collapsed state without changing logical ownership or causing another write. The 30-second session deadline performed one baseline replacement in 3.224 ms; both third-party targets were absent afterward and the Blenny fallback was directly visible again.

The owner then completed manual round trips. Representative reveal transitions activated in 26.216 ms and 26.047 ms; after each reveal, native overflow appeared and the Blenny control was physically available only behind that system overflow. The owner first opened native overflow, then pressed Blenny's still-owning double arrow to conceal. The matching baseline transitions activated in 28.375 ms and 28.764 ms. Usage4Claude followed every Blenny transition, CleanShot X remained absent in every managed baseline and reveal state, and all Blenny actions behaved correctly.

In a final reveal, the replacement activated in 24.600 ms. The owner repeatedly toggled native overflow while the fallback session remained revealed. AX reported alternating expanded and collapsed states, but the reducer ignored them as inactive-owner events: no additional assertion plan or transition was emitted. The owner confirmed that these system actions affected only the ordinary system-overflow presentation and did not control Usage4Claude or CleanShot X. The 30-second deadline then applied one baseline replacement in 4.632 ms.

This establishes that the earlier report of CleanShot X becoming visible was not reproduced while a managed assertion remained active. The instrumented run instead shows that the whole experiment restoration is the point at which both targets become unrestricted. The later self-position run resolved the physical fallback-control problem described below.

### Timeout, exit, failure, and disconnect

The first real run reached the five-minute experiment bound without an interactive transition. The controller executed complete restoration and changed the Blenny item back to the non-reveal diagnostics state. Blenny then exited normally. No Blenny process remained; MenuBarAgent, Usage4Claude, and CleanShot X retained their original process identifiers, and read-only AX calls again obtained both third-party `AXExtrasMenuBar` roots.

This run supplies real experiment-timeout and normal-exit recovery evidence. The second run exercised the 30-second reveal-session replacement, but its user-visible result was not separately confirmed before the later failed round trip.

Immediately after the critical report, the validation process was terminated to remove its process-owned assertion connection. No Blenny validation process remained; MenuBarAgent, Usage4Claude, and CleanShot X retained PIDs 1590, 21837, and 3438 respectively. This is process-level evidence for disconnect cleanup without restarting MenuBarAgent. The owner later confirmed that the post-exit behavior and normal unrestricted visibility were correct.

The instrumented reproduction reached its whole-experiment deadline at 300.901 seconds. It logged complete restoration beginning immediately and completing about 2.202 ms later. The application then quit normally. MenuBarAgent, Usage4Claude, and CleanShot X again retained PIDs 1590, 21837, and 3438; no MenuBarAgent restart was used.

## User visual checks

Status: **Passed for managed baseline, native entry, fallback entry, bounded timeout behavior, and final post-exit restoration.**

Record separately for baseline, native reveal, native conceal, fallback reveal, fallback conceal, session timeout, normal exit, and disconnect:

- whether Usage4Claude is visible as required;
- whether CleanShot X remains absent during every managed baseline and ordinary reveal state;
- whether Blenny remains visible;
- whether any flicker, perceptible delay, layout jump, or entry gap occurs.

The owner confirmed that Usage4Claude appeared only during Blenny-managed reveal states and that CleanShot X remained absent throughout all managed baseline and reveal states. The owner also confirmed no flicker, perceptible delay, or layout jump. Multiple Blenny reveal/conceal actions worked correctly, and repeated native-overflow toggles did not control either policy target.

The earlier failed visual result concerned entry presentation: after Blenny revealed Usage4Claude, native overflow reappeared and Blenny's own conceal control moved behind it. The user first had to open native overflow to see and press Blenny. The system control did not itself own or change the Blenny session, so that run did not demonstrate a directly usable stable fallback entry even though the logical reducer retained ownership.

A later real run combined the installed Blenny identity with process-scoped self-position `500`. The owner confirmed that the managed baseline concealed both Usage4Claude and CleanShot X while keeping Blenny visible. On reveal, Usage4Claude appeared, CleanShot X remained absent, native overflow reappeared collapsed, and Blenny's conceal arrow remained directly visible. Direct fallback round trips activated in 27.052–53.180 ms, and a 30-second automatic baseline replacement activated in 5.280 ms. Repeated further round trips kept the same visible-control behavior.

Near the end of that run, a final fallback reveal activated at 300.620 seconds. The five-minute experiment bound fired at 301.271 seconds, about 0.651 seconds later, fully restored the assertion and process-scoped placement, and intentionally changed Blenny back to its non-actionable diagnostics icon. The owner initially interpreted the icon change as a refresh failure; the explicit monotonic telemetry established that it was the designed whole-experiment termination. The position preference key was absent after restoration and normal application exit.

This supersedes the earlier fallback-presentation failure: the installed, positioned Blenny fallback remains directly usable during real Revealable/Hidden coexistence.

For native ownership, the owner confirmed two complete system-double-arrow cycles. Usage4Claude appeared on each native expansion and disappeared on each native collapse; CleanShot X remained absent throughout. In the real-run binary, Blenny remained present as a diagnostics and recovery item and did not show or accept its fallback action while native overflow owned the session. The later display-only refinement keeps Blenny's base icon and a state-mirroring arrow visible under native ownership, but preserves the same non-writing click behavior. All observed policy results matched the entry-selection and policy plans.

## Automated evidence

Status: **Passed before real-write authorization.**

Xcode 27 results:

- Debug: 62 tests in 10 suites passed.
- Release: 60 tests in 9 suites passed. The two exact private-runtime surface tests are Debug-only.
- Debug and Release app bundles built successfully as ad-hoc signed arm64 executables with version `0.0.3`, `minos 27.0`, and `sdk 27.0`.

Deterministic coverage includes:

- Pinned at baseline and ordinary reveal.
- Revealable only during ordinary reveal.
- Hidden excluded at baseline and through native and fallback ordinary reveal entries.
- identical or overlapping Revealable and Hidden assignments failing closed.
- missing, duplicate, multi-process, or menu-bar-unattributable real targets failing closed.
- native entry preference, installed fallback selection, and failure when neither is usable.
- inactive fallback events under native ownership producing no transition.
- stable fallback ownership when a fallback reveal causes native overflow to appear; the inactive native event produces no transition.
- availability changes switching directly between usable entries without an entryless intermediate state.
- duplicate and out-of-order events producing no repeated transition.
- replacement activation preceding old assertion invalidation.
- failed reveal and activation timeout preserving the old concealed baseline.
- failed conceal invalidating both the failed replacement and the preceding revealed restriction, then permanently stopping the writer.
- 30-second session timeout returning to baseline exactly once.
- five-minute experiment timeout requesting complete restoration.
- idempotent normal-exit restoration, connection invalidation, and exit/disconnect races with an in-flight activation.

Release binary and linkage inspection found none of the private framework path, assessment assertion/configuration classes, private activation selector, `0.0.3` real-write or target environment keys, approved target identifiers, or Debug coexistence UI marker. The Debug binary retained the expected isolated markers.

## Final verification and restoration

Status: **Passed.**

- Xcode 27 Debug and Release app builds passed. Debug ran 62 tests in 10 suites; Release ran 60 tests in 9 suites.
- Both bundles are ad-hoc signed arm64 executables with version `0.0.3`, deployment target 27.0, and SDK 27.0.
- Release inspection found no assessment private class or selector, real-write or target environment key, approved third-party target identifier, or Debug coexistence UI marker.
- The owner confirmed normal unrestricted post-exit behavior. No MenuBarAgent restart was required.
- The final display-only dry-run activated no assertion. Its process ended before cleanup.
- `/Applications/Blenny 0.0.3 Validation.app` was unregistered and deleted, the unique self-position key was absent, and the experiment-only Accessibility grant for `com.example.BlennyProbe` was reset.
- No Blenny validation process remains. MenuBarAgent, Usage4Claude, and CleanShot X retained PIDs 1590, 21837, and 3438 through cleanup.
- No raw log was written for the final runs. Existing ignored `LocalData/` material was left untouched because it predates this run and is not part of the `0.0.3` change.
- Repository privacy and ignored-build-product checks pass. The release audit, local commit, and annotated `v0.0.3` tag are recorded in Git history.

## Unresolved issues

- Native ownership depends on the current display and frontmost application's leading-menu width. The observer handles those event-driven availability changes, but broader display, sleep/wake, and application-layout coverage remains outside this milestone.
- The process-scoped Blenny self-position value is validation-only and not policy persistence. Product persistence and update-like placement behavior remain assigned to `0.0.4` and later milestones.
- The Debug-only two-symbol status affordance uses independent AppKit image views. The owner accepted a small weight difference from AppKit's single primary status-button image; final product iconography remains out of scope.
- Build-specific disconnect cleanup remains an experimental observation rather than a public platform contract.
- Broader lifecycle, display, app-update, and policy-persistence behavior remains assigned to later milestones.
