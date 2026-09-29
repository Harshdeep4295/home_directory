"""HueSim checked against the reference client: aiohue 4.9.0 (v1 API)."""

import asyncio
import json
import urllib.request

import pytest
from aiohue.errors import LinkButtonNotPressed
from aiohue.util import create_app_key
from aiohue.v1 import HueBridgeV1

from ohsim.devices.hue import HueSim


async def test_pairing_needs_link_button() -> None:
    async with HueSim() as sim:
        with pytest.raises(LinkButtonNotPressed):
            await create_app_key(f"{sim.host}:{sim.port}", "offline_home#test")
    async with HueSim(pressed="1") as sim:
        key = await create_app_key(f"{sim.host}:{sim.port}", "offline_home#test")
        assert key in sim.users


async def test_lights_via_aiohue() -> None:
    async with HueSim() as sim:
        b = HueBridgeV1(f"{sim.host}:{sim.port}", "simuser")
        await b.initialize()
        light = b.lights["1"]
        await light.set_state(on=True, bri=127, ct=250)
        assert sim.lights["1"]["state"] == {**sim.lights["1"]["state"], "on": True, "bri": 127, "ct": 250}
        await b.close()


def _req(url: str, method: str = "GET", body: dict | None = None):
    r = urllib.request.Request(url, method=method, data=json.dumps(body).encode() if body else None)
    with urllib.request.urlopen(r, timeout=2) as resp:
        return json.loads(resp.read())


async def test_timer_schedule_runs_command() -> None:
    async with HueSim() as sim:
        base = f"http://{sim.host}:{sim.port}/api/simuser"
        body = {
            "name": "off",
            "command": {"address": "/api/simuser/lights/2/state", "method": "PUT", "body": {"on": True}},
            "localtime": "PT00:00:01",
            "autodelete": True,
        }
        r = await asyncio.to_thread(_req, f"{base}/schedules", "POST", body)
        sid = r[0]["success"]["id"]
        s = await asyncio.to_thread(_req, f"{base}/schedules/{sid}")
        assert s["status"] == "enabled"
        await asyncio.sleep(1.3)
        assert sim.lights["2"]["state"]["on"] is True
        assert sid not in sim.schedules
