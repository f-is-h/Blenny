# Blenny

> Version 0.10.0 completes the locally accepted interface, ordering and unified Undo milestone.
> See [the release record](docs/RELEASE_0.10.0.md) for evidence and remaining limits.


Blenny is a minimal, native menu bar organizer for macOS 27 and later. It uses
three explicit intent areas:

- **Visible** items remain available in the menu bar.
- **Revealable** items are concealed during ordinary management and return for
  a bounded reveal session.
- **Hidden** items stay out of ordinary reveal sessions.

Policy is owned at the application bundle level. The current experimental 0.10.0
configuration also retains reviewed preferred-position changes for attributable
third-party owners. Every configured key associated with one owner moves as a
block, and the same serial coordinator, durable receipt and bounded verification
contract protect policy and ordering writes.

## Current status

Version `0.10.0` completed as a local experimental milestone on 2026-09-15.
Verification is recorded in
[the 0.10.0 release record](docs/RELEASE_0.10.0.md). It is not a distribution or
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

In the 0.10.0 ordering-enabled build, **Position Blenny Controls…** in Blenny's menu
places its double arrow and fish at the configured Revealable/Visible boundary,
with the arrow on the left. The saved placement stays after Stop or Quit;
**Undo Control Placement** restores their previous positions independently of
ordinary ordering Undo. Once enabled, placement follows successful Organize Apply
and ordering Undo; Undo Control Placement turns this adjustment off. Expansion and collapse do
not reposition it, and a fixed screen coordinate is not promised.

Version 0.11.0 begins with permissions/onboarding and final UI polish, followed
by the remaining distribution gates. One canonical repository remains the
publication model; changing visibility or publishing any ref is a separate action.
Current evidence is in [the 0.10.0 technical spike](docs/TECH_SPIKE_0.10.0.md).
Earlier results remain in [the 0.9.0 spike](docs/TECH_SPIKE_0.9.0.md) and
[the historical notes](docs/HISTORICAL_DEVELOPMENT_NOTES.md).

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
Undo Changes reverses the last successful Apply, including visibility and ordering changes. It is single-level Undo. Incomplete writes remain
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

## Using Blenny

Drag icons in Organize to edit your draft, then choose Apply. Discard Changes
returns to the accepted configuration. Icons belonging to one app move together.
Use an icon's context menu or accessibility actions to move it without dragging;
Item controls opens the complete selection controls.

Visible stays available, Revealable appears when expanded, and Hidden is excluded
from expansion. macOS may still put Visible items into its own overflow.
Stop and Quit release visibility controls but retain accepted ordering. Resume
uses saved visibility settings. Undo Changes reverses the last successful Apply, including visibility and ordering. If the menu bar changed outside Blenny, Replace Undo & Apply
explicitly replaces the previous Undo history before applying the draft.

Clock is fixed: it cannot be sorted or moved between groups. On the tested macOS
27 build, clicking Clock cannot open Notification Center while Blenny manages
visibility; swipe left from the trackpad's right edge instead. Siri, Time Machine
and Control Center sorting remains unverified. Exact coordinates and adjacent
arrows are not guaranteed. See [known limitations](docs/KNOWN_LIMITATIONS.md).

### Move Blenny's own icon

Hold Command and drag the fish in the macOS menu bar. macOS controls its final
placement; Blenny does not guarantee adjacency to the overflow arrow.

If saved control positions have changed, **Position Blenny Controls** can review
a new placement and replace its stale Undo baseline. The previous record is
archived; Undo Control Placement then restores the positions before that action.
