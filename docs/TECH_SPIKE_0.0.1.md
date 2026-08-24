# Blenny 0.0.1 Technical Spike

> Historical engineering record. It documents unsupported, build-specific experiments and is not a production API guide. Sanitized source for the decisive installed toggle experiment lives under [`Research/0.0.1/Probes`](../Research/0.0.1/Probes/README.md) and is excluded from product targets.

Status: Complete — go on macOS 27.0 build `26A5416b` for an installed, LaunchServices-registered custom-control architecture. Phase A captured a trusted, privacy-bounded inventory and event-driven native-overflow observation. Phase B's Blenny-owned length experiment passed. Phase C showed that preferred-position writes are reversible but ineffective for cross-application priority, while a private assessment-mode assertion can hard-hide and rapidly reveal an approved bundle. Uninstalled Blenny probes were suppressed during the restriction; an installed and registered Blenny remained visible and completed repeated reveal/conceal transitions without user-visible flicker or delay. This is evidence to proceed to an integrated prototype, not a compatibility guarantee or distributable product release.

Completion date: 2026-08-24

Last updated: 2026-08-24

## Scope and safety boundary

This document records the Phase A read-only Accessibility probe, Phase B experiments against Blenny's own status item, and one controlled Phase C experiment against a non-critical third-party status item. No critical system status item was modified or restarted.

The Phase A build contains no Accessibility attribute writes, Accessibility actions, synthetic input, mouse movement, WindowServer manipulation, Screen Recording dependency, private entitlement, injection, polling timer, or automatic reconciliation loop. A refresh is manually initiated, limited to 1,024 Accessibility elements, given a five-second wall-clock budget, and uses a 0.5-second per-application AX messaging timeout.

The implementation is clean-room Swift/AppKit code. It does not use or link Ice, Thaw, or PlatformRuntimeKit code or binaries. No license file has been added because the project license remains undecided.

The product policy scope is bundle-level. All status items owned by one application bundle share one Pinned, Automatic, or Hidden policy. Per-instance management for apps that expose multiple status items is explicitly out of scope; instance-level Accessibility metadata remains diagnostic only.

## Environment and build

| Item | Observed value |
| --- | --- |
| Hardware architecture | Apple Silicon `arm64` |
| macOS | 27.0 |
| macOS build | 26A5416b |
| Default Xcode | 26.6 (17F113) |
| Xcode 27 used explicitly | 27.0 beta (27A5237l) |
| Swift 27 toolchain | Apple Swift 6.4 (`swiftlang-6.4.0.30.4`, `clang-2100.3.30.1`) |
| macOS 27 SDK | 27.0 (26A5406c) |
| Blenny deployment target | 27.0 |
| App architecture | arm64 |
| Temporary Bundle ID | `com.example.BlennyProbe` |
| Signing used for local probe | ad-hoc |

The first local app bundle was produced with Xcode 26.6 and records `LC_BUILD_VERSION minos 27.0`, `sdk 26.5`. Xcode 27 was subsequently installed alongside it. Without changing global `xcode-select`, the package now builds with the macOS 27 SDK and the SwiftPM executable records `minos 27.0`, `sdk 27.0`. No macOS 26 fallback was added. The already-authorized ad-hoc `.app` was deliberately not rebuilt during this SDK check because replacing its signature would invalidate the user's Accessibility grant.

