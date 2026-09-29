# Technical spike 0.13.0: Product presentation and controls

Status: **Complete local experimental milestone**, 2026-09-29. The owner
authorized local closure after the menu, icon and Settings work and selected
1.0.0 as the next version, with final checks in a separate session. See the
[release record](RELEASE_0.13.0.md) for the final audit. No public release,
publication, or push is authorized. Earlier dated entries preserve their
original authorization and verification limits; the closure supersedes their
then-current prohibition on a local commit or tag.

## Scope and contract

Keep status-item click routing, management backend, serial writer, recovery
receipts, and editor draft behavior. The owner's later explicit selection of
v13 application artwork and the face-silhouette A menu bar design supersedes
the initial unchanged-icon constraint. Broader Debug feature cleanup remains
later work requiring explicit scope.

The owner additionally authorized the Settings layout correction described
below, preserving the fixed window, existing controls and update behavior.

The daily menu is:

- Open Blenny
- Expand Revealable Items / Collapse Revealable Items
- Resume Managing / Stop Managing, according to current state and saved intent
- Check for Updates (available only when the existing updater is ready)
- GitHub Sponsors
- Buy Me a Coffee (`https://ko-fi.com/blenny`)
- Website
- Debug submenu, compiled only under `#if DEBUG`
- Quit Blenny

The Debug submenu contains Refresh Menu Bar Items, the fallback-slot diagnostic,
Arm Next Click Check, Save Boundary Snapshot, Open Saved Snapshots, Position
Blenny Controls, and Undo Control Placement. Historical prototype status, when
that explicit experiment is running, also stays inside this submenu. Ordinary
Release has none of these menu entries; an optimized trial explicitly defining
`DEBUG` remains a Debug-capability build.

Remove the duplicate access/setup entry and permission status from the menu;
Open Blenny retains the existing onboarding and access interface. Refresh stays
in the Debug submenu; the ordinary editor refresh path is unchanged.

An active session offers Stop. An explicitly stopped session offers Resume.
A paused session with saved enabled intent offers both: Resume retries the
existing preflight, while Stop clears saved startup intent. Unknown and busy
states retain disabled actions. Reveal availability continues to follow the
existing native-overflow presentation. Hidden bundles remain excluded.

Disable AppKit automatic menu validation so it cannot re-enable actions guarded
by busy state, missing access, local drafts, or required observation refresh.
Stop remains available with an unapplied draft when the writer is idle; it does
not discard that draft. Restore Previous Visibility is removed from this menu.
The editor's existing restore and Undo/Recover Changes remain unchanged.
Quit continues through the application's existing termination and draft guards.

## Verification

Use Xcode 27 and macOS 27 SDK explicitly for both configurations. Core fixtures
cover active, stopped, paused, recovery and transitional menu visibility.
AppKit fixtures construct the actual menu with no-op action callbacks, exercise
state/draft/access/busy transitions and `NSMenu.update()`, and check the Debug
submenu presence or Release absence. These fixtures do not activate a management
writer or invoke a real restore, Stop, or Quit.

Build/test results and remaining attended checks are recorded below after the
verification run. Physical right-click interaction, VoiceOver, and real
Stop/Resume/recovery/Quit with an installed candidate are not established by
these fixtures. No installed app or existing user policy is replaced.

### 2026-09-27 automated results

- Explicit `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` selected
  Xcode 27.0 (`27A266a`), macOS SDK 27.0.
- `swift test --configuration debug`: build passed; 637 core tests and one
  actual AppKit menu test passed (638 total).
- `swift test --configuration release`: build passed; 335 core tests and one
  actual AppKit menu test passed (336 total).
- Neither build/test log contains compiler warnings or errors.
- Five development-action title literals are present in the Debug executable
  and absent from the ordinary Release executable. The Release AppKit fixture
  separately confirmed there was no Debug submenu.
- `git diff --check` passed. Logs remain ignored under `LocalData/0.13.0-menu/`.
- Not tested: physical menu rendering/right-click delivery, VoiceOver, installed
  candidate Stop/Resume/Quit, real restore, or draft-discard confirmation.
  Existing handlers and backend code are unchanged; automated restoration tests
  do not constitute a new live restoration trial.

### Owner-authorized installation follow-up

The owner requested packaging and replacement of the current application.
The previous installed package identified itself as 0.11.0 Build 59 despite
later milestone documentation. Xcode 27 produced **0.13.0 Build 60**, using the
same pinned local signing certificate and Debug capabilities. The packaged
ordering Board lifecycle self-check passed. Both packages passed strict deep
signature verification and have the same designated requirement.

After normal application exit, the previous package was backed up under ignored
`LocalData/0.13.0-menu/previous-Build59.app`. The new package replaced the existing
application at the same installation path and was launched. Installed metadata
confirms 0.13.0 Build 60 and the new process is running. Application-support file
hashes were unchanged across the replacement itself, before launching the new
application. This does not claim unchanged runtime state after startup or a new
physical management/recovery acceptance pass. No commit, tag or push occurred.

