# Blenny 0.5.0 Technical Spike

## Reviewed Management Loop

Status: complete on 2026-08-30 for the exact Debug development boundary. Deterministic Debug and Release verification, installed dry-run, owner-approved real validation, exact restoration, and the release audit passed; the version is closed locally at annotated tag `v0.5.0`, with no push. The owner accepted the current fish/arrow presentation and folded all direct-control follow-ups into this version, explicitly authorizing replacement of only the unpublished local `v0.5.0` tag. Existing commits and all other tags remain unchanged.

Blenny 0.5.0 closes the management loop that 0.4.0 presented but did not connect
to the development-only macOS 27 mutation backend. A valid application-bundle
Draft can be reviewed, bound to an exact system observation, applied through the
single serial writer, verified once, committed atomically, stopped, and restored.

This version remains a development-build compatibility milestone. It does not
promote the unsupported backend to Release and it does not claim broader macOS
27, lifecycle, display, or distribution compatibility.

## Product boundary

- Policy remains application-bundle scoped. One app with multiple status items is
  one policy target.
- `Visible`, `Revealable`, and `Hidden` remain distinct intent.
- Blenny is always `Visible`.
- Apple system items are read-only and can never become mutation targets.
- An ordinary reveal session includes `Visible` and `Revealable`, never `Hidden`.
- Every mutation uses the one serial writer owned by the application management
  loop.
- There is no polling, continuous observation, automatic reconciliation,
  automatic rewrite, or unbounded retry.
- A failed write may be verified once and may retry the identical operation at
  most once, only when the previous safe state is still proven.
- Accepted policy and runtime management state are different facts. Persisted
  intent alone never makes the UI report management as active.

## Management state machine

`ManagementLoopController` is the application-lifetime owner of the state
machine. It is an actor and serializes startup recovery, Apply, reveal, Stop,
Restore, connection invalidation, and termination.

Stable states:

- `unknown`: policy or runtime state has not been established. The UI must not
  report active management.
- `stopped`: accepted policy has management disabled and no writer assertion is
  owned.
- `acceptedPolicyLoadedInactive`: accepted policy requests management but no
  baseline is active yet.
- `active`: the persisted accepted policy matches the exact baseline currently
  owned and verified by the serial writer.
- `unsupportedRuntimeContract`: the compatibility contract failed before a
  backend was created. No assertion is owned.
- `failClosedUnrestricted`: all locally owned assertions were invalidated and the
  runtime is confirmed unrestricted. The requested policy may remain persisted as
  intent, but the UI must not report it as active.

Review and transaction states:

- `reviewPreparing`
- `reviewedPlanReady`
- `applying`
- `writerActivating`
- `baselineVerified`
- `persistenceCommitting`
- `ordinaryRevealSession`
- `stopManagingReview`
- `stopping`
- `restorePreviousPolicyReview`
- `restoring`
- `terminating`
- `connectionInvalidated`

Failure states preserve their exact stage and proven system disposition:

- `activationFailed`
- `activationTimedOut`
- `verificationFailed`
- `persistenceFailed`
- `rollbackFailed`
- `restorationFailed`
- `staleDraft`
- `staleReview`
- `staleObservation`

The UI exposes a compact stable state plus the last transition outcome. It never
collapses `inactive`, `unsupported`, `failed`, or `unrestricted` into `active`.

### Normal startup

1. Enter `unknown`.
2. Load and validate accepted policy, recovery backup, candidate inventory,
   Accessibility permission, installed-app identity, and runtime compatibility.
3. If management is disabled, confirm no writer is owned and enter `stopped`.
4. If management is enabled, enter `acceptedPolicyLoadedInactive`.
5. Prepare the accepted policy's exact baseline without changing persistence.
6. Activate it through the serial writer and perform one bounded verification.
7. Enter `active` only when the exact plan is verified.
8. On any incompatibility or uncertain result, invalidate all locally owned
   assertions and enter an explicit unsupported or fail-closed state.

Startup recovery never rotates the backup and never rewrites an already accepted
policy. There is no daily management switch. An intentionally stopped policy can
be resumed through Review; an unsupported policy cannot be presented as active.

## Ownership

- Accepted policy: `PersistentBundlePolicyStore`; the interface holds a mirror
  refreshed only after a successful commit or a verified load.
- Draft: `PolicyEditorViewModel`; drag, keyboard, and VoiceOver assignment only
  mutate this local value.
- Candidate inventory and observation generation: the interface store that
  produced the Draft and Review inputs.
- Reviewed plan: an immutable, single-use `ReviewedPolicyPlan` owned by the internal action
  preparation flow until consumed or invalidated; no ordinary Review page exists.
- Writer: one `ManagementLoopController`-owned serial writer lease. Transactions
  do not create independent long-lived writers.
- Active assertion: exclusively owned by that writer.
- Persistence transaction: `PersistentBundlePolicyStore` through a staged commit
  API.
- Recovery backup: the persistent store. Restore reads it but never rotates it.

No UI view, AppKit controller, reveal session, or Debug command owns a second
writer.

## Reviewed plan binding

`ReviewedPolicyPlan` binds all inputs that can change the meaning of Apply:

- canonical accepted-policy hash;
- Draft fingerprint and Draft revision;
- candidate generation;
- normalized candidate-inventory fingerprint;
- validation-scope fingerprint;
- bounded system-observation fingerprint;
- runtime-contract fingerprint;
- exact old and new baseline fingerprints;
- exact ordinary reveal fingerprint;
- exact allowed bundle identifiers and allowed system items;
- exact mutable application-bundle target set;
- Hidden exclusion;
- recovery-backup hash and schema when recovery is relevant;
- persistence operation (`saveAcceptedPolicy` or `restorePreviousPolicy`);
- action kind and a single-use review identifier.

Draft edits, candidate refresh, validation-scope changes, accepted-policy changes,
backup changes, or managed-target observation changes invalidate the reviewed plan.
Apply takes only a current `ReviewedPolicyPlan`. Unrelated pass-through process
churn is not target authorization: one bounded preflight rebuilds the exact full
allow-list while requiring the reviewed managed-target bindings to remain equal.
No mutable target is inferred or added from that fresh pass-through observation.

