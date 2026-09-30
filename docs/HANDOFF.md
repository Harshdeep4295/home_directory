# Handoff — Offline Home (state as of 2026-09-30, end of M8)

Read `CLAUDE.md` first (rules are non-negotiable), then this file, then `docs/TASKS.md`.
This note says where the work stands, how to run things, and what is left.

## 1. Where things are

| Milestone | State |
|---|---|
| M0–M7 | **Merged into `main`** (M5 = PR #6 App UI, M6 = PR #7 Key import, M7 = PR #8 Remaining adapters). |
| M8 Hardening | T8.1 error UX, T8.2 performance, T8.4 README, T8.5 build scripts done on `claude/sweet-thompson-fba2km` → **M8 PR**. T8.3 is the owner's offline checklist (hardware check #24). |

- v1 is feature-complete. What remains is **real-hardware validation** by the owner: every row of
  "Pending hardware checks" in `docs/HARDWARE_LOG.md` (#1–#25), plus the open `VERIFY` notes per task in
  `docs/TASKS.md`. Fix whatever those checks report.
- Deferred / optional: T4.9 real-voice test (hardware), T5.10 iOS widget, Later list L1–L5.
- Latest full local run: 513 Flutter tests + 49 simulator tests green.

## 2. Workflow the owner agreed to

- One commit per task, message `T<id>: <title>`; tick the task in `docs/TASKS.md` with a one-line note (what was done + open VERIFYs).
- Commit trailers (required on every commit):
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: <link of the session making the commit>
  ```
  No model IDs in commits/PRs. PR bodies end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)` + session link.
- **One PR per milestone** into `main`, created from the latest `main` after the previous milestone merged. The owner authorised **the agent to merge a milestone PR itself once CI (`flutter` + `sim` jobs) is green** (merge method `merge`, pass the full head SHA). After merging: `git fetch origin main && git checkout -B claude/sweet-thompson-fba2km origin/main` and start the next milestone.
- The owner is **not near the devices**: implement everything, skip 👤 hardware steps, and add each real-device check to the **"Pending hardware checks"** table in `docs/HARDWARE_LOG.md` (rows 1–25 so far). They will run them in one go later.
- Only ping the owner (push notification) when their input is genuinely needed.

## 3. Environment (cloud container) — how to run things

- Flutter: `export PATH=/opt/flutter/bin:$PATH` (Flutter 3.47.5 / Dart 3.13.4; runs as root, ignore the warning).
- Python for simulators: a venv with `pytest pytest-asyncio tinytuya==1.20.0` (`sim/requirements-dev.txt`). The previous session's venv lived in its scratchpad and is **gone** in a new container — recreate:
  ```
  python3 -m venv /tmp/venv && /tmp/venv/bin/pip install -r sim/requirements-dev.txt
  # requirements-dev now also pins aioshelly, python-kasa and tzdata (reference clients)
  ```
- Full check (same as CI): `make fmt-check codegen-check test PYTHON=/tmp/venv/bin/python`
  - `codegen-check` fails if anything under `app/lib`/`app/test` is **uncommitted** (it uses `git status`), so run it after committing.
  - Simulator-backed Dart tests (`app/test/sim`, tag `sim`) need `OH_PYTHON=/tmp/venv/bin/python` when run directly with `flutter test`.
- Kotlin was only type-checked (kotlinc + android-all API 35 + Flutter embedding jar, script lived in the old scratchpad); Swift was never compiled. Neither is built in CI.
- Byte-exact protocol vectors are generated from the reference libraries: `python sim/tools/gen_tuya_vectors.py` (3.x/3.4/3.5), `gen_tuya_cloud_vectors.py` (OpenAPI signing), `gen_shelly_vectors.py` (Gen2 digest), `gen_klap_vectors.py` (KLAP v1/v2). Re-running must leave existing vector files unchanged.
- `.gitignore` ignores any file named `devices.json` (real keys). Test fixtures must use another name (`test/onboarding/fixtures/sample_devices.json`) — this bit CI once.

## 4. Architecture cheat-sheet (what exists)

- `app/lib/adapters/` — `DeviceAdapter` interface (`guarded()`, countdown API, `powerFor`), `AdapterRegistry`, `FakeAdapter`, `wiz/`, `tuya/` (codec: 3.1/3.3 `TuyaCodec3x`, 3.4 `TuyaCodec34` HMAC+ECB, 3.5 `TuyaCodec35` 6699 AES-GCM; `TuyaSessionCodec` negotiation; adapter matches 3.5 replies by command), `kasa/kasa_xor.dart` (discovery only so far).
- `discovery/` CandidateCollector (UDP probes, Tuya beacons 6666/6667/7000 + REQ_DEVINFO broadcast, TCP port scan, HTTP, mDNS) → `Fingerprinter` → `DiscoveryService` (merge by id → MAC → IP).
- `engine/` CommandEngine (serial per device, retries, optimistic state) + StatePoller. `timers/` TimerService (native tier first, phone tier fallback; Android exact alarms + headless engine, iOS notification + ticker). `voice/` offline STT → normaliser → lexicon → time/intent parser → fuzzy target resolver.
- `onboarding/` badges, permissions, `devices_json_import.dart`, `manual_key.dart`, `cloud_import/tuya_cloud.dart` (**the only internet code**; a guard test fails if any other `lib/` file uses HTTPS/`package:http`/imports `cloud_import`).
- `ui/` Riverpod providers, Shell (Home/Timers/Settings), device detail, voice sheet, add devices, key import screens, Tuya guide, home-screen widget sync (`home_widget_sync.dart`).
- `sim/ohsim/devices/`: `WizSim`, `TuyaSim` (versions 3.1/3.3/3.4/3.5, profiles plug|bulb, device22, beacons). Sim behaviour is checked against the reference client (tinytuya) in `sim/tests`.
- Every adapter must pass `adapterContractTest()` (`app/test/support/adapter_contract.dart`) against its simulator.

## 5. What is left

All planned milestones are implemented (adapters in `app/lib/adapters/{tuya,wiz,shelly,kasa,hue,yeelight,sonoff,tasmota,esphome}`,
sims in `sim/ohsim/devices/`, each sim checked in `sim/tests` against the reference client).
Next work comes from the owner's hardware runs:
- Work through `docs/HARDWARE_LOG.md` → *Pending hardware checks* results as the owner reports them; fix and add a
  regression test (sim or vector) for every real-device difference, then resolve the matching `VERIFY` note.
- Known gaps: TP-Link AES / HTTPS devices (Tapo cameras, hubs) show "Not supported yet"; Sonoff state on eWeLink
  firmware may need mDNS TXT parsing; ESPHome entity listing; iOS widget (T5.10); Later list L1–L5.
- Builds were never run in the cloud container (no Android SDK / Xcode): first real build is hardware check #25.

## 6. Open VERIFY items (need real hardware or official docs)

`grep -rn VERIFY app/lib` lists them in code. Main ones:
- Tuya: countdown flip semantics + max duration; 3.4/3.5 STATUS push shape; behaviour on a wrong key during 3.4/3.5 negotiation (we map "connection closed during handshake" → auth); beacons on iOS.
- Tuya cloud import: token call without tinytuya's `secret` header; auth error codes 1004/1010/1011.
- WiZ reply port on broadcast; KLAP static discovery query answered by devices.
- Android foreground-service type on 14/15; STT error strings; home-screen widget + quick-settings tile never run on a device.

## 7. Gotchas learned

- Riverpod 3: use `.value` (no `valueOrNull`); `Override` type comes from `package:flutter_riverpod/misc.dart`.
- drift in widget tests: create services via `TestServices.inTester` (real async) and always `await t.tearDown(tester)`; FK constraints are on (seed rooms/devices before referencing them).
- Lazily built lists in widget tests: `scrollUntilVisible(..., scrollable: find.byType(Scrollable).first)`.
- `flutter analyze` needs `--fatal-infos` to fail on infos (Makefile already does this).
- Merging a PR via the GitHub tool: pass the full 40-char head SHA from `git rev-parse HEAD`.
