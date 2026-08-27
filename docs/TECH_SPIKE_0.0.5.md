# Blenny 0.0.5 Policy Editing Core

> Engineering record for the UI-independent `0.0.5` core. This is not the `0.1.0` settings interface, a distributable build, or a supported public-API implementation.

Status: **Complete on macOS 27.0 build `26A5416b`; tag and push remain intentionally deferred.**

Last updated: 2026-08-27

## Scope

Version `0.0.5` adds a UI-independent editing boundary around the persistent bundle policy established in `0.0.4`:

- immutable draft values for bundle-level Pinned, Revealable, and Hidden assignments;
- deterministic accepted-to-proposed policy diffs;
- a stable human-readable dry-run impact report generated before persistence, writer creation, or assertion construction;
- fail-closed validation against a read-only, bounded menu-bar ownership candidate inventory;
- a deterministic activation-then-persistence transaction with bounded rollback;
- core paths for Resume Managing, Restore Previous Policy, and draft discard;
- accepted-policy identity across Blenny relaunch and managed-app PID replacement.

A formal settings window, three-column editor, drag and drop, shortcuts, login launch, updater, helper, IPC, profiles, themes, animations, automatic rules, polling, and reconciliation remain excluded. The first product interface remains `0.1.0`.

## Starting state

The repository began at clean annotated tag `v0.0.4`, commit `750c615fb387ca30b3bc47ef0f71040c2d882668`, on `main`. The remote `main` branch and published tags remained at `v0.0.3`; `v0.0.4` was local only.

The machine-wide developer selection remained Xcode 26.6. Every milestone command explicitly selects Xcode 27.0 build `27A5237l` and the macOS 27.0 SDK. The host runs macOS 27.0 build `26A5416b` on arm64.

The `0.0.4` recovery audit found:

- no Blenny process and therefore no process-owned assessment assertion;
- no `Blenny0.0.4Validation` placement value in the Blenny preference domain;
- the accepted policy persisted with `managementEnabled=false`;
- exactly one previous-policy backup containing the preceding enabled three-bundle policy;
- both policy files limited to mode `0600`;
- Usage4Claude, CleanShot X, and MenuBarAgent still running without a MenuBarAgent restart.

The clean `0.0.4` baseline passed 78 Debug tests in 12 suites and 76 Release tests in 11 suites. Both app configurations built successfully with Xcode 27 before implementation began.

## Draft and accepted-policy separation

`BundlePolicyDraft` is a value containing three arrays of owning bundle identifiers. It deliberately retains duplicate, conflicting, and malformed raw input so validation can report every issue rather than normalizing an unsafe edit into apparent validity.

An accepted `PersistentBundlePolicyDocument` remains a separate immutable value. Creating, assigning within, or discarding a draft cannot mutate the accepted document. Draft discard reconstructs a new draft from the currently accepted document and performs no persistence or writer access.

Policy identity remains the owning bundle identifier. PID, executable path, coordinate, image, Accessibility label, status-item title, and individual status-item identity are not policy keys. Multiple observed status items from one uniquely owning process remain one candidate and one bundle-level policy.

## Candidate inventory and fail-closed validation

The candidate list is constructed only from the existing bounded, read-only observation of current top-level `AXMenuBarItem` ownership. It does not accept an application-directory scan or arbitrary running-process inventory as a policy candidate source.

Validation reports and rejects:

- malformed, whitespace-bearing, or structurally invalid bundle identifiers;
- exact duplicates and case-insensitive collisions;
- one bundle assigned to multiple policy groups;
- unapproved or unknown draft bundles;
- approved bundles omitted from the draft;
- approved bundles with no current attributable menu-bar owner;
- menu-bar owners without a bundle identifier;
- invalid or case-conflicting observed identifiers;
- one bundle identifier attributed to multiple current processes;
- any draft that does not keep Blenny Pinned;
- any draft whose set of bundles differs from the exact approved validation scope.

The bounded Debug validation scope remains exactly installed Blenny, `xyz.fi5h.Usage4Claude`, and `pl.maketheweb.cleanshotx`. Policy groups may be edited, but the set of real targets cannot be broadened by a draft, environment value, persistent file, or changed PID.

## Deterministic diff and impact report

