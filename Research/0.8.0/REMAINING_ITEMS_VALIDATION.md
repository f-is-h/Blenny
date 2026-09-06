# Remaining system items: route validation

Date: 2026-09-04. Inspected runtime: macOS 27.0 build `26A5416b`.
Clock is explicitly excluded. This follow-up did not replace/restart the owner's
running Blenny installation or invoke any system writer, notification or setter.

## Outcome by item

| Item | Newly validated evidence | Candidate path | Still unproven |
| --- | --- | --- | --- |
| Weather | Dedicated `com.apple.weather.menu` process owns one observed status item; its AppKit plugin creates an `NSStatusItem`; owner-confirmed hide/reveal succeeds | Exact owning-bundle allowance, not a fabricated numeric system ID | Independent lifecycle/restoration matrix and Release decision |
| Input Menu | Dedicated `com.apple.TextInputMenuAgent`; whole-item visibility binding and targeted insert/remove handlers; owner-confirmed hide/reveal succeeds | Exact owning-bundle allowance, not a persistent visibility edit | Independent lifecycle/restoration matrix and Release decision |
| Now Playing | Typed exact-key snapshot prepares a hide/inverse description; 95 pure checks pass in both unoptimized and optimized builds | Current-user/current-host `com.apple.controlcenter:NowPlaying` packed flags | External write permission, no-restart live effect and actual restoration; persistent writes do not disappear on process exit |
| Siri | Shared SystemUIServer AX owner; exact current-user/any-host two-key snapshot and pure inverse; distributed refresh emitter identified | Exact two-key preference route, subject to consumer-refresh proof | External write access, no-restart live effect and actual restoration |
| Time Machine | Shared SystemUIServer AX owner; exact ordered `menuExtras` membership and current status metadata; private System Settings setter route traced | Exact Time Machine menu-extra route, never shared-owner assessment | External setter/write access, no-restart live effect and actual restoration |

These are not four successful hiding tests. Weather/Input Menu are dedicated
owner candidates; Now Playing/Siri are separate persistent-state investigations.
Neither a missing numeric ID nor a current product restriction proves that macOS
cannot hide the item. Weather and Input Menu now have positive owner-observed
functional evidence, but no additional item is promoted to Release here.

## Weather: avoid changing login-item state

The bounded live AX read found one existing `com.apple.weather.menu` owner and
one `AXMenuBarItem`, with a complete traversal and no AX identifier. Its installed
owner is Weather's `Contents/Library/LoginItems/WeatherMenu.app`; this is not
the main Weather application, MenuBarAgent or SystemUIServer. The plugin's
`systemStatusBar` / `statusItemWithLength:` calls are at image-relative offsets
`0x6180` / `0x6194`. A bundle plan intentionally covers every item from this
owner, not a stable per-item AX handle. Do not invent `com.apple.menuextra.weather`.

Apple's Settings path is materially different. In ControlCenter framework,
`WeatherPreferences.showInMenuBar` getter/setter at `0x2B07C` / `0x2B0AC` call
`LoginItemController.loginItemEnabled` / `setLoginItemAllowed`. The latter routes
through BackgroundTaskManagement: `setAllowed:` and `updateItem:error:` at
`0x8CF8C` / `0x8CFA0`. Missing-item state returns false from the getter but follows
a different setter branch, including `setDisposition:11`. Consequently, saving
only a Boolean cannot restore the difference between absent and disabled state.
The `menuBarEnabled` string alone does not establish a writable preference key.

An exact bundle-allowance experiment would avoid altering login/background-item
configuration. Its future preview must preserve all other bundle allowances and
all numeric system items, bind the actual owner evidence, and define restoration
before execution. No BackgroundTaskManagement method was called.

## Input Menu: name text is not item visibility

The bounded AX read found one `com.apple.TextInputMenuAgent` process and one
status item, but no stable item AX identifier or writable AX-hidden property.
Its input-source description changes with the selected input method. Do not use
that text or a child index as persistent control identity. The numeric framework
case `keyboard` remains keyboard **brightness**, not this menu.

