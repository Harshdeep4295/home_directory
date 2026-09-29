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

## Device survey (T0.6)

Paste the summary printed by `spike/survey.py` here (keys are redacted by the script).

```
(not run yet)
```

## Results

| Date | Device (room) | Brand / model | Protocol + version | IP | Test | Result | Notes |
|---|---|---|---|---|---|---|---|
| | | | | | | | |
