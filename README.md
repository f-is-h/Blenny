<img src="Assets/AppIcon/BlennyAppIcon.png" width="96" alt="Blenny icon">

# Blenny

A native menu bar organizer built only for macOS 27. Keep everyday apps visible,
reveal occasional ones when needed, and keep the rest hidden, without Blenny
ever taking over your mouse.

## Why Blenny

- **Designed for macOS 27 only.** Blenny uses the menu bar ordering and
  visibility mechanisms of macOS 27 directly. There is no compatibility layer
  for older systems and no workaround carried over from them.
- **Never moves your pointer or fakes a drag.** Blenny does not move the cursor,
  synthesize clicks or simulate Command-drag. Your mouse stays yours while a
  change is applied, and no icon is dragged across the screen on your behalf.
- **Lightweight.** A native AppKit and SwiftUI app of about 6 MB, with Sparkle
  as its only bundled dependency. It needs no Screen Recording permission and
  runs no background polling loop; it acts only when you do or when the system
  reports a relevant change.
- **Fast.** Visibility and order are applied together as one reviewed change,
  written through one serial writer instead of replaying moves icon by icon.
- **Safe to try.** Edit a draft, review it, then Apply. Undo Changes reverses
  the latest Apply, Stop releases restrictions immediately, and unexpected
  system state fails closed instead of being retried in a loop.

## Organize your menu bar

- **Visible** keeps an app available during management.
- **Revealable** conceals it until you expand Blenny's bounded reveal session.
- **Hidden** keeps it out of ordinary reveal sessions.

Drag icons in Organize to edit a draft, then choose **Apply**. You can also use
an icon's context menu or accessibility actions. Icons belonging to one application
move together. **Discard Changes** returns to your accepted configuration.

**Undo Changes** reverses the latest successful Apply, including its visibility
and ordering changes. Undo has one level. If another change invalidates the old
Undo baseline, review **Replace Undo & Apply** before replacing that history.

**Stop** releases active visibility restrictions and retains accepted order.
**Resume** revalidates and uses the saved configuration. **Quit** also releases
restrictions; your saved Resume choice is retained for the next launch. macOS
still controls its own overflow, so a Visible app may overflow when space is tight.

**Position Blenny Controls…** reviews placement of Blenny's arrow and fish at
the Revealable/Visible boundary; **Undo Control Placement** restores their prior
positions independently. Accepted placement persists through Stop and Quit.

## Install and grant access

Requires **Apple silicon · macOS 27 only**. See the
[acceptance matrix](docs/ACCEPTANCE_1.0.0.md) for tested environments.

**1.0.0 source finalized — local checks and owner acceptance completed;
GitHub release pending.** Multi-display testing remains unverified. See the
[release record](docs/RELEASE_1.0.0.md) for status.

