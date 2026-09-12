# Blenny 0.9.0 release record

Status: complete on 2026-09-12; local milestone tag `v0.9.0`.
This is a local experimental engineering milestone, not public distribution.

## Accepted scope

- Real configuration-backed ordering in the existing Organize Board, through the
  existing serial coordinator, combined with Visible / Revealable / Hidden intent.
- Whole-owner configured key groups, preview, stale-state checks, durable recovery,
  scoped inverse and preservation of unrelated external changes.
- Accepted order persists through Stop/Quit; explicit Undo remains separate.
- Owner-reported working third-party ordering and combined area/order changes,
  including Weather/Input Menu, plus corrected repeated drag and Stop/Resume flows.
- Owner-reported responsive system visibility, including Siri and Time Machine.

The owner accepts the native Clock action as a known limitation; the trackpad
right-edge swipe opens Notification Center during management on the tested setup.
No automatic Stop/Resume is used. Siri, Time Machine and Control Center sorting
are deferred, with existing mapped visibility retained. Native-arrow adjacency,
absolute coordinates, general multi-display support and unknown runtime support
are not promised by this milestone.

## Evidence classification

Historical attended research proves the scoped pair swap and exact preference
inverse. Later owner-operated product feedback establishes the reported behavior;
it is not a comprehensive hardware/lifecycle matrix. Automated tests use fixtures
and isolated temporary data. The release inspection does not perform a new real
third-party or system-item mutation and does not restore accepted user ordering.

Fresh Xcode 27 / macOS 27 SDK verification on 2026-09-12:

| Configuration | Automated tests | App build | Interface-model check |
| --- | --- | --- | --- |
| Debug | 560 tests / 50 suites passed | passed | passed |
| Ordinary Release | 315 tests / 32 suites passed | passed | excluded by design |
| Optimized ordering trial | 560 tests / 50 suites passed | passed | passed |

All three test builds report zero warnings and errors. The separate research
Python suite passes 44 tests. These are deterministic/isolated checks, not new
live mutation evidence. All applications identify as 0.9.0, arm64, minimum macOS
27.0, SDK 27.0, and pass strict ad-hoc signature verification. Following the owner's
license deferral, all three app packages were rebuilt without LICENSE and NOTICE.
Product source is unchanged and the test results above remain applicable.
This is not Developer ID signing or
notarization, which remains distribution work.

The ordinary Release executable excludes the ordering table key and Debug
ordering self-check entry; both are present in the explicit trial builds. Existing
pre-0.9 visibility support still contains its private assessment contract, so no
claim is made that Release contains no private functionality whatsoever.

The final read-only runtime audit finds a clean, applied,
configuration-verified Undo ledger, no pending ordering values/policy rollback,
no known shared-system receipts and no policy transaction markers. Blenny was
confirmed by the owner to be already stopped. Saved `managementEnabled` values
and a running process do not establish active restrictions; an earlier inference
that another Stop was required was incorrect. The final scoped reread confirms
no pending receipts or transaction markers. Stopped runtime state is owner-attested,
not direct inspection of the private assertion. Accepted user order remains intact.
See the version spike for historical attended restoration and owner acceptance.

## Source and publication

One canonical repository is retained. License adoption and resource packaging
remain follow-up work after the 0.10.0 interface review. The 0.9.0 Git tree and
app packages contain no LICENSE or NOTICE; owner-only drafts may remain locally
excluded. Research source and sanitized conclusions remain in the repository;
raw evidence and Chinese owner notes remain private and ignored. Historical
research failures remain labeled rather than erased.

Version 0.10.0 focuses on interface, copy and usability refinement. Public source
and signed binaries remain scheduled together for 0.11.0, retaining every
licensing, signing, distribution, lifecycle and display acceptance gate.

The owner authorized organizing only the unpublished 0.9.0 commits into research,
product implementation with tests, and milestone documentation. The original
first commit and all history through v0.8.0 are preserved. No push, publication
or repository visibility change is authorized; exact remote refs require separate
approval.
