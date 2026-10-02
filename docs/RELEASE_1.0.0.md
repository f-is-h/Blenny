# Blenny 1.0.0 source release record

Status: **Published on 2026-10-01 from annotated tag `v1.0.0` (source
`a7c004a`) by GitHub Actions run 36823493882, Build 1701.** Anonymous asset and
feed verification passed; see `docs/public-release.json`. Multi-display coverage
remains unverified. Updated 2026-10-03.

## Release page story, 2026-10-02 to 2026-10-03

After publication the owner approved a reviewed story in `docs/releases/1.0.0.md`,
rendered by `release_tools.py` into the 1.0.0 section of `docs/RELEASE_NOTES.md`
on main. On 2026-10-03, with the owner's explicit authorization, the GitHub
Release body was replaced with that section (`gh release edit v1.0.0
--notes-file` using `release_tools.py notes --version 1.0.0`) and verified
identical afterwards. The tag, DMG, checksum, receipt, `release-notes.md` asset
and appcast entry are unchanged and carry the originally sealed notes
(`releaseNotesSHA256` `9f8b2c01…`), which `docs/release-acceptance.json` also
records. The Release body therefore intentionally differs from the sealed
`release-notes.md` asset. Do not rerun the 1.0.0 publish transaction: its body
check compares against the tagged notes and would stop. 1.0.0 is the first
release, so no updater shows its notes.

## Final source closure decision, 2026-09-30

The owner instructed formal 1.0.0 closure and confirmed all requested development
acceptance except multiple displays. The versioned acceptance record now binds
the current product/configuration digest and prepared release-notes section.
This is owner-observed evidence; earlier Build 107 and English VM Build 114
observations retain their exact scope, with no new Build 116 physical run inferred.
The all-locale label extension remains deterministic coverage.

The owner initially requested a GitHub Release before changing visibility, then
accepted local version closure first, manual Public conversion second and Actions
publication afterward. Keep the existing production preflight and anonymous
delivery checks. Do not change visibility or push the production tag while the
repository is private. Hosted signing Secrets and first workflow execution remain
pending; the xcode-27 ARM64 catalog advertises macOS 27.0 (26A428), Xcode 27.0
(27A266a) and SDK 27.0, which is feasibility evidence rather than a successful run.

The intended source commit includes product/tests, build/release tooling,
workflows, public documentation, Apache-2.0 notices and the empty root appcast.
Website/ and .claude/ are excluded; LocalNotes/ and LocalData/ remain ignored.
Existing history and the original first commit are preserved. No source rewrite,
visibility change, credential transfer, push or hosted publication is implied.
The dated preparation sections below preserve their earlier status and are
superseded by this closure decision where applicable.

## Fresh VM regression follow-up, 2026-09-30

The owner found persistent lane scrollbars and failed native-chevron takeover in
the English macOS 27.0.1 VM using Build 113. The lane visibility preference now
uses SwiftUI never rather than hidden. Classifiers now accept MenuBarAgent's
actual English expanded label, Hide Menu Bar Items, and its Japanese expand/
collapse pair. The label-to-management-loop regression fails before the repair
and passes afterward, preserving one writer and excluding Hidden owners. See
TECH_SPIKE_1.0.0.md for the deterministic and owner-observed evidence boundary.
Build 113 predates this repair and is superseded for new acceptance.

The corrected VM package is `LocalData/releases/1.0.0-114/Blenny-1.0.0.dmg`,
5,807,702 bytes, SHA-256
`34da366d5df89b8fe0fdd68f0d6d2ac57c6b3f1557f0aee2ab0d21cc41b868a0`.
Its local-development receipt records dirty source truthfully. Debug 650 core +
9 app = 659 and ordinary Release 598 core + 9 app = 607 tests pass, alongside
27 Python tests, workflow boundary checks and pinned actionlint. Pinned code
signatures, production resource gates, read-only mounted contents, checksum and
independent Ed25519 verification pass. Neither host nor guest installation was
replaced by the agent. The owner subsequently reported testing the replacement
package in the fresh system and confirmed the reported problems were resolved.
This closes the English-guest regression cases; broader permissions/lifecycle
and first-launch provenance are not inferred from that report.

