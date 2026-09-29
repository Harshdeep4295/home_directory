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
- [x] **T1.2 Logger + redaction** (S) — deps: T1.1
  Accept: test proves values registered in SecretStore never appear in log output.
  Note: core/log.dart: Logger (d/i/w/e + tag), Redactor (longest-first, min length 4), ConsoleSink, MemorySink ring (500) for diagnostics. Message, error, stack and tag all redacted. End-to-end 'SecretStore value never logged' test lands with T1.8.
- [x] **T1.3 LanSocketFactory (Dart side)** (M) — deps: T1.1 — Ref: §LanSocketFactory
  Do: tcp(), udp(), udpBroadcast(), http() with timeouts; delegates Android binding to plugin.
  Accept: unit tests with local echo servers; timeouts return `DeviceError.timeout`.
  Note: net/: LanSocketFactory (tcp w/ NODELAY, udp bind, udpRequest single/many, broadcast w/ MulticastLock + iOS unsupported, http with DIRECT proxy), errno→DeviceError map (Linux+Darwin), PlatformBridge interface + DefaultPlatformBridge, NetInfo, IPv4 helpers (broadcast addr, host list capped at /22). 15 tests vs local echo/HTTP servers incl. refused and timeouts.
- [x] **T1.4 Android LanBindingPlugin (Kotlin)** (M) — deps: T1.3 — Ref: §Android plugin
  Do: request Wi-Fi network without INTERNET capability requirement, `bindProcessToNetwork`,
  expose `isWifiConnected`, `hasInternet`, `wifiIp`, `subnetPrefix`; MulticastLock acquire/release.
  Accept: 👤 on Wi-Fi with WAN unplugged and mobile data ON, app reaches a sim on the laptop by
  LAN IP (steps written in task note).
  Note: LanBindingPlugin.kt (requestNetwork Wi-Fi w/o INTERNET → bindProcessToNetwork; netInfo ip/prefix/validated/ssid; MulticastLock; event channel), registered in MainActivity; manifest network perms + cleartext; Dart AndroidPlatformBridge + mocked-channel tests; NetDebugScreen as placeholder home. Kotlin typechecked here with kotlinc 2.4.0 vs android-all API 35 + Flutter embedding (no Android SDK in container: dl.google.com blocked) — first real Gradle build happens on the MacBook.
  - [ ] 👤 Hardware check (Android):
    1. Laptop on home Wi-Fi: `python3 sim/run.py --devices wiz --host 0.0.0.0 --base-port 38899`
       (allow incoming connections if macOS asks). Note the laptop IP (`ipconfig getifaddr en0`).
    2. Unplug the router's WAN cable. On the phone: Wi-Fi on (same network), mobile data ON.
       Android will show "connected, no internet" — tap "stay connected" if asked.
    3. `make run-android`. The debug screen should show Wi-Fi connected, Internet "no (local mode)".
    4. Enter the laptop IP, port 38899 → "Send WiZ getPilot" → expect `OK in <N> ms` + JSON.
    5. Log the result (and N) in HARDWARE_LOG with test `lan-bind`. If it fails with
       timeout/offline, note it — that means sockets went over mobile data.
