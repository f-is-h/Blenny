# 0.12.0 signing and permission continuity investigation

Status: **durable self-signed Build 24→25 and Build 25→27 kept Device Control
without regrant; same-build restart and overwrite also kept it. Ordering values
changed during 24→25 but remained identical during 25→27. On Build 27 the
owner confirmed native dragging and Apply worked; the full typed preference
write was verified, while physical-position verification remained unavailable.
The bookmark is stale, and Undo, Sparkle installation and macOS reboot remain
unverified**, updated 2026-09-26.
The earlier disposable Build 16→17 experiment remains recorded below.
This is a focused investigation record, not 0.12.0
acceptance or a change to the 0.11.0 product. The owner will use a no-paid-Apple-
certificate route. Two local Debug packages were signed with one isolated
self-signed identity. In a first read-only round, Build 16 was temporarily
installed and then the byte-identical original Build 15 was restored. In a
second attended round, Build 16 was installed again. System Settings showed an
enabled Blenny row while that process still reported Device Control denied.
Adding the installed app reached a macOS administrator-password prompt; the
prompt was cancelled and the later file chooser did not register the app. The
original Build 15 was restored and again reported Device Control granted. In a
third attended round, the owner removed the old Blenny Device Control entry and
added the installed signed A. A then reported granted, retained that grant
through an app restart, and signed B retained it through manual same-path
upgrade, app restart, and same-build overwrite. No selected-file grant, ordering
write, policy edit, or Apply occurred. After restoring Build 15, its previous
Device Control grant no longer applied because that old entry had been removed.
The owner regranted the original installed app. Its normal Board and a separate
LaunchServices-started, read-only instance then succeeded; the saved bookmark
still reported stale. In a fourth attended round, B was reinstalled at the same
path after the original app was backed up. The owner's Device Control regrant
made B report granted again. Separate normal-launch diagnostics before and after
that regrant both read the same complete 33-key table through file/API/file,
despite the stale bookmark. Raw evidence and user-specific state belong only in
`LocalData/`.

## Existing constraints and evidence

The 0.12.0 roadmap requires a stable `xyz.fi5h.blenny` identity, Device Control
and exact-file grant continuity, and update/restart validation. Its Developer ID
and notarization publication gates remain separate and cannot be claimed from
this no-paid local experiment. Ordering remains Debug/optimized-trial only;
ordinary Release cannot serve as an ordering continuity test. The 0.11.0
[release record](RELEASE_0.11.0.md)
documents owner-accepted Build 15 dragging and Apply, a clean applied Undo receipt,
and a stale bookmark warning. The earlier
[permissions investigation](PERMISSIONS_0.11.0_PHASE1_DRAFT.md) reports that an
ad-hoc CDHash change required Device Control remove/add/enable, while the saved
exact-file bookmark had survived that earlier replacement. These are historical
ad-hoc observations, not a stable-signature upgrade result. A local 0.12.0
Files & Folders probe found that a visible app row did not produce MenuBar
group-container access; its ignored `INVESTIGATION.md` is retained under
`LocalData/0.12.0-permission-entry-recheck/`.

