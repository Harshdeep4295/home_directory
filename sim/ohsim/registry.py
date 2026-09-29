"""Device-type registry and the ``--devices`` spec parser used by run.py."""

from __future__ import annotations

from dataclasses import dataclass, field

from .base import SimDevice
from .devices.shelly import ShellySim
from .devices.tuya import TuyaSim
from .devices.wiz import WizSim

SIM_TYPES: dict[str, type[SimDevice]] = {
    WizSim.kind: WizSim,
    TuyaSim.kind: TuyaSim,
    ShellySim.kind: ShellySim,
}


@dataclass
class DeviceSpec:
    """One ``kind[:key=value...]`` entry, e.g. ``tuya33:key=0123456789abcdef:id=abc``."""

    kind: str
    name: str
    options: dict[str, str] = field(default_factory=dict)


def parse_specs(text: str) -> list[DeviceSpec]:
    specs: list[DeviceSpec] = []
    seen: dict[str, int] = {}
    for raw in (part.strip() for part in text.split(",")):
        if not raw:
            continue
        kind, *pairs = raw.split(":")
        if kind not in SIM_TYPES:
            raise ValueError(f"unknown simulator {kind!r}; known: {', '.join(sorted(SIM_TYPES))}")
        options: dict[str, str] = {}
        for pair in pairs:
            key, sep, value = pair.partition("=")
            if not sep or not key:
                raise ValueError(f"bad option {pair!r} in {raw!r} (expected key=value)")
            options[key] = value
        seen[kind] = seen.get(kind, 0) + 1
        name = options.pop("name", kind if seen[kind] == 1 else f"{kind}-{seen[kind]}")
        specs.append(DeviceSpec(kind=kind, name=name, options=options))
    names = [s.name for s in specs]
    if len(names) != len(set(names)):
        raise ValueError(f"duplicate simulator names: {names}")
    return specs


async def start_all(
    specs: list[DeviceSpec], host: str = "127.0.0.1", base_port: int = 0
) -> list[SimDevice]:
    """Start every spec. base_port=0 → OS-assigned ports; else base_port, base_port+1, ..."""
    devices: list[SimDevice] = []
    try:
        for i, spec in enumerate(specs):
            options = dict(spec.options)
            port = int(options.pop("port", base_port + i if base_port else 0))
            device_id = options.pop("id", None)
            dev = SIM_TYPES[spec.kind](
                name=spec.name, host=host, port=port, device_id=device_id, **options
            )
            await dev.start()
            devices.append(dev)
    except Exception:
        for dev in devices:
            await dev.stop()
        raise
    return devices
