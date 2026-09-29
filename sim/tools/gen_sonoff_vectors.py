#!/usr/bin/env python3
"""eWeLink LAN (Sonoff) crypto vectors from AlexxIT/SonoffLAN (the reference, CLAUDE.md
rule 2). Output: app/test/adapters/sonoff/crypto_vectors.json.

    git clone https://github.com/AlexxIT/SonoffLAN /tmp/SonoffLAN
    python sim/tools/gen_sonoff_vectors.py /tmp/SonoffLAN

encrypt()/decrypt() are taken verbatim from custom_components/sonoff/core/ewelink/local.py
(extracted with ast so Home Assistant is not needed), with os.urandom pinned for the IV.
"""

from __future__ import annotations

import ast
import base64
import hashlib
import json
import os
import sys
from pathlib import Path
from unittest import mock

from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

OUT = Path(__file__).resolve().parents[2] / "app/test/adapters/sonoff/crypto_vectors.json"
IV = bytes(range(0x40, 0x50))


def load_reference(repo: Path) -> dict:
    src = (repo / "custom_components/sonoff/core/ewelink/local.py").read_text()
    tree = ast.parse(src)
    fns = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in ("encrypt", "decrypt")]
    ns: dict = {"hashlib": hashlib, "os": os, "json": json, "base64": base64, "padding": padding,
                "Cipher": Cipher, "algorithms": algorithms, "modes": modes}
    exec(compile(ast.Module(body=fns, type_ignores=[]), "local.py", "exec"), ns)  # noqa: S102
    return ns


def main(repo: Path) -> None:
    ref = load_reference(repo)
    cases = []
    for key, data in (
        ("0123456789abcdef0123456789abcdef", {"switch": "on"}),
        ("a1b2c3d4-e5f6-4a7b-8c9d-e0f1a2b3c4d5", {"switches": [{"switch": "off", "outlet": 1}]}),
    ):
        payload = {"sequence": "1790000000000", "deviceid": "1000abcdef", "selfApikey": "123", "data": dict(data)}
        with mock.patch("os.urandom", return_value=IV):
            enc = ref["encrypt"](json.loads(json.dumps(payload)), key)
        assert json.loads(ref["decrypt"](enc, key)) == data
        cases.append({"devicekey": key, "plain": data, "request": enc})
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"source": "AlexxIT/SonoffLAN local.py encrypt/decrypt", "iv": IV.hex(), "cases": cases}, indent=2) + "\n")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/SonoffLAN"))
