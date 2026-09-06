# Blenny

Development follow-up (2026-09-04): accepted application launch/quit no longer
invalidates unchanged bundle policy in the local implementation. Confirmed
cleanup is a neutral pause rather than a danger banner. Both test/build
configurations pass; its installed no-writer dry-run also passes. Live launch
latency and visual reflow remain unmeasured. The owner
has now authorized additions-only pass-through updates for newly launched bundles.
The local implementation coalesces those events for 250 ms and reuses the existing
serial writer without changing Hidden/Revealable policy or system-item allowances.
Known identities do not write; no polling, retry loop, or full icon refresh occurs.
Unidentified ownership and actual writer failures still require safe handling. See the
[0.8.0 spike](docs/TECH_SPIKE_0.8.0.md) for current verification boundaries.

Debug trial follow-up (2026-09-05): Weather and Input Menu are now exposed as
exact owning-bundle candidates in the manual Board. This exception is limited to
`com.apple.weather.menu` and `com.apple.TextInputMenuAgent`; all other Apple
bundles remain rejected. The machine updated to macOS build `26A5425a`, so the
new build was admitted only to Debug after a read-only six-method encoding check,
unchanged framework UUID and in-memory configuration round trip. Release retains
the previously validated `26A5416b` gate. The installed dry-run observed both
owners and prepared six policy plans without creating a writer or assertion.
The owner then confirmed that both items hide and reappear normally. Their
application-level control identity no longer determines their artwork: the exact
Apple owners now use semantic monochrome Weather and Input Menu symbols instead
of Weather's full-color application icon or the generic fallback.

Siri and Time Machine are not safe owning-bundle candidates: a current bounded
AX sample places both in the shared `com.apple.systemuiserver` host, so excluding
that bundle would hide multiple unrelated items. Read-only current-build evidence
instead identifies per-item preference routes. Siri uses the exact
`com.apple.Siri` `StatusMenuVisible`/stash pair and a distributed notification;
Time Machine is represented by one exact path in `com.apple.systemuiserver`'s
ordered `menuExtras` array. Pure snapshot/inverse models pass in unoptimized and
optimized builds. A later Debug-only manual panel implements the exact per-item
route with one serial writer, mode-0600 recovery receipts, one verification and
compare-before-restore. At the owner's request, an optimized Release-configuration
trial flavor is used for manual validation. The current implementation promotes
Siri, Time Machine and Now Playing from separate buttons into the ordinary
Visible / Revealable / Hidden Draft flow. Their item-scoped persistent writer is
coordinated with the process-owned assertion writer: Revealable hides at baseline,
restores the exact captured visible state while expanded, and hides again when
collapsed. Stop, Quit or invalidation restores every exact receipt. Clock,
native overflow, unknown identities and incomplete capability descriptors remain
read-only. Normal Release remains unchanged: Bluetooth alone is promoted, and
the wider trial route is stripped.

The final optimized trial executable is installed at `/Applications/Blenny.app`
with SHA-256 `8795e401166f8efb5ab7e19a19d25aeff420340db1fe4e49f07ee55262e37768`.
It starts stopped, creates no recovery receipt and leaves the isolated and
production policy/backup files plus Siri, Time Machine and Now Playing preference
baselines unchanged. No system-item Apply occurs on startup.
The first attended Siri Revealable Apply was rolled back by an older Time Machine
receipt whose target-owned preferences normalized again after the original write.
The restore guard now accepts only descriptor-proven hidden normalization: Siri
and Now Playing remain exact, while Time Machine must preserve every unrelated
menu-extra entry and order. Unknown drift is still rejected. The corrected trial
was installed only after its one-shot read-only PREVIEW validated the sole Time
Machine receipt. The same serial writer restored the exact path, visibility and
position baseline once and removed the receipt; Siri and all policy/backup hashes
remained unchanged. The owner later confirmed the hidden state for Siri, Time
Machine and Now Playing and manually restored all three. The final read-only
comparison found no receipt, an absent Now Playing key, the exact Time Machine
path, `VisibleCC = true` and preferred position 86. Ordinary Release still strips
this trial recovery route.

Blenny is a minimal, native menu bar organizer designed exclusively for macOS 27 and later.

