import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/timers/android_alarm_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('offline_home/alarms');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  var exact = true;

  setUp(() {
    calls.clear();
    exact = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'schedule' => exact,
        'canScheduleExact' => exact,
        _ => null,
      };
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('schedule/cancel pass job id and epoch millis', () async {
    final s = AndroidPhoneAlarmScheduler();
    final at = DateTime.utc(2026, 9, 29, 23);
    await s.schedule('j1', at);
    await s.cancel('j1');
    expect(calls.map((c) => c.method), ['schedule', 'cancel']);
    expect(calls.first.arguments, {
      'jobId': 'j1',
      'fireAtMs': at.millisecondsSinceEpoch,
    });
    expect(calls.last.arguments, {'jobId': 'j1'});
    expect(s.lastScheduleWasExact, isTrue);
  });

  test('inexact fallback is reported', () async {
    exact = false;
    final s = AndroidPhoneAlarmScheduler();
    await s.schedule('j2', DateTime.now());
    expect(s.lastScheduleWasExact, isFalse);
    expect(await s.canScheduleExact(), isFalse);
  });
}
