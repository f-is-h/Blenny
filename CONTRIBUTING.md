# Contributing to Blenny

Read PROJECT_BRIEF.md, AGENTS.md and docs/REPOSITORY_POLICY.md before changing
behavior. Use Xcode 27 and the macOS 27 SDK. Run `scripts/verify-local.sh` with an
explicit DEVELOPER_DIR; it checks both Debug and ordinary Release plus appcast
validation. Tests cover policy, serialization, bounded failure and restoration.

For every meaningful change, add a small JSON fragment in `docs/changes/` with
an ID matching its filename, `version: unreleased`, a category, a technical
summary, optional user-facing summary and verified commit references. Use the
existing fragments as the schema examples. Codex should draft this entry while
implementing the change, using the real diff and tested behavior. Internal-only
entries may omit `user`; a change with no release entry needs a justified
`Release-Note: none (reason)` commit trailer. Direct commits and merged PR
contributions are reconciled during preparation. Pure merges need no duplicate
entry; conflict-resolution changes do.

Run `python3 scripts/release_tools.py prepare --version X.Y.Z --date YYYY-MM-DD
--previous-public-tag vPREVIOUS` to assign unreleased fragments, update the
canonical marketing version and regenerate CHANGELOG.md and docs/RELEASE_NOTES.md.
Use `render` for corrections and `check`/`coverage` to validate. Generated output
is deterministic; review fragments rather than editing the two outputs separately.
A version may add a hand-written `docs/releases/X.Y.Z.md` story that replaces the
generated user list in its release notes; see docs/DISTRIBUTION.md for its rules.
The first public 1.0.0 notes cover the complete product, not the private 0.13 delta.

Normal CI has no signing secrets or publication rights. The preparation workflow
creates a review PR. All human tests and content review precede the authorized
annotated tag; the release workflow then runs unattended. See docs/DISTRIBUTION.md
for internal version ordering, setup, failure recovery and public provenance.

Keep AppKit responsible for lifecycle and Accessibility. macOS 27 backend
contracts must remain narrow and fail closed. Use the existing serial writer.
Do not add pointer movement, synthesized clicks or Command-drag, private
entitlements, SIP changes, Screen Recording dependencies or polling loops.
Do not test real third-party system writes without an approved target scope and
a complete restoration snapshot. Use deterministic fixtures first.

English is canonical for tracked source, documentation, comments and commits.
Use the Conventional Commit rules in docs/COMMIT_MESSAGE_GUIDELINES.md.
Keep raw diagnostics, screenshots, system backups, signing material and build
output in ignored LocalData. Do not include personal paths or unrelated inventory.
Sanitized reproduction steps and expected/actual behavior are enough for issues.

Release signing keys and certificates are owner-managed and are not required for
source-level testing. Explicit ad-hoc developer builds are not release artifacts.
Never regenerate or export keys to make a release test pass. Publication and
visibility changes require the owner's exact-ref approval.
