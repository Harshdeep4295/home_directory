# TASKS — Offline Home

Work top to bottom. Pick the first unchecked task whose `deps` are all checked.
Each task: **Do** (scope), **Accept** (definition of done). Pseudocode refs point into
`PSEUDOCODE.md`. Size: S ≈ < 1 session, M ≈ 1–2 sessions, L ≈ split before starting.

Legend: 👤 = needs the human (hardware, phone, account). Claude Code prepares everything and
writes clear instructions, then stops.

---

## M0 — Scaffold

- [x] **T0.1 Repo scaffold** (S) — deps: none
  Do: create layout from CLAUDE.md; `flutter create app --org dev.offlinehome --platforms android,ios`;
  add packages from PLAN §4; `analysis_options.yaml` (strict); `.gitignore` (secrets, devices.json).
  Accept: `flutter analyze` clean, `flutter test` runs a placeholder test.
  Note: Flutter 3.47.5 / Dart 3.13.4. package offline_home, org dev.offlinehome, minSdk 26. sqlite3_flutter_libs is EOL → using sqlite3 3.x (bundled via build hooks). vosk_flutter deferred to T4.1. Root .gitignore anchored /lib/ so app/lib is tracked; secrets (devices.json etc.) ignored. iOS deployment target 16 set in T1.5.
- [x] **T0.2 Simulator harness** (S) — deps: T0.1
  Do: `sim/` Python package, `sim/run.py --devices wiz,tuya33,...` starts N fake devices on
  127.0.0.1 with configurable ports; pytest config. Ref: §Simulators.
  Accept: `pytest sim` green; `python sim/run.py --devices wiz` answers a UDP getPilot.
  Note: ohsim package (UdpSimDevice/TcpSimDevice bases, registry, spec parser); run.py prints port map, exits on SIGTERM or stdin EOF; minimal WiZ sim (getPilot/setPilot) — rest of WiZ in T2.2. 9 pytest tests incl. run.py subprocess test.
- [x] **T0.3 Dev scripts** (S) — deps: T0.1
  Do: `Makefile` targets: `fmt`, `analyze`, `test`, `sim`, `run-android`, `run-ios`, `codegen`.
  Accept: `make test` runs analyze + flutter test + pytest.
  Note: Makefile: help, deps, fmt, fmt-check, analyze, codegen, flutter-test, sim-test, test, sim, run-android, run-ios, clean. make test = analyze + flutter test + pytest sim.
- [x] **T0.4 HARDWARE_LOG template** (S) — deps: none
  Do: `docs/HARDWARE_LOG.md` table: date, device, brand, model, protocol, IP, test, result, notes.
  Note: Table existed; added test-name vocabulary, result conventions and a survey section for T0.6 output.
- [x] **T0.5 CI** (S) — deps: T0.2, T0.3
  Do: `.github/workflows/ci.yml` on push + PR: Flutter (format check, analyze, test) and
  Python (pytest sim) jobs; pinned Flutter version.
  Accept: workflow green on the M0 PR.
  Note: GitHub Actions: flutter job (pinned 3.47.5; fmt-check, analyze, test) + sim job (Python 3.11, pytest). Verified on the M0 PR.
- [x] **T0.6 Device survey spike** (S) — deps: T0.2
  Do: `spike/survey.py` (Python, run by the human on the MacBook on home Wi-Fi): listens for
  Tuya beacons (tinytuya), probes WiZ on UDP 38899, Kasa on 9999, TCP-scans the /24 for the
  ports in PLAN §5, and — if `devices.json` is present — queries each Tuya device's DPs. Writes
  `spike/survey-<date>.json` (gitignored; keys redacted) + a readable summary.
  Accept: runs against `sim/run.py` locally; 👤 human runs it at home and pastes the summary
  into `docs/HARDWARE_LOG.md` (answers: which protocols, Tuya versions, DP maps).
  Note: spike/survey.py + README (tinytuya wizard steps). Unicast WiZ/Kasa UDP + TCP port scan + HTTP (Shelly/Tasmota/Hue) + optional tinytuya beacons/zeroconf mDNS; --devices-json dumps Tuya version, device22 flag and named DPs; keys never output (checked). Tested vs WiZ sim in sim/tests/test_survey_spike.py.
  - [ ] 👤 Run `spike/survey.py` at home (with `--devices-json` once you have it) and paste the summary into HARDWARE_LOG.

