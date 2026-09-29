import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/adapters/fake_adapter.dart';
import 'package:offline_home/core/intent.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/engine/command_engine.dart';
import 'package:offline_home/registry/database.dart';
import 'package:offline_home/registry/repositories.dart';
import 'package:offline_home/timers/ios_phone_timers.dart';
import 'package:offline_home/timers/phone_tier_ticker.dart';
import 'package:offline_home/timers/tier_copy.dart';
import 'package:offline_home/timers/timer_service.dart';

class FakeNotifier implements LocalNotifier {
  final Map<int, (DateTime, String, String)> scheduled = {};
  @override
  Future<void> schedule(int id, DateTime at, String title, String body) async =>
      scheduled[id] = (at, title, body);
  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}

void main() {
  late AppDatabase db;
  late FakeAdapter wizLike;
  late CommandEngine engine;
  late TimerRepository timers;
  late FakeNotifier notifier;
  late TimerService svc;
  late PhoneTierTicker ticker;
  var now = DateTime(2026, 9, 29, 21);
  final lamp = Device(
    id: 'lamp',
    brand: Brand.wiz,
    protocol: 'fake',
    ip: '127.0.0.1',
    name: 'Bedroom lamp',
    lastSeen: DateTime.utc(2026),
  );

  setUp(() async {
    now = DateTime(2026, 9, 29, 21);
    db = AppDatabase.memory();
    wizLike = FakeAdapter(countdownMax: null);
    final reg = AdapterRegistry([wizLike]);
    engine = CommandEngine(reg, StateCacheRepository(db), backoff: const []);
    timers = TimerRepository(db);
    final devices = DeviceRepository(db);
    await devices.upsert(lamp);
    notifier = FakeNotifier();
    Future<String> describe(String id) async {
      final j = (await timers.byId(id))!;
      final d = (await devices.byId(j.deviceId))!;
      return '${d.name} ${j.endOn ? 'on' : 'off'}';
    }

    svc = TimerService(
      engine,
      reg,
      devices,
      timers,
      IosPhoneTimers(notifier, describe),
      now: () => now,
    );
    ticker = PhoneTierTicker(timers, svc, now: () => now);
  });
  tearDown(() async {
    ticker.stop();
    await engine.dispose();
    await db.close();
  });

  test(
    'phone-tier job schedules a notification naming device and action',
    () async {
      final j = (await svc.powerFor(
        [lamp],
        PowerAction.on,
        const Duration(minutes: 30),
      )).single.result.valueOrNull!;
      expect(j.tier, TimerTier.phone);
      final (at, title, body) = notifier.scheduled[IosPhoneTimers.idFor(j.id)]!;
      expect(at, now.add(const Duration(minutes: 30)));
      expect(title, 'Timer due: Bedroom lamp off');
      expect(body, contains('Open Offline Home'));
    },
  );

  test('cancel removes the notification', () async {
    final j = (await svc.powerFor(
      [lamp],
      PowerAction.on,
      const Duration(minutes: 30),
    )).single.result.valueOrNull!;
    await svc.cancel([lamp]);
    expect(notifier.scheduled, isNot(contains(IosPhoneTimers.idFor(j.id))));
  });

  test('foreground ticker runs due jobs only', () async {
    await svc.powerFor([lamp], PowerAction.on, const Duration(minutes: 1));
    expect(await ticker.tick(), 0, reason: 'not due yet');
    expect(wizLike.power['lamp'], isTrue);
    now = now.add(const Duration(minutes: 1));
    expect(await ticker.tick(), 1);
    expect(wizLike.power['lamp'], isFalse);
    expect(await ticker.tick(), 0, reason: 'already done');
  });

  test('ticker start/stop', () {
    ticker.start();
    expect(ticker.running, isTrue);
    ticker.stop();
    expect(ticker.running, isFalse);
  });

  test('tier copy always names the tier', () {
    expect(TierCopy.badge(TimerTier.native, Brand.tuya), 'Plug');
    expect(TierCopy.badge(TimerTier.native, Brand.hue), 'Bridge');
    expect(TierCopy.badge(TimerTier.phone, Brand.wiz), 'Phone');
    expect(
      TierCopy.feedbackSuffix(TimerTier.phone, isIOS: true),
      contains('keep the app open'),
    );
    expect(
      TierCopy.feedbackSuffix(TimerTier.native, isIOS: false),
      '(plug timer)',
    );
    expect(TierCopy.iosPhoneWarning, contains('Keep Offline Home open'));
  });
}
