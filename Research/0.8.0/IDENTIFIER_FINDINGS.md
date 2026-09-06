# System menu-item identities: read-only follow-up

Date: 2026-09-04
Runtime inspected: macOS 27.0 build `26A5416b`, arm64
Toolchain: Xcode 27 beta, macOS 27 SDK

## Conclusion

Subsequent [remaining-item validation](REMAINING_ITEMS_VALIDATION.md) adds
Weather/Input Menu dedicated-owner candidates, corrects source-name versus
whole-input-menu visibility, resolves Siri's emitter as a distributed
notification, and tests a pure Now Playing inverse. It does not add missing
numeric enum cases or claim successful hiding for those four items.

The missing Siri and Now Playing mappings are not undiscovered numbers in the
current `MBSystemItemIdentifier` enum. That enum has exactly nine fixed values.
Apple has other, separate identity and preference surfaces for menu-bar modules.
Thaw's macOS 27 preview also uses the assessment assertion family, but combines
it with other mechanisms; its capabilities do not establish one universal API.

The initial identifier investigation changed no product capability. Bluetooth remains the only
promoted Apple item. No assertion, preference mutation, Settings action, private
controller construction, app launch/restart, or installation occurred. Existing
installation and accepted-policy/backup hashes and Git HEAD were unchanged.
Raw third-party source and inspection tooling remain in ignored
`LocalData/0.8.0/identifier-research/`; none is a product dependency.

## 1. How the numbers are assigned

In the inspected `MenuBarClientCore.framework`, `MBSystemItemIdentifier` is a
fixed Swift enum, not a session allocation, discovery index, AX handle, or
registry of every visible icon. Static disassembly independently confirms the
catalog obtained by the [existing read-only probe](README.md):

| Raw value | String value |
| ---: | --- |
| 0 | `battery` |
| 1 | `bluetooth` |
| 2 | `clock` |
| 3 | `displays` |
| 4 | `keyboard` |
| 5 | `volume` |
| 6 | `wifi` |
| 7 | `screenMirroring` |
| 8 | `primaryBentoBox` |

`init(rawValue:)` accepts only unsigned values at most 8; this also rejects
negative integers. `allCases` returns static storage, `stringValue` has a
nine-entry table, and `init(stringValue:)` recognizes those nine names. Its
out-of-domain string getter traps. Do not bypass the initializer or brute-force
larger numbers. A new visible feature cannot add a case to this installed enum.

Reproduction anchors: framework UUID `CA5DE7FC-32E9-327F-BC2E-BF44B4035141`;
image-relative offsets `0x3739C` for `init(rawValue:)`, `0x373AC` for the string
getter, `0x374E8` for the string initializer, and `0x37748` for `allCases`.
These are build-specific inspection anchors, not addresses to hard-code.

This establishes completeness for this type/build only, not Apple's reason for
choosing the order or stable values across OS updates. Further investigation and
validation target macOS 27 exclusively; earlier OS availability is not a product
requirement and is not an ongoing research task.

### Additional macOS 27 AX candidate mapping

Read-only inspection of the installed ControlCenter executable resolves the
following exact AX strings. The live sample observed Sound and Control Center;
the other four were absent, which does not mean unsupported or currently hidden.

| External raw value | AX candidate |
| ---: | --- |
| 0 | `com.apple.menuextra.battery` |
| 3 | `com.apple.menuextra.display` |
| 4 | `com.apple.menuextra.keyboard-brightness` |
| 5 | `com.apple.menuextra.sound` |
| 7 | `com.apple.menuextra.screen-mirroring` |
| 8 | `com.apple.menuextra.controlcenter` |

Keyboard means keyboard **brightness**, not TextInput. Its constructor at
image-relative `0x52EB7C` calls `KeyboardBrightnessController.isSaturated` before
constructing that AX identity. AX construction call sites for the six rows are
`0x394ECC`, `0x14C880`, `0x52EC54`, `0x5584CC`, `0x53526C`, and `0x560F58`.
The module-to-`MBControlCenterSystemItemIdentifier` conversion is at `0x5A5664`,
with fixed binding table `0x88AD70`; primary and ordinary BentoBox are distinct.
These static associations are not six demonstrated write/restoration contracts.
Require a fresh exactly-one target observation before any trial. Primary
BentoBox must not be confused with the identifier-less native overflow button.

