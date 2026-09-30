# Blenny 1.0.0 implementation and local acceptance plan

Status: planned, 2026-09-29. This document records the owner's revised scope
after the pre-publication audit. It does not claim implementation or acceptance.

2026-09-30 addendum: the approved
[versioning and release automation plan](RELEASE_AUTOMATION_PLAN_1.0.0.md)
supersedes this document's release orchestration where they differ. All human
acceptance occurs during development; after the authorized release trigger,
GitHub builds and publishes without a post-build human gate. The product and
restoration constraints below remain in effect.

## Owner decisions and precedence

- Ship the same everyday product capabilities in Debug and ordinary Release.
  Keep developer menus, probes, dry-run entry points and abandoned experiments
  Debug-only. Do not achieve parity by defining DEBUG in Release.
- Use Blenny's existing self-signed code-signing certificate and independent
  Sparkle EdDSA key. A paid Apple Developer ID certificate, Apple notarization
  and notarization-specific requirements are not 1.0.0 acceptance gates.
- Follow Usage4Claude's working distribution model: persistently signed app,
  Sparkle-signed package, GitHub Release downloads and a public HTTPS appcast.
  Reuse the design, not its application identity, keys or sandbox settings.
- Perform all feasible local update, authorization and restoration validation.
- Support the currently tested macOS configuration. Do not promise untested
  future versions or add a remote kill-switch service. Keep existing runtime
  guards, explicit Stop and fail-closed recovery. Briefly document this scope.
- Complete licensing, README and public release documentation in this version.
- Perform the scoped refactoring below in this version, before final acceptance.
- The website is implemented in another conversation. This work only coordinates
  links and release facts; it must not create or modify the website.
- Implementation does not authorize commits, tags, pushes, public releases,
  repository visibility changes or unrelated system preference mutations.

These decisions supersede the prior audit's mandatory Developer ID/notarization
recommendation and its suggestion to defer the listed refactoring. Update active
project requirements accordingly; preserve dated historical evidence as history.
Self-signing and EdDSA verification must not be described as Apple notarization
or proof of default-Gatekeeper trust.

## Execution rules for the implementing agent

Read AGENTS.md, PROJECT_BRIEF.md, REPOSITORY_POLICY.md, ROADMAP.md, the 0.13.0
release/spike and this plan. Read RTK.md and prefix shell commands appropriately.
Re-scan current changes before editing; do not overwrite another conversation's
work. Implement phases sequentially, recording evidence after each phase. Do not
start with a wholesale rewrite or a mass removal of conditional compilation.

Use Xcode 27 and macOS 27 SDK explicitly. Keep one serial mutation coordinator,
the current bundle identity and receipt compatibility. No cursor movement,
synthetic clicks/Command-drag, private entitlements, continuous polling, automatic
reconciliation or expanded retry budgets. Do not remove system write guards to
make an acceptance test pass.

Use existing configured signing commands without exporting, printing, rotating
or copying private keys. Never read root-level .p12/.key backups for convenience.
Missing keys or credentials require owner input, not replacement key generation.
Test artifacts, system backups and diagnostics stay in ignored LocalData.

For real writes, use owned helpers first. Freeze and show exact affected targets
and restoration snapshots before using real third-party targets; use existing
explicit target authorization only where it clearly covers the current action.
System permission dialogs, credentials and physical acceptance may require owner
participation. Complete independent work while those checks are pending.

## Phase 0 — Establish the candidate and revised contract

1. Record branch, HEAD, status, local/remote tags, installed app identity, OS and
   SDK. Do not assume the audit's fe34d52 HEAD or installed build is still current.
2. Create TECH_SPIKE_1.0.0.md as the current contract and evidence ledger. Use
   statuses implemented / verified / awaiting owner / deferred, with exact reasons.
3. Align the active portions of PROJECT_BRIEF, ROADMAP and REPOSITORY_POLICY with
   the decisions above. Revise release-skill checklist wording if it would wrongly
   retain a paid-signing gate; preserve its audit and publication authorization.
4. Read Usage4Claude's current build script, release workflow, appcast generator,
   version handling, Info.plist and updater integration. Record a small comparison
   table in the spike. The reference repository is read-only.
5. Confirm the final license before adopting it. Apache-2.0 is the existing
   preferred candidate, not an already authorized selection. Ask one focused
   question if the owner has not selected a license; continue other phases.

