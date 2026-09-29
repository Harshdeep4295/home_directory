import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../core/models.dart';
import '../../core/result.dart';
import '../../net/lan_socket_factory.dart';
import '../device_adapter.dart';
import 'kasa_xor.dart';

/// TP-Link Kasa legacy (IOT) plugs, strips and bulbs: TCP 9999, length-prefixed XOR JSON.
/// Ported from python-kasa 0.10.2: transports/xortransport.py (framing),
/// iot/iotdevice.py (_create_request {target: {cmd: args}} + context child_ids,
/// _query_helper err_code checks), iot/iotplug.py (system.set_relay_state),
/// iot/iotstrip.py (children), iot/iotbulb.py (lightingservice transition_light_state,
/// ignore_default rule).
///
/// Countdown: an `add_rule {enable, delay, act, name}` in module `count_down` (softScheck
/// tplink-smartplug, the protocol source python-kasa credits), falling back to python-kasa's
/// module name `countdown`. `act` makes it absolute (1 = on, 0 = off), so it can end in
/// either state. VERIFY on hardware: module name, `remain` field, max delay.
class KasaAdapter extends DeviceAdapter {
  KasaAdapter(
    this._sockets, {
    this.timeout = LanSocketFactory.defaultTimeout,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// xortransport.py: XorTransport.DEFAULT_PORT = 9999.
  static const port = KasaXor.discoveryPort;

  static const lightService = 'smartlife.iot.smartbulb.lightingservice';
  static const countdownModules = ['count_down', 'countdown'];

  /// VERIFY per model.
  static const countdownMax = Duration(hours: 24);

  static const _tag = 'kasa';

  final LanSocketFactory _sockets;
  final Duration timeout;
  final DateTime Function() _now;

  /// Countdown module name that worked per device (learned on first use).
  final Map<String, String> _countdownModule = {};

  @override
  Brand get brand => Brand.kasa;

  @override
  Set<String> get protocols => {'kasa'};

  /// Only legacy IOT devices; `kasa-klap` / `kasa-aes` belong to the KLAP adapter.
  @override
  bool handles(Device d) => d.protocol == 'kasa';

  static String? childOf(Device d) => d.meta['childId'] as String?;

  @override
  Future<Candidate?> probe(ProbeContext ctx) async {
    final r = await query(ctx.ip, port, {
      'system': {'get_sysinfo': <String, Object?>{}},
    }, timeout: ctx.timeout);
    final info = _dig(r.valueOrNull, 'system', 'get_sysinfo');
    if (info == null) return null;
    final mac = (info['mac'] ?? info['mic_mac']) as String?;
    final norm = mac?.replaceAll(RegExp('[:-]'), '').toLowerCase();
    return Candidate(
      ip: ctx.ip,
      mac: norm,
      brand: Brand.kasa,
      protocol: 'kasa',
      deviceId: (info['deviceId'] as String?) ?? norm,
      name: info['alias'] as String?,
      evidence: const ['tcp 9999 sysinfo'],
    );
  }

  /// One request/response over a fresh TCP connection (XorTransport._execute_send).
  Future<Result<Map<String, Object?>>> query(
    String ip,
    int port,
    Map<String, Object?> request, {
    Duration? timeout,
  }) async {
    final t = timeout ?? this.timeout;
    final s = await _sockets.tcp(ip, port, timeout: t);
    if (s case Err(:final error)) return Err(error);
    final socket = (s as Ok<Socket>).value;
    try {
      socket.add(KasaXor.frame(jsonEncode(request)));
      final body = await _readFrame(socket).timeout(t);
      final json = jsonDecode(utf8.decode(KasaXor.decrypt(body)));
      if (json is! Map<String, Object?>) {
        return Err(DeviceError.protocol('kasa: not a JSON object'));
      }
      return Ok(json);
    } on TimeoutException {
      return Err(DeviceError.timeout('kasa: no reply from $ip'));
    } on SocketException catch (e) {
      return Err(mapSocketError(e, 'kasa'));
    } on FormatException catch (e) {
      return Err(DeviceError.protocol('kasa: bad reply (${e.message})'));
    } on StateError {
      return Err(DeviceError.offline('kasa: connection closed'));
    } finally {
      socket.destroy();
    }
  }

  /// 4-byte big-endian length, then that many XOR bytes.
  static Future<Uint8List> _readFrame(Socket socket) async {
    final buf = BytesBuilder(copy: false);
    int? need;
    await for (final chunk in socket) {
      buf.add(chunk);
      if (need == null && buf.length >= 4) {
        need = ByteData.sublistView(buf.toBytes()).getUint32(0);
      }
      if (need != null && buf.length >= 4 + need) {
        return Uint8List.sublistView(buf.toBytes(), 4, 4 + need);
      }
    }
    throw StateError('closed');
  }

  static Map<String, Object?>? _dig(
    Map<String, Object?>? r,
    String target,
    String cmd,
  ) {
    final t = r?[target];
    final c = t is Map ? t[cmd] : null;
    return c is Map<String, Object?> ? c : null;
  }

  /// _query_helper: {target: {cmd: args}} (+ context), unwrap, check err_code.
  Future<Result<Map<String, Object?>>> call(
    Device d,
    String target,
    String cmd, [
    Map<String, Object?> args = const {},
  ]) async {
    final child = childOf(d);
    final r = await query(d.ip, d.port ?? port, {
      if (child != null)
        'context': {
          'child_ids': [child],
        },
      target: {cmd: args},
    });
    if (r case Err(:final error)) return Err(error);
    final t = (r as Ok<Map<String, Object?>>).value[target];
    if (t is Map && t['err_code'] is num && t['err_code'] != 0) {
      return Err(DeviceError.unsupported('kasa: $target ${t['err_msg']}'));
    }
    final res = _dig(r.value, target, cmd);
    if (res == null) return Err(DeviceError.protocol('kasa: no $target.$cmd'));
    final code = res['err_code'];
    if (code is num && code != 0) {
      return Err(
        code == -1 || code == -2
            ? DeviceError.unsupported('kasa: $target.$cmd ${res['err_msg']}')
            : DeviceError.protocol('kasa: $target.$cmd ${res['err_msg']}'),
      );
    }
    return Ok(res);
  }

  static bool isBulb(Map<String, Object?> info) =>
      ((info['mic_type'] ?? info['type']) as String? ?? '').contains('BULB');

  Future<Result<Map<String, Object?>>> sysinfo(Device d) =>
      call(d, 'system', 'get_sysinfo');

  @override
  Future<Result<DeviceState>> getState(Device d) =>
      guarded(_tag, 'getState', () async {
        final r = await sysinfo(d);
        if (r case Err(:final error)) return Err(error);
        final info = (r as Ok<Map<String, Object?>>).value;
        bool? on;
        int? brightness;
        int? colorTemp;
        if (isBulb(info)) {
          final ls = info['light_state'];
          if (ls is Map) {
            on = ls['on_off'] == 1;
            final src = on ? ls : (ls['dft_on_state'] as Map?) ?? const {};
            brightness = (src['brightness'] as num?)?.toInt();
            final ct = (src['color_temp'] as num?)?.toInt();
            colorTemp = ct == null || ct == 0 ? null : ct;
          }
        } else if (childOf(d) case final child?) {
          final kids = info['children'];
          final me = kids is List
              ? kids.whereType<Map<Object?, Object?>>().firstWhere(
                  (c) => c['id'] == child || '${c['id']}'.endsWith(child),
                  orElse: () => const {},
                )
              : const <Object?, Object?>{};
          on = me['state'] is num ? me['state'] == 1 : null;
        } else if (info['relay_state'] is num) {
          on = info['relay_state'] == 1;
        }
        final left = await getCountdown(d, null);
        return Ok(
          DeviceState(
            on: on,
            brightness: brightness,
            colorTemp: colorTemp,
            countdownLeft: left.valueOrNull,
            at: _now(),
          ),
        );
      });

  /// Bulb or plug? Asked once per call; cheap on the LAN and avoids stale caches.
  Future<Result<bool>> _bulb(Device d) async =>
      d.capabilities.contains(Capability.brightness)
      ? const Ok(true)
      : (await sysinfo(d)).map(isBulb);

  /// iotbulb._set_light_state: ignore_default = 0 only for a bare on/off.
  Future<Result<void>> _light(Device d, Map<String, Object?> state) async {
    final bare = state.keys.every((k) => k == 'on_off');
    return (await call(d, lightService, 'transition_light_state', {
      ...state,
      'ignore_default': state['on_off'] == 1 && bare ? 0 : 1,
    })).map((_) {});
  }

  @override
  Future<Result<void>> setPower(Device d, bool on) =>
      guarded(_tag, 'setPower', () async {
        final b = await _bulb(d);
        if (b case Err(:final error)) return Err(error);
        if ((b as Ok<bool>).value) return _light(d, {'on_off': on ? 1 : 0});
        return (await call(d, 'system', 'set_relay_state', {
          'state': on ? 1 : 0,
        })).map((_) {});
      });

  @override
  Future<Result<void>> setBrightness(Device d, int pct) =>
      guarded(_tag, 'brightness', () async {
        final b = await _bulb(d);
        if (b.valueOrNull != true) {
          return Err(DeviceError.unsupported('brightness'));
        }
        return _light(d, {'on_off': 1, 'brightness': pct.clamp(1, 100)});
      });

  @override
  Future<Result<void>> setColorTemp(Device d, int kelvin) =>
      guarded(_tag, 'colorTemp', () async {
        final b = await _bulb(d);
        if (b.valueOrNull != true) {
          return Err(DeviceError.unsupported('color temperature'));
        }
        return _light(d, {'on_off': 1, 'color_temp': kelvin});
      });

  // ------------------------------------------------------------------ countdown

  @override
  Duration? nativeCountdownMax(Device d) => countdownMax;

  /// Rules carry an action, so any end state works.
  @override
  bool canCountdownTo(Device d, bool endState, {bool? currentOn}) => true;

  /// Runs [op] against the countdown module that answers (count_down, then countdown).
  Future<Result<(String, Map<String, Object?>)>> _countdown(
    Device d,
    String cmd, [
    Map<String, Object?> args = const {},
  ]) async {
    final known = _countdownModule[d.id];
    for (final m in known == null ? countdownModules : [known]) {
      final r = await call(d, m, cmd, args);
      if (r case Ok(:final value)) {
        _countdownModule[d.id] = m;
        return Ok((m, value));
      }
      if (r.errorOrNull?.kind != DeviceErrorKind.unsupported) {
        return Err(r.errorOrNull!);
      }
    }
    return Err(DeviceError.unsupported('kasa: no countdown module'));
  }

  @override
  Future<Result<CountdownHandle>> setCountdown(
    Device d,
    Duration after,
    bool targetOn,
  ) => guarded(_tag, 'setCountdown', () async {
    // One rule slot on most plugs: clear first.
    final del = await _countdown(d, 'delete_all_rules');
    if (del case Err(:final error)) return Err(error);
    final r = await _countdown(d, 'add_rule', {
      'enable': 1,
      'delay': after.inSeconds,
      'act': targetOn ? 1 : 0,
      'name': 'offline_home',
    });
    return r.map(
      (v) => {'module': v.$1, if (v.$2['id'] case final String id) 'id': id},
    );
  });

  @override
  Future<Result<Duration?>> getCountdown(Device d, CountdownHandle? h) async {
    final r = await _countdown(d, 'get_rules');
    return r.map((v) {
      final list = v.$2['rule_list'];
      if (list is! List) return null;
      for (final rule in list.whereType<Map<Object?, Object?>>()) {
        final remain = rule['remain'];
        if (rule['enable'] == 1 && remain is num && remain > 0) {
          return Duration(seconds: remain.toInt());
        }
      }
      return null;
    });
  }

  @override
  Future<Result<void>> cancelCountdown(Device d, CountdownHandle? h) async =>
      (await _countdown(d, 'delete_all_rules')).map((_) {});

  @override
  Future<void> dispose(Device d) async => _countdownModule.remove(d.id);

  @override
  Future<void> disposeAll() async => _countdownModule.clear();
}
