# sim — device simulators

Fake LAN devices on `127.0.0.1` for adapter tests. Python 3.11+, stdlib only at runtime.

```sh
pip install -r sim/requirements-dev.txt
pytest sim                                      # simulator self-tests
python sim/run.py --devices wiz,wiz:mac=a8bb50000002 --base-port 20000
```

`run.py` prints one JSON line `{name: {kind, protocol, host, port, id}}` once all devices
listen, then runs until SIGINT/SIGTERM or until stdin closes. Device spec syntax:
`kind[:key=value...]`; common keys `name`, `id`, `port`, plus per-kind options.

| kind | protocol | task |
|---|---|---|
| `wiz` | UDP JSON getPilot/setPilot/getSystemConfig/registration; opts `mac`, `module`, `fw`, `drop` | T2.2 |

Add a simulator: subclass `UdpSimDevice` or `TcpSimDevice` in `ohsim/devices/`, register it in
`ohsim/registry.py`, add tests in `tests/`.
