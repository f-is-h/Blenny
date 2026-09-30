---
name: blenny-release
description: Audit and prepare a Blenny version for its authorized annotated-tag release, including source/history privacy, development acceptance, generated notes, signing setup and exact refs. Use when the owner asks to audit, close, tag, release or push a Blenny version. For 1.0.0 and later, GitHub builds and publishes automatically after pre-trigger authorization. Do not use for ordinary feature implementation.
---

# Blenny Release

Prepare and close one Blenny version without weakening safety, privacy or history.
Read `docs/RELEASE_AUTOMATION_PLAN_1.0.0.md` and `docs/DISTRIBUTION.md` for the
approved 1.0.0-and-later lifecycle. All human acceptance and setup precede the
formal release trigger. Do not add a post-build owner check or manual publish gate.

## Establish the release boundary

1. Read the repository-root `AGENTS.md`, `PROJECT_BRIEF.md`, `docs/REPOSITORY_POLICY.md`, `docs/ROADMAP.md`, `docs/COMMIT_MESSAGE_GUIDELINES.md`, and the technical-spike document for the version.
2. Resolve the version, previous version tag, current branch, `HEAD`, configured remote, existing local tags, and remote refs. Never assume that an existing tag points to `HEAD`.
3. Inspect the complete version range and working tree before editing. Record the commits, changed paths, and any changes unrelated to the version.
4. Do not push or change repository visibility during the audit.

## Audit the version

Run `scripts/release_audit.sh` from this skill directory with the version and
previous public tag (or the recorded first-public engineering base commit).
Use `--phase prepare --allow-dirty` while preparing; this permits an uncommitted
candidate without requiring a false completion claim. Preserve an explicit
no-commit/no-tag instruction. Use `--phase pre-trigger` on the clean authorized
source after development acceptance and source closure. Use `--phase published`
to reconcile the later public receipt and feed with the release source tag.

Also perform checks that require judgment:

- Confirm every roadmap exit criterion has direct test, runtime, or user-observed evidence. State which experiments were real and which were dry-run.
- Confirm every real system mutation ended in verified restoration and no validation process remains active.
- Review the entire reachable history, not just `HEAD`, for personal data, signing material, raw diagnostics, generated binaries, copied third-party code, and unsafe research artifacts.
- Review commit metadata and messages. Use English Conventional Commit subjects and no AI attribution or generated-by trailers.
- Confirm unsupported code is isolated and gated, all writes use one serial writer, failure is bounded, and Release builds exclude Debug-only diagnostics and abandoned runtime trials; accepted macOS 27 product capabilities remain enabled in both configurations.
- Run Xcode 27 Debug and Release tests and app builds. Verify the deployment target, SDK, architecture, version, signatures, and the absence of diagnostic/test entry points from Release output; verify accepted backend capabilities remain present.
- Run the fragment/generator, publication-transaction and workflow checks. Verify
  `docs/release-acceptance.json` covers the current product/configuration digest
  and reviewed version notes. Record missing observations, never infer a pass.
- Check hosted runner feasibility, signing-secret setup, repository visibility,
  branch/tag protections and the automatic feed write before the first production
  trigger. A locally linted workflow is not hosted execution evidence.

Treat a passing script as necessary but not sufficient. Stop on missing evidence, failed tests, unrestored state, unexpected remote refs, a divergent tag, or a privacy finding.

## Organize without falsifying history

- Keep the original first commit and genuine history beginning on 2026-08-21.
- Do not rewrite any shared history.
- Before the first push, reorganize later private commits only when the owner explicitly authorizes history rewriting. Otherwise use focused forward commits.
- Never change authorship, timestamps, or experimental claims to make a release look cleaner.
- Keep tracked public material in English. Distill any owner-only decision needed for maintenance or recovery from ignored `LocalNotes/` into tracked English documentation.

## Align and tag

Before tagging, align the current status in `PROJECT_BRIEF.md`, `README.md`,
`docs/ROADMAP.md`, the technical spike, `Config/Info.plist`, generated notes and
the acceptance record. Preparation documents must not claim publication.
`docs/public-release.json`, written automatically with the feed, records actual
publication. Every public binary is a clean GitHub build of the annotated source.

- Use annotated tags named `vX.Y.Z`.
- If the tag is absent, create it only when tagging is authorized and all
  pre-trigger checks pass. A completion statement does not override a no-tag request.
- If the tag already exists and points to the audited `HEAD`, preserve it.
- If an unpushed local tag points to an earlier commit, report the exact mismatch and obtain explicit confirmation before replacing it.
- Never overwrite a remote tag.

## Pre-trigger authorization and automatic publication

Present a concrete pre-trigger receipt containing:

- exact remote URL;
- exact branch and commit;
- exact annotated tag and peeled commit;
- test/build totals;
- privacy and history audit result;
- restoration result;
- whether the remote is empty or already contains refs;
- exact push command that will be run.
- the workflow that will automatically build, sign, verify, publish assets, update
  the feed and verify anonymous delivery for this tag;
- verified hosted setup, development acceptance and source/notes review;
- any separately authorized visibility or credential-transfer action.

Obtain exact-ref authorization before the trigger unless already explicitly
provided for these exact refs. A statement that a version is complete is not push
authorization. Do all authorized local preparation before requesting this decision.

Push only the named branch and named tag. Never use `--mirror`, `--all`, `--tags`, or force push for a normal release. Verify the remote branch and tag immediately afterward and report their object IDs.

For a tooling-only repair after a failed trigger, preserve the application version
and existing public tag. Review and authorize the forward controller commit on
main. Use release.yml's `signing-diagnostics` operation first when signing remains
unexplained; it does not build or publish. For manual production, select `publish`
and the exact existing annotated `release_tag`. The workflow checks out controller
and source separately and records both commits. This manual entry shares all
production gates and never creates or moves a tag. It may retry an unpublished
version; after publication, reuse sealed bytes and reject conflicts.

Then observe `.github/workflows/release.yml` through completion. Do not ask for
another approval, post-build VM test or draft-publication action. The tag approval
covers its automatic publication transaction. On failure, report whether assets
are public, whether the feed is updated and the bounded recovery path. Reuse sealed
bytes; never overwrite a published version. Distinguish hosted information checks,
manager-free install/relaunch fixtures and actual owner-operated menu-bar tests.
