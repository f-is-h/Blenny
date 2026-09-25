# 0.11.0 phase 1: permissions investigation

Status: **historical phase-one investigation, retained for evidence**. The
0.11.0 local milestone is complete; [the release record](RELEASE_0.11.0.md) and
[the technical spike](TECH_SPIKE_0.11.0.md) supersede intermediate pending claims
below. Mixed Apply/Undo and native drag acceptance have since passed on the
formal host. Broader revoke/regrant, stable signing/update continuity and public
Release authorization remain 0.12.0 gates.

Investigated on 2026-09-15 against `3962231757bb2a3e2f0a07706b3a16acf7db5cc2`
(`v0.10.0`). This document does not advance the application version, reopen the
accepted 0.10.0 milestone, promote ordering, or change the recovery contract.

The owner authorized the focused onboarding implementation, exact-file read
experiment and first bounded write/inverse packet on 2026-09-19. The later packet
used the exact installed candidate identified below and changed only the two
reviewed ordering values before restoring them. No visibility state changed and
management did not Resume.

Implemented source behavior:

- the first explicit setup action in a process calls
  `AXIsProcessTrustedWithOptions` with Apple's prompt option;
- a later setup action in the same process opens the existing Accessibility
  System Settings destination;
- no persistent “prompt already requested” flag suppresses a request after the
  app is reopened or replaced;
- return-to-app trust detection retains the existing bounded automatic refresh
  and draft safety gates;
- user-facing copy names Device Control and Data Access while source and API
  terminology retain Accessibility where technically accurate.

This is compile- and unit-test-verified only. It does not prove that a fresh
macOS 27 identity appears in the list, that a specific build avoids manual Add,
or that an ad-hoc update retains its row and grant.

Owner verification on 2026-09-19 subsequently established the fresh Device
Control case: the public request added an absent Blenny row in the off state;
the owner enabled it and the grant succeeded. Manual Add is now a fallback for
abnormal or stale identities, not an unverified normal first-use requirement.
The update/signature cases remain pending.

The same owner session confirmed the separate ordering problem: **Open System
Settings reaches Files & Folders, but Blenny has no row there.** The current
deep link cannot create a row and therefore is not an actionable authorization
flow when the list is empty.

## 1. Direct conclusions

1. **Device Control and Data Access is a system label on the inspected macOS 27
   build.** The system settings extension maps its `ACCESSIBILITY` resource key
   to that English label and to `设备控制和数据访问`. Blenny still calls this
   permission Accessibility. The existing public request is
   `AXIsProcessTrustedWithOptions`; it requests an asynchronous system prompt,
   not a grant. The user enables the app in System Settings. The renamed label
   alone does not prove access to arbitrary protected containers or a combined
   authorization API. Test AX trust and each required data operation separately.
2. **Do not require Full Disk Access by default. Its replacement is not yet
   proven for ordering and recovery.** Visibility assertions do not themselves
   use the menu-bar preference container. Ordering does: direct file reads,
   private preference reads/writes, owner-identity corroboration and durable
   inverse must all succeed under the proposed smaller grant. Successful AX
   enumeration or a single file read is insufficient.
3. **macOS 27 changes the App Data request model.** Current Apple release notes
   say cross-team app data and app group container access no longer prompts, is
   denied by default, and is managed in Privacy & Security
   (161835690). XProtect can additionally restrict targeted app data (178668601).
   The older Sonoma prompt-on-open explanation and the generic
   `NSAppDataUsageDescription` page must not be used to promise that prompt on
   macOS 27. Adding that purpose string is not an authorization fix. [A1–A4]
4. Recommend **capability-specific setup**: device control first, then only the
   data access required by an explicitly requested ordering operation. Exact-file
   `NSOpenPanel` selection plus a persistent security-scoped bookmark is verified
   for group-table access and already eligible owners, but it does not preserve
   the 0.10 Sandbox-owner sorting coverage. Keep a visibility-only fallback with
   explicit reporting of omitted sorting while the narrower owner-identity proof
   is developed. Full Disk Access is a separately disclosed fallback only if
   narrower candidates fail a complete, authorized inverse/lifecycle test.
5. **A missing Files & Folders row is no longer the first group-table blocker.** A
   usage-description key still does not create that row, but the isolated
   `NSOpenPanel` experiment granted the exact MenuBar plist to an ad-hoc app.
   Direct POSIX read, private container-preference read, same-binary reopen and
   one changed-CDHash rebuild all succeeded. The installed candidate also passed
   one exact two-key write and inverse for Lark/ChatGPT. Subsequent comparison
   disproved this as a complete replacement for the former broad App Data/FDA
   context: Sandbox-owner preference evidence became unavailable. A stable Developer
   ID/Sparkle update and the remaining recovery/lifecycle cases remain separate
   validation items.

## 2. Evidence and inspected baseline

Evidence labels used below:

- **O**: Apple public documentation, retrieved 2026-09-15. Version-specific
  release notes take precedence over older general guidance where they differ.
- **S**: current source or static inspection of the installed OS/app. This proves
  a call, resource, guard or packaged symbol, not a successful TCC operation.
- **H**: earlier repository/owner acceptance. It is not a fresh permission test.
- **V pending**: a normally launched exact app must demonstrate the result.

Baseline (S): clean `main` at `v0.10.0`; bundle version `0.10.0` / build `1`;
macOS `27.0 (26A5425a)`, arm64 installed executable. The single observed normal
Blenny process resolves to the app in `/Applications`, not an archived copy.
Its signature is ad-hoc, has no TeamIdentifier and displays no entitlements.
The displayed designated requirement binds its CDHash; it is not a stable
Developer ID team-based requirement. Strict signature verification passes.
The ordering writer symbol is present. Its executable exactly matches the
archived **Undo Auto Refresh** owner candidate. That proves artifact identity;
it does not prove the installed executable was rebuilt from the final tag.
The tagged documentation identifies this candidate family as optimized trial;
no new compiler invocation was used to establish optimization flags.

There are 126 archived/build app copies in the inspected repository roots, 125
using the current bundle ID. They were not launched, deleted or re-registered.
Only one running Blenny was observed. This is a scoped copy inventory, not an
exhaustive Spotlight/LaunchServices registration audit. An app name or bundle ID
alone cannot identify the binary receiving authorization. Exact paths, process
IDs, hashes and copy inventory remain in ignored local evidence.

Build distinctions (S):

| Build | Visibility backend | Ordering / control placement | State directory |
| --- | --- | --- | --- |
| Ordinary Release | Current allowlist only `26A5416b`; Bluetooth is the sole promoted system-item policy | Excluded | `PersistentPolicyPrototype` |
| Debug | macOS 27 major; wider admitted system capabilities | Included; ordering records the complete build but admits every macOS 27 build only after the live arm64/private-ABI/configuration contract checks pass | `ManualSystemItemTrial`, plus recovery stores |
| Optimized ordering trial | `release` compilation with explicit Swift/C `DEBUG` defines | Same capability gates as Debug | Same manual-trial directories |

Sources: `Scripts/build-app.sh:17–56`,
`Sources/BlennyCore/MacOS27/ExperimentalAssessmentRuntime.swift:28–38`,
`Sources/BlennyCore/MacOS27/MenuBarOrderingBackend.swift:1,110–140`,
`Sources/BlennyApp/AppDelegate.swift:2266–2288`.
**Ordinary Release failing management on this host is a runtime gate, not proof
of a missing permission.** Do not widen that gate in this investigation.

The release record's 594 Debug / 322 Release tests and owner acceptance are H.
This phase now has 600 passing Debug tests in 56 suites and 322 passing ordinary
Release tests in 34 suites. Fresh Debug, optimized ordering-trial and ordinary
Release packages under ignored `LocalData/` pass strict signature verification.
The corrected optimized trial was installed and launched; Debug and ordinary
Release were not launched. The earlier frozen optimized trial was installed and
used for the explicitly approved two-key write/inverse described in Round C.
No TCC database read/change, reset, synthetic input or visibility mutation was
performed.