## M1 — Core, network, registry

- [x] **T1.1 Core models** (S) — deps: T0.1 — Ref: §Core models
  Do: freezed models Device, DeviceState, Capability, Room, Alias, TimerJob, Intent,
  Candidate, `Result<T,E>`, `DeviceError`.
  Accept: JSON round-trip tests for every model.
  Note: lib/core: result.dart (sealed Result<T> Ok/Err + freezed DeviceError), models.dart (Device, DeviceState, Room, Alias, TimerJob w/ meta, Candidate + enums), intent.dart (Intent union keyed by 'type', TargetSpan, ClockTime). Durations as seconds, DateTimes UTC ISO. Generated code committed; CI step make codegen-check. 19 tests.
- [ ] **T1.2 Logger + redaction** (S) — deps: T1.1
  Accept: test proves values registered in SecretStore never appear in log output.
- [ ] **T1.3 LanSocketFactory (Dart side)** (M) — deps: T1.1 — Ref: §LanSocketFactory
  Do: tcp(), udp(), udpBroadcast(), http() with timeouts; delegates Android binding to plugin.
  Accept: unit tests with local echo servers; timeouts return `DeviceError.timeout`.
- [ ] **T1.4 Android LanBindingPlugin (Kotlin)** (M) — deps: T1.3 — Ref: §Android plugin
  Do: request Wi-Fi network without INTERNET capability requirement, `bindProcessToNetwork`,
  expose `isWifiConnected`, `hasInternet`, `wifiIp`, `subnetPrefix`; MulticastLock acquire/release.
  Accept: 👤 on Wi-Fi with WAN unplugged and mobile data ON, app reaches a sim on the laptop by
  LAN IP (steps written in task note).
- [ ] **T1.5 iOS LocalNetworkPlugin (Swift)** (S) — deps: T1.3 — Ref: §iOS plugin
  Do: trigger local-network permission (NWBrowser on `_http._tcp`), report granted/denied;
  Info.plist keys from PLAN §10.
  Accept: 👤 prompt appears on first launch; denied state shows guidance screen.
- [ ] **T1.6 NetworkMonitor** (S) — deps: T1.4, T1.5
  Do: stream of `NetState{wifi, internet, ssid, ip, prefix}`; UI banner "Local mode" when no internet.
  Accept: unit tests with fake platform channel.
- [ ] **T1.7 Database (drift)** (M) — deps: T1.1 — Ref: §Registry
  Do: tables devices, rooms, aliases, timer_jobs, settings, device_state_cache; migrations v1.
  Accept: repository CRUD tests; migration test.
- [ ] **T1.8 SecretStore** (S) — deps: T1.1
  Do: wrapper over flutter_secure_storage; keys `secret/<deviceId>/<name>`; in-memory fake for tests.
  Accept: tests; no secret columns in SQLite (schema test).

## M2 — Adapter framework, first adapters, discovery

- [ ] **T2.1 DeviceAdapter interface + AdapterRegistry** (S) — deps: T1.1, T1.3 — Ref: §Adapter interface
  Accept: a `FakeAdapter` passes a shared `adapterContractTest()` suite (reusable by all adapters).
- [ ] **T2.2 WiZ simulator** (S) — deps: T0.2
- [ ] **T2.3 WiZ adapter** (M) — deps: T2.1, T2.2 — Ref: §WiZ
  Accept: contract suite green vs sim; power, brightness, colorTemp; probe() identifies WiZ.
- [ ] **T2.4 Tuya codec 3.1/3.3** (M) — deps: T2.1 — Ref: §Tuya codec
  Do: frame encode/decode, CRC32, AES-ECB, version header rules, sequence numbers.
  Accept: byte-exact tests with vectors ported from tinytuya tests (cite file).
- [ ] **T2.5 Tuya simulator 3.3** (M) — deps: T0.2, T2.4
  Do: plug with DPs {1: switch, 9: countdown} (configurable DP map), UDP beacon broadcaster.