Project website: <https://blenny.fi5h.xyz>. The application uses the stable reverse-DNS bundle identifier `xyz.fi5h.blenny`.

Version `0.8.0` completed the bounded Apple system-item visibility feasibility
spike and promotes only the verified Bluetooth path. Read-only runtime inspection
maps Bluetooth to private raw
value `1` and AX identity `com.apple.menuextra.bluetooth`. Bluetooth is the only
promoted target in Release. At the owner's request, the Debug Board also exposes
manual Visible / Revealable / Hidden controls for Battery, Display, Keyboard
Brightness, Sound, Wi-Fi, Screen Mirroring and Control Center when observed.
These are experimental controls, not ordinary Release promotion.
Clock and native overflow stay read-only. In the optimized owner trial, Now
Playing, Siri and Time Machine use exact item-scoped routes, while Weather and
Input Menu use their dedicated owners. All expose the same three policy states;
this is not ordinary Release promotion.

In the optimized owner trial, Weather and Input Menu are visually grouped with
macOS items and use the natural-aspect system-symbol renderer, although their
writer identity remains the exact owning bundle. After owner validation, Siri
and Time Machine use the ordinary Board lanes while remaining outside bundle
assertion policy. Now Playing uses a third capability that preserves every
non-visibility bit in the current-host packed preference and restores key absence
exactly. The
footer's unreadable count can be opened to inspect exact bundle IDs and AX results;
these failures are not treated as missing or manageable menu-bar icons.

Debug manual-test policy is isolated from the ordinary policy and recovery
backup. Each launch starts stopped; Apply/Resume is an explicit owner action.
There is no timed trial rollback: the owner chooses Visible, Stop or Quit.
Stop/Quit releases Blenny's process-owned restrictions without changing system
preferences. Recovery rows remain available for hidden experimental items.

Installed Bluetooth PREVIEW receipts used only
MenuBarAgent's canonical `AXExtrasMenuBar` root and bound AX identities, semantic
scoped preferences, exact file hashes and a non-expanding application allow-list.
Owner-observed validation proved that excluding Bluetooth raw value `1` hides
Bluetooth without changing Wi-Fi, Clock or Control Center. The native overflow
control disappeared only while the active application's menu bar fit and returned
when another application activated; the owner confirmed this as normal macOS
reflow rather than loss of the protected control. Independent RECOVER matched AX
state, semantic preferences and exact file hashes. Bluetooth therefore joins the
formal Visible / Revealable / Hidden policy in Release. All other Apple items
remain read-only in Release.
The installed follow-up confirmed normal Bluetooth adjustment. Blenny presents
Bluetooth with AppKit's native Bluetooth template and Siri with macOS 27's
dedicated `siri` symbol; these are presentation-only corrections.
See [the 0.8.0 spike](docs/TECH_SPIKE_0.8.0.md).

The same milestone corrects an over-strict startup preflight. A previously
approved bundle may be dormant or temporarily lack an ownership observation
without forcing management inactive; its exact bundle-level policy remains in the
frozen plan. Multiple processes for the same approved bundle consolidate at bundle
scope. Unknown ownership or an unknown bundle still fails closed. A bounded installed run reproduced
the old missing-Usage4Claude case, reached active management and restored on Quit.

The distribution prototype moves unchanged to `0.9.0`, and the first public
release-candidate line moves to `0.10.x`.

Version `0.7.0` closes the real menu-bar ordering investigation with a deliberately
manual product boundary. Blenny does not reorder third-party or Apple items. When
one usable native overflow control is observed, Settings explains how the user can
Command-drag the fish immediately to its right. The fish has one stable public
AppKit autosave identity so macOS can retain the user's placement across Blenny
updates. macOS still owns the physical order, so this is guidance rather than an
arrow-relative pinning guarantee.

Private API, preference storage, historical spikes, competitor behavior and
bounded installed experiments did not establish a complete readable, writable and
reversible cross-app ordering contract. Blenny therefore adds no synthetic input,
polling, automatic reconciliation, third-party write, Board-only sorting, helper or
Release backend promotion. Full findings and recovery limits are in
[the 0.7.0 spike](docs/TECH_SPIKE_0.7.0.md).

