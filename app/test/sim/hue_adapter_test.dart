@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/adapters/hue/hue_adapter.dart';
import 'package:offline_home/core/log.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/net/lan_socket_factory.dart';
import 'package:offline_home/onboarding/hue_pairing.dart';
import 'package:offline_home/registry/database.dart';
import 'package:offline_home/registry/repositories.dart';
import 'package:offline_home/registry/secret_store.dart';

import '../support/adapter_contract.dart';
import '../support/fake_platform.dart';
import '../support/sim_process.dart';

Device hueLight(SimInfo s, String light) => Device(
  id: HueAdapter.lightDeviceId(s.id, light),
  brand: Brand.hue,
  protocol: 'hue',
  ip: s.host,
  port: s.port,
  name: 'Hue $light',
  capabilities: {Capability.power, Capability.brightness},
  meta: {'hueBridge': s.id, 'hueLight': light},
  lastSeen: DateTime.now(),
);

Candidate bridge(SimInfo s) => Candidate(
  ip: s.host,
  port: s.port,
  brand: Brand.hue,
  protocol: 'hue',
  deviceId: s.id,
  needsKey: true,
);

void main() {
  final sockets = LanSocketFactory(FakePlatformBridge());
  const timeout = Duration(milliseconds: 800);

  Future<(HueAdapter, SecretStore)> make(
    SimInfo s, {
    String? user = 'simuser',
  }) async {
    final secrets = SecretStore(MemorySecretBackend(), Redactor());
    if (user != null) await secrets.set(s.id, SecretName.hueUser, user);
    return (HueAdapter(sockets, secrets, timeout: timeout), secrets);
  }

  adapterContractTest('Hue light', () async {
    final sim = await SimProcess.start('hue');
    final s = sim['hue'];
    return ContractHarness(
      adapter: (await make(s)).$1,
      device: hueLight(s, '1'),
      stopDevice: sim.stop,
      tearDown: sim.stop,
      expectedTimeout: timeout,
      countdownSupported: true,
    );
  });

  test('bridge id normalisation (aiohue util.normalize_bridge_id)', () {
    expect(HueAdapter.normalizeBridgeId('001788FFFE123456'), '001788123456');
    expect(HueAdapter.normalizeBridgeId('00:17:88:12:34:56'), '001788123456');
    expect(HueAdapter.normalizeBridgeId('001788123456'), '001788123456');
    expect(
      HueAdapter.ptTime(const Duration(hours: 1, minutes: 2, seconds: 3)),
      'PT01:02:03',
    );
    expect(HueAdapter.pctToBri(50), 127);
    expect(HueAdapter.kelvinToMired(4000), 250);
  });

  group('Hue vs simulator', () {
    late SimProcess sim;
    tearDown(() async => sim.stop());

    test('pairing with the button pressed imports every light', () async {
      sim = await SimProcess.start('hue:pressed=1:lights=3');
      final s = sim['hue'];
      final (hue, secrets) = await make(s, user: null);
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final r = await HuePairing(
        hue,
        secrets,
        DeviceRepository(db),
        every: const Duration(milliseconds: 50),
      ).pairAndImport(bridge(s));
      final lights = r.valueOrNull!;
      expect(lights.map((d) => d.id), ['${s.id}-1', '${s.id}-2', '${s.id}-3']);
      expect(lights.first.capabilities, contains(Capability.colorTemp));
      expect(lights[1].capabilities, isNot(contains(Capability.colorTemp)));
      expect(await secrets.has(s.id, SecretName.hueUser), isTrue);
      expect(await hue.setPower(lights[2], true), isA<Ok<void>>());
      expect((await hue.getState(lights[2])).valueOrNull?.on, isTrue);
    });

    test('button not pressed → auth error after the window', () async {
      sim = await SimProcess.start('hue');
      final s = sim['hue'];
      final (hue, secrets) = await make(s, user: null);
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final ticks = <int>[];
      final r = await HuePairing(
        hue,
        secrets,
        DeviceRepository(db),
        window: const Duration(milliseconds: 300),
        every: const Duration(milliseconds: 100),
      ).pairAndImport(bridge(s), onTick: ticks.add);
      expect(r.errorOrNull?.kind, DeviceErrorKind.auth);
      expect(ticks, isNotEmpty);
    });

    test('unknown username → auth error', () async {
      sim = await SimProcess.start('hue');
      final (hue, _) = await make(sim['hue'], user: 'stranger');
      final r = await hue.getState(hueLight(sim['hue'], '1'));
      expect(r.errorOrNull?.kind, DeviceErrorKind.auth);
    });

    test('schedule timer can end ON; remaining time; cancel', () async {
      sim = await SimProcess.start('hue');
      final (hue, _) = await make(sim['hue']);
      final d = hueLight(sim['hue'], '2');
      expect(hue.canCountdownTo(d, true, currentOn: true), isTrue);
      final h = await hue.setCountdown(d, const Duration(seconds: 1), true);
      expect(h.valueOrNull?['scheduleId'], isNotNull);
      final left = (await hue.getCountdown(d, h.valueOrNull)).valueOrNull;
      expect(left, isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      expect((await hue.getState(d)).valueOrNull?.on, isTrue);
      expect((await hue.getCountdown(d, h.valueOrNull)).valueOrNull, isNull);

      final h2 = await hue.setCountdown(d, const Duration(seconds: 1), false);
      expect(await hue.cancelCountdown(d, h2.valueOrNull), isA<Ok<void>>());
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect((await hue.getState(d)).valueOrNull?.on, isTrue);
      expect(h2.valueOrNull, isA<CountdownHandle>());
    });
  });
}
