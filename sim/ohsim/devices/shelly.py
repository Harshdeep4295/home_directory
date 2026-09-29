"""Shelly Gen1 (REST) and Gen2+ (JSON-RPC over HTTP) relay simulator.

API shapes follow the Shelly API docs as used by aioshelly 13.34.0:
- ``GET /shelly`` (aioshelly common.get_info): Gen1 {"type", "mac", "auth", "fw"};
  Gen2+ {"id", "mac", "model", "gen", "fw_id", "auth_en", "auth_domain"}.
- Gen1 (aioshelly block_device Block.set_state → GET ``relay/<ch>`` with kwargs):
  ``turn=on|off|toggle``, ``timer=<s>`` = one-shot flip-back timer; reply is the relay
  status {"ison", "has_timer", "timer_started", "timer_duration", "timer_remaining"}.
  Password → HTTP Basic auth (aioshelly common.encode_basic_auth).
- Gen2+ (aioshelly rpc_device, frame of wsrpc.RPCCall.build_request_frame, sent here as
  HTTP ``POST /rpc``): Switch.GetStatus {id} → {"id","output","timer_started_at",
  "timer_duration"}; Switch.Set {id, on, toggle_after} → {"was_on"}; Shelly.GetDeviceInfo.
  Password → digest auth in the frame's "auth" object exactly as wsrpc.AuthData computes it
  (SHA-256, HA2 = sha256("dummy_method:dummy_uri")); a missing/wrong auth answers 401 with
  the challenge JSON in error.message (as wsrpc parses it). VERIFY: HTTP POST /rpc accepting
  the in-frame auth object like the websocket transport does.

Options:
    gen=1|2           API generation (default 1)
    password=<pw>     require auth (user "admin")
    mac=<12 hex>      MAC (default derived from name)
"""

from __future__ import annotations

import asyncio
import base64
import hashlib
import json
import time
from typing import Any

from ..base import HttpSimDevice

USER = "admin"


def _sha(s: str) -> str:
    return hashlib.sha256(s.encode()).hexdigest()


