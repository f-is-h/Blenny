# Blenny 0.5.0 Technical Spike

## Reviewed Management Loop

Status: complete on 2026-08-30 for the exact Debug development boundary. Deterministic Debug and Release verification, installed dry-run, owner-approved real validation, exact restoration, and the release audit passed; the version is closed locally at annotated tag `v0.5.0`, with no push.

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
- Reviewed plan: an immutable, single-use `ReviewedPolicyPlan` owned by the Review
  presentation until consumed or invalidated.
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
backup changes, or observation changes invalidate the reviewed plan. Apply takes
only a current `ReviewedPolicyPlan`; it cannot reconstruct a different plan from
the latest UI state.

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
- appear in the exact diff and mutation warning shown before Apply.

Blenny is forced to `Visible` by validation and by plan construction. The Review
also displays the complete assertion configuration, including bundles that are
allowed to remain visible even when they are not mutation targets.

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

An unchanged reviewed plan is a no-op: no candidate, persistence write, or backup
rotation occurs.

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
5. Synchronize accepted policy, Draft, Review, status item, and UI.

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
- Review continues to show exact diff, impact, validation, recovery, assertion
  warning, baseline allowed set, ordinary reveal set, Hidden exclusion, backup,
  rollback, Stop, and restoration behavior.
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

The 0.6.0 roadmap will record only that ordering feasibility must be investigated
separately before implementation, must distinguish bundle policy, status-item
instance, and physical position, must prohibit synthetic input, and must not ship
a misleading Board-only ordering feature. Existing 0.6.0 lifecycle and display
hardening remains planned.
