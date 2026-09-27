# Technical spike 0.12.0: Spotlight visibility and ordering trial

Status: **Build 59 restores startup and explicit Resume in the observed layout.
The owner accepted that unattributed icons may disappear during active
management; they remain read-only and are never writer targets. The earlier
draft was discarded by owner direction. The owner observed Spotlight sorting,
and the attended Visible / Revealable / Hidden trials passed on this macOS 27
host in Build 35. The owner reports no expand/conceal wait in Build 36.**
This is not Release promotion or a claim that macOS 27 provides a public
cross-process system-item API. The Build 50-58 activation-guard history below
records the earlier visibility-preservation requirement, which the owner
superseded for Resume in Build 59.

## Build 44 observation and recovery follow-up

The owner moved Now Playing to Revealable in Build 41. Its current-user,
current-host `com.apple.controlcenter:NowPlaying` value became `8`, matching the
applied hidden receipt and saved Revealable policy. This is the intended hidden
state while collapsed, not evidence of a failed signature or lost preference.
Build 41 simultaneously displayed two Now Playing Board cards and disabled
their policy and ordering actions. One was the observed exact
`com.apple.MenuBarAgent` item; the other was a synthetic recovery card using
the `com.apple.controlcenter` writer owner. The duplicate check compared owner
strings before resolving their shared canonical target. Build 44 suppresses
the synthetic card when one live, owner-verified observation already represents
that target. It retains duplicate-observation fail-closed behavior and an
absent-item recovery card. A packaged lifecycle self-check covers the live
agent item plus recovery receipt; the installed Build 44 Board shows one Now
Playing card with three-state and sorting actions. No new Now Playing drag or
Apply was performed after this repair, so physical reveal and the inverse
remain an attended validation step.

The owner also reported two missing menu-bar icons. On this host the Wine tray
host and Apple's `/usr/libexec/GamePolicyAgent` each exposed one top-level
`AXMenuBarItem` / `AXMenuExtra`. Both running processes lacked an application
Bundle ID and the items had no AX identifier or title. This does not mean they
have no identity: the game host executable is Apple signed with code identifier
`com.apple.GamePolicyAgent`; the Wine loader inside D4Mac is signed with code
identifier `com.codeweavers.CrossOver.wineloader`. The observed Wine menu-extra
process was `explorer.exe /desktop`, while a separate Battle.net process was
running in the same bottle. A later native Accessibility read found the Wine
item's `AXHelp` was `战网` (Battle.net), identifying the presented tray item
more specifically. It does not turn the Wine loader into an application Bundle
ID or a recovery-backed writer target. `GameOverlayUI` was running but
had no `AXExtrasMenuBar` or AX child at the inspected instant; the observed
game-related icon belonged to GamePolicyAgent. The ordinary process filter
excluded these prohibited-activation-policy hosts. Build 44 includes such
unbundled processes in the bounded read-only scan and shows their observed
items as transient, read-only, unidentified cards. Their PIDs never enter the
policy candidate inventory, saved policy, ordering plan, or writer targets.
The initial cards used a fallback glyph and live process name. The follow-up
presentation names the observed Apple host and Wine loader. When the single
Wine item reports exactly `战网` or `Battle.net` as AX help, its read-only card
displays Battle.net. Neither card is promoted to a policy or ordering target;
the game item still lacks an exact control identity. The first game-card SF
Symbol `rocket.fill` was absent on this macOS runtime and was replaced with
verified `gamecontroller.fill`. Build 43
temporarily allowed unknown-owner issues into policy preflight and paused
management at startup. Build 44 isolates those observations from preflight;
the installed app resumed management, retained the accepted policy, and showed
both read-only cards.

