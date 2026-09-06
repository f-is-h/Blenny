# 0.8.0 Apple system-item visibility research

This directory contains read-only, unsupported research source for the macOS 27
Apple system-item visibility spike. It is excluded from every Blenny product
target. Generated binaries and raw machine evidence belong under ignored
`LocalData/0.8.0/`.

## Runtime identifier enumeration

`InspectSystemItemIdentifiers.swift` links the system copy of
`MenuBarClientCore.framework` only in this standalone research build. It calls
the inspected runtime's read-only `MBSystemItemIdentifier.allCases`, `rawValue`
and `stringValue` exports. It does not construct a configuration or assertion,
write a preference, perform an Accessibility action, synthesize input, capture
pixels, inject into another process, restart a system UI process or request an
entitlement.

Build and run on the exact 0.8.0 development boundary:

```sh
mkdir -p LocalData/0.8.0/probes
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun swiftc Research/0.8.0/InspectSystemItemIdentifiers.swift \
  -target arm64-apple-macos27.0 \
  -F /System/Library/PrivateFrameworks \
  -framework MenuBarClientCore \
  -o LocalData/0.8.0/probes/inspect-system-item-identifiers
LocalData/0.8.0/probes/inspect-system-item-identifiers
```

The observed macOS 27.0 build `26A5416b` catalog is:

```text
0 battery
1 bluetooth
2 clock
3 displays
4 keyboard
5 volume
6 wifi
7 screenMirroring
8 primaryBentoBox
```

These values are private, version-specific runtime evidence, not a public API or
a compatibility promise. The product's Release build excludes this standalone
probe and the Debug validation route. Its separately promoted macOS 27 backend
loads the assessment runtime dynamically; Bluetooth is its sole writable Apple
system item.

The [2026-09-04 identifier follow-up](IDENTIFIER_FINDINGS.md) confirms this is a
closed nine-value enum, distinguishes MenuBarAgent's separate internal enum,
and records alternative Siri/Control Center preference surfaces and pinned
existing-tool evidence. It does not add a product mutation path.

The existing read-only AX position probe in `Research/0.7.0/` supplies the other
side of the identity mapping. A complete sample observed Bluetooth as
`com.apple.menuextra.bluetooth`, Wi-Fi as `com.apple.menuextra.wifi`, Clock as
`com.apple.menuextra.clock`, Control Center as
`com.apple.menuextra.controlcenter`, and one unidentified native overflow
control. Later installed preflight attempts correctly failed closed when the
MenuBarAgent AX root was temporarily unavailable; absence of a complete sample
is never treated as evidence that an item is hidden.

## Stored module-preference reads

`InspectModulePreferences.swift` reads only the three statically identified
Now Playing / Siri keys in two explicit user/host scopes. It uses public
`CFPreferencesCopyValue`, never synchronization, private object initialization,
notifications or setters. It is not a visibility experiment or an authoritative
effective-defaults reader. See the identifier findings for packed-bit and Siri
stash restoration hazards. Build it with the macOS 27 toolchain and direct all
output to a mode-0600 file under ignored `LocalData/0.8.0/`.

## Remaining-item route validation

The [remaining-item report](REMAINING_ITEMS_VALIDATION.md) records dedicated
Weather/Input Menu owners, exact Input Menu visibility versus source-name
controls, the resolved Siri distributed-notification emitter, and the distinct
Time Machine menu-extra path. Clock is excluded. The owner subsequently confirmed
that Weather and Input Menu both hide and reappear normally through the exact
Debug owning-bundle route.

`ValidateNowPlayingPreferencePlan.swift` implements only a pure proposed-value /
inverse model and optional two-scope reads. It has no executable writer. On the
inspected macOS 27 build, both `-Onone` and `-O` builds pass 95 pure checks:

```sh
mkdir -p LocalData/0.8.0/probes
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun swiftc -parse-as-library -Onone -target arm64-apple-macos27.0 \
  Research/0.8.0/ValidateNowPlayingPreferencePlan.swift \
  -o LocalData/0.8.0/probes/validate-now-playing
LocalData/0.8.0/probes/validate-now-playing
```

Repeat compilation with `-O` for optimized checks. The optional `--snapshot`
argument reads exactly two scoped values and prints XML to stdout; direct it to
a new mode-0600 file under ignored LocalData. Tests print to stderr. There is no
APPLY mode; a prepared fingerprint is not a mutation receipt. Persistent system
preference changes would require a separate installed writer and recovery design.

`ValidateAssessmentContract.swift` is the read-only build-compatibility gate used
after the host moved to macOS 27 build `26A5425a`. It checks the six exact
Objective-C method encodings and round-trips an in-memory configuration, but never
constructs an assessment assertion or calls activation/invalidation. Build it
like the Now Playing probe with `-parse-as-library`, first `-Onone` and then `-O`.
Its two admitted build strings describe research evidence only; the product's
Release gate is separately and deliberately narrower.

`ValidateSharedSystemItemPreferencePlans.swift` is the no-write current-build
model for Siri and Time Machine. It binds Siri's two exact
current-user/any-host values and Time Machine's complete ordered `menuExtras`
array plus its visibility and preferred-position metadata. It rejects
non-Boolean Siri data, duplicate or missing Time Machine membership, and an
intervening value change before inverse. Both `-Onone` and `-O` builds pass 15
pure checks. The optional `--snapshot` mode performs exactly five
`CFPreferencesCopyValue` reads. There is no APPLY mode, setter, synchronize call,
notification, private-controller initialization or assertion path.

The subsequent app implementation does not turn these research probes into
writers. It separately implements current-build capability descriptors for Siri,
Time Machine and Now Playing, then maps their item-scoped persistent transitions
onto the ordinary Visible / Revealable / Hidden policy state machine. The pure
Now Playing mask/inverse remains the source of the exact restoration contract;
the first live Now Playing transition still requires an installed stopped-state
preflight and explicit owner authorization.

The product follow-up deliberately does not add an APPLY mode to this research
tool. Instead, the Debug app has a separate owner-operated panel backed by a
runtime-gated bridge to Apple's item-specific Siri and Time Machine setters. It
uses a single serial gate and persistent exact recovery receipts. Normal Release
strips the bridge and controls. An explicit optimized Release-configuration trial
flavor is installed for the owner's manual permission environment. The corrected
flavor also compiles the full existing manual Board catalog and exact Weather/Input
Menu exceptions; Clock and unknown identities remain read-only. Its startup
performed no mutation. Live hide/restore validation is still pending.
