import 'dart:async';

import '../adapters/hue/hue_adapter.dart';
import '../core/log.dart';
import '../core/models.dart';
import '../core/result.dart';
import '../registry/repositories.dart';
import '../registry/secret_store.dart';

/// PSEUDOCODE §12.5: "Press the round button on the bridge" + 30 s window →
/// HueAdapter.pair() → import lights (T7.7).
class HuePairing {
  HuePairing(
    this._hue,
    this._secrets,
    this._devices, {
    DateTime Function()? now,
    this.window = const Duration(seconds: 30),
    this.every = const Duration(seconds: 2),
  }) : _now = now ?? DateTime.now;

  final HueAdapter _hue;
  final SecretStore _secrets;
  final DeviceRepository _devices;
  final DateTime Function() _now;
  final Duration window;
  final Duration every;
  static const _tag = 'hue';

  /// Tries to pair until the link button is pressed or [window] passes, then adds one
  /// app device per light. [onTick] reports the seconds left (for the countdown UI).
  Future<Result<List<Device>>> pairAndImport(
    Candidate bridge, {
    void Function(int secondsLeft)? onTick,
    bool Function()? cancelled,
  }) async {
    final id = bridge.deviceId;
    if (id == null) return Err(DeviceError.protocol('hue: bridge id unknown'));
    final deadline = _now().add(window);
    Result<String> r = Err(DeviceError.auth('hue: link button not pressed'));
    while (!_now().isAfter(deadline) && !(cancelled?.call() ?? false)) {
      onTick?.call(deadline.difference(_now()).inSeconds.clamp(0, 999));
      r = await _hue.pair(bridge.ip, port: bridge.port);
      if (r.isOk || r.errorOrNull?.kind != DeviceErrorKind.auth) break;
      await Future<void>.delayed(every);
    }
    if (r case Err(:final error)) return Err(error);
    final user = (r as Ok<String>).value;
    await _secrets.set(id, SecretName.hueUser, user);
    return importLights(bridge, user);
  }

  Future<Result<List<Device>>> importLights(
    Candidate bridge,
    String user,
  ) async {
    final id = bridge.deviceId!;
    final l = await _hue.lights(bridge.ip, user, port: bridge.port);
    if (l case Err(:final error)) return Err(error);
    final out = <Device>[];
    for (final MapEntry(key: lid, value: (name, caps))
        in (l as Ok<Map<String, (String, Set<Capability>)>>).value.entries) {
      final devId = HueAdapter.lightDeviceId(id, lid);
      final old = await _devices.byId(devId);
      final d =
          old?.copyWith(ip: bridge.ip, port: bridge.port) ??
          Device(
            id: devId,
            brand: Brand.hue,
            protocol: 'hue',
            ip: bridge.ip,
            port: bridge.port,
            name: name,
            capabilities: caps,
            meta: {'hueBridge': id, 'hueLight': lid},
            lastSeen: _now().toUtc(),
          );
      await _devices.upsert(d);
      out.add(d);
    }
    log.i(_tag, 'imported ${out.length} lights from bridge');
    return Ok(out);
  }
}
