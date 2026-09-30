#!/usr/bin/env python3
"""Mount a distribution DMG read-only, verify it, and always detach it."""
import argparse
import hashlib
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def contents(root):
    result = {}
    for directory, directories, files in os.walk(root, followlinks=False):
        for name in sorted(directories + files):
            path = Path(directory) / name
            relative = path.relative_to(root).as_posix()
            if path.is_symlink():
                result[relative] = ("link", os.readlink(path))
            elif path.is_file():
                result[relative] = ("file", hashlib.sha256(path.read_bytes()).hexdigest(), path.stat().st_mode & 0o777)
    return result


def verify(archive, expected_app=None):
    subprocess.run(["hdiutil", "verify", str(archive)], check=True, stdout=subprocess.DEVNULL)
    with tempfile.TemporaryDirectory(prefix="blenny-readonly-dmg-") as directory:
        mount = Path(directory) / "mount"
        mount.mkdir()
        attached = subprocess.check_output(["hdiutil", "attach", "-readonly", "-nobrowse", "-plist", "-mountpoint", str(mount), str(archive)])
        try:
            entities = plistlib.loads(attached)["system-entities"]
            mounted = [e for e in entities if e.get("mount-point")]
            if len(mounted) != 1 or Path(mounted[0]["mount-point"]).resolve() != mount.resolve():
                raise ValueError("Unexpected DMG mount scope")
            app = mount / "Blenny.app"
            if not app.is_dir() or not (mount / "Applications").is_symlink() or os.readlink(mount / "Applications") != "/Applications":
                raise ValueError("DMG must contain Blenny.app and the Applications link")
            subprocess.run(["zsh", str(ROOT / "scripts/verify-distribution.sh"), str(app)], check=True)
            if expected_app is not None and contents(app) != contents(expected_app):
                raise ValueError("Mounted app differs from the signed source app")
        finally:
            # Detach by our mountpoint even when response parsing/validation fails.
            subprocess.run(["hdiutil", "detach", "-quiet", str(mount)], check=True)
    print("Read-only DMG contents, resources and signature: PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--expected-app", type=Path)
    args = parser.parse_args()
    verify(args.archive, args.expected_app)
