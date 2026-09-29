import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/models.dart';
import '../../core/result.dart';
import '../../net/lan_socket_factory.dart';
import '../device_adapter.dart';

/// Yeelight bulbs with "LAN control" enabled: TCP 55443, one JSON object per line.
/// Ported from python-yeelight 0.7.16 yeelight/main.py: Bulb.send_command (request
/// {"id","method","params"} + "\r\n", skip {"method":"props"} notifications),
/// get_properties (get_prop), _command_to_send_command (effect "smooth", duration 300 ms
/// appended to set_power / set_bright / set_ct_abx), cron_add / cron_get / cron_del with
/// CronType.off = 0 (enums.py). The only cron type is a power-OFF timer in whole minutes,
/// so native timers can only end OFF; anything else runs on the phone tier.
class YeelightAdapter extends DeviceAdapter {
  YeelightAdapter(
    this._sockets, {
    this.timeout = LanSocketFactory.defaultTimeout,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// python-yeelight Bulb(port=55443).
  static const port = 55443;

  /// Bulb defaults: effect="smooth", duration=300.
  static const effect = 'smooth';
  static const duration = 300;

  /// enums.CronType.off
  static const cronOff = 0;

  /// VERIFY: longest cron delay a bulb accepts.
  static const countdownMax = Duration(hours: 24);

  /// set_color_temp docstring: "min/max are specified by the model's capabilities, or
  /// 1700-6500".
  static const kelvinMin = 1700;
  static const kelvinMax = 6500;

  static const _tag = 'yeelight';

  final LanSocketFactory _sockets;
  final Duration timeout;
  final DateTime Function() _now;
  int _id = 0;

  @override
  Brand get brand => Brand.yeelight;

  @override
  Set<String> get protocols => {'yeelight'};

  @override
  Future<Candidate?> probe(ProbeContext ctx) async {
    final r = await command(ctx.ip, port, 'get_prop', [
      'power',
    ], timeout: ctx.timeout);
    if (r.isErr) return null;
    return Candidate(
      ip: ctx.ip,
      brand: Brand.yeelight,
      protocol: 'yeelight',
      evidence: const ['tcp 55443 get_prop'],
    );
  }

  /// send_command over a fresh connection; returns the reply object with our id.
  Future<Result<Map<String, Object?>>> command(
    String ip,
    int port,
    String method,
    List<Object?> params, {
    Duration? timeout,
  }) async {
    final t = timeout ?? this.timeout;
    final s = await _sockets.tcp(ip, port, timeout: t);
    if (s case Err(:final error)) return Err(error);
    final socket = (s as Ok<Socket>).value;
    final id = ++_id;
    try {
      socket.add(
        utf8.encode(
          '${jsonEncode({'id': id, 'method': method, 'params': params})}\r\n',
        ),
      );
      final reply = await _reply(socket, id).timeout(t);
      final err = reply['error'];
      if (err is Map) {
        return Err(
          DeviceError.protocol('yeelight: $method ${err['message'] ?? err}'),
        );
      }
      return Ok(reply);
    } on TimeoutException {
      return Err(DeviceError.timeout('yeelight: no reply from $ip'));
    } on SocketException catch (e) {
      return Err(mapSocketError(e, 'yeelight'));
    } on StateError {
      return Err(DeviceError.offline('yeelight: connection closed'));
    } finally {
      socket.destroy();
    }
  }

  static Future<Map<String, Object?>> _reply(Socket socket, int id) async {
    var pending = '';
    await for (final chunk in socket) {
      pending += utf8.decode(chunk, allowMalformed: true);
      final lines = pending.split('\r\n');
      pending = lines.removeLast();
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        Object? j;
        try {
          j = jsonDecode(line);
        } on FormatException {
          continue;
        }
        if (j is! Map<String, Object?> || j['method'] == 'props') continue;
        if (j['id'] == id || !j.containsKey('id')) return j;
      }
    }
    throw StateError('closed');
  }

  Future<Result<Map<String, Object?>>> _cmd(
    Device d,
    String method,
    List<Object?> params,
  ) => command(d.ip, d.port ?? port, method, params);

  @override
  Future<Result<DeviceState>> getState(Device d) =>
      guarded(_tag, 'getState', () async {
        final r = await _cmd(d, 'get_prop', ['power', 'bright', 'ct']);
        if (r case Err(:final error)) return Err(error);
        final res = (r as Ok<Map<String, Object?>>).value['result'];
        if (res is! List || res.length < 3) {
          return Err(DeviceError.protocol('yeelight: bad get_prop reply'));
        }
        final left = await getCountdown(d, null);
        return Ok(
          DeviceState(
            on: res[0] == 'on',
            brightness: int.tryParse('${res[1]}'),
            colorTemp: int.tryParse('${res[2]}'),
            countdownLeft: left.valueOrNull,
            at: _now(),
          ),
        );
      });

  Future<Result<void>> _set(Device d, String method, Object value) async =>
      (await _cmd(d, method, [value, effect, duration])).map((_) {});

  @override
  Future<Result<void>> setPower(Device d, bool on) =>
      guarded(_tag, 'setPower', () => _set(d, 'set_power', on ? 'on' : 'off'));

  @override
  Future<Result<void>> setBrightness(Device d, int pct) => guarded(
    _tag,
    'brightness',
    () => _set(d, 'set_bright', pct.clamp(1, 100)),
  );

  @override
  Future<Result<void>> setColorTemp(Device d, int kelvin) => guarded(
    _tag,
    'colorTemp',
    () => _set(d, 'set_ct_abx', kelvin.clamp(kelvinMin, kelvinMax)),
  );

  @override
  Duration? nativeCountdownMax(Device d) => countdownMax;

  /// cron can only switch the bulb off.
  @override
  bool canCountdownTo(Device d, bool endState, {bool? currentOn}) => !endState;

  /// cron_add [0, minutes]; the bulb counts whole minutes, so [after] is rounded
  /// (at least 1). The timer service corrects its fire time from getCountdown.
  @override
  Future<Result<CountdownHandle>> setCountdown(
    Device d,
    Duration after,
    bool targetOn,
  ) => guarded(_tag, 'setCountdown', () async {
    if (targetOn) {
      return Err(DeviceError.unsupported('yeelight: cron only turns off'));
    }
    final minutes = (after.inSeconds / 60).round().clamp(
      1,
      countdownMax.inMinutes,
    );
    final r = await _cmd(d, 'cron_add', [cronOff, minutes]);
    return r.map((_) => const <String, String>{});
  });

  /// cron_get [0] → [{"type":0,"delay":<minutes left>,"mix":0}] (VERIFY reply shape).
  @override
  Future<Result<Duration?>> getCountdown(Device d, CountdownHandle? h) async {
    final r = await _cmd(d, 'cron_get', [cronOff]);
    return r.map((j) {
      final res = j['result'];
      if (res is! List || res.isEmpty || res.first is! Map) return null;
      final delay = (res.first as Map)['delay'];
      return delay is num && delay > 0
          ? Duration(minutes: delay.toInt())
          : null;
    });
  }

  @override
  Future<Result<void>> cancelCountdown(Device d, CountdownHandle? h) async =>
      (await _cmd(d, 'cron_del', [cronOff])).map((_) {});
}
