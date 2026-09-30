import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location("ci_release", Path(__file__).with_name("ci-release.py"))
ci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)


class ReleaseTransactionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.directory = self.root / "sealed"
        self.directory.mkdir()
        self.notes = "## 1.0.0 — 2026-09-30\n\nA < B & C\n"
        self.receipt = dict(version="1.0.0", build="1101", archive="Blenny-1.0.0.dmg", length=7,
                            sha256=hashlib.sha256(b"archive").hexdigest(), edSignature=base64.b64encode(bytes(64)).decode(),
                            sourceCommit="a" * 40)
        self.url = "https://github.com/f-is-h/Blenny/releases/download/v1.0.0/Blenny-1.0.0.dmg"
        self.assets = ["Blenny-1.0.0.dmg", "Blenny-1.0.0.dmg.sha256", "Blenny-1.0.0.receipt.json", "release-notes.md"]
        for name in self.assets:
            (self.directory / name).write_bytes(b"archive" if name.endswith(".dmg") else b"metadata")

    def feed(self, path):
        ci.appcast.create_item(path, version="1.0.0", build="1101", length=7, signature=self.receipt["edSignature"],
                               download_url=self.url, release_url="https://github.com/f-is-h/Blenny/releases/tag/v1.0.0", notes=self.notes)

    def test_feed_metadata_is_exact_and_conflicts_fail(self):
        feed = self.root / "feed.xml"
        self.feed(feed)
        with patch.object(ci, "version_notes", return_value=self.notes):
            self.assertTrue(ci.feed_has_release(feed.read_bytes(), self.receipt, self.url))
            for key, value in [("build", "1102"), ("length", 8), ("edSignature", "wrong")]:
                with self.assertRaises(ValueError):
                    ci.feed_has_release(feed.read_bytes(), {**self.receipt, key: value}, self.url)
            tree = ET.parse(feed)
            tree.find("channel/item/description").text = "different notes"
            with self.assertRaises(ValueError):
                ci.feed_has_release(ET.tostring(tree.getroot()), self.receipt, self.url)

    def test_public_history_rejects_stale_versions(self):
        releases = [dict(tag_name="v1.0.1", draft=False)]
        with self.assertRaises(ValueError):
            ci.ensure_order("1.0.0", releases, "v1.0.0")
        ci.ensure_order("1.0.2", releases, "v1.0.2")
        ci.ensure_order("1.0.0", [dict(tag_name="v1.0.0", draft=False)], "v1.0.0")

    def test_existing_release_lookup_does_not_treat_auth_failure_as_absence(self):
        with patch.object(ci.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "gh: Not Found (HTTP 404)")):
            self.assertIsNone(ci.optional_release("v1.0.0"))
        with patch.object(ci.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "HTTP 403: forbidden")):
            with self.assertRaisesRegex(RuntimeError, "Cannot establish"):
                ci.optional_release("v1.0.0")

    def test_partial_draft_recovers_sealed_artifact_without_rebuilding(self):
        release = dict(draft=True, assets=[dict(name=self.assets[0])])
        artifact_name = "sealed-1.0.0-" + "a" * 40 + "-1"
        listing = json.dumps([dict(artifacts=[dict(name=artifact_name, id=3, expired=False)])])
        with patch.object(ci, "preflight", return_value=("a" * 40, "1.0.0", "v1.0.0")), patch.object(ci, "optional_release", return_value=release), patch.object(ci, "gh", return_value=listing), patch.object(ci, "run") as run, patch.object(ci.artifact, "verify"), patch.dict(os.environ, GITHUB_RUN_ID="123"):
            self.assertTrue(ci.recover(self.directory, True))
            self.assertEqual(run.call_count, 1)
            self.assertEqual(run.call_args.args[:3], ("gh", "run", "download"))
        with patch.object(ci, "preflight", return_value=("a" * 40, "1.0.0", "v1.0.0")), patch.object(ci, "optional_release", return_value=release), patch.object(ci, "gh", return_value='[{"artifacts": []}]'), patch.dict(os.environ, GITHUB_RUN_ID="123"):
            with self.assertRaisesRegex(ValueError, "refuse to rebuild"):
                ci.recover(self.directory, True)

    def test_published_conflicting_assets_fail_before_any_transfer(self):
        with patch.object(ci, "preflight", return_value=("a" * 40, "1.0.0", "v1.0.0")), patch.object(ci, "optional_release", return_value=dict(draft=False, assets=[])), patch.object(ci, "run") as run:
            with self.assertRaises(ValueError):
                ci.recover(self.directory, True)
            run.assert_not_called()

    def test_anonymous_downloads_must_match_every_asset(self):
        release = dict(assets=[dict(name=n, browser_download_url="https://example.org/" + n) for n in self.assets])
        with patch.object(ci, "public_bytes", side_effect=lambda url: (self.directory / url.rsplit("/", 1)[1]).read_bytes()):
            self.assertEqual(len(ci.verify_public_assets(release, self.directory, self.receipt)), 4)
        with patch.object(ci, "public_bytes", return_value=b"tampered"):
            with self.assertRaisesRegex(ValueError, "differ"):
                ci.verify_public_assets(release, self.directory, self.receipt)

    def test_public_download_is_anonymous_and_https_only(self):
        class Response:
            status, url = 200, "https://example.org/redirect"
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def read(self): return b"content"
        with patch.object(ci.urllib.request, "urlopen", return_value=Response()) as opened:
            self.assertEqual(ci.public_bytes("https://example.org/archive"), b"content")
            self.assertNotIn("Authorization", opened.call_args.args[0].headers)
            self.assertEqual(opened.call_args.kwargs["timeout"], 60)
        with self.assertRaises(ValueError):
            ci.public_bytes("http://example.org/archive")

    def test_feed_failure_after_publication_reuses_existing_release(self):
        release = dict(draft=False, assets=[], body=self.notes, html_url="https://github.com/f-is-h/Blenny/releases/tag/v1.0.0")
        urls = {n: "https://example.org/" + n for n in self.assets}
        with patch.object(ci, "preflight", return_value=("a" * 40, "1.0.0", "v1.0.0")), patch.object(ci.artifact, "verify", return_value=self.receipt), patch.object(ci, "optional_release", return_value=release), patch.object(ci, "version_notes", return_value=self.notes), patch.object(ci, "verify_public_assets", return_value=urls), patch.object(ci, "run", side_effect=RuntimeError("feed write refused")) as run, patch("builtins.print"):
            with self.assertRaisesRegex(RuntimeError, "feed write"):
                ci.publish(self.directory)
            self.assertEqual(run.call_args.args, ("git", "fetch", "origin", "main"))
            self.assertFalse((self.directory / "publication-result.json").exists())

    def test_wrong_notes_fail_before_feed_write(self):
        with patch.object(ci, "preflight", return_value=("a" * 40, "1.0.0", "v1.0.0")), patch.object(ci.artifact, "verify", return_value=self.receipt), patch.object(ci, "optional_release", return_value=dict(draft=False, body="unreviewed")), patch.object(ci, "version_notes", return_value=self.notes), patch.object(ci, "run") as run:
            with self.assertRaisesRegex(ValueError, "notes differ"):
                ci.publish(self.directory)
            run.assert_not_called()

    def test_unreviewed_draft_is_never_published(self):
        with patch.object(ci, "preflight", return_value=("a" * 40, "1.0.0", "v1.0.0")), patch.object(ci.artifact, "verify", return_value=self.receipt), patch.object(ci, "optional_release", return_value=dict(draft=True, body="unreviewed")), patch.object(ci, "version_notes", return_value=self.notes), patch.object(ci, "run") as run:
            with self.assertRaisesRegex(ValueError, "notes differ"):
                ci.publish(self.directory)
            run.assert_not_called()

    def test_workflow_context_required_even_in_verification_mode(self):
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "false"}, clear=True):
            with self.assertRaisesRegex(ValueError, "expected GitHub"):
                ci.preflight("verification")

    def test_independent_ed25519_verification_rejects_tampering_and_wrong_key(self):
        openssl = shutil.which("openssl")
        if "OpenSSL 3." not in subprocess.check_output([openssl, "version"], text=True):
            openssl = "/opt/homebrew/opt/openssl@3/bin/openssl"
        private, public, signature = (self.root / name for name in ["fixture-secret", "fixture-public", "fixture-signature"])
        subprocess.run([openssl, "genpkey", "-algorithm", "ED25519", "-out", str(private)], check=True, capture_output=True)
        subprocess.run([openssl, "pkey", "-in", str(private), "-pubout", "-outform", "DER", "-out", str(public)], check=True, capture_output=True)
        archive = self.directory / self.receipt["archive"]
        subprocess.run([openssl, "pkeyutl", "-sign", "-inkey", str(private), "-rawin", "-in", str(archive), "-out", str(signature)], check=True, capture_output=True)
        key = base64.b64encode(public.read_bytes()[-32:]).decode()
        sig = base64.b64encode(signature.read_bytes()).decode()
        with patch.dict(os.environ, BLENNY_OPENSSL=openssl):
            ci.artifact.verify_signature(archive, sig, key)
            archive.write_bytes(b"changed")
            with self.assertRaises(subprocess.CalledProcessError):
                ci.artifact.verify_signature(archive, sig, key)
            with self.assertRaises(subprocess.CalledProcessError):
                ci.artifact.verify_signature(archive, sig, base64.b64encode(bytes(32)).decode())

    def test_mounted_image_is_detached_when_plist_or_distribution_validation_fails(self):
        dmg = ci.load_script("verify-dmg")
        for malformed in [True, False]:
            def attach(args):
                mount = Path(args[args.index("-mountpoint") + 1])
                if malformed:
                    return b"invalid property list"
                (mount / "Blenny.app").mkdir()
                (mount / "Applications").symlink_to("/Applications")
                import plistlib
                return plistlib.dumps({"system-entities": [{"dev-entry": "/dev/fixture", "mount-point": str(mount)}]})
            def run(args, **kwargs):
                if args[0] == "zsh":
                    raise subprocess.CalledProcessError(65, args)
                return subprocess.CompletedProcess(args, 0)
            with patch.object(dmg.subprocess, "check_output", side_effect=attach), patch.object(dmg.subprocess, "run", side_effect=run) as calls:
                with self.assertRaises(Exception):
                    dmg.verify(self.root / "fixture.dmg")
                detaches = [call.args[0] for call in calls.call_args_list if call.args[0][:2] == ["hdiutil", "detach"]]
                self.assertEqual(len(detaches), 1)
                self.assertEqual(detaches[0][2], "-quiet")


if __name__ == "__main__":
    unittest.main()
