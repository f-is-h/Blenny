# Blenny 0.2.0 Icon-first Policy Presentation

> Engineering record for one independently reviewable product increment.

Status: **Complete on macOS 27.0 build `26A5416b`; local tag and push deferred.**

Last updated: 2026-08-27

## Starting boundary

Development started from clean commit `5966c02c` after local annotated tag `v0.1.0`, peeled commit `5df98625d1ee2493bd0ea0d0eea94d427cbcac20`. The tag object and peeled commit were left unchanged. Version `0.1.0` already provides the three horizontal policy lanes, bounded current observation, read-only Apple system-item cards, local drafts, deterministic review, recovery paths, and Accessibility onboarding.

The installed policy remains disabled. Version `0.2.0` does not authorize a real assertion write or broaden the private backend.

## Product decision

Roadmap entries record current product judgment rather than immutable commitments to an earlier planning suggestion. At this stage, iconification is a more direct product improvement than lifecycle and display-matrix hardening because the policy editor still presents candidates primarily as text.

Version `0.2.0` therefore delivers one capability only: replace text-dominant candidate cards with stable icon-first presentation while preserving the complete `0.1.0` behavior and safety boundary.

## Icon-source contract

### Application bundles

- Resolve presentation from the currently observed owning application's installed bundle icon through public AppKit and Workspace facilities.
- Keep the owning bundle identifier as policy identity; an icon is never identity or persistence data.
- Use a deterministic generic application fallback when the bundle URL or icon cannot be resolved.
- Do not attempt to reproduce live status-item glyphs, animated status, counters, graphs, or text embedded in the real menu bar.

The implementation uses `NSWorkspace.urlForApplication(withBundleIdentifier:)` and `NSWorkspace.icon(forFile:)`. A resolved bundle must also declare an application icon in its public bundle metadata; otherwise the editor presents the shared fallback rather than an unrelated generic application placeholder. Application icons remain full color because they are the stable public recognition source. Artificially grayscaling them would not reproduce the owning app's live menu-bar glyph.

### Apple system items

- Map stable, known observation identifiers such as Wi-Fi, Bluetooth, Clock, Control Center, Sound, Now Playing, and Siri to semantic system symbols.
- Keep every Apple system item read-only and outside `BundlePolicyDraft`.
- Use a generic read-only system-item fallback when no explicit semantic mapping exists.
- Do not infer mutability from successful observation or symbol mapping.

The semantic map covers Bluetooth, Clock, Control Center, Now Playing, Siri, Sound, Wi-Fi, Weather, Text Input, and Time Machine identifiers observed through the bounded Accessibility reader. Matching operates on normalized stable observation-identifier tokens, never on icon pixels.

### Blenny status item

- `Design/MenuBar/BlennyMenuBarOpenMouthMaster.svg` preserves the detailed open-mouth vector design independently from production rendering constraints.
- `Assets/MenuBar/BlennyMenuBarTemplate.svg` is the 18-by-18-point optical-size production asset for Blenny's own menu-bar status item. It uses direct even-odd paths and status-size details instead of a nested SVG mask whose subpixel cutouts blurred when rasterized by AppKit.
- The build copies only the production asset into the application resources. AppKit loads it as a template image without additional button scaling, allowing the system to choose the appropriate monochrome rendering for appearance and emphasis.
- This template asset is deliberately separate from the color application icon.

### Blenny application icon

- `Assets/AppIcon/BlennyAppIconMaster.svg` is the tracked copy of the supplied v12 color vector master, and `Assets/AppIcon/BlennyAppIcon.png` is the byte-identical tracked copy of its supplied 1024-by-1024 sRGB preview render used for production packaging.
- The script-built application does not maintain hand-edited size variants. Each Debug or Release build derives the standard 16-, 32-, 128-, 256-, 512-, and 1024-pixel representations with system tools and packages them as `BlennyAppIcon.icns`.
- `CFBundleIconFile` declares that generated resource, so Finder, Launch Services, `NSWorkspace`, and Blenny's own public icon resolver receive the color bundle icon. The SVG master and intermediate iconset do not enter the application bundle.
- The color application icon is bundle presentation only. It does not enter observation identity, policy persistence, drafts, diffs, reports, fingerprints, diagnostics, or the status-item rendering path.

### Presentation and accessibility

- Make the icon the primary visual recognition element in each candidate card.
- Retain the human-readable name, policy, bundle identifier, observation count, fallback state, and read-only state through supplementary text, tooltips, selection detail, and Accessibility labels as appropriate.
- Preserve standard keyboard navigation and focus indication.
- Render system symbols and fallback glyphs in a way that remains legible under normal system appearance without adding a theme system.

## Privacy and safety boundary

- Do not request Screen Recording.
- Do not capture, cache, or persist menu-bar pixels or live item screenshots.
- Do not store raw icon image bytes in policy documents, backups, diagnostics, or Git.
- Do not change policy serialization, draft semantics, deterministic review, restoration, assertion construction, or Release backend isolation.
- Continue using manual Refresh only; add no polling or reconciliation loop.

## Deterministic verification

Tests cover:

- application icon-source eligibility and deterministic fallback selection;
- stable icon descriptors across observation and candidate ordering;
- known Apple observation identifier to semantic-symbol mapping;
- unknown Apple system-item fallback and read-only labeling;
- duplicate observations remaining one bundle-level icon candidate;
- Blenny remaining Visible and ordinary reveal continuing to exclude Hidden;
- no draft, persistence, report, or policy fingerprint change caused solely by icon resolution.

