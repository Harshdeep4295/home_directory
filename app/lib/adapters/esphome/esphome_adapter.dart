import 'dart:convert';

import '../../core/models.dart';
import '../../core/result.dart';
import '../../net/lan_socket_factory.dart';
import '../../registry/secret_store.dart';
import '../device_adapter.dart';

/// ESPHome devices with the `web_server` component (ESPHome web_server REST docs,
/// PSEUDOCODE §6.12): `GET /<domain>/<id>` → {"state","value"[,"brightness" 0..255]},
/// `POST /<domain>/<id>/turn_on|turn_off` (lights: `?brightness=`). Optional HTTP Basic
/// auth (username in meta, default "admin"; password in SecretStore).
/// The entity is chosen by the user when adding (meta.espEntity, e.g. `switch/relay`,
/// `light/lamp`). No native countdown → phone tier.
class EspHomeAdapter extends DeviceAdapter {
  EspHomeAdapter(
    this._sockets,
    this._secrets, {
    this.timeout = LanSocketFactory.defaultTimeout,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const port = 80;
  static const defaultEntity = 'switch/relay';
  static const _tag = 'esphome';

  final LanSocketFactory _sockets;
  final SecretStore _secrets;
  final Duration timeout;
  final DateTime Function() _now;

  @override
  Brand get brand => Brand.esphome;

  @override
  Set<String> get protocols => {'esphome'};

  @override
  Future<Candidate?> probe(ProbeContext ctx) async => null; // mDNS _esphomelib._tcp

  static String entityOf(Device d) =>
      (d.meta['espEntity'] as String?) ?? defaultEntity;
  static bool isLight(Device d) => entityOf(d).startsWith('light/');

  Future<Result<HttpReply>> _call(
    Device d,
    String method,
    String path, [
    Map<String, String>? query,
  ]) async {
    final pw = await _secrets.get(d.id, SecretName.password);
    final user = (d.meta['espUser'] as String?) ?? 'admin';
    final r = await _sockets.http(
      method,
      Uri(
        scheme: 'http',
        host: d.ip,
        port: d.port ?? port,
        path: '/${entityOf(d)}$path',
        queryParameters: query,
      ),
      body: method == 'POST' ? const [] : null,
      headers: {
        if (pw != null)
          'Authorization': 'Basic ${base64.encode(utf8.encode('$user:$pw'))}',
      },
      timeout: timeout,
    );
    return switch (r) {
      Err(:final error) => Err(error),
      Ok(value: final res) when res.status == 401 => Err(
        DeviceError.auth(
          pw == null
              ? 'esphome: web password required'
              : 'esphome: wrong password',
        ),
      ),
      Ok(value: final res) when res.status == 404 => Err(
        DeviceError.unsupported('esphome: no entity ${entityOf(d)}'),
      ),
      Ok(value: final res) when res.status != 200 => Err(
        DeviceError.protocol('esphome: HTTP ${res.status}'),
      ),
      Ok() => r,
    };
  }

  @override
  Future<Result<DeviceState>> getState(Device d) =>
      guarded(_tag, 'getState', () async {
        final r = await _call(d, 'GET', '');
        if (r case Err(:final error)) return Err(error);
        final Object? j;
        try {
          j = (r as Ok<HttpReply>).value.json;
        } on FormatException {
          return Err(DeviceError.protocol('esphome: not JSON'));
        }
        if (j is! Map) return Err(DeviceError.protocol('esphome: bad state'));
        final b = j['brightness'];
        return Ok(
          DeviceState(
            on: j['state'] == 'ON' || j['value'] == true,
            brightness: b is num ? (b * 100 / 255).round().clamp(1, 100) : null,
            at: _now(),
          ),
        );
      });

  @override
  Future<Result<void>> setPower(Device d, bool on) => guarded(
    _tag,
    'setPower',
    () async =>
        (await _call(d, 'POST', on ? '/turn_on' : '/turn_off')).map((_) {}),
  );

  @override
  Future<Result<void>> setBrightness(Device d, int pct) =>
      guarded(_tag, 'brightness', () async {
        if (!isLight(d)) return Err(DeviceError.unsupported('brightness'));
        return (await _call(d, 'POST', '/turn_on', {
          'brightness': '${(pct.clamp(1, 100) * 255 / 100).round()}',
        })).map((_) {});
      });
}
