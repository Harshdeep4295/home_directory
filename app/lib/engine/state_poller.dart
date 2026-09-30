import 'dart:async';

import '../adapters/device_adapter.dart';
import '../core/log.dart';
import '../core/models.dart';
import '../core/result.dart';
import 'command_engine.dart';

/// Keeps device state fresh while the app is visible (PSEUDOCODE §9): push where the
/// adapter supports it, else poll. Two consecutive timeouts/offline → marked offline.
class StatePoller {
  StatePoller(
    this._engine,
    this._adapters, {
    this.interval = const Duration(seconds: 5),
    this.pushGrace = const Duration(seconds: 30),
    this.offlineAfter = 2,
    this.onOffline,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Called once when a device is marked offline (e.g. to rescan for a moved IP).
  void Function(Device d)? onOffline;

  final CommandEngine _engine;
  final AdapterRegistry _adapters;

  /// Poll period; changes apply to devices subscribed after the change.
  Duration interval;

  /// How long push sockets stay open after the app goes to the background.
  final Duration pushGrace;
  final int offlineAfter;
  final DateTime Function() _now;

  static const _tag = 'poller';

  final Map<String, Timer> _polls = {};
  final Map<String, StreamSubscription<DeviceState>> _pushes = {};
  final Map<String, int> _failures = {};
  final Map<String, Device> _devices = {};
  Timer? _graceTimer;
  bool _foreground = false;
  bool _disposed = false;

  bool get isForeground => _foreground;
  Set<String> get polled => _polls.keys.toSet();
  Set<String> get pushed => _pushes.keys.toSet();

  /// App became visible (or the device list changed while visible).
  void onForeground(List<Device> devices) {
    _foreground = true;
    _graceTimer?.cancel();
    _graceTimer = null;
    final ids = {for (final d in devices) d.id};
    for (final id in [..._polls.keys, ..._pushes.keys]) {
      if (!ids.contains(id)) _stop(id);
    }
    for (final d in devices) {
      final old = _devices[d.id];
      // New IP / port / protocol (rescan found it elsewhere): resubscribe.
      if (old != null &&
          (old.ip != d.ip ||
              old.port != d.port ||
              old.protocol != d.protocol)) {
        _stop(d.id);
        unawaited(_adapters.adapterFor(old)?.dispose(old));
      }
      _devices[d.id] = d;
      if (_polls.containsKey(d.id) || _pushes.containsKey(d.id)) continue;
      final adapter = _adapters.adapterFor(d);
      if (adapter == null) continue;
      final stream = adapter.watch(d);
      if (stream != null) {
        _pushes[d.id] = stream.listen((s) => unawaited(_ok(d, s)));
      }
      // Pushes carry changes only; still poll so offline devices are noticed.
      unawaited(pollOnce(d));
      _polls[d.id] = Timer.periodic(
        interval,
        (_) => unawaited(pollOnce(_devices[d.id] ?? d)),
      );
    }
  }

  /// App went to the background: stop polling now, drop push sockets after [pushGrace].
  void onBackground() {
    _foreground = false;
    for (final t in _polls.values) {
      t.cancel();
    }
    _polls.clear();
    _graceTimer?.cancel();
    _graceTimer = Timer(pushGrace, () => unawaited(_dropPushes()));
  }

  Future<void> _dropPushes() async {
    for (final e in _pushes.entries) {
      await e.value.cancel();
      final d = _devices[e.key];
      if (d != null) await _adapters.adapterFor(d)?.dispose(d);
    }
    _pushes.clear();
  }

  Future<void> pollOnce(Device d) async {
    if (_disposed) return;
    final r = (await _engine.status([d])).single.result;
    if (_disposed) return;
    switch (r) {
      case Ok(:final value):
        await _ok(d, value);
      case Err(:final error)
          when error.kind == DeviceErrorKind.timeout ||
              error.kind == DeviceErrorKind.offline ||
              error.kind == DeviceErrorKind.refused:
        final n = (_failures[d.id] ?? 0) + 1;
        _failures[d.id] = n;
        if (n == offlineAfter) {
          log.i(_tag, '${d.id} offline after $n failed polls');
          final last = _engine.cached(d.id);
          await _engine.remember(
            d.id,
            (last ?? DeviceState(at: _now())).copyWith(
              online: false,
              at: _now(),
            ),
          );
          onOffline?.call(d);
        }
      case Err(:final error) when error.kind == DeviceErrorKind.auth:
        _failures[d.id] = 0;
        final last = _engine.cached(d.id);
        if (last?.keyRejected != true) {
          log.w(_tag, '${d.id}: key / password rejected');
          await _engine.remember(
            d.id,
            (last ?? DeviceState(at: _now())).copyWith(
              online: true,
              keyRejected: true,
              at: _now(),
            ),
          );
        }
      case Err():
        break; // protocol problems: keep the last known state
    }
  }

  Future<void> _ok(Device d, DeviceState s) async {
    _failures[d.id] = 0;
    final last = _engine.cached(d.id);
    // Push updates may omit fields; keep what we knew.
    final merged = last == null
        ? s
        : s.copyWith(
            on: s.on ?? last.on,
            brightness: s.brightness ?? last.brightness,
            colorTemp: s.colorTemp ?? last.colorTemp,
            online: true,
            keyRejected: false,
          );
    await _engine.remember(d.id, merged);
  }

  void _stop(String id) {
    _polls.remove(id)?.cancel();
    unawaited(_pushes.remove(id)?.cancel());
    _failures.remove(id);
  }

  Future<void> dispose() async {
    _disposed = true;
    _graceTimer?.cancel();
    for (final id in [..._polls.keys, ..._pushes.keys]) {
      _stop(id);
    }
  }
}
