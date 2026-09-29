#!/usr/bin/env python3
"""Bounded owned-bundle copies; no status item or system preference writer."""

import argparse
import hashlib
import json
import plistlib
import shutil
import subprocess
import tempfile
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path, required=True)
    parser.add_argument("--reader-pid", type=int, required=True)
    parser.add_argument("--evidence-directory", type=Path, required=True)
    args = parser.parse_args()
    repository = Path(__file__).resolve().parents[2]
    local_data = repository / "LocalData"
    evidence = args.evidence_directory.resolve()
    probe = args.probe.resolve()
    if not evidence.is_relative_to(local_data) or not probe.is_relative_to(local_data):
        parser.error("The compiled probe and all evidence must be under this repository's LocalData.")
    if not probe.is_file() or args.reader_pid <= 0:
        parser.error("An existing owned probe and positive MenuBarAgent PID are required.")
    if not (Path.home() / "Applications").is_dir():
        parser.error("This comparison requires an existing ~/Applications directory.")
    evidence.mkdir(parents=True, exist_ok=True)
    print("Unsupported research: creates four owned file copies, starts no status items, then removes the copies.")

    created = []
    temporary_root = None
    try:
        temporary_root = Path(tempfile.mkdtemp(prefix="blenny-resume-identity-", dir="/private/tmp"))
        name = "BlennyResumeIdentityProbe.app"
        packages = [evidence / name, Path("/Applications") / name,
                    Path.home() / "Applications" / name, temporary_root / name]
        for package in packages:
            if package.exists() or package.is_symlink():
                raise RuntimeError(f"Refusing a pre-existing path: {package}")
        original = packages[0]
        original.mkdir()
        created.append(original)
        executable_directory = original / "Contents" / "MacOS"
        executable_directory.mkdir(parents=True)
        shutil.copy2(probe, executable_directory / probe.name)
        (original / "Contents" / "Info.plist").write_bytes(plistlib.dumps({
            "CFBundleIdentifier": "xyz.fi5h.blenny.resume-identity-readonly",
            "CFBundleExecutable": probe.name,
            "CFBundleName": "Blenny Resume Identity Read-only Probe",
            "CFBundlePackageType": "APPL",
            "LSUIElement": True,
        }))
        for package in packages[1:]:
            package.mkdir()
            created.append(package)
            shutil.copytree(original, package, dirs_exist_ok=True)

        launches = []
        for package in packages:
            executable = package / "Contents" / "MacOS" / probe.name
            launch = subprocess.run([str(executable), "--own-bundle"], capture_output=True,
                                    text=True, timeout=15, check=True)
            launches.append({"result": json.loads(launch.stdout),
                             "executableSHA256": hashlib.sha256(executable.read_bytes()).hexdigest(),
                             "infoSHA256": hashlib.sha256((package / "Contents" / "Info.plist").read_bytes()).hexdigest()})
        if len({item["executableSHA256"] for item in launches}) != 1 or len({item["infoSHA256"] for item in launches}) != 1:
            raise RuntimeError("Copies differ; no path conclusion may be drawn.")
        query = subprocess.run([str(probe), "--reader-pid", str(args.reader_pid)] +
                               [str(package / "Contents" / "MacOS") for package in packages],
                               capture_output=True, text=True, timeout=15, check=True)
        result = {"launches": launches, "sandboxQueries": json.loads(query.stdout),
                  "launchStyle": "direct executable; no open or Launch Services registration",
                  "statusItemsCreated": 0}
        (evidence / "owned-copy-matrix.json").write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps(result, indent=2))
    finally:
        for package in reversed(created):
            shutil.rmtree(package)
        if temporary_root is not None:
            temporary_root.rmdir()
        cleanup = {"createdPackages": [str(package) for package in created],
                   "allCreatedPackagesRemoved": all(not package.exists() for package in created),
                   "temporaryRootRemoved": temporary_root is None or not temporary_root.exists()}
        (evidence / "owned-copy-cleanup.json").write_text(json.dumps(cleanup, indent=2) + "\n")
        print(json.dumps(cleanup, indent=2))


if __name__ == "__main__":
    main()