- [ ] **T2.6 Tuya adapter 3.1/3.3** (M) — deps: T2.4, T2.5 — Ref: §Tuya adapter
  Do: persistent TCP connection per device, heartbeat, status, set DP, countdown DP, DP-map
  profiles (plug, bulb, multi-gang switch) with per-device override.
  Also: "device22" mode (22-char ids query via CONTROL_NEW with explicit DP list) — see
  PSEUDOCODE §6.3; sim must support it as an option.
  Accept: contract suite green vs sim (normal + device22); reconnect after sim restart.
- [ ] **T2.7 Candidate collectors** (M) — deps: T1.3, T1.4 — Ref: §Discovery
  Do: mDNS (bonsoir), UDP listeners (6666/6667), broadcast probes (38899, 9999, 20002, 1982),
  unicast fallback for iOS, TCP port scan /24 (concurrency 64, 300 ms).
  Accept: with sims running, collector returns expected candidates; iOS path unit-tested with
  broadcast disabled flag.
- [ ] **T2.8 Fingerprinter** (M) — deps: T2.7 — Ref: §Fingerprinter
  Accept: table-driven tests using recorded replies for every brand in PLAN §6 (use sim replies
  where no real recording exists; mark them).
- [ ] **T2.9 Discovery service + merge** (S) — deps: T2.8, T1.7
  Do: merge candidates with registry by deviceId → mac → ip; mark moved IPs (DHCP change).
  Accept: test: device changes IP, registry updates, user settings preserved.
- [ ] **T2.10 👤 Hardware check #1** (S) — deps: T2.3, T2.6, T2.9
  Do: debug screen "Scan + toggle"; human tests WiZ + Wipro with WAN unplugged; logs results.

## M3 — Engine, state, timers

- [ ] **T3.1 CommandEngine** (M) — deps: T2.1, T1.7 — Ref: §CommandEngine
  Do: per-device serial queue, parallel across devices, retry (2x, backoff 150/400 ms),
  optimistic state + confirm read-back, result aggregation for multi-target commands.
  Accept: tests with FakeAdapter incl. partial failures.
- [ ] **T3.2 StatePoller** (S) — deps: T3.1 — Ref: §StatePoller
  Do: push where adapter supports it, else poll every 5 s while app foreground, 0 when background;
  cache to device_state_cache.
- [ ] **T3.3 TimerService core** (M) — deps: T3.1 — Ref: §TimerService
  Do: tier selection, powerFor/powerAfter/powerAt semantics, persistence, cancel, reconcile.
  Accept: matrix tests with fake clock and fake adapters (native / no-native / max exceeded).
- [ ] **T3.4 Android phone-tier timers (Kotlin)** (L → split) — deps: T3.3, T1.4
  - [ ] **T3.4a Alarm scheduling channel** (S): MethodChannel `scheduleExactAlarm(jobId, fireAtMs)`,
    `cancelAlarm(jobId)`, `canScheduleExactAlarms()`; AlarmManager `setExactAndAllowWhileIdle`;
    Dart side behind `PhoneAlarmScheduler` interface with a fake for tests.
  - [ ] **T3.4b Background Dart entrypoint** (M): `@pragma('vm:entry-point') timerCallback(jobId)`
    that opens the DB, builds adapters + CommandEngine without Flutter UI, runs `onAlarm(jobId)`.
    Accept: Dart unit test runs the entrypoint against a fake adapter.
  - [ ] **T3.4c AlarmReceiver + TimerForegroundService** (M): receiver starts the FGS, FGS starts a
    headless `FlutterEngine` on the entrypoint, passes jobId, stops itself when done (timeout 30 s);
    binds to Wi-Fi via LanBindingPlugin before running.
  - [ ] **T3.4d Boot + re-arm** (S): `RECEIVE_BOOT_COMPLETED` receiver asks Dart for active phone
    jobs and re-arms them; exact-alarm permission prompt on Android 12+.
  Accept: 👤 1-minute WiZ timer fires with screen off (WiZ has no native countdown).
- [ ] **T3.5 iOS phone-tier behaviour** (S) — deps: T3.3
  Do: warning copy, foreground ticker, local notification at fire time.