The diff is ordered first by the management state transition and then by canonical bundle identifier. It reports:

- management disabled/enabled changes;
- additions;
- removals;
- moves between Pinned, Revealable, and Hidden;
- a stable no-op result.

Every preview renders:

- the old accepted policy;
- the proposed policy or invalid raw draft;
- the complete deterministic diff;
- per-approved-bundle baseline allow/deny impact;
- per-approved-bundle ordinary-reveal allow/deny impact;
- exact system-item set and managed-policy fingerprints;
- the approved bundle scope;
- every validation issue;
- the complete rollback and previous-policy recovery sequence.

The report text has a SHA-256 fingerprint. It deliberately binds authorization to the approved managed policy, effective allow/deny state, presentation, and system-item set, while excluding unrelated running-bundle churn. The complete plan retains a separate exact-snapshot fingerprint for audit evidence. Report generation receives no writer provider and cannot create the private factory, a candidate assertion, or a `RevealAssertionWriter`.

## Persist/apply transaction

The prepared transaction binds the exact old document, proposed document, baseline and reveal plans, report, and persistence mode. Commit reloads the accepted document first and rejects a stale preview before requesting a writer.

For an enabled proposed policy:

1. Obtain the single session writer only after validation and explicit authorization.
2. Activate the proposed baseline through `RevealAssertionWriter`.
3. Verify the writer still owns that exact plan; a process disconnect before this check fails without persistence.
4. Atomically persist the accepted document, writing one scoped `0600` previous-policy backup first.
5. If persistence fails and the old policy was enabled, activate the exact old baseline before invalidating the proposed assertion.
6. If old-baseline rollback fails, invalidate every owned assertion and remain unrestricted while the old persisted document remains intact.
7. If the old policy was disabled, any activation or persistence failure invalidates the candidate and remains unrestricted.

Changing an enabled baseline to a different enabled baseline now compares the complete plan, not only the `baseline` presentation enum. This preserves replacement-before-invalidation for edits that remain in the same presentation state.

A disabled-to-disabled accepted edit persists without requesting a writer. For an enabled-to-disabled transition, the transaction first acquires the current writer, persists disabled intent, and then invalidates every owned assertion; persistence failure leaves the previous policy and writer unchanged, while process-disconnect cleanup remains the final restoration boundary after persistence. Resume Managing produces an explicit management-state diff and follows the enabled transaction. Restore Previous Policy loads and validates the one backup, activates it when enabled, and writes it directly without rotating the backup. Repeating a completed restore is therefore a deterministic no-op. Malformed or unsupported policy and backup documents fail before writer creation.

## Lifecycle and restoration

- Blenny remains Pinned in every valid baseline and reveal plan.
- Hidden bundles remain denied during ordinary reveal.
- A failed reveal preserves the old concealed baseline.
- A failed conceal invalidates all owned assertions and stops the writer.
- Replacement activates before the prior assertion invalidates, including same-presentation policy edits.
- Connection invalidation and normal exit invalidate pending and active assertions.
- Bundle identity survives Blenny relaunch, managed-app relaunch, PID replacement, and update-like executable replacement.
- No mutation retries, polling, or automatic reconciliation were added.

The persistent store continues to keep only `bundle-policies.json` and one `bundle-policies.previous.blenny-backup.json` file under the user's Application Support directory. Both are `0600`. The backup contains only the previous schema-versioned policy document and contains no PID, path, owner observation, application version, status-item content, unrelated inventory, assertion object, or signing data.

## Debug-only installed validation boundary

The installed Debug app accepts one explicit validation action for preview or commit:

- edit approved roles and Resume Managing;
- Resume Managing without role changes;
- Restore Previous Policy.

Preview logs the complete report and managed-policy fingerprints, then exits through the normal restore path with `assertion_factory_created=false` and `assertion_candidate_created=false`. Commit additionally requires the separate real-write switch, installed-and-registered Blenny fallback, exact report fingerprint, exact baseline managed-policy fingerprint, and exact reveal managed-policy fingerprint.

These environment keys, approved third-party identifiers, validation controller, status UI, unsupported factory, and private runtime remain inside `#if DEBUG`. Release must contain none of them.

## Installed dry-run evidence

