import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/registry/database.dart';
import 'package:offline_home/registry/repositories.dart';

void main() {
  late AppDatabase db;
  late DeviceRepository devices;
  late RoomRepository rooms;
  late TimerRepository timers;
  late StateCacheRepository cache;
  late SettingsRepository settings;
  final t = DateTime.utc(2026, 9, 29, 10);

  Device dev(String id, {String? room, List<String> aliases = const []}) =>
      Device(
        id: id,
        brand: Brand.tuya,
        protocol: 'tuya-3.3',
        ip: '192.168.1.${id.hashCode % 200 + 2}',
        mac: 'AA:BB:CC:00:00:${id.length}',
        name: 'Dev $id',
        roomId: room,
        aliases: aliases,
        capabilities: {Capability.power, Capability.nativeCountdown},
        nativeCountdownMax: const Duration(hours: 24),
        dpMap: {'switch': 1, 'countdown': 9},
        defaultAutoOff: const Duration(minutes: 30),
        meta: {'fw': '1.0', 'device22': false, 'gen': 2},
        lastSeen: t,
      );

  setUp(() {
    db = AppDatabase.memory();
    devices = DeviceRepository(db);
    rooms = RoomRepository(db);
    timers = TimerRepository(db);
    cache = StateCacheRepository(db);
    settings = SettingsRepository(db);
  });
  tearDown(() => db.close());

  group('devices', () {
    test('upsert + lookups round-trip every field', () async {
      await rooms.upsert(const Room(id: 'bath', name: 'Bathroom'));
      final d = dev('geyser', room: 'bath', aliases: ['heater', 'geezer']);
      await devices.upsert(d);

      final back = await devices.byId('geyser');
      expect(
        back!.copyWith(aliases: [...back.aliases]..sort()),
        d.copyWith(aliases: ['geezer', 'heater']),
      );
      expect((await devices.byMac('aa:bb:cc:00:00:6'))?.id, 'geyser');
      expect((await devices.byIp(d.ip))?.id, 'geyser');
      expect((await devices.inRoom('bath')).single.id, 'geyser');
      expect(await devices.byId('nope'), isNull);
    });

    test(
      'upsert updates in place and syncs aliases, keeping alias language',
      () async {
        await devices.upsert(dev('fan', aliases: ['ceiling fan']));
        await devices.addAlias(
          const Alias(
            id: 'fan#pankha',
            deviceId: 'fan',
            alias: 'pankha',
            lang: AliasLang.hi,
          ),
        );

        final current = (await devices.byId('fan'))!;
        await devices.upsert(
          current.copyWith(ip: '10.0.0.9', aliases: ['pankha', 'fan light']),
        );

        final back = (await devices.byId('fan'))!;
        expect(back.ip, '10.0.0.9');
        expect(back.aliases.toSet(), {'pankha', 'fan light'});
        final langs = {
          for (final a in await devices.aliasesOf('fan')) a.alias: a.lang,
        };
        expect(langs, {'pankha': AliasLang.hi, 'fan light': AliasLang.en});
        expect(await devices.all(), hasLength(1));
      },
    );

    test('delete cascades aliases, timers and state cache', () async {
      await devices.upsert(dev('ac', aliases: ['a c']));
      await timers.upsert(
        TimerJob(
          id: 'j',
          deviceId: 'ac',
          endOn: false,
          fireAt: t,
          tier: TimerTier.phone,
          createdAt: t,
        ),
      );
      await cache.put('ac', DeviceState(on: true, at: t));

      await devices.delete('ac');
      expect(await devices.aliasesOf('ac'), isEmpty);
      expect(await timers.byId('j'), isNull);
      expect(await cache.get('ac'), isNull);
    });

    test('watchAll emits on change', () async {
      final stream = devices.watchAll();
      final firstTwo = stream.take(2).toList();
      await Future<void>.delayed(Duration.zero);
      await devices.upsert(dev('lamp'));
      final emitted = await firstTwo;
      expect(emitted.first, isEmpty);
      expect(emitted.last.single.id, 'lamp');
    });
  });

  group('rooms', () {
    test(
      'ordered by sort then name; delete sets device room to null',
      () async {
        await rooms.upsert(const Room(id: 'b', name: 'Bedroom', sort: 1));
        await rooms.upsert(const Room(id: 'k', name: 'Kitchen'));
        await rooms.upsert(const Room(id: 'a', name: 'Attic', sort: 1));
        expect((await rooms.all()).map((r) => r.id), ['k', 'a', 'b']);

        await devices.upsert(dev('light', room: 'b'));
        await rooms.delete('b');
        expect((await devices.byId('light'))!.roomId, isNull);
      },
    );
  });

  group('timers', () {
    test('active, activeFor, setStatus, meta round-trip', () async {
      await devices.upsert(dev('geyser'));
      final j = TimerJob(
        id: 'j1',
        deviceId: 'geyser',
        endOn: false,
        fireAt: t.add(const Duration(minutes: 20)),
        tier: TimerTier.native,
        meta: {'scheduleId': '7'},
        createdAt: t,
      );
      await timers.upsert(j);
      expect(await timers.byId('j1'), j);
      expect((await timers.active()).single, j);
      expect(await timers.activeFor('geyser'), j);

      await timers.setStatus('j1', TimerStatus.done);
      expect(await timers.active(), isEmpty);
      expect((await timers.byId('j1'))!.status, TimerStatus.done);
    });
  });

  test('state cache put/get/all', () async {
    await devices.upsert(dev('lamp'));
    final s = DeviceState(
      on: true,
      brightness: 50,
      countdownLeft: const Duration(seconds: 30),
      at: t,
    );
    await cache.put('lamp', s);
    expect(await cache.get('lamp'), s);
    expect(await cache.all(), {'lamp': s});
  });

  test('settings get/set/bool/remove', () async {
    expect(await settings.get('lang'), isNull);
    await settings.set('lang', 'hi');
    expect(await settings.get('lang'), 'hi');
    expect(await settings.getBool('onboarded'), isFalse);
    await settings.setBool('onboarded', true);
    expect(await settings.getBool('onboarded'), isTrue);
    await settings.remove('lang');
    expect(await settings.get('lang'), isNull);
  });

  test('schema has no secret-like columns (CLAUDE.md rule 5)', () async {
    final bad = RegExp(
      r'key|secret|password|passwd|token|username|credential',
      caseSensitive: false,
    );
    // settings.key is the setting's name, not a secret value.
    const allowed = {'settings.key'};
    for (final table in db.allTables) {
      for (final column in table.$columns) {
        if (allowed.contains('${table.actualTableName}.${column.name}')) {
          continue;
        }
        expect(
          bad.hasMatch(column.name),
          isFalse,
          reason: '${table.actualTableName}.${column.name}',
        );
      }
    }
  });
}
