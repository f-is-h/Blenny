# Blenny research

This directory contains source snapshots from bounded engineering experiments. It is versioned for reproducibility and historical review, but it is not part of any Blenny product target.

## Safety boundary

- The probes may reference unsupported private macOS behavior.
- They are specific to the recorded macOS build and can stop working without notice.
- They must fail closed when expected runtime classes, selectors, or encodings differ.
- Mutation probes must have an explicit time bound and restore path.
- Do not run a probe against a critical system item or an unapproved third-party application.
- Do not package or distribute these probes as product components.

Generated applications, executables, logs, screenshots, system-state backups, and build caches belong in ignored `LocalData/`, not here.

The corresponding observations and recovery results are documented in [the 0.0.1 technical spike](../docs/TECH_SPIKE_0.0.1.md).
