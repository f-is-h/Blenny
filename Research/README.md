# Blenny research

This directory contains source snapshots from bounded engineering experiments.
It is versioned for reproducibility and historical review, but it is not part of
any Blenny product target. Research code is archived and unsupported; current
product behavior is defined by [the project brief](../PROJECT_BRIEF.md),
[the roadmap](../docs/ROADMAP.md) and the relevant technical spike.

## Index

- `0.0.1/` preserves the initial macOS 27 feasibility probes. Conclusions and
  recovery boundaries are in
  [the 0.0.1 technical spike](../docs/TECH_SPIKE_0.0.1.md).
- [`0.7.0/`](0.7.0/README.md) contains read-only ordering and Accessibility
  probes from the earlier no-go investigation. Later evidence superseded the
  broad no-go; the original results remain useful historical evidence.
- [`0.8.0/`](0.8.0/README.md) records system-item identity, ABI and inverse-model
  research. The probes remain separate from product targets.
- [`0.13.0/`](0.13.0/README.md) contains original read-only host-identity and
  sandbox-path probes, plus bounded owned-file comparisons with exact cleanup.
  It creates no status items and cannot establish physical Resume visibility.
- [`OrderingAdoptionProbe/`](OrderingAdoptionProbe/README.md) is the archived
  build-specific ordering experiment. It can perform real preference mutation;
  its own snapshot, authorization and exact-inverse requirements apply to every
  run. It is not a general ordering utility.
- [`NotificationCenterCompatibilityProbe/`](NotificationCenterCompatibilityProbe/README.md)
  is the read-only Clock and Notification Center compatibility investigation.
  Apple binaries, disassembly and local runtime captures are not distributed.

The current 0.9.0 product contract and the distinction between Debug, optimized
trial and ordinary Release are in
[the 0.9.0 technical spike](../docs/TECH_SPIKE_0.9.0.md). Dated candidate reports
formerly held in the top-level README are preserved in
[historical development notes](../docs/HISTORICAL_DEVELOPMENT_NOTES.md).

## Safety boundary

- The probes may reference unsupported private macOS behavior.
- They are specific to the recorded macOS build and can stop working without notice.
- They must fail closed when expected runtime classes, selectors, or encodings differ.
- Mutation probes must have an explicit time bound and restore path.
- Do not run a probe against a critical system item or an unapproved third-party application.
- Do not package or distribute these probes as product components.

Generated applications, executables, logs, screenshots, system-state backups, and build caches belong in ignored `LocalData/`, not here.

## Reproduction tooling

Follow the README inside each experiment before building or running it. Commands
that use `rtk` require the external RTK command proxy; use `rtk proxy` when exact,
unfiltered output is required for comparison or documentation. RTK is development
tooling and is not linked into Blenny.

Every experiment is tied to its recorded runtime and target scope. Reacquire
identity and state before relying on an old result. A historical successful run
does not authorize a new mutation, establish general compatibility or make the
probe supported product code.