- [x] **T1.5 iOS LocalNetworkPlugin (Swift)** (S) — deps: T1.3 — Ref: §iOS plugin
  Do: trigger local-network permission (NWBrowser on `_http._tcp`), report granted/denied;
  Info.plist keys from PLAN §10.
  Accept: 👤 prompt appears on first launch; denied state shows guidance screen.
  Note: LocalNetworkPlugin in AppDelegate.swift (no pbxproj edits): permission probe = NWListener advertising _offlinehome._tcp + NWBrowser (own service seen → granted; DNS PolicyDenied -65570 → denied, VERIFY); NWPathMonitor(wifi) + getifaddrs(en0) for ip/prefix; events channel. Info.plist: NSLocalNetworkUsageDescription, NSBonjourServices (+_offlinehome._tcp), NSAllowsLocalNetworking; deployment target 16.0. Dart IosPlatformBridge (canBroadcast=false); NetInfo.internet now nullable (iOS can't know without contacting the internet). Debug screen shows permission + denied guidance. Swift NOT compiled here (no toolchain) — first build on the MacBook.
  - [ ] 👤 Hardware check (iPhone): `make run-ios` (Xcode → Signing: pick your Personal Team once).
    1. First launch → system prompt "Offline Home would like to find devices on your local network" → Allow.
       Debug screen shows `Local Network permission: granted`, Wi-Fi connected, your IP/prefix.
    2. Settings → Privacy & Security → Local Network → turn Offline Home off → relaunch app →
       expect `denied` + the guidance card. Turn it back on.
    3. With the WiZ sim running on the laptop (see T1.4), "Send WiZ getPilot" → `OK`.
    Log as test `lan-bind` in HARDWARE_LOG. If the build fails, paste the Xcode error.
- [x] **T1.6 NetworkMonitor** (S) — deps: T1.4, T1.5
  Do: stream of `NetState{wifi, internet, ssid, ip, prefix}`; UI banner "Local mode" when no internet.
  Accept: unit tests with fake platform channel.
  Note: net/network_monitor.dart: NetworkMonitor (seed + platform changes, dedup, wifiChanges ignores internet-only flips), bannerFor → none/localMode/noWifi (iOS unknown internet → no banner); ui/widgets/net_banner.dart shown on debug screen. network_info_plus removed (plugins provide the data). Riverpod provider wiring in T5.1.
- [x] **T1.7 Database (drift)** (M) — deps: T1.1 — Ref: §Registry
  Do: tables devices, rooms, aliases, timer_jobs, settings, device_state_cache; migrations v1.
  Accept: repository CRUD tests; migration test.
  Note: registry/: drift tables (rooms, devices, aliases, timer_jobs+meta_json, device_state_cache, settings; FKs with cascade/set-null, foreign_keys ON, dates as text), AppDatabase.open()/memory(), repositories (Device w/ alias sync, Room, Timer, StateCache, Settings). Schema dump drift_schemas/app/v1 + SchemaVerifier migration test. upsertFromCandidate/merge is T2.9.
- [x] **T1.8 SecretStore** (S) — deps: T1.1
  Do: wrapper over flutter_secure_storage; keys `secret/<deviceId>/<name>`; in-memory fake for tests.
  Accept: tests; no secret columns in SQLite (schema test).
  Note: registry/secret_store.dart: SecretStore over SecretBackend (SecureStorageBackend: Keychain first_unlock_this_device / Keystore; MemorySecretBackend for tests), keys secret/<deviceId>/<name>, SecretName enum; every value read/written registered with the log Redactor, warmUp() at startup. Tests incl. end-to-end 'secret never logged'; no-secret-columns schema test is in repositories_test.dart.

## M2 — Adapter framework, first adapters, discovery

- [x] **T2.1 DeviceAdapter interface + AdapterRegistry** (S) — deps: T1.1, T1.3 — Ref: §Adapter interface
  Accept: a `FakeAdapter` passes a shared `adapterContractTest()` suite (reusable by all adapters).
  Note: adapters/device_adapter.dart: DeviceAdapter (defaults = Err(unsupported); countdown handle, canCountdownTo, combined powerFor, watch, dispose), guarded() wrapper, AdapterRegistry (protocol exact or '<id>-' prefix), ProbeContext. FakeAdapter (flip-based countdown, offline set, failNext) passes shared adapterContractTest (test/support/adapter_contract.dart).
- [x] **T2.2 WiZ simulator** (S) — deps: T0.2
  Note: WizSim: getPilot/setPilot/getSystemConfig/registration + -32601 error, shapes from pywizlight tests/fake_bulb.py 0.6.6; options mac, module (default ESP10_SOCKET_06 plug), fw, drop=N for retry tests; records request methods.
- [x] **T2.3 WiZ adapter** (M) — deps: T2.1, T2.2 — Ref: §WiZ
  Accept: contract suite green vs sim; power, brightness, colorTemp; probe() identifies WiZ.
  Note: adapters/wiz/wiz_adapter.dart (ported from pywizlight 0.6.6: port 38899, registration message, -32601, dimming max(1,…), temp clamp 1000..10000 VERIFY per model, resend after 750 ms, capabilities from moduleName per bulblibrary). Contract suite green vs WizSim + probe/brightness/CT/drop-resend tests in test/sim/ (tag sim, SimProcess helper spawns sim/run.py). No native countdown → phone tier. CI flutter job now installs Python.
- [x] **T2.4 Tuya codec 3.1/3.3** (M) — deps: T2.1 — Ref: §Tuya codec
  Do: frame encode/decode, CRC32, AES-ECB, version header rules, sequence numbers.
  Accept: byte-exact tests with vectors ported from tinytuya tests (cite file).
  Note: adapters/tuya/tuya_codec.dart: 55AA framing (pack/unpack, retcode, CRC32, streaming decoder with resync), AES-ECB/PKCS7 (pointycastle), 3.3 version-header rules, 3.1 base64+md5 signing, payload builders incl. device22, 'data unvalid' detection, UDP beacon decode. Vectors generated by tinytuya 1.20.0 itself (sim/tools/gen_tuya_vectors.py → test/adapters/tuya/vectors_3x.json); all byte-exact. PSEUDOCODE §6.2 corrected (suffix is 0x0000AA55, t is a string).
- [x] **T2.5 Tuya simulator 3.3** (M) — deps: T0.2, T2.4
  Do: plug with DPs {1: switch, 9: countdown} (configurable DP map), UDP beacon broadcaster.
  Note: sim/ohsim/devices/tuya.py: TuyaSim (3.3 + 3.1; DP_QUERY, CONTROL → ACK + STATUS push, HEART_BEAT, countdown DP flips switch, device22 mode answering 'data unvalid' + CONTROL_NEW queries, plug/bulb profiles, optional encrypted UDP beacons). Framing/crypto via tinytuya (now in sim/requirements-dev.txt). Verified with the real tinytuya OutletDevice client in sim/tests/test_tuya.py (7 tests).
- [x] **T2.6 Tuya adapter 3.1/3.3** (M) — deps: T2.4, T2.5 — Ref: §Tuya adapter
  Do: persistent TCP connection per device, heartbeat, status, set DP, countdown DP, DP-map
  profiles (plug, bulb, multi-gang switch) with per-device override.
  Also: "device22" mode (22-char ids query via CONTROL_NEW with explicit DP list) — see
  PSEUDOCODE §6.3; sim must support it as an option.
  Accept: contract suite green vs sim (normal + device22); reconnect after sim restart.
  Note: adapters/tuya/tuya_adapter.dart: persistent TCP session per device (seq-matched replies, STATUS pushes → watch(), heartbeat 10 s, closes on error, lazy reconnect), key from SecretStore (missing → auth), device22 auto-switch on 'data unvalid' (isDevice22() for persisting to meta), 3.1/3.3, plug/bulb DP profiles + detect(), flip-based countdown (canCountdownTo, refuses when already in target state; max 86400 s VERIFY). Contract suite + 8 more sim tests green (normal, device22, 3.1, reconnect after restart, pushes, countdown get/cancel). Brightness/multi-gang in T7.3.
- [x] **T2.7 Candidate collectors** (M) — deps: T1.3, T1.4 — Ref: §Discovery
  Do: mDNS (bonsoir), UDP listeners (6666/6667), broadcast probes (38899, 9999, 20002, 1982),
  unicast fallback for iOS, TCP port scan /24 (concurrency 64, 300 ms).
  Accept: with sims running, collector returns expected candidates; iOS path unit-tested with
  broadcast disabled flag.
  Note: discovery/: HostEvidence/MdnsRecord/UdpProbe/ScanPort, BonsoirMdnsBrowser (bonsoir 7, resolves services → IPv4), CandidateCollector running in parallel: mDNS, Tuya beacon listeners (6666/6667 + MulticastLock), WiZ registration broadcast bound to 38899 (pywizlight), Kasa XOR 9999 + KLAP 20002 static query (python-kasa 0.10.2), Yeelight SSDP (Android only), TCP scan (64 conc., 300 ms), HTTP probes on port-80 hosts; iOS = unicast to every host. adapters/kasa/kasa_xor.dart with python-kasa vectors. All ports overridable; sim test + iOS-path test green. VERIFY on hardware: WiZ reply port, KLAP static query answered, Tuya beacons on iOS.
- [x] **T2.8 Fingerprinter** (M) — deps: T2.7 — Ref: §Fingerprinter
  Accept: table-driven tests using recorded replies for every brand in PLAN §6 (use sim replies
  where no real recording exists; mark them).
  Note: discovery/fingerprinter.dart: pure, first-match rules per §7.2 (Tuya beacon → WiZ → Hue → Shelly gen1/2 → Sonoff → ESPHome → Kasa XOR → KLAP/Tapo → Yeelight SSDP/55443 → Tasmota → Tuya port → unknown), KnownSecrets turns needsKey off. 16 table-driven tests with fixtures from pywizlight/python-kasa/python-yeelight/tinytuya and vendor-doc samples; SIM-marked ones to be replaced by real recordings from HARDWARE_LOG. Collector now also GETs /api/config for Hue.
- [x] **T2.9 Discovery service + merge** (S) — deps: T2.8, T1.7
  Do: merge candidates with registry by deviceId → mac → ip; mark moved IPs (DHCP change).
  Accept: test: device changes IP, registry updates, user settings preserved.
  Note: discovery/discovery_service.dart: scan() = collect → fingerprint (KnownSecrets from SecretStore.deviceIdsWithSecrets) → merge; merge matches deviceId → MAC → IP (IP only for same brand), updates ip/mac/port/lastSeen, keeps known protocol version and all user settings, reports movedFrom; new candidates are reported (add() inserts with '<Brand> <last4>' name + default caps); notSeen list. CandidateCollector implements EvidenceSource. 6 tests incl. the IP-change case.
- [x] **T2.10 👤 Hardware check #1** (S) — deps: T2.3, T2.6, T2.9
  Do: debug screen "Scan + toggle"; human tests WiZ + Wipro with WAN unplugged; logs results.
  Note: Debug 'Scan + toggle' screen (radar icon on the network debug screen): scan → badges (Ready / Needs key / Needs pairing / Unknown) → Add → paste Tuya local key → tap to toggle with timing. AppServices wires db, SecretStore, sockets, WiZ + Tuya adapters, discovery. Widget test with fakes.
  - [ ] 👤 With WAN unplugged: open app → radar icon → Scan. Expect the Philips (WiZ) and Wipro/Syska
    (Tuya) devices listed. Add them; for Tuya tap the key icon and paste the local key from
    `devices.json`. Tap each device → it toggles; note the ms shown. Log each in HARDWARE_LOG
    (test `scan+toggle`).

## M3 — Engine, state, timers

- [x] **T3.1 CommandEngine** (M) — deps: T2.1, T1.7 — Ref: §CommandEngine
  Do: per-device serial queue, parallel across devices, retry (2x, backoff 150/400 ms),
  optimistic state + confirm read-back, result aggregation for multi-target commands.
  Accept: tests with FakeAdapter incl. partial failures.
  Note: engine/command_engine.dart: per-device SerialQueue, parallel across devices, retry x2 (150/400 ms) except auth/unsupported, optimistic state + revert on failure + read-back (800 ms) confirm, cache persisted to device_state_cache (warmUp/remember), stateChanges stream, power/powerOne/status/run, Aggregate ok/failed. 8 tests with FakeAdapter incl. partial failure.
- [x] **T3.2 StatePoller** (S) — deps: T3.1 — Ref: §StatePoller
  Do: push where adapter supports it, else poll every 5 s while app foreground, 0 when background;
  cache to device_state_cache.
  Note: engine/state_poller.dart: onForeground subscribes adapter.watch() pushes and polls every 5 s (also push devices, to notice offline); 2 consecutive timeout/offline/refused → online=false (auth/protocol errors don't count); background stops polls immediately, drops push sockets after 30 s; push partial updates merged with cache via engine.remember. Engine/poller guard against late results after dispose. 6 tests, stable over repeated runs.
- [x] **T3.3 TimerService core** (M) — deps: T3.1 — Ref: §TimerService
  Do: tier selection, powerFor/powerAfter/powerAt semantics, persistence, cancel, reconcile.
  Accept: matrix tests with fake clock and fake adapters (native / no-native / max exceeded).
  Note: timers/timer_service.dart: tier selection (native if max ≥ d and canCountdownTo(end, currentOn), else phone), powerFor (combined adapter call when supported, else set now + countdown to the opposite), powerAfter, powerAt/powerUntil via untilNext, one active job per device, cancel per tier, reconcile (overdue native → done; overdue phone never run → failed, never executed late; countdown gone on device → cancelled; drift > 1 min → fireAt corrected), onAlarm for phone tier. PhoneAlarmScheduler interface. 19 matrix tests with fake clock and fake adapters.
- [x] **T3.4 Android phone-tier timers (Kotlin)** (L → split) — deps: T3.3, T1.4
  - [x] **T3.4a Alarm scheduling channel** (S): MethodChannel `scheduleExactAlarm(jobId, fireAtMs)`,
    `cancelAlarm(jobId)`, `canScheduleExactAlarms()`; AlarmManager `setExactAndAllowWhileIdle`;
    Dart side behind `PhoneAlarmScheduler` interface with a fake for tests.
    Note: AlarmStore.kt (SharedPreferences jobId→fireAt, setExactAndAllowWhileIdle, inexact fallback when exact not allowed, distinct PendingIntent per job via data URI) + AlarmsPlugin.kt channel offline_home/alarms; Dart AndroidPhoneAlarmScheduler (reports inexact fallback, openExactAlarmSettings) with mocked-channel tests.
  - [x] **T3.4b Background Dart entrypoint** (M): `@pragma('vm:entry-point') timerCallback(jobId)`
    that opens the DB, builds adapters + CommandEngine without Flutter UI, runs `onAlarm(jobId)`.
    Accept: Dart unit test runs the entrypoint against a fake adapter.
    Note: timers/alarm_runner.dart: drainAlarms(host, timerService) pulls job ids until null, runs onAlarm each (crash-safe), reports finished/done; MethodChannelAlarmRunnerHost; @pragma('vm:entry-point') timerAlarmMain in main.dart builds AppServices and drains. AppServices now owns CommandEngine, StatePoller, TimerService (+ phone scheduler per platform). DB uses WAL (two engines share the file). Unit test runs the entry-point logic against a fake adapter.
  - [x] **T3.4c AlarmReceiver + TimerForegroundService** (M): receiver starts the FGS, FGS starts a
    headless `FlutterEngine` on the entrypoint, passes jobId, stops itself when done (timeout 30 s);
    binds to Wi-Fi via LanBindingPlugin before running.
    Note: AlarmReceiver.kt → startForegroundService; TimerForegroundService.kt starts a headless FlutterEngine on timerAlarmMain with LanBindingPlugin + AlarmsPlugin, serves next/finished/done over offline_home/alarm_runner, stops on done or 30 s. FGS type dataSync (VERIFY on Android 14/15). Manifest: SCHEDULE_EXACT_ALARM, FOREGROUND_SERVICE(_DATA_SYNC), RECEIVE_BOOT_COMPLETED, POST_NOTIFICATIONS, receivers, service.
  - [x] **T3.4d Boot + re-arm** (S): `RECEIVE_BOOT_COMPLETED` receiver asks Dart for active phone
    jobs and re-arms them; exact-alarm permission prompt on Android 12+.
  - [ ] 👤 Accept: 1-minute WiZ timer fires with screen off (WiZ has no native countdown). On first
    use allow "Alarms & reminders" if asked. Use the timer action on the debug screen (T3.6).
    Note: BootReceiver.kt re-arms future alarms from AlarmStore after BOOT_COMPLETED / MY_PACKAGE_REPLACED; jobs that passed while off are dropped (not fired late), same rule as reconcile. Exact-alarm permission prompt via AndroidPhoneAlarmScheduler.openExactAlarmSettings (UI in T5.8).
- [x] **T3.5 iOS phone-tier behaviour** (S) — deps: T3.3
  Do: warning copy, foreground ticker, local notification at fire time.
  Note: timers/ios_phone_timers.dart (IosPhoneTimers: local notification 'Timer due: <device> <on/off>' via flutter_local_notifications zonedSchedule at a UTC instant; cancel), timers/phone_tier_ticker.dart (runs due phone jobs while foreground), timers/tier_copy.dart (tier badge/feedback suffix, iOS warning, Android inexact warning). TimerService now stores the job before scheduling. AppServices wires the iOS scheduler + ticker. Android: core library desugaring enabled (plugin requirement). 5 tests.
- [x] **T3.6 👤 Hardware check #2** (S) — deps: T3.3, T2.6
  Accept: "Wipro plug on for 1 minute" turns off with phone in airplane mode.
  Note: Debug screen: long-press a registered device → 'On for 1 minute' / 'Off after 1 minute' / 'Cancel timer', result shows end time and tier ('(plug timer)' / '(phone timer…)'). App start runs timerService.reconcile(); iOS starts the phone-tier ticker. Widget test covers the native-tier path.
  - [ ] 👤 Wipro/Syska plug: long-press → "On for 1 minute" → expect "(plug timer)". Put the phone in
    airplane mode right away; the plug must switch off by itself after 1 minute. Log as
    `native-timer`. If it shows "(phone timer)", note the DP map from the survey.

## M4 — Voice

- [x] **T4.1 SttService** (M) — deps: T0.1 — Ref: §SttService
  Do: speech_to_text on-device mode, contextual strings, partial results, 1.2 s silence stop;
  capability check (on-device available? locales?); Vosk fallback on Android behind interface.
  Accept: 👤 prints transcripts offline on both phones; task note lists available locales.
  Note: voice/stt_service.dart: SttService over a SpeechEngine interface (partials → one final/error, 8 s max, 1.2 s silence stop, contextual phrases, capabilities = available + locale ids); PlatformSpeechEngine = speech_to_text 7.5 with onDevice: true always (rule 6, no cloud fallback) and error mapping to modelMissing/noMatch/permission (VERIFY strings on phones). Vosk fallback NOT added: vosk_flutter is abandoned (Dart 2); the engine interface allows adding one if T4.9 shows a phone lacks an on-device model. Android RECORD_AUDIO + RecognitionService query; iOS mic/speech usage strings. 4 tests.
  - [ ] 👤 On each phone with Wi-Fi off: speak a few commands on the voice debug screen (T4.8) and
    note the transcripts and the locales it lists (en_IN? hi_IN?). If a "language not
    available" error appears, download the offline model: Android → Settings → Google →
    Speech / "Offline speech recognition"; iPhone → Settings → General → Keyboard →
    Dictation languages (on-device).
- [x] **T4.2 Normaliser** (S) — deps: T1.1 — Ref: §Normaliser
  Do: lowercase, punctuation, Devanagari→Latin map, filler removal, spelling variants
  (bandh→band, chaalu→chalu), number words EN + HI (ek..sau, one..hundred, "dedh", "dhai", "sava", "paune").
  Note: voice/normaliser.dart: lowercase, Devanagari→Latin (word table + letter fallback with schwa deletion, Devanagari digits), punctuation (keeps 11:30, a.c.→ac), word + phrase variants (bandh→band, kar do→karo, geezer→geyser, half an hour→0.5 hour …), verb+'do' merging (jala do→jalao) with 'do'=2 only before a unit, 'saath'=60 only before a unit, a/an+unit→1, fillers, EN (incl. twenty five) + HI (1–100 common) number words, fractions aadha/dedh/dhai and sava/saadhe/paune X. 37 tests.
- [x] **T4.3 Lexicons** (S) — deps: T4.2 — Ref: §Lexicon
  Do: `assets/voice/lexicon_en.yaml`, `lexicon_hi.yaml`: actions, time words, room/device nouns.
  Note: assets/voice/lexicon_en.yaml + lexicon_hi.yaml (normalised forms): actions on/off/toggle/cancel/status, relations for/until/after/at, dayparts (subah/raat/…→am/pm), nouns with Hinglish seeds (batti→light, pankha→fan …), quantifiers all/except, units (ghanta→hour), particles. voice/lexicon.dart loads + merges (longest phrase first), nounAt/unitOf/matchAt helpers; registered as Flutter assets. 4 tests.
- [x] **T4.4 Duration + time parser** (M) — deps: T4.2 — Ref: §Time parsing
  Accept: tests: "20 minutes", "adha ghanta", "dedh ghante", "for 1 hour 15", "11 pm", "raat 11 baje",
  "subah 6 baje", "11:30", "in 5 min", "5 minute baad".
  Note: voice/time_parser.dart: parseDuration (n unit, h hour m [minute], fractions from dedh/dhai/adha, seconds) and parseClock (HH:MM, H am/pm, H baje, at H, daypart before/after, saadhe/sava/paune via .5/.25/.75, raat 1–4 → early morning, raat 12 → 00:00, subah 12 → null/ask, bare 12-hour → next occurrence from now), both return token spans. 38 tests covering the task's list.
- [x] **T4.5 IntentParser** (M) — deps: T4.3, T4.4 — Ref: §IntentParser
  Note: voice/intent_parser.dart: normalise → cancel (phrase or 'timer' + cancel verb anywhere) → status (question forms, trailing on/off dropped) → action (longest phrase; on/off beat toggle) → duration/clock spans with ADJACENT relation words only (for/after vs until/at) → target span (all quantifiers, plural nouns imply all, nouns canonicalised batti→light, English 'except X' vs Hindi 'X ke alawa', particles/verb residue dropped). No target → Unknown('which device?'). All 9 §11.5 examples + 15 more pass. 'switch' removed from plug nouns (verb ambiguity).
- [x] **T4.6 TargetResolver** (M) — deps: T1.7, T4.5 — Ref: §TargetResolver
  Do: Jaro-Winkler + Double Metaphone, aliases, rooms, "all", "except", Hinglish plurals ("lights", "batiyan").
  Note: voice/target_resolver.dart + voice/fuzzy.dart: exact whole-phrase name wins; room matching (token or JW ≥ 0.85); room + only nouns / room alone / all → pool filtered by noun (name/alias/brightness-capable for 'light') minus except (room or device); otherwise score = max over name+aliases of containment (0.95) or 0.6·JaroWinkler + 0.4·phonetic; < 0.6 none, < 0.8 or tie within 0.05 → ambiguous chips (top 3). Generic alias == generic word scores as category (0.95), not a name. DEVIATION: Hinglish-tuned phonetic key instead of Double Metaphone (English rules mangle aspirates/vowels). 14 end-to-end utterance→device tests + ambiguity + fuzzy tests.
- [x] **T4.7 Golden corpus** (M) — deps: T4.5, T4.6
  Do: ≥ 150 cases in `test/voice/corpus/*.yaml` (EN 60%, Hinglish 40%, incl. STT-style misspellings).
  Accept: ≥ 95% pass; failures listed in task note.
  Note: test/voice/corpus/{en,hi}.yaml: 159 cases (95 EN = 60 %, 64 Hinglish incl. Devanagari = 40 %, 17 STT-style misspellings), compact [utterance, expected] notation (corpus/README.md); golden_corpus_test.dart asserts ≥ 150 cases and ≥ 95 % exact. First run 92.5 %: fixed 'run'/'keep … on', 'in the morning'/'at night' after a time, 'stop … timer' as cancel, STT 'of'→'off'; one expectation of mine was wrong ('sab kuch' = everything). Now 159/159. CAVEAT: written alongside the parser, so this proves consistency, not real-world accuracy — add real transcripts from T4.9.
- [x] **T4.8 VoiceController + feedback** (S) — deps: T4.1, T4.6, T3.1, T3.3
  Do: orchestration, confirmation rules (PLAN §7), TTS + toast, undo for 5 s.
  Note: voice/voice_controller.dart: listen (contextual hints = device names/aliases/rooms) → parse → resolve → confirm (ambiguous → chips; 'all' > 5 devices → question) → execute via CommandEngine/TimerService → message + TTS ('Geyser on. Off at 9:40 pm (plug timer).', 'X is not responding.', 'key rejected') → 5 s undo (restores prior power / cancels created timers). VoiceState stream for the UI. voice/tts.dart (flutter_tts en-IN, SilentTts). AppServices loads the lexicon and builds the controller. Voice debug screen (mic icon): hold to talk or type, chips, undo, locale list. 8 controller tests.
- [ ] **T4.9 👤 Real-voice test** (S) — deps: T4.8
  Do: 30 spoken commands per language on each phone, results logged.
  Note: use the mic screen (debug home → mic icon); it shows transcript → result. Paste misses
  back so they become corpus cases.

## M5 — UI and onboarding

- [x] **T5.1 App shell + theme + navigation** (S) — deps: T0.1
  Note: ui/providers.dart (services, devices, rooms, deviceStates from engine cache + stateChanges, netState, active timers with 1 s tick, voiceState, clock), ui/theme.dart (Material 3 teal seed, light/dark), ui/app.dart (lifecycle: resume → poller.onForeground + iOS ticker + reconcile; pause → poller.onBackground; devices change → re-arm poller), ui/screens/shell.dart (Home/Timers/Settings NavigationBar + network banner), debug screens moved behind ui/screens/debug_menu.dart. main() runs the shell in a ProviderScope. test/support/test_services.dart builds AppServices on fakes; tearDown() pumps before closing drift (else close() hangs on fake-zone stream queries).
- [x] **T5.2 Home screen** (M) — deps: T5.1, T3.2
  Do: rooms → device tiles (state, tap toggle, long-press detail), "Local mode" banner, mic FAB.
  Note: ui/screens/home_screen.dart: devices grouped by room (sort order) + 'Other', responsive tile grid, tap → engine toggle, long-press → onOpenDevice, empty state → Add devices, large mic FAB; ui/widgets/device_tile.dart: icon by name/capability, On/Off/Offline (greyed), timer chip 'off in 18m · Plug' (tier named). Banner comes from the shell. Wired as the Home tab. 3 widget tests.
- [x] **T5.3 Device detail** (M) — deps: T5.2, T3.3
  Do: power, sliders by capability, timer presets (15/30/60/custom), default auto-off, name, room,
  aliases, protocol info, "re-scan IP".
  Note: ui/screens/device_detail_screen.dart: power switch (offline-aware), brightness / colour-temperature sliders only with those capabilities, current timer with tier + cancel, presets on for 15/30/60 min + custom (iOS phone-tier warning), default auto-off dropdown (TimerService.applyAutoOff now runs after app/voice power-on), rename, room, aliases with Hinglish suggestions (ui/alias_suggestions.dart), connection info (brand/protocol/IP/MAC/id, Tuya key stored?), Re-scan IP, remove device (cancels timers, deletes key). Feedback via SnackBar. Long-press on Home opens it. 5 widget tests + auto-off test.
- [x] **T5.4 Timers screen** (S) — deps: T3.3
  Do: list with remaining time, tier badge (Plug / Phone), cancel, reconcile on open.
  Note: ui/screens/timers_screen.dart: reconcile on open, active timers sorted by fire time with live countdown ('Geyser off in 18m', 'at 9:40 PM'), tier chip (Plug/Bridge/Phone), cancel per row, iOS warning card when any phone-tier timer exists, empty state with a voice hint. Wired as the Timers tab. 2 widget tests.
- [x] **T5.5 Voice sheet** (S) — deps: T4.8
  Do: listening animation, live transcript, disambiguation chips, result.
  Note: ui/screens/voice_sheet.dart: bottom sheet opened by the Home mic FAB (starts listening), pulsing mic + live transcript + Stop, confirmation chips (device / 'All of these' / Cancel), result with icon, Undo (5 s) and 'Speak again', idle 'Tap to speak', plus a typed-command field (works without speech). Widget test drives typed commands through VoiceController: result, TTS, undo, ambiguity chips.
- [x] **T5.6 Add-devices flow** (M) — deps: T2.9 — Ref: §Onboarding
  Do: scan, badges, per-badge resolve screens, naming + rooms + alias suggestions.
  Note: ui/screens/add_devices_screen.dart + onboarding/badges.dart: scans on open, new devices with badge Ready / Needs key / Needs pairing / Cloud-only / Not supported yet (no adapter for the protocol — honest until M7) / Unknown, already-added summary incl. moved IPs; per-badge resolve: Tuya key paste (verified against the device after add; missing id → points to devices.json), explanations for the rest; name sheet with room chips + New room…, alias suggestions. AdapterRegistry.supportsProtocol. Shared ui/widgets/prompt.dart (dialog owns its controller — fixes dispose-during-animation crash) now used by device detail too. Opened from the Home empty state.
- [x] **T5.7 Settings** (S) — deps: T5.1
  Do: language, TTS on/off, poll interval, export/import config (encrypted JSON with passphrase,
  secrets included only if user opts in), diagnostics (logs, network state).
  Note: ui/screens/settings_screen.dart: voice language (English (India) / Hinglish → en_IN, Hindi → hi_IN) + spoken feedback, applied live to VoiceController; poll interval (3/5/10/30 s → StatePoller); Add devices; export/import configuration (registry/config_export.dart: PBKDF2-HMAC-SHA256 150k → AES-256-GCM envelope; secrets only when opted in; wrong passphrase → clear error) via ui/file_access.dart (file_picker); diagnostics: network state, recent redacted logs (AppServices.logSink), developer tools; About with 'not affiliated'. app/app_settings.dart typed settings; AppServices.applySettings() at startup. Tests: config round trip (with/without secrets, wrong pass, junk) + settings apply.
- [x] **T5.8 Permissions + first-run** (S) — deps: T1.5, T4.1
  Do: permission walkthrough, offline speech model download instructions per platform.
  Note: ui/screens/first_run.dart shown until settings.onboarded: welcome (local-only, not affiliated) → permissions (onboarding/permissions.dart PlatformPermissions: iOS Local Network probe, mic+speech via speech_to_text init, notifications via flutter_local_notifications, Android exact alarms → system settings; status per row with Allow / Try again) → offline speech model (lists en/hi locales, per-platform download steps) → add devices → Done. App root gated by onboardedProvider. Widget test walks the whole flow with fake permissions.
- [x] **T5.9 Android widget + quick-settings tile** (M) — deps: T4.8
  Do: widget with mic button + 4 favourite devices; tile opens voice sheet directly.
  Note: plain AppWidgetProvider (no Glance) + TileService open the app with `offlinehome://voice|toggle/<id>` via home_widget's launch action; star on device detail marks favourites; hardware check #9 pending.
- [ ] **T5.10 iOS widget / Shortcuts** (S) — deps: T4.8 — optional, can defer.
  Note: deferred — needs a WidgetKit extension target + App Group, which requires Xcode signing on the Mac.

## M6 — Key import (onboarding/cloud_import — the only internet code)

- [x] **T6.1 tinytuya devices.json import** (S) — deps: T5.6, T1.8 — Ref: §Key import
  Accept: sample file imports; keys land in SecretStore; devices matched by id.
  Note: lib/onboarding/devices_json_import.dart (no network) + import screen; dpMap from mapping codes (switch_1/switch_led, countdown_1/countdown); sub-devices skipped; quick scan + status check per device. Hardware check #10 pending.
- [x] **T6.2 Manual key entry** (S) — deps: T6.1
  Note: device detail → "Enter local key"; 16 printable chars; session reset + one status read; auth error rolls back to the previous key (lib/onboarding/manual_key.dart).
- [x] **T6.3 Tuya OpenAPI in-app import** (M) — deps: T6.1 — Ref: §Tuya cloud import
  Do: user enters access id/secret + region; signed requests; fetch device list with local_key.
  Accept: unit tests with recorded (sanitised) responses; VERIFY signing against Tuya docs.
  Note: lib/onboarding/cloud_import/tuya_cloud.dart ported from tinytuya 1.20.0 Cloud.py; signing checked byte-for-byte against vectors from sim/tools/gen_tuya_cloud_vectors.py; recorded-response flow tests; guard test keeps HTTP out of the rest of lib/. VERIFY open: token call without tinytuya's `secret` header, auth error codes 1004/1010/1011. Hardware check #11.
- [x] **T6.4 Guide screen: re-pair Tuya device to own account** (S) — deps: T6.1
  Do: step-by-step copy: reset device, add in Smart Life, link to Tuya IoT project, run wizard,
  re-link in Alexa.
  Note: lib/ui/screens/tuya_guide_screen.dart, linked from the key import screen ("How do I get keys?").

## M7 — Remaining adapters (each: simulator → adapter → contract suite → probe rule)

- [x] **T7.1 Tuya 3.4** (M) — deps: T2.6 — Ref: §Tuya 3.4
  Note: session negotiation + HMAC framing + CONTROL_NEW/DP_QUERY_NEW payloads, byte-exact vs tinytuya (vectors_34.json); TuyaSim version=3.4 verified with tinytuya's client; contract suite green. VERIFY: 3.4 STATUS push shape, device behaviour on a wrong key (we map hang-up → auth). Hardware check #12.
- [x] **T7.2 Tuya 3.5** (M) — deps: T7.1 — Ref: §Tuya 3.5
  Note: 6699 AES-GCM frames, GCM session negotiation, replies matched by command (3.5 seqno is the device's), port-7000 beacons + REQ_DEVINFO broadcast; byte-exact vs tinytuya (vectors_35.json); TuyaSim version=3.5 verified with tinytuya; contract suite green. Hardware check #13.
- [x] **T7.3 Tuya bulb + multi-gang profiles** (S) — deps: T2.6
  Note: bulb types A/B/C + detection + value ranges ported from tinytuya BulbDevice (set_white semantics); import derives bulb roles/ranges and one app device per gang (`<id>#n`, shared key/session); sim profile=bulba, gang=N. VERIFY: gang countdown default 6+n, Kelvin↔Tuya temp mapping; bulbs added by scan only (no devices.json) get power caps until a mapping is imported. Hardware check #14.
- [x] **T7.4 Shelly Gen1 + Gen2** (M) — deps: T2.1 — Ref: §Shelly
  Note: ShellyAdapter (Gen1 REST relay/turn/timer + Basic auth; Gen2 JSON-RPC POST /rpc Switch.GetStatus/Set/toggle_after + aioshelly AuthData digest, byte-checked vs aioshelly vectors); flip-based countdown + combined powerFor; ShellySim gen=1|2 password=; contract suite green for 4 variants; add-flow asks for the Shelly password. VERIFY: in-frame digest over HTTP POST, countdown max, cancel by re-sending state, Gen2 timer vs phone clock. Hardware check #15.
- [x] **T7.5 Kasa legacy** (M) — deps: T2.1 — Ref: §Kasa legacy
  Note: KasaAdapter (TCP 9999 XOR per python-kasa; plugs, strip outlets via context child_ids, bulbs via lightingservice); absolute countdown rules (count_down → countdown fallback); KasaSim verified with python-kasa's IotPlug/IotStrip/IotBulb; contract suite green (plug, plug w/ `countdown` module, bulb). VERIFY: countdown module/add_rule/remain on real plugs; strip outlets and bulb caps are not auto-created on add yet (T7.12). Hardware check #16.
- [x] **T7.6 KLAP transport + Tapo/Kasa new** (L → split) — deps: T7.5 — Ref: §KLAP
  - [x] **T7.6a KLAP transport** — handshake1/2 (v1 md5 / v2 sha256 hashes, default + blank credential fallback), TP_SESSIONID cookie, AES-CBC session with signed seq; byte-exact vs python-kasa `klaptransport.py`; KlapSim.
    Note: lib/adapters/kasa/klap.dart byte-exact vs python-kasa (klap_vectors.json, v1+v2); KlapSim (device side built from python-kasa's own session/hash helpers) verified with python-kasa's KlapTransport(V2)+Smart/IotProtocol; Dart transport green incl. default creds, wrong account, 403 re-handshake.
  - [x] **T7.6b Devices over KLAP** — IOT.KLAP (legacy JSON, reuse KasaAdapter) and SMART.KLAP (Tapo: get_device_info / set_device_info device_on, brightness, color_temp). python-kasa 0.10.2 has no SMART countdown-rule API → phone-tier timers.
    Note: KasaAdapter speaks `klap-iot` (KLAP v1) with the same IOT JSON; new TapoAdapter for `klap-smart` (get/set_device_info, brightness, color_temp; SmartErrorCode auth set). Contract suites green for both. No native countdown for Tapo (phone tier).
  - [x] **T7.6c TP-Link account + discovery** — account e-mail/password in SecretStore (`tplink`), add-flow prompt, fingerprinter maps 20002 device_type → `klap-iot` / `klap-smart` (AES → not supported yet).
    Note: fingerprinter maps 20002 device_type/encrypt_type like kasa/device_factory.py → `klap-iot` / `klap-smart` (AES / HTTPS → `tplink-*` = not supported yet); add flow asks for the TP-Link account once (SecretStore `tplink`). VERIFY: the static 20002 query is answered at home. Hardware check #17.
- [x] **T7.7 Hue bridge + link-button pairing** (M) — deps: T2.1 — Ref: §Hue
  Note: HueAdapter (v1 REST per aiohue: pairing, lights on/bri/ct, errors 1/101, bridge-id normalisation); one app device per light (`<bridge>-<light>`), username in SecretStore; timers = bridge schedules `PT hh:mm:ss` found again via GET /schedules; add-flow pairing dialog with 30 s countdown; discovery moves lights with the bridge IP. HueSim verified with aiohue. VERIFY: schedule API/limits and starttime clock on a real bridge. Hardware check #18.
- [x] **T7.8 Yeelight** (S) — deps: T2.1 — Ref: §Yeelight
  Note: YeelightAdapter (TCP 55443 JSON lines per python-yeelight: get_prop, set_power/bright/ct_abx + smooth 300 ms, props notifications skipped); native timer = cron off-timer in whole minutes (so ON-ending timers use the phone tier); YeelightSim verified with python-yeelight's Bulb. VERIFY: cron_get reply shape and max delay; LAN control must be enabled in the Yeelight app. Hardware check #19.
- [x] **T7.9 Sonoff LAN (DIY + encrypted)** (M) — deps: T2.1 — Ref: §Sonoff
  Note: SonoffAdapter per AlexxIT/SonoffLAN local.py (POST /zeroconf/<cmd>, AES-CBC md5(devicekey) crypto byte-exact vs vectors from its own encrypt()); switch + multi-channel switches; state via DIY `info`; add-flow asks for the devicekey. SonoffSim (DIY / encrypted / outlets=N). VERIFY: `info` on eWeLink firmware (state may only be in mDNS TXT); no native countdown (phone tier). Hardware check #20.
- [x] **T7.10 Tasmota** (S) — deps: T2.1 — Ref: §Tasmota
  Note: TasmotaAdapter (/cm Power<n>, Dimmer, CT, web password); native timer only for "on for d" via PulseTime, cleared on every other power command, on cancel and when getState sees the pulse finished; other timers → phone tier. Contract harness gained `combinedPowerForOnly`. VERIFY: PulseTime behaviour on hardware. Hardware check #21.
- [x] **T7.11 ESPHome (web server REST)** (S) — deps: T2.1 — Ref: §ESPHome
  Note: EspHomeAdapter (GET /<domain>/<id>, POST turn_on/turn_off, light ?brightness=, optional Basic auth); entity entered when adding (meta.espEntity); phone-tier timers. EspHomeSim per the web_server REST docs. VERIFY: entity listing (/events) to avoid typing the id. Hardware check #22.
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
