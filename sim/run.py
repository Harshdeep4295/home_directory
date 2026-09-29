#!/usr/bin/env python3
"""Start simulated devices on localhost.

    python sim/run.py --devices wiz,wiz:mac=a8bb50000002 [--base-port 20000]

Prints ONE line of JSON to stdout once every device is listening:
    {"wiz": {"kind": "wiz", "protocol": "wiz", "host": "127.0.0.1", "port": 20000, "id": "..."}}
then runs until SIGINT/SIGTERM or stdin closes (so a parent test process that dies takes the
simulators with it). Flutter integration tests read that line to find the ports.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import signal
import sys
import threading
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from ohsim import SIM_TYPES, parse_specs, start_all  # noqa: E402


def _watch_stdin(loop: asyncio.AbstractEventLoop, stop: asyncio.Event) -> None:
    """Set ``stop`` when stdin reaches EOF. Daemon thread, so it never blocks shutdown."""

    def run() -> None:
        sys.stdin.read()
        loop.call_soon_threadsafe(stop.set)

    threading.Thread(target=run, name="stdin-watch", daemon=True).start()


async def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--devices", required=True, help=f"comma list; kinds: {', '.join(sorted(SIM_TYPES))}")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--base-port", type=int, default=0, help="0 = OS-assigned ports")
    ap.add_argument("--no-stdin-watch", action="store_true", help="do not exit when stdin closes")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.WARNING, stream=sys.stderr)

    try:
        specs = parse_specs(args.devices)
    except ValueError as e:
        ap.error(str(e))
    devices = await start_all(specs, host=args.host, base_port=args.base_port)
    print(json.dumps({d.name: d.info() for d in devices}), flush=True)

    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, stop.set)
    if not args.no_stdin_watch and not sys.stdin.isatty():
        _watch_stdin(loop, stop)
    await stop.wait()
    for d in devices:
        await d.stop()
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main(sys.argv[1:])))