The deterministic suite now verifies all of those presentation boundaries in `PolicyIconResolverTests`, including installed-application eligibility, known and unknown system identifiers, stable results across ordering and duplicate observations, the shared fallback, and unchanged document, managed-policy, draft, diff, report, and fingerprint values.

Installed visual review must confirm:

- application and known system candidates are recognizable primarily by icon;
- missing icons produce an honest, consistent fallback rather than a blank or clipped card;
- long horizontal lanes still scroll cleanly;
- keyboard navigation, tooltips, read-only system markers, Review, Discard Draft, Resume Managing, Stop Managing, Restore Previous Policy, close, and Quit remain stable.

## Verification record

- Host: macOS 27.0 build `26A5416b`, Apple silicon.
- Toolchain: Xcode 27.0 build `27A5237l`, macOS 27.0 SDK selected explicitly through `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`.
- Debug tests: 115 tests in 16 suites passed.
- Release tests: 113 tests in 15 suites passed.
- Debug and Release application builds passed; both declare a macOS 27 minimum and SDK 27 in their Mach-O load commands and pass deep ad-hoc signature verification.
- Final Debug executable SHA-256: `fce3dbc18642a07b09568362b63be6ffa57a3eca53e5a791fbeb46bf5fe5bf60`.
- Final Release executable SHA-256: `9566c506aa3f7a314a31432dfc607c04964f0bea07587069837b25dd9ab28289`.
- The preserved detailed vector master has SHA-256 `db83c97a9e27da5b816d5b18e29f94b9ffd6abd3e9c2f1b4150c46949ade88e9`, exactly matching the pre-optical production asset. Source, Debug-resource, Release-resource, and installed-resource copies of the 18-point production SVG share SHA-256 `53edfd091d35ec50a5a9aabc9322fa71986b9fc76465a0e77e97627ccda52d20`; AppKit successfully decodes the packaged SVG.
- The v12 application-icon SVG master has SHA-256 `11716e2320fc2022e5c2581c1f7d92e0bafc9194c9ceb7e5d6b46789046b444b`; its 1024-pixel sRGB PNG has SHA-256 `0afc17b236b7451d7135b278dab0b1e5a94ff3cf866a38b9f19c53c4df1913b0`. Two consecutive Debug builds produced the same multi-resolution ICNS SHA-256 `5e5fdce3f203ce44fbc70561ea0a68adf221596eba56bec37325a8e96b471387`.
- The installed Debug bundle declares `BlennyAppIcon.icns`; Finder renders the color icon at normal and enlarged icon-view sizes, and public `NSWorkspace.icon(forFile:)` returns the installed resource with the expected multi-resolution representations.
- The Release executable links only the expected public Apple frameworks and Swift runtime. Privacy scans found no Screen Recording descriptions, live-pixel capture path, owner path, private validation identifiers, or enablement tokens.
- The prior full-lane installed acceptance populated all three horizontal lanes with 20 bundle owners and nine identifiable system items. It showed recognizable color application icons, the then-current Blenny fallback, semantic monochrome system symbols including Text Input, local horizontal scrolling, and complete selection/accessibility detail without clipping. After the color bundle icon was added, Finder and `NSWorkspace` acceptance verified the production icon path; the full Accessibility scan was not repeated because rebuilding the ad-hoc-signed app removed its prior trust, and this icon-only follow-up did not change system privacy settings.
- Installed interaction acceptance exercised selection details, keyboard focus traversal, a reversible draft move, deterministic Review, Discard Draft, the assertion-blocked Resume preview, the disabled Stop state, Restore preview, manual Refresh, close, reopen, and Quit. No Apply action was used during the final acceptance pass.

A post-QA recovery check detected that two disabled-policy saves had occurred during an earlier installed-interface exercise: the accepted document had gained local candidate assignments and the single backup had rotated. Both files remained disabled and mode `0600`, and no writer or assertion could be created through this path. Before closeout, the observed files were copied to ignored `LocalData/` evidence and the versioned schema-1 baseline was regenerated deterministically. The restored accepted-policy SHA-256 is `0618f1078de2655c5d4263c030459e7a1e0a320237708018957df83f8b74a004`; the restored backup SHA-256 is `938ad8a5611a0c9bb0459a77f61528ecc587457f96b160db4044bd41874c9599`; both are `0600`. The unexpected writes changed filesystem modification times, so this record does not claim timestamp preservation.

Management remains disabled, the validation preferred-position key remains absent, no Blenny validation process remains, and MenuBarAgent, Usage4Claude, and CleanShot X remain running. No real assertion write, retry, Screen Recording request, persisted screenshot, or menu-bar pixel capture occurred.

## Explicit exclusions

Version `0.2.0` does not include:

- drag-and-drop or within-lane ordering;
- physical menu-bar priority or per-status-item control;
- real assertion writes or backend promotion;
- mutable Apple system items;
- live status-item image capture;
- lifecycle or display-matrix hardening;
- login launch, updater, helper, IPC, global shortcut, shelf, search, profiles, themes, animation system, automatic rules, polling, or reconciliation.

Any proposal to add one of these capabilities requires an explicit roadmap decision rather than being absorbed into iconification work.

## Exit boundary

The milestone is complete only when Xcode 27 Debug and Release tests and app builds pass, installed visual review accepts the icon and fallback behavior, tracked documentation agrees on the narrow scope, restoration remains complete, and `$blenny-release` closes the version. Do not tag or push without the required evidence and owner confirmation.
