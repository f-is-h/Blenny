# Building and distributing Blenny

## Approved lifecycle

Develop and test locally, complete owner acceptance, review source and generated
notes, resolve hosted setup, then authorize the exact main commit and annotated
version tag. The tag triggers `.github/workflows/release.yml`, which builds,
signs, verifies, publishes assets, updates the feed and checks delivery without
another human checkpoint. Do not add a post-build VM test, required environment
reviewer or manually published draft. Automatic checks still fail closed.

Every public binary, beginning with 1.0.0, is built on GitHub from the exact
annotated tag. Local packages are development acceptance artifacts; their bytes
are not claimed to equal a later hosted build. No workflow changes repository
visibility, exports owner keys or authorizes its own trigger. See the approved
[execution contract](RELEASE_AUTOMATION_PLAN_1.0.0.md).

## Source commit and release are separate actions

A source commit reviews the candidate, validates tests and generated notes, then
records only authorized source changes. It does not authorize a tag, push,
repository visibility change, credential transfer or publication. Website remains
outside the current owner-approved application commit boundary.

Blenny Release covers pre-trigger acceptance and hosted setup, exact-ref
authorization, the annotated-tag trigger, and monitoring the automatic GitHub
publication transaction through delivery verification. A commit-only helper
should be called Blenny Commit and must stop at its authorized commit boundary;
renaming the release workflow to Commit would hide its publication scope.

For later releases: develop with change fragments; review and commit source;
run the preparation workflow to propose the version/notes PR; complete acceptance
and normal CI on the merged candidate; audit the exact main commit and annotated
tag; authorize and push those exact refs; monitor release.yml through signed asset,
feed and Sparkle delivery checks. The first 1.0.0 additionally needs repository
visibility, signing-secret configuration and hosted verification resolved first.

### Initial 1.0.0 closure and visibility sequence

The owner authorized local source commit/tag closure first, will switch the
repository to Public manually, and requested Actions publication afterward. A
local tag runs no workflow. Preserve the public-production preflight; do not push
the version tag while private. After visibility/setup and exact-ref authorization,
push the reviewed main commit, prove normal CI and verification-only release
execution, then push the exact annotated tag for unattended publication.
Signing-secret transfer remains separately controlled.

## Identity and versions

- Bundle ID: `xyz.fi5h.blenny`; arm64; macOS 27 only.
- Pinned code-signing certificate: `Config/SigningIdentity.sha1`.
- Sparkle: exact version 2.10.0; pinned public Ed25519 key in Config/Info.plist.
- Feed: `https://raw.githubusercontent.com/f-is-h/Blenny/main/appcast.xml`.
- Assets: `https://github.com/f-is-h/Blenny/releases/download/vX.Y.Z/Blenny-X.Y.Z.dmg`.
- Config/Info.plist is the canonical marketing-version source. Public UI shows
  only that version; recovery diagnostics retain the integer build.

CI allocates `CFBundleVersion = 1000 + github.run_number * 100 + github.run_attempt`
for the stable `release.yml` workflow. Attempts 1–99 have reserved slots; a new
run advances beyond all attempts of the previous run. The migration predecessor
is development Build 108; the first CI build is at least 1101. Allocation also
checks published feed/history receipts, including assets published before a failed
feed commit. A reset, workflow rename or slot exhaustion fails and needs an
explicit pre-trigger offset migration. Local development counters never select
public build numbers. Every new public binary increments X.Y.Z as well.

Code signing establishes integrity and continuity; Sparkle authenticates the
archive. Neither implies Apple notarization or default Gatekeeper trust. Keep the
selected self-signed identity and independent Blenny update key. Do not borrow
Usage4Claude credentials or disable system protection.