### Menu refinement

The owner approved combining Open Blenny and management status into one clickable
item, removing Restore Previous Visibility from the menu, and adding website
and support links. The existing product status presentation supplies all titles,
including stopped, active, paused and transitional states. Website uses the
existing project URL; Support Blenny contains the established `f-is-h` GitHub
Sponsors profile and `1atte` Ko-fi page. The menu Sponsors URL does not preselect
a contribution frequency, and identifies its placement as `menu`. Links open
through the default browser; no payment action is performed by Blenny.

Xcode 27 follow-up validation passed: Debug 638 tests and ordinary Release 336
tests, including actual AppKit menu state and link-destination assertions. The
packaged Board lifecycle self-check passed. Version 0.13.0 Build 61 was signed
with the existing certificate, verified, installed after normal Quit, and
launched. Build 60 is backed up in ignored local evidence. Application-support
hashes were unchanged during replacement before launch. Physical right-click,
external browser delivery and destination availability remain untested. No
backend or icon changes, version closure, commit, tag, or push were performed.

### Compact labels and top-level links

The owner superseded the combined status title: the first action now reads
only Open Blenny. Resume/Stop remain state-aware; the existing status detail
remains in the opening item's tooltip and the main window. GitHub Sponsors and
Ko-fi are top-level actions, followed immediately by Website. The Support Blenny
submenu is removed. AppKit fixtures check the stable opening title and exact
link order in both build configurations.

Build 62: Xcode 27 Debug 638 tests and ordinary Release 336 tests passed,
including the revised AppKit menu assertions. Packaged lifecycle self-check and
strict signatures passed. The same-signature Debug package replaced Build 61
after normal Quit and was launched; the previous package is backed up locally.
Application-support hashes were unchanged during replacement before launch.
Physical menu interaction and external link delivery remain untested.

### Menu appearance, icons and update entry

The owner requested Usage4Claude-style native menu icons, no external-link
arrow suffixes, and a manual update action. Read-only comparison found that
Usage4Claude uses 16-point template symbols and explicitly opts into macOS 27
menu image visibility. Blenny uses the typed macOS 27 `preferredImageVisibility`
API, with no compatibility fallback or private selector. Open Blenny reuses a
copy of the actual menu-bar artwork; all other action rows, including Debug
children, use template SF Symbols. Expand/collapse symbols follow their action.

Previously the menu had no explicit appearance and was positioned in the status
button's view. A dark status-bar host is a possible source of the reported dark
menu; the old live menu appearance was not measured. At each open, the menu now
uses the application's effective appearance, so the ordinary build follows
system light/dark mode rather than inheriting the status-button host. No fixed
light/dark theme or status-item artwork change is introduced.

Check for Updates uses the existing Sparkle controller and draft guard. Menu
availability also respects updater readiness and the interaction busy state.
This local package has no SUFeedURL, so the entry is disabled with an explanatory
tooltip. No feed URL is invented, no automatic update setting changes, and no
network check or update installation is exercised during verification.

Build 63 passed Xcode 27 Debug 638 tests and ordinary Release 336 tests,
including actual AppKit image visibility, light/dark appearance, update
readiness and draft/busy gating. Packaged lifecycle self-check and strict
signature verification passed. The same-signature package replaced Build 62
after normal Quit and was launched; Build 62 is backed up locally. App-data
hashes were unchanged during replacement before launch. Physical visual
acceptance, external link delivery and end-to-end Sparkle updates are untested.

### Menu anchor and sponsor color

The menu previously used `bounds.height` as its vertical anchor without checking
whether the status button was flipped. Both normal and historical Debug opening
paths now share the button's lower-edge anchor (maxY for flipped views, minY
otherwise), with screen-edge placement left to AppKit. No pointer movement or
synthetic input is used. GitHub Sponsors uses a red non-template heart; other
symbols retain template rendering. The update label is Check for Updates,
without an ellipsis. Physical placement acceptance remains an attended check.

Build 64 passed Xcode 27 Debug 638 tests and ordinary Release 336 tests,
packaged lifecycle self-check and strict signature verification. Installed with
the same signing requirement after normal Quit, with Build 63 backed up locally;
application-support hashes were unchanged during replacement before launch.
The new process was launched. Physical menu placement and red-heart appearance
remain unverified by these automated checks. No commit, tag or push occurred.

### Owner-requested reveal latency follow-up

The owner expanded scope to removing intentional expand latency, alongside a
filled red sponsor heart and removal of all context-menu item tooltips. Menu-bar
button tooltips and accessibility descriptions remain; native hover selection
is unchanged. The update entry remains disabled without a configured feed.

