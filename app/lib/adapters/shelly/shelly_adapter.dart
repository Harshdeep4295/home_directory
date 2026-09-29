import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../core/models.dart';
import '../../core/result.dart';
import '../../net/lan_socket_factory.dart';
import '../../registry/secret_store.dart';
import '../device_adapter.dart';

/// Shelly relays, Gen1 (REST) and Gen2+ (JSON-RPC), over plain HTTP on the LAN.
/// Ported from aioshelly 13.34.0 + the Shelly API docs (PLAN §6, PSEUDOCODE §6.5):
/// - GET /shelly (common.get_info) identifies gen, mac, auth.
/// - Gen1: GET `relay/<ch>?turn=on|off[&timer=s]` (block_device Block.set_state); `timer`
///   is a one-shot flip-back timer. Password → HTTP Basic (common.encode_basic_auth).
/// - Gen2+: JSON-RPC frame (rpc_device/wsrpc.py RPCCall.build_request_frame) POSTed to
///   /rpc; Switch.GetStatus / Switch.Set {on, toggle_after}. Password → digest `auth`
///   object computed like wsrpc.AuthData. VERIFY: devices accept the in-frame auth over
///   HTTP POST as they do over the websocket (aioshelly only authenticates via WS).
/// Countdowns flip the relay, so they can only end in the opposite of the current state.
class ShellyAdapter extends DeviceAdapter {
  ShellyAdapter(
    this._sockets,
    this._secrets, {
    this.timeout = LanSocketFactory.defaultTimeout,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  static const _tag = 'shelly';

  /// aioshelly: DEFAULT_HTTP_PORT = 80.
  static const port = 80;

  /// Shelly's fixed RPC/basic-auth user name (aioshelly ConnectionOptions default).
  static const username = 'admin';

  /// VERIFY per model: longest Gen1 `timer` / Gen2 `toggle_after` accepted.
  static const countdownMax = Duration(hours: 24);

  final LanSocketFactory _sockets;
  final SecretStore _secrets;
  final Duration timeout;
  final DateTime Function() _now;
  final Random _random;
  final Map<String, ShellyDigest> _digests = {};
  int _rpcId = 0;

  @override
  Brand get brand => Brand.shelly;

  @override
  Set<String> get protocols => {'shelly'};

  static bool isGen2(Device d) => d.protocol != 'shelly-gen1';

  static int channelOf(Device d) => (d.meta['channel'] as num?)?.toInt() ?? 0;

  Uri _url(Device d, String path, [Map<String, String>? q]) => Uri(
    scheme: 'http',
    host: d.ip,
    port: d.port ?? port,
    path: path,
    queryParameters: q,
  );

  @override
  Future<Candidate?> probe(ProbeContext ctx) async {
    final r = await _sockets.http(
      'GET',
      Uri(scheme: 'http', host: ctx.ip, port: port, path: '/shelly'),
      timeout: ctx.timeout,
    );
    final j = r.valueOrNull?.json;
    if (j is! Map || !(j.containsKey('type') || j['gen'] is num)) return null;
    final gen = (j['gen'] as num?)?.toInt() ?? 1;
    // Same normalisation as Fingerprinter._normMac (device id = MAC).
    final mac = (j['mac'] as String?)
        ?.replaceAll(RegExp('[:-]'), '')
        .toLowerCase();
    return Candidate(
      ip: ctx.ip,
      mac: mac,
      brand: Brand.shelly,
      protocol: gen >= 2 ? 'shelly-gen2' : 'shelly-gen1',
      version: '$gen',
      deviceId: mac,
      name: (j['name'] ?? j['type'] ?? j['model']) as String?,
      needsKey: j['auth'] == true || j['auth_en'] == true,
      evidence: ['http /shelly gen $gen'],
    );
  }

  // ------------------------------------------------------------------ Gen1

  Future<Result<Map<String, Object?>>> _gen1(
    Device d,
    Map<String, String> query,
  ) async {
    final pw = await _secrets.get(d.id, SecretName.password);
    final r = await _sockets.http(
      'GET',
      _url(d, '/relay/${channelOf(d)}', query.isEmpty ? null : query),
      headers: {
        if (pw != null)
          'Authorization':
              'Basic ${base64.encode(utf8.encode('$username:$pw'))}',
      },
      timeout: timeout,
    );
    return switch (r) {
      Err(:final error) => Err(error),
      Ok(value: final res) when res.status == 401 => Err(
        DeviceError.auth(
          pw == null ? 'shelly: password required' : 'shelly: wrong password',
        ),
      ),
      Ok(value: final res) when res.status != 200 => Err(
        DeviceError.protocol('shelly: HTTP ${res.status}'),
      ),
      Ok(value: final res) => switch (res.json) {
        final Map<String, Object?> m => Ok(m),
        _ => Err(DeviceError.protocol('shelly: not JSON')),
      },
    };
  }

  DeviceState _gen1State(Map<String, Object?> st) {
    final left = st['timer_remaining'];
    return DeviceState(
      on: st['ison'] as bool?,
      countdownLeft: st['has_timer'] == true && left is num && left > 0
          ? Duration(seconds: left.toInt())
          : null,
      at: _now(),
    );
  }

  // ------------------------------------------------------------------ Gen2

  /// One JSON-RPC call; on a 401 challenge computes the digest and retries once.
  Future<Result<Map<String, Object?>>> rpc(
    Device d,
    String method, [
    Map<String, Object?>? params,
  ]) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final digest = _digests[d.id];
      final frame = <String, Object?>{
        'id': ++_rpcId,
        'src': 'offline_home',
        'method': method,
        'params': ?params,
        if (digest != null) 'auth': digest.next(_cnonce()),
      };
      final r = await _sockets.http(
        'POST',
        _url(d, '/rpc'),
        body: utf8.encode(jsonEncode(frame)),
        headers: {'Content-Type': 'application/json'},
        timeout: timeout,
      );
      if (r case Err(:final error)) return Err(error);
      final res = (r as Ok<HttpReply>).value;
      Object? json;
      try {
        json = res.json;
      } on FormatException {
        json = null; // e.g. a plain-text HTTP 401 page
      }
      if (json is Map<String, Object?> && json['result'] is Map) {
        return Ok((json['result']! as Map).cast<String, Object?>());
      }
      final err = json is Map ? json['error'] : null;
      final code = err is Map ? err['code'] : res.status;
      if (code != 401) {
        return Err(
          DeviceError.protocol(
            'shelly: $method failed (${err is Map ? err['message'] : 'HTTP ${res.status}'})',
          ),
        );
      }
      // 401: challenge JSON in error.message (as aioshelly wsrpc parses it).
      final pw = await _secrets.get(d.id, SecretName.password);
      if (pw == null) return Err(DeviceError.auth('shelly: password required'));
      if (attempt == 1) return Err(DeviceError.auth('shelly: wrong password'));
      final Object? challenge;
      try {
        challenge = jsonDecode((err as Map)['message'] as String);
      } on Object {
        return Err(DeviceError.auth('shelly: unreadable auth challenge'));
      }
      if (challenge is! Map<String, Object?>) {
        return Err(DeviceError.auth('shelly: unreadable auth challenge'));
      }
      final realm = challenge['realm'] as String? ?? d.id;
      try {
        _digests[d.id] = ShellyDigest(realm, username, pw)
          ..updateChallenge(challenge);
      } on FormatException catch (e) {
        return Err(DeviceError.auth('shelly: ${e.message}'));
      }
    }
    return Err(DeviceError.auth('shelly: authentication failed'));
  }