- [ ] **T3.6 👤 Hardware check #2** (S) — deps: T3.3, T2.6
  Accept: "Wipro plug on for 1 minute" turns off with phone in airplane mode.

## M4 — Voice

- [ ] **T4.1 SttService** (M) — deps: T0.1 — Ref: §SttService
  Do: speech_to_text on-device mode, contextual strings, partial results, 1.2 s silence stop;
  capability check (on-device available? locales?); Vosk fallback on Android behind interface.
  Accept: 👤 prints transcripts offline on both phones; task note lists available locales.
- [ ] **T4.2 Normaliser** (S) — deps: T1.1 — Ref: §Normaliser
  Do: lowercase, punctuation, Devanagari→Latin map, filler removal, spelling variants
  (bandh→band, chaalu→chalu), number words EN + HI (ek..sau, one..hundred, "dedh", "dhai", "sava", "paune").
- [ ] **T4.3 Lexicons** (S) — deps: T4.2 — Ref: §Lexicon
  Do: `assets/voice/lexicon_en.yaml`, `lexicon_hi.yaml`: actions, time words, room/device nouns.
- [ ] **T4.4 Duration + time parser** (M) — deps: T4.2 — Ref: §Time parsing
  Accept: tests: "20 minutes", "adha ghanta", "dedh ghante", "for 1 hour 15", "11 pm", "raat 11 baje",
  "subah 6 baje", "11:30", "in 5 min", "5 minute baad".
- [ ] **T4.5 IntentParser** (M) — deps: T4.3, T4.4 — Ref: §IntentParser
- [ ] **T4.6 TargetResolver** (M) — deps: T1.7, T4.5 — Ref: §TargetResolver
  Do: Jaro-Winkler + Double Metaphone, aliases, rooms, "all", "except", Hinglish plurals ("lights", "batiyan").
- [ ] **T4.7 Golden corpus** (M) — deps: T4.5, T4.6
  Do: ≥ 150 cases in `test/voice/corpus/*.yaml` (EN 60%, Hinglish 40%, incl. STT-style misspellings).
  Accept: ≥ 95% pass; failures listed in task note.
- [ ] **T4.8 VoiceController + feedback** (S) — deps: T4.1, T4.6, T3.1, T3.3
  Do: orchestration, confirmation rules (PLAN §7), TTS + toast, undo for 5 s.
- [ ] **T4.9 👤 Real-voice test** (S) — deps: T4.8
  Do: 30 spoken commands per language on each phone, results logged.

## M5 — UI and onboarding

- [ ] **T5.1 App shell + theme + navigation** (S) — deps: T0.1
- [ ] **T5.2 Home screen** (M) — deps: T5.1, T3.2
  Do: rooms → device tiles (state, tap toggle, long-press detail), "Local mode" banner, mic FAB.
- [ ] **T5.3 Device detail** (M) — deps: T5.2, T3.3
  Do: power, sliders by capability, timer presets (15/30/60/custom), default auto-off, name, room,
  aliases, protocol info, "re-scan IP".
- [ ] **T5.4 Timers screen** (S) — deps: T3.3
  Do: list with remaining time, tier badge (Plug / Phone), cancel, reconcile on open.
- [ ] **T5.5 Voice sheet** (S) — deps: T4.8
  Do: listening animation, live transcript, disambiguation chips, result.
- [ ] **T5.6 Add-devices flow** (M) — deps: T2.9 — Ref: §Onboarding
  Do: scan, badges, per-badge resolve screens, naming + rooms + alias suggestions.
- [ ] **T5.7 Settings** (S) — deps: T5.1
  Do: language, TTS on/off, poll interval, export/import config (encrypted JSON with passphrase,
  secrets included only if user opts in), diagnostics (logs, network state).
- [ ] **T5.8 Permissions + first-run** (S) — deps: T1.5, T4.1
  Do: permission walkthrough, offline speech model download instructions per platform.
- [ ] **T5.9 Android widget + quick-settings tile** (M) — deps: T4.8
  Do: widget with mic button + 4 favourite devices; tile opens voice sheet directly.