An Apply that can activate or replace an assertion performs one fresh bounded
read-only preflight and compares every bound fingerprint. A mismatch is rejected
before writer acquisition. A reviewed transition to disabled management creates
no assertion and uses its reviewed snapshot: unrelated process churn cannot block
the safety cleanup, while policy, Draft, generation, scope, backup, runtime, and
review identity remain bound and stale changes still reject it.

## Exact target authorization

An eligible mutable target must:

- be represented by an unambiguous application-bundle owner in the complete
  candidate snapshot;
- be included in the Review validation scope;
- not use an Apple bundle identifier;
- not be a read-only system item;
- not be added after Review;
- appear in the exact internally prepared diff and authorization scope before Apply.

Blenny is forced to `Visible` by validation and by plan construction. Internal
Review also prepares the complete assertion configuration, including bundles
allowed to remain visible even when they are not mutation targets. Debug dry-run
reports expose these details; ordinary users do not see an engineering report.

The installed validation approval is narrower than product eligibility: a real
validation run may mutate only the exact targets and exact plan shown to the owner
immediately before the run. Approval never extends to another bundle or another
plan fingerprint.

## Serial writer boundary

The writer actor serializes candidate creation, activation, replacement,
verification, ordinary reveal, conceal, Stop, rollback, restoration, connection
invalidation, and termination.

- Concurrent mutation requests are rejected or queued by the management loop;
  they never create candidates concurrently.
- An exact active plan is idempotent and creates no replacement.
- Baseline replacement activates a candidate before invalidating the preceding
  verified baseline.
- A failed ordinary reveal keeps the preceding baseline.
- A failed transition from revealed presentation back to baseline cannot leave a
  revealed assertion active; it invalidates all owned assertions and fails closed.
- `restoreAndStop` and `connectionInvalidated` are idempotent.
- No component can retain an assertion after surrendering the writer lease.

## Activation and bounded verification

Activation has a finite deadline. A successful completion alone is not published
as active management. Verification checks, within a second finite deadline:

- the exact configuration round-tripped before activation;
- the activation completion succeeded;
- the candidate and writer generation are still current;
- the connection has not been invalidated;
- the writer's active-plan fingerprint equals the reviewed baseline fingerprint.

This is assertion-contract verification, not menu-bar pixel verification. Blenny
does not capture menu-bar pixels and does not claim visual reconciliation.

After a write failure or ambiguous timeout, verification is attempted once. The
identical operation may retry once only if the verifier proves the failed
candidate inactive and proves the preceding safe baseline still current. An
unknown result does not retry and instead enters rollback. No loop exists.

If the development runtime cannot provide the required verification signals, the
compatibility kill switch remains closed and real Apply is unavailable.

## Apply transaction

1. Consume the current reviewed plan.
2. For an activating transaction, freshly revalidate policy, Draft, candidate,
   scope, observation, backup, runtime, and authorization fingerprints. For a
   disabling transaction, revalidate the non-observational bindings against the
   reviewed snapshot so unrelated process churn cannot prevent cleanup.
3. Capture the exact accepted-policy, backup, writer, and system baseline.
4. Acquire the single writer lease.
5. Activate the reviewed new baseline.
6. Perform one bounded verification.
7. Enter persistence only after the new baseline is verified.
8. Commit persistence at the defined commit point.
9. Publish accepted policy, clear Draft and Review, synchronize status item and
   window UI, and enter `active` or `stopped` as appropriate.

An unchanged reviewed plan with a verified active baseline is a no-op: no
candidate, persistence write, or backup rotation occurs. Explicit Resume from
inactive accepted enabled intent may freshly activate and verify that unchanged
policy without saving it or rotating recovery; the follow-up contract below
specifies this distinction.

## Persistence and recovery commit

Policy and backup files remain scoped to Blenny's application-support directory,
are encoded deterministically, are written atomically, and have mode 0600.

A semantic policy change uses staged files plus a small 0600 transaction marker
in the same directory:

1. Read and hash the exact old accepted policy and old backup.
2. Stage and decode-verify the new accepted policy.
3. Stage the old accepted policy as the new recovery backup.
4. Record enough transaction metadata to distinguish old and new hashes after a
   crash and to restore the exact previous backup.
5. Atomically replace the backup.
6. Atomically replace the accepted policy.
7. Decode, permission-check, and hash-check accepted policy.
8. The successful accepted-policy replacement and readback is the persistence
   commit point.
9. Remove transaction staging data after both committed files are verified.

Before the commit point, failure or startup recovery restores the exact previous
accepted policy and previous backup. After the commit point, recovery completes
and verifies the new accepted policy with the old accepted policy as its backup.
Only a successfully committed semantic change leaves a rotated backup.

`Restore Previous Policy` atomically writes the validated backup policy to the
accepted path without rotating or replacing the backup. Repeated restoration is a
no-op.

## Rollback and restoration

If activation or verification fails, persistence remains unchanged.

If persistence fails after a verified activation:

- when a preceding management baseline existed, replace the candidate with that
  exact baseline and verify it once;
- when management was previously stopped, invalidate the candidate and verify no
  writer plan remains;
- restore accepted-policy and backup hashes to their pre-transaction values.

If replacement or rollback cannot be proven, invalidate pending and active
assertions, close the writer connection, stop ordinary reveal, and enter
`failClosedUnrestricted` only after unrestricted state is confirmed. If cleanup
cannot be confirmed while the process remains alive, report
`restorationFailed`, prevent further mutation, and terminate the application so
process disconnect is the final cleanup boundary.

Failure never publishes the proposed policy as accepted, never clears the Draft,
and never rotates the backup without a committed policy change.

## Stop Managing

Stop is a reviewed transaction, not an immediate button action.

1. Prepare an exact disabled-policy Review and recovery plan.
2. Reject stale policy, Draft, generation, scope, backup, runtime, or Review
   identity before the writer. Candidate and observation data remain the exact
   reviewed snapshot because Stop cannot create or replace an assertion.
3. Commit the disabled policy so a crash cannot reactivate management on the next
   launch.
4. Invalidate pending and active assertions and verify the writer has no plan.
5. Synchronize accepted policy, Review, status item, and UI while preserving any
   unapplied Draft assignments. Resume and Restore reject a dirty Draft.

