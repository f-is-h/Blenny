"""Verify evidence conclusions without real system reads or writes."""
import json
from pathlib import Path
import tempfile
import unittest
from evaluate import evaluate


class EvidenceTests(unittest.TestCase):
    def fixture(self, root, swapped=(100, 500), restored=(500, 100), wrong_pid=False):
        identities = ["xyz.fi5h.blenny.research.adoption20260908" + x for x in "ab"]
        result = {"samples": {}, "errors": [], "ownersCleaned": True, "wholeGroupLogicallyUnchanged": True}
        for phase, xs in [("initial", (500, 100)), ("swapped", swapped), ("restored", restored)]:
            result["samples"][phase] = [{"bundle": identity, "pid": 100 + i, "frame": [xs[i], 870, 40, 30]} for i, identity in enumerate(identities)]
            rows = [{"bundle": identity, "ownerPID": 999 if wrong_pid else 100 + i, "x": xs[i] + 7} for i, identity in enumerate(identities)]
            (root / (phase + "-ax.log")).write_text("\n".join(map(json.dumps, rows)))
        (root / "control-result.json").write_text(json.dumps(result))

    def test_swap_and_exact_inverse(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); self.fixture(root)
            result = evaluate(root)
            self.assertTrue(result["swapObserved"] and result["inverseOrderObserved"] and result["exactOwnerXRestored"])

    def test_unchanged_order_is_not_a_swap(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); self.fixture(root, swapped=(500, 100))
            self.assertFalse(evaluate(root)["swapObserved"])

    def test_inverse_order_is_distinct_from_exact_coordinates(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); self.fixture(root, restored=(502, 100))
            result = evaluate(root)
            self.assertTrue(result["inverseOrderObserved"])
            self.assertFalse(result["exactOwnerXRestored"])

    def test_ax_pid_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); self.fixture(root, wrong_pid=True)
            with self.assertRaises(AssertionError): evaluate(root)
