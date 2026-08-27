# Blenny 0.0.4 Persistent Policy Prototype

> Engineering record for the bounded `0.0.4` prototype. This is not the `0.0.5` Policy Editing Core, the `0.1.0` product interface, a distributable build, or a supported public-API implementation.

Status: **Complete on macOS 27.0 build `26A5416b`, including deterministic verification, Release isolation, installed dry-runs, owner-authorized real-write validation, persistent disable, and complete restoration.**

Last updated: 2026-08-27

## Scope

Version `0.0.4` extends the validated `0.0.3` Debug-only policy session with:

- versioned persistence of bundle-level `Pinned`, `Revealable`, and `Hidden` intent;
- identity resolution by owning bundle identifier across Blenny relaunch and PID replacement;
- explicit reporting and fail-closed behavior for unknown or ambiguous menu-bar ownership;
- a no-assertion dry-run that emits the exact baseline and ordinary-reveal plans;
- an explicit **Stop Managing and Restore** action;
- one previous-policy backup containing only the scoped policy state needed to recover user intent.

A formal settings editor, Hidden-only recovery browser, shortcut, login launch, updater, helper, IPC service, distribution work, and continuous lifecycle reconciliation remain excluded.

## Starting state

The repository began from clean annotated tag `v0.0.3` at commit `2cc67a73e7f441cba6a2daad88e234920d9f595d` on `main`. The globally selected Xcode remained 26.6, while all milestone commands explicitly used Xcode 27.0 beta build `27A5237l`, Swift 6.4, and the macOS 27.0 SDK.

The read-only recovery audit found no Blenny process, no installed `/Applications/Blenny 0.0.3 Validation.app`, and no persisted `NSStatusItem Preferred Position Blenny0.0.3Validation` value. MenuBarAgent, Usage4Claude, and CleanShot X retained their existing processes. Because the validated assessment assertion is process-owned, absence of a Blenny process also means no prior assertion can remain active.

Before implementation, 62 Debug tests and 60 Release tests passed. Both app configurations built with Xcode 27.

## Persistent policy format

The canonical policy document has schema version `1` and stores only:

- `managementEnabled`;
- one owning bundle identifier per policy entry;
- the entry's `pinned`, `revealable`, or `hidden` value.

Bundle identifiers must be trimmed, contain at least two non-empty components, use only letters, numbers, periods, and hyphens, and be unique under case-insensitive comparison. The document must assign Blenny itself to `Pinned`. Unsupported schemas, malformed identifiers, duplicate identities, overlap, or a missing Pinned Blenny identity fail closed.

The Debug prototype stores the document under the current user's Application Support directory, outside the repository. Writes are atomic and the resulting file permission is `0600`.

Before replacing an existing policy document, the store atomically writes one `bundle-policies.previous.blenny-backup.json` file. That backup contains only the preceding policy document. It contains no PID, process name, application path, version, status-item image, AX tree, unrelated bundle inventory, system preference domain, assertion object, or signing data. The backup can be decoded and restored deterministically. The repository ignores `*.blenny-backup.json` and all `LocalData/` evidence.

No system preference backup is created for the assessment assertion because that assertion does not replace persistent MenuBarAgent preference values. Its complete restoration operation is explicit invalidation by the owning serial writer, with process-disconnect cleanup as the final tested safety boundary. Recording unrelated system preferences would increase privacy and recovery risk without improving restoration.

## Identity and ownership resolution

Persisted identity is the owning bundle identifier only. PID, executable path, app version, current coordinate, AX label, and status-item count are never persistence keys.

At each bounded launch, one five-second, non-polling Accessibility preflight observes top-level `AXMenuBarItem` ownership. The resolver:

- maps a stored bundle identifier to the current unique owner process;
- permits multiple status items from that one process because policy remains bundle-level;
- accepts a changed PID as an app relaunch or update-like replacement;
- reports a configured bundle that is absent or has no attributable menu extra;
- reports multiple current owner processes for one configured bundle as ambiguous;
- reports any observed menu-bar owner without a valid bundle identifier;
- refuses to construct or activate an assertion if any reportable ownership issue exists.

