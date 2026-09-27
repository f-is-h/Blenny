# Disposable admission preference trial

Unsupported macOS 27 research, excluded from the product. Build `Trial.m` with
Xcode 27, `-DDEBUG=1 -fobjc-arc -Wall -Wextra -Werror`, and AppKit. Its disposable
application bundle must identify itself as `xyz.fi5h.blenny.admission-trial`.
Keep the bundle, snapshots, bookmark and receipt in ignored `LocalData/`.

**Observed limitation:** the first live write and the recovery write both
encountered same-process API/file disagreement at verification. A fresh reader
confirmed exact restoration after the inverse, including absence of the helper
row and unchanged other preference keys. The owner observed no disappearance
of BT, including no noticed brief disappearance, during the attended attempt.
Persisted denial therefore did not demonstrate live hiding. Do not treat the current executable
as a validated automatic visibility/restoration backend or repeat the trial
without resolving that verification behavior. See the
[investigation](../../docs/UNBUNDLED_MENU_EXTRA_COMPATIBILITY_0.12.0.md).

Run `AdmissionTrial --self-test` for nine deterministic state/inverse checks.
Normal arguments are an absolute private output directory and an exact-file
bookmark path. If the bookmark does not resolve to the expected file, the helper
requires an attended selection of only
`~/Library/Group Containers/group.com.apple.controlcenter/Library/Preferences/group.com.apple.controlcenter.plist`.
No whole-container or Full Disk Access request is made.

The application creates its own AppKit status item titled `BT`. Stop Blenny's
assessment management and confirm BT physically appears before pressing Run
once. That action snapshots the current independently agreed data, records an
inverse, changes only its own `isAllowed` flag to false, verifies once
after a 1.5-second settlement, and schedules restoration after 12 seconds.
Restore now and normal Quit also attempt restoration. There is only one apply
per process; restoration is limited to two write attempts. Do not use another
application or system-item identity as a replacement target.

If its row was absent, the proposal inserts only the exact helper bundle
location with `isAllowed = false`. The inverse removes that row, restoring
absence rather than inventing a previous true value. Tests cover exact encoded
restoration, removal while preserving unrelated edits, and already-removed
state. The first attended attempt stopped before any write because the original
probe required a pre-existing row; it was not a backend visibility failure.

For interrupted recovery, launch the same executable with the same output
directory, its current exact-file bookmark, and `--restore`. That mode does not
create a status item. It validates the receipt and restores only its target row,
preserving other current rows. An unchanged proposal restores the original
encoded bytes exactly. Target conflicts or failed readback retain the receipt
and stop. No background agent or crash-time automatic restoration is installed.

Physical disappearance/reappearance must be recorded by the owner. File/API
success alone is not a visibility pass. The helper's AppKit registration may
create a new system tracking row; its eventual cleanup must be accounted for
separately from restoration of the tested Boolean. Keep the helper and receipt
until that check is complete. This experiment does not validate Gaming, Wine,
three-state policy, or product lifecycle integration.
