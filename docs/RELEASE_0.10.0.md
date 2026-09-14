# Blenny 0.10.0 release record

Status: complete local experimental milestone, 2026-09-15. No publication or push
is included. The prior v0.9.0 tag and all genuine history remain unchanged.

## Accepted scope

- Compact native Organize, Settings and Support; stable window height without
  vertical scrolling, clearer drag affordance, concise copy and optional item controls.
- Board-as-preview, one Apply, quiet cancelled/no-op drops and shared draft gates.
- Supported third-party/Apple ordering and three-state visibility, with explicit
  unsupported ordering status for Siri, Time Machine and Control Center.
- Separate native fish and double-arrow controls, explicit persistent boundary
  placement, independent control Undo and reviewed stale-placement recovery.
- Single-level Undo Changes for the last successful Apply, including visibility
  and ordering. One bounded automatic read-only refresh follows a failed post-Undo
  interface read. No repeat Apply, input synthesis or polling is introduced.
- Successful Undo says Changes undone. Details disclose that saved settings were
  verified but on-screen positions were not independently verified when unavailable.
  Actual inverse and control-placement failures remain actionable errors.

## Evidence and acceptance

| Area | Evidence | Limit |
| --- | --- | --- |
| Compact UI, drag/drop and tabs | Repeated owner feedback and accepted revisions | VoiceOver/keyboard and first-use matrix remains follow-up |
| Native control click and boundary | Owner-operated click checks, boundary exports, narrow arrow move and exact inverse | No absolute coordinate or native macOS-arrow guarantee |
| Persistent fish/arrow placement | Owner reports correct boundary; reviewed stale-record recovery succeeds | Future macOS position drift remains possible and is not silently overwritten |
| Unified Undo | Real-store deterministic tests and owner verification of the final candidate | Old receipts retain their previous scope until a new Apply |
| Post-Undo automatic refresh | Owner confirms the candidate operates normally | Read failure remains possible; retry is bounded |
| Siri visibility | Owner reports successful move/reveal; inverse tested in unified tests and final acceptance | Siri ordering is not offered |
| Restoration | No active ordinary ordering receipt; latest restored receipt is schema 4, preferencesRestored, configurationVerified | Accepted persistent controls deliberately remain saved |

The attended arrow-only trial has a completed restored receipt and earlier exact
configuration comparison. The active control record is clean applied schema 2
with persistsAfterQuit=true; it is accepted configuration, not an unfinished
experiment. No validation/probe process is active. The owner's normal installed
Blenny remains running and was not stopped, replaced or mutated during this audit.
Raw receipts, screenshots, build outputs and diagnostics remain under ignored local
storage and are not reproduced here.

## Automated validation

- Xcode 27.0 (27A5237l), macOS SDK 27.0, arm64, deployment target macOS 27.0.
- Debug: 594 tests in 55 suites pass.
- Ordinary Release: 322 tests in 34 suites pass.
- Debug, ordinary Release and optimized ordering-enabled app builds pass.
- Executable inspection confirms ordering-table and control-writer surfaces in
  Debug/optimized trial and their absence from ordinary Release.
- The packaged optimized candidate passes its fixture-only interface check,
  strict ad-hoc signature validation and extracted-archive executable comparison.
- No normal application launch or new real system mutation was used for these checks.

## Privacy, history and repository audit

The full pre-closure reachable history comprises 52 commits and 608 unique blob
objects. Review and scanning found no forbidden raw-evidence paths, tracked Mach-O
binaries, files over 5 MiB, private keys, GitHub tokens or personal absolute paths.
Author/committer metadata is the approved public identity. The original first
commit is preserved. Research sources and release scripts are unchanged by this
version; no third-party implementation or new injection/synthetic-input path is
introduced. New mutation code is isolated in the existing macOS 27 backend and
runs through the serial coordinator with durable intent, fresh identity and
bounded recovery. The abandoned grouped-control experiment remains separately
compile-gated and is not enabled in the milestone package.

Root LICENSE and NOTICE drafts remain locally excluded and absent from packages.
No history rewriting, signing-identity change, notarization, publication or push
is authorized by this closure. The remote main remains the known v0.7.0 ancestor;
remote existing tags match local objects and v0.10.0 is absent before closure.
The release skill audit is run before preparation and again on the clean commit.

## 0.11.0 boundary

Next work starts with permission/onboarding flow, final UI polish and accessibility
acceptance, then licensing and distribution readiness. Explicitly review promotion
of ordering into ordinary Release; this milestone still uses Debug or the opted-in
optimized trial. Validate restart/update, interrupted recovery, installation and
uninstall before public distribution. Test unknown-build rejection and document
supported configurations. This milestone is not universal compatibility proof.

The Clock/Notification Center limitation remains accepted: the trackpad right-edge
swipe is available; no automatic Stop/Resume workaround is introduced. Siri, Time
Machine and Control Center ordering remains unproven. No screen-coordinate or
native-arrow adjacency promise is made. Unified Undo fails closed if accepted
policy/runtime identity changes; it never silently resumes a stopped coordinator.
