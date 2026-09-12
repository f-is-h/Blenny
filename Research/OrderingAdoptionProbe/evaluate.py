"""Read-only evaluation of independent owner/AX swap and inverse evidence."""
import argparse
import json
from pathlib import Path


def evaluate(root):
    result = json.loads((root / "control-result.json").read_text())
    phases = ["initial", "swapped", "restored"] if "nudged" not in result["samples"] else ["initial", "nudged", "restore-nudged"]
    identities = ["xyz.fi5h.blenny.research.adoption20260908" + suffix for suffix in "ab"]
    deltas, pids, coordinates = [], [], {}
    for phase in phases:
        owners = result["samples"][phase]
        assert [owner["bundle"] for owner in owners] == identities
        rows = [json.loads(line) for line in (root / (phase + "-ax.log")).read_text().splitlines() if line.startswith("{")]
        assert len(rows) == 2 and {row["bundle"] for row in rows} == set(identities)
        ax = {row["bundle"]: row["x"] for row in rows}
        owner_x = [owner["frame"][0] for owner in owners]
        ax_x = [ax[identity] for identity in identities]
        owner_delta, ax_delta = owner_x[0] - owner_x[1], ax_x[0] - ax_x[1]
        assert abs(owner_delta) >= 20 and abs(ax_delta) >= 20 and owner_delta * ax_delta > 0, "uncorroborated or coincident order"
        assert all(row["ownerPID"] == next(owner["pid"] for owner in owners if owner["bundle"] == row["bundle"]) for row in rows), "AX owner PID differs"
        deltas.append(owner_delta)
        pids.append([owner["pid"] for owner in owners])
        coordinates[phase] = {"ownerX": owner_x, "axX": ax_x}
    return {
        "swapObserved": deltas[0] * deltas[1] < 0,
        "inverseOrderObserved": deltas[0] * deltas[2] > 0,
        "sameOwnerProcesses": pids[0] == pids[1] == pids[2],
        "exactOwnerXRestored": coordinates["initial"]["ownerX"] == coordinates[phases[2]]["ownerX"],
        "ownersCleaned": result.get("ownersCleaned", False),
        "wholeGroupLogicallyUnchanged": result.get("wholeGroupLogicallyUnchanged", False),
        "executionErrors": result["errors"],
        "coordinates": coordinates,
        "limitation": "AX and window geometry establish relative order observations, not rendered visibility or general third-party compatibility.",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("artifacts", type=Path)
    args = parser.parse_args()
    print(json.dumps(evaluate(args.artifacts), indent=2))
