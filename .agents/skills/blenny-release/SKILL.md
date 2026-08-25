---
name: blenny-release
description: Audit and close a completed Blenny version by reviewing its diff and reachable Git history, running release checks, aligning version documentation, verifying or creating an annotated tag, and pushing only after explicit confirmation. Use when the user says a Blenny version is complete or asks to audit, organize, tag, release, or push a Blenny version. Do not use for ordinary feature implementation.
---

# Blenny Release

Close one Blenny version without weakening its safety, privacy, or history guarantees.

## Establish the release boundary

1. Read the repository-root `AGENTS.md`, `PROJECT_BRIEF.md`, `docs/REPOSITORY_POLICY.md`, `docs/ROADMAP.md`, `docs/COMMIT_MESSAGE_GUIDELINES.md`, and the technical-spike document for the version.
2. Resolve the version, previous version tag, current branch, `HEAD`, configured remote, existing local tags, and remote refs. Never assume that an existing tag points to `HEAD`.
3. Inspect the complete version range and working tree before editing. Record the commits, changed paths, and any changes unrelated to the version.
4. Do not push or change repository visibility during the audit.

## Audit the version

Run `scripts/release_audit.sh` from this skill directory with the version and previous tag. Run it first with `--allow-dirty` while preparing the release and again without that option after the release-preparation commit.

Also perform checks that require judgment:

- Confirm every roadmap exit criterion has direct test, runtime, or user-observed evidence. State which experiments were real and which were dry-run.
- Confirm every real system mutation ended in verified restoration and no validation process remains active.
- Review the entire reachable history, not just `HEAD`, for personal data, signing material, raw diagnostics, generated binaries, copied third-party code, and unsafe research artifacts.
- Review commit metadata and messages. Use English Conventional Commit subjects and no AI attribution or generated-by trailers.
- Confirm unsupported code is isolated and gated, all writes use one serial writer, failure is bounded, and Release builds exclude Debug-only private runtime surfaces.
- Run Xcode 27 Debug and Release tests and app builds. Verify the deployment target, SDK, architecture, version, signatures, and the absence of Debug/private strings from Release output when the milestone depends on that boundary.

Treat a passing script as necessary but not sufficient. Stop on missing evidence, failed tests, unrestored state, unexpected remote refs, a divergent tag, or a privacy finding.

## Organize without falsifying history

- Keep the original first commit and genuine history beginning on 2026-08-21.
- Do not rewrite any shared history.
- Before the first push, reorganize later private commits only when the owner explicitly authorizes history rewriting. Otherwise use focused forward commits.
- Never change authorship, timestamps, or experimental claims to make a release look cleaner.
- Keep tracked public material in English. Distill any owner-only decision needed for maintenance or recovery from ignored `LocalNotes/` into tracked English documentation.

## Align and tag

Before tagging, make `PROJECT_BRIEF.md`, `README.md`, `docs/ROADMAP.md`, the version's technical-spike document, and `Config/Info.plist` agree about the version and status.

- Use annotated tags named `vX.Y.Z`.
- If the tag is absent and the user asked to close the version, create it only after all checks pass.
- If the tag already exists and points to the audited `HEAD`, preserve it.
- If an unpushed local tag points to an earlier commit, report the exact mismatch and obtain explicit confirmation before replacing it.
- Never overwrite a remote tag.

## Confirmation and push

Present a final pre-push receipt containing:

- exact remote URL;
- exact branch and commit;
- exact annotated tag and peeled commit;
- test/build totals;
- privacy and history audit result;
- restoration result;
- whether the remote is empty or already contains refs;
- exact push command that will be run.

Obtain explicit user confirmation after presenting that receipt. A prior statement that a version is complete is not push authorization.

Push only the named branch and named tag. Never use `--mirror`, `--all`, `--tags`, or force push for a normal release. Verify the remote branch and tag immediately afterward and report their object IDs.
