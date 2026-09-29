# Offline Home

Control smart plugs, switches and bulbs on your home Wi-Fi **directly over the LAN — no
internet, no vendor cloud** — by tap or by offline voice (English + Hinglish), with timers
("geyser on for 20 minutes", "AC band karo 11 baje").

Flutter app for Android and iOS. Personal, non-commercial, open-source project.

> **Not affiliated with, endorsed by, or supported by** Tuya, Wipro, Syska, Signify/Philips
> (WiZ, Hue), TP-Link (Kasa, Tapo), Shelly, Yeelight, Sonoff/eWeLink, Amazon or any other vendor.
> Local protocols are implemented from public documentation and open-source projects.
> Use at your own risk.

## Status

Early development. See [`docs/TASKS.md`](docs/TASKS.md) for progress and
[`docs/PLAN.md`](docs/PLAN.md) for the design.

## Layout

| Path | What |
|---|---|
| `app/` | Flutter app |
| `sim/` | Python device simulators used by tests |
| `spike/` | Scripts for exploring real devices (start with `spike/survey.py`) |
| `docs/` | Plan, tasks, pseudocode, hardware log |

## Develop

Requires Flutter 3.47+ and Python 3.11+.

```sh
make deps     # flutter pub get + pip install sim dev deps
make test     # analyze + flutter test + pytest sim
make help     # all targets
```

## License

[MIT](LICENSE)
