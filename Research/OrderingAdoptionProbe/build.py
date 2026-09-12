"""Build original Debug probes into an ignored artifact directory; never launch."""
import argparse
import os
from pathlib import Path
import plistlib
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--developer-dir", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
os.umask(0o077)
root = Path(__file__).resolve().parent
output = args.output.resolve()
assert not output.exists(), "Choose a new ignored output directory"
environment = dict(os.environ, DEVELOPER_DIR=str(args.developer_dir.resolve()))


def tool(*arguments):
    return subprocess.check_output(["/usr/bin/xcrun", "--sdk", "macosx", *map(str, arguments)], env=environment, text=True)


sdk_version = tool("--show-sdk-version").strip()
assert sdk_version.split(".")[0] == "27", "SDK 27 required"
output.mkdir(parents=True, mode=0o700)
tool("swiftc", "-D", "DEBUG", "-parse-as-library", "-target", "arm64-apple-macos27.0", root / "Probe.swift", "-o", output / "probe")
tool("swiftc", "-target", "arm64-apple-macos27.0", root.parent / "0.7.0/ReadPositionSnapshot.swift", "-o", output / "read-position")
tool("swiftc", "-D", "DEBUG", "-target", "arm64-apple-macos27.0", root / "ReadOwners.swift", "-o", output / "read-owners")
tool("clang", "-DDEBUG", "-fobjc-arc", "-framework", "AppKit", "-target", "arm64-apple-macos27.0", root / "GroupWriter.m", "-o", output / "group-writer")
tool("clang", "-DDEBUG", "-fobjc-arc", "-framework", "AppKit", "-target", "arm64-apple-macos27.0", root / "ApprovedPairWriter.m", "-o", output / "approved-pair-writer")
shutil.copytree(root, output / "executed-source", ignore=shutil.ignore_patterns("__pycache__"))
for suffix in "AB":
    app = output / ("Adoption" + suffix + ".app")
    (app / "Contents/MacOS").mkdir(parents=True, mode=0o700)
    info = {
        "CFBundleIdentifier": "xyz.fi5h.blenny.research.adoption20260908" + suffix.lower(),
        "CFBundleExecutable": "OrderingAdoption" + suffix, "CFBundleName": "Ordering Adoption " + suffix,
        "CFBundlePackageType": "APPL", "LSUIElement": True,
        "LSMinimumSystemVersion": "27.0",
    }
    (app / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
    executable = app / "Contents/MacOS" / ("OrderingAdoption" + suffix)
    shutil.copyfile(output / "probe", executable)
    executable.chmod(0o700)
    subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", str(app)], check=True)
(output / "sdk-version.txt").write_text(sdk_version + "\n")
print("Built Debug research probes and scoped writer; nothing was launched.")
