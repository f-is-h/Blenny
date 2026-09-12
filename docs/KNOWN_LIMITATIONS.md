# Known limitations

## Experimental ordering scope

Version 0.9.0 ordering is available in Debug and the explicitly enabled optimized
owner-test build on the admitted macOS 27 runtime. Ordinary Release excludes it.
It is not a general guarantee for every application, monitor or future OS build.
Unknown identities and incomplete owner scope remain unsupported.

Siri, Time Machine and Control Center sorting is deferred. Their mapped three-state
visibility controls remain available in the experimental configuration; visibility
support does not imply ordering support. Clock and native overflow stay read-only.

Exact adjacency of the native overflow arrow and Blenny's controls is not
guaranteed. Preferred positions express relative order rather than fixed pixels.
Accepted order persists through Stop and Quit; those actions release concealment,
so they do not guarantee continued invisibility or arrow-relative placement.

## Clock cannot open Notification Center during management

On macOS 27.0 build `26A5425a`, clicking the native menu-bar Clock does not open
Notification Center while Blenny management is active. Blenny's assessment-based
hiding backend activates a system restriction state. ControlCenter responds by
ignoring Clock menu events before they can request Notification Center. The Clock
is already included in the visibility allowlist, so
this is not an ordering failure or a missing-permission condition.

The owner confirms that **swiping left from the right edge of the trackpad opens
Notification Center while Blenny management remains active**, even when Clock
clicks do not. Use this gesture on the tested setup; stopping management is not
required. This is owner-operated verification, not an automated test or a claim
about every hardware configuration or macOS build.

The failure is specific to the native Clock entry in this observation; it does
not mean Notification Center is generally unavailable. Static inspection locates
the suppression in ControlCenter's Clock event handler before its menu XPC
request. The complete gesture implementation has not been statically traced.

Blenny will not stop and resume management around Clock clicks. The owner
explicitly rejects that approach because it would release hiding restrictions.
Manual Stop remains an ordinary user control, not the proposed Clock repair.

The owner accepts this as a known limitation for `0.9.0`, so it is no longer by
itself a mandatory-fix blocker for that milestone. It is not a repair, version
closure, release permission, or a broader compatibility claim. Distribution and
public release still require the complete compatibility, recovery, disclosure,
privacy, signing, and repository gates in the roadmap and repository policy.

See the [final technical report](NOTIFICATION_CENTER_TECHNICAL_REPORT_2026-09-12.md)
for the exact cause and the [investigation record](NOTIFICATION_CENTER_RESEARCH_2026-09-12.md)
for the bounded searches and rejected alternatives. No compatible repair was
found in the final round; further parameter and delay trials are deferred beyond
0.9.0 unless new backend evidence changes the premises.