Apple describes a designated requirement as the code identity used to track
privacy-protected access. Its [distribution signing guidance](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/)
also warns that different distribution identities need not share grants. Its
[code-signing guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html)
allows a self-signed identity to validate continuity between versions but does
not treat it as Apple-verified publisher identity. Pure ad-hoc signatures do not
provide a reusable signer requirement across changed builds. Its
[security-scoped bookmark guidance](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
says a resolved stale bookmark should be recreated and stored, then the resolved
URL's scope started before use. Neither source guarantees Blenny's Device Control
or MenuBar App Data outcome on this host.

## Read-only baseline on this host

| Item | Observation | Boundary |
| --- | --- | --- |
| Host and installed app | macOS 27.0 (`26A428`), Xcode/SDK 27.0; `/Applications/Blenny.app`, `0.11.0 (Build 15)`, bundle ID `xyz.fi5h.blenny`; executable SHA-256 `ef31b9cebc70b0000daa78d12fbb7b1be1f251c5890e2cbfd1d386cc4a1edfa2` | Matches the 0.11.0 release-record executable, not a new build. |
| Signature | Strict verification passes; ad-hoc, no TeamIdentifier; CDHash `c947e4016a8c001e8d0a3568b5a63c47730843aa`; designated requirement `cdhash H"c947e4016a8c001e8d0a3568b5a63c47730843aa"` | A different ad-hoc build cannot demonstrate stable designated-requirement continuity. |
| Earlier Build 15 UI | Reported **Device Control granted**, management paused, **Changes applied**, with an available **Undo Changes** action and no visible pending draft | The Build 15 process subsequently exited; its saved policy still records `managementEnabled=true`, which is not proof of a live assertion. No drag or Apply was performed in this investigation. |
| Saved bookmark | Existing private `layout-access.bookmark` is present, 956 bytes, mode `0600`; a fresh instance of the same installed executable reports `bookmarkStale` | Existence and storage mode do not prove usable scope. Its raw bytes were not inspected or copied to Git. |
| Fresh same-binary data read, direct executable launch | The read-only `--ordering-preference-read-only` instance reports direct-file `EPERM` before and after the container read; the container API read also fails | The failure occurs with the same executable, Bundle ID and installed path. Signature change is not a necessary cause. A later LaunchServices-started instance of this same executable succeeded, so direct launch is not representative of normal-app file access on this host. |
| Fresh same-binary data read, LaunchServices launch after original regrant | `open -n -g -W -a /Applications/Blenny.app -o <ignored-output> --args --ordering-preference-read-only` reported stale bookmark but successfully read file/API/file; all three complete typed tables agreed on 33 entries | Same binary, Bundle ID and path as the direct-launch failure. The changed launch context correlates with the access difference; the exact macOS policy decision was not directly inspected. The real Board also displayed **Menu bar order** after normal app relaunch. |
| Original signing inventory | `security find-identity -v -p codesigning` found zero valid identities | No paid Developer ID identity is available. The isolated self-signed identity is reported as untrusted by this command but can sign local code. |
| Local Build 16 and 17 | Same source revision and Debug flavor, same Bundle ID and exact-file entitlement; signed with one local self-signed certificate | Their CDHashes differ, but both have the same certificate-bound designated requirement and satisfy it under strict `codesign` verification. This proves code-identity continuity only. |
| Build 16 first installation at `/Applications/Blenny.app` | Strict signature verification passes; a normal launch showed **Device Control not granted** | The old ad-hoc grant did not carry into the first self-signed identity. The owner later regranted the installed signed A in a separate round. |
| Device Control settings row versus process | The System Settings Blenny toggle remained **on** while signed Build 16 reported **not granted** | A visible/on row is not evidence that the new process satisfies its stored code requirement. Selecting Add for the new installed identity reached a macOS administrator-password prompt. The prompt was cancelled and the subsequent file chooser closed without registering Build 16. |
| Build 16 fresh data diagnostic | Saved bookmark is stale; direct-file reads return `EPERM`; container read fails | The same bookmark was stale on Build 15 before the signature transition, so this is not evidence that signing caused the bookmark failure. |
| Post-test restoration | Original Build 15 app restored after each round; executable SHA-256 again `ef31b9cebc70b0000daa78d12fbb7b1be1f251c5890e2cbfd1d386cc4a1edfa2`, original ad-hoc requirement and strict verification pass. On normal launch after round two, its Settings reported **Device Control granted** and the Organization Board populated. | All eight private Blenny app-state files match the second pre-test backup byte for byte. The first round's MenuBar plist size, inode and modification time matched, but its full contents could not be read without the denied exact-file access; do not label a full-table restoration verified. |
| Third-round restoration and original regrant | Original Build 15 app and strict signature restored; executable SHA-256 matches baseline | All eight private Blenny state files matched the third pre-test backup byte for byte; no Apply occurred. Build 15 first reported **Device Control not granted** after its old entry was removed during A onboarding. The owner regranted it; Settings then reported **granted** and the Board populated after another normal app restart. |

The read-only diagnostic is designed to create no status item, policy store,
writer, recovery lease, or preference synchronization. Its full JSON contains
preference values; retain raw output only under ignored `LocalData/` and record
only source agreement, counts/digests, and errors in a reviewable report.
Compare a direct executable invocation with a LaunchServices invocation of the
**same installed package**. The latter is the relevant normal-app context on
this host. Keep each raw JSON and stderr file ignored, then parse only the
`errors`, source names, typed-table count and equality into the tracked report:

```sh
rtk proxy mkdir -p LocalData/0.12.0-signing-continuity/launchservices-read
rtk proxy open -n -g -W -a /Applications/Blenny.app \
  -o "$PWD/LocalData/0.12.0-signing-continuity/launchservices-read/current.json" \
  --stderr "$PWD/LocalData/0.12.0-signing-continuity/launchservices-read/current.err" \
  --args --ordering-preference-read-only
```

Use `-n` so the diagnostic is a separate fresh instance even when the main app
is running. Do not count a direct-launch `EPERM` as a normal-app failure when
the LaunchServices control succeeds. A stale bookmark is still a separate
failure of the stored bookmark even when another permission path allows reads.

## Two-consecutive-build protocol

Use one local self-signed code-signing identity for this no-paid test; never
label it Developer ID, notarized, or Gatekeeper-ready. Freeze one source revision
and one build flavor with ordering enabled. Build A and B consecutively with
different `CFBundleVersion` values and the **same** certificate, Bundle ID,
entitlements, and installation path. `scripts/build-app.sh` provides separate
build roots and build-number overrides; it first applies the usual ad-hoc
signature. Re-sign each finished package with the same local identity and its
original exact-file entitlement. Keep packages, logs, and temporary keychain
only under ignored `LocalData/`. Record each executable SHA-256, app CDHash,
TeamIdentifier, designated requirement, entitlements, Bundle ID, version and
strict signature result. Require different CDHashes and the same certificate-
bound requirement before testing a grant. A name match alone is insufficient.

Example packaging and identity capture (the identity and keychain are local;
do not store private signing material or full preference diagnostics in Git):

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
rtk proxy env BLENNY_BUILD_ROOT="$PWD/LocalData/0.12.0-signing-continuity/A" BLENNY_BUILD_NUMBER="$BUILD_A" ./scripts/build-app.sh debug
rtk proxy env BLENNY_BUILD_ROOT="$PWD/LocalData/0.12.0-signing-continuity/B" BLENNY_BUILD_NUMBER="$BUILD_B" ./scripts/build-app.sh debug
rtk proxy codesign --force --sign "$LOCAL_IDENTITY_SHA1" --keychain "$LOCAL_KEYCHAIN" --identifier xyz.fi5h.blenny --entitlements Config/OrderingTrial.entitlements LocalData/0.12.0-signing-continuity/A/Blenny.app
rtk proxy codesign --force --sign "$LOCAL_IDENTITY_SHA1" --keychain "$LOCAL_KEYCHAIN" --identifier xyz.fi5h.blenny --entitlements Config/OrderingTrial.entitlements LocalData/0.12.0-signing-continuity/B/Blenny.app
rtk proxy codesign --verify --strict --verbose=2 LocalData/0.12.0-signing-continuity/A/Blenny.app
rtk proxy codesign -dv --verbose=4 LocalData/0.12.0-signing-continuity/A/Blenny.app
rtk proxy codesign -dr - LocalData/0.12.0-signing-continuity/A/Blenny.app
rtk proxy codesign --verify --strict --verbose=2 LocalData/0.12.0-signing-continuity/B/Blenny.app
rtk proxy codesign -dv --verbose=4 LocalData/0.12.0-signing-continuity/B/Blenny.app
rtk proxy codesign -dr - LocalData/0.12.0-signing-continuity/B/Blenny.app
```

The actual packages are `0.11.0 (Build 16)` and `0.11.0 (Build 17)`, built from
`bc832e7` with only documentation changes in the working tree. Their CDHashes
are `5714aa8ef389b6a949c591081d2aca3923278ae4` and
`ec762177dbf36962a8906e4fc6159bc314379bf5`. Both requirements are
`identifier "xyz.fi5h.blenny" and certificate root =
H"5f7c44c030e074a077477b1ea22fbded2642b4ad"`; explicit requirement
verification passes for each. TeamIdentifier is unset. Gatekeeper assessments
were already disabled on this host; `spctl` acceptance here proves nothing about
default-Gatekeeper launch or public distribution.
The private key, PKCS#12 export, temporary keychains and tiny signing probes were
deleted after both packages were signed. Only the public certificate and signed
packages remain in ignored `LocalData/`. Rebuilding with this exact identity is
not possible without the deleted private key; the completed A/B packages remain
valid for the bounded continuity experiment. A future real no-paid upgrade path
requires a new long-lived local signing identity with its private key retained
securely outside Git. That identity would first require its own permission
onboarding; the disposable certificate in this experiment cannot sign it.

Before the second Build 16 installation, the restored Build 15 was running with
management stopped, no visible draft, and a clean applied 18-key Undo receipt.
Its executable and private app-state files were backed up again under ignored
`LocalData/0.12.0-signing-continuity/run2-baseline/`. A normal Quit changed none
of those private file hashes. The MenuBar plist metadata was unchanged from the
first round, but direct content backup still returned `EPERM`; no Apply is
permitted until the full table can be independently verified. The old Build 15
bundle was moved intact into the private rollback directory before Build 16
was installed at `/Applications/Blenny.app`.

For the third round, the installed Build 15 was stopped with no visible draft.
The original bundle and all private Blenny state files were preserved in ignored
`LocalData/0.12.0-signing-continuity/run3-baseline/`. The owner removed the old
Device Control entry and added signed A. The agent did not enter a password.
The saved bookmark was not renewed or replaced. Read-only diagnostics in fresh
A and B processes both reported stale bookmark, direct-file `EPERM` before and
after the container API, and failed container API read. Board population after
Device Control regrant does not prove independent preference access. The agent
made one local within-area ordering draft and one Visible-to-Revealable-to-Hidden
draft for previously approved Usage4Claude; each was discarded without Apply.
The eight private state files remained byte-identical. No native drag was run.

1. **Freeze the accepted baseline.** Confirm the installed path, running process,
   active/stopped management, draft status and clean/pending recovery and Undo
   receipts. Preserve the exact original app and private app-state files under
   ignored `LocalData/`. Before any **Apply**, also capture the whole typed
   ordering table and independently verify API/file agreement. If protected-file
   access prevents this, restrict the round to no-write permission checks. An
   in-memory draft or non-restorable pending transaction blocks replacement.
2. **Explain the first identity transition.** Replacing the current ad-hoc Build
   15 with signed A changes its designated requirement. Device Control may need
   user regrant; the saved bookmark may need renewal or exact-file reselection.
   Quitting the current process ends its active security scope and any unsaved UI
   draft. Applied order and its Undo receipt must be retained for recovery, not
   silently discarded. Quit normally, then install signed A at
   `/Applications/Blenny.app`; never overwrite the running bundle. In this run,
   Build 15 was already not running, its executable and app-state files were
   backed up, and Build 16 was installed without a preference write. Record this
   transition as migration/onboarding, separate from A-to-B continuity.
3. **Establish A.** In System Settings and the app, record the exact Device
   Control row and `AXIsProcessTrusted` result. Run one fresh-process ordering
   diagnostic and record bookmark state plus file/API/file agreement. If A needs
   an equivalent grant for its new code identity or the same exact-file
   selection, record that distinct user action and the old row's status. Do not
   widen file scope, reset TCC, or use Full Disk Access to make the case pass.
   Verify the Board and run the bounded interaction packet below only after all
   preflight and inverse criteria pass.
4. **App restart.** Quit A normally and reopen the same installed binary. Record
   Device Control, bookmark, file/API/file agreement, Board state, and the
   interaction packet again. This tests process restart only.
5. **A-to-B manual upgrade.** Quit A and replace it with B at the same path,
   without changing designated requirement, Bundle ID, or entitlements. Record
   the pre/post signature, permission and operation rows. This tests an ordinary
   manual update, not Sparkle update delivery. Sparkle integration was added
   later; the A/B trial did not exercise that delivery path.
6. **System restart and overwrite.** After B is healthy, repeat the checks after
   an ordinary macOS restart. Separately, quit B and reinstall the **same** B
   package over the same path, then repeat. This distinguishes reboot persistence
   from same-build overwrite. Do not infer either from an app relaunch.
7. **Restoration.** End each bounded Apply with the product's reviewed Undo and
   independently compare the entire typed table and policy with its pre-case
   baseline. Preserve a clean accepted Undo receipt as user state. If permission
   loss prevents inverse, leave the durable recovery receipt and report
   `recovery pending`; request only the same needed user grant, then perform one
   bounded recovery. Never rewrite an accepted arrangement as a workaround.

The interaction packet for each eligible case records: one native drag with
visible local draft and normal session end; one within-area sort of an approved
owner; one Visible/Revealable/Hidden draft transition for an approved owner;
one reviewed Apply; and one reviewed Undo. Record Board lane/order, actual
menu-bar observation when available, receipt phase, complete API/file agreement,
and exact inverse. Keep critical system items and unapproved third-party bundles
out of the mutation packet. A successful table write alone does not prove
physical placement or drag usability.

## Result matrix

`Observed` means this investigation or the cited historical record actually
exercised the case. `Not run` is not a pass.

| Scenario | Signature / designated requirement | Device Control | Bookmark and ordering reads | Drag, sort, three-state, Apply | Result |
| --- | --- | --- | --- | --- | --- |
| Initial Build 15, running | Ad-hoc; CDHash-bound requirement above | UI reported granted before the owner replaced its TCC entry | Running process not independently rechecked | Historical owner acceptance in 0.11.0; not repeated here | Baseline only |
| Same installed Build 15, direct-launched read-only process | Exactly the current installed code and path | Not queried in that process | Bookmark stale; direct file `EPERM`; container read fails | Not run | **Data access fails in this launch context**; this is not a normal-app result or evidence of a signature change |
| Same installed Build 15, LaunchServices-started read-only process after owner regrant | Same installed binary, Bundle ID and path | Normal app reports granted | Bookmark still stale, but direct file/API/file reads all succeed and agree on the complete 33-key table | No drag or Apply | **Normal-launch read continuity observed despite stale bookmark**; direct-launch `EPERM` is context-dependent |
| Local packages A/B | Same self-signed certificate, Bundle ID and entitlement; distinct CDHashes; same certificate-bound designated requirement | Not tested by packaging | Not tested by packaging | Not run | **Code-identity continuity passed offline**; live rows below |
| Build 15 ad-hoc to signed Build 16 at same path | Designated requirement changed from CDHash to the local certificate | Build 16 UI said **not granted** | Bookmark stale; direct file `EPERM`; container read fails | Board unavailable; no drag or Apply | **Initial identity transition did not retain Device Control**. Bookmark failure predates transition. Build 15 was restored afterward. |
| Build 16 second same-path installation and attempted onboarding | Same Build 16 certificate-bound requirement as the first round | System Settings old Blenny row **on**, process **not granted**; Add reached password prompt, but no new app registration was completed | No exact-file reselection; previous stale/`EPERM` evidence remains the only Build 16 read | Board blocked by Device Control; no drag or Apply | **Old visible TCC row was ineffective for new signed identity**. No claim about how a completed regrant would behave. |
| Restored Build 15 after second round | Original ad-hoc CDHash-bound requirement and executable restored | Settings reports **granted**; Board populated | Direct-launched diagnostic reported stale/`EPERM`; Board displayed **Menu bar order**, which the source sets after a corroborated capture | No draft or Apply in this investigation | Original authorization still works; private state files unchanged. |
| Signed A after owner onboarding and app restart | Same certificate-bound requirement and path | **Granted** before and after normal quit/relaunch; Board displayed **Menu bar order** | Direct-launched A diagnostic: stale bookmark and `EPERM`; normal Board status implies a successful corroborated capture, but raw A table was not independently extracted | No draft in A; no Apply | **Device Control and normal-app read continuity passed for app restart**; bookmark health failed in direct diagnostic |
| Signed A to B manual same-path upgrade | Distinct CDHashes; identical certificate-bound requirement, Bundle ID and entitlement | **Granted** in B without another user action; Board displayed **Menu bar order** | Direct-launched B diagnostic: stale bookmark and `EPERM`; normal Board status implies a successful corroborated capture, but raw B table was not independently extracted | No drag or Apply; local draft checks followed | **Device Control and normal-app read continuity passed for manual upgrade**; bookmark health remains unverified for normal B launch |
| Signed B normal app restart | Same B code and path | **Granted** without user action; Board displayed **Menu bar order** | No new exact-file grant; Board status implies corroborated capture | Not run | **Device Control and normal-app read continuity passed for app restart** |
| Signed B same-build overwrite after normal quit | Byte-equivalent B copied again to the same path | **Granted** without user action; Board displayed **Menu bar order** | No new exact-file grant; Board status implies corroborated capture | Local within-area sort draft and Visible→Revealable→Hidden draft succeeded and were discarded; no native drag or Apply | **Device Control, normal-app read and local draft controls passed for overwrite**. Full workflow unverified. |
| Signed B reinstalled after original regrant, before B Device Control regrant | Same signed B and installation path; original app and eight private files backed up | B reports **not granted** and its Board is blocked | A separate LaunchServices-started B diagnostic still reports stale bookmark but successfully reads the 33-key table from file/API/file with full agreement | No drag or Apply while Board blocked | **Ordering-file reads and Device Control are separate on this host.** A stale bookmark did not prevent these normal-launch reads; B Device Control onboarding is pending. |
| Signed B after owner Device Control regrant in fourth round | Same installed B code, path, Bundle ID and certificate-bound requirement | **Granted**; Board populated and displayed **Menu bar order** | Separate LaunchServices read-only diagnostic again reported bookmark stale, but file/API/file all succeeded and agreed on the same complete 33-key table as before regrant and on restored Build 15 | Agent pointer drag did not start; owner dragged approved Usage4Claude across WeChat. B showed the moved icon, **Changes not applied**, and Apply. The agent used **Discard Changes**; original order and **No pending changes** returned. No Apply occurred. | **Device Control regrant restored Board access; ordering-file reads were already available; human native drag and discard passed.** All eight private app-state files remained byte-identical to fourth-round backup. |
| Signed B after macOS restart | B was tested but no macOS reboot occurred | Not run | Not run | Not run | Untested |
| Restored original Build 15 after owner replaced the old TCC entry | Original ad-hoc CDHash requirement restored at same path | Initially **not granted**; owner regranted, then Settings reported **granted** and Board displayed **Menu bar order** after normal app restart | LaunchServices diagnostic reports stale bookmark but complete file/API/file agreement | Not run | **Rollback required equivalent Device Control regrant** after removal of its old entry; private files unchanged |
| Original Build 15 native drag attempt before reinstalling B | Original accepted app, same source as A/B | Granted; Board visible | Board displayed **Menu bar order** | Two automated pointer drags of approved Usage4Claude produced no draft; the same test tool can produce non-drag local drafts through controls | **Inconclusive for human native drag.** The automation method did not establish a drag session; no Apply or persisted change. |

## Failure classification and smallest repair candidates

- **Device Control/TCC:** First compare the running or freshly launched app's
  trust result, System Settings row, responsible installed path, Bundle ID,
  TeamIdentifier, and designated requirement. A missing or ineffective row with
  `AXIsProcessTrusted == false` points to this layer. Do not infer it from a
  sorting error alone. The historical changed-CDHash ad-hoc regrant is not
  evidence that a stable signed update needs regrant.
- **Bookmark:** A present store that resolves stale, fails resolution, or cannot
  start scope is its own failure. Current source throws immediately on `stale`
  before trying safe renewal. The smallest candidate repair is to validate the
  resolved exact path, regenerate and atomically save a bookmark from that URL,
  activate its security scope and recheck the exact file. If that fails, ask the
  user to select the **same file** again. Test both branches with stale/denied
  fixtures and a real same-binary reopen; do not infer access from file presence.
- **Protected file or preference access:** The direct executable launch returned
  `EPERM`, while a LaunchServices-started instance of the same installed Build
  15 and B read file/API/file successfully despite the stale bookmark. B reads
  were identical before and after its Device Control regrant. That isolates
  the observed denial to launch context, not a blanket failure of normal Blenny
  access. The responsible-process or App Data policy is a plausible mechanism,
  not directly proven. Further diagnosis must compare equivalent launch contexts.
  macOS 27 may deny cross-team app/group-container reads by default; the
  [release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes)
  do not make Device Control a substitute for this access. Do not add Full Disk
  Access, reset TCC, or change ordering to mask a denial.
- **Preference settlement/cache:** The LaunchServices Build 15 diagnostic found
  complete file/API/file equality on 33 keys; no cache split was observed in
  that case. If later values disagree, preserve
  the existing bounded exact-file event wait and single fresh read. A persistent
  split is an unverified endpoint, not a signature problem or permission pass.
  Do not flush caches, poll, or issue an extra preference write to force equality.
- **Product logic/interaction:** If AX trust, scope and independent sources are
  sound but drag does not start, a draft does not move, an owner is ineligible,
  or Apply/Undo fails, investigate the specific UI, identity, preflight, writer
  and receipt path. Preserve the 0.11.0 typed drag source and equality guard;
  neither a successful signature check nor a successful read proves Apply.

**Reauthorization boundary:** After the owner granted signed A, normal app
restart, same-identity A-to-B manual upgrade, B app restart and same-B overwrite
all retained **Device Control without another user action on this host**. This
establishes normal-app corroborated ordering reads on A and B, but does not
establish bookmark health, Apply, reboot persistence, automatic update delivery,
or a general macOS guarantee. The ad-hoc-to-local-certificate
transition did not carry the old Device Control grant; owner onboarding was
needed. Removing the old ad-hoc entry meant the restored original Build 15
needed its own equivalent regrant, which the owner completed. Direct-launched
fresh instances of Build 15, A and B reported the saved bookmark stale and
preference access denied; a LaunchServices-started Build 15 instance reported
the bookmark stale but read the complete table from all three sources. An
exact-file reselection may be needed if safe bookmark renewal fails; current
normal-app reads do not themselves require another file-picker action. No
broader grant or TCC reset is justified by these observations.

## Long-lived no-paid signing route investigated on 2026-09-26

The currently installed Usage4Claude app is signed with a self-signed Code
Signing certificate, has no Apple TeamIdentifier, and passes strict code-signing
verification. Its default designated requirement combines its bundle identifier
with the certificate leaf; for a single self-signed certificate, leaf and root
refer to the same certificate. The embedded public certificate has Code Signing
extended key usage and a 2025–2035 validity interval. Usage4Claude's build
script selects that identity by name; its release workflow imports a password-
protected PKCS#12 identity into an ephemeral CI keychain. A separate Sparkle
EdDSA key signs its update archive. Usage4Claude's own README reports manual
first-launch approval and occasional renewed Keychain prompts after updates.
These are concrete implementation details, not evidence that Blenny's Device
Control, exact-file bookmark, or Gatekeeper path will behave identically.

**Recommended for Blenny's local, no-paid continuity path:** create a distinct,
long-lived self-signed Code Signing identity for Blenny in a persistent private
keychain. Retain its private key and one encrypted, owner-controlled offline
backup outside Git and CI until a release workflow actually needs it. Use the
same identity for every eligible Blenny package, keep
`xyz.fi5h.blenny`, entitlements, build flavor and installation path stable,
and record the resulting designated requirement and certificate expiration.
The existing `BLENNY_CODE_SIGN_IDENTITY` build switch already accepts an
identity; do not hard-code or commit private material. The A/B test's disposable
private key was destroyed, so adopting a durable identity is a new initial
signer transition and requires its own Device Control onboarding and continuity
retest. Do not re-use Usage4Claude's private signing key merely to avoid
creating a Blenny key: it couples both apps' release security and recovery.

An owner-operated private CA with a stable root and replaceable signing leaves
could instead use an explicit root-anchored designated requirement. Apple's
code-signing guide describes this mechanism. It adds offline CA-key custody,
chain configuration and rotation procedures, and Blenny has not tested its
Device Control or bookmark behavior. For the current single-app, local trial it
is more machinery than the proven single long-lived self-signed identity;
revisit it before certificate expiry or if planned rotation becomes material.

Ad-hoc signing has no reusable certificate requirement. Apple's free Personal
Team is for development and has short-lived provisioning, not a durable direct-
distribution substitute. A self-signed identity gives local version continuity
but not Apple-verified publisher identity, Developer ID, notarization, or a
default-Gatekeeper distribution pass. This host currently has Gatekeeper
assessments disabled, so local `spctl` acceptance cannot fill that gap. Apple
explicitly requires Developer ID for notarization and cautions against shipping
self-signed apps. Adding Sparkle EdDSA would protect an update archive if an
updater is later added; it would not replace the app code-signing identity or
Apple notarization. Blenny currently has no updater, so adopting Sparkle solely
for this signature investigation alone would expand product scope without
improving the observed Device Control or bookmark boundary.

The owner subsequently requested Sparkle and durable Blenny signing as one
implementation. The integration and its separate acceptance gates are tracked
in [the Sparkle update record](SPARKLE_UPDATES_0.12.0.md). The earlier A/B
permission outcomes remain limited to the disposable certificate and manual
replacement; they do not prove Sparkle delivery or continuity under the new
durable identity.

The owner subsequently created the distinct identity and the agent ran the
bounded live sequence described below. The owner later reported keeping the
PKCS#12 export as a SafeInCloud attachment; importability was not tested at
the owner's request. Do not label reboot, bookmark renewal, Undo, or public
installation as passed without those live tests. The owner's intermittently
unstable Undo is deferred. An owner-initiated Build 27 Apply is recorded below
without running Undo or modifying the accepted result.

## Durable identity live continuation on 2026-09-26

The new login-Keychain `Blenny-CodeSigning` identity has public SHA-1 hash
`A8B5D4CB304878A53B7B76C139572F414D70EC28`, Code Signing extended key
usage, and expiry 2036-09-23. Debug Builds 24, 25 and 27 were built with the same
certificate, `xyz.fi5h.blenny`, exact-file entitlements and installation path.
Their CDHashes were `f5e62559ff5f052fbf78f570652644b1068aee89`,
`8a4dc90b699899246bc1a86fe64dc14251b5249b`, and
`b55ea8b8b07e6d00916dede7c2187ae792cef45f`, respectively. Their
designated requirement was identical:
`identifier "xyz.fi5h.blenny" and certificate root =
H"a8b5d4cb304878a53b7b76c139572f414d70ec28"`. All three passed strict
nested code-signature verification. This is a distinct certificate from the
disposable Build 16/17 test signer.

Before replacement, Build 17 was running with management on, no pending
draft and a previously undone change. The installed bundle and all private
Blenny app-state files were backed up byte for byte under ignored `LocalData/`.
A LaunchServices read-only diagnostic produced 33 identical typed entries
from file/API/file, despite its pre-existing stale bookmark. Build 17 was
quit normally before installing Build 24. That normal quit changed only the
saved `managementEnabled` flag from `true` to `false`; accepted policy maps and
the other private state files remained identical. Do not attribute this
business-state transition to the new signature.

| Scenario | Device Control | Bookmark and ordering | Local actions | Boundary |
| --- | --- | --- | --- | --- |
| First durable Build 24 at the same path | Initially denied; the owner removed the old Blenny entry and granted the installed app. Settings then reported granted. | Bookmark still stale; normal-launch file/API/file agreed on the same 33-key table as the Build 17 baseline. | Board populated; no draft or Apply. | First signer transition needs onboarding. |
| Build 24→25 manual upgrade, same signer and path | Granted without a new user action. | Bookmark still stale; all three reads agreed on 33 entries, but 19 existing position values differed from Build 24. | Board populated; no Apply. | Device Control continuity passed; complete ordering-value continuity did **not** pass. |
| Build 25 ordinary process restart | Granted without user action. | Full 33-key table digest unchanged from first Build 25 capture. | Board populated. | App restart passed; this is not a macOS reboot. |
| Build 25 same-build overwrite | Granted without user action. | Full 33-key table digest unchanged from pre-overwrite Build 25; file/API/file agree. | Within-area sort and Visible→Revealable→Hidden drafts appeared and were discarded; no preference change. | Same-build overwrite and local draft controls passed. Native drag, Apply and Undo on Build 25 remain untested. |
| Build 25→27 manual upgrade, same signer and path | Granted without a new user action. | The complete 33-key table was identical as typed values immediately before and after replacement; file/API/file agreed in both captures. The same saved bookmark remained stale. | Board populated, management remained stopped, and no Apply occurred. All private Blenny app-state files matched the pre-upgrade backup. | A second same-signer manual upgrade passed Device Control and ordering-value continuity. This does not explain the earlier 24→25 change or establish reboot/Sparkle-install continuity. |
| Build 27 local controls after upgrade, before owner Apply | Grant and Board remained available. | File/API/file still agreed on all 33 entries after the drafts were discarded, and the complete table and private Blenny app-state files stayed unchanged. | The approved Usage4Claude moved one position right in a local sort draft, then Visible→Revealable→Hidden in a separate three-state draft; each was discarded. | Local sort and three-state draft controls passed after upgrade. Native drag and Apply were tested later by the owner; Undo remains untested. |
| Build 27 normal quit while a local draft exists | The same running process stayed open. | The accepted 33-key table and private Blenny app-state files remained unchanged after Discard. | Quit was cancelled with an apply-or-discard warning; the draft remained visible until explicitly discarded. | Normal-quit draft protection passed. Forced termination and an actual Sparkle installer were not tested. |
| Owner native drag and Apply in Build 27 | Device Control still reported granted after Apply. | The complete table retained 33 keys; direct file/API/file agreed. Four existing application-position values changed, with no key additions or removals. The saved bookmark remained stale. | The owner reported native dragging and the accidental Apply worked normally. The UI showed Changes applied and an available Undo Changes action; the recovery receipt recorded phase `applied` and `configurationVerified=true`. | The configuration write is independently verified. The product recorded `physicalVerificationStatus=unavailable` and displayed "Some on-screen positions could not be verified"; the owner's visual success is separate evidence. Undo was not run, and the accepted new order and receipt were preserved. |

The 19-value change includes a substantial WeChat position change and is
reflected by a changed Board order. A same-build Build 25 restart and overwrite
and the later Build 25→27 upgrade did not repeat it. The captured file/API/file
agreement rules out a mere
presentation cache mismatch at the time of each read. The writer or external
cause of the change has not been established; do not call it a signing-caused
bookmark or TCC failure, and do not rewrite the accepted ordering to hide it.
There was no TCC reset, broader file grant or real Sparkle update. The later
owner-initiated Apply is the only Blenny Apply in this durable-signing
continuation. The
separate [Sparkle integration record](SPARKLE_UPDATES_0.12.0.md) covers signed
archive verification and its remaining network/installation gates.

Sources: [Apple Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html),
[code requirements](https://developer.apple.com/documentation/security/applying-code-requirements),
[free Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account),
[Developer ID eligibility](https://developer.apple.com/help/glossary/developer-id-certificate/),
[notarization requirements](https://developer.apple.com/documentation/security/resolving-common-notarization-issues),
and [Sparkle update signing](https://sparkle-project.org/documentation/).
