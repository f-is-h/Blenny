# Technical spike 1.0.0: public release preparation

Status: 1.0.0 source finalized for authorized local commit/tag closure. Local
implementation and checks are verified through 2026-09-30; the owner confirmed
all requested development acceptance except multiple displays. GitHub-built
publication is pending and is not implied by local closure. See [the release record](RELEASE_1.0.0.md) and
[acceptance matrix](ACCEPTANCE_1.0.0.md).

The approved [automation plan](RELEASE_AUTOMATION_PLAN_1.0.0.md) supersedes earlier
post-build owner gates. Version display now excludes the internal build; recovery
receipts retain it. Structured fragments generate both release documents. The
three GitHub workflows separate ordinary CI, preparation PRs and annotated-tag
publication. All human acceptance precedes that trigger. Publication reuses sealed
artifacts, checks pinned signatures and provenance, verifies anonymous assets
before updating the feed, and performs a manager-free Sparkle information check.
These are implemented workflow paths, not evidence of a hosted run.

## Hosted signing diagnosis and manual recovery (2026-10-01)

The first production attempt stopped on repository visibility; the second passed
660 Debug and 608 Release tests and the source/history audit, then stopped at the
valid-identity check after P12 import. That check did not distinguish a wrong
certificate from a missing private-key identity or missing hosted trust. The
existing self-signed signing route is retained. Run 36792759271 confirmed that
the matching certificate and private-key identity were excluded by the trusted
valid-identity filter, then became valid after temporary runner trust. This proves
the prefilter's trust rejection, not that actual explicit-identity signing needs
that trust. Its exit cleanup stalled; run 36793628261 localized the hang to the
admin trust removal and import commands. Keychain context restoration and deletion
worked. The controller now removes those administrator mutations and probes actual
signing plus fixed-root requirement verification on a disposable executable. That
probe must be verified on the real runner before declaring this route resolved.
The bb3f9ae and bfe8231 controllers both passed hosted Development checks (660 Debug
and 608 Release tests, with their respective release-tool checks).

The owner specified retaining 1.0.0 for CI-only repairs and requested a manual
production entry for future use. The controller and selected annotated application
source are checked out separately. The app is built from the clean original tag,
with its accepted digest and reviewed notes; the receipt also records the workflow
controller commit. Verification and diagnosis never publish. Manual production
requires an explicit existing tag and shares the automatic publication gates;
public tags and published asset bytes remain immutable. This implementation is
available on main. Certificate diagnostics alone do not imply successful probe verification,
cleanup, packaging or publication.

## Hosted draft-publication recovery (2026-10-01)

Controller a893e93 passed the actual fixed-root signing probe without modifying
system trust (diagnostic run 36794394103), then completed verification-only
packaging and Sparkle fixture checks (run 36794536859). The owner's manual
production run 36796785800 also passed source tests, signing, sealed provenance
and the build job. Publication created an empty draft, then failed because
`GET /releases/tags/{tag}` returns published releases only. Treating its 404 as
absence made the script dereference a missing release. No asset upload or feed
write occurred in that attempt.

The controller now checks the authenticated, paginated release list after a tag
404 and rejects duplicate matches or lookup failures. It resumes the existing
empty draft rather than creating another release. With no asset bytes present,
a fresh dispatch may allocate a newer unpublished internal build. Partial drafts
still require their matching sealed artifact; published assets remain immutable.
Before publishing, downloaded draft files must also match every selected sealed
file byte for byte. Tests cover draft lookup, first creation, empty-draft recovery,
unavailable drafts and mismatched sealed bytes. This repair preserves v1.0.0 and
its original application source; production retry remains owner initiated.

The automation-stage follow-up passed 658 Debug and 606 ordinary Release tests,
27 Python release tests, workflow boundary checks and pinned actionlint locally
on macOS 27.0.1 build 26A434 with Xcode 27.0 / SDK 27.0. Eight negative package
cases are rejected. This is deterministic/build evidence on that patch build,
not new physical menu-bar acceptance. That development DMG was Build 113;
the corrected Build 114 candidate and owner result are recorded below and in
RELEASE_1.0.0.md. The installed daily app remains Build 108. Earlier 26A428
and Build 107/108 observations retain their original scope.

## Fresh VM overflow and scroll-indicator regression (2026-09-30)

The owner reported persistent horizontal scrollbars in all three policy lanes
and two chevrons after reveal on the fresh VM. Read-only Parallels inspection
confirmed macOS 27.0.1 build 26A434, English language and installed Build 113.
The VM's explicit AppleShowScrollBars preference is absent; no setting was changed.

