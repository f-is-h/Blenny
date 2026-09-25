# Blenny 0.11.0 release record

Status: complete local experimental milestone, 2026-09-25. The owner accepted
Build 15 dragging and Apply and authorized local closure. Public-release
preparation moves to 0.12.0; no push or publication is included. Existing commits
and tags are preserved.

## Accepted scope

- Repair Device Control onboarding using Apple's public prompt option and a
  process-scoped request state. Keep exact layout-file selection/bookmark access
  scoped to Debug or the explicitly opted-in optimized ordering trial.
- Restore eligible application ownership evidence with an exact bundle-key anchor
  and fresh public code-signing identity. Refuse unanchored executable-only keys,
  collisions, ambiguous owners and identity drift.
- Stop the redundant native-overflow publication that caused the observed
  AttributeGraph feedback loop. Prepare drag payloads outside view evaluation
  and use one typed drag-source modifier for application and system artwork.
- Canonically encode reviewed sets and integer-keyed dictionaries so unchanged
  preview content cannot spuriously invalidate Replace Undo & Apply.
- Limit pure within-area sorting to owners whose relative order changes;
  retain complete partition validation for cross-area changes.
- Require API/file agreement in both directions. After a disagreement, wait once
  for the exact file's event, bounded by 15 seconds, then read once more. The
  event is only a wake-up, never proof of success. No polling, reconciliation or
  additional system write is introduced by settlement.
- Preserve stopped management through Undo and same-binary reopen; refresh system
  host identity for reviewed cross-build recovery. Persist recovery intent before
  compensation; permit at most one explicit inverse retry after full zero-change
  proof, with a durable retry count.
- Identify local packages by marketing version and build number. Keep ordinary
  Release ordering exclusions and the existing unsupported-item boundaries.

## Evidence and acceptance

| Area | Verified evidence | Limit |
| --- | --- | --- |
| Native drag and Apply | Owner confirms Build 15 dragging and Apply are normal after application/system source parity repair | Owner acceptance is not an independently witnessed test of every individual icon |
| CPU feedback loop | Same-binary changed/always/changed publication contrast produced idle/high-CPU/idle behavior; equality guard is retained | An idle sample alone is not long-duration performance coverage |
| Preview stability | Canonical serialization tests cover set ordering, integer-keyed dictionaries and legacy decoding | Real external policy, generation or target drift still rejects review |
| Ordering scope and owner proof | Deterministic inversion-scope, identity, collision, Apply/Undo and drift-refusal tests; owner-used local workflow | No arbitrary unknown-owner or per-status-item support |
| Delayed preference commit | Build 13 reproduced API-target/file-old from a clean baseline; the file changed after the old five-second check | Internal cfprefsd scheduling and a universal delay bound are not established |
| Settlement and inverse | Build 14 completed five Applies and three Undos in one process, six preference writes, five actual event waits and zero recovery actions or extra write retries | Board movement actions exercised this pipeline; native drag acceptance is separately supplied by the owner on Build 15 |
| Permission setup | Public prompt created the missing Device Control row; exact-file read/write/inverse and same-binary reopen passed | Broader revoke/regrant and stable Developer ID/update continuity remain open |
| Clock | Owner repeats Resume-fails/Stop-works on formal build; fresh read-only contract and both ControlCenter slices confirm the existing event gate | No compatible fix; earlier trackpad alternative was not freshly retested on every build |

The five observed settlement waits were 2.948, 8.176, 5.777, 7.924 and 1.609
seconds. Each ended on a file event and its single subsequent complete read
established agreement. Three exceeded the old five-second delay. All successful
Apply receipts were verified `applied`; all saved inverses were verified
`preferencesRestored`. A fresh LaunchServices process independently confirmed
exact equality with the complete pre-test table after the controlled run.
Physical menu-bar coordinates remain separately unverified when unavailable.

## Restoration and retained user state

