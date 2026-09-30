#!/usr/bin/env python3
"""Check the published app's Sparkle feed in a fresh hosted Mac, without a manager."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import urllib.request

from release_tools import ROOT, REPOSITORY, marketing_version, write_json


def main():
    if os.getenv("GITHUB_ACTIONS") != "true" or os.getenv("GITHUB_REPOSITORY") != REPOSITORY:
        raise ValueError("Run only in the fresh hosted verification job")
    version = marketing_version()
    url = f"https://github.com/{REPOSITORY}/releases/download/v{version}/Blenny-{version}.dmg"
    receipt_url = f"https://github.com/{REPOSITORY}/releases/download/v{version}/Blenny-{version}.receipt.json"
    with urllib.request.urlopen(receipt_url, timeout=60) as response:
        receipt = json.load(response)
    if receipt["sourceCommit"] != os.getenv("BLENNY_RELEASE_SOURCE_SHA", os.environ["GITHUB_SHA"]) or receipt["version"] != version:
        raise ValueError("Public receipt differs from the released source")
    output = ROOT / "LocalData/hosted-update"
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="blenny-hosted-info-") as temp:
        root = Path(temp)
        archive = root / f"Blenny-{version}.dmg"
        with urllib.request.urlopen(url, timeout=60) as response:
            archive.write_bytes(response.read())
        if hashlib.sha256(archive.read_bytes()).hexdigest() != receipt["sha256"] or archive.stat().st_size != receipt["length"]:
            raise ValueError("Public downloaded archive does not match its receipt")
        spec = importlib.util.spec_from_file_location("verify_artifact", ROOT / "scripts/verify-artifact.py")
        verifier = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(verifier)
        public_key = plistlib.loads((ROOT / "Config/Info.plist").read_bytes())["SUPublicEDKey"]
        verifier.verify_signature(archive, receipt["edSignature"], public_key)
        mounted = plistlib.loads(subprocess.check_output(["hdiutil", "attach", "-readonly", "-nobrowse", "-plist", str(archive)]))
        entity = next(e for e in mounted["system-entities"] if "mount-point" in e)
        app = root / "Blenny.app"
        try:
            subprocess.run(["zsh", str(ROOT / "scripts/verify-distribution.sh"), str(Path(entity["mount-point"]) / "Blenny.app")], check=True)
            subprocess.run(["ditto", str(Path(entity["mount-point"]) / "Blenny.app"), str(app)], check=True)
        finally:
            subprocess.run(["hdiutil", "detach", "-quiet", entity["dev-entry"]], check=True)
        frameworks = app / "Contents/Frameworks"
        binary = root / "feed-probe"
        subprocess.run(["xcrun", "clang", "-fobjc-arc", "-Werror", "-mmacosx-version-min=27.0", "-F", str(frameworks),
                        "-framework", "AppKit", "-framework", "Sparkle", "-Wl,-rpath," + str(frameworks),
                        str(ROOT / "scripts/hosted-update-check.m"), "-o", str(binary)], check=True)
        subprocess.run([str(binary), str(app), receipt["build"], version, url, str(receipt["length"])], check=True, timeout=60)
    write_json(output / "result.json", dict(version=version, sourceCommit=receipt["sourceCommit"],
                                            hostedUpdateInformationVerified=True, hostedInstallRelaunchVerified=False))


if __name__ == "__main__":
    main()