The lanes used SwiftUI's hidden indicator preference, which macOS may override
for a mouse. Apple's documented never visibility overrides that behavior. The
lanes now use never; their scrolling and existing item-movement actions remain.

Read-only inspection of MenuBarAgent's MenuBarCore localization table found the
English pair Show Hidden Menu Bar Items / Hide Menu Bar Items. The former was
recognized, but the latter was absent from both control and state classifiers.
An expanded English control therefore ceased to qualify as a usable control:
Blenny restored its fallback and could not retain the known native collapse edge.
The same table supplied the Japanese pair; those exact labels were also missing.
The classifiers now recognize these labels without changing discovery roots,
notification subscriptions, ambiguity guards, compaction limits or writers.

A regression using the resource labels failed before the repair for both
languages, then passed after it. It exercises Blenny-opened reveal, native
takeover, fallback suppression and native collapse through the management loop,
asserting baseline / revealed / baseline plans and exclusion of Hidden owners.
This establishes the deterministic defect and repair. On 2026-09-30 the owner
reported testing the corrected package in the fresh system and confirmed the
reported problems were resolved. This is owner-observed English-guest acceptance
of the lane indicators and native takeover/collapse; no Japanese physical run or
broader permission/lifecycle coverage is inferred.
The corrected ordinary Release Build 114 package passes signatures, read-only
mounted contents and independent Ed25519 authentication. Full checks pass 659
Debug, 607 ordinary Release and 27 Python tests, plus workflow/actionlint checks.
Use that package, rather than Build 113, for the guest regression run.
No real Apply, reveal, collapse, preference write or installation was performed
in the VM during this investigation.

## Complete system-label coverage follow-up (2026-09-30)

The English repair did not establish support for other system languages. A
read-only inspection of the installed macOS 27.0.1 (26A434) MenuBarCore.loctable
found 40 locale entries and 37 distinct collapse/expand pairs. The previous
English/Chinese/Japanese marker list omitted most of them. A macOS 27-only label
catalog now supplies both control identity and exact presentation-state matching;
existing observed aliases remain accepted. No runtime resource dependency,
translation guess, new subscription, polling, write or synthetic action is added.
Unknown and contradictory labels still fail closed.

An independent fixture covers every resource locale entry. It exercises native
takeover, fallback suppression, collapse, the sole writer and Hidden exclusion;
classifier cases also reject wrong roles, unrelated owners, extended labels and
contradictory states. This closes the known label-list omission deterministically.
Full local verification passes 660 Debug, 608 ordinary Release and 27 Python
tests, workflow checks and pinned actionlint. Build 116 passes sealed signed
package checks. Physical acceptance remains the owner's English guest result and earlier host
observations; other languages and future system label changes are not declared
physically tested.

## Contract

Debug and ordinary Release share accepted daily ordering, three-state policy,
access and durable recovery. Diagnostics and research entry points stay Debug-only.
The existing self-signed Blenny certificate and independent Sparkle key remain
stable. Developer ID and notarization are not gates for this owner-selected route.
Current-host macOS 27 support is validated; other configurations are unverified.
The owner selected Apache-2.0. The website is handled separately. Publication,
commits and tags remain separate actions. See IMPLEMENTATION_PLAN_1.0.0.md.

## Reference comparison

| Area | Usage4Claude | Blenny 1.0.0 |
| --- | --- | --- |
| App signing | Fixed self-signed identity | Existing pinned Blenny identity |
| Update signing | Independent EdDSA signature | Existing Blenny key/account |
| Hosting | GitHub Release DMG and raw HTTPS appcast | Same hosting design, Blenny URLs |
| Release notes | User-facing release notes feed appcast | Separate user-facing notes |
| Automatic checking | Enabled in the reference | Explicit user toggle, default off; no unattended install |
| Sandbox | Sandboxed XPC configuration | Existing non-sandboxed architecture |
| Build number | Version-derived reference | Monotonic Blenny release number |

The reference repository was inspected read-only. Its identity, keys, sandbox
settings and older mixed certificate/EdDSA backup instructions were not reused.

## Capability boundary

| Shipping in both configurations | Debug / explicit test only |
| --- | --- |
| Policy groups, ordering Board, exact system-item capabilities | Developer menu, environment seeds, dry runs |
| Coordinated Apply, unified Undo, durable recovery and access picker | Position calibration, boundary snapshots, click diagnostics |
| Persistent control placement and separate Undo | Grouped fallback and legacy Now Playing experiments |
| Exact macOS 27 writer/shim with runtime guards | Raw inventory diagnostics and disposable Sparkle user driver |