The bounded real-write prototype additionally requires the exact approved scope from `0.0.3`: installed Blenny is Pinned, `xyz.fi5h.Usage4Claude` is Revealable, and `pl.maketheweb.cleanshotx` is Hidden. A persistent file cannot broaden the authorized target set.

## Dry-run and mutation boundary

The Debug prototype defaults to dry-run. An absent policy file may be seeded only by the two exact approved target environment values. Later launches load the stored document without requiring those seed values, demonstrating Blenny-relaunch persistence.

Dry-run performs policy decoding, scope validation, bounded ownership resolution, entry selection, and exact baseline/reveal plan generation. It does not construct the private assertion factory or a serial writer and cannot activate an assertion.

Real mutation remains unavailable unless the separate Debug-only `BLENNY_ENABLE_0_0_4_REAL_WRITES=YES` switch is present. The owner must inspect the human-readable managed policy and explicitly authorize that launch first. The authorized baseline and reveal managed-policy SHA-256 fingerprints must also be supplied through two separate Debug-only values. Each fingerprint covers every managed bundle's assigned policy and effective allow/deny state, the presentation, and the system-item set. The complete running-bundle snapshot receives a separate audit fingerprint, but unrelated helper-process churn does not invalidate an otherwise identical managed-policy authorization. The app recomputes both fingerprints after ownership and entry preflight; any managed policy, effective managed state, system-item, or presentation change fails closed before the private factory or candidate is created.

## Stop Managing and Restore

The Debug status-item menu exposes **Stop Managing and Restore** after a valid enabled policy loads.

The action atomically persists `managementEnabled=false`, preserving the three policy entries and backing up the previously enabled document. It then asks the existing `RevealAssertionWriter` actor to invalidate pending and active assertions exactly once, stops AX observation and bounded timers, restores Blenny's process-scoped placement, and leaves an unrestricted baseline. If the process exits between persistence and explicit invalidation, process-disconnect cleanup removes the assertion. A disabled document is loaded but never applied on a later launch.

Normal Quit and the five-minute experiment bound restore the active assertion but intentionally leave `managementEnabled=true`, so a later explicitly launched prototype can demonstrate policy persistence. They do not create a background agent or automatic login behavior.

## Preserved safety properties

- All assessment assertion transitions still pass through one `RevealAssertionWriter` actor.
- A replacement must activate before the preceding assertion is invalidated.
- Failed reveal preserves the concealed baseline; failed conceal fully restores and stops the writer.
- The activation timeout remains one second, ordinary reveal timeout 30 seconds, and whole experiment timeout five minutes.
- No pointer movement, synthetic click, Command-drag, Screen Recording, injection, private entitlement, MenuBarAgent restart, continuous polling, reconciliation loop, or unbounded retry is introduced.
- The private macOS 27 runtime, real-write switch, approved real targets, and 0.0.4 validation UI remain Debug-only.

## Deterministic evidence

Current verification passes 78 Debug tests in 12 suites and 76 Release tests in 11 suites. The two exact private-runtime contract checks remain Debug-only. New coverage includes:

- deterministic policy encoding and strict schema validation;
- invalid and case-colliding bundle identifiers failing closed;
- atomic save/load across a simulated Blenny relaunch;
- persistent disable, scoped previous-policy backup, and backup restoration;
- `0600` policy-file permissions;
- backup content excluding PID, owner fields, and application paths;
- managed-app relaunch and update-like PID replacement preserving all three policies;
- multiple status items from one process remaining one bundle policy;
- missing configured bundles, ambiguous owner processes, and unidentified menu-bar owners producing explicit fail-closed reports;
- disabled management retaining intent without becoming applicable.
- deterministic exact-snapshot fingerprints and fingerprint changes for any plan change;
- stable managed-policy authorization across unrelated running-bundle churn;
- managed-policy authorization changes for any managed allow/deny, presentation, or system-item change.