Status: **Passed twice without persistence, writer creation, factory creation, or assertion construction.**

The tested Debug app was copied to `/Applications/Blenny 0.0.5 Validation.app`, registered with LaunchServices, and passed strict deep signature verification. Its installed executable SHA-256 matched the tested Debug build: `4e78292bfca28c045a5445ac641addd49e63b53169ae458a0db36a53d1f86166`.

Both installed launches loaded the existing disabled `0.0.4` policy and used the exact `preview-edit-and-resume` action with no real-write switch. The proposed bounded edit is:

- keep installed Blenny Pinned;
- move CleanShot X from Hidden to Revealable;
- move Usage4Claude from Revealable to Hidden;
- change management from disabled to enabled.

The two previews produced identical report and managed-policy fingerprints:

- report: `e02bc4e153f261f9c64a768f7b9ee1f9de0acc839b1c1f6c8bd9229f1c8884e7`;
- baseline managed policy: `be03b2e78d58dc6bd5f7f4fabc95676472cae4478f0d573928f1d1d24ee15c8a`;
- ordinary-reveal managed policy: `46ed0e58ea6ac702443b73625f7d8f5eecf6767365364150b68970e319848a52`;
- baseline exact audit snapshot: `73f53e04fd7a06b5100e0c04959ddb549136609c2d597aff1ad5df25432bdf91`;
- ordinary-reveal exact audit snapshot: `a2ec8519c48113d716bf539e258b3ee027a8e54ab60adeca42f4e2b988c548b6`.

The proposed baseline allows Blenny and denies both third-party targets. Ordinary reveal allows Blenny and CleanShot X while continuing to deny Hidden Usage4Claude. Both plans retain system item identifiers `0...8`.

Each launch logged `assertion_factory_created=false assertion_candidate_created=false` before completing the normal local restore path. After both previews:

- no Blenny process remained;
- the accepted policy remained `managementEnabled=false` with SHA-256 `0618f1078de2655c5d4263c030459e7a1e0a320237708018957df83f8b74a004`;
- the one previous-policy backup remained unchanged with SHA-256 `dfd204dc05ee3ca85f4c72655d6d626f809e74e605a6bf8bce80d6c1b5c6be22`;
- both files remained `0600` with their original modification timestamps;
- the `Blenny0.0.5Validation` placement key was absent;
- MenuBarAgent remained PID 1590, Usage4Claude remained PID 21279, and CleanShot X remained PID 3438.

No private factory, assertion candidate, system mutation, policy persistence, backup restoration, MenuBarAgent restart, or third-party process restart occurred.

## Deterministic evidence

Current verification passes 102 Debug tests in 14 suites and 100 Release tests in 13 suites. New coverage includes:

- draft and accepted-policy immutable separation;
- deterministic no-op, add, remove, move, and Resume Managing diffs;
- stable report text and fingerprint across input ordering and PID replacement;
- proof that dry-run and draft discard create no writer, factory, assertion, or persistence;
- invalid, duplicate, case-conflicting, overlapping, unknown, missing, unapproved, unattributed, and ambiguous ownership failure reports;
- Blenny Pinned and Hidden ordinary-reveal exclusion invariants;
- stale accepted policy, store load, writer creation, activation, persistence, rollback, and process-disconnect failures;
- previous safe baseline rollback and unrestricted fail-safe outcomes;
- replacement-before-invalidation for two different baseline plans;
- normal exit, connection invalidation, conceal failure, and activation timeout;
- one scoped `0600` backup, repeated restore no-op, and malformed policy/backup rejection;
- Blenny and managed-app relaunch or PID replacement preserving bundle identity.

Xcode 27 built both ad-hoc signed arm64 app bundles with version `0.0.5`, deployment target 27.0, and SDK 27.0. The final Debug and Release executable SHA-256 values are `be0febecfa8a2cc3e8715042ed437eabb23997de454be0a9485bbe2065e7674a` and `b46a1f78c512b6d12434a409f2ecb4e363bce2d26a827a6883075fcfb9db1f64`.

