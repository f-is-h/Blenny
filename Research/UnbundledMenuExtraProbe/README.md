# Unbundled menu-extra host probe

Standalone read-only research for macOS 27. This is not part of the application
target or a visibility backend. See the
[compatibility investigation](../../docs/UNBUNDLED_MENU_EXTRA_COMPATIBILITY_0.12.0.md).

The probe finds GamePolicyAgent and a bounded set of Wine executable candidates,
checks their live strict code signatures, reads the running application Bundle
ID, and reads AX menu-extra identity/setter capabilities for matching hosts.
It does not prompt for Accessibility, open a menu, create an assertion, write
preferences, move an item, or invoke an AX action. It does not load private
frameworks or attach to another process.

From the repository root, with Xcode 27 installed at the selected developer
directory:

```sh
rtk proxy mkdir -p LocalData/0.12.0-unbundled-compatibility
rtk proxy env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror \
  -mmacosx-version-min=27.0 -framework AppKit \
  -framework ApplicationServices -framework Security \
  Research/UnbundledMenuExtraProbe/InspectHosts.m \
  -o LocalData/0.12.0-unbundled-compatibility/inspect-hosts
rtk proxy sh -c 'LocalData/0.12.0-unbundled-compatibility/inspect-hosts > LocalData/0.12.0-unbundled-compatibility/hosts.json'
```

Use an existing authorized AX context only. If `axTrusted` is false, report the
identity-only result; do not change permissions for this probe. Scan limits are
16 matching hosts, 8 extras per host, a checked 5-second scan deadline, and a
0.2-second AX messaging timeout. The deadline is checked between operations,
not a hard process timeout. Review truncation flags and errors. A process may
exit during inspection, and PID/signature observations are not durable mutation
authority.

`physicalVisibilityVerified` is always false. Successful AX reads, an AX frame,
or a Board card cannot establish that the original icon is physically rendered.
Raw output contains private process and item observations and must remain in
ignored `LocalData/`; do not commit it or any compiled probe.
