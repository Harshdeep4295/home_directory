"""YeelightSim checked against the reference client: python-yeelight 0.7.16 Bulb."""

import asyncio

from yeelight import Bulb, CronType

from ohsim.devices.yeelight import YeelightSim


async def test_bulb_control_via_python_yeelight() -> None:
    async with YeelightSim(minute="1") as sim:
        b = Bulb(sim.host, port=sim.port)

        def go() -> dict:
            b.turn_on()
            b.set_brightness(40)
            b.set_color_temp(3000)
            return b.get_properties(["power", "bright", "ct"])

        props = await asyncio.to_thread(go)
        assert props["power"] == "on" and props["bright"] == "40" and props["ct"] == "3000"
        assert (sim.power, sim.bright, sim.ct) == ("on", 40, 3000)


async def test_cron_off_timer_via_python_yeelight() -> None:
    async with YeelightSim(minute="1") as sim:
        b = Bulb(sim.host, port=sim.port)
        await asyncio.to_thread(b.turn_on)
        await asyncio.to_thread(b.cron_add, CronType.off, 1)
        got = await asyncio.to_thread(b.cron_get, CronType.off)
        assert got["type"] == 0 and got["delay"] == 1
        await asyncio.sleep(1.3)
        assert sim.power == "off"
        await asyncio.to_thread(b.turn_on)
        await asyncio.to_thread(b.cron_add, CronType.off, 1)
        await asyncio.to_thread(b.cron_del, CronType.off)
        await asyncio.sleep(1.3)
        assert sim.power == "on"