Repeated Stop is idempotent and does not rotate backup. A cleanup failure is shown
as a failure, never as stopped success; process termination remains the final
cleanup boundary.

## Restore Previous Policy

Restore also requires Review. The backup must be present, decode correctly, use a
compatible schema, keep Blenny visible, contain no mutable Apple target, and pass
current candidate, scope, observation, and runtime validation.

- Enabled backup: activate and verify its exact baseline, then atomically restore
  it to accepted policy without rotating the backup.
- Disabled backup: atomically restore it, then ensure the writer is stopped.
- Missing or incompatible backup: no writer or persistence call.
- Repeated Restore: no assertion replacement, write, or backup rotation.

## Application termination and connection invalidation

When a pending or active assertion exists, AppKit termination enters
`terminating`, rejects new work, cancels reveal, and waits for bounded,
idempotent writer cleanup before replying to the termination request.
`applicationWillTerminate` performs a final best-effort invalidation.

Unexpected process death relies on the process-owned MenuBarAgent connection to
remove the assertion. The next launch always begins at `unknown` and rebuilds the
runtime truth from scratch.

Writer connection invalidation clears pending and active ownership, cancels
reveal, invalidates the reviewed generation, and enters a fail-closed state. It
does not automatically reconnect, recreate, rewrite, or reconcile.

Broader MenuBarAgent recreation, sleep/wake, Spaces, display changes, and status-
item lifecycle hardening remain outside this version's compatibility claim.

## Runtime compatibility boundary

Real mutation is available only when all of the following are true:

- Debug development build;
- arm64;
- exact macOS 27.0 build 26A5416b;
- built with Xcode 27 and macOS 27 SDK;
- Blenny installed under `/Applications` and registered with LaunchServices;
- Accessibility authorized;
- the expected private framework, classes, selectors, exact Objective-C method
  encodings, configuration round-trip, activation completion, and invalidation
  contract all match;
- accepted policy, backup, candidate scope, and observation are valid and stable;
- the exact target authorization is current.

Failure closes the runtime kill switch before candidate creation. This version
does not claim support across a changed process/status-item topology without a
new bounded Review and observation.

## Debug and Release isolation

- Private framework loading, private class and selector strings, the real factory,
  compatibility manifest, real-write authorization, and installed validation
  entrypoints remain inside `#if DEBUG` or a Debug-only source boundary.
- The generic policy model and deterministic fake writer remain testable in both
  configurations.
- Release receives an unavailable backend and cannot opt in through environment,
  defaults, UI, or dependency injection.
- Release validation scans the executable and bundle for private runtime symbols,
  Debug fixtures, validation bundle IDs, and mutation switches.
- Connecting Review and Apply in Debug is not Release backend promotion.

Release promotion requires a later, explicit compatibility decision.

## UI and error presentation

- The UI distinguishes persisted intent from runtime actuality.
- `Management On` appears only for a verified active baseline.
- Startup may briefly show `Preparing Management` or `Verifying Management`.
- Stopped, stale, unsupported, rollback, unrestricted, and restoration failures
  have distinct concise messages and recovery guidance.
- Internal Review prepares exact diff, impact, validation, recovery, assertion
  warning, baseline allowed set, ordinary reveal set, Hidden exclusion, backup,
  rollback, Stop, and restoration behavior. Full reports remain in Debug dry-run
  evidence; ordinary Apply, Resume, Stop, and Restore need no separate Review page.
- Successful Apply synchronizes accepted policy, Draft, Review, status item, and
  every open window from the committed result.
- Once normal startup reliably restores management, the transitional stopped-
  management banner can be removed from routine Organize UI.
- Stop Managing and Restore Previous Policy remain visible safety operations.

Organization Board, Liquid Glass navigation, assignment interaction, keyboard,
VoiceOver, Settings, Support, window animation, placement, size, and appearance
behavior must remain stable.

## Deterministic tests

The 0.5.0 suite must cover:

- reviewed-plan binding to Draft, candidate generation, candidate inventory,
  validation scope, accepted policy, backup, runtime contract, and observation;
- stale Draft, stale Review, and stale observation rejection before writer access;
- unreviewed Draft rejection;
- exact target authorization and Apple-system-item exclusion;
- Blenny always Visible and Hidden never in ordinary reveal;
- serial writer exclusion, first activation, replacement, and unchanged-plan
  idempotence;
- activation failure, timeout, bounded verification, permitted single retry, and
  forbidden retry on unknown state;
- verification and persistence failure;
- rollback success, rollback failure, unrestricted cleanup, and restoration
  failure;
- staged persistence commit ordering, crash recovery, 0600 permissions, backup
  stability, and no failed-transaction pollution;
- startup recovery, unsupported runtime, malformed policy, missing or incompatible
  backup;
- Stop, repeated Stop, Restore, and repeated Restore;
- connection invalidation and application termination;
- successful transaction synchronization;
- Release inability to construct or access the Debug-only backend;
- Accessibility, Open at Login, Refresh, Review, close, reopen, Quit, and recovery
  presentation stability;
- drag, keyboard, and VoiceOver assignment remaining local Draft operations;
- existing 0.4.0 product-interface behavior remaining stable.

## Installed dry-run and real-write approval gate

After all Debug and Release deterministic tests and final app builds pass:

1. Install the final Debug app.
2. Record pre-mutation policy, backup, permissions, hashes, management state,
   relevant processes, assertion disposition, Accessibility, and Open at Login.
3. Run an installed dry-run that structurally cannot construct an assertion
   factory or candidate.
4. Present the exact bundle identifiers, mutable targets, baseline allowed set,
   ordinary reveal allowed set, Hidden exclusion, writer operation, assertion
   replacement, verification, persistence, backup, rollback, Stop, and
   restoration plan.
5. Prove the complete restoration path exists.
6. Wait for explicit owner approval of that exact plan.
7. Do not broaden the approved targets or plan fingerprint.
8. After any approved write validation, restore the complete pre-mutation system
   state and compare content, permissions, hashes, management, processes,
   assertion cleanup, Accessibility, and Open at Login.
9. Confirm no Blenny process remains after validation.

