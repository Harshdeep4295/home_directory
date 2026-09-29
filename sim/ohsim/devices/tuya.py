"""Tuya 3.1 / 3.3 plug/bulb simulator (TCP, 55AA frames), plus optional UDP beacons.

Framing and crypto come from tinytuya (test dependency, CLAUDE.md rule 2):
tinytuya/core/message_helper.py (unpack_message), crypto_helper.AESCipher, header.py,
udp_helper.py. Behaviour follows what tinytuya's client expects (XenonDevice._decode_payload):

- DP_QUERY            → reply (same seq) {"devId", "dps"}; device22 mode replies "data unvalid"
- CONTROL_NEW (0x0d)  → device22 status query: reply with the requested DPs
- CONTROL             → empty ACK (same seq), then a STATUS (0x08) push with the changed DPs
- HEART_BEAT          → empty HEART_BEAT reply
- countdown DP > 0    → after that many seconds the switch DP FLIPS (Tuya countdown semantics,
                        VERIFY on hardware) and a STATUS push is sent

Options:
    key=<16 chars>        local key (default 0123456789abcdef)
    version=3.3|3.1       protocol version (default 3.3)
    profile=plug|bulb     DP map: plug {1: switch, 9: countdown}; bulb v2 {20 switch, 22 bright,
                          23 temp, 26 countdown} (PSEUDOCODE §6.3 defaults, VERIFY per model)
    device22=1            behave like a 22-char-id device that ignores DP_QUERY
    beacon_port=<port>    send encrypted 6667-style beacons to 127.0.0.1:<port> every second
"""

from __future__ import annotations

import asyncio
import binascii
import json
import struct
import time
from typing import Any

from tinytuya.core import command_types as CT
from tinytuya.core import header as H
from tinytuya.core import udp_helper
from tinytuya.core.crypto_helper import AESCipher
from tinytuya.core.message_helper import parse_header, unpack_message

from ..base import TcpSimDevice

TUYA_PORT = 6668  # tinytuya: TCPPORT = 6668

PROFILES: dict[str, dict[str, Any]] = {
    "plug": {"switch": "1", "countdown": "9", "dps": {"1": False, "9": 0}},
    "bulb": {
        "switch": "20",
        "countdown": "26",
        "dps": {"20": False, "21": "white", "22": 1000, "23": 500, "26": 0},
    },
}


def device_frame(seq: int, cmd: int, payload: bytes, retcode: int = 0) -> bytes:
    """Device→client 55AA frame (header + retcode + payload + crc + suffix)."""
    body = struct.pack(">I", retcode) + payload
    head = struct.pack(">4I", H.PREFIX_55AA_VALUE, seq, cmd, len(body) + 8)
    crc = binascii.crc32(head + body) & 0xFFFFFFFF
    return head + body + struct.pack(">2I", crc, H.SUFFIX_55AA_VALUE)


