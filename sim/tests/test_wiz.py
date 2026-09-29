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