Build and test commands:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --configuration release
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/build-app.sh debug
open build/debug/Blenny.app
```

The app bundling script builds with SwiftPM, creates `build/debug/Blenny.app`, copies the centralized `Info.plist`, and applies a local ad-hoc signature. Build output is ignored by Git.

## Phase A implementation

The probe includes:

- One Blenny-owned `NSStatusItem` with a monochrome template SF Symbol and a native menu.
- An AppKit diagnostics window with explicit Refresh, Request Access, Open Device Control Settings, and Export JSON controls.
- A non-repeating permission flow. The application checks trust without prompting at launch; only the explicit Request Access action asks macOS to show its permission prompt, at most once per process launch.
- A manual, actor-isolated Accessibility inventory. Cross-process calls do not run as a permanent main-thread polling loop.
- Enumeration of non-background running applications' `AXExtrasMenuBar` trees, plus the extras tree and menu-bar-sized presentation roots exposed by a running `com.apple.MenuBarAgent` process.
- Per-element owner PID, bundle ID, tree source, depth, role, subrole, title, description, identifier, computed frame, actions, and read/settable results for `AXHidden`, `AXPosition`, and `AXSize`.
- Element, wall-clock, and per-application message limits. There is no retry loop.
- A privacy-limited JSON report. Traversal stops at each status item and excludes its menu, menu items, nested application trees, unrelated windows, file paths, images, and window contents. Required menu-item text fields are whitespace-normalized and capped at 256 characters; custom action metadata is reduced to its semantic first line.
- A conservative overflow classifier. A `MenuBarAgent` element that contains a recognized overflow/chevron Accessibility marker is labeled `nativeOverflowPresentationControl`. All other `MenuBarAgent` elements remain `systemOwnedPresentation`, never ordinary manageable items.
- A diagnostic `MenuBarItemIdentity` based on normalized bundle ID, Accessibility identifier when present, otherwise semantic title/description, role, subrole, and an observation ordinal. Decimal runs in semantic labels are represented by a stable `{number}` token because live status text often contains changing counters or time values; identities using this heuristic are explicitly weak confidence. PID, transient element keys, image bytes, and coordinates are excluded. Product policy persistence uses the owning bundle identifier and deliberately does not distinguish multiple items from one bundle.

## Phase B implementation

The Debug app adds an explicitly warned status-item length experiment to the diagnostics window. It offers 80, 160, and 320 point values. Each run changes only Blenny's own `NSStatusItem.length`, disables repeated runs, and automatically restores `NSStatusItem.variableLength` after eight seconds. A manual Restore Now control is available during the pulse. Release builds contain neither the controls nor their strings.

## APIs and attributes attempted

### Public AppKit/Foundation APIs

- `NSStatusBar` and `NSStatusItem` for Blenny's own menu bar item.
- `NSStatusItem.length` and `NSStatusItem.variableLength` for the bounded Debug-only Phase B experiment.
- `NSMenu`, `NSWindow`, `NSSavePanel`, and standard AppKit controls.
- `NSWorkspace.runningApplications` and `NSRunningApplication` for PID/bundle attribution.
- `ProcessInfo` and the system version property list for environment reporting.

### Public Accessibility APIs

- `AXIsProcessTrusted` and `AXIsProcessTrustedWithOptions`.
- `AXUIElementCreateApplication`.
- `AXUIElementCopyAttributeValue`.
- `AXUIElementCopyActionNames`.
- `AXUIElementIsAttributeSettable`.
- `AXUIElementSetMessagingTimeout`, which configures the local AX client timeout and does not mutate the target application or system menu bar state.
- `AXObserverCreate` and `AXObserverAddNotification` for the one-off read-only native-overflow state-transition probe.
- `AXValueGetType` and `AXValueGetValue` for position and size.
- Attributes: `AXExtrasMenuBar`, `AXChildren`, `AXRole`, `AXSubrole`, `AXTitle`, `AXDescription`, `AXIdentifier`, `AXHidden`, `AXPosition`, and `AXSize`.

The code does not call `AXUIElementSetAttributeValue` or `AXUIElementPerformAction`.

### Public preference APIs used for Phase C preparation

- `CFPreferencesCopyKeyList` and `CFPreferencesCopyValue` read the narrowly scoped `NSStatusItem Preferred Position ` keys.
- `CFNumberGetType` and `CFNumberGetValue` preserve the original numeric representation in the backup.
- `CFPreferencesSetValue` and `CFPreferencesSynchronize` exist only inside the explicitly named `ExperimentalMacOS27PreferredPositionWriter` and are compiled only in Debug. They were exercised once to apply one third-party value and once to restore the exact original value.
- `CryptoKit.SHA256` fingerprints the exact scoped domains and sorted entries used by snapshot, preview, stale-state detection, and restore verification.

The command-line layout probe never prints item keys. Backups are written with mode `0600` under the ignored `LocalData/` tree.

### Version-sensitive or unsupported observations

- Treating bundle identifier `com.apple.MenuBarAgent` and the shape/labels of its Accessibility tree as architecture signals is version-sensitive observation, not a private API call.
- Native overflow classification depends on an `AXButton` owned by `MenuBarAgent` plus an Accessibility identifier or localized semantic label containing a known overflow/chevron marker. The live Simplified Chinese label on this system is `显示隐藏菜单栏项目`.
- The overflow button emitted public Accessibility notification `AXValueChanged` when its presentation switched in both directions. Discovering the button through the undocumented `MenuBarAgent` tree and interpreting its localized description remain version-sensitive behavior.
- The System Settings deep link is only a convenience; the UI also provides a plain-language manual path in case the URL scheme changes.

No private framework, symbol, XPC service, entitlement, preference domain, or mutation mechanism is present in Phase A.

### Debug-only private visibility-restriction research

A one-off Objective-C runtime probe was built under the ignored `LocalData/` directory and was not added to the product or Git index. It dynamically loaded the system `MenuBarClientCore` private framework and verified the Objective-C runtime surface for:

- `MBAssessmentModeAssertion.init`, `activateWithConfiguration:completionHandler:`, and `invalidate`;
- `MBAssessmentModeConfiguration.initWithAllowedSystemItems:allowedBundleIdentifiers:`;
- the `allowedSystemItems` and `allowedBundleIdentifiers` configuration accessors.

The probe requested no private entitlement and performed no injection, synthetic input, preference write, or system-process restart. Configuration used all nine known `MBSystemItemIdentifier` values and the bundle identifiers of all currently running applications. Bundle identifiers were counted but not printed or persisted.

This is unsupported, private, version-sensitive behavior. Runtime availability and exact method encodings must be checked on every supported macOS build, and the backend must fail closed when they differ.

A follow-up export scan found three `VisibilityRestrictionOrigin` cases: `assessmentMode`, `userSessionTransition`, and `campoDrag`. Only assessment mode exposes a configurable allowlist assertion. `MBUserSessionTransitionAssertion` exposes fixed activate/invalidate behavior without an allowlist, while no general exported client assertion was found for `campoDrag`. Neither alternative was invoked because its target scope and recovery semantics are unsuitable or unknown.

A later surrogate-control experiment corrected the interpretation of the first forced-pressure result. The Blenny-owned pressure items used there were not proven to be visually presented while assessment mode was active, so their apparent inability to trigger overflow does not prove that assessment mode globally disables native overflow. In the later test, allowing Usage4Claude added enough presented width for the native overflow control to return; excluding it removed the control when the remaining presented items fit. Native overflow therefore appears to continue following the width of actually presented allowlisted items on this build.

A broader read-only scan covered MenuBarAgent's Objective-C metadata and Swift reflection strings plus the exported Swift surfaces of `MenuBarClient`, `MenuBarClientCore`, and `SkyLight`. MenuBarAgent contains internal `MenuBarOverflowComponent`, `ResolveOverflowGroupsPass`, `AssignCollapsedOverflowFramesPass`, and `wasOverflowIndicatorShown` state, but none is exported as a client-callable force-overflow method. `MBUtilities` exposes diagnostics, item listing, preferred-position reads/clear, and performance-test controls only. `MBMenuBarItemManager.requestMenuBarVisibility` controls the whole menu bar. `MBLockScreenMenuBarConfiguration.setLockScreenTrailingAreaWidth` is lock-screen-specific. The SkyLight surface contains `kSLMenuBarFirstMenuMaxXKey`, menu-bar bounds transactions, and the server-side `SLSMenuBarAgentManager`; mutating those contracts directly would impersonate or override MenuBarAgent/WindowServer state and was not attempted because recovery and ownership semantics are not established.

The scan also found AppKit's private `NSMenuBarRepresentation.availableStatusBarWidth` getter and `NSMenuBarItemView.setExplicitWidth:`. Setting one Blenny-owned main-menu item view to an explicit width of 1,200 points did not change native overflow, so that local representation property is not a usable pressure control on this build. Actual main-menu title width did propagate through the normal AppKit/WindowServer path.

## macOS 27 public API research

The companion [macOS 27 Menu Bar Public API Research](MACOS_27_MENU_BAR_API_RESEARCH.md) reviews Apple-published documentation, WWDC material, and both local SDK 26.5 and SDK 27 headers. The main findings are:

- macOS 27 adds a public `NSStatusItem` expanded-interface delegate/session lifecycle for an app's own custom status-item UI.
- `NSStatusItem.isVisible` remains `true` when the system temporarily hides an item for insufficient space, so it is not a public overflow signal.
- No new public cross-application item inventory, native-overflow observation, or priority-management API was located.
- `MenuBarAgent` remains a version-sensitive Accessibility observation rather than a documented management contract.
- SDK 27 confirms that direct `NSStatusItem.view`, `target`, and `action` are active declarations rather than deprecated compatibility members.
- Swift 6.4 imports the begin callback as `statusItem(_:didBegin:)`; the delegate protocol is not MainActor-isolated in this beta SDK, so an `@MainActor` conformance fails strict concurrency checking.

## Experiments and results

| Experiment | Execution status | Result |
| --- | --- | --- |
| Original Debug app with deployment target 27.0 | Run | Passed. Mach-O reports `minos 27.0`, `sdk 26.5`. This authorized app was not re-signed during the SDK 27 check. |
| SDK 27 SwiftPM build | Run | Passed with Xcode 27.0 beta and Swift 6.4. Mach-O reports `minos 27.0`, `sdk 27.0`. |
| Debug unit tests with SDK 27 | Run | Passed: 25 tests in 5 suites. |
| Release build and unit tests with SDK 27 | Run | Passed: 25 tests in 5 suites. |
| Expanded-interface public API compile probe | Run | Passed. The test compiles protocol conformance, `expandedInterfaceDelegate`, `expandedInterfaceSession`, and `cancel()` against SDK 27. It does not claim that callbacks have been exercised interactively. |
| App launch | Run | Passed. The process remained running from the generated `.app`. |
| Re-signed Phase B Debug app | Run | Passed. The new Debug interface launched, but replacing the ad-hoc signature invalidated its prior Accessibility trust as expected. No permission prompt was triggered automatically; Phase B overflow observations used an independent read-only system Accessibility client. |
| Reopen after closing diagnostics window | Run | Passed. Closing the last window kept the status-item process alive, and opening the same `.app` again restored the diagnostics window. |
| Diagnostics window | Run and visually inspected | Passed. Permission status and all four controls rendered correctly. |
| Manual refresh without Accessibility permission | Run | Passed. Returned zero elements in 0 ms, showed a clear permission note, and enabled JSON export without prompting. |
| Accessibility permission prompt | Run by user | Permission was granted and detected without a repeating prompt. |
| First trusted scan | Run | Completed in 10,110 ms, found 24 extras trees, and revealed that the initial Agent traversal was too broad. The raw local report was deleted after extracting anonymous aggregates. |
| Trusted `AXExtrasMenuBar` enumeration | Run | An offline top-level filter found 26 status-item candidates across 23 owner bundles. All 26 exposed actions; none allowed `AXHidden` or `AXPosition` writes. |
| Trusted `MenuBarAgent` tree enumeration | Run | `com.apple.MenuBarAgent` was found. Its relevant tree exposed native menu extras, hosted controls, and two overflow-control instances. |
| Native overflow detection against a live AX tree | Run | Two read-only `AXButton` elements had description `显示隐藏菜单栏项目`, no actions, and non-settable `AXHidden`/`AXPosition`. The localized classifier and tests were updated. |
| Native overflow event observation | Run for one complete expand/collapse cycle | A one-off read-only `AXObserver` registered directly on the live overflow `AXButton`. Opening it produced `AXValueChanged` with state `expanded` and description `隐藏菜单栏项目`; closing it produced `AXValueChanged` with state `collapsed` and description `显示隐藏菜单栏项目`. No recurring poll, global input monitor, event interception, or Blenny-side synthetic input was used. This establishes that the state transition is event-observable on this build, not yet that it is reliable across displays, relaunches, languages, or future builds. |
| Privacy-scoped confirmation scan | Run | Completed in 282 ms. It checked 123 eligible processes, found 24 extras trees and one Agent process, and emitted 120 bounded records: 24 manageable candidates, 2 native overflow controls, 23 structural elements, and 71 system-presentation records. No element or time limit was reached. |
| Privacy-boundary validation | Run | The corrected report contained zero `AXApplication`, `AXMenu`, `AXMenuItem`, or `AXWebArea` records. Agent presentation roots were bounded; the deeper Agent records came only from its dedicated `AXExtrasMenuBar` tree. |
| Candidate write-surface check | Run | All 24 candidates exposed actions, but none exposed settable `AXHidden`, `AXPosition`, or `AXSize`. Two menu-bar-sized Agent root windows reported settable `AXPosition`; they remain classified as system presentation and were not modified. |
| Diagnostics report display | Run, defect fixed and rerun | The trusted scan completed and JSON export worked, but a zero-sized text view initially made the report appear blank and a permission refresh replaced the completion summary. The final build displays JSON and preserves the completion summary; a zero-item read-only report was used for the visual rerun after rebuilding reset local trust. |
| Consecutive static identity comparison | Run | Two bounded scans 39 seconds apart each found 24 candidates. Identity v1 matched 23/24; one same-owner item changed one numeric scalar in an 11-character semantic label. Replaying both reports through the v2 numeric-mask rule matched 24/24. This validates the specific fix, not lifecycle stability. |
| Identity stability across app relaunch/reflow/sleep/display change | Not run | Requires trusted captures and a controlled test matrix. |
| Blenny status-item menu | Run before and after Phase B | Clicking Blenny opened a native menu containing Open Diagnostics, Refresh, permission status/request, and Quit. The menu remained functional after all length pulses. |
| Phase B, 80 pt pulse | Run once | Blenny remained present in the collapsed menu-bar presentation. Native overflow, clock, and Control Center remained available. Automatic restoration to `NSStatusItem.variableLength` completed after eight seconds. |
| Phase B, 160 pt pulse | Run once | Blenny remained present in the collapsed presentation. Native overflow remained available; no critical system control disappeared. Automatic restoration completed after eight seconds. |
| Phase B, 320 pt pulse | Run once | Blenny disappeared from the collapsed presentation and appeared when the native overflow control was opened. The overflow label changed from `显示隐藏菜单栏项目` to `隐藏菜单栏项目`. After automatic length restoration and closing overflow, Blenny returned to the collapsed presentation. |
| Phase B Release isolation | Inspected | Release binary strings contain no Debug experiment warning or controls; the Debug binary contains the clearly labeled experiment surface. |
| Preferred-position domain discovery | Run, read-only | `com.apple.MenuBarAgent` currently contains only two analytics values. Fifteen live preferred-position keys were found across `com.apple.controlcenter` and `com.apple.systemuiserver`; the selected non-critical third-party test domain contributes one additional key. All 16 values are CFNumbers of the same representation. |
| Phase C baseline snapshot | Run, read-only | Captured the two system domains plus the selected test domain into a mode-`0600` ignored backup. A SHA-256 fingerprint covers domain scope, keys, value types, and values. |
| Restore preview | Run, read-only | Immediate preview found identical backup/current fingerprints with zero set and zero remove operations. A zero-operation restore command also completed final read-back verification without calling a preference write. |
| One-item priority dry-run | Run, no write | Prepared one unsupported Debug operation for Usage4Claude, changing its sole preferred position from 510 to 6000. The current state matched the backup fingerprint and the proposed state received a distinct fingerprint. No preference value or process state was changed. |
| Phase C real preferred-position write | Run once after explicit confirmation | The Debug writer changed only Usage4Claude's sole value from 510 to 6000. Read-back matched the proposed 16-entry fingerprint. No automatic retry or continuous reconciliation ran. |
| Immediate layout observation | Run | Usage4Claude remained at AX x=913. Native overflow remained at x=374.5, Control Center at x=1489, and clock at x=1562. The stored preference changed, but the live layout did not. |
| Usage4Claude relaunch under proposed state | Run once | After a graceful third-party-only relaunch, the value remained 6000 and Usage4Claude appeared at x=914. The one-pixel shift is not evidence of priority control; no meaningful reordering or overflow change occurred. No system UI process was restarted. |
| Non-empty restore | Run and verified | The writer restored the original CFNumber value 510 and verified the complete baseline fingerprint. After relaunching Usage4Claude under the restored state, it returned to x=913. A final preview reported zero set and zero remove operations. |
| Critical presentation-control validation | Run after unlock | Control Center opened and exposed its normal controls, and the clock opened Notification Center. Both were closed without changing their contents. Native overflow changed from `显示隐藏菜单栏项目` to `隐藏菜单栏项目` when opened and returned to its original label when closed. |
| Private API runtime availability scan | Run, read-only | `MenuBarClientCore` loaded from the dyld shared cache. The assessment assertion/configuration classes and expected Objective-C selectors were present with matching object/block encodings. No assertion was activated in this step. |
| Visibility restriction no-change assertion | Run once while locked | A configuration allowing all nine system-item identifiers and all 151 observed running bundle identifiers was accepted. The assertion remained active for two seconds, then `invalidate()` completed. MenuBarAgent logged both activation and invalidation and kept the same PID. |
| Single-bundle visibility restriction, locked | Run once | The same configuration omitted only the previously approved Usage4Claude bundle for two seconds. MenuBarAgent accepted and invalidated the restriction. Usage4Claude's owner AX tree continued to expose one item at the same frame before, during, and after, showing that the owner AX tree is not a reliable presentation-visibility signal. |
| Single-bundle visibility restriction, unlocked | Run once for 30 seconds | With native overflow expanded at baseline, Usage4Claude was identified as one 83-point status item rendering three circular usage indicators. During the assertion all three indicators disappeared and later items shifted into the freed space. After explicit invalidation the three indicators returned at their original frame. The removal freed enough width that native overflow itself disappeared during the assertion, so the stricter simultaneous-overflow case remains untested. |
| Visibility restriction under forced overflow pressure | Run once for 45 seconds; interpretation later revised | While excluding Usage4Claude, two Blenny-owned ad-hoc pressure items did not make native overflow appear. The later surrogate experiment showed that an ad-hoc Blenny status item could retain an owner-side AX object and frame without being drawn by MenuBarAgent during the assertion. The pressure items were therefore not valid evidence that assessment mode globally disables overflow. |
| Post-restriction system-control recovery | Run and visually inspected | Control Center opened with its normal controls, the clock opened Notification Center, and native overflow opened and closed with the expected label transition. Usage4Claude's three indicators were present after restoration. |
| Assertion disconnect recovery | Run once while locked | After a no-change assertion activated successfully, the probe exited through `_exit` without calling `invalidate()`. MenuBarAgent logged XPC connection invalidation followed by restriction invalidation about 25 ms later. Its PID remained unchanged. This confirms crash/disconnect cleanup for this build, not a permanent API contract. |
| Surrogate item created before/after restriction | Run with same-process and split-process probes | Creating the status item after assertion activation produced `isVisible == true` and an image but no presented window. Creating it before activation produced an owner-side AX item and frame, but MenuBarAgent did not draw the glyph while the restriction was active. Splitting UI ownership and assertion ownership into two temporary bundle identifiers did not change this result. |
| Blenny-only surrogate position write | Run and restored | The temporary UI bundle had no original preferred-position key. Writing its own autosaved status-item position to 500 moved its owner AX frame from an obscured/offscreen position to approximately x=948. This did not make MenuBarAgent draw the item during assessment mode. The key was removed on normal termination and the temporary preference domain is empty. No third-party position was changed. |
| Split-process surrogate expand/collapse | Run for one complete round trip | A public UI process posted a local distributed notification to a Debug-only policy helper. Initial collapsed activation completed in 11.5 ms, reveal in 34.7 ms, and conceal in 26.9 ms. The UI received the resulting state about 45.9 ms after the expand click and 30.5 ms after the collapse click. Usage4Claude's three indicators appeared and disappeared accordingly. There was no unrestricted gap because each replacement assertion activated before the preceding assertion was invalidated. |
| Surrogate visual safety check | Run and failed | Although the surrogate owner's AX item still accepted `AXPress`, no surrogate glyph was visible in menu-bar screenshots. Its frame overlapped a different presented status item, and invoking the invisible item also opened the underlying item's unrelated menu. The menu was dismissed without selection. This is unsafe and rules out the tested ad-hoc surrogate configuration. |
| Normally signed split-process surrogate | Run and failed; no click attempted | Temporary ignored UI and policy bundles were signed with an existing valid development identity without printing, exporting, or persisting identity details. The collapsed assertion activated in 12.3 ms. The UI owner exposed one AX item titled `B`, described as `Blenny 折叠组：展开`, at `948,3,48.5,24`, but a direct menu-bar screenshot showed only pre-existing items throughout that frame: neither `B` nor the double-chevron glyph was drawn. Normal signing therefore did not fix presentation. Because the target was invisible and overlapping, `AXPress` was deliberately not invoked. |
| Main Blenny bundle under visibility restriction | Run and user-confirmed | The actual `com.example.BlennyProbe` Debug status item was temporarily labeled `BLENNY MAIN`. The user confirmed it was visible after manually expanding native overflow without a restriction. A bounded assessment assertion then explicitly allowed the main Blenny bundle and all nine system-item identifiers while excluding only the approved Usage4Claude target. During the assertion, the user manually expanded native overflow again and confirmed that neither Usage4Claude nor `BLENNY MAIN` was presented. Both owner-side AX trees remained present. This rules out the temporary surrogate bundle as the sole cause, but does not reveal the additional private eligibility or identity rule that rejected Blenny despite its bundle identifier being allowlisted. |
| Installed and registered main Blenny bundle | Run and user-confirmed | A separate Debug build labeled `BLENNY MAIN` was assembled under ignored local storage without changing or re-signing the trusted original app. Its exact app bundle was copied to `/Applications/Blenny Assessment Probe.app`, verified byte-for-byte at the executable level, explicitly registered with LaunchServices, and launched with the same `com.example.BlennyProbe` bundle identifier. The user confirmed the normal baseline, then confirmed that Usage4Claude disappeared while the installed `BLENNY MAIN` remained visible during the same bounded assessment restriction. This establishes positive evidence for an installed custom control. Because installation location and explicit LaunchServices registration changed together, the decisive prerequisite has not yet been isolated between those two factors. |
| Installed custom-control reveal/conceal round trip | Run repeatedly and user-confirmed | An installed `BLENNY` status item sent event-driven commands to a separate Debug-only serial policy writer. Each replacement assessment assertion activated successfully before the preceding assertion invalidated, so there was no deliberate unrestricted gap. The user triggered seven measured transitions: four reveals and three conceals. Usage4Claude appeared and disappeared as requested, the Blenny control remained visible, and the user reported no flicker, jump, or perceptible delay. The policy activation average was 12.948 ms (7.177–28.100 ms); click-to-UI acknowledgement averaged 32.873 ms (27.378–47.909 ms). |
| Force-overflow private surface scan | Run, read-only | MenuBarAgent's internal overflow component, passes, and state were found, but no client-callable force-overflow method or setting was present in the MenuBarClient/Core exports or XPC protocols. Whole-menu-bar visibility, lock-screen-only trailing width, read-only diagnostics, and server-role SkyLight contracts were rejected as semantically different or unsafe. No system method was invoked. |
| Leading menu width without visibility restriction | Run for narrow/wide/narrow | Expanding the frontmost temporary Blenny app from four ordinary root menus to nine very long root menus moved one display's native overflow frame from x=374.5 to x=1487; the other display's x=637.5 control did not move. Returning to the narrow menu restored the first frame. This confirms that active-app leading width is a live per-display overflow input. |
| Leading menu width during visibility restriction | Run for narrow/wide/narrow | While the assertion excluded only the approved Usage4Claude bundle and Blenny's own diagnostic bundle, the narrow state exposed only the x=675 overflow control. The wide state added the first display's native overflow at x=1487. Returning to narrow removed that control again. This establishes that leading-menu pressure can force native overflow while hard hiding is active. |
| Blank leading spacer during visibility restriction | Run for spacer/narrow | One top-level Blenny menu title consisting of 180 non-breaking spaces added the first display's native overflow at x=895 without requiring visible long diagnostic labels. Returning to the ordinary narrow menu removed it. A private 1,200-point `NSMenuBarItemView.explicitWidth` attempt did not produce the same effect. |
| Leading-pressure ownership switch | Run once | With the blank spacer active, the first display exposed overflow at x=895. Activating Finder immediately removed that control and left only the other display's x=675 control. The pressure therefore follows the frontmost application's menu and cannot remain globally owned by a background Blenny process through the tested AppKit path. |

## Unit-test coverage

The current tests verify:

- case, diacritic, and whitespace normalization;
- Accessibility identifier precedence over changing titles;
- masking changing decimal runs in semantic labels while preserving digits in Accessibility identifiers;
- duplicate observation removal;
- deterministic ordinals for multiple semantically identical diagnostic observations; these ordinals are not product policy identities;
- omission of PID and position from persistent identity;
- recognition of a labeled MenuBarAgent overflow control;
- exclusion of unknown MenuBarAgent controls from manageable candidates;
- classification of a third-party menu bar item candidate;
- exclusion of application menus, menu items, ordinary windows, and nested application trees;
- one-level-only traversal of `MenuBarAgent` presentation roots;
- rejection of ordinary windows as menu bar presentation roots;
- removal of pointer/selector details from custom AX action names;
- recognition of the live Simplified Chinese overflow label and rejection when attached to a non-button role.
- compilation of the public macOS 27 expanded-interface delegate/session surface with SDK 27.
- deterministic preferred-position snapshot fingerprints including domain scope;
- lossless JSON round trips for the observed CFNumber representation;
- empty, set, remove, and mismatched-scope restore plans.

## Performance observations

- The untrusted manual refresh completed in 0 ms and performed no cross-process tree traversal.
- Idle behavior is event-free: there is no timer or recurring task after launch.
- One idle-process sample after approximately four minutes showed 0.0% CPU and 27,568 KiB RSS (about 26.9 MiB). This is below the tentative 40 MB target but is not a statistically meaningful benchmark.
- The first trusted scan took 10,110 ms and produced 3,355 elements because it traversed unrelated hosted application subtrees. This was a correctness and privacy failure, not an acceptable performance result.
- The corrected inventory filters background processes, stops at status items, inspects only one child level of menu-bar-sized Agent roots, caps each AX application at a 0.5-second messaging timeout, and caps the overall scan at five seconds.
- The corrected trusted scan completed in 282 ms with 120 records and did not reach either bound. This is one measurement on one busy-menu-bar state, not a performance guarantee.
- Two later bounded scans completed in 761 ms and 250 ms with 121 records each. Their candidate count remained 24; latency variation still requires a larger sample before setting a target.
- During one complete native-overflow expand/collapse cycle, the directly observed control delivered one relevant `AXValueChanged` transition for each direction. The observer was event-driven and idle between notifications. Latency was not instrumented in this first probe.
- The installed custom-control probe completed seven user-triggered assessment-allowlist replacements: four reveals and three conceals. Policy activation averaged 12.948 ms with a 7.177–28.100 ms range. Click-to-UI acknowledgement averaged 32.873 ms with a 27.378–47.909 ms range. The user reported no visible flicker, layout jump, or perceptible delay. The probe used notifications and one serial writer, not polling or continuous reconciliation.

## Recovery and cleanup

The controlled Phase C experiment temporarily changed one Usage4Claude preference value from 510 to 6000. It has been restored to 510. The complete 16-entry current-state fingerprint equals the pre-experiment baseline, and the restore preview contains zero operations. Usage4Claude was relaunched after restoration and returned to its pre-experiment AX coordinate. Every Phase B pulse restored `NSStatusItem.variableLength`, the overflow presentation was closed, and Blenny returned to the collapsed presentation. No system preference domain, critical system item, or system UI process was changed or restarted. Quitting Blenny removes its process-owned status item through normal AppKit/process teardown.

The visibility-restriction experiments did not write persistent state. Every normally completed assertion was explicitly invalidated. In a separate disconnect test, MenuBarAgent invalidated the restriction when the client XPC connection disappeared. The MenuBarAgent PID remained unchanged across the private-API probes. No active test assertion remains.

The later unlocked 30-second exclusion was also explicitly invalidated. Usage4Claude returned at AX frame `911,3,83,24`, its three circular indicators returned visually, and MenuBarAgent kept the same PID. MenuBar-only screenshots used for comparison were kept under ignored `LocalData/` during analysis and then deleted; they are not delivery artifacts.

The 45-second forced-pressure assertion was explicitly invalidated, its temporary pressure status item was removed, and Blenny's separate eight-second length pulse reported restoration to `NSStatusItem.variableLength`. The target bundle and native overflow returned, Control Center and Notification Center opened normally, and overflow completed an expand/collapse cycle. The ten-minute `caffeinate` guard was terminated early after verification.

The later read-only overflow observer performed no system-state write. Its test opened and then closed the native overflow control once; the final observed state was `collapsed`. The temporary observer source and binary were removed after recording anonymous results.

The surrogate experiment used only temporary bundle domains. Its Blenny-only preferred-position key was absent at baseline, set to 500 for the bounded test, and removed during normal termination. Both temporary UI and policy processes exited, the policy assertion was invalidated, and the preference domain is empty. Usage4Claude and the existing Blenny item returned. The final MenuBarAgent Accessibility tree exposed Control Center, the clock, and the collapsed `显示隐藏菜单栏项目` control. No surrogate status item, assertion, or open test menu remains.

The normally signed follow-up used only ignored temporary bundles and did not retain a certificate, identity hash, provisioning material, or signing log. Its assertion reached the 150-second bound and restored through its timeout path; the UI then received the policy shutdown notification and removed its temporary self-position key. Both processes exited. A final screenshot confirmed that Usage4Claude's three indicators, native overflow, clock, and Control Center were presented again. The temporary preference domain is empty.

The main-bundle visual follow-up explicitly invalidated its bounded assertion after the user's observation and received a successful restoration acknowledgement. Usage4Claude's three indicators returned in the final capture. The `BLENNY MAIN` Debug-only label was removed, the original Blenny Debug app was rebuilt and relaunched, and the tracked source returned to its pre-experiment state. Rebuilding through the current ad-hoc signing path invalidated the app's Accessibility trust; the user subsequently reauthorized that exact original build and the app again reported `Granted`.

The installed-copy follow-up preserved the reauthorized original app and its executable hash. After the successful observation, the assessment assertion explicitly invalidated and Usage4Claude returned. The installed copy was verified against the expected bundle identifier and executable hash, terminated, unregistered from LaunchServices, and deleted from `/Applications`. The untouched original app was relaunched from `build/debug`, retained the same executable hash, and still reported `Accessibility: Granted`. No assertion or installed experimental copy remains.

The later installed toggle probe completed repeated reveal/conceal transitions and then outlived its bounded policy helper. The helper process exited, causing MenuBarAgent to invalidate the process-owned restriction. The installed UI copy was subsequently terminated, unregistered, hash-checked, and deleted from `/Applications`. The untouched original trusted Blenny app was relaunched with its original executable hash. The anonymous timing log under `/tmp` was deleted after aggregate measurements were recorded. No toggle assertion or installed toggle copy remains.

The leading-menu pressure probe changed only its own active application menu and held no persistent preference. Each assessment assertion either invalidated during normal termination or reached its 120-second bound. The final run terminated normally, the temporary process exited, and focus returned to the previously active application. Usage4Claude's three indicators, native overflow, clock, and Control Center were present in the final menu-bar capture. The private `explicitWidth` experiment affected only a temporary AppKit view and disappeared with the menu/process. No SkyLight or WindowServer setter was invoked.

To remove local artifacts:

1. Quit Blenny from its status-item menu.
2. Delete the ignored `.build/` and `build/` directories if desired.
3. Delete any manually exported `*.blenny-diagnostics.json` files if they are no longer needed.
4. If Accessibility was granted, remove or disable Blenny in System Settings under Privacy & Security › Device Control and Data Access.

A timestamped preferred-position baseline exists under ignored `LocalData/Backups/`. It contains project-relevant local item identifiers and must never be committed. It is retained as recovery evidence until the spike is complete.

All trusted JSON exports and the temporary process sample were permanently deleted after anonymous aggregates were recorded. None was tracked by Git.

## Unresolved questions

- Are the overflow control's labels stable across language and display configurations?
- Which identity components remain stable across owner-app relaunch, menu bar reflow, sleep/wake, and display changes? Static numeric-title drift is now covered by identity v2, but non-numeric dynamic labels remain unresolved.
- Do the two observed overflow controls map deterministically to the two active menu bar presentation roots/displays?
- Does the overflow control continue delivering `AXValueChanged` after display changes, sleep/wake, MenuBarAgent recreation, and Accessibility permission changes, and what is its end-to-end notification latency?
- Does `MenuBarAgent` appear through `NSWorkspace` consistently on every display configuration?
- What are corrected trusted-scan latency and memory characteristics across repeated refreshes and display configurations?
- Does the new expanded-interface delegate receive begin/end callbacks correctly during mouse and keyboard activation? The SDK surface compiles, but interactive lifecycle behavior has not been run.
- Are the observed preferred-position keys now legacy owner metadata, or does MenuBarAgent consume them only through another trigger or state relationship? Changing one value and relaunching its owner did not produce meaningful reordering.
- Can a read-only before/after capture around a user-performed native reorder identify additional macOS 27 state without restarting MenuBarAgent or writing another guessed value?
- Does the visibility-restriction service remain callable without a private entitlement on later macOS 27 builds, and does disconnect cleanup remain reliable?
- Which part of the successful installed-copy setup is decisive: residence under `/Applications`, explicit LaunchServices registration, or another persistent owner record created by those operations? The executable and bundle identifier were otherwise unchanged.
- Does a production-signed and notarized Blenny retain its visible control across app updates, logout/login, sleep/wake, and MenuBarAgent recreation while the assessment restriction is active?
- Can an Automatic bundle be revealed after the overflow transition and placed in the intended expanded segment without visible layout flicker or synthetic reordering?
- After the user opens pressure-forced native overflow, can Blenny remove its blank leading spacer without immediately collapsing or invalidating the expanded group?
- Can Blenny temporarily own the active menu, observe one native-overflow interaction, and restore the preceding frontmost application without visible focus disruption, lost keystrokes, or a clickable blank menu region?
- Can pressure be scoped and restored independently for each display when the frontmost application changes or a display is added/removed?

## Go/no-go assessment

The custom-control architecture meets the `0.0.1` product-go threshold on the tested build. Probes launched outside `/Applications` failed the visual safety condition, while an installed and registered Blenny remained visible, hard-hid the approved third-party target, and drove repeated reveal/conceal transitions with bounded sub-50 ms acknowledgement and no user-visible flicker. Installation and LaunchServices registration changed together, so their individual contribution remains unresolved; a normally installed product satisfies both conditions in practice.

The corrected live scan provides positive evidence that third-party extras trees and native overflow controls are observable within a narrow, fast privacy boundary. A direct `AXObserver` experiment adds positive evidence that the native overflow control emits an event on both expand and collapse, so Blenny can observe this transition on the tested build without polling or intercepting mouse input. Phase B demonstrates that macOS 27's native overflow reacts to the public length of a Blenny-owned status item. The visibility-restriction service proves that an ordinary third-party process can visibly remove and restore one approved bundle and can rely on server-side invalidation when its XPC connection disappears. The later round trip also shows that allowlist replacement is fast enough to merit further study and that native overflow can return when the revealed items again require it.

The uninstalled custom affordances remain unsafe because owner-side AX presence did not guarantee pixels or a safe hit target. The installed main-bundle result changes the route: a normally installed Blenny can plausibly own the always-visible control while the assessment assertion handles hard hiding. The native-control alternative still has positive evidence as a fallback. An ordinary wide main menu and a visually blank non-breaking-space menu title caused MenuBarAgent to add the real overflow control under the restriction, but switching the frontmost application removed that pressure immediately.

The preferred-position experiment shows that values can be read, fingerprinted, changed through public CFPreferences functions, and restored exactly. It also provides important negative evidence: changing Usage4Claude from 510 to 6000 had no meaningful layout effect either immediately or after relaunch. A separate self-only position value did move Blenny's owner-side item frame, but could not force visual presentation during assessment mode. None of the 24 AX candidates exposed writable hidden/position/size attributes, and no public cross-application priority API was found. Preferred-position mutation is therefore not the primary backend for `0.0.2`; the installed custom control plus serialized visibility restriction is.

## Recommendation

Close `0.0.1` and begin the `0.0.2` integrated prototype. Move the proven installed custom control, bundle-level allowlist model, and assertion-before-invalidation handoff into a narrow Debug-only macOS 27 backend with one serial writer. Add deterministic restore tests and bounded lifecycle checks for normal quit, helper disconnect, app relaunch, and update-like replacement. Keep native-overflow pressure as a fallback research route. Do not invoke raw SkyLight menu-bar setters, the fixed user-session-transition assertion, or `campoDrag` without a proven read-only contract and recovery path. Do not click owner-side AX items that are not visibly presented or restart MenuBarAgent.
