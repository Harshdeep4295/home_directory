# Handoff — Offline Home (state as of 2026-10-25, M10 + tablet)

Read `CLAUDE.md` first (rules are non-negotiable), then this file, then `docs/TASKS.md`.
This note says where the work stands, how to run things, and what is left.

## 1. Where things are

| Milestone | State |
|---|---|
| M0–M9 | **Merged into `main`** (PRs #6–#10). |
| M10 Places, sharing, choose-what-to-share | **Merged** (PRs #12, #13). T10.1–T10.4, T10.6 done; T10.5 = owner's hardware checks. |
| Fixes after M10 | **Merged**: Tuya idle hang-up + "busy" instead of "key rejected" (PR #14), TV backlight on DP 102 (PR #14), Android 7.1 / minSdk 25 (PR #15). |
| T10.7 Wall tablet voice (Vosk) | This branch / latest PR. |

- The owner uses the app daily on Android: main phone (release APK from CI), a spare OnePlus and a wall tablet
  (Samsung SM-T561, LineageOS 7.1, armeabi-v7a, 1.4 GB RAM). All devices are under the place "Guglanas Home".
- **Owner rules**: never reset or change any device's password or settings; never ask the owner for vendor
  account credentials; no cloud import for now. Tuya keys came from a `devices.json` (kept outside the repo).
- Tuya devices allow **one local client**. Two phones open on the app take turns: the adapter now hangs up after
  2 s idle and reports "busy/offline" (not "key rejected") when another client holds the socket. Auth error only
  after 3 hang-ups in a row on a key that never worked.
- Tablet: no Google speech service → voice falls back to the bundled **Vosk** engine (`VoskPlugin.kt`,
  `FallbackSpeechEngine`). Its camera preview stays black in the QR scanner (CameraX on the Spreadtrum HAL), so
  set it up with a `devices.json` import or the backup file instead of the QR share.
- Panasonic AC is cloud-only (Espressif, no open LAN ports) — out of scope. Motor/Fan are flaky on Wi-Fi.
- Pending owner checks: `docs/HARDWARE_LOG.md` → *Pending hardware checks* (#29 share QR, #30 tablet voice,
  #31 two-phone Tuya).

### Test APK pipeline (how the owner gets builds)

- `.github/workflows/apk.yml` builds on every push to `claude/sweet-thompson-fba2km` (or workflow_dispatch) and
  publishes to the **`apk-latest` pre-release**:
  https://github.com/Harshdeep4295/home_directory/releases/download/apk-latest/offline-home.apk
- `make apk` fetches the Vosk model first (`tools/fetch_vosk_model.sh`, sha256-pinned, into the gitignored
  `app/android/app/src/main/assets/vosk-en-in/`) and builds ARM-only (`android-arm`, `android-arm64`), ~135 MB.
- Release builds are signed with the debug key; CI's key differs from the Mac's, so switching a phone between a
  CI APK and a locally built one needs an uninstall (export a backup first). Same source → `adb install -r` works.
- Local install from the Mac: `cd app && flutter build apk --release --target-platform android-arm,android-arm64`
  then `adb -s <serial> install -r build/app/outputs/flutter-apk/app-release.apk`.

## 2. Workflow the owner agreed to

- One commit per task, message `T<id>: <title>`; tick the task in `docs/TASKS.md` with a one-line note (what was done + open VERIFYs).
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No model IDs elsewhere in commits/PRs.
  PR bodies end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- **One PR per milestone** into `main`, created from the latest `main` after the previous milestone merged. The owner authorised **the agent to merge a milestone PR itself once CI (`flutter` + `sim` + `apk` jobs) is green** (merge method `merge`, pass the full head SHA). After merging: `git fetch origin main && git checkout -B claude/sweet-thompson-fba2km origin/main` and start the next milestone.
- The owner is **not near the devices**: implement everything, skip 👤 hardware steps, and add each real-device check to the **"Pending hardware checks"** table in `docs/HARDWARE_LOG.md` . They will run them in one go later.
- Only ping the owner (push notification) when their input is genuinely needed.

## 3. Environment — how to run things

- **Owner's Mac (current)**: Flutter on PATH, Android SDK + adb present; the shell is zsh (unquoted vars don't
  word-split). Push with the gh credential helper (SSH maps to another GitHub account):
  `git -c credential.helper= -c credential.helper='!gh auth git-credential' push https://github.com/Harshdeep4295/home_directory.git claude/sweet-thompson-fba2km`.
  Never commit `app/ios/Flutter/*.xcconfig` or `app/ios/Podfile` (local CocoaPods edits).
- Cloud container (older sessions):

- Flutter: `export PATH=/opt/flutter/bin:$PATH` (Flutter 3.47.5 / Dart 3.13.4; runs as root, ignore the warning).
- Python for simulators: a venv from `sim/requirements-dev.txt`. Venvs do not survive into a new container, so recreate it:
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

- Tablet: install the T10.7 build, run check #30; the main phone still runs an APK from before PR #14 → update it.
- Ideas: reverse QR (camera-less device shows a QR, phone scans it), Hindi Vosk model, permission page does not
  refresh after the mic grant on Android 7, Fan/Motor flakiness, the unknown Tuya 3.4 at .15 and a new 3.5 device
  without a key.
- Spare phone has `stay_on_while_plugged_in=3` (restore to 0 when done); the tablet keeps it for wall use.

All planned milestones (M0–M10) are implemented. Next work comes from the owner's hardware runs:
- Work through `docs/HARDWARE_LOG.md` → *Pending hardware checks* as the owner reports results. Fix each
  real-device difference, add a regression test (sim or vector), and resolve the matching `VERIFY` note.
- **Cameras (M9)**:
  - Code lives in `app/lib/cameras/`: `Camera` stored as JSON in the settings table, `CameraService`, and
    `RtspClient` (DESCRIBE with digest auth from `lib/net/digest_auth.dart`, to find the main/sub stream paths).
  - Video uses `CameraPlayer`, a seam implemented by `MediaKitCameraPlayer`: libmpv, muted, protocol whitelist
    rtsp/rtp/udp/tcp only.
  - UI: `ui/screens/camera_view_screen.dart`, `ui/widgets/camera_tile.dart` (Home "Cameras" row).
  - Discovery: `discovery/camera_probes.dart` (ONVIF WS-Discovery 3702, Hikvision SADP 37020, RTSP OPTIONS on 554)
    and `discovery/categorizer.dart` (DeviceCategory per host). Simulators: `onvif`, `sadp`, `rtsp` in
    `sim/ohsim/devices/camera.py`.
  - Cameras are **not** DeviceAdapters (they have no power control) and stay out of voice and timers.
- Known gaps:
  - TP-Link AES/HTTPS devices show "Not supported yet".
  - Sonoff on eWeLink firmware may need mDNS TXT parsing.
  - ESPHome has no entity listing yet.
  - No iOS widget yet (T5.10).
  - media_kit has never been built for iOS.
  - Later list L1–L5 (Fire TV / TV control is L1).
- Builds: Android is built in CI and on the Mac (see §1). iOS has never been built; that needs the owner's Mac (`make ios-device`).

## 6. Open VERIFY items (need real hardware or official docs)

`grep -rn VERIFY app/lib` lists them in code. Main ones:
- Tuya: countdown flip semantics + max duration; 3.4/3.5 STATUS push shape; behaviour on a wrong key during 3.4/3.5 negotiation (hang-up → busy/offline; auth after 3 hang-ups on a key that never worked, or an HMAC failure); beacons on iOS.
- Tuya cloud import: token call without tinytuya's `secret` header; auth error codes 1004/1010/1011.
- WiZ reply port on broadcast; KLAP static discovery query answered by devices.
- Android foreground-service type on 14/15; STT error strings; home-screen widget + quick-settings tile never run on a device.
- Cameras (M9):
  - SADP reply format and port on EZVIZ firmware.
  - EZVIZ RTSP paths (tried in order: `/Streaming/Channels/101|102`, `/h264/ch1/main|sub/av_stream`, `/H.264`).
  - Video encryption must be off.
  - Hikvision `Server` header strings.
  - Router guess: a `.1`/`.254` host with a web page is labelled Network.
  - Scan time with 16 mDNS types on Android 10–13.
  - Live-view latency.

## 7. Gotchas learned

- Riverpod 3: use `.value` (no `valueOrNull`); `Override` type comes from `package:flutter_riverpod/misc.dart`.
- drift in widget tests: create services via `TestServices.inTester` (real async) and always `await t.tearDown(tester)`; FK constraints are on (seed rooms/devices before referencing them).
- Lazily built lists in widget tests: `scrollUntilVisible(..., scrollable: find.byType(Scrollable).first)`.
- `flutter analyze` needs `--fatal-infos` to fail on infos (Makefile already does this).
- Merging a PR via the GitHub tool: pass the full 40-char head SHA from `git rev-parse HEAD`.
- media_kit in widget tests: use the `cameraPlayerFactoryProvider` override with a fake player. `grabFrame`
  waits on fake time, so call `tester.pump(Duration)`. `Image.memory` needs real image bytes, e.g. a 1×1 PNG.
- Reference clients for the camera sims are pinned in `sim/requirements-dev.txt` (WSDiscovery 2.1.2, hiktools 1.2.2).
