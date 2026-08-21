# Blenny 0.0.1 Technical Spike

Status: Phase A implementation complete; trusted Accessibility capture still requires user authorization.

Date: 2026-08-21

## Scope and safety boundary

This document currently records only Phase A, the read-only Accessibility probe. Phase B status-item length experiments and Phase C layout-state experiments have not been implemented or run.

The Phase A build contains no Accessibility writes, Accessibility actions, synthetic input, mouse movement, WindowServer manipulation, Screen Recording dependency, private entitlement, injection, polling timer, or automatic reconciliation loop. A refresh is manually initiated and bounded to 4,096 Accessibility elements.

The implementation is clean-room Swift/AppKit code. It does not use or link Ice, Thaw, or PlatformRuntimeKit code or binaries. No license file has been added because the project license remains undecided.

## Environment and build

| Item | Observed value |
| --- | --- |
| Hardware architecture | Apple Silicon `arm64` |
| macOS | 27.0 |
| macOS build | 26A5416b |
| Xcode | 26.6 (17F113) |
| Swift | Apple Swift 6.3.3 (`swiftlang-6.3.3.1.3`, `clang-2100.1.1.101`) |
| Installed macOS SDK | 26.5 (25F70) |
| SDK-declared maximum deployment target | 26.5.99 |
| Blenny deployment target | 27.0 |
| App architecture | arm64 |
| Temporary Bundle ID | `com.example.BlennyProbe` |
| Signing used for local probe | ad-hoc |

There is a version mismatch in the installed developer tools: the host is macOS 27.0, while Xcode contains a 26.5 SDK. SwiftPM and the linker nevertheless produced the probe successfully with `LC_BUILD_VERSION minos 27.0` and `sdk 26.5`; `LSMinimumSystemVersion` is also 27.0. No macOS 26 fallback was added. This is sufficient to run the probe on this host, but a macOS 27 SDK should be used before treating SDK-specific behavior as final.

Build and test commands:

```sh
swift test
swift test --configuration release
./scripts/build-app.sh debug
open build/debug/Blenny.app
```

The app bundling script builds with SwiftPM, creates `build/debug/Blenny.app`, copies the centralized `Info.plist`, and applies a local ad-hoc signature. Build output is ignored by Git.

## Phase A implementation

The probe includes:

- One Blenny-owned `NSStatusItem` with a monochrome template SF Symbol and a native menu.
- An AppKit diagnostics window with explicit Refresh, Request Access, Open Accessibility Settings, and Export JSON controls.
- A non-repeating permission flow. The application checks trust without prompting at launch; only the explicit Request Access action asks macOS to show its permission prompt, at most once per process launch.
- A manual, actor-isolated Accessibility inventory. Cross-process calls do not run as a permanent main-thread polling loop.
- Enumeration of each running application's `AXExtrasMenuBar`, plus the children and extras tree exposed by a running `com.apple.MenuBarAgent` process.
- Per-element owner PID, bundle ID, tree source, depth, role, subrole, title, description, identifier, computed frame, actions, and read/settable results for `AXHidden`, `AXPosition`, and `AXSize`.
- A 4,096-element hard limit. There is no retry loop.
- A privacy-limited JSON report. It excludes process names, unrelated windows and Accessibility trees, file paths, images, and window contents. Required menu-item text fields are whitespace-normalized and capped at 256 characters.
- A conservative overflow classifier. A `MenuBarAgent` element that contains a recognized overflow/chevron Accessibility marker is labeled `nativeOverflowPresentationControl`. All other `MenuBarAgent` elements remain `systemOwnedPresentation`, never ordinary manageable items.
- A candidate `MenuBarItemIdentity` based on normalized bundle ID, Accessibility identifier when present, otherwise semantic title/description, role, subrole, and an instance ordinal. PID, a transient element observation key, image bytes, and coordinates are excluded from the persistent identity.

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
- `AXValueGetType` and `AXValueGetValue` for position and size.
- Attributes: `AXExtrasMenuBar`, `AXChildren`, `AXRole`, `AXSubrole`, `AXTitle`, `AXDescription`, `AXIdentifier`, `AXHidden`, `AXPosition`, and `AXSize`.

The code does not call `AXUIElementSetAttributeValue` or `AXUIElementPerformAction`.

### Version-sensitive or unsupported observations

- Treating bundle identifier `com.apple.MenuBarAgent` and the shape/labels of its Accessibility tree as architecture signals is version-sensitive observation, not a private API call.
- Native overflow classification currently depends on Accessibility identifiers or localized semantic labels containing known overflow/chevron markers. This heuristic must be validated against the actual macOS 27 tree after permission is granted.
- The System Settings deep link is only a convenience; the UI also provides a plain-language manual path in case the URL scheme changes.

