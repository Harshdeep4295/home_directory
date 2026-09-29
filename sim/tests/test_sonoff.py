"""SonoffSim crypto checked against vectors produced by AlexxIT/SonoffLAN's own
encrypt()/decrypt() (sim/tools/gen_sonoff_vectors.py), plus the request flow."""

import asyncio
import json
import urllib.request
from pathlib import Path
from unittest import mock

from ohsim.devices.sonoff import SonoffSim, decrypt_data, encrypt_data

VECTORS = json.loads((Path(__file__).resolve().parents[2] / "app/test/adapters/sonoff/crypto_vectors.json").read_text())


def test_crypto_matches_sonofflan_vectors() -> None:
    iv = bytes.fromhex(VECTORS["iv"])
    for c in VECTORS["cases"]:
        with mock.patch("ohsim.devices.sonoff.os.urandom", return_value=iv):
            data, iv_b64 = encrypt_data(c["plain"], c["devicekey"])
        assert (data, iv_b64) == (c["request"]["data"], c["request"]["iv"])
        assert json.loads(decrypt_data(data, iv_b64, c["devicekey"])) == c["plain"]


def _post(url: str, body: dict) -> dict:
    r = urllib.request.Request(url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=2) as resp:
        return json.loads(resp.read())


async def test_encrypted_switch_and_info() -> None:
    key = "0123456789abcdef0123456789abcdef"
    async with SonoffSim(devicekey=key) as sim:
        url = f"http://{sim.host}:{sim.port}/zeroconf"
        data, iv = encrypt_data({"switch": "on"}, key)
        body = {"sequence": "1", "deviceid": sim.device_id, "selfApikey": "123", "data": data, "encrypt": True, "iv": iv}
        r = await asyncio.to_thread(_post, f"{url}/switch", body)
        assert r["error"] == 0 and sim.on
        data, iv = encrypt_data({}, key)
        r = await asyncio.to_thread(_post, f"{url}/info", {**body, "data": data, "iv": iv})
        assert json.loads(decrypt_data(r["data"], r["iv"], key)) == {"switch": "on"}
        bad, iv = encrypt_data({"switch": "off"}, "wrongwrongwrongwrongwrongwrong00")
        r = await asyncio.to_thread(_post, f"{url}/switch", {**body, "data": bad, "iv": iv})
        assert r["error"] != 0 and sim.on
