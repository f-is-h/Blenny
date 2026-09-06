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

Historical observations and recovery results are documented in [the 0.0.1 technical spike](../docs/TECH_SPIKE_0.0.1.md).

[The 0.7.0 read-only probes](0.7.0/README.md) inspect position interfaces and
scoped AX frames without providing a mutation path. The ordering implementation
gate did not pass; no position guarantee is added.

[The 0.8.0 research](0.8.0/README.md) enumerates the exact macOS 27 private
system-item identifier catalog, validates dedicated Weather/Input Menu owners,
and models the separate Siri, Time Machine and Now Playing preference inverses.
Its shared-item probe has snapshot and pure-test modes only; it performs no
assertion activation, preference write, synchronization or notification.
The later product trial uses those reviewed inverses behind a current-build gate
to give Siri, Time Machine and Now Playing the same three policy states as the
assertion-backed items. The research executables remain read-only and are not
linked into the app.