Version `0.7.0` completed after 292 Debug and 261 Release deterministic tests,
both app builds, and installed no-writer regression. The existing annotated
`v0.7.0` tag predates the final placement-guidance follow-up and remains unchanged
under the repository's no-tag-rewrite boundary. History is forward-only and no
push is authorized.

An application launch no longer stops management solely because its bundle was
absent from the frozen startup plan. Blenny coalesces new launches into one
bounded, delayed, read-only AX ownership check. Applications with no attributable
menu-bar item leave the verified writer untouched. A managed application, a new
menu-bar owner, or incomplete ownership evidence still revokes the assertion and
requires explicit Resume. The check never edits or automatically rebuilds the
allow-list and does not poll.

macOS 27 may also emit `didChangeScreenParameters` while an ordinary application
activates even though the displays did not change. Blenny compares a public
`NSScreen` signature of display identifiers, frames and backing scales. An
unchanged signature keeps management active; a real display, resolution or scale
change still restores the writer and requires explicit Resume.

When a usable system overflow control appears after an explicit user Reveal,
Blenny first removes its fallback status item. If that makes native overflow
disappear, it tries one contentless zero-length transition; if that also fails,
it restores the full 22-point fallback. Automatic layout events cannot restart
the ladder, while a later user Reveal may begin one fresh bounded attempt. This
avoids a repeating layout loop; it does not move either status item or promise
that the system control will remain present. Event-driven confirmation may show
a brief empty transition before the fallback is removed.

The preceding `0.6.0` completed the native-overflow integration investigation, accepted
by the owner on 2026-08-31 on the exact Debug development boundary: macOS 27.0
build `26A5416b`, arm64, one 1600 × 900 logical-point display at 2x scale.
Native expand/collapse now coordinates Blenny's Revealable session, including
when the system arrow first appears while Blenny is already running, without
requiring a preceding Blenny click. This observes native Accessibility state;
it does not intercept, replace, or modify Apple's button.

Blenny hides its fallback arrow when one known, registered native control is
usable and restores it when native observation is absent, unavailable or
ambiguous. The fish, safety-menu action and existing artwork remain. Version
0.7.0 adds the bounded empty-slot compaction described above. This is not a
fixed-position or physical-visibility guarantee.
Transient presentation loss preserves an authorized reveal and its original
deadline; lifecycle or permission loss still restores through the serial writer.
Canonical-root topology subscriptions and one coalesced post-activation read
discover newly created controls without waiting for a Blenny write. Discovery
alone never opens a session; there is no polling or automatic reconciliation.

The missing-app report concerned **Coffee Buzz**, not Bartender. Bounded discovery,
ownership attribution and installed-icon presentation succeeded; discovery grants
no mutation authority, and the owner's later explicit assignment is preserved.
Xcode 27 verification passed 255 Debug and 253 Release tests and both app builds.
Installed no-write preflight, bounded real-run cleanup and unchanged policy/backup
checks are recorded separately from the owner's visual acceptance in
[the 0.6.0 spike](docs/TECH_SPIKE_0.6.0.md).

This is a local engineering milestone, not general macOS compatibility or a
distributable release. Release has no unsupported mutation backend. Broader
lifecycle/display validation remains an explicit carry-forward gate in
[the roadmap](docs/ROADMAP.md). The 0.7.0 investigation does not add sorting or
fixed placement, and does not expand the accepted 0.6.0 compatibility matrix.
The historical `v0.6.0` closure tag is preserved.

The project is currently under private development. Versions through `0.4.0` established the bounded macOS 27 backend, persistent bundle policy, deterministic Review, the single-window product, icon-first Organization Board, and native cross-lane Draft assignment. Version `0.5.0` connects a freshly reviewed application-bundle plan to one Debug-only serial writer on one exact development runtime. Activation is verified before transactional persistence; scoped 0600 recovery, rollback, ordinary Reveal, Stop Managing, Restore Previous Policy, connection invalidation, and termination cleanup close the loop. Blenny remains Visible, Hidden never enters ordinary Reveal, Apple system items remain read-only, and stale or unauthorized plans cannot reach the writer. Release still cannot access the unsupported backend. This remains a local engineering milestone, not a distributable release or a general compatibility claim.

