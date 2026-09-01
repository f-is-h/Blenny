# Blenny

Blenny is a minimal, native menu bar organizer designed exclusively for macOS 27 and later.

Project website: <https://blenny.fi5h.xyz>. The application uses the stable reverse-DNS bundle identifier `xyz.fi5h.blenny`.

Version `0.7.0` closes the real menu-bar ordering investigation with a deliberately
manual product boundary. Blenny does not reorder third-party or Apple items. When
one usable native overflow control is observed, Settings explains how the user can
Command-drag the fish immediately to its right. The fish has one stable public
AppKit autosave identity so macOS can retain the user's placement across Blenny
updates. macOS still owns the physical order, so this is guidance rather than an
arrow-relative pinning guarantee.

Private API, preference storage, historical spikes, competitor behavior and
bounded installed experiments did not establish a complete readable, writable and
reversible cross-app ordering contract. Blenny therefore adds no synthetic input,
polling, automatic reconciliation, third-party write, Board-only sorting, helper or
Release backend promotion. Full findings and recovery limits are in
[the 0.7.0 spike](docs/TECH_SPIKE_0.7.0.md).

Version `0.7.0` completed after 285 Debug and 254 Release deterministic tests,
both app builds, and installed no-writer regression. The existing annotated
`v0.7.0` tag predates the final placement-guidance follow-up and remains unchanged
under the repository's no-tag-rewrite boundary. History is forward-only and no
push is authorized.

The preceding `0.6.0` completed the native-overflow integration investigation, accepted
by the owner on 2026-08-31 on the exact Debug development boundary: macOS 27.0
build `26A5416b`, arm64, one 1600 × 900 logical-point display at 2x scale.
Native expand/collapse now coordinates Blenny's Revealable session, including
when the system arrow first appears while Blenny is already running, without
requiring a preceding Blenny click. This observes native Accessibility state;
it does not intercept, replace, or modify Apple's button.

Blenny hides its fallback arrow when one known, registered native control is
usable and restores it when native observation is absent, unavailable or
ambiguous. The fish, safety-menu action, existing artwork and fixed 22-point
slots remain. This is not a fixed-position or physical-visibility guarantee.
Transient presentation loss preserves an authorized reveal and its original
deadline; lifecycle or permission loss still restores through the serial writer.
Canonical-root topology subscriptions and one coalesced post-activation read
discover newly created controls without waiting for a Blenny write. Discovery
alone never opens a session; there is no polling or automatic reconciliation.

The missing-app report concerned **Coffee Buzz**, not Bartender. Bounded discovery,
ownership attribution and installed-icon presentation succeeded; discovery grants
no mutation authority, and the owner's later explicit assignment is preserved.
Xcode 27 verification passed 255 Debug and 253 Release tests and both app builds.
Installed no-write preflight, bounded real-run cleanup and unchanged policy/backup
checks are recorded separately from the owner's visual acceptance in
[the 0.6.0 spike](docs/TECH_SPIKE_0.6.0.md).

This is a local engineering milestone, not general macOS compatibility or a
distributable release. Release has no unsupported mutation backend. Broader
lifecycle/display validation remains an explicit carry-forward gate in
[the roadmap](docs/ROADMAP.md). The 0.7.0 investigation does not add sorting or
fixed placement, and does not expand the accepted 0.6.0 compatibility matrix.
The historical `v0.6.0` closure tag is preserved.

The project is currently under private development. Versions through `0.4.0` established the bounded macOS 27 backend, persistent bundle policy, deterministic Review, the single-window product, icon-first Organization Board, and native cross-lane Draft assignment. Version `0.5.0` connects a freshly reviewed application-bundle plan to one Debug-only serial writer on one exact development runtime. Activation is verified before transactional persistence; scoped 0600 recovery, rollback, ordinary Reveal, Stop Managing, Restore Previous Policy, connection invalidation, and termination cleanup close the loop. Blenny remains Visible, Hidden never enters ordinary Reveal, Apple system items remain read-only, and stale or unauthorized plans cannot reach the writer. Release still cannot access the unsupported backend. This remains a local engineering milestone, not a distributable release or a general compatibility claim.

