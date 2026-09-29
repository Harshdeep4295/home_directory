"""End-to-end: run.py as a subprocess, the way Flutter integration tests will use it."""

import json
import socket
import subprocess
import sys
from pathlib import Path

RUN = Path(__file__).resolve().parents[1] / "run.py"


def test_run_py_prints_map_and_answers_get_pilot() -> None:
    proc = subprocess.Popen(
        [sys.executable, str(RUN), "--devices", "wiz"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        text=True,
    )
    try:
        line = proc.stdout.readline()  # type: ignore[union-attr]
        info = json.loads(line)["wiz"]
        assert info["protocol"] == "wiz"
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(2)
        s.sendto(b'{"method":"getPilot","params":{}}', (info["host"], info["port"]))
        reply = json.loads(s.recv(4096))
        s.close()
        assert reply["method"] == "getPilot"
    finally:
        proc.stdin.close()  # type: ignore[union-attr]  # EOF on stdin → run.py exits
        assert proc.wait(timeout=5) == 0
