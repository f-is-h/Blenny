"""Pure, conservative owner association. A mapping never authorizes a write."""
from collections import Counter, defaultdict
import math


def parse_key(key):
    if not isinstance(key, str) or not key.startswith("status:") or key.count("::") != 1:
        return None
    owner, persistent = key[7:].split("::")
    if not owner or not persistent or any(ord(c) < 32 or ord(c) == 127 for c in key):
        return None
    return owner, persistent


def associate(snapshot):
    before, after = snapshot["owners"]["before"], snapshot["owners"]["after"]
    observations = snapshot["owners"]["observations"]
    table = snapshot["table"]
    events = snapshot["events"]
    keys = sorted(set(table) | {event["key"] for event in events})
    bundle_counts = Counter(app["bundle"] for app in before if app["bundle"])
    after_by_pid = {app["pid"]: app for app in after}
    rows, by_bundle = [], defaultdict(list)
    for key in keys:
        row = {"key": key, "source": "configured" if key in table else "legacy-log", "reasons": [], "owner": None}
        parsed = parse_key(key)
        if not parsed:
            row["reasons"].append("unsupported-key")
            rows.append(row)
            continue
        token, persistent = parsed
        matching = [app for app in before if token in (app["bundle"], app["executable"])]
        if len(matching) != 1:
            row["reasons"].append("owner-absent" if not matching else "owner-token-collision")
            rows.append(row)
            continue
        owner = matching[0]
        row["owner"] = owner
        row["persistentIdentifier"] = persistent
        row["matchedBy"] = "bundle" if token == owner["bundle"] else "executable"
        if not owner["bundle"] or bundle_counts[owner["bundle"]] != 1:
            row["reasons"].append("bundle-owner-ambiguous")
        if owner.get("system", True):
            row["reasons"].append("system-owner-excluded")
        fields = ["pid", "bundle", "executable", "launchTime", "system"]
        later = after_by_pid.get(owner["pid"], {})
        if not owner.get("launchTime") or any(owner.get(f) != later.get(f) for f in fields):
            row["reasons"].append("owner-lifetime-unverified")
        ax = observations.get(str(owner["pid"]), {})
        items = ax.get("items", [])
        if not ax.get("complete") or any(item.get("ownerPID") != owner["pid"] for item in items):
            row["reasons"].append("AX-incomplete")
        if len(items) != 1:
            row["reasons"].append("single-live-item-not-established")
        row["AXItemCount"] = len(items)
        owner_preferences = snapshot["owners"].get("ownerPreferences", {}).get(owner["bundle"], {})
        saved = owner_preferences.get("positions", {})
        # A configured override intentionally differs from the owner's legacy
        # position. Corroborate the exact autosave name, not numeric equality.
        row["savedAutosaveCorroboratesConfigured"] = (
            owner_preferences.get("keyListObserved", False)
            and owner_preferences.get("positionsComplete", False)
            and key in table and set(saved) == {persistent}
            and type(saved[persistent]) in (int, float)
            and math.isfinite(saved[persistent]) and saved[persistent] > 0
        )
        row["ownerSavedPosition"] = saved.get(persistent)
        fresh = [event for event in events if event["key"] == key
                 and max(snapshot["windowStart"], owner.get("launchTime") or math.inf) <= event["time"] <= snapshot["capturedAt"]]
        row["freshLegacyInput"] = fresh[-1]["value"] if fresh else None
        if not fresh:
            row["reasons"].append("no-current-lifetime-key-observation")
        if key in table and (type(table[key]) not in (int, float) or not math.isfinite(table[key]) or table[key] <= 0):
            row["reasons"].append("configured-position-contract-differs")
        if not snapshot["groupUnchanged"]:
            row["reasons"].append("group-drift-during-capture")
        rows.append(row)
        by_bundle[owner["bundle"]].append(row)
    # Never pick a convenient key from a multi-key owner or treat stale entries
    # as a complete live bundle group. Multi-item ordering needs separate proof.
    for group in by_bundle.values():
        if len(group) != 1:
            for row in group:
                row["reasons"].append("bundle-key-set-not-single")
    for row in rows:
        row["reviewCandidate"] = not row["reasons"]
        row["configuredReviewCandidate"] = (
            row["reasons"] == ["no-current-lifetime-key-observation"]
            and row.get("savedAutosaveCorroboratesConfigured", False)
        )
        row["writeAuthorized"] = False
    return {"schemaVersion": 1, "mutations": 0, "rows": rows,
            "counts": {"keys": len(rows), "ownerAssociated": sum(r["owner"] is not None for r in rows),
                       "reviewCandidates": sum(r["reviewCandidate"] for r in rows),
                       "configuredReviewCandidates": sum(r["configuredReviewCandidate"] for r in rows)},
            "limitations": ["Token association is not proof of arbitrary item ownership.",
                            "AX cardinality and recent logs provide corroboration, not a cross-process atomic identity snapshot.",
                            "Configured keys without current-lifetime logs may be stale; all results remain read-only."]}