Exit: scope and acceptance conditions are explicit; no dependency on Developer ID
or website implementation is accidentally introduced.

## Phase 1 — Make a capability map, then establish Release parity

1. Inventory DEBUG and trial gates in BlennyMain, AppDelegate, the views/window
   model, policy catalogs, ordering models/store/backend and Objective-C shim.
2. Classify each gate as production capability, development tooling, or abandoned
   experiment. Record the intended shipping behavior before changing it.
3. Promote accepted ordering, three-state policy, supported system items,
   single-level unified Undo, recovery, required access UI and persistence into
   ordinary Release. Preserve the current unsupported-item boundaries: Now Playing
   remains recovery-only; do not enable deferred sorting for Siri, Time Machine or
   Control Center. Preserve exact capability checks rather than name-based access.
4. Keep probes, legacy Now Playing trials, mutation diagnostics, debug menus and
   environment-variable experiment entry points out of Release. Do not compile
   every experimental target merely because the core catalogs need promotion.
5. Carry necessary existing ordering access entitlements and purpose strings
   into the shipping package. Review each one; never add private entitlements.
6. Preserve existing state locations and decoding for old policy, bookmarks and
   receipt schemas. A directory named DebugOrdering is not sufficient reason to
   move or discard user state. If migration is unavoidable, make it explicit,
   recoverable and covered by fixtures before any real installation.
7. Add shared Debug/Release tests for product capability parity and restoration
   compatibility. Test that diagnostic interfaces remain absent from Release.
   Test totals may differ because development-only tests remain development-only.

Primary files: Sources/BlennyCore/OrderingModels.swift, OrderingRecoveryStore.swift,
CoordinatedPolicyWriter.swift, SystemItemPolicyCatalog.swift,
PersistentSystemItemPolicyCatalog.swift, MenuBarLayoutAccess.swift,
MacOS27/MenuBarOrderingBackend.swift, Sources/BlennyPrivateABIShim,
Sources/BlennyApp and scripts/build-app.sh.

Exit: ordinary Release exposes the accepted daily workflow and can read/recover
existing state without enabling diagnostic or previously failed experiments.

## Phase 2 — Refactor responsibilities without changing the backend contract

Perform small extractions with checks between them, not one simultaneous rewrite.

1. Extract updater and launch-at-login services from AppDelegate; keep AppKit
   lifetime and main-thread UI ownership explicit. Preserve draft/update guards.
2. Extract Debug diagnostic dispatch and owner-test support from ordinary
   application lifecycle code, maintaining compile-time exclusion.
3. Extract ordering presentation/preflight orchestration from AppDelegate into
   a focused controller that uses the existing writer and interaction gate.
   It must not own a second independent writer or management state machine.
4. Split BlennyRootView by existing Board, Settings, Support and reusable visual
   components. Preserve current geometry, drag identity and accessibility actions.
5. Separate window lifecycle from observable presentation state in
   PolicyEditorWindowController. Preserve a single accepted-state/draft authority.
6. Split OrderingModels into value/serialization, snapshot/identity, target,
   plan/fingerprint and verification files. Keep serialized names, schema versions,
   equality and fingerprints unchanged, with compatibility fixtures.
7. Review policy storage's atomicity, private permissions and crash guarantees
   against OrderingRecoveryStore. Implement a narrowly scoped shared durable-file
   primitive where justified, including restrictive creation permissions and
   explicit synchronization. Do not rewrite all storage formats. Test interruption
   and error paths; distinguish process-crash evidence from untested power loss.
8. Remove demonstrably unreachable obsolete paths only after checking callers,
   recovery schemas and historical reproduction requirements. Keep archived
   Research source outside product targets.

Exit: responsibilities are clearer, existing behavior/receipt fixtures pass and
no unexplained test deletion or new system-mutation pathway exists.

## Phase 3 — Finish the self-signed local distribution pipeline

1. Retain xyz.fi5h.blenny, Config/SigningIdentity.sha1 and the existing Sparkle
   public key. Code signing and Sparkle EdDSA are separate trust mechanisms.
2. Make the distributable build require the pinned Blenny certificate. Missing
   identity, incorrect requirement or invalid nested signatures must fail; never
   silently fall back to ad-hoc. Ad-hoc may remain an explicitly non-distributable
   developer option. Keep Usage4Claude's identity entirely separate.
