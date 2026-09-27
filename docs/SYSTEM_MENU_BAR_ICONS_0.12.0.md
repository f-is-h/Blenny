# macOS 27 system menu-bar icon presentation

Status: presentation catalog implemented for the identities listed below.
This changes Board names and artwork only. It grants no visibility or ordering
capability and does not change policy, recovery, or system preferences. The
images are semantic static artwork, not live copies of changing status such as
battery charge, Wi-Fi strength, or the active Focus mode.

Board editing is assessed independently of this presentation catalog. A unique
observed item with an exact owner and an existing writer target can expose
three-state visibility after its target-specific preflight. Sorting additionally
requires an offered exact configuration key and an eligible current ordering
row. A retained hidden policy may keep a zero-observation restoration entry.
An icon or English label alone never enables either operation. Observed unknown,
ambiguous, and preflight-failed items remain visible in the Board with an
explanation and no corresponding action. An unobserved ready target is omitted;
an absent target with a recovery receipt retains its restoration row. This does not add
writer targets for the other presentation-only icons listed below.

## Evidence and coverage boundary

[Apple's macOS 27 Menu Bar settings guide](https://support.apple.com/en-gu/guide/mac-help/mchlad96d366/mac)
lists Clock, Siri, Spotlight, Wi-Fi, Bluetooth, Battery, Focus, Screen Mirroring,
Display, Sound, Now Playing, Fast User Switching, Time Machine, VPN, and Weather.
Control Center itself and Input Menu are separately observed menu-bar items.
[Apple's customization guide](https://support.apple.com/en-mn/guide/mac-help/mchl4af84660/mac)
also allows controls from the gallery, including Quick Note, Put Display to
Sleep, and Color Filters. The gallery can include controls supplied by apps;
there is no fixed, public list of every possible menu-bar control.

Read-only string inspection of the installed macOS 27 ControlCenter executable
found 23 exact `com.apple.menuextra.*` identity candidates. They are all mapped
to a Board name and an AppKit-available image:

| Identity suffix | Board name | Image |
| --- | --- | --- |
| `accessibility-shortcuts` | Accessibility Shortcuts | `accessibility` |
| `airdrop` | AirDrop | `circle.dotted.circle` |
| `audiovideo` | Audio & Video | `video.badge.waveform` |
| `battery` | Battery | `battery.100` |
| `bluetooth` | Bluetooth | `NSBluetoothTemplate` |
| `clock` | Clock | `clock` |
| `controlcenter` | Control Center | `switch.2` |
| `display` | Display | `display` |
| `energy-mode` | Energy Mode | `bolt` |
| `faceTime` | FaceTime | `video` |
| `focusmode` | Focus | `moon.fill` |
| `hearing` | Hearing | `ear.badge.waveform` |
| `keyboard-brightness` | Keyboard Brightness | `sun.max` |
| `musicrecognition` | Music Recognition | `music.note` |
| `now-playing` | Now Playing | `play.circle` |
| `screen-mirroring` | Screen Mirroring | `rectangle.on.rectangle` |
| `sound` | Sound | `speaker.wave.2` |
| `TimeMachine` | Time Machine | `clock.arrow.trianglehead.counterclockwise.rotate.90` |
| `timer` | Timer | `timer` |
| `user` | Fast User Switching | `person.crop.circle` |
| `voice-control` | Voice Control | `waveform.badge.mic` |
| `vpn` | VPN | `network` |
| `wifi` | Wi-Fi | `wifi` |

The existing Siri, Weather, and Input Menu presentations are retained. Spotlight
now maps the actually observed `com.apple.campo` owner plus `spotlight` stable
semantic identity to a magnifying glass. Its absence from the old icon catalog
explained the question-mark artwork on the new machine. None of the 23 strings
alone proves that its control is installed, currently visible, or writable.

The same executable also contains 15 exact Apple control-widget kind strings:
Calculator, Display Control, Dark Mode, Lock Screen, Night Shift, Screen Saver,
Put Display to Sleep, True Tone, Screenshot, Capture Screen, Alarm, Stopwatch,
Timer, Quick Note, and Printer. These have semantic artwork when an observed AX
identifier equals the corresponding kind string. The Apple-documented gallery
examples Quick Note, Put Display to Sleep, and Color Filters also have an exact
English semantic-label fallback from recognized Apple owners. These strings
have **not** been confirmed as live `AXMenuExtra` identifiers; their mapping is
conditional presentation coverage, not a claim that every gallery tile appears
as an independent Board row or works in every locale.

Exact AX identifiers take precedence. A length-checked Blenny stable identity
can use its exact AX identifier or an exact semantic label from a recognized
Apple owner. The built-in menu-extra names above also have exact English-label
fallbacks when their AX identifier is absent. Unknown or malformed identities
keep the question-mark fallback;
substring matches cannot assign another item's artwork accidentally.

Build 44 also shows a transient read-only fallback card when the bounded scan
finds an application menu extra whose running owner has no Bundle ID. On the
inspected host this exposed one Wine tray item and one Apple GamePolicyAgent
item. Neither item supplied an AX identifier or title. A later read verified
the GamePolicyAgent executable's Apple signing identifier and the D4Mac Wine
loader's `com.codeweavers.CrossOver.wineloader` identifier. The follow-up card
shows the known host instead of calling it wholly unidentified. The observed
Wine menu-extra process was `explorer.exe /desktop`; its menu item's AX help
was `战网` (Battle.net). The Build 48 read-only card uses that exact hint when
present; Build 50 renders its Wine host with `wineglass.fill`. A separate
Battle.net process in the same bottle does not establish a Bundle ID or a
mutation target for the tray item. These observations remain excluded from
policy candidates and all writers. Build 50 uses them in activation preflight
to prevent the Bundle-ID allow-list from hiding them. `GameOverlayUI` itself
had no `AXExtrasMenuBar`
during this read; the game-related menu extra was observed under GamePolicyAgent.
Clock is displayed last in the Visible Board lane, matching its observed
rightmost physical position without adding a Clock position writer.

Privacy indicator dots/arrows, Notification Center, the native overflow
control, and other Control Center gallery widgets have no verified independent
`AXMenuExtra` identity in this catalog. They are not silently given an
item-specific image or management control. A newly observed gallery identity
needs a read-only identity capture and a presentation mapping; it does not
justify a visibility or sorting write.

## Verification

The Build 41 capability follow-up passed 632 Xcode 27 Debug tests, the packaged
Board lifecycle self-check, ordinary Release compilation, and strict signature
verification. Its installed read-only UI exposed Now Playing's existing exact
writer and ordering route when Apple's MenuBarAgent reported one canonical AX
identifier. The observed Focus icon remained read-only because no verified
writer target exists. The follow-up did not mutate either item. Absent ready
targets no longer create duplicate Board placeholders; a recovery receipt keeps
an absent restoration row.

Xcode 27 tests cover every listed exact identity, image availability, the
`com.apple.campo` Spotlight identity, malformed and unrelated identities, and
the Board row with no AX description. All 626 Debug tests pass and the ordinary
Release app compiles. Signed Builds 29 through 31 use the same designated
requirement, bundle identifier, and install path as Build 28. Installed-app
accessibility reads showed the Spotlight Board row change from "Fallback icon"
in Build 28 to "System symbol" in Builds 29 through 31 while remaining read-only.
No system icon setting was toggled to populate the Board. Private Blenny
app-state files were byte identical before replacement, after normal Quit, and
after Build 29 startup; they also remained identical across the Build 29 to 30
and Build 30 to 31 replacements before each launch. They were still identical
after Build 31 startup. Builds 30 and 31 restarted with management on. The 15
widget-kind mappings and the additional label-only
built-in cases were not exercised with live menu-bar controls.
The exact `com.apple.MenuBar.plist` file was not independently read because the
shell lacks access; this presentation check is not ordering-table continuity
evidence. The runtime was already in "Management paused" before replacement,
and remained there afterward despite saved Resume intent; Build 30 subsequently
started with management on.
