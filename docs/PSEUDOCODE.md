# PSEUDOCODE — Offline Home

Language-neutral pseudocode (Dart-flavoured). `VERIFY` = port the exact value/behaviour from the
named reference implementation and add a test vector before trusting it (CLAUDE.md rule 2).

Contents: 0 End-to-end flows · 1 Bootstrap · 2 Core models · 3 Network · 4 Registry ·
5 Adapter interface · 6 Adapters · 7 Discovery · 8 CommandEngine · 9 StatePoller ·
10 TimerService · 11 Voice · 12 Onboarding & key import · 13 UI state · 14 Simulators

---

## 0. End-to-end flows

### 0.1 First run
```
launch app
  → bootstrap()                                   // §1
  → if !settings.onboarded: FirstRunFlow
       PermissionsScreen: localNetwork, mic, speech, notifications, (Android) exact alarms
       SpeechModelScreen: check SttService.capabilities(); if on-device model missing →
                          show platform steps to download it (needs internet once)
       ScanScreen: candidates = DiscoveryService.scan()          // §7
                   show list with badges (Ready | Needs key | Needs pairing | Cloud-only | Unknown)
       ResolveBadges: devices.json import / key paste / Hue button / Tapo credentials   // §12
       NameAndRooms: per device name, room, aliases (suggest Hinglish aliases)
       settings.onboarded = true
  → HomeScreen
```

### 0.2 Voice command (happy path)
```
user holds mic
  VoiceController.start()
    ctx = registry.allNames() + aliases + rooms
    text = await SttService.listen(onDevice=true, locale=settings.locale, contextual=ctx)
    intent = IntentParser.parse(text)                        // §11.5
    if intent is Unknown: say("Sorry, didn't get that"); show transcript; return
    targets = TargetResolver.resolve(intent.targetSpan)       // §11.6
    if needsConfirmation(intent, targets): show chips; await user pick
    switch intent:
      Power(on/off/toggle)        → results = CommandEngine.power(targets, action)
      PowerFor(action, d)         → TimerService.powerFor(targets, action, d)
      PowerAfter(action, d)       → TimerService.powerAfter(targets, action, d)
      PowerAt(action, clockTime)  → TimerService.powerAfter(targets, action, untilNext(clockTime))
      PowerUntil(action, clockT)  → TimerService.powerFor(targets, action, untilNext(clockT))
      CancelTimer                 → TimerService.cancel(targets)
      Status                      → states = CommandEngine.status(targets)
    feedback(results)             // TTS + toast + undo(5 s)
```

### 0.3 Timer with phone gone (Tuya plug)
```
"geyser 20 minute ke liye chalu karo"
 → PowerFor(on, 20m) → TimerService picks tier NATIVE (Tuya countdown DP)
 → adapter.setPower(on); adapter.setCountdown(1200 s)   // device flips itself off at 0
 → persist TimerJob(tier=native, fireAt=now+20m)
 phone leaves home; plug switches off on its own; next app open → reconcile() marks job done
```

---

## 1. Bootstrap
```
main():
  WidgetsFlutterBinding.ensureInitialized()
  log = Logger(redactor = SecretStore.redactor)
  db = AppDatabase.open()                          // drift, runs migrations
  secrets = SecretStore()
  platform = PlatformBridge()                      // LanBinding (Android) / LocalNetwork (iOS)
  await platform.init()                            // Android: bind process to Wi-Fi network if present
  sockets = LanSocketFactory(platform)
  adapters = AdapterRegistry([
     WizAdapter, TuyaAdapter, ShellyAdapter, KasaLegacyAdapter, KlapAdapter, HueAdapter,
     YeelightAdapter, SonoffAdapter, TasmotaAdapter, EspHomeAdapter ], sockets, secrets)
  netMonitor = NetworkMonitor(platform)
  engine = CommandEngine(adapters, db)
  timers = TimerService(engine, adapters, db, platform, clock)
  poller = StatePoller(engine, db)
  voice = VoiceController(SttService(), IntentParser(lexicons), TargetResolver(db), engine, timers, Tts())
  netMonitor.onWifiChanged → platform.rebind(); discovery.quickRefresh()
  unawaited(timers.reconcile())
  runApp(ProviderScope(overrides=[...all of the above...], child=App()))
```

---

## 2. Core models
```
enum Brand { wiz, tuya, shelly, kasa, tapo, hue, yeelight, sonoff, tasmota, esphome, unknown }
enum Capability { power, brightness, colorTemp, rgb, nativeCountdown }

Device {
  id: String              // stable: vendor device id, else mac, else "ip:<ip>"
  brand: Brand
  protocol: String        // "tuya-3.3", "wiz", "kasa-klap", ...
  ip: String, mac: String?, port: int?
  name: String, roomId: String?, aliases: [String]
  capabilities: Set<Capability>
  nativeCountdownMax: Duration?
  dpMap: Map<String,int>? // Tuya: {"switch":1,"countdown":9,...}
  defaultAutoOff: Duration?
  meta: Map<String,any>   // model, fw, gen, bridgeLightId ...
  lastSeen: DateTime
}
DeviceState { on: bool?, brightness: int?, colorTemp: int?, countdownLeft: Duration?, online: bool, at: DateTime }
TimerJob { id, deviceId, action(on|off), fireAt: DateTime, tier(native|phone), status(active|done|cancelled|failed),
           meta: Map<String,String> }   // meta holds the adapter's CountdownHandle (e.g. hue scheduleId)
Candidate { ip, mac?, brand, protocol, version?, deviceId?, name?, needsKey: bool, evidence: [String] }
Intent = Power{action, targets} | PowerFor{action, d, targets} | PowerAfter{...} | PowerAt{action, clock, targets}
       | PowerUntil{action, clock, targets} | CancelTimer{targets} | Status{targets} | Unknown{text}
TargetSpan { words: [String], all: bool, room: String?, except: [String] }
Result<T> = Ok(T) | Err(DeviceError{kind: timeout|refused|auth|protocol|unsupported|offline, msg})
```

