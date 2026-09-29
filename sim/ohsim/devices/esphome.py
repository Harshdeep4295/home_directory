"""ESPHome web_server (REST) simulator (ESPHome web_server REST docs, PSEUDOCODE §6.12).

- GET  /switch/<id>                → {"id":"switch-<id>","value":bool,"state":"ON"|"OFF"}
- POST /switch/<id>/turn_on|turn_off|toggle
- GET  /light/<id>                 → {"id":"light-<id>","state":"ON"|"OFF","brightness":0..255}
- POST /light/<id>/turn_on[?brightness=0..255] | turn_off | toggle
- optional HTTP Basic auth (web_server auth: username/password)
No native countdown (phone tier).

Options:
    switch=<id>     switch entity id (default relay)
    light=<id>      light entity id (default: none)
    username=, password=
"""

from __future__ import annotations

import base64
import json
from typing import Any

from ..base import HttpSimDevice


class EspHomeSim(HttpSimDevice):
    kind = "esphome"
    protocol = "esphome"

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        self.switch_id = self.options.get("switch", "relay")
        self.light_id = self.options.get("light")
        self.user = self.options.get("username", "admin")
        self.password = self.options.get("password")
        self.switch_on = False
        self.light_on = False
        self.brightness = 255

    def default_device_id(self) -> str:
        return "esphome-sim"

    @property
    def on(self) -> bool:
        return self.switch_on

    def handle_http(self, method, path, query, headers, body):  # type: ignore[override]
        if self.password:
            want = "Basic " + base64.b64encode(f"{self.user}:{self.password}".encode()).decode()
            if headers.get("authorization") != want:
                return 401, {"WWW-Authenticate": 'Basic realm="Login Required"', "Content-Type": "text/plain"}, b"Unauthorized"
        parts = [p for p in path.split("/") if p]
        if len(parts) < 2:
            return 404, {"Content-Type": "text/plain"}, b"Not Found"
        domain, entity, action = parts[0], parts[1], parts[2] if len(parts) > 2 else None
        if domain == "switch" and entity == self.switch_id:
            if action is None and method == "GET":
                return self._ok({"id": f"switch-{entity}", "value": self.switch_on, "state": "ON" if self.switch_on else "OFF"})
            if method == "POST" and action in ("turn_on", "turn_off", "toggle"):
                self.switch_on = {"turn_on": True, "turn_off": False}.get(action, not self.switch_on)
                return 200, {"Content-Type": "text/plain"}, b""
        if domain == "light" and entity == self.light_id:
            if action is None and method == "GET":
                return self._ok({"id": f"light-{entity}", "state": "ON" if self.light_on else "OFF", "brightness": self.brightness})
            if method == "POST" and action in ("turn_on", "turn_off", "toggle"):
                self.light_on = {"turn_on": True, "turn_off": False}.get(action, not self.light_on)
                if action == "turn_on" and "brightness" in query:
                    self.brightness = max(0, min(255, int(query["brightness"])))
                return 200, {"Content-Type": "text/plain"}, b""
        return 404, {"Content-Type": "text/plain"}, b"Not Found"

    @staticmethod
    def _ok(obj: dict[str, Any]):
        return 200, {}, json.dumps(obj).encode()