Source inspection confirms Spotlight already bypasses both one-second ordinary
reveal settlement waits in Debug (since Build 36). The current saved system
policy also assigns Now Playing to Revealable. That target still took both
one-second waits, and the shared writer processes it serially before the
assertion transition. This establishes a deterministic delay in the combined
reveal path, not a measured physical Spotlight-only latency diagnosis.

Debug ordinary Now Playing reveal now bypasses those fixed waits, matching
Spotlight and Time Machine. It uses the same synchronous exact-preference write,
CFPreferencesSynchronize and immediate independent writer capture. All exact
baseline comparisons, receipts, serial mutation, failure checkpoint restoration,
Stop, Quit and explicit recovery waits remain. No target or Release capability
is promoted. Tests cover immediate routing, exact cleanup, failed reveal rollback
and receipt preservation. Live reveal responsiveness still requires acceptance.

Build 65 passed Xcode 27 Debug 641 tests and ordinary Release 336 tests,
packaged lifecycle self-check and strict signature verification. Installed with
the same signing requirement after normal Quit; Build 64 is backed up locally.
Application-support hashes were unchanged during replacement before launch.
Real reveal timing and live cleanup/rollback were not exercised; the saved
management choice was stopped before replacement and was not explicitly resumed.

### Build 66 Now Playing suspension (superseded by Build 67)

The owner reports Now Playing absent both collapsed and expanded after Resume.
A live Board read identifies the exact Now Playing observation under
`com.apple.MenuBarAgent`; this is not the demonstrated nil-Bundle-ID case for
GamePolicyAgent/Wine. Preference capture alone cannot prove physical adoption.
The cause of the reported disappearance is unproven. Build 65's immediate
Now Playing reveal trial was not physically accepted and is superseded.

The owner's authorized fallback is to remove this item from management. It is
now read-only, with no three-state assignment, manual Hide, or new ordering
capability. Existing canonical identity decoding remains intact for exact
visibility and ordering recovery. Every legacy Now Playing Visible, Revealable
or Hidden policy projects to a restore-only plan in both baseline and reveal.
An existing receipt is restored and verified through the serial writer; without
a receipt no Now Playing preference is written and externally hidden native
state is accepted. Saved documents and old Undo receipts are not rewritten or
deleted during installation. The editor presents the suspended item in the
Visible/read-only area instead of falsely promising Revealable behavior.

Existing exact restore timing is retained for Now Playing. Spotlight and Time
Machine keep their previously established immediate ordinary-reveal path.
This suspension does not prove that the macOS assessment backend will preserve
the native icon physically; no system preference is guessed or force-enabled.
A subsequent physical Resume/expand observation remains necessary to determine
whether an independent assessment-level limitation also applies.

Build 66 validation: Xcode 27 Debug passed 643 tests (641 core and two AppKit),
ordinary Release passed 337 tests (336 core and one AppKit). Packaged Board
lifecycle self-check and strict signature verification passed. Tests cover all
legacy Now Playing policies projecting to restore-only, rejected assignment
and drag, disabled new sorting with retained identity decoding, receipt cleanup,
and leaving externally hidden state untouched after cleanup.

The same-signature package replaced Build 65 after normal Quit; Build 65 is
backed up in ignored local evidence. Application-support hashes were unchanged
across replacement before launch. The installed Build 66 Accessibility tree
shows Now Playing in the Visible read-only section with no Move/Hide/order
actions, and Spotlight remains editable in Revealable. Management stayed
stopped with no Draft. No live Resume, physical visibility, new preference write,
or live recovery was tested in this installation. No commit, tag or push.


### Build 67: investigate and repair before excluding Now Playing

The owner recalled earlier successful management and explicitly superseded the
Build 66 quarantine. Version 0.8.0 records owner-observed hiding and exact manual
restoration; this is historical evidence, not acceptance of the current reveal
path. Now Playing remains in the existing policy and ordering catalogs.

The ordinary reveal path previously restored the original snapshot, including an
absent/default preference, immediately after requesting visibility. That confused
temporary reveal with final restoration. Now Playing now retains explicit visible
bits (`0x2`, mask `0xA`) while expanded, preserving all unrelated bits. Before the
setter runs, receipt schema 3 records that exact owned reveal state. Collapse
returns to the hidden proposal; Stop/Quit/recovery restores the original snapshot,
including absence. Older receipt schemas remain readable; older app builds reject
schema 3 instead of guessing ownership. No assessment allow-list workaround,
polling, new target, or arbitrary delay is introduced.

Deterministic tests cover absent/default and unrelated-bit baselines, write-ahead
receipt persistence, exact crash recovery through a fresh writer, foreign drift
rejection, hide-after-reveal, and failed reveal compensation. Xcode 27 Debug and
ordinary Release tests passed (642 Debug tests and 336 Release tests). The
installed Debug app is 0.13.0 Build 67, with
unchanged designated requirement and valid deep strict signatures. Installation
preserved all application-support file hashes before launch.

