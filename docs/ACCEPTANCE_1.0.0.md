# 1.0.0 acceptance matrix

Support is limited to Apple silicon and macOS 27. Test environments are recorded
here rather than on the README homepage; this is not a future-macOS promise.

| Environment | System | Evidence |
| --- | --- | --- |
| Native Apple silicon host, earlier runs | macOS 27.0 (26A428) | Earlier physical menu-bar and Sparkle observations below |
| Native Apple silicon host, current runs | macOS 27.0.1 (26A434), Xcode 27.0 (27A266a), SDK 27.0 | Current deterministic tests, builds and signed-package checks |
| Fresh Parallels guest, English | macOS 27.0.1 (26A434) | Build 113 regression reproduction and owner-confirmed Build 114 fixes |

Tests and preference readback do not establish physical visibility. No new live
third-party or critical system-item write is claimed.

On 2026-09-30, when authorizing formal 1.0.0 source closure, the owner explicitly
confirmed all requested development checks were completed except multiple
displays. Fresh installation/access, grant revoke/regrant, first Apply/Undo/
relaunch, login, uninstall/restoration and sleep/wake are owner-observed passes.
Multi-display behavior remains unverified. The current product digest and notes
hash bind that acceptance; no new agent action trace or Build 116 physical run
is inferred. The earlier build-specific evidence below retains its original scope.

On 2026-09-30 the owner reported completing real-menu-bar acceptance of ordinary
Release Build 107. This is owner-observed evidence; no per-target action trace was
provided. Build 108 adds a narrowly scoped first-Undo/relaunch correction. Its
normal installed startup is verified locally; the fresh macOS 27 VM run below
remains a separate acceptance run.

The final development-stage package also changes version display and packaging.
Use the new development DMG recorded in RELEASE_1.0.0.md for the guest run.
Record these observations before the formal GitHub release trigger in
release-acceptance.json; its product digest binds them to the tested configuration.
Public GitHub builds have automated checks only, with no later owner gate.
The final owner confirmation above supersedes pending attended rows below.
Workflow implementation and local linting do not establish a hosted success.

The owner's English macOS 27.0.1 Build 113 VM run exposed persistent lane
scrollbars and failed native-chevron takeover. These are confirmed regressions:
the lanes now use never-visible indicators, and classifiers recognize the actual
MenuBarAgent English expanded label and Japanese expand/collapse pair. The
resource-label regression fails before the repair and passes afterward. On
2026-09-30 the owner reported testing the replacement package and confirmed the
reported problems were resolved. This closes the English-guest regression cases,
without inferring Japanese physical coverage or broader permission/lifecycle tests.

