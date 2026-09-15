import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import socket
import struct
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import patch
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    loader = importlib.machinery.SourceFileLoader(name, str(ROOT / "scripts/runtime" / name))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


probe = load("altserver-native-probe")
migration = load("altserver-anisette-migrate")
MAC = ":".join(["ab"] * 6)
UDID = "test-device"


class ProbeTests(unittest.TestCase):
    def test_anisette_protocol_rejects_missing_fields_and_nine_hour_skew(self):
        data = dict.fromkeys(("machineID", "oneTimePassword", "localUserID", "deviceUniqueIdentifier",
                              "deviceSerialNumber", "deviceDescription", "locale", "timeZone"), "fixture")
        data.update(routingInfo="1", date="2026-09-15T15:00:00Z")
        response = dict(identifier="AnisetteDataResponse", version=1, anisetteData=data)
        now = datetime(2026, 9, 15, 15, 0, tzinfo=timezone.utc)
        self.assertTrue(probe.valid_anisette_response(response, now))
        data["date"] = "2026-09-15T06:00:00Z"
        self.assertFalse(probe.valid_anisette_response(response, now))
        data["date"] = "2026-09-15T15:00:00Z"
        data.pop("locale")
        self.assertFalse(probe.valid_anisette_response(response, now))

    def test_fragmented_header_and_body(self):
        with socket.socket() as server:
            server.bind(("127.0.0.1", 0))
            server.listen()
            body = plistlib.dumps({"DeviceList": []})
            packet = struct.pack("<IIII", 16 + len(body), 1, 8, 1) + body

            def serve():
                with server.accept()[0] as peer:
                    header = probe.recv_exact(peer, 16)
                    probe.recv_exact(peer, struct.unpack("<I", header[:4])[0] - 16)
                    for byte in packet:
                        peer.sendall(bytes([byte]))

            thread = threading.Thread(target=serve)
            thread.start()
            self.assertEqual(probe.mux_request({"MessageType": "ListDevices"}, server.getsockname()),
                             {"DeviceList": []})
            thread.join(timeout=2)
            self.assertFalse(thread.is_alive())

    def test_truncated_packet(self):
        fake = unittest.mock.Mock()
        fake.recv.side_effect = [b"abc", b""]
        with self.assertRaises(OSError):
            probe.recv_exact(fake, 16)

    def test_rejects_oversized_packet(self):
        fake = unittest.mock.MagicMock()
        fake.__enter__.return_value = fake
        fake.recv.return_value = struct.pack("<IIII", probe.MAX_PACKET + 1, 1, 8, 1)
        with patch.object(socket, "create_connection", return_value=fake), self.assertRaises(ValueError):
            probe.mux_request({})

    def test_discovery_ignores_other_phone_and_synthetic_feedback(self):
        encoded = MAC.replace(":", r"\058")
        records = "\n".join([
            "=;eth0;IPv4;other@other;_apple-mobdev2._tcp;local;other.local;203.0.113.2;62078;",
            f"=;eth0;IPv4;{encoded}\\064{UDID};_apple-mobdev2._tcp;local;iphone-alt.local;203.0.113.3;62078;",
            f"=;eth0;IPv4;{encoded}\\064real;_apple-mobdev2._tcp;local;phone.local;203.0.113.4;32498;",
        ])
        self.assertEqual(probe.candidates("", records, MAC, UDID, ""), ["203.0.113.4"])

    def test_neighbor_mac_is_exact(self):
        lines = f"203.0.113.5 dev eth0 lladdr {MAC} REACHABLE\n203.0.113.6 dev eth0 lladdr {MAC}00 REACHABLE"
        self.assertEqual(probe.candidates(lines, "", MAC, UDID, ""), ["203.0.113.5"])

    def test_fallback_does_not_trust_an_open_port(self):
        env = {"IPHONE_UDID": UDID, "IPHONE_WIFI_MAC": MAC, "IPHONE_FALLBACK_IP": "203.0.113.8"}
        with patch.dict(os.environ, env), patch.object(probe, "output", return_value=""), \
                patch.object(probe, "port_open", return_value=True), \
                patch.object(probe, "device_identity", return_value=False):
            self.assertIsNone(probe.discover())


@unittest.skipUnless(hasattr(os, "chown"), "requires Linux ownership semantics")
class MigrationTests(unittest.TestCase):
    def test_preserves_existing_container_identity(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "state"

            def docker(*args):
                if args[0] == "ps":
                    return "container-id\n"
                if args[0] == "inspect":
                    return json.dumps([{"Config": {"Image": "dadoum/anisette-v3-server:latest"}}])
                if args[0] == "cp":
                    stage = Path(args[-1])
                    (stage / "device.json").write_text('{"test": "identity"}')
                    (stage / "adi.pb").write_bytes(b"provisioning-fixture")
                    return ""
                self.fail("Unexpected Docker mutation")

            with patch.dict(os.environ, {"ANISETTE_STATE_DIR": str(target)}), \
                    patch.object(migration, "docker", side_effect=docker), patch.object(os, "chown"):
                migration.main()
                migration.main()
            self.assertEqual((target / "adi.pb").read_bytes(), b"provisioning-fixture")
            self.assertEqual((target / "device.json").stat().st_mode & 0o777, 0o600)
            self.assertEqual(len(list(Path(tmp).glob("anisette-backup-*"))), 1)

    def test_incomplete_state_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)
            (target / "device.json").write_text("{}")
            with patch.dict(os.environ, {"ANISETTE_STATE_DIR": str(target)}), self.assertRaises(SystemExit):
                migration.main()


@unittest.skipUnless(os.name == "posix", "requires POSIX shell")
class HealthTests(unittest.TestCase):
    def test_offline_phone_does_not_hide_server_failure_and_cooldown(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            (directory / "config").write_text("")
            (directory / "probe").write_text('#!/bin/sh\ncase "$1" in anisette|query) exit 0;; *) exit 1;; esac\n')
            (directory / "systemctl").write_text('#!/bin/sh\nif [ "$1" = restart ]; then echo "$2" >>"$CALLS"; fi\nexit 0\n')
            (directory / "logger").write_text('#!/bin/sh\nexit 0\n')
            for name in ("probe", "systemctl", "logger"):
                (directory / name).chmod(0o755)
            env = dict(os.environ, ENV_FILE=str(directory / "config"),
                       ALTSERVER_PROBE=str(directory / "probe"), CALLS=str(directory / "calls"),
                       ALTSERVER_HEALTH_STATE_DIR=str(directory / "health"),
                       PATH=str(directory) + os.pathsep + os.environ["PATH"])
            for _ in range(5):
                result = subprocess.run(["sh", str(ROOT / "scripts/runtime/altserver-native-healthcheck")],
                                        env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertNotIn("\nhealthy\n", result.stdout)
            self.assertEqual((directory / "calls").read_text(), "altserver-native.service\n")


if __name__ == "__main__":
    unittest.main()