## Pre-release review reconciliation, 2026-09-30

The earlier review's pending real-menu-bar list is partly superseded by the
owner's Build 107 acceptance and the Build 114 English-guest regression result.
Unreported first-launch provenance, permission revoke/regrant, login, uninstall
and relevant lifecycle observations retain their own acceptance states. Passing
these regression cases does not establish every attended check.

The intended application source boundary includes product code, tests, build/
release tooling, workflows, public documentation, legal files and root
appcast.xml. The feed remains a valid empty document until the first authorized
publication; it must not advertise a private development package. Website/ and
.claude/ remain outside this release's intended commit scope. The local
.claude/settings.local.json is now ignored without deleting or editing it.
Other .claude files retain their existing state and are not silently staged.
The owner explicitly reconfirmed that Website/ must not be committed.

AGENTS.md now explicitly records the owner's 2026-09-29 Apache-2.0 selection.
Config/Info.plist already declares marketing version 1.0.0; build tooling assigns
the actual local/CI internal build. It does not encode milestone completion.
Keep the candidate status until the remaining acceptance, authorized Git closure
and hosted setup/execution are complete. Source scope preparation is not commit,
tag, push or publication authorization.

The owner also requested one-time sponsorship as the right-click menu default.
The GitHub Sponsors link now specifies frequency=one-time and retains its menu
attribution metadata. The Support page's explicitly monthly and one-time actions
retain their separate purposes. No browser payment or external write was made.
All current GitHub Sponsors entry points were compared with Usage4Claude:
application links carry project/source/placement; local website menu/footer links
also carry language=en. The owner explicitly retained both Support buttons and
every entry-point design; website default frequency remains unchanged. Only those two website
URLs were edited under the owner's follow-up; Website/ remains excluded from the
release commit and was not deployed. The later owner-requested README addition
provides GitHub Sponsors and Ko-fi, with readme/badge/en metadata on Sponsors.

At that stage, all five URLs passed metadata-schema/order/HTML-escaping checks and return
HTTP 200 with the actual public Sponsors page. The product-presentation and
actual AppKit status-menu tests pass in Debug and ordinary Release. Full checks
remain 659 Debug, 607 ordinary Release and 27 Python tests, with workflow checks.
The sponsorship follow-up development package was Build 115, containing the menu's one-time
default and the previously accepted VM repairs. Its archive is
`LocalData/releases/1.0.0-115/Blenny-1.0.0.dmg`, 5,807,741 bytes, SHA-256
`88d53a1bb541c3074e0e57f317f5bd09e040d72c10a40237ba141acac580fc25`.
The code/resource, mounted-content and independent Ed25519 gates pass. This is a
local development artifact, not a published binary or new broad owner acceptance.

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
Physical acceptance remains the owner's English guest result and earlier host
observations; other languages and future system label changes are not declared
physically tested.

The owner requested a minimal macOS 27-only README requirement, exact test
environments in the acceptance matrix and both sponsorship destinations. An
ignored Chinese preview is retained under LocalNotes; English remains canonical.

Full local verification now passes 651 core + 9 app = 660 Debug and 599 core +
9 app = 608 ordinary Release tests, plus 27 Python tests, workflow checks and
pinned actionlint. All 40 locale fixture cases pass takeover/collapse and exact
classification checks. The six public source/website/README Sponsors links pass
schema and encoding checks and return HTTP 200; the ignored Chinese preview's
language-tagged link also returns HTTP 200. Both READMEs' local links resolve.

The newest signed development artifact is Build 116:
`LocalData/releases/1.0.0-116/Blenny-1.0.0.dmg`,
5,812,142 bytes, SHA-256
`ea9a5dc3fe5a938db6925603359dfcb2bff5d750265d8c76b5e941c8dfc27487`.
Pinned/nested signatures, production resources, read-only mounted contents and
independent Ed25519 authentication pass. The source receipt remains honestly
dirty and local-development; the installed host/guest apps were not replaced.
Earlier Build 114 owner acceptance retains its exact scope. Neither other-language
physical acceptance nor hosted execution is inferred from these checks.

