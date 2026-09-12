# Notification Center compatibility investigation

Unsupported, read-only macOS 27 research; excluded from all product build targets.
See [the investigation](../../docs/NOTIFICATION_CENTER_RESEARCH_2026-09-12.md).

`InspectContracts.m` loads Apple's framework and prints class/protocol method names
and type encodings. It does not instantiate an assertion, connect to XPC, change
preferences, open Notification Center, synthesize input, or restart any process.
There is no mutation to restore. Missing contracts return a nonzero exit status.
The runtime check is macOS 27; output from another build is new evidence, not a
compatibility guarantee.

Set `DEVELOPER_DIR` to Xcode 27 explicitly before running:

```sh
mkdir -p LocalData/0.9.0-clock-repair
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror \
  -mmacosx-version-min=27.0 -framework Foundation \
  Research/NotificationCenterCompatibilityProbe/InspectContracts.m \
  -o LocalData/0.9.0-clock-repair/inspect-contracts
LocalData/0.9.0-clock-repair/inspect-contracts \
  > LocalData/0.9.0-clock-repair/inspected-contracts.txt
```

This inventory cannot establish Notification Center functionality or the server's
state computation. Those conclusions require the separate static analysis and
owner-operated interaction evidence described in the investigation. Do not treat
method discovery as authorization to invoke a write or use an unsupported origin.
Raw Apple disassembly, process evidence and binaries stay in ignored `LocalData/`.
