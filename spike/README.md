# spike — scripts for exploring real devices (human-run)

## survey.py — what is on my network? (T0.6)

On the MacBook, connected to the home Wi-Fi:

```sh
python3 -m venv .venv && . .venv/bin/activate
pip install tinytuya zeroconf
python spike/survey.py
```

It scans your /24, listens for Tuya beacons and mDNS, and prints one line per device with the
protocol it speaks. Paste that output into `docs/HARDWARE_LOG.md` → "Device survey".

### Getting Tuya data points (Wipro / Syska)

Tuya devices need their `local_key` before we can read their data points. The key comes from
Tuya's cloud, once:

1. Make sure the devices are in **your own** Smart Life (or Tuya Smart) account. If they were
   added via Wipro Next / Syska apps under someone else's account, reset and re-add them in
   Smart Life (you can re-link Smart Life to Alexa afterwards).
2. Create a free project at <https://platform.tuya.com> (Cloud → Development → Create project,
   "Smart Home", pick the data center for India), then Devices → Link App Account → scan the QR
   code with Smart Life.
3. `python -m tinytuya wizard` → enter the project's Access ID/Secret and region. It writes
   `devices.json` (gitignored — never commit it).
4. `python spike/survey.py --devices-json devices.json`

For each Tuya device the summary then shows the working protocol version (3.1/3.3/3.4/3.5),
whether it is a "device22" type, and every DP with its name, e.g.
`dps 1:switch_1=True, 9:countdown_1=0`. Keys are never printed or written to the output file.
