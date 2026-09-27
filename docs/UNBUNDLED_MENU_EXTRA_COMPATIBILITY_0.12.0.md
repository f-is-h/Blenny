# Unbundled menu extras: macOS 27 compatibility investigation

Date: 2026-09-26; owner disposition updated 2026-09-27.
Status: **accepted known issue; no compatibility fix shipped**.

## Final owner disposition and handoff

Keep Build 59's current management backend and record the inability to guarantee
preservation of unmanaged extras after Resume as a known issue. Do not rewrite
the backend, restore the earlier Resume-blocking guard, or add automatic
Stop/Resume. Visible / Revealable / Hidden semantics remain unchanged.

The native application-admission mechanism can be considered only as a future
supplementary hiding capability after exact mapping and target-specific proof.
The owner reports D4Mac's native switch controls Wine/Battle.net, whereas
Usage4Claude and ChatGPT do not hide via their switches. Gaming and Now Playing
have no corresponding application-list entries; Now Playing has a separate
existing Blenny backend. The disposable BT native-switch hide/show pass is also
owner-confirmed. These results do not establish complete coverage.

Both mechanisms can coexist, but an allowed native setting cannot override
assessment rejection. Therefore coexistence does not fulfill the requirement
to preserve Gaming/Wine after Resume. A complete alternative needs adequate
coverage without assessment or a verified assessment exception; neither exists
in this investigation.

Research code is not production-ready. The custom preference write did not
hide BT, used an incorrect constructed item-location mapping, encountered
API/file disagreement, and did not prove durable restoration. The actual native
record uses an executable `adhocBinary` location for this helper. Point-in-time
restoration was independently verified, but the old temporary row later
reappeared. As of handoff, the native helper process has exited and its research
row remains present with `isAllowed = true`. Exact-file access was owner-granted;
no revocation is claimed. Preserve ignored snapshots/bookmarks/receipts until
deliberate cleanup is verified; do not restore an old whole blob over unrelated
concurrent changes. No full Stop/Quit/relaunch/reboot acceptance was performed.