| Check | Current evidence | Status |
| --- | --- | --- |
| Debug / ordinary Release product capability parity | Shared product gates, catalogs, recovery tests and AppKit menu tests | Verified locally |
| Fixed application identity and nested signing | Deep strict/pinned-requirement package gate | Verified locally |
| Device Control from installed path | LaunchServices support command at /Applications; original installation restored | Verified locally |
| Existing stale exact-file bookmark | Exact target validated, scope acquired, one renewal persisted; subsequent launch active | Verified locally |
| Revoked/wrong-file grant and failed renewal | Deterministic operation fixtures; saved bytes/prior active scope retained | Verified in tests |
| Policy/order Apply, Undo and drift | Deterministic coordinated writer, schema, inverse, failure and restoration coverage; owner reports completed Build 107 real-menu-bar acceptance | Tests passed; owner-observed Build 107 acceptance |
| Hidden excluded from ordinary reveal | Policy/reveal tests; owner reports completed Build 107 real-menu-bar acceptance | Tests passed; owner-observed Build 107 acceptance |
| Native overflow takeover and collapse | All 40 resource locale entries exercised through classification and the management loop; owner confirms Build 114 fixes in the English macOS 27.0.1 guest | Tests passed; owner-observed English-guest acceptance |
| Policy lane scroll indicators | SwiftUI never replaces hidden; owner confirms the reported lane scrollbar problem is resolved in the replacement package | Tests/builds passed; owner-observed guest acceptance |
| Interrupted Apply/restore | Deterministic checkpoints and durable receipt tests; no fault injection against a real third-party owner | Verified in tests |
| First Apply with no saved policy | Shared-store repair, initial backup, sparse Undo and Restore Visibility tests; Build 107 owner acceptance; Build 108 active/stopped first Undo and resume tests, negative missing-backup tests, normal installed startup reports Management on with all three state-file hashes unchanged | Tests and installed startup passed; owner-confirmed fresh-VM acceptance |
| Draft/update interactions | Actual Sparkle delegate methods tested for manual, background and information checks; termination/draft tests retained; standard UI uses the actual ApplicationUpdater in a manager-free test fixture | Guards verified in tests; standard UI install/relaunch observed locally |
| Standard Sparkle update window | Version/release notes inspected; keyboard confirmation downloads, extracts, installs and relaunches Build 101→102; signed target executable and state preservation verified | Install/relaunch passed; dialog dismissal by keyboard not established |
| Sparkle A→B replacement/relaunch | Real loopback installer run, executable/build/identity/key checks | Verified locally |
| Cancel/equal/older/unavailable feed | Real loopback Sparkle checks | Verified locally |
| Invalid signature/damaged package | Real Sparkle rejection and direct EdDSA tamper rejection | Verified locally |
| Policy/recovery preservation during updates | Full app-owned file hashes unchanged; Sparkle preference keys restored | Verified locally |
| Fresh installation and first launch | Owner confirms fresh-install/access acceptance on 2026-09-30; exact quarantine provenance was not separately supplied | Owner-observed acceptance; download provenance not inferred |
| Login / revoked OS grant / sleep | Owner confirms these development checks completed on 2026-09-30; no agent permission/sleep mutation | Owner-observed acceptance |
| Multiple displays | Owner explicitly excluded this hardware coverage | Unverified; accepted coverage limit |
| Uninstall and restoration | Owner confirms development check completed on 2026-09-30; agent retained the host daily app | Owner-observed acceptance |
| Public HTTPS asset/feed access | Repository remains private; root feed has no unpublished item | Awaiting publication |

## Attended final run

Use the final candidate, with no second Blenny manager. Begin with owned test
applications. Record exact approved real targets and their complete current
configuration before a real write; do not include Clock or unsupported identities.
Preserve the original app and all recovery data. Stop immediately if restoration
cannot be verified.

1. Install the candidate in Applications, launch normally, and confirm no access
   error. If macOS actually revokes access, regrant through the exact-file picker
   and Device Control UI; do not delete TCC records.
2. Confirm the physical icons for Visible, Revealable and Hidden. Expand/collapse
   and verify Hidden never enters ordinary reveal.
   In the English VM, verify only the system chevron remains when it is usable;
   after expanding through Blenny's fallback, use the system chevron to collapse
   and confirm that Revealable icons return to their concealed baseline. Repeat
   from native collapsed state. Check all three lanes with a mouse and with the
   system's automatic/always scroll-indicator setting; horizontal scrolling and
   item movement must remain usable without persistent lane scrollbars.
3. Review a within-area order and a cross-area policy/order draft. Apply once,
   inspect the physical bar, Undo, and verify complete touched-state restoration.
4. Repeat a reviewed Apply. Change an approved target outside Blenny and confirm
   stale Undo/preflight is rejected or explicitly reviewed. Restore the baseline.
5. Exercise Stop, Resume, normal Quit and next launch. Check actual physical
   visibility separately from accepted-state/Board presence.
6. Make a draft and try Quit and update checks; verify discard/apply protection.
   The standard Sparkle install/relaunch UI is already verified in a disposable
   loopback fixture; review guest-specific interaction or dismissal as needed.
7. Where available, revoke/regrant access, sleep/wake and change displays. Treat
   unavailable hardware cases as unverified rather than passed.
8. Undo any test changes, disable test login registration, Quit and verify the
   baseline and receipts. Record build, targets, action, result and restoration.

