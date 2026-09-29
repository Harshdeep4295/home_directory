"""TasmotaSim behaviour per the Tasmota commands docs (no reference Python client for the
HTTP API exists in our deps)."""

import asyncio
import json
import urllib.parse
import urllib.request

from ohsim.devices.tasmota import TasmotaSim, pulse_seconds


def _cm(base: str, cmnd: str, **extra: str) -> dict:
    q = urllib.parse.urlencode({**extra, "cmnd": cmnd})
    try:
        with urllib.request.urlopen(f"{base}/cm?{q}", timeout=2) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        return {"_status": e.code, **json.loads(e.read())}


def test_pulse_encoding() -> None:
    assert pulse_seconds(0) == 0 and pulse_seconds(5) == 0.5 and pulse_seconds(111) == 11.1
    assert pulse_seconds(112) == 12 and pulse_seconds(64900) == 64800


async def test_power_and_pulsetime() -> None:
    async with TasmotaSim(relays="2") as sim:
        base = f"http://{sim.host}:{sim.port}"
        assert await asyncio.to_thread(_cm, base, "Power2 On") == {"POWER2": "ON"}
        assert sim.power == [False, True]
        await asyncio.to_thread(_cm, base, "PulseTime1 10")
        assert await asyncio.to_thread(_cm, base, "Power1 On") == {"POWER1": "ON"}
        await asyncio.sleep(1.3)
        assert sim.power[0] is False


async def test_password() -> None:
    async with TasmotaSim(password="pw") as sim:
        base = f"http://{sim.host}:{sim.port}"
        assert (await asyncio.to_thread(_cm, base, "Power"))["_status"] == 401
        assert await asyncio.to_thread(_cm, base, "Power", user="admin", password="pw") == {"POWER": "OFF"}
