# Offline Home

Control smart plugs, switches and bulbs on your home Wi-Fi **directly over the LAN — no
internet, no vendor cloud** — by tap or by offline voice (English + Hinglish), with timers
("geyser on for 20 minutes", "AC band karo 11 baje").

Flutter app for Android and iOS. Personal, non-commercial, open-source project.

> **Not affiliated with, endorsed by, or supported by** Tuya, Wipro, Syska, Signify/Philips
> (WiZ, Hue), TP-Link (Kasa, Tapo), Shelly, Yeelight, Sonoff/eWeLink, Tasmota, ESPHome, Amazon
> or any other vendor. Brand names are used only to say which devices work. Local protocols
> are implemented from public documentation and open-source projects. Use at your own risk:
> switching mains appliances (geysers, heaters, ACs) on timers is your responsibility.

## What it does

- **Finds your devices** on the Wi-Fi (UDP broadcasts, mDNS, TCP/HTTP probes) and tells you
  which are ready, which need a key and which are not supported yet.
- **Tap to toggle**, long-press for brightness / colour temperature, rooms, aliases and a
  home-screen widget + quick-settings tile (Android).
- **Offline voice** in English and Hinglish using the phone's on-device speech recogniser —
  audio never leaves the phone.
- **Timers** that run on the device itself when it has a timer ("plug timer"), otherwise on the
  phone ("phone timer"); the app always says which.
- **No internet on the control path.** The only code that ever goes online is the optional
  Tuya cloud key import, and only when you start it (`app/lib/onboarding/cloud_import/`, guarded
  by a test).

## Supported devices

| Family | How | Timer | Needs |
|---|---|---|---|
| Tuya 3.1–3.5 (Wipro, Syska, Smart Life …) incl. bulbs, multi-gang | TCP 6668 | plug timer | local key (devices.json import, cloud import or paste) |
| WiZ (Philips Smart Wi-Fi) | UDP 38899 | phone | — |
| Shelly Gen1 / Gen2+ | HTTP | plug timer | password if set |
| Kasa (older, XOR) plugs / strips / bulbs | TCP 9999 | plug timer | — |
| Tapo / newer Kasa (KLAP) | HTTP | phone | TP-Link account (stays on the phone) |
| Philips Hue (bridge) | HTTP v1 | bridge timer | press the bridge button once |
| Yeelight | TCP 55443 | off-timer on the bulb | "LAN Control" on in the Yeelight app |
| Sonoff (DIY / LAN mode) | HTTP 8081 | phone | devicekey for encrypted LAN mode |
| Tasmota | HTTP | on-for pulse | password if set |
| ESPHome (`web_server`) | HTTP | phone | entity id, password if set |

Every adapter is tested against a simulator in `sim/`, and those simulators are checked
against the reference open-source client (tinytuya, aioshelly, python-kasa, aiohue,
python-yeelight, SonoffLAN). Real-hardware checks still to do are listed in
[`docs/HARDWARE_LOG.md`](docs/HARDWARE_LOG.md).

## Install on your phones

See **[docs/INSTALL.md](docs/INSTALL.md)**: `make install-apk` for Android, `make ios-device`
for an iPhone signed with a free Apple ID (re-run every 7 days).

## Status

v1 feature-complete (milestones M0–M8 in [`docs/TASKS.md`](docs/TASKS.md)); real-device
validation pending. Design: [`docs/PLAN.md`](docs/PLAN.md) and
[`docs/PSEUDOCODE.md`](docs/PSEUDOCODE.md).

## Layout

| Path | What |
|---|---|
| `app/` | Flutter app (`lib/adapters`, `discovery`, `engine`, `timers`, `voice`, `ui`, …) |
| `sim/` | Python device simulators + tests; `sim/tools/` regenerates byte-exact protocol vectors from the reference libraries |
| `spike/` | Scripts for exploring real devices (start with `spike/survey.py`) |
| `docs/` | Plan, tasks, pseudocode, hardware log, install guide |

## Develop

Requires Flutter 3.47+ and Python 3.11+.

```sh
make deps     # flutter pub get + pip install sim dev deps
make test     # analyze + flutter test + pytest sim
make sim SIMS=tuya:key=0123456789abcdef,wiz   # run simulators on localhost
make help     # all targets
```

CI (`.github/workflows/ci.yml`) runs format, codegen, analyze, Flutter tests and the
simulator tests on every PR.

## License

[MIT](LICENSE)
