"""Unsupported read-only research; excluded from product targets.

Compare one exact position key in the ordinary and sandbox preference files
with defaults' effective read. No synchronization, writes, app launch or XPC
utilities request. Keep all output under ignored LocalData.
"""
import hashlib
import json
from pathlib import Path
import plistlib
import re
import signal
import subprocess
import sys


def main():
    signal.alarm(10)
    print("WARNING: unsupported read-only preference source comparison; mutations=0", file=sys.stderr)
    if len(sys.argv) != 3:
        raise SystemExit("Pass one exact bundle identifier and position key.")
    domain, key = sys.argv[1:]
    if not re.fullmatch(r"[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)+", domain):
        raise SystemExit("Invalid bundle identifier.")
    if not key.startswith("NSStatusItem Preferred Position ") or len(key) > 256:
        raise SystemExit("Only one explicit status-item position key is supported.")
    roots = {
        "ordinary-file": Path.home() / "Library/Preferences",
        "sandbox-file": Path.home() / "Library/Containers" / domain / "Data/Library/Preferences",
    }
    records = []
    for label, root in roots.items():
        path = root / (domain + ".plist")
        record = {"source": label}
        try:
            if path.stat().st_size > 4 * 1024 * 1024:
                raise ValueError("Preference file exceeds read bound.")
            with path.open("rb") as stream:
                raw = stream.read(4 * 1024 * 1024 + 1)
            if len(raw) > 4 * 1024 * 1024:
                raise ValueError("Preference file exceeds read bound.")
            data = plistlib.loads(raw)
            value = data.get(key)
            if value is not None and (isinstance(value, bool) or not isinstance(value, (int, float))):
                raise ValueError("Position value is not numeric.")
            record.update(present=key in data, value=value, sha256=hashlib.sha256(raw).hexdigest())
        except FileNotFoundError:
            record["fileAbsent"] = True
        except (PermissionError, ValueError, plistlib.InvalidFileException) as error:
            record["error"] = type(error).__name__
        records.append(record)
    # Explicit argument vector: no shell expansion, target launch or preference write.
    result = subprocess.run(
        ["/usr/bin/defaults", "read", domain, key],
        capture_output=True, text=True, timeout=5, check=False,
    )
    records.append({"source": "defaults-read", "exitCode": result.returncode,
                    "output": result.stdout.strip()[:256]})
    print(json.dumps({"bundle": domain, "key": key, "records": records,
                      "liveAppValueProven": False, "mutations": 0}, indent=2, allow_nan=False))


if __name__ == "__main__":
    main()
