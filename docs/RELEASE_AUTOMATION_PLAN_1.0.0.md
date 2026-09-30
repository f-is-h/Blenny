# Blenny 1.0.0 versioning and release automation plan

Status: approved design; local implementation/checks and owner development
acceptance complete, except multiple displays. Local source closure is authorized;
hosted setup and execution remain pending.
Owner decisions recorded on 2026-09-30. This records the execution contract;
it is not hosted release evidence. See DISTRIBUTION.md for implemented commands.

On 2026-09-30 the owner additionally selected local 1.0.0 commit/tag closure,
followed by manual Public conversion and then GitHub Actions publication. This
supersedes earlier no-commit/no-tag preparation instructions. It does not authorize
visibility changes or implicit credential export. Public production preflight and
exact-ref authorization remain in place.

## 1. Decisions and precedence

The owner approved the version-display and GitHub automation proposal, with one
explicit revision: all human acceptance belongs to development. Once the formal
release workflow is triggered, it must complete publication without another human
approval, VM test, environment-review gate, or manually published draft release.

The resulting sequence is:

> Develop and test locally -> owner acceptance -> finalize source and release
> documentation -> authorize the exact release trigger -> GitHub builds, signs,
> verifies, publishes assets, updates the feed, and checks public delivery.

Ordinary PR/push CI remains a validation workflow and does not publish releases.
Automatic failures must stop unsafe publication and report the failed step;
"no human gate" does not mean ignoring tests, accepting invalid signatures, or
publishing incomplete artifacts.

This plan supersedes the earlier proposal to download a GitHub candidate, wait
for owner VM acceptance, and then run a separate manually approved publish job.
It also supersedes the requirement to publish the exact locally tested DMG:
development acceptance covers the selected source and release configuration;
the public DMG is independently built on GitHub from that exact source revision.
Do not claim byte identity between local and GitHub builds. Record both toolchains
and receipts, and align configuration, dependencies, signing identity and keys.

Retain these approved choices:

- Public UI displays only the marketing version, such as `Blenny 1.0.0`.
- Every new public binary release increments the marketing version.
- Keep an internal, monotonically increasing `CFBundleVersion`, assigned by CI.
- The first public binary and every later public binary are built on GitHub.
- Keep the current self-signed Blenny identity and its independent Sparkle key.
  Developer ID and notarization are not added as requirements.
- Automate CHANGELOG and user-facing Release Notes preparation and rendering.
- Human review of release content takes place before the release trigger.
- The owner will test first-use authorization, login and uninstall in a fresh
  macOS 27 Parallels VM using a development-stage package. Record sleep/display
  coverage only for the hardware and behavior actually exercised.

Writing this plan does not execute a commit, tag, push, secret export, visibility
change or release. The previous instruction to defer those actions remains in
effect for the current preparation work. Resolve setup and exact-ref publication
authorization before entering the release workflow, never midway through it.

## 2. Start from the current checkout

Read AGENTS.md, PROJECT_BRIEF.md, REPOSITORY_POLICY.md, ROADMAP.md,
TECH_SPIKE_1.0.0.md, IMPLEMENTATION_PLAN_1.0.0.md and this plan. Follow RTK.md.
Recheck the working tree and installed app before editing. Many 1.0.0 files are
already modified or untracked; do not reset, broadly stage or replace them.

Known evidence at handoff, to be revalidated when relevant:

- Build 108 contains the first-Apply and first-Undo/relaunch fixes. Preserve
  PolicyInterfaceStore, sparse restoration scope and strict initial-policy
  missing-backup handling. Do not reimplement the completed product work.
- Latest recorded tests: Debug 649 core + 8 app; Release 597 core + 8 app;
  five appcast tests. Counts are evidence, not permanently hard-coded targets.
- Signed packaging, negative-package rejection, local Sparkle install/relaunch,
  standard update-window installation and product-state preservation passed.
- Standard-dialog keyboard dismissal was not established; do not mark it passed.
- Build 107 physical acceptance was reported by the owner. Fresh-user and
  lifecycle results have not yet been supplied.
- The current Build 108 DMG is a dirty-source local test artifact, not the future
  public GitHub release binary.
- Preserve the owner's latest README. Make only necessary, targeted factual
  updates after inspecting the current text; do not redesign or replace it.
- Website/ and .claude/ are parallel work and are outside this implementation.