Raw-byte verification found that `dyld_info -section __cstring` prints
end-plus-one locations for these strings; use actual byte starts rather than
treating its printed locations as string-start addresses. Raw evidence remains
ignored under `LocalData/0.8.0/identifier-research/runtime/`.

## 2. Another enum is not an extension of this one

MenuBarAgent's Swift metadata contains a different type,
`MenuBarSystemItemIdentifier`, with eleven cases:

`battery`, `bluetooth`, `clock`, `displays`, `keyboard`, `volume`, `wifi`,
`addNewBentoBoxButton`, `primaryBentoBox`, `bentoBox`, `screenMirroring`.

Static call sites translate through the framework's string value. Internal
ordinals therefore must not be supplied as framework raw values. The additional
names concern Bento-box containers; they do not supply Siri/Now Playing IDs or
prove the identity of the native overflow control.

Reproduction anchors: MenuBarAgent UUID
`DE3CDABA-05ED-328C-88BE-41D240550156`, field descriptor at image-relative
`0x3D3FC4`, string conversion call site at `0x12300`.

## 3. Where additional controls actually appear

Static exports from Apple's private `ControlCenter.framework` provide more
promising leads than additional numeric values:

| Exported surface | What it establishes | What remains unknown |
| --- | --- | --- |
| `SystemItemMenuBarPreferences.showSiri: Bool` | A Siri-specific getter/setter exists | External access, storage scope, live effect, exact inverse |
| `SiriPreferences.showInMenuBar: Bool` | Another Siri visibility surface exists | Relationship to `showSiri` and `statusItemEnabled` |
| `ControlCenterModulePreferencesController.init(identifier: String)` | Modules can be addressed with a string | Exact accepted identifiers and target ownership |
| `showInMenuBar: Bool` / `userShowInMenuBar: Bool?` | Effective and optional user visibility have getters/setters | Notifications, permissions, persistence and restoration |
| `userShowInMenuBarAlways: Bool` | Always-show intent is distinct | Interaction with visibility and native overflow |

The generic visibility setter routes to the optional user-value setter; the
getter can fall back when that optional is absent. Restoration must distinguish
an absent override from an explicit false/true value. Saving just the effective
Boolean could change the user's original configuration.

Framework UUID: `8EE7F051-C400-3E27-A86D-C6EF5CE84565`. Getter/setter offset
pairs are `0x38028`/`0x380D8` for `showSiri`, `0x314E4`/`0x314EC` for Siri
`showInMenuBar`, `0x6ABE8`/`0x6AC40` for generic `showInMenuBar`, and
`0x6AC48`/`0x6AC54` for `userShowInMenuBar`. Export names/signatures are
inspectable with Xcode's `dyld_info -exports` and `swift-demangle` without loading
the framework into Blenny or constructing private objects.

Apple's installed `ControlCenterSettingsIntents.appex` corroborates a separate
settings model. Its `Metadata.appintents/extract.actionsdata` declares:

- entity `ControlCenterSettingsIntents.ControlCenterModule`;
- properties `showInMenuBar` and `alwaysShowInMenuBar`;
- action `UpdateControlCenterModuleShowinmenubarIntent`, accepting the module
  entity and a Boolean property value;
- query `AvailableControlCenterModuleQuery`.

The extension binary separately contains `nowPlaying`, `siri`,
`com.apple.controlcenter.nowplaying`, `showNowPlayingStatusInTheMenuBar`, and
`showSiriInTheMenuBar`. Strings can be names, settings links, or resources: they
are not by themselves proven controller identifiers or callable methods. The
metadata's discoverability flag is not authorization for third-party invocation.
ControlCenter app metadata also contains Now Playing controller/view types.

These findings establish leads, not a tested write route. No constructor,
getter, setter, query, or intent above was invoked during this follow-up.

## 4. What existing tools demonstrate

