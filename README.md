# Blenny

Blenny is a minimal, native menu bar organizer designed exclusively for macOS 27 and later.

The project is currently under private development. Versions `0.0.1` through `0.0.5` established the bounded macOS 27 backend, bundle-policy persistence, deterministic editing, rollback, and restoration foundations. Version `0.1.0` completed the first minimal AppKit product interface: Visible, Revealable, and Hidden bundle-level states, bounded read-only candidate refresh, read-only Apple system-item presentation, local drafts, deterministic review before Apply, recovery actions, and non-repeating Accessibility onboarding. Visible means Blenny does not conceal an item; macOS still owns final placement and native overflow. It is not yet a distributable release or a general compatibility claim; lifecycle and display hardening remain `0.2.0` work.

## Product direction

- Use AppKit for status-item, window, and Accessibility infrastructure.
- Manage intent at the application-bundle level.
- Never move the pointer or synthesize Command-drag reordering.
- Avoid continuous polling and automatic reconciliation loops.
- Prefer native overflow presentation where it is adequate.
- Fail closed and restore deterministically when unsupported behavior changes.

Blenny is a clean implementation. It does not use or link Ice or Thaw code or binaries.

## Repository layout

- `Sources/` — product and bounded Debug-probe targets.
- `Tests/` — deterministic tests for identity, traversal, policy editing, the interface view model, transactions, overflow classification, and reversible state.
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
