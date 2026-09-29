from ohsim.devices.wiz import WizSim


async def test_get_and_set_pilot(udp) -> None:
    async with WizSim() as sim:
        r = await udp.request(sim.host, sim.port, {"method": "getPilot", "params": {}})
        assert r["method"] == "getPilot"
        assert r["result"]["state"] is False
        assert r["result"]["mac"] == sim.device_id

        r = await udp.request(sim.host, sim.port, {"method": "setPilot", "params": {"state": True, "dimming": 40}})
        assert r["result"] == {"success": True}
        assert sim.state["on"] is True and sim.state["dimming"] == 40


async def test_unknown_method_returns_error(udp) -> None:
    async with WizSim() as sim:
        r = await udp.request(sim.host, sim.port, {"method": "bogus", "params": {}})
        assert r["error"]["code"] == -32601


async def test_garbage_is_ignored_and_sim_survives(udp) -> None:
    async with WizSim() as sim:
        import socket

        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.sendto(b"\xff not json", (sim.host, sim.port))
        s.close()
        r = await udp.request(sim.host, sim.port, {"method": "getPilot", "params": {}})
        assert r["method"] == "getPilot"


async def test_system_config_and_registration(udp) -> None:
    async with WizSim(module="ESP01_SHDW1C_31", fw="1.21.0") as sim:
        r = await udp.request(sim.host, sim.port, {"method": "getSystemConfig", "params": {}})
        assert r["result"]["moduleName"] == "ESP01_SHDW1C_31"
        assert r["result"]["fwVersion"] == "1.21.0"
        reg = {
            "method": "registration",
            "params": {"phoneMac": "AAAAAAAAAAAA", "register": False, "phoneIp": "1.2.3.4", "id": "1"},
        }
        r = await udp.request(sim.host, sim.port, reg)
        assert r["result"] == {"mac": sim.device_id, "success": True}


async def test_drop_first_n(udp) -> None:
    import asyncio

    import pytest

    async with WizSim(drop="1") as sim:
        with pytest.raises(asyncio.TimeoutError):
            await udp.request(sim.host, sim.port, {"method": "getPilot", "params": {}}, timeout=0.3)
        r = await udp.request(sim.host, sim.port, {"method": "getPilot", "params": {}})
        assert r["method"] == "getPilot"
