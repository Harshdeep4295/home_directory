import 'dart:async';

import '../core/models.dart';
import '../core/result.dart';
import 'device_adapter.dart';

/// In-memory adapter for tests and UI development. Devices with protocol `fake` are
/// simulated; [offline] ids answer with `Err(offline)` after [latency].
class FakeAdapter extends DeviceAdapter {
  FakeAdapter({
    this.latency = Duration.zero,
    this.countdownMax = const Duration(hours: 24),
    this.protocols = const {'fake'},
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration latency;
  final Duration? countdownMax;
  final DateTime Function() _now;

  final Map<String, bool> power = {};
  final Map<String, int> brightness = {};
  final Set<String> offline = {};

  /// Devices that answer but refuse our key (auth errors).
  final Set<String> rejectKey = {};

  /// Ids whose next N setPower calls fail with the given error (for retry tests).
  final Map<String, List<DeviceError>> failNext = {};
  final List<String> calls = [];
  final Map<String, Timer> _countdowns = {};
  final Map<String, DateTime> _countdownEnds = {};
  final _watch = StreamController<(String, DeviceState)>.broadcast();

  @override
  Brand get brand => Brand.unknown;

  /// Protocols this fake answers for (tests can impersonate e.g. `wiz`).
  @override
  final Set<String> protocols;

  Future<Result<T>> _run<T>(
    Device d,
    String call,
    Result<T> Function() body,
  ) async {
    calls.add('$call:${d.id}');
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (offline.contains(d.id)) {
      return Err(DeviceError.offline('${d.id} offline'));
    }
    if (rejectKey.contains(d.id)) {
      return Err(DeviceError.auth('${d.id} key rejected'));
    }
    return body();
  }

  DeviceState _state(Device d) => DeviceState(
    on: power[d.id] ?? false,
    brightness: brightness[d.id],
    countdownLeft: _countdownEnds[d.id]?.difference(_now()),
    at: _now(),
  );

  @override
  Future<Candidate?> probe(ProbeContext ctx) async => null;

  @override
  Future<Result<DeviceState>> getState(Device d) =>
      _run(d, 'getState', () => Ok(_state(d)));

  @override
  Future<Result<void>> setPower(Device d, bool on) => _run(d, 'setPower', () {
    final failures = failNext[d.id];
    if (failures != null && failures.isNotEmpty) {
      return Err<void>(failures.removeAt(0));
    }
    power[d.id] = on;
    _watch.add((d.id, _state(d)));
    return ok;
  });

  @override
  Future<Result<void>> setBrightness(Device d, int pct) =>
      _run(d, 'setBrightness', () {
        brightness[d.id] = pct.clamp(1, 100);
        return ok;
      });

  @override
  Duration? nativeCountdownMax(Device d) => countdownMax;

  /// Behaves like a flip-based countdown (Tuya): only ends in !current state.
  @override
  bool canCountdownTo(Device d, bool endState, {bool? currentOn}) =>
      countdownMax != null && (currentOn ?? power[d.id] ?? false) != endState;

  @override
  Future<Result<CountdownHandle>> setCountdown(
    Device d,
    Duration after,
    bool targetOn,
  ) => _run(d, 'setCountdown', () {
    if (countdownMax == null) {
      return Err(DeviceError.unsupported('no countdown'));
    }
    _countdowns.remove(d.id)?.cancel();
    _countdownEnds[d.id] = _now().add(after);
    _countdowns[d.id] = Timer(after, () {
      power[d.id] = targetOn;
      _countdownEnds.remove(d.id);
      _countdowns.remove(d.id);
      _watch.add((d.id, _state(d)));
    });
    return const Ok(<String, String>{});
  });

  @override
  Future<Result<Duration?>> getCountdown(Device d, CountdownHandle? h) => _run(
    d,
    'getCountdown',
    () => Ok(_countdownEnds[d.id]?.difference(_now())),
  );

  @override
  Future<Result<void>> cancelCountdown(Device d, CountdownHandle? h) =>
      _run(d, 'cancelCountdown', () {
        _countdowns.remove(d.id)?.cancel();
        _countdownEnds.remove(d.id);
        return ok;
      });

  @override
  Stream<DeviceState>? watch(Device d) =>
      _watch.stream.where((e) => e.$1 == d.id).map((e) => e.$2);

  @override
  Future<void> disposeAll() async {
    for (final t in _countdowns.values) {
      t.cancel();
    }
    _countdowns.clear();
  }
}
