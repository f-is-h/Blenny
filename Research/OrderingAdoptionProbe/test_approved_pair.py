"""Bounded real-pair controller tests with entirely fake readers and writer."""
import json
import plistlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import run_approved_pair as trial


class ApprovedPairTests(unittest.TestCase):
    def exercise(self, failure=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            group = root / "Library/Group Containers/com.apple.MenuBar/Library/Preferences/com.apple.MenuBar.plist"
            group.parent.mkdir(parents=True)
            before = {"TrailingItemPreferredPositions": {"a": 995.0, "b": 581.0, "unrelated": 42}}
            group.write_bytes(plistlib.dumps(before)); (root / "group-before.plist").write_bytes(plistlib.dumps(before))
            owners = {"before": [{"bundle": bundle, "pid": i + 100} for i, bundle in enumerate(trial.BUNDLES)],
                      "ownerPreferences": {bundle: {"positions": {"Item-0": 123}} for bundle in trial.BUNDLES}}
            (root / "snapshot.json").write_text(json.dumps({"owners": owners}))
            writes = []

            def fake_call(args):
                if args[0] == "writer":
                    phase = args[-1]; writes.append(phase)
                    receipt = root / ("external-" + phase + ".json")
                    receipt.write_text(json.dumps({"intent": True}))
                    if phase == "restore" and failure == "inverse": raise RuntimeError("fake failed inverse")
                    data = plistlib.loads(group.read_bytes())
                    data["TrailingItemPreferredPositions"].update({"a": 581.0, "b": 995.0} if phase == "apply" else {"a": 995.0, "b": 581.0})
                    group.write_bytes(plistlib.dumps(data))
                    if phase == "apply" and failure == "partial-apply": raise RuntimeError("apply verification lost")
                    receipt.write_text(json.dumps({"completed": True}))
                    return ""
                if args[0] == "owner-reader": return json.dumps(owners)
                self.assertEqual(args[0], "reader")
                swapped = plistlib.loads(group.read_bytes())["TrailingItemPreferredPositions"]["a"] == 581.0
                if failure == "incomplete-initial" and not writes: return "DONE complete=false"
                xs = [300, 100] if swapped else [100, 300]
                rows = [{"bundle": bundle, "ownerPID": i + 100, "x": xs[i], "y": 3, "width": 24, "height": 24} for i, bundle in enumerate(trial.BUNDLES)]
                return "\n".join(map(json.dumps, rows)) + "\nDONE complete=true"

            with patch.object(Path, "home", return_value=root), patch.object(trial, "call", side_effect=fake_call), patch.object(trial.time, "sleep"), patch("builtins.print"):
                result = trial.execute(root, "writer", "reader", "owner-reader", hold_seconds=0)
                if failure == "inverse":
                    with self.assertRaises(RuntimeError): trial.restore_once(root, "writer")
            return result, writes

    def test_success_is_corroborated_and_restored(self):
        result, writes = self.exercise()
        self.assertEqual(writes, ["apply", "restore"])
        self.assertTrue(result["swapObserved"] and result["inverseOrderObserved"] and result["exactAXGeometryRestored"])
        self.assertTrue(result["wholeGroupRestored"] and result["ownerPreferencesRestored"])

    def test_partial_apply_runs_inverse(self):
        result, writes = self.exercise("partial-apply")
        self.assertEqual(writes, ["apply", "restore"])
        self.assertTrue(result["wholeGroupRestored"])
        self.assertTrue(result["errors"])

    def test_failed_inverse_is_not_retried_by_watchdog(self):
        result, writes = self.exercise("inverse")
        self.assertEqual(writes, ["apply", "restore"])
        self.assertFalse(result["wholeGroupRestored"])

    def test_incomplete_initial_read_prevents_apply(self):
        result, writes = self.exercise("incomplete-initial")
        self.assertFalse(writes)
        self.assertTrue(result["wholeGroupRestored"])