## 3. Current request, return and failure chains

### Device control / Accessibility

`BlennyRootView.swift:833–840,3132–3207` and
`StatusItemController.swift:909` → `AppDelegate.requestAccessibilityAccess`
(`AppDelegate.swift:2006–2043`) →
`AccessibilityOnboardingPolicy.action` (`PolicyEditorViewModel.swift:3–17`):

- Trusted: call Refresh.
- Untrusted, local prompt-history flag false: save
  `AccessibilitySystemPromptRequestedForMenuBarOwnership` in Blenny defaults,
  then call `AXIsProcessTrustedWithOptions` with the prompt option.
- Untrusted, flag true: open the existing
  `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
  URL using `NSWorkspace.open`.

`AccessibilityAuthorization.swift:4–15` uses public AX APIs. Prompt return value
is current trust, not the user's eventual choice (O, A5). The local flag means
“Blenny requested a prompt”, not “the system displayed it”, “the user denied it”,
or “the system will only ever prompt once”. Existing one-time wording overstates
what the application knows. The exact deep-link destination and open success
are not checked; the fragment is a compatibility mechanism, not a verified
cross-version public settings-navigation contract.

Apple's guide describes alert → Open System Settings → enable the app. If absent
from the list, use Add and select the installed app (O, A6). Do not make manual
Add a mandatory initial step. No unconditional OS restart is documented for this
flow. Whether regrant takes effect without app relaunch on this exact identity
is V pending; do not borrow the deprecated `AXMakeProcessTrusted` relaunch rule.

Return chain: `NSApplication.didBecomeActive` or `NSWindow.didBecomeKey` →
`updatePermissionPresentation` → retained `AccessibilityGrantRefreshState` →
one `refresh()` when false→true, idle and draft-free
(`AppDelegate.swift:203–207,326–352,408–449,2065–2080`;
`PolicyEditorViewModel.swift:20–47`). Repeated presentation reads preserve the
pending grant. A draft blocks refresh. Busy/termination/invalidation gates can
also block it; there is no polling and no general proof that every blocked case
is drained immediately without another event. Trust loss routes to lifecycle
invalidation and bounded cleanup (`AppDelegate.swift:1883–1949`), not automatic
Resume. Restoring AX trust does not itself authorize another Apply.

**Refresh is not a universally side-effect-free test entry.** The first complete
refresh constructs the policy store, may recover an interrupted local commit or
migrate identity, may initialize/disable the manual trial's saved state, and calls
`recoverManagement` once (`AppDelegate.swift:503–609,621–689`;
`PersistentBundlePolicy.swift:291–312`). Ordinary Release can resume enabled
saved intent on its admitted runtime. Later observation does not replay ordering.
Do not launch the app, invoke a diagnostic delegate, or reuse this path as a
no-state experiment merely because its UI says Refresh.

### Data access

`readOrderingForBoard` → `MacOS27MenuBarOrderingBackend.capture` →
`readCorroboratedGroup`. File open/metadata/read `EPERM` or `EACCES` is converted
to `needsDataAccess` (`MenuBarOrderingBackend.swift:32–92`;
`AppDelegate.swift:3237–3265`). `DebugOrderingStatusBar` exposes Open System
Settings (`DebugOrderingView.swift:362–375`) →
`Privacy_FilesAndFolders` (`AppDelegate.swift:2400–2412`).

The Debug/optimized ordering path now uses `NSOpenPanel`, validates the exact
MenuBar plist, stores a security-scoped bookmark in the private DebugOrdering
directory, restores that scope on launch and automatically retries the ordering
read after selection. Ordinary Release contains neither the picker code nor its
user-selected-file entitlement or App Data purpose string. There remains no
separate public App Data status/request API and no FDA request/check.
`EPERM`/`EACCES` establishes an access failure, not its controlling policy or that
Full Disk Access is required.

The inspected system resource also names a combined **Files & Folders** page
for files, folders and other app data. Which row/switch appears for this precise
access, its scope, and whether an initial denied access is needed to populate it
are V pending. No unsupported deep link for an invented per-container service is
proposed. Fallback navigation is Privacy & Security, then the verified page.

### Other permissions

Open at Login uses `SMAppService.mainApp.status/register/unregister` and
`openSystemSettingsLoginItems` (`AppDelegate.swift:2082–2108`). This is optional
startup service registration, not a requirement for visibility or ordering.
No baseline Screen Recording, Input Monitoring, Automation/Apple Events, Contacts,
Bluetooth hardware access or administrator prompt is justified by these paths.
Managing the Bluetooth **menu item** does not imply using the Bluetooth radio.
The system describes device-control access as broad; explain Blenny's bounded
use without claiming the OS permission itself is narrowly limited to the menu bar.

## 4. Access inventory

All source positions refer to the investigated HEAD. `~` denotes the current
user. “Required” means required by the present implementation/contract, not an
immutable platform necessity. Exact failure behavior still requires live tests.

| Access and source | Purpose / necessity / scope | Mechanism, protection and denial behavior | Evidence |
| --- | --- | --- | --- |
| AX menu roots and menu-bar attributes: `AccessibilityInventory.swift:26–161,178–260`; `ApplicationMenuBarDiscovery.swift`; `NativeOverflowObservation.swift` | Required for owner attribution and native overflow observation; no window-content or pixel capture | Public AX reads/observer APIs; trust, traversal/time limits and owner checks. Untrusted/incomplete inventory blocks preparation; lost trust invalidates active context | S + A5; absent-row first grant and changed-CDHash regrant owner-verified; Deny/revoke pending |
| Running owner bundles, application icons: `AppDelegate.swift:2334`; `PolicyIconResolver.swift`; `PolicyEditorWindowController.swift:35–139` | NSWorkspace descriptors required for identity; icons are presentation and may fall back | Public process/bundle metadata and NSWorkspace icon lookup. No arbitrary user-document read or app-bundle modification. Failure must not invent identity | S; identity and fallback fixtures H |
| Visibility assertion: `ExperimentalAssessmentRuntime.swift:28–175`; `RevealAssertionWriter.swift:48–125`; `AppDelegate.swift:58–96` | Required for current third-party/numbered-item hide/reveal; no MenuBar plist read/write inherent to assertion | Private `MenuBarClientCore`, `MBAssessmentModeAssertion/Configuration`; OS/ABI guards, exact allowlist, serial replacement-before-invalidation, bounded cleanup. Unsupported runtime or activation fails closed | S/H; no Apple entitlement or FDA requirement proven for this private path |
| Group plist: `~/Library/Group Containers/com.apple.MenuBar/Library/Preferences/com.apple.MenuBar.plist`; `MenuBarOrderingBackend.swift` | Required independent configuration read, preflight and inverse verification; reads full bounded root, not only changed keys | Direct POSIX open/read, final-component `O_NOFOLLOW`, owner/link/type/size checks and repeated file/API agreement. The exact-file picker changed the isolated probe from `EPERM` to a successful bounded read, survived reopen and a changed-CDHash installed replacement, and supported corrected Apply/Undo | S + live read/write/inverse/reopen V; revocation pending |
| Group preference API: same domain/container, `TrailingItemPreferredPositions`; `MenuBarOrderingBackend.swift`; `MenuBarOrderingDefaults.m` | Required current writer, readback, Undo and control placement; **whole table is submitted**, with allowed key delta and unrelated values preserved | Private `_CFPreferencesCopyValueWithContainer` and `_initWithSuiteName:container:`; public `setObject`/`synchronize` within private namespace. All verification requires complete API/file agreement. If sources disagree, an operation-scoped exact-file observer waits once for write/rename/delete with a 15-second deadline, then performs one complete read retry. A source split in either direction is not a verified endpoint. The prior five-second check rejected a real Undo before the delayed file commit; no cache flush, polling, extra write or permission expansion was added | S + live delayed-commit reproduction V; event-driven correction passes 620 Debug tests, live acceptance pending |
| Non-sandbox owner preferences: `MenuBarOrderingBackend.swift` | Legacy corroboration for owners without an exact bundle-key anchor; enumerates keys and reads only `NSStatusItem Preferred Position ` values | Public CFPreferences current-user/any-host. Nil/incomplete or drift cannot silently become empty authoritative scope. The exact-bundle code-identity route skips this read | S; retained for executable-only mappings, not required for anchored owners |
| Sandbox owner metadata: `~/Library/Containers/<bundle>/.com.apple.containermanagerd.metadata.plist`; `MenuBarOrderingBackend.swift`; `SandboxOwnerPreferenceNamespace.swift` | Legacy identity corroboration for owners without an exact bundle-key anchor; reads MCMMetadataIdentifier and hashes metadata | Canonical standard container, descriptor-walk ownership/no-symlink checks, device/inode binding and bounded metadata. The exact-bundle code-identity route skips this access | S; private layout; no longer a baseline requirement for anchored owners |
| Sandbox owner preferences: `~/Library/Containers/<bundle>/Data/Library/Preferences/<bundle>.plist`; `MenuBarOrderingBackend.swift` | Legacy corroboration can read the **entire preference domain** via file and private API before filtering status-item values | File/API/file equality, stable container metadata and bounded values/bytes. The exact-bundle code-identity route skips this access. Executable-only mappings still require legacy proof and fail closed when it is unavailable | S; App Data protection O A1; no longer a baseline requirement for anchored owners |
| Owner/system code identity: `MenuBarOrderingBackend.swift:640–666,669–865` | Required signed process identity; sandbox entitlement identifies **target**, not permission held by Blenny. Pinned host UUID evidence is compatibility checking | Public Security code APIs; bounded system executable header reads under `/System/Library/CoreServices`; build/ABI validation. Unknown identity/UUID fails closed | S; readable signed binary is not permission to mutate its owner |
| Siri/Time Machine/Now Playing: `DebugSharedSystemItemTrialBackend.swift:14–69,90–195,238–345`; `SharedSystemItemManualTrial.swift` | Debug/trial visibility, including exact inverse. Siri: two `com.apple.Siri` keys. Time Machine: `com.apple.systemuiserver` menuExtras, VisibleCC and preferred position. Now Playing: current-host `com.apple.controlcenter/NowPlaying` | Private paired ControlCenter setters/getters; public exact CFPreferences restore and notification; serial receipts preserve absence/types/unrelated bits and bounded normalization. No direct plist mutation. Failure retains recovery / refuses unsupported state | S/H; no new least-permission live proof; not ordinary Release requirements |
| Own policy/previous backup/transaction marker: `AppDelegate.swift:2266–2312`; `PersistentBundlePolicy.swift:291–312,340–418,503–580` | Required own persistence and failure recovery. `~/Library/Application Support/Blenny/{PersistentPolicyPrototype,ManualSystemItemTrial}` | Foundation read/atomic write, private file modes, marker-based recovery; current store is **not identical** to descriptor-bound ordering store. Initialization may restore files. Failure blocks policy preparation/commit; no FDA should be requested merely for own normal storage | S; ungranted launch and storage failure pending |
| Ordering journal/lease/archive: `OrderingRecoveryStore.swift:17–48,185–338`; `AppDelegate.swift:136–138` | Required latest-Apply policy+order Undo and interrupted recovery; `.../Blenny/DebugOrdering` | 0700 directory, 0600 files, descriptor checks, exclusive lease, atomic durable writes and readback. Save failure prevents or preserves uncertain transaction; never delete receipt to dismiss access error | S/H; real restart under minimal grant pending |
| Control placement journal: `FallbackPositionRecoveryStore.swift`; `AppDelegate.swift:125–127`; `CoordinatedPolicyWriter.swift:36–180`; `FallbackPositionDelta.swift` | Required independent fish/arrow placement inverse under `.../Blenny/LocalData/FallbackPositionExperiment`; despite name, clean accepted placement is persistent user configuration | Same serial writer plus both leases; own canonical keys only, native identity, schema/type/endpoint checks, drift refusal. Uses the same group file/API access as ordering. Follow-up failure does not roll back preceding accepted Apply | S/H; do not call clean persistent record an unfinished experiment |
| Own defaults and status registration: `StatusItemController.swift:125–177,799–814`; `AppDelegate.swift:2006–2021` | Required prompt-history/defaults and public AppKit autosave; private position getters and temporary placement overrides are Debug-specific | `UserDefaults.standard`, `NSStatusItem.autosaveName`; Debug getter ABI checks. AppKit can persist state on status-item lifecycle; a normal launch is not a no-write probe | S |
| Optional exports/traces and validation delegates: `DebugBoundaryEvidence.swift`, `DebugSessionTrace.swift`, `AppDelegate.swift:2480–2565`, `Sources/BlennyLayoutProbe` | Diagnostics only. Explicit boundary export performs AX+ordering reads and writes own LocalData; may have broader read requirements than baseline visibility | Debug/explicit environment gates, bounded reports/private files. No FDA request should follow an optional diagnostic failure. Archived Research probes are not product requirements | S; only the separate layout-access probe was executed |

### Opportunities to reduce access

- Do not perform ordering/owner-container reads merely to enable baseline
  visibility; first prove the visibility flow without them in a no-auto-start
  test entry. Preserve full owner inventory and current intent.
- Request/check only necessary identity and collision evidence. Capture now skips
  owner preferences for a strictly signed owner with an exact bundle-key anchor;
  executable-only mappings retain the legacy preference proof and fail closed
  when it is unavailable.
- Preserve complete associated status-key enumeration, code-identity freshness,
  whole-owner grouping and unrelated-write protection on the anchored route.
- Do not remove group-file corroboration, recovery access, token collision checks
  or whole-owner completeness simply to make a denied request pass. Retain the
  container metadata/file/API checks wherever the legacy route is still used.
- Do not switch to direct plist writes: that changes daemon/cache/atomicity and
  restoration semantics, not merely permission scope.

## 5. Distinct security mechanisms

| Mechanism | What it means here |
| --- | --- |
| TCC / privacy and mandatory data protections | User consent and system policy. AX trust is process-specific. Other app data and FDA are separately evidenced capabilities; settings labels alone do not prove which operations are covered. macOS 27 also documents XProtect restrictions |
| App Sandbox | Additional process restrictions enabled by signed entitlements. Current installed Blenny is not shown as sandbox-enabled; target apps may be. Adding sandbox is an architecture change, not a way to bypass TCC |
| Entitlements | Code-signature claims/capabilities. A purpose string is not an entitlement. `files.user-selected.*`/bookmark entitlements describe sandbox access and do not authorize arbitrary system-private interfaces. Blenny cannot join Apple's `com.apple.MenuBar` group by claiming its name |
| Unix ownership/modes and ACLs | Must permit filesystem operations independently of privacy grants. `chmod`, root or FDA is not a generic fix for another mechanism or a failed Blenny identity guard |
| Signature / identity | Bundle ID, path, designated requirement, team, CDHash and responsible launch context are different facts. A shared bundle ID across ad-hoc builds does not prove stable consent or bookmark reuse. A developer-launched helper succeeding does not establish normal-app access |

The current record does not show Blenny's live TCC grants, nor determine whether
prior FDA belonged to Blenny, a terminal or an IDE. Do not infer that from the
running app or source. No developer identity, keychain or credential enumeration
is needed for this phase. No private entitlement, SIP change, input synthesis,
injection, global permission reset or database access is a candidate solution.

## 6. Candidate comparison and recommendation

| Candidate | Grant scope and user steps | Persistence / complete coverage | Decision |
| --- | --- | --- | --- |
| Device control only | One Blenny setup action; system alert/settings; enable exact app; return. Add app only if absent; authentication is system-controlled | AX trust checked on return. No proof this also grants protected file/API access. Visibility backend must be admitted | **Default starting point**; test data without adding grants before concluding another is needed |
| Device control + specific App Data setting | Open Files & Folders after a bounded, expected denial; enable the relevant access for exact app; return for one check | Avoids unrelated FDA scope, but the tested ad-hoc Blenny did not appear and macOS 27 exposes no public registration API | Defer; no actionable first-use flow is proven |
| Selected exact MenuBar plist + persistent bookmark, plus exact-bundle code identity | `NSOpenPanel` opens its Preferences directory; user selects the one displayed plist and chooses Grant Access; Blenny validates the exact canonical path. Public Security.framework evidence binds an exact bundle-key anchor to one live signed owner | Direct file/private container reads, changed-CDHash installed replacement, visible two-key Apply/Undo and same-binary reopen passed. The new implementation skips owner-container reads when an exact bundle anchor and stable code identity are available, and can carry unique executable-name sibling keys as one owner block. Deterministic Apply/Undo passes; real arbitrary-owner acceptance, revocation and Developer ID/Sparkle continuity remain pending | **Recommended Debug/optimized-trial route**; replaces the former FDA-era owner-container dependency for anchored owners, pending live acceptance |
| Selected specific directories + bookmarks | Select MenuBar container, then only necessary owner container roots (metadata + Data). Never Home, all Library or all Containers | Broader per-directory grant but better coverage of replacement/child paths. Existing parent descriptor traversal may still be denied. Does not prove API scope or indefinite authorization | Prefer smallest verified scope; compare file vs directory with actual reader, not an unrelated sample |
| Full Disk Access | Manually add/enable exact app in FDA; follow system quit/reopen requirement; return and verify | Broad privacy grant; still no guarantee for sandbox, private runtime, identity or future OS. Local system resources explicitly describe FDA grant/revoke taking effect after quit | Optional, separately approved fallback only after narrow route failure; never automatic |
| Add App Sandbox / group entitlement / helper | New signing and execution boundaries plus capability work | Not an authorization shortcut for another developer's group. Helper inherits neither every grant nor every bookmark by assumption | Out of scope; no recommendation to add |

“Fewest permissions” and “fewest clicks” are different. The one exact layout-file
selection takes more steps than a switch, while App Data and FDA are broader and
may require relaunch even if they seem convenient. Start with Device Control; for
Debug ordering, use the exact layout file plus the exact-bundle code proof. Keep
App Data and FDA as separately tested fallbacks only if the narrow route cannot
cover an intended owner. In the ordering trial, visibility-only Apply still uses
unified Undo/recovery machinery:
**a fallback cannot be promised until that policy-only path works without the
denied data access.** Separate control-placement follow-up must also be accounted
for. Ordinary Release not running the writer is not a test of this fallback.

## 7. Proposed concise flow and English copy

The picker strings below are implemented in Debug/optimized ordering builds;
other text remains proposed until its corresponding flow is implemented.

1. Show build compatibility independently. Only offer capabilities included in
   that build. Request device control on a deliberate setup action.
   - Heading: **Allow Device Control**
   - Body: **Blenny uses this access to identify menu bar items and observe the
     overflow control.**
   - Button: **Open System Settings**
   - Instructions: **Turn on Blenny in Device Control and Data Access, then return.**
   - Disclosure: **macOS grants broad control access. Blenny uses it for menu bar
     management.**
   Use the verified system label on the supported build; retain Accessibility
   in technical details. If keeping first-click AX prompt, call it **Set Up
   Access…** and say “requested”, never “granted”. Repeated clicks can open settings.
2. On return, recheck AX and run one bounded observation when safe. Preserve
   drafts and pending intent; no startup activation or persistence mutation in
   the dedicated permission check. Separate ordinary startup policy restoration.
   - Pending: **Finish or discard your draft to refresh.**
   - Denied: **Access is off. You can enable it in System Settings.**
3. When sorting is requested, read only the required scope and distinguish
   denied file, unavailable API, unsupported runtime, identity and storage errors.
   - Heading: **Menu Bar Layout Access**
   - Body: **Choose the menu bar layout file so Blenny can apply and undo the
     order you choose.**
   - Button: **Choose Layout File…**
   - Panel prompt: **Grant Access**
   The panel opens the exact Preferences directory and accepts only the expected
   plist after canonical-path validation. Do not describe this as a Files &
   Folders switch or Full Disk Access.
4. After data settings return or explicit selection, run one bounded check;
   coalesce window/application activation and honor draft/busy gates. “Checked”
   is not “Apply succeeded”. Never use a silent test write to label access ready.
5. If access is lost mid-operation, retain the journal and name the next action.
   - **Access is needed to finish restoring your changes.**
   - **Re-enable access, then choose Recover Changes.**
   - Partial commit: **Changes applied. Control placement needs attention.**
   - Committed but refresh failed: **Changes applied. Refresh to update the view.**
6. Only a proven necessary FDA fallback shows:
   - **Full Disk Access allows access to other apps’ data.**
   - **Enable it for Blenny only if you want to use sorting.**
   - Conditional system instruction: **Quit and reopen Blenny to use the updated
     access.** Do not terminate automatically. Explain beforehand that Quit
     releases visibility restrictions but keeps accepted order/control placement.
   If FDA is not accepted, keep the proven available capability and retained
   recovery data; never label an unperformed inverse as restored.

## 8. Staged experiments

### Completed read-only exact-file round — 2026-09-19

The owner authorized and performed the sole system grant action. The isolated
GUI probe used bundle ID `xyz.fi5h.Blenny.LayoutAccessProbe.20260919`, Xcode 27,
macOS 27 SDK, arm64, ad-hoc signing and only the public
`com.apple.security.files.user-selected.read-write` entitlement. It had no
status item, policy store, writer or management lifecycle.

- Before selection, exact `open(O_RDONLY | O_NOFOLLOW)` failed with `EPERM`.
- After selecting only `com.apple.MenuBar.plist`, the bounded read succeeded:
  2,954 bytes and 55 ordering entries. Evidence recorded metadata and a digest,
  not preference values.
- Resolving the saved bookmark and calling `startAccessingSecurityScopedResource`
  succeeded in the same process and after a same-binary relaunch.
- Rebuilding at the same path and bundle ID changed the ad-hoc CDHash from
  `c54931720b3d1efad128ead38e967db06fe4e594` to
  `9969db5d583aa19710ed3a914c4189651b9ebe9d`; the old bookmark still resolved.
- With that scope active, `_CFPreferencesCopyValueWithContainer` returned the
  same 55-entry ordering table.
- File identity, size, modification time and digest were unchanged across the
  experiment. `/Applications/Blenny.app` remained running and untouched.

This proves the two current read paths for the exact group preference on this
host. It does not prove the private setter, daemon adoption, physical ordering,
Undo, failure recovery, file replacement, revocation/regrant or a Developer
ID/Sparkle signature transition. Raw sources, builds, bookmark and JSONL evidence
remain only under ignored `LocalData/0.11.0-layout-access-probe/`.

### Common experiment authorization packet

Before each real round, fill in and obtain approval for: exact executable path,
SHA-256, bundle ID, signature requirement/TeamID/CDHash, compiler configuration,
macOS build, launch method, user session, grant changes, target owner IDs and
complete configured keys, planned value/type changes, duration, and inverse.
An isolated identity does not authorize a system write. No root-wide picker,
global `tccutil reset`, TCC SQL, SIP change, kill of MenuBarAgent, or automatic
Stop/Resume belongs in any packet.

Recommended environment: a separately approved local test account on the same
OS/hardware with its own menu-bar state, launched by Finder, not via a terminal
or IDE whose access could confound attribution. VM evidence can supplement
permission tests but cannot establish physical menu-bar compatibility. Do not
create the account or log out of the owner's session without approval.

Prepared build boundaries:

- P0: dedicated no-status-item/no-AppDelegate permission harness, based on this
  HEAD's readers; actual ID `xyz.fi5h.Blenny.LayoutAccessProbe.20260919`. No writer,
  policy-store initializer, startup management, import, observer-triggered writer
  or login registration. Output only under its private LocalData. Build with
  explicit Xcode 27 / SDK 27; one fixed identity across regrant trials.
- P1: fixture-only test target with injected file/API errors and temporary local
  stores; no live backend or normal app launch.
- P2: the real optimized ordering trial from the reviewed source, with a
  separately reviewed no-auto-start permission test mode, launched normally in
  the approved test account. Ordinary Release is retained as a negative
  build-gate comparison, not substituted for P2.

A different bundle ID alone does not isolate current hard-coded policy paths or
own-control keys. P0 cannot validate production own-control placement. P2 must use
the correct stable production identity in an isolated account, or undergo a
separate reviewed test identity adapter; changing IDs cannot bypass owner guards.
P0 was built and exercised read-only. P1 now includes deterministic exact-path,
private-mode bookmark round-trip and symlink-refusal tests. P2 Debug and optimized
ordering trial packages were built but not launched; ordinary Release was built
as the negative package comparison. All artifacts remain in ignored LocalData.

### Round A — authorization and exact read matrix

Start with a fresh approved test identity/account, no FDA. First record visible
settings state; do not inspect TCC storage. Request AX, exercise Deny, grant and
return, and recheck without launching any state-restoring product entry.

After separate approval for protected-path reads, test these operations in the
same process before adding data access, after the specific settings grant, and
after an exact picker grant (independent clean cases):

1. Exact MenuBar plist POSIX read using the current flags/metadata rules.
2. Exact private MenuBar preference getter; compare typed table with the file.
3. One approved non-sandbox owner's public preference enumeration/position read.
4. One approved sandbox owner's metadata, preference file, private Data-domain
   read, repeated identity/file/API agreement using the real descriptor walk.
5. Own temporary recovery-store save/read/lease/rename only in the harness's
   LocalData after that filesystem write scope is approved.

For each operation record NSError domain/code or errno, returned absence versus
failure, elapsed bound, app identity and settings before/after. A read-only
operation may register an app in system privacy UI; it still needs this round's
approval. Stop on unexpected prompt, unrelated scope or unclassified failure.
Do not equate a nil preference value with a deliberately absent baseline.
Capture the actual Files & Folders/App Data row and its label/scope. FDA remains
off. Close/reopen only the harness when approved and repeat once to test lifetime.

### Round B — deterministic failure and restoration

Use P1 to cover denied metadata/file/API access, missing vs denied preference,
stale bookmark and wrong selected path; identity drift, full owner-key scope,
permission loss before/after intent, after write and during verification/inverse;
lease failure, receipt save failure and uncertain save acknowledgement. Prove
no write on failed preflight, bounded inverse and durable pending recovery.
Prove return refresh once, retained drafts, busy-event drainage and no automatic
Resume, startup initialization or order replay in permission checks.
Use fixture stores to establish these invariants before a live failure experiment.

### Round C — one real Apply/inverse at a time

Only after A/B pass and a new exact packet is approved:

First packet, **authorized and executed on 2026-09-19; exact configuration
write and inverse completed, with physical verification unavailable**:

- Candidate: ignored `LocalData/0.11.0-layout-access-build/app-ordering-trial/Blenny.app`,
  version 0.10.0, optimized Release compilation with Debug ordering gates,
  arm64, ad-hoc bundle ID `xyz.fi5h.blenny`, CDHash
  `ce70edffb27cbeb835d939321293a1fff0ec8d14`, executable SHA-256
  `34e943a7c8998e50a73bd5b55126cd474a42d4f3f84a85b9de5408b3d6f00f5a`.
- Host: macOS 27.0 build `26A5425a`, one display. The installed accepted Blenny
  remains a different running binary and must be quit by the owner before this
  candidate is launched; Blenny must not automate Stop/Resume.
- Proposed targets: Snipaste and CleanShot X only if fresh process lifetime,
  bundle-signature, complete owner-key and preference-namespace preflight finds
  both configuration-eligible. Any absent, identity-ambiguous,
  sandbox-incomplete, Apple-owned or changed target cancels the write rather
  than substituting another app. AX frame overlap alone follows the 0.10.0
  configuration-first contract: it does not block an attributable write, but it
  makes automatic physical verification unavailable and requires owner-observed
  visual acceptance.
- Before Apply: copy the complete bounded group snapshot, target owner evidence,
  current policy/backup/markers, clean Undo ledger and control-placement record
  to a new private LocalData directory. Verify no unfinished receipt and preserve
  the existing clean Undo record outside the active store.
- Operation: grant the exact layout file to this candidate; prepare one
  ordering-only exchange; Apply once; capture file/API agreement and physical
  relative order; immediately choose Undo Changes once.
- Success: Apply and Undo each produce one serial write, file/API readback agree,
  the two targets return to exact original typed values and relative order, all
  unrelated group values/policy/control records remain unchanged, and the final
  active receipt is clean/restored as designed.
- Failure: no write after any failed preflight. After an uncertain or mismatched
  write, keep the durable journal and perform only the existing bounded inverse;
  do not retry Apply. If the inverse cannot be verified, stop with recovery
  pending and retain the accepted binary plus all evidence.

Observed result:

- The owner quit the previously installed binary. The frozen candidate was
  launched first from ignored `LocalData/`, then moved by the owner to
  `/Applications/Blenny.app`; the executable digest and CDHash remained exact.
  A Remove/Add attempt before selecting the installed candidate did not make the
  running candidate AX trusted. Selecting and granting the exact installed copy
  did. The evidence cannot distinguish path sensitivity from selection of the
  wrong or stale ad-hoc copy, so Remove/Add is not promoted to an update rule.
- The exact layout-file panel grant succeeded, produced a private 0600 bookmark
  and refreshed the protected 55-entry table. Management stayed stopped, no
  automatic Resume occurred and no ordering receipt existed.
- The first complete boundary export failed its own coherence flag because both
  Blenny control frames shifted 16 points during capture. A repeated export was
  coherent: management state, policy/lifecycle context and both control frames
  were unchanged across the 1.707-second sample.
- The coherent export found one stable process, one complete current-user owner
  namespace, one exact key and no token collision for each target. Their observed
  frames overlapped: Snipaste `(x: 379, width: 24)` and CleanShot X
  `(x: 375, width: 36)`.
- The initial experiment review incorrectly applied the legacy pairwise
  `OrderingIdentityResolver` geometry gate to the current configuration-backed
  Board. The 0.10.0 contract explicitly excludes AX geometry from configuration
  eligibility, and `overlappingProxyFramesRemainEligibleButVisuallyUnverified`
  passed in the 12-test Xcode 27 configuration-model run. The live Board also
  resolves both owners as configuration-eligible. Overlap means automatic
  physical verification can be `unavailable`; it does not weaken exact table
  write/readback, durable Undo or owner-observed physical verification.
- No Apply, target write, inverse or active recovery receipt occurred during the
  mistaken pause. The same authorized target packet remains eligible to continue;
  no substitute application or relaxed identity check is needed.
- After that no-write stop, the candidate quit normally and reopened from
  `/Applications/Blenny.app`. Management remained stopped, the saved bookmark
  restored exact-file access without another panel, the Board repopulated and
  no active ordering receipt appeared. Replacement, revocation and signed-update
  continuity remain unverified.
- The owner then prepared the reviewed exchange in Hidden. Hidden was a poor
  choice for manual visual acceptance because those items are intentionally not
  visible. Ordering writes do not require Resume, and management remained
  stopped throughout.
- Apply wrote the reviewed Snipaste/CleanShot X endpoint, but its immediate
  independent capture reported that the private container API and protected
  plist disagreed. The active schema-4 receipt remained at `applyIntent`; no
  automatic write retry occurred.
- After the local draft was discarded, one explicit Recover first captured the
  applied endpoint, persisted `restoreIntent` and issued the exact inverse once.
  Its immediate capture hit the same disagreement and retained the receipt.
  There was no second inverse.
- A separate read-only diagnostic later read both complete 55-entry tables as
  equal. Snipaste was `1097.5` and CleanShot X `1135.5`, exactly their original
  typed values. A final explicit Recover inspected that endpoint, performed no
  system write, archived the completed receipt and removed the active receipt.
  The archive records `preferencesRestored`, `configurationVerified = true` and
  physical verification `unavailable`.
- The full-table disagreement was transient write adoption, not evidence that
  the inverse failed. The first source fix waited 750 ms and repeated the
  complete corroborated read once only for this error. It did not poll or repeat
  the write; the later visible-pair trial showed that bound was still too short.
- The completed Undo triggered a separate automatic fallback-control placement
  update. Its old accepted receipt and both Blenny values remained unchanged
  after an identity refusal, so ordering recovery was unaffected. The source
  now skips that follow-up when the exact fallback AppKit identity is absent.
  Control placement remains a separate acceptance case.

The 2026-09-20 visible-pair round added the following evidence:

- The owner exchanged visible Lark Helper and ChatGPT. Physical movement
  succeeded, while the installed 750-ms build still retained `applyIntent`
  because the container API and protected plist disagreed at readback.
- The decoded table exposed an independent scope defect: Lark/ChatGPT changed as
  reviewed, but the global plan also exchanged unrelated Alfred/Tailscale values.
  Pure same-area sorting had included every globally eligible subject instead of
  only subjects whose relative order changed.
- One explicit ordering recovery restored all four values and cleared its active
  receipt. The automatic accepted fallback follow-up then changed only the fish
  key and retained its separate receipt after the same readback disagreement.
  One explicit **Undo Control Placement** restored that key. The owner observed
  only the fish and ChatGPT change relative position during that final action.
- Final read-only verification found all 55 decoded entries equal to the fresh
  pre-Apply baseline, API/file equality, and no active ordering or fallback
  receipt. The binary plist digest changed after serialization and is not used as
  a substitute for typed-table equality.
- Source now selects only pairwise inversion participants for a pure same-area
  order. A policy/area change still retains the complete global partition. Source
  also extends the one API/file settlement wait to five seconds. Both corrections
  pass deterministic tests.

The corrected candidate then passed the bounded visible-pair round:

- The installed executable SHA-256 was
  `f560c4f84ed5879ef907b70cc11b5875f4dccd4babfe55519dd6494a08d86a48` and its
  changed ad-hoc CDHash was `210b10f3b984a70c45f2f9d284ba746541892c7a`.
  Device Control required the owner to enable the replacement identity again.
  The existing exact-file bookmark restored without another picker.
- A coherent 55-entry pre-Apply boundary equaled the prior restored baseline.
  Management stayed stopped and both recovery stores had no active receipt.
- The pure same-area draft inverted only Lark Helper and ChatGPT. The schema-4
  plan and successful receipt contained exactly their two keys; Alfred,
  Tailscale and both Blenny controls were absent.
- Apply completed without an API/file-disagreement error and recorded
  `configurationVerified = true`. The owner observed the pair exchange relative
  order with the fish still between them. The run does not reveal whether the
  first corroborated read agreed or the one five-second retry was used.
- **Undo Changes** completed without error. The complete typed table had zero
  differences from the fresh baseline, both active receipts were absent, and the
  archive recorded `preferencesRestored` with `configurationVerified = true`.
- An accidental **Undo Control Placement** had no receipt and changed no key. It
  left stale **Restoring control positions…** text after controls re-enabled; this
  presentation issue is separate from ordering correctness and recovery.
- After clean Undo, quitting and reopening the same candidate required neither a
  Device Control action nor another file selection. The Board loaded normally,
  management stayed stopped, no active receipt reappeared, and the complete table
  remained equal to the fresh baseline. Revoke/regrant and signed update identity
  remain separate cases.

The formal macOS 27 major-gate recovery round added cross-build evidence:

- The optimized trial executable SHA-256 was
  `b209ff6fb8edfd1167b7fd526d8dc1d8671908841b13751924834f29d913a60f`.
  Its changed ad-hoc identity required the owner to remove/add and enable the
  exact installed app under Device Control. The grant became effective without
  restarting Blenny, and the existing exact-file bookmark remained usable.
- Read-only preflight kept management stopped and proved byte-for-byte equality
  with the preserved failed-recovery state: 55 table entries, 16 controlled
  originals, nine controlled committed values and no unknown value. The active
  `restoreIntent` receipt retained all 25 originals as pending and had no retry
  count; policy remained at the applied endpoint.
- One separately authorized **Recover Changes** consumed the bounded retry and
  completed. The active receipt disappeared; the archive records
  `preferencesRestored`, `configurationVerified = true` and
  `configurationRestoreRetryCount = 1`. All 25 controlled keys equal their exact
  originals, all 30 unrelated keys equal the preflight table, RunCat returned to
  Visible, management remained stopped and no fallback receipt was created.
- This validates recovery across the tested macOS 27 public-build transition
  under the major-version gate. It does not establish arbitrary future private
  ABI compatibility, Developer ID/Sparkle continuity or absolute physical
  coordinates; the live ABI/readback/identity gates and update matrix remain.

A subsequent RunCat/Dato round exposed a narrower readback issue:

- The reviewed two-key write visibly exchanged the menu-bar items. After the
  bounded wait, the protected plist contained the target while the low-level
  container reader remained on the exact previous generation. The old rule
  treated all disagreement as failure and performed its one exact rollback.
- Read-only evidence then confirmed both keys at their originals, a clean
  verified receipt, all 55 entries and no pending recovery. The user-visible
  failure was therefore an over-strict post-write decision rather than a lost
  inverse or insufficient file permission.
- Source now accepts only that exact two-generation post-write endpoint after
  the existing single wait. Pre-write reads remain strict; no write is retried;
  arbitrary disagreement, partial tables and unrelated drift remain failures.
  The optimized candidate is built and statically verified but not installed,
  so live Apply/Undo acceptance remains pending.

- Use two non-critical, approved menu-bar owner targets with existing resolvable
  position values; add one sandbox owner as a separate round. Owner names/keys
  must be filled from fresh preflight, not guessed from historical receipts.
- Start with no unfinished receipt, and archive the existing **clean** Undo/control
  records without consuming them. Snapshot full group root plus exact target
  values/types/absence, own policy/backup/markers, relevant system-item baselines,
  signature/identity and visible/expanded baseline. Store privately in LocalData.
- First visibility-only Apply + Undo Changes; then ordering-only Apply + Undo;
  then mixed Apply + Undo. Run consecutive A/B Apply to prove single-level Undo
  returns to A, then execute the separately prepared exact inverse to the
  pre-experiment baseline. Do not lose baseline by assuming Undo is multi-level.
- Separately authorize control placement/Undo Control Placement, including the
  existing accepted-placement follow-up after area Apply/Undo. Snapshot both
  own control keys and preserve every non-control value.
- Separately test admitted Siri/Time Machine/Now Playing visibility and inverse
  if their least-permission support is to be claimed. No Siri, Time Machine or
  Control Center sorting experiment is included.

Success requires verified exact configuration inverse and distinct owner-observed
physical restoration/click behavior. Full raw plist overwrite is not the normal
inverse: restore only owned known transitions through the same serial writer,
preserving unrelated changes. Unexpected target drift stops the round. A file
hash alone is insufficient when macOS adopts/normalizes preferences separately.

### Round D — revoke, reopen and update

After clean restoration first test AX/data revoke and regrant with no pending
write. Approve any required Quit separately: the inspected FDA resource explicitly
defers grant/revoke until quit. Do not promise revocation is immediate or that
reboot is required. Exact App Data/AX regrant behavior is measured, not assumed.

For interruption-after-write testing, prepare a recoverable checkpoint and a
tested recovery executable before approval. Retain the journal and exact baseline;
the owner must be willing to regrant the **same needed access** for restoration.
If access remains denied, the honest result is “recovery pending”, not a bypass.
Do not disable production access to create a failure. Reopen P2, explicitly
recover pending work once, and verify the entire inverse. Clean accepted order
must not replay or undo on startup, Stop or Quit.

Later update tests: same signature identity/new version, changed ad-hoc CDHash,
future ad-hoc→Developer ID transition, moved/copied app, stale bookmarks, old
receipt schemas and downgrade rejection. Preserve old binary and receipts until
inverse succeeds; an old binary that rejects schema 4 is not a valid recovery
fallback. Developer ID signing/notarization is a later separately approved phase.

### Acceptance ledger

| Case | Automated / static evidence | Required real evidence | Current status |
| --- | --- | --- | --- |
| Fresh AX request, Deny, grant, absent-list Add | Existing onboarding/refresh policies; prompt flag audit | Correct system page, exact installed app, actual trust after return | Absent row auto-add/off and enable/grant owner-verified; Deny/regrant/update pending |
| Revoke/regrant AX | Existing retained-grant and lifecycle fixtures | Deferred revocation/reopen, bounded cleanup, no silent Resume | Changed-CDHash ad-hoc replacement: retained on-row grant failed code-requirement matching; off/on was insufficient; remove/add/enable became effective without process restart. Stable signed update remains pending |
| Data settings grant/deny/revoke/regrant | Current error route identified; new capability/return tests needed | Actual App Data switch, API+file coverage with FDA off | Pending |
| Permission return with no draft / draft / busy | Three existing grant-state tests; additional event-drain/no-start tests proposed | One check, retained draft, no repeated prompt/Apply | Partial H/S; live pending |
| Visibility-only Apply and Undo | Policy/serialization and unified Undo tests in 0.10.0 | Trial with data denied; every relevant visibility family separately | Minimum unproven |
| Ordering-only and mixed Apply, consecutive Apply and Undo | Scope, drift, failure, real-store unified Undo H; pure-sort inversion scope and full policy-partition scope tested; Apply -> Stop -> Undo and Apply -> Stop -> reopen -> Undo preserve stopped state; recovery accepts only a freshly code-verified stable system host after PID/launch-time replacement while fresh Apply still requires review; verified-zero-change inverse retry is capped at one; both directions of API/file split require actual agreement after one bounded event-driven wait | Full group/API/owner proof, exact inverse, physical observation | Corrected visible pair changed exactly two keys, moved both ways, and Undo restored the full table without error. Cross-build recovery restored all 25 controlled values and preserved all 30 unrelated values. A later RunCat/Dato write visibly applied but the old universal API/file-equality rule rolled it back; read-only evidence confirmed the exact rollback. The historical generation-split exception is superseded by the September 25 delayed-file-commit reproduction and event-driven verification in the 0.11.0 spike. Build 14 passed five Applies and three Undos in one process, including five real file-event waits of 1.609–8.176 seconds; a fresh reader confirmed the complete original table and no active recovery receipt remained. All 620 Debug tests pass. Board movement actions were exercised; physical coordinates remain independently unverified |
| Own controls, follow-up and independent inverse | Native identity/delta/schema/lease tests H | Both own keys, unrelated keys unchanged, native buttons usable | Earlier automatic follow-up and explicit Undo were recovered; corrected pure sort did not write controls. No-receipt Undo is a no-op but leaves stale footer text |
| Refusal before intent / loss after write / inverse denied | Injected failures proposed; existing restoration tests H | Retained journal; regrant and bounded exact recovery | Minimum unproven |
| Relaunch after grant; after clean commit; after interruption | Startup/store chain audited | Same access still usable, no replay of accepted order, full inverse | Same-binary reopen after clean Apply/Undo passed with bookmark and AX grant retained; accepted-order and interrupted reopen pending |
| Stop/Quit with accepted order | Existing persistent-order/control contract H; unified Undo preserves current management state, accepts a fresh inactive recovery coordinator only when it has no active plan, revalidates restarted system hosts by stable verified identity, and caps a verified-zero-change retry at one | Retention, visibility release, and exact later Undo under minimum grants | Stop retained accepted order and disabled management. Three Undo attempts and one Recover failed closed without changing the table. After replacement, regrant and exact preflight, one bounded retry restored the complete original table and policy while management stayed stopped; no automatic Resume or fallback mutation occurred |
| Exact-file picker, bookmark and exact-bundle identity | Exact path/private store tested; public code identity, anchored alias grouping, Apply/Undo and identity-drift refusal pass deterministic tests | Dato/RunCat exact two-key Apply/Undo under the selected-file grant; read-only admission for Coffee Buzz and anchored Usage4Claude alias | Implementation verified; exact-bundle live acceptance pending |
| Version/signature/path change | Stable-ID requirement; Debug/trial entitlement inspected; macOS 27 major-version gate plus per-write complete-build freshness and live ABI checks | Same-ID/path ad-hoc replacement retained the file bookmark. Device Control required removing the old row and adding/enabling the changed-CDHash bundle; toggle-only regrant failed. Developer ID/Sparkle and moved path remain | Partial; formal macOS 27 build is admitted without a per-build list, ad-hoc development identity behavior established, distribution transition unproven |
| Ordinary Release comparison | Ordering absent; current-host runtime unsupported | Only on admitted runtime or separately approved compatibility work | Not ordering evidence |

## 9. Proposed implementation boundary and owner decisions

The agreed permission-name/copy accuracy, exact-file picker/bookmark flow and
exact-bundle code-identity route are implemented for Debug and optimized ordering
builds. Preserve every established identity, scope, lease, verification and
restoration guard while completing the separately authorized live rounds.

Owner decisions needed before broader acceptance or promotion:

1. Retain Device Control → exact layout-file selection for group-table access,
   then use the implemented exact-bundle code proof instead of owner-container
   reads for anchored owners. Do not require FDA for the baseline. Live acceptance
   must still establish that the intended current owners are admitted and fully
   recoverable under this route.
2. Decide separately whether to continue with mixed visibility/order,
   interruption, revoke/regrant and reopen/update rounds. The corrected
   visible-pair Apply/Undo is accepted; it does not establish those lifecycle
   cases. Keep control placement as a separate reviewed packet.
3. The owner selected the exact-bundle proof. Source now requires a strictly valid
   public code identity, one exact bundle-key anchor, unique live token resolution
   and stable process lifetime. Executable-only mappings, token collisions and
   signing drift still fail closed. This is implemented and automatically tested;
   real current-host acceptance is pending.

No decision is needed now on license, signing certificates, release promotion or
publication. No push, commit, version edit, history rewrite, license adoption,
further app replacement, launch or system mutation is authorized after this
accepted trial without a new owner-approved packet.

Proposed future contract language (not effective until accepted):

> Blenny requests access only for the capability the user chooses. Authorization
> is never inferred from a previous successful read or another process. A
> permission check does not Apply, Resume, replay ordering, or consume Undo.
> Ordering is available only when the required identity, read, write-verification
> and persistent recovery paths are supported. Loss of access retains recovery
> evidence and blocks unsafe writes. Recovery can require the user to re-enable
> access. Optional diagnostics do not expand baseline permission requirements.

Existing effective contracts remain: Visible / Revealable / Hidden; third-party
owner blocks; one serial writer; identity-bound, bounded operations; durable
inverse; Undo Changes reverses the last successful Apply's areas and order;
Stop/Quit preserve accepted order and control placement. The Clock limitation,
deferred Siri/Time Machine/Control Center sorting and absence of absolute-position
or native-arrow-adjacency guarantees remain unchanged.

## 10. Official sources

All links below were retrieved on **2026-09-15**. Retrieval dates are not claimed
publication dates. Historical WWDC sessions are explicitly dated by event year.
No third-party report is used as proof of Blenny's required permissions.

- **A1 — [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes)**:
  System Integrity Protection 161835690/178668601 and TCC 90775556. The live page
  is newer than cached beta search snippets. It does not document Blenny's private
  MenuBar preferences API or prove those changes in every earlier beta build.
- **A2 — [What's new in privacy, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10053/)**,
  App Sandbox chapter at 17:46: historical container prompts, picker alternative
  and FDA scope; prompt lifetime is superseded by A1 for the macOS 27 design.
- **A3 — [Protecting local app data using containers](https://developer.apple.com/documentation/xcode/protecting-local-app-data-using-containers)**:
  app data/group protection and team/group boundaries. Its generic prompt wording
  must be read with A1.
- **A4 — [NSAppDataUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsappdatausagedescription)**:
  a purpose message, default text if absent; not a permission request API.
- **A5 — [AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)**:
  current-process trust and asynchronous prompt semantics.
- **A6 — [Allow accessibility apps to access your Mac](https://support.apple.com/en-gb/guide/mac-help/mh43185/mac)**:
  user-controlled settings enable/deny and Add if missing. General naming lags the
  inspected system resource; exact macOS 27 UI behavior still needs acceptance.
- **A7 — [Privacy & Security settings](https://support.apple.com/guide/mac-help/change-privacy-security-settings-on-mac-mchl211c911f/mac)** and
  [file/folder controls](https://support.apple.com/guide/mac-help/control-access-to-files-and-folders-on-mac-mchld5a35146/mac):
  FDA and location permissions. These do not establish a grant for a private API.
- **A8 — [Configuring App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)**:
  signed sandbox capability and separate resource entitlements.
- **A9 — [Creating bookmark data](https://developer.apple.com/documentation/foundation/nsurl/bookmarkdata(options:includingresourcevaluesforkeys:relativeto:))** and
  [enabling scoped bookmarks](https://developer.apple.com/documentation/professional-video-applications/enabling-security-scoped-bookmark-and-url-access):
  persistent selected-resource candidate and signing identity constraints. The
  documented sandbox mechanism is not proof for this unsandboxed app's private
  cross-container preference service. Scope lifetime, stale resolution, identity
  changes and recovery must be validated before adoption.

Local OS label evidence: `SecurityPrivacyExtension.appex`, resource
`Localizable.loctable`, keys `ACCESSIBILITY`, `ACCESSIBILITY_SUMMARY`,
`FILE_ACCESS_COMBINED` and `ALL_FILES_QUIT_*`. Only sanitized interpretation is
included here; raw resource excerpts and runtime identity remain in LocalData.

## 11. Focused follow-up: first install, reauthorization and updates

Owner follow-up on 2026-09-15 prioritizes device-control setup. Other data access
work remains deferred. This section is the concrete implementation proposal;
it does not authorize changing a grant, replacing the app or signing it.

### Public API and the expected first-use path

The macOS 27 SDK's `AXUIElement.h:55–74` exposes
`AXIsProcessTrustedWithOptions`, `kAXTrustedCheckOptionPrompt` and
`AXIsProcessTrusted`. Use the exported option constant. There is a public
request for system guidance, not a public setter that turns permission on for
the app. The user-controlled system-alert/settings flow is the normal route.

Opening an app is not itself a documented guarantee that its entry appears.
In current Blenny, startup checks trust without the prompt option; the explicit
setup action requests the prompt. The expected happy path after that request
is to enable Blenny's entry and return, with no manual file search. The public
API does not guarantee list-insertion timing, focus/selection of that row, or
repair of a stale row. First-install entry appearance on the admitted macOS 27
build remains an explicit manual test, not an observation from this investigation.

| Normal implementation | User effort | Proposed use |
| --- | --- | --- |
| Public AX prompt → system-provided settings action → enable app → return | One extra system prompt step; provides native guidance | Recommended primary route |
| Open the settings page directly → enable app → return | Fewer steps when the correct row already exists; a URL does not register or repair a row | Repeated-action fallback; check URL-open result |
| Manual Add / select installed app | More steps, but works as documented fallback when absent | Troubleshooting only, never required standard onboarding |

Do not simultaneously request a system alert and immediately force-open settings
to save a click: the asynchronous windows can compete, and that interaction has
not been tested. Do not expose three competing choices in the ordinary interface.

### Why removing and re-adding can appear necessary during development

Read-only comparison of the current installed app and the prior archived Unified
Undo candidate finds different CDHash-only designated requirements. Both retain
the Blenny bundle ID, but they do not have a version-independent signing identity.
This supports an identity-mismatch explanation for a visible stale row, not proof
of what a particular existing TCC record contains. No record was inspected/reset.

Apple's [TN3127: Inside Code Signing: Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)
explains that authorization continuity uses code identity and that ad-hoc signing
ties that identity to one code version. Its worked example concerns microphone
permission, so this is platform evidence plus a strong Blenny-specific inference,
not a measured AX repair result. The note also distinguishes Apple Development
from Developer ID requirements. Consistent signing identity and a compatible
designated requirement, not merely a constant bundle ID or filename, are the
prerequisites for update continuity. Certificate renewal need not invalidate a
compatible requirement; changing signing class/team requires separate validation.

Sparkle's [official setup documentation](https://sparkle-project.org/documentation/)
distinguishes Developer ID application signing from EdDSA update-archive signing.
EdDSA authenticates an update package; it does not preserve or grant AX consent.
A normally signed, identity-compatible in-place update should not routinely
require Remove/Add. That is the acceptance target, not an untested macOS 27
guarantee. Ad-hoc-to-Developer-ID migration and actual Sparkle-installed updates
need separate tests; Sparkle is not integrated by this task.

### Minimal implementation proposal

1. Quiet trust check at launch; show one **Set Up Access…** action if untrusted.
2. First deliberate request in the current process invokes the public prompt
   API once. Replace the permanent prompt-history suppression with process-local
   attempt state; do not auto-prompt on every launch or repeat from activation.
   The old preference may remain unused; no reset of system permission is needed.
3. Subsequent setup clicks open the verified settings destination. Detect an
   unsuccessful URL open and provide manual Privacy & Security navigation.
4. Reuse bounded trust-return observation with retained draft/busy intent. Keep
   permission checks separate from startup recovery and never auto-Apply/Resume.
5. If trust is still false, show **Access is still off** and optional help.
   A false result does not establish that a visible switch is on or stale.
   For missing-row help, a public `NSWorkspace.activateFileViewerSelecting` action
   can reveal `Bundle.main.bundleURL`, avoiding a manual search for the correct
   installation. It is only a troubleshooting proposal, not invoked here.
6. Remove/Add is a last-resort manual repair after exact app identity and the
   user's reported settings state are checked; never an automatic reset or the
   normal update flow. Explain effects on active management before revocation.

Focused acceptance: fresh identity with no row; request then enable; deny then
regrant; user-removed row followed by a fresh launch/request; repeated clicks;
draft/busy return; stale ad-hoc row; same-identity update; signing-class migration.
The no-state Device Control round and focused UI implementation are complete.
Deny/regrant, update and signing-class migration remain pending.