All logs, reports, state copies, and local evidence remain under ignored
`LocalData/`. No menu-bar pixels are captured or persisted.

The final installed Debug validation on 2026-08-30 completed the reviewed real
Apply, Stop Managing, Restore Previous Policy, repeated Restore no-op, active
Quit, ordinary-launch resume, final Stop, and exact restoration sequence. The
final safety pass also proved that an activating Apply rejects fresh observation
drift before writer access and that reviewed Stop is not blocked by unrelated
process churn. The
accepted policy and scoped backup returned to their pre-validation SHA-256
values and 0600 permissions, `managementEnabled` returned to false, Open at
Login remained disabled, and no Blenny process or process-owned assertion
remained. Activation and verification failure injection remains deterministic
test coverage because the installed private runtime deliberately exposes no
failure-injection switch.

## Acceptance criteria

- A valid reviewed application-bundle Draft can complete the real Debug Apply
  transaction inside the exact compatibility boundary.
- Apply cannot use stale or unreviewed state.
- Every mutation goes through the single serial writer.
- Activation is followed by one bounded verification.
- Persistence has a defined recoverable commit point and preserves the exact prior
  backup on failure.
- Failed transactions return to a proven preceding baseline or confirmed
  unrestricted state.
- Startup restores a safe persisted managed policy without a daily switch.
- Stop and Restore are reviewed, safe, and idempotent.
- termination and connection invalidation clean up writer ownership.
- UI management state is always truthful.
- Release cannot access the Debug-only mutation backend.
- Debug and Release tests and builds pass with Xcode 27/macOS 27 SDK.
- Installed dry-run passes without assertion creation.
- Any approved real-write validation ends with complete state restoration.
- No tracked build output, log, screenshot, state copy, binary, or private path is
  introduced.

## Explicit exclusions

- Lane ordering.
- Custom Blenny Board display order.
- Physical menu-bar ordering or ordering feasibility work.
- Preferred-position promotion or pointer-selected insertion.
- Synthetic pointer movement, click, or Command-drag.
- Mutable Apple system items.
- Per-status-item policy.
- Screen Recording or menu-bar pixel capture.
- Polling, continuous observation, automatic reconciliation, or unbounded retry.
- Helpers, IPC services, daemons, or additional background processes.
- Broader lifecycle, display, multi-screen, Spaces, sleep/wake, or MenuBarAgent
  recreation hardening.
- Updater, signing, notarization, distribution, global shortcuts, profiles,
  themes, automatic rules, decorative animation systems, purchasing,
  subscription, entitlement, licensing, or payment handling.
- Release backend promotion without a separate compatibility review.

The owner subsequently assigned native-overflow integration and missing-application
discovery to 0.6.0, retaining its lifecycle/display hardening scope. Ordering
feasibility moves to 0.7.0: distinguish bundle policy, status-item instance and
physical position; prohibit synthetic input and misleading Board-only ordering;
prove exact write, snapshot, diff, Review, restoration and lifecycle safety before
choosing whether to implement. No ordering investigation occurs in 0.5.0.

## Implementation follow-ups and installed evidence

The following record preserves the chronological attempts and their evidence.
Intermediate pending-acceptance and no-tag statements describe those runs, not
the final closure. The owner subsequently accepted the current fish/arrow
presentation, kept the whole milestone at 0.5.0, and approved replacing its local
tag without rewriting history. Earlier attempt descriptions are not a claim that
superseded UI paths or native-control integration are accepted capabilities.

### Problem

The 0.5.0 routine Review exposed the full engineering dry-run report. It was
auditable but poor product UI. Review authorization also included unrelated
running processes, so harmless process churn could reject Resume with a generic
`staleReviewedPlan` error. Finally, applying a Draft while management was stopped
saved the policy but did not activate it.

### Decision

- Owner decision: ordinary users do not see a Review page. Apply, Resume,
  Stop, and Restore each prepare and validate an immutable single-use plan
  internally, then commit it. Assignment itself remains Draft-only.
- Preparation and commit share an interaction gate. Duplicate clicks, Draft
  edits, Refresh and reveal transitions cannot overlap an in-flight action.
  Errors remain visible and preserve the Draft; there is no automatic retry of
  a stale plan.
- Stop remains available with a dirty Draft and preserves those unapplied
  assignments. Resume and Restore require applying or discarding that Draft
  first, so they cannot silently replace it. Termination closes the interaction
  gate, waits for the bounded in-flight action, then cleans up the writer.
- Keep bounded process-local action audit records (action, phase, binding and
  plan fingerprints). The existing atomic policy, previous-policy backup and
  transaction marker remain the durable recovery source. Do not add an
  always-on disk logger or persist unrelated process inventories. Debug dry-run
  evidence can still be redirected explicitly into ignored LocalData.
- The complete hashes, exact allow-lists, transaction details, and recovery steps
  remain available in the Debug installed dry-run and ignored local evidence.
- A valid Draft Apply proposes `managementEnabled=true` on the supported Debug
  boundary. Stop Managing remains the explicit reviewed way to persist disabled
  intent.
- Review authorization binds accepted policy, Draft, candidate generation,
  validation scope, runtime contract, recovery backup, and the candidate and
  running state of approved managed bundles.
- Unrelated pass-through processes are excluded from the authorization binding.
  Apply still performs one fresh bounded scan, rebuilds the full exact baseline
  and ordinary-reveal plans from that scan, and sends only that refreshed plan to
  the serial writer.
- A managed bundle PID, ownership, availability, assignment, scope, policy,
  runtime, backup, or generation change remains stale and fails before writer
  access.
- User-facing stale errors name the corrective action instead of exposing an enum
  number.
- A Draft edit during the bounded Apply preflight is rejected before commit.
- A no-op keeps the actual active plans and does not claim a freshly rebuilt
  pass-through plan was written. It creates no assertion and rotates no backup.
- The normal AppKit controls use two native NSStatusItems: Blenny artwork and
  13-point medium double chevrons in two compact 22-point items. Each native button has its own action;
  artwork opens the editor, while the arrow
  sits on the left and toggles a session independently of native presence.
  The inline arrow remains present throughout active/revealed states; the explicit reveal/conceal
  menu action remains reachable. Right-click and an Accessibility custom action
  retain the safety/recovery menu. Inactive, unsupported
  and busy states do not accept reveal actions. A completed reveal changes the
  direction; failed transitions retain the proven direction or disable the
  control after fail-closed cleanup. The ordinary 30-second bounded session still closes itself.
