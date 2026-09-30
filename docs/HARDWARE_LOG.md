# HARDWARE_LOG — real-device results (human-owned)

Claude Code never edits the result rows; it only prepares the tests. One row per device per
test run. Use `pass` / `fail` / `partial` in **Result**; put error text and firmware in **Notes**.

**Test** values (match the 👤 tasks in `TASKS.md`): `survey` (T0.6), `lan-bind` (T1.4),
`scan+toggle` (T2.10), `native-timer` (T3.6), `phone-timer` (T3.4), `voice` (T4.9),
`offline-checklist` (T8.3).

## Pending hardware checks (run in one sitting)

Claude Code keeps this list current; details are in each task's note in `docs/TASKS.md`.
Setup once on the MacBook: `make deps`, then `pip install tinytuya zeroconf` in a venv.

| # | Task | What to do | Needs |
|---|---|---|---|
| 1 | T0.6 | `python spike/survey.py` (then again with `--devices-json devices.json`) → paste summary below | MacBook on home Wi-Fi |
| 2 | T1.4 | Android: WAN unplugged + mobile data on → debug screen reaches `sim/run.py --devices wiz --host 0.0.0.0 --base-port 38899` on the laptop | Android phone, laptop |
| 3 | T1.5 | iPhone: Local Network prompt → granted; deny → guidance card; getPilot to laptop sim | iPhone, laptop |
| 4 | T2.10 | Scan + toggle: WiZ + Wipro/Syska found, Tuya key pasted, each toggles offline | both phones, devices |
| 5 | T3.6 | Wipro/Syska plug: long-press → "On for 1 minute" shows (plug timer); airplane mode; plug turns off by itself | Android or iPhone, plug |
| 6 | T3.4 | Android + WiZ: long-press → "On for 1 minute" shows (phone timer); lock the screen; WiZ turns off after 1 min (allow "Alarms & reminders" if asked) | Android, WiZ |
| 7 | T4.1 | Each phone, Wi-Fi off: mic icon → hold and say "geyser on" → transcript appears; note the locales listed; if "offline speech model missing", download it (steps in TASKS T4.1) | both phones |
| 8 | T4.9 | Real voice: 30 commands per language per phone from `test/voice/corpus/*.yaml` on the mic screen; note each transcript + result; send me the misses to add to the corpus | both phones, devices |
| 9 | T5.9 | Android: star 2 devices on their detail screens; add the "Offline Home" widget; tap a favourite → toggles; tap mic → voice sheet; add the "Voice command" quick-settings tile → opens voice sheet (Android 14+ too) | Android, devices |
| 10 | T6.1 | Run `python -m tinytuya wizard` on the Mac, AirDrop/share devices.json to each phone, Settings → Import Tuya keys → each Wipro/Syska shows "Key works" | Mac, both phones, Tuya devices |
| 11 | T6.3 | Phone with internet: Settings → Import Tuya keys → Import from Tuya cloud → Access ID/Secret from iot.tuya.com, data centre India → keys import and each device shows "Key works" (if the token step fails, tell me the error text) | phone, Tuya IoT project |
| 12 | T7.1 | Any Tuya device whose devices.json / beacon says version 3.4: toggle, state refresh, "On for 1 minute" (plug timer), and one wrong key (edit it on the device page) → "key rejected" | phone, 3.4 device if you have one |
| 13 | T7.2 | A Tuya 3.5 device (newer Tuya/Smart Life plugs): appears in a scan (port-7000 beacon), toggles, state refresh, plug timer | phone, 3.5 device if you have one |
| 14 | T7.3 | Syska/Wipro bulb after devices.json import: brightness + colour-temp sliders work (note which end of the temp slider is warm); a 2/3-gang switch (if any) shows one tile per gang, each toggles its own relay, "On for 1 minute" per gang | phone, Tuya bulb / multi-gang switch |
| 15 | T7.4 | Only if you own a Shelly: scan finds it, toggle, "On for 1 minute" (plug timer), then set a device password in the Shelly app and re-add | phone, Shelly |
| 16 | T7.5 | Only if you own an older Kasa plug (HS1xx/KP1xx): scan finds it, toggle, "On for 1 minute" shows plug timer and it turns off by itself | phone, Kasa plug |
| 17 | T7.6 | Only if you own a Tapo / new Kasa device: scan finds it (UDP 20002), enter the TP-Link account, toggle; bulbs: brightness slider. If the scan misses it, tell me the model | phone, Tapo device |
| 18 | T7.7 | Only if you own a Hue bridge: scan → Needs pairing → press the bridge button → lights appear; toggle, brightness, "On for 1 minute" (bridge timer) | phone, Hue bridge |
| 19 | T7.8 | Only if you own a Yeelight: enable "LAN Control" in the Yeelight app, scan, toggle, brightness, "off in 2 minutes" (bulb timer) | phone, Yeelight |
| 20 | T7.9 | Only if you own a Sonoff: DIY mode (or LAN mode + devicekey), scan finds it (mDNS), toggle, state refresh | phone, Sonoff |
| 21 | T7.10 | Only if you own a Tasmota device: scan, toggle, "on for 1 minute" (plug timer) — then press its button: it must stay on (PulseTime cleared) | phone, Tasmota |
| 22 | T7.11 | Only if you run ESPHome with `web_server:`: scan finds it (mDNS), enter e.g. switch/relay, toggle | phone, ESPHome device |
| 23 | T8.2 | After a day of normal use: Settings → Diagnostics → Performance — note p50 / p95 and cold start for each phone (targets: p95 < 500 ms, cold start < 2 s) | both phones |

## Device survey (T0.6)

Paste the summary printed by `spike/survey.py` here (keys are redacted by the script).

```
(not run yet)
```

## Results

| Date | Device (room) | Brand / model | Protocol + version | IP | Test | Result | Notes |
|---|---|---|---|---|---|---|---|
| | | | | | | | |
