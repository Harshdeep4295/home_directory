import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as hash;

import '../../core/models.dart';
import '../../core/result.dart';
import '../../net/lan_socket_factory.dart';
import '../../registry/secret_store.dart';
import '../device_adapter.dart';
import 'kasa_adapter.dart';
import 'klap.dart';

/// Tapo (and new Kasa) SMART devices over KLAP v2 (protocol `klap-smart`).
/// Ported from python-kasa 0.10.2: protocols/smartprotocol.py (get_smart_request,
/// _handle_response_error_code), smart/smartdevice.py (get_device_info,
/// set_device_info {"device_on"}), smart/modules/brightness.py and colortemperature.py
/// (set_device_info {"brightness"} / {"color_temp"}), exceptions.py (SmartErrorCode).
/// python-kasa has no SMART countdown-rule API, so timers use the phone tier (rule 4).
class TapoAdapter extends DeviceAdapter {
  TapoAdapter(
    this._sockets,
    this._secrets, {
    this.timeout = LanSocketFactory.defaultTimeout,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _terminalUuid = base64.encode(
         hash.md5
             .convert(
               List.generate(
                 16,
                 (_) => (random ?? Random.secure()).nextInt(256),
               ),
             )
             .bytes,
       );

  static const _tag = 'tapo';

  /// SmartErrorCode values python-kasa treats as authentication errors
  /// (SMART_AUTHENTICATION_ERRORS).
  static const authErrors = {-1501, 1111, -1005, 1100, 1003, -40412};

  final LanSocketFactory _sockets;
  final SecretStore _secrets;
  final Duration timeout;
  final DateTime Function() _now;

  /// smartprotocol.py: base64(md5(uuid4)) per protocol instance.
  final String _terminalUuid;
  final Map<String, KlapTransport> _klap = {};

  @override
  Brand get brand => Brand.tapo;

  @override
  Set<String> get protocols => {'klap-smart'};

  @override
  Future<Candidate?> probe(ProbeContext ctx) async => null; // UDP 20002 discovery

  Future<KlapTransport> _transport(Device d) async =>
      _klap[d.id] ??= KlapTransport(
        _sockets,
        host: d.ip,
        port: d.port ?? 80,
        version: KlapVersion.v2,
        username: await _secrets.get(KasaAdapter.accountId, SecretName.email),
        password: await _secrets.get(
          KasaAdapter.accountId,
          SecretName.password,
        ),
        timeout: timeout,
      );

  /// get_smart_request + error-code check; returns `result` (or {} when absent).
  Future<Result<Map<String, Object?>>> call(
    Device d,
    String method, [
    Map<String, Object?>? params,
  ]) async {
    final r = await (await _transport(d)).send({
      'method': method,
      'request_time_milis': _now().millisecondsSinceEpoch,
      'terminal_uuid': _terminalUuid,
      'params': ?params,
    });
    if (r case Err(:final error)) return Err(error);
    final res = (r as Ok<Map<String, Object?>>).value;
    final code = res['error_code'];
    if (code is num && code != 0) {
      return Err(
        authErrors.contains(code)
            ? DeviceError.auth('tapo: $method error $code')
            : code == -1002
            ? DeviceError.unsupported('tapo: $method not supported')
            : DeviceError.protocol('tapo: $method error $code'),
      );
    }
    final result = res['result'];
    return Ok(result is Map ? result.cast<String, Object?>() : const {});
  }

  @override
  Future<Result<DeviceState>> getState(Device d) =>
      guarded(_tag, 'getState', () async {
        final r = await call(d, 'get_device_info');
        return r.map(
          (i) => DeviceState(
            on: i['device_on'] as bool?,
            brightness: (i['brightness'] as num?)?.toInt(),
            colorTemp: switch (i['color_temp']) {
              final num t when t > 0 => t.toInt(),
              _ => null,
            },
            at: _now(),
          ),
        );
      });

  @override
  Future<Result<void>> setPower(Device d, bool on) => guarded(
    _tag,
    'setPower',
    () async =>
        (await call(d, 'set_device_info', {'device_on': on})).map((_) {}),
  );

  @override
  Future<Result<void>> setBrightness(Device d, int pct) => guarded(
    _tag,
    'brightness',
    () async => (await call(d, 'set_device_info', {
      'brightness': pct.clamp(1, 100),
    })).map((_) {}),
  );

  @override
  Future<Result<void>> setColorTemp(Device d, int kelvin) => guarded(
    _tag,
    'colorTemp',
    () async =>
        (await call(d, 'set_device_info', {'color_temp': kelvin})).map((_) {}),
  );

  @override
  Future<void> dispose(Device d) async => _klap.remove(d.id);

  @override
  Future<void> disposeAll() async => _klap.clear();
}
