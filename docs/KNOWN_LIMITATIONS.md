# Known limitations

## Experimental ordering scope

Version 0.10.0 ordering is available in Debug and the explicitly enabled optimized
owner-test build on the admitted macOS 27 runtime. Ordinary Release excludes it.
It is not a general guarantee for every application, monitor or future OS build.
Unknown identities and incomplete owner scope remain unsupported.

Siri, Time Machine and Control Center sorting is deferred. Their mapped three-state
visibility controls remain available in the experimental configuration; visibility
support does not imply ordering support. Clock and native overflow stay read-only.

Exact adjacency of the native overflow arrow and Blenny's controls is not
guaranteed. Preferred positions express relative order rather than fixed pixels.
Accepted order persists through Stop and Quit; those actions release concealment,
so they do not guarantee continued invisibility or arrow-relative placement.

## Clock cannot open Notification Center during management

On macOS 27.0 builds `26A5425a` and `26A428`, clicking the native menu-bar Clock does not open
Notification Center while Blenny management is active. Blenny's assessment-based
hiding backend activates a system restriction state. ControlCenter responds by
ignoring Clock menu events before they can request Notification Center. The Clock
is already included in the visibility allowlist, so
this is not an ordering failure or a missing-permission condition.

The owner's September 25 report reconfirms failure after Resume and recovery
after Stop on `26A428`. A bounded read-only recheck of the current runtime
contracts and both installed ControlCenter architecture slices retains the
same event gate. No compatible repair was found; see the
[formal-build recheck](NOTIFICATION_CENTER_TECHNICAL_REPORT_2026-09-12.md#formal-build-recheck-2026-09-25).
This round is closed without changing the hiding backend or adding automatic
suspension. The trackpad evidence below is from the earlier owner test, not a
fresh gesture test on every build.

The owner confirms that **swiping left from the right edge of the trackpad opens
Notification Center while Blenny management remains active**, even when Clock
clicks do not. Use this gesture on the tested setup; stopping management is not
required. This is owner-operated verification, not an automated test or a claim
about every hardware configuration or macOS build.

The failure is specific to the native Clock entry in this observation; it does
not mean Notification Center is generally unavailable. Static inspection locates
the suppression in ControlCenter's Clock event handler before its menu XPC
request. The complete gesture implementation has not been statically traced.

Blenny will not stop and resume management around Clock clicks. The owner
explicitly rejects that approach because it would release hiding restrictions.
Manual Stop remains an ordinary user control, not the proposed Clock repair.

The owner accepts this as a known limitation for `0.9.0`, so it is no longer by
itself a mandatory-fix blocker for that milestone. It is not a repair, version
closure, release permission, or a broader compatibility claim. Distribution and
public release still require the complete compatibility, recovery, disclosure,
privacy, signing, and repository gates in the roadmap and repository policy.

See the [final technical report](NOTIFICATION_CENTER_TECHNICAL_REPORT_2026-09-12.md)
for the exact cause and the [investigation record](NOTIFICATION_CENTER_RESEARCH_2026-09-12.md)
for the bounded searches and rejected alternatives. No compatible repair was
found in the final round; further parameter and delay trials are deferred beyond
0.9.0 unless new backend evidence changes the premises.

## Unmanaged extras may disappear after Resume

On macOS 27.0 `26A428`, Build 59 can Resume, but the active assessment backend
can suppress original menu extras even when Blenny does not manage or move
them. The owner accepts this as a known issue on 2026-09-27; it is not fixed,
and no backend replacement or automatic Stop/Resume workaround is adopted.

MenuBarAgent's assessment filter rejects status items with no application
Bundle ID before matching its bundle allow-list. The observed GamePolicyAgent
and Wine tray hosts have no application Bundle IDs. Build 54's signing-ID and
Build 58's containing-app-ID allow-list trials failed to preserve the physical
Gaming icon. Earlier physical evidence shows it returning after normal Quit.
Wine disappearance was owner-reported; a complete physical lifecycle matrix
for Wine was not independently established. Board/AX presence is not evidence
of physical visibility.

The native System Settings > Menu Bar > Allow in the Menu Bar mechanism is a
potential **supplementary hiding route**, not an override of assessment:

- The owner verified the disposable BT host's native switch hides and restores
  its original icon, and reports D4Mac's switch controls the Wine/Battle.net icon.
- The owner reports Usage4Claude and ChatGPT do not hide through their switches.
- Gaming and Now Playing have no corresponding entries in that application
  list. Now Playing retains its separate existing Blenny system-item route.

A helper process without a Bundle ID may still be attributed to an owning app
by the native settings mechanism; do not conflate that mapping with assessment
allow-list identity. Any supplementary integration needs exact owner/item
mapping, per-target physical hide/show evidence, and proven durable restoration.
It may affect multiple items belonging to one application.

Combining both mechanisms does not guarantee preservation after Resume:
assessment can still exclude an item that the native application switch allows.
Preserving these extras while managing everything else would require sufficient
non-assessment coverage or a genuine assessment exception, neither established.
Keep the current backend and the distinction between Visible, Revealable and
Hidden. Do not repeat failed allow-list guesses or promote the research writer.

The custom admission-preference trial did not physically hide BT. Its constructed
`menuItemLocations` differed from the native record, its in-process readback
disagreed with the file, and a temporary row later reappeared after point-in-time
restoration checks. Native switch success therefore does not validate that
writer. A later exact-row cleanup removed the research registration and verified
its absence after System Settings reopened. Reboot persistence and OS grant
revocation remain unverified, as does the full Stop/Quit/relaunch/reboot matrix
for a replacement backend. See the
[investigation and handoff](UNBUNDLED_MENU_EXTRA_COMPATIBILITY_0.12.0.md).

## Application location can prevent status-item bundle identity

On macOS 27 build `26A428`, the external-process identity route used by AppKit
checks whether MenuBarAgent can read the client's executable directory before
reading its bundle information. A denied check produces a nil status-item host
Bundle ID, which active assessment rejects even when the running application has
a valid Bundle ID and is present in Blenny's allow-list.

The owner-observed Betta Applications/desktop contrast now has matching read-only
sandbox evidence: global Applications is permitted; its desktop and development
`dist` paths are denied. Identical owned probe packages identify themselves
correctly in all tested locations, but MenuBarAgent's read check denies user
Applications, LocalData and temporary copies. This is a current-host access
restriction, not a universal hard-coded Applications requirement. Native admission
and Launch Services registration do not override the subsequent nil-ID filter.
Moving an app should be followed by quitting it and launching the installed copy,
because the host identity is stored when the status-item host is constructed.
See the [completed investigation](RESUME_VISIBILITY_INVESTIGATION_0.13.0.md) for
the identity chain, owned-copy checks and remaining physical-test limits.

The owner also enabled Full Disk Access for Blenny. The on toggle and a changed
Blenny process were independently observed, but MenuBarAgent's three Betta path queries
remained unchanged. This Blenny permission is not a remedy for the separate
MenuBarAgent reader restriction. Full Disk Access for MenuBarAgent itself was
not tested and must not be advertised as a verified repair.

## 0.10.0 local milestone

See [the release record](RELEASE_0.10.0.md) for accepted scope and remaining 0.11.0
validation. Saved-setting verification is distinct from independent physical
position verification. A stale accepted control-placement record needs explicit
review; it is not automatically overwritten. Unified Undo restores the latest
Apply but fails closed when policy or runtime identity has changed and does not
automatically resume management. Old order-only receipts retain their old scope.


## Now Playing is hidden by active management on macOS 27 build 26A428

The owner confirmed that Now Playing still fails to appear when expanded in
0.13.0 Build 67, despite a verified explicit-visible preference. The native
Control Center item has no assessment system identifier and is filtered while
assessment is active. This is separate from the missing application Bundle ID
case for Gaming/Wine. Blenny now offers recovery only for Now Playing, retaining
old receipts and saved intent without new visibility or ordering writes.
Exclusion from Blenny writes does not exempt it from macOS assessment filtering.
Stop management to release that restriction. See the
[0.13.0 investigation](TECH_SPIKE_0.13.0.md) for evidence and verification limits.
