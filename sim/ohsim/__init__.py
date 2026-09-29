"""Offline Home device simulators.

Each simulator is a fake LAN device bound to 127.0.0.1 so adapters (Dart) and tests (pytest)
can exercise real sockets without hardware. See docs/PSEUDOCODE.md §14.
"""

from .base import SimDevice, TcpSimDevice, UdpSimDevice
from .registry import SIM_TYPES, DeviceSpec, parse_specs, start_all

__all__ = [
    "SIM_TYPES",
    "DeviceSpec",
    "SimDevice",
    "TcpSimDevice",
    "UdpSimDevice",
    "parse_specs",
    "start_all",
]