- The ordinary path now explicitly owns the previously prototype-only native
  overflow observer. A present, observable, known native state selects native
  ownership for native events, but never disables Blenny's explicit button.
  An explicit Blenny click supersedes queued native intent and can also conceal
  a native-owned session. A Blenny-opened transition retains its owner while in
  flight, even if its own reveal makes native overflow appear. Once it finishes,
  fresh native edges may continue that session. The first snapshot is not a click.
  Only known expand/collapse edges can request native-owned transitions.
- Native events coalesce into at most one pending intent and use the same
  interaction gate and serial writer as fallback actions. Duplicates do not write.
  A collapse received during reveal activation is retained; a reflow during
  conceal cannot queue an immediate reopen. Unknown or lost native observation
  closes a native-owned session and selects fallback after verified conceal.
- Apply, Stop and Restore suspend native intent and discard stale queued events.
  A session-specific timeout also enters through the gate, waiting behind a
  bounded Refresh instead of racing it. Termination detaches the observer and
  prevents callbacks from starting more work. Observer contexts reject callbacks
  from a previous registration; replaced AX elements are unregistered.
- Discovery is bounded by depth, element count, a one-second traversal deadline
  and per-message timeout. Native notifications do not refresh the application
  candidate inventory or authorize new bundles. There is no polling, position
  write, synthetic input, or promotion of the old placement/length experiments.
- Installed validation exposed another prototype gap: unrestricted descent into
  MenuBarAgent child menus exhausted the element limit. Native discovery now
  reuses the inventory's privacy boundary: AXExtrasMenuBar containers stop at
  buttons/status items; menu-bar-sized agent presentation roots expose only one
  child level. Unrelated application menu/window content is not traversed.
  Unavailable observation carries a scoped reason rather than claiming absence.
- One read-only sample after an explicit operation or Workspace application
  activation discovers newly created overflow controls when container layout
  notifications are absent. Discovery may close an unsafe native-owned session,
  but never interprets an expanded snapshot as a reveal request or schedules
  another sample. Subsequent registered native value edges drive the session.

### Ordinary-path integration audit

The prototype was separately launched and therefore was not inherited merely by
retaining its source. The patch explicitly checks each entry point:

| Capability | Ordinary-path result |
| --- | --- |
| Native overflow events | Connected through `OrdinaryRevealCoordinator`; same verified writer as fallback |
| Native discovery | Reuses the bounded inventory traversal policy; unrelated menus cannot exhaust the native scan |
| Session ownership and Hidden exclusion | One owner per session; immutable accepted reveal plan, never Hidden |
| Session timeout | Session identity plus shared interaction gate; no out-of-band write |
| Manual Refresh | Read-only after the first startup recovery; no silent assertion replacement and no Draft discard |
| Failed reveal | Verify and retain the preceding baseline once; failed/throwing verification fails closed |
| MenuBarAgent exit | Stop observation, invalidate writer, report unrestricted; no automatic reconnect |
| Termination | Wait for active interaction and connection cleanup; reject late callbacks and activation publication |
| Stop, Restore, persistence | Existing prepared transaction and scoped backup remain mandatory |
| Prototype placement, length, experiment timeout and fixture actions | Deliberately not promoted |

MenuBarAgent process termination is an observable connection-loss boundary, not
a newly proven private XPC invalidation callback. The private assertion contract
still exposes only activation completion and explicit invalidation. Silent
connection loss without a process-exit signal, broader lifecycle/display behavior,
and guaranteed collapsed-bar placement remain unproven and deferred. `Visible`
is an allow policy, not a guarantee that macOS cannot overflow Blenny itself.
The desired edge-adjacent location is recorded as a later positioning question;
this patch does not investigate or write positions.

### Safety boundary

The 0.5.0 Debug-only runtime boundary, single serial writer, activation and
verification rules, bounded retry, transactional persistence, rollback,
restoration, lifecycle cleanup, Apple read-only boundary, Blenny Visible rule,
Hidden exclusion, and Release isolation are unchanged.

No sorting, polling, automatic reconciliation, synthetic input, menu-bar pixel
capture, helper, IPC, daemon, mutable Apple item, or Release backend promotion is
added.

### Native-control handoff follow-up

Historical handoff attempt: the auto-hide rule below was superseded by the
own-arrow follow-up. Native-control repair is still not accepted as complete.

The owner requested arrow-left/artwork-right placement, a smaller arrow matching
the supplied crop, and no duplicate Blenny arrow when native overflow is usable.
The previous fix kept the explicit action reachable but retained the prototype's
inactive-owner rule: native edges during a Blenny-opened session were deliberately
ignored. That behavior does not meet the requested handoff.

- Use 13-point regular chevrons to reduce the oversized 16-point glyph.
- Keep a directly usable safety-menu reveal/conceal action, even when the inline
  arrow is hidden. Unknown or unavailable native observation shows the fallback.
- Hide only the inline arrow when the native control is present, observed and
  known. Reserve the same two control slots while management is active so hiding
  the arrow cannot itself create/remove overflow and cause a layout feedback loop.
- An initial snapshot, discovery, or native appearance never writes. A fresh
  known native edge may control an already revealed Blenny session once its
  transition has finished. It uses the same prepared plan, interaction gate,
  bounded session deadline and serial writer. In-flight Blenny reflow cannot
  race the operation; conceal reflow cannot immediately reopen it.
- Retain subscriptions for unchanged AX elements. Read the notifying native
  element for value changes instead of unregistering and rediscovering the whole
  control tree on every edge; topology changes still get one bounded discovery.
- This observes and follows native state; it does not intercept, suppress or
  replace Apple's input, layout or animation.
- The historical self-position-500 receipt in the 0.0.3 spike proves only its
  bounded test. Ordinary self-placement promotion remains a separate owner
  decision; no position write is added by this handoff fix.

### Own-arrow click and visibility follow-up