The hosted signing wrapper compares the imported public certificate's SHA-1
fingerprint with the pin and requires its matching private-key identity. It then
signs an isolated disposable executable with that exact identity and verifies the
signature against an explicit certificate-root requirement. A system-trust
`find-identity -v` listing is diagnostic only: it must not reject an otherwise
usable self-signed identity before actual signing. No administrator trust or
authorization settings are modified. The wrapper restores the original user
keychain search/default state and deletes its temporary keychain. Each cleanup
command has a 20-second process timeout and a named progress marker; any failed
cleanup fails the job and is recorded in the diagnostic receipt. These operations
are confined to the ephemeral GitHub runner. Apple's
[TN2206](https://developer.apple.com/library/archive/technotes/tn2206/) documents
self-signed identities and explicit designated requirements; ordinary requirement
verification does not consult system trust unless it requests a trusted anchor.

An existing public source tag remains immutable after a failed workflow. Changes
to release tooling can be reviewed as forward commits on main without changing
the application version. Manual dispatch selects the existing annotated source
tag and checks out its exact commit separately from the release controller. The
app, its build scripts, notes, product digest and acceptance come from that clean
tag checkout; the temporary signing wrapper and publication controller come from
the immutable workflow revision. The sealed receipt records both `sourceCommit`
and `workflowCommit`. Rerunning the original failed tag event still runs its old
workflow; use a reviewed main dispatch to apply a tooling repair.

## Development commands and notes

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer zsh scripts/verify-local.sh
python3 scripts/release_tools.py render
python3 scripts/release_tools.py check
python3 scripts/release_tools.py coverage
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer zsh scripts/prepare-release.sh "$BUILD_NUMBER"
```

Set BUILD_NUMBER to an unused integer build and use a fresh output directory. Output defaults to
ignored `LocalData/releases/X.Y.Z-BUILD/`: signed `package/Blenny.app`,
`Blenny-X.Y.Z.dmg`, `.dmg.sha256`, `.receipt.json`, `release-notes.md` and a
candidate appcast. The checksum contains a portable basename. The receipt records
source SHA/dirty state, product digest, build origin, toolchain, archive length,
SHA-256 and EdDSA signature. Local dirty-source packages cannot pass the public
provenance gate. Existing archives are immutable.

The package gate checks nested/pinned signatures, required resources, entitlement,
architecture, minimum OS/SDK, relative framework paths, key/feed and diagnostic
exclusion. It mounts the DMG read-only, verifies every app file/link against the
signed source and detaches. Independent OpenSSL 3 verification uses the tracked
Sparkle public key. Diagnostic, trial, ad-hoc and loopback packages are rejected.

Change fragments in docs/changes provide engineering and optional user summaries.
Release records in docs/releases provide the date and previous public tag. Codex
drafts fragments during development from the real diff and verification. Preparation
assigns unreleased fragments, reconciles verified commit references and renders
CHANGELOG.md and docs/RELEASE_NOTES.md deterministically. Missing contributions,
stale output, malformed fragments and mismatched versions fail. A no-entry commit
requires `Release-Note: none (reason)`. No model-service credential is required.
GitHub and Sparkle extract the same reviewed version section. Initial 1.0.0 covers
the entire first public product, including its requirements and accepted limits.

## Pre-trigger setup and acceptance

Record actual owner observations in docs/release-acceptance.json. Only after
those observations, set the current `productDigest` from `release_tools.py
fingerprint` and `reviewedReleaseNotesSHA256` from the reviewed version section.
Required observations cover real menu bar behavior, first install/permissions,
first Apply/Undo/relaunch, login, uninstall and restoration. Sleep/display entries
must record exercised behavior or explicit hardware/guest limits. A stale product
digest or changed notes invalidate the receipt. Never fill pending rows from
deterministic tests alone. All these checks precede the formal tag trigger.

Before first hosted publication:

1. Authorize source closure and exact refs for `https://github.com/f-is-h/Blenny.git`,
   main and the annotated version tag. Preserve the original first commit and
   genuine history; audit every reachable ref and current candidate for privacy.
2. Resolve public visibility and anonymous delivery separately. Publication
   preflight rejects a private repository. Do not infer a visibility permission.
3. Use a controlled owner-approved transfer to configure repository secrets:
   `BLENNY_CERTIFICATE_P12_BASE64`, `BLENNY_CERTIFICATE_PASSWORD` and
   `BLENNY_SPARKLE_PRIVATE_KEY`. Their values must match Blenny's existing identities.
   Do not export or regenerate local keys implicitly. Only the signing step sees
   them, imports into a temporary CI keychain and removes it on success/failure.
4. Permit the preparation workflow to create its PR, and the publisher's scoped
   feed commit to main without a mandatory manual merge. Review actual branch/tag
   protections; do not broadly disable protections. Default tokens remain read-only;
   jobs request only their required permissions. No release job has a required
   environment reviewer.
5. Push reviewed workflow/source only when authorized, and run normal CI plus a
   verification-only release dispatch on main. Prove AppKit test and Sparkle fixture
   feasibility on the actual `xcode-27` ARM64 image. Runtime assertions require
   macOS 27, Xcode 27.0 and SDK 27.0. Never substitute macOS 26 to get a green run.
6. Complete the clean pre-trigger audit and exact-ref authorization before pushing
   the formal tag. Remote private engineering v0.13.0 is not required: first-release
   auditing uses its recorded commit SHA, reachable through main.

As inspected on 2026-09-30, the repository is private, main is unprotected, Actions
is enabled with a read-only default token and no signing secrets are configured.
The Actions create/approve-PR setting is false. Ruleset inspection returns a plan/
visibility-related 403; do not claim there are no rulesets. No setup was changed.
These observations require refresh after owner-authorized configuration.

## Workflow responsibilities and failure recovery

`ci.yml` tests Debug/ordinary Release and checks notes, fragments and workflows
on source pushes/PRs. It has no signing secrets or publication permissions.
`release-prepare.yml` is manually selected on main and creates a version-preparation
PR and explicitly dispatches unsigned CI because token-created PR events do not
start normal CI. Its Actions write permission is for that dispatch; it has no
signing secrets. It never tags, signs or publishes. The equivalent preparation command works
locally before the initial authorized push.

`release.yml` accepts an annotated version-tag push or an explicit publication
dispatch on reviewed main. Both check the selected clean source, tag annotation,
remote tag object, main ancestry, reviewed notes and development acceptance, and
use the same sealed publication transaction. All action code and
the actionlint archive are checksum/SHA pinned. Production runs serialize across
the whole repository. Signing does not occur on PRs or arbitrary branches.

The manual Actions form has three operations:

- `verification` (default): test, sign and verify; no public release or feed write.
- `signing-diagnostics`: compare the imported certificate fingerprint and report
  whether its matching private-key identity can actually sign and verify a
  disposable executable against the fixed certificate-root requirement. It does not build an application or publish.
- `publish`: requires an existing annotated `release_tag`, such as `v1.0.0`.
  It tests and builds that exact tag source, then publishes automatically.

Select main for manual execution. `release_tag` may also be supplied for the two
non-publishing operations to inspect or verify that same frozen application
source. Inputs are validated as data; the workflow never creates or moves a tag.
Before the first successful publication, tooling-only repairs can retry the same
marketing version. After publication, recovery must reuse the existing sealed
bytes; conflicting bytes for a public version remain an error. Functional source
changes require a new reviewed source tag and marketing version.

The hosted signing job runs a separate manager-free Sparkle fixture covering
cancel, equal/older versions, unavailable feed, wrong signature, damaged archive,
installation/relaunch and state preservation. It then builds and verifies the
ordinary Release DMG. Test flavors are never uploaded or advertised. The sealed
DMG/checksum/receipt/notes transfer to publication unchanged. A rerun recovers a
matching existing release or same-run Actions artifact. Release lookup falls back
from the published-tag endpoint to the authenticated, paginated release list so
an existing draft is recognized. An empty unpublished draft may resume with a
newer internal build; it contains no sealed asset bytes to preserve. A partial draft resumes
only from its sealed bytes. Expired/missing seals or conflicting bytes fail;
published assets are never overwritten.

The publication job uploads all assets, verifies the draft automatically and
compares every downloaded file with the selected sealed bytes before publishing,
then checks anonymous downloaded bytes before adding the feed item. It writes only
appcast.xml and docs/public-release.json on fresh origin/main, preserving unrelated
changes. A concurrent main advance fails safely; a rerun starts from fresh main
and reuses the published bytes. If assets are public but feed publication fails,
report that partial state. Do not rebuild the same version or roll back other work.

After immutable and canonical HTTPS feed checks, a fresh Mac job downloads the
public archive and runs Sparkle's information check without launching Blenny's
manager or installing anything. This checks actual Sparkle feed parsing/version
selection; installation/relaunch evidence belongs to the separate local/hosted
fixture. Final Actions receipts distinguish them. No owner decision is inserted
between these steps. A hosted failure stops and reports the failed step.

## Local Sparkle fixture

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
BLENNY_BUILD_ROOT=LocalData/sparkle-fixture/template \
BLENNY_SWIFT_SCRATCH_PATH=LocalData/sparkle-fixture/swift BLENNY_BUILD_NUMBER=101 \
BLENNY_UPDATE_TEST=YES BLENNY_UPDATE_FEED_URL=http://127.0.0.1:8765/appcast.xml \
zsh scripts/build-app.sh release
python3 scripts/test-sparkle-local.py LocalData/sparkle-fixture/template/Blenny.app \
  LocalData/sparkle-fixture/run
```

Run with the normal app quit, a fresh output directory and port 8765 available.
The fixture never starts management, compares app-owned policy/recovery hashes
and restores Sparkle preferences. No third-party menu-bar mutation or public
delivery is established by this loopback check. Standard update UI and physical
menu-bar acceptance remain separately recorded development evidence.

## GitHub Sponsors attribution

Use the Usage4Claude metadata schema, with project fixed to blenny. Retain the
existing entry-point design and both Support buttons. Only the status-menu entry
changes its default to one-time; explicit Support frequencies and the website's
existing default remain unchanged. Metadata persists when users choose another
frequency or tier on GitHub; Blenny does not collect payment data.

| Entry | metadata_source | metadata_placement | metadata_lang |
| --- | --- | --- | --- |
| Status menu | app | menu | Omitted |
| Support, one-time | app | about | Omitted |
| Support, monthly | app | about | Omitted |
| English README | readme | badge | en |
| Local website menu | website | menu | en |
| Local website support footer | website | footer | en |

The owner requested README support links. Its GitHub Sponsors entry uses
source=readme, placement=badge and language=en, with a one-time default. The
owner-only Chinese preview uses language=zh-cn. Ko-fi uses the existing Blenny
destination. No FUNDING.yml exists in this candidate; creating or redesigning the
native repository Sponsor button is outside this link update.

Parameter order is frequency (when present), metadata_project, metadata_source,
metadata_placement, metadata_lang (documents/web only). Swift literals use bare
ampersands; HTML attributes use `&amp;`. Keep every metadata key/value within ASCII
letters, digits, dashes and underscores, with no spaces. Use at most ten metadata
pairs, keys up to 25 characters and values up to 100 characters. Invalid characters
can make the page return 404; exceeding documented limits can truncate metadata.
Validate actual links after changes. See [GitHub's metadata requirements](https://docs.github.com/en/sponsors/receiving-sponsorships-through-github-sponsors/viewing-your-sponsors-and-sponsorships#tracking-where-sponsorships-come-from).

Website link edits remain local and excluded from the owner's release commit;
they do not authorize website publication or deployment.
