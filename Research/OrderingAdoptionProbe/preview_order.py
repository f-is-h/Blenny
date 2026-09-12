"""Offline swap/restore planning for Debug integration. No system writer."""
import argparse
import copy
import hashlib
import json
import math
import os
from pathlib import Path
from identity import associate


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()


def make_plan(snapshot, bundles):
    assert len(bundles) == 2 and len(set(bundles)) == 2, "select two distinct owning bundles"
    result = associate(snapshot)
    selected = []
    for bundle in bundles:
        rows = [row for row in result["rows"] if row["owner"] and row["owner"]["bundle"] == bundle]
        assert len(rows) == 1, "entire bundle key set is not single and unambiguous"
        row = rows[0]
        assert row["reviewCandidate"] or row["configuredReviewCandidate"], "insufficient identity evidence"
        assert not row["owner"]["system"], "system owner excluded"
        old = snapshot["table"].get(row["key"])
        position = old if row["key"] in snapshot["table"] else row["freshLegacyInput"]
        assert type(position) in (int, float) and math.isfinite(position) and position > 0, "unsupported position"
        selected.append({"bundle": bundle, "key": row["key"], "pid": row["owner"]["pid"],
                         "launchTime": row["owner"]["launchTime"], "name": row["owner"].get("name"),
                         "before": {"present": row["key"] in snapshot["table"], "value": old},
                         "effectiveInput": position,
                         "identityEvidence": "recent-legacy-log" if row["reviewCandidate"] else "configured-key-autosave-AX-corroboration"})
    assert selected[0]["key"] != selected[1]["key"], "key collision"
    assert selected[0]["effectiveInput"] != selected[1]["effectiveInput"], "equal positions are not a swap"
    selected[0]["after"] = selected[1]["effectiveInput"]
    selected[1]["after"] = selected[0]["effectiveInput"]
    plan = {"schemaVersion": 1, "previewOnly": True, "writeAuthorized": False,
            "capturedAt": snapshot["capturedAt"], "baselineTableFingerprint": fingerprint(snapshot["table"]),
            "targets": selected,
            "requiredBeforeExecution": ["Explicit authorization of the exact third-party bundles.",
                                        "Fresh unchanged process, identity, AX and group-state checks.",
                                        "Single serial backend with receipt-backed inverse and bounded verification.",
                                        "Attended validation of real icon identity and restored layout."]}
    plan["fingerprint"] = fingerprint(plan)
    return plan


def transition(plan, current, phase):
    """Pure plan evaluator, not an execution capability or authorization token."""
    payload = {k: v for k, v in plan.items() if k != "fingerprint"}
    assert fingerprint(payload) == plan["fingerprint"], "plan changed"
    assert plan["schemaVersion"] == 1 and plan["previewOnly"] and not plan["writeAuthorized"]
    assert phase in ["apply", "restore"]
    if phase == "apply":
        assert fingerprint(current) == plan["baselineTableFingerprint"], "stale baseline"
    next_table = copy.deepcopy(current)
    for target in plan["targets"]:
        key, before = target["key"], target["before"]
        original = (key in current and before["present"]
                    and type(current[key]) is type(before["value"]) and current[key] == before["value"]
                    or key not in current and not before["present"])
        applied = key in current and type(current[key]) is type(target["after"]) and current[key] == target["after"]
        assert original or phase == "restore" and applied, "target drift"
        if phase == "apply":
            next_table[key] = target["after"]
        elif before["present"]:
            next_table[key] = before["value"]
        else:
            next_table.pop(key, None)
    return next_table


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("snapshot", type=Path)
    parser.add_argument("--bundles", nargs=2, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    os.umask(0o077)
    snapshot = json.loads(args.snapshot.read_text())
    plan = make_plan(snapshot, args.bundles)
    proposed = transition(plan, snapshot["table"], "apply")
    assert transition(plan, proposed, "restore") == snapshot["table"], "inverse mismatch"
    with args.output.open("x") as output:
        json.dump(plan, output, indent=2)
    print("Offline preview and inverse passed; system reads=0, writes=0, authorization=false")
