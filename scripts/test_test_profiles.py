"""Verify test selection and destination without launching Xcode or any device."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class TestProfilesTests(unittest.TestCase):
    def run_profile(self, profile, device=""):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            recorder = folder / "args"
            xcodebuild = folder / "xcodebuild"
            xcodebuild.write_text('#!/bin/bash\nif [[ "$1" != "-version" ]]; then printf "%s\\n" "$@" > "$PROFILE_ARGS"; fi\n')
            xcodebuild.chmod(0o755)
            xcrun = folder / "xcrun"
            payload = {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
                {"name": "iPhone 17 Pro", "udid": "sim-test", "isAvailable": True}
            ]}}
            xcrun.write_text("#!/bin/bash\ncat <<'JSON'\n" + json.dumps(payload) + "\nJSON\n")
            xcrun.chmod(0o755)
            env = {k: v for k, v in os.environ.items() if not k.startswith("IOS_")}
            env.update(PATH=directory + os.pathsep + env["PATH"], PROFILE_ARGS=str(recorder),
                       IOS_TEST_PROFILE=profile, IOS_DEVICE_UDID=device)
            result = subprocess.run(["bash", str(ROOT / "scripts/test-ios.sh")], env=env,
                                    capture_output=True, text=True)
            return result, recorder.read_text().splitlines() if recorder.exists() else []

    def test_simulator_reports_every_exclusion(self):
        result, args = self.run_profile("simulator")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("platform=iOS Simulator,id=sim-test", args)
        excluded = [arg for arg in args if arg.startswith("-skip-testing:")]
        self.assertEqual(len(excluded), 9)
        for arg in excluded:
            self.assertIn(arg.split(":", 1)[1], result.stderr)

    def test_device_requires_id_and_never_falls_back(self):
        result, args = self.run_profile("device")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(args, [])

    def test_device_selects_real_inference_suite(self):
        result, args = self.run_profile("device", "physical-test")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("platform=iOS,id=physical-test", args)
        self.assertEqual(len([arg for arg in args if arg.startswith("-only-testing:")]), 9)
        self.assertFalse(any(arg.startswith("-skip-testing:") for arg in args))

    def test_unknown_profile_fails_before_test(self):
        result, args = self.run_profile("typo")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(args, [])


if __name__ == "__main__":
    unittest.main()
