# Blenny

Blenny is a minimal, native menu bar organizer designed exclusively for macOS 27 and later.

Project website: <https://blenny.fi5h.xyz>. The application uses the stable reverse-DNS bundle identifier `xyz.fi5h.blenny`.

The project is currently under private development. Versions through `0.4.0` established the bounded macOS 27 backend, persistent bundle policy, deterministic Review, the single-window product, icon-first Organization Board, and native cross-lane Draft assignment. Version `0.5.0` connects a freshly reviewed application-bundle plan to one Debug-only serial writer on one exact development runtime. Activation is verified before transactional persistence; scoped 0600 recovery, rollback, ordinary Reveal, Stop Managing, Restore Previous Policy, connection invalidation, and termination cleanup close the loop. Blenny remains Visible, Hidden never enters ordinary Reveal, Apple system items remain read-only, and stale or unauthorized plans cannot reach the writer. Release still cannot access the unsupported backend. This remains a local engineering milestone, not a distributable release or a general compatibility claim.

Version `0.5.0` completed implementation, Debug/Release deterministic verification, installed no-mutation dry-run, owner-approved exact real-write validation, full restoration comparison, and the release audit. It is closed locally at annotated tag `v0.5.0`. Version `0.5.1` is a focused patch with code, tests, builds and no-write validation audited; final compact-spacing visual acceptance and the local tag remain pending: the ordinary Review page is removed while internal plan validation and recovery remain mandatory. Draft Apply starts management, and unrelated process churn is incorporated into a freshly rebuilt exact writer plan instead of producing a false stale-plan error. A smaller double-chevron button sits left of the artwork/editor button as two compact 22-point native status items. Blenny keeps its arrow throughout verified management and ordinary reveal, independently of native overflow presence. The arrow has its own native action, shared with the safety menu; the artwork opens the editor without coordinate-based click routing. Native-control integration and missing-application discovery, including the reported Bartender issue, are deferred to 0.6.0 with lifecycle/display hardening. This is not a promise to intercept Apple's button. Ordering investigation moves to 0.7.0, retaining all safety gates; distribution preparation follows at 0.8.0. Refresh stays read-only after startup and cannot silently replace the assertion. Existing tags remain unchanged; nothing is pushed.

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
