#!/usr/bin/env python3
"""Shelly Gen2 RPC digest-auth vectors from aioshelly (the reference, CLAUDE.md rule 2).
Output: app/test/adapters/shelly/digest_vectors.json, consumed by the Dart ShellyAdapter
tests.

    pip install aioshelly==13.34.0 && python sim/tools/gen_shelly_vectors.py

Uses aioshelly/rpc_device/wsrpc.py AuthData.update_challenge + get_auth with
secrets.token_bytes pinned so the cnonce is reproducible.
"""

from __future__ import annotations

import json
from pathlib import Path
from unittest import mock

import aioshelly
from aioshelly.rpc_device.wsrpc import AuthData

OUT = Path(__file__).resolve().parents[2] / "app/test/adapters/shelly/digest_vectors.json"
RANDOM = bytes(range(16))


def main() -> None:
    cases = []
    for realm, password, challenge in (
        ("shellyplus1-a8032ab12345", "pw", {"auth_type": "digest", "nonce": 1790000001, "nc": 1, "realm": "shellyplus1-a8032ab12345", "algorithm": "SHA-256"}),
        ("shellypro4pm-ec62608a0000", "s3cr3t!", {"auth_type": "digest", "nonce": 1625038762, "nc": "2", "realm": "shellypro4pm-ec62608a0000", "algorithm": "SHA-256"}),
    ):
        a = AuthData(realm, "admin", password)
        a.update_challenge(challenge)
        with mock.patch("aioshelly.rpc_device.wsrpc.secrets.token_bytes", return_value=RANDOM):
            first = a.get_auth()
            second = a.get_auth()
        cases.append({"realm": realm, "password": password, "challenge": challenge, "auth": [first, second]})
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(
        json.dumps({"source": f"aioshelly {aioshelly.__version__ if hasattr(aioshelly, '__version__') else '13.34.0'}", "randomBytes": RANDOM.hex(), "cases": cases}, indent=2)
        + "\n"
    )
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
