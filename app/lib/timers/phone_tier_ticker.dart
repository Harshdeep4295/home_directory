import 'dart:async';

import '../core/models.dart';
import '../registry/repositories.dart';
import 'timer_service.dart';

/// Runs due phone-tier jobs while the app is in the foreground (iOS phone tier, T3.5).
/// On Android the exact alarm does this even when the app is closed.
class PhoneTierTicker {
  PhoneTierTicker(
    this._timers,
    this._service, {
    this.every = const Duration(seconds: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TimerRepository _timers;
  final TimerService _service;
  final Duration every;
  final DateTime Function() _now;
  Timer? _timer;
  bool _busy = false;

  bool get running => _timer != null;

  void start() => _timer ??= Timer.periodic(every, (_) => unawaited(tick()));

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Fires every active phone-tier job that is due. Returns how many ran.
  Future<int> tick() async {
    if (_busy) return 0;
    _busy = true;
    try {
      final now = _now();
      var ran = 0;
      for (final j in await _timers.active()) {
        if (j.tier == TimerTier.phone && !j.fireAt.isAfter(now)) {
          await _service.onAlarm(j.id);
          ran++;
        }
      }
      return ran;
    } finally {
      _busy = false;
    }
  }
}
