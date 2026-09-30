# Recovery and uninstall

## What each action restores

| Action | Visibility restrictions | Accepted preferred positions | Saved data |
| --- | --- | --- | --- |
| Stop | Releases process-owned restrictions | Retained | Retained; saved management choice becomes stopped |
| Quit | Releases process-owned restrictions | Retained | Resume choice and recovery data retained |
| Undo Changes | Restores the latest Apply's prior policy and positions | Latest Apply reversed | Single-level receipt retained according to transaction state |
| Recover Changes | Completes a specifically recorded interrupted recovery | Only the receipt's recorded scope | Incomplete receipt kept if verification fails |
| Undo Control Placement | Restores Blenny's prior control positions | Other accepted order retained | Separate control-placement record |

Stop is not an all-history ordering reset. Undo reverses one latest Apply, not
every change ever made. A legacy order-only receipt retains its original scope.
Recovery checks complete identities and touched values before writing. An
external change or missing target can require review rather than forced recovery.

## Lost access

Launch the installed `/Applications/Blenny.app` copy normally. Check Device
Control in System Settings and relaunch after changing the permission if needed.
For a missing or revoked layout-file grant, choose **Menu Bar Layout File** in
Blenny and select the exact file shown. The app does not request a whole-home
directory grant or delete TCC records.

The support command below reads layout state and reports agreement and access
errors without changing menu bar preferences. It may renew an existing stale
exact-file bookmark after validation; it never creates a grant or prompts:

```sh
open -n -g -W -a /Applications/Blenny.app -o /tmp/blenny-access.json --args --diagnose-access
```

Do not launch a second full manager to diagnose the first. This command exits
before management initialization. Its report contains no bundle inventory or
preference values. Readback equality is not proof of physical icon visibility.

## Uninstall safely

1. Finish or recover a running change. If desired, use the available Undo actions
   to reverse the latest recorded changes. Do not discard an unresolved receipt.
2. Stop management, disable Open Blenny at Login in Settings, and Quit Blenny.
3. Move Blenny from Applications to Trash. Verify restrictions have been released.
4. Keep `~/Library/Application Support/Blenny` while any recovery is unresolved.
   Only after successful restoration may you remove this app-owned directory and
   its app preferences if you want to erase settings.

The `DebugOrdering` subdirectory is an intentionally retained legacy data path
also used by Release 1.0.0. Do not rename it, delete bookmarks or wipe Undo data
as an upgrade shortcut. macOS-managed item positions may remain after uninstall
when you chose to retain an accepted order.
