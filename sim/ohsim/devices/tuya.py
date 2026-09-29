"""Tuya 3.1 / 3.3 / 3.4 plug/bulb simulator (TCP, 55AA frames), plus optional UDP beacons.

Framing and crypto come from tinytuya (test dependency, CLAUDE.md rule 2):
tinytuya/core/message_helper.py (unpack_message), crypto_helper.AESCipher, header.py,
udp_helper.py. Behaviour follows what tinytuya's client expects (XenonDevice._decode_payload):

- DP_QUERY            → reply (same seq) {"devId", "dps"}; device22 mode replies "data unvalid"
- CONTROL_NEW (0x0d)  → device22 status query: reply with the requested DPs
- CONTROL             → empty ACK (same seq), then a STATUS (0x08) push with the changed DPs
- HEART_BEAT          → empty HEART_BEAT reply
- countdown DP > 0    → after that many seconds the switch DP FLIPS (Tuya countdown semantics,
                        VERIFY on hardware) and a STATUS push is sent

Protocol 3.4 (tinytuya XenonDevice._negotiate_session_key*, device side mirrored):
- SESS_KEY_NEG_START (nonce, AES-ECB local key) → SESS_KEY_NEG_RESP: remote nonce +
  HMAC-SHA256(local key, client nonce); SESS_KEY_NEG_FINISH must carry HMAC(local key, remote
  nonce); session key = AES-ECB(local key, nonce XOR nonce). Per connection.
- afterwards every frame is HMAC-SHA256(session key); payloads AES-ECB(session key), the
  "3.4"+12x00 header inside the ciphertext for pushes/CONTROL_NEW.
- DP_QUERY_NEW → {"dps"}; CONTROL_NEW {"protocol":5,"data":{"dps"}} → empty ACK + STATUS push
  {"protocol":4,"t","data":{"dps"}} (push format VERIFY on hardware)

Options:
    key=<16 chars>        local key (default 0123456789abcdef)
    version=3.3|3.1|3.4   protocol version (default 3.3)
    profile=plug|bulb     DP map: plug {1: switch, 9: countdown}; bulb v2 {20 switch, 22 bright,
                          23 temp, 26 countdown} (PSEUDOCODE §6.3 defaults, VERIFY per model)
    device22=1            behave like a 22-char-id device that ignores DP_QUERY
    beacon_port=<port>    send encrypted 6667-style beacons to 127.0.0.1:<port> every second
"""

from __future__ import annotations

import asyncio
import binascii
import hmac
import json
import os
import struct
import time
from hashlib import sha256
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


def device_frame(seq: int, cmd: int, payload: bytes, retcode: int = 0, hmac_key: bytes | None = None) -> bytes:
    """Device→client 55AA frame (header + retcode + payload + crc|hmac + suffix)."""
    body = struct.pack(">I", retcode) + payload
    if hmac_key is not None:  # 3.4: MESSAGE_END_FMT_HMAC ">32sI"
        head = struct.pack(">4I", H.PREFIX_55AA_VALUE, seq, cmd, len(body) + 36)
        mac = hmac.new(hmac_key, head + body, sha256).digest()
        return head + body + mac + struct.pack(">I", H.SUFFIX_55AA_VALUE)
    head = struct.pack(">4I", H.PREFIX_55AA_VALUE, seq, cmd, len(body) + 8)
    crc = binascii.crc32(head + body) & 0xFFFFFFFF
    return head + body + struct.pack(">2I", crc, H.SUFFIX_55AA_VALUE)