Controlled validation ended in exact restoration; no validation/probe process
remains active. A distinct migrated transaction had later drifted and could not
be honestly described as restored. The owner explicitly authorized keeping the
current arrangement and abandoning that old Undo baseline. Its receipt and full
snapshot were privately archived without changing system preferences. Recovery
rules were not relaxed to overwrite the later arrangement.

After the controlled tests, the owner made and accepted further changes. The
closing read-only fresh-process capture confirms file/API/file agreement. Its
clean applied Undo receipt has `configurationVerified == true`, no pending
values, and all 18 committed keys match the live table. The last-restored receipt
is verified `preferencesRestored`. This applied record is retained user Undo,
not pending recovery; closure does not discard or undo the accepted arrangement.
The bookmark reader reported a stale saved bookmark while the authorized direct
file/API reads succeeded. Bookmark renewal and distribution-identity continuity
remain explicit 0.12.0 validation, not a claim of universal permission readiness.
The accepted installed app remains running and was not replaced during closure.

## Automated validation and package identity

- Xcode 27.0 (`27A266a`), macOS SDK 27.0, arm64, deployment target macOS 27.0.
- Debug: **620 tests in 57 suites pass**.
- Ordinary Release: **324 tests in 34 suites pass**.
- Debug, ordinary Release and optimized ordering-enabled app builds pass, each
  packaged as `0.11.0 (Build 15)` for reproducible closeout checks.
- Debug and optimized trial pass the packaged actual-interface lifecycle fixture
  check; it creates no live management writer or system preference mutation.
- All three packages pass strict ad-hoc signature checks. Debug/trial carry only
  the user-selected read/write entitlement; ordinary Release has no entitlement
  payload or ordering App Data purpose string. These are integrity checks, not
  Developer ID trust, notarization or default-Gatekeeper acceptance.
- Binary checks find the ordering writer, table key, read-only preference entry
  point and launch-time drag/preference diagnostics only in Debug/trial, absent
  from ordinary Release. Already promoted visibility behavior is unchanged.

The accepted installed Debug Build 15 executable has SHA-256
`ef31b9cebc70b0000daa78d12fbb7b1be1f251c5890e2cbfd1d386cc4a1edfa2`.
Closeout packages are separate builds of that source baseline and are not
byte-identical replacements; they were not installed or granted new permissions.
All raw traces, state snapshots, build logs and binaries remain ignored locally.

## Privacy, history and repository audit

The pre-closure reachable history contains 53 commits and 690 unique blobs.
History and candidate inspection found no forbidden raw-evidence paths, Mach-O
binaries, oversized blobs, private keys, detected credentials or personal absolute
paths. Content email review found only the approved public author address and
icon-filename false positives. Commit metadata uses the approved public identity;
messages follow repository conventions and contain no AI attribution.
The original first commit `4a4dbe32d9382efe04769d4e1566d8f5ab695bcf`, dated
2026-08-21, is preserved. Third-party references are research/documentation;
no copied Ice/Thaw implementation, linked binary or synthetic-input/injection
path was introduced. Unsupported ordering remains isolated and build-gated,
with all mutations under the serial writer and durable recovery contract.

The release skill audit runs before preparation and on the clean committed
candidate before creating the annotated local `v0.11.0` tag. Remote `main` was
verified at `3962231757bb2a3e2f0a07706b3a16acf7db5cc2` (0.10.0), with no remote
0.11.0 tag. Closure uses forward commits only. License drafts remain excluded;
no license selection, distribution signing, remote update or visibility change
is part of this milestone.

## 0.12.0 boundary

Complete the public-release gates in [the roadmap](ROADMAP.md): ordinary Release
ordering review; final onboarding, keyboard and VoiceOver acceptance; stable
signing and grant continuity; restart/update/interrupted recovery; installation
and uninstall; broader hardware/display compatibility; emergency disable;
license and notices; notarization; privacy/security and publication audit.

The Clock limitation remains disclosed with no automatic Stop/Resume workaround.
Siri, Time Machine and Control Center sorting remains deferred. Neither this
milestone nor the major-version runtime gate promises every macOS 27 build,
physical screen coordinate or adjacency to the native overflow arrow.
