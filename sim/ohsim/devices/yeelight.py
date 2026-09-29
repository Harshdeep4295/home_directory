"""Yeelight LAN-control simulator: TCP 55443, one JSON object per line ("\\r\\n").

Follows python-yeelight 0.7.16 (the reference, CLAUDE.md rule 2), yeelight/main.py:
- request {"id","method","params"} + "\\r\\n" (Bulb.send_command); replies {"id","result"}
  or {"id","error":{"code","message"}}; unsolicited {"method":"props","params":{...}}
  notifications may precede a reply (send_command skips them).
- get_prop [names] → result list of strings (Bulb.get_properties).
- set_power ["on"|"off", effect, duration(, mode)], set_bright [1..100, effect, duration],
  set_ct_abx [kelvin, effect, duration] (_command_to_send_command appends effect/duration).
- cron_add [0, minutes] / cron_get [0] / cron_del [0]: CronType.off = 0, the only type — a
  power-off timer in minutes. cron_get reply shape [{"type":0,"delay":<min left>,"mix":0}]
  is from the Yeelight inter-operation spec (python-yeelight does not parse it) — VERIFY.

Options:
    minute=<s>   seconds per cron "minute" (default 60; tests use 1)
"""

from __future__ import annotations

import asyncio
import json
import time
from typing import Any

from ..base import TcpSimDevice


class YeelightSim(TcpSimDevice):
    kind = "yeelight"
    protocol = "yeelight"

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        self.minute = float(self.options.get("minute", "60"))
        self.power = "off"
        self.bright = 100
        self.ct = 4000
        self._cron: asyncio.Task[None] | None = None
        self._cron_end: float | None = None
        self.commands: list[str] = []

    def default_device_id(self) -> str:
        return "0x00000000037073d2"

    @property
    def on(self) -> bool:
        return self.power == "on"

    async def handle_connection(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        while True:
            line = await reader.readline()
            if not line:
                return
            line = line.strip()
            if not line:
                continue
            try:
                req = json.loads(line)
            except ValueError:
                writer.write(b'{"id":0,"error":{"code":-1,"message":"invalid command"}}\r\n')
                continue
            changed, reply = self._handle(req)
            if changed:  # the bulb notifies before answering; clients must skip it
                writer.write((json.dumps({"method": "props", "params": changed}) + "\r\n").encode())
            writer.write((json.dumps(reply) + "\r\n").encode())
            await writer.drain()

    def _handle(self, req: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
        rid, method, params = req.get("id"), req.get("method"), req.get("params") or []
        self.commands.append(method)
        ok = {"id": rid, "result": ["ok"]}
        if method == "get_prop":
            props = {"power": self.power, "bright": str(self.bright), "ct": str(self.ct), "color_mode": "2", "name": ""}
            return {}, {"id": rid, "result": [props.get(p, "") for p in params]}
        if method == "set_power" and params and params[0] in ("on", "off"):
            self.power = params[0]
            return {"power": self.power}, ok
        if method == "set_bright" and params:
            self.bright = max(1, min(100, int(params[0])))
            return {"bright": self.bright}, ok
        if method == "set_ct_abx" and params:
            self.ct = int(params[0])
            return {"ct": self.ct}, ok
        if method == "cron_add" and len(params) >= 2 and params[0] == 0:
            self._arm(int(params[1]))
            return {}, ok
        if method == "cron_get" and params[:1] == [0]:
            if self._cron_end is None:
                return {}, {"id": rid, "result": []}
            left = max(0, round((self._cron_end - time.monotonic()) / self.minute))
            return {}, {"id": rid, "result": [{"type": 0, "delay": left, "mix": 0}]}
        if method == "cron_del" and params[:1] == [0]:
            self._arm(0)
            return {}, ok
        return {}, {"id": rid, "error": {"code": -1, "message": "method not supported"}}

    def _arm(self, minutes: int) -> None:
        if self._cron is not None:
            self._cron.cancel()
            self._cron = None
        self._cron_end = None
        if minutes > 0:
            secs = minutes * self.minute
            self._cron_end = time.monotonic() + secs
            self._cron = asyncio.get_running_loop().create_task(self._off_later(secs))

    async def _off_later(self, secs: float) -> None:
        await asyncio.sleep(secs)
        self.power = "off"
        self._cron = None
        self._cron_end = None

    async def stop(self) -> None:
        if self._cron is not None:
            self._cron.cancel()
            self._cron = None
        await super().stop()
