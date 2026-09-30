import 'dart:math';

import 'log.dart';

/// T8.2 measurements: tap→device latency per protocol family and cold start → device
/// list. Kept in memory (ring buffers), shown in Settings → Diagnostics and logged.
class LatencyStats {
  LatencyStats({this.capacity = 200});

  final int capacity;
  final Map<String, List<int>> _samples = {};

  void add(String key, Duration d) {
    for (final k in {key, 'all'}) {
      final l = _samples.putIfAbsent(k, () => []);
      l.add(d.inMicroseconds);
      if (l.length > capacity) l.removeAt(0);
    }
  }

  int count(String key) => _samples[key]?.length ?? 0;
  Iterable<String> get keys => _samples.keys;

  /// Nearest-rank percentile ([q] in 0..1), null without samples.
  Duration? percentile(String key, double q) {
    final l = _samples[key];
    if (l == null || l.isEmpty) return null;
    final sorted = [...l]..sort();
    final rank = max(1, (q * sorted.length).ceil());
    return Duration(microseconds: sorted[rank - 1]);
  }
}

abstract final class Perf {
  static const _tag = 'perf';

  /// Target from TASKS T8.2.
  static const tapBudget = Duration(milliseconds: 500);
  static const coldStartBudget = Duration(seconds: 2);

  static final latency = LatencyStats();
  static DateTime? appStart;
  static Duration? coldStart;

  static void markAppStart([DateTime? at]) => appStart = at ?? DateTime.now();

  /// First frame with the device list; logged once.
  static void markDeviceListShown([DateTime? at]) {
    final start = appStart;
    if (start == null || coldStart != null) return;
    coldStart = (at ?? DateTime.now()).difference(start);
    final msg = 'cold start → device list ${coldStart!.inMilliseconds}ms';
    if (coldStart! > coldStartBudget) {
      log.w(_tag, msg);
    } else {
      log.i(_tag, msg);
    }
  }

  static void recordTap(String protocol, Duration d) {
    final family = protocol.split('-').first;
    latency.add(family, d);
    if (d > tapBudget) {
      log.w(_tag, '$family command took ${d.inMilliseconds}ms');
    }
  }

  static String summary() {
    String ms(Duration? d) => d == null ? '–' : '${d.inMilliseconds}ms';
    final p50 = latency.percentile('all', 0.5);
    final p95 = latency.percentile('all', 0.95);
    return 'tap→device p50 ${ms(p50)} · p95 ${ms(p95)} '
        '(${latency.count('all')} cmds) · cold start ${ms(coldStart)}';
  }
}