---

## 3. Network

### 3.1 LanSocketFactory
```
class LanSocketFactory(platform):
  tcp(ip, port, timeout=1500ms):
     s = await Socket.connect(ip, port, timeout)   // on Android the whole process is bound to Wi-Fi
     s.setOption(tcpNoDelay, true); return s
  udp(bindPort=0, broadcast=false):
     s = await RawDatagramSocket.bind(anyIPv4, bindPort, reuseAddress=true)
     s.broadcastEnabled = broadcast; return s
  udpRequest(ip, port, bytes, timeout, expectMany=false):
     s = udp(); s.send(bytes, ip, port); collect replies until timeout (or first if !expectMany)
  broadcast(port, bytes, window=2s):
     if platform.isIOS and !platform.hasMulticastEntitlement: return Err(unsupported)
     platform.acquireMulticastLock()
     s = udp(broadcast=true); s.send(bytes, subnetBroadcast(), port); collect replies for window
     platform.releaseMulticastLock()
  http(method, url, body?, headers?, timeout=2000ms): HttpClient with connectionTimeout; no proxy
```

### 3.2 Android LanBindingPlugin (Kotlin)
```
init():
  req = NetworkRequest.Builder().addTransportType(TRANSPORT_WIFI)
          .removeCapability(NET_CAPABILITY_INTERNET).build()   // accept Wi-Fi even without internet
  cm.requestNetwork(req, callback{
     onAvailable(n): wifiNet = n; cm.bindProcessToNetwork(n); emit(wifiUp)
     onLost(n): if n == wifiNet: cm.bindProcessToNetwork(null); emit(wifiDown)
     onCapabilitiesChanged(n, caps): emit(internet = caps.has(NET_CAPABILITY_VALIDATED))
  })
methods: isWifiConnected, hasInternet, wifiIp, subnetPrefix (LinkProperties), acquire/releaseMulticastLock
NOTE: Dart sockets are created by the process → covered by bindProcessToNetwork. VERIFY on a real phone (T1.4).
```

### 3.3 iOS LocalNetworkPlugin (Swift)
```
requestPermission():
  browser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: nil), using: .tcp)
  browser.stateUpdateHandler: .ready → granted ; .waiting(error) with policyDenied → denied
  start; timeout 3 s → report status
Info.plist: NSLocalNetworkUsageDescription, NSBonjourServices [_hue._tcp,_shelly._tcp,_http._tcp,
  _ewelink._tcp,_esphomelib._tcp,_matter._tcp], NSAllowsLocalNetworking
```

### 3.4 NetworkMonitor
```
stream NetState{wifi, internet?, ssid, ip, prefix} from platform events (internet = null on iOS: unknowable
  without contacting the internet)
UI: internet == false && wifi == true → banner "Internet down · Local mode" (info only)
wifi == false → blocking banner "Connect to home Wi-Fi"
```

---

## 4. Registry
```
tables:
 devices(id PK, brand, protocol, ip, mac, port, name, room_id, capabilities_json, dp_map_json,
         native_countdown_max_s, default_auto_off_s, meta_json, last_seen)
 rooms(id PK, name, sort)
 aliases(id PK, device_id FK, alias, lang)        // lang: en | hi
 timer_jobs(id PK, device_id, action, fire_at, tier, status, created_at, meta_json)
 device_state_cache(device_id PK, state_json, at)
 settings(key PK, value)
SecretStore: get/set/delete("secret/<deviceId>/<name>"); names: local_key, username, password, hue_user, devicekey
DeviceRepository.upsertFromCandidate(c):
  existing = findById(c.deviceId) ?? findByMac(c.mac) ?? findByIp(c.ip)
  if existing: update ip/lastSeen/protocol version; keep name, room, aliases
  else: insert with defaults (name = c.name ?? "<Brand> <last 4 of id>")
```

---

## 5. Adapter interface
```
abstract class DeviceAdapter:
  Brand brand; Set<String> protocols
  Future<Candidate?> probe(ProbeContext ctx)               // used by Fingerprinter
  Set<Capability> capabilitiesOf(Device d)
  Future<Result<DeviceState>> getState(Device d)
  Future<Result<void>> setPower(Device d, bool on)
  Future<Result<void>> setBrightness(Device d, int pct)    // default Err(unsupported)
  Future<Result<void>> setColorTemp(Device d, int kelvin)  // default Err(unsupported)
  Duration? nativeCountdownMax(Device d)                   // null → no native countdown
  // CountdownHandle = opaque Map<String,String> the TimerService stores in TimerJob.meta
  // (e.g. Hue scheduleId, Kasa rule id); empty for devices with a single countdown DP.
  Future<Result<CountdownHandle>> setCountdown(Device d, Duration after, bool targetOn)
  Future<Result<Duration?>> getCountdown(Device d, CountdownHandle? h)
  Future<Result<void>> cancelCountdown(Device d, CountdownHandle? h)
  // Can the device's own countdown END in `endState`? Flip-based countdowns (Tuya, Shelly Gen1
  // timer, Tasmota PulseTime) can only end in !currentOn; Kasa rules carry an explicit act;
  // Yeelight cron_add can only end in off. TimerService.chooseTier() calls this.
  bool canCountdownTo(Device d, bool endState, {bool? currentOn})
  // One-shot "set now, flip back after d" (Shelly Gen1 turn+timer, Gen2 toggle_after,
  // Tasmota PulseTime, Sonoff pulse). Default false / Err(unsupported) → TimerService does
  // setPower + setCountdown itself.
  bool supportsCombinedPowerFor(Device d)
  Future<Result<CountdownHandle>> powerFor(Device d, bool on, Duration after)
  Stream<DeviceState>? watch(Device d)                     // push, if supported
  Future<void> dispose(Device d)                           // close persistent sockets

adapterContractTest(adapterFactory, simFactory):   // shared test suite, run for every adapter
  setPower(on) → getState().on == true ; setPower(off) → false
  if countdown supported: setCountdown(2s, false) after on → state off within 4 s
  getState on stopped sim → Err(offline|timeout) within timeout + 200 ms
  no call throws
```

