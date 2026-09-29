"""TuyaSim checked against the reference client: tinytuya.OutletDevice (CLAUDE.md rule 2)."""

import asyncio
import json
import socket

import pytest
import tinytuya
from tinytuya.core import udp_helper

from ohsim.devices.tuya import TuyaSim

KEY = "0123456789abcdef"


def client(sim: TuyaSim, version: float = 3.3) -> tinytuya.OutletDevice:
    d = tinytuya.OutletDevice(sim.device_id, sim.host, KEY, version=version, port=sim.port, connection_timeout=2)
    d.set_socketRetryLimit(1)
    return d


async def run(fn, *args):
    return await asyncio.to_thread(fn, *args)


async def test_status_and_control_via_tinytuya() -> None:
    async with TuyaSim(key=KEY) as sim:
        d = client(sim)
        st = await run(d.status)
        assert st["dps"] == {"1": False, "9": 0}
        r = await run(d.turn_on)
        assert r is None or "Error" not in r
        assert sim.on is True
        st = await run(d.status)
        assert st["dps"]["1"] is True
        d.close()


async def test_countdown_flips_switch() -> None:
    async with TuyaSim(key=KEY) as sim:
        d = client(sim)
        await run(d.turn_on)
        await run(d.set_value, 9, 1)
        assert 0 < sim.current_dps()["9"] <= 1
        await asyncio.sleep(1.3)
        assert sim.on is False and sim.dps["9"] == 0
        d.close()


async def test_device22_autodetected_by_tinytuya() -> None:
    async with TuyaSim(key=KEY, device22="1") as sim:
        assert len(sim.device_id) == 22
        d = client(sim)
        d.set_dpsUsed({"1": None, "9": None})
        st = await run(d.status)
        if "dps" not in st:  # tinytuya switches to device22 after "data unvalid" and retries
            st = await run(d.status)
        assert st["dps"]["1"] is False
        d.close()


async def test_protocol_31_control_and_query() -> None:
    async with TuyaSim(key=KEY, version="3.1") as sim:
        d = client(sim, 3.1)
        await run(d.turn_on)
        assert sim.on is True
        st = await run(d.status)
        assert st["dps"]["1"] is True
        d.close()


async def test_bulb_profile() -> None:
    async with TuyaSim(key=KEY, profile="bulb") as sim:
        d = client(sim)
        await run(d.set_value, 20, True)
        assert sim.on is True and sim.switch_dp == "20"
        d.close()


async def test_beacons_decrypt_with_tinytuya() -> None:
    rx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    rx.bind(("127.0.0.1", 0))
    rx.settimeout(3)
    port = rx.getsockname()[1]
    async with TuyaSim(key=KEY, beacon_port=str(port)) as sim:
        data = await asyncio.to_thread(rx.recv, 4096)
        beacon = json.loads(udp_helper.decrypt_udp(data))
        assert beacon["gwId"] == sim.device_id and beacon["version"] == "3.3"
    rx.close()


def test_bad_key_rejected() -> None:
    with pytest.raises(ValueError):
        TuyaSim(key="short")


async def test_protocol_34_session_status_control_countdown() -> None:
    async with TuyaSim(key=KEY, version="3.4") as sim:
        d = client(sim, version=3.4)
        st = await run(d.status)
        assert st["dps"] == {"1": False, "9": 0}, st
        await run(d.turn_on)
        assert sim.on is True
        await run(d.set_value, 9, 1)
        await asyncio.sleep(1.3)
        assert sim.on is False
        st = await run(d.status)
        assert st["dps"]["1"] is False
        d.close()


async def test_protocol_34_wrong_key_gets_nothing() -> None:
    async with TuyaSim(key=KEY, version="3.4") as sim:
        d = tinytuya.OutletDevice(sim.device_id, sim.host, "WrongKeyWrongKey", version=3.4, port=sim.port, connection_timeout=1)
        d.set_socketRetryLimit(1)
        st = await run(d.status)
        assert "Error" in st or "Err" in st, st
        assert sim.on is False
        d.close()


async def test_protocol_35_session_status_control() -> None:
    async with TuyaSim(key=KEY, version="3.5") as sim:
        d = client(sim, version=3.5)
        st = await run(d.status)
        assert st["dps"] == {"1": False, "9": 0}, st
        await run(d.turn_on)
        assert sim.on is True
        st = await run(d.status)
        assert st["dps"]["1"] is True
        d.close()


def test_protocol_35_beacon_decrypts_with_tinytuya() -> None:
    sim = TuyaSim(key=KEY, version="3.5")
    assert json.loads(udp_helper.decrypt_udp(sim.beacon_frame()))["version"] == "3.5"


async def test_multi_gang_switches_and_countdowns() -> None:
    async with TuyaSim(key=KEY, gang="3") as sim:
        d = client(sim)
        st = await run(d.status)
        assert st["dps"] == {"1": False, "2": False, "3": False, "7": 0, "8": 0, "9": 0}
        await run(d.turn_on, 2)
        assert sim.dps["2"] is True and sim.dps["1"] is False
        await run(d.set_value, 8, 1)
        await asyncio.sleep(1.3)
        assert sim.dps["2"] is False
        d.close()


async def test_bulb_type_a_detected_by_tinytuya() -> None:
    async with TuyaSim(key=KEY, profile="bulba") as sim:
        b = tinytuya.BulbDevice(sim.device_id, sim.host, KEY, version=3.3, port=sim.port, connection_timeout=2)
        b.set_socketRetryLimit(1)
        await run(b.detect_bulb)
        assert b.bulb_type == "A"
        await run(b.set_brightness_percentage, 50)
        assert sim.dps["3"] == 127 and sim.dps["1"] is True
        b.close()
