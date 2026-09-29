"""KasaSim checked against the reference client: python-kasa 0.10.2 IOT devices."""

import asyncio

from kasa import DeviceConfig
from kasa.iot import IotBulb, IotPlug, IotStrip
from kasa.transports.xortransport import XorEncryption

from ohsim.devices.kasa import KasaSim


def cfg(sim: KasaSim) -> DeviceConfig:
    return DeviceConfig(host=sim.host, port_override=sim.port, timeout=2)


async def test_plug_via_python_kasa() -> None:
    async with KasaSim() as sim:
        p = IotPlug(sim.host, config=cfg(sim))
        await p.update()
        assert p.is_on is False and p.alias == sim.name
        await p.turn_on()
        assert sim.on is True
        await p.update()
        assert p.is_on is True
        await p.protocol.close()


async def test_strip_children_via_python_kasa() -> None:
    async with KasaSim(type="strip", children="2") as sim:
        s = IotStrip(sim.host, config=cfg(sim))
        await s.update()
        assert len(s.children) == 2
        await s.children[1].turn_on()
        assert [c.on for c in sim.children] == [False, True]
        await s.protocol.close()


async def test_bulb_via_python_kasa() -> None:
    async with KasaSim(type="bulb") as sim:
        b = IotBulb(sim.host, config=cfg(sim))
        await b.update()
        await b.turn_on()
        await b.modules["Light"].set_brightness(40)
        assert sim.on is True and sim.brightness == 40
        await b.update()
        assert b.modules["Light"].brightness == 40
        await b.protocol.close()


async def test_countdown_rule_and_python_kasa_rule_listing() -> None:
    async with KasaSim() as sim:
        # add_rule as softScheck documents it (python-kasa has no add helper)
        r = sim.handle({"count_down": {"add_rule": {"enable": 1, "delay": 1, "act": 1, "name": "t"}}})
        assert r["count_down"]["add_rule"]["err_code"] == 0
        # python-kasa's own Countdown module reads rules via the "countdown" module
        s = IotStrip(sim.host, config=cfg(sim))
        rules = sim.handle({"countdown": {"get_rules": {}}})["countdown"]["get_rules"]["rule_list"]
        assert rules[0]["act"] == 1 and rules[0]["remain"] <= 1
        await asyncio.sleep(1.3)
        assert sim.on is True
        assert sim.handle({"count_down": {"get_rules": {}}})["count_down"]["get_rules"]["rule_list"] == []
        del s


async def test_udp_discovery_reply_is_prefixless_xor() -> None:
    async with KasaSim() as sim:
        loop = asyncio.get_running_loop()
        fut: asyncio.Future[bytes] = loop.create_future()

        class P(asyncio.DatagramProtocol):
            def datagram_received(self, data, addr):  # type: ignore[no-untyped-def]
                fut.set_result(data)

        t, _ = await loop.create_datagram_endpoint(P, remote_addr=(sim.host, sim.port))
        t.sendto(XorEncryption.encrypt('{"system":{"get_sysinfo":{}}}')[4:])
        data = await asyncio.wait_for(fut, 2)
        t.close()
        assert '"deviceId"' in XorEncryption.decrypt(data)