Thaw tag `macos-27-preview.5`, pinned commit
`528b9503b051cc1ccccae766014e64404670088b`, explicitly describes holding an
`MBAssessmentModeAssertion`; its tests require the same system allow-list range
0...8, and its catalog has the same nine mappings. Thus it is incorrect to say
that other tools never use this family. The exact configuration construction
is behind its binary PRK dependency, so public source does not prove identical
ABI usage throughout. [Assertion evidence](https://github.com/thaw-app/Thaw/blob/528b9503b051cc1ccccae766014e64404670088b/Thaw/MenuBar/HiddenSectionPatch/AssessmentStateMonitor.swift#L12-L21),
[allow-list test](https://github.com/thaw-app/Thaw/blob/528b9503b051cc1ccccae766014e64404670088b/ThawTests/MenuBarItemTagTests.swift#L2015-L2033),
[catalog](https://github.com/thaw-app/Thaw/blob/528b9503b051cc1ccccae766014e64404670088b/MenuBarModel/Sources/MenuBarModel/SystemMenuBarModuleCatalog.swift#L57-L150).

Thaw also uses Control Center preferences and preferred positions for selected
modules. Its source documents ControlCenter restarts for preference application
and exceptions around temporary reveal, Focus and Now Playing. Such restart and
reconciliation assumptions are outside Blenny's contract. These are Thaw's
observations, not proof that every preference API requires a restart or that
Blenny's successful Bluetooth trial is invalid. [Module handling](https://github.com/thaw-app/Thaw/blob/528b9503b051cc1ccccae766014e64404670088b/Thaw/MenuBar/HiddenSectionPatch/MenuBarSectionController.swift#L1997-L2022).

For Siri, Thaw tests discuss bundle concealment through `com.apple.systemuiserver`
on the assumption that it hosts only Siri on their macOS 27 target. This is not
a safe per-item identity established for Blenny: another item sharing that owner
could be affected. The Siri-specific preference surfaces are a more precise
research lead. [Siri assumption](https://github.com/thaw-app/Thaw/blob/528b9503b051cc1ccccae766014e64404670088b/ThawTests/MenuBarItemTagTests.swift#L2000-L2012).

Ice's inspected `main` snapshot at
`11edd39115f3f43a83ae114b5348df6a0e1741cf` instead expands its own AppKit divider
status item to displace items. That is geometry, not a universal system-item
visibility setter. [Ice control item](https://github.com/jordanbaird/Ice/blob/11edd39115f3f43a83ae114b5348df6a0e1741cf/Ice/MenuBar/ControlItem/ControlItem.swift#L153-L168).
Bartender is closed source; its feature/recovery notes do not establish an exact
API implementation. [Vendor notes](https://www.macbartender.com/goldengate/releases/).

## 5. Older and other identities must remain separate

| Identity | Meaning | Not interchangeable with |
| --- | --- | --- |
| Bundle identifier | Application/package ownership | One particular item in a shared system host |
| Legacy `.menu` bundle identifier | Historical menu-extra feature bundle | Modern module/controller identity |
| AX identifier | An observed accessibility element's identity signal | A setter argument or preference key |
| `CGWindowID`, PID, frame | Session/process/layout observation | Durable feature identity |
| `NSStatusItem.autosaveName` | Persistence name for the caller's own AppKit item | Authority over another process's item |
| WidgetKit control `kind` | App-defined ControlWidget type identity | Built-in Siri/Now Playing or the assessment enum |
| Preference key or controller string | A particular owner's storage/API namespace | Any similarly spelled identity in another namespace |

Apple's SDK headers specify session-local window IDs and caller-owned AppKit
status-item persistence. The macOS 26.5 WidgetKit interface exposes control
discovery with `kind`; this concerns WidgetKit controls, not an enumeration of
legacy system menu extras. Neither those APIs nor historical Siri visibility
key names establish missing assessment IDs. [Window IDs](https://developer.apple.com/documentation/coregraphics/cgwindowid),
[status-item visibility](https://developer.apple.com/documentation/appkit/nsstatusitem/isvisible),
[control identity](https://developer.apple.com/documentation/widgetkit/controlinfo/kind).

## 6. Next investigation, not new write authority

1. Trace the Settings extension's action call sites to the exact Siri and Now
   Playing preference/controller routes. Resolve strings from call sites, not
   guesses based on labels or similar keys.
2. Establish each route's user/host/domain scope, effective versus stored value,
   nil/absent semantics, normal change notification and permission checks.
   Reject a route that requires private entitlements or system UI restart.
3. Define whether the route merely changes persistent system settings or can
   support Blenny's temporary Revealable sessions as well. Do not equate a
   persistent off switch with process-owned, crash-recoverable concealment.
4. Only then design snapshot/restoration, deterministic tests and an installed
   no-writer dry-run. A new real trial still requires its scoped execution and
   observation/recovery plan; tell the owner before rollback so they can observe.

Clock is excluded from the owner's requested next exploration. A known numeric
ID does not itself mean another item is promoted, and a missing numeric ID does
not mean macOS cannot hide that item. This research supports a capability-based
mapping with distinct backend routes, not arbitrary numbers or blanket permission.

## 7. macOS 27 Settings call-site follow-up

Continued on 2026-09-04 at the owner's request, exclusively on macOS 27. Static
call-site tracing resolves two concrete routes beyond the earlier string leads.
Settings extension UUID: `27669E02-5FAF-306F-AD8B-3E354949E053` (arm64e).
The internal module case numbers below are not assessment system-item IDs.

### Now Playing

Settings module case 11 maps to the exact controller identifier `NowPlaying`
(capital N/P), via the getter at image-relative `0x2BDC`, branch `0x2C50`.
The settings writer constructs the generic preferences controller at `0x5204`;
the generic visibility path at `0x15604` invokes `userShowInMenuBar: Bool?`.

The ControlCenter implementation uses `CFPreferences` with domain
`com.apple.controlcenter`, current user, **current host**, key `NowPlaying`.
The stored value is an unsigned packed number, not a Boolean:

| User visibility override | Modification to the stored flags |
| --- | --- |
| true | Clear mask `0xA`, then set `0x2` |
| false | Clear mask `0xA`, then set `0x8` |
| nil / use default | Clear mask `0xA` |

Other bits are preserved; always-show has a separate `0x10` bit. The inspected
setter writes an NSNumber and synchronizes the preference domain. Setting a nil
override still writes a packed value, potentially zero: it does not restore
whole-key absence. An exact inverse must preserve key presence, value/type and
unrelated flags. No write or bit-manipulation implementation is added to Blenny.

There is no explicit distributed visibility notification in the inspected setter.
Its separate asynchronous `com.apple.controlcenter.customized.menubar` event is
for Discoverability/Signals, not a restore token or proven refresh instruction.
Live no-restart behavior remains untested.

### Siri

Settings module case 13 follows a different branch at `0x15630`. It constructs
`SiriPreferences`, calls `statusItemEnabled` at `0x1564C`, then `synchronize()`
at `0x15650`. It does **not** call the earlier `showSiri` candidate.

`statusItemEnabled` forwards to SiriFoundation's shared
`SRFUserDefaultsController.setStatusMenuVisible:`. The defaults suite is
`com.apple.Siri`. Its setter unconditionally removes
`SiriPrefStashedStatusMenuVisible` before potentially updating `StatusMenuVisible`
and posting `com.apple.Siri.StatusMenuVisibilityChanged`.
Even an apparently idempotent set can therefore destroy another stored value.

When `StatusMenuVisible` is absent, the getter derives a default from assistant
and microphone-key state. The getter also synchronizes defaults; neither private
construction nor a getter call should be labeled a side-effect-free snapshot.
The exact suite-backed search/persistence scopes remain unresolved; do not apply
Now Playing's CurrentHost finding to Siri by analogy.

### Read-only snapshot and remaining limits

[`InspectModulePreferences.swift`](InspectModulePreferences.swift) performs exactly
six public `CFPreferencesCopyValue` reads: the three identified keys at current
user/current host and current user/any host. It calls no synchronization function,
private object, notification, intent, or setter. The standalone macOS 27 build
and one execution succeeded; its raw property-list output validates and is kept
mode 0600 under ignored LocalData. These are explicitly scoped stored values, not
a reconstruction of effective defaults or a complete restoration receipt. Absence
does not mean a feature is disabled or unsupported.

The Settings extension has shared-preference exceptions, an application group
and notification-post privileges. Their presence does not establish which are
required for these routes, nor whether an ordinary app can use them. No new real
mutation is proposed yet: permission, no-restart live effect, exact inverse and
temporary-reveal semantics still need evidence.
