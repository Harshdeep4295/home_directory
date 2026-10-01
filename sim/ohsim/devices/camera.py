"""IP-camera discovery simulators: ONVIF WS-Discovery, Hikvision SADP and RTSP.

- ``OnvifSim`` answers a WS-Discovery ``Probe`` (UDP, normally multicast 239.255.255.250:3702)
  with a ``ProbeMatches`` envelope. Namespaces/actions per python WSDiscovery 2.1.2
  (wsdiscovery/namespaces.py, actions/probematch.py); scopes per the ONVIF Core spec
  (``onvif://www.onvif.org/<type|name|hardware>/...``). Checked with WSDiscovery's own parser.
- ``SadpSim`` answers a Hikvision SADP ``inquiry`` (UDP 37020) with a ``ProbeMatch`` XML whose
  fields are the ones hiktools 1.2.2 lists for ``DiscoveryPacket`` (hiktools/sadp/message.py).
  Checked with hiktools' ``fromdict`` / ``unmarshal``.
- ``RtspSim`` is an RFC 2326 server: OPTIONS (no auth) and DESCRIBE (digest auth, RFC 2617)
  for a set of stream paths, enough for discovery and the camera adapter's path probing.

Options (all):
    model=<text>        model / hardware (default DS-2CD1043G0-I for Hikvision, CS-C6N for EZVIZ)
    vendor=<text>       ONVIF name scope (default HIKVISION)
    mac=<aa-bb-..>      SADP MAC
    ip=<a.b.c.d>        address reported inside replies (default the sim host)
RtspSim:
    user=<u> password=<p>   credentials (default admin / ABCDEF)
    paths=<p1|p2>           stream paths that exist (default the Hikvision channel paths)
    server=<text>           Server header
"""

from __future__ import annotations

import asyncio
import hashlib
import re
import uuid
import xml.etree.ElementTree as ET
from typing import Any

from ..base import TcpSimDevice, UdpSimDevice

# wsdiscovery/namespaces.py
NS_SOAPENV = "http://www.w3.org/2003/05/soap-envelope"
NS_ADDRESSING = "http://schemas.xmlsoap.org/ws/2004/08/addressing"
NS_DISCOVERY = "http://schemas.xmlsoap.org/ws/2005/04/discovery"
ACTION_PROBE = "http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe"
ACTION_PROBE_MATCHES = "http://schemas.xmlsoap.org/ws/2005/04/discovery/ProbeMatches"
ADDRESS_UNKNOWN = "http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous"
# ONVIF Core spec: device types advertised by video devices.
NS_ONVIF_NETWORK = "http://www.onvif.org/ver10/network/wsdl"

ONVIF_PORT = 3702  # wsdiscovery/threaded.py MULTICAST_PORT
SADP_PORT = 37020  # hiktools/sadp/client.py SADPClient(port=37020)
RTSP_PORT = 554  # RFC 2326 §3.2 default port

DEFAULT_PATHS = "/Streaming/Channels/101|/Streaming/Channels/102|/h264/ch1/main/av_stream|/h264/ch1/sub/av_stream"


class OnvifSim(UdpSimDevice):
    kind = "onvif"
    protocol = "onvif"

    def default_device_id(self) -> str:
        return f"urn:uuid:{uuid.uuid5(uuid.NAMESPACE_DNS, self.name)}"

    def handle_datagram(self, data: bytes, addr: tuple[str, int]) -> bytes | None:
        try:
            root = ET.fromstring(data)
        except ET.ParseError:
            return None
        action = root.find(f".//{{{NS_ADDRESSING}}}Action")
        msg_id = root.find(f".//{{{NS_ADDRESSING}}}MessageID")
        if action is None or (action.text or "").strip() != ACTION_PROBE or msg_id is None:
            return None
        self.state.setdefault("probes", 0)
        self.state["probes"] += 1
        ip = self.options.get("ip", self.host)
        vendor = self.options.get("vendor", "HIKVISION")
        model = self.options.get("model", "DS-2CD1043G0-I")
        scopes = " ".join(
            [
                "onvif://www.onvif.org/type/video_encoder",
                "onvif://www.onvif.org/Profile/Streaming",
                f"onvif://www.onvif.org/name/{vendor}",
                f"onvif://www.onvif.org/hardware/{model}",
                "onvif://www.onvif.org/location/city/hangzhou",
            ]
        )
        body = (
            f'<?xml version="1.0" encoding="UTF-8"?>'
            f'<env:Envelope xmlns:env="{NS_SOAPENV}" xmlns:wsa="{NS_ADDRESSING}" '
            f'xmlns:d="{NS_DISCOVERY}" xmlns:dn="{NS_ONVIF_NETWORK}">'
            f"<env:Header>"
            f"<wsa:MessageID>urn:uuid:{uuid.uuid4()}</wsa:MessageID>"
            f"<wsa:RelatesTo>{(msg_id.text or '').strip()}</wsa:RelatesTo>"
            f"<wsa:To>{ADDRESS_UNKNOWN}</wsa:To>"
            f"<wsa:Action>{ACTION_PROBE_MATCHES}</wsa:Action>"
            f'<d:AppSequence InstanceId="1" MessageNumber="1"/>'
            f"</env:Header>"
            f"<env:Body><d:ProbeMatches><d:ProbeMatch>"
            f"<wsa:EndpointReference><wsa:Address>{self.device_id}</wsa:Address></wsa:EndpointReference>"
            f"<d:Types>dn:NetworkVideoTransmitter</d:Types>"
            f"<d:Scopes>{scopes}</d:Scopes>"
            f"<d:XAddrs>http://{ip}/onvif/device_service</d:XAddrs>"
            f"<d:MetadataVersion>10</d:MetadataVersion>"
            f"</d:ProbeMatch></d:ProbeMatches></env:Body></env:Envelope>"
        )
        return body.encode()


