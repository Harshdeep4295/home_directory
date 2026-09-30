import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/discovery/auto_rescan.dart';
import 'package:offline_home/discovery/discovery_service.dart';

void main() {
  test('one scan at a time, then at most one per gap', () async {
    var now = DateTime(2026, 9, 29, 10);
    var scans = 0;
    final r = AutoRescan(
      ({Duration window = Duration.zero}) async {
        scans++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return const ScanReport([], []);
      },
      minGap: const Duration(minutes: 2),
      now: () => now,
    );
    final a = r.request('a');
    final b = r.request('b'); // joins the running scan
    expect(identical(a, b), isTrue);
    await a;
    expect(r.request('c'), isNull, reason: 'inside the gap');
    now = now.add(const Duration(minutes: 3));
    await r.request('d');
    expect(scans, 2);
  });
}