Build 44 passed 633 Xcode 27 Debug tests in 58 suites, packaged Board lifecycle
self-check, ordinary Release compilation, and strict installed signature
verification. The accepted policy file and ordering recovery receipt were
byte-identical before the Build 41 replacement and after Build 44 startup.
Now Playing remained Revealable with its recovery receipt present. No TCC
reset, ordering Apply, or new system-item write was used for this investigation.
The read-only physical sample taken before Build 42 placed the Blenny arrow at
`x=1146`, fish at `x=1184`, and the next visible WeChat item at `x=1214`;
the macOS `com.apple.menuextra.clock` item was the rightmost sampled item at
`x=2010`. Those frames do not establish permanent pinning or explain a
different expanded layout. The nearby date/time text was owned by Dato, not
by the macOS Clock item. Arrow-relative fish placement and any observed
Clock/date-time discrepancy need an exact state-specific reproduction before
a position write can be proposed.
The unbundled Wine and GamePolicyAgent items were sampled at `x=884` and
`x=913`, left of the arrow despite being physically visible. A later Build 47
read-only boundary export, taken while management was paused after an active
Space change, put CleanShot X at `x=766` (Revealable), Wine at `x=809`
(Visible), GamePolicyAgent at `x=838` (Visible), Tailscale at `x=879`
(Revealable), Blenny's double arrow at `x=1053`, and fish at `x=1124`.
The groups are interleaved in this saved layout; moving only Blenny's controls
cannot separate every subject. The exact configuration has scalar keys for
GamePolicyAgent and the signed Wine loader, but the current resolver has not
established an eligible owner-bound sorting target for either. A present key
alone is not write authority. The follow-up candidate preflight therefore
rejects an observed unbundled menu extra before proposing a persistent control
position, with a deterministic regression test. This prevents the explicit
placement action from claiming complete separation that it cannot verify.
The 0.10.0 owner-
accepted Position Blenny Controls operation persists arrow/fish preferences at
the configured gap and follows later Apply/Undo only while its clean placement
receipt exists. The current 0.12.0 support directory has no such receipt, so
that follow-up is dormant. Its candidate calculation also excludes unbundled
processes because they have no verified owner-bound ordering identity. Thus the
earlier success for attributable ordering subjects cannot establish a physical
separator for these newly observed items. Do not infer that the old positioning
mechanism never existed, and do not reposition the controls from geometry alone.
The Build 44 draft was discarded at the owner's direction before its normal
Quit and same-requirement replacement by Build 47. Build 47 showed Clock last
in the Visible Board lane and the two read-only owner cards. Its saved policy
could be resumed. A separate read-only command-line process could not open the
exact preference file under its own access context. The UI later reported
`The active Space changed.` and failed closed; the normal app could still
export the boundary with its existing grant. No TCC reset or preference write
was used. Physical boundary placement remains unaccepted because the saved
subject order has no complete group gap.

The macOS Clock is the observed rightmost physical system item on this host.
The Board previously sorted residual system items by display name, placing its
Clock card before Control Center and Siri. The follow-up pins the read-only
Clock card to the far right of the Visible Board lane, after transient owner
cards, without attempting to write Clock position or changing Dato.
Signed Build 47 has the same designated requirement as Build 44 and passed
strict code-signature verification, 633 Xcode 27 Debug tests in 58 suites,
the packaged Board lifecycle self-check, and ordinary Release compilation.
Clock's Board placement was verified in the installed app before and after a
manual Refresh. Build 48 repeats those automated gates for the help-hint and
symbol correction. Its installed UI displayed Battle.net under Wine ownership,
Game under Apple GamePolicyAgent ownership, and Clock last in the Visible lane;
the saved management policy resumed at startup. No sorting Apply was used.
Build 49 passed 634 Xcode 27 Debug tests in 58 suites, the packaged Board
lifecycle self-check, ordinary Release compilation, and strict installed
signature verification. It retained the same designated requirement and
installation path. The installed Board still displayed those cards and Clock
last, and saved management resumed after the final active-Space interruption.
The new Position Blenny Controls rejection was verified by deterministic test;
an attended live attempt was not completed, so it is not marked as a physical
boundary acceptance.

## Build 50: unattributed items during Resume

The assessment configuration admits application Bundle IDs and known system
item numbers. The observed Wine and GamePolicyAgent menu extras have no
application Bundle ID and are not proven members of the known system-item
allow-list. The owner's observation that they disappear after Resume is
consistent with the assertion excluding them; a Board card is read-only
discovery, not an allow-list entry. After exclusion, a new AX scan may also
lose the transient Board cards. This is a visibility-assertion boundary, not
evidence of lost TCC authorization, an invalid bookmark, or a changed signing
requirement.

