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
        with patch.object(ci.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "gh: Not Found (HTTP 404)")), patch.object(ci, "releases", return_value=[]):
            self.assertIsNone(ci.optional_release("v1.0.0"))
        with patch.object(ci.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "HTTP 403: forbidden")), patch.object(ci, "releases") as listed:
            with self.assertRaisesRegex(RuntimeError, "Cannot establish"):
                ci.optional_release("v1.0.0")
            listed.assert_not_called()

    def test_tag_404_finds_exact_draft_across_release_pages(self):
        draft = dict(tag_name="v1.0.0", draft=True, assets=[])
        pages = json.dumps([[dict(tag_name="v1.0.1", draft=True)], [draft]])
        with patch.object(ci.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "HTTP 404")), patch.object(ci, "gh", return_value=pages) as gh:
            self.assertEqual(ci.optional_release("v1.0.0"), draft)
            self.assertEqual(gh.call_args.args, ("api", "--paginate", "--slurp", f"repos/{ci.REPOSITORY}/releases?per_page=100"))

    def test_draft_list_failure_and_duplicate_tag_fail_closed(self):
        with patch.object(ci.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "HTTP 404")), patch.object(ci, "gh", side_effect=subprocess.CalledProcessError(1, ["gh", "api"])):
            with self.assertRaises(subprocess.CalledProcessError):
                ci.optional_release("v1.0.0")
        with patch.object(ci.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "HTTP 404")), patch.object(ci, "releases", return_value=[dict(tag_name="v1.0.0")] * 2):
            with self.assertRaisesRegex(ValueError, "Multiple releases"):
                ci.optional_release("v1.0.0")

    def test_empty_draft_allows_new_unpublished_build(self):
        with patch.object(ci, "preflight", return_value=("a" * 40, "1.0.0", "v1.0.0")), patch.object(ci, "optional_release", return_value=dict(draft=True, assets=[])), patch.object(ci, "gh", return_value='[{"artifacts": []}]'), patch.dict(os.environ, GITHUB_RUN_ID="123"), patch.object(ci, "run") as run:
            self.assertFalse(ci.recover(self.directory, True))
            run.assert_not_called()

    def exercise_draft_publication(self, *, create=False, changed_bytes=False):
        draft = dict(tag_name="v1.0.0", draft=True, assets=[], body=self.notes)
        published = dict(draft=False, assets=[], body=self.notes, html_url=self.url)
        lookups = ([None] if create else []) + [draft, published]
        calls = []
        def run(*args):
            calls.append(args)
            if args[:3] == ("gh", "release", "download"):
                target = Path(args[-1])
                for path in self.directory.iterdir():
                    shutil.copyfile(path, target / path.name)
                if changed_bytes:
                    (target / self.receipt["archive"]).write_bytes(b"different previously sealed build")
            if args[:2] == ("git", "fetch"):
                raise RuntimeError("feed transaction reached")
        with patch.object(ci, "preflight", return_value=("a" * 40, "1.0.0", "v1.0.0")), patch.object(ci.artifact, "verify", return_value=self.receipt), patch.object(ci, "optional_release", side_effect=lookups), patch.object(ci, "version_notes", return_value=self.notes), patch.object(ci, "run", side_effect=run), patch.object(ci, "verify_public_assets", return_value={n: self.url for n in self.assets}), patch("builtins.print"):
            with self.assertRaisesRegex(ValueError if changed_bytes else RuntimeError, "bytes differ" if changed_bytes else "feed transaction reached"):
                ci.publish(self.directory)
        return calls

    def test_first_publication_creates_reads_and_verifies_draft_before_publish(self):
        calls = self.exercise_draft_publication(create=True)
        self.assertEqual(sum(c[:3] == ("gh", "release", "create") for c in calls), 1)
        self.assertEqual(sum(c[:3] == ("gh", "release", "upload") for c in calls), 4)
        self.assertLess(next(i for i, c in enumerate(calls) if c[:3] == ("gh", "release", "download")), next(i for i, c in enumerate(calls) if c[:3] == ("gh", "release", "edit")))

    def test_existing_empty_draft_is_resumed_without_duplicate_creation(self):
        calls = self.exercise_draft_publication()
        self.assertFalse(any(c[:3] == ("gh", "release", "create") for c in calls))
        self.assertTrue(any(c[:3] == ("gh", "release", "edit") for c in calls))

    def test_different_valid_draft_bytes_stop_before_publishing(self):
        calls = self.exercise_draft_publication(changed_bytes=True)
        self.assertFalse(any(c[:3] == ("gh", "release", "edit") for c in calls))

    def test_created_but_unavailable_draft_has_explicit_failure(self):
        with patch.object(ci, "preflight", return_value=("a" * 40, "1.0.0", "v1.0.0")), patch.object(ci.artifact, "verify", return_value=self.receipt), patch.object(ci, "optional_release", return_value=None), patch.object(ci, "run") as run:
            with self.assertRaisesRegex(ValueError, "Created release is unavailable"):
                ci.publish(self.directory)
            self.assertEqual(run.call_count, 1)
            self.assertEqual(run.call_args.args[:3], ("gh", "release", "create"))

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