The pre-existing deterministic writer, policy, native/fallback ownership, timeout, failure, and restoration coverage remains intact. Xcode 27 built both ad-hoc signed arm64 app bundles with version `0.0.4`, deployment target 27.0, and SDK 27.0.

The final Debug and Release executable SHA-256 values are `7651587c5eeffe78ce83e8bc0d3b372abb9a952fb4afa005d0aa585b62b6c55e` and `64f00e1734021ae0ddf013057ccfefdb55645a010a2a0307a0ef77933da4b1a4`. The Release executable links only public system frameworks. A string and linkage scan found none of the private MenuBarClientCore path, assessment assertion/configuration classes, activation selector, 0.0.4 real-write, approved-target, or plan-fingerprint environment keys, approved third-party target identifiers, Debug Persistent Policy UI marker, or Stop Managing menu title.

## Installed dry-run evidence

Status: **Passed without constructing an assertion factory or candidate.**

The final Debug app was copied to `/Applications/Blenny 0.0.4 Validation.app`, registered with LaunchServices, and passed strict deep signature verification. Its installed executable SHA-256 matched the tested Debug build: `7651587c5eeffe78ce83e8bc0d3b372abb9a952fb4afa005d0aa585b62b6c55e`.

The first installed launch used the two exact approved seed values and omitted the real-write switch. It wrote schema-version-1 policy state with permission `0600`, then resolved unique ownership for installed Blenny, Usage4Claude, and CleanShot X. Native overflow was present and observable. The initial exact dry-run plans were:

- Baseline: 136 allowed bundle identifiers; Blenny allowed, Usage4Claude excluded, CleanShot X excluded.
- Ordinary reveal: 137 allowed bundle identifiers; Blenny allowed, Usage4Claude allowed, CleanShot X excluded.
- Both plans: system item identifiers `0...8`.

The app then quit normally. A second launch omitted both seed values, loaded `managementEnabled=true` from the persistent store, resolved the same three identities to the current PIDs, emitted the same plans, and quit normally.

For update-like installed-app replacement evidence, the installed Blenny executable was replaced in place with newly tested binaries whose initial hash `d18a334db94fbbdbd5a47e2138602351a69db19e80f583f41675e94b633ef623` ultimately changed to the final hash above. The bundle identifier and Application Support policy location remained stable. No-seed launches of the replacements loaded the existing policy and retained Blenny's Pinned identity.

One replacement launch initially found a prior LaunchServices query had unintentionally left a second Blenny instance running. The resolver reported `com.example.BlennyProbe` as ambiguous with two owner PIDs and generated no plan or write. After both dry-run processes were removed, clean single-instance launches again resolved each owner uniquely. This is positive installed evidence for explicit ambiguity reporting and fail-closed behavior rather than PID guessing.

Two owner-authorized real launches before the final authorization design was completed were rejected before backend construction because unrelated running helpers changed the complete snapshot. The first changed from 137/138 allowed bundles to 135/136; the second changed back to a different 137/138 set. Both launches logged `assertion_factory_created=false assertion_candidate_created=false`, restored Blenny's process-scoped placement, and activated no assertion. This demonstrated that exact whole-snapshot authorization was safe but operationally unsuitable: the requested three-bundle policy had not changed, yet unrelated helper churn repeatedly invalidated owner confirmation.

The authorization boundary was therefore narrowed to the owner-visible managed policy while preserving the exact whole-snapshot fingerprint as audit evidence. Two final installed dry-runs resolved unique ownership for the same three bundles and produced identical results:

- Baseline managed policy: Blenny allowed, Usage4Claude denied, CleanShot X denied; system item identifiers `0...8`; authorization fingerprint `4897816b591efc51227d0782635e0ee8126a4a60cced3d41a7abbe7c0c6f15e6`.
- Ordinary reveal managed policy: Blenny allowed, Usage4Claude allowed, CleanShot X denied; system item identifiers `0...8`; authorization fingerprint `942f1420016ae29b5dd33a94dba16f3f4ed7cd6220cc1296d63e2fb94b42c24a`.
- The complete audit snapshots contained 138/139 allowed bundles and had exact fingerprints `6ffc39549d4cbdc030f66f6a91f84410518f990bfb72ee4ec0ffa3d2fa8a1c22` and `fa56005f0a423e42992229b70e321a47d1ba3466c5ce504b6bf45ab41c296a26` during these two runs. These values are evidence, not owner authorization inputs.