Historical coordinate-routing attempt: the owner subsequently confirmed that
visibility and direction were correct but physical left clicks still did not
toggle. The hit-test checks below did not prove real action delivery. This path
is replaced by the dedicated native buttons described next.

The owner reports that the safety-menu toggle works, while Blenny's arrow
disappears after expansion and its physical click is unreliable. Native-control
repair is a separate undecided scope item and is not attempted here.

- Remove native presence from inline-arrow visibility. A native AX snapshot is
  not proof that the native control can replace Blenny's own working action.
- Keep the arrow left and artwork right in stable 26-point hit regions. The
  parent NSStatusBarButton owns physical tracking; its child presentation stack
  passes hit testing through. Route the left region to exactly the same toggle
  as the menu, and the right region to the editor. A busy left region is a no-op,
  not an accidental editor click. Secondary click retains the safety menu.
- Preserve separate child accessibility actions and labels. No system-wide
  event monitor, synthetic event, new writer path or position write is added.
- Verify local AppKit hit testing without creating a status item or displaying a
  window, and test repeated reveal/conceal with changing native presence. Debug
  installed diagnostics record action names and the own-arrow hit-route result,
  not pointer coordinates or pixels.
- Existing native observer/session code is unchanged. Its installed behavior
  remains unresolved; this fix neither claims to intercept native clicks nor
  guarantees Blenny a physical position outside macOS overflow.

### Dedicated native buttons follow-up

- Use two normal NSStatusItems with independent NSStatusBarButton actions.
  The arrow invokes the same toggle as the working menu; the artwork opens the
  editor. No NSApp.currentEvent location, subview hit test, pointer sampling,
  event injection, global monitor or preferred-position write is involved.
- Create both 26-point items before the first inventory and retain them until
  Quit (the final spacing follow-up reduces each item to 22 points). Inactive/unavailable management leaves the native arrow visibly disabled
  with an explanatory label; it is not removed and re-created during management
  transitions. This keeps Blenny's own candidate item count stable for prepared
  policy bindings. The artwork and safety menu remain available.
- Busy state disables the arrow. Direction follows only the verified baseline
  or reveal state, independently of native overflow presence. Each native
  button exposes its own accessibility label and action.
- The historical explicitly launched Debug policy prototype keeps its separate
  single-item control. Release still has no mutation backend or diagnostic switch.
- Test sender-identity routing, unavailable/busy guards and repeated toggle
  direction. Installed acceptance must capture an actual arrow action followed
  by the verified state transition; geometry or action-binding inspection alone
  does not establish physical click success.
- This replaces only Blenny's own click path. Native system-arrow behavior,
  ordering/own-position promotion, policy, writer and recovery scope are unchanged.

### Failed-startup Resume follow-up

Persisted `managementEnabled=true` is intent, not proof of an active assertion.
The editor and status menu enable explicit Resume from inactive/fail-closed
states after Accessibility is granted, while busy actions and dirty Drafts still
block it. Stop stays available to persist disabled intent. Refresh remains
read-only and never retries startup in the background.

Resume captures current candidate ownership for internal preparation, then checks
the fresh runtime and observation again at commit. The prepared persistence mode
explicitly identifies Resume. If accepted enabled intent is unchanged but no
assertion exists, the transaction acquires a fresh writer, activates the exact
baseline and verifies it without saving policy or rotating backup. A repeated
Resume with the same verified active plan is a no-op. Missing/incompatible or
changed recovery backup rejects before writer access. Activation/verification
failure restores unrestricted state: persisted enabled intent must not be used
to invent a previously active baseline. Termination and connection invalidation
still require a new process, not an in-process reconnection.

Startup validation errors name missing managed bundles and ask the user to open
them before Resume. This development boundary still requires all scoped targets
to be running and attributable; launching only some targets is not partial
authorization to change the plan. No candidate is silently removed from policy.

### Deterministic acceptance

- Unrelated running-process churn keeps the reviewed authorization valid.
- Apply rebuilds the exact plan and includes the current unrelated pass-through
  process before writer access.
- Managed candidate PID replacement still invalidates Review.
- Draft, generation, scope, runtime, policy, and backup changes remain stale.
- Draft Apply from stopped management proposes an active policy.
- Routine Apply has no visible Review route and still requires a validated plan.
- Busy gating prevents duplicate actions and Draft/Refresh/reveal overlap.
- Status chevrons, click routing, no-Revealable policy, busy, stopped,
  unsupported, failure and termination presentations are deterministic.
- Native known-state edges, duplicate/initial snapshots, collapse during
  activation, fallback ownership during activation, later native handoff, observer unavailability,
  suspended policy actions, stale timeout generations, conceal reflow, and
  direct clicks with native overflow present, direct conceal of native sessions,
  direct-intent priority, and startup/Stop/Resume arrow availability are deterministic.
- Native events and ordinary fallback use the same fake-writer integration test;
  reveal failure retains the verified baseline and throwing verification cleans up.
- A native collapse after a completed Blenny reveal closes the same session;
  native appearance and post-write discovery cannot immediately undo that reveal.
- Native presence, absence and expansion do not hide Blenny's native arrow.
  Dedicated sender actions, busy rejection and disabled inactive presentation are deterministic.
- A delayed successful verification after connection invalidation cannot publish
  active management again; the lifecycle generation must still match.
- Audit records are bounded, contain no raw bundle inventory, and do not replace
  the atomic recovery files.
- Debug and Release test suites pass; Release still lacks the Debug backend.

### Installed acceptance

Build and install the final Debug app, confirm direct Apply and status chevrons,
validate the current owner-selected policy through Apply and Stop, then restore and compare the
pre-validation policy, backup, permissions, process, assertion, Accessibility,
and Open at Login state. Store all evidence under ignored `LocalData/` and capture
no menu-bar pixels.

For explicit installed sessions, Debug-only `BLENNY_SESSION_DIAGNOSTICS=YES`
emits compact launch, management, native-state and termination receipts to stdout.
It enables no mutation path and changes no authorization. Redirect it only into
ignored `LocalData/`; normal launches do not create a log file. The switch and
private backend remain absent from Release.

