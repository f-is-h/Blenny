"""Deterministic controller failure checks. Never launch a Mac application."""
import contextlib
import io
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import run_control


class ControlFailures(unittest.TestCase):
    def exercise(self, failure):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            group = root / "Library/Group Containers/com.apple.MenuBar/Library/Preferences/com.apple.MenuBar.plist"
            group.parent.mkdir(parents=True)
            original = {"TrailingItemPreferredPositions": {"untouched": 42}, "unrelated": True}
            group.write_bytes(plistlib.dumps(original))
            identities = ["xyz.fi5h.blenny.research.adoption20260908" + x for x in "ab"]
            stopped = []
            signals = []
            states = dict(zip(identities, [120, 1000]))
            preflights = 0

            def fake_run(arguments, **kwargs):
                nonlocal preflights
                if "--preflight" in arguments:
                    preflights += 1
                    code = 2 if failure == "cleanup" and preflights == 2 else 0
                    return subprocess.CompletedProcess(arguments, code, "", "")
                if "--signal" in arguments:
                    identity, command = arguments[-2:]
                    signals.append((identity, command))
                    if command == "stop":
                        stopped.append(identity)
                    elif failure == "missing-receipt" and command == "swap":
                        pass
                    else:
                        if command == "swap":
                            states[identity] = 1000 if identity == identities[0] else 120
                        elif command == "restore":
                            states[identity] = 120 if identity == identities[0] else 1000
                        record = {"completed": True, "bundle": identity, "saved": states[identity], "autosave": "AdoptionProbe" + ("A" if identity == identities[0] else "B"), "pid": identities.index(identity) + 100, "itemObject": "fixture", "frame": [100 + 40 * identities.index(identity), 870, 40, 30]}
                        (root / (identity + "-" + command + ".json")).write_text(json.dumps(record))
                    return subprocess.CompletedProcess(arguments, 0, "", "")
                if arguments[0].endswith("group-writer"):
                    phase = arguments[-1]
                    signals.append(("external", phase))
                    receipt = root / ("external-" + phase + ".json")
                    receipt.write_text(json.dumps({"intent": True}))
                    state = plistlib.loads(group.read_bytes())
                    keys = ["status:OrderingAdoption" + suffix + "::AdoptionProbe" + suffix for suffix in "AB"]
                    if phase == "apply":
                        state["TrailingItemPreferredPositions"].update(dict(zip(keys, [1000, 120])))
                        group.write_bytes(plistlib.dumps(state))
                        if failure == "partial-external-apply":
                            raise subprocess.CalledProcessError(2, arguments)
                    else:
                        if failure == "external-restore":
                            raise subprocess.CalledProcessError(2, arguments)
                        for key in keys:
                            state["TrailingItemPreferredPositions"].pop(key)
                        group.write_bytes(plistlib.dumps(state))
                    receipt.write_text(json.dumps({"completed": True, "writes": 1}))
                    return subprocess.CompletedProcess(arguments, 0, "", "")
                if arguments[0].endswith("fake-reader"):
                    if failure == "group-drift":
                        changed = dict(original, unrelated=False)
                        group.write_bytes(plistlib.dumps(changed))
                    rows = [{"bundle": identity, "x": 200 if failure == "unstable-baseline" else 107 + 40 * index} for index, identity in enumerate(identities)]
                    return subprocess.CompletedProcess(arguments, 0, "\n".join(json.dumps(row) for row in rows) + "\nDONE complete=true\n", "")
                if arguments[0] == "/usr/bin/log":
                    log = "\n".join(f"Using legacy NSStatusItemHost preferredPosition {states[identity]}.000000 for status:OrderingAdoption{suffix}::AdoptionProbe{suffix}" for identity, suffix in zip(identities, "AB"))
                    return subprocess.CompletedProcess(arguments, 0, log, "")
                self.assertEqual(arguments[0], "/usr/bin/open")
                return subprocess.CompletedProcess(arguments, 0, "", "")

            argv = ["run_control.py", "--artifacts", str(root), "--reader", str(root / "fake-reader")]
            if failure in ["partial-external-apply", "external-restore"]:
                argv.append("--external")
            if failure == "scene-input":
                argv.append("--settings-only")
            if failure == "scene-identity":
                argv.append("--snapshot-only")
            with patch.object(sys, "argv", argv), patch.object(Path, "home", return_value=root), patch.object(run_control.subprocess, "run", side_effect=fake_run), patch.object(run_control.time, "sleep"), contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaises(SystemExit) as raised:
                    run_control.run()
                self.assertEqual(raised.exception.code, 2)
            self.assertEqual(stopped, identities)
            result = json.loads((root / "control-result.json").read_text())
            return result, plistlib.loads(group.read_bytes()), signals

    def test_partial_external_apply_executes_inverse_before_owner_cleanup(self):
        result, group, signals = self.exercise("partial-external-apply")
        self.assertTrue(result["wholeGroupLogicallyUnchanged"])
        self.assertEqual([command for owner, command in signals if owner == "external"], ["apply", "restore"])
        self.assertLess(signals.index(("external", "restore")), next(i for i, (_, command) in enumerate(signals) if command == "stop"))
        self.assertEqual(group["TrailingItemPreferredPositions"], {"untouched": 42})

    def test_failed_external_inverse_is_not_retried_or_reported_restored(self):
        result, _, signals = self.exercise("external-restore")
        self.assertFalse(result["wholeGroupLogicallyUnchanged"])
        self.assertEqual([command for owner, command in signals if owner == "external"], ["apply", "restore"])
        self.assertFalse(any(command == "swap" for _, command in signals))

    def test_missing_receipt_stops_both_and_does_not_send_next_mutation(self):
        result, group, signals = self.exercise("missing-receipt")
        self.assertTrue(result["errors"])
        self.assertTrue(result["ownersCleaned"])
        self.assertTrue(result["wholeGroupLogicallyUnchanged"])
        self.assertEqual(sum(command == "swap" for _, command in signals), 1)
        self.assertTrue(group["unrelated"])

    def test_foreign_drift_is_preserved_and_stops_before_position_change(self):
        result, group, signals = self.exercise("group-drift")
        self.assertFalse(result["wholeGroupLogicallyUnchanged"])
        self.assertFalse(group["unrelated"])
        self.assertFalse(any(command == "swap" for _, command in signals))

    def test_failed_cleanup_cannot_be_reported_as_success(self):
        result, _, _ = self.exercise("cleanup")
        self.assertFalse(result["ownersCleaned"])
        self.assertFalse(result["errors"])

    def test_coincident_ax_baseline_prevents_position_mutation(self):
        result, _, signals = self.exercise("unstable-baseline")
        self.assertTrue(result["errors"])
        self.assertFalse(any(command == "swap" for _, command in signals))

    def test_missing_scene_input_stops_before_position_send(self):
        result, _, signals = self.exercise("scene-input")
        self.assertTrue(result["errors"])
        self.assertFalse(any(command == "swap" for _, command in signals))

    def test_snapshot_mode_requires_scene_identity_and_sends_no_position(self):
        result, _, signals = self.exercise("scene-identity")
        self.assertTrue(result["errors"])
        self.assertFalse(any(command == "swap" for _, command in signals))


class AdoptionLogTests(unittest.TestCase):
    def test_old_colliding_fixture_is_rejected(self):
        with self.assertRaises(AssertionError):
            run_control.adopted_inputs("Using legacy NSStatusItemHost preferredPosition 120.000000 for status:probe::AdoptionProbe")

    def test_ambiguous_key_for_same_autosave_is_rejected(self):
        with self.assertRaises(AssertionError):
            run_control.adopted_inputs("\n".join(f"Using legacy NSStatusItemHost preferredPosition 120.000000 for status:{key}::AdoptionProbeA" for key in ["first", "second"]))

    def test_actual_fallback_keys_and_latest_values_are_retained(self):
        log = "\n".join(f"Using legacy NSStatusItemHost preferredPosition {value} for status:OrderingAdoption{suffix}::AdoptionProbe{suffix}" for suffix, value in [("A", 120), ("B", 1000), ("A", 1000), ("B", 120)])
        result = run_control.adopted_inputs(log)
        self.assertEqual(result["AdoptionProbeA"], {"key": "status:OrderingAdoptionA::AdoptionProbeA", "value": 1000})
        self.assertEqual(result["AdoptionProbeB"]["value"], 120)


if __name__ == "__main__":
    unittest.main()
