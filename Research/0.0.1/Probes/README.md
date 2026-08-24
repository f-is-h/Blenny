# 0.0.1 probe snapshots

`InstalledToggleProbe/` preserves a sanitized source snapshot of the decisive installed AppKit status-item experiment and its separate serialized policy writer. It was used for repeated reveal/conceal measurements.

These files are historical evidence, not supported tools. No build script is provided, and the Swift package does not reference them.

The policy writer requires the `BLENNY_TEST_TARGET_BUNDLE_ID` environment variable. It exits without activating a restriction when the variable is absent or the target application is not running. Only use a non-critical, explicitly approved test application.

The plist uses a temporary `com.example` identifier. Generated bundles and executables must remain under ignored `LocalData/`.
