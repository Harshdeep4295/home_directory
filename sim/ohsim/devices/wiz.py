"""WiZ bulb/plug simulator: UDP JSON on port 38899.

Reply shapes are copied from pywizlight's fake bulb (pywizlight/tests/fake_bulb.py, v0.6.6):
getPilot / setPilot / getSystemConfig / registration, errors as
{"error": {"code": -32601, "message": "Method not found"}}.

Options:
    mac=<12 hex>       device MAC (default derived from the sim name)
    module=<name>      moduleName in getSystemConfig (default ESP10_SOCKET_06, a WiZ plug)
    fw=<version>       fwVersion (default 1.25.0)
    drop=<n>           silently drop the first n datagrams (retry tests)
"""

from __future__ import annotations

import json
import zlib
from typing import Any

from ..base import UdpSimDevice

WIZ_PORT = 38899  # pywizlight/bulb.py: PORT = 38899


class WizSim(UdpSimDevice):
    kind = "wiz"
    protocol = "wiz"

    def default_device_id(self) -> str:
        # Stable, unique per sim name (a8bb50 is the WiZ OUI in pywizlight fixtures).
        return self.options.get("mac", f"a8bb50{zlib.crc32(self.name.encode()) & 0xFFFFFF:06x}")

    def initial_state(self) -> dict[str, Any]:
        return {"on": False, "dimming": 100, "temp": 2700}

    @property
    def module(self) -> str:
        return self.options.get("module", "ESP10_SOCKET_06")

    def handle_datagram(self, data: bytes, addr: tuple[str, int]) -> bytes | None:
        drop = int(self.options.get("drop", "0"))
        if drop > 0:
            self.options["drop"] = str(drop - 1)
            return None
        try:
            req = json.loads(data)
        except ValueError:
            return None
        if not isinstance(req, dict):
            return None
        method = req.get("method")
        params = req.get("params") or {}
        self.state.setdefault("requests", []).append(method)
        if method == "getPilot":
            result: dict[str, Any] = {
                "mac": self.device_id,
                "rssi": -55,
                "src": "",
                "state": self.state["on"],
                "sceneId": 0,
                "temp": self.state["temp"],
                "dimming": self.state["dimming"],
            }
        elif method == "setPilot":
            if "state" in params:
                self.state["on"] = bool(params["state"])
            if "dimming" in params:
                self.state["dimming"] = int(params["dimming"])
            if "temp" in params:
                self.state["temp"] = int(params["temp"])
            result = {"success": True}
        elif method == "getSystemConfig":
            result = {
                "mac": self.device_id,
                "homeId": 653906,
                "roomId": 989983,
                "moduleName": self.module,
                "fwVersion": self.options.get("fw", "1.25.0"),
                "groupId": 0,
                "drvConf": [20, 1],
            }
        elif method == "registration":
            result = {"mac": self.device_id, "success": True}
        else:
            return json.dumps(
                {"method": method, "env": "pro", "error": {"code": -32601, "message": "Method not found"}}
            ).encode()
        return json.dumps({"method": method, "env": "pro", "result": result}).encode()
