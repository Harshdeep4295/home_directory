"""spike/survey.py must find simulated devices (T0.6 acceptance). Runs without tinytuya/zeroconf."""

import asyncio
import importlib.util
import json
import sys
from pathlib import Path

from ohsim.devices.wiz import WizSim

SURVEY = Path(__file__).resolve().parents[2] / "spike" / "survey.py"


def _load_survey():
    spec = importlib.util.spec_from_file_location("survey", SURVEY)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["survey"] = mod
    spec.loader.exec_module(mod)  # type: ignore[union-attr]
    return mod


def test_kasa_xor_roundtrip() -> None:
    survey = _load_survey()
    plain = b'{"system":{"get_sysinfo":{}}}'
    enc = survey.kasa_xor_encrypt(plain)
    assert enc[0] == 171 ^ plain[0]
    assert survey.kasa_xor_decrypt(enc) == plain


async def test_survey_finds_wiz_sim(tmp_path: Path) -> None:
    survey = _load_survey()
    async with WizSim() as sim:
        out = tmp_path / "s.json"
        argv = ["--hosts", sim.host, "--wiz-port", str(sim.port), "--no-tuya", "--no-mdns",
                "--timeout", "0.3", "--out", str(out)]
        rc = await asyncio.to_thread(survey.main, argv)
        assert rc == 0
        result = json.loads(out.read_text())
        dev = result["devices"][sim.host]
        assert dev["guess"] == "wiz"
        assert dev["wiz"]["pilot"]["mac"] == sim.device_id
