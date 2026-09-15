import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
import plistlib
import struct

spec = importlib.util.spec_from_file_location(
    "compatibility", Path(__file__).resolve().parents[1] / "tools/check-netmux-compatibility.py")
compat = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compat)


class WireFormatTests(unittest.TestCase):
    def test_observed_release_formats(self):
        self.assertEqual(compat.classify(bytes.fromhex("0a020000c0000201") + bytes(144)), "legacy-bsd-ipv4")
        for size in (128, 152):
            self.assertEqual(compat.classify(bytes.fromhex("02000000c0000201") + bytes(size - 8)),
                             "native-linux-ipv4-incompatible")

    def test_bsd_ipv6_and_linux_ipv6_are_distinct(self):
        self.assertEqual(compat.classify(bytes.fromhex("1c1e0000") + bytes(24)), "bsd-ipv6")
        self.assertEqual(compat.classify(bytes.fromhex("0a000000") + bytes(24)),
                         "native-or-malformed-ipv6-incompatible")

    def test_short_and_invalid_values_fail_closed(self):
        for value in (None, "02000000", b"", b"\x02\x00", b"\x10\x02" + bytes(6)):
            self.assertNotIn(compat.classify(value), ("legacy-bsd-ipv4", "bsd-ipv4", "bsd-ipv6"))

    def inspect_response(self, payload=None, raw=None):
        if raw is None:
            body = plistlib.dumps(payload)
            raw = struct.pack("<IIII", len(body) + 16, 1, 8, 1) + body

        class FragmentedSocket:
            def __init__(self):
                self.data = raw

            def __enter__(self):
                return self

            def __exit__(self, *args):
                pass

            def sendall(self, request):
                assert plistlib.loads(request[16:])["MessageType"] == "ListDevices"

            def recv(self, count):
                chunk = self.data[:min(count, 3)]
                self.data = self.data[len(chunk):]
                return chunk

        with patch.object(compat.socket, "create_connection", return_value=FragmentedSocket()):
            return compat.inspect("127.0.0.1", 27015)

    def test_fragmented_wire_response(self):
        self.assertEqual(self.inspect_response({"DeviceList": [{"Properties": {
            "ConnectionType": "Network", "NetworkAddress": b"\x02\x00" + bytes(126)}}]}),
            ["native-linux-ipv4-incompatible"])

    def test_no_network_device_is_inconclusive(self):
        self.assertEqual(self.inspect_response({"DeviceList": []}), [])
        self.assertEqual(self.inspect_response({"DeviceList": [
            {"Properties": {"ConnectionType": "USB"}}]}), [])

    def test_truncation_and_invalid_frame_rejected(self):
        for raw in (b"\x10", struct.pack("<IIII", 100, 1, 8, 1),
                    struct.pack("<IIII", compat.MAX_FRAME + 1, 1, 8, 1),
                    struct.pack("<IIII", 100, 1, 8, 2)):
            with self.assertRaises(ValueError):
                self.inspect_response(raw=raw)

    def test_invalid_list_rejected(self):
        for payload in ({}, {"DeviceList": {}}, {"DeviceList": ["invalid"]}):
            with self.assertRaises(ValueError):
                self.inspect_response(payload)


if __name__ == "__main__":
    unittest.main()
