# Blenny 0.0.1 Technical Spike

Status: Phase A trusted baseline captured; one controlled Phase C write/relaunch/restore cycle completed; the tested preferred-position change produced no meaningful layout effect.

Date: 2026-08-21

## Scope and safety boundary

This document records the Phase A read-only Accessibility probe and one controlled Phase C experiment against a non-critical third-party status item. Phase B status-item length experiments have not been run. No critical system status item was modified or restarted.

The Phase A build contains no Accessibility attribute writes, Accessibility actions, synthetic input, mouse movement, WindowServer manipulation, Screen Recording dependency, private entitlement, injection, polling timer, or automatic reconciliation loop. A refresh is manually initiated, limited to 1,024 Accessibility elements, given a five-second wall-clock budget, and uses a 0.5-second per-application AX messaging timeout.

The implementation is clean-room Swift/AppKit code. It does not use or link Ice, Thaw, or PlatformRuntimeKit code or binaries. No license file has been added because the project license remains undecided.

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
- A candidate `MenuBarItemIdentity` based on normalized bundle ID, Accessibility identifier when present, otherwise semantic title/description, role, subrole, and an instance ordinal. Decimal runs in semantic labels are represented by a stable `{number}` token because live status text often contains changing counters or time values; identities using this heuristic are explicitly weak confidence. PID, a transient element observation key, image bytes, and coordinates are excluded from the persistent identity.

## APIs and attributes attempted

### Public AppKit/Foundation APIs

- `NSStatusBar` and `NSStatusItem` for Blenny's own menu bar item.
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
- The System Settings deep link is only a convenience; the UI also provides a plain-language manual path in case the URL scheme changes.

No private framework, symbol, XPC service, entitlement, preference domain, or mutation mechanism is present in Phase A.

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
| Reopen after closing diagnostics window | Run | Passed. Closing the last window kept the status-item process alive, and opening the same `.app` again restored the diagnostics window. |
| Diagnostics window | Run and visually inspected | Passed. Permission status and all four controls rendered correctly. |
| Manual refresh without Accessibility permission | Run | Passed. Returned zero elements in 0 ms, showed a clear permission note, and enabled JSON export without prompting. |
| Accessibility permission prompt | Run by user | Permission was granted and detected without a repeating prompt. |
| First trusted scan | Run | Completed in 10,110 ms, found 24 extras trees, and revealed that the initial Agent traversal was too broad. The raw local report was deleted after extracting anonymous aggregates. |
| Trusted `AXExtrasMenuBar` enumeration | Run | An offline top-level filter found 26 status-item candidates across 23 owner bundles. All 26 exposed actions; none allowed `AXHidden` or `AXPosition` writes. |
| Trusted `MenuBarAgent` tree enumeration | Run | `com.apple.MenuBarAgent` was found. Its relevant tree exposed native menu extras, hosted controls, and two overflow-control instances. |
| Native overflow detection against a live AX tree | Run | Two read-only `AXButton` elements had description `显示隐藏菜单栏项目`, no actions, and non-settable `AXHidden`/`AXPosition`. The localized classifier and tests were updated. |
| Privacy-scoped confirmation scan | Run | Completed in 282 ms. It checked 123 eligible processes, found 24 extras trees and one Agent process, and emitted 120 bounded records: 24 manageable candidates, 2 native overflow controls, 23 structural elements, and 71 system-presentation records. No element or time limit was reached. |
| Privacy-boundary validation | Run | The corrected report contained zero `AXApplication`, `AXMenu`, `AXMenuItem`, or `AXWebArea` records. Agent presentation roots were bounded; the deeper Agent records came only from its dedicated `AXExtrasMenuBar` tree. |
| Candidate write-surface check | Run | All 24 candidates exposed actions, but none exposed settable `AXHidden`, `AXPosition`, or `AXSize`. Two menu-bar-sized Agent root windows reported settable `AXPosition`; they remain classified as system presentation and were not modified. |
| Diagnostics report display | Run, defect fixed and rerun | The trusted scan completed and JSON export worked, but a zero-sized text view initially made the report appear blank and a permission refresh replaced the completion summary. The final build displays JSON and preserves the completion summary; a zero-item read-only report was used for the visual rerun after rebuilding reset local trust. |
| Consecutive static identity comparison | Run | Two bounded scans 39 seconds apart each found 24 candidates. Identity v1 matched 23/24; one same-owner item changed one numeric scalar in an 11-character semantic label. Replaying both reports through the v2 numeric-mask rule matched 24/24. This validates the specific fix, not lifecycle stability. |
| Identity stability across app relaunch/reflow/sleep/display change | Not run | Requires trusted captures and a controlled test matrix. |
| Phase B status-item length changes | Not implemented or run | Out of current phase. |
| Preferred-position domain discovery | Run, read-only | `com.apple.MenuBarAgent` currently contains only two analytics values. Fifteen live preferred-position keys were found across `com.apple.controlcenter` and `com.apple.systemuiserver`; the selected non-critical third-party test domain contributes one additional key. All 16 values are CFNumbers of the same representation. |
| Phase C baseline snapshot | Run, read-only | Captured the two system domains plus the selected test domain into a mode-`0600` ignored backup. A SHA-256 fingerprint covers domain scope, keys, value types, and values. |
| Restore preview | Run, read-only | Immediate preview found identical backup/current fingerprints with zero set and zero remove operations. A zero-operation restore command also completed final read-back verification without calling a preference write. |
| One-item priority dry-run | Run, no write | Prepared one unsupported Debug operation for Usage4Claude, changing its sole preferred position from 510 to 6000. The current state matched the backup fingerprint and the proposed state received a distinct fingerprint. No preference value or process state was changed. |
| Phase C real preferred-position write | Run once after explicit confirmation | The Debug writer changed only Usage4Claude's sole value from 510 to 6000. Read-back matched the proposed 16-entry fingerprint. No automatic retry or continuous reconciliation ran. |
| Immediate layout observation | Run | Usage4Claude remained at AX x=913. Native overflow remained at x=374.5, Control Center at x=1489, and clock at x=1562. The stored preference changed, but the live layout did not. |
| Usage4Claude relaunch under proposed state | Run once | After a graceful third-party-only relaunch, the value remained 6000 and Usage4Claude appeared at x=914. The one-pixel shift is not evidence of priority control; no meaningful reordering or overflow change occurred. No system UI process was restarted. |
| Non-empty restore | Run and verified | The writer restored the original CFNumber value 510 and verified the complete baseline fingerprint. After relaunching Usage4Claude under the restored state, it returned to x=913. A final preview reported zero set and zero remove operations. |
| Critical presentation-control validation | Run after unlock | Control Center opened and exposed its normal controls, and the clock opened Notification Center. Both were closed without changing their contents. Native overflow changed from `显示隐藏菜单栏项目` to `隐藏菜单栏项目` when opened and returned to its original label when closed. |