## Release automation implementation, 2026-09-30

The approved automation design is implemented locally. Public UI displays only
the marketing version; ordering recovery diagnostics retain the internal build.
The first-public fragment set generates CHANGELOG.md and the versioned user
release notes. Both publication channels consume the same reviewed section.
Normal CI, preparation PRs and annotated-tag publication are separate workflows.
Publication has no post-build human checkpoint. Hosted execution and owner VM
results are still pending; linting is not evidence of a successful Actions run.

Automation-stage local verification on arm64 macOS 27.0.1 build 26A434, Xcode 27.0 build
27A266a / SDK 27.0: Debug 649 core + 9 app = 658; ordinary Release 597 core +
9 app = 606; six appcast, eight preparation/generator and thirteen transaction/
signature/cleanup tests passed. Workflow YAML/security-boundary checks and
checksum-pinned actionlint 1.7.11 passed. Signed Debug Build 111 and ordinary
Release packages passed their relevant signature checks. Eight negative
distribution cases rejected test flavors, loopback feeds, wrong keys, missing
artwork, zero builds, mismatched marketing versions, ad-hoc identities and Debug
diagnostic entry points. The public provenance gate rejects local artifacts.
The manager-free public Sparkle information probe compiles with warnings as
errors; it has not contacted a published Blenny feed.

The automation-stage VM package was `LocalData/releases/1.0.0-113/Blenny-1.0.0.dmg`;
the corrected Build 114 package above supersedes it.
Its adjacent checksum and receipt record the exact byte length, SHA-256, signature,
product digest, source/dirty state and toolchain. Packaging verifies read-only
mounted contents, pinned/nested code signatures, resources and independent
Ed25519 authentication. Build 109 was a failed verification attempt after macOS
returned a /private/var mountpoint alias; the image was detached, canonical path
comparison and unconditional cleanup were fixed, and failure-cleanup tests added.
Do not use that unsealed attempt. Builds 110 and 112 are superseded development
iterations. The installed daily Build 108 was not replaced by this work.

The owner README was retained with only a three-line GitHub-build/notes addition;
removing that addition reproduces its original SHA-256. The three app-owned
policy/access files remain byte-identical. No new real Apply/Undo or third-party
menu-bar write was performed. Earlier owner and Sparkle runtime evidence below
retains its original scope; no new physical or hosted result is inferred.

Remaining pre-trigger work: owner fresh-VM permission/login/uninstall and relevant
first-Undo/lifecycle observations, reviewed notes and bound acceptance digest,
authorized source closure/push, controlled Blenny signing-secret setup, Actions
preparation-PR permission and actual hosted CI/verification-only execution.
The repository remains private with no signing secrets. Visibility and exact-tag
authorization precede production. Once authorized, the tag's workflow performs
the whole publication transaction unattended. No commit, tag, push, key export,
repository-setting change or publication was performed during local implementation.

