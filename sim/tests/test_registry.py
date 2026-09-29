import pytest

from ohsim import parse_specs, start_all


def test_parse_specs_names_and_options() -> None:
    specs = parse_specs("wiz, wiz:mac=a8bb50000002,wiz:name=hall:id=x")
    assert [s.name for s in specs] == ["wiz", "wiz-2", "hall"]
    assert specs[1].options == {"mac": "a8bb50000002"}
    assert specs[2].options == {"id": "x"}


@pytest.mark.parametrize("bad", ["nope", "wiz:novalue", "wiz:name=a,wiz:name=a"])
def test_parse_specs_rejects(bad: str) -> None:
    with pytest.raises(ValueError):
        parse_specs(bad)


async def test_start_all_ephemeral_ports_and_stop() -> None:
    devices = await start_all(parse_specs("wiz,wiz"))
    try:
        ports = {d.port for d in devices}
        assert len(ports) == 2 and all(p > 0 for p in ports)
        assert devices[0].device_id != devices[1].device_id
    finally:
        for d in devices:
            await d.stop()
    assert not any(d.running for d in devices)