Two mechanisms must be kept distinct:

- `com.apple.menuextra.textinput:ModeNameVisible` and
  `showHideSourceNameInMenuBar:syncingUserPrefs:` affect only the displayed source
  **name**. Local show/hide-source-name notifications and explicit UI strings
  corroborate this. This is not a whole-item hiding route.
- The whole status item observes `NSStatusItem.visible` and a defaults object's
  `visible` property in both directions. The exact observed stored key is
  `com.apple.TextInputMenuAgent:NSStatusItem VisibleCC Item-0`. It was read
  without synchronization in explicit scopes; the raw value remains local.

The agent also handles private distributed notifications
`com.apple.controlcenter.setting.statusItemInsert` / `statusItemRemove`, gated
on userInfo identifier `TextInputMenu`. Insert sets the item visible and accepts
an optional `index` feeding an internal ordering path; Remove sets it invisible.
No notification was sent. Their external permission, side effects and inverse
are not validated, and the ordering parameter is outside Blenny's scope.

Reproduction anchors in TextInputMenuAgent (UUID
`D56B3244-C0E9-3FA5-A762-AE291BAFB1E8`, image base `0x100000000`): KVO
registration `0x1644–0x16AC`, mirror handler `0x1C9C`, insert identifier gate
`0x2D74–0x2DB4`, insert visibility call `0x2DB8–0x2DD8`, remove identifier gate
`0x2E7C–0x2EC0`, and remove visibility call `0x2EC4–0x2EE0`.
Source-name-only handling starts at `0xA488`. These are inspection anchors,
not addresses to invoke or hard-code in product behavior.