---

## 6. Adapters

### 6.1 WiZ — ref: pywizlight
```
PORT = 38899 (UDP)
send(d, obj): udpRequest(d.ip, PORT, json(obj), timeout=1000ms) → parse JSON; retry once
probe(ctx): reply = udpRequest(ip, PORT, {"method":"getPilot","params":{}})
            if reply.method == "getPilot": mac = reply.result.mac
            cfg = send {"method":"getSystemConfig","params":{}} → moduleName (capability hints)
            return Candidate(brand=wiz, protocol="wiz", deviceId=mac, mac=mac, needsKey=false)
discoverBroadcast(): broadcast(PORT, {"method":"registration","params":{"phoneMac":"AAAAAAAAAAAA",
            "register":false,"phoneIp":"1.2.3.4","id":"1"}})     // VERIFY vs pywizlight discovery
getState: r = send getPilot → DeviceState(on=r.state, brightness=r.dimming, colorTemp=r.temp)
setPower: send {"method":"setPilot","params":{"state":on}}
setBrightness: send setPilot {"dimming": clamp(pct,10,100)}
setColorTemp: send setPilot {"temp": clamp(k,2200,6500)}                       // VERIFY range per model
nativeCountdownMax → null  (phone tier)
```

### 6.2 Tuya codec 3.1/3.3 — ref: tinytuya core
```
PREFIX=0x000055AA SUFFIX=0x0000AA99
CMD: CONTROL=0x07 STATUS=0x08 HEART_BEAT=0x09 DP_QUERY=0x0a CONTROL_NEW=0x0d DP_QUERY_NEW=0x10
     SESS_KEY_NEG_START=0x03 SESS_KEY_NEG_RESP=0x04 SESS_KEY_NEG_FINISH=0x05      // VERIFY all
encodeFrame(seq, cmd, payload):
  header = be32(PREFIX) + be32(seq) + be32(cmd) + be32(len(payload) + 8)
  body = header + payload
  return body + be32(crc32(body)) + be32(SUFFIX)
decodeFrame(bytes):  // may contain several frames; loop
  check prefix, read seq, cmd, len; payload = next (len-8) bytes; verify crc; check suffix
  replies from device start with 4-byte return code → strip if present (retcode & 0xFFFFFF00 == 0)
encryptPayload33(key, cmd, json):
  ct = aesEcbEncrypt(key, pkcs7(utf8(json)))
  if cmd in {DP_QUERY, DP_REFRESH?}: return ct                  // no version header — VERIFY
  return b"3.3" + 12*0x00 + ct
decryptPayload33(key, payload):
  if payload.startsWith(b"3.3"): payload = payload[15:]
  return json(unpad(aesEcbDecrypt(key, payload)))
3.1: CONTROL payload = b"3.1" + md5hex-signature + base64(aesEcb(json)); DP_QUERY plaintext  // VERIFY; low priority
Tuya UDP beacons: port 6666 plaintext, 6667 AES-ECB with key md5(b"yGAdlopoPVldABfn")   // VERIFY
  beacon JSON → {ip, gwId, version, productKey, encrypt}
```

