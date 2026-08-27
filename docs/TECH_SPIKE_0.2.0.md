# Blenny 0.2.0 Icon-first Policy Presentation

> Planning and engineering contract for one independently reviewable product increment. This document contains no implementation or runtime evidence yet.

Status: **Planned; implementation has not started.**

Last updated: 2026-08-27

## Starting boundary

Development starts after local annotated tag `v0.1.0`, peeled commit `5df98625d1ee2493bd0ea0d0eea94d427cbcac20`. Version `0.1.0` already provides the three horizontal policy lanes, bounded current observation, read-only Apple system-item cards, local drafts, deterministic review, recovery paths, and Accessibility onboarding.

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

### Apple system items

- Map stable, known observation identifiers such as Wi-Fi, Bluetooth, Clock, Control Center, Sound, Now Playing, and Siri to semantic system symbols.
- Keep every Apple system item read-only and outside `BundlePolicyDraft`.
- Use a generic read-only system-item fallback when no explicit semantic mapping exists.
- Do not infer mutability from successful observation or symbol mapping.

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

Add tests for:

- application icon-source eligibility and deterministic fallback selection;
- stable icon descriptors across observation and candidate ordering;
- known Apple observation identifier to semantic-symbol mapping;
- unknown Apple system-item fallback and read-only labeling;
- duplicate observations remaining one bundle-level icon candidate;
- Blenny remaining Visible and ordinary reveal continuing to exclude Hidden;
- no draft, persistence, report, or policy fingerprint change caused solely by icon resolution.

Installed visual review must confirm:

- application and known system candidates are recognizable primarily by icon;
- missing icons produce an honest, consistent fallback rather than a blank or clipped card;
- long horizontal lanes still scroll cleanly;
- keyboard navigation, tooltips, read-only system markers, Review, Discard Draft, Resume Managing, Stop Managing, Restore Previous Policy, close, and Quit remain stable.

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