class ManualReleaseSourceTests(unittest.TestCase):
    def setUp(self):
        self.controller = "b" * 40
        self.source = "a" * 40
        self.tag_object = "c" * 40
        self.environment = dict(GITHUB_ACTIONS="true", GITHUB_REPOSITORY="f-is-h/Blenny",
                                GITHUB_EVENT_NAME="workflow_dispatch", GITHUB_REF="refs/heads/main",
                                GITHUB_SHA=self.controller)
        self.addCleanup(patch.stopall)
        patch.dict(os.environ, self.environment).start()
        self.git = patch.object(ci, "git", side_effect=self.git_result).start()
        self.api = patch.object(ci, "api", return_value={"object": {"sha": self.tag_object}}).start()
        self.run = patch.object(ci, "run").start()

    def git_result(self, *args, **kwargs):
        if args == ("status", "--porcelain"):
            return ""
        if args == ("rev-parse", "HEAD"):
            return self.controller
        if args[0] == "cat-file":
            return "tag"
        if args[0] == "rev-parse":
            return self.source if args[1].endswith("^{commit}") else self.tag_object
        self.fail("Unexpected Git operation: " + repr(args))

    def test_manual_publication_selects_original_tag_source_without_changing_version(self):
        selected = ci.select_source("publish", "v1.0.0")
        self.assertEqual(selected["source_sha"], self.source)
        self.assertNotEqual(selected["source_sha"], self.controller)
        self.assertEqual(selected["source_tag"], "v1.0.0")
        self.assertEqual(selected["production"], "true")
        self.run.assert_called_once_with("git", "-C", str(ci.CONTROLLER_ROOT), "merge-base", "--is-ancestor", self.source, "origin/main")

    def test_manual_publication_rejects_missing_or_noncanonical_tags(self):
        for tag in ["", "main", "v1.0.0;echo injected", "v../1.0.0", "v01.0.0", "v1.0.0\n"]:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                ci.select_source("publish", tag)

    def test_diagnosis_and_verification_never_select_publication(self):
        for operation in ["signing-diagnostics", "verification"]:
            selected = ci.select_source(operation, "v1.0.0")
            self.assertEqual(selected["production"], "false")
            self.assertEqual(selected["diagnostics"], str(operation == "signing-diagnostics").lower())

    def test_tag_push_uses_event_tag_even_when_dispatch_arguments_disagree(self):
        with patch.dict(os.environ, GITHUB_EVENT_NAME="push", GITHUB_REF="refs/tags/v1.0.0"):
            selected = ci.select_source("signing-diagnostics", "v9.9.9")
        self.assertEqual(selected["source_tag"], "v1.0.0")
        self.assertEqual(selected["production"], "true")

    def test_remote_tag_divergence_is_rejected_before_build(self):
        self.api.return_value = {"object": {"sha": "d" * 40}}
        with self.assertRaisesRegex(ValueError, "replaced or diverged"):
            ci.select_source("publish", "v1.0.0")
        self.run.assert_not_called()

    def test_lightweight_tag_is_rejected(self):
        self.git.side_effect = lambda *args, **kwargs: "commit" if args[0] == "cat-file" else self.git_result(*args, **kwargs)
        with self.assertRaisesRegex(ValueError, "annotated"):
            ci.select_source("publish", "v1.0.0")

    def test_manual_controls_reject_another_branch_and_dirty_controller(self):
        with patch.dict(os.environ, GITHUB_REF="refs/heads/other"), self.assertRaisesRegex(ValueError, "reviewed main"):
            ci.select_source("publish", "v1.0.0")
        self.git.side_effect = lambda *args, **kwargs: " M unsafe.py" if args[0] == "status" else self.git_result(*args, **kwargs)
        with self.assertRaisesRegex(ValueError, "clean"):
            ci.select_source("publish", "v1.0.0")

    def test_manual_form_never_defaults_to_publication_and_enforces_separate_checkouts(self):
        checker = ci.load_script("check-workflows")
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            shutil.copytree(ci.CONTROLLER_ROOT / ".github/workflows", root / ".github/workflows")
            release = root / ".github/workflows/release.yml"
            original = release.read_text()
            release.write_text(original.replace("default: verification", "default: publish"))
            with self.assertRaisesRegex(ValueError, "default stays verification"):
                checker.check(root)
            release.write_text(original.replace("ref: ${{ needs.build.outputs.source_sha }}", "ref: ${{ github.sha }}"))
            with self.assertRaisesRegex(ValueError, "source separate"):
                checker.check(root)

    def test_diagnostics_without_tag_stays_on_reviewed_controller_source(self):
        selected = ci.select_source("signing-diagnostics", "")
        self.assertEqual(selected["source_sha"], self.controller)
        self.api.assert_not_called()

    def test_manual_preflight_checks_clean_original_source_acceptance_and_remote_tag(self):
        source_root = Path("/isolated-source-fixture")
        def source_git(*args, **kwargs):
            if args == ("rev-parse", "HEAD"):
                return self.controller if kwargs.get("root") == ci.CONTROLLER_ROOT else self.source
            return self.git_result(*args, **kwargs)
        with patch.object(ci, "ROOT", source_root), patch.object(ci, "git", side_effect=source_git), \
             patch.object(ci, "validate_documents"), patch.object(ci, "validate_coverage"), \
             patch.object(ci, "marketing_version", return_value="1.0.0"), \
             patch.object(ci, "validate_acceptance") as acceptance, \
             patch.object(ci, "gh", return_value=json.dumps({"object": {"sha": self.tag_object}})), \
             patch.object(ci, "api", return_value={"private": False}), patch.object(ci, "releases", return_value=[]), \
             patch.dict(os.environ, BLENNY_RELEASE_SOURCE_SHA=self.source, BLENNY_RELEASE_TAG="v1.0.0"):
            self.assertEqual(ci.preflight("production"), (self.source, "1.0.0", "v1.0.0"))
            acceptance.assert_called_once()
            with patch.object(ci, "validate_acceptance", side_effect=ValueError("stale acceptance")), self.assertRaisesRegex(ValueError, "stale"):
                ci.preflight("production")
            with patch.object(ci, "gh", return_value=json.dumps({"object": {"sha": "d" * 40}})), self.assertRaisesRegex(ValueError, "diverged"):
                ci.preflight("production")
            with patch.dict(os.environ, BLENNY_RELEASE_TAG="v1.0.1"), self.assertRaisesRegex(ValueError, "explicit existing-tag"):
                ci.preflight("production")