Build 50 gives the Wine-owned Board card the available `wineglass.fill` system
symbol for both the generic Wine and Battle.net-help presentations. This is
semantic artwork only; it does not identify or manage the Windows program.
The bounded ownership snapshot now blocks startup activation and fresh
Apply/Resume activation when an unbundled menu extra is observed. It names the
count and reason, keeps management unrestricted, and asks for Refresh before
a later Resume. No unverified signing identifier, PID, or preference key is
inserted into the assertion. Build 51 also counts an unattributed extra in
the bounded application-launch scan so an observed new item triggers the
existing fail-closed cleanup. Whether the active assertion can suppress a
new item's AX observation before that scan remains untested.
Build 52 scopes the fresh-snapshot guard to operations that activate or
replace the visibility assertion. A policy Undo that leaves management off
retains its recovery preflight without being blocked by these extras. That
Existing Undo tests passed, but the unbundled-item Undo combination was not
exercised as a live ordering or policy mutation in Build 52.

Build 50 passed 634 Xcode 27 Debug tests in 58 suites, the packaged Board
lifecycle self-check, and strict signature verification. It replaced the
paused, draft-free Build 49 at the same path with the same designated
requirement. On startup it stayed paused while the Game and Battle.net cards
remained visible. An attended Resume reported two unattributed menu extras and
did not activate management; both Board cards remained. The accepted policy
and previous-policy backup hashes were unchanged across replacement and this
rejected Resume. Keeping these icons visible while management is active is not
validated; the current safe behavior is to decline activation in this layout.
Build 51 retained the same signing requirement and installation path, passed
634 Xcode 27 Debug tests in 58 suites, ordinary Release compilation, packaged
Board lifecycle self-check, and strict signature verification. Its installed
startup and attended Resume again stayed paused with both read-only cards
present, and the accepted policy and backup hashes remained unchanged. No
third-party or system-item visibility mutation was used to trial an unverified
allow-list identity.
Build 52 passed the same 634 Xcode 27 Debug tests, ordinary Release
compilation, packaged Board lifecycle self-check, and strict signature check.
It retained the designated requirement and installation path. Installed
startup and one attended Resume left management paused, retained both cards,
and reported the same two-item activation reason; no ordering Apply or Undo
was performed.

Build 53 corrected a separate Board refresh defect: explicit Resume recreated
the editor model from a fresh candidate inventory without carrying forward
the fresh `unattributedItems`. A Debug-only bypass of the activation guard
confirmed that the Game and Battle.net read-only cards can remain on the Board
while management is active. It did **not** preserve their physical menu-bar
icons. The post-activation Accessibility inventory continued to report both
extras, so AX presence is insufficient proof of menu-bar visibility.

Build 54 performed one bounded, Debug-only allow-list trial. Before activation,
it checked that the two observed unbundled PIDs still referred to the reviewed
executables, had valid code signatures, and exposed the expected Apple and Wine
signing identifiers. It added those identifiers to the assessment allow-list
for an explicit Resume. Resume reached `Management on`, and the Board retained
both cards, but a physical menu-bar screenshot showed the GamePolicyAgent
rocket icon missing. The Wine-owned Battle.net icon was not conclusively
mapped in that screenshot. Normal Quit invalidated the assertion and the
rocket reappeared. This demonstrates that adding the two code-signing
identifiers to the application Bundle ID allow-list does not preserve every
reviewed item. The trial code was removed. No TCC reset, sorting Apply, or
system-item preference write was used. The saved policy remains unchanged.

The guard now reports the backend limitation without instructing the owner to
close a system process. When the unbundled icons are present, Resume must stay
paused; if they disappear, Refresh and Resume can be retried. An implementation
that keeps both icons physically visible while this assertion is active has
not been established. Do not promote an AX-only success or this identifier
trial as a fix.

Build 55 removes the trial path, retains the Board-model correction, and
clarifies the paused-state error. It passed 634 Xcode 27 Debug tests in 58
suites, ordinary Release compilation, the packaged Board lifecycle self-check,
and strict signature verification. The installed app retained the same Bundle
ID, designated requirement, and path. Startup stayed paused with the Game and
Battle.net read-only cards and physical icons visible. An explicit Resume was
rejected with the revised explanation; the accepted policy and previous-policy
backup hashes remained unchanged. No physical ordering or system-item Apply
was performed in Build 55.