BLENNY_PRODUCT explicitly enables reviewed product code in Swift and the C shim.
Release does not define DEBUG. Public Release carries required exact-file access
entitlements/purpose strings. Now Playing stays recovery-only; Siri, Time Machine
and Control Center sorting remain deferred. Catalog and AppKit menu tests run
in both configurations. Production package strings prove the ordering table is
present and diagnostic/test entry points are absent.

## Responsibility and storage changes

- ApplicationUpdater and ApplicationLoginService own their separate services.
- AppDelegate ordering and diagnostics are extracted into separate files. The
  AppKit delegate retains the shared state/interaction lifetime; no second writer
  or independent management controller was introduced.
- Window lifecycle, observable interface state/actions, Board, Settings, Support
  and visual components are separated. Geometry/accessibility/drag tests remain.
- Ordering values, snapshot, identities, targets and plan serialization are split
  without changing encoded names, schemas or fingerprints. Legacy recovery
  fixtures remain in both test configurations.
- Policy and bookmark replacement share a private synchronized file primitive:
  directory 0700, file 0600, exclusive temporary file, checked directory identity,
  rename and directory/file fsync. Symlink rejection leaves its destination's
  permissions unchanged. These are filesystem/process tests, not power-loss tests.
- Existing DebugOrdering, shared-system and control-placement data paths remain.
  No state migration, accepted-policy reset or Undo deletion is performed.

## Authorization finding and repair

A normal LaunchServices read-only run of the installed baseline and the first
candidate found Device Control granted and complete API/file layout agreement,
but the saved exact-file bookmark was stale. The old code rejected staleness
before trying the resolved scope. The repair validates the exact target, enters
its existing scope and renews the bookmark once. Wrong identity/revoked scope or
renewal failure preserves saved bytes and the prior active scope; no fresh grant
is manufactured and no TCC state is reset. New deterministic lifecycle tests pass.

Final Build 106 was temporarily placed at /Applications for explicit diagnostics
only, which exit before management initialization. Fresh launch and relaunch JSON
reports have Device Control granted, active bookmark, complete read agreement
and no errors. The installed 0.13.0 Build 79 was restored byte-for-byte and its
deep strict signature verified. No third-party preference mutation was exercised.

On the second very short diagnostic run, `open -W` can report a kevent wait race
("No such process") after the application has already written a complete valid
fresh JSON report and exited. Reports and complete installation restoration were
verified independently; this wrapper result is not treated as a failed grant.

## Distribution and update evidence

### First-use Apply follow-up (2026-09-30)

The owner reported a session-invalidated error after clearing application data
and reinstalling Build 106. Read-only inspection found an absent Blenny data
directory and an unapplied Board draft. The exact intervening user actions were
not recorded. A deterministic empty-directory reproduction establishes the
first-Apply defect: preview reads the in-memory initial policy through
PolicyInterfaceStore, but combined Apply read the raw persistent store, which
returns nil until the first save. It rejects before an ordering intent or system
write. The former error text incorrectly asserted that restoration was required.

Ordering activation, Apply, Undo and cleanup now share PolicyInterfaceStore.
The first explicit save durably seeds the reviewed initial policy before saving
the proposal, so the accepted policy has a previous-policy backup on relaunch.
The adapter forwards exact snapshot restoration, including an absent backup.
Undo and Restore Visibility validate the prior sparse policy using only its
already-approved owners; removed assignments return to implicit Visible intent
without authorizing any new owner. Review freshness uses the same reduced scope.
Session invalidation no longer claims that a recovery record necessarily exists.

New tests reproduce the old pre-write rejection, then exercise first Apply,
disk-store reopening, stopped Undo, Restore Visibility to the initial policy,
unapproved-target rejection and exact backup rollback. They use private temporary
files and fake system writers. Build 106 remains the earlier DMG artifact and
does not contain this source repair. The owner authorized compilation and local
installation of ordinary Release Build 107 on 2026-09-30. Its pinned designated
requirement matches Build 106, deep strict signature validation passes, installed
files match the new package, and the complete old installation was preserved in
ignored local storage. A normal launch from Applications with empty application
data displayed the stopped initial Board without the session-invalidated error.
The owner subsequently reported completing real-menu-bar acceptance of Build
107. No per-target action trace was supplied; this is owner-observed evidence.

Read-only inspection after that run found an initial Visible policy with
management enabled and no previous-policy backup. Active first Undo restores
that exact shape, including backup absence. A deterministic reproduction showed
that resume and startup incorrectly rejected it. Build 108 permits backup absence
only for a strict initial policy: one Visible Blenny entry, Visible Bluetooth,
and no other system-item entries. Any additional owner entry or non-Visible
Bluetooth intent still requires the recovery backup. No historical backup is
fabricated or replaced. Tests cover active and stopped Undo, relaunch/resume and
negative missing-backup cases.

