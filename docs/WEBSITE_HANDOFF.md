# Website release facts

Website implementation and deployment are separate from 1.0.0 engineering.
This record supplies the facts without choosing a domain or changing Website/.

- Product: Blenny — a native menu bar organizer for macOS 27.
- Version: 1.0.0 candidate, not yet published.
- Platform: Apple silicon; macOS 27 or later. Current verification: macOS 27.0
  build 26A428. Other configurations are unverified.
- Feature copy: Visible, Revealable and Hidden application groups; reviewed
  policy/order Apply; single-level Undo; Stop/Resume; authenticated Sparkle updates.
- Project link: https://github.com/f-is-h/Blenny.
- Download landing page after publication: https://github.com/f-is-h/Blenny/releases/latest.
- Planned candidate asset: https://github.com/f-is-h/Blenny/releases/download/v1.0.0/Blenny-1.0.0-106.dmg.
- Update feed after publication: https://raw.githubusercontent.com/f-is-h/Blenny/main/appcast.xml.
- Legal: Apache-2.0; packaged Sparkle notices.
- Installation: self-signed, not Apple-notarized; Applications install and the
  system's per-app Open Anyway flow if blocked. No disabling system protection.
- Known limits: Clock clicks/Notification Center during management, recovery-only
  Now Playing, disappearing unattributed Gaming/Wine items, deferred system
  sorting, and no guaranteed native-overflow adjacency.
- Approved visual assets: Assets/AppIcon/BlennyAppIcon.png and
  Assets/MenuBar/BlennyMenuBarTemplate.svg. No new menu bar screenshots have been
  cleared for publication in this work; omit unrelated inventories/personal data.

Use README and docs/RELEASE_NOTES.md as the user-facing text. The asset URL is
planned, not live. Confirm the final build/asset after Git closure and publication
approval before displaying an active download button. Supply the canonical site
URL back to the product task when selected; current product links use GitHub.