After publication, download the DMG from [GitHub Releases](https://github.com/f-is-h/Blenny/releases),
open it, and drag Blenny into **Applications**. Quit an older copy before replacing
it, eject the disk image, and launch the installed copy.

Blenny uses a fixed self-signed certificate and is not notarized by Apple. If
macOS blocks first launch, attempt to open it, then use **System Settings →
Privacy & Security → Open Anyway** for Blenny. Follow
[Apple's first-launch instructions](https://support.apple.com/102445).
You do not need to disable Gatekeeper or SIP or install a trusted root certificate.

Grant **Device Control** when Blenny requests it. If requested for ordering,
choose the exact **Menu Bar Layout File** shown by Blenny's file picker.
The selected file's security-scoped bookmark is saved privately. A stale bookmark
is renewed once only if it still resolves to the correct file with a usable grant;
invalid or revoked access requires choosing the file again. Screen Recording is
not required.

Install managed applications in `/Applications` and relaunch them after moving
them (see the application location limitation below).

## Known limitations

Blenny 1.0.0 ships with the following known limitations. They come from how
macOS 27 treats menu bar items while management is active, not from missing
permissions. They are reviewed and accepted for this release rather than
required fixes, and each has a workaround or a safe fallback. Please read them
before you install.

| Area | What happens | Workaround |
| --- | --- | --- |
| Clock / Notification Center | Clicking the native Clock does not open Notification Center while management is active. | Swipe left from the right edge of the trackpad (owner-verified on an earlier tested build), or Stop management. |
| Now Playing | Can disappear during active management, although Blenny writes no new settings for it. Blenny offers recovery only. | Stop management to release the restriction. |
| Gaming, Wine and other unattributed extras | Menu extras whose host has no application Bundle ID may disappear during management. A Board entry does not prove the icon is physically visible. | Stop or Quit Blenny to release the restriction (the Gaming icon was observed returning after Quit). |
| Application location | On the tested system, apps run from development folders, the Desktop or `~/Applications` can lose their menu bar identity and be hidden during management. Full Disk Access for Blenny does not fix this. | Install managed apps in `/Applications` and relaunch them after moving. |
| System item sorting | Siri, Time Machine and Control Center cannot be sorted yet. Clock and the native overflow arrow stay fixed. | Their visibility can still be managed where supported. |
| Exact placement | Pixel positions and adjacency between Blenny's controls and the native overflow arrow are not guaranteed. | Preferred positions keep relative order. |
| Platform and signing | Apple silicon and macOS 27 only. The app is self-signed and not notarized. | Use Open Anyway on first launch, as described above. |

### Help wanted

These limitations are open problems, and we would love help solving them. If
you know macOS 27's menu bar internals, or you find a route that works, please
open an [issue](https://github.com/f-is-h/Blenny/issues) with your evidence or
send a pull request. The
[technical details](docs/KNOWN_LIMITATIONS.md) record what has already been
tried and why it failed, so you can start from there instead of from zero.

A fix must keep Blenny's core promises: no pointer movement, synthesized clicks
or simulated drags, no private entitlements or SIP changes, no Screen Recording
requirement, no polling loops, and complete restoration of any system state it
changes. Automatically stopping and resuming management around a click is not
an accepted fix, because it releases hiding restrictions.

## Updates and recovery

Use **Check for Updates** in Settings or Blenny's menu. Settings also lets you
enable **Automatic checks**; it is off by default. Automatic checks do not enable
unattended installation. Finish a running operation, resolve pending recovery,
and apply or discard your draft before updating. Sparkle verifies each update
against Blenny's independent EdDSA public key and persistent application identity.

When Blenny reports an unfinished change, use **Recover Changes** and retain
its recovery data until completion. Unexpected target drift fails closed rather
than repeatedly writing system settings. Do not delete recovery files to dismiss
an error. [Recovery and uninstall guidance](docs/RECOVERY_AND_UNINSTALL.md) explains
which changes Stop, Undo and recovery can restore.

## Build and contribute

Public binaries, starting with 1.0.0, are built on GitHub from reviewed source.
See the [release procedure](docs/DISTRIBUTION.md) and [release notes](docs/RELEASE_NOTES.md).

Use Xcode 27 and the macOS 27 SDK explicitly:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/verify-local.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build-app.sh debug
```

Debug and ordinary Release share the daily product capabilities. Debug adds
development menus and bounded probes. Distribution builds require the owner's
existing pinned certificate; a contributor can explicitly request a development
ad-hoc build using `BLENNY_CODE_SIGN_IDENTITY=- BLENNY_ALLOW_ADHOC=YES`.
That build is not eligible for distribution or authenticated release updates.

See [contributing](CONTRIBUTING.md), [product contract](PROJECT_BRIEF.md),
[release procedure](docs/DISTRIBUTION.md), [roadmap](docs/ROADMAP.md) and
[archived research](Research/README.md). Report reproducible problems through
[GitHub Issues](https://github.com/f-is-h/Blenny/issues); omit raw menu bar
inventories, credentials and personal paths.

## Support Blenny

If Blenny is useful to you, you can support its development through
<a href="https://github.com/sponsors/f-is-h?frequency=one-time&amp;metadata_project=blenny&amp;metadata_source=readme&amp;metadata_placement=badge&amp;metadata_lang=en">GitHub Sponsors</a>
or [Ko-fi](https://ko-fi.com/blenny).

## License

Blenny is licensed under [Apache-2.0](LICENSE). See [NOTICE](NOTICE) and
[third-party notices](THIRD_PARTY_NOTICES.txt). Sparkle is the bundled update
dependency.
