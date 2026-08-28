# Blenny

Blenny is a minimal, native menu bar organizer designed exclusively for macOS 27 and later.

Project website: <https://blenny.fi5h.xyz>. The application uses the stable reverse-DNS bundle identifier `xyz.fi5h.blenny`.

The project is currently under private development. Versions `0.0.1` through `0.0.5` established the bounded macOS 27 backend, bundle-policy persistence, deterministic editing, rollback, and restoration foundations. Version `0.1.0` completed the first minimal AppKit product interface, and version `0.2.0` completed icon-first policy presentation. Version `0.3.0` completed the durable single-window product interface: symbol-and-label navigation in one fixed-height band below the title bar; top-level Organize, Settings, and Support destinations without unnecessary vertical scrolling; compact horizontal policy lanes with tightly spaced borderless icon cells and one macOS read-only marker; a wide Organize presentation and one stable narrower width for Settings and Support in the same top-left-anchored window; an anchored manual-observation footer whose idle Refresh action rechecks Accessibility and whose active state places an unmistakable progress overlay over the lanes; native Open at Login through macOS Service Management; restrained one-time, monthly, and Ko-fi support links with Blenny project attribution on GitHub; and one in-window safety Review route for management and recovery. The visible interface is SwiftUI, while AppKit remains responsible for the status item, product window, workspace integration, Service Management, and Accessibility infrastructure. This remains a local engineering milestone, not a distributable release or a general compatibility claim.

Icon-first recognition remains intact: installed application icons come from public AppKit/Workspace APIs, known read-only Apple system items use natural-aspect semantic SF Symbols, and unresolved candidates use one explicit fallback. Names, policies, bundle identifiers, observation counts, read-only state, tooltips, and Accessibility labels remain supplementary to the icons. Visible means Blenny does not conceal an item; macOS still owns final placement and native overflow. Organize exposes no temporary assignment or draft-creation control before cross-lane dragging arrives in `0.4.0`.

Blenny's application bundle uses the v12 color artwork from `Assets/AppIcon/`; the build deterministically derives the complete multi-resolution macOS icon resource from its 1024-pixel production PNG. The app icon remains separate from Blenny's status-item artwork: the status item uses a bundled, 18-point optical-size monochrome template SVG so AppKit can adapt it to the current menu-bar appearance without rescaling fine details, while the detailed status-item vector master remains under `Design/MenuBar/`. Blenny never captures live menu-bar pixels and does not require Screen Recording.

Existing local policy and recovery documents created with the former development identifier `com.example.BlennyProbe` migrate deterministically to `xyz.fi5h.blenny`. The migration preserves policy assignments and management state, updates both the accepted document and its scoped backup, is idempotent, and fails closed if both identities are already present.

## Product direction

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