### 6.3 Tuya adapter (3.1/3.3; 3.4/3.5 via codec strategy)
```
connections: Map<deviceId, TuyaConn>
TuyaConn(d):
  socket = tcp(d.ip, 6668); seq = 1; key = secrets.get(d.id, "local_key")
  codec = codecFor(d.protocolVersion)          // 3.1 | 3.3 | 3.4 | 3.5
  if codec.needsSession: codec.negotiate(socket, key)   // §6.4
  start heartbeat every 10 s (cmd HEART_BEAT, empty json); on 2 missed → reconnect with backoff
  reader loop → decode frames → if cmd==STATUS: emit dps update to watch stream
  request(cmd, json) → send frame, await reply with matching seq (timeout 1500 ms)

payloads:
  query = {"gwId":id,"devId":id,"uid":id,"t":epochSec}
  control33 = {"devId":id,"uid":id,"t":epochSec,"dps":{dp: value}}
  control34plus = {"protocol":5,"t":epochSec,"data":{"dps":{dp: value}}}   // CONTROL_NEW — VERIFY

getState:  r = request(DP_QUERY, query) → dps
           "device22" quirk (tinytuya): devices with a 22-char id ignore DP_QUERY and must be
           queried with CONTROL_NEW (0x0d) carrying {"devId","uid","t","dps":{dp:null,...}}
           for the DPs of the profile. Detect: DP_QUERY reply "data unvalid"/empty → switch
           to device22 mode and persist it in Device.meta.tuyaDevice22 = true.   // VERIFY vs tinytuya
           on = dps[dpMap.switch]; countdown = dps[dpMap.countdown]; brightness via dpMap if bulb
setPower:  request(CONTROL, control(dpMap.switch: on))
countdown: nativeCountdownMax = 86400 s if dpMap.countdown present           // VERIFY per model
setCountdown(after, targetOn):
     // Tuya countdown FLIPS the current state when it reaches 0 (VERIFY on hardware)
     state = getState()
     if state.on == targetOn: // need flip to target at end → first set opposite? No:
        // powerFor semantics handled by TimerService: it sets power first, then countdown.
        // Here: if current == target, countdown would flip AWAY from target → return Err(protocol,"state already target")
     request(CONTROL, control(dpMap.countdown: after.inSeconds))
cancelCountdown: request(CONTROL, control(dpMap.countdown: 0))
DP profiles (defaults, overridable per device, VERIFY with tinytuya scan on real device):
  plug:        switch=1, countdown=9, (power metering 17..20 ignored)
  bulb v2:     switch=20, mode=21, bright=22 (10..1000), temp=23, countdown=26
  multi-gang:  switch_n = n (1..4), countdown_n = 7..10
  auto-profile: on first successful query, inspect dps keys; pick profile; store dpMap
```

### 6.4 Tuya 3.4 / 3.5 session — ref: tinytuya (VERIFY every line)
```
3.4 negotiate(sock, localKey):
  localNonce = random(16)
  send frame(cmd=SESS_KEY_NEG_START, payload=aesEcb(localKey, localNonce), mac=hmacSha256(localKey, ...))
  resp = decrypt(localKey, frame(cmd=SESS_KEY_NEG_RESP)) → remoteNonce = resp[0:16], hmacCheck = resp[16:48]
  assert hmacCheck == hmacSha256(localKey, localNonce)
  send frame(cmd=SESS_KEY_NEG_FINISH, payload=aesEcb(localKey, hmacSha256(localKey, remoteNonce)))
  sessionKey = aesEcbEncrypt(localKey, xor(localNonce, remoteNonce))[0:16]
3.4 frames: whole payload AES-ECB(sessionKey); CRC replaced by 32-byte HMAC-SHA256(sessionKey, header+payload);
            version header "3.4"+12 zeros is inside the encrypted payload for CONTROL_NEW
3.5 frames: PREFIX=0x00006699 SUFFIX=0x00009966
            header = prefix(4) + reserved(2) + seq(4) + cmd(4) + len(4)
            body = iv(12) + AES-GCM(sessionKey, iv, aad=header[4:], plaintext) + tag(16)
            negotiation like 3.4 but using GCM; sessionKey = gcmEncrypt(localKey, iv=localNonce[:12], xor(...))[..16]
```

### 6.5 Shelly — ref: Shelly API docs, aioshelly
```
probe: GET http://ip/shelly → json; gen = json.gen ?? 1; mac = json.mac; type/model
Gen1:
  getState: GET /relay/0 → {ison, has_timer, timer_remaining}
  setPower: GET /relay/0?turn=on|off
  setCountdown(after, targetOn): GET /relay/0?turn=<!targetOn>&timer=<secs>   // timer flips back after secs
     (so for powerFor(on, d): turn=on&timer=d in ONE call — TimerService uses combined op when available)
  bulbs (SHBLB/Duo): /light/0 with brightness
Gen2+:
  getState: GET /rpc/Switch.GetStatus?id=0 → {output, timer_started_at?, timer_duration?}
  setPower: GET /rpc/Switch.Set?id=0&on=true|false
  powerFor combined: GET /rpc/Switch.Set?id=0&on=<target>&toggle_after=<secs>
auth: if 401 → digest auth with password from SecretStore (Gen2 uses digest SHA-256) // VERIFY
nativeCountdownMax: Gen1 VERIFY, Gen2 VERIFY (large)
```

### 6.6 Kasa legacy — ref: python-kasa (protocol.py / xortransport)
```
xorEncrypt(bytes): key=171; out=[]; for b in bytes: a = key ^ b; key = a; out.append(a)
xorDecrypt(bytes): key=171; out=[]; for b in bytes: a = key ^ b; key = b; out.append(a)
TCP 9999: send be32(len) + xorEncrypt(json); read be32 len then that many bytes → xorDecrypt
UDP 9999 discovery: xorEncrypt(json) without length prefix; broadcast {"system":{"get_sysinfo":{}}}
getState: {"system":{"get_sysinfo":{}}} → relay_state (plug) or light_state.on_off (bulb)
setPower plug: {"system":{"set_relay_state":{"state":1|0}}}
setPower bulb: {"smartlife.iot.smartbulb.lightingservice":{"transition_light_state":{"on_off":1|0}}}
countdown (plugs): {"count_down":{"delete_all_rules":{}}}
                   {"count_down":{"add_rule":{"enable":1,"delay":secs,"act":targetOn?1:0,"name":"offlinehome"}}}
getCountdown: {"count_down":{"get_rules":{}}} → rule.remain
```

