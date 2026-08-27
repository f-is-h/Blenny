# Blenny 0.1.0 Minimal Product Interface

> Engineering and product record for the first AppKit interface over the validated `0.0.5` policy-editing core. Icon-first presentation begins in `0.2.0`; this record is not a distributable release.

Status: **Complete on macOS 27.0 build `26A5416b`; closed at local annotated tag `v0.1.0`, push deferred.**

Last updated: 2026-08-27

## Scope

Version `0.1.0` adds the first product-facing interface without broadening the macOS backend:

- one AppKit-owned menu bar entry and a minimal native editor window;
- three clear bundle-level groups: Visible, Revealable, and Hidden;
- candidates derived only from a bounded, read-only observation of current top-level `AXMenuBarItem` ownership;
- identifiable Apple system items shown read-only from the same bounded current observation, without admitting them to the editable bundle-policy draft;
- local `BundlePolicyDraft` edits with no persistence or assertion construction during selection or reassignment;
- one deterministic review surface containing the `0.0.5` diff, baseline and ordinary-reveal impact, validation results, exact fingerprints, and full recovery plan before Apply;
- UI entry points that reuse the `0.0.5` Resume Managing, Restore Previous Policy, and Discard Draft core paths, plus a prepared Stop Managing path;
- explicit, non-repeating Accessibility onboarding;
- stable menu-bar open, manual refresh, keyboard navigation, quit, and management-recovery actions.

Icon sourcing, icon-first candidate presentation, drag-and-drop, global shortcuts, login launch, updating, helpers, IPC, profiles, themes, animations, automatic rules, polling, reconciliation, lifecycle hardening, and display-matrix work remain excluded.

## Starting boundary

Development began from clean annotated tag `v0.0.5`, peeled commit `c86e6decf3602eceb80f778e1bdc8fca7be02909`, on `main`. The existing remote already contained the same `main` commit and `v0.0.5`; this milestone does not authorize any new remote-ref change.

The host runs macOS 27.0 build `26A5416b` on arm64. The system-selected developer directory remains Xcode 26.6, so every milestone build and test explicitly selects Xcode 27.0 build `27A5237l` and the macOS 27.0 SDK.

The pre-implementation recovery check established:

- no running Blenny executable and therefore no process-owned assessment assertion;
- no `Blenny0.0.5Validation` preferred-position value;
- accepted policy `managementEnabled=false` with SHA-256 `0618f1078de2655c5d4263c030459e7a1e0a320237708018957df83f8b74a004`;
- one previous-policy backup with SHA-256 `938ad8a5611a0c9bb0459a77f61528ecc587457f96b160db4044bd41874c9599`;
- both scoped files mode `0600`;
- MenuBarAgent, Usage4Claude, and CleanShot X still running without a MenuBarAgent restart.

The clean `v0.0.5` baseline passed 102 Debug tests in 14 suites with Xcode 27.

## AppKit interface

The editor uses three native horizontal policy lanes with restrained semantic color rails:

- **Visible** — not deliberately concealed by Blenny; macOS may still move an item into native overflow when space is limited, and Blenny's recovery control is locked here;
- **Revealable** — concealed at baseline and admitted during an ordinary reveal;
- **Hidden** — concealed at baseline and never admitted during an ordinary reveal.

Each lane keeps its policy meaning fixed on the left and presents owning bundles from left to right like menu-bar items. A lane scrolls horizontally when its bundle cards exceed the available width. Every observed owner appears once regardless of how many status items it exposes. Bundle identifiers remain the application policy identity, while item counts are presentation metadata only. Current Apple system items with stable read-only observations appear as disabled `macOS System Item · Read Only` cards in Visible; they never become application-bundle candidates. Selecting and moving an editable row updates only the immutable draft value. The accepted document and persistent store remain unchanged until a reviewed Apply action.

The editor states the system capacity boundary directly: Visible means Blenny does not conceal an item, not that it owns a fixed menu-bar position. macOS remains the final layout authority and may move any allowed item into native overflow when the available region is full.

The interface uses standard AppKit buttons, segmented controls, focus rings, menu key equivalents, and window behavior. Closing the editor keeps the menu bar entry alive; reopening, manual refresh, and Quit remain available from that menu. No global event monitor or global shortcut is installed.

## Bounded candidate observation

`MenuBarOwnershipSnapshotBuilder` accepts only records produced by the existing bounded `AccessibilityInventory`. Editable application candidates include only application `AXExtrasMenuBar` records classified as manageable, with top-level role `AXMenuBarItem` and subrole `AXMenuExtra`. MenuBarAgent presentation controls, structural nodes, and Apple-owned critical system bundles remain excluded from candidate policy scope.

