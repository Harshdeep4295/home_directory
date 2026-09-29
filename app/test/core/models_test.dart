import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/intent.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';

/// Encode to a JSON string and back, as the DB and config export will.
T roundTrip<T>(
  Map<String, dynamic> Function() toJson,
  T Function(Map<String, dynamic>) fromJson,
) => fromJson(jsonDecode(jsonEncode(toJson())) as Map<String, dynamic>);

void main() {
  final t = DateTime.utc(2026, 9, 29, 10, 30);
  const span = TargetSpan(
    words: ['lights'],
    all: true,
    room: 'bedroom',
    except: ['lamp'],
  );

  group('JSON round-trip', () {
    test('Device (full)', () {
      final d = Device(
        id: 'bf123',
        brand: Brand.tuya,
        protocol: 'tuya-3.3',
        ip: '192.168.1.20',
        mac: 'aa:bb:cc:dd:ee:ff',
        port: 6668,
        name: 'Geyser',
        roomId: 'bath',
        aliases: ['water heater', 'geezer'],
        capabilities: {Capability.power, Capability.nativeCountdown},
        nativeCountdownMax: const Duration(hours: 24),
        dpMap: {'switch': 1, 'countdown': 9},
        defaultAutoOff: const Duration(minutes: 30),
        meta: {'model': 'plug', 'gen': 2, 'device22': true},
        lastSeen: t,
      );
      expect(roundTrip(d.toJson, Device.fromJson), d);
    });

    test('Device (minimal, defaults)', () {
      final d = Device(
        id: 'ip:10.0.0.5',
        brand: Brand.wiz,
        protocol: 'wiz',
        ip: '10.0.0.5',
        name: 'Lamp',
        lastSeen: t,
      );
      final back = roundTrip(d.toJson, Device.fromJson);
      expect(back, d);
      expect(back.capabilities, {Capability.power});
      expect(back.nativeCountdownMax, isNull);
    });

    test('DeviceState', () {
      final s = DeviceState(
        on: true,
        brightness: 40,
        colorTemp: 2700,
        countdownLeft: const Duration(seconds: 90),
        online: true,
        at: t,
      );
      expect(roundTrip(s.toJson, DeviceState.fromJson), s);
      final offline = DeviceState(online: false, at: t);
      expect(roundTrip(offline.toJson, DeviceState.fromJson), offline);
    });

    test('Room and Alias', () {
      const r = Room(id: 'bed', name: 'Bedroom', sort: 2);
      expect(roundTrip(r.toJson, Room.fromJson), r);
      const a = Alias(
        id: 'a1',
        deviceId: 'd1',
        alias: 'batti',
        lang: AliasLang.hi,
      );
      expect(roundTrip(a.toJson, Alias.fromJson), a);
    });

    test('TimerJob', () {
      final j = TimerJob(
        id: 'j1',
        deviceId: 'd1',
        endOn: false,
        fireAt: t.add(const Duration(minutes: 20)),
        tier: TimerTier.native,
        status: TimerStatus.active,
        meta: {'scheduleId': '7'},
        createdAt: t,
      );
      expect(roundTrip(j.toJson, TimerJob.fromJson), j);
    });

    test('Candidate', () {
      const c = Candidate(
        ip: '192.168.1.30',
        brand: Brand.tuya,
        protocol: 'tuya',
        version: '3.3',
        deviceId: 'bf1',
        needsKey: true,
        evidence: ['udp 6667 beacon'],
      );
      expect(roundTrip(c.toJson, Candidate.fromJson), c);
    });

    test('DeviceError', () {
      final e = DeviceError.timeout('no reply in 1500 ms');
      expect(roundTrip(e.toJson, DeviceError.fromJson), e);
    });

    test('TargetSpan and ClockTime', () {
      expect(roundTrip(span.toJson, TargetSpan.fromJson), span);
      const c = ClockTime(23, 30);
      expect(roundTrip(c.toJson, ClockTime.fromJson), c);
    });

    final intents = <String, Intent>{
      'power': const Intent.power(PowerAction.off, span),
      'powerFor': const Intent.powerFor(
        PowerAction.on,
        Duration(minutes: 20),
        TargetSpan(words: ['geyser']),
      ),
      'powerAfter': const Intent.powerAfter(
        PowerAction.off,
        Duration(minutes: 10),
        TargetSpan(words: ['fan']),
      ),
      'powerAt': const Intent.powerAt(
        PowerAction.off,
        ClockTime(23),
        TargetSpan(words: ['ac']),
      ),
      'powerUntil': const Intent.powerUntil(
        PowerAction.on,
        ClockTime(23),
        TargetSpan(words: ['ac']),
      ),
      'cancelTimer': const Intent.cancelTimer(TargetSpan(words: ['geyser'])),
      'status': const Intent.status(TargetSpan(words: ['geyser'])),
      'unknown': const Intent.unknown('kuch bhi'),
    };
    intents.forEach((name, intent) {
      test('Intent.$name', () {
        final json = intent.toJson();
        expect(json['type'], name);
        expect(roundTrip(() => json, Intent.fromJson), intent);
      });
    });
  });

  group('Result', () {
    test('Ok / Err accessors and map', () {
      const Result<int> a = Ok(2);
      final Result<int> b = Err(DeviceError.offline());
      expect(a.isOk, isTrue);
      expect(a.valueOrNull, 2);
      expect(a.map((v) => v * 10), const Ok(20));
      expect(b.isErr, isTrue);
      expect(b.valueOrNull, isNull);
      expect(b.errorOrNull!.kind, DeviceErrorKind.offline);
      expect(b.map((v) => v * 10), Err<int>(DeviceError.offline()));
    });

    test('then chains async and short-circuits on Err', () async {
      const Result<int> a = Ok(2);
      expect(await a.then((v) async => Ok('$v!')), const Ok('2!'));
      final Result<int> b = Err(DeviceError.auth('bad key'));
      var called = false;
      final r = await b.then((v) async {
        called = true;
        return Ok(v);
      });
      expect(called, isFalse);
      expect(r.errorOrNull!.kind, DeviceErrorKind.auth);
    });
  });

  test('ClockTime rejects invalid hour', () {
    expect(() => ClockTime(24), throwsA(isA<AssertionError>()));
  });
}