No private framework, symbol, XPC service, entitlement, preference domain, or mutation mechanism is present in Phase A.

## Experiments and results

| Experiment | Execution status | Result |
| --- | --- | --- |
| Debug build with deployment target 27.0 | Run | Passed. Mach-O reports `minos 27.0`, `sdk 26.5`. |
| Debug unit tests | Run | Passed: 8 tests in 2 suites. |
| Release build and unit tests | Run | Passed: 8 tests in 2 suites. |
| App launch | Run | Passed. The process remained running from the generated `.app`. |
| Diagnostics window | Run and visually inspected | Passed. Permission status and all four controls rendered correctly. |
| Manual refresh without Accessibility permission | Run | Passed. Returned zero elements in 0 ms, showed a clear permission note, and enabled JSON export without prompting. |
| Accessibility permission prompt | Not run | Deliberately left for the user to initiate. |
| Trusted `AXExtrasMenuBar` enumeration | Blocked on permission | No evidence yet. |
| Trusted `MenuBarAgent` tree enumeration | Blocked on permission | No evidence yet. |
| Native overflow detection against a live AX tree | Blocked on permission | Classifier is implemented and unit-tested only. |
| Identity stability across app relaunch/reflow/sleep/display change | Not run | Requires trusted captures and a controlled test matrix. |
| Phase B status-item length changes | Not implemented or run | Out of current phase. |
| Phase C preferred-position reads/writes | Not implemented or run | Out of current phase. |

## Unit-test coverage

The current tests verify:

- case, diacritic, and whitespace normalization;
- Accessibility identifier precedence over changing titles;
- duplicate observation removal;
- deterministic ordinals for multiple semantically identical items;
- omission of PID and position from persistent identity;
- recognition of a labeled MenuBarAgent overflow control;
- exclusion of unknown MenuBarAgent controls from manageable candidates;
- classification of a third-party menu bar item candidate.

## Performance observations

- The untrusted manual refresh completed in 0 ms and performed no cross-process tree traversal.
- Idle behavior is event-free: there is no timer or recurring task after launch.
- One idle-process sample after approximately four minutes showed 0.0% CPU and 27,568 KiB RSS (about 26.9 MiB). This is below the tentative 40 MB target but is not a statistically meaningful benchmark.
- Trusted scan duration, item count, memory usage, and behavior across multiple displays are not yet measured.
- The inventory actor keeps cross-process Accessibility work away from AppKit UI updates and caps each refresh at 4,096 elements.

## Recovery and cleanup

Phase A changes no menu bar layout or system preference state, so there is no system-state restoration operation to perform. Quitting Blenny removes its process-owned status item through normal AppKit/process teardown.

To remove local artifacts:

1. Quit Blenny from its status-item menu.
2. Delete the ignored `.build/` and `build/` directories if desired.
3. Delete any manually exported `*.blenny-diagnostics.json` files if they are no longer needed.
4. If Accessibility was granted, remove or disable Blenny in System Settings under Privacy & Security › Accessibility.

No backup file exists because no system state has been written.

## Unresolved questions

- Does a normally signed Blenny build receive complete `AXExtrasMenuBar` trees from representative third-party status-item applications on build 26A5416b?
- Which element/attribute shape does this build expose for `MenuBarAgent` and the double-chevron overflow control?
- Are the overflow control's labels stable across language and display configurations?
- Which identity components remain stable across owner-app relaunch, dynamic title changes, menu bar reflow, sleep/wake, and display changes?
- How should multiple indistinguishable items from one bundle receive a stable ordinal if traversal order changes?
- Does `MenuBarAgent` appear through `NSWorkspace` consistently on every display configuration?
- What are the trusted scan latency and memory characteristics with a busy menu bar?

## Go/no-go assessment

No go decision can be made yet.

The app, data model, bounded read-only inventory, UI, export path, and tests are functioning. However, the required evidence for useful third-party enumeration and reliable native-overflow observation is still missing because Accessibility permission has not been granted. Stable identity across lifecycle events has also not been tested. Therefore Phase A is implemented but not empirically complete, and Phase B must not be treated as unlocked yet.

## Recommendation

Grant Accessibility access to this exact local probe build, relaunch it if macOS requests that, and capture/export at least two baseline scans: one with native overflow absent and one with it visible. Then repeat after relaunching one or more non-critical third-party status-item apps. Review the exported attributes and refine the overflow classifier and identity confidence rules before beginning Phase B.
