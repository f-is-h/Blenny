# Read-only ordering feasibility probes

These unsupported macOS 27 investigation sources are excluded from all Swift
package and product targets. Candidates, attempted reads and safety limits are in
[the 0.7.0 spike](../../docs/TECH_SPIKE_0.7.0.md).

- `InspectPositionInterfaces.swift` loads MenuBarClient and MacSystemUI frameworks and reads
  Objective-C class/protocol metadata. It creates no private object, invokes no
  private method and opens no XPC connection. Method names are evidence of an
  interface, not a tested contract or authorization to call it. The expanded
  inventory includes AppKit status-item hosts/scenes and BoardServices transport
  classes; selected method addresses support static inspection, not invocation.
- `ReadPositionSnapshot.swift` performs one bounded AXExtrasMenuBar read for
  1–12 exact bundle identifiers supplied by the operator. It needs existing
  Accessibility trust and never prompts for permission. It limits traversal to
  256 elements, depth 8 and a 10-second scan budget with bounded per-call AX
  messaging timeouts; no read retry or polling runs. A bounded final AX call can
  finish after the scan deadline. Missing/ambiguous owners and incomplete reads
  are reported as failure. No unrelated app window or pixel data is read.

- `ReadAgentPreferredPositions.m` reads the candidate agent preference key or
  attempts one private utilities getter, with exact runtime/signature guards,
  a five-second reply deadline and ten-second process alarm. `--preferences`
  performs ten CFPreferences copy operations without synchronization or writes.
  `--preference-key DOMAIN KEY` instead reads one exact key through effective
  lookup and the four user/host scopes. It does not select or modify a sandbox
  container; the two views can differ even for the same bundle and key.
  `--xpc-bs` uses the agent's published BoardServices endpoint with ordinary
  process credentials. The tested server rejected it for a missing Apple
  utilities entitlement: do not retry, add entitlements or bypass access control.
  `--xpc-mach` retains the original failed transport hypothesis for historical
  reproducibility; it is not the correct service route. The interface declares
  only the getter, never the service's clear or performance-test operations.
- `InspectPositionObservability.swift` makes one bounded canonical AX tree scan
  for up to four exact owners, inspecting advertised attribute names and selected
  scalar/geometry values. Parameterized attribute names are listed, never invoked.
  It reports incomplete roots and missing identity/visibility fields without
  guessing. Native menu-bar data is not recovered by searching arbitrary windows.
- `ComparePreferenceFiles.py DOMAIN KEY` reads one numeric position key from
  the ordinary and sandbox preference files and invokes `defaults read` once.
  It never synchronizes preferences, launches the target, or rewrites either
  file. Different values are a storage-source ambiguity, not permission to fix
  one of them. It does not read the running target application's memory.

Redirect stdout and stderr to ignored `LocalData/`; never
commit process identities, bundle inventories, coordinates, metadata dumps or
binaries. The AX probe reads positions and settable flags; it cannot set an
attribute, activate an item, create a status item or mutate preferences. Its
frames are not proof of compositor visibility or persistent physical order.

Example compilation from the repository root:

```sh
mkdir -p LocalData/0.7.0
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun swiftc Research/0.7.0/InspectPositionInterfaces.swift \
  -o LocalData/0.7.0/inspect-position-interfaces
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun swiftc Research/0.7.0/ReadPositionSnapshot.swift \
  -o LocalData/0.7.0/read-position-snapshot
LocalData/0.7.0/inspect-position-interfaces > LocalData/0.7.0/interfaces.log
LocalData/0.7.0/read-position-snapshot com.apple.MenuBarAgent xyz.fi5h.blenny \
  > LocalData/0.7.0/positions.log
```

Blenny must already be running for the last example to report its items. Do not
launch ordinary Debug merely to sample it: saved enabled intent can activate
management. Use the installed no-writer validation route described in the spike.
Do not modify trust, launch other apps or invoke historical mutation probes to
turn a failed read into a pass.

Compile the utilities reader independently (this does not execute it):

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Werror \
  -mmacosx-version-min=27.0 -framework Foundation \
  Research/0.7.0/ReadAgentPreferredPositions.m \
  -o LocalData/0.7.0/read-agent-positions
```

Preference absence is not an empty compositor state, and equal preferences are
not physical layout restoration. No research command authorizes a position write
or repairs the unresolved second-run layout change described in the spike.

The later owner-authorized write is implemented only by the Debug product route
documented in the spike, not by these research tools. It targets one exact Blenny
autosave identity, uses the existing serial writer, and restores the absent agent
table after 60 seconds. Its one-runtime success does not authorize a guessed
third-party identity, Apple entry, global clear, refresh nudge or Release backend.
