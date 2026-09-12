"""Identity ambiguity and lifetime regressions; no real app or preference reads."""
import copy
import unittest
from identity import associate, parse_key


class IdentityTests(unittest.TestCase):
    def snapshot(self, token="Example"):
        app = {"pid": 123, "bundle": "test.example", "executable": "Example", "name": "Example", "launchTime": 100, "system": False}
        key = "status:" + token + "::Item-0"
        return {"table": {key: 120}, "events": [{"key": key, "value": 120, "time": 190}],
                "owners": {"before": [app], "after": [copy.deepcopy(app)],
                           "observations": {"123": {"complete": True, "items": [{"ownerPID": 123, "x": 100}]}}},
                "windowStart": 150, "capturedAt": 200, "groupUnchanged": True}

    def row(self, value):
        return associate(value)["rows"][0]

    def test_exact_fallback_mapping_is_reviewable_but_never_authorized(self):
        row = self.row(self.snapshot())
        self.assertTrue(row["reviewCandidate"])
        self.assertFalse(row["writeAuthorized"])
        self.assertEqual(row["matchedBy"], "executable")

    def test_bundle_mapping_is_separate_from_executable_fallback(self):
        self.assertEqual(self.row(self.snapshot("test.example"))["matchedBy"], "bundle")

    def test_configured_override_can_differ_from_saved_value(self):
        value = self.snapshot(); value["events"] = []
        value["owners"]["ownerPreferences"] = {"test.example": {"keyListObserved": True, "positionsComplete": True, "positions": {"Item-0": 999}}}
        row = self.row(value)
        self.assertTrue(row["configuredReviewCandidate"])
        self.assertFalse(row["reviewCandidate"] or row["writeAuthorized"])

    def test_incomplete_preference_read_is_not_corroboration(self):
        value = self.snapshot(); value["events"] = []
        value["owners"]["ownerPreferences"] = {"test.example": {"keyListObserved": True, "positionsComplete": False, "positions": {"Item-0": 120}}}
        self.assertFalse(self.row(value)["configuredReviewCandidate"])

    def test_keys_preserve_unicode_case_and_spaces(self):
        self.assertEqual(parse_key("status:EX Å::My Item"), ("EX Å", "My Item"))
        self.assertIsNone(parse_key("status:Example::name::ambiguous"))
        self.assertIsNone(parse_key("status:Example::name\n"))

    def test_same_executable_in_two_owners_is_ambiguous(self):
        value = self.snapshot()
        value["owners"]["before"].append(dict(value["owners"]["before"][0], pid=456, bundle="test.other"))
        self.assertIn("owner-token-collision", self.row(value)["reasons"])

    def test_exact_bundle_does_not_override_a_conflicting_executable(self):
        value = self.snapshot("test.example")
        value["owners"]["before"].append(dict(value["owners"]["before"][0], pid=456, bundle="test.other", executable="test.example"))
        self.assertIn("owner-token-collision", self.row(value)["reasons"])

    def test_reused_pid_or_relaunch_invalidates_lifetime(self):
        value = self.snapshot()
        value["owners"]["after"][0]["launchTime"] = 199
        self.assertIn("owner-lifetime-unverified", self.row(value)["reasons"])

    def test_event_before_current_process_start_is_not_live_evidence(self):
        value = self.snapshot()
        value["events"][0]["time"] = 90
        self.assertIn("no-current-lifetime-key-observation", self.row(value)["reasons"])

    def test_future_event_is_not_live_evidence(self):
        value = self.snapshot()
        value["events"][0]["time"] = 201
        self.assertFalse(self.row(value)["reviewCandidate"])

    def test_table_entry_alone_is_not_live_identity(self):
        value = self.snapshot(); value["events"] = []
        self.assertFalse(self.row(value)["reviewCandidate"])

    def test_multi_item_bundle_cannot_be_silently_partially_selected(self):
        value = self.snapshot()
        value["owners"]["observations"]["123"]["items"].append({"ownerPID": 123, "x": 140})
        self.assertIn("single-live-item-not-established", self.row(value)["reasons"])

    def test_stale_extra_key_blocks_single_key_selection(self):
        value = self.snapshot(); value["table"]["status:Example::Old-Item"] = 160
        self.assertTrue(all(not row["reviewCandidate"] for row in associate(value)["rows"]))

    def test_ax_other_pid_or_incomplete_is_not_confirmation(self):
        value = self.snapshot(); value["owners"]["observations"]["123"]["items"][0]["ownerPID"] = 999
        self.assertIn("AX-incomplete", self.row(value)["reasons"])

    def test_system_owner_and_group_drift_remain_blocked(self):
        value = self.snapshot(); value["owners"]["before"][0]["system"] = True
        value["groupUnchanged"] = False
        row = self.row(value)
        self.assertIn("system-owner-excluded", row["reasons"])
        self.assertIn("group-drift-during-capture", row["reasons"])

    def test_boolean_is_not_a_numeric_position_contract(self):
        value = self.snapshot(); value["table"][next(iter(value["table"]))] = True
        self.assertIn("configured-position-contract-differs", self.row(value)["reasons"])

    def test_several_processes_for_one_bundle_are_not_one_owner(self):
        value = self.snapshot()
        value["owners"]["before"].append(dict(value["owners"]["before"][0], pid=456, executable="Different"))
        self.assertIn("bundle-owner-ambiguous", self.row(value)["reasons"])


if __name__ == "__main__":
    unittest.main()
