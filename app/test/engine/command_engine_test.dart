import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/adapters/fake_adapter.dart';
import 'package:offline_home/core/intent.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/engine/command_engine.dart';
import 'package:offline_home/registry/database.dart';
import 'package:offline_home/registry/repositories.dart';

Device dev(String id) => Device(
  id: id,
  brand: Brand.unknown,
  protocol: 'fake',
  ip: '127.0.0.1',
  name: id,
  lastSeen: DateTime.utc(2026),
);

void main() {
  late AppDatabase db;
  late FakeAdapter fake;
  late CommandEngine engine;
  late DeviceRepository devices;

  setUp(() async {
    db = AppDatabase.memory();
    devices = DeviceRepository(db);
    fake = FakeAdapter(latency: const Duration(milliseconds: 10));
    engine = CommandEngine(
      AdapterRegistry([fake]),
      StateCacheRepository(db),
      backoff: const [Duration(milliseconds: 5), Duration(milliseconds: 10)],
    );
    for (final id in ['a', 'b', 'c']) {
      await devices.upsert(dev(id));
    }
  });
  tearDown(() async {
    await engine.dispose();
    await db.close();
  });

  test(
    'power on several devices in parallel; state cached and persisted',
    () async {
      final sw = Stopwatch()..start();
      final results = await engine.power([
        dev('a'),
        dev('b'),
        dev('c'),
      ], PowerAction.on);
      expect(
        sw.elapsedMilliseconds,
        lessThan(3 * 2 * 10 + 40),
        reason: 'parallel across devices',
      );
      expect(Aggregate(results).allOk, isTrue);
      expect(fake.power, {'a': true, 'b': true, 'c': true});
      expect(engine.cached('a')!.on, isTrue);
      expect((await StateCacheRepository(db).get('a'))!.on, isTrue);
    },
  );

  test('serial per device: calls never interleave', () async {
    final d = dev('a');
    await Future.wait([
      engine.powerOne(d, true),
      engine.powerOne(d, false),
      engine.powerOne(d, true),
    ]);
    final seq = fake.calls.where((c) => c.endsWith(':a')).toList();
    expect(seq, [
      'setPower:a', 'getState:a', //
      'setPower:a', 'getState:a',
      'setPower:a', 'getState:a',
    ]);
    expect(fake.power['a'], isTrue);
  });

  test('retries transient errors twice, then succeeds', () async {
    fake.failNext['a'] = [DeviceError.timeout(), DeviceError.offline()];
    final r = await engine.powerOne(dev('a'), true);
    expect(r.isOk, isTrue);
    expect(fake.calls.where((c) => c == 'setPower:a'), hasLength(3));
  });

  test('does not retry auth errors', () async {
    fake.failNext['a'] = [DeviceError.auth('bad key')];
    final r = await engine.powerOne(dev('a'), true);
    expect(r.errorOrNull?.kind, DeviceErrorKind.auth);
    expect(fake.calls.where((c) => c == 'setPower:a'), hasLength(1));
  });

  test(
    'partial failure: optimistic state reverted only for the failed device',
    () async {
      await engine.power([dev('a'), dev('b')], PowerAction.off);
      fake.offline.add('b');
      final seen = <(String, bool?)>[];
      final sub = engine.stateChanges.listen((e) => seen.add((e.$1, e.$2.on)));
      final agg = Aggregate(
        await engine.power([dev('a'), dev('b')], PowerAction.on),
      );
      await pumpEventQueue(); // broadcast events are delivered asynchronously
      await sub.cancel();

      expect(agg.ok.map((d) => d.id), ['a']);
      expect(agg.failed.single.$1.id, 'b');
      expect(agg.failed.single.$2.kind, DeviceErrorKind.offline);
      expect(engine.cached('a')!.on, isTrue);
      expect(engine.cached('b')!.on, isFalse, reason: 'reverted');
      expect(
        seen,
        containsAllInOrder([('b', true), ('b', false)]),
        reason: 'optimistic then revert',
      );
    },
  );

  test('toggle uses cached state; unknown → on', () async {
    await engine.power([dev('a')], PowerAction.toggle);
    expect(fake.power['a'], isTrue);
    await engine.power([dev('a')], PowerAction.toggle);
    expect(fake.power['a'], isFalse);
  });

  test('status refreshes cache; missing adapter → unsupported', () async {
    fake.power['c'] = true;
    final r = await engine.status([dev('c')]);
    expect(r.single.result.valueOrNull!.on, isTrue);
    expect(engine.cached('c')!.on, isTrue);

    final orphan = dev('x').copyWith(protocol: 'nope');
    expect(
      (await engine.powerOne(orphan, true)).errorOrNull?.kind,
      DeviceErrorKind.unsupported,
    );
  });

  test('warmUp loads persisted cache', () async {
    await StateCacheRepository(db)
        .put('a', DeviceState(on: true, at: DateTime.utc(2026)));
    final e2 = CommandEngine(AdapterRegistry([fake]), StateCacheRepository(db));
    await e2.warmUp();
    expect(e2.cached('a')!.on, isTrue);
    await e2.dispose();
  });
}
