"""Philips Hue bridge simulator (local REST API v1, HTTP).

Shapes follow aiohue 4.9.0 (the reference client, CLAUDE.md rule 2) and the Hue API docs:
- GET /api/config (aiohue discovery.is_hue_bridge): {"bridgeid", "name", "modelid", "mac", ...}
- POST /api {"devicetype"} (aiohue util.create_app_key) → [{"success":{"username"}}] or
  [{"error":{"type":101,"description":"link button not pressed"}}]
- GET /api/<user> (aiohue v1 HueBridgeV1.initialize) → full state {"lights","groups","config"}
- GET /api/<user>/lights[/<id>], PUT /api/<user>/lights/<id>/state {"on","bri","ct"}
  (aiohue v1 lights.Light.set_state); unknown user → [{"error":{"type":1}}] (errors.ERRORS)
- Schedules (Hue API docs "Schedules API", not in aiohue — VERIFY): POST /api/<user>/schedules
  {"command":{"address","method","body"},"localtime":"PT hh:mm:ss","autodelete":true} →
  [{"success":{"id"}}]; GET /api/<user>/schedules, GET / DELETE /api/<user>/schedules/<id>; the command runs when the
  timer expires.

Options:
    lights=N          number of lights (default 2; light 1 has ct, all dimmable)
    pressed=1         link button pressed (pairing succeeds)
    user=<name>       pre-authorised username (default "simuser")
"""

from __future__ import annotations

import asyncio
import datetime as dt
import json
import re
from typing import Any

from ..base import HttpSimDevice


class HueSim(HttpSimDevice):
    kind = "hue"
    protocol = "hue"

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        self.pressed = self.options.get("pressed", "0") in ("1", "true")
        self.users = {self.options.get("user", "simuser")}
        n = int(self.options.get("lights", "2"))
        self.lights: dict[str, dict[str, Any]] = {
            str(i): {
                "state": {"on": False, "bri": 254, "ct": 366, "alert": "none", "colormode": "ct", "reachable": True}
                if i == 1
                else {"on": False, "bri": 254, "alert": "none", "reachable": True},
                "type": "Color temperature light" if i == 1 else "Dimmable light",
                "name": f"Hue light {i}",
                "modelid": "LTW001" if i == 1 else "LWB010",
                "manufacturername": "Signify Netherlands B.V.",
                "uniqueid": f"00:17:88:01:00:00:00:{i:02x}-0b",
                "swversion": "1.0",
            }
            for i in range(1, n + 1)
        }
        self.schedules: dict[str, dict[str, Any]] = {}
        self._tasks: dict[str, asyncio.Task[None]] = {}
        self._next = 0

    def default_device_id(self) -> str:
        return "001788fffe000001"[:6] + "000001"  # normalised 12-char bridge id

    def _config(self) -> dict[str, Any]:
        return {
            "name": "Philips hue",
            "bridgeid": self.device_id.upper()[:6] + "FFFE" + self.device_id.upper()[6:],
            "modelid": "BSB002",
            "mac": "00:17:88:00:00:01",
            "apiversion": "1.60.0",
            "swversion": "1960000000",
        }

    # ------------------------------------------------------------------ http

    def handle_http(self, method, path, query, headers, body):  # type: ignore[override]
        req = json.loads(body) if body else None
        if path == "/api/config" and method == "GET":
            return self._ok(self._config())
        if path == "/api" and method == "POST":
            if not self.pressed:
                return self._ok([{"error": {"type": 101, "address": "", "description": "link button not pressed"}}])
            user = f"user{len(self.users):04d}{self.device_id}"
            self.users.add(user)
            return self._ok([{"success": {"username": user}}])
        m = re.fullmatch(r"/api/([^/]+)(/.*)?", path)
        if not m:
            return 404, {}, b""
        user, rest = m.group(1), m.group(2) or ""
        if user not in self.users:
            return self._ok([{"error": {"type": 1, "address": rest or "/", "description": "unauthorized user"}}])
        return self._api(user, method, rest, req)

    @staticmethod
    def _ok(obj: Any):
        return 200, {}, json.dumps(obj).encode()

    def _api(self, user: str, method: str, rest: str, req: Any):
        if rest in ("", "/") and method == "GET":
            return self._ok({"lights": self.lights, "groups": {}, "config": self._config(), "schedules": self.schedules})
        if rest == "/lights" and method == "GET":
            return self._ok(self.lights)
        if m := re.fullmatch(r"/lights/(\d+)", rest):
            light = self.lights.get(m.group(1))
            return self._ok(light) if light else self._ok([{"error": {"type": 3, "description": "resource not available"}}])
        if (m := re.fullmatch(r"/lights/(\d+)/state", rest)) and method == "PUT":
            return self._ok(self._set_state(m.group(1), req or {}))
        if rest == "/schedules" and method == "GET":
            return self._ok(self.schedules)
        if rest == "/schedules" and method == "POST":
            return self._ok(self._add_schedule(user, req or {}))
        if m := re.fullmatch(r"/schedules/(\d+)", rest):
            sid = m.group(1)
            if method == "DELETE":
                self.schedules.pop(sid, None)
                task = self._tasks.pop(sid, None)
                if task:
                    task.cancel()
                return self._ok([{"success": f"/schedules/{sid} deleted."}])
            s = self.schedules.get(sid)
            return self._ok(s) if s else self._ok([{"error": {"type": 3, "description": "resource not available"}}])
        return self._ok([{"error": {"type": 4, "description": f"method {method} not available for {rest}"}}])

    def _set_state(self, lid: str, changes: dict[str, Any]) -> list[dict[str, Any]]:
        light = self.lights.get(lid)
        if light is None:
            return [{"error": {"type": 3, "description": "resource not available"}}]
        out = []
        for k, v in changes.items():
            if k in ("on", "bri", "ct") and k in light["state"]:
                light["state"][k] = v
                out.append({"success": {f"/lights/{lid}/state/{k}": v}})
        return out

    def _add_schedule(self, user: str, req: dict[str, Any]) -> list[dict[str, Any]]:
        m = re.fullmatch(r"PT(\d{2}):(\d{2}):(\d{2})", str(req.get("localtime", "")))
        cmd = req.get("command") or {}
        if not m or not cmd.get("address"):
            return [{"error": {"type": 7, "description": "invalid value for parameter, localtime"}}]
        secs = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3))
        self._next += 1
        sid = str(self._next)
        self.schedules[sid] = {
            "name": req.get("name", "schedule"),
            "command": cmd,
            "localtime": req["localtime"],
            "time": req["localtime"],
            "starttime": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S"),
            "status": "enabled",
            "autodelete": req.get("autodelete", True),
        }
        self._tasks[sid] = asyncio.get_running_loop().create_task(self._fire(sid, secs))
        return [{"success": {"id": sid}}]

    async def _fire(self, sid: str, secs: int) -> None:
        await asyncio.sleep(secs)
        s = self.schedules.pop(sid, None)
        self._tasks.pop(sid, None)
        if s is None:
            return
        m = re.fullmatch(r"/api/[^/]+/lights/(\d+)/state", s["command"]["address"])
        if m and s["command"].get("method") == "PUT":
            self._set_state(m.group(1), s["command"].get("body") or {})

    async def stop(self) -> None:
        for t in self._tasks.values():
            t.cancel()
        self._tasks.clear()
        await super().stop()