### 6.7 KLAP (Tapo + new Kasa) — ref: python-kasa klaptransport.py (VERIFY everything)
```
authHash = sha256(sha1(email) + sha1(password))            // v2; v1 = md5(md5(email)+md5(password))
handshake():
  localSeed = random(16)
  r1 = POST http://ip/app/handshake1 body=localSeed → remoteSeed = r1[0:16], serverHash = r1[16:48]
  assert serverHash == sha256(localSeed + remoteSeed + authHash)   (try v1 hash if mismatch)
  cookie = r1.cookie TP_SESSIONID
  POST /app/handshake2 body=sha256(remoteSeed + localSeed + authHash) with cookie → 200
  key = sha256("lsk" + localSeed + remoteSeed + authHash)[0:16]
  ivBase = sha256("iv" + localSeed + remoteSeed + authHash); iv = ivBase[0:12]; seq = int32(ivBase[-4:])
  sig = sha256("ldk" + localSeed + remoteSeed + authHash)[0:28]
request(json):
  seq += 1; ivSeq = iv + be32(seq)
  ct = aesCbcEncrypt(key, ivSeq, pkcs7(json))
  body = sha256(sig + be32(seq) + ct) + ct
  POST /app/request?seq=<seq> body with cookie → decrypt resp[32:] with same ivSeq
  on 403/session expiry → handshake() and retry once
Tapo methods: get_device_info, set_device_info {"device_on":bool}, countdown: VERIFY method names
Kasa-new: same transport, legacy JSON payloads inside
discovery: UDP 20002 query packet — VERIFY bytes from python-kasa
```

### 6.8 Hue bridge — ref: Hue API v1 docs
```
probe: mDNS _hue._tcp → ip; GET http://ip/api/config → bridgeid, name
pair(): loop 30 s: POST /api {"devicetype":"offlinehome#phone"} → [{"success":{"username":u}}] or error 101
        → secrets.set(bridgeId, "hue_user", u)
list lights: GET /api/u/lights → each light becomes a Device(meta.bridgeLightId)
getState: GET /api/u/lights/<id> → state.on, state.bri(1..254), state.ct
setPower: PUT /api/u/lights/<id>/state {"on":bool}
setBrightness: {"bri": round(pct*2.54)}
setCountdown(after, targetOn): POST /api/u/schedules {"name":"oh-<jobId>","command":{"address":
   "/api/u/lights/<id>/state","method":"PUT","body":{"on":targetOn}},"localtime":"PT<hh:mm:ss>","autodelete":true}
   store scheduleId in TimerJob.meta
cancelCountdown: DELETE /api/u/schedules/<scheduleId>
nativeCountdownMax: 23:59:59 (PT format)
```

### 6.9 Yeelight — ref: python-yeelight
```
TCP 55443, newline-delimited JSON: {"id":n,"method":m,"params":[...]}\r\n
probe: TCP connect 55443 + get_prop ["power"] reply ok
discovery (Android only): M-SEARCH to 239.255.255.250:1982 "wifi_bulb"
getState: get_prop ["power","bright","ct"]
setPower: set_power ["on"|"off","smooth",300]
setCountdown(after, targetOn=false): cron_add [0, minutes]     // only "off after" supported, minute resolution
targetOn=true → Err(unsupported) → phone tier
cancel: cron_del [0]
note: device must have "LAN Control" enabled in Yeelight app — show hint on probe failure
```

### 6.10 Sonoff LAN — ref: AlexxIT/SonoffLAN
```
probe: mDNS _ewelink._tcp → TXT: id, type, encrypt, data1..dataN, seq
DIY (encrypt=false): POST http://ip:8081/zeroconf/switch {"deviceid":id,"data":{"switch":"on"}}
                     POST /zeroconf/info → state
encrypted: data = base64(aesCbc(md5(devicekey), iv=random16, pkcs7(json))); body adds "encrypt":true,"iv":b64(iv)
           TXT data fields decrypted the same way for state                       // VERIFY
countdown: /zeroconf/pulse {"pulse":"on","pulseWidth":ms} = inching (auto-off) → powerFor(on) only; VERIFY max
```

### 6.11 Tasmota — ref: Tasmota commands docs
```
probe: GET http://ip/cm?cmnd=Status%200 → json.Status, StatusNET.Mac
getState: GET /cm?cmnd=Power → {"POWER":"ON"}
setPower: GET /cm?cmnd=Power%20On|Off
powerFor(on, d): GET /cm?cmnd=Backlog%20PulseTime%20<d.s+100>%3BPower%20On     // PulseTime >111 = secs+100
     after fire: reconcile sets PulseTime 0 so later "on" is not auto-off         // VERIFY behaviour
powerAfter → phone tier
```

### 6.12 ESPHome (web server) — ref: ESPHome web_server REST docs
```
probe: mDNS _esphomelib._tcp; GET http://ip/ → server header / events endpoint
entities from user config (v1: user enters entity id, e.g. switch/relay) — VERIFY listing endpoint
getState: GET /switch/<id> → {"state":"ON"}
setPower: POST /switch/<id>/turn_on|turn_off
nativeCountdownMax → null (phone tier)
```

---

## 7. Discovery

### 7.1 Collectors
```
scan(timeout=6s):
  net = platform.netInfo()          // ip, prefix
  results = mergeByIp(await all([
     mdnsBrowse(["_hue._tcp","_shelly._tcp","_http._tcp","_ewelink._tcp","_esphomelib._tcp"], 4s),
     listenUdp([6666, 6667], 6s),                 // Tuya beacons (Android; iOS best effort)
     broadcastOrUnicast(38899, wizProbe),         // iOS → unicast to every host in /24
     broadcastOrUnicast(9999, kasaSysinfoXor),
     broadcastOrUnicast(20002, klapDiscovery),    // VERIFY packet
     androidOnly(ssdpYeelight()),
     tcpPortScan(hosts(net), ports=[6668, 9999, 80, 8081, 55443, 6053], concurrency=64, timeout=300ms),
  ]))
  candidates = []
  for hostEvidence in results: c = Fingerprinter.identify(hostEvidence); if c: candidates.add(c)
  also: for each registry device not seen → quick targeted probe at last IP; if gone → mark offline
  return candidates

broadcastOrUnicast(port, payload):
  if platform.canBroadcast: return broadcast(port, payload)
  else: return parallel(hosts(net), h → udpRequest(h, port, payload, 400ms), concurrency=64)
```

