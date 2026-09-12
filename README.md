# Blenny

Blenny is a minimal, native menu bar organizer for macOS 27 and later. It uses
three explicit intent areas:

- **Visible** items remain available in the menu bar.
- **Revealable** items are concealed during ordinary management and return for
  a bounded reveal session.
- **Hidden** items stay out of ordinary reveal sessions.

Policy is owned at the application bundle level. The current experimental 0.9.0
configuration also retains reviewed preferred-position changes for attributable
third-party owners. Every configured key associated with one owner moves as a
block, and the same serial coordinator, durable receipt and bounded verification
contract protect policy and ordering writes.

## Current status

Version `0.9.0` completed as a local experimental milestone on 2026-09-12.
Verification is recorded in
[the 0.9.0 release record](docs/RELEASE_0.9.0.md). It is not a distribution or
public-release candidate.

Owner-operated testing on macOS 27.0 build `26A5425a` confirms the current
three-state visibility behavior for Siri, Time Machine and Control Center is
responsive, and confirms the tested third-party ordering and repaired drag flow.
These observations establish the tested local workflow; they are not a universal
application, hardware, display or macOS-build compatibility claim.

Ordering is available only in Debug or in the explicitly opted-in optimized trial
build. Ordinary Release excludes the ordering implementation. Sorting for Siri,
Time Machine and Control Center is deferred to a later version. Weather and Input
Menu retain their separately attributed experimental ordering route. The native
overflow arrow has no established writable ordering identity, so Blenny does not
guarantee that the fish or any managed item remains adjacent to it.

Version 0.10.0 focuses on final interface, copy and usability refinement, starting
with an evidence-based review before implementation. Distribution requirements
remain gates for the first public source and binary
release candidate is scheduled for 0.11.0. Keeping one canonical repository is
the accepted publication model; changing repository visibility or publishing
any ref remains a separate action.

Detailed current evidence and historical candidate results are in
[the 0.9.0 technical spike](docs/TECH_SPIKE_0.9.0.md) and
[the historical development notes](docs/HISTORICAL_DEVELOPMENT_NOTES.md).

## Known limitation

On the tested build, clicking the native Clock cannot open Notification Center
while Blenny management is active. A left swipe from the trackpad's right edge
still opens Notification Center. The project will not add automatic Stop/Resume
around Clock clicks. See [Known limitations](docs/KNOWN_LIMITATIONS.md) and
[the technical report](docs/NOTIFICATION_CENTER_TECHNICAL_REPORT_2026-09-12.md).

## Safety and recovery

Blenny keeps AppKit in charge of status items, windows and Accessibility
infrastructure. It never moves the pointer, synthesizes Command-drag input,
injects into `MenuBarAgent`, disables SIP or requires Screen Recording for its
baseline behavior. Unsupported macOS behavior stays isolated and build-gated.

All system mutation runs through one serial writer. A reviewed change uses fresh
identity and configuration checks, a durable private recovery record, one bounded
verification and bounded rollback. Stop and Quit release Blenny's active
visibility restrictions while retaining a successfully committed user order.
Explicit Undo restores the recorded ordering baseline. Incomplete writes remain
recoverable and unexpected target drift fails closed.

## Repository layout

- `Sources/` contains product code and bounded Debug-only integration code.
- `Tests/` contains deterministic policy, ordering, serialization, failure and
  restoration coverage.
- `Assets/` contains application and status-item artwork.
- `Research/` contains archived unsupported experiments excluded from product
  targets; start with [the research index](Research/README.md).
- `docs/` contains product decisions, roadmap, limitations, technical reports
  and historical development records.
- `LocalData/` is ignored and holds short-lived local evidence and build output.

Read [PROJECT_BRIEF.md](PROJECT_BRIEF.md) for the product contract,
[docs/ROADMAP.md](docs/ROADMAP.md) for version boundaries and
[docs/REPOSITORY_POLICY.md](docs/REPOSITORY_POLICY.md) for publication rules.

## Build

Blenny requires Xcode 27 and the macOS 27 SDK. Select the Xcode 27 developer
directory explicitly because the machine default may point to an older Xcode.

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun swift test

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./scripts/build-app.sh debug
```

To build the optimized local ordering trial:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
BLENNY_ORDERING_TRIAL=YES ./scripts/build-app.sh release
```

The optimized trial retains Debug capability gates. It is not ordinary Release.
Programs under `Research/` are not built by the Swift package and are not supported
product entry points. The separate `BlennyLayoutProbe` package product is a bounded
development tool, not part of the shipped application.

## License

License adoption and distribution notices remain follow-up work after the
0.10.0 interface review. No license files are tracked in this milestone. The project is a clean implementation and
does not use or link Ice or Thaw code or binaries.
