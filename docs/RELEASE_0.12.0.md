# Blenny 0.12.0 local milestone audit

Status: **complete local experimental milestone**, 2026-09-27. This is a macOS 27
experimental milestone, not a public release candidate. No push, publication,
ordinary Release ordering promotion, or hosted Sparkle update is authorized.
The owner plans a separate 0.13.0 iteration for the right-click menu, Debug
controls, and application/menu-bar artwork before any public release.

## Scope and evidence

| Area | Observed or verified | Limit |
| --- | --- | --- |
| Stable local signing | Self-signed same-identity upgrades at the same Bundle ID and installation path retained Device Control without regrant in the Build 24→25 and 25→27 trials. The independently built 0.12.0 Build 60 Debug and ordinary Release packages have the same certificate-bound designated requirement. | Initial change from the ad-hoc signer required the owner's regrant. The saved exact-file bookmark is stale. A macOS reboot and Sparkle-delivered replacement remain untested. |
| Sparkle | Sparkle 2.10.0 is pinned and packaged with strict nested signature verification. The Ed25519 public key is embedded; update checks require a configured HTTPS feed and are otherwise disabled. | No hosted feed, installed update, notarization, or public distribution proof. |
| Startup and Dock | The owner and local diagnostics verified Build 28 normal Quit and automatic Resume from a saved active state, visibility release on Quit, and Dock presence while the main window is open. | Forced termination and reboot were not exercised. |
| System-item Board | The owner verified Spotlight sorting and its Visible/Revealable/Hidden transitions with explicit inverses on Build 35. Build 36 removed the observed ordinary reveal delay. Build 44 corrected a duplicate Now Playing card. Known system-item art and action availability are gated by exact observed capability. | Spotlight remains a Debug-only writer. Other icons are not granted write access by artwork alone. The Now Playing repair was not followed by a fresh physical drag/Apply. |
| Unbundled menu extras | Build 59 can Resume with read-only GamePolicyAgent and Wine/Battle.net observations. The owner accepts that assessment may suppress original unmanaged icons during active management. | Gaming preservation is not fixed; Wine's full physical lifecycle is unverified. No alternate backend was promoted. |
| Current automated checks | Xcode 27 and macOS 27 SDK: 634 Debug tests in 58 suites and 332 ordinary Release tests in 35 suites passed. Build 60 Debug and ordinary Release packages built with version 0.12.0; strict nested signatures and the Debug packaged Board lifecycle self-check passed. | Build 60 packages were not installed; these checks do not establish their live physical behavior or a public release. |

Details and original observations are in the
[technical spike](TECH_SPIKE_0.12.0.md),
[signing investigation](SIGNING_PERMISSION_CONTINUITY_0.12.0.md),
[Sparkle record](SPARKLE_UPDATES_0.12.0.md), and
[unbundled-item investigation](UNBUNDLED_MENU_EXTRA_COMPATIBILITY_0.12.0.md).

## Restoration and retained state

The 0.12.0 unbundled-item trial initially left an allowed
`xyz.fi5h.blenny.admission-trial` registration in macOS System Settings > Menu
Bar. Its disposable helper bundles and bookmark files were removed. A later
owner-requested exact-row cleanup used a fresh snapshot and API/file agreement,
removed only that row, and independently verified unchanged unrelated
preferences. The entry remained absent after System Settings reopened, and a
separate read-only inspection on 2026-09-27 found zero matching rows. No
research process remains active. The private snapshot and verification record
stay in ignored `LocalData/`; no whole-preference reset was used.

The cleanup did not test reboot persistence or OS-maintained authorization
revocation. Neither is claimed as passed. The native Files & Folders list did
not display the admission-trial helper; direct TCC database reads were denied,
so absence from that UI is not proof that every OS authorization record was
revoked. The one-off helper executable and its saved bookmarks were removed,
so no active research writer or stored access token remains. The installed,
owner-accepted Build 59, its saved policy, order, and ordinary Undo record were
not replaced for this source milestone.

## Repository and package audit

The release audit reviewed the version range and reachable history, checked
Conventional Commit subjects and Git object integrity, and found no tracked
private keys, raw evidence, personal absolute paths, generated binaries, or
files over the repository size limit. Signing material and raw snapshots remain
ignored; `Config/SigningIdentity.sha1` is only the public certificate
fingerprint. The original 2026-08-21 first commit is preserved, and 0.12.0 uses
forward commits without rewriting shared history. The Debug package carries
only the user-selected exact-file entitlement; ordinary Release carries no
ordering entitlement or App Data purpose string. Both packages target macOS
27.0 and have the same certificate-bound designated requirement. The remote
branch and tags were not changed by this local milestone.

## Next boundary

Version 0.13.0 is planned for product presentation and controls. The first
public release version has not been assigned. The broader compatibility,
onboarding, accessibility, license, update, signing and publication gates in
the [roadmap](ROADMAP.md) remain open. A local self-signed package is not a
Developer ID or notarized distribution package.
