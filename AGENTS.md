# Blenny repository instructions

These rules apply to every task in this repository.

## Required context

- Read `PROJECT_BRIEF.md`, `docs/REPOSITORY_POLICY.md`, and `docs/ROADMAP.md` before changing product behavior, architecture, release state, or Git history.
- Read the technical-spike document for the version being changed.
- Treat the product decisions and safety boundaries in those documents as constraints, not suggestions.

## Product and system safety

- Support macOS 27 only. Do not add macOS 26 fallbacks.
- Keep AppKit in charge of status items, windows, and Accessibility infrastructure.
- Do not copy non-trivial Ice or Thaw implementation code or link their binaries.
- Never move the pointer, synthesize clicks or Command-drag, inject into `MenuBarAgent`, disable SIP, request private entitlements, or require Screen Recording for the baseline product.
- Do not add continuous polling, automatic reconciliation loops, or unbounded retries. A failed system write may be verified once and retried at most once.
- Isolate unsupported macOS behavior in the macOS 27 backend, keep experiments Debug-only until deliberately promoted, and fail closed when a private runtime contract differs.
- Route all system mutation through one serial writer. Read, snapshot, and implement restoration before a new mutation path is exercised.
- Never run a real mutation against an unapproved third-party bundle or a critical system item. Stop if complete restoration cannot be demonstrated.

## Scope and architecture

- Manage policy at the owning application bundle level; per-status-item control within one app is out of scope.
- Preserve distinct `Visible`, `Revealable`, and `Hidden` intent. Ordinary reveal sessions must not include `Hidden` bundles.
- Keep product logic independent from the unsupported backend and keep the backend narrow and replaceable.
- Do not add themes, profiles, animation systems, synthetic-input ordering, or unrelated product features without an explicit roadmap change.

## Repository and privacy

- English is canonical for tracked documentation, code, comments, commits, and release material. Owner-only Chinese notes belong in ignored `LocalNotes/`; any decision needed to build, audit, recover, maintain, or distribute Blenny must also exist in tracked English documentation.
- Keep raw diagnostics, screenshots, crash reports, samples, system-state backups, build products, binaries, signing material, credentials, and unrelated bundle inventories out of Git. Put short-lived local evidence under ignored `LocalData/`.
- Do not add personal absolute paths. `poemfar@gmail.com` is explicitly approved public Git author metadata; do not infer that any other owner-specific information is public.
- The owner selected Apache-2.0 on 2026-09-29. Preserve LICENSE, NOTICE, THIRD_PARTY_NOTICES.txt and the packaged dependency notices; do not change the license without explicit owner approval.
- Use the Conventional Commit rules in `docs/COMMIT_MESSAGE_GUIDELINES.md`. Do not add AI attribution or generated-by trailers.
- For a meaningful change, draft a structured release fragment under `docs/changes/` from the actual diff and verified behavior. Use `version: unreleased` after the current release is frozen. Include technical and optional user-facing text; for no release entry, record a justified `Release-Note: none (reason)` commit trailer. Prepare both generated documents with `scripts/release_tools.py`; never independently rewrite generated version sections.
- Preserve the genuine history beginning on 2026-08-21 and the original first commit. Before the first push, later private commits may be reorganized only with explicit owner approval. Never silently rewrite shared history.
- Never push, force-push, publish, or change repository visibility without explicit confirmation of the exact remote, branch, and tags.

## Verification and version completion

- Use Xcode 27 and the macOS 27 SDK explicitly for builds and tests; the machine's default developer directory may point to an older Xcode.
- Add deterministic tests for policy, serialization, failure, and restoration behavior. Do not rely only on a successful visual experiment.
- Keep `PROJECT_BRIEF.md`, `README.md`, `docs/ROADMAP.md`, the relevant technical-spike document, `Config/Info.plist`, and the version tag consistent.
- A technical milestone is not complete while tests fail, documentation disagrees, the working tree is dirty, raw evidence is tracked, or system state is not fully restored.
- At the end of every version, invoke the repository skill `$blenny-release`. It must audit the version diff and reachable history, run the required checks, organize only authorized history, verify or create the annotated tag, and obtain explicit confirmation before pushing exact refs.
- For 1.0.0 and later, finish human acceptance, source/notes review, signing setup and exact-ref authorization before the annotated-tag trigger. `.github/workflows/release.yml` then builds and publishes without another human checkpoint. Public binaries must be built on GitHub; local packages remain development acceptance artifacts. See `docs/RELEASE_AUTOMATION_PLAN_1.0.0.md` and `docs/DISTRIBUTION.md`.