- [ ] **T5.10 iOS widget / Shortcuts** (S) — deps: T4.8 — optional, can defer.

## M6 — Key import (onboarding/cloud_import — the only internet code)

- [ ] **T6.1 tinytuya devices.json import** (S) — deps: T5.6, T1.8 — Ref: §Key import
  Accept: sample file imports; keys land in SecretStore; devices matched by id.
- [ ] **T6.2 Manual key entry** (S) — deps: T6.1
- [ ] **T6.3 Tuya OpenAPI in-app import** (M) — deps: T6.1 — Ref: §Tuya cloud import
  Do: user enters access id/secret + region; signed requests; fetch device list with local_key.
  Accept: unit tests with recorded (sanitised) responses; VERIFY signing against Tuya docs.
- [ ] **T6.4 Guide screen: re-pair Tuya device to own account** (S) — deps: T6.1
  Do: step-by-step copy: reset device, add in Smart Life, link to Tuya IoT project, run wizard,
  re-link in Alexa.

## M7 — Remaining adapters (each: simulator → adapter → contract suite → probe rule)

- [ ] **T7.1 Tuya 3.4** (M) — deps: T2.6 — Ref: §Tuya 3.4
- [ ] **T7.2 Tuya 3.5** (M) — deps: T7.1 — Ref: §Tuya 3.5
- [ ] **T7.3 Tuya bulb + multi-gang profiles** (S) — deps: T2.6
- [ ] **T7.4 Shelly Gen1 + Gen2** (M) — deps: T2.1 — Ref: §Shelly
- [ ] **T7.5 Kasa legacy** (M) — deps: T2.1 — Ref: §Kasa legacy
- [ ] **T7.6 KLAP transport + Tapo/Kasa new** (L → split) — deps: T7.5 — Ref: §KLAP
- [ ] **T7.7 Hue bridge + link-button pairing** (M) — deps: T2.1 — Ref: §Hue
- [ ] **T7.8 Yeelight** (S) — deps: T2.1 — Ref: §Yeelight
- [ ] **T7.9 Sonoff LAN (DIY + encrypted)** (M) — deps: T2.1 — Ref: §Sonoff
- [ ] **T7.10 Tasmota** (S) — deps: T2.1 — Ref: §Tasmota
- [ ] **T7.11 ESPHome (web server REST)** (S) — deps: T2.1 — Ref: §ESPHome
- [ ] **T7.12 Fingerprinter rules for all of the above** (S) — deps: T7.1–T7.11

## M8 — Hardening and release to own phones

- [ ] **T8.1 Error UX** (S) — deps: T5.*
  Do: per-device offline state, "device moved IP" auto-rescan, key-rejected → re-import prompt.
- [ ] **T8.2 Performance** (S) — Accept: tap→device p95 < 500 ms on LAN, list render < 2 s cold start (measure, log).
- [ ] **T8.3 👤 Offline validation checklist** (S)
  With WAN cable unplugged and mobile data ON, on Android and iPhone:
  - [ ] cold start shows all devices with state
  - [ ] tap on/off each brand
  - [ ] voice EN: "turn off all lights except bedroom"
  - [ ] voice Hinglish: "geyser 20 minute ke liye chalu karo"
  - [ ] timer on Tuya plug fires with phone away/airplane mode
  - [ ] timer on WiZ fires (Android phone tier) with screen off
  - [ ] device IP change (reboot router) → recovered within one scan
  - [ ] no request leaves the LAN (check router logs or Android `PCAPdroid`)
- [ ] **T8.4 README + LICENSE + disclaimer** (S) — MIT (LICENSE + README disclaimer added in M0; T8.4 finishes install docs), "not affiliated", build + install steps for both phones.
- [ ] **T8.5 Build scripts** (S) — `make apk`, `make ios-device` with notes on 7-day free signing.

## Later (not v1)

- [ ] L1 Smart TVs: Fire TV (ADB), Android TV Remote v2, Samsung, LG
- [ ] L2 Matter commissioning + control (native plugins)
- [ ] L3 Optional hub mode on an old Android phone
- [ ] L4 Wake word
- [ ] L5 Scenes ("good night")
