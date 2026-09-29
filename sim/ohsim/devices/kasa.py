"""TP-Link Kasa legacy (IOT) simulator: TCP 9999 length-prefixed XOR JSON + UDP 9999 discovery.

Framing and request/response shapes follow python-kasa 0.10.2 (the reference, CLAUDE.md
rule 2): transports/xortransport.py (XorEncryption, 4-byte big-endian length prefix),
iot/iotdevice.py (_create_request / _query_helper: {target: {cmd: args}}, err_code, context
child_ids), iot/iotplug.py (system.set_relay_state), iot/iotstrip.py (children),
iot/iotbulb.py (smartlife.iot.smartbulb.lightingservice transition_light_state), discover.py
(UDP datagram = XOR without the length prefix).

Countdown rules: python-kasa only reads/deletes them (iot/modules/rulemodule.py, module
"countdown"); add_rule {"enable","delay","act","name"} and module "count_down" are from
softScheck tplink-smartplug (the protocol source xortransport.py credits). The sim answers
both module names. A rule runs its act (1 on / 0 off) after `delay` s. VERIFY on hardware.

Options:
    type=plug|strip|bulb   device type (default plug)
    children=N             outlets for type=strip (default 3)
    countdown_module=M     answer only this countdown module name (default: both)
    mac=<12 hex>
"""

from __future__ import annotations

import asyncio
import json
import struct
import time
from typing import Any

from kasa.transports.xortransport import XorEncryption

from ..base import TcpSimDevice

LIGHT = "smartlife.iot.smartbulb.lightingservice"
COUNTDOWN_MODULES = ("count_down", "countdown")


class _Outlet:
    def __init__(self, child_id: str, alias: str) -> None:
        self.id = child_id
        self.alias = alias
        self.on = False
        self.rules: list[dict[str, Any]] = []
        self.tasks: list[asyncio.Task[None]] = []