### 7.2 Fingerprinter (first match wins)
```
identify(e: HostEvidence{ip, openPorts, mdns[], udpReplies{port→payload}, http{path→resp}}):
  if e.udpReplies[6666|6667] (Tuya beacon for this ip) → tuya, version from beacon, deviceId=gwId, needsKey=!hasKey(gwId)
  if e.udpReplies[38899].method == "getPilot" → wiz
  if e.mdns has _hue._tcp → hue bridge (needsPairing unless hue_user stored)
  if e.mdns has _shelly._tcp or http["/shelly"].type → shelly (gen from payload)
  if e.mdns has _ewelink._tcp → sonoff (needsKey if encrypt==true && !hasKey)
  if e.mdns has _esphomelib._tcp → esphome
  if e.udpReplies[9999] decodes as sysinfo → kasa legacy
  if e.udpReplies[20002] → klap (tapo/kasa) needsKey=!hasCredentials
  if 55443 open and yeelight get_prop ok → yeelight
  if http["/cm?cmnd=Status 0"].Status → tasmota
  if 6668 open → tuya (unknown version; try 3.3 then 3.4 then 3.5 once key present), needsKey=true
  if 80 open and nothing matched → unknown (show "Unknown device at <ip>")
  else → null
```

---

## 8. CommandEngine
```
class CommandEngine:
  queues: Map<deviceId, SerialQueue>
  power(targets, action):
    return parallel(targets, d → queues[d.id].run(() → powerOne(d, action)))
  powerOne(d, action):
    adapter = registry.adapterFor(d)
    desired = action == toggle ? !(cache[d.id]?.on ?? false) : action == on
    emitOptimistic(d, on=desired)
    r = retry(times=2, backoff=[150ms, 400ms], () → adapter.setPower(d, desired))
    if r is Err: revertOptimistic(d); return r
    s = await adapter.getState(d) (timeout 800ms, ignore error)
    cache(d, s ?? optimistic)
    return Ok
  status(targets): parallel getState, refresh cache
  aggregate(results) → {ok: [...], failed: [(device, error)]} for feedback
```

## 9. StatePoller
```
onAppForeground: for each device: if adapter.watch(d) → subscribe; else schedule poll every 5 s
onAppBackground: cancel polls; keep push sockets for 30 s then dispose
poll(d): s = adapter.getState(d); if Err(timeout|offline) x2 → mark offline (tile greyed)
```

---

## 10. TimerService
```
powerFor(targets, action, d):        // "on for 20 min" → on now, back off after d
  for dev in targets:
    target = action == on
    if adapter.supportsCombinedPowerFor(dev) and d <= adapter.nativeCountdownMax(dev):
       adapter.powerFor(dev, target, d) → tier native (store returned handle in job.meta)
    else:
      engine.powerOne(dev, target)
      tier = chooseTier(dev, d, endState = !target)
      schedule(dev, endState = !target, d, tier)
powerAfter(targets, action, d):      // "on after 20 min" / "off at 11 pm"
  for dev: schedule(dev, endState = (action == on), d, chooseTier(dev, d, endState))

chooseTier(dev, d, endState):
  max = adapter.nativeCountdownMax(dev)
  if max != null and d <= max and adapter.canCountdownTo(dev, endState, currentOn: cache[dev.id]?.on): return native
  return phone

schedule(dev, endState, d, tier):
  cancelExisting(dev)                                  // one active timer per device
  if tier == native:
     // flip-based countdowns (Tuya, Shelly, Kasa act-less): device must currently be !endState
     r = adapter.setCountdown(dev, d, endState)
     if r is Err: tier = phone (fall through)
  if tier == phone:
     if Android: platform.scheduleExactAlarm(jobId, fireAt = now + d)
     if iOS: localNotification(fireAt, "Open the app to run: <dev> <endState>"); foregroundTicker.add(job)
  db.insert(TimerJob(dev.id, endState, now + d, tier, active))
  return (tier, fireAt)

onAlarm(jobId)  [Android background isolate]:
  job = db.get(jobId); if job.status != active: return
  r = engine.powerOne(device(job), job.action)
  job.status = r is Ok ? done : failed; notify on failure

cancel(targets): for each active job: native → adapter.cancelCountdown; phone → cancel alarm; status=cancelled
reconcile():
  for job in active jobs:
    if job.fireAt < now - 1 min: job.status = done (verify state if device online)
    elif job.tier == native: left = adapter.getCountdown(dev); if left == null/0 and fireAt > now + 30s → failed/cancelled externally
untilNext(clock): next occurrence of clock after now (today or tomorrow); ambiguity rules in §11.4
```

---

## 11. Voice

