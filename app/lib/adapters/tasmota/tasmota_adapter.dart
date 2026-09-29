import '../../core/models.dart';
import '../../core/result.dart';
import '../../net/lan_socket_factory.dart';
import '../../registry/secret_store.dart';
import '../device_adapter.dart';

/// Tasmota over HTTP: `GET /cm?cmnd=<command>` (Tasmota commands docs, PSEUDOCODE §6.11).
/// `Power<n> On|Off`, Dimmer 0..100, CT 153..500 mired, Status 0; web password → user=admin
/// &password=… query parameters.
///
/// Timers: only "ON now, OFF after d" is native, via `PulseTime<n>` (1..111 = ×0.1 s,
/// 112..64900 = value−100 s). PulseTime persists and would auto-off every later ON, so the
/// adapter sets it just for that ON and clears it (PulseTime 0) on every other power
/// command, on cancel, and when getState finds the pulse finished. VERIFY on hardware.
class TasmotaAdapter extends DeviceAdapter {
  TasmotaAdapter(
    this._sockets,
    this._secrets, {
    this.timeout = LanSocketFactory.defaultTimeout,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const port = 80;
  static const user = 'admin';
  static const _tag = 'tasmota';

  /// PulseTime maximum 64900 → 64800 s.
  static const countdownMax = Duration(seconds: 64800);

  final LanSocketFactory _sockets;
  final SecretStore _secrets;
  final Duration timeout;
  final DateTime Function() _now;

  @override
  Brand get brand => Brand.tasmota;

  @override
  Set<String> get protocols => {'tasmota'};

  @override
  Future<Candidate?> probe(ProbeContext ctx) async => null; // HTTP evidence rule

  static int relayOf(Device d) => (d.meta['relay'] as num?)?.toInt() ?? 1;

  /// PulseTime encoding (Tasmota docs).
  static int pulseValue(Duration d) {
    final tenths = (d.inMilliseconds / 100).round();
    if (tenths <= 0) return 0;
    if (tenths <= 111) return tenths;
    return (d.inSeconds + 100).clamp(112, 64900);
  }

  static Duration pulseDuration(int v) => v <= 0
      ? Duration.zero
      : v <= 111
      ? Duration(milliseconds: v * 100)
      : Duration(seconds: v - 100);

  Future<Result<Map<String, Object?>>> cmnd(Device d, String command) async {
    final pw = await _secrets.get(d.id, SecretName.password);
    final r = await _sockets.http(
      'GET',
      Uri(
        scheme: 'http',
        host: d.ip,
        port: d.port ?? port,
        path: '/cm',
        queryParameters: {
          if (pw != null) 'user': user,
          'password': ?pw,
          'cmnd': command,
        },
      ),
      timeout: timeout,
    );
    if (r case Err(:final error)) return Err(error);
    final res = (r as Ok<HttpReply>).value;
    if (res.status == 401) {
      return Err(
        DeviceError.auth(
          pw == null
              ? 'tasmota: web password required'
              : 'tasmota: wrong password',
        ),
      );
    }
    try {
      final j = res.json;
      if (j is Map<String, Object?>) {
        if (j['Command'] == 'Unknown') {
          return Err(DeviceError.unsupported('tasmota: $command unknown'));
        }
        return Ok(j);
      }
    } on FormatException {
      // fall through
    }
    return Err(DeviceError.protocol('tasmota: HTTP ${res.status}'));
  }

  String _powerKey(Device d, Map<String, Object?> j) {
    final n = relayOf(d);
    return j.containsKey('POWER$n') ? 'POWER$n' : 'POWER';
  }

  Future<Result<(int, int)>> _pulse(Device d, [int? set]) async {
    final n = relayOf(d);
    final r = await cmnd(d, set == null ? 'PulseTime$n' : 'PulseTime$n $set');
    return r.map((j) {
      final p = j['PulseTime$n'];
      return p is Map
          ? (
              ((p['Set'] as num?) ?? 0).toInt(),
              ((p['Remaining'] as num?) ?? 0).toInt(),
            )
          : (0, 0);
    });
  }

  @override
  Future<Result<DeviceState>> getState(Device d) => guarded(
    _tag,
    'getState',
    () async {
      final r = await cmnd(d, 'Power${relayOf(d)}');
      if (r case Err(:final error)) return Err(error);
      final j = (r as Ok<Map<String, Object?>>).value;
      final on = j[_powerKey(d, j)] == 'ON';
      Duration? left;
      final p = await _pulse(d);
      if (p case Ok(value: (final set, final remaining))) {
        if (remaining > 0) left = pulseDuration(remaining);
        // A finished pulse leaves PulseTime set: clear it so later ONs stay on.
        if (set > 0 && remaining == 0) await _pulse(d, 0);
      }
      return Ok(DeviceState(on: on, countdownLeft: left, at: _now()));
    },
  );

  Future<Result<void>> _power(Device d, bool on) async =>
      (await cmnd(d, 'Power${relayOf(d)} ${on ? 'On' : 'Off'}')).map((_) {});

  @override
  Future<Result<void>> setPower(Device d, bool on) =>
      guarded(_tag, 'setPower', () async {
        final c = await _pulse(d, 0);
        if (c case Err(:final error)) return Err(error);
        return _power(d, on);
      });

  @override
  Future<Result<void>> setBrightness(Device d, int pct) => guarded(
    _tag,
    'brightness',
    () async => (await cmnd(d, 'Dimmer ${pct.clamp(1, 100)}')).map((_) {}),
  );

  @override
  Future<Result<void>> setColorTemp(Device d, int kelvin) => guarded(
    _tag,
    'colorTemp',
    () async => (await cmnd(
      d,
      'CT ${(1000000 / kelvin).round().clamp(153, 500)}',
    )).map((_) {}),
  );

  @override
  Duration? nativeCountdownMax(Device d) => countdownMax;

  /// No stand-alone countdown: only the combined ON-then-OFF pulse.
  @override
  bool canCountdownTo(Device d, bool endState, {bool? currentOn}) => false;

  @override
  bool supportsCombinedPowerFor(Device d) => true;

  @override
  Future<Result<CountdownHandle>> powerFor(Device d, bool on, Duration after) =>
      guarded(_tag, 'powerFor', () async {
        if (!on) {
          return Err(DeviceError.unsupported('tasmota: pulse only ends OFF'));
        }
        final p = await _pulse(d, pulseValue(after));
        if (p case Err(:final error)) return Err(error);
        final r = await _power(d, true);
        return r.map((_) => const <String, String>{});
      });

  @override
  Future<Result<Duration?>> getCountdown(Device d, CountdownHandle? h) async {
    final p = await _pulse(d);
    return p.map((v) => v.$2 > 0 ? pulseDuration(v.$2) : null);
  }

  @override
  Future<Result<void>> cancelCountdown(Device d, CountdownHandle? h) async =>
      (await _pulse(d, 0)).map((_) {});
}