Deterministic tests prove that unrelated running-bundle additions or removals change the exact audit snapshot but not these two authorization fingerprints. Tests also prove that changing any managed effective state, presentation, or system-item set changes authorization and fails closed.

Every final dry-run logged `assertion_factory_created=false assertion_candidate_created=false`. Normal Quit completed the local restore path; no Blenny process or process-scoped placement key remained. No third-party or system menu-bar policy was mutated during dry-run.

## Bounded real validation

Status: **Complete with owner-observed visibility and complete restoration.**

The owner explicitly authorized this human-readable policy:

- Pinned: installed Blenny, `com.example.BlennyProbe`;
- Revealable: Usage4Claude, `xyz.fi5h.Usage4Claude`;
- Hidden: CleanShot X, `pl.maketheweb.cleanshotx`;
- system item identifiers: the already validated bounded set `0...8`;
- one 30-second reveal-session limit and one five-minute whole-experiment limit.

The first final real launch resolved unique ownership for Blenny PID 20024, Usage4Claude PID 21837, and CleanShot X PID 3438. Unrelated running-bundle churn changed the exact snapshot to 133/134 allowed bundles, while both approved managed-policy fingerprints remained unchanged. The private factory was constructed only after that match, and the baseline assertion activated successfully. The owner observed Blenny visible with Usage4Claude and CleanShot X concealed. Fallback reveal activated its replacement in 23.621 ms; the owner observed Usage4Claude appear while CleanShot X remained concealed. Conceal activated the replacement baseline in 29.228 ms; the owner observed Usage4Claude disappear again.

Usage4Claude then quit normally and relaunched from PID 21837 to PID 21279 without changing its bundle identifier. It remained concealed at baseline and appeared in a subsequent reveal while CleanShot X remained concealed, which the owner confirmed. That reveal activated in 21.598 ms. Its 30-second session bound returned to baseline in 3.513 ms without user input. Blenny then quit normally at 273.95 seconds; the assertion and process-scoped placement were restored while `managementEnabled=true` and no backup remained, as intended for relaunch persistence.

A no-seed Blenny relaunch loaded the same enabled policy at PID 21654, resolved the new Usage4Claude PID, and activated the same managed policy despite a different 136/137-bundle exact snapshot. Its whole-experiment bound later restored automatically. A separate final launch completed **Stop Managing and Restore** 21.70 seconds after startup. The action persisted `managementEnabled=false`, created one previous-policy backup, invalidated the active assertion, and restored Blenny's placement before logging completion.

The resulting policy file is 359 bytes and the only backup is 440 bytes; both are `0600`. The backup contains only schema version 1 and the previous enabled three-bundle policy. It contains no PID, path, owner observation, diagnostics, or unrelated bundle inventory. MenuBarAgent remained PID 1590, Usage4Claude remained PID 21279, CleanShot X remained PID 3438, and the Blenny placement key was absent. A final launch without seed or real-write values loaded `managementEnabled=false`, immediately preserved unrestricted state, and constructed no private factory or assertion candidate. Blenny then quit normally with no residual process. The owner confirmed that Usage4Claude and CleanShot X were both visible again after Stop Managing.

No third-party application binary was updated or modified during validation. No MenuBarAgent restart, synthetic input, Screen Recording, polling, or private Release code was used.

## Closeout boundary

All required implementation, deterministic, installed dry-run, real-write, relaunch, Stop Managing, backup, and restoration evidence is complete. An annotated `v0.0.4` tag may be created only after the final clean release audit. Creating the local tag is not Push authorization; publishing the exact branch and tag requires a separate owner confirmation after the pre-push receipt is presented.
