"""TP-Link KLAP device simulator (Tapo SMART.KLAP and IOT.KLAP), HTTP on one port.

Device side of python-kasa 0.10.2 kasa/transports/klaptransport.py: handshake hashes come
from KlapTransport / KlapTransportV2 and the session key/iv/seq/sig from
KlapEncryptionSession, so the sim cannot drift from the reference client.
- POST /app/handshake1 (16-byte local seed) → remote seed + handshake1 hash, sets
  TP_SESSIONID and TIMEOUT cookies.
- POST /app/handshake2 → 200 if the hash matches, else 403.
- POST /app/request?seq=N → body sha256(sig+seq+ct)+ct; reply encrypted with the same seq.
SMART requests (smartprotocol.get_smart_request): {"method", "params"} → {"error_code",
"result"}: get_device_info (nickname base64, device_on, brightness, color_temp),
set_device_info. IOT requests are the legacy JSON of KasaSim.

Options:
    family=smart|iot         SMART.KLAP (KlapTransportV2) or IOT.KLAP (KlapTransport)
    username=, password=     the TP-Link account the device was set up with
    creds=KASA|TAPO|blank    answer with python-kasa DEFAULT_CREDENTIALS / blank instead
    type=plug|bulb           SMART device type (default plug)
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
import struct
from typing import Any

from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from kasa.credentials import DEFAULT_CREDENTIALS, Credentials, get_default_credentials
from kasa.transports.klaptransport import KlapEncryptionSession, KlapTransport, KlapTransportV2

from ..base import HttpSimDevice
from .kasa import KasaSim


class KlapSim(HttpSimDevice):
    kind = "klap"
    protocol = "klap-smart"

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        self.family = self.options.get("family", "smart")
        self.transport = KlapTransportV2 if self.family == "smart" else KlapTransport
        creds_opt = self.options.get("creds")
        if creds_opt == "blank":
            creds = Credentials()
        elif creds_opt:
            creds = get_default_credentials(DEFAULT_CREDENTIALS[creds_opt])
        else:
            creds = Credentials(self.options.get("username", "user@example.com"), self.options.get("password", "hunter2"))
        self.auth_hash = self.transport.generate_auth_hash(creds)
        self.type = self.options.get("type", "plug")
        self.on = False
        self.brightness = 100
        self.color_temp = 2700
        self.iot = KasaSim(name=self.name, device_id=self.device_id) if self.family == "iot" else None
        self._pending: dict[str, tuple[bytes, bytes]] = {}  # cookie → (local, remote)
        self._sessions: dict[str, KlapEncryptionSession] = {}
        self.handshakes = 0

    def default_device_id(self) -> str:
        return ("80" + self.name.encode().hex().upper() + "0" * 40)[:40]

    def info(self) -> dict[str, Any]:
        return {**super().info(), "protocol": f"klap-{self.options.get('family', 'smart')}"}

    # ------------------------------------------------------------------ crypto

    @staticmethod
    def _cipher(s: KlapEncryptionSession, seq: int) -> Cipher:
        return Cipher(algorithms.AES(s._key), modes.CBC(s._iv + struct.pack(">l", seq)))

    def _decrypt(self, s: KlapEncryptionSession, seq: int, body: bytes) -> bytes | None:
        sig = hashlib.sha256(s._sig + struct.pack(">l", seq) + body[32:]).digest()
        if sig != body[:32]:
            return None
        d = self._cipher(s, seq).decryptor()
        raw = d.update(body[32:]) + d.finalize()
        u = padding.PKCS7(128).unpadder()
        return u.update(raw) + u.finalize()

    def _encrypt(self, s: KlapEncryptionSession, seq: int, plain: bytes) -> bytes:
        p = padding.PKCS7(128).padder()
        e = self._cipher(s, seq).encryptor()
        ct = e.update(p.update(plain) + p.finalize()) + e.finalize()
        return hashlib.sha256(s._sig + struct.pack(">l", seq) + ct).digest() + ct

    # ------------------------------------------------------------------ http

    def handle_http(self, method, path, query, headers, body):  # type: ignore[override]
        cookie = ""
        for part in headers.get("cookie", "").split(";"):
            k, _, v = part.strip().partition("=")
            if k == "TP_SESSIONID":
                cookie = v
        if method != "POST":
            return 404, {}, b""
        if path == "/app/handshake1":
            self.handshakes += 1
            local, remote = body[:16], os.urandom(16)
            sid = os.urandom(16).hex().upper()
            self._pending[sid] = (local, remote)
            h1 = self.transport.handshake1_seed_auth_hash(local, remote, self.auth_hash)
            return 200, {"Set-Cookie": f"TP_SESSIONID={sid};TIMEOUT=86400", "Content-Type": "application/octet-stream"}, remote + h1
        if path == "/app/handshake2":
            seeds = self._pending.pop(cookie, None)
            if seeds is None or body != self.transport.handshake2_seed_auth_hash(*seeds, self.auth_hash):
                return 403, {}, b""
            self._sessions[cookie] = KlapEncryptionSession(*seeds, self.auth_hash)
            return 200, {}, b""
        if path == "/app/request":
            s = self._sessions.get(cookie)
            seq = int(query.get("seq", "0"))
            plain = self._decrypt(s, seq, body) if s else None
            if s is None or plain is None:
                return 403, {}, b""
            reply = self._handle(json.loads(plain))
            return 200, {"Content-Type": "application/octet-stream"}, self._encrypt(s, seq, json.dumps(reply).encode())
        return 404, {}, b""

    def _handle(self, req: dict[str, Any]) -> dict[str, Any]:
        if self.iot is not None:
            out = self.iot.handle(req)
            self.on = self.iot.on
            return out
        method = req.get("method")
        params = req.get("params") or {}
        if method == "get_device_info":
            info: dict[str, Any] = {
                "device_id": self.device_id,
                "model": "L530" if self.type == "bulb" else "P110",
                "type": "SMART.TAPOBULB" if self.type == "bulb" else "SMART.TAPOPLUG",
                "mac": "AA-BB-CC-00-00-01",
                "nickname": base64.b64encode(self.name.encode()).decode(),
                "device_on": self.on,
            }
            if self.type == "bulb":
                info.update(brightness=self.brightness, color_temp=self.color_temp, color_temp_range=[2500, 6500])
            return {"error_code": 0, "result": info}
        if method == "set_device_info":
            if "device_on" in params:
                self.on = bool(params["device_on"])
            if "brightness" in params and self.type == "bulb":
                self.brightness = int(params["brightness"])
            if "color_temp" in params and self.type == "bulb":
                self.color_temp = int(params["color_temp"])
            return {"error_code": 0}
        return {"error_code": -1002}  # kasa/exceptions.py SmartErrorCode.UNKNOWN_METHOD_ERROR
