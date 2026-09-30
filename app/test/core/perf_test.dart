import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/perf.dart';

void main() {
  test('nearest-rank percentiles, per key and overall', () {
    final s = LatencyStats(capacity: 100);
    for (var i = 1; i <= 100; i++) {
      s.add(i.isEven ? 'tuya' : 'wiz', Duration(milliseconds: i));
    }
    expect(s.percentile('all', 0.5), const Duration(milliseconds: 50));
    expect(s.percentile('all', 0.95), const Duration(milliseconds: 95));
    expect(s.count('tuya'), 50);
    expect(s.percentile('nope', 0.5), isNull);
  });

  test('ring buffer keeps the newest samples', () {
    final s = LatencyStats(capacity: 3);
    for (final ms in [900, 1, 2, 3]) {
      s.add('x', Duration(milliseconds: ms));
    }
    expect(s.percentile('x', 1), const Duration(milliseconds: 3));
  });

  test('cold start recorded once', () {
    final t0 = DateTime(2026);
    Perf.markAppStart(t0);
    Perf.coldStart = null;
    Perf.markDeviceListShown(t0.add(const Duration(milliseconds: 800)));
    Perf.markDeviceListShown(t0.add(const Duration(seconds: 5)));
    expect(Perf.coldStart, const Duration(milliseconds: 800));
    expect(Perf.summary(), contains('cold start 800ms'));
  });
}