class ShellySim(HttpSimDevice):
    kind = "shelly"
    protocol = "shelly-gen1"

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        self.gen = int(self.options.get("gen", "1"))
        self.password = self.options.get("password")
        self.mac = self.options.get("mac", (self.name.encode().hex() + "000000000000")[:12]).upper()
        self.on = False
        self.timer_started: float | None = None  # wall clock (Gen2 reports unix time)
        self.timer_duration = 0.0
        self._timer_task: asyncio.Task[None] | None = None
        self.nonce = 1790000000
        self.requests: list[str] = []

    def default_device_id(self) -> str:
        mac = self.options.get("mac", (self.name.encode().hex() + "000000000000")[:12])
        return mac.lower()  # the app's device id: MAC, lower-case, no separators

    def info(self) -> dict[str, Any]:
        return {**super().info(), "protocol": f"shelly-gen{1 if self.gen == 1 else 2}"}

    @property
    def realm(self) -> str:
        return f"shellyplus1-{self.mac.lower()}"

    # ------------------------------------------------------------------ state

    def _arm(self, seconds: float) -> None:
        if self._timer_task is not None:
            self._timer_task.cancel()
            self._timer_task = None
        self.timer_started = None
        self.timer_duration = 0.0
        if seconds > 0:
            self.timer_started = time.time()
            self.timer_duration = float(seconds)
            self._timer_task = asyncio.get_running_loop().create_task(self._flip_later(seconds))

    async def _flip_later(self, seconds: float) -> None:
        await asyncio.sleep(seconds)
        self.on = not self.on
        self.timer_started = None
        self.timer_duration = 0.0
        self._timer_task = None

    def remaining(self) -> int:
        if self.timer_started is None:
            return 0
        return max(0, round(self.timer_started + self.timer_duration - time.time()))

    def _gen1_status(self) -> dict[str, Any]:
        return {
            "ison": self.on,
            "has_timer": self.timer_started is not None,
            "timer_started": int(self.timer_started or 0),
            "timer_duration": int(self.timer_duration),
            "timer_remaining": self.remaining(),
            "source": "http",
        }

    # ------------------------------------------------------------------ http

    def handle_http(self, method, path, query, headers, body):  # type: ignore[override]
        self.requests.append(f"{method} {path}")
        if path == "/shelly":
            return 200, {}, json.dumps(self._shelly()).encode()
        if self.gen == 1:
            return self._gen1(path, query, headers)
        if path == "/rpc" and method == "POST":
            return self._rpc(json.loads(body or b"{}"))
        return 404, {}, b"Not Found"

    def _shelly(self) -> dict[str, Any]:
        if self.gen == 1:
            return {"type": "SHSW-1", "mac": self.mac, "auth": bool(self.password), "fw": "sim", "num_outputs": 1}
        return {
            "name": None,
            "id": self.realm,
            "mac": self.mac,
            "model": "SNSW-001X16EU",
            "gen": self.gen,
            "fw_id": "sim",
            "ver": "1.0.0",
            "app": "Plus1",
            "auth_en": bool(self.password),
            "auth_domain": self.realm if self.password else None,
        }

    def _gen1(self, path: str, query: dict[str, str], headers: dict[str, str]):
        if self.password:
            want = "Basic " + base64.b64encode(f"{USER}:{self.password}".encode()).decode()
            if headers.get("authorization") != want:
                return 401, {"WWW-Authenticate": 'Basic realm="shelly"'}, b"401 Unauthorized"
        if path != "/relay/0":
            return 404, {}, b"Not Found"
        turn = query.get("turn")
        if turn in ("on", "off", "toggle"):
            self.on = (not self.on) if turn == "toggle" else turn == "on"
            self._arm(float(query.get("timer", "0") or 0))
        return 200, {}, json.dumps(self._gen1_status()).encode()

    def _challenge(self) -> dict[str, Any]:
        self.nonce += 1
        return {"auth_type": "digest", "nonce": self.nonce, "nc": 1, "realm": self.realm, "algorithm": "SHA-256"}

    def _auth_ok(self, auth: dict[str, Any] | None) -> bool:
        if not auth:
            return False
        ha1 = _sha(f"{USER}:{self.realm}:{self.password}")
        ha2 = _sha("dummy_method:dummy_uri")
        expect = _sha(f"{ha1}:{auth.get('nonce')}:{auth.get('nc')}:{auth.get('cnonce')}:auth:{ha2}")
        return auth.get("response") == expect and auth.get("username") == USER

    def _rpc(self, frame: dict[str, Any]):
        rid = frame.get("id", 1)
        if self.password and not self._auth_ok(frame.get("auth")):
            err = {"id": rid, "src": self.realm, "error": {"code": 401, "message": json.dumps(self._challenge())}}
            return 401, {}, json.dumps(err).encode()
        method = frame.get("method")
        params = frame.get("params") or {}

        def ok(result: dict[str, Any]):
            return 200, {}, json.dumps({"id": rid, "src": self.realm, "result": result}).encode()

        if method == "Shelly.GetDeviceInfo":
            return ok(self._shelly())
        if method == "Switch.GetStatus":
            st: dict[str, Any] = {"id": 0, "source": "http", "output": self.on}
            if self.timer_started is not None:
                st["timer_started_at"] = self.timer_started
                st["timer_duration"] = self.timer_duration
            return ok(st)
        if method == "Switch.Set":
            was = self.on
            self.on = bool(params.get("on"))
            self._arm(float(params.get("toggle_after", 0) or 0))
            return ok({"was_on": was})
        err = {"id": rid, "src": self.realm, "error": {"code": 404, "message": f"No handler for {method}"}}
        return 200, {}, json.dumps(err).encode()

    async def stop(self) -> None:
        if self._timer_task is not None:
            self._timer_task.cancel()
            self._timer_task = None
        await super().stop()