Changes are research sources and documentation only; no product backend was
integrated, installed Blenny build replaced, commit made, or push performed by
this investigation. See [Known limitations](KNOWN_LIMITATIONS.md#unmanaged-extras-may-disappear-after-resume).

### Owner-requested cleanup (2026-09-27)

No research process was running at cleanup. Disposable app bundles, compiled
probe executables, copied Apple binary slices, the full MenuBarAgent disassembly,
the duplicate framework disassembly, and saved exact-file bookmark files were
removed. Focused evidence, source, baseline snapshots and recovery receipts
remain ignored for audit and recovery, with a private cleanup manifest.
No product file, installed Blenny bundle, unrelated worktree change, or system
preference was removed or rewritten. Removal of local bookmarks does not prove
revocation of OS-maintained authorization.

The research application row was still present with `isAllowed = true` at the
cleanup preflight. It was deliberately not deleted through the unverified
preference writer: previous point-in-time removal did not prove durable removal.
No system service restart or broader preference reset was attempted. This is
an explicitly retained residue, not a claim of complete system-state cleanup.

### Subsequent exact-row cleanup (2026-09-27)

The owner explicitly requested removal of the remaining
`xyz.fi5h.blenny.admission-trial` Settings entry. System Settings was quit before
one targeted preference write. A fresh snapshot and API/file agreement were
required; only that exact location/value pair was removed from the current
array. All other current rows and preference keys were preserved. Independent
fresh-process reads verified the intended bytes, absence of the target and
unchanged unrelated preferences. System Settings was then reopened and its
Menu Bar application list no longer contained the research entry. Another
fresh API/file check after reopening confirmed the same state.

This supersedes the retained-row status above: the entry is now removed and
verified absent across this Settings relaunch. No system service restart or
preference reset was needed. Reboot persistence and OS authorization revocation
were not tested. The private cleanup snapshot and verification record remain;
the one-off compiled cleanup executable was removed.

The requested result is to leave the original GamePolicyAgent and Wine
Battle.net extras unmanaged and unmoved, yet physically visible while Blenny
manages other applications. It must preserve Visible / Revealable / Hidden
semantics and exact Stop, Quit, and restart recovery. Build 59 does not provide
that result. Its Resume acceptance remains historical evidence, not acceptance
of this subsequent compatibility requirement.

The initial read-only investigation changed no product behavior, installed build, system
preference, management state, permission, or recovery receipt. It did not repeat
the failed allow-list trials or conduct a new visibility mutation. Raw evidence
and executable tools remain ignored under
`LocalData/0.12.0-unbundled-compatibility/`.

A later owner-authorized disposable-helper write trial is recorded below. Its
temporary admission entry was removed and the original preference bytes were
independently verified restored. It did not establish a visibility fix.

## Evidence and host-specific results

Environment: macOS 27.0 `26A428`, installed Blenny Debug Build 59, Xcode 27.0
`27A266a`, macOS 27.0 SDK. Historical trials are recorded in
[the 0.12.0 spike](TECH_SPIKE_0.12.0.md).

| Evidence | Gaming / GamePolicyAgent | Wine / Battle.net |
| --- | --- | --- |
| Build 54: code-signing IDs in the assertion allow-list | Original rocket disappeared during management | Physical icon not conclusively mapped |
| Build 58: containing application Bundle IDs in the allow-list | Original rocket still disappeared | Physical outcome not conclusively mapped |
| Build 59: normal management and Quit | Original rocket absent during management; returned after Quit | User reports disappearance; prior captures do not independently verify disappearance or restoration |
| Fresh read-only host probe | `/usr/libexec/GamePolicyAgent`, strict valid code identifier `com.apple.GamePolicyAgent`, no application Bundle ID, one AX menu extra | Strict valid code identifier `com.codeweavers.CrossOver.wineloader`, no application Bundle ID, one extra with AX help `战网` |
| Fresh AX setter capability read | No supported `AXHidden` / `AXVisible`; position and size not settable | Same result for the identified Battle.net extra |

Both selected hosts have prohibited activation policy. The probe matches the
host by executable family and validates its code identity before AX reads.
Neither a signature ID, the containing D4Mac application, nor GameOverlayUI is
the missing application Bundle ID of the observed host. PIDs are transient
observations, not policy or restoration identities. No PID is published here.

The fresh probe verifies identity and AX observability only. It does not sample
the physical menu bar, prove physical visibility, or establish a new lifecycle
pass. The current Wine identity is more specific than an unidentified Board
card, but its physical behavior remains separately unverified.

## The assessment failure occurs in MenuBarAgent filtering

Read-only disassembly and Swift metadata from the installed Apple binary show
the following flow. This is a reconstruction of the branch logic, not copied
implementation code:

```text
assertion configuration: allowedSystemItems + allowedBundleIdentifiers
    -> resolved assessment restriction
    -> FilterStep receives statusItems and controlCenterItems separately
    -> for each statusItem while assessment is active:
         missing ComponentStatusItemClientElement.bundleIdentifier: discard
         otherwise: retain only if bundle identifier is in the bundle set
    -> layout receives the filtered output
```

`ComponentStatusItemClientElement.bundleIdentifier` is optional. The status
item filter checks its nil discriminator before invoking bundle-set membership.
The numeric system-item allow-list is consumed in a separate branch over
`controlCenterItems`; it is not an alternate namespace for arbitrary status
item PIDs or signing IDs. Adding another string cannot satisfy the missing-ID
branch, and an `isAllowed` registration flag cannot override this subsequent
assessment check.

Both architecture slices in the installed MenuBarAgent binary contain this
branch. Addresses below are unslid and specific to this OS binary; they are
research locators, never callable product constants.

| Anchor | arm64e | arm64e.x1 |
| --- | --- | --- |
| Mach-O UUID | `9E3A0BA9-0E78-3C4E-B0E7-8B2BC1BD09C8` | `FE196456-9F8B-3503-B388-C5D9E622AEF3` |
| `FilterStep.Input` field metadata | `0x1003c7424` | `0x1003adce4` |
| `ResolveRestrictionsStep.Output` field metadata | `0x1003c7538` | `0x1003addf8` |
| Filter function | `0x10000e274` | `0x10000d9d8` |
| Assessment-active check | `0x10000e36c` | `0x10000dad0` |
| Optional bundle nil test / skip | `0x10000e558` through `0x10000e570` | `0x10000dcb4` through `0x10000dccc` |
| Non-nil bundle-set lookup call | `0x10000e580` | `0x10000dcdc` |
| `ComponentStatusItemClientElement` field metadata | `0x1003d4b88` | `0x1003bb448` |

The field metadata names `bundleIdentifier` as the seventh stored field; its
symbolic type reference has the optional `Sg` suffix. The comparison uses the
optional nil discriminator `0xc`, distinct from the compact non-nil
`BundleIdentifier.Symbol` cases. In arm64e the alternate filter predicate at
`0x10000eb1c` also rejects nil before bundle lookup. The membership implementation
at `0x1000ecc74` uses the typed bundle set and string equality, not a wildcard,
PID, executable path, or code-signature query.

A separate arm64e host accessor at `0x100287f98` reads the `sourceHost` ivar and
calls its `bundleIdentifier` selector at `0x100287fb0`, preserving nil. This
supports the distinction between host Bundle ID and enclosing application/code
identity. The entire live host-to-scene construction was not instrumented, and
no debugger was attached to MenuBarAgent. Thus the filter rule is directly
evidenced statically; its explanation of the Gaming failure combines that rule,
the fresh nil host identity, and the prior physical A/B outcomes. Wine has the
same risk conditions, but that is not a new physical A/B result for Wine.

Fresh read-only Objective-C contract inspection also confirms that
`MBAssessmentModeConfiguration` exposes `allowedSystemItems` and
`allowedBundleIdentifiers`, while
`MBVisibilityRestrictionXPCServer` acquires an assertion using those same two
collections. No per-PID, per-status-item, signing-ID, or path exemption was
found in this inspected contract. This is a boundary of the current assessment
route, not a proof that every possible future macOS backend is impossible.

## Alternative routes and their limits

| Route | Evidence and disposition |
| --- | --- |
| More assessment allow-list strings | Rejected for nil-bundle status items by the branch above. Builds 54 and 58 already failed physically for Gaming. Do not repeat. |
| AX visibility or geometry setter | The fresh target reads do not expose such a setter. AX observability is not presentation control. No AX write attempted. |
| Public `NSStatusItem.isVisible` | Controls the caller's own AppKit status item, not another process's existing item. Creating a replacement would not preserve the requested original. |
| `MBMenuBarItemManager` registration / global visibility | Current ABI remains a client item-management connection. Earlier connection/audit-token investigation establishes caller ownership; no current foreign-owner control route has been verified. |
| MenuBarAgent utility XPC | The inspected diagnostic/listing/preferred-position service has private entitlement `com.apple.private.menubar.utilities`. It is not an allowed escape hatch; no privileged call or entitlement request was made. |
| Native overflow or auxiliary bar | An independent Ice proposal depends on synthetic Command-drag and capture for its auxiliary bar. Overflow alone does not provide equivalent Hidden / Revealable behavior, nor guarantee these extras remain visible. No implementation copied. |
| Temporarily release assessment / replacement icon | Releasing assessment suspends the current visibility filter and can expose Hidden items; a replacement/launcher is not the original extra. Neither meets the requested active-management result. |
| `TrackedApplicationsPreferences.isAllowed` | A distinct persistent registration/admission mechanism with live preference observation exists. It is a candidate for replacing assessment, not an exception within assessment. Safe access, exact restore, current-item hide/reappearance, and full policy coverage are not proven. |

### Separate admission-preference candidate

MenuBarAgent's `StatusItemApplicationRegistry` holds
`TrackedApplicationsPreferences` and subscribes to its preference changes.
Its location model distinguishes `bundle(BundleIdentifier)` and
`adhocBinary(URL)`, and an application row includes `isAllowed`. In the arm64e
slice, initialization at `0x100290b1c` calls observer setup at `0x100290c30`;
the initial preference read is at `0x100290ef8`, and the update path at
`0x1002929c8` reads preferences again. The row conversion calls the tracked
application `isAllowed` getter at `0x100294268` and stores that flag in the
registry application at `0x1002942a4`.

The current shared-cache MenuBarClientCore implementation initializes the
secured preferences controller with group `group.com.apple.controlcenter`.
The `NSUserDefaults.trackedApplications` accessor reads key
`trackedApplications`. The preference wrapper stores an encoded data blob;
this is shared persisted state, not a temporary assertion token. Exact group
and key strings were corroborated from the mapped framework, not inferred
from neighboring disassembler string labels.

Direct read of that group's preferences file was denied with `EPERM` in this
shell context. A separate read-only `CFPreferencesCopyAppValue` for the exact
group and key returned nil. Nil does not distinguish an absent value from an
unavailable/protected domain, so it is not a usable baseline snapshot. The
existing ordering grant for `com.apple.MenuBar` is a different scope and does
not establish access to this group. Conversely, shell denial alone does not
prove that an already-authorized signed app context would also be denied.
No new grant was requested and no preference was written.

On the owner's subsequent request to try writing the candidate, an additional
read-only preflight used the exact container initializer
`NSUserDefaults._initWithSuiteName:container:` after checking its runtime method
encoding. It explicitly selected the same group container and read only
`trackedApplications`; the API again returned nil. The independent file read
failed with Cocoa error 257 (read permission denied). The probe compiled with
Xcode 27 and warnings as errors. It did not call a setter or `synchronize`.
This rules out an omitted explicit container as a sufficient fix in the tested
research context; it does not establish access from an untested signed app
context. The requested live write remained blocked before mutation because an
authoritative snapshot and exact inverse were unavailable. The owner's earlier
no-permission-expansion and restore-before-write constraints were retained.

The owner subsequently authorized narrowly scoped exact-file access and a
write trial. An attended file selection succeeded: two file reads were stable,
the exact-container API value agreed, and a private baseline plus scoped
bookmark were saved. Inspection of that baseline **corrects the earlier JSON
interpretation**: the value starts with `bplist00` and decodes as an alternating
location/value array. Rows contain `location`, `menuItemLocations`, and Boolean
`isAllowed`. This is observed serialization evidence, not a guessed schema.
A separate Debug-only disposable helper and a recovery-first single-attempt
writer were prepared. Six deterministic checks cover exact inverse, already
restored state, preservation of unrelated edits, a denied baseline, a conflicting
target, and duplicate ownership. The helper requires independent file/API
agreement, a durable receipt, and explicit attended activation; it targets only
`xyz.fi5h.blenny.admission-trial`. A physical live pass is not yet recorded.

The first attended Run action reported no physical disappearance or later
reaction. Its process log establishes that preflight rejected the missing
helper preference row before creating a receipt or performing a write. The
12-second restoration timer therefore never started. The probe was extended
to snapshot absence, insert only its exact own bundle row, and remove that row
on restoration; nine deterministic tests pass, including absence restoration
and unrelated-edit preservation.

### Bounded write and recovery result

The revised attended attempt wrote the exact proposed blob containing only the
new disposable helper's denied row. The 1.5-second verification encountered a
file/API disagreement; it stopped the apply path before scheduling the
12-second timer. The initial in-process restoration preflight also rejected
that disagreement. The UI therefore correctly retained the recovery receipt
and displayed `RESTORATION REQUIRED`. Its original diagnostic suffix "no write"
was misleading when reused after a write; that suffix has been removed.

An independent file read confirmed the blob exactly equaled the recorded
proposal. A separate recovery-only process then performed one inverse write.
Its in-process readback also reported file/API disagreement, but independent
file reads found the exact original blob. A fresh standalone exact-container
API read agreed with the original bytes as well. The current snapshot matched
every pre-trial preference key; the inserted helper row was absent. Both test
processes were stopped only after that independent verification, and another
fresh API/file check after their exit again matched the original blob. The
receipt preserves the earlier failure and records external restoration
verification. Seven previously tracked Blenny policy/recovery evidence files
also remained unchanged.

This proves one persisted proposal and its exact persisted inverse on the
authorized host. It does **not** prove a usable runtime visibility backend:
the owner subsequently reported observing no disappearance of BT, including
no noticed brief disappearance, during the revised attempt. Thus the attended
trial did not demonstrate live hiding despite confirmed persisted denial.
This does not distinguish an unapplied preference notification from a
registration-only check or another unverified runtime condition. In addition,
same-process verification was unreliable in this trial, and the source of the
API/file disagreement has not been independently traced. No Gaming or Wine row
was written, no further trial was started, and the full lifecycle matrix was
not run. The isolated executable remains research only, not a product fix.

The owner subsequently confirmed that BT never briefly disappeared in that
attempt. The direct-preference-write route therefore failed its attended
physical visibility test, despite its persisted proposal and verified inverse.
The next contrast uses macOS's own Menu Bar settings and a separate host with
no preference writer, launched through LaunchServices with a verified
`NSRunningApplication.bundleIdentifier`. This distinguishes native system
behavior from the custom preference path. Native-switch results remain pending;
no success is inferred from the switch's existence alone.

### Native Settings contrast: attended physical pass

The owner found the entry under the cached system display name `AdmissionTrial`
in System Settings > Menu Bar > Allow in the Menu Bar. They confirmed that
switching it off removed the original BT item and switching it on displayed
the item again. This is an attended physical hide/show pass for the disposable
host through Apple's native control path. It is not yet a programmatic backend
pass or a Gaming/Wine result.

The resulting system-generated row differs materially from the earlier
constructed row: its application `location` is the helper Bundle ID, but
`menuItemLocations` contains an `adhocBinary` executable URL. The failed probe
invented a bundle location for that member. Consequently the probe did not
faithfully reproduce the native record. Do not conclude that raw preference
notifications alone caused its failure, or reuse the invented member in a
future writer. Capture the system-generated owner/item relationship and preserve
it, then change only the verified admission Boolean if that route is retried.
Raw local paths remain in ignored evidence only.

The saved pre-launch snapshot for this native contrast also shows that the old
constructed denied helper row had reappeared after the earlier point-in-time
restoration checks. Therefore those checks did not prove durable restoration
of the system's effective state. The native switch was returned to on by the
owner. At that point full removal of the research row was pending; the later
exact-row cleanup above verified absence across a System Settings relaunch.
Reboot persistence remains untested.
An unrelated application row changed during the native contrast as well; any
cleanup must preserve it rather than restoring the whole older preference blob.
Resolve the writer's adoption and durable inverse before claiming product-ready
recovery or starting another custom write.

The live observer makes this more substantial than a guessed allow-list ID,
but it does not yet prove that changing admission updates existing scenes,
restores them without restarting their owners, or covers every currently
managed application. To avoid assessment filtering the two unbundled extras,
an alternative must manage the other required targets without leaving an
assessment restriction active. Simply combining `isAllowed = true` with the
current assessment assertion cannot bypass the nil test.

## Snapshot and recovery gates for any future Debug trial

At the end of the initial read-only stage there was no mutation-ready candidate. The next smallest
useful step is a read-only check of the exact admission preference from an
existing authorized signed context, plus tracing whether changed admission
rebuilds an already-present item. If that cannot be done under existing
permissions, stop this candidate; do not broaden access to force an experiment.

Before a writer or attended third-party trial can run:

1. Establish an authoritative baseline: exact domain/container/user/host scope,
   key presence versus absence, raw encoded value and schema, exact owner row,
   independent readback agreement, and current original-item presentation.
   A nil read or partial dictionary is a hard stop.
2. Prove the setter and inverse on a Blenny-owned disposable helper first.
   Use one serial writer and a durable receipt written before mutation. Preserve
   the existing accepted policy, previous-policy backup, and ordering Undo.
3. Record before and expected-after values. Before rollback, verify that the
   target still matches the receipt; preserve unrelated rows and external edits.
   A whole-blob setter needs a conflict strategy that is safe against concurrent
   system writers, not merely an in-process lock or blind full-file restore.
   Unknown schema or a target conflict must halt and retain the receipt.
4. Define Stop/Quit restoration, failed-write compensation, and recovery after
   process exit/relaunch and reboot. A persistent admission change does not gain
   assertion-style automatic cleanup merely because Blenny exits. No promise of
   recovery while Blenny is absent is valid without demonstrated machinery.
5. Keep a missing Bundle ID from becoming a guessed policy key. For the minimum
   alternative, never write or move Gaming or Wine at all; manage only other
   validated application owners. Direct control of Wine would additionally have
   to distinguish its shared host/bottle identities within the bundle-level
   product boundary. Direct Gaming mutation needs its own approved safe scope.
6. Prove the three states with deterministic failure/serialization/restoration
   tests before a live trial. During ordinary reveal, only Revealable owners
   change; Hidden owners remain hidden. Baseline-disallowed owners must not be
   silently enabled as part of a visibility policy.

Once those gates pass, perform one bounded attended matrix: baseline; management
on collapsed; expand; conceal; Stop; Resume; normal Quit; app relaunch; and an
explicitly arranged OS reboot. Record Gaming and Battle.net separately at each
step, with original icon presence and location plus exact target-state
readback. AX/Board presence alone never passes a physical step. A failed write
may be verified once and retried at most once. No polling loop, synthetic input,
system-process injection, new entitlement, TCC reset, or screenshot permission
may be introduced. Failure stops the matrix and invokes the proven inverse.

This full matrix was **not run**. The later disposable-helper persistence trial
above does not satisfy its runtime visibility and recovery gates.
No management-on, expand/conceal, Stop/Quit, relaunch, or reboot compatibility
pass is claimed by this investigation. Until a separate backend passes, manually
stopping management is only a temporary mitigation, not fulfillment of the
requested simultaneous visibility and management.

## Verification and references

The new [read-only host probe](../Research/UnbundledMenuExtraProbe/README.md)
compiles with Xcode 27, the macOS 27 SDK, ARC, and warnings as errors, and ran
without requesting accessibility permission. No product code was changed, so
the historical 634-test Build 59 pass is not presented as a new test run.
The accepted policy, previous-policy backup, four ordering recovery/history
files and retained boundary snapshot were checked against their starting
SHA-256 values; all seven remained unchanged. This proves preservation of those
files, not an unperformed system restoration or physical lifecycle test.

External primary references consulted for alternative route assessment:

- [Apple NSStatusItem documentation](https://developer.apple.com/documentation/appkit/nsstatusitem).
- [Ice macOS 27 proposal #997](https://github.com/jordanbaird/Ice/pull/997): route description only; no implementation copied.
- [Pelmet FAQ](https://github.com/fif7y/pelmet/blob/main/docs/FAQ.md): reports assessment-related system-extra limitations and replacement strategies. Its general compatibility statements do not verify either of these hosts.

These external descriptions are corroborating context. The filter conclusion
rests on this host's Apple binary and the explicitly separated local evidence.
