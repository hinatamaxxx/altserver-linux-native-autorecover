import asyncio
import importlib.machinery
from pathlib import Path
import plistlib
import struct
import unittest
import os

adapter = importlib.machinery.SourceFileLoader("adapter", str(
    Path(__file__).resolve().parents[1] / "scripts/runtime/altserver-netmux-compat")).load_module()


def packet(payload, tag=1):
    body = plistlib.dumps(payload)
    return struct.pack("<IIII", len(body) + 16, 1, 8, tag) + body


class AdapterTests(unittest.IsolatedAsyncioTestCase):
    async def run_pair(self, backend, client):
        server = await asyncio.start_server(backend, "127.0.0.1", 0)
        instance = adapter.Adapter(server.sockets[0].getsockname()[1])
        proxy = await asyncio.start_server(instance.handle, "127.0.0.1", 0)
        try:
            reader, writer = await asyncio.open_connection("127.0.0.1", proxy.sockets[0].getsockname()[1])
            try:
                await asyncio.wait_for(client(reader, writer), 5)
            finally:
                writer.close()
                await writer.wait_closed()
        finally:
            proxy.close()
            server.close()
            await proxy.wait_closed()
            await server.wait_closed()

    async def test_list_and_unsolicited_attached(self):
        address = b"\x02\x00" + bytes(126)
        properties = {"ConnectionType": "Network", "NetworkAddress": address}
        async def backend(r, w):
            await adapter.frame(r)
            for data in ({"DeviceList": [{"Properties": properties}]},
                         {"MessageType": "Attached", "Properties": properties}):
                for byte in packet(data):
                    w.write(bytes([byte]))
                    await w.drain()
            w.close()
        async def client(r, w):
            w.write(packet({"MessageType": "ListDevices"}))
            for key in ("DeviceList", "Properties"):
                _, _, data = await adapter.frame(r)
                props = data[key][0]["Properties"] if key == "DeviceList" else data[key]
                self.assertEqual(props["NetworkAddress"], b"\x10\x02" + address[2:])
        await self.run_pair(backend, client)

    async def test_pair_record_wire_unchanged(self):
        response = packet({"PairRecordData": b"opaque-test-bytes"}, 7)
        async def backend(r, w):
            await adapter.frame(r)
            w.write(response)
            await w.drain()
            w.close()
        async def client(r, w):
            w.write(packet({"MessageType": "ReadPairRecord"}, 7))
            self.assertEqual(await r.readexactly(len(response)), response)
        await self.run_pair(backend, client)

    @unittest.skipIf(os.name == "nt", "Windows Proactor streams do not support write_eof")
    async def test_connect_tunnel_and_client_half_close(self):
        data = b"\x00\xffraw-service-stream" * 5000
        async def backend(r, w):
            await adapter.frame(r)
            w.write(packet({"MessageType": "Result", "Number": 0}, 9))
            await w.drain()
            received = await r.read()
            w.write(received)
            await w.drain()
            w.close()
        async def client(r, w):
            w.write(packet({"MessageType": "Connect", "PortNumber": 1234}, 9))
            _, _, reply = await adapter.frame(r)
            self.assertEqual(reply["Number"], 0)
            w.write(data)
            await w.drain()
            w.write_eof()
            self.assertEqual(await r.read(), data)
        await self.run_pair(backend, client)

    async def test_rejected_connect_stays_framed(self):
        async def backend(r, w):
            await adapter.frame(r)
            w.write(packet({"MessageType": "Result", "Number": 1}, 9))
            await w.drain()
            await adapter.frame(r)
            w.write(packet({"DeviceList": []}, 10))
            await w.drain()
            w.close()
        async def client(r, w):
            w.write(packet({"MessageType": "Connect"}, 9))
            _, _, response = await adapter.frame(r)
            self.assertEqual(response["Number"], 1)
            w.write(packet({"MessageType": "ListDevices"}, 10))
            _, tag, response = await adapter.frame(r)
            self.assertEqual((tag, response), (10, {"DeviceList": []}))
        await self.run_pair(backend, client)

    async def test_oversized_client_frame_closed(self):
        async def backend(r, w):
            await r.read()
            w.close()
        async def client(r, w):
            w.write(struct.pack("<IIII", adapter.MAX_FRAME + 1, 1, 8, 1))
            await w.drain()
            self.assertEqual(await r.read(), b"")
        await self.run_pair(backend, client)

    def test_addresses(self):
        ipv6 = b"\x0a\x00" + bytes(range(2, 28))
        self.assertEqual(adapter.bsd_address(ipv6), b"\x1c\x1e" + ipv6[2:])
        bsd = b"\x10\x02" + bytes(126)
        self.assertEqual(adapter.bsd_address(bsd), bsd)
        with self.assertRaises(ValueError):
            adapter.bsd_address(b"\x02\x00")


if __name__ == "__main__":
    unittest.main()