Build 56 narrows that explanation from "would hide" to "may hide": the live
trial proved the GamePolicyAgent rocket disappeared, but did not conclusively
map the Wine-owned icon. This build passed the same 634 tests, Release compile,
packaged lifecycle self-check, strict signature verification, and installed
same-path/same-requirement check. Startup and explicit Resume remained paused;
the revised reason was shown and the Game and Battle.net read-only cards
remained. The physical rocket returned in the unrestricted menu bar, and the
accepted policy and previous-policy backup hashes remained unchanged. No
sorting Apply, system-item Apply, TCC reset, or permission expansion occurred.

Build 57 removes the misleading generic "bounded Apply preflight" prefix from
this specific Resume guard. It passed the same 634 Debug tests, Release compile,
packaged lifecycle self-check, strict signature check, and same-requirement
installation. An attended Resume showed the direct two-item explanation,
remained paused, retained both read-only cards, and left the menu-bar rocket
visible. The policy and backup hashes were unchanged. This is an accurate
fail-closed outcome, not an active-management fix.

Read-only follow-up after the owner confirmed Build 57 still cannot Resume:
the live macOS 27 `MBAssessmentModeConfiguration` exposes only
`initWithAllowedSystemItems:allowedBundleIdentifiers:` and its two getters.
`MBAssessmentModeAssertion` exposes activation and invalidation, with no
observed PID, executable-path, or signing-identity exception setter. The
existing numbered system catalog covers only 0 through 8 and does not identify
GamePolicyAgent or the Wine tray host. AppKit's public
[`NSStatusItem.isVisible`](https://developer.apple.com/documentation/appkit/nsstatusitem/isvisible)
controls the status item instance owned by the calling app; it does not provide
a cross-process replacement for this assertion. The repository's exact
per-item preference routes cover selected Apple system items, not arbitrary
third-party status items. No alternative with equivalent three-state policy,
live reveal, and exact restoration has been verified. The installed Build 57
therefore remains paused in the observed layout. Do not label its safety guard
as a Resume fix or bypass it based on AX card presence alone.

The owner requested continued work toward a functional Resume. A second
bounded Debug trial in Build 58 admitted the running containing-app bundle IDs
`com.apple.GameOverlayUI` and `com.d4mac.app` after verifying the two observed
unbundled hosts still had the reviewed strict code-signing identities. Resume
reached `Management on`, but a physical screenshot again showed the
GamePolicyAgent rocket absent. Normal Quit released the assertion, the rocket
returned, and the accepted policy and backup hashes remained byte-identical.
The trial code was removed and the same-requirement installed Build 57 was
restored in its paused, unrestricted state.

## Build 59: Resume is no longer gated by unattributed extras

The owner clarified that restoring functional Resume is the current acceptance
condition. Physical persistence of the Game and Wine menu extras during active
management is not a prerequisite. An earlier bounded trial proved that the
GamePolicyAgent rocket may disappear while the assessment assertion is active;
the Wine icon's physical state was not conclusively mapped. Build 59 removes
only the startup and fresh-preflight rejection based on unattributed extras.
It continues to require a complete bounded observation, reviewed application
policy scope, Accessibility, a valid recovery backup, and the existing serial
writer. Unattributed extras remain read-only Board observations, excluded from
candidate inventory, policy validation and system mutation.

Build 59 passed 634 Xcode 27 Debug tests in 58 suites, ordinary Release
compilation, the packaged ordering Board lifecycle self-check, strict signature
verification, and `git diff --check`. The installed app retained bundle ID
`xyz.fi5h.blenny`, the same self-signed designated requirement, and
`/Applications/Blenny.app`. With the Game and Battle.net observations present,
its first startup reached `Management on`; Stop reached `Management stopped`;
explicit Resume returned to `Management on` without an error. Normal Quit
ended the process, and a fresh launch again reached `Management on`. The two
observations remained read-only on the Board throughout. The accepted policy
and previous-policy backup SHA-256 hashes were unchanged before and after the
Stop/Resume/Quit sequence. No drag, Apply, Undo, TCC reset, new authorization,
or item-specific preference write was performed. Physical menu-bar captures
showed the GamePolicyAgent rocket absent during management and present after
normal Quit, consistent with assertion cleanup. The Wine icon was not
conclusively mapped in those captures; its physical restoration is not claimed.

A read-only Accessibility attribute probe of the four currently managed
third-party menu extras (CleanShot X, Tailscale, Paste, Snipaste), plus the
GamePolicyAgent and Wine extras, found no `AXHidden` or `AXVisible` attribute;
their `AXPosition` and `AXSize` attributes were not settable. This excludes a
simple AX visibility setter as an equivalent third-party policy backend on
this observed macOS 27 host. No AX write was attempted. The separate public
`NSStatusItem.isVisible` API is scoped to an app's own status item. Current
management cannot preserve the Game icon and maintain the accepted three-state
policy merely by changing the assertion's allow-list inputs or using AX.

An independent macOS 27 [Ice compatibility proposal](https://github.com/jordanbaird/Ice/pull/997)
describes an Ice-owned spacer that pushes icons into native overflow, with
synthetic Command dragging for its boundary and screen capture for an auxiliary
bar. That approach is not an equivalent drop-in backend for Blenny: this
repository prohibits synthesized Command-drag and Screen Recording in the
baseline, and native overflow alone does not enforce Blenny's distinct Hidden
versus Revealable intent. No Ice implementation code was copied.

### Follow-up: keep unmanaged Game and Wine extras visible

The owner would prefer these original extras to remain physically visible
while Blenny manages other items. That behavior has not been achieved. Keeping
their Board cards read-only does not exempt their physical icons from the
assessment restriction. The two host processes have no application Bundle
IDs, neither item maps to the nine numbered system cases, and read-only
runtime inspection found no PID, path, or signing-identity exception. The
reviewed code-identifier and containing-app Bundle ID trials both failed to
preserve the GamePolicyAgent rocket. Wine visibility was not conclusively
mapped in those trials, so the same physical outcome is not claimed for it.

A future per-item backend would need to prove live visibility and exact
restoration for the original items while retaining distinct Hidden and
Revealable behavior. No such route is verified for either host. Stop releases
the restriction and restored the rocket in the observed run, but also suspends
Blenny's active visibility management. This follow-up made no code, TCC,
ordering, or system-preference changes.

### Independent filter and alternate-backend investigation (2026-09-26)

The [unbundled menu-extra investigation](UNBUNDLED_MENU_EXTRA_COMPATIBILITY_0.12.0.md)
locates a nil-Bundle-ID rejection before allow-list lookup in MenuBarAgent's
assessment `FilterStep`, corroborated in both installed architecture slices.
A fresh read-only probe identifies GamePolicyAgent and the Wine extra with
`AXHelp` `战网`, both without application Bundle IDs. These AX observations do
not establish physical visibility or a Wine lifecycle pass.

The separate `TrackedApplicationsPreferences.isAllowed` mechanism has a live
registry observer, making it a candidate for replacing assessment rather than
exempting an item inside it. Its protected baseline was not authoritatively
readable from the research context, and current-item inverse and lifecycle
recovery remain unproven. No preference was written or new live mutation trial
performed. The report records the exact evidence, alternative routes, snapshot
and restoration gates, and the unrun physical acceptance matrix. Build 59 and
its policy/recovery state were preserved; compatibility remains unresolved.

## Capability-based Board admission follow-up

The Board now evaluates visibility and sorting separately for each observed
system item. A three-state action requires one exact, owner-attributed item
identity, an existing item-specific writer and recovery path, and a ready
target preflight. An existing Blenny-hidden policy may retain an absent row for
restoration; an externally hidden item cannot begin a new policy assignment.
An exact canonical menu-extra identifier reported by Apple's MenuBarAgent may
resolve to its existing target after the target-specific preflight. A composite
label from MenuBarAgent cannot impersonate a separately hosted item.
An unobserved ready target does not create a Board placeholder; a durable
recovery receipt does.
Sorting requires an offered exact ordering identity, the current exact
configuration key, and an eligible ready ordering row. Duplicate identities
and missing or blocked rows fail closed in the Board and at drag delivery.
Known icon artwork is not mutation authority. No additional system preference
keys, assertion values, or sorting targets are introduced by this follow-up.
Clock, unverified Control Center gallery controls, privacy indicators, and the
native overflow control remain read-only until separately evidenced.

Xcode 27 passed 632 Debug tests in 58 suites, the packaged Board lifecycle
self-check, and ordinary Release compilation. The same-certificate Build 41
passed strict signature verification and installed at the existing path. Its
read-only accessibility tree shows a single observed Now Playing item with
three-state and sorting actions, Focus with no write actions, and the existing
Spotlight, Wi-Fi, Bluetooth, Sound, Siri, and Control Center actions in their
independent capability states. Management resumed from saved intent with no
local Draft. No new system-item Apply or physical ordering was exercised in
Build 41; the earlier Build 35/36 Spotlight observations remain specific to
those builds.

Runtime inspected: macOS 27.0 build `26A428`, arm64, one signed local Blenny
installation. Build 35 replaced Build 33 at the existing bundle identifier and
path, with the same designated requirement as Build 31 and Build 33. The owner
performed the real Spotlight ordering and visibility trials described below;
the implementation work itself did not write a Spotlight system preference or
ordering value.

## Read-only evidence

- Accessibility exposes one Spotlight `AXMenuBarItem` / `AXMenuExtra` with owner
  `com.apple.campo`, empty AX identifier, and stable semantic label `spotlight`.
  A similar label from another owner is not a policy or ordering identity.
- The running Apple-signed `com.apple.campo` host is the `Siri AI` executable.
  Its code requirement is `identifier "com.apple.campo" and anchor apple`.
- The installed Control Center runtime exports exact `showSpotlight` Boolean
  getter and setter symbols. A read-only getter returned true. The current
  `com.apple.campo` `NSStatusItem VisibleCC Item-0` preference is a Boolean true.
- Blenny's authorized read-only ordering diagnostic found exactly one
  `status:com.apple.campo::Item-0` in the 33-entry position table. The value was
  a positive real (`113`) and matched across container, file-before and
  file-after sources. The saved exact-file bookmark reported stale; this was
  retained as a separate access finding and did not change the agreeing reads.

These observations identify a candidate. They do not prove that the private
visibility setter changes only the captured preference key, or that the
inverse succeeds after owner normalization. Those remain attended trial gates.

## Bounded implementation

The Debug catalog maps only the exact `com.apple.campo` Spotlight observation
to `com.apple.menuextra.spotlight`. The persistent system-item writer takes an
exact target-local Boolean snapshot and durable receipt before a setter call.
The private runtime bridge requires the exact getter and setter symbols; an
unexpected runtime fails closed. The existing serial coordinator performs
target capture, one write, verification and exact restoration on failure.
Build 35 treats the paired `showSpotlight` getter as the live visibility
authority. The target-local `NSStatusItem VisibleCC Item-0` remains captured
and type-checked, but may remain at its original Boolean while the getter
reports hidden. Post-write verification accepts only that unchanged value,
explicit false, or removal while the getter reports hidden. The snapshot and
restoration remain limited to the exact Spotlight target key.

Ordering resolves the Spotlight observation to the single exact configuration
key above. It requires a positive position, no sibling `com.apple.campo`
status key, and one verified Apple-signed `com.apple.campo` process named
`Siri AI`. The existing ordering writer snapshots the complete table, writes
through its durable recovery path, verifies adoption and retains an inverse
receipt. A changed owner, ambiguous key, missing read, or stale plan rejects
the operation. The Release catalog and Release writer do not offer Spotlight
visibility or ordering.

## Validation and owner test

Xcode 27 passed 629 Debug tests across 58 suites; the ordinary Release target
compiled. Tests cover exact Spotlight identity, false-owner rejection, all
three policy states through the shared writer, target-local preference
normalization, serial rollback, ordering namespace ambiguity, and stable Board
identity. Build 35 passes strict code signature verification. Its installed
accessibility tree shows Spotlight in the movable Visible section with Move
Left, Move Right, Move to Revealable and Move to Hidden actions, no draft, and
management on. The failed Build 33 trial's visibility receipt directory is
empty and its ordering recovery record says the failed configuration revision
was rolled back to the last committed values; the prior ordering receipt remains
`applied`, not a pending restoration. The Campo visibility preference was true
before the Build 35 trial. No Spotlight order or system preference was rewritten
during upgrade.

The owner observed physical Spotlight sorting succeed in Build 33. Moving it
from Visible to Revealable and clicking Apply then failed with
`SharedSystemItemTrialError error 1`. The failed trial left an unapplied Board
draft; its system-item receipt was restored and removed. A signed, read-only
diagnostic confirmed a valid Spotlight baseline (`showSpotlight == true`,
target preference true) and valid hide proposal (false). Build 33 required the
preference value to equal the getter after writing. A post-write getter /
preference divergence is therefore a plausible cause of error 1, but the exact
throw site of that real Apply was not captured. Build 35 changes only this
validation boundary. The failed unapplied draft was discarded before replacing
Build 33; the owner's successful physical ordering was retained.

In Build 35, the owner reported that moving Spotlight to Revealable and Apply
hid the native icon, and Blenny's explicit expand made it appear. This is a
live pass for the hide and ordinary reveal direction. After Refresh, the Board
and saved policy were still Revealable, the Spotlight receipt was present with
an applied hidden state, and the private getter was false. The target preference
key was absent; temporary reveal had not changed the committed policy. The owner
then moved Spotlight back to Visible and Applied. The Board and saved policy now
show Visible, the private getter and target preference are true, and the
Spotlight recovery receipt has been removed. This verifies the explicit Visible
inverse. The ordering recovery receipt remains applied with exact configuration
verified; its physical ordering verification still reports unavailable.

The owner then moved Spotlight to Hidden and Applied. The native icon hid and
ordinary Blenny expand did not reveal it. After moving it back to Visible and
Applying, the owner observed the icon remain visible. Independent read-only
checks found the Board and saved policy Visible, private getter true, target
preference true, and no Spotlight visibility receipt. This verifies the Hidden
direction and its explicit Visible inverse on this host. No reboot or macOS
update was part of this Spotlight trial.

The owner next reported that, while Spotlight is Revealable, Blenny's ordinary
expand/conceal appears to change Spotlight first and the other icons about one
second later. Build 35's ordinary Spotlight reveal called the exact restoration
backend, which deliberately sleeps one second before and one second after
restoring the target-local preference. Build 36 routes only ordinary Spotlight
reveal through immediate setter, exact target-key restoration, and immediate
readback, as already used for the Time Machine Debug timing trial. Stop, Quit,
failed-operation checkpoint restoration, and explicit Visible Apply keep the
waited exact-restoration route. The writer remains serial and retains its
receipt and exact verification. Xcode 27 passes 631 tests across 58 suites,
including Spotlight ordinary-reveal routing and failed-readback checkpoint
recovery; the ordinary Release product compiles. Build 36 is signed with the
same designated requirement and installed at the existing path. Normal Quit
restored Spotlight before replacement; startup re-applied the saved Revealable
policy, with no unapplied draft. The owner subsequently reported that the
expand/conceal wait is gone. This is attended responsiveness evidence, not an
independent timing trace or confirmation that Spotlight's menu opens after
reveal. The earlier conceal-side gap was not independently traced to the
ordinary-reveal waits.

| Spotlight operation | Build | Result | Evidence limit |
| --- | --- | --- | --- |
| Physical sorting in Visible | 33 | Owner observed success | Original native position inverse was not independently captured. |
| Visible to Revealable, Apply | 33 | Failed with error 1 | Exact throw site was not captured; recovery removed the visibility receipt. |
| Visible to Revealable, Apply | 35 | Owner observed native hide | Receipt records an applied hidden state and the private getter later returned false. |
| Explicit expand while Revealable | 35 | Owner reported icon appeared | Ordinary reveal is temporary; the saved policy remains Revealable. |
| Revealable to Visible, Apply | 35 | Passed | Board and saved policy Visible; getter and preference true; visibility receipt removed. |
| Visible to Hidden, Apply | 35 | Owner observed pass | Native icon hid; ordinary expand did not reveal it. |
| Hidden to Visible, Apply | 35 | Passed | Board and saved policy Visible; getter and preference true; visibility receipt removed. |

Further compatibility work, if Spotlight is considered for Release, is
deliberately separate:

1. Repeat the trial on other macOS 27 builds and after OS changes. Confirm
   owner identity, setter availability, exact restoration, and physical order.
2. Review the Debug-only private backend, permission requirements, failure
   recovery, and lifecycle behavior before any explicit Release promotion.

If any Apply fails, stop further Spotlight actions, preserve the error and
recovery receipt, and use Blenny's explicit recovery flow. Do not replace the
app or rewrite the table while a receipt remains. The attended pass is limited
to the current signed Debug build and host; UI exposure and deterministic tests
alone remain insufficient evidence for wider compatibility.
