#!/usr/bin/env python3
"""Run a checksum-pinned actionlint without installing or trusting mutable tags."""
import hashlib
import io
from pathlib import Path
import platform
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
VERSION = "1.7.11"
CHECKSUMS = {
    ("Darwin", "arm64"): ("darwin_arm64", "a21ba7366d8329e7223faee0ed69eb13da27fe8acabb356bb7eb0b7f1e1cb6d8"),
    ("Linux", "x86_64"): ("linux_amd64", "900919a84f2229bac68ca9cd4103ea297abc35e9689ebb842c6e34a3d1b01b0a"),
}


def main():
    variant, expected = CHECKSUMS[(platform.system(), platform.machine())]
    directory = ROOT / "LocalData/release-automation/actionlint"
    directory.mkdir(parents=True, exist_ok=True)
    archive = directory / f"actionlint_{VERSION}_{variant}.tar.gz"
    if not archive.exists():
        url = f"https://github.com/rhysd/actionlint/releases/download/v{VERSION}/{archive.name}"
        with urllib.request.urlopen(url, timeout=60) as response:
            archive.write_bytes(response.read())
    payload = archive.read_bytes()
    if hashlib.sha256(payload).hexdigest() != expected:
        raise ValueError("Pinned actionlint archive checksum mismatch")
    with tarfile.open(fileobj=io.BytesIO(payload)) as tar:
        member = tar.getmember("actionlint")
        if not member.isfile():
            raise ValueError("Unexpected linter archive entry")
        binary = directory / "actionlint"
        binary.write_bytes(tar.extractfile(member).read())
    binary.chmod(0o755)
    subprocess.run([str(binary), "-shellcheck=", "-pyflakes="], cwd=ROOT, check=True)
    print(f"Pinned actionlint {VERSION}: PASS")


if __name__ == "__main__":
    main()