class SadpSim(UdpSimDevice):
    kind = "sadp"
    protocol = "sadp"

    def default_device_id(self) -> str:
        return self.options.get("serial", "DS-2CD1043G0-I20200101AAWRF12345678")

    def handle_datagram(self, data: bytes, addr: tuple[str, int]) -> bytes | None:
        try:
            root = ET.fromstring(data)
        except ET.ParseError:
            return None
        if root.tag != "Probe" or (root.findtext("Types") or "").lower() != "inquiry":
            return None
        self.state.setdefault("probes", 0)
        self.state["probes"] += 1
        fields = {
            "Uuid": root.findtext("Uuid") or "",
            "Types": "inquiry",
            "DeviceType": self.options.get("type", "138210"),
            "DeviceDescription": self.options.get("model", "DS-2CD1043G0-I"),
            "DeviceSN": self.device_id,
            "CommandPort": "8000",
            "HttpPort": "80",
            "MAC": self.options.get("mac", "c0-56-e3-12-34-56"),
            "Ipv4Address": self.options.get("ip", self.host),
            "Ipv4SubnetMask": "255.255.255.0",
            "Ipv4Gateway": "192.168.1.1",
            "DHCP": "true",
            "AnalogChannelNum": "0",
            "DigitalChannelNum": "1",
            "SoftwareVersion": "V5.7.3build 220112",
            "DSPVersion": "V7.3 build 220112",
            "Activated": self.options.get("activated", "true"),
            "PasswordResetAbility": "true",
        }
        out = ET.Element("ProbeMatch")
        for k, v in fields.items():
            ET.SubElement(out, k).text = v
        return ET.tostring(out, xml_declaration=True, encoding="utf-8")


class RtspSim(TcpSimDevice):
    kind = "rtsp"
    protocol = "rtsp"

    def default_device_id(self) -> str:
        return f"rtsp-{self.name}"

    def initial_state(self) -> dict[str, Any]:
        return {"requests": []}

    @property
    def paths(self) -> list[str]:
        return self.options.get("paths", DEFAULT_PATHS).split("|")

    def _ha1(self, realm: str) -> str:
        user = self.options.get("user", "admin")
        password = self.options.get("password", "ABCDEF")
        return hashlib.md5(f"{user}:{realm}:{password}".encode()).hexdigest()

    async def handle_connection(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        realm = self.options.get("realm", "IP Camera(C1234)")
        nonce = uuid.uuid4().hex
        while True:
            try:
                head = await reader.readuntil(b"\r\n\r\n")
            except asyncio.IncompleteReadError:
                return
            lines = head.decode("latin-1").split("\r\n")
            method, url, _ = lines[0].split(" ", 2)
            headers = {}
            for line in lines[1:]:
                if ":" in line:
                    k, v = line.split(":", 1)
                    headers[k.strip().lower()] = v.strip()
            self.state["requests"].append(f"{method} {url}")
            cseq = headers.get("cseq", "0")
            server = self.options.get("server", "Hikvision RTSP Server")
            out = {"CSeq": cseq, "Server": server}
            if method == "OPTIONS":
                status = "200 OK"
                out["Public"] = "OPTIONS, DESCRIBE, PLAY, PAUSE, SETUP, TEARDOWN, SET_PARAMETER, GET_PARAMETER"
                body = b""
            elif method == "DESCRIBE":
                path = re.sub(r"^rtsp://[^/]+", "", url) or "/"
                status, body = self._describe(path, url, headers.get("authorization", ""), realm, nonce, out)
            else:
                status, body = "405 Method Not Allowed", b""
            if body:
                out["Content-Type"] = "application/sdp"
                out["Content-Length"] = str(len(body))
            writer.write(
                (f"RTSP/1.0 {status}\r\n" + "".join(f"{k}: {v}\r\n" for k, v in out.items()) + "\r\n").encode()
                + body
            )
            await writer.drain()

    def _describe(
        self, path: str, url: str, auth: str, realm: str, nonce: str, out: dict[str, str]
    ) -> tuple[str, bytes]:
        params = dict(re.findall(r'(\w+)="?([^",]*)"?', auth)) if auth.lower().startswith("digest") else {}
        if not params:
            out["WWW-Authenticate"] = f'Digest realm="{realm}", nonce="{nonce}", stale="FALSE"'
            return "401 Unauthorized", b""
        ha2 = hashlib.md5(f"DESCRIBE:{params.get('uri', '')}".encode()).hexdigest()
        expected = hashlib.md5(f"{self._ha1(realm)}:{params.get('nonce', '')}:{ha2}".encode()).hexdigest()
        if (
            params.get("username") != self.options.get("user", "admin")
            or params.get("nonce") != nonce
            or params.get("response") != expected
        ):
            out["WWW-Authenticate"] = f'Digest realm="{realm}", nonce="{nonce}", stale="FALSE"'
            return "401 Unauthorized", b""
        if path.split("?")[0] not in self.paths:
            return "404 Not Found", b""
        sdp = (
            "v=0\r\no=- 0 0 IN IP4 0.0.0.0\r\ns=Media Presentation\r\nt=0 0\r\n"
            "m=video 0 RTP/AVP 96\r\na=rtpmap:96 H264/90000\r\na=control:trackID=1\r\n"
        )
        return "200 OK", sdp.encode()
