# Blenny 0.13.0 local milestone audit

Status: **complete local experimental milestone**, 2026-09-29. The owner
authorized local closure and chose **1.0.0 as the next version**, with final
checks in a separate session. This does not authorize publication, a push,
ordinary Release ordering promotion, or a public distribution package.

## Scope and evidence

| Area | Verified or observed | Limit |
| --- | --- | --- |
| Daily context menu | Open Blenny; state-aware expand/collapse and Resume/Stop; Check for Updates; GitHub Sponsors; Buy Me a Coffee; Website; Debug submenu in Debug only; Quit. Actual AppKit fixtures cover state, access, draft, busy, updater, image, appearance and submenu gates. | Physical right-click placement, highlighted images, VoiceOver and draft-confirmation interaction remain unverified. Native hover selection remains; item tooltips were removed. |
| Support and artwork | Both support surfaces use `https://ko-fi.com/blenny` under Buy Me a Coffee. The owner approved the balanced rock/water application artwork. Menu bar silhouette A uses the established optical-size correction; Open Blenny reuses it. Offline rasters and the installed Board artwork were inspected. | External destination delivery, payments, Finder/Dock pixels and wider display acceptance were not tested. |
| Settings | The added Updates section made the old root require 487 points in a 420-point window. Revised spacing preserves the original window and heading alignment. A real SwiftUI/AppKit matrix covers 80 width, appearance, permission, updater and startup-state combinations, requiring 393–403 points. | Offscreen content inspection is not installed native-window visual acceptance. No login-item, permission or update-network action was invoked. |
| Management transition | A clean Board rebuilds after policy-scope changes instead of reporting a failed management transition. Dirty drafts retain their fail-closed guard. The packaged lifecycle fixture covers this behavior and retained recovery capability. | A new attended Resume warning test was not performed. Build 79 was paused at the final audit; normal Quit completed. No forced Resume was used. |
| Now Playing | Isolated native hide/reveal/exact-restore passed while assessment was inactive. Full managed reveal failed in owner testing. Static inspection identifies the missing Control Center assessment identifier. New policy and sorting actions are disabled; existing identities and schema 3 receipts remain recoverable. | It still disappears under the inspected assessment filter. Excluding preference writes cannot preserve it. The old timing comparison failed end to end and was not promoted. |
| Resume host identity | Owner testing of the same Betta copy contrasts Applications and desktop launches. Original read-only probes and static evidence connect MenuBarAgent path-read denial to nil host identity. Owned-copy controls had identical executable/Info.plist hashes and were completely removed. Blenny Full Disk Access did not change the separate reader guard. | The path probes create no status items. The result is specific to the inspected host/build; it is not a universal Applications-only rule or a fix for Now Playing. |

The [technical spike](TECH_SPIKE_0.13.0.md) preserves the candidate sequence,
failed trials, exact restoration evidence and superseded decisions. The
[Resume investigation](RESUME_VISIBILITY_INVESTIGATION_0.13.0.md) records the
identity chain and permission controls. [Known limitations](KNOWN_LIMITATIONS.md)
remain part of the product contract.

## Final automated and package verification

Explicit Xcode 27.0 (`27A266a`) and macOS SDK 27.0 verification passed:

- Debug: **642 core tests / 59 suites plus 3 AppKit tests / 2 suites**, 645 total.
- Ordinary Release: **336 core tests / 36 suites plus 2 AppKit tests / 2 suites**,
  338 total. Each configuration includes the 80-case Settings layout matrix.
- Both complete test logs contain no compiler warnings or errors.
- Signed Debug **Build 81** and ordinary Release **Build 82** built for arm64,
  minimum macOS 27.0, SDK 27.0, marketing version 0.13.0. Both pass nested deep
  strict signature verification and preserve the installed certificate-bound
  designated requirement. The Debug build's rpath removal produces an expected
  pre-signing invalidation warning; final signing and verification pass.