An explicitly gated Debug-only validation delegate exercised only Now Playing
through the existing serial writer while management was stopped. PREVIEW captured
the absent-key baseline. APPLY observed hidden flags 8 with no exact AX item,
then visible flags 2 with the exact Now Playing AX item back at its baseline frame.
Final recovery restored the absent key, removed the receipt, and retained the AX
item. No assessment assertion or accepted-policy change was made. Observation
pauses exist only in this diagnostic harness, not ordinary reveal. Reports remain
under ignored LocalData. This confirms native preference/AX behavior; it does not
prove physical pixels or the full Resume/expand interaction under assessment.
The installed app is ready for that owner-operated acceptance.


### Build 68 follow-up: full managed reveal fails at native assessment filtering

The owner reports that Build 67 still fails to show Now Playing after Resume and
expand. During the attended expanded state, the application reported
`Revealable items expanded`, the current-host NowPlaying preference was exactly
2, and its schema 3 receipt held the expected visible reveal intent and original
absent baseline. Thus the reveal preference write occurred successfully; the
previous isolated test was insufficient to claim a full fix. A later AX capture
found no native Now Playing item but was already collapsed, so it is not cited as
independent AX proof of the expanded state. Owner observation supplies that part.

Read-only inspection of this host's macOS 27 build 26A428 explains the separate
filter. ControlCenter arm64e UUID is C7B60E84-3CC5-30CE-9090-C27E7FDB687D;
MenuBarAgent arm64e UUID is 9E3A0BA9-0E78-3C4E-B0E7-8B2BC1BD09C8. Static anchors
below are research evidence, never runtime addresses called by Blenny:

- ControlCenter's NowPlaying class descriptor at 0x10079fdc4 overrides Module's
  slot 0xa0 (method descriptor 0x100798a80) with 0x1000e851c, returning module kind 11.
- The Control Center item configuration caller at 0x1005a4f4c obtains the optional
  system identifier through 0x1005a587c and forwards it into the item constructor.
  The mapping subtracts 2 from the module kind and tests mask 0x2c8f. Bit 9 for
  Now Playing is clear, so this case returns an absent system identifier.
- MenuBarAgent's inspected FilterStep processes Control Center items separately
  from application status items. At 0x10000e7e4-0x10000e7ec it discards the absent
  systemIdentifier discriminator (11) before system allow-list membership.
  The matching metadata contains 11 concrete system cases and no Now Playing.
- The current MenuBarClientCore assessment enum only accepts raw values 0...8;
  there is no established Now Playing assessment identifier to add. Adding the
  AX presentation host's Bundle ID cannot affect this Control Center branch.

This is different from the nil application-Bundle-ID filter documented for
Gaming/Wine. Both are assessment limitations, but they use different item
collections and identifiers. No injection, numeric-ID guessing, entitlement,
agent restart, synthetic input, or global assessment release was attempted.
Releasing assessment during reveal would violate the Hidden policy boundary.
Historical 0.8.0 hide/restore acceptance does not establish compatibility of this
full path on the current runtime. A general replacement backend is outside this
menu cleanup and targeted investigation; no compatible exception was established.

The owner's fallback now applies: Now Playing policy assignment, drag and new
ordering are disabled, with an explicit active-management compatibility message.
Legacy policy identity and ordering identity remain decodable. Every saved Now
Playing policy projects to restoration in both baseline and reveal. Without a
receipt, externally hidden state is accepted and untouched. With a receipt,
including schema 3 from Build 67, exact baseline recovery remains mandatory.
The saved policy is not rewritten. This avoids further writes; it does not claim
that the original icon remains visible while other items are managed.


Build 68 verification: Xcode 27 Debug passed 644 tests (642 core plus two AppKit),
and ordinary Release passed 337 tests (336 core plus one AppKit). The packaged
Board lifecycle self-check passed, including a single live/recovery Now Playing
row, disabled policy controls, and retained exact receipt recovery. Regression
coverage includes all three legacy intents mapping to restore-only, rejection of
new assignments, untouched externally hidden state without a receipt, and schema
3 recovery through a fresh writer's managed restore plan.

Normal Quit of Build 67 completed exact recovery: the Now Playing key was absent,
all shared-item receipts were removed, and the native Now Playing AX item returned.
This is AX evidence, not a newly attended pixel-level Stop acceptance. Build 68
was installed with the same designated signing requirement and deep strict
verification. All application-support hashes remained unchanged during replacement
before launch. Startup resumed the owner's saved enabled choice. The installed UI
shows one read-only Now Playing card with the explicit assessment limitation;
the Now Playing preference remains absent and no Now Playing receipt is created.
Physical expanded display is unresolved by design in this fallback. No commit,
tag, version closure or push occurred.

### Build 69: isolated 0.8.0 Now Playing reveal timing comparison

