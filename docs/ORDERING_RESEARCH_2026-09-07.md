# External ordering verification, 2026-09-07

Subsequent identity correction, 2026-09-08: the system key builder also has an
executable-basename fallback. The newer two-owner fixture was directly observed
to collide on that fallback; see [the correction](ORDERING_RESEARCH_2026-09-08.md#system-log-identity-correction).
The external trials below did not verify their actual system keys in agent
logs. Their failed ordering observations therefore do not demonstrate that
writes to the correct, independently identified keys are ineffective. The
corrected September 8 external experiment subsequently passed a swap and exact
inverse for the two original test owners, without width changes or synthetic
input; the linked report contains that positive evidence and its limits.


Follow-up: [the 2026-09-08 adoption control](ORDERING_RESEARCH_2026-09-08.md)
separates owner-position sends, width refresh and recreation. Its positive swap
control failed, so no further external position-table write was attempted.

Status: **The tested external preference-write route did not pass a controlled
swap-and-inverse verification. No product ordering implementation is promoted.**
This is an unreleased research update, not a version closure. The owner narrowed
the investigation to ordering; native overflow ownership was not investigated
or changed in this pass.

## Correction to the preference-store evidence

Earlier absence results for ordinary `com.apple.MenuBarAgent` preferences did
not establish that the system had no global position table. On macOS 27.0 build
`26A5425a`, the retained Apple image provides more specific evidence:

- The main constructor creates `NSUserDefaults` with suite `com.apple.MenuBar`
  and supplies it to the settings controller. The controller retains that
  defaults object; standard defaults also participate in a startup migration.
- The position decoder asks for the literal `TrailingItemPreferredPositions`.
  This particular key does not receive the prefix used for other menu settings.
- The installed agent has the `com.apple.MenuBar` application-group entitlement.
  Its associated group preference file contains a numeric position table with
  47 existing entries, despite absence in the ordinary domains examined earlier.
- Explicit-container CFPreferences and an independently constructed
  explicit-container `NSUserDefaults` read the same dictionary. Current-user,
  any-host access finds it; the tested any-user access does not.

The group-relative file is
`com.apple.MenuBar/Library/Preferences/com.apple.MenuBar.plist` under the user's
Library Group Containers directory. This identifies a materially better store
candidate and corrects the earlier absence inference. It does **not** constitute
an observation of the running agent consuming an external change.

The ordinary agent-domain experiment's historical visible self-placement is not
erased by this correction. Its mechanism cannot be assumed to be identical to
this build's suite-backed settings path. Historical owner-preference values,
ordinary domains, and group overrides must be kept distinct.

## Static ordering and identity evidence

Apple's retained arm64 image has SHA-256
`a702b2a3e8007c12ba6d056a07f8ca1d2bcb383dbed7712553857174fba6b9c8`.
The following are unslid addresses in that image:

| Evidence | Address |
| --- | --- |
| Construct the `com.apple.MenuBar` suite and pass it to settings | `0x1000030e8`, `0x100003110`, `0x100003154` |
| Retain the defaults object in the settings controller | `0x1002dcb10` |
| Decode the unprefixed position dictionary | `0x10033d104`, `0x100340d9c` |
| Merge configured positions with missing legacy owner positions | `0x10025e558` |
| Build the `status:<bundle>::<persistent identifier>` key | `0x10028433c` |
| Partition items using persisted positions | `0x10022ac14` |
| Compare preferred trailing distances | `0x10022d4a0` |
| Merge persisted items with the remaining sized displayables | `0x100222514` |

The persisted numeric value feeds a real comparison and insertion algorithm.
It is not a public absolute-X or universal rank setter. Category, width, and
visibility processing also affect the final layout. The complete current-space
dataflow and invalidation contract remain unverified.

Read-only inspection of AppKit in the research process also follows
`NSSceneStatusItem` client settings into the host: `autosaveName` becomes the
host's persistent identifier, and the client's saved preferred position becomes
the host's preferred position. This supports using the explicit test autosave
identity. It is static contract evidence, not a live read of another process's
private host object. The owner's `_currentPreferredPosition` getter returned
zero in these probes and was not used as the physical-position measurement.

## Controlled experiment

Two original temporary accessory applications each created one AppKit status
item. They had separate bundle identities, the explicit autosave name
`OrderingProbe`, and distinct owner saved positions of 120 and 160. An external
controller performed the position-table writes. Owner window frames and a
separate Accessibility reader supplied the geometry observations.

Only the two temporary identities were written. Existing table entries were
preserved with their original property-list values. Before every transition,
the writer checked the complete expected dictionary, exact two-key scope,
numeric validity, and owner PIDs. It recorded intent before writing, verified
the result once, and refused repeated phase receipts or unexpected state.
Cleanup removed the temporary applications' items and preferences, then removed
only their two group-table entries. No existing application was a write target.

The experiments separated several different failure hypotheses:

| Test | Observation |
| --- | --- |
| Ordinary agent domain | Readback succeeded; no verified swap |
| Ordinary menu-bar domain | Readback succeeded; shared geometry shifted, but relative order did not swap |
| Explicit group container through CFPreferences | Readback succeeded; no verified swap |
| Explicit group container through Foundation, with independent KVO observer | Observer received the table's 47-to-49-to-47 transitions; no demonstrated agent adoption |
| Widely separated values, 20 and 1100, exchanged between the two test keys | No immediate relative-order change at the bounded observation |
| Recreate only the test items while the swapped values remain present | No verified controlled swap |

An initial recreation probe was invalid: AppKit removed the owner's saved
position when removing its status item. Both new items then reported an unset
saved position and coincident frames. That observation was excluded. The
corrected fixture restored each owner's 120/160 seed before every creation and
verified those values after recreation.

The final corrected sequence is particularly important. X coordinates below are
AppKit owner-window observations; the separate AX samples corroborated the
relative order, with the expected inset for each button:

| Phase | Table values A / B | Window X, A / B | Finding |
| --- | --- | --- | --- |
| Initial creation | Both absent | 1319 / 1359 | A left of B |
| Explicit baseline, after 6 seconds | 20 / 1100 | 1319 / 1359 | No change |
| Applied swap, after 6 seconds | 1100 / 20 | 1319 / 1359 | No change |
| Recreated test items, after 6 seconds | 1100 / 20 | 1319 / 1359 | No change; owner seeds still 120 / 160 |
| Restored baseline and recreated test items | 20 / 1100 | 1321 / 1281 | Relative order changed at this later stage |

The final row is not a successful inverse: the baseline order was never
established from the written values, the apply did not visibly swap it, and the
later recreation changed the order. Delayed adoption, creation ordering,
unobserved host state, or another layout input have not been isolated. The
result therefore rejects a claim of deterministic external control, while also
preventing the stronger claim that the table can never influence layout.
The 6-second observations, and earlier 12-second observations, are bounded
samples; they do not establish behavior at every possible later time.

## Restoration and verification

- The final complete group property list was logically equal to its saved
  pre-experiment value, including all 47 original position entries and unrelated
  settings. This is property-list equality, not a byte-for-byte file comparison.
- Both temporary owners had exited; their preference domains and their two
  position-table entries were absent. A fresh preflight check passed.
- The test writer passed 12 scope/transition checks and three preservation and
  inverse checks. These establish helper checks, not physical sorting success.
- The scratch helpers and applications were built explicitly with Xcode 27 and
  SDK 27. Product code and build targets were unchanged, so product tests were
  not rerun for this research-only update.
- The installed Blenny executable retained SHA-256
  `8795e401166f8efb5ab7e19a19d25aeff420340db1fe4e49f07ee55262e37768`.
- No pointer movement, synthetic input, process injection, private entitlement,
  permission change, system-process restart, or feature-flag change was used.
  Physical restoration of the complete unrelated menu bar was not established
  merely by preference equality.

Raw receipts, exact snapshots, scratch sources, local binaries, AX readings,
and disassembly remain ignored under
`LocalData/2026-09-07-ordering-verification/` and the earlier
`LocalData/2026-09-06-order-overflow/` evidence directory. They are not a supported
or distributable ordering tool. No raw inventory or system backup is tracked.

## Engineering conclusion

There is concrete private sorting machinery and a reachable persisted table.
The ordinary-domain absence argument was incorrect. However, successful storage
and notification do not provide a proven live external reorder contract.
This build has not passed even the two-test-owner swap-and-inverse gate, so
Blenny cannot promote this technique to existing third-party applications.

The remaining research question is precise: how does the running agent adopt
this suite's external update and invalidate the relevant current-space layout,
and how can that adoption be observed? Additional guessed weights or repeated
writes to existing applications do not answer it. A later investigation needs
a positive adoption signal or a causal timing control before another target
experiment. This is a no-go for the tested implementation, not proof that every
private API approach is impossible.