The owner-reported Build 107 acceptance above supersedes the earlier pending
real-menu-bar status. The final owner confirmation at the top closes the separate installation,
permission and lifecycle checks, retaining the multi-display coverage limit.
Do not mark the release complete or create its final tag until the required
acceptance and authorized Git closure are finished.

## Fresh macOS 27 VM plan

Use the newest development-stage DMG listed in RELEASE_1.0.0.md. The owner confirmed the new Parallels guest is
macOS 27. Keep the guest installation independent from the host's Blenny state.
Do not install another menu-bar manager alongside Blenny.

Install these applications from their official sources:

| Application | Role | Initial setup |
| --- | --- | --- |
| [Itsycal](https://www.mowglii.com/itsycal/) | Single calendar item | Keep its date icon enabled; calendar account integration is unnecessary |
| [Maccy](https://github.com/p0deje/Maccy/releases) | Single application item | Keep the menu-bar icon enabled; clipboard paste automation is unnecessary |
| [Stats](https://github.com/exelban/stats/releases) | Multiple items owned by one bundle | Enable separate CPU, RAM and network items; do not combine them into one item |

VM sensor readings are not an acceptance requirement. If a particular widget is
unavailable in the guest, use two other working independent Stats widgets.
Before installing Blenny, launch the three apps, allow their menu-bar items in
System Settings if necessary, capture the physical baseline and take a VM snapshot.
Record the actual app versions and owner bundle IDs shown in Blenny.

1. **First launch and access:** install in Applications with no prior Blenny
   data. Check the initial access guidance before granting Device Control and
   choosing the exact layout file. Decline access once, then grant it through the
   normal user interface. There must be no false success or required Screen
   Recording grant. A shared-folder copy is suitable for functional testing;
   it does not by itself prove browser-download quarantine or Gatekeeper behavior.
   Record first-launch provenance and test the quarantined browser-downloaded
   package separately when that download route is available.
2. **First Apply and Undo:** approve only the three installed test applications.
   Set Itsycal to Visible, Maccy to Revealable and Stats to Hidden. Apply once.
   Inspect actual icons in collapsed and expanded states: Visible remains shown,
   Revealable appears on expansion, and every Stats icon remains Hidden. Undo
   immediately while management remains active; quit and relaunch. Confirm no
   missing-backup warning and a usable Board. Repeat Undo after Stop.
3. **Rotate the roles:** move each app through all three states. Stats is managed
   as one owning application; its icons must share the policy. Per-icon control
   within Stats is out of scope.
4. **Order and restore:** with both single-item apps visible, perform a reviewed
   same-area exchange and a cross-area move. Apply, inspect the physical bar and
   Undo. Test Stats ordering only when Blenny offers a complete attributable
   group; record a refusal instead of treating unsupported geometry as success.
5. **Lifecycle and drafts:** apply a reviewed policy; quit/reopen one test app,
   then Blenny. Check Stop/Resume and guest logout/login, including the explicit
   Open Blenny at Login setting. Make an unapplied draft and exercise Quit and
   Check for Updates to verify protection. Standard-window installation is already
   covered locally; guest window dismissal may be checked separately. Revoke/regrant one access permission
   through System Settings; do not reset TCC databases.
6. **System items:** after third-party restoration succeeds, use Sound as an
   explicitly approved noncritical target if it is present and editable. Record
   its original state, apply one group change and restore it. Keep Clock read only
   and leave critical Control Center/Wi-Fi items out of the first mutation run.
   VM-absent Bluetooth, battery or display hardware cases are not failures.
7. **Uninstall and recovery:** Undo test changes, verify all touched settings
   against the baseline, Stop, disable login registration, Quit and move Blenny
   to Trash. Retain recovery data until restoration is verified. A VM snapshot
   is an additional reset mechanism, not evidence that Blenny restored the state.

For each step record build, approved targets, action, expected and observed
physical behavior, any error, and verified restoration. Screenshots and raw
reports belong in ignored local evidence. VM display/suspend results do not
establish physical multi-monitor, notch or host sleep/wake behavior.
