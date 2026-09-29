"""ShellySim checked against the reference: aioshelly's own digest AuthData (Gen2) and the
Gen1 REST shapes aioshelly's block device uses."""

import asyncio
import base64
import json
import urllib.error
import urllib.request

from aioshelly.rpc_device.wsrpc import AuthData

from ohsim.devices.shelly import ShellySim


def _get(url: str, headers: dict[str, str] | None = None) -> tuple[int, dict]:
    req = urllib.request.Request(url, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=2) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        body = e.read()
        try:
            return e.code, json.loads(body)
        except ValueError:
            return e.code, {}


def _post(url: str, frame: dict) -> tuple[int, dict]:
    req = urllib.request.Request(url, data=json.dumps(frame).encode(), headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=2) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


async def run(fn, *args):
    return await asyncio.to_thread(fn, *args)


async def test_gen1_relay_turn_and_flip_back_timer() -> None:
    async with ShellySim(gen="1") as sim:
        base = f"http://{sim.host}:{sim.port}"
        _, info = await run(_get, f"{base}/shelly")
        assert info["type"] == "SHSW-1" and info["auth"] is False
        _, st = await run(_get, f"{base}/relay/0?turn=on&timer=1")
        assert st["ison"] is True and st["has_timer"] is True and st["timer_remaining"] == 1
        await asyncio.sleep(1.3)
        _, st = await run(_get, f"{base}/relay/0")
        assert st["ison"] is False and st["has_timer"] is False


async def test_gen1_basic_auth() -> None:
    async with ShellySim(gen="1", password="pw") as sim:
        base = f"http://{sim.host}:{sim.port}"
        code, _ = await run(_get, f"{base}/relay/0")
        assert code == 401
        auth = "Basic " + base64.b64encode(b"admin:pw").decode()
        code, st = await run(_get, f"{base}/relay/0?turn=on", {"Authorization": auth})
        assert code == 200 and st["ison"] is True


async def test_gen2_rpc_set_toggle_after_and_digest_auth() -> None:
    async with ShellySim(gen="2", password="pw") as sim:
        base = f"http://{sim.host}:{sim.port}"
        _, info = await run(_get, f"{base}/shelly")
        assert info["gen"] == 2 and info["auth_en"] is True
        frame = {"id": 1, "src": "t", "method": "Switch.Set", "params": {"id": 0, "on": True, "toggle_after": 1}}
        code, err = await run(_post, f"{base}/rpc", frame)
        assert code == 401
        challenge = json.loads(err["error"]["message"])
        auth = AuthData(info["auth_domain"], "admin", "pw")
        auth.update_challenge(challenge)
        code, res = await run(_post, f"{base}/rpc", {**frame, "auth": auth.get_auth()})
        assert code == 200 and res["result"] == {"was_on": False}
        st_frame = {"id": 2, "src": "t", "method": "Switch.GetStatus", "params": {"id": 0}, "auth": auth.get_auth()}
        _, st = await run(_post, f"{base}/rpc", st_frame)
        assert st["result"]["output"] is True and st["result"]["timer_duration"] == 1
        await asyncio.sleep(1.3)
        _, st = await run(_post, f"{base}/rpc", {**st_frame, "auth": auth.get_auth()})
        assert st["result"]["output"] is False
        bad = AuthData(info["auth_domain"], "admin", "wrong")
        bad.update_challenge(challenge)
        code, _ = await run(_post, f"{base}/rpc", {**st_frame, "auth": bad.get_auth()})
        assert code == 401
