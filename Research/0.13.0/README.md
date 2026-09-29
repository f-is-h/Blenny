# 0.13.0 Resume host-identity research

Unsupported, read-only macOS 27 build `26A428` research. These files are excluded
from Blenny's product targets. The probe refuses other OS builds and non-Debug
compilation. Raw results, executables and disposable bundles belong under ignored
`LocalData/0.13.0-resume-identity/`.

`InspectResumePathAccess.m` queries the inspected `sandbox_check` contract for
one exact running MenuBarAgent PID and explicitly supplied directories. It uses
the same `file-read-data`, path filter and no-report flag as the inspected
BaseBoard identity helper. This does not read the target directory's contents,
request a file-access grant, alter a sandbox, create an assessment assertion,
write a preference, register a menu extra or inject into another process.
Missing directories must not be interpreted as proof of a location restriction.

The `--own-bundle` mode reads only its own `NSBundle` identity and exits. That
identity is a control, not a measurement of a live MenuBarAgent status-item field.
An application's ability to identify itself does not establish that a different,
sandboxed process can read its bundle information.

Build with Xcode 27 and its macOS 27 SDK:

```sh
rtk proxy mkdir -p LocalData/0.13.0-resume-identity
rtk proxy env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun --sdk macosx clang -DDEBUG=1 -fobjc-arc -Wall -Wextra -Werror \
  -mmacosx-version-min=27.0 -framework Foundation \
  Research/0.13.0/InspectResumePathAccess.m \
  -o LocalData/0.13.0-resume-identity/inspect-resume-path-access
rtk proxy pgrep -x MenuBarAgent
```

Pass the returned PID explicitly; do not reuse a historical PID. For example:

```sh
rtk proxy LocalData/0.13.0-resume-identity/inspect-resume-path-access \
  --reader-pid <CURRENT_MENU_BAR_AGENT_PID> \
  /Applications/Betta.app/Contents/MacOS
```

## Owned identical-copy comparison

`CompareResumeIdentityPaths.py` requires an existing `~/Applications` directory.
It creates four copies of a new, owned probe bundle under LocalData, global
Applications, user Applications and a new temporary directory. It refuses any
pre-existing destination, checks executable and Info.plist hashes, directly runs
each bundle executable once, and queries MenuBarAgent's access while all copies
exist. The same bundle identifier is intentionally used in all four copies.
No status item is created and neither `open` nor a Launch Services registration
API is called. Each invocation has a 15-second timeout; there is no polling or
retry. A `finally` block removes only destinations created by that invocation
and records cleanup verification. An abnormal termination requires checking the
recorded probe destinations before another run; never remove a pre-existing app.

```sh
rtk proxy python3 Research/0.13.0/CompareResumeIdentityPaths.py \
  --probe LocalData/0.13.0-resume-identity/inspect-resume-path-access \
  --reader-pid <CURRENT_MENU_BAR_AGENT_PID> \
  --evidence-directory LocalData/0.13.0-resume-identity/copy-comparison
```

All four copies identified themselves correctly, but MenuBarAgent's directory
read query permitted only the global Applications copy on the inspected host.
This is a sandbox/path test, not an end-to-end menu-extra visibility test. See
[the findings](../../docs/RESUME_VISIBILITY_INVESTIGATION_0.13.0.md) for the static
identity-to-filter chain and the separate owner-observed Betta contrast.
