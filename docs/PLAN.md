# PLAN — Offline Home

Status: v1 plan, 29 Sep 2026. Source PRD: the Claude Doc "PRD: Offline Voice Control for Smart
Home Devices". This file supersedes the PRD wherever they differ.

---

## 1. Decisions log

| # | Decision | Consequence |
|---|---|---|
| D1 | Personal + open source (GitHub), never commercial | Reverse-engineered protocols are acceptable; README must say "not affiliated with any vendor". |
| D2 | Flutter, Android **and** iOS in v1 | Shared Dart core; thin Kotlin/Swift plugins. |
| D3 | Built on MacBook, installed with `flutter run`; iOS uses a free Apple ID | iOS build expires every 7 days (re-run). No multicast entitlement → iOS discovery = Bonjour + unicast scan, no UDP broadcast. |
| D4 | No hub in v1, phone only | Timers must use device-native countdown; phone fallback on Android only (best effort), iOS shows a warning. |
| D5 | Hinglish in v1 | Parser normalises Latin-script Hindi and Devanagari; golden corpus includes Hinglish. |
| D6 | Auto-off is optional per device (no mandatory safety timer) | Device setting `defaultAutoOff: Duration?`. |
| D7 | Build **all** plug/bulb adapters; priority = build order | See §6. |
| D8 | Smart TV / Fire TV deferred | Not in v1 tasks; adapter interface must not block it later. |
| D9 | Alexa account is not accessible | Brand is auto-detected. Tuya keys come from (a) importing a `tinytuya` `devices.json`, (b) manual paste, or (c) in-app Tuya cloud import after re-pairing devices to the owner's own Smart Life account. |
| D10 | Matter deferred to after v1 | Needs native SDK work on both platforms. |

### Corrections to the PRD
- **MAC-vendor lookup is not available** on modern phones (Android 10+ blocks the ARP table,
  iOS never exposes it). Fingerprinting uses open ports, protocol replies and mDNS instead;
  MAC comes from the device's own reply where the protocol includes it.
- **v1 Tuya key path = import `devices.json`** produced by `python -m tinytuya wizard` on the
  MacBook. In-app cloud import is a later task (T6.3).

---

## 2. Scope of v1

In: discovery, brand fingerprinting, device registry with rooms/aliases, tap control, live
state, voice (EN + Hinglish, push-to-talk), timers (device-native first), timers screen,
onboarding/key import, settings, config export/import, Android widget + quick-settings tile.

Out: remote access, wake word, TV control, Matter, scenes with conditions, hub mode,
Zigbee/BLE-only devices, Echo speakers.

---

## 3. Architecture

```
UI (Flutter screens, riverpod providers)
 ├─ VoiceController ── SttService (on-device) ─► IntentParser ─► TargetResolver
 │                                                   │
 └────────────── CommandEngine ◄─────────────────────┘
                     │  ├─ TimerService (tier select, persistence, reconcile)
                     │  └─ StatePoller (poll / push, cache)
                     ▼
               AdapterRegistry ─► DeviceAdapter (tuya, wiz, shelly, kasa, tapo, hue,
                     │                            yeelight, sonoff, tasmota, esphome)
                     ▼
               LanSocketFactory ─► [Android: sockets bound to Wi-Fi Network]
                     ▼
               Home router (LAN) ─► devices

Discovery (bonsoir mDNS, UDP listen/broadcast, unicast subnet scan) ─► Fingerprinter
   ─► DeviceRepository (drift/SQLite) + SecretStore (Keychain/Keystore)

Onboarding/cloud_import (ONLY internet-using code): devices.json import, Tuya OpenAPI,
Tapo/Kasa credential capture, Hue link-button pairing
```

### Module responsibilities

