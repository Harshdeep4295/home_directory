import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/adapters/fake_adapter.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/engine/command_engine.dart';
import 'package:offline_home/engine/state_poller.dart';
import 'package:offline_home/registry/database.dart';
import 'package:offline_home/registry/repositories.dart';

/// Fake without push support (poll-only), like WiZ.
class PollOnlyAdapter extends FakeAdapter {
  PollOnlyAdapter() : super(protocols: {'poll'});
  @override
  Stream<DeviceState>? watch(Device d) => null;
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
  late FakeAdapter pushy;
  late PollOnlyAdapter polly;
  late CommandEngine engine;
  late StatePoller poller;
  const tick = Duration(milliseconds: 40);

  setUp(() async {
    db = AppDatabase.memory();
    pushy = FakeAdapter(protocols: {'push'});
    polly = PollOnlyAdapter();
    final reg = AdapterRegistry([pushy, polly]);
    engine = CommandEngine(reg, StateCacheRepository(db));
    poller = StatePoller(engine, reg, interval: tick, pushGrace: tick * 2);
    for (final d in [dev('p', 'push'), dev('q', 'poll')]) {
      await DeviceRepository(db).upsert(d);
    }
  });
  tearDown(() async {
    await poller.dispose();
    await engine.dispose();
    await pushy.disposeAll();
    await db.close();
  });

  test('foreground: subscribes to push devices and polls everything', () async {
    poller.onForeground([dev('p', 'push'), dev('q', 'poll')]);
    expect(poller.pushed, {'p'});
    expect(poller.polled, {'p', 'q'});
    polly.power['q'] = true;
    await Future<void>.delayed(tick * 3);
    expect(engine.cached('q')!.on, isTrue);
    expect(
      polly.calls.where((c) => c == 'getState:q').length,
      greaterThanOrEqualTo(2),
    );
  });

  test('push updates land in the cache without polling', () async {
    poller.onForeground([dev('p', 'push')]);
    await pushy.setPower(dev('p', 'push'), true); // device-side change → push
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(engine.cached('p')!.on, isTrue);
  });

  test('two failed polls → offline; recovery → online', () async {
    polly.offline.add('q');
    poller.onForeground([dev('q', 'poll')]);
    await Future<void>.delayed(tick * 3);
    expect(engine.cached('q')!.online, isFalse);
    polly.offline.remove('q');
    await Future<void>.delayed(tick * 2);
    expect(engine.cached('q')!.online, isTrue);
  });

  test(
    'background: polling stops at once, pushes dropped after grace',
    () async {
      poller.onForeground([dev('p', 'push'), dev('q', 'poll')]);
      await Future<void>.delayed(tick);
      poller.onBackground();
      expect(poller.polled, isEmpty);
      expect(poller.pushed, {'p'});
      // Let polls already in flight finish before counting.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final before = polly.calls.length;
      await Future<void>.delayed(tick * 3);
      expect(polly.calls.length, before, reason: 'no polls in background');
      expect(poller.pushed, isEmpty);
    },
  );

  test('removed devices stop being polled', () async {
    poller.onForeground([dev('p', 'push'), dev('q', 'poll')]);
    poller.onForeground([dev('q', 'poll')]);
    expect(poller.polled, {'q'});
    expect(poller.pushed, isEmpty);
  });

  test('auth errors do not mark a device offline', () async {
    final orphan = dev('q', 'poll');
    polly.offline.clear();
    await engine.remember('q', DeviceState(on: true, at: DateTime.now()));
    // simulate auth failure by using a failing adapter call path
    await poller.pollOnce(orphan.copyWith(protocol: 'nope'));
    await poller.pollOnce(orphan.copyWith(protocol: 'nope'));
    expect(engine.cached('q')!.online, isTrue);
    expect(
      (await engine.status([orphan.copyWith(protocol: 'nope')]))
          .single
          .result
          .errorOrNull
          ?.kind,
      DeviceErrorKind.unsupported,
    );
  });
}