Usage4Claude is a read-only reference: inspect its current release/test workflows,
version configuration and release-note generators. Reuse the architecture, not
its identity, keys, Xcode 26.6 selection or assumptions about a sandboxed app.

## 3. Version display and source of truth

1. Keep `Config/Info.plist`'s `CFBundleShortVersionString` as the canonical
   marketing version. Preparation automation updates it; all other versioned
   outputs are derived from or validated against it. Do not introduce several
   independently edited version authorities.
2. Split `BlennyApplicationVersion` into user display and diagnostic identity.
   Windows, Settings/Support display and tooltips show only the marketing version.
   Internal receipts and diagnostics retain the build number and, where useful,
   the source revision. Review `AppDelegate+Ordering.swift` separately so changing
   `.display` does not silently remove useful receipt identification.
3. Preserve positive integer `CFBundleVersion` and integer Sparkle version
   ordering. The first production CI number must exceed relevant existing
   installed/published numbers, including 108. Do not reset it to 1 or `1.0.0`.
4. Use a documented release-workflow CI sequence with a fixed migration offset,
   and validate it against published history. Handle reruns deliberately:
   reuse an already sealed artifact or allocate a newer unpublished build;
   never overwrite a published version with different bytes. Workflow renames
   or counter resets must not silently make builds decrease.
5. Public assets use `Blenny-X.Y.Z.dmg` and matching checksum/receipt names.
   Internal Actions artifact names may include the run/attempt for uniqueness.
6. Generalize hard-coded 1.0.0 paths, filenames, release URLs and note extraction
   in prepare-release.sh, prepare-sparkle-update.sh and related tests/docs.
   Local development counters must not allocate public release numbers.
7. Keep development/test flavors distinguishable in internal metadata. Continue
   rejecting diagnostic, trial, ad-hoc and loopback builds from distribution.

Acceptance: normal UI contains no `(Build N)`; diagnostics remain traceable;
version ordering works from the development predecessor through later public
versions; duplicate or decreasing published versions are rejected.

## 4. CHANGELOG and Release Notes automation

Use small structured change fragments as the shared input. Each meaningful
change records category, concise technical summary, optional user-facing summary
and references. Internal-only changes need no user-facing summary.

During development, Codex drafts the fragment from the actual diff and verified
behavior. Document this step in repository guidance so it is part of implementing
a change, rather than a separate writing task left until release day. CI validates
fragments and allows an explicit rationale for changes needing no release entry.
Do not add a paid model service or extra API credential just to render documents.

The preparation workflow or equivalent local preparation command must:

1. Collect changes since the previous public release, including direct commits
   as well as merged PRs; reconcile them with fragments and flag omissions.
2. Generate versioned `CHANGELOG.md` entries covering engineering and user changes.
3. Generate the matching `docs/RELEASE_NOTES.md` section containing user-visible
   behavior, relevant known limitations and installation implications.
4. Produce a reviewable release-preparation PR when remote preparation is
   authorized. Provide the same deterministic generator locally for the initial
   uncommitted checkout. Do not require GitHub access just to preview its output.
5. Deduplicate related changes, omit empty sections, preserve previous releases,
   and verify referenced contributions before attributing them. Keep tracked
   content in English. For 1.0.0, describe the complete first public product,
   not merely the delta from the private 0.13.0 engineering milestone.
6. Extract the exact same user-facing version section for GitHub Release and
   Sparkle. Do not auto-generate different prose at publication time.

GitHub's generated PR/contributor notes may supply source material, but they are
not sufficient for complete technical history or user-facing prose. All content
review and correction must finish before the release trigger.

Acceptance: one fragment set deterministically generates both documents;
missing version sections, malformed fragments, stale generated outputs and
version mismatches fail checks. Untrusted fragment/PR text is data, never shell
source. Tests cover XML/Markdown escaping and repeatable generation.

## 5. Workflows

Implement three workflows, sharing existing scripts instead of duplicating them.

### ci.yml: ordinary development validation

- Run on relevant PRs and source pushes; never publish or access signing secrets.
- Use a GitHub-hosted ARM64 environment actually running macOS 27 with Xcode 27
  and its macOS 27 SDK. The official catalog listed `xcode-27` at planning time;
  verify current availability, explicitly select the agreed Xcode version and
  assert the actual OS/SDK/architecture. Do not use `macos-latest` implicitly.
