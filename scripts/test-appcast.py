import base64
import importlib.util
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location("appcast", Path(__file__).with_name("create-appcast.py"))
appcast = importlib.util.module_from_spec(spec)
spec.loader.exec_module(appcast)


class AppcastTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.feed = Path(self.directory.name) / "appcast.xml"
        self.args = dict(version="1.0.0", build="100", signature=base64.b64encode(bytes(64)).decode(),
                         length=10, download_url="https://example.org/app.dmg?x=1&y=2",
                         release_url="https://example.org/release", notes="A < B & C\nSecond line")

    def test_xml_preserves_notes_and_history(self):
        appcast.create_item(self.feed, **self.args)
        root = ET.parse(self.feed)
        self.assertEqual(root.findtext("channel/item/description"), self.args["notes"])
        self.args["build"] = "101"
        self.args["version"] = "1.0.1"
        appcast.create_item(self.feed, **self.args)
        self.assertEqual(len(ET.parse(self.feed).findall("channel/item")), 2)

    def test_duplicate_or_older_build_leaves_feed_unchanged(self):
        appcast.create_item(self.feed, **self.args)
        original = self.feed.read_bytes()
        for build in ["99", "100"]:
            with self.assertRaises(ValueError):
                appcast.create_item(self.feed, **{**self.args, "build": build})
            self.assertEqual(self.feed.read_bytes(), original)

    def test_invalid_inputs_do_not_create_feed(self):
        for changed in [dict(signature="bad"), dict(length=0), dict(build="0"),
                        dict(download_url="http://example.org/app"), dict(download_url="https://user:pass@example.org/app")]:
            with self.assertRaises(ValueError):
                appcast.create_item(self.feed, **{**self.args, **changed})
            self.assertFalse(self.feed.exists())

    def test_same_marketing_version_cannot_publish_different_bytes(self):
        appcast.create_item(self.feed, **self.args)
        original = self.feed.read_bytes()
        with self.assertRaises(ValueError):
            appcast.create_item(self.feed, **{**self.args, "build": "101"})
        self.assertEqual(self.feed.read_bytes(), original)

    def test_test_feed_is_loopback_only(self):
        appcast.create_item(self.feed, **{**self.args, "download_url": "http://127.0.0.1:8765/app.dmg"}, allow_loopback=True)
        with self.assertRaises(ValueError):
            appcast.validate_url("http://example.org/app", True)

    def test_malformed_existing_feed_is_preserved(self):
        self.feed.write_text("<broken>")
        with self.assertRaises(ET.ParseError):
            appcast.create_item(self.feed, **self.args)
        self.assertEqual(self.feed.read_text(), "<broken>")


if __name__ == "__main__":
    unittest.main()