3. Preserve inside-out Sparkle component signing and relative framework rpaths.
   Decide Hardened Runtime based on the chosen local pipeline and real runtime
   tests; notarization is not a reason to block this self-signed release.
4. Produce a user-facing DMG following Usage4Claude's packaging convention. Adapt
   the existing update helper to sign the final immutable DMG (or deliberately
   document a ZIP update artifact if separate from the installer). Do not rebuild
   or mutate the package after its signature/hash is generated.
5. Emit SHA-256, size, marketing version, CFBundleVersion, EdDSA signature and
   exact source revision as a release receipt. Use monotonically increasing
   release build numbers that exceed relevant prior installed builds; do not
   reset to 1 or rely on an ignored workstation counter for publication.
6. Provide one documented local command for build, package and verification.
   Do not copy Usage4Claude's permissive skip-signing behavior into the final
   release gate. Absence of required update signing must fail that gate.
7. Add concise first-launch instructions for an unsigned-by-Apple application,
   based on the actual current system flow. Never require disabling Gatekeeper,
   SIP or broadly trusting the self-signed certificate as a system root.

Exit: a reproducible self-signed local package with strict integrity, identity,
version and update-signature checks; no claim of notarization or Apple trust.

## Phase 4 — Complete Sparkle integration and feasible local update testing

1. Follow Usage4Claude's architecture: HTTPS raw GitHub appcast plus immutable
   GitHub Release asset URLs, with user-facing release notes as a shared source.
   Blenny's expected feed is the main branch's appcast.xml under its own repo.
   A private-repository URL is not yet a usable unauthenticated public feed.
2. Keep Blenny's EdDSA key/account. Never reuse Usage4Claude's key. Its older
   instructions mix certificate and EdDSA backup formats; follow Blenny's own
   documented key distinction and the pinned Sparkle tooling instead.
3. Generate appcast XML structurally, preserving history and correct version,
   macOS minimum, URL, signature, byte length and release notes. Add tests for
   XML escaping, malformed input, duplicates and version ordering.
4. Match the reference's automatic update-check experience, with an explicit
   user control/consent behavior; do not silently enable unattended installation.
   Preserve manual checking and draft/busy/restore guards. Test the delegate path
   used by automatic checks so it cannot bypass those protections.
5. Prepare two disposable, same-identity builds A and B, with increasing build
   numbers. Preserve the real installed application, accepted state and receipts.
   Use a separate user or isolated fixture when possible; do not run two managers.
6. Serve a loopback test appcast and package using a test-only feed override.
   Prefer local HTTPS; if a loopback HTTP exception is necessary, confine it to a
   test flavor and exact loopback host. Never relax production ATS/TLS validation,
   install a system trust root or ship a test feed. Exercise production update code.
7. Test feed parsing/version comparison; package/signature verification; tampered
   package and incorrect-signature rejection; no update for equal/older builds;
   unavailable feed; cancellation; and available-update UI.
8. Exercise actual A-to-B installation and relaunch where isolation permits.
   Verify version, executable, designated requirement, public key and relevant
   policy/recovery hashes. Restore the original local installation/environment.
9. Record exactly what passed. Static XML validation is not installation E2E;
   loopback E2E is not public HTTPS delivery. If UI/permissions block a scenario,
   request the specific owner action and retain all completed independent checks.

Exit: local evidence and reproducible scripts exist; only genuinely external
checks (public feed/assets and real hosted delivery) remain for publication.

## Phase 5 — Verify authorization, lifecycle and restoration on this host

Do not infer a current failure from old records. Reacquire evidence first.

1. Normally launch the final signed candidate through LaunchServices, at the
   intended installed path. Record actual Device Control trust and exact-file
   bookmark resolution/access, plus fresh API/file agreement. A direct executable
   launch's EPERM is not sufficient evidence that normal app launch is broken.
2. If a grant is stale, guide the owner through the existing exact-file regrant
   UI. Repair stale-bookmark handling only with a test and observed evidence.
   Never delete all TCC data or the accepted Undo ledger as a repair shortcut.