The previous `0.5.0` milestone closed the reviewed management loop and direct
fish/arrow controls at `v0.5.0`, with no separate patch release. It removed the
ordinary Review page while retaining internal plan validation and recovery,
made Draft Apply start management, and rebuilt exact plans from fresh bounded
preflight instead of treating unrelated process churn as changed authorization.
Its always-shown fallback policy is superseded by the accepted 0.6.0 native
handoff above; the artwork and separate native actions are unchanged. Historical
missing-app wording is retained in the older spike, not treated as a Bartender
diagnosis. Existing tags, including `v0.5.0`, are not modified by this version.

Icon-first recognition remains intact: installed application icons come from public AppKit/Workspace APIs, known Apple system items remain read-only semantic symbols, and unresolved candidates use one explicit fallback. Cross-lane movement changes only `BundlePolicyDraft`; Apply accepts only the exact current prepared Review. A false-to-true Accessibility transition triggers one bounded read-only refresh; later observations remain manual. No sorting, Screen Recording, menu-bar pixel capture, polling, automatic reconciliation, synthetic input, helper, or Release backend promotion is included.

Blenny's application bundle uses the v12 color artwork from `Assets/AppIcon/`; the build deterministically derives the complete multi-resolution macOS icon resource from its 1024-pixel production PNG. The app icon remains separate from Blenny's status-item artwork: the status item uses a bundled, 18-point optical-size monochrome template SVG so AppKit can adapt it to the current menu-bar appearance without rescaling fine details, while the detailed status-item vector master remains under `Design/MenuBar/`. Blenny never captures live menu-bar pixels and does not require Screen Recording.

Existing local policy and recovery documents created with the former development identifier `com.example.BlennyProbe` migrate deterministically to `xyz.fi5h.blenny`. The migration preserves policy assignments and management state, updates both the accepted document and its scoped backup, is idempotent, and fails closed if both identities are already present.

## Product direction

If startup cannot safely activate the saved policy, management stays inactive and
Resume remains available after Accessibility is granted. Open any managed app
named in the error, then choose Resume. This performs fresh safety checks and
activates unchanged accepted intent without rewriting the policy or rotating its
backup. A lost system connection still requires quitting and reopening Blenny.

- Use AppKit for status-item, window, Workspace, Service Management, and Accessibility infrastructure, with one SwiftUI hierarchy for all visible product content.
- Manage intent at the application-bundle level.
- Never move the pointer or synthesize Command-drag reordering.
- Avoid continuous polling and automatic reconciliation loops.
- Prefer native overflow presentation where it is adequate.
- Fail closed and restore deterministically when unsupported behavior changes.

Blenny is a clean implementation. It does not use or link Ice or Thaw code or binaries.

## Repository layout

- `Sources/` — product and bounded Debug-probe targets.
- `Tests/` — deterministic tests for identity, traversal, policy editing, product-interface presentation state, transactions, overflow classification, and reversible state.
- `Assets/` — tracked application-icon sources and production menu-bar artwork copied or derived into the app bundle.
- `Research/` — historical, unsupported experiments excluded from product targets.
- `docs/` — roadmap, repository policy, API research, and technical-spike results.
- `LocalData/` — ignored local diagnostics, backups, binaries, screenshots, and build artifacts.

Read [PROJECT_BRIEF.md](PROJECT_BRIEF.md) for the product constraints and [docs/ROADMAP.md](docs/ROADMAP.md) for version exit criteria.

## Build

Blenny requires Xcode 27 and the macOS 27 SDK.

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun swift test

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./scripts/build-app.sh debug
```

The `Research/` probes are not built by the Swift package and are not supported product entry points.

## Unsupported system behavior

The validated architecture includes version-sensitive, unsupported macOS behavior. Public APIs alone do not provide the required bundle-level presentation control. The production backend must remain isolated, build-gated, reversible, and protected by an emergency compatibility kill switch.

Do not treat the historical research probes as safe general-purpose utilities.

## License

No open-source license has been selected yet. A license will be added before the first public release. Until then, this repository is not offered for redistribution.
