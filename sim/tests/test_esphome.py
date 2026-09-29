"""EspHomeSim follows the ESPHome web_server REST docs."""

import asyncio
import base64
import json
import urllib.request

from ohsim.devices.esphome import EspHomeSim


def _req(url: str, method: str = "GET", auth: str | None = None) -> tuple[int, bytes]:
    r = urllib.request.Request(url, method=method, data=b"" if method == "POST" else None)
    if auth:
        r.add_header("Authorization", "Basic " + base64.b64encode(auth.encode()).decode())
    try:
        with urllib.request.urlopen(r, timeout=2) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


async def test_switch_and_light() -> None:
    async with EspHomeSim(light="lamp") as sim:
        base = f"http://{sim.host}:{sim.port}"
        assert (await asyncio.to_thread(_req, f"{base}/switch/relay/turn_on", "POST"))[0] == 200
        _, body = await asyncio.to_thread(_req, f"{base}/switch/relay")
        assert json.loads(body) == {"id": "switch-relay", "value": True, "state": "ON"}
        await asyncio.to_thread(_req, f"{base}/light/lamp/turn_on?brightness=128", "POST")
        _, body = await asyncio.to_thread(_req, f"{base}/light/lamp")
        assert json.loads(body)["brightness"] == 128


async def test_basic_auth() -> None:
    async with EspHomeSim(password="pw") as sim:
        base = f"http://{sim.host}:{sim.port}"
        assert (await asyncio.to_thread(_req, f"{base}/switch/relay"))[0] == 401
        assert (await asyncio.to_thread(_req, f"{base}/switch/relay", "GET", "admin:pw"))[0] == 200
