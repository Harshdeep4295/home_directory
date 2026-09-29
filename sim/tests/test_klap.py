"""KlapSim checked against python-kasa's own KLAP transports and protocols."""

from kasa import Credentials, DeviceConfig
from kasa.deviceconfig import DeviceConnectionParameters, DeviceEncryptionType, DeviceFamily
from kasa.protocols import IotProtocol, SmartProtocol
from kasa.transports.klaptransport import KlapTransport, KlapTransportV2

from ohsim.devices.klap import KlapSim


def cfg(sim: KlapSim, family: DeviceFamily, user: str = "user@example.com", pw: str = "hunter2") -> DeviceConfig:
    return DeviceConfig(
        host=sim.host,
        port_override=sim.port,
        timeout=2,
        credentials=Credentials(user, pw),
        connection_type=DeviceConnectionParameters(family, DeviceEncryptionType.Klap, login_version=2),
    )


async def test_smart_klap_v2_with_python_kasa() -> None:
    async with KlapSim(family="smart") as sim:
        p = SmartProtocol(transport=KlapTransportV2(config=cfg(sim, DeviceFamily.SmartTapoPlug)))
        info = await p.query("get_device_info")
        assert info["get_device_info"]["device_on"] is False
        await p.query({"set_device_info": {"device_on": True}})
        assert sim.on is True
        await p.close()


async def test_iot_klap_v1_with_python_kasa() -> None:
    async with KlapSim(family="iot") as sim:
        p = IotProtocol(transport=KlapTransport(config=cfg(sim, DeviceFamily.IotSmartPlugSwitch)))
        r = await p.query({"system": {"set_relay_state": {"state": 1}}})
        assert r["system"]["set_relay_state"]["err_code"] == 0
        assert sim.on is True
        await p.close()


async def test_default_tapo_credentials_are_found_by_python_kasa() -> None:
    async with KlapSim(family="smart", creds="TAPO") as sim:
        p = SmartProtocol(transport=KlapTransportV2(config=cfg(sim, DeviceFamily.SmartTapoPlug, "someone@else", "x")))
        info = await p.query("get_device_info")
        assert "device_on" in info["get_device_info"]
        await p.close()
