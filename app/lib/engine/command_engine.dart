import 'dart:async';

import '../adapters/device_adapter.dart';
import '../core/intent.dart';
import '../core/log.dart';
import '../core/models.dart';
import '../core/perf.dart';
import '../core/result.dart';
import '../registry/repositories.dart';

/// Outcome of one device in a multi-device command.
class CommandResult<T> {
  const CommandResult(this.device, this.result);
  final Device device;
  final Result<T> result;
}

/// ok / failed split for feedback ("3 lights off, bedroom lamp not responding").
class Aggregate<T> {
  Aggregate(List<CommandResult<T>> results)
    : ok = [
        for (final r in results)
          if (r.result.isOk) r.device,
      ],
      failed = [
        for (final r in results)
          if (r.result case Err(:final error)) (r.device, error),
      ];

  final List<Device> ok;
  final List<(Device, DeviceError)> failed;
  bool get allOk => failed.isEmpty;
}

/// Runs tasks one after another (per-device serial queue).
class SerialQueue {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

/// Sends commands to devices (PSEUDOCODE §8): serial per device, parallel across
/// devices, retries, optimistic state with read-back confirmation.
class CommandEngine {
  CommandEngine(
    this._adapters,
    this._cacheRepo, {
    this.backoff = const [
      Duration(milliseconds: 150),
      Duration(milliseconds: 400),
    ],
    this.readbackTimeout = const Duration(milliseconds: 800),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AdapterRegistry _adapters;
  final StateCacheRepository _cacheRepo;

  /// Delays before retry 1, retry 2, ... (length = number of retries).
  final List<Duration> backoff;
  final Duration readbackTimeout;
  final DateTime Function() _now;

  static const _tag = 'engine';

  final Map<String, SerialQueue> _queues = {};
  final Map<String, DeviceState> _cache = {};
  final _changes = StreamController<(String, DeviceState)>.broadcast();

  /// Every optimistic, confirmed or reverted state change: (deviceId, state).
  Stream<(String, DeviceState)> get stateChanges => _changes.stream;

  DeviceState? cached(String deviceId) => _cache[deviceId];

  /// Loads the persisted cache (call at startup so tiles show last-known state).
  Future<void> warmUp() async => _cache.addAll(await _cacheRepo.all());

  /// Records a state learned elsewhere (poller, push) without sending anything.
  Future<void> remember(String deviceId, DeviceState s) async {
    if (_changes.isClosed) return;
    _cache[deviceId] = s;
    _changes.add((deviceId, s));
    await _cacheRepo.put(deviceId, s);
  }

  /// Runs [op] on the device's adapter inside its serial queue.
  Future<Result<T>> run<T>(
    Device d,
    Future<Result<T>> Function(DeviceAdapter a) op,
  ) {
    final adapter = _adapters.adapterFor(d);
    if (adapter == null) {
      return Future.value(
        Err(DeviceError.unsupported('no adapter for ${d.protocol}')),
      );
    }
    return _queues.putIfAbsent(d.id, SerialQueue.new).run(() => op(adapter));
  }

  static bool _retryable(DeviceError e) =>
      e.kind != DeviceErrorKind.auth && e.kind != DeviceErrorKind.unsupported;

  Future<Result<T>> _withRetry<T>(Future<Result<T>> Function() call) async {
    var r = await call();
    for (final delay in backoff) {
      if (r case Err(:final error) when _retryable(error)) {
        await Future<void>.delayed(delay);
        r = await call();
      } else {
        break;
      }
    }
    return r;
  }

  /// Desired power for [action] given the cached state (toggle of unknown → on).
  bool desiredFor(Device d, PowerAction action) => switch (action) {
    PowerAction.on => true,
    PowerAction.off => false,
    PowerAction.toggle => !(_cache[d.id]?.on ?? false),
  };

  Future<List<CommandResult<void>>> power(
    List<Device> targets,
    PowerAction action,
  ) => Future.wait([
    for (final d in targets)
      powerOne(d, desiredFor(d, action)).then((r) => CommandResult(d, r)),
  ]);

  /// Sets one device's power: optimistic update, retries, revert on failure,
  /// read-back to confirm.
  Future<Result<void>> powerOne(Device d, bool on) => run(d, (a) async {
    final before = _cache[d.id];
    _emit(
      d.id,
      (before ?? DeviceState(at: _now())).copyWith(on: on, at: _now()),
    );
    final sw = Stopwatch()..start();
    final r = await _withRetry(() => a.setPower(d, on));
    // T8.2: tap → device acknowledged (before the confirming read-back).
    if (r.isOk) Perf.recordTap(d.protocol, sw.elapsed);
    if (r case Err(:final error)) {
      log.w(_tag, '${d.id} setPower($on) failed: ${error.kind.name}');
      if (before != null) {
        _emit(d.id, before);
      } else {
        _cache.remove(d.id);
        if (!_changes.isClosed) {
          _changes.add((d.id, DeviceState(online: false, at: _now())));
        }
      }
      return r;
    }
    final confirmed = await a
        .getState(d)
        .timeout(
          readbackTimeout,
          onTimeout: () => Err(DeviceError.timeout('read-back')),
        );
    final s = confirmed.valueOrNull ?? _cache[d.id]!;
    await remember(d.id, s);
    return r;
  });

  /// Reads state from every target in parallel and refreshes the cache.
  Future<List<CommandResult<DeviceState>>> status(List<Device> targets) =>
      Future.wait([
        for (final d in targets)
          run(d, (a) => a.getState(d)).then((r) async {
            if (r case Ok(:final value)) await remember(d.id, value);
            return CommandResult(d, r);
          }),
      ]);

  void _emit(String id, DeviceState s) {
    _cache[id] = s;
    if (!_changes.isClosed) _changes.add((id, s));
  }

  Future<void> dispose() => _changes.close();
}