The owner requested a direct comparison of the old reveal sequence after the
unmodified 0.8.0 optimized trial refused Apply on macOS build 26A428. That
version's assessment runtime only accepts 26A5416b or 26A5425a, so it cannot
exercise the current host without changing its private-runtime gate. Its manual
Hide/Restore acceptance did not establish ordinary reveal under management.

The current macOS 27 backend retains its runtime checks. A dedicated Debug-only
`BLENNY_NOW_PLAYING_LEGACY_REVEAL_TRIAL` build temporarily re-enables exact
Now Playing policy control. During ordinary reveal, it follows the 0.8.0
sequence: request visible, wait for owner settlement, restore the pre-hide
preference exactly (including an absent key), then wait for exact restoration.
The durable receipt and serial writer remain in force. Stop, Quit, and failure
recovery still require the original baseline. The flag does not alter Spotlight
or ordinary Debug/Release behavior. This is a timing comparison, not a proven
assessment exception or a product capability promotion.

Build 68 and its complete application-support directory were restored byte-for-
byte after the 0.8.0 comparison attempt. The old trial's separate data and app
were archived under ignored LocalData. A focused deterministic test covers the
legacy reveal, retained receipt, repeated hidden transition, and final exact
recovery. The owner then expanded Build 69 and reported that Now Playing still
did not appear. Immediately afterward, the app reported Management paused and
the key was hidden again; asynchronous cleanup subsequently removed the receipt
and restored the absent-key baseline. This is a failed end-to-end trial, not
proof that a stable expanded session completed the old sequence. Build 69 was
archived locally and the ordinary Build 68 app was restored and launched. No
second live mutation was attempted. The assessment limitation remains.

The same source follow-up also corrects an unrelated Resume Board warning. A
clean ordering layout that cannot rebind to changed policy scope now rebuilds
from captured rows; a dirty layout still fails closed with a specific draft
warning. The lifecycle self-check exercises the clean-policy-change path.

The ordinary Debug Build 70 (without the legacy trial flag) passed the packaged
Board lifecycle check and strict deep signature verification. Xcode 27 Debug
tests passed 644 cases and Release passed 337 before the final lifecycle-only
fixture was added; the packaged lifecycle fixture itself then passed. The
signed package replaced Build 68 after normal Quit, with no shared-item receipt
and no Now Playing preference key remaining. Application-support hashes were
unchanged across replacement before launch. The installed UI reports Build 70,
Management on, and Now Playing recovery-only. The owner has not retested a
subsequent Resume warning or the physical menu appearance on Build 70.

### Build 71: support label and Betta read-only observation

The top-level Ko-fi link and the Support page button now display **Buy Me a
Coffee**. Both still open the existing Ko-fi destination; no payment URL or
support action changed. Xcode 27 Debug and ordinary Release focused AppKit menu
tests passed (two and one cases, respectively). The packaged lifecycle check,
strict deep signature verification, and `git diff --check` passed. The signed
0.13.0 Build 71 replaced Build 70 after normal Quit through the existing
restoration path. No shared-item receipt or Now Playing preference key remained.
The previous package is backed up under ignored LocalData; policy, ordering-recovery,
and Control Center preference hashes were unchanged across replacement before
launch. The installed UI reports Build 71 with Management on. Physical menu
interaction and external browser delivery were not tested.

Betta was inspected read-only after its owner changed its identity and signing.
Its running process and strict-valid signed package use `xyz.fi5h.betta`; AX
exposes one `β✓` menu extra, and Blenny's Board observes it under Visible with
one item. A current screen capture still does not show that glyph. The saved
Blenny policy has no Betta Hidden assignment. Control Center's persisted
`trackedApplications` still contains only the former
`com.fish.betta.mvp`/`adhocBinary` path entry, with no new bundle entry. That
bundle-ID mismatch is a plausible cause, not proof of the private filter's
current identity. Blenny itself has an older `adhocBinary` path entry but a
matching bundle ID and remains visible, so `adhocBinary` alone is insufficient
to explain Betta. No Control Center preference, Betta binary, or management
backend was changed as part of this observation.

After a later macOS restart at 23:38, the owner moved the same signed Betta
package to `/Applications/Betta.app` and launched it at 23:54. The executable's
CDHash still matches the earlier `dist/Betta.app` inspection. The owner confirms
that its menu extra is physically visible, including after Resume. Blenny still
shows `xyz.fi5h.betta` as Visible and now reports a physical ordering mapping.
Control Center retained the former `com.fish.betta.mvp`/`adhocBinary` entry and
added a new allowed entry whose item location is the `xyz.fi5h.betta` bundle.
The old persistent record was therefore not cleared; a new bundle-scoped
registration appeared. Moving, relaunching, and the preceding system restart
were not isolated experimentally, so this does not prove that `/Applications`
is mandatory for macOS 27 menu extras or identify which event refreshed the
private admission identity. Blenny's normal management path does not require
target applications to reside under `/Applications`; its installation check
applies to Blenny itself. Apple's Launch Services documentation permits
registering an app by file URL and describes automatic discovery in Applications
folders: <https://developer.apple.com/documentation/coreservices/1446350-lsregisterurl>
and <https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/LaunchServicesConcepts/LSCConcepts/LSCConcepts.html>.

