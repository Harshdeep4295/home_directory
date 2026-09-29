"""Sonoff / eWeLink LAN-mode simulator: HTTP on 8081, /zeroconf/<command>.

Request/crypto shapes follow AlexxIT/SonoffLAN (the reference, CLAUDE.md rule 2),
custom_components/sonoff/core/ewelink/local.py: XRegistryLocal.send posts
{"sequence","deviceid","selfApikey":"123","data":{...}} to http://host:8081/zeroconf/<cmd>;
with a devicekey, encrypt() replaces data with base64(AES-CBC(md5(devicekey), iv, PKCS7(
compact JSON))) and adds "encrypt": true, "iv"; replies {"seq","error":0[,"data","iv"]}.
Commands: switch {"switch"}, switches {"switches":[{"switch","outlet"}]}, info (DIY API,
returns the current params — VERIFY on eWeLink firmware, where state normally arrives via
mDNS TXT). The crypto below mirrors local.py and is checked against the vectors generated
from it (sim/tools/gen_sonoff_vectors.py).

Options:
    devicekey=<key>   encrypted (non-DIY) mode; without it the device is in DIY mode
    outlets=N         multi-channel (uses "switches"); default 1 (uses "switch")
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
from typing import Any

from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

from ..base import HttpSimDevice


def encrypt_data(data: dict[str, Any], devicekey: str) -> tuple[str, str]:
    plaintext = json.dumps(data, separators=(",", ":")).encode("utf-8")
    key = hashlib.md5(devicekey.encode("utf-8")).digest()  # noqa: S324
    iv = os.urandom(16)
    p = padding.PKCS7(128).padder()
    e = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor()
    ct = e.update(p.update(plaintext) + p.finalize()) + e.finalize()
    return base64.b64encode(ct).decode(), base64.b64encode(iv).decode()


def decrypt_data(data_b64: str, iv_b64: str, devicekey: str) -> bytes:
    key = hashlib.md5(devicekey.encode("utf-8")).digest()  # noqa: S324
    d = Cipher(algorithms.AES(key), modes.CBC(base64.b64decode(iv_b64))).decryptor()
    padded = d.update(base64.b64decode(data_b64)) + d.finalize()
    u = padding.PKCS7(128).unpadder()
    return u.update(padded) + u.finalize()


class SonoffSim(HttpSimDevice):
    kind = "sonoff"
    protocol = "sonoff"

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        self.devicekey = self.options.get("devicekey")
        self.outlets = int(self.options.get("outlets", "1"))
        self.switches = ["off"] * self.outlets
        self.seq = 0

    def default_device_id(self) -> str:
        return ("10" + self.name.encode().hex())[:10].ljust(10, "0")

    @property
    def on(self) -> bool:
        return self.switches[0] == "on"

    def _params(self) -> dict[str, Any]:
        if self.outlets == 1:
            return {"switch": self.switches[0]}
        return {"switches": [{"switch": s, "outlet": i} for i, s in enumerate(self.switches)]}

    def handle_http(self, method, path, query, headers, body):  # type: ignore[override]
        if method != "POST" or not path.startswith("/zeroconf/"):
            return 404, {"Content-Type": "text/html"}, b"<html>404</html>"
        cmd = path[len("/zeroconf/"):]
        req = json.loads(body or b"{}")
        if req.get("deviceid") not in (self.device_id, ""):
            return 200, {}, json.dumps({"seq": self.seq, "error": 400}).encode()
        data = req.get("data") or {}
        if self.devicekey:
            if not req.get("encrypt") or "iv" not in req:
                return 200, {}, json.dumps({"seq": self.seq, "error": 400}).encode()
            try:
                data = json.loads(decrypt_data(req["data"], req["iv"], self.devicekey))
            except Exception:  # wrong key → garbage / bad padding
                return 200, {}, json.dumps({"seq": self.seq, "error": 403}).encode()
        self.seq += 1
        if cmd == "switch" and data.get("switch") in ("on", "off"):
            self.switches[0] = data["switch"]
        elif cmd == "switches":
            for s in data.get("switches", []):
                self.switches[int(s["outlet"])] = s["switch"]
        elif cmd != "info":
            return 200, {}, json.dumps({"seq": self.seq, "error": 404}).encode()
        reply: dict[str, Any] = {"seq": self.seq, "error": 0}
        if cmd == "info":
            if self.devicekey:
                reply["data"], reply["iv"] = encrypt_data(self._params(), self.devicekey)
                reply["encrypt"] = True
            else:
                reply["data"] = self._params()
        return 200, {}, json.dumps(reply).encode()