The previous `0.5.0` milestone closed the reviewed management loop and direct
fish/arrow controls at `v0.5.0`, with no separate patch release. It removed the
ordinary Review page while retaining internal plan validation and recovery,
made Draft Apply start management, and rebuilt exact plans from fresh bounded
preflight instead of treating unrelated process churn as changed authorization.
Its always-shown fallback policy is superseded by the accepted 0.6.0 native
handoff above; the artwork and separate native actions are unchanged. Historical
missing-app wording is retained in the older spike, not treated as a Bartender
diagnosis. Existing tags, including `v0.5.0`, are not modified by this version.

Icon-first recognition remains intact: installed application icons come from public AppKit/Workspace APIs, known Apple system items remain read-only semantic symbols, and unresolved candidates use one explicit fallback. Cross-lane movement changes only `BundlePolicyDraft`; Apply accepts only the exact current prepared Review. A false-to-true Accessibility transition triggers one bounded read-only refresh; later observations remain manual. No sorting, Screen Recording, menu-bar pixel capture, polling, automatic reconciliation, synthetic input, helper, or Release backend promotion is included.

Blenny's application bundle uses the v12 color artwork from `Assets/AppIcon/`; the build deterministically derives the complete multi-resolution macOS icon resource from its 1024-pixel production PNG. The app icon remains separate from Blenny's status-item artwork: the status item uses a bundled, 18-point optical-size monochrome template SVG so AppKit can adapt it to the current menu-bar appearance without rescaling fine details, while the detailed status-item vector master remains under `Design/MenuBar/`. Blenny never captures live menu-bar pixels and does not require Screen Recording.

Existing local policy and recovery documents created with the former development identifier `com.example.BlennyProbe` migrate deterministically to `xyz.fi5h.blenny`. The migration preserves policy assignments and management state, updates both the accepted document and its scoped backup, is idempotent, and fails closed if both identities are already present.

## Product direction

If startup cannot safely activate the saved policy, management stays inactive and
Resume remains available after Accessibility is granted. Open any managed app
named in the error, then choose Resume. This performs fresh safety checks and
activates unchanged accepted intent without rewriting the policy or rotating its
backup. A lost system connection still requires quitting and reopening Blenny.

- Use AppKit for status-item, window, Workspace, Service Management, and Accessibility infrastructure, with one SwiftUI hierarchy for all visible product content.
- Manage intent at the application-bundle level.
- Never move the pointer or synthesize Command-drag reordering.
- Avoid continuous polling and automatic reconciliation loops.
- Prefer native overflow presentation where it is adequate.
- Fail closed and restore deterministically when unsupported behavior changes.

Blenny is a clean implementation. It does not use or link Ice or Thaw code or binaries.

## Repository layout

- `Sources/` — product and bounded Debug-probe targets.
- `Tests/` — deterministic tests for identity, traversal, policy editing, product-interface presentation state, transactions, overflow classification, and reversible state.
- `Assets/` — tracked application-icon sources and production menu-bar artwork copied or derived into the app bundle.
- `Research/` — historical, unsupported experiments excluded from product targets.
- `docs/` — roadmap, repository policy, API research, and technical-spike results.
- `LocalData/` — ignored local diagnostics, backups, binaries, screenshots, and build artifacts.

Read [PROJECT_BRIEF.md](PROJECT_BRIEF.md) for the product constraints and [docs/ROADMAP.md](docs/ROADMAP.md) for version exit criteria.

## Build

Blenny requires Xcode 27 and the macOS 27 SDK.

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun swift test

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./scripts/build-app.sh debug
```

The `Research/` probes are not built by the Swift package and are not supported product entry points.

## Unsupported system behavior

The validated architecture includes version-sensitive, unsupported macOS behavior. Public APIs alone do not provide the required bundle-level presentation control. The production backend must remain isolated, build-gated, reversible, and protected by an emergency compatibility kill switch.

Do not treat the historical research probes as safe general-purpose utilities.

## License

No open-source license has been selected yet. A license will be added before the first public release. Until then, this repository is not offered for redistribution.