### Resume visibility investigation on the installed macOS build

The installed macOS build remains `26A428`, and MenuBarAgent's two Mach-O UUIDs
match the binary analyzed in `UNBUNDLED_MENU_EXTRA_COMPATIBILITY_0.12.0.md`.
With assessment active, that binary's status-item filter first rejects an item
whose `ComponentStatusItemClientElement.bundleIdentifier` is nil, then checks a
non-nil identifier against the assertion's allowed bundle set. System Control
Center items use a separate numeric allow-list. These are necessary filter
conditions, not a guarantee that an admitted item will have visible pixels.

Blenny's current planner includes accepted Visible bundles and observed running
unmanaged bundles in the baseline allow-list, includes Revealable bundles only
during reveal, and excludes Hidden bundles in both states. A newly launched
unmanaged bundle can be added to both active plans by the bounded pass-through
writer. The Xcode 27 focused policy, pass-through, and lifecycle tests passed
37 cases. A Board Visible row, a running process Bundle ID, and a valid code
signature do not establish that MenuBarAgent assigned that same ID to the
status-item element consumed by the filter.

Read-only historical logs sharpen the Betta comparison. When the signed
`xyz.fi5h.betta` process launched from `dist/Betta.app` at 21:16, MenuBarAgent
logged `SceneWorkspace clientDidConnectWith: ... Optional("xyz.fi5h.betta")`
and `Creating status item ..., isAllowed: true`, followed by
`No server elements for status item: nil`. No new bundle-scoped tracked-
application entry appeared, and the owner observed no physical Betta glyph.
After the move and relaunch from `/Applications/Betta.app` at 23:54, the same
Bundle ID string and `isAllowed: true` were logged, followed by
`Started to track application .bundle(xyz.fi5h.betta)` and
`No server elements for status item: Optional("xyz.fi5h.betta")`. The owner
then confirmed physical visibility after Resume. The old `com.fish.betta.mvp`
entry remained alongside the new `xyz.fi5h.betta` entry, so a deletion of the
old persisted cache entry was not the fix. The latter log's optional value is
a correlated host/item attribution signal; its exact correspondence to the
filter's stored `bundleIdentifier` was not dynamically instrumented.

The best-supported diagnosis is that the earlier Betta status item lacked a
usable bundle-scoped identity/registration at MenuBarAgent even though the
process itself had a valid Bundle ID and native admission allowed creation.
Before the desktop-copy contrast below, the move, relaunch, and preceding
reboot remained confounded, so neither a mandatory `/Applications` location nor
a specific cache invalidation event was proven. Existing visible Blenny and
ChatGPT registrations also contain
`adhocBinary` menu-item locations; that location type alone is not a failure
criterion. No Betta, MenuBarAgent, or Control Center state was mutated for
this investigation. An unattended new-host experiment was not used because it
would create another persistent system registration and physical visibility
could not be independently observed and durably restored in this session.

### Owner-operated desktop-copy contrast

On September 28 the owner reports copying the same Betta package to the desktop,
launching that copy, and observing its menu extra disappear after Blenny Resume.
The package equivalence is owner-attested; this investigation did not acquire
a new desktop-file grant or independently compare both copies' hashes.
RunningBoard logs confirm the desktop executable launched as PID 11933 at
07:59:06, followed by the `/Applications/Betta.app` executable as PID 12034 at
07:59:42. MenuBarAgent remained PID 698 throughout this contrast, eliminating
an intervening MenuBarAgent restart as the explanation for these two launches.

Both launches report `xyz.fi5h.betta` at the scene connection and
`isAllowed: true` during status-item creation. The desktop launch additionally
logs `Started to track application .bundle(xyz.fi5h.betta)`, but the later
status-item attribution log is still nil. The subsequent Applications launch
reports `Optional("xyz.fi5h.betta")` at the same log site. The persisted allowed
`xyz.fi5h.betta` row now contains the desktop executable as an `adhocBinary`
menu-item location, even after the Applications launch. Thus a correctly named
persisted bundle record, `isAllowed: true`, and its item-location encoding are
not sufficient to establish the live identity consumed by assessment.

The contrast materially strengthens a location/launch-resolution dependency
on this host: the same owner-attested package fails after Resume from the
desktop, while its Applications launch restores the non-nil attribution
signal. The earlier reboot and removal of a stale persisted record cannot
explain this fresh difference. It does not establish a universal prohibition
on every non-Applications path or isolate path classification from duplicate
bundle/path resolution. The exact private log field remains uninstrumented;
do not convert the correlated attribution log into an independently read
filter field. No product behavior or system preference was changed.