| Module | Responsibility |
|---|---|
| `core/` | Models (Device, DeviceState, Capability, Timer, Intent), `Result`, errors, clock, logger. |
| `net/` | `LanSocketFactory` (TCP/UDP/HTTP), `NetworkMonitor` (Wi-Fi present? internet present?), Wi-Fi IP/subnet. |
| `registry/` | drift DB (devices, rooms, aliases, timers, settings), `SecretStore`, repositories. |
| `discovery/` | Candidate collection from mDNS, UDP listeners, broadcast probes, subnet scan; `Fingerprinter` decides brand/protocol. |
| `adapters/` | One folder per protocol, all implementing `DeviceAdapter`. |
| `engine/` | `CommandEngine` (fan-out, retries, per-device serial queue), `StatePoller`. |
| `timers/` | Tier selection, native countdown mapping, Android alarm fallback, reconciliation. |
| `voice/` | STT wrapper, normaliser, lexicons (en, hi-Latn, hi-Deva), grammar parser, number/time parsing, target resolver, TTS feedback. |
| `onboarding/` | Scan flow, key import, pairing flows, cloud import. |
| `ui/` | Home (rooms), device detail, timers, add devices, settings, voice sheet, widget. |

---

## 4. Tech choices

| Need | Choice | Note |
|---|---|---|
| State | `flutter_riverpod` | |
| DB | `drift` + `sqlite3_flutter_libs` | |
| Models | `freezed`, `json_serializable` | |
| Secrets | `flutter_secure_storage` | Keychain / Keystore |
| Sockets | `dart:io` `Socket`, `RawDatagramSocket`, `HttpClient` via `LanSocketFactory` | |
| Crypto | `pointycastle` (AES-ECB/CBC/GCM, HMAC-SHA256), `crypto` (MD5, SHA) | Tuya, Sonoff, KLAP |
| mDNS | `bonsoir` | Native NSD / NetService — works on iOS without multicast entitlement |
| Wi-Fi info | `network_info_plus` | IP, subnet, SSID |
| STT | `speech_to_text` with on-device option; Android fallback: Vosk (`vosk_flutter`) | VERIFY each plugin's on-device flag and iOS support at T4.1 |
| TTS | `flutter_tts` | offline voices |
| Android native | Kotlin plugin `LanBindingPlugin`, `TimerForegroundService`, `AlarmReceiver` | |
| iOS native | Swift plugin `LocalNetworkPlugin` (trigger permission prompt, report status) | |
| Widget / tile | `home_widget` (Android widget), Kotlin `TileService` | |
| Simulators | Python 3.11, asyncio, pytest | `sim/` |

---

## 5. Discovery and fingerprinting

Run all probes in parallel for up to 6 s, merge by IP, then fingerprint.

| Probe | Android | iOS (no multicast entitlement) | Identifies |
|---|---|---|---|
| mDNS browse `_hue._tcp`, `_shelly._tcp`, `_http._tcp`, `_ewelink._tcp`, `_esphomelib._tcp`, `_matter._tcp` | bonsoir | bonsoir (declare in `NSBonjourServices`) | Hue, Shelly, Sonoff LAN, ESPHome, Matter (later) |
| Listen UDP 6666 / 6667 (Tuya beacons) | yes (MulticastLock) | VERIFY: receiving broadcast may fail | Tuya id, ip, version |
| Broadcast UDP 38899 `getPilot` | yes | no → unicast to each IP | WiZ |
| Broadcast UDP 9999 `get_sysinfo` (XOR) | yes | no → unicast | Kasa legacy |
| Broadcast UDP 20002 (KLAP discovery) | yes | no → unicast | Tapo / new Kasa |
| SSDP-like 239.255.255.250:1982 | yes | no → skip, TCP probe 55443 | Yeelight |
| TCP connect scan of /24 on 6668, 9999, 80, 8081, 55443, 6053 | yes | yes | candidate ports |
| HTTP `GET /shelly`, `GET /cm?cmnd=Status`, `GET /` | yes | yes | Shelly, Tasmota, generic |

Fingerprint rules (first match wins): see `PSEUDOCODE.md §Fingerprinter`. Output:
`Candidate{ip, mac?, brand, protocol, protocolVersion?, deviceId?, name?, needsKey}`.

---

## 6. Adapter matrix and build order

