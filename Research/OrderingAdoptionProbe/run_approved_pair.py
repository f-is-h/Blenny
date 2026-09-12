"""One owner-authorized pair trial, bounded observation, and receipt-backed inverse."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import time

BUNDLES = ["com.Snipaste", "xyz.fi5h.Usage4Claude"]


def call(arguments):
    return subprocess.run(list(map(str, arguments)), capture_output=True, text=True, check=True, timeout=18).stdout


def save(root, name, value):
    (root / name).write_text(json.dumps(value, indent=2) + "\n")


def restore_once(root, writer):
    receipt = root / "external-restore.json"
    if receipt.exists():
        if not json.loads(receipt.read_text()).get("completed"):
            raise RuntimeError("inverse already attempted without completion; inspect, do not retry blindly")
        return
    if (root / "external-apply.json").exists():
        call([writer, root, "restore"])
        if not json.loads(receipt.read_text()).get("completed"):
            raise RuntimeError("inverse incomplete")


def capture_ax(root, reader, phase, pids):
    output = call([reader, *BUNDLES])
    (root / (phase + "-ax.log")).write_text(output)
    if "DONE complete=true" not in output:
        raise RuntimeError("incomplete AX observation")
    rows = [json.loads(line) for line in output.splitlines() if line.startswith("{")]
    if len(rows) != 2 or {row["bundle"] for row in rows} != set(BUNDLES):
        raise RuntimeError("AX bundle coverage differs")
    by_bundle = {row["bundle"]: row for row in rows}
    if any(by_bundle[bundle]["ownerPID"] != pids[bundle] for bundle in BUNDLES):
        raise RuntimeError("AX process differs")
    if abs(by_bundle[BUNDLES[0]]["x"] - by_bundle[BUNDLES[1]]["x"]) < 20:
        raise RuntimeError("coincident or unstable target geometry")
    return by_bundle


def execute(root, writer, reader, owner_reader, hold_seconds=65):
    group = Path.home() / "Library/Group Containers/com.apple.MenuBar/Library/Preferences/com.apple.MenuBar.plist"
    before = plistlib.loads((root / "group-before.plist").read_bytes())
    snapshot = json.loads((root / "snapshot.json").read_text())
    pids = {app["bundle"]: app["pid"] for app in snapshot["owners"]["before"] if app["bundle"] in BUNDLES}
    result = {"errors": [], "samples": {}, "wholeGroupRestored": False, "ownerPreferencesRestored": False}
    if (root / "trial-result.json").exists():
        raise RuntimeError("use a fresh trial directory")
    save(root, "trial-result.json", result)
    try:
        if plistlib.loads(group.read_bytes()) != before:
            raise RuntimeError("group drift before initial observation")
        result["samples"]["initial"] = capture_ax(root, reader, "initial", pids)
        call([writer, root, "apply"])
        if not json.loads((root / "external-apply.json").read_text()).get("completed"):
            raise RuntimeError("apply incomplete")
        time.sleep(3)
        result["samples"]["swapped"] = capture_ax(root, reader, "swapped", pids)
        print("VISUAL_WINDOW: pair applied; observe Snipaste and Usage4Claude; automatic inverse after the bounded hold.", flush=True)
        save(root, "trial-result.json", result)
        time.sleep(hold_seconds)
    except Exception as error:
        result["errors"].append(str(error))
        print("STOP", str(error), flush=True)
    finally:
        try:
            restore_once(root, writer)
        except Exception as error:
            result["errors"].append("inverse: " + str(error))
        time.sleep(3)
        result["wholeGroupRestored"] = plistlib.loads(group.read_bytes()) == before
        try:
            result["samples"]["restored"] = capture_ax(root, reader, "restored", pids)
            raw = call([owner_reader, root / "owner-tokens.json"])
            (root / "owners-after.json").write_text(raw)
            owners_after = json.loads(raw)
            result["ownerPreferencesRestored"] = all(
                owners_after["ownerPreferences"].get(bundle) == snapshot["owners"]["ownerPreferences"].get(bundle)
                for bundle in BUNDLES
            )
        except Exception as error:
            result["errors"].append("final observation: " + str(error))
        samples = result["samples"]
        if all(phase in samples for phase in ["initial", "swapped", "restored"]):
            delta = lambda phase: samples[phase][BUNDLES[0]]["x"] - samples[phase][BUNDLES[1]]["x"]
            result["swapObserved"] = delta("initial") * delta("swapped") < 0
            result["inverseOrderObserved"] = delta("initial") * delta("restored") > 0
            result["exactAXGeometryRestored"] = all(
                all(samples["initial"][bundle][field] == samples["restored"][bundle][field] for field in ["x", "y", "width", "height"])
                for bundle in BUNDLES
            )
        save(root, "trial-result.json", result)
        print("FINAL", json.dumps({key: value for key, value in result.items() if key != "samples"}), flush=True)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--writer", type=Path, required=True)
    parser.add_argument("--reader", type=Path)
    parser.add_argument("--owner-reader", type=Path)
    parser.add_argument("--watchdog-deadline", type=float)
    args = parser.parse_args()
    os.umask(0o077)
    root, writer = args.artifacts.resolve(), args.writer.resolve()
    if args.watchdog_deadline is not None:
        # One independent deadline check, not polling or repeated recovery.
        time.sleep(max(0, args.watchdog_deadline - time.monotonic()))
        try:
            restore_once(root, writer)
            save(root, "watchdog-result.json", {"completed": True})
        except Exception as error:
            save(root, "watchdog-result.json", {"completed": False, "error": str(error)})
        sys.exit(0)
    if not args.reader or not args.owner_reader:
        parser.error("readers required")
    if (root / "watchdog-armed.json").exists():
        parser.error("trial already armed")
    deadline = time.monotonic() + 100
    with (root / "watchdog.log").open("x") as log:
        child = subprocess.Popen([sys.executable, __file__, "--artifacts", str(root), "--writer", str(writer),
                                  "--watchdog-deadline", str(deadline)], stdout=log, stderr=log, start_new_session=True)
    save(root, "watchdog-armed.json", {"pid": child.pid, "deadlineUptime": deadline})
    result = execute(root, writer, args.reader.resolve(), args.owner_reader.resolve())
    sys.exit(2 if result["errors"] or not result["wholeGroupRestored"] or not result["ownerPreferencesRestored"] else 0)