class TuyaSim(TcpSimDevice):
    kind = "tuya"
    protocol = "tuya-3.3"

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        self.version = self.options.get("version", "3.3")
        self.key = self.options.get("key", "0123456789abcdef").encode()
        if len(self.key) != 16:
            raise ValueError("tuya sim key must be 16 characters")
        self.device22 = self.options.get("device22", "0") in ("1", "true", "yes")
        prof = PROFILES[self.options.get("profile", "plug")]
        self.switch_dp: str = prof["switch"]
        self.countdown_dp: str = prof["countdown"]
        self.dps: dict[str, Any] = dict(prof["dps"])
        self._countdown_deadline: float | None = None
        self._countdown_task: asyncio.Task[None] | None = None
        self._beacon_task: asyncio.Task[None] | None = None
        self.push_seq = 0
        self.received: list[int] = []  # commands received, for tests

    def default_device_id(self) -> str:
        n = 22 if self.options.get("device22", "0") in ("1", "true", "yes") else 20
        base = f"bf{self.name.encode().hex()}000000000000000000000000"
        return base[:n]

    def initial_state(self) -> dict[str, Any]:
        return {}

    @property
    def cipher(self) -> AESCipher:
        return AESCipher(self.key)

    def info(self) -> dict[str, Any]:
        return {**super().info(), "protocol": f"tuya-{self.version}", "key": self.key.decode()}

    # ------------------------------------------------------------------ state

    @property
    def on(self) -> bool:
        return bool(self.dps[self.switch_dp])

    def current_dps(self) -> dict[str, Any]:
        dps = dict(self.dps)
        if self._countdown_deadline is not None:
            dps[self.countdown_dp] = max(0, round(self._countdown_deadline - time.monotonic()))
        return dps

    def _set_dps(self, changes: dict[str, Any]) -> dict[str, Any]:
        applied: dict[str, Any] = {}
        for dp, value in changes.items():
            if dp not in self.dps:
                continue
            if dp == self.countdown_dp:
                self._arm_countdown(int(value))
            else:
                self.dps[dp] = value
            applied[dp] = value
        return applied

    def _arm_countdown(self, seconds: int) -> None:
        if self._countdown_task is not None:
            self._countdown_task.cancel()
            self._countdown_task = None
        self.dps[self.countdown_dp] = seconds
        if seconds <= 0:
            self._countdown_deadline = None
            return
        self._countdown_deadline = time.monotonic() + seconds
        self._countdown_task = asyncio.get_running_loop().create_task(self._countdown(seconds))

    async def _countdown(self, seconds: int) -> None:
        await asyncio.sleep(seconds)
        self.dps[self.switch_dp] = not self.dps[self.switch_dp]  # countdown flips the switch
        self.dps[self.countdown_dp] = 0
        self._countdown_deadline = None
        self._countdown_task = None
        await self._push({self.switch_dp: self.dps[self.switch_dp], self.countdown_dp: 0})

    # ------------------------------------------------------------------ crypto

    def _encrypt(self, obj: dict[str, Any] | str, header: bool) -> bytes:
        raw = (obj if isinstance(obj, str) else json.dumps(obj, separators=(",", ":"))).encode()
        if self.version == "3.1":
            return raw  # 3.1 devices answer queries in plaintext
        ct = self.cipher.encrypt(raw, use_base64=False)
        return (H.PROTOCOL_33_HEADER + ct) if header else ct

    def _decrypt(self, payload: bytes) -> dict[str, Any] | None:
        if not payload:
            return None
        if payload.startswith(H.PROTOCOL_VERSION_BYTES_31):
            data = self.cipher.decrypt(payload[3 + 16 :], use_base64=True, decode_text=True)
        elif payload[:1] == b"{":
            data = payload.decode()
        else:
            if payload.startswith(H.PROTOCOL_VERSION_BYTES_33):
                payload = payload[len(H.PROTOCOL_33_HEADER) :]
            data = self.cipher.decrypt(payload, use_base64=False, decode_text=True)
        return json.loads(data)

    # ------------------------------------------------------------------ protocol

    async def handle_connection(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        buf = b""
        while True:
            chunk = await reader.read(4096)
            if not chunk:
                return
            buf += chunk
            while len(buf) >= 16:
                header = parse_header(buf)
                if len(buf) < header.total_length:
                    break
                frame, buf = buf[: header.total_length], buf[header.total_length :]
                msg = unpack_message(frame, header=header, no_retcode=True)
                self.received.append(msg.cmd)
                for reply in self._handle(msg.seqno, msg.cmd, msg.payload):
                    writer.write(reply)
                await writer.drain()

    def _handle(self, seq: int, cmd: int, payload: bytes) -> list[bytes]:
        req = self._decrypt(payload) if payload else {}
        if cmd == CT.HEART_BEAT:
            return [device_frame(seq, CT.HEART_BEAT, b"")]
        if cmd == CT.DP_QUERY:
            if self.device22:
                return [device_frame(seq, CT.DP_QUERY, self._encrypt("json obj data unvalid", False))]
            return [device_frame(seq, CT.DP_QUERY, self._encrypt({"devId": self.device_id, "dps": self.current_dps()}, False))]
        if cmd == CT.CONTROL_NEW and self.device22:
            wanted = (req or {}).get("dps", {})
            dps = self.current_dps()
            reply = {k: dps[k] for k in wanted if k in dps} or dps
            return [device_frame(seq, CT.CONTROL_NEW, self._encrypt({"devId": self.device_id, "dps": reply}, False))]
        if cmd == CT.CONTROL:
            applied = self._set_dps((req or {}).get("dps", {}))
            out = [device_frame(seq, CT.CONTROL, b"")]
            if applied:
                out.append(self._status_frame(applied))
            return out
        return [device_frame(seq, cmd, b"", retcode=1)]

    def _status_frame(self, dps: dict[str, Any]) -> bytes:
        self.push_seq += 1
        body = {"dps": dps, "t": int(time.time())}
        if self.device22:
            body["devId"] = self.device_id
        return device_frame(0, CT.STATUS, self._encrypt(body, True))

    async def _push(self, dps: dict[str, Any]) -> None:
        frame = self._status_frame(dps)
        for w in list(self._clients):
            try:
                w.write(frame)
                await w.drain()
            except ConnectionError:
                pass

    # ------------------------------------------------------------------ beacons

    def beacon_frame(self) -> bytes:
        beacon = {
            "ip": self.host,
            "gwId": self.device_id,
            "active": 2,
            "ablilty": 0,
            "encrypt": True,
            "productKey": "simproductkey",
            "version": self.version,
        }
        enc = udp_helper.encrypt(json.dumps(beacon, separators=(",", ":")).encode(), udp_helper.udpkey)
        return device_frame(0, CT.UDP_NEW, enc)

    async def _beacons(self, port: int) -> None:
        loop = asyncio.get_running_loop()
        transport, _ = await loop.create_datagram_endpoint(asyncio.DatagramProtocol, remote_addr=("127.0.0.1", port))
        try:
            while True:
                transport.sendto(self.beacon_frame())
                await asyncio.sleep(1)
        finally:
            transport.close()

    async def start(self) -> None:
        await super().start()
        if "beacon_port" in self.options:
            self._beacon_task = asyncio.get_running_loop().create_task(self._beacons(int(self.options["beacon_port"])))

    async def stop(self) -> None:
        for t in (self._beacon_task, self._countdown_task):
            if t is not None:
                t.cancel()
        self._beacon_task = self._countdown_task = None
        await super().stop()