| Order | Adapter | Protocol summary | Native countdown | Needs secret | Reference to port from |
|---|---|---|---|---|---|
| 1 | WiZ (Philips Smart Wi-Fi) | UDP 38899 JSON `getPilot`/`setPilot` | No (phone tier) | No | `pywizlight` |
| 2 | Tuya 3.1/3.3 (Wipro, Syska, Smart Life) | TCP 6668, 55AA frames, AES-ECB | Yes, countdown DP | `local_key` | `tinytuya` (`core.py`) |
| 3 | Tuya 3.4 | + session-key negotiation, HMAC-SHA256 | Yes | `local_key` | `tinytuya` |
| 4 | Tuya 3.5 | 6699 frames, AES-GCM | Yes | `local_key` | `tinytuya` |
| 5 | Shelly Gen1 / Gen2+ | HTTP REST / RPC | Yes (`timer`, `toggle_after`) | Optional password | Shelly API docs, `aioshelly` |
| 6 | Kasa legacy | TCP 9999, XOR autokey | Yes (`count_down` rules) | No | `python-kasa` |
| 7 | Kasa KLAP / Tapo | HTTP handshake1/2, AES-CBC | Yes (VERIFY per model) | Account email+password | `python-kasa` (`klaptransport.py`) |
| 8 | Hue bridge | Local REST v1 (v2 optional) | Yes (bridge schedules `PT..`) | Bridge username | Hue API docs |
| 9 | Yeelight | TCP 55443 JSON (LAN control must be enabled) | Yes (`cron_add`) | No | `python-yeelight` |
| 10 | Sonoff LAN / DIY | HTTP 8081 `/zeroconf/*`, AES-CBC for non-DIY | VERIFY | `devicekey` (non-DIY) | `SonoffLAN` (AlexxIT) |
| 11 | Tasmota | HTTP `/cm?cmnd=` | Yes (`PulseTime`) | Optional | Tasmota docs |
| 12 | ESPHome | Web server REST (native API later) | No (phone tier) | Optional | ESPHome docs |

Capabilities per adapter: `power` always; `brightness`, `colorTemp`, `rgb` where supported
(UI shows sliders only if present); `nativeCountdown(maxSeconds)`.

---

## 7. Voice design

Push-to-talk → `SttService.listen(onDevice: true, locale, contextualStrings = device names +
aliases + rooms)` → text → `Normaliser` (lowercase, Devanagari→Latin transliteration, number
words → digits, strip fillers "please", "zara", "na") → `IntentParser` (rule grammar) →
`TargetResolver` (fuzzy + phonetic match) → confirmation rules → `CommandEngine`.

Intents: `power(on|off|toggle)`, `powerFor(duration)`, `powerAt(time)`, `powerAfter(duration)`,
`cancelTimer`, `status`, `listTimers`.
Targets: device, alias, room ("bedroom ki lights"), `all`, `all in room`, `except X`.

Confirmation required when: target is "all" with > 5 devices, match score < 0.8, or two
candidates within 0.05 of each other (show chips).

Feedback: short TTS + toast: "Geyser on. Off at 9:40 (plug timer)."

Language setting: `English (India)` | `Hinglish`. Hinglish mode runs the recogniser in
`en-IN` first; if confidence < threshold and `hi-IN` on-device is available, re-run on the same
audio is NOT possible with platform STT, so instead offer a "Hindi" toggle in the voice sheet.
VERIFY available on-device locales on both test phones at T4.1.

---

## 8. Timer design

Tier selection per device:
1. `nativeCountdown` supported and duration ≤ max → program the device.
2. Else Android → schedule exact alarm + execute in `TimerForegroundService`.
3. Else iOS → store timer, show "phone must stay open on Wi-Fi" warning, run while app is
   foregrounded, plus a local notification at fire time prompting the user to open the app.

Absolute times ("at 11 pm", "11 baje") are converted to a duration at request time. Timers are
persisted; on app start and every Timers-screen open, `reconcile()` reads native countdowns
back from devices and fixes drift or removes finished timers.