The earlier native-control integration passed 186 Debug tests in 21 suites and 184
Release tests in 20 suites with Xcode 27/macOS 27 SDK. Both arm64 app builds pass
strict codesign validation and declare minimum macOS 27.0. Release contains no
private assessment factory, mutation switch, placement switch, or session-log
switch. The installed Debug dry-run passed without writer, assertion or
persistence. Final read-only observation found the native control collapsed and
successfully registered its state notifications. Explicit normal startup reported
verified active management with native ownership; normal termination confirmed
writer cleanup. Policy and backup bytes and 0600 permissions were unchanged,
Accessibility remained granted, and Open at Login remained unregistered.
These receipts do not establish installed native-click or split-button visual
acceptance; those remain pending owner validation, and this patch is not closed
or tagged.

Owner follow-up exposed a UI arbitration error in that validation build: native
presence disabled Blenny's button even when the native control was no longer
usable on screen. Stop/Resume could change the observation and mask the error.
The patch removes native presence from button enablement; verified management,
Revealable scope and the shared busy gate remain mandatory. It also changes
the chevron weight from semibold to regular without shrinking its optical size.
Installed diagnostics now report the actual AppKit arrow's enabled property
after the interaction gate is released, without reading or capturing pixels.

The follow-up passed 189 Debug tests in 21 suites and 187 Release tests in 20
suites, both arm64 app builds and strict codesign checks. The installed no-write
dry-run passed. Normal startup verified active management with observable native
overflow and the actual AppKit arrow enabled after the gate released. Normal Quit
reported writer cleanup, no Blenny process remained, and policy/backup bytes and
0600 permissions matched the pre-install copies. Accessibility remained granted.
Service Management reported `notFound` in this run, rather than the earlier
`notRegistered`; no login registration/unregistration was invoked, and this is
not evidence of unchanged login registration status. Actual click feel and glyph
weight remain owner visual acceptance, without pixel capture. No tag is created
by this incremental check.

The native-handoff follow-up passed 194 Debug tests in 21 suites and 192 Release
tests in 20 suites; both arm64 app builds and strict signature checks passed.
Its first installed dry-run correctly rejected a missing running approved target.
After temporarily starting that already-approved application, a fresh dry-run
passed without a writer or persistence. Normal startup verified active fallback
management, an enabled inline arrow and arrow-left/artwork-right arrangement.
No actual native expand/collapse click occurred during this installed session,
so native-event delivery, automatic hiding in the live native-present layout and
glyph visual parity remain pending owner acceptance, not claimed as passed by
the deterministic handoff tests. Normal Quit confirmed writer cleanup; policy
and backup bytes and 0600 permissions were unchanged. The temporarily started
target was returned to its original stopped state. Self-position promotion
remains unapproved and disabled; this patch is not closed or tagged.

The failed-startup Resume follow-up passed 202 Debug tests in 21 suites and 200
Release tests in 20 suites, both app builds and strict codesign checks. The final
installed dry-run rejected the absent approved target without creating a writer,
assertion or persistence change. Normal startup remained honestly unrestricted,
named that missing target and reported both the editor and AppKit menu Resume
controls enabled. Normal Quit confirmed cleanup, with no Blenny process left.
Policy/backup bytes and 0600 permissions were unchanged; Accessibility was granted
and Service Management reported `notFound`. No real Resume activation or native
click was exercised in this follow-up: unchanged reactivation, failure cleanup,
staleness and backup preservation are deterministic-test evidence. No position
write, new authorization target, tag or push was added.

The own-arrow follow-up passed 206 Debug tests in 22 suites and 204 Release tests
in 21 suites, both app builds and strict signature checks. Local AppKit tests
confirm parent-owned hit testing with retained accessibility elements, left/right
action routing, busy rejection and repeated reveal/conceal presentation across
native appearance. Installed dry-run passed without mutation. Owner-authorized
normal startup activated the unchanged accepted baseline and reported an enabled,
visible left arrow whose real AppKit hit region routes to the shared toggle.
No physical user click occurred in the bounded installed session, so repeated
installed click behavior remains owner acceptance rather than a claimed real-run
result. Normal Quit confirmed assertion cleanup; no Blenny process remained.
Approved target processes, policy/backup bytes and 0600 permissions were unchanged.
Accessibility remained granted and Open at Login reported `notFound`. Native
control repair and own-position promotion remain outside this follow-up.

The dedicated-native-buttons follow-up passed 206 Debug tests in 22 suites and
204 Release tests in 21 suites. Both arm64 app builds, strict signatures and the
installed no-write dry-run passed. The installed normal session activated the
unchanged accepted baseline, reported an enabled, visible arrow and confirmed
distinct native button targets/actions. No actual arrow action arrived during
this bounded session; physical left-click behavior is therefore still pending
owner acceptance, not established by the action-binding check. The read-only
window-frame diagnostic does not establish relative physical placement. Normal
Quit reported writer cleanup and no Blenny process remained. The approved target
processes, policy/backup bytes and 0600 permissions were unchanged. Accessibility
was granted; installed startup reported Open at Login `notFound`, and no login or
permission setting was changed. The prior installed app is recoverable in ignored
local evidence. Native system-arrow repair, positioning and release closure
remain outside this follow-up.

### Owner acceptance and optical-weight follow-up

The owner subsequently confirmed that the dedicated native arrow now expands
and conceals correctly, and accepted keeping the artwork and arrow as separate
status items. This is owner-reported installed click acceptance, separate from
the earlier bounded diagnostic session, which captured no physical click.

The arrow appeared slightly thinner than the native control. Change only its
symbol weight from regular to medium, retaining the 13-point size, two stable
26-point native items, action bindings and verified-state direction. Exact
visual parity is not claimed and no menu-bar pixels are captured.

The owner also reports an unlisted Bartender item that remains missing after
manual Refresh. Its cause is not yet diagnosed; this is a known discovery issue,
not evidence that all newly launched applications are unsupported. No Bartender
mutation or inventory change is authorized by this optical adjustment. The owner
subsequently approved deferring that investigation and native-overflow integration
to 0.6.0. This is not a completed fix or a promise to intercept Apple's button.

The weight-only change passed 206 Debug and 204 Release deterministic tests,
both app builds, strict signature validation and the installed no-write dry-run.
The prior running validation app was quit normally before replacement. The new
app was not launched for real management validation: no new assertion was
created, policy and backup remained byte-identical with 0600 permissions, and
no Blenny process remained. The owner-confirmed click behavior above applies to
the previous regular-weight build; the new weight awaits visual acceptance.