- Run Debug and ordinary Release tests/builds, appcast/generator tests, version
  consistency checks and relevant formatting/static workflow checks.
- Pin action implementations to reviewed commit SHAs and dependencies to the
  existing resolved versions. Cache keys must include configuration/toolchain.
- Prove AppKit test feasibility in the initial runner smoke test. Do not silently
  delete tests or switch to an unsupported OS to obtain a green workflow.
- Retain useful failure logs without secrets or private local evidence.

### release-prepare.yml: pre-release development work

- Explicitly select the intended marketing version and generate the release PR
  described above. It does not tag, sign, publish or update the production feed.
- Local preparation remains possible before the first authorized repository push.
- Merge/review decisions and the owner's local/VM acceptance happen at this stage.

### release.yml: unattended publication

Prefer an authorized push of an annotated `vX.Y.Z` tag as the single production
trigger. On 2026-10-01 the owner also authorized adding a manual production entry
for an existing annotated version tag, and specified that CI-only repairs do not
require a marketing-version increase. Manual dispatch is restricted to reviewed
main, requires an explicit tag for publication and uses the same gates and sealed
transaction as the automatic path. Verification and signing-diagnostic operations
remain non-publishing. Do not publish
on an arbitrary main push, README edit or commit-message keyword.

Check out the immutable workflow/controller revision and the selected immutable
application source in separate directories. Build and audit the exact tag source
without editing its tracked files. A tooling repair can run from a later reviewed
main commit while preserving `1.0.0`, its source tag, accepted product digest and
reviewed notes. Record both the application `sourceCommit` and the signing
`workflowCommit` in the sealed receipt. Never retarget a public tag or replace
published assets. A signing-diagnostic dispatch reports certificate fingerprint
and private-key/validity checks before and after temporary hosted trust; it does
not build, publish or update the feed.

Execute the following without a human checkpoint between steps:

1. Resolve the tag to an immutable commit. Verify annotation, expected repository,
   permitted main-branch ancestry, marketing version, prepared notes and recorded
   development acceptance for that source/configuration. Reject unauthorized
   tag replacement and stale/non-increasing release versions.
2. Run automated tests and release checks on that exact checkout. Development
   acceptance must already be recorded; do not request new owner testing here.
3. Allocate the internal build, compile ordinary Release on GitHub, sign nested
   components and the app with the pinned Blenny identity, and create the DMG.
4. Verify the existing distribution gates, mounted app contents and required
   resources; generate SHA-256, EdDSA signature, byte length and provenance receipt.
   Include source SHA, tag, version/build, workflow run/attempt and OS/Xcode/SDK.
5. Seal and transfer the artifact between jobs. Never rebuild or mutate it during
   publication. Restrict signing credentials to the job that needs them.
6. Create a draft release only as an automatic upload transaction if useful,
   upload the complete asset set, verify it, and publish it in the same workflow.
   No owner action is needed to publish that draft.
7. Confirm anonymous access to the published asset and verify the downloaded
   bytes against the receipt before advertising it in the update feed.
8. Publish the generated appcast item, preserving existing feed history and
   unrelated main-branch changes. Its version, URL, length, signature and notes
   must refer to the already published artifact.
9. Verify anonymous HTTPS feed access, item metadata and asset consistency.
   Use an isolated hosted update check where the runner supports it; explicitly
   distinguish delivery verification from a real installation/relaunch test.
10. Emit one final release receipt and success/failure summary with public URLs.

There must be no required environment reviewer, second manual publish workflow,
post-build owner VM checklist or approval prompt in this release path. Once the
owner authorizes the exact tag trigger, that authorization covers the automatic
asset/feed publication described here for that tag.

## 6. Signing, repository setup and partial failures

Complete all setup in development, before the first production trigger:

- Destination: `https://github.com/f-is-h/Blenny.git`, main, annotated `vX.Y.Z`
  release tags; first intended public release is `v1.0.0`.
- Inventory required permissions and branch/tag rules. Ensure the narrowly scoped
  appcast update can complete automatically without a mandatory manual merge.
  Do not broadly disable repository protection or use force push to work around it.
- Resolve first-release repository visibility and anonymous-download availability
  with the owner before triggering publication. This plan does not authorize an
  unannounced visibility change or a new broad administration credential.
- Configure Blenny-specific code-signing certificate/password and Sparkle secret
  through a controlled owner-approved transfer. Do not read/export existing keys
  merely because the workflow needs placeholders. Never reuse Usage4Claude keys.
