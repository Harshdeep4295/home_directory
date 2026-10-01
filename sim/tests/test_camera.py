"""Camera discovery sims checked against the reference clients: WSDiscovery 2.1.2 (ONVIF
WS-Discovery) and hiktools 1.2.2 (Hikvision SADP); RTSP digest per RFC 2617."""

import asyncio
import hashlib
import re
from uuid import uuid4

from hiktools import sadp
from wsdiscovery import QName
from wsdiscovery.actions.probe import constructProbe, createProbeMessage
from wsdiscovery.message import parseSOAPMessage

from ohsim.devices.camera import NS_ONVIF_NETWORK, OnvifSim, RtspSim, SadpSim


async def _udp(host: str, port: int, payload: bytes) -> bytes:
    loop = asyncio.get_running_loop()
    fut: asyncio.Future[bytes] = loop.create_future()

    class _P(asyncio.DatagramProtocol):
        def datagram_received(self, data: bytes, addr: tuple[str, int]) -> None:
            if not fut.done():
                fut.set_result(data)

    t, _ = await loop.create_datagram_endpoint(_P, remote_addr=(host, port))
    try:
        t.sendto(payload)
        return await asyncio.wait_for(fut, 1.0)
    finally:
        t.close()


async def test_onvif_probe_match_parsed_by_wsdiscovery() -> None:
    async with OnvifSim(model="CS-C6N", vendor="EZVIZ") as sim:
        env = constructProbe([QName(NS_ONVIF_NETWORK, "NetworkVideoTransmitter", "dn")], [])
        reply = await _udp(sim.host, sim.port, createProbeMessage(env).encode())
        match = parseSOAPMessage(reply, sim.host)
        assert match is not None
        assert match.getRelatesTo() == env.getMessageId()
        (pm,) = match.getProbeResolveMatches()
        assert [t.getLocalname() for t in pm.getTypes()] == ["NetworkVideoTransmitter"]
        scopes = [s.getValue() for s in pm.getScopes()]
        assert "onvif://www.onvif.org/name/EZVIZ" in scopes
        assert "onvif://www.onvif.org/hardware/CS-C6N" in scopes
        assert pm.getXAddrs() == [f"http://{sim.host}/onvif/device_service"]


async def test_sadp_inquiry_via_hiktools() -> None:
    async with SadpSim(model="CS-C6N-A0-1C2WFR") as sim:
        inquiry = sadp.fromdict({"Uuid": str(uuid4()).upper(), "MAC": "ff-ff-ff-ff-ff-ff", "Types": "inquiry"})
        reply = await _udp(sim.host, sim.port, bytes(inquiry))
        msg = sadp.unmarshal(sadp.SADPMessage(response=reply).toxml())
        assert isinstance(msg, sadp.DiscoveryPacket)
        assert msg["DeviceDescription"] == "CS-C6N-A0-1C2WFR"
        assert msg["Ipv4Address"] == sim.host
        assert msg["Activated"] == "true"


async def _rtsp(port: int, req: str) -> str:
    r, w = await asyncio.open_connection("127.0.0.1", port)
    w.write(req.encode())
    await w.drain()
    head = (await r.readuntil(b"\r\n\r\n")).decode()
    if m := re.search(r"Content-Length: (\d+)", head):
        head += (await r.readexactly(int(m.group(1)))).decode()
    w.close()
    return head


async def test_rtsp_options_and_digest_describe() -> None:
    async with RtspSim(password="QWERTY") as sim:
        opt = await _rtsp(sim.port, f"OPTIONS rtsp://127.0.0.1:{sim.port}/ RTSP/1.0\r\nCSeq: 1\r\n\r\n")
        assert opt.startswith("RTSP/1.0 200") and "Server: Hikvision RTSP Server" in opt
        url = f"rtsp://127.0.0.1:{sim.port}/Streaming/Channels/101"
        first = await _rtsp(sim.port, f"DESCRIBE {url} RTSP/1.0\r\nCSeq: 2\r\n\r\n")
        assert first.startswith("RTSP/1.0 401")
        realm = re.search(r'realm="([^"]+)"', first).group(1)
        nonce = re.search(r'nonce="([^"]+)"', first).group(1)

        def auth(pw: str) -> str:
            ha1 = hashlib.md5(f"admin:{realm}:{pw}".encode()).hexdigest()
            ha2 = hashlib.md5(f"DESCRIBE:{url}".encode()).hexdigest()
            resp = hashlib.md5(f"{ha1}:{nonce}:{ha2}".encode()).hexdigest()
            return f'Digest username="admin", realm="{realm}", nonce="{nonce}", uri="{url}", response="{resp}"'

        # A fresh connection gets a fresh nonce, so authenticate on one connection.
        r, w = await asyncio.open_connection("127.0.0.1", sim.port)
        w.write(f"DESCRIBE {url} RTSP/1.0\r\nCSeq: 3\r\n\r\n".encode())
        head = (await r.readuntil(b"\r\n\r\n")).decode()
        nonce = re.search(r'nonce="([^"]+)"', head).group(1)
        w.write(f"DESCRIBE {url} RTSP/1.0\r\nCSeq: 4\r\nAuthorization: {auth('nope')}\r\n\r\n".encode())
        assert (await r.readuntil(b"\r\n\r\n")).decode().startswith("RTSP/1.0 401")
        w.write(f"DESCRIBE {url} RTSP/1.0\r\nCSeq: 5\r\nAuthorization: {auth('QWERTY')}\r\n\r\n".encode())
        ok = (await r.readuntil(b"\r\n\r\n")).decode()
        assert ok.startswith("RTSP/1.0 200") and "application/sdp" in ok
        w.close()