### September 28 follow-up: host identity fails at a sandbox path-read guard

The [completed Resume visibility investigation](RESUME_VISIBILITY_INVESTIGATION_0.13.0.md)
supersedes the unresolved path-versus-registration explanation above. Static
inspection now links the log's `sourceHost.bundleIdentifier` to the seventh
`ComponentStatusItemClientElement` field and traces AppKit's host construction
through `BSProcessHandle` to an executable-directory sandbox read check. A denied
check returns nil before bundle information is read. The path comes from the
scene client's audit token, not from a competing Launch Services registration.

Read-only queries for the running MenuBarAgent permit Betta's global Applications
directory but deny its desktop and development `dist` directories. Four identical
owned probe packages all read the same own Bundle ID, while MenuBarAgent's read
query permits only the global Applications copy and denies user Applications,
LocalData and the temporary copy. No status item was created; no `open` or
registration API was called. Created packages were removed and no probe tracking
record remained. The path-access restriction explains the owner's fresh Betta
A/B without a reboot or stale-record cleanup. It is an installed-build result,
not a universal non-Applications prohibition or a physical visibility proof for
the owned probes. Now Playing retains its separate system-identifier limitation.

The owner subsequently enabled Full Disk Access for Blenny. System Settings' on
toggle and a newly running Blenny process were verified read-only. MenuBarAgent
remained the same process, and fresh directory queries exactly matched the saved
pre-grant results: Applications permitted, desktop and `dist` denied. Thus this
Blenny grant did not change the identified identity failure. Full Disk Access
does not establish access through a separate process's App Sandbox; granting it
to MenuBarAgent itself and a new physical desktop lifecycle test were not tried.
See the report's Full Disk Access follow-up for evidence and source attribution.

### Dedicated Blenny Ko-fi account

The owner supplied `https://ko-fi.com/blenny` as the new app-specific Ko-fi
destination. The shared support-link constant now supplies that exact URL to
both the top-level context-menu action and the Support page. The owner-approved
**Buy Me a Coffee** label remains unchanged. This supersedes the earlier `1atte`
destination; GitHub sponsorship metadata and the website link are unchanged.

Xcode 27 Debug checks passed three focused cases; ordinary Release passed two,
including the exact support destination and actual AppKit menu binding. The
packaged Board lifecycle check and deep strict signature verification passed.
Signed 0.13.0 Build 72 replaced Build 71 after normal Quit, with the previous
package backed up under ignored LocalData. Application-support hashes were
unchanged across replacement before launch; the installed executable matches
the candidate and contains only the new Ko-fi URL. The designated signing
requirement is unchanged. The installed UI confirms Build 72 and Management on
after startup revalidated the saved enabled intent. External browser delivery
and payment flows were not exercised. No commit, tag or push occurred.

### Owner-selected application and menu bar icons

The owner explicitly selected the v13 exploration's
`09-natural-cirri-connection.png` and `BlennyMenuBarFaceSilhouette-A.svg`.
This supersedes the initial unchanged-icon scope. The production application
PNG is a 1024-by-1024 resize of the supplied 1254-by-1254 image, with no crop or
artwork edit. The existing build derives all ICNS resolutions from that PNG;
an SVG master is not required. The historical v12 SVG remains preserved and
is not a source for the new icon.

The menu bar production asset preserves A's face silhouette, cirri, transparent
eye whites, pupils, and absence of a mouth. It applies the established 0.2.0
optical-size correction: an explicit 18-point canvas, a centered square view
box without stretching, and direct even-odd eye cutouts instead of the design
source's SVG mask. Status-item allocation, click routing, template rendering,
and the 16-point Open Blenny image reuse are unchanged.

Verification used Xcode 27.0 build `27A266a` and SDK 27.0 explicitly:

- Signed Debug **Build 73** and ordinary Release **Build 74** packaged
  successfully, target macOS 27, and pass deep strict signature verification.
  Both contain identical ICNS and menu bar SVG resources.
- Three focused Debug cases and two ordinary Release cases passed, covering
  actual AppKit menu state/draft gates, image presence, and support bindings.
  The packaged Board lifecycle self-check passed.
- AppKit decoded the packaged ICNS and SVG. Black/white template rasters at
  18 and 16 points, each at 1x and 2x, were inspected; they contain nonempty
  silhouettes without edge clipping. Application artwork was inspected at
  32, 64, and 128 pixels. These are offline render checks.
- Debug Build 73 replaced the installed Build 72 after normal Quit. The previous
  bundle and application-support files were backed up under ignored LocalData.
  Support hashes were unchanged across replacement, and the installed executable
  and resources match the candidate. The designated signing requirement remains
  unchanged.
