# Unsupported ordering adoption probe

Original macOS 27 Debug research, excluded from every product target. The
corrected fixture has demonstrated a two-owner swap and inverse through the
external group preference route; see [the evidence and limits](../../docs/ORDERING_RESEARCH_2026-09-08.md).
It is not a production ordering backend or general third-party compatibility
claim. Native-arrow ownership is outside scope.

## Identity correction

The earlier fixture used distinct bundle IDs but shared executable basename
`probe` and autosave `AdoptionProbe`. MenuBarAgent actually assigned both the
key `status:probe::AdoptionProbe`. Those failed trials did not establish two
independent ordering identities.

The corrected applications use executable names `OrderingAdoptionA` and
`OrderingAdoptionB`, with autosaves `AdoptionProbeA` and `AdoptionProbeB`.
The controller requires fresh system merge logs proving two independent keys
and initial values before sending position changes. It never substitutes a
bundle ID for the observed key. Missing subsequent merge logs are recorded as
absent observations, not as proof of rejection or a reason to skip restoration.

## Modes

Each temporary application owns one AppKit item. Initial saved values are
120 and 1000. The controller sends serial, receipt-backed commands and samples
after fixed waits. There is no input synthesis, process injection, private
entitlement, system restart, continuous polling or automatic retry.

- Default owner mode: swap own saved values through the runtime-checked
  `_sendSavedPreferredPosition`; separately change A's width from 24 to 25;
  restore values and width separately; recreate only the test items.
- `--settings-only`: swap and restore without width changes or recreation.
- `--snapshot-only`: create test items, inspect identities and clean up. No
  position-change commands are sent, but creation seeds own preferences.
- `--external`: keep both owners' saved values unchanged; use `GroupWriter.m`
  to add only the two log-verified test keys to the real group table, then
  remove them as the inverse. Width changes are observed separately. No
  recreation occurs in this mode.
- `--external --settings-only`: external apply and inverse only. No owner
  position commands, width changes or item recreation between samples.

Owner samples record saved values, process IDs, window frames, length, autosave,
object addresses and local scene fields. The exact observed scene getter
encodings are checked before invocation. The scalar `hostPreferred` field
remained zero even during successful external ordering; it is not the agent's
adopted input. Allocator reuse means an unchanged object address after recreation
does not prove the same item instance survived.

Independent AX samples corroborate geometry. `evaluate.py` distinguishes a
relative swap, inverse order and exact coordinate restoration. These observations
do not establish compositor visibility, timing guarantees or display/lifecycle
compatibility.

## Safety and recovery

The owners reject any other OS build, bundle or command. They start only with
empty preference domains, accept each non-stop command once and write an intent
receipt before mutation. Stop removes the owned item and initially absent domain;
a 150-second owner watchdog provides bounded ordinary cleanup. Killing an owner
forcibly can bypass cleanup, so process absence alone is insufficient.

The external writer accepts exactly two hardcoded test keys on build `26A5425a`.
It verifies the private container initializer encoding, initial system-key
observations, live owner PIDs, the fresh whole-file baseline and container/file
agreement before applying. It uses `_initWithSuiteName:container:` for
`com.apple.MenuBar`, sets `TrailingItemPreferredPositions` and synchronizes.
It does not directly edit the plist file or post guessed notifications.

All mutations run serially; a nonblocking file lock prevents overlapping writer
instances using the same evidence directory. The apply and inverse each have
at-most-once intent/completion receipts. The inverse removes only test values
that still match the apply, preserving unrelated table drift. Unexpected target
drift fails closed. Synchronization has one readback verification and no retry.
This is not an atomic cross-process compare-and-swap against other system writers;
that limitation still needs a production design.

The controller tries the inverse in `finally` if apply was attempted and the
inverse was not already attempted, then stops both owners and verifies cleanup.
Its helper calls have 15-second bounds. An interrupted controller can leave a
persistent external override: retain the evidence directory and inspect receipts.
If an apply intent exists but no restore intent exists, run the exact inverse:

```sh
rtk proxy LocalData/ordering-fresh/group-writer LocalData/ordering-fresh restore
```

If a restore intent exists without completion, do not blindly repeat it or erase
the receipt. Inspect actual scoped state and preserve unrelated drift. Test
owners can be stopped with `probe --signal <exact research bundle> stop`.
The completed live runs left neither overrides nor owner preferences.

Other applications are not stopped or controlled by the fixture. Do not run
while another person or menu-bar manager is changing the menu bar. Existing
application and system item preferences are never approved mutation targets.
All binaries, receipts, snapshots and raw logs remain ignored in `LocalData/`.

## Build and verify

Build with Xcode 27 / SDK 27 explicitly. This compiles and snapshots the research
sources without launching the applications or writing preferences:

```sh
rtk proxy python3 Research/OrderingAdoptionProbe/build.py \
  --developer-dir /Applications/Xcode-beta.app/Contents/Developer \
  --output LocalData/ordering-fresh
rtk proxy LocalData/ordering-fresh/group-writer --contract
rtk proxy LocalData/ordering-fresh/group-writer --self-test
rtk proxy env PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s Research/OrderingAdoptionProbe -p 'test_*.py' -v
```

The following performs **real, scoped external writes and their inverse**, using
the existing AX access of the repository's read-only helper:

```sh
rtk proxy python3 Research/OrderingAdoptionProbe/run_control.py \
  --artifacts LocalData/ordering-fresh \
  --reader LocalData/ordering-fresh/read-position --external --settings-only
rtk proxy python3 Research/OrderingAdoptionProbe/evaluate.py LocalData/ordering-fresh
```