The Release executable links only public system frameworks. Its string scan found none of the private MenuBarClientCore path, assessment assertion/configuration classes, activation selector, 0.0.5 Debug validation or real-write environment keys, approved third-party identifiers, Debug validation marker, or Stop Managing menu title. The UI-independent report title remains in `BlennyCore` by design and does not expose the private backend or a write entry point.

## Bounded real-validation evidence

Status: **Passed with explicit owner authorization and complete final restoration.**

The owner reviewed the exact old policy, proposed policy, deterministic diff, baseline and ordinary-reveal impact, approved targets, report and managed-policy fingerprints, and full rollback and previous-policy recovery plan before authorizing real validation. Only installed Blenny, Usage4Claude, and CleanShot X participated.

The edit-and-resume transaction used report fingerprint `e02bc4e153f261f9c64a768f7b9ee1f9de0acc839b1c1f6c8bd9229f1c8884e7`, baseline managed-policy fingerprint `be03b2e78d58dc6bd5f7f4fabc95676472cae4478f0d573928f1d1d24ee15c8a`, and ordinary-reveal fingerprint `46ed0e58ea6ac702443b73625f7d8f5eecf6767365364150b68970e319848a52`. The writer and private factory were created only after those values matched. The proposed baseline activated before persistence, the accepted policy became enabled with CleanShot X Revealable and Usage4Claude Hidden, and the single backup became the pre-edit disabled policy. A first unattended session reached the five-minute bound and logged complete restoration without a reveal event.

The installed Resume Managing dry-run was a deterministic `NO-OP`, produced report fingerprint `53e4767487a6466daaf7049afb133d14c8993d234e1f4dd234d6e1023df9c01a`, and created no writer, factory, or assertion. The first real resume attempt encountered the bounded ownership-scan timeout and failed before writer creation or persistence. After confirming one process per approved target and unchanged policy and backup hashes, the one bounded retry passed.

The owner then observed the complete fallback transition:

- baseline: Blenny visible; CleanShot X and Usage4Claude concealed;
- reveal: CleanShot X visible while Hidden Usage4Claude remained concealed;
- conceal: both third-party targets concealed again;
- measured writer transitions: 0.0274 seconds to reveal and 0.0303 seconds to conceal.

Usage4Claude was normally replaced from PID 21279 to PID 48268 and CleanShot X from PID 3438 to PID 48270. Blenny then exited normally with `restored on exit` and relaunched. The accepted bundle policy and report fingerprints remained unchanged, the new ownership was resolved without PID persistence, and the same baseline activated successfully. No polling or reconciliation loop was introduced.

Before the final recovery write, review found that the Debug validation controller would have started a bounded session after committing a disabled document even though the core transaction had already restored the writer. The installed recovery build was corrected to stop immediately when a disabled policy commits. All 102 Debug tests passed again, the app was rebuilt and reinstalled, and the Restore Previous Policy dry-run reproduced the approved report fingerprint `b0a328e10de2dacbdf43aa83c3a07d261050d816955bc8456c4c6cf7ebc856f9` without creating a writer, factory, or assertion candidate.

The authorized restore then logged `policy_transaction_committed=true` followed immediately by `disabled policy committed; fully restored`; it did not enter a reveal session. Final checks established:

- no Blenny process or Blenny placement key remained;
- the accepted policy is the original disabled policy with SHA-256 `0618f1078de2655c5d4263c030459e7a1e0a320237708018957df83f8b74a004`;
- exactly one scoped previous-policy backup remains, is semantically the same disabled policy, and has SHA-256 `938ad8a5611a0c9bb0459a77f61528ecc587457f96b160db4044bd41874c9599`;
- both policy files remain mode `0600`;
- a repeated Restore Previous Policy preview reports `NO-OP` with fingerprint `8d3ae1af6fbc2c556c9058dccc9605ff7219c0ba67ebef91128b95614291c96c` and creates no writer, factory, assertion, persistence, or system write;
- Usage4Claude and CleanShot X remain normally running under their replacement PIDs, and MenuBarAgent was never restarted.

## Closeout boundary

Implementation, installed dry-run, owner-authorized bounded real validation, final restoration, and Xcode 27 Debug/Release verification are complete. `$blenny-release` provides the history, privacy, version-alignment, and clean-tree closeout audit. It must not create `v0.0.5` without a later evidence confirmation and must not push any ref.