`powerFor(d)` = set target state now + countdown d that flips it back.
`powerAfter(d)` = countdown d that sets target state (leave current state).

---

## 9. Onboarding and secrets

1. Grant permissions (local network, microphone, speech, notifications, exact alarms on
   Android).
2. Download the on-device speech model while online (instructions per platform).
3. Scan. Show found devices with brand + badge: `Ready` | `Needs key` | `Needs pairing` |
   `Cloud-only` | `Unknown`.
4. Resolve badges:
   - Tuya `Needs key`: import `devices.json` (Files picker / AirDrop / share-sheet) or paste key.
   - Tapo/KLAP: enter the TP-Link account email + password once (stored in SecretStore).
   - Hue: "Press the bridge button" then pair.
   - Sonoff non-DIY: paste `devicekey` or import.
5. Name devices, assign rooms, add aliases (suggest Hinglish aliases: light → batti,
   fan → pankha).

---

## 10. Platform configuration

**Android** (`AndroidManifest.xml`): `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`,
`CHANGE_WIFI_MULTICAST_STATE`, `NEARBY_WIFI_DEVICES` (33+), `ACCESS_FINE_LOCATION`
(≤32, for SSID), `RECORD_AUDIO`, `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`,
`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC` (VERIFY best FGS type),
`RECEIVE_BOOT_COMPLETED`. `usesCleartextTraffic=true` (LAN HTTP). minSdk 26.

**iOS** (`Info.plist`): `NSLocalNetworkUsageDescription`, `NSBonjourServices` (list in §5),
`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`,
`NSAppTransportSecurity > NSAllowsLocalNetworking = YES`. Deployment target iOS 16.

---

## 11. Testing strategy

| Layer | How |
|---|---|
| Protocol codecs | Unit tests with byte-exact vectors taken from reference libraries' tests. |
| Adapters | Integration tests against `sim/` simulators on localhost. |
| Discovery | Simulators announce on loopback / fake mDNS; fingerprinter unit tests with recorded replies. |
| Voice | Golden corpus YAML (≥ 150 utterances EN + Hinglish) → expected Intent JSON. |
| Timers | Fake clock; tier selection matrix tests; reconcile tests. |
| Offline | Manual checklist in `TASKS.md` T8.3, run with WAN cable unplugged, on both phones. |
| Hardware | Human records each real device result in `docs/HARDWARE_LOG.md`. |

---

## 12. Milestones

| M | Name | Exit gate |
|---|---|---|
| M0 | Scaffold + CI | `flutter test` green on empty app; sims run; CI green on GitHub Actions. |
| M1 | Core, net, registry | Sockets bind to Wi-Fi on Android with "no internet" Wi-Fi. |
| M2 | First adapters (WiZ, Tuya 3.3) + discovery | Real WiZ + Wipro toggled offline from the app. |
| M3 | Engine, state, timers | "On for 1 min" on a Tuya plug turns off with phone in airplane mode. |
| M4 | Voice EN + Hinglish | ≥ 95% corpus pass; real-voice spot test ≥ 90%. |
| M5 | UI + onboarding complete | Fresh install → controlling devices in < 5 min. |
| M6 | Key import | `devices.json` import puts keys in SecretStore; manual key entry works. |
| M7 | Remaining adapters | Each passes its simulator suite. |
| M8 | Hardening + offline validation | Full T8.3 checklist passes on both phones. |

---

## 13. Risks (delta from PRD)

| Risk | Mitigation |
|---|---|
| Tuya keys unobtainable (account not accessible) | Re-pair to own Smart Life account → `tinytuya wizard`; or have the account owner log in once. |
| iOS cannot receive Tuya UDP beacons without entitlement | TCP 6668 scan + devices.json already carries ids and IPs. |
| Hinglish STT accuracy with `en-IN` model | Phonetic lexicon variants, corpus from real recordings, Hindi toggle. |
| Free iOS signing expiry (7 days) | Accepted; reinstall from MacBook. |
| Protocol constants wrong | Rule 2 in CLAUDE.md: port, cite, test vectors, VERIFY markers. |