Use a new evidence directory for every run. A zero controller exit means the
sequence completed and cleanup passed, not that ordering succeeded; inspect the
evaluator and phase evidence. Fifteen Python checks cover instrumentation,
identity ambiguity, controller failures, external rollback and evidence
interpretation. Four original native self-checks cover the inverse and drift
preservation without accessing real preferences.


## Real-owner identity capture and offline preview

`ReadOwners.swift` and `capture_identity.py` implement a separate **read-only**
Debug entry point. It combines one group-table snapshot, at most 60 seconds of
retained legacy merge logs, exact running bundle/executable tokens, bounded AX
extras-menu observations, process launch times, and narrowly selected owner
`NSStatusItem Preferred Position` preferences. It captures process descriptors
again and compares the whole group plist after the read. It never invokes
`GroupWriter`, launches status-item owners, changes system preferences, requests
permissions, or activates applications.

`identity.py` retains exact case and Unicode. Bundle-ID matches and executable
fallback matches are considered together so a conflicting executable cannot be
silently ignored. Missing owners, duplicate tokens/bundles, unverified process
lifetimes, incomplete AX reads, multiple live items, extra historical keys and
system owners do not become review candidates. Unknown or truncated preference
reads cannot corroborate an autosave name.

Two evidence levels remain distinct:

- A recent legacy log from the current owner's lifetime can corroborate the
  exact key. This still is not write authorization.
- Configured keys suppress legacy-fallback logs. A single configured key whose
  autosave name matches the owner's one saved-position key, with one observed
  AX item and stable unique process, is a **configured review candidate**.
  Its current live key has not been directly read from the remote agent.

Owner saved values need not equal configured positions: the configured value
intentionally overrides the legacy input, as the successful external control
already demonstrated. The cross-check uses exact autosave names and reports
values separately. Neither level permits automatic writes or arbitrary multi-
item bundle ordering.

```sh
rtk proxy env PYTHONDONTWRITEBYTECODE=1 python3 \
  Research/OrderingAdoptionProbe/capture_identity.py \
  --reader LocalData/ordering-fresh/read-owners \
  --output LocalData/ordering-identity-fresh
```

`preview_order.py` accepts a captured snapshot and exactly two candidate bundles.
It creates an offline, fingerprinted swap plan and validates its inverse entirely
in memory. Existing values are restored and originally absent entries are
removed. Stale apply baselines, altered plans and unexpected target drift reject;
restoration preserves unrelated drift and handles a partial known apply. A
preview records process identity and evidence level, stays `previewOnly: true`
and `writeAuthorized: false`, and is not accepted by the fixed-scope live writer.
A future live backend must refresh identity and state, use the single serial
writer, and obtain the exact third-party scope authorization before execution.

```sh
rtk proxy env PYTHONDONTWRITEBYTECODE=1 python3 \
  Research/OrderingAdoptionProbe/preview_order.py \
  LocalData/ordering-identity-fresh/snapshot.json \
  --bundles example.first example.second \
  --output LocalData/ordering-identity-fresh/swap-preview.json
```

The complete research Python suite now has **40 tests**, including 17 identity
checks and eight offline plan/restore checks in addition to the original 15.
All real app inventories, plans, raw keys and snapshots remain ignored; the
tracked follow-up report records aggregate results only.


## Owner-authorized real-pair trial

`ApprovedPairWriter.m` is a separate Debug-only writer for the explicitly
approved Snipaste / Usage4Claude experiment. It hardcodes their two exact
`Item-0` system keys and the original 995 / 581 values; it does not consume or
execute arbitrary offline preview plans. The original `GroupWriter.m` retains
its test-owner-only scope.

`run_approved_pair.py` requires a fresh identity capture and a new evidence
directory. It observes a bounded 65-second swap, restores the existing values,
and compares independent AX, the complete group plist and both owners' saved
position preferences. A separate 100-second watchdog performs one recovery
check. Receipt and native lock guards prevent duplicate writes; failed inverse
receipts are not blindly retried. The controller does not stop/restart owners,
change item width, activate UI or synthesize input.

This command performs **real writes to the specifically approved pair**. It
requires authorization for that concrete run; the historical experiment is not
standing authorization to repeat it:

```sh
rtk proxy env PYTHONDONTWRITEBYTECODE=1 python3 \
  Research/OrderingAdoptionProbe/run_approved_pair.py \
  --artifacts LocalData/approved-pair-fresh \
  --writer LocalData/ordering-fresh/approved-pair-writer \
  --reader LocalData/ordering-fresh/read-position \
  --owner-reader LocalData/ordering-fresh/read-owners
```

The artifacts directory must first be populated by `capture_identity.py` and
its two original positions must still be exactly 995 / 581. Snapshot freshness,
identity and process guards fail closed. A pending apply without a restore
attempt can be recovered with the same binary and evidence directory:

```sh
rtk proxy LocalData/ordering-fresh/approved-pair-writer \
  LocalData/approved-pair-fresh restore
```

The executed trial passed relative swap/inverse and exact scoped preference
restoration. Both target AX coordinates returned with a common three-point
rightward shift also present in other owners; absolute geometry restoration and
human visual confirmation were not established in that initial unattended run.
The owner subsequently requested an attended repeat, confirmed readiness, and
visually confirmed that both the exchange and restoration looked perfect. The
repeat still measured a common two-point X translation, so exact absolute AX
geometry is a separate unpassed metric. Neither run assumes adjacent icons.
See the detailed result before drawing a product conclusion. The Python suite now has 44 tests;
the new native writer also passes four pure inverse/preservation checks.
