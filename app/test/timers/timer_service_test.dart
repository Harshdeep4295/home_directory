import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/adapters/fake_adapter.dart';
import 'package:offline_home/core/intent.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/engine/command_engine.dart';
import 'package:offline_home/registry/database.dart';
import 'package:offline_home/registry/repositories.dart';
import 'package:offline_home/timers/timer_service.dart';

class FakePhone implements PhoneAlarmScheduler {
  final Map<String, DateTime> scheduled = {};
  final List<String> cancelled = [];
  @override
  Future<void> schedule(String jobId, DateTime fireAt) async =>
      scheduled[jobId] = fireAt;
  @override
  Future<void> cancel(String jobId) async {
    cancelled.add(jobId);
    scheduled.remove(jobId);
  }
}

/// Native countdown adapter whose device also supports one-shot powerFor (Shelly-like).
class CombinedAdapter extends FakeAdapter {
  CombinedAdapter() : super(protocols: {'combined'});
  final List<(bool, Duration)> combinedCalls = [];
  @override
  bool supportsCombinedPowerFor(Device d) => true;
  @override
  Future<Result<CountdownHandle>> powerFor(
    Device d,
    bool on,
    Duration after,
  ) async {
    combinedCalls.add((on, after));
    power[d.id] = on;
    return const Ok({'kind': 'combined'});
  }
}

/// Native countdown that errors (e.g. device rejects the DP).
class BrokenCountdown extends FakeAdapter {
  BrokenCountdown() : super(protocols: {'broken'});
  @override
  Future<Result<CountdownHandle>> setCountdown(
    Device d,
    Duration after,
    bool targetOn,
  ) async => Err(DeviceError.protocol('rejected'));
}

Device dev(String id, String protocol) => Device(
  id: id,
  brand: Brand.unknown,
  protocol: protocol,
  ip: '127.0.0.1',
  name: id,
  lastSeen: DateTime.utc(2026),
);