Apple's currently published guide (labeled macOS Tahoe, not a macOS 27 runtime
guarantee) says adding another input source automatically enables the Input
menu. A restore based on stale preferences could therefore overwrite an
intervening user/system change. Exact pre-restore comparison is necessary, but
even matching bytes cannot prove that user intent did not change and return.
[Apple Input Sources settings](https://support.apple.com/guide/mac-help/change-input-sources-settings-mchl84525d76/mac).

## Now Playing: tested pure inverse, no executable writer

[`ValidateNowPlayingPreferencePlan.swift`](ValidateNowPlayingPreferencePlan.swift)
is excluded from every product target. It is gated to the inspected build,
imports no private framework, and contains no write/synchronize/notification or
assertion operation. With no arguments it runs 95 pure checks; `--snapshot`
additionally performs exactly two `CFPreferencesCopyValue` reads of `NowPlaying`
at current-user/current-host and current-user/any-host. No other mode exists.

The model preserves all bits outside mask `0xA`; show sets `0x2`, hide `0x8`,
and system-default clears that mask. It rejects Boolean, negative, floating,
string and dictionary values rather than coercing them into bit flags. It binds
the exact scope and original key absence/value into a fingerprint. That
fingerprint is a research-plan identity, not an executable APPLY authorization.

The inverse restores the recorded value or removes an originally absent key;
setting a default flag value is not equivalent to deletion. It is idempotent
after restoration and rejects an unexpected current value instead of clobbering
a later change. Apple's documented CFPreferences removal/caching semantics agree
with this distinction, but do not establish the private menu's behavior.
[Apple Preference Services](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/PreferencePanes/Tasks/Preferences.html).

Both `-Onone` and `-O` macOS 27 builds pass all 95 checks. Two explicit scoped
snapshot outputs matched, and the current snapshot could prepare a hide/inverse
description. This is not a mutation trial, installed-app writer validation,
successful visibility observation, or proof of crash-safe restoration.

## Siri: access checks do not establish an entitlement requirement for Blenny

`SRFUserDefaultsController.sharedUserDefaultsController` calls its cached
`_canAccessUserDefaults` check at `0x1BFF795B8`. Denial enters an assertion/
diagnostic path at `0x1BFF795C0–0x1BFF79638`; this capture does not prove whether
the assertion throws or returns, and it shows no explicit nil-return branch.
The check delegates to `SRFUtilities.canWritePreferenceDomain:`. The initializer
creates a defaults controller and installs observation state, so calling it is
not a side-effect-free snapshot technique.

Siri.app's shared-preference entitlement includes `com.apple.Siri`; inspected
ControlCenter entitlements differ. This **does not prove** that an unsandboxed
Blenny process needs a private entitlement for a direct preference route. No
private entitlement is requested or proposed.

The setter deletes `SiriPrefStashedStatusMenuVisible` unconditionally before
conditionally updating `StatusMenuVisible`. A correct inverse must account for
both keys' presence, type, value and exact scope; the setter is not intrinsically
irreversible, but saving one effective Boolean is insufficient. The later exact
read locates the current stored state at current-user/any-host; consumer refresh,
external write behavior and live restoration are not validated.

The notifier transport is now resolved: `_notifyStatusMenuVisibleDidChange`
at `0x1BFF79988` uses `NSDistributedNotificationCenter.defaultCenter`, posting
`com.apple.Siri.StatusMenuVisibilityChanged` with nil object/userInfo and
`deliverImmediately: true`. Decoded selector stubs at `0x1C0005980` and
`0x1C001D520` match `defaultCenter` and
`postNotificationName:object:userInfo:deliverImmediately:`. The class GOT target
decodes to `0x1E63C40B0`, matching Foundation's exported class and independent
class metadata name. It is not a Darwin-notification emitter. No notification
was sent; identifying Apple's emitter does not prove that an ordinary external
sender can refresh the live consumer.

## Evidence and state boundaries

Raw AX, static disassembly, entitlement captures, typed snapshots and hashes are
ignored LocalData only. The owner's running Blenny executable, production policy
and backup, and manual-trial policy and backup hashes matched across this work.
No owned state required rollback, so none was performed.

The broad ControlCenter preference-file comparison was **not identical**: one
`displayablemenuextras` ByHost file changed during observation. The ordinary and
host-scoped ControlCenter preference files used for the NowPlaying key matched,
as did both exact-key snapshot outputs. The change's cause was not established;
do not overwrite that system-maintained file or claim whole-system hash stability.

This research does not re-run or broaden the prior product regression matrix.
The installed manual test build stays in place, and the owner's report of normal
Bluetooth/Wi-Fi/Control Center/Sound hiding and showing is recorded as user
observation, not automatic Release promotion or exhaustive lifecycle acceptance.

Local reproduction groups: `LocalData/0.8.0/input-menu-research/` contains the
scoped AX and source-name reads and key-list probe;
`LocalData/0.8.0/identifier-research/runtime/` contains static framework evidence,
Weather route anchors and corrected Siri notifier receiver decoding;
`LocalData/0.8.0/remaining-system-items.hpBRbB/` contains this plan probe's
build/test logs, typed snapshots and before/after comparisons. The final probe
adds an explicit inspected-build fingerprint field after the paired snapshots;
both final binaries were rechecked with all 95 pure tests. Earlier snapshot
fingerprints are historical evidence, not final executable receipts.

## 2026-09-05 trial handoff

After the host updated to macOS 27 build `26A5425a`, a read-only compatibility
probe confirmed the unchanged MenuBarClientCore UUID, six exact runtime method
encodings and configuration round trip. The new build is admitted only in Debug.
Weather and Input Menu are now exact application-level candidates in the manual
Board; no other Apple owning bundle is admitted, and Release admits none through
this route. Debug 345/35 and Release 296/30 tests and both builds pass. An
installed dry-run observed both owners and prepared six policy plans without a
writer, assertion or policy/hash change. Live hiding/restoration remain unproven
until the owner's attended manual test.

## 2026-09-05 owner result and shared SystemUIServer follow-up

The owner exercised the installed Debug Board and confirmed both Weather and
Input Menu hide under their exact bundle policy and return during Reveal without
an observed problem. This is stronger than the earlier candidate-only result.
It is still attended functional evidence, not an independent termination,
failure, login/session or future-build compatibility matrix.

Their presentation bug was unrelated to the mutation mechanism. Because they
entered the Board as application-level candidates, the generic application icon
resolver selected Weather's full-color app icon and could not resolve the Input
Menu agent, producing the shared question-mark fallback. The exact experimental
Apple-owner catalog now supplies semantic names and routes only these two owners
to macOS system symbols: `cloud.sun` and `keyboard`. Policy identity,
fingerprints and writer plans are unchanged. Runtime checks confirm both symbols
exist on the inspected macOS 27 build.

A fresh bounded AX read found two `AXMenuBarItem` children beneath
`com.apple.systemuiserver`. One has title and description `Siri`; the other has no
identifier, title or description. `com.apple.Siri` itself returned no usable
extras root. The unlabeled item correlates with the only configured legacy menu
extra, `/System/Library/CoreServices/Menu Extras/TimeMachine.menu`, and the owner
reported Siri and Time Machine as the only remaining visible system items. This
is sufficient to reject shared-owner assertion as a control route, but not to
use the unlabeled AX child as a durable Time Machine identity on another machine.
Future product presentation should synthesize an exact per-item candidate from
preference/controller state rather than an AX ordinal.

Current-user/any-host read-only snapshots resolve:

- `com.apple.Siri:StatusMenuVisible = true` and absent
  `SiriPrefStashedStatusMenuVisible`;
- `com.apple.systemuiserver:menuExtras` as an ordered array containing exactly
  the Time Machine menu-extra path;
- `NSStatusItem VisibleCC com.apple.menuextra.TimeMachine = true`; and
- `NSStatusItem Preferred Position com.apple.menuextra.TimeMachine = 86`.

`ControlCenter.framework` on build `26A5425a` has UUID
`8EE7F051-C400-3E27-A86D-C6EF5CE84565`. Its relevant exported offsets and control
flow are unchanged from the inspected capture: `CoreMenuExtra.timeMachine`, its
`showInMenuBar` getter/setter, `SystemItemMenuBarPreferences.showTimeMachine`,
and `SystemItemMenuBarPreferences.showSiri` remain present. The Time Machine
settings path constructs the exact `CoreMenuExtra.timeMachine` value and invokes
its per-item `showInMenuBar` setter; the lightweight `TimeMachinePreferences`
class alone is only an in-memory Boolean model. This supports a dedicated
per-item private route, not a direct blind defaults edit and not a
`com.apple.systemuiserver` assessment exclusion.

Apple's current Menu Bar guide independently lists Siri, Weather and Time Machine
as removable System Settings items. Its managed-device documentation also names
`TimeMachine.menu`, but that configuration-profile surface is not a local
third-party mutation API and is not proposed for Blenny.
[Apple Menu Bar guide](https://support.apple.com/en-gb/guide/mac-help/mchl4af84660/mac);
[Apple ManagedMenuExtras](https://developer.apple.com/documentation/devicemanagement/managedmenuextras?changes=la_7).

[`ValidateSharedSystemItemPreferencePlans.swift`](ValidateSharedSystemItemPreferencePlans.swift)
contains no write surface. Both unoptimized and optimized builds pass 15 pure
checks. Its optional mode performed five exact reads and prepared Siri and Time
Machine hide-plan fingerprints while reporting zero writes, synchronization
calls and notifications. Siri inverse restores both key presence/value states;
Time Machine inverse restores the complete ordered array and binds the two
status-item metadata values. Both reject intervening changes instead of
overwriting them.

No Siri notification, Time Machine setter, preference write, assertion, process
restart or application replacement occurred. The existing Blenny process and
its active manual policy were left untouched. Before any real trial, the missing
work is an installed no-write receipt that binds AX/prefs/files, a single serial
persistent-state writer, one verification and at most one bounded retry, plus a
separately authorized exact target and inverse. The owner must be notified before
the currently running assertion is released or the installed app is replaced.
