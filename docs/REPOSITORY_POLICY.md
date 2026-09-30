# Repository policy

Blenny uses one canonical repository. It remains private during the engineering
milestones and is intended to become public with version `1.0.0`, after its
distribution gates pass and the owner explicitly authorizes publication.
This supersedes the earlier `0.12.x` candidate plan.

## License and publication scope

The owner selected Apache-2.0 for 1.0.0 on 2026-09-29. LICENSE, NOTICE and
THIRD_PARTY_NOTICES.txt are prepared for the authorized source commit and
packaged with the application. Sparkle's
license is included in full. No private signing material is part of the source.
Third-party names and interface descriptions do not grant rights in another
party's implementation or trademarks. Any third-party dependency must have
compatible licensing and retain its required notices.

Sanitized research and original reproducible probes stay in this same repository.
They do not require a second public mirror. Raw evidence and owner-only Chinese
notes remain ignored and require a private backup. Published historical reports
retain their original evidence and explicitly identify superseded conclusions.

## Distribution route

The owner selected the existing fixed self-signed certificate and independent
Sparkle EdDSA key for 1.0.0. Developer ID and Apple notarization are not release
gates. Signature integrity and update authentication do not imply Apple trust.
Document the actual first-launch steps without disabling system protection.

From the first public 1.0.0, every public binary is built on GitHub from the
authorized annotated source tag. Local signed packages are development acceptance
artifacts. Complete all human acceptance, release-content review, hosted setup,
visibility decisions and exact-ref authorization before that trigger. The release
workflow then signs, verifies, publishes and checks delivery automatically, with
no required reviewer, second publish workflow or post-build owner test. Failed
checks still stop publication; reruns reuse sealed bytes and never replace a
published version. See RELEASE_AUTOMATION_PLAN_1.0.0.md and DISTRIBUTION.md.

## History

- Preserve the repository's genuine development history beginning on 2026-08-21, including the original first commit.
- Before the first public push, later private commits may be combined or reorganized to produce a clear, reviewable history. Preserve their real authorship and dates where practical.
- After the first public push, prefer forward cleanup commits and rewrite shared history only to remove a credential, private signing material, unrelated personal data, or content that cannot legally be distributed.
- Use public-safe author metadata for every commit intended to reach the public repository.

## Tracked content

Product code, tests, build scripts, design decisions, sanitized research notes, and source needed to reproduce an experiment belong in Git.

Unsupported experiments belong under `Research/`. They must:

- be excluded from product build targets;
- display an unsupported-behavior warning;
- use bounded execution and fail closed;
- identify mutation and recovery behavior;
- avoid fixed personal filesystem paths and unrelated user data;
- never contain copied third-party implementation code or Apple binaries.

## Content that never belongs in Git

- Credentials, certificates, signing identities, provisioning profiles, or notarization secrets.
- Raw local diagnostics, menu-bar screenshots, crash reports, process samples, or system-state backups.
- Built applications, Mach-O binaries, DerivedData, SDK caches, or compiler intermediates.
- Absolute personal filesystem paths or unrelated bundle inventories.
- Third-party source copied for investigation.

These artifacts belong under ignored `LocalData/` only for the shortest useful retention period.

## Language and local notes

- English is the canonical language for tracked documentation, code, comments, commit messages, issue templates, and release material.
- Localized strings may remain in source, tests, and technical evidence when their exact spelling is required for behavior or reproducibility.
- Public translations are optional. They must identify the English document they translate and must not silently become the only record of a product, architecture, safety, or recovery decision.
- Private working-language drafts and owner notes belong under ignored `LocalNotes/`. They may explain or summarize the project, but they are not part of the repository history or public source of truth.
- Any conclusion required to build, maintain, recover, audit, or distribute Blenny must also be distilled into the appropriate tracked English document.
- Because ignored notes are not protected by Git history, they require an independent private backup if they contain information worth retaining.

## Publication gate

Before changing the repository from private to public:

1. Inspect every reachable branch and tag, not only the working tree.
2. Scan file content and commit metadata for private data and signing material.
3. Confirm that ignored local artifacts have never entered reachable history.
4. Verify that every shipped binary can be built from the published source.
5. Confirm that all unsupported behavior is documented, isolated, build-gated, and recoverable.
6. Select the license and add required notices.
7. Build, test, sign with the pinned self-signed identity, verify Sparkle updates,
   install, restore and validate uninstall during development. Validate the hosted
   workflow and signing setup before the first formal trigger.
8. Publish source and the first public binary together.

The owner authorizes the exact destination, main commit and annotated tag before
the production trigger. That authorization covers the tag's automatic asset and
feed transaction. Visibility changes and controlled signing-secret transfer remain
explicit setup actions. No workflow may infer those permissions or export keys.

Historical research may be published with the product when it is sanitized. Its presence is not a promise that abandoned probes remain supported.