3. With owned fixtures and then explicitly approved real targets, execute:
   - fresh grant and saved-grant relaunch;
   - Visible/Revealable/Hidden, verifying Hidden stays excluded from reveal;
   - same-area ordering and cross-area policy/order Apply;
   - unified Undo, repeated Apply and external-change rejection/review;
   - Stop, Resume, normal Quit and next launch;
   - draft protection during Quit and updates;
   - revoked/regranted permissions and missing/changed target identity;
   - interrupted Apply/restore at deterministic checkpoints, then explicit recovery;
   - sleep/wake and display changes where available on the current setup.
4. Never fault-inject a live third-party write before fixture restoration is
   proven. Save exact touched values and preserve unrelated values. Stop on a
   restoration failure and retain the receipt; no unbounded retry or force reset.
5. Distinguish configuration readback from visible behavior. Request attended
   physical confirmation when automation cannot prove the actual bar behavior.
6. Verify uninstall guidance: Stop/restore according to chosen intent, quit,
   remove login registration and application; retain recoverable data until safe.
   Do not actually uninstall the owner's normal app without explicit scope.

Exit: a matrix names target/build/action, expected and observed state, restoration
result and evidence. Pending manual steps are explicit, not marked passed.

## Phase 6 — Finish README, license and public-facing material

1. After license selection, add the selected license and appropriate notices,
   verify Sparkle/other dependency notices and package needed legal resources.
2. Rewrite README around product use, not development chronology:
   - concise purpose, actual features and screenshot assets safe to publish;
   - currently tested macOS version/build and Apple silicon requirement;
   - download/install/self-signing first-launch guidance and required permissions;
   - Visible/Revealable/Hidden, Apply, Stop/Resume and unified Undo;
   - short, prominent known limitations;
   - updates, recovery/uninstall, support and build-from-source links;
   - license and website link when supplied by the website conversation.
3. Explain Clock/Notification Center, Now Playing and unattributed Gaming/Wine
   behavior accurately. Do not imply read-only entries necessarily remain visible.
   Mention deferred sorting and lack of guaranteed overflow-arrow adjacency.
4. Keep compatibility language short: verified on the named current configuration;
   other builds/configurations have not been verified. Do not add repeated broad
   disclaimers or a speculative future-OS engineering project.
5. Separate user-facing RELEASE_NOTES from technical evidence. Link deep technical
   reports rather than putting the whole history in README. Preserve history.
6. Website handoff: provide product name, version, supported platform, limitations,
   expected download/feed URLs and screenshots. Until the canonical URL is supplied,
   keep a working project link; no guessed domain or broken placeholder link.
7. Align version metadata, project brief, roadmap, spike and release record, with
   status reflecting actual completion rather than prematurely declaring release.

## Phase 7 — Final local gate and publication handoff

1. Run full Debug and ordinary Release tests/builds with explicit Xcode 27.
   Old baseline totals were 645 and 338; promoted coverage changes these totals.
2. Inspect the final signed package: identity, architecture, minimum OS/SDK,
   entitlement/purpose-string needs, nested signatures, keys/feed, relative rpaths,
   legal resources, expected product capability and excluded diagnostic surfaces.
3. Run the new distribution/update gate and record the final artifact hashes.
4. Invoke blenny-release. Scan all reachable refs/blobs and metadata, including
   newly added documents, website links and legal material. Preserve the original
   first commit and shared history. Re-run whitespace/status/object checks.
5. If the script reports no version commit or an unclean tree during preparation,
   record the expected condition. Do not create unauthorized commits solely to
   make the gate green. Re-run the clean gate after authorized commits.
6. Report implemented/verified/pending separately, including local update E2E,
   physical acceptance and public-delivery checks. Avoid claiming complete 1.0.0
   while a required local recovery test is failing.
7. Prepare the exact remote, branch/commit, annotated tag target, release assets,
   appcast commit and intended private-to-public change for owner confirmation.
   No push, release publication or visibility change is authorized by this plan.
8. Publication order must keep downloads available before an appcast advertises
   them. After authorized publication, verify anonymous asset/feed access and a
   hosted update check. Keep website deployment in its own conversation.

## Start instruction

Implement phases 0 through 7 in order, starting from the current checkout. Do not
ask the owner to reconfirm the established self-signing or capability decisions.
Pause only the dependent action for missing license selection, unavoidable system
interaction, unspecified live mutation targets or final publication authorization.
Continue independent authorized work. Report each phase's concrete changes and
evidence, preserving the distinction between tests, local real behavior and public
delivery. This plan is the current scope; the earlier audit is historical input.