### Compact spacing and confirmed milestone sequence

The final spacing adjustment retains both working native buttons and reduces
each item's public AppKit length from 26 to 22 points. Neither the 18-point fish
artwork nor the 13-point medium chevrons shrink; only surrounding whitespace is
reduced. No image offset, custom hit region, positional preference or system
spacing setting is changed. The two item identities, action targets, direction
and management gates remain unchanged. Actual visual spacing remains installed
owner acceptance, not a guarantee about macOS placement.

The owner approved moving native-overflow integration and missing-application
discovery work to 0.6.0, alongside the existing lifecycle/display hardening.
Real menu-bar ordering investigation moves from 0.6.0 to 0.7.0 with every original
safety gate intact. Distribution preparation follows at 0.8.0; public release
candidates remain 0.9.x. No work on those deferred capabilities is included here.

The compact-spacing build passed 206 Debug and 204 Release tests, both arm64 app
builds, strict signatures and the installed no-write dry-run using Xcode 27 and
the macOS 27 SDK. The previous running app quit normally before replacement; no
new real management session was started. Policy/backup bytes and 0600 permissions
match this run's pre-install copies, and no Blenny process remained. Accessibility
was granted; Open at Login reported `notFound`, with neither setting changed.
Visual spacing remains owner acceptance before release closure.

### Historical release audit and presentation gate

The complete patch from `v0.5.0` / `9ccffa08` was reviewed, including every new
source/test file. The coupled implementation is organized as a forward fix
commit, followed by the version record and roadmap. No existing commit, tag,
author or timestamp is rewritten. The original first commit is preserved.

| Patch criterion | Evidence and boundary |
| --- | --- |
| Internal preparation instead of a routine Review page | Ordinary UI route removed; navigation, action gate and Draft tests pass; owner requested this behavior |
| Apply and failed-startup Resume | Exact managed authorization and fresh pass-through plan tests; unchanged Resume activates without saving or rotating backup; owner reported working management |
| Safe Stop and Restore | Dirty-Draft preservation and recovery/control tests; inherited atomic store and serialized transaction tests remain passing |
| Independent arrow and artwork | Owner confirmed real reveal/conceal clicks; sender-identity and repeated-direction tests pass; final 22-point spacing still needs visual confirmation |
| Staleness, verification and cleanup | Deterministic stale scope/PID/runtime/backup, activation, verification, rollback, termination and connection-loss tests |
| Final build boundary | Xcode 27, macOS 27 SDK, arm64, minimum macOS 27.0; Debug 206 tests in 22 suites, Release 204 tests in 21 suites; both app builds and strict signatures pass |
| Release isolation | Final Release string scan contains no Debug fixture, assessment classes, mutation, placement or session-diagnostic switches |
| Installed no-write validation | First run correctly rejected an absent approved target; temporary launch of that already-approved target allowed a fresh dry-run to pass without writer, assertion or persistence |
| State preservation | Running Blenny quit normally before installation; temporary target returned to its original stopped state; policy/backup bytes and 0600 permissions unchanged |
| History and privacy | All reachable objects and current candidate paths audited; no credentials, private paths, raw diagnostics, generated binaries or copied dependency trees found; the sole binary asset is the tracked application icon source |

Final Accessibility was granted and Open at Login reported `notFound`; neither
setting was changed. No new real assertion session was started during this
release audit. Earlier owner-approved baseline activations and normal Quit
cleanup are recorded above; fake-writer tests are not claimed as real failure
injection. Native-arrow takeover, missing Bartender discovery and ordering are
not accepted capabilities of this patch and retain their explicit later scopes.

At that audit, closure stopped pending final presentation acceptance. The owner
has now accepted keeping the fish and arrow as currently installed and requested
that all follow-ups remain part of 0.5.0, not a separate patch release. The owner
also explicitly authorized replacing the unpublished local `v0.5.0` tag after
final checks. This supersedes only the earlier version/tag and presentation gate;
it does not approve native-control takeover, discovery repair, ordering, Release
backend promotion, history rewriting or any push. Raw receipts remain ignored.

## Final 0.5.0 closure

The final version combines the initial management-loop implementation and every
direct-control follow-up in this document. The temporary patch-version proposal
is withdrawn; its former document is consolidated here without deleting the
historical experimental results. Existing commits remain genuine, including their
earlier version wording. Only the owner-approved unpublished local `v0.5.0` tag
is replaced after the final checks; no other tag or remote ref changes.

The owner confirmed the working dedicated arrow earlier and accepted the current
fish/arrow presentation for this version. Exact glyph parity and physical edge
placement are not claimed. Native-control integration and the reported missing
Bartender candidate remain 0.6.0 work; ordering investigation remains 0.7.0 work.

The final 0.5.0 build passed 206 Debug tests in 22 suites and 204 Release tests in
21 suites with Xcode 27.0, the macOS 27 SDK and Swift 6.4. Both arm64 application
builds declare minimum macOS 27.0 and the stable bundle identifier, pass strict
signature and plist checks, and the Release executable excludes Debug fixtures,
assessment factories, mutation and diagnostic switches.

The final Debug app was installed under the normal Blenny application name. Its
first no-write dry-run correctly rejected an absent approved target. Temporarily
starting that already-approved app allowed a new dry-run to pass, after which the
temporary app quit normally. No real assertion was created in this closure run.
The policy and scoped backup remain byte-identical with 0600 permissions;
persisted management intent is unchanged. Accessibility remains granted and Open
at Login reports `notFound` before and after, with neither setting changed.
Scoped processes match the pre-install snapshot and no Blenny process remains.
The replaced validation app remains recoverable in ignored local evidence.

The full release boundary is `v0.4.0` to the final commit, including the original
management loop, existing sponsor-attribution correction, direct-control fixes
and this forward-only version consolidation. The release audit covers all
reachable history and tags, not only the follow-up diff. Local evidence preserves
the previous tag object, exact state comparisons and build receipts. No menu-bar
pixels, ordering experiments, private paths or raw artifacts are added to Git.