The same snapshot separately extracts current Apple `AXMenuBarItem` / `AXMenuExtra` records that have a stable Accessibility identifier or resolved observation identity. A live bounded read-only check confirmed named MenuBarAgent records for Bluetooth, Wi-Fi, Now Playing, Sound, Control Center, and Clock. Other current system owners such as SystemUIServer, Weather, and TextInputMenuAgent remain read-only. These records may be displayed but cannot be selected, persisted, diffed, or sent to the assertion planner. The backend continues allowing all known system-item IDs; `0.1.0` does not claim or exercise an individual mapping between those private numeric IDs and the observed Accessibility identities.

The snapshot fails closed when Accessibility is not granted or when the inventory reaches its element or wall-clock limit. PID and current coordinates are not policy identity. Multiple observations from the same owning process become one bundle candidate with an item count; ambiguous multi-process ownership remains a validation error.

The current running-bundle set is used only to produce the same deterministic allowlist impact plans as `0.0.5`; it does not add editor candidates.

## Draft and review boundary

The pure `PolicyEditorViewModel` merges the accepted bundle policy with currently observed candidates. A newly observed candidate is effectively Visible in the interface but does not silently enter the persistent draft or validation scope. Assigning it to Revealable or Hidden creates explicit user intent; assigning an already managed item to Visible records the explicit three-state move. Blenny is forcibly Visible. The view model cannot save a document, request a writer, construct an assertion factory, or mutate system state.

Discard Draft calls the existing core discard path and reconstructs the accepted assignment exactly. Newly observed applications return to implicit Visible presentation without becoming policy entries. Discard performs no persistence or writer access.

The product data model is unified around `visible`, `revealable`, and `hidden`: `MenuBarBundlePolicy`, assignments, drafts, validation issues, deterministic report input, persistence resolution, and Debug-only backend authorization use the same terminology. Persistent policy documents now encode schema 2. A bounded schema-1 decoder maps the previous allow-state spelling into `.visible` in memory; no launch or Refresh path writes the migrated document, and every later encoding uses schema 2 terminology.

Review Changes calls the existing `PolicyEditingCore.preview` path. Resume Managing and Restore Previous Policy call their existing preview paths. Stop Managing now also produces a prepared disabled-policy transaction through the same dry-run machinery rather than directly changing persistence from the product UI.

The review window always displays the complete `0.0.5` deterministic report before Apply. Validation failure disables Apply. A plan that would create, replace, or restore an assertion is preview-only in the normal `0.1.0` interface and explains the installed Debug dry-run and explicit-authorization requirement. A disabled-to-disabled policy edit or no-op may be applied because it cannot request a writer; Apply remains the first persistence boundary.

## Accessibility onboarding

Blenny never requests Accessibility at launch. The editor explains the bounded, read-only purpose and requires an explicit user action. A persisted local flag is recorded immediately before the first system-prompt request. Later actions open the relevant System Settings pane without repeating the system prompt. Grant state is checked on launch and manual refresh; no permission polling was added.

## Safety and backend isolation

- Blenny remains Visible in the view model, validator, baseline plan, and ordinary-reveal plan.
- Hidden remains excluded from ordinary reveal.
- UI selection and movement cannot write persistence or assertions.
- Release has no writer provider capable of constructing the unsupported assertion runtime.
- The existing private macOS 27 runtime, approved third-party scope, real-write environment switches, and fingerprint authorization remain inside `#if DEBUG`.
- The legacy diagnostic editor window was removed from the product target; the bounded read-only inventory remains as the candidate source.
- Standard Debug launches now open the product interface. The previous validation controller starts only when an explicit validation action environment key is present.
- No polling, reconciliation, retry loop, pointer movement, synthetic input, MenuBarAgent injection, helper, IPC, or Screen Recording requirement was added.

## Deterministic verification

The final Xcode 27 verification completed with:

- 110 Debug tests in 15 suites passing;
- 108 Release tests in 14 suites passing;
- successful Debug and Release `Blenny.app` builds using Xcode 27.0 build `27A5237l` and the macOS 27.0 SDK;
- arm64 Debug and Release executables with deployment target and SDK both recorded as macOS 27.0;
- valid ad-hoc deep signatures and bundle version `0.1.0`;
- Debug executable SHA-256 `cf7ebbee5e57d1c88a6def9483cb16f6e1ab14b776076bd1dceb69bdcd2f10e1`;
- Release executable SHA-256 `00e221b16b4cc6936109b2d68595af51679587dde961097d51eeec1ab35cf15b`.

The Release executable links only public AppKit, ApplicationServices, Foundation, CoreFoundation, CryptoKit, Swift, Objective-C, and system libraries. Searches for the private assessment classes and selectors, Debug action gates, approved validation bundle identifiers, `_RBS`, the owner path, and approved Git email returned zero Release-binary matches.

New deterministic coverage includes:

- top-level application menu-extra records are the only candidate source;
- Apple-owned critical system bundles are excluded from the editable draft;
- system-owned presentation is excluded;
- duplicate items from one owner collapse to one bundle candidate;
- missing Accessibility and bounded-scan truncation fail closed;
- new candidates are implicitly Visible without entering the persistent draft or validation scope;
- schema-1 policy terminology migrates deterministically to schema 2 `visible` encoding;
- identifiable MenuBarAgent system items are deterministic read-only observations and never editable bundle candidates;
- draft movement does not mutate the accepted document;
- Blenny cannot leave Visible;
- Discard Draft restores accepted intent and implicit Visible current observations;
- the Accessibility system prompt decision is made at most once;
- Stop Managing is previewed before persistence and assertion restoration.

## Installed dry-run and restoration evidence

The final Debug app was installed at `/Applications/Blenny 0.1.0 Validation.app`; its installed executable hash matched the final Debug build. The explicit `preview-resume-managing` installed dry-run was executed twice and reproduced the same complete passing report each time:

- report fingerprint `a7d35119ea172dbac2423262fb133bb20cdfbd7f29af538625e189b69d8177ca`;
- baseline managed-policy fingerprint `4391f3c2ea60cfef7f383364006603161c7903bd05716e7bcf87a2de24d4d299`;
- ordinary-reveal managed-policy fingerprint `f06c7d0981b59080c9b6c16414fcb33aa8226254b57f3be2b0ba40a0572a5038`;
- exact baseline snapshot fingerprint `c3df7c3853e71a7ea008de4af70cc1cb5d79572e73570abc208c05b441d300df`;
- exact ordinary-reveal snapshot fingerprint `0a5e0c738fbb1a544abafd36b256a74e315dc396765103db3ffc20ea41e0ba87`;
- `assertion_factory_created=false` and `assertion_candidate_created=false` on both runs.

Before and after both runs, the accepted policy remained disabled with SHA-256 `0618f1078de2655c5d4263c030459e7a1e0a320237708018957df83f8b74a004`, and the previous-policy backup remained SHA-256 `938ad8a5611a0c9bb0459a77f61528ecc587457f96b160db4044bd41874c9599`. Both files remained mode `0600` with unchanged modification times. No Blenny validation process remained, the validation preferred-position key remained absent, and MenuBarAgent, Usage4Claude, and CleanShot X remained on PIDs 1590, 48268, and 48270 respectively.

The standard installed interface was also exercised directly with Accessibility granted. It completed one bounded observation, excluded Apple-owned critical system bundles, moved a third-party bundle between draft groups without changing accepted state, displayed the complete deterministic Review Changes report, and returned to accepted intent through Discard Draft. Resume Managing displayed a passing accepted-policy-scoped preview. Apply was disabled for every assertion-changing plan. Tab navigation, close/reopen from the menu bar, and Command-Q were exercised successfully. No system prompt appeared at launch and no real write was attempted.

The final system-item change was verified against a separate bounded live Accessibility observation that returned Bluetooth, Wi-Fi, Now Playing, Sound, Control Center, and Clock from MenuBarAgent, plus current SystemUIServer, Weather, and TextInputMenuAgent items. Unit coverage verifies that these observations become deterministic read-only Visible cards and never enter the editable bundle-policy draft. After re-enabling Accessibility for the rebuilt ad-hoc app and selecting Refresh, owner visual review confirmed populated application and system cards in the Visible lane. A final Accessibility-tree inspection confirmed nine current read-only system cards: Bluetooth, Clock, Control Center, Now Playing, Siri, Sound, Wi-Fi, Weather, and the active input source. The horizontal strip requires scrolling to reach later cards. Time Machine was not present in that identifiable snapshot; `0.1.0` promises only stable current observations, not exhaustive enumeration or mutation of every Apple system item.

Follow-up visual QA exposed an AppKit sizing defect: the window frame opened at the intended width while its root content view was allowed to collapse to approximately 215 points, producing an unusably narrow and vertically expanded editor. The editor now uses an explicit view-controller-owned content root, disables stale window restoration, declares matching content and root-layout minimum dimensions, and repairs an undersized restored window before presentation. Rebuilt installed-app QA confirmed normal-width headers, onboarding, all three policy regions, draft actions, and recovery controls in one window.

Owner review then found that tall policy columns did not match the horizontal reading model of the menu bar and exposed clipped document-view fragments at the bottom of each column. The three policies now render as stacked horizontal lanes with fixed semantic descriptions and independently sized horizontal item strips. Each strip owns an explicit content width derived from its arranged bundle cards, eliminating the clipped fragments while keeping overflow bounded to local horizontal scrolling.

No real assertion write was authorized or performed for `0.1.0`. Any later real write still requires an installed dry-run, presentation of the exact report and managed-policy fingerprints, and separate explicit owner confirmation.

## Closeout boundary

The owner reviewed the final interface and system-item evidence and explicitly authorized local release closure through `$blenny-release`. Annotated tag `v0.1.0` points to audited release commit `5df98625d1ee2493bd0ea0d0eea94d427cbcac20`; no branch or tag was pushed. Subsequent work begins from that immutable boundary. Version `0.2.0` is limited to icon-first presentation and must not absorb drag-and-drop, real policy writes, or lifecycle/display hardening.
