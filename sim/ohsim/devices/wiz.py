"""WiZ bulb/plug simulator: UDP JSON on port 38899.

Reply shapes follow pywizlight (pywizlight/bulb.py, pywizlight/models.py). T0.2 answers
getPilot/setPilot; T2.2 extends it (getSystemConfig, registration, error replies).
"""

from __future__ import annotations

import json
import zlib
from typing import Any

from ..base import UdpSimDevice

WIZ_PORT = 38899  # pywizlight: PORT = 38899


class WizSim(UdpSimDevice):
    kind = "wiz"
    protocol = "wiz"

    def default_device_id(self) -> str:
        # Stable, unique per sim name (a8bb50 is a WiZ OUI seen in pywizlight fixtures).
        return self.options.get("mac", f"a8bb50{zlib.crc32(self.name.encode()) & 0xFFFFFF:06x}")

    def initial_state(self) -> dict[str, Any]:
        return {"on": False, "dimming": 100, "temp": 2700}

    def handle_datagram(self, data: bytes, addr: tuple[str, int]) -> bytes | None:
        try:
            req = json.loads(data)
        except ValueError:
            return None
        method = req.get("method")
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
            params = req.get("params", {})
            if "state" in params:
                self.state["on"] = bool(params["state"])
            if "dimming" in params:
                self.state["dimming"] = int(params["dimming"])
            if "temp" in params:
                self.state["temp"] = int(params["temp"])
            result = {"success": True}
        else:
            return json.dumps(
                {"method": method, "env": "pro", "error": {"code": -32601, "message": "Method not found"}}
            ).encode()
        return json.dumps({"method": method, "env": "pro", "result": result}).encode()
