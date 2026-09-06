# Technical spike 0.8.0: Apple system-item visibility on macOS 27

Status: **Complete. Bluetooth raw value `1` is the sole Apple system item
promoted to ordinary Release. The optimized owner trial validates the numbered,
exact-owner and item-scoped persistent capability families for every current
mapped target except Clock. Siri, Time Machine and Now Playing were hidden and
restored under owner observation. The final installed stopped-startup regression
preserved every restored preference, receipt and policy baseline.**

Date: 2026-09-03
Runtime: macOS 27.0 build `26A5416b`, arm64, one 1600 × 900 point display at 2x
Toolchain: Xcode 27.0 beta build `27A5237l`, macOS 27 SDK
Starting point: clean `5768266c15a20de0ff4b580d8ace2aa4a651ccb1`, equal to
`v0.7.0^{}` and `origin/main`

## Question and safety decision

This spike asks whether one Apple system menu-bar item that macOS itself permits
the user to hide can be concealed through Blenny's existing process-owned,
Debug-only macOS 27 assessment assertion and then restored exactly. Bluetooth is
the only approved real-write candidate. Battery, Wi-Fi, Clock, Control Center and
the native overflow control are observation-only. No other system item is an
implicit fallback target.

The answer is **promotable for Bluetooth only on the exact gated runtime**. The
final installed observation resolved the apparent native-overflow coupling, and
exact recovery passed after the normal menu-bar reflow settled. Release and the
formal policy expose Bluetooth Visible / Revealable / Hidden intent. Every other
Apple item remains read-only.

## Public surface

Apple's linked macOS 26 user guide says Bluetooth and Wi-Fi may be selected for display
in Menu Bar settings, Battery may be selected on a laptop, and Clock is always
shown. This makes Bluetooth a lower-risk candidate than Clock and avoids inventing
a state that System Settings does not offer. This is historical public UI
precedent, not documentation of a macOS 27 developer API or its private contract:

- [Apple: Change Menu Bar settings on Mac](https://support.apple.com/en-gb/guide/mac-help/mchlad96d366/26/mac/26)
- [Apple: Customize the menu bar on Mac](https://support.apple.com/guide/mac-help/customize-the-menu-bar-mchl4af84660/26/mac/26)

AppKit's public `NSStatusItem.isVisible` controls only the caller's own status
item. Its value persists through the caller's `autosaveName`, and it still reports
true when an item is merely displaced by insufficient space. It is not a
cross-process or Apple-system-item API:

- [Apple: `NSStatusItem.isVisible`](https://developer.apple.com/documentation/appkit/nsstatusitem/isvisible)

No public AppKit, Accessibility or System Settings API discovered in this review
lets a third-party process hide an exact Apple system item. Accessibility supplies
read-only identity and geometry on the inspected runtime; scoped positions are not
settable.

## Private runtime and preference findings

Read-only static inspection of the system's `MenuBarClientCore.framework` confirms
the assessment contract isolated by Blenny:

- `MBAssessmentModeConfiguration`
- `initWithAllowedSystemItems:allowedBundleIdentifiers:`
- `MBAssessmentModeAssertion`
- `activateWithConfiguration:completionHandler:` and `invalidate`

The framework also exports a private `MBSystemItemIdentifier` value type. The
standalone, read-only probe in
[`Research/0.8.0`](../Research/0.8.0/README.md) enumerated the exact runtime
catalog without creating a configuration or assertion:

| Raw value | Private string | 0.8.0 treatment |
| ---: | --- | --- |
| 0 | `battery` | read-only, allowed |
| 1 | `bluetooth` | sole candidate to exclude |
| 2 | `clock` | read-only, allowed |
| 3 | `displays` | allowed |
| 4 | `keyboard` | allowed |
| 5 | `volume` | allowed |
| 6 | `wifi` | read-only, allowed |
| 7 | `screenMirroring` | allowed |
| 8 | `primaryBentoBox` | Control Center boundary; read-only, allowed |

The local Control Center settings-intent extension contains strings such as
`showBluetoothStatusInTheMenuBar` and `showBluetoothStatusInControlCenter`.
Those strings alone do not establish callable actions. Its actual metadata
declares a module `showInMenuBar` update intent, as detailed in the identifier
follow-up below. Neither is a documented cross-application visibility API.
Blenny does not invoke the extension.

Current scoped preference evidence is consistent with the UI and AX identities:

| Domain | Current relevant evidence |
| --- | --- |
| `com.apple.controlcenter` | `NSStatusItem VisibleCC Bluetooth = 1`; preferred position `Bluetooth = 5781`; analogous current Wi-Fi, Clock and Sound values |
| `com.apple.systemuiserver` | legacy `NSStatusItem Visible com.apple.menuextra.bluetooth = 1`; preferred position `345` |
| `com.apple.MenuBarAgent` | analytics only in the current file; no current `TrailingItemPreferredPositions` table |

These preferences are snapshot evidence, not the selected write route. Direct
preference writes have unresolved cache, owner, notification and restoration
semantics and may require a forbidden system UI restart to become effective.
The 0.8.0 plan performs zero preference writes.

## Existing tools

This review treats vendor behavior as corroboration, not an implementation source:

- [Ice](https://github.com/jordanbaird/Ice) uses AppKit-owned divider status items
  and width expansion for its traditional sections. Its
  [control-item source](https://github.com/jordanbaird/Ice/blob/main/Ice/MenuBar/ControlItem/ControlItem.swift)
  does not establish a safe Apple-system-item visibility contract for macOS 27.
- [Thaw macOS 27 Preview 5](https://github.com/thaw-app/Thaw/releases/tag/macos-27-preview.5)
  reports cursor-free work, Apple system-item hiding and a
  `TrailingItemPreferredPositions` path, but its preview notes also document
  dynamic-item, restoration and system-item exceptions. Its
  [item-manager source](https://github.com/thaw-app/Thaw/blob/macos-27-preview.5/Thaw/MenuBar/MenuBarItems/MenuBarItemManager.swift)
  is read as independent evidence only; Blenny neither copies it nor links Thaw.
- [Bartender's macOS 27 notes](https://www.macbartender.com/goldengate/releases/)
  claim mouse-free movement but also say some Control Center widgets cannot be
  hidden, layout can drift, and a menu-bar restart may be needed after failures.
  Those recovery assumptions are outside Blenny's boundary.

The public evidence therefore supports continued caution: other tools demonstrate
that macOS 27 has new internal routes, not that every Apple item has stable,
reversible semantics suitable for Blenny.

## Exact identity mapping

One complete read-only AX sample on this runtime supplied the live mapping:

| Product name | Private identity | AX identity | Preference identity |
| --- | --- | --- | --- |
| Bluetooth | `1 / bluetooth` | `com.apple.menuextra.bluetooth` | `Bluetooth` and legacy `com.apple.menuextra.bluetooth` |
| Wi-Fi | `6 / wifi` | `com.apple.menuextra.wifi` | `WiFi` |
| Clock | `2 / clock` | `com.apple.menuextra.clock` | `Clock` |
| Control Center | `8 / primaryBentoBox` boundary | `com.apple.menuextra.controlcenter` | preserved, never written |
| Native overflow | not treated as a system-item candidate | one identifier-less classified AX control | none written |

The mapping is build-specific. A fresh installed snapshot must still observe
exactly one Bluetooth, Wi-Fi, Clock, Control Center and native overflow control.
Historical or preference-only presence cannot substitute for that fresh sample.

## Prepared Debug experiment

The implementation is isolated under `#if DEBUG`:

- `SystemItemVisibilityPlan` binds runtime, the complete private catalog, exact
  baseline, bounded duration and SHA-256 fingerprint.
- The only assessment configuration is system allow-list
  `[0, 2, 3, 4, 5, 6, 7, 8]`. It omits only Bluetooth raw value `1`.
- The application allow-list is every bundle identifier visible in one bounded
  `NSWorkspace` snapshot, including Blenny and MenuBarAgent. The final PREVIEW
  saw 141 identifiers; later departures are benign, while any addition fails
  before activation or during the one applied-state verification.
- One existing `RevealAssertionWriter` owns activation and invalidation. No
  second writer, preference writer, helper or reconciliation task exists.
- After activation, one one-second-delayed AX snapshot must show Bluetooth absent,
  all other system-item counts and the native overflow count unchanged, and all
  scoped preferences and file hashes unchanged.
- Normal exit invalidates the assertion, waits once for one second, and requires
  exact system identity counts, native overflow count, scoped preferences and
  file hashes with no application-set expansion. AX frames remain recorded
  evidence but ordinary reflow is not visibility drift.
- There is no automatic write retry. Activation or verification failure causes
  one invalidation. A failed restore comparison stays terminal and visible.
- Process-disconnect cleanup is a secondary safety property of the process-owned
  assertion, not a substitute for explicit invalidation and comparison.
- `RECOVER` is a read-only installed mode that compares current state with the
  reviewed receipt. It cannot create a writer or attempt an unbounded repair.

The exact file snapshot includes the three relevant preference plists, matching
bounded ByHost plists, and Blenny's accepted-policy and previous-policy files.
The exact scoped preference snapshot includes all `NSStatusItem` values from the
three domains plus MenuBarAgent's position table if it exists. Raw receipts and
machine identifiers stay in ignored `LocalData/0.8.0/`.

Thirteen system-item deterministic tests cover exact target/catalog binding, incomplete
snapshots, read-only plan construction, confirmation and stale-state rejection,
single-writer activation/restoration, failed verification rollback, terminal
restore mismatch, semantic preference equality with changed-value rejection,
non-expanding bundle scope, benign departures, layout-only reflow, dynamic
non-protected system items and Bluetooth-hidden applied capture, plus rejection of
every broader plan. Policy tests cover approved bundles without a
current ownership observation and multi-PID consolidation across bundle-level
Visible, Revealable and Hidden intent. The complete Xcode 27 matrix
passes: 312 Debug tests in 33 suites and 267 Release tests
in 28 suites.
Both app configurations build as arm64 with minimum OS and SDK 27.0, strict
ad-hoc signatures and version 0.8.0. The validation delegate, environment keys,
receipts and snapshot backend remain Debug-only. Release contains the same
runtime-gated assessment factory and single serial writer used by ordinary bundle
policy, now with the Bluetooth-only system allow-list delta.

## Installed PREVIEW result

The Debug 0.8.0 app was built with the required Xcode, installed at
`/Applications/Blenny.app`, verified as the exact built binary and launched
through the isolated PREVIEW delegate. The original installed 0.7.0 bundle is
recoverably preserved under ignored local evidence.

The first diagnostic attempt scanned the full application set through AX and hit
the bounded time limit. The implementation was corrected: AX now scans only the
single MenuBarAgent process, while the assessment allow-list still contains all
running bundle identifiers.

The corrected installed PREVIEW then reported:

- one MenuBarAgent process;
- zero available MenuBarAgent AX trees;
- zero current system AX identities and zero native overflow controls;
- three scoped preference snapshots, ten local file digests and 141 running
  bundle identifiers;
- `VALIDATION FAILED incompleteSnapshot`;
- `writerCreated=false` and no assertion invalidation required.

A separate read-only probe returned `AXError.noValue` for MenuBarAgent's
`AXExtrasMenuBar` at the same checkpoint. After the owner restored an ordinary
collapsed menu-bar state, PREVIEW obtained one AX tree, exactly one Bluetooth,
Wi-Fi, Clock and Control Center identity, and one native overflow control. The
immediate second exact capture had the same counts but did not equal the baseline,
so the stale-state gate rejected it twice. A later diagnostic sample exposed two
native overflow presentation controls and failed the one-control completeness
gate. Blenny does not reinterpret any of these states as Bluetooth absence and
does not fall back to a preference-only write. No receipt was produced, no
fingerprint is eligible for approval, and no real mutation was performed.

The duplicate overflow observation was not a second canonical control. The broad
diagnostic inventory traversed both `AXExtrasMenuBar` and a separate MenuBarAgent
presentation root under the same source label. The experiment now excludes the
secondary presentation roots and uses only the canonical root already required by
ordinary native observation. The canonical snapshot contains one overflow control.

The remaining stale comparison was isolated to encoded scoped-preference bytes:
the semantic values, preference-file hashes, AX observations and application list
were unchanged. Property-list dictionary encoding order is not state. Scoped
preferences now compare decoded property-list values exactly, while the file layer
continues to compare exact byte count and SHA-256. A deterministic test proves that
two encodings of the same values compare equal and a changed Bluetooth value does
not.

The first successful installed PREVIEW produced two equal complete snapshots with one
Bluetooth, Wi-Fi, Clock, Control Center and native overflow observation, three
scoped preference domains, ten file digests and 134 running bundle identifiers.
It wrote the ignored receipt with mode 0600 and fingerprint
`0b547519bccc20df90801b4bf7d68b0e6e71febb673082b687719099d97dba32`.
It reported `writerCreated=false`, `assertionCreated=false`,
`preferenceChanged=false` and `fileHashChanged=false`. A later installed
read-only RECOVER matched the receipt exactly. This fingerprint was eligible at
that checkpoint and was not used for APPLY.

The final installed Release regression then changed the running application set,
so read-only RECOVER correctly rejected that receipt. It was archived as local
evidence and is not authorizable. Later fingerprints
`99c3f8f4e86afbbf373c80a9e1a4b00b942bfd46e45d44a1b99cf4a209afa578`
and `ccf887b15406c085110bb95d137f805781a5996613fb3fd3a0ff598f1bb018ec`
received exact authorization, but their final read-only preflights saw unrelated
application-set churn and refused before writer creation. No APPLY occurred.

That evidence identified two checks that were stricter than visibility safety
required. Schema 2 permits a previously frozen bundle to exit while continuing to
reject any newly running bundle. A later installed Release regression kept the
same 141 bundle identities, protected system identity counts, preference values
and file hashes but changed only AX frames. Schema 3 therefore records frames as
diagnostic evidence without treating ordinary menu-bar reflow as visibility drift.
Freshness and restoration still require exact system identity counts, one native
overflow control, semantic scoped preference equality, exact file digests and a
running-bundle set that is a subset of the reviewed allow-list.

After the complete Debug/Release matrix, installed ordinary active-management
regression, installed Release launch/normal-Quit regression and restoration of the
exact Debug build, PREVIEW produced two complete snapshots with 141 running bundle
identifiers and fingerprint
`acead2927bcac4cde1dbb71e68c3127fcf11ba1edfac1ae8d4b54ae1370b5acf`.
An immediate read-only RECOVER passed. Time-based state changes later made that
receipt stale; the owner explicitly authorized a fresh receipt without another
round trip when target, change, risk and recovery remained identical.

## Authorized APPLY results

A fresh installed PREVIEW and immediate RECOVER passed with 132 bundle identifiers
and fingerprint `d17fe0a7e79937bee3eac4d68fd80727022754b9005e4878696c196a0b1ba577`.
The first owner-authorized APPLY created the single writer and assessment
assertion. Its applied AX sample showed Bluetooth absent while Wi-Fi, Clock,
Control Center and native overflow remained present. A dynamic Now Playing item
was also absent. Verification nevertheless failed early because the backend used
baseline completeness validation, which incorrectly required Bluetooth to remain
present even in an applied-state capture. Serial invalidation restored the reviewed
baseline; the in-process restore and independent read-only RECOVER both passed,
including semantic preferences and exact file hashes.

The deterministic defect was corrected so backend capture validates bounded
structure while the plan separately validates baseline and applied states. The
danger comparison was also narrowed to the explicitly protected identities:
Bluetooth, Battery when present, Wi-Fi, Clock, Control Center and native overflow.
Dynamic non-protected items remain recorded but do not create a false failure. The
new test proves that a Bluetooth-hidden capture reaches applied verification.

After 13 focused tests, the 306-test Debug matrix, a rebuilt exact installed Debug
app, fresh PREVIEW and immediate RECOVER, the one allowed retry used fingerprint
`9c0bf7534580a776907aa5e0544b1835cdaea8b81cc11655750d06d62e577f3e`.
Bluetooth disappeared, but native overflow also disappeared in the same applied
sample. That protected-state change failed verification and triggered immediate
serial invalidation. The following sample again contained Bluetooth and native
overflow, but the exact restore comparison failed. No second retry was attempted.

Independent read-only evidence after invalidation established:

- Bluetooth, Wi-Fi, Clock and Control Center were present once each;
- native overflow was present once;
- the frozen bundle set had not expanded;
- all three scoped preference domains were semantically equal to the reviewed
  values;
- Blenny's accepted-policy and previous-policy hashes and 0600 modes were unchanged;
- one bounded Control Center `displayablemenuextras` ByHost plist retained the
  same byte count but a different SHA-256 from the reviewed receipt.

The reviewed receipt stored this file's digest, not its original bytes, and no
preference-write recovery path was authorized. Blenny therefore did not write the
file. Bounded read-only forensics parsed its one `displayablesInfo` data value and
reconstructed the only alternate order of its two nested JSON keys. That 189-byte
candidate exactly matched the reviewed SHA-256; the current bytes exactly matched
the reverse key order. Both decode to the same empty `displayableInfos`, identical
`providerData` and identical outer property-list value. The logical system state
is therefore restored, while the intentionally stricter byte-exact acceptance
criterion remained failed for that receipt and drove the provisional no-go. A final installed PREVIEW and
read-only RECOVER proved the current state stable. Raw receipts, reconstructed
bytes and the machine-specific filename remain only under ignored
`LocalData/0.8.0/`.

## Startup recovery correction

The installed ordinary app exposed an independent over-strict preflight. The
accepted policy still contained Visible `xyz.fi5h.Usage4Claude`, but that app had
no current menu-bar ownership observation. Startup therefore entered
`failClosedUnrestricted` even though an absent approved bundle does not make the
current assertion ambiguous.

Policy validation now limits danger detection to mutation scope:

- a previously approved bundle retains its exact bundle identifier and Visible /
  Revealable / Hidden intent without requiring a current ownership observation,
  whether dormant or running;
- multiple owner PIDs for the same approved bundle consolidate under the one
  bundle-level policy identity;
- Blenny itself must remain Visible in policy;
- unknown owners and unknown new bundle identifiers still fail closed because
  either could cause an unapproved menu item to be hidden;
- a later application launch still crosses the existing event-driven lifecycle
  revalidation boundary; no polling or automatic reconciliation was added.

One bounded installed normal run reproduced the missing-Usage4Claude state. The
old build reported inactive; the corrected build activated the exact baseline,
reported `management=active`, fell back safely when the native overflow control
became absent, and explicitly restored the serial writer on normal Quit. The
accepted-policy and previous-policy files were not rewritten.

The earlier ordinary installed Debug no-writer regression prepared the existing
bundle-policy plan, passed its AppKit fixtures, retained Hidden exclusion and
reported `writerCreated=false`, `assertionCreated=false` and
`persistenceChanged=false`; its native observation independently remained
unavailable. At that checkpoint Release still had no backend. The accepted-policy and previous-policy
SHA-256 values remained `01ed8828...fdee57` and `42e61287...1593fbf`, modes
remained 0600, and no Blenny process remained. The later promotion regression is
recorded below.

## Risk, restoration and authorization gate

The owner authorization named all of the following before APPLY:

- target: Bluetooth only, private raw value `1`, AX identifier
  `com.apple.menuextra.bluetooth`;
- change: activate one bounded Debug assessment assertion whose system
  allow-list omits only `1`; no preference write or system UI restart;
- risk: the private mapping or assessment semantics may differ despite the build
  gate, another just-launched application could be temporarily absent from the
  frozen bundle list, AX verification may fail, and a crash may prevent the
  in-process comparison even though process disconnect should release the
  assertion;
- recovery: explicit serial invalidation, one delayed exact visibility/preference/hash
  comparison, followed by read-only `RECOVER` if the process did not record a
  complete comparison;
- exact reviewed receipt fingerprint.

The first exact fingerprint was authorized in a separate message. When elapsed
time changed only the bounded receipt, the owner explicitly delegated refresh of
the same target/change/risk/recovery contract. The one permitted retry followed
the verification defect correction and another installed PREVIEW. Both real runs
are accounted for above. The owner later explicitly authorized a fresh observation
without another fingerprint round trip and requested the Bluetooth-only Release
promotion after visually accepting the result.

## Final owner-observed validation and installed promotion

Schema 5 kept one Bluetooth-only applied capture, protected Wi-Fi / Clock /
Control Center counts, semantic scoped preferences, exact file hashes and the
non-expanding application set. Native overflow was permitted to be either present
or absent because its presentation depends on the active application's available
menu-bar width. The 60-second installed run reported Bluetooth absent, protected
counts unchanged, native overflow `0`, preferences unchanged and file hashes
unchanged. The owner observed the menu bar directly and confirmed that switching
to another application restored native overflow while Bluetooth remained hidden.

The deadline invalidated the assertion. Its one-second in-process sample was still
inside the visual reflow window and reported restoration unverified; the immediate
independent read-only RECOVER then matched Bluetooth, native overflow, all protected
items, semantic preferences and every exact file hash. No preference recovery write
was needed.

Formal policy schema 3 adds one `bluetoothPolicy` value with safe migration of
schema 1 and 2 documents to Visible. Baseline and ordinary-reveal plans implement:

- Visible: raw `1` allowed in both plans;
- Revealable: raw `1` excluded at baseline and allowed only in a user reveal;
- Hidden: raw `1` excluded from both plans.

The Board retains a synthetic Bluetooth recovery entry when the hidden item is no
longer observable. Wi-Fi, Battery, Clock, Control Center and native overflow have
no mutation action. Installed Debug dry-run prepared the current Bluetooth-visible
plan with `writerCreated=false`, `assertionCreated=false` and no persistence change.
The exact tested Release build was then installed; startup preserved both policy
file hashes.

## Promotion decision

Bluetooth is promoted to formal Visible / Revealable / Hidden policy and Release
on the exact macOS 27 build contract. The promotion does not generalize from the
catalog: Wi-Fi, Battery, Clock, Control Center and native overflow remain read-only.
An unknown runtime fails closed before factory creation. Mutation still uses one
serial writer, bounded activation and verification, at most one retry of an exact
failed plan, and process-owned invalidation. There is no preference write,
synthetic input, polling, reconciliation, injection, private entitlement, helper,
SIP change or system UI restart.

## Remaining exit sequence

1. Keep every Apple item other than Bluetooth out of formal policy until a
   separate exact identity, snapshot, restoration, deterministic-test and
   installed-dry-run gate is complete. The subsequent owner request opens
   individual Debug trials for additional system items, beginning with Wi-Fi;
   Clock and native overflow remain read-only.
2. Reconcile any trial findings in English and ignored Chinese documentation.
3. Run `$blenny-release` only after the owner explicitly asks for it.
4. Create annotated `v0.8.0` only after that audit and acceptance.
   Do not modify `v0.7.0`,
   rewrite history or push any ref.

The installed follow-up also found two presentation-only icon mismatches. macOS
27 has no `bluetooth` SF Symbol, but AppKit publicly provides
`NSImageNameBluetoothTemplate`; Blenny now uses that native Bluetooth template.
The SDK does provide the dedicated `siri` SF Symbol, which replaces the generic
sparkles placeholder. Neither correction changes policy, plans, fingerprints or
assertion behavior.

The follow-up passed the unchanged Xcode 27 matrix: 312 Debug tests in 33 suites,
267 Release tests in 28 suites and both app builds. The corrected Release was
installed after a normal Quit and started with the owner's current Bluetooth
intent still `Revealable`. Accepted-policy and recovery-backup SHA-256 remained
`b78eec9cb8d0ec57a92a7d66ca33593f5cff7a36610da2262d83dbfd8e75bdd6`
and `d36592309ff2e4ffe4e1e9ed6fc97f384b4e04435394e953f877be0deb2f45ee`;
both files remained mode `0600`. The installed executable matches the tested
Release build at
`08ece3c9997af877434d61a37dc4628253e836f6d32f8251e384e974c2dbfa41`.

## 2026-09-04: identifier research follow-up

The owner requested read-only investigation of numeric system-item identities,
including older APIs and independent tools, before further implementation.
Three parallel research tracks examined the runtime, public tool source and
historical/API identity distinctions. Consolidated evidence and reproduction
anchors are in
[`Research/0.8.0/IDENTIFIER_FINDINGS.md`](../Research/0.8.0/IDENTIFIER_FINDINGS.md).

Static disassembly confirms that `MBSystemItemIdentifier` is a closed enum with
exactly values 0...8 on this build. Siri and Now Playing are not missing entries
in a dynamically allocated number space. MenuBarAgent has a separate eleven-case
internal enum whose ordinals must not be passed to the framework. Thaw Preview 5
uses the assessment assertion family and the same nine-value catalog, alongside
preference/position mechanisms with recovery assumptions Blenny does not adopt.

Private ControlCenter exports provide Siri-specific visibility properties and a
string-addressed module preference controller. Settings AppIntent metadata
corroborates module visibility editing. These are promising static leads, not
proof of external permission, live application without restart, safe temporary
reveal, or exact restoration. The next useful investigation is their exact
identity, storage and notification semantics, not guessing larger numbers.

No new real write, product/runtime edit, install, app restart, release audit,
commit, tag or push occurred. Installed executable and accepted-policy/backup
hashes remained unchanged. This documentation-only follow-up does not repeat or
extend the earlier Debug/Release test matrix or promote any additional item.

## 2026-09-04: continued API research and lifecycle correction

The owner excluded earliest-OS research and requested continued macOS 27 work,
plus a fix for recurrent inactive-management notices without manually launching
or restarting an app. Workspace launch notifications can also originate from
background activity; the old notice did not identify the triggering bundle, so
the exact historical process cannot be reconstructed from that message alone.

Static Settings call-site research now resolves Now Playing to controller string
`NowPlaying`, domain `com.apple.controlcenter`, current-user/current-host packed
flags. Siri routes through `SiriPreferences.statusItemEnabled`, whose backing
setter also removes a stashed value before setting visibility. A new excluded
probe made six non-synchronizing CFPreferences reads of the exact keys/scopes.
The [identifier report](../Research/0.8.0/IDENTIFIER_FINDINGS.md) records verified
call sites, bit semantics and unresolved permissions/live-effect/recovery gates.
No private setter, assertion experiment, system preference write or UI restart
was performed.

The lifecycle defect was separate from the earlier startup-preflight correction:

- Accepted bundle launch/quit still invalidated a bundle-scoped assertion as if
  policy depended on PID lifetime. It now retains the same exact plan/writer.
- Lifecycle checks read unapplied Draft scope. They now use accepted policy;
  draft-only entries do not gain authority and removing an accepted entry in an
  unapplied Draft does not revoke its current policy.
- A positive no-extras result for one process no longer inherits an unrelated
  incomplete batch's failure. An observed-but-incomplete or unavailable read
  remains uncertain.
- Confirmed unrestricted cleanup is a neutral, truthful pause notice with saved
  intent, not a red danger banner. The remaining new-application notice includes
  its bundle identity and Resume action. Unconfirmed cleanup remains an error.

The deeper frozen-allowlist limitation remains: a genuinely new bundle is not
automatically admitted. Even background-only activation policy cannot prove it
has no status item, so it cannot safely bypass this boundary. Unknown launches
retain bounded assessment, or immediate generation invalidation during an active
transaction. No automatic writer replacement is added. The owner has been asked
whether to authorize an event-triggered, additions-only pass-through update as a
narrow exception to the original no-automatic-reconciliation rule; it is not
implemented or treated as approved.

Verification: 316 Debug tests / 33 suites and 271 Release tests / 28 suites pass
with the required Xcode 27 toolchain. Both app builds and strict signatures pass.
The existing AppDelegate main-actor warning remains; it predates this change.
The lifecycle correction has not yet been installed or subjected to installed
regression: the existing installation and accepted-policy/backup hashes remain
unchanged while the remaining behavior decision is pending. No release skill,
commit, tag or push was invoked.

## Owner-authorized additions-only lifecycle maintenance

The owner explicitly approved bounded additions to the visibility allowance via
the sole writer and asked whether this would cause frequent refresh or lag.
This is a narrow exception to the earlier frozen-allowlist/no-automatic-update
rule, not permission for background hiding, position writes or drift repair.

Implemented behavior:

- Launch events for accepted or already-allowed bundles do nothing. Other events
  coalesce by bundle identity in one fixed 250 ms window; later arrivals do not
  reset the timer. A multi-process launch contributes one identity, not one write
  per PID. No timer is scheduled without pending launch events and active plans.
- A batch takes one Workspace snapshot. Named bundles do not cause an AX or icon
  inventory, candidate refresh, disk-policy write, or editor-model replacement.
  Only processes without a usable bundle identity retain bounded AX handling.
- Pure plan preparation adds only previously unaccepted, unallowlisted identities
  to both baseline and reveal plans. It preserves accepted policy and every
  system-item value exactly. No Hidden or Revealable assignment is promoted to
  pass-through by the event path.
- The management actor snapshots the existing writer's exact active plan and
  checks the additions-only delta before using that same serial writer. There is
  one replacement and one verification, no retry, and no writer acquisition or
  automatic Resume. Replacement activation precedes old-assertion invalidation.
- Updates wait for the existing interaction gate during startup, Apply, Reveal
  or Refresh, then prepare against the resulting plans. Stop, permission/session
  loss and termination retain generation-based cleanup. Failed additions remove
  restrictions rather than retain a plan that might hide an unaccepted app.
- An existing Reveal retains its session identity and original timeout task.
  Native reflow during the update cannot queue a compensating write; explicit
  input and an already-fired timeout remain pending for the gate to drain.
- Successfully admitted identities remain in memory for the active management
  session, including ordinary app exits. They are not saved as policy entries and
  are cleared when management becomes stopped, failed, unsupported or terminating.
  Queue capacity is 256 distinct identities; session additions are capped at 4096
  to bound memory/plan growth. An exhausted capacity safely pauses instead of
  looping. There is no arbitrary lifetime write-count budget: each later batch
  requires a genuinely new external launch event, not self-triggered reflow.

Performance expectation is structural, not yet measured: routine launches are
set comparisons; a new batch incurs one asynchronous assertion replacement plus
its verification and existing bounded native observation. No full refresh or
continuous reconciliation occurs. The batching window itself may delay a new
item's admission by 250 ms (longer while an explicit action holds the gate).
Private-system reflow and real latency still require installed observation; do
not promise zero flicker from unit tests.

Deterministic verification passes 330 Debug tests / 34 suites and 285 Release
tests / 29 suites. Added coverage includes additive-only deltas, system/policy
preservation, duplicate-event batches, exact verification failure cleanup,
stopped-writer rejection, Stop racing a late completion, Reveal presentation and
deadline retention, and native reflow not adding writes. A test initially exposed
Set-order-dependent duplicate-error spelling; reporting now uses the canonical
identity and is deterministic.

The installed no-writer dry-run now includes a pure additions-only fixture but
has not yet been executed for this build. The owner has been asked to observe
the existing menu bar before normal Quit of the old installed app, respecting
the requested pre-rollback observation checkpoint. Installation, live launch
regression and observed timing remain pending that checkpoint. No new real
assertion, system preference write, release audit, commit, tag or push occurred
while preparing this change.

## Broader system-item trial preparation

The owner subsequently said to begin trying all system items. This opens
individual trial preparation, not simultaneous writes or blanket Release
promotion. Clock remains excluded by the earlier specific decision; native
overflow is observation-only. Wi-Fi is the next exact Debug target. Sound,
display, keyboard brightness, screen mirroring, battery and Control Center have
grounded AX candidates in the identifier report; absence in this machine's
current AX sample is not evidence of an unsupported control. Siri and Now
Playing still need separate preference-route restoration contracts.

Schema 6 binds a closed Bluetooth/Wi-Fi target, its raw and AX identity, complete
snapshot and exact allow-list to the receipt fingerprint. The Wi-Fi plan removes
only raw value 6 from 0...8. Every other observed catalog identity is protected,
including optional Sound/display/keyboard-brightness/screen-mirroring entries;
optional hardware icons need not be present at baseline. Dynamic native overflow
may be absent or singular at baseline, application and restoration. No clock or
overflow mutation is introduced, and malformed/older receipts are rejected.

The 60-second trial now emits a warning with 30 seconds remaining. The operator
must relay the checkpoint before normal rollback so the owner can observe;
failure cleanup still cannot be postponed if restoration is needed. A trial
must disclose this bounded observation deadline before execution. Zero retries,
one serial writer, no system preference writes and independent read-only RECOVER
remain the contract.

The earlier additions-only implementation was installed after normal Quit of the
old app, which was preserved in ignored LocalData. Installed no-writer regression
passed, including the pure pass-through fixture: no writer/assertion creation,
policy persistence or management-intent change. The process exited normally and
accepted-policy/backup hashes matched. This is not a live performance or visual
reflow pass. No new system-item APPLY has occurred during this preparation.

The expanded Debug implementation passes 333 tests / 34 suites; Release passes
285 / 29 suites. Both app builds pass strict signature, arm64 macOS 27 minimum
and SDK checks, and the Debug trial entry points are absent from Release. The
exact tested Debug app was installed while Blenny was stopped. Its Wi-Fi PREVIEW
passed two captures against the same receipt with no writer, assertion,
preference change or file-hash change, then exited normally. The receipt and
raw log are mode 0600 under ignored LocalData. Accepted policy and backup hashes
still match the pre-install baseline. Execution remains pending the exact Wi-Fi
trial disclosure/authorization; no real Wi-Fi result is claimed.

Review limitation: protected-count verification covers the nine mapped catalog
identities, not every transient/unmapped AX item. It is a bounded snapshot check,
not continuous coverage of applications launched later during the observation
window. Do not claim universal target-only behavior from a passing receipt.
If restoration verification fails, normal process termination still proceeds to
release process-owned state; independently run read-only RECOVER and report the
failure rather than calling the trial restored. A failed verification does not
authorize preference repair, another APPLY or UI restart.

## Owner-operated Debug Board controls (supersedes sequential trials)

The owner clarified that the requested build should expose all usable controls
for manual testing, rather than asking for one automated trial at a time. No
Wi-Fi APPLY was executed under the prior receipt. The timed diagnostic delegate
is no longer the requested workflow and will not be invoked for this handoff.

The Debug policy catalog permits Bluetooth and the seven additional exact
assessment mappings: Battery (0), Display (3), Keyboard Brightness (4), Sound
(5), Wi-Fi (6), Screen Mirroring (7) and Control Center (8). Clock (2) remains
excluded by the owner's earlier specific decision. Native overflow has no
promoted identity. Siri, Now Playing and unknown items remain visible as
read-only observations; a label or boolean permission cannot implement their
missing backend route. The catalog does not guess extra raw values or use a
shared Apple host bundle as a substitute for per-item identity.

The ordinary Board, Review/Apply, one serial writer and explicit Reveal semantics
are reused. A selected Visible item stays allowed; Revealable is allowed only
during ordinary reveal; Hidden stays excluded from ordinary reveal. A hidden
accepted item retains an editable recovery row after refresh. Unknown/Clock keys
are rejected rather than silently converted into application policy. Existing
failure, Stop, transaction rollback and process-exit cleanup remain in force.

Manual Debug policy and its previous-policy backup live separately from the
production store under `Blenny/ManualSystemItemTrial` in Application Support.
The initial policy imports production intent read-only, with management disabled.
Every launch starts stopped and requires an explicit Apply/Resume; read-only
dry-run creates neither policy files nor a writer. Refresh does not disable an
ongoing manual trial. Only Debug accepts additional system policies; Release
cannot decode/execute a nonempty experimental policy. Production policy and
backup are never written by this Debug session.

The owner controls the observation period: no 60-second automatic rollback is
scheduled. Stop or Quit releases process-owned restrictions; selecting Visible
and applying also removes that item's restriction. No wireless/radio settings,
system visibility preferences, system process restart or input synthesis is
added. Private-interface visibility and broader layout effects remain unverified
until the owner tests them. A successful writer acknowledgement is not proof of
visual hiding or complete physical restoration. This manual-test authority does
not promote additional items to Release or authorize a release audit, tag or push.

Verification: Xcode 27 Debug passes 341 tests / 35 suites and Release passes 292
/ 30 suites. Both app builds and strict signatures pass, with macOS 27 SDK and
minimum deployment. Release excludes the manual-trial store/UI/disable entry
points and rejects experimental policy decoding and planning. An early Release
test run incorrectly ran Debug-only success expectations and failed three tests;
the corrected tests assert Release rejection and the full final run passes.

Review also caught two integration defects before handoff: Bluetooth's dedicated
field needed its own dispatch in the installed dry-run fixture, and startup's
disabled-intent persistence must not rotate the trial recovery backup. The latter
now uses one idempotent, Debug-only atomic policy write, preserves exact backup
bytes, and has deterministic restoration and read-only rejection coverage.

The exact tested Debug app is installed. Its directly launched installed dry-run
passed all eight catalog controls across three policy states (24 pure plans),
Clock preservation, stopped startup, isolated store, and existing pass-through
fixtures, with no writer, assertion or persistence changes. It exited normally;
production accepted-policy and backup hashes matched. The prior installed app is
retained recoverably under ignored LocalData.

The subsequent ordinary LaunchServices launch reported Accessibility unavailable,
despite the directly launched dry-run's access. Blenny is open at its permission
setup screen, with no manual-trial policy created and no writer activated. The
owner was asked to enable Blenny in macOS Accessibility settings; do not bypass
that permission boundary by switching launch context. Manual visibility results,
actual standalone startup after permission, and final post-owner restoration are
pending. No system preference write, automated APPLY, release skill, commit, tag
or push occurred. Raw logs and installation evidence remain ignored LocalData.

## Owner results and remaining-item validation

The owner subsequently reported that Bluetooth, Wi-Fi, Control Center and Sound
all hide and show normally in the installed manual Board. This supersedes the
pending visibility checkpoint above, but does not claim independent full
lifecycle or post-owner restoration acceptance. The owner explicitly excludes
Clock from further investigation.

The [remaining-item report](../Research/0.8.0/REMAINING_ITEMS_VALIDATION.md)
records new static and bounded read-only evidence:

- Weather has a dedicated `com.apple.weather.menu` owner creating a normal
  AppKit status item. Exact bundle assessment is a candidate; Apple's Settings
  alternative modifies login/background-item state, not a simple visibility key.
- Input Menu belongs to `com.apple.TextInputMenuAgent`. Whole-item visibility
  binds to `NSStatusItem VisibleCC Item-0` and targeted distributed insert/remove
  handlers; `ModeNameVisible` changes only source-name text. Exact-owner
  assessment is a candidate, separate from persistent preference changes.
- Now Playing's exact scoped snapshot can prepare a proposed hide/inverse.
  The standalone, product-excluded model passes 95 pure checks in both Xcode 27
  `-Onone` and `-O` builds. It preserves unrelated bits and original absence and
  rejects unexpected values or conflicting restoration. It has no writer.
- Siri's notifier is resolved to `NSDistributedNotificationCenter.defaultCenter`
  with `com.apple.Siri.StatusMenuVisibilityChanged`. The two-key setter's stash
  deletion, access check and unresolved effective scope prevent treating a lone
  Boolean as complete restoration. Apple's entitlements do not establish that
  unsandboxed Blenny requires a private entitlement.

No private controller initialization, notification, setter, assertion, app
restart/replacement, or rollback was performed in this follow-up. Actual hiding
and restoration for these four remaining items are unproven. The installed app,
production policy/backup and manual policy/backup hashes matched; paired exact
NowPlaying snapshots matched. A broader comparison detected one changed
ControlCenter `displayablemenuextras` ByHost file of unestablished cause. It was
not overwritten; whole-system hash stability is not claimed.

The final pure probes pass after adding exact-build gating. Existing product
test/build results above were not rerun for research-only files. Raw evidence
stays ignored LocalData; English findings and ignored Chinese guidance are
updated. Release remains unchanged; no release audit, commit, tag or push.

## 2026-09-05: dedicated-owner Debug trial build

The host updated from build `26A5416b` to `26A5425a`. The existing exact runtime
gate rejected the new build, producing the only two failures in the first
344-test Debug run. Before changing that gate, the standalone product-excluded
`ValidateAssessmentContract.swift` probe confirmed that MenuBarClientCore retains
UUID `CA5DE7FC-32E9-327F-BC2E-BF44B4035141`, all six required class/selector
encodings, and the exact in-memory configuration round trip. It constructed no
assertion and performed no mutation. Both unoptimized and optimized probe builds
passed. Build `26A5425a` is admitted only in Debug; Release remains gated to the
previously mutation-validated `26A5416b` runtime.

The Debug candidate boundary now has exactly two Apple owning-bundle exceptions:
`com.apple.weather.menu` and `com.apple.TextInputMenuAgent`. The snapshot builder
places these exact owners in the application candidate inventory; validator and
resume-backup checks admit only these canonical identities in Debug. Every other
`com.apple.*` bundle remains rejected, and Release's exception catalog is empty.
These entries reuse the existing application bundle policy, Review, single
serial assertion writer, stopped startup and process-invalidation restoration.
No persistent system preference, notification, login item or new writer is used.

Deterministic tests cover exact inclusion, rejection of unrelated Apple owners,
Visible/Revealable/Hidden plans, baseline/reveal semantics, backup compatibility
and Release exclusion. The final Xcode 27 matrix passes 345 Debug tests / 35
suites and 296 Release tests / 30 suites. Both app configurations build with
macOS 27 SDK/minimum deployment and pass strict signature verification.

The exact Debug app was installed after confirming no Blenny process was active;
the prior installation was retained under ignored LocalData. Its read-only
installed dry-run observed both current owners and passed six policy plans. It
reported `writerCreated=false`, `assertionCreated=false` and
`persistenceChanged=false`; production and manual policy/backup hashes matched
before and after. The normal installed app was then launched and starts stopped.
The owner may move Weather or Input Menu to Revealable/Hidden and explicitly
Apply. Stop, Quit, or assigning Visible and applying releases the process-owned
restriction. Actual live hiding and restoration remain owner-observation gates.
No Release invocation, commit, tag or push occurred.

## 2026-09-05: owner confirmation, semantic icons and shared-host routes

The owner confirmed that Weather and Input Menu both hide and return during
Reveal without an observed problem. They remain exact application-level
assertion identities, but that implementation detail must not dictate their UI
artwork. The Board now resolves `com.apple.weather.menu` to the semantic
`cloud.sun` symbol and `com.apple.TextInputMenuAgent` to `keyboard`; it no longer
shows Weather's full-color application icon or the generic question-mark
fallback. This is presentation-only and leaves policy, fingerprints and writer
plans unchanged. Focused icon tests and the full Xcode 27 matrix pass: 345 Debug
tests / 35 suites and 296 Release tests / 30 suites. Both app configurations
build, pass strict signature verification, and record arm64, minimum macOS 27,
SDK 27 and version 0.8.0.

Siri and Time Machine require a separate architecture. A current bounded AX
sample found both items inside the shared `com.apple.systemuiserver` extras root;
`com.apple.Siri` did not supply its own usable root. Excluding the shared owner
would hide multiple system items and is therefore rejected. Siri is semantically
identifiable by its AX title/description. The other item is identifier-less and
unlabeled; on this machine it correlates with the sole configured legacy menu
extra and the owner's report that Time Machine is the other remaining item. That
correlation is not a portable AX identity and must not be converted to an ordinal
or coordinate rule.

The exact current-user/any-host stored state is now read-only mapped. Siri has
`StatusMenuVisible = true` and no `SiriPrefStashedStatusMenuVisible` key. Time
Machine appears exactly once in `com.apple.systemuiserver:menuExtras` as
`/System/Library/CoreServices/Menu Extras/TimeMachine.menu`; its separate
`NSStatusItem VisibleCC com.apple.menuextra.TimeMachine` value is true and its
preferred-position value is 86. These are scoped machine observations, not
defaults to embed in product code.

Current `ControlCenter.framework` UUID
`8EE7F051-C400-3E27-A86D-C6EF5CE84565` retains the inspected
`CoreMenuExtra.timeMachine` and per-item `showInMenuBar` accessors plus
`SystemItemMenuBarPreferences.showTimeMachine` and `.showSiri`. The Time Machine
settings path constructs the exact menu-extra value and calls its per-item
setter. This supports a dedicated unsupported route, not a blind defaults write,
shared-owner assessment, private entitlement or system UI restart. Apple's
current user guide independently documents that Siri, Weather and Time Machine
can be removed through Menu Bar settings:
[Apple: Customise the menu bar on Mac](https://support.apple.com/en-gb/guide/mac-help/mchl4af84660/mac).

The product-excluded
`Research/0.8.0/ValidateSharedSystemItemPreferencePlans.swift` adds no writer.
Both unoptimized and optimized binaries pass 15 pure checks. Its optional
snapshot performs five exact `CFPreferencesCopyValue` reads and zero writes,
synchronizations or notifications. The Siri inverse binds and restores both
keys, including absence; the Time Machine inverse restores the complete ordered
array and binds the two status-item metadata values. Both fail closed on type,
membership or intervening-state changes.

No Siri notification, Time Machine setter, preference write, assertion, app
replacement, rollback or system-process restart occurred. The currently running
Blenny and its enabled manual policy were left untouched; Weather and Input Menu
are both assigned Revealable. The newly
built icon-corrected app is not installed because replacing it would first
release that active assertion; the owner requested an observation checkpoint
before any such rollback. Siri and Time Machine remain read-only until a separate
installed dry-run, serial persistent-state writer, one verification / at-most-one
retry contract and exact real-write authorization are complete. No Release skill,
commit, tag or push occurred.

## 2026-09-05: owner-operated Siri and Time Machine Debug controls

The owner requested a build in which they, rather than an automated validation
delegate, perform both the visibility transition and restoration. The new
Settings section is Debug-only and has independent Hide/Restore actions for Siri
and Time Machine. Neither item is added to the bundle-policy Board: both share
`com.apple.systemuiserver`, so that owner remains prohibited as a mutation target.

A read-only ABI probe first loaded the current `ControlCenter.framework`, obtained
the shared `SystemItemMenuBarPreferences` instance and called only the Siri and
Time Machine Boolean getters. Both returned `true`; no setter, preference write,
notification, assertion or process restart occurred. The product bridge is pinned
to build `26A5425a` and resolves the same five exact Swift symbols at runtime. A
small arm64 ABI shim is compiled only with `DEBUG`; Release contains none of the
framework path, property symbols, shim symbols or panel text.

The manual writer is separate from the process-owned assertion writer but is the
sole writer for both shared items. An explicit hide captures the exact scoped
keys, derives a deterministic hidden state, creates a mode-0600 receipt, invokes
Apple's per-item setter, waits once and verifies once. It does not retry. If that
verification fails, it attempts one exact rollback and leaves the receipt in place
unless rollback is verified. Restore first requires the current state to equal
either the receipt baseline or the deterministic applied state; any intervening
change stops without overwriting it. Siri recovery preserves both value and key
absence and posts the identified distributed notification. Time Machine recovery
preserves ordered `menuExtras`, `VisibleCC` and preferred position. Receipts live
under the Debug application-support directory and survive a crash for manual
recovery; quitting does not silently restore because the owner requested to
control the observation and rollback timing.

Four new deterministic tests cover exact proposals, serialization under concurrent
requests, one bounded failure rollback and refusal of intervening state. The full
Xcode 27 matrix passes 349 Debug tests / 36 suites and 296 Release tests / 30 suites.
Both apps build as signed arm64 binaries with minimum macOS 27 and SDK 27.

The owner then requested a Release-configuration installation because the Debug
artifact was unsuitable for their local permission state. This does not promote
the feature into normal Release: a separate `BLENNY_SHARED_SYSTEM_ITEM_TRIAL`
flavor compiles the same manual panel and bridge with optimization, while the
ordinary Release artifact continues to contain none of its framework path,
accessor symbols, ABI symbols or UI text. The trial flavor passed 300 tests / 31
suites, built and signed, and has executable SHA-256
`6d580ff8a81c76954cbabffd12738776b89735934bad664b8f68f9d04da3c226`.

Before installation, the prior app was copied recoverably to ignored LocalData.
It quit normally, releasing its process-owned management. That quit changed the
manual accepted-policy hash from `3b4cb804...` to
`c77ee1ce9803190fe9fe58802ec75e80be7f0376bd36829e104654ac94fe8437`
by persisting stopped management; the recovery-backup hash remained
`6b1a20d5ab95632a5bf22514eea9b07c096b9af852c42f59eb77f627a7a3515d`.
The policy was not rolled back. The candidate was installed and registered at
`/Applications/Blenny.app`, then launched as PID `32778`. One startup check found
no shared-item receipt directory, Siri still visible, the Time Machine menu-extra
path still present, and the policy/backup hashes unchanged from the post-quit
values. Thus installation/startup performed no shared-item mutation. The owner
now controls Hide and Restore; no live click has yet been observed. No Release
skill, commit, tag or push ran.

The owner immediately found that this first optimized flavor exposed the shared
Siri/Time Machine panel but left every Board system-item control except Bluetooth
locked. The cause was compile-flavor wiring, not runtime refusal: the dedicated
macro included the new bridge but the existing eight-item catalog, two exact Apple
bundle exceptions, persistence validation, reveal planning, current-build runtime
gate, isolated store and manual-start behavior still compiled only under `DEBUG`.

The corrected optimized trial flavor extends only those established manual-test
conditions to `BLENNY_SHARED_SYSTEM_ITEM_TRIAL`. Ordinary Release remains
Bluetooth-only and still strips the shared-item route. The corrected matrix passes
349 Debug tests / 36 suites, 296 ordinary Release tests / 30 suites and 300
optimized-trial tests / 31 suites. The signed installed executable SHA-256 is
`46cb5788a209fb2d5c0381472d0c62c92bd84aa247b009f6ce8193537c135aeb`.
It was registered at `/Applications/Blenny.app` and launched as PID `36806`.
Startup created no shared-item receipt and left both production and isolated manual
policy/backup hashes unchanged. This flavor exposes all eight exact numbered
manual controls, Weather and Input Menu, plus the separate Siri/Time Machine panel;
Clock and unknown identities remain read-only. No hide or restore was invoked by
the installation process. The superseded partial flavor is recoverably preserved
under ignored LocalData. No Release skill, commit, tag or push ran.

## 2026-09-05: system presentation and shared-item entry correction

Owner review found four presentation gaps in the corrected trial build. Weather
and Input Menu retained application-card placement and stretched pre-sized SF
Symbol bitmaps; Siri's Board observation still showed the generic read-only lock;
and a visible Time Machine item was filtered when its exact Accessibility
identifier had no localized title or description. The footer also collapsed every
application-root read failure into an unexplained count.

The fix is presentation- and recognition-scoped. The two exact Apple bundle
candidates remain application-level assertion identities internally, but are
rendered after the macOS divider. Their SF Symbols now use the same natural-aspect
`Image(systemName:)` path as numbered system items. Siri and Time Machine Board
observations map only to their exact dedicated manual target; selecting or
context-clicking one exposes Hide or receipt-backed Restore rather than pretending
the shared SystemUIServer bundle supports three policy lanes. Known Time Machine
AX identifier `com.apple.menuextra.TimeMachine` no longer requires localized text.
Unknown textless identities remain excluded.

The unreadable footer count means a running process returned an unexpected AX root
read result. It excludes the normal `noValue` / `attributeUnsupported` outcome and
does not create a candidate. The count is now a button that displays the exact
bundle identifier and AX result for every failure; there is still no log, polling
or retry. The final matrix passes 351 Debug tests / 36 suites, 297 ordinary Release
tests / 30 suites and 302 optimized-trial tests / 31 suites. The signed trial
executable hash is
`b6083ea84ac59d646cb00b9d9dcd54e38db08c47bd0675cf191e553b97b1ae79`;
it is running from `/Applications/Blenny.app` as PID `41358`. Replacement occurred
only after confirming stopped manual management, no shared-item receipt and
unchanged production/manual policy and backup hashes. Startup preserved all four
hashes and created no receipt. No Release skill, commit, tag or push ran.

## 2026-09-05: owner-validated Siri two-state Board control

The owner confirmed that both Siri Hide and receipt-backed Restore work normally
on the current macOS 27 build. Siri therefore now behaves like an ordinary
draggable Board item for the two states the dedicated setter actually supports:
dragging Visible to Hidden invokes the existing serial hide writer, and dragging
Hidden back to Visible invokes exact receipt-backed restoration. Revealable is
explicitly rejected because this persistent preference route has no temporary
reveal-session meaning. The shared `com.apple.systemuiserver` bundle is still
never placed in an assertion plan or policy document.

Time Machine uses the same two-state presentation, but no longer depends on an AX
label to appear. When its dedicated getter verifies that it is visible, or a
Blenny recovery receipt proves it is hidden, the Board synthesizes only the known
`com.apple.menuextra.TimeMachine` observation. The plain circular clock in the
owner screenshot is `com.apple.menuextra.clock`, not Time Machine; Clock remains
fixed and read-only. Unknown system identities are not synthesized.

The footer's unreadable count is not a count of missing menu-bar icons. It counts
running processes whose single `AXExtrasMenuBar` root read returned an unexpected
error; normal no-root results are excluded. Such rows commonly belong to helper,
agent or background processes, but the UI reports the exact current bundle IDs
and AX codes rather than guessing their role.

The two-state planner has deterministic coverage for hide, restore, forbidden
Revealable, busy/unavailable state and stale source state. The final matrix passes
353 Debug tests / 36 suites, 298 ordinary Release tests / 30 suites and 304
optimized-trial tests / 31 suites. The signed trial executable SHA-256 is
`d6c76f66c1079fb51fd7a9a7ca4975e5bc0e146eec16f2bd59fcdf6abcd50a35`;
it is installed at `/Applications/Blenny.app` as PID `47667`. Replacement occurred
only after confirming stopped manual management and no shared-item receipt.
Startup preserved the manual policy and backup hashes and created no receipt. No
Release skill, commit, tag or push ran.

## 2026-09-05: Time Machine normalized-write verification correction

The owner's first Time Machine Hide removed the menu extra, but Apple's setter
normalized Time Machine's own preference representation instead of producing the
byte-for-byte proposal predicted by Blenny. The old verifier treated that valid
target-local normalization as failure, performed its bounded exact rollback, and
then incorrectly left the safely restored Board item unavailable. This explains
the observed immediate reappearance and subsequent missing Blenny card; the
current Time Machine baseline was fully restored (`menuExtras` contains the one
known path, `VisibleCC` is true, and preferred position is 86), and no receipt
remained.

Verification accepts a Time Machine hide only when Apple's paired getter reports
hidden and the ordered `menuExtras` array is either unchanged or differs solely by
removal of the target path. Every unrelated entry and its order remain byte-for-byte
identical. Absence and an empty array are treated as the setter's equivalent
representations. Only Time Machine's own optional Boolean `VisibleCC` and optional
integral preferred-position metadata may be normalized during write verification;
the actual verified post-write snapshot is saved in the mode-0600 receipt. A later
target-local normalization is accepted for restore only while the authoritative
getter remains hidden and the complete snapshot still satisfies this same bounded
contract. Restore still writes and verifies all three original values exactly.
Any unrelated menu-extra insertion, removal, reordering, unsupported value, or
intervening state remains a fail-closed error.

After a failed hide that completes exact rollback, presentation now re-reads the
target and returns its card to ready/hidden rather than unconditionally marking it
unavailable. A surviving receipt still takes precedence as recovery-required. New
deterministic tests cover normalized write acceptance, unrelated drift rejection,
recording the actual applied snapshot, exact restore, and receipt removal. The
matrix passes 356 Debug tests / 36 suites, 298 ordinary Release tests / 30 suites,
and 307 optimized-trial tests / 31 suites. The corrected signed trial executable
SHA-256 is
`757555ac46d34350ff34e2aad3caac8668dcd43d1f540d035f7a2456e658b3da`;
it is installed at `/Applications/Blenny.app` as PID `50500`. Replacement occurred
only after confirming stopped manual management and no shared-item receipt. Startup
preserved both production and isolated policy/backup hashes and created no receipt.
No automatic Hide was performed. No Release skill, commit, tag or push ran.

The owner's next attended attempt produced decisive runtime evidence. Unified logs
recorded `CoreMenuExtra.timeMachine.showInMenuBar` becoming false and
SystemUIServer removing `com.apple.menuextra.TimeMachine`; exactly one second later,
Blenny's rollback set it true and SystemUIServer added it again. The failure was
therefore not Apple's setter or a permission denial. The macOS 27 setter can retain
the legacy `menuExtras` membership while its paired getter and live item are hidden,
so using that array as effective visibility was incorrect.

The backend now obtains effective Time Machine visibility from the exact paired
`SystemItemMenuBarPreferences.showTimeMachine` getter. Legacy preferences remain in
the receipt solely for exact recovery and unrelated-drift validation. A new test
covers getter-confirmed hidden state with unchanged legacy membership; the matrix
passes 357 Debug tests / 36 suites and 308 optimized-trial tests / 31 suites.
Ordinary Release remains 298 / 30 because it excludes this trial route. The signed
replacement candidate has executable SHA-256
`412ca1ad4bbcbb1a52e0219e1e47a58c70d818f8ecf8778285b2737ca408b6b4`.
The owner restored Siri, removing its exact recovery receipt, and then authorized
installation. The candidate is installed at `/Applications/Blenny.app` as PID
`52867`. The installed startup regression remained stopped, created no receipt,
preserved all four production/isolated policy and backup hashes, and left the Time
Machine baseline unchanged: its path is present, `VisibleCC` is true, and preferred
position is 86. Installation performed no Hide. No Release skill, commit, tag or
push ran.

System-item control is capability-based rather than inferred from Accessibility
recognition alone. Recognition establishes presentation identity, not a safe
isolated setter, authoritative state, or exact inverse. Numbered assertion items
share one capability family; Siri and Time Machine share another item-specific
Boolean-setter family. Now Playing is already recognized, but its researched route
is a third family: a packed `NowPlaying` value in current-host
`com.apple.controlcenter` preferences. That pure inverse has not yet been
revalidated or exercised on the current build, so Now Playing remains read-only.
Future catalog entries may automatically become interactive when a complete
runtime-gated capability descriptor supplies identity, state, mutation,
verification and exact restoration; unknown recognized items do not become
writable merely by appearing.

## 2026-09-05: capability-based three-state system-item policy

The owner correctly identified that a persistent hide setter is not inherently
limited to two Board states. `Visible`, `Revealable` and `Hidden` describe product
intent; they do not require identical backend mechanics. A persistent item with a
captured exact visible baseline can implement Revealable by alternating only at
the existing ordinary reveal edges:

| Product intent | Baseline presentation | Revealed presentation |
| --- | --- | --- |
| Visible | exact captured visible baseline | exact captured visible baseline |
| Revealable | verified target-local hidden state | exact captured visible baseline |
| Hidden | verified target-local hidden state | verified target-local hidden state |

This is event-driven and adds no polling or reconciliation loop. If an item is
already hidden outside Blenny and has no Blenny recovery receipt, the current
trial does not invent a visible baseline or mutate it. Such a target remains
unavailable until its normal visible state can be captured exactly.

Three backend capability families now implement the same policy surface in the
optimized owner trial:

1. The eight mapped numeric MenuBarClientCore items other than Clock use the
   process-owned assessment assertion.
2. Weather and Input Menu use their already bounded exact owning-bundle assertion.
3. Siri, Time Machine and Now Playing use item-scoped persistent transactions.

Siri and Time Machine keep their previously verified current-build accessors and
exact preference receipts. Now Playing is the third persistent descriptor. It
reads and writes current-user/current-host `com.apple.controlcenter:NowPlaying`.
Only visibility mask `0xA` is changed: show is `0x2`, hide is `0x8`; every other
bit is preserved. An absent key is interpreted as the visible default for the
proposal and is restored as absence, not as a synthesized integer. This path is
compiled only in Debug or `BLENNY_SHARED_SYSTEM_ITEM_TRIAL`; ordinary Release
still excludes it.

One `CoordinatedPolicyWriter` is the logical serial writer across assertion and
persistent capabilities. It applies the persistent transition before replacing
the assertion, then verifies both. A failed reveal restores the preceding
persistent presentation. A failed conceal stops management and restores every
owned assertion and receipt instead of leaving a partially revealed restriction.
An Apply persistence failure reactivates the preceding baseline. Stop, Quit and
connection invalidation restore all exact persistent baselines. Each item writer
still performs one post-write capture and no retry; a batch failure rolls every
already-touched item back to its exact checkpoint and restores the prior receipts.

The old special two-state Board planner and direct Hide path have been removed
from normal item interaction. Exact Siri, Time Machine and Now Playing identities
now use the same Draft, Review, Apply, keyboard and drag paths as other policy
items. Persistent desired states participate in plan, authorization and managed
policy fingerprints. Additions-only pass-through replacement must preserve them
byte-for-byte.
Removing an item from a restored backup is also explicit: a missing desired key
means restore any surviving receipt to its exact baseline, verify it, and remove
the receipt only after the policy commit succeeds.

Deterministic Xcode 27 verification passes:

- Debug: 369 tests / 37 suites.
- Ordinary Release: 307 tests / 31 suites; private shared-item accessors and UI
  strings remain absent.
- Optimized `BLENNY_SHARED_SYSTEM_ITEM_TRIAL`: 320 tests / 32 suites.
- Debug, ordinary Release and optimized-trial app bundles build, sign and pass
  strict code-signature verification as arm64 binaries.

The candidate executable hashes are `50c7a277...` (Debug), `d951a11e...`
(ordinary Release) and `ffc7f6dd...` (optimized trial). They and all raw build
evidence remain under ignored `LocalData/0.8.0/three-state-builds/`.

No live Now Playing write has occurred. The optimized trial was installed only
after confirming stopped management, no shared-item receipt and unchanged
isolated/production policy hashes. The previous app was preserved under ignored
LocalData. Installed executable `ffc7f6dd...` is running from
`/Applications/Blenny.app` as PID 61869. Its startup kept all four policy/backup
hashes exact, created no receipt, left Siri visible, preserved Time Machine's one
path / `VisibleCC = 1` / position 86 baseline, and left the absent Now Playing key
absent. Before its first owner-operated Apply, the exact live target is only
`com.apple.controlcenter` current-host key `NowPlaying`; risk is unsupported
runtime behavior or failure to refresh its presentation; recovery is the
mode-0600 exact baseline receipt followed by the bounded item restore. Clock,
native overflow and every identity without a complete descriptor remain read-only.
This is not ordinary Release promotion. No release audit, commit, tag or push ran.

## 2026-09-05: post-write Time Machine normalization during Siri Apply

The owner's first three-state Siri Apply hid Siri, then rolled it back and reported
unconfirmed cleanup. Read-only diagnosis found Siri already restored exactly
(`StatusMenuVisible = true`, no Siri receipt) and the isolated policy still stopped.
The blocking state was an older Time Machine receipt. Its recorded applied snapshot
retained the legacy menu-extra path while clearing Time Machine metadata; the later
live preference snapshot had removed the path as well. Both are setter-produced,
target-local hidden representations, but the restore guard accepted only the first
recorded representation. That stale-state result aborted the multi-target batch
and its exact checkpoint rollback restored Siri.

Receipt ownership now follows each target's already bounded hide predicate rather
than byte equality with only the first post-setter capture. Siri and Now Playing
remain exact because their predicates admit only the one exact hiding proposal.
Time Machine may move between the two documented path representations and may
normalize only its own optional visibility/position metadata while its paired
getter reports hidden. Every unrelated `menuExtras` entry and its order must still
match the baseline exactly; any unrecognized state remains fail-closed. The same
predicate is used for hidden-plan verification, repeated conceal and exact restore,
so delayed SystemUIServer normalization cannot poison a later unrelated Apply.
Deterministic coverage reproduces the second normalization and proves exact baseline
restoration plus receipt removal, while unrelated menu-extra drift is still rejected.
The current Xcode 27 matrix passes 370 Debug tests / 37 suites, 307 ordinary
Release tests / 31 suites and 321 optimized-trial tests / 32 suites. All three
arm64 bundles pass strict ad-hoc signature verification. Final executable hashes
are `b2562bf8...` (Debug), `bd060f4a...` (ordinary Release) and `befc3b7e...`
(optimized trial). Ordinary Release still contains none of the shared-item
accessor or one-shot recovery strings.

After the owner approved rollback and installation, the old process did not
complete its normal AppKit Quit because it was already in the terminal cleanup
state. A normal `TERM` released that process without changing preferences and
left the receipt intact. The corrected installed trial then ran an explicit
one-shot recovery mode through the same `SharedSystemItemManualTrialWriter` and
backend. Its installed PREVIEW validated the sole Time Machine receipt and
current authoritative state with `write=false`; APPLY performed one exact restore
with no retry. Post-restore reads matched the baseline path, `VisibleCC = true`
and preferred position 86, and the receipt directory was empty. Siri remained
visible. All four isolated/production policy and backup hashes stayed unchanged.
Normal installed startup is stopped, creates no receipt, and is running as PID
67676 with executable hash `9978eafd...`. The observed old-process Quit stall was
a self-wait risk after terminal cleanup failure. The follow-up schedules exit on
the next run-loop turn and returns `.terminateNow` for that already-unconfirmed
state, so process connection release cannot wait on the transaction that requested
it. This final `befc3b7e...` candidate is built and verified but deliberately not
installed while the owner tests the current corrected normalization build. The
previous app and intermediate candidates remain recoverable only under ignored
`LocalData/`. No release audit, commit, tag or push ran.

## 2026-09-06: final owner restoration and release candidate

The owner confirmed that Siri and Time Machine hide and restore correctly, then
observed the Now Playing hidden state. Before release closure, the owner manually
restored all three persistent targets. A bounded read-only comparison found:

- no shared-system-item recovery receipt;
- no current-user/current-host `com.apple.controlcenter:NowPlaying` key, matching
  the absence-preserving visible baseline;
- the exact Time Machine path
  `/System/Library/CoreServices/Menu Extras/TimeMachine.menu`, `VisibleCC = true`
  and preferred position 86;
- unchanged accepted policy-state modes and the following post-restoration
  SHA-256 baselines: manual policy
  `5dd0ff04afaedb89caddc49cf7499b724293cb54e35b078b28181e9201890b32`,
  manual backup
  `d9f1f234ae88455412da2c8b388885180baa98eb46b00debf97695b46c931ad9`,
  production policy
  `b78eec9cb8d0ec57a92a7d66ca33593f5cff7a36610da2262d83dbfd8e75bdd6`,
  and production backup
  `d36592309ff2e4ffe4e1e9ed6fc97f384b4e04435394e953f877be0deb2f45ee`.

Final Xcode 27 verification passes 370 Debug tests / 37 suites, 307 ordinary
Release tests / 31 suites and 321 optimized-trial tests / 32 suites. Debug,
ordinary Release and optimized-trial arm64 application bundles all build and pass
strict signature verification. Their executable SHA-256 values are respectively
`ae4cf226677d913835d70e51c819f150f6cfa345aab202d7332e2affb49e4bbe`,
`4da288028eee8670743c13cf16c70714dd094b3989bbea2f09fc6678943be085`
and `8795e401166f8efb5ab7e19a19d25aeff420340db1fe4e49f07ee55262e37768`.
The ordinary Release executable contains none of the shared-item recovery,
accessor, trial-gate or Now Playing strings.

The final optimized-trial bundle was installed at `/Applications/Blenny.app`.
Normal startup remained stopped, created no receipt, and left every restored
preference and policy hash exact. Bluetooth remains the only system-item writer
promoted to ordinary Release. Wider capability-family support remains isolated to
the explicit optimized owner-trial flavor; Clock, native overflow, unknown
identities and incomplete descriptors remain read-only. Raw evidence and replaced
application bundles remain only under ignored `LocalData/`.