Follow-up on 2026-09-30: empty-data first Apply fails in Build 106 because
preview uses the initial in-memory policy while execution reads an absent disk
policy. The source now shares that store across Apply and recovery, retains the
initial-policy backup, and restores sparse prior policies without expanding
authorization. See [the technical follow-up](TECH_SPIKE_1.0.0.md#first-use-apply-follow-up-2026-09-30).
The Build 106 artifacts below predate this repair. Ordinary Release Build 107
was subsequently compiled, signed with the same pinned identity, locally
installed and launched with an empty data directory; the initial stopped Board
displayed normally. The old installation was backed up and the new installation
matched its package. The owner then reported completing real-menu-bar acceptance.
No per-target action trace was supplied. A subsequent active first-Undo regression
was reproduced in tests: the exact initial Visible policy correctly has no old
backup, but startup and resume incorrectly rejected that shape. The narrow repair
accepts backup absence only for that initial policy; every noninitial policy still
requires its recovery backup. It neither fabricates a backup nor expands scope.

Ordinary Release Build 108 now contains this repair. It is packaged and installed
with matching complete file hashes and pinned/deep strict signatures; Build 107
is preserved locally. Normal installed startup reports Management on with the
existing initial policy, no new backup and all three product-state file hashes
unchanged. The agent performed no reviewed live Apply. The owner-confirmed new
macOS 27 Parallels guest is the planned fresh-install regression environment.

## Resulting behavior

Ordinary Release now exposes the reviewed daily Debug product capabilities:
three-state policy, attributable-owner ordering, exact supported system items,
coordinated Apply/unified Undo, existing durable recovery, layout access, persistent
Blenny control placement and its separate Undo. Developer menus, raw probes,
legacy Now Playing trials and the disposable update driver stay out of production.
No new capability is granted by an icon/name alone.

The existing macOS 27 backend, serial writer, receipt formats, bundle ID,
certificate/public key and legacy state directories are preserved. AppDelegate
orchestration, window/model/view responsibilities, ordering models, updater and
login services are split. Policy/bookmark storage now shares synchronized private
replacement. Stale bookmarks are renewed once only after exact-target and
security-scope validation; rejected renewal preserves saved bytes and prior scope.

The application uses the owner-selected self-signed route, with independently
signed Sparkle DMGs. Developer ID/notarization are not acceptance requirements.
Automatic update checks have an explicit Settings toggle and default off;
unattended installation remains disabled. Actual Sparkle delegate paths enforce
interaction guards. Apache-2.0, NOTICE and the full Sparkle license are packaged.
README and recovery/uninstall/distribution guidance replace the development-log
homepage. Website implementation is left to its separate task.

## Earlier Build 108 verification

Environment: Apple silicon, macOS 27.0 build 26A428, Xcode 27.0 build 27A266a,
macOS 27 SDK, explicitly selected developer directory.

| Check | Result |
| --- | --- |
| Debug tests | 649 core + 8 app = 657 passed |
| Ordinary Release tests | 597 core + 8 app = 605 passed |
| Appcast tests | 5 passed |
| AppKit Settings geometry | 80 cases, including update toggle, fit 420 px |
| Debug / ordinary Release app packages | Fixed identity and deep strict signing passed |
| Ad-hoc contributor Debug build | Explicit opt-in passed; release feed disabled |
| Release artifact gate | Identity, arm64, macOS 27 SDK/minimum, entitlements, production key/feed, rpaths, legal files and diagnostic exclusion passed |
| Negative distribution checks | Test flavor, HTTP feed, wrong key, missing NOTICE, altered executable rejected |
| Immutable DMG | Mounted read-only; complete application file hashes match; Applications link valid |
| Sparkle local checks | Cancel/equal/older/unavailable/bad-signature/damaged-package cases passed |
| Sparkle install/relaunch | Actual Build 101→102 replacement and relaunch passed with matching executable/key/requirement |
| Standard Sparkle UI | Actual ApplicationUpdater in a manager-free fixture; version/notes, download, ready and install/relaunch observed; signed Build 102 target verified |
| State preservation | Policy and recovery file hashes unchanged; Sparkle preference keys restored |
| Installed-path access | Build 106 launch/relaunch reports: Device Control and saved bookmark active; complete API/file agreement; no errors |
| Installed app restoration | Original 0.13.0 Build 79 restored with all file contents equal and deep strict signature valid |
| Build 108 installed startup | Management on after initial-policy first Undo; complete package/installed file match; three state files unchanged; Build 107 backup retained |
| Build 107 real-menu-bar acceptance | Owner reports completed acceptance; individual action/target trace not supplied |
| Reachable history / current-content scan | 62 commits, 767 blobs; scanned forbidden paths, keys, tokens and personal absolute paths absent; fsck passed |

The short-lived support process can exit before `open -W` registers its kevent
wait; a fresh complete JSON report and independent restoration checks establish
those access results. No full manager or third-party write ran in these diagnostics.
Full test evidence and raw reports remain ignored under LocalData; the sanitized
contract is [TECH_SPIKE_1.0.0.md](TECH_SPIKE_1.0.0.md).

## Earlier Build 108 artifacts

These retained artifacts are under ignored `LocalData/releases/1.0.0-108/`.
Use the final Build 113 VM package identified above for new acceptance:

- `package/Blenny.app`.
- `Blenny-1.0.0-108.dmg`, 5,807,687 bytes.
- `Blenny-1.0.0-108.dmg.sha256`.
- `Blenny-1.0.0-108.receipt.json`.
- `appcast.xml`, ready for publication review; root feed still advertises no item.

DMG SHA-256:
`94f8dc6265c0394c7e0737d34efe5a0d438b3fa98b24fd312ae3e7d8f70f81c0`.

Executable SHA-256:
`c56b346633135aea08c122898a6f6b2446867fc42c7f69a8910cdb3d5bc48f20`.

The DMG was mounted read-only; complete application file hashes, the Applications
link and deep strict signature pass. Current-source loopback Sparkle scenarios
and all five negative distribution cases pass. The older Build 106 candidate
remains historical evidence and must not be selected for fresh-user testing.

The EdDSA signature and byte length are in the private candidate receipt and
candidate feed. The source receipt identifies HEAD
`fe34d5205f9fc63e4a140bf45cc926312c4c7b7e` plus `sourceDirty: true`.
The candidate includes uncommitted work and must not be represented as a binary
built from that clean commit alone. After authorized source closure, prepare a
fresh final artifact with an unused increasing build number.

## What is still required

[ACCEPTANCE_1.0.0.md](ACCEPTANCE_1.0.0.md) records the owner's Build 107 acceptance
and supplies the fresh macOS 27 VM application list and action/restore sequence.
Fresh first launch, permission revoke/regrant and login/uninstall require their
own results; physical sleep/display cases remain hardware-specific. Standard
update installation/relaunch passed locally. Keyboard-only standard-dialog
dismissal was not established; bounded fixtures exited without installing and
the custom-driver cancellation case remains passed separately.
No real third-party fault injection is claimed. The daily app was preserved and
updated, rather than uninstalled. The Build 108 follow-up preserved the owner's
independently edited README; the subsequent automation work added only the three
GitHub-build/notes lines recorded above.
Known Clock, Now Playing, Gaming/Wine and deferred-sorting limits remain disclosed.

The earlier completion-only audit reported an empty version commit range and
documents that correctly did not claim completion. Auditing is now phase-aware:
preparation may remain uncommitted; pre-trigger requires clean authorized source,
reviewed notes and recorded development acceptance; publication checks the actual
receipt and feed. Do not make an unauthorized commit/tag or invent completion.
The approved RELEASE_AUTOMATION_PLAN_1.0.0.md supersedes the earlier locally built
final-binary/post-build approval path. Finish human acceptance and exact-ref
authorization in development; GitHub then builds and publishes automatically.

## Git and publication receipt

- Remote: `https://github.com/f-is-h/Blenny.git`.
- Branch: `main`; local HEAD `fe34d5205f9fc63e4a140bf45cc926312c4c7b7e`.
- Remote main: `bef1bf306abc37a83b0db3ddd43007bbf04a846f`; local main ahead by 4.
- Local v0.13.0 points to the current baseline; v1.0.0 is absent.
- Remote tags currently stop at v0.12.0. Repository remains private.
- Original first commit preserved: `4a4dbe32d9382efe04769d4e1566d8f5ab695bcf`,
  dated 2026-08-21. No history rewrite, commit, tag or push occurred in this work.
- Website/ and .claude/ parallel files are preserved and excluded from this task's
  intended source boundary. Their inclusion belongs to their own review.

Exact commit/tag IDs and the final asset set must be fixed after authorized Git
closure. Do not push broad refs or publish this dirty-source candidate by default.
Make assets available before the feed advertises them. After separately approved
publication/visibility changes, verify anonymous source, asset/feed access and
an actual hosted check. Website deployment remains separate.