- The first installed Board still showed the old application artwork, and a
  separate public `NSWorkspace.icon(forFile:)` query reproduced it despite the
  correct new ICNS. Force-registering the app alone did not refresh that result.
  Updating only Blenny's bundle-directory timestamp and force-registering that
  path refreshed the public icon lookup. A normal relaunch then visibly showed
  the new artwork in the Board. No global cache reset or unrelated process
  restart was performed.
- The installed UI confirms Build 73 and Management on after normal startup
  revalidated the saved enabled intent. All nine pre-existing application-support
  files remain byte-identical after the final launch; startup added the expected
  active Spotlight recovery receipt. No Apply or arrangement action was used.

Live menu bar pixels, highlighted/disabled menu icon appearance, Finder and Dock
display, and additional displays/scales were not inspected. The live Board check
does not claim that wider visual acceptance. Evidence remains ignored under
`LocalData/0.13.0-icons/`. No management backend code, commit, tag, version
closure, or push was part of this icon change.

### Alternate application artwork trial

The owner requested trying `11-balanced-rock-water-window.png` instead of the
previous `09-natural-cirri-connection.png`. The production PNG is a 1024-pixel
resize of the new 1254-pixel source, preserving its full composition. This is
the current installed artwork trial, not final visual acceptance. The
face-silhouette A menu bar resource remains byte-identical.

Xcode 27 and SDK 27 produced signed Debug **Build 75** and ordinary Release
**Build 76**. Both packages pass deep strict signature verification, preserve the
designated signing requirement and macOS 27 target, and contain identical new
ICNS resources. AppKit decoded the new packaged icon, and 32/64/128-pixel renders
were generated; the 128-pixel artwork was inspected. No product code changed,
so the previously passing menu tests were not repeated for this raster swap.

Build 75 replaced the installed Build 73 after normal Quit, with the old bundle
and support data backed up under ignored LocalData. Support bytes were unchanged
across replacement and after startup. Updating Blenny's directory timestamp and
force-registering only that app path refreshed the public Workspace icon lookup
before launch. The running Board visibly shows the new artwork and Build 75.
Startup reported **Management paused**; no forced Resume was performed and its
cause was not investigated as part of this icon trial. Finder/Dock appearance
and additional display acceptance remain untested. Evidence is ignored under
`LocalData/0.13.0-icons/11-trial/`. No commit, tag, version closure or push occurred.

### Settings fixed-height layout correction

The owner approved the alternate application artwork and reported broken
Settings layout after the Updates section was added. The third section retained
spacing designed for two sections: the complete SwiftUI root naturally required
487 points at both 560- and 680-point widths, exceeding the established
420-point window. An initial regression run reproduced the failure in all eight
permission, updater-availability, and width combinations.

Settings now uses 12-point spacing between sections, 5-point section-header
spacing, and 40-point minimum row heights. The original 28-point top inset is
preserved to align page headings; the bottom inset is 12 points. Support retains
the section component's existing 10-point default. All three Settings sections
fit the original window without page scrolling. The Settings update button now
reads **Check for Updates**, matching the context menu's punctuation preference.
Update availability, feed/check behavior, login-item handling, permissions,
management policy, recovery, and draft protection are unchanged.

Verification used Xcode 27.0 build `27A266a` and SDK 27.0 explicitly:

- A real `NSHostingView` regression matrix covers 80 combinations: 560/680-point
  widths, granted/missing Accessibility, available/unavailable updater, five
  startup states including approval and failure messages, and light/dark
  appearance. Natural height is 393–403 points, and rendering invokes none of
  the supplied permission, login-item, or updater actions.
- Focused Debug checks passed 13 test functions; ordinary Release passed 12,
  including presentation, actual AppKit menu gates, and the layout matrix.
  After preserving the original top inset, the affected 80-case layout matrix
  passed again in both configurations. Offscreen captures were inspected for
  Settings content fit; they do not verify the installed native window pixels.
- Signed Debug **Build 79** and ordinary Release **Build 80** packaged
  successfully, target macOS 27, and pass deep strict signature verification.
  Both icon resources and the designated signing requirement remain unchanged.
  The packaged Board lifecycle self-check passed.
- Build 79 replaced the installed intermediate Build 77 after normal Quit.
  The pre-change Build 75 package and support data remain backed up under ignored
  LocalData. Application-support hashes were unchanged across replacement;
  the installed executable matches the candidate. The running UI confirms
  **0.13.0 Build 79** and **Management on** after normal startup. All nine
  pre-existing support files remain byte-identical after launch, including the
  accepted ordering recovery record. Startup added the expected active Spotlight
  recovery receipt. No Apply, arrangement, or forced Resume action was used.

Installed Settings route interaction and native-window visual acceptance remain
unverified: keyboard navigation did not reach the page, and no synthetic click
was used. Additional displays, real update-network/download behavior, login-item
registration changes, and permission changes were not exercised. Evidence is
ignored under `LocalData/0.13.0-settings/`. No management backend or persistence
change, commit, tag, version closure, or push occurred.