- Import secrets only into a temporary CI keychain; verify the expected certificate
  fingerprint and Sparkle public key. Clean up even after failure. No keys in logs,
  caches, artifacts, receipts, source, or third-party PR jobs.
- Use minimum per-job token permissions. Never run untrusted PR code with release
  credentials. Freeze and review workflow code before making secrets available.
- Serialize production publishing across the repository, not separately by tag.
  Recheck release/feed ordering after acquiring publication ownership.
- Make reruns idempotent: reuse and verify an existing sealed matching artifact.
  A published version with conflicting bytes is an error, never an overwrite.
- If assets are published but feed publication fails, report that precise state.
  A bounded recovery rerun must reuse the existing assets. Do not rebuild the same
  public version, roll back an unrelated commit or advertise an incomplete upload.
- Failures terminate and notify; they do not wait indefinitely for manual approval
  or retry without a bound. Fix the failure in development before a new run.

## 7. Development acceptance and execution order

Implement in this order:

1. Rebaseline and inspect the current checkout; prepare a narrow implementation
   inventory that preserves completed fixes and parallel work.
2. Implement version display/diagnostics and parameterized packaging; add focused
   version and compatibility tests.
3. Implement change-fragment validation and deterministic document generation;
   generate reviewable 1.0.0 notes locally.
4. Implement normal CI and verify the actual macOS 27 runner/toolchain before
   depending on it for publication. Initial remote setup requires the existing
   exact push/credential authorization to be resolved at this stage.
5. Implement the single unattended release workflow and exercise verification-only
   paths, signatures, bad-package rejection, idempotency and partial-failure cases.
6. Produce a new local ordinary Release package with the final display/packaging
   changes for the owner's development-stage VM testing. This is expected and
   does not violate the requirement that all public binaries be built on GitHub.
7. Record owner results for fresh installation/authorization, first Apply/Undo and
   relaunch, login, permission lifecycle and uninstall. Record hardware-dependent
   sleep/display limits accurately. Continue independent implementation while
   waiting for results; never convert pending checks into successful evidence.
8. Finish the local release audit, source/notes review and signing/repository setup.
   Freeze the source to be released. Material product, signing, packaging or
   dependency changes after acceptance require relevant checks before triggering
   publication; do not move those checks behind the GitHub build.
9. Present the exact source SHA, remote, main ref and annotated tag for the
   pre-trigger publication decision. Preserve the earlier no-commit/no-tag request
   until the owner explicitly authorizes the required Git operations.
10. After authorization, the tag trigger runs the full release automatically.
    Report its final verified result; no post-build owner approval is introduced.

## 8. Documentation and release-skill alignment

Update active sections of PROJECT_BRIEF, ROADMAP, REPOSITORY_POLICY,
TECH_SPIKE_1.0.0, DISTRIBUTION, ACCEPTANCE_1.0.0 and release guidance to point to
this lifecycle. Preserve historical Build 106/107/108 results as dated evidence.
Update the repository release skill so exact-ref authorization happens before
the automatic trigger, not after a GitHub candidate build.

Make release auditing phase-aware. The current completion-only checks must not
force documents to claim a published milestone before publication, or force an
unauthorized commit during preparation. Keep source cleanliness, privacy,
restoration, version consistency and accurate completion evidence mandatory.

Expected files include ApplicationVersion.swift and its consumers, existing build/
package/appcast scripts and tests, the three workflows, fragment schema/generator,
CHANGELOG.md, versioned RELEASE_NOTES.md and focused documentation/skill updates.
Avoid unrelated product features, backend changes or README redesign.

Sol's handoff must state: implemented files and behavior; tests actually run;
local versus hosted workflow evidence; owner acceptance still missing; setup or
authorization still needed before the trigger; exact public release result if an
authorized release has run. Do not claim a locally validated YAML file proves a
successful GitHub run.

## References

- [GitHub runner image catalog](https://github.com/actions/runner-images/blob/main/README.md)
- [Sparkle version comparison](https://sparkle-project.org/documentation/api-reference/Classes/SUStandardVersionComparator.html)
- [GitHub generated release notes](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes)
- [Current acceptance evidence](ACCEPTANCE_1.0.0.md)
- [Earlier implementation scope](IMPLEMENTATION_PLAN_1.0.0.md)
