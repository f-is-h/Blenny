# Blenny 0.12.0 local milestone audit

Status: **closure pending** as of 2026-09-27. This is a local macOS 27
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
| Current automated checks | Xcode 27 and macOS 27 SDK: 634 Debug tests in 58 suites and 332 ordinary Release tests in 35 suites passed. Build 60 Debug and ordinary Release packages built with version 0.12.0; strict nested signatures and the Debug packaged Board lifecycle self-check passed. | These checks do not establish live physical behavior of Build 60 or a public release. |

Details and original observations are in the
[technical spike](TECH_SPIKE_0.12.0.md),
[signing investigation](SIGNING_PERMISSION_CONTINUITY_0.12.0.md),
[Sparkle record](SPARKLE_UPDATES_0.12.0.md), and
[unbundled-item investigation](UNBUNDLED_MENU_EXTRA_COMPATIBILITY_0.12.0.md).

## Restoration gate

The 0.12.0 unbundled-item preference trial left an allowed
`xyz.fi5h.blenny.admission-trial` registration in macOS System Settings > Menu
Bar. The disposable helper bundles and bookmark files were removed in a
separate cleanup; that cleanup did not rewrite the system preference and did
not prove exact-file grant revocation. A fresh read-only inspection on
2026-09-27 still found the row allowed. The native UI exposes a switch for it,
but no single-item remove action. The prior custom writer showed API/file
readback disagreement and a row reappearing after a point-in-time inverse.
Replacing the complete preference blob could overwrite unrelated applications'
changes. No unverified system write is used to make this gate appear clear.

Repository policy requires complete system-state restoration before milestone
closure. Until the test row is removed through a demonstrated exact route, or
the owner explicitly changes that closure criterion for this documented
research residue, do not mark 0.12.0 complete or create `v0.12.0`.

## Next boundary

Version 0.13.0 is planned for product presentation and controls. The first
public release version has not been assigned. The broader compatibility,
onboarding, accessibility, license, update, signing and publication gates in
the [roadmap](ROADMAP.md) remain open. A local self-signed package is not a
Developer ID or notarized distribution package.
