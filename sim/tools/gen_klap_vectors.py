#!/usr/bin/env python3
"""KLAP vectors from python-kasa 0.10.2 (the reference, CLAUDE.md rule 2).
Output: app/test/adapters/kasa/klap_vectors.json, consumed by the Dart KLAP transport tests.

    pip install python-kasa==0.10.2 && python sim/tools/gen_klap_vectors.py

Uses kasa/transports/klaptransport.py: KlapTransport / KlapTransportV2 static hash helpers
and KlapEncryptionSession (key/iv/seq/sig derivation, encrypt, decrypt), plus
kasa/credentials.py DEFAULT_CREDENTIALS.
"""

from __future__ import annotations

import json
from pathlib import Path

from kasa.credentials import DEFAULT_CREDENTIALS, Credentials, get_default_credentials
from kasa.transports.klaptransport import KlapEncryptionSession, KlapTransport, KlapTransportV2

OUT = Path(__file__).resolve().parents[2] / "app/test/adapters/kasa/klap_vectors.json"
LOCAL = bytes(range(0x10, 0x20))
REMOTE = bytes(range(0xA0, 0xB0))


def main() -> None:
    creds = Credentials("user@example.com", "hunter2")
    out: dict = {"source": "python-kasa 0.10.2", "localSeed": LOCAL.hex(), "remoteSeed": REMOTE.hex(), "versions": {}}
    for name, t in (("v1", KlapTransport), ("v2", KlapTransportV2)):
        auth = t.generate_auth_hash(creds)
        blank = t.generate_auth_hash(Credentials())
        s = KlapEncryptionSession(LOCAL, REMOTE, auth)
        msgs = []
        for m in ('{"method":"get_device_info"}', '{"method":"set_device_info","params":{"device_on":true}}'):
            payload, seq = s.encrypt(m)
            assert s.decrypt(payload) == m
            msgs.append({"plain": m, "seq": seq, "payload": payload.hex()})
        out["versions"][name] = {
            "username": creds.username,
            "password": creds.password,
            "authHash": auth.hex(),
            "blankAuthHash": blank.hex(),
            "defaultAuthHashes": {k: t.generate_auth_hash(get_default_credentials(v)).hex() for k, v in DEFAULT_CREDENTIALS.items()},
            "handshake1": t.handshake1_seed_auth_hash(LOCAL, REMOTE, auth).hex(),
            "handshake2": t.handshake2_seed_auth_hash(LOCAL, REMOTE, auth).hex(),
            "sessionKey": s._key.hex(),
            "iv": s._iv.hex(),
            "initialSeq": s._seq - len(msgs),
            "sig": s._sig.hex(),
            "messages": msgs,
        }
    out["defaultCredentials"] = {k: list(v) for k, v in DEFAULT_CREDENTIALS.items()}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, indent=2) + "\n")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