  /// wsrpc.AuthData.get_auth: base64 of 16 random bytes.
  String _cnonce() =>
      base64.encode(List<int>.generate(16, (_) => _random.nextInt(256)));

  DeviceState _gen2State(Map<String, Object?> st) {
    final started = st['timer_started_at'];
    final dur = st['timer_duration'];
    Duration? left;
    if (started is num && dur is num) {
      // VERIFY: device clock vs phone clock (offline Shellys may not have NTP time).
      final end = DateTime.fromMillisecondsSinceEpoch(
        ((started + dur) * 1000).round(),
      );
      final d = end.difference(_now());
      if (d > Duration.zero) left = d;
    }
    return DeviceState(
      on: st['output'] as bool?,
      countdownLeft: left,
      at: _now(),
    );
  }

  // ------------------------------------------------------------------ interface

  @override
  Future<Result<DeviceState>> getState(Device d) =>
      guarded(_tag, 'getState', () async {
        if (isGen2(d)) {
          return (await rpc(d, 'Switch.GetStatus', {
            'id': channelOf(d),
          })).map(_gen2State);
        }
        return (await _gen1(d, const {})).map(_gen1State);
      });

  Future<Result<void>> _set(Device d, bool on, {Duration? flipAfter}) =>
      guarded(_tag, 'set', () async {
        if (isGen2(d)) {
          return (await rpc(d, 'Switch.Set', {
            'id': channelOf(d),
            'on': on,
            if (flipAfter != null) 'toggle_after': flipAfter.inSeconds,
          })).map((_) {});
        }
        return (await _gen1(d, {
          'turn': on ? 'on' : 'off',
          if (flipAfter != null) 'timer': '${flipAfter.inSeconds}',
        })).map((_) {});
      });

