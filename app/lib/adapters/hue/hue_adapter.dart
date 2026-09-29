import 'dart:convert';

import '../../core/models.dart';
import '../../core/result.dart';
import '../../net/lan_socket_factory.dart';
import '../../registry/secret_store.dart';
import '../device_adapter.dart';

/// Philips Hue lights behind a bridge, local REST API v1 over HTTP.
/// Ported from aiohue 4.9.0: util.create_app_key (POST /api {"devicetype"}),
/// util.normalize_bridge_id, errors.ERRORS (1 unauthorized, 101 link button),
/// v1 HueBridgeV1.request (`http://<bridge>/api/<key>/<endpoint>`), v1 lights.Light.set_state
/// ({"on","bri","ct"}); discovery.is_hue_bridge (GET /api/config → bridgeid).
/// Timers: bridge schedules with a "PT hh:mm:ss" localtime (Hue API docs; not in aiohue —
/// VERIFY on a real bridge). They carry the target state, so any end state works.
///
/// Every light is an app device: id `<bridgeId>-<lightId>`, meta {hueBridge, hueLight};
/// the bridge username lives in SecretStore under the bridge id ([SecretName.hueUser]).
class HueAdapter extends DeviceAdapter {
  HueAdapter(
    this._sockets,
    this._secrets, {
    this.timeout = LanSocketFactory.defaultTimeout,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const _tag = 'hue';

  /// Hue API docs: devicetype `<application_name>#<devicename>`.
  static const deviceType = 'offline_home#phone';

  /// aiohue errors.ERRORS
  static const errUnauthorized = 1;
  static const errLinkButton = 101;

  /// Hue v1 light state ranges (Hue API docs "Lights API"): bri 1..254, ct 153..500 mired.
  static const briMax = 254;
  static const ctMin = 153;
  static const ctMax = 500;

  /// "PT hh:mm:ss" timers: VERIFY the bridge's upper limit.
  static const countdownMax = Duration(hours: 23, minutes: 59, seconds: 59);

  final LanSocketFactory _sockets;
  final SecretStore _secrets;
  final Duration timeout;
  final DateTime Function() _now;

  @override
  Brand get brand => Brand.hue;

  @override
  Set<String> get protocols => {'hue'};

  static String bridgeOf(Device d) => (d.meta['hueBridge'] as String?) ?? d.id;
  static String lightOf(Device d) => '${d.meta['hueLight'] ?? '1'}';
  static String lightDeviceId(String bridge, String light) => '$bridge-$light';

  /// aiohue util.normalize_bridge_id.
  static String normalizeBridgeId(String id) {
    final b = id.toLowerCase();
    if (b.length == 17 && ':'.allMatches(b).length == 5) {
      return b.replaceAll(':', '');
    }
    if (b.length == 16 && b.substring(6, 10) == 'fffe') {
      return b.substring(0, 6) + b.substring(10);
    }
    return b;
  }

  /// `[{"success": {key: value}}]` → value.
  static Object? _success(Object? j, String key) {
    if (j is! List || j.isEmpty) return null;
    final first = j.first;
    final ok = first is Map ? first['success'] : null;
    return ok is Map ? ok[key] : null;
  }

  Uri _uri(String host, int? port, String path) =>
      Uri(scheme: 'http', host: host, port: port ?? 80, path: path);

  Future<Result<Object?>> _json(
    String method,
    Uri url, [
    Map<String, Object?>? body,
  ]) async {
    final r = await _sockets.http(
      method,
      url,
      body: body == null ? null : utf8.encode(jsonEncode(body)),
      headers: body == null ? null : {'Content-Type': 'application/json'},
      timeout: timeout,
    );
    if (r case Err(:final error)) return Err(error);
    final res = (r as Ok<HttpReply>).value;
    if (res.status != 200) {
      return Err(DeviceError.protocol('hue: HTTP ${res.status}'));
    }
    try {
      final j = res.json;
      // v1 errors come as [{"error": {"type", "description"}}].
      if (j is List && j.isNotEmpty && j.first is Map) {
        final err = (j.first as Map)['error'];
        if (err is Map) {
          final type = err['type'];
          final desc = err['description'] ?? 'error $type';
          return Err(switch (type) {
            errUnauthorized => DeviceError.auth('hue: $desc'),
            errLinkButton => DeviceError.auth('hue: $desc'),
            _ => DeviceError.protocol('hue: $desc'),
          });
        }
      }
      return Ok(j);
    } on FormatException {
      return Err(DeviceError.protocol('hue: not JSON'));
    }
  }

  @override
  Future<Candidate?> probe(ProbeContext ctx) async {
    final r = await _json('GET', _uri(ctx.ip, null, '/api/config'));
    final cfg = r.valueOrNull;
    if (cfg is! Map || cfg['bridgeid'] is! String) return null;
    final id = normalizeBridgeId(cfg['bridgeid'] as String);
    return Candidate(
      ip: ctx.ip,
      brand: Brand.hue,
      protocol: 'hue',
      deviceId: id,
      name: cfg['name'] as String? ?? 'Hue Bridge',
      needsKey: !await _secrets.has(id, SecretName.hueUser),
      evidence: const ['http /api/config'],
    );
  }

  /// create_app_key: succeeds only while the bridge's link button is pressed.
  Future<Result<String>> pair(String ip, {int? port}) async {
    final r = await _json('POST', _uri(ip, port, '/api'), {
      'devicetype': deviceType,
    });
    if (r case Err(:final error)) return Err(error);
    final j = (r as Ok<Object?>).value;
    final user = _success(j, 'username');
    return user is String
        ? Ok(user)
        : Err(DeviceError.protocol('hue: no username'));
  }

  /// The bridge's lights: id → (name, capabilities).
  Future<Result<Map<String, (String, Set<Capability>)>>> lights(
    String ip,
    String user, {
    int? port,
  }) async {
    final r = await _json('GET', _uri(ip, port, '/api/$user/lights'));
    return r.map((j) {
      final out = <String, (String, Set<Capability>)>{};
      if (j is! Map) return out;
      for (final MapEntry(:key, :value) in j.entries) {
        if (value is! Map) continue;
        final st = value['state'];
        out['$key'] = (
          (value['name'] as String?) ?? 'Hue light $key',
          {
            Capability.power,
            Capability.nativeCountdown,
            if (st is Map && st.containsKey('bri')) Capability.brightness,
            if (st is Map && st.containsKey('ct')) Capability.colorTemp,
          },
        );
      }
      return out;
    });
  }

  Future<Result<String>> _user(Device d) async {
    final u = await _secrets.get(bridgeOf(d), SecretName.hueUser);
    return u == null ? Err(DeviceError.auth('hue: bridge not paired')) : Ok(u);
  }

  Future<Result<Object?>> _api(
    Device d,
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final u = await _user(d);
    if (u case Err(:final error)) return Err(error);
    return _json(
      method,
      _uri(d.ip, d.port, '/api/${(u as Ok<String>).value}$path'),
      body,
    );
  }

  static int pctToBri(int pct) =>
      (pct.clamp(1, 100) * briMax / 100).round().clamp(1, briMax);
  static int kelvinToMired(int k) => (1000000 / k).round().clamp(ctMin, ctMax);

  @override
  Future<Result<DeviceState>> getState(Device d) =>
      guarded(_tag, 'getState', () async {
        final r = await _api(d, 'GET', '/lights/${lightOf(d)}');
        if (r case Err(:final error)) return Err(error);
        final st = ((r as Ok<Object?>).value as Map?)?['state'];
        if (st is! Map) return Err(DeviceError.protocol('hue: no state'));
        if (st['reachable'] == false) {
          return Err(DeviceError.offline('hue: light unreachable'));
        }
        final bri = st['bri'];
        final ct = st['ct'];
        final left = await getCountdown(d, null);
        return Ok(
          DeviceState(
            on: st['on'] as bool?,
            brightness: bri is num
                ? (bri * 100 / briMax).round().clamp(1, 100)
                : null,
            colorTemp: ct is num && ct > 0 ? (1000000 / ct).round() : null,
            countdownLeft: left.valueOrNull,
            at: _now(),
          ),
        );
      });

  Future<Result<void>> _state(Device d, Map<String, Object?> s) async =>
      (await _api(d, 'PUT', '/lights/${lightOf(d)}/state', s)).map((_) {});

  @override
  Future<Result<void>> setPower(Device d, bool on) =>
      guarded(_tag, 'setPower', () => _state(d, {'on': on}));

  @override
  Future<Result<void>> setBrightness(Device d, int pct) => guarded(
    _tag,
    'brightness',
    () => _state(d, {'on': true, 'bri': pctToBri(pct)}),
  );

  @override
  Future<Result<void>> setColorTemp(Device d, int kelvin) => guarded(
    _tag,
    'colorTemp',
    () => _state(d, {'on': true, 'ct': kelvinToMired(kelvin)}),
  );

  // ------------------------------------------------------------------ timers

  @override
  Duration? nativeCountdownMax(Device d) => countdownMax;

  @override
  bool canCountdownTo(Device d, bool endState, {bool? currentOn}) => true;

  static String ptTime(Duration t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'PT${two(t.inHours)}:${two(t.inMinutes % 60)}:${two(t.inSeconds % 60)}';
  }

  /// Latest schedule id per device (so getState can report the countdown).
  final Map<String, String> _schedules = {};

  @override
  Future<Result<CountdownHandle>> setCountdown(
    Device d,
    Duration after,
    bool targetOn,
  ) => guarded(_tag, 'setCountdown', () async {
    final u = await _user(d);
    if (u case Err(:final error)) return Err(error);
    final user = (u as Ok<String>).value;
    final old = _schedules[d.id];
    if (old != null) await _api(d, 'DELETE', '/schedules/$old');
    final r = await _api(d, 'POST', '/schedules', {
      'name': 'offline_home',
      'command': {
        'address': '/api/$user/lights/${lightOf(d)}/state',
        'method': 'PUT',
        'body': {'on': targetOn},
      },
      'localtime': ptTime(after),
      'autodelete': true,
    });
    if (r case Err(:final error)) return Err(error);
    final j = (r as Ok<Object?>).value;
    final id = _success(j, 'id');
    if (id == null) return Err(DeviceError.protocol('hue: no schedule id'));
    _schedules[d.id] = '$id';
    return Ok({'scheduleId': '$id'});
  });

  /// Our schedule for [d]: the handle's id, else the one on the bridge whose command
  /// targets this light (survives an app restart).
  Future<Result<(String, Map<Object?, Object?>)?>> _findSchedule(
    Device d,
    CountdownHandle? h,
  ) async {
    final r = await _api(d, 'GET', '/schedules');
    if (r case Err(:final error)) return Err(error);
    final all = (r as Ok<Object?>).value;
    if (all is! Map) return const Ok(null);
    final want = h?['scheduleId'] ?? _schedules[d.id];
    for (final MapEntry(:key, :value) in all.entries) {
      if (value is! Map) continue;
      final cmd = value['command'];
      final mine =
          want == '$key' ||
          (want == null &&
              value['name'] == 'offline_home' &&
              cmd is Map &&
              '${cmd['address']}'.endsWith('/lights/${lightOf(d)}/state'));
      if (mine) return Ok(('$key', value));
    }
    return const Ok(null);
  }

  @override
  Future<Result<Duration?>> getCountdown(Device d, CountdownHandle? h) =>
      guarded(_tag, 'getCountdown', () async {
        final f = await _findSchedule(d, h);
        if (f case Err(:final error)) return Err(error);
        final found = (f as Ok<(String, Map<Object?, Object?>)?>).value;
        if (found == null) {
          _schedules.remove(d.id); // fired and auto-deleted
          return const Ok(null);
        }
        final s = found.$2;
        if (s['status'] != 'enabled') return const Ok(null);
        final m = RegExp(r'^PT(\d{2}):(\d{2}):(\d{2})$')
            .firstMatch('${s['localtime'] ?? s['time']}');
        final start = DateTime.tryParse('${s['starttime']}Z');
        if (m == null || start == null) return const Ok(null);
        final total = Duration(
          hours: int.parse(m.group(1)!),
          minutes: int.parse(m.group(2)!),
          seconds: int.parse(m.group(3)!),
        );
        // VERIFY: starttime is the bridge's UTC time; the bridge may be out of sync.
        final left = start.add(total).difference(_now().toUtc());
        return Ok(left > Duration.zero ? left : null);
      });

  @override
  Future<Result<void>> cancelCountdown(Device d, CountdownHandle? h) =>
      guarded(_tag, 'cancelCountdown', () async {
        final f = await _findSchedule(d, h);
        if (f case Err(:final error)) return Err(error);
        final found = (f as Ok<(String, Map<Object?, Object?>)?>).value;
        _schedules.remove(d.id);
        if (found == null) return const Ok(null);
        return (await _api(d, 'DELETE', '/schedules/${found.$1}')).map((_) {});
      });

  @override
  Future<void> dispose(Device d) async => _schedules.remove(d.id);

  @override
  Future<void> disposeAll() async => _schedules.clear();
}