class _Session:
    """Per-connection 3.4 session state."""

    def __init__(self) -> None:
        self.local_nonce = b""
        self.remote_nonce = b""
        self.key: bytes | None = None


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
        self._sessions: dict[asyncio.StreamWriter, _Session] = {}

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

    @property
    def v34(self) -> bool:
        return self.version == "3.4"

    def _encrypt(self, obj: dict[str, Any] | str, header: bool, sess: _Session | None = None) -> bytes:
        raw = (obj if isinstance(obj, str) else json.dumps(obj, separators=(",", ":"))).encode()
        if self.version == "3.1":
            return raw  # 3.1 devices answer queries in plaintext
        if self.v34:
            assert sess is not None and sess.key is not None
            return AESCipher(sess.key).encrypt((H.PROTOCOL_34_HEADER + raw) if header else raw, use_base64=False)
        ct = self.cipher.encrypt(raw, use_base64=False)
        return (H.PROTOCOL_33_HEADER + ct) if header else ct

    def _decrypt(self, payload: bytes, sess: _Session | None = None) -> dict[str, Any] | None:
        if not payload:
            return None
        if self.v34:
            assert sess is not None and sess.key is not None
            raw = AESCipher(sess.key).decrypt(payload, use_base64=False, decode_text=False)
            if raw.startswith(H.PROTOCOL_VERSION_BYTES_34):
                raw = raw[len(H.PROTOCOL_34_HEADER) :]
            return json.loads(raw.decode())
        if payload.startswith(H.PROTOCOL_VERSION_BYTES_31):
            data = self.cipher.decrypt(payload[3 + 16 :], use_base64=True, decode_text=True)
        elif payload[:1] == b"{":
            data = payload.decode()
        else:
            if payload.startswith(H.PROTOCOL_VERSION_BYTES_33):
                payload = payload[len(H.PROTOCOL_33_HEADER) :]
            data = self.cipher.decrypt(payload, use_base64=False, decode_text=True)
        return json.loads(data)

    def _frame(self, seq: int, cmd: int, payload: bytes, sess: _Session | None, retcode: int = 0) -> bytes:
        key = None
        if self.v34:
            key = sess.key if sess is not None and sess.key is not None else self.key
        return device_frame(seq, cmd, payload, retcode=retcode, hmac_key=key)

    # ------------------------------------------------------------------ protocol

    async def handle_connection(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        sess = _Session()
        self._sessions[writer] = sess
        buf = b""
        try:
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
                    hmac_key = (sess.key or self.key) if self.v34 else None
                    msg = unpack_message(frame, header=header, hmac_key=hmac_key, no_retcode=True)
                    if not msg.crc_good:
                        return  # a real device drops the connection on a bad CRC/HMAC
                    self.received.append(msg.cmd)
                    replies = self._negotiate(msg, sess) if self.v34 and sess.key is None else self._handle(msg.seqno, msg.cmd, msg.payload, sess)
                    if replies is None:
                        return
                    for reply in replies:
                        writer.write(reply)
                    await writer.drain()
        finally:
            self._sessions.pop(writer, None)

    def _negotiate(self, msg: Any, sess: _Session) -> list[bytes] | None:
        """Device side of tinytuya's 3.4 session key negotiation."""
        real = AESCipher(self.key)
        if msg.cmd == CT.SESS_KEY_NEG_START:
            sess.local_nonce = real.decrypt(msg.payload, use_base64=False, decode_text=False)[:16]
            sess.remote_nonce = os.urandom(16)
            body = sess.remote_nonce + hmac.new(self.key, sess.local_nonce, sha256).digest()
            return [self._frame(msg.seqno, CT.SESS_KEY_NEG_RESP, real.encrypt(body, use_base64=False), None)]
        if msg.cmd == CT.SESS_KEY_NEG_FINISH and sess.remote_nonce:
            got = real.decrypt(msg.payload, use_base64=False, decode_text=False)[:32]
            if got != hmac.new(self.key, sess.remote_nonce, sha256).digest():
                return None
            xor = bytes(a ^ b for a, b in zip(sess.local_nonce, sess.remote_nonce))
            sess.key = real.encrypt(xor, use_base64=False, pad=False)
            return []
        return None  # anything else before a session exists: hang up

    def _handle(self, seq: int, cmd: int, payload: bytes, sess: _Session | None = None) -> list[bytes]:
        req = self._decrypt(payload, sess) if payload else {}
        if cmd == CT.HEART_BEAT:
            return [self._frame(seq, CT.HEART_BEAT, b"", sess)]
        if self.v34:
            if cmd == CT.DP_QUERY_NEW:
                return [self._frame(seq, CT.DP_QUERY_NEW, self._encrypt({"dps": self.current_dps()}, False, sess), sess)]
            if cmd == CT.CONTROL_NEW:
                applied = self._set_dps(((req or {}).get("data") or {}).get("dps", {}))
                out = [self._frame(seq, CT.CONTROL_NEW, b"", sess)]
                if applied:
                    out.append(self._status_frame(applied, sess))
                return out
            return [self._frame(seq, cmd, b"", sess, retcode=1)]
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

    def _status_frame(self, dps: dict[str, Any], sess: _Session | None = None) -> bytes:
        self.push_seq += 1
        if self.v34:
            body34 = {"protocol": 4, "t": int(time.time()), "data": {"dps": dps}}
            return self._frame(0, CT.STATUS, self._encrypt(body34, True, sess), sess)
        body = {"dps": dps, "t": int(time.time())}
        if self.device22:
            body["devId"] = self.device_id
        return device_frame(0, CT.STATUS, self._encrypt(body, True))

    async def _push(self, dps: dict[str, Any]) -> None:
        for w in list(self._clients):
            sess = self._sessions.get(w)
            if self.v34 and (sess is None or sess.key is None):
                continue
            try:
                w.write(self._status_frame(dps, sess))
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
