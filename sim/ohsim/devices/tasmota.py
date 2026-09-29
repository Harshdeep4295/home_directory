"""Tasmota HTTP simulator: GET /cm?cmnd=<command> (Tasmota commands docs).

- Power<n> [On|Off|Toggle] → {"POWER<n>":"ON"}; single relay reports "POWER".
- PulseTime<n> [v] → {"PulseTime<n>":{"Set":v,"Remaining":r}}; v 1..111 = v×0.1 s,
  112..64900 = v−100 s; after the relay turns ON it turns OFF again after that time. The
  setting persists (that is why the app clears it after use — PSEUDOCODE §6.11 VERIFY).
- Dimmer [0..100], CT [153..500] for lights; Status 0 → {"Status":{...},"StatusNET":{"Mac"}}.
- Web password → every request needs user=admin&password=… (else 401 WARNING).

Options:
    relays=N     number of relays (default 1)
    password=<pw>
    light=1      also Dimmer / CT
"""

from __future__ import annotations

import asyncio
import json
import time
from typing import Any

from ..base import HttpSimDevice


def pulse_seconds(v: int) -> float:
    return 0.0 if v <= 0 else v / 10 if v <= 111 else float(v - 100)


class TasmotaSim(HttpSimDevice):
    kind = "tasmota"
    protocol = "tasmota"

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        self.n = int(self.options.get("relays", "1"))
        self.password = self.options.get("password")
        self.light = self.options.get("light", "0") == "1"
        self.power = [False] * self.n
        self.pulse = [0] * self.n
        self.pulse_end: list[float | None] = [None] * self.n
        self._tasks: list[asyncio.Task[None] | None] = [None] * self.n
        self.dimmer = 100
        self.ct = 327

    def default_device_id(self) -> str:
        return "a4cf12000001"

    @property
    def on(self) -> bool:
        return self.power[0]

    def _key(self, prefix: str, i: int) -> str:
        return prefix if self.n == 1 and prefix == "POWER" else f"{prefix}{i + 1}"

    def _set_power(self, i: int, on: bool) -> None:
        self.power[i] = on
        t = self._tasks[i]
        if t is not None:
            t.cancel()
        self._tasks[i] = None
        self.pulse_end[i] = None
        if on and self.pulse[i] > 0:
            secs = pulse_seconds(self.pulse[i])
            self.pulse_end[i] = time.monotonic() + secs
            self._tasks[i] = asyncio.get_running_loop().create_task(self._off_after(i, secs))

    async def _off_after(self, i: int, secs: float) -> None:
        await asyncio.sleep(secs)
        self.power[i] = False
        self.pulse_end[i] = None
        self._tasks[i] = None

    def handle_http(self, method, path, query, headers, body):  # type: ignore[override]
        if path != "/cm":
            return 404, {"Content-Type": "text/html"}, b"<html>404</html>"
        if self.password and (query.get("user") != "admin" or query.get("password") != self.password):
            return 401, {}, json.dumps({"WARNING": "Need user=<username>&password=<password>"}).encode()
        cmnd = query.get("cmnd", "").strip()
        name, _, arg = cmnd.partition(" ")
        low = name.lower()
        idx = 0
        for prefix in ("power", "pulsetime"):
            if low.startswith(prefix) and low[len(prefix):].isdigit():
                idx = int(low[len(prefix):]) - 1
                low = prefix
        if not 0 <= idx < self.n:
            return 200, {}, json.dumps({"Command": "Unknown"}).encode()
        arg = arg.strip().lower()
        if low == "power":
            if arg in ("on", "1"):
                self._set_power(idx, True)
            elif arg in ("off", "0"):
                self._set_power(idx, False)
            elif arg in ("toggle", "2"):
                self._set_power(idx, not self.power[idx])
            return self._ok({self._key("POWER", idx): "ON" if self.power[idx] else "OFF"})
        if low == "pulsetime":
            if arg:
                self.pulse[idx] = int(arg)
            end = self.pulse_end[idx]
            left = 0 if end is None else max(0, end - time.monotonic())
            raw_left = 0 if left <= 0 else (round(left * 10) if left <= 11.1 else round(left) + 100)
            return self._ok({f"PulseTime{idx + 1}": {"Set": self.pulse[idx], "Remaining": raw_left}})
        if low == "dimmer" and self.light:
            if arg:
                self.dimmer = max(0, min(100, int(arg)))
                self.power[0] = self.dimmer > 0
            return self._ok({"POWER": "ON" if self.power[0] else "OFF", "Dimmer": self.dimmer})
        if low == "ct" and self.light:
            if arg:
                self.ct = max(153, min(500, int(arg)))
            return self._ok({"CT": self.ct})
        if low == "status" and arg == "0":
            return self._ok(
                {
                    "Status": {"Module": 1, "DeviceName": "Tasmota", "FriendlyName": ["Tasmota"], "Power": int(self.power[0])},
                    "StatusNET": {"Hostname": "tasmota-0001", "IPAddress": self.host, "Mac": "A4:CF:12:00:00:01"},
                }
            )
        return self._ok({"Command": "Unknown"})

    @staticmethod
    def _ok(obj: dict[str, Any]):
        return 200, {}, json.dumps(obj).encode()

    async def stop(self) -> None:
        for t in self._tasks:
            if t is not None:
                t.cancel()
        await super().stop()
