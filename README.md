# Blenny

> Version 0.12.0 completed as a local macOS 27 experimental milestone on
> 2026-09-27. It is not a public release candidate. See the
> [release record](docs/RELEASE_0.12.0.md) and [roadmap](docs/ROADMAP.md).


Blenny is a minimal, native menu bar organizer for macOS 27 and later. It uses
three explicit intent areas:

- **Visible** items remain available in the menu bar.
- **Revealable** items are concealed during ordinary management and return for
  a bounded reveal session.
- **Hidden** items stay out of ordinary reveal sessions.

Policy is owned at the application bundle level. The current experimental 0.12.0
configuration also retains reviewed preferred-position changes for attributable
third-party owners. Every configured key associated with one owner moves as a
block, and the same serial coordinator, durable receipt and bounded verification
contract protect policy and ordering writes.

## Current status

Version `0.12.0` completed as a local experimental milestone. Its tested
scope includes self-signed build continuity, opt-in Sparkle packaging, startup
Resume, Dock presentation, system-item Board capabilities, and the accepted
Build 59 Resume behavior. The unbundled Gaming and Wine visibility limitation
remains open; see [Known limitations](docs/KNOWN_LIMITATIONS.md).

On macOS 27.0 build `26A428`, the owner confirms Build 15 native dragging and
Apply work normally after the shared application/system drag-source correction.
Repeated mixed Apply/Undo runs independently verify the delayed preference-file
commit repair and exact restoration. These results establish the tested local
workflow, not universal application, hardware, display or macOS-build coverage.
Local packages display both the marketing version and an identifying build number.

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

The planned 0.13.0 iteration owns right-click menu productization, Debug
feature cleanup, and replacement menu-bar and app icons. Public release remains
a later milestone, with onboarding/accessibility acceptance, Release ordering
review, licensing, signing, installation/update and publication gates still
open. One canonical repository remains the publication model;
changing visibility or publishing any ref is a separate action. See
[the 0.11.0 technical spike](docs/TECH_SPIKE_0.11.0.md) for the final fixes and
superseded investigation steps, and [the roadmap](docs/ROADMAP.md) for open gates.
Earlier results remain in [the 0.9.0 spike](docs/TECH_SPIKE_0.9.0.md) and
[the historical notes](docs/HISTORICAL_DEVELOPMENT_NOTES.md).

## Known limitation

On tested builds `26A5425a` and `26A428`, clicking the native Clock cannot open
Notification Center while Blenny management is active. A left swipe from the
trackpad's right edge worked in the earlier owner test; it was not retested on
every build. The project will not add automatic Stop/Resume
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
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  ./scripts/build-app.sh debug
```

To build the optimized local ordering trial:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
BLENNY_ORDERING_TRIAL=YES ./scripts/build-app.sh release
```

The optimized trial retains Debug capability gates. It is not ordinary Release.
Each successful app build allocates the next local `CFBundleVersion` from an
ignored `LocalData/build-number.txt` counter. Set `BLENNY_BUILD_NUMBER` to a
positive integer when a reproducible CI or archival build needs an explicit
number.
Programs under `Research/` are not built by the Swift package and are not supported
product entry points. The separate `BlennyLayoutProbe` package product is a bounded
development tool, not part of the shipped application.

## License

License adoption and distribution notices remain future public-release gates.
No license files are tracked in this milestone. The project is a clean
implementation and does not use or link Ice or Thaw code or binaries.

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
