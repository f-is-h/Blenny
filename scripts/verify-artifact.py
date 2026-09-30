#!/usr/bin/env python3
"""Verify sealed bytes and Ed25519 against the tracked public key, without secrets."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile

from release_tools import ROOT, marketing_version, product_digest, sha256, version_notes, version_tuple


def verify_signature(archive, signature, public_key):
    key = base64.b64decode(public_key, validate=True)
    sig = base64.b64decode(signature, validate=True)
    if len(key) != 32 or len(sig) != 64:
        raise ValueError("Invalid Ed25519 key/signature")
    openssl = os.getenv("BLENNY_OPENSSL") or shutil.which("openssl")
    if openssl is None:
        raise ValueError("OpenSSL 3 is required for independent public-key verification")
    if "OpenSSL 3." not in subprocess.check_output([openssl, "version"], text=True):
        candidate = Path("/opt/homebrew/opt/openssl@3/bin/openssl")
        if not candidate.exists():
            raise ValueError("OpenSSL 3 is required")
        openssl = str(candidate)
    with tempfile.TemporaryDirectory(prefix="blenny-public-verification-") as temp:
        key_file, signature_file = Path(temp) / "public.der", Path(temp) / "signature"
        key_file.write_bytes(bytes.fromhex("302a300506032b6570032100") + key)
        signature_file.write_bytes(sig)
        subprocess.run([openssl, "pkeyutl", "-verify", "-pubin", "-keyform", "DER", "-inkey", str(key_file),
                        "-rawin", "-in", str(archive), "-sigfile", str(signature_file)], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def verify(directory, root=ROOT, production=False, source=None):
    version = marketing_version(root)
    receipt_path = directory / f"Blenny-{version}.receipt.json"
    receipt = json.loads(receipt_path.read_text())
    version_tuple(receipt["version"])
    expected_name = f"Blenny-{version}.dmg"
    if receipt["version"] != version or receipt["archive"] != expected_name:
        raise ValueError("Artifact version/name mismatch")
    archive = directory / expected_name
    if archive.is_symlink() or not archive.is_file() or sha256(archive) != receipt["sha256"] or archive.stat().st_size != receipt["length"]:
        raise ValueError("Artifact bytes do not match sealed receipt")
    if not str(receipt["build"]).isdigit() or int(receipt["build"]) <= 108:
        raise ValueError("Artifact build must exceed the migration predecessor")
    if (directory / (expected_name + ".sha256")).read_text() != f"{receipt['sha256']}  {expected_name}\n":
        raise ValueError("Checksum file mismatch")
    notes = version_notes(version, root)
    if (directory / "release-notes.md").read_text() != notes or receipt["releaseNotesSHA256"] != hashlib.sha256(notes.encode()).hexdigest():
        raise ValueError("Sealed release notes differ from reviewed source")
    if receipt["productDigest"] != product_digest(root):
        raise ValueError("Artifact was built from a different product/configuration")
    if source is not None and receipt["sourceCommit"] != source:
        raise ValueError("Artifact source commit mismatch")
    if receipt.get("verification") != {"distribution": True, "mountedContents": True}:
        raise ValueError("Required build-job distribution checks are missing")
    info = plistlib.loads((root / "Config/Info.plist").read_bytes())
    verify_signature(archive, receipt["edSignature"], info["SUPublicEDKey"])
    if production:
        toolchain = receipt["toolchain"]
        if not re.fullmatch(r"[a-f0-9]{40}", receipt.get("workflowCommit", receipt["sourceCommit"])):
            raise ValueError("Invalid release-controller commit provenance")
        if receipt["buildOrigin"] != "github-actions" or receipt["sourceDirty"] is not False or receipt["tag"] != "v" + version:
            raise ValueError("Public artifacts must be clean, tag-bound GitHub builds")
        if receipt.get("sparkleFixtureVerified") is not True:
            raise ValueError("Hosted Sparkle installation/relaunch and rejection fixture has not passed")
        if not receipt.get("workflowRun") or not receipt.get("workflowAttempt") or toolchain["architecture"] != "arm64" or not toolchain["os"].startswith("27.") or not toolchain["xcode"].startswith("Xcode 27.") or not toolchain["sdk"].startswith("27."):
            raise ValueError("Invalid GitHub build provenance/toolchain")
    print("Sealed archive checksum, notes, provenance and pinned Ed25519 signature: PASS")
    return receipt


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--production", action="store_true")
    parser.add_argument("--source")
    args = parser.parse_args()
    verify(args.directory, production=args.production, source=args.source)
