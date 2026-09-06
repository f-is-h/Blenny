# Repository policy

Blenny uses one canonical repository. It remains private during the engineering milestones and is intended to become public with the first `0.10.x` release candidate.

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
7. Build, test, sign, notarize, install, restore, and uninstall the release candidate.
8. Publish source and the first public binary together.

Historical research may be published with the product when it is sanitized. Its presence is not a promise that abandoned probes remain supported.
