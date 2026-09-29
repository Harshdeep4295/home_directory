import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/adapters/fake_adapter.dart';
import 'package:offline_home/core/intent.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/engine/command_engine.dart';
import 'package:offline_home/registry/database.dart';
import 'package:offline_home/registry/repositories.dart';
import 'package:offline_home/timers/alarm_runner.dart';
import 'package:offline_home/timers/timer_service.dart';

class FakeHost implements AlarmRunnerHost {
  FakeHost(this.queue);
  final List<String> queue;
  final List<String> finishedIds = [];
  bool isDone = false;
  @override
  Future<String?> next() async => queue.isEmpty ? null : queue.removeAt(0);
  @override
  Future<void> finished(String jobId) async => finishedIds.add(jobId);
  @override
  Future<void> done() async => isDone = true;
}

class NoPhone implements PhoneAlarmScheduler {
  @override
  Future<void> schedule(String jobId, DateTime fireAt) async {}
  @override
  Future<void> cancel(String jobId) async {}
}

void main() {
  test(
    'background entry point runs queued jobs through TimerService',
    () async {
      final db = AppDatabase.memory();
      final fake = FakeAdapter(
        countdownMax: null,
      ); // phone tier only (WiZ-like)
      final reg = AdapterRegistry([fake]);
      final engine = CommandEngine(
        reg,
        StateCacheRepository(db),
        backoff: const [],
      );
      final devices = DeviceRepository(db);
      final timers = TimerRepository(db);
      final svc = TimerService(engine, reg, devices, timers, NoPhone());
      final lamp = Device(
        id: 'lamp',
        brand: Brand.unknown,
        protocol: 'fake',
        ip: '127.0.0.1',
        name: 'Lamp',
        lastSeen: DateTime.utc(2026),
      );
      await devices.upsert(lamp);

      final j = (await svc.powerFor(
        [lamp],
        PowerAction.on,
        const Duration(minutes: 1),
      )).single.result.valueOrNull!;
      expect(j.tier, TimerTier.phone);
      expect(fake.power['lamp'], isTrue);

      final host = FakeHost([j.id, 'unknown-job']);
      expect(await drainAlarms(host, svc), 2);
      expect(fake.power['lamp'], isFalse, reason: 'alarm turned it off');
      expect((await timers.byId(j.id))!.status, TimerStatus.done);
      expect(host.finishedIds, [j.id, 'unknown-job']);
      expect(host.isDone, isTrue);

      await engine.dispose();
      await db.close();
    },
  );
}
