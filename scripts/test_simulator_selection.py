import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("selector", Path(__file__).with_name("select-simulator.py"))
selector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(selector)
OLD = "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
NEW = "com.apple.CoreSimulator.SimRuntime.iOS-27-0"


class SimulatorSelectionTests(unittest.TestCase):
    def setUp(self):
        self.devices = {
            OLD: [dict(name="iPhone", udid="old", isAvailable=True)],
            NEW: [dict(name="iPhone", udid="new", isAvailable=True)],
        }

    def test_ambiguous_name_fails_with_actionable_ids(self):
        with self.assertRaisesRegex(ValueError, "IOS_SIMULATOR_UDID"):
            selector.select(self.devices, "iPhone")

    def test_runtime_pins_name(self):
        self.assertEqual(selector.select(self.devices, "iPhone", runtime=OLD)[1]["udid"], "old")

    def test_id_takes_precedence_over_default_name(self):
        self.assertEqual(selector.select(self.devices, "other", udid="new")[0], NEW)

    def test_conflicting_runtime_fails(self):
        with self.assertRaises(ValueError):
            selector.select(self.devices, "iPhone", udid="old", runtime=NEW)

    def test_unavailable_id_fails(self):
        self.devices[OLD][0]["isAvailable"] = False
        with self.assertRaises(ValueError):
            selector.select(self.devices, "iPhone", udid="old")

    def test_unique_name_resolves(self):
        del self.devices[NEW]
        self.assertEqual(selector.select(self.devices, "iPhone")[1]["udid"], "old")

    def test_unknown_id_does_not_fall_back(self):
        with self.assertRaises(ValueError):
            selector.select(self.devices, "iPhone", udid="missing")

    def test_non_ios_device_excluded(self):
        with self.assertRaises(ValueError):
            selector.select({"com.apple.CoreSimulator.SimRuntime.tvOS-27-0": self.devices[OLD]}, "iPhone")


if __name__ == "__main__":
    unittest.main()
