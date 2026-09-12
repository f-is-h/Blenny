"""Pure serialization, stale-state, scope and inverse tests."""
import copy
import json
import unittest
from preview_order import make_plan, transition
import test_identity


class PreviewTests(unittest.TestCase):
    def fixture(self, absent=False):
        value = test_identity.IdentityTests().snapshot("test.example")
        app = dict(value["owners"]["before"][0], pid=456, bundle="test.second", executable="Second")
        value["owners"]["before"].append(app)
        value["owners"]["after"].append(copy.deepcopy(app))
        value["owners"]["observations"]["456"] = {"complete": True, "items": [{"ownerPID": 456, "x": 300}]}
        key = "status:test.second::Item-0"
        value["events"].append({"key": key, "value": 900, "time": 190})
        if not absent: value["table"][key] = 900
        value["table"]["module:untouched"] = 42
        return value, make_plan(value, ["test.example", "test.second"])

    def test_serialized_swap_restores_existing_values_and_preserves_unrelated(self):
        value, plan = self.fixture()
        plan = json.loads(json.dumps(plan))
        applied = transition(plan, value["table"], "apply")
        self.assertNotEqual(applied, value["table"])
        self.assertEqual(transition(plan, applied, "restore"), value["table"])
        self.assertFalse(plan["writeAuthorized"])

    def test_absent_key_is_removed_during_inverse(self):
        value, plan = self.fixture(absent=True)
        self.assertEqual(transition(plan, transition(plan, value["table"], "apply"), "restore"), value["table"])

    def test_stale_baseline_rejects_apply(self):
        value, plan = self.fixture(); value["table"]["module:untouched"] = 43
        with self.assertRaises(AssertionError): transition(plan, value["table"], "apply")

    def test_inverse_preserves_unrelated_drift(self):
        value, plan = self.fixture(); applied = transition(plan, value["table"], "apply")
        applied["new-foreign-key"] = 55
        restored = transition(plan, applied, "restore")
        self.assertEqual(restored, dict(value["table"], **{"new-foreign-key": 55}))

    def test_target_drift_rejects_without_mutating_input(self):
        value, plan = self.fixture(); applied = transition(plan, value["table"], "apply")
        applied[plan["targets"][1]["key"]] = 777
        original = copy.deepcopy(applied)
        with self.assertRaises(AssertionError): transition(plan, applied, "restore")
        self.assertEqual(original, applied)

    def test_partial_known_apply_can_be_recovered(self):
        value, plan = self.fixture(); partial = copy.deepcopy(value["table"])
        target = plan["targets"][0]; partial[target["key"]] = target["after"]
        self.assertEqual(transition(plan, partial, "restore"), value["table"])

    def test_tampered_plan_is_rejected(self):
        value, plan = self.fixture(); plan["targets"][0]["key"] = "module:untouched"
        with self.assertRaises(AssertionError): transition(plan, value["table"], "apply")

    def test_duplicate_or_system_selection_rejected(self):
        value, _ = self.fixture()
        with self.assertRaises(AssertionError): make_plan(value, ["test.example", "test.example"])
        value["owners"]["before"][0]["system"] = True
        with self.assertRaises(AssertionError): make_plan(value, ["test.example", "test.second"])