## Unit-test coverage

The current tests verify:

- case, diacritic, and whitespace normalization;
- Accessibility identifier precedence over changing titles;
- masking changing decimal runs in semantic labels while preserving digits in Accessibility identifiers;
- duplicate observation removal;
- deterministic ordinals for multiple semantically identical items;
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

## Recovery and cleanup

The controlled experiment temporarily changed one Usage4Claude preference value from 510 to 6000. It has been restored to 510. The complete 16-entry current-state fingerprint equals the pre-experiment baseline, and the restore preview contains zero operations. Usage4Claude was relaunched after restoration and returned to its pre-experiment AX coordinate. No system preference domain, critical system item, or system UI process was changed or restarted. Quitting Blenny removes its process-owned status item through normal AppKit/process teardown.

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
- How should multiple indistinguishable items from one bundle receive a stable ordinal if traversal order changes?
- Do the two observed overflow controls map deterministically to the two active menu bar presentation roots/displays?
- Does `MenuBarAgent` appear through `NSWorkspace` consistently on every display configuration?
- What are corrected trusted-scan latency and memory characteristics across repeated refreshes and display configurations?
- Does the new expanded-interface delegate receive begin/end callbacks correctly during mouse and keyboard activation? The SDK surface compiles, but interactive lifecycle behavior has not been run.
- Are the observed preferred-position keys now legacy owner metadata, or does MenuBarAgent consume them only through another trigger or state relationship? Changing one value and relaunching its owner did not produce meaningful reordering.
- Can a read-only before/after capture around a user-performed native reorder identify additional macOS 27 state without restarting MenuBarAgent or writing another guessed value?

## Go/no-go assessment

No go decision can be made yet.

The corrected live scan provides positive evidence that third-party extras trees and native overflow controls are observable within a narrow, fast privacy boundary. The state experiment adds positive evidence that the observed preferred-position values can be read, fingerprinted, changed through public CFPreferences functions, and restored exactly without continuous rewriting. It also provides important negative evidence: changing Usage4Claude from 510 to 6000 had no meaningful layout effect either immediately or after relaunch. None of the 24 AX candidates exposed writable hidden/position/size attributes, and no public cross-application priority API was found. Deterministic storage restoration is now demonstrated for one operation, but meaningful priority control is not. The current preferred-position hypothesis therefore does not satisfy the product's go condition.

## Recommendation

Do not repeat guessed preferred-position writes or restart MenuBarAgent. Prefer a read-only differential capture around a user-performed native reorder of the same non-critical item to determine whether macOS 27 updates another state source or relationship. In parallel, proceed with Phase B's Blenny-owned `NSStatusItem.length` and expanded-interface experiments because they use public, owner-scoped AppKit APIs. Treat cross-application priority control as no-go until a reproducible effect is found and reversed without critical system UI manipulation.