- Six development menu title literals are present in Debug and absent from
  ordinary Release. Release also excludes the Now Playing diagnostic entry,
  Spotlight private setter, exact ordering-domain literal, ordering entitlement
  and App Data purpose string. Its AppKit fixture confirms no Debug submenu.
  This does not claim that the baseline private assessment backend is absent.
- The Debug packaged Board lifecycle self-check passes. Package update feeds
  remain unconfigured, so Check for Updates remains disabled. No hosted update
  or installation was exercised by the release audit.

The installed owner-test package remains **Build 79**; the independently audited
Build 81/82 packages were not installed. The latest source behavior is the same
as Build 79; closure changes only tracked documentation and local Git records.
Build numbers do not establish public distribution acceptance.

## Restoration and retained state

The isolated Now Playing preference trial restored its exact absent-key
baseline and removed its receipt. The 0.8.0 comparison used separate support
data and refused the current runtime before Apply. Its prior package/data were
restored byte for byte. The later legacy-timing trial failed, completed cleanup,
and returned to ordinary Debug. Neither failed comparison is successful managed
Now Playing evidence.

At final audit, Build 79 displayed **Management paused** and a visibility-recovery
affordance; the underlying pause cause was not established. Normal Quit ended
the process. All nine existing application-support files remain byte-identical,
with no shared-system-item receipt or owned validation process. Independent
current-host preference API and file reads confirm NowPlaying absent; Spotlight's
visibility preference is true. Previously created owned probe bundles and their
temporary directories are reverified absent. No new preference mutation,
ordering Apply, Undo, assessment activation or permission change was attempted.

The accepted ordering ledger remains in its verified `applied` phase and is
preserved as normal Undo history, not an unfinished experiment. User-chosen order
must not be erased to close a milestone. A fresh read-only ordering diagnostic
reports an invalid saved exact-file grant and denied API/file reads, so this
audit does **not** independently reverify the current complete ordering table.
That grant/regrant and live ordering check remain explicit 1.0.0 review items.
Earlier live ordering and inverse evidence is retained without claiming a new
physical pass.

## Repository and history audit

The preparation audit initially found only the expected missing version commits
and incomplete status alignment. The final release audit requires a clean
working tree, aligned version documents, valid Conventional Commit subjects,
no prohibited attribution and Git object integrity. Forward commits organize
the authorized version work; no shared commit or existing tag is rewritten.
The original first commit, `4a4dbe32d9382efe04769d4e1566d8f5ab695bcf`, and genuine
development history beginning on 2026-08-21 remain preserved.

Reachable-history inspection covers all branches/tags and unique blobs, with
no private keys, tokens, personal absolute paths, raw diagnostics, generated
binaries, copied third-party implementation or oversized candidate files.
Historical binary blobs are application PNG assets. The sole broad attribution
scan match was the release audit script's own prohibited-pattern literal,
not a commit trailer. All reachable author/committer metadata uses the approved
public identity. New research source is original, bounded, excluded from product
targets and documents its cleanup. Raw evidence, snapshots, packages and signing
material remain ignored under LocalData or outside Git. No license is added.

The configured origin already contains the 0.12.0 branch and tags. No remote ref,
repository visibility or publication state is changed. The local annotated tag
is `v0.13.0`; it is created only after the release audit passes and must peel to
the final closure commit. Final audit receipts remain ignored under
`LocalData/0.13.0-release/`.

## Next boundary: 1.0.0

The owner's separate final-check session must review the full
[1.0.0 gates](ROADMAP.md#100--first-public-and-stable-release), including Release
ordering promotion, exact-file grant/regrant and interrupted recovery,
onboarding/keyboard/VoiceOver, final menu and Settings pixels, supported
hardware/displays/builds, signing/notarization, hosted updates, uninstall,
license selection, publication privacy and emergency backend disable. Existing
Clock/Notification Center, unmanaged-extra and Now Playing limitations must be
explicitly accepted or resolved. Wider Debug cleanup remains deferred until
that review assigns scope. Planning 1.0.0 does not waive these gates.
