"""One-shot read-only real-owner capture. Raw identity evidence stays local."""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import time
from identity import associate, parse_key


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument("--reader", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    os.umask(0o077)
    root = args.output.resolve()
    root.mkdir(parents=True, exist_ok=False)
    group = Path.home() / "Library/Group Containers/com.apple.MenuBar/Library/Preferences/com.apple.MenuBar.plist"
    original = group.read_bytes()
    before = plistlib.loads(original)
    table = before["TrailingItemPreferredPositions"]
    (root / "group-before.plist").write_bytes(original)
    window_start = time.time() - 60
    predicate = 'process == "MenuBarAgent" AND eventMessage CONTAINS "Using legacy NSStatusItemHost"'
    output = subprocess.run(["/usr/bin/log", "show", "--last", "60s", "--style", "json", "--predicate", predicate],
                            capture_output=True, text=True, timeout=20, check=True).stdout
    (root / "legacy-log.json").write_text(output)
    events = []
    for event in json.loads(output):
        match = re.search(r"Using legacy NSStatusItemHost preferredPosition ([0-9.]+) for (status:[^\r\n]+)$", event.get("eventMessage", ""))
        if not match or not parse_key(match[2]):
            continue
        timestamp = datetime.fromisoformat(event["timestamp"]).timestamp()
        events.append({"key": match[2], "value": float(match[1]), "time": timestamp})
    events.sort(key=lambda event: event["time"])
    all_keys = set(table) | {event["key"] for event in events}
    tokens = sorted({parsed[0] for key in all_keys if (parsed := parse_key(key))})
    token_file = root / "owner-tokens.json"
    token_file.write_text(json.dumps(tokens))
    raw = subprocess.run([str(args.reader.resolve()), str(token_file)], capture_output=True, text=True, check=True, timeout=18).stdout
    owners = json.loads(raw)
    (root / "owners.json").write_text(raw)
    current_bytes = group.read_bytes()
    snapshot = {"schemaVersion": 1, "table": table, "events": events, "owners": owners,
                "windowStart": window_start, "capturedAt": time.time(),
                "groupUnchanged": plistlib.loads(current_bytes) == before,
                "groupBeforeSHA256": hashlib.sha256(original).hexdigest(),
                "groupAfterSHA256": hashlib.sha256(current_bytes).hexdigest()}
    (root / "snapshot.json").write_text(json.dumps(snapshot, indent=2))
    result = associate(snapshot)
    (root / "identity-result.json").write_text(json.dumps(result, indent=2))
    print(json.dumps({"mutations": 0, "groupUnchanged": snapshot["groupUnchanged"], **result["counts"]}))


if __name__ == "__main__":
    run()