Xcode 27/macOS 27 SDK verification for this follow-up: Debug 649 core + 8 app
tests (657 total), ordinary Release 597 core + 8 app tests (605 total), all
passed. Signed Debug and ordinary Release app packages were rebuilt. The installed
Build 108 files match its package and its pinned/deep strict signatures pass;
Build 107 is preserved locally. Normal installed startup reports Management on
for the existing initial policy, with all three app-owned state-file hashes
unchanged and no backup created. No reviewed Apply was performed by the agent.

A replacement Build 108 DMG passes the distribution gate, read-only mounted
file comparison, Applications-link and signature checks. Five negative packages
are rejected again. The real loopback Sparkle installer and all rejection/cancel
cases were rerun from current source; product file hashes and Sparkle preferences
are preserved. Build 106 is retained only as historical evidence below.

The previously prepared self-signed candidate is 1.0.0 Build 106. Deep strict/pinned signatures,
arm64/minimum OS/SDK, production feed/public key, rpaths, legal resources and
Debug/test exclusion pass. The DMG mounts read-only and every application file
matches the signed candidate. It includes an Applications link. EdDSA verification,
checksum and receipt are generated after the immutable archive is complete.
Five negative distribution checks reject test flavor, HTTP feed, wrong key,
missing NOTICE and modified executable.

A separate scratch directory builds the disposable update fixture with the same
source, certificate and public key. Its driver bypasses management startup and
uses real Sparkle installation. The harness refuses an ordinary manager binary.
Build 101 updates to 102 and relaunches; cancellation, equal/older builds, missing
feed, incorrect signature and damaged archive all pass. Direct signature tamper
verification also rejects the archive. Executable, designated requirement, key
and build checks pass; all policy/recovery file hashes remain unchanged and
Sparkle preference keys are restored. No production ATS exception is added.
This proves local loopback installation, not public HTTPS delivery or attended
guest behavior. Actual delegate checks cover manual/background/information paths
and share the draft/busy/recovery gate.

A test-only `standard-ui` mode additionally calls the actual ApplicationUpdater
with Sparkle's standard user driver, without initializing menu-bar management.
The actual update window's version and release notes were inspected. Keyboard
confirmation exercised downloading, extraction, Ready to Install and Install and
Relaunch. The fixture updated from Build 101 to 102 and relaunched with the target
executable and pinned signature; all product file hashes remained unchanged and
Sparkle keys were restored afterward. Initial keyboard-only dismissal attempts
did not dismiss the prompt and ended at the fixture's bounded deadline; this is
not claimed as standard-dialog cancellation evidence. The automated custom-driver
cancel test remains passed separately. All fixture processes and the loopback
server exited, and the daily installed Build 108 was reopened. Ordinary Release
was rebuilt after the test-only addition: its CDHash is unchanged and diagnostic
exclusion still passes.

## Verification ledger

Xcode 27.0 build 27A266a, macOS 27 SDK, Apple silicon, macOS 27.0 build 26A428:

- Debug: 649 core tests + 8 app tests = 657, all passed (2026-09-30).
- Ordinary Release: 597 core tests + 8 app tests = 605, all passed (2026-09-30).
- Appcast: 5 deterministic tests, all passed.
- Settings: 80 actual AppKit layout cases with the update toggle, all fit 420 px.
- Debug and ordinary Release app builds: signed; strict signatures pass.
- Explicit ad-hoc contributor Debug build: passed, public update feed disabled.
- Local Sparkle fixture and negative distribution checks: passed as above.
- Current-host authorization reports and original app restoration: verified.
- Reachable-history/privacy audit: 62 commits, 767 blobs; no scanned forbidden
  paths, private keys, GitHub tokens or personal absolute paths; Git fsck passed.

The release skill's preparation audit has two expected closure findings: no
1.0.0 commit exists after v0.13.0, and documents deliberately do not claim a
completed milestone. The source is uncommitted and no v1.0.0 tag exists. Do not
change evidence/status merely to satisfy the completion-only audit condition.

## Remaining acceptance

The [matrix](ACCEPTANCE_1.0.0.md) records the owner-reported Build 107 acceptance
and a fresh macOS 27 VM plan. Clean-host first launch, revoked/regranted OS
permissions, login/uninstall and sleep/display cases where available retain
separate evidence requirements. Standard update installation is verified locally;
dialog dismissal and guest behavior are separate observations. No real fault injection or
third-party write substitutes for those. After authorized source closure and
publication, verify anonymous public asset/feed delivery and hosted updating.