class HostedSigningIdentityTests(unittest.TestCase):
    """Run the real wrapper with isolated Security CLI and signing probes."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ["scripts", "Config", "bin", "runner"]:
            (self.root / name).mkdir()
        shutil.copyfile(Path(__file__).with_name("ci-sign-package.sh"), self.root / "scripts/ci-sign-package.sh")
        self.fingerprint = hashlib.sha1(b"isolated-public-certificate-fixture").hexdigest().upper()
        (self.root / "Config/SigningIdentity.sha1").write_text(self.fingerprint + "\n")
        (self.root / "Config/Info.plist").write_text('<plist version="1.0"><dict><key>CFBundleShortVersionString</key><string>1.0.0</string></dict></plist>')
        self.trace = self.root / "trace.jsonl"
        self.fake_command("security", r'''import base64, json, os, pathlib, sys, time
args = sys.argv[1:]
root = pathlib.Path(os.environ["SIGNING_FIXTURE_ROOT"])
with (root / "trace.jsonl").open("a") as trace:
    trace.write(json.dumps(["security", *args]) + "\n")
command = args[0]
assert command not in {"add-trusted-cert", "remove-trusted-cert", "trust-settings-export", "trust-settings-import", "authorizationdb"}
if command == "list-keychains" and "-s" not in args:
    print('    "fixture-original.keychain-db"')
elif command == "list-keychains" and len(args) == 5 and "-s" in args and "fixture-original.keychain-db" == args[-1]:
    mode = os.environ.get("SIGNING_FIXTURE_CLEANUP", "yes")
    if mode == "hang": time.sleep(60)
    if mode == "no": sys.exit(88)
elif command == "default-keychain" and "-s" not in args:
    print('"fixture-default.keychain-db"')
elif command == "find-certificate":
    encoded = base64.b64encode(b"isolated-public-certificate-fixture").decode()
    print("-----BEGIN CERTIFICATE-----\n" + encoded + "\n-----END CERTIFICATE-----")
elif command == "find-identity":
    if os.environ.get("SIGNING_FIXTURE_KEY", "yes") == "yes" and "-v" not in args:
        print("1) " + os.environ["SIGNING_FIXTURE_FINGERPRINT"] + ' "Fixture Identity"')
''')
        self.fake_command("codesign", r'''import json, os, pathlib, sys
root = pathlib.Path(os.environ["SIGNING_FIXTURE_ROOT"])
args = sys.argv[1:]
with (root / "trace.jsonl").open("a") as trace:
    trace.write(json.dumps(["codesign", *args]) + "\n")
if "--sign" in args:
    assert args[args.index("--sign") + 1] == os.environ["SIGNING_FIXTURE_FINGERPRINT"]
    assert "--keychain" in args
    sys.exit(int(os.environ.get("SIGNING_FIXTURE_SIGN_STATUS", "0")))
assert "--verify" in args and "--strict" in args
assert any(arg.startswith('-R=identifier "xyz.fi5h.blenny.ci-signing-probe" and certificate root = H"') for arg in args)
sys.exit(int(os.environ.get("SIGNING_FIXTURE_VERIFY_STATUS", "0")))
''')
        (self.root / "scripts/build-app.sh").write_text("#!/bin/zsh\nexit ${SIGNING_FIXTURE_PACKAGE_STATUS:-0}\n")
        (self.root / "scripts/prepare-release.sh").write_text('''#!/bin/zsh
mkdir -p "$2"
print '{"version":"1.0.0"}' > "$2/Blenny-1.0.0.receipt.json"
''')
        for name in ["test-sparkle-local.py", "verify-artifact.py"]:
            (self.root / "scripts" / name).write_text("pass\n")
        self.env = {**os.environ, "PATH": str(self.root / "bin") + os.pathsep + os.environ["PATH"],
                    "GITHUB_ACTIONS": "true", "GITHUB_REPOSITORY": "f-is-h/Blenny", "GITHUB_SHA": "a" * 40,
                    "RUNNER_TEMP": str(self.root / "runner"), "SIGNING_FIXTURE_ROOT": str(self.root),
                    "BLENNY_RELEASE_SOURCE_ROOT": str(self.root), "GITHUB_WORKSPACE": str(self.root),
                    "BLENNY_RELEASE_SOURCE_SHA": "a" * 40, "BLENNY_SIGNING_DIAGNOSTICS_ONLY": "false",
                    "SIGNING_FIXTURE_FINGERPRINT": self.fingerprint,
                    "BLENNY_CERTIFICATE_P12_BASE64": base64.b64encode(b"fixture-p12").decode(),
                    "BLENNY_CERTIFICATE_PASSWORD": "fixture-password", "BLENNY_SPARKLE_PRIVATE_KEY": "fixture-update-key"}

    def fake_command(self, name, source):
        path = self.root / "bin" / name
        path.write_text("#!" + shutil.which("python3") + "\n" + source)
        path.chmod(0o700)

    def execute(self, **environment):
        result = subprocess.run(["zsh", str(self.root / "scripts/ci-sign-package.sh"), str(self.root / "sealed"), "1103"],
                                env={**self.env, **environment}, capture_output=True, text=True, timeout=40)
        self.assertEqual(list((self.root / "runner").iterdir()), [])
        self.assertNotIn("fixture-password", result.stdout + result.stderr)
        self.assertNotIn("fixture-update-key", result.stdout + result.stderr)
        calls = [json.loads(line) for line in self.trace.read_text().splitlines()]
        self.assertIn(["security", "default-keychain", "-d", "user", "-s", "fixture-default.keychain-db"], calls)
        self.assertIn(["security", "list-keychains", "-d", "user", "-s", "fixture-original.keychain-db"], calls)
        self.assertTrue(any(call[:2] == ["security", "delete-keychain"] for call in calls))
        return result, calls, json.loads((self.root / "LocalData/ci/signing-diagnostic.json").read_text())

    def test_self_signed_identity_is_actually_verified_without_system_trust_mutation(self):
        result, calls, report = self.execute()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(report["validIdentityBeforeTrust"])
        self.assertTrue(report["codeSigningProbeVerified"])
        self.assertFalse(report["systemTrustModified"])
        self.assertTrue(report["cleanupCompleted"])
        self.assertEqual(report["cause"], "self-signed-identity-excluded-by-validity-filter")
        self.assertEqual(sum(call[0] == "codesign" for call in calls), 2)

    def test_wrong_certificate_is_rejected_before_signing(self):
        (self.root / "Config/SigningIdentity.sha1").write_text("B" * 40 + "\n")
        result, calls, report = self.execute()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(report["cause"], "certificate-fingerprint-mismatch")
        self.assertFalse(any(call[0] == "codesign" for call in calls))

    def test_missing_private_key_is_rejected_before_signing(self):
        result, calls, report = self.execute(SIGNING_FIXTURE_KEY="no")
        self.assertEqual(result.returncode, 65)
        self.assertEqual(report["cause"], "matching-certificate-has-no-usable-private-key")
        self.assertFalse(any(call[0] == "codesign" for call in calls))

    def test_signing_failure_stops_before_signature_verification(self):
        result, calls, report = self.execute(SIGNING_FIXTURE_SIGN_STATUS="65")
        self.assertEqual(result.returncode, 65)
        self.assertFalse(report["codeSigningProbeVerified"])
        self.assertEqual(sum(call[0] == "codesign" for call in calls), 1)
        self.assertFalse((self.root / "sealed").exists())

    def test_pinned_signature_verification_failure_stops_before_packaging(self):
        result, calls, report = self.execute(SIGNING_FIXTURE_VERIFY_STATUS="65")
        self.assertEqual(result.returncode, 65)
        self.assertEqual(report["cause"], "identity-cannot-sign-pinned-probe")
        self.assertFalse((self.root / "sealed").exists())

    def test_packaging_failure_still_restores_keychain_context(self):
        result, calls, report = self.execute(SIGNING_FIXTURE_PACKAGE_STATUS="42")
        self.assertEqual(result.returncode, 42)
        self.assertTrue(report["cleanupCompleted"])

    def test_cleanup_failure_cannot_report_success(self):
        result, calls, report = self.execute(SIGNING_FIXTURE_CLEANUP="no")
        self.assertEqual(result.returncode, 65)
        self.assertFalse(report["cleanupCompleted"])

    def test_hung_keychain_cleanup_is_bounded_and_cannot_report_success(self):
        result, calls, report = self.execute(SIGNING_FIXTURE_CLEANUP="hang")
        self.assertEqual(result.returncode, 65)
        self.assertIn("timed out: keychain-search-list", result.stderr)
        self.assertFalse(report["cleanupCompleted"])

    def test_diagnostics_skip_application_build_and_publication(self):
        result, calls, report = self.execute(BLENNY_SIGNING_DIAGNOSTICS_ONLY="true", SIGNING_FIXTURE_PACKAGE_STATUS="42")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / "sealed").exists())
        self.assertIn("no application build or publication", result.stdout)


if __name__ == "__main__":
    unittest.main()