### 11.1 SttService
```
capabilities(): {onDeviceAvailable, locales[]}   // speech_to_text: locales(); VERIFY on-device flag per platform
listen(onDevice=true, locale, contextual):
  if !onDeviceAvailable: return Err("offline speech model missing") → UI shows download steps
  start recognizer(onDevice: true, partialResults: true, listenFor: 8s, pauseFor: 1.2s,
                   localeId: locale, contextualStrings: contextual (iOS) )
  return best final transcript (+ alternatives if provided)
Android fallback (if platform on-device unavailable): Vosk small en-in model with grammar =
  vocabulary from lexicons + device names  // VERIFY vosk_flutter API
```

### 11.2 Normaliser
```
normalise(s):
  s = lower(s); s = transliterateDevanagari(s)        // table: बंद→band, चालू→chalu, लाइट→light, पंखा→pankha, ...
  s = replace punctuation with space; collapse spaces
  s = applyVariants(s)   // bandh|bundh|bund→band ; chaalu|chalu|chaloo→chalu ; kar do|kardo|karo→karo ;
                         // minit|mint|minat→minute ; ghanta|ghante|ghanton→ghanta ; geezer|gizer→geyser
  s = removeFillers(s)   // please, zara, na, yaar, ji, jaldi, hey, ok, the, a
  AMBIGUITY RULES (Hinglish words that are also number/relation words):
    "do"   → verb suffix when the previous token is a verb stem (kar, jala, bujha, chala, rok,
             hata, band, chalu, on, off); number 2 only when followed by a unit
             (minute|ghanta|ghante|second|baje) or preceded by a relation word.
             Rewrite "<stem> do" → "<stem>o"/"<stem> karo" BEFORE numberWordsToDigits.
    "saath"→ 60 only when followed by a unit; otherwise "with" (drop).
    "in", "mein", "pe", "par" → relation (after / at) only when adjacent to a duration or clock
             span; otherwise a location preposition (part of the target span: "bedroom mein").
    "tak"  → until only when adjacent to a clock span; "tak ke liye" → for.
  Each rule gets corpus cases (T4.7).
  s = numberWordsToDigits(s)   // en: one..hundred; hi: ek do teen char chaar paanch chhe saat aath nau das
                               // gyarah barah terah chaudah pandrah solah satrah atharah unnis bees ...
                               // tees chalees pachaas saath(when followed by minute/second) sattar assi nabbe sau
  s = fractionWords(s)   // aadha|adha→0.5 ; dedh→1.5 ; dhai|dhaai→2.5 ; sava X→X+0.25 ; saadhe X→X+0.5 ; paune X→X-0.25
  return tokens
```

### 11.3 Lexicon (assets/voice/*.yaml)
```
actions:
  on:     [turn on, switch on, start, on, chalu, chalu karo, on karo, jalao, jala do, shuru karo, chala do, chalao]
  off:    [turn off, switch off, stop, off, band, band karo, off karo, bujhao, bujha do, rok do, bandh kar do]
  toggle: [toggle, switch]
  cancel: [cancel timer, stop timer, remove timer, timer hatao, timer band karo, timer cancel]
  status: [is, status, on hai kya, off hai kya, chal raha hai kya, kya chal raha]
relations:
  for:   [for, ke liye, tak ke liye]
  until: [until, till, tak]
  after: [after, in, baad, mein]           // "10 minute mein" = after 10 min
  at:    [at, baje, pe, par]
dayparts: {subah: am, morning: am, dopahar: pm(12-16), shaam: pm, evening: pm, raat: pm (1-4 → am), night: pm}
nouns (alias seeds): light→[batti, lights, bulb], fan→[pankha], geyser→[water heater, heater], ac→[a c, a.c.]
quantifiers: all→[all, everything, sab, sabhi, saari, saare], except→[except, but, other than, chhod ke, ke alawa]
```

### 11.4 Duration and time parsing
```
parseDuration(tokens): patterns
  <n> (minute|min|minutes|mins) → n min ; <n> (hour|hours|hr|ghanta) → n h ; <n> (second|sec|seconds)
  <h> hour <m> (minute)? ; "<h> ghante <m> minute" ; "half an hour" → 30 min ; "quarter hour" → 15
  bare fraction + ghanta ("dedh ghanta") → 90 min
parseClock(tokens):
  "HH:MM", "H MM", "H (am|pm)", "H baje", "daypart H baje", "saadhe H baje", "sava H", "paune H"
  hour12 without daypart → next future occurrence within 12 h (e.g. at 20:00 "11" → 23:00)
  raat 1..4 → AM next day ; subah 12 → reject/ask
returns Duration | ClockTime | null and the token span consumed
```

### 11.5 IntentParser
```
parse(text):
  t = normalise(text)
  if match(t, cancel): return CancelTimer(targets = span(t - cancelWords))
  if match(t, status) and !match(t, action-with-karo): return Status(span)
  action = findAction(t)                        // longest match first ("band karo" before "band")
  if !action: return Unknown(text)
  d = parseDuration(t); c = parseClock(t); rel = findRelation(t)
  targets = extractTargetSpan(t minus action/duration/clock/relation tokens)
  switch:
    d and rel in {for}                  → PowerFor(action, d)
    d and rel in {after}                → PowerAfter(action, d)
    d and no rel                        → PowerFor(action, d)        // "geyser on 20 minute" 
    c and rel == until                  → PowerUntil(action, c)      // "AC 11 baje tak chalao"
    c                                   → PowerAt(action, c)
    else                                → Power(action)
  if targets empty → Unknown ("which device?") → UI asks
examples (all must be in golden corpus):
  "turn on geyser for 20 minutes"          → PowerFor(on, 20m, [geyser])
  "geyser 20 minute ke liye chalu karo"    → PowerFor(on, 20m, [geyser])
  "AC band karo 11 baje"                   → PowerAt(off, 23:00, [ac])
  "AC 11 baje tak chalao"                  → PowerUntil(on, 23:00, [ac])
  "turn off all lights except bedroom"     → Power(off, all lights, except bedroom)
  "sab batti band karo bedroom ke alawa"   → same
  "10 minute baad fan band kar do"         → PowerAfter(off, 10m, [fan])
  "is the geyser on"                       → Status([geyser])
  "geyser ka timer hatao"                  → CancelTimer([geyser])
```