  @override
  Future<Result<void>> setPower(Device d, bool on) => _set(d, on);

  @override
  Duration? nativeCountdownMax(Device d) => countdownMax;

  @override
  bool canCountdownTo(Device d, bool endState, {bool? currentOn}) =>
      currentOn != null && currentOn != endState;

  /// Keep the current state and flip to [targetOn] after [after] (Gen1 turn+timer,
  /// Gen2 Switch.Set + toggle_after).
  @override
  Future<Result<CountdownHandle>> setCountdown(
    Device d,
    Duration after,
    bool targetOn,
  ) async {
    final s = await getState(d);
    if (s case Err(:final error)) return Err(error);
    final on = (s as Ok<DeviceState>).value.on;
    if (on == targetOn) {
      return Err(
        DeviceError.protocol(
          'already ${targetOn ? 'on' : 'off'}: countdown flips',
        ),
      );
    }
    return (await _set(
      d,
      !targetOn,
      flipAfter: after,
    )).map((_) => const <String, String>{});
  }

  @override
  Future<Result<Duration?>> getCountdown(Device d, CountdownHandle? h) async =>
      (await getState(d)).map((s) => s.countdownLeft);

  /// Re-sends the current state without a timer. VERIFY on hardware that this clears a
  /// running Gen1 `timer` / Gen2 `toggle_after`.
  @override
  Future<Result<void>> cancelCountdown(Device d, CountdownHandle? h) async {
    final s = await getState(d);
    if (s case Err(:final error)) return Err(error);
    final on = (s as Ok<DeviceState>).value.on;
    if (on == null) return Err(DeviceError.protocol('shelly: state unknown'));
    return _set(d, on);
  }

  @override
  bool supportsCombinedPowerFor(Device d) => true;

  @override
  Future<Result<CountdownHandle>> powerFor(
    Device d,
    bool on,
    Duration after,
  ) async => (await _set(
    d,
    on,
    flipAfter: after,
  )).map((_) => const <String, String>{});

  @override
  Future<void> dispose(Device d) async => _digests.remove(d.id);

  @override
  Future<void> disposeAll() async => _digests.clear();
}

/// aioshelly rpc_device/wsrpc.py AuthData: SHA-256 digest carried in the RPC frame.
///   ha1 = sha256("user:realm:password"), ha2 = sha256("dummy_method:dummy_uri"),
///   response = sha256("ha1:nonce:nc:cnonce:auth:ha2"); nc increments per call.
class ShellyDigest {
  ShellyDigest(this.realm, this.username, String password)
    : _ha1 = _hex('$username:$realm:$password');

  final String realm;
  final String username;
  final String _ha1;
  static final _ha2 = _hex('dummy_method:dummy_uri');

  Object? _nonce;
  int _nc = 0;

  static String _hex(String s) => sha256.convert(utf8.encode(s)).toString();

  /// update_challenge: only SHA-256 is supported; `nc` may arrive as a string.
  void updateChallenge(Map<String, Object?> c) {
    if (c['algorithm'] != 'SHA-256') {
      throw FormatException('unsupported auth algorithm ${c['algorithm']}');
    }
    _nonce = c['nonce'];
    _nc = int.tryParse('${c['nc'] ?? 1}') ?? 1;
  }

  Map<String, Object?> next(String cnonce) {
    final response = _hex('$_ha1:$_nonce:$_nc:$cnonce:auth:$_ha2');
    final out = {
      'realm': realm,
      'username': username,
      'nonce': _nonce,
      'nc': _nc,
      'cnonce': cnonce,
      'response': response,
      'algorithm': 'SHA-256',
    };
    _nc++;
    return out;
  }
}