class KasaSim(TcpSimDevice):
    kind = "kasa"
    protocol = "kasa"

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        self.type = self.options.get("type", "plug")
        mac = self.options.get("mac", (self.name.encode().hex() + "000000000000")[:12]).upper()
        self.mac = ":".join(mac[i : i + 2] for i in range(0, 12, 2))
        self.root = _Outlet("", self.name)
        n = int(self.options.get("children", "3")) if self.type == "strip" else 0
        self.children = [_Outlet(f"{self.device_id}{i:02d}", f"Outlet {i + 1}") for i in range(n)]
        self.brightness = 100
        self.color_temp = 2700
        self._udp: asyncio.DatagramTransport | None = None
        self.requests: list[dict[str, Any]] = []
        self._rule_seq = 0

    def default_device_id(self) -> str:
        return ("8006" + self.name.encode().hex().upper() + "0" * 40)[:40]

    def initial_state(self) -> dict[str, Any]:
        return {}

    @property
    def on(self) -> bool:
        return self.root.on

    # ------------------------------------------------------------------ sysinfo

    def sysinfo(self) -> dict[str, Any]:
        base: dict[str, Any] = {
            "sw_ver": "1.0.0 Build 000000 Rel.000000",
            "hw_ver": "1.0",
            "deviceId": self.device_id,
            "alias": self.name,
            "mac": self.mac,
            "err_code": 0,
        }
        if self.type == "bulb":
            return {
                **base,
                "model": "KL130(US)",
                "mic_type": "IOT.SMARTBULB",
                "is_dimmable": 1,
                "is_color": 0,
                "is_variable_color_temp": 1,
                "light_state": self._light_state(),
                # iot/modules/lightpreset.py reads the presets from sysinfo
                "preferred_state": [{"index": 0, "brightness": 50, "hue": 0, "saturation": 0, "color_temp": 2700}],
            }
        info = {**base, "model": "HS103(US)", "mic_type": "IOT.SMARTPLUGSWITCH", "relay_state": int(self.root.on)}
        if self.type == "strip":
            info["model"] = "HS300(US)"
            info["child_num"] = len(self.children)
            info["children"] = [{"id": c.id, "state": int(c.on), "alias": c.alias} for c in self.children]
        return info

    def _light_state(self) -> dict[str, Any]:
        if self.root.on:
            return {"on_off": 1, "mode": "normal", "brightness": self.brightness, "color_temp": self.color_temp, "hue": 0, "saturation": 0}
        return {"on_off": 0, "dft_on_state": {"mode": "normal", "brightness": self.brightness, "color_temp": self.color_temp, "hue": 0, "saturation": 0}}

    # ------------------------------------------------------------------ rules

    def _targets(self, context: dict[str, Any] | None) -> list[_Outlet]:
        ids = (context or {}).get("child_ids")
        if ids:
            return [c for c in self.children if c.id in ids or c.id.endswith(tuple(ids))]
        return [self.root, *self.children] if self.children else [self.root]

    def _add_rule(self, outlet: _Outlet, rule: dict[str, Any]) -> dict[str, Any]:
        if outlet.rules:
            return {"err_code": -10, "err_msg": "table is full"}
        self._rule_seq += 1
        rid = f"{self._rule_seq:032X}"
        delay = int(rule.get("delay", 0))
        entry = {"id": rid, "name": rule.get("name", ""), "enable": int(rule.get("enable", 1)), "delay": delay, "act": int(rule.get("act", 0)), "remain": delay, "_end": time.monotonic() + delay}
        outlet.rules.append(entry)
        outlet.tasks.append(asyncio.get_running_loop().create_task(self._run_rule(outlet, entry)))
        return {"id": rid, "err_code": 0}

    async def _run_rule(self, outlet: _Outlet, rule: dict[str, Any]) -> None:
        await asyncio.sleep(rule["delay"])
        if rule in outlet.rules and rule["enable"]:
            outlet.on = bool(rule["act"])
            outlet.rules.remove(rule)

    def _rules(self, outlet: _Outlet) -> list[dict[str, Any]]:
        now = time.monotonic()
        out = []
        for r in outlet.rules:
            pub = {k: v for k, v in r.items() if not k.startswith("_")}
            pub["remain"] = max(0, round(r["_end"] - now))
            out.append(pub)
        return out

    # ------------------------------------------------------------------ requests

    def handle(self, req: dict[str, Any]) -> dict[str, Any]:
        self.requests.append(req)
        context = req.get("context")
        out: dict[str, Any] = {}
        for target, cmds in req.items():
            if target == "context":
                continue
            res: dict[str, Any] = {}
            for cmd, args in (cmds or {}).items():
                res[cmd] = self._cmd(target, cmd, args or {}, context)
            out[target] = res
        return out

    def _cmd(self, target: str, cmd: str, args: dict[str, Any], context: dict[str, Any] | None) -> dict[str, Any]:
        if target == "system" and cmd == "get_sysinfo":
            return self.sysinfo()
        if target == "system" and cmd == "set_relay_state" and self.type != "bulb":
            for o in self._targets(context):
                o.on = bool(args.get("state"))
            return {"err_code": 0}
        if target == LIGHT and self.type == "bulb":
            if cmd == "get_light_state":
                return {**self._light_state(), "err_code": 0}
            if cmd == "transition_light_state":
                if "on_off" in args:
                    self.root.on = bool(args["on_off"])
                if "brightness" in args:
                    self.brightness = int(args["brightness"])
                if "color_temp" in args:
                    self.color_temp = int(args["color_temp"])
                return {**self._light_state(), "err_code": 0}
        if target in ("time", "smartlife.iot.common.timesetting"):
            # iot/modules/time.py queries these on every update(); index 0 = UTC-12 table entry
            t = time.gmtime()
            if cmd == "get_time":
                return {"year": t.tm_year, "month": t.tm_mon, "mday": t.tm_mday, "hour": t.tm_hour, "min": t.tm_min, "sec": t.tm_sec, "err_code": 0}
            if cmd == "get_timezone":
                return {"index": 39, "err_code": 0}
        allowed = self.options.get("countdown_module")
        if target in COUNTDOWN_MODULES and (allowed is None or allowed == target):
            outlets = self._targets(context)
            if cmd == "get_rules":
                return {"rule_list": [r for o in outlets for r in self._rules(o)], "err_code": 0}
            if cmd == "add_rule":
                return self._add_rule(outlets[0], args)
            if cmd == "delete_all_rules":
                for o in outlets:
                    o.rules.clear()
                    for t in o.tasks:
                        t.cancel()
                    o.tasks.clear()
                return {"err_code": 0}
        return {"err_code": -2, "err_msg": "member not support"}

    # ------------------------------------------------------------------ transport

    async def handle_connection(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        while True:
            try:
                head = await reader.readexactly(4)
            except asyncio.IncompleteReadError:
                return
            (n,) = struct.unpack(">I", head)
            body = await reader.readexactly(n)
            req = json.loads(XorEncryption.decrypt(body))
            writer.write(XorEncryption.encrypt(json.dumps(self.handle(req))))
            await writer.drain()

    async def start(self) -> None:
        await super().start()
        sim = self
        loop = asyncio.get_running_loop()

        class _Udp(asyncio.DatagramProtocol):
            def connection_made(self, transport: asyncio.BaseTransport) -> None:
                self.transport = transport  # type: ignore[assignment]

            def datagram_received(self, data: bytes, addr: tuple[str, int]) -> None:
                try:
                    req = json.loads(XorEncryption.decrypt(data))
                except ValueError:
                    return
                # discover.py: the reply is XOR without the TCP length prefix
                self.transport.sendto(XorEncryption.encrypt(json.dumps(sim.handle(req)))[4:], addr)  # type: ignore[attr-defined]

        self._udp, _ = await loop.create_datagram_endpoint(_Udp, local_addr=(self.host, self.port))

    async def stop(self) -> None:
        for o in (self.root, *self.children):
            for t in o.tasks:
                t.cancel()
            o.tasks.clear()
        if self._udp is not None:
            self._udp.close()
            self._udp = None
        await super().stop()