void main() {
  late AppDatabase db;
  late FakeAdapter native; // flip-based, max 24 h (Tuya-like)
  late FakeAdapter noNative; // WiZ-like
  late CombinedAdapter combined;
  late CommandEngine engine;
  late TimerRepository timers;
  late FakePhone phone;
  late TimerService svc;
  var now = DateTime(2026, 9, 29, 20, 0);
  var ids = 0;

  final geyser = dev('geyser', 'fake');
  final lamp = dev('lamp', 'wizlike');
  final shelly = dev('shelly', 'combined');
  final broken = dev('broken', 'broken');

  setUp(() async {
    now = DateTime(2026, 9, 29, 20, 0);
    ids = 0;
    db = AppDatabase.memory();
    native = FakeAdapter(now: () => now);
    noNative = FakeAdapter(protocols: {'wizlike'}, countdownMax: null);
    combined = CombinedAdapter();
    final reg = AdapterRegistry([
      native,
      noNative,
      combined,
      BrokenCountdown(),
    ]);
    engine = CommandEngine(reg, StateCacheRepository(db), backoff: const []);
    timers = TimerRepository(db);
    phone = FakePhone();
    final devices = DeviceRepository(db);
    for (final d in [geyser, lamp, shelly, broken]) {
      await devices.upsert(d);
    }
    svc = TimerService(
      engine,
      reg,
      devices,
      timers,
      phone,
      now: () => now,
      newId: () => 'j${ids++}',
    );
  });
  tearDown(() async {
    await native.disposeAll();
    await engine.dispose();
    await db.close();
  });

  TimerJob job(List<TimerOutcome> o) => o.single.result.valueOrNull!;

  group('tier selection matrix', () {
    test('native countdown, within max, flip-compatible → native', () async {
      final j = job(
        await svc.powerFor(
          [geyser],
          PowerAction.on,
          const Duration(minutes: 20),
        ),
      );
      expect(j.tier, TimerTier.native);
      expect(j.endOn, isFalse);
      expect(j.fireAt, now.add(const Duration(minutes: 20)));
      expect(native.power['geyser'], isTrue, reason: 'on now');
      expect(phone.scheduled, isEmpty);
    });

    test('no native countdown → phone tier with alarm scheduled', () async {
      final j = job(
        await svc.powerFor([lamp], PowerAction.on, const Duration(minutes: 1)),
      );
      expect(j.tier, TimerTier.phone);
      expect(phone.scheduled[j.id], now.add(const Duration(minutes: 1)));
    });

    test('duration above native max → phone tier', () async {
      final j = job(
        await svc.powerFor([geyser], PowerAction.on, const Duration(hours: 25)),
      );
      expect(j.tier, TimerTier.phone);
    });

    test(
      'flip-based countdown cannot end in the current state → phone tier',
      () async {
        // Device is off; "off after 10 min" cannot be a flip countdown.
        await engine.powerOne(geyser, false);
        final j = job(
          await svc.powerAfter(
            [geyser],
            PowerAction.off,
            const Duration(minutes: 10),
          ),
        );
        expect(j.tier, TimerTier.phone);
        // Device on; "off after 10 min" can.
        await engine.powerOne(geyser, true);
        final j2 = job(
          await svc.powerAfter(
            [geyser],
            PowerAction.off,
            const Duration(minutes: 10),
          ),
        );
        expect(j2.tier, TimerTier.native);
      },
    );

    test('native setCountdown failure falls back to phone tier', () async {
      await engine.powerOne(broken, true);
      final j = job(
        await svc.powerAfter(
          [broken],
          PowerAction.off,
          const Duration(minutes: 5),
        ),
      );
      expect(j.tier, TimerTier.phone);
      expect(phone.scheduled, contains(j.id));
    });

    test('combined powerFor used when the adapter supports it', () async {
      final j = job(
        await svc.powerFor(
          [shelly],
          PowerAction.on,
          const Duration(minutes: 15),
        ),
      );
      expect(j.tier, TimerTier.native);
      expect(j.meta, {'kind': 'combined'});
      expect(combined.combinedCalls, [(true, const Duration(minutes: 15))]);
      expect(engine.cached('shelly')!.on, isTrue);
    });
  });

  test(
    'device-native countdown actually flips the device (end-to-end with fake)',
    () async {
      final real = TimerService(
        engine,
        AdapterRegistry([native]),
        DeviceRepository(db),
        timers,
        phone,
      );
      await real.powerFor(
        [geyser],
        PowerAction.on,
        const Duration(milliseconds: 100),
      );
      expect(native.power['geyser'], isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(native.power['geyser'], isFalse);
    },
  );

  test('powerAfter leaves the current state alone', () async {
    await engine.powerOne(lamp, false);
    final j = job(
      await svc.powerAfter([lamp], PowerAction.on, const Duration(minutes: 5)),
    );
    expect(j.endOn, isTrue);
    expect(noNative.power['lamp'], isFalse);
  });

  test('powerAt / powerUntil convert clock times to durations', () async {
    final at = job(
      await svc.powerAt([lamp], PowerAction.off, const ClockTime(23)),
    );
    expect(at.fireAt, DateTime(2026, 9, 29, 23, 0));
    final until = job(
      await svc.powerUntil([geyser], PowerAction.on, const ClockTime(6, 30)),
    );
    expect(
      until.fireAt,
      DateTime(2026, 9, 30, 6, 30),
      reason: 'tomorrow morning',
    );
    expect(until.endOn, isFalse);
  });

  test('untilNext', () {
    final n = DateTime(2026, 9, 29, 20, 0);
    expect(
      TimerService.untilNext(const ClockTime(23), n),
      const Duration(hours: 3),
    );
    expect(
      TimerService.untilNext(const ClockTime(20), n),
      const Duration(hours: 24),
    );
    expect(
      TimerService.untilNext(const ClockTime(6), n),
      const Duration(hours: 10),
    );
  });

  test('one active timer per device: new timer cancels the old one', () async {
    final first = job(
      await svc.powerFor([lamp], PowerAction.on, const Duration(minutes: 30)),
    );
    final second = job(
      await svc.powerFor([lamp], PowerAction.on, const Duration(minutes: 10)),
    );
    expect(phone.cancelled, [first.id]);
    expect((await timers.byId(first.id))!.status, TimerStatus.cancelled);
    expect((await timers.activeFor('lamp'))!.id, second.id);
  });

  test(
    'cancel: native → cancelCountdown on device; phone → alarm cancelled',
    () async {
      await svc.powerFor([geyser], PowerAction.on, const Duration(minutes: 20));
      await svc.powerFor([lamp], PowerAction.on, const Duration(minutes: 20));
      await svc.cancel([geyser, lamp]);
      expect(native.calls, contains('cancelCountdown:geyser'));
      expect(phone.scheduled, isEmpty);
      expect(await timers.active(), isEmpty);
    },
  );

  test('powerFor fails cleanly when the device is offline', () async {
    native.offline.add('geyser');
    final o = (await svc.powerFor(
      [geyser],
      PowerAction.on,
      const Duration(minutes: 5),
    )).single;
    expect(o.result.errorOrNull?.kind, DeviceErrorKind.offline);
    expect(await timers.active(), isEmpty);
  });

  group('reconcile', () {
    test('overdue native job → done', () async {
      final j = job(
        await svc.powerFor(
          [geyser],
          PowerAction.on,
          const Duration(minutes: 20),
        ),
      );
      now = now.add(const Duration(hours: 1));
      native.power['geyser'] = false;
      await svc.reconcile();
      expect((await timers.byId(j.id))!.status, TimerStatus.done);
    });

    test(
      'overdue phone job that never ran → failed (not executed late)',
      () async {
        final j = job(
          await svc.powerFor(
            [lamp],
            PowerAction.on,
            const Duration(minutes: 20),
          ),
        );
        now = now.add(const Duration(hours: 2));
        await svc.reconcile();
        expect((await timers.byId(j.id))!.status, TimerStatus.failed);
        expect(
          noNative.power['lamp'],
          isTrue,
          reason: 'still on; not flipped late',
        );
      },
    );

    test('countdown cancelled on the device itself → cancelled', () async {
      final j = job(
        await svc.powerFor(
          [geyser],
          PowerAction.on,
          const Duration(minutes: 20),
        ),
      );
      await native.cancelCountdown(geyser, null);
      await svc.reconcile();
      expect((await timers.byId(j.id))!.status, TimerStatus.cancelled);
    });

    test('drift beyond 1 min → fireAt corrected from the device', () async {
      final j = job(
        await svc.powerFor(
          [geyser],
          PowerAction.on,
          const Duration(minutes: 20),
        ),
      );
      // Device countdown was re-armed to 5 min elsewhere.
      await native.setCountdown(geyser, const Duration(minutes: 5), false);
      await svc.reconcile();
      // Stored as UTC; compare instants.
      expect(
        (await timers.byId(j.id))!.fireAt.isAtSameMomentAs(
          now.add(const Duration(minutes: 5)),
        ),
        isTrue,
      );
    });
  });

  group('onAlarm (phone tier)', () {
    test('executes the job and marks it done', () async {
      final j = job(
        await svc.powerFor([lamp], PowerAction.on, const Duration(minutes: 1)),
      );
      expect(noNative.power['lamp'], isTrue);
      expect(await svc.onAlarm(j.id), isA<Ok<void>>());
      expect(noNative.power['lamp'], isFalse);
      expect((await timers.byId(j.id))!.status, TimerStatus.done);
    });

    test('failure → failed; inactive/unknown job → no-op', () async {
      final j = job(
        await svc.powerFor([lamp], PowerAction.on, const Duration(minutes: 1)),
      );
      noNative.offline.add('lamp');
      expect((await svc.onAlarm(j.id)).isErr, isTrue);
      expect((await timers.byId(j.id))!.status, TimerStatus.failed);
      expect(await svc.onAlarm(j.id), isA<Ok<void>>());
      expect(await svc.onAlarm('nope'), isA<Ok<void>>());
    });
  });
}
