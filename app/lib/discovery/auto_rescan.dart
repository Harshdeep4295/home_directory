import 'dart:async';

import '../core/log.dart';
import 'discovery_service.dart';

/// T8.1 "device moved IP": when a device goes offline, run a short scan so DHCP moves are
/// picked up without the user doing anything. At most one scan per [minGap]; requests
/// during a scan or inside the gap are dropped.
class AutoRescan {
  AutoRescan(
    this._scan, {
    this.minGap = const Duration(minutes: 2),
    this.window = const Duration(seconds: 3),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Future<ScanReport> Function({Duration window}) _scan;
  final Duration minGap;
  final Duration window;
  final DateTime Function() _now;
  static const _tag = 'rescan';

  DateTime? _last;
  Future<ScanReport?>? _running;
  int scans = 0;

  /// Returns the running (or just started) scan, or null if rate-limited.
  Future<ScanReport?>? request(String reason) {
    if (_running != null) return _running;
    final now = _now();
    if (_last != null && now.difference(_last!) < minGap) return null;
    _last = now;
    scans++;
    log.i(_tag, 'rescan: $reason');
    return _running = () async {
      try {
        final r = await _scan(window: window);
        final moved = r.results.where((x) => x.movedFrom != null).length;
        if (moved > 0) log.i(_tag, '$moved device(s) found at a new address');
        return r;
      } on Object catch (e) {
        log.w(_tag, 'rescan failed', e);
        return null;
      } finally {
        _running = null;
      }
    }();
  }
}
