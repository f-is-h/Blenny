"""Unsupported, bounded test-owner control with an explicit scoped external mode."""
import argparse
from datetime import datetime
import re
import json
import os
from pathlib import Path
import plistlib
import subprocess
import time


AUTOSAVES = ["AdoptionProbeA", "AdoptionProbeB"]


def adopted_inputs(output):
    """Read actual public log keys, never infer the system key from bundle ID."""
    rows = re.findall(r"Using legacy NSStatusItemHost preferredPosition ([0-9.]+) for (status:[^\s]+)", output)
    result = {}
    for autosave in AUTOSAVES:
        matching = [(key, float(value)) for value, key in rows if key.endswith("::" + autosave)]
        keys = {key for key, _ in matching}
        assert len(keys) == 1, "missing or ambiguous adopted identity: " + autosave
        result[autosave] = {"key": matching[-1][0], "value": matching[-1][1]}
    assert len({row["key"] for row in result.values()}) == 2, "system persistence identities collide"
    return result


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--reader", type=Path, required=True)
    parser.add_argument("--settings-only", action="store_true", help="Observe only the owner settings swap and inverse, without width changes or recreation")
    parser.add_argument("--snapshot-only", action="store_true", help="Create test items, read their initial scene identity, and clean up without position-change commands")
    parser.add_argument("--external", action="store_true", help="Write only the two log-verified test keys using the serial receipt-backed group writer; owner position preferences stay unchanged")
    args = parser.parse_args()
    assert not (args.external and args.snapshot_only), "external mode cannot be snapshot-only"
    os.umask(0o077)
    root = args.artifacts.resolve()
    executable = root / "probe"
    identities = ["xyz.fi5h.blenny.research.adoption20260908" + x for x in "ab"]
    group = Path.home() / "Library/Group Containers/com.apple.MenuBar/Library/Preferences/com.apple.MenuBar.plist"
    before = plistlib.loads(group.read_bytes())
    assert not any(any(token in key for token in ["adoption20260908", "AdoptionProbe", "OrderingAdoption"]) for key in before["TrailingItemPreferredPositions"])
    assert not (root / "control-result.json").exists(), "Use a fresh evidence directory"
    expected_group = before
    result = {"mode": "external" if args.external else "owner", "samples": {}, "errors": [], "externalTableWrites": 0, "adoption": {}}
    (root / "control-group-before.plist").write_bytes(group.read_bytes())

    def call(arguments, check=True):
        return subprocess.run([str(x) for x in arguments], check=check, capture_output=True, text=True, timeout=15)

    def command(identity, name):
        call([executable, "--signal", identity, name])
        time.sleep(0.6)
        if name != "stop":
            receipt = json.loads((root / (identity + "-" + name + ".json")).read_text())
            assert receipt.get("completed") is True, receipt
            assert receipt["bundle"] == identity
            return receipt

    def external(phase):
        nonlocal expected_group
        call([root / "group-writer", root, phase])
        receipt = json.loads((root / ("external-" + phase + ".json")).read_text())
        assert receipt.get("completed") is True, "external transition incomplete"
        result["externalTableWrites"] += receipt["writes"]
        expected_group = dict(before)
        if phase == "apply":
            expected_group["TrailingItemPreferredPositions"] = dict(before["TrailingItemPreferredPositions"])
            for autosave, value in zip(AUTOSAVES, [1000, 120]):
                key = result["adoption"]["initial"][autosave]["key"]
                expected_group["TrailingItemPreferredPositions"][key] = value

    def sample(name, expected):
        owners = [command(identity, name) for identity in identities]
        assert [owner["saved"] for owner in owners] == expected, owners
        assert [owner["autosave"] for owner in owners] == AUTOSAVES
        if result["samples"]:
            initial = result["samples"]["initial"]
            assert [x["pid"] for x in initial] == [x["pid"] for x in owners]
        result["samples"][name] = owners
        output = call([args.reader.resolve(), *identities]).stdout
        (root / (name + "-ax.log")).write_text(output)
        assert "DONE complete=true" in output, "AX read incomplete"
        assert plistlib.loads(group.read_bytes()) == expected_group, "group changed; stop the control"
        rows = [json.loads(line) for line in output.splitlines() if line.startswith("{")]
        assert len(rows) == 2 and {row["bundle"] for row in rows} == set(identities), "AX identity coverage differs"
        ax_by_owner = {row["bundle"]: row["x"] for row in rows}
        if name == "initial":
            owner_delta = owners[0]["frame"][0] - owners[1]["frame"][0]
            ax_delta = ax_by_owner[identities[0]] - ax_by_owner[identities[1]]
            assert abs(owner_delta) >= 20 and abs(ax_delta) >= 20 and owner_delta * ax_delta > 0, "initial owner/AX order is unstable or coincident"
        predicate = 'process == "MenuBarAgent" AND eventMessage CONTAINS "Using legacy NSStatusItemHost" AND eventMessage CONTAINS "AdoptionProbe"'
        log = call(["/usr/bin/log", "show", "--start", phase_start, "--style", "compact", "--predicate", predicate]).stdout
        (root / (name + "-adoption.log")).write_text(log)
        # The log is emitted on a merge, not on every scene-settings send.
        # No fresh merge log after a known identity is an observation, not a
        # reason to skip the planned inverse or confuse absence with rejection.
        adopted = None if name != "initial" and "Using legacy NSStatusItemHost" not in log else adopted_inputs(log)
        result["adoption"][name] = adopted
        if name == "initial":
            assert [adopted[a]["value"] for a in AUTOSAVES] == expected, "initial remote input differs"
        print("ADOPTED", adopted, flush=True)
        print(name, [(x["saved"], x.get("frame"), x["itemObject"]) for x in owners], flush=True)
        if any("scene" in owner for owner in owners):
            print("SCENES", [owner.get("scene") for owner in owners], flush=True)
        (root / "control-result.json").write_text(json.dumps(result, indent=2) + "\n")

    phase_start = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    call([executable, "--preflight"])
    try:
        for suffix in "AB":
            call(["/usr/bin/open", "-g", "-n", root / ("Adoption" + suffix + ".app"), "--args", "--owner", root])
        time.sleep(6)
        sample("initial", [120, 1000])
        if args.snapshot_only:
            assert [owner.get("scene", {}).get("clientAutosave") for owner in result["samples"]["initial"]] == AUTOSAVES, "scene autosave identity differs"
            return
        if args.settings_only:
            assert [owner.get("scene", {}).get("clientSaved") for owner in result["samples"]["initial"]] == [120, 1000], "scene input is unavailable or differs from owner values; stop before sending"
        for action, phase, expected in [
            ("swap", "swapped", [1000, 120]),
            ("nudge-swap", "nudged", [1000, 120]),
            ("restore", "restored", [120, 1000]),
            ("nudge-restore", "restore-nudged", [120, 1000]),
            ("recreate", "recreated", [120, 1000]),
        ]:
            if args.external and action == "recreate":
                continue
            if args.settings_only and action not in ["swap", "restore"]:
                continue
            phase_start = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            if args.external and action in ["swap", "restore"]:
                external("apply" if action == "swap" else "restore")
            else:
                for identity in identities:
                    command(identity, action)
            time.sleep(8)
            sample(phase, [120, 1000] if args.external else expected)
    except Exception as error:
        result["errors"].append(str(error))
        print("STOP", str(error), flush=True)
    finally:
        if args.external and (root / "external-apply.json").exists() and not (root / "external-restore.json").exists():
            try:
                external("restore")
            except Exception as error:
                result["errors"].append("external inverse: " + str(error))
        for identity in identities:
            try:
                command(identity, "stop")
            except Exception as error:
                result["errors"].append(str(error))
        time.sleep(2)
        clean = call([executable, "--preflight"], check=False)
        result["ownersCleaned"] = clean.returncode == 0
        result["wholeGroupLogicallyUnchanged"] = plistlib.loads(group.read_bytes()) == before
        (root / "control-result.json").write_text(json.dumps(result, indent=2) + "\n")
        print("FINAL", {k: v for k, v in result.items() if k != "samples"}, flush=True)
        if result["errors"] or not result["ownersCleaned"] or not result["wholeGroupLogicallyUnchanged"]:
            raise SystemExit(2)


if __name__ == "__main__":
    run()