### 11.6 TargetResolver
```
resolve(span):
  devices = registry.all()
  if span.all:
     pool = span.room ? devicesIn(span.room) : devices
     pool = filterByNoun(pool, span.words)            // "all lights" → devices whose name/alias/category is light
     pool -= resolveMany(span.except)
     return pool
  room = matchRoom(span.words)                        // "bedroom ki light" → room=bedroom, rest="light"
  scored = for d in (room ? devicesIn(room) : devices):
       names = [d.name] + d.aliases
       score = max over names of 0.6*jaroWinkler(phrase, n) + 0.4*phoneticEq(doubleMetaphone(phrase), doubleMetaphone(n))
  best = top(scored)
  if best.score < 0.6 → none ; if best.score < 0.8 or second within 0.05 → ambiguous(top 3)
  if noun is plural ("lights", "batiyan", "saari") and room → return all matches in room above 0.7
```

### 11.7 VoiceController
```
see §0.2; plus:
needsConfirmation(intent, targets): intent affects > 5 devices, or ambiguous, or action on device flagged "confirm"
feedback: tts.speak(short) if settings.tts; toast with Undo (reverts power for 5 s, cancels created timers)
error phrases: offline device → "<name> is not responding"; unsupported timer on iOS → explain phone tier
```

---

## 12. Onboarding and key import (the only internet code)

### 12.1 devices.json import (tinytuya wizard output)
```
file = pickFile(json)
for entry in json: {id, name, key, ip?, version?, mapping?}
   dev = registry.findById(entry.id) ?? create placeholder(brand=tuya, name=entry.name)
   secrets.set(entry.id, "local_key", entry.key)
   if entry.mapping: derive dpMap from mapping codes (switch_1, countdown_1, bright_value ...)
   if entry.version: dev.protocol = "tuya-" + version
then trigger quick probe to fill ip/version; show result per device (ok | key rejected)
never persist the file; wipe from temp storage
```

### 12.2 Manual key entry
```
device detail → "Enter local key" → validate length (16 chars) → try getState → ok/rejected
```

### 12.3 Tuya OpenAPI import (later in M6) — ref: Tuya OpenAPI signing docs (VERIFY)
```
inputs: accessId, accessSecret, region endpoint, (linked app account uid discovered via API)
token = GET /v1.0/token?grant_type=1  (signed)
devices = GET /v1.0/users/<uid>/devices  or /v1.0/iot-01/associated-users/devices (VERIFY)
each device has local_key → same as 12.1
sign = HMAC-SHA256(secret, clientId + [accessToken] + t + nonce + stringToSign).upper()   // VERIFY exact format
```

### 12.4 Tapo / KLAP credentials
```
prompt email + password once → secrets.set("tplink", "email"/"password") → test handshake on one device
```

### 12.5 Hue pairing
```
show "Press the round button on the bridge" + 30 s countdown → HueAdapter.pair() → import lights
```

---

## 13. UI state (riverpod)
```
devicesProvider        = stream from db (joined with state cache)
roomsProvider          = stream from db
netStateProvider       = NetworkMonitor.stream
timersProvider         = stream of active TimerJobs with remaining time (1 s ticker)
voiceStateProvider     = idle | listening(partial) | parsing | confirming(options) | result(msg)
scanProvider           = scanning(progress, candidates) | done(candidates)
HomeScreen: rooms as sections, DeviceTile(onTap → engine.power(toggle), onLongPress → detail)
DeviceTile shows: name, on/off, offline grey, small timer chip "off in 18m (plug)"
```

---

## 14. Simulators (`sim/`, Python asyncio)
```
class SimDevice: host="127.0.0.1", port, state={on: False,...}, countdown_task=None
  start(), stop(); tests can inspect/mutate state

WizSim(udp 38899 or custom): handle getPilot / setPilot / getSystemConfig / registration → JSON replies
TuyaSim(version, local_key, dp_map, tcp 6668 or custom):
   implement frame decode/encode using a Python reference (tinytuya is allowed as a TEST dependency)
   DP_QUERY → dps ; CONTROL → update dps, push STATUS frame ; countdown dp → asyncio task flips switch at 0
   optional UDP beacon sender (6667 encrypted)
ShellySim(gen): aiohttp routes /shelly, /relay/0, /rpc/Switch.*
KasaSim: TCP 9999 XOR framing, sysinfo, set_relay_state, count_down rules
KlapSim: aiohttp handshake1/2/request (port python-kasa test fixtures)
HueSim: aiohttp /api, /api/config, /api/<u>/lights, /schedules (link button toggled by test)
YeelightSim, SonoffSim, TasmotaSim, EspHomeSim: minimal HTTP/TCP handlers per §6

sim/run.py --devices wiz,tuya33:key=0123456789abcdef,shelly2 --base-port 20000
  prints a JSON map {name: {protocol, host, port, id}} used by Flutter integration tests
Flutter integration tests: start sims via Process.start(python sim/run.py ...) and point adapters at 127.0.0.1:<port>
```
