import importlib.machinery
import os
from pathlib import Path
from unittest.mock import patch
import unittest

p = importlib.machinery.SourceFileLoader("registration_probe", str(
    Path(__file__).resolve().parents[1] / "scripts/runtime/altserver-native-probe")).load_module()


class RegistrationTests(unittest.TestCase):
    def test_api_registers_only_verified_missing_device(self):
        with patch.dict(os.environ, {"NETMUXD_REGISTER_MODE": "api", "IPHONE_UDID": "test-device"}), \
             patch.object(p.sys, "argv", ["probe", "register", "192.0.2.10"]), \
             patch.object(p, "discover", return_value="192.0.2.10"), \
             patch.object(p, "has_device", side_effect=[False, True]), \
             patch.object(p, "mux_request", return_value={"Result": 1}) as request:
            self.assertEqual(p.main(), 0)
            self.assertEqual(request.call_args.args[0]["IPAddress"], "192.0.2.10")
            self.assertEqual(request.call_args.args[0]["DeviceID"], "test-device")

    def test_no_api_for_unverified_address(self):
        with patch.dict(os.environ, {"NETMUXD_REGISTER_MODE": "api", "IPHONE_UDID": "test-device"}), \
             patch.object(p.sys, "argv", ["probe", "register", "192.0.2.10"]), \
             patch.object(p, "discover", return_value=None), \
             patch.object(p, "mux_request") as request:
            self.assertEqual(p.main(), 2)
            request.assert_not_called()

    def test_existing_device_is_not_added_twice(self):
        with patch.dict(os.environ, {"NETMUXD_REGISTER_MODE": "api", "IPHONE_UDID": "test-device"}), \
             patch.object(p.sys, "argv", ["probe", "register", "192.0.2.10"]), \
             patch.object(p, "discover", return_value="192.0.2.10"), \
             patch.object(p, "has_device", return_value=True), \
             patch.object(p, "mux_request") as request:
            self.assertEqual(p.main(), 0)
            request.assert_not_called()

    def test_old_profile_keeps_mdns_path(self):
        with patch.dict(os.environ, {"NETMUXD_REGISTER_MODE": "mdns", "IPHONE_UDID": "test-device"}), \
             patch.object(p.sys, "argv", ["probe", "register", "192.0.2.10"]), \
             patch.object(p, "discover", return_value="192.0.2.10"), \
             patch.object(p, "has_device", side_effect=[False, True]), \
             patch.object(p, "mux_request") as request, \
             patch.object(p.subprocess, "run") as run, patch.object(p.time, "sleep"):
            self.assertEqual(p.main(), 0)
            request.assert_not_called()
            run.assert_called_once()


if __name__ == "__main__":
    unittest.main()
