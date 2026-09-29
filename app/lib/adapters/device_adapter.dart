import 'dart:async';

import '../core/log.dart';
import '../core/models.dart';
import '../core/result.dart';

/// Opaque data an adapter needs to find its countdown again (Hue scheduleId, Kasa rule
/// id, ...). Stored in [TimerJob.meta]. Empty for devices with a single countdown slot.
typedef CountdownHandle = Map<String, String>;

/// What discovery already knows about a host when it asks an adapter to probe it.
class ProbeContext {
  const ProbeContext({
    required this.ip,
    this.openPorts = const {},
    this.timeout = const Duration(milliseconds: 800),
  });

  final String ip;
  final Set<int> openPorts;
  final Duration timeout;
}

/// One protocol family (PSEUDOCODE §5). Implementations must never throw across this
/// interface: every failure is a [Result] error. Wrap bodies in [guarded].
abstract class DeviceAdapter {
  Brand get brand;

  /// Protocol ids this adapter serves; a device matches when its [Device.protocol]
  /// equals one of these or starts with `<id>-` (e.g. `tuya` matches `tuya-3.3`).
  Set<String> get protocols;

  bool handles(Device d) =>
      protocols.any((p) => d.protocol == p || d.protocol.startsWith('$p-'));

  /// Identify the host at [ctx.ip], or null if it is not this protocol.
  Future<Candidate?> probe(ProbeContext ctx);

  Set<Capability> capabilitiesOf(Device d) => d.capabilities;

  Future<Result<DeviceState>> getState(Device d);

  Future<Result<void>> setPower(Device d, bool on);

  Future<Result<void>> setBrightness(Device d, int pct) async =>
      Err(DeviceError.unsupported('brightness'));

  Future<Result<void>> setColorTemp(Device d, int kelvin) async =>
      Err(DeviceError.unsupported('color temperature'));

  /// Longest countdown the device can run itself; null → no native countdown.
  Duration? nativeCountdownMax(Device d) => null;

  /// Can the device's own countdown end in [endState]? Flip-based countdowns can only
  /// end in `!currentOn`. See PSEUDOCODE §5.
  bool canCountdownTo(Device d, bool endState, {bool? currentOn}) => false;

  /// Program the device to switch to [targetOn] after [after].
  Future<Result<CountdownHandle>> setCountdown(
    Device d,
    Duration after,
    bool targetOn,
  ) async => Err(DeviceError.unsupported('countdown'));

  /// Remaining time of the device's countdown; `Ok(null)` when none is running.
  Future<Result<Duration?>> getCountdown(Device d, CountdownHandle? h) async =>
      Err(DeviceError.unsupported('countdown'));

  Future<Result<void>> cancelCountdown(Device d, CountdownHandle? h) async =>
      Err(DeviceError.unsupported('countdown'));

  /// True when [powerFor] sets the state now and reverts it after a delay in one call.
  bool supportsCombinedPowerFor(Device d) => false;

  Future<Result<CountdownHandle>> powerFor(
    Device d,
    bool on,
    Duration after,
  ) async => Err(DeviceError.unsupported('combined power-for'));

  /// Push updates, if the protocol has them; null → caller polls [getState].
  Stream<DeviceState>? watch(Device d) => null;

  /// Close anything held for [d] (persistent sockets).
  Future<void> dispose(Device d) async {}

  /// Close everything (app shutdown, tests).
  Future<void> disposeAll() async {}
}

/// Runs [body] and converts anything thrown into `Err(protocol)`, logging it.
/// Adapters wrap every public method body in this so nothing escapes.
Future<Result<T>> guarded<T>(
  String tag,
  String what,
  Future<Result<T>> Function() body,
) async {
  try {
    return await body();
  } catch (e, st) {
    log.w(tag, '$what failed unexpectedly', e, st);
    return Err(DeviceError.protocol('$what: $e'));
  }
}

/// Picks the adapter for a device by protocol.
class AdapterRegistry {
  AdapterRegistry(this.adapters);

  final List<DeviceAdapter> adapters;

  DeviceAdapter? adapterFor(Device d) {
    for (final a in adapters) {
      if (a.handles(d)) return a;
    }
    return null;
  }

  DeviceAdapter? byBrand(Brand b) {
    for (final a in adapters) {
      if (a.brand == b) return a;
    }
    return null;
  }

  Future<void> disposeAll() async {
    for (final a in adapters) {
      await a.disposeAll();
    }
  }
}
