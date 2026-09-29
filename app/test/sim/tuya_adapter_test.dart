@Tags(['sim'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/adapters/tuya/tuya_adapter.dart';
import 'package:offline_home/core/log.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/net/lan_socket_factory.dart';
import 'package:offline_home/registry/secret_store.dart';

import '../support/adapter_contract.dart';
import '../support/fake_platform.dart';
import '../support/sim_process.dart';

const key = '0123456789abcdef';

Device tuyaDevice(SimInfo s, {Map<String, int>? dpMap, int? port}) => Device(
  id: s.id,
  brand: Brand.tuya,
  protocol: s.protocol,
  ip: s.host,
  port: port ?? s.port,
  name: 'Geyser',
  capabilities: {Capability.power, Capability.nativeCountdown},
  dpMap: dpMap,
  lastSeen: DateTime.now(),
);

Future<int> freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final p = s.port;
  await s.close();
  return p;
}

void main() {
  final sockets = LanSocketFactory(FakePlatformBridge());
  const timeout = Duration(milliseconds: 800);

  Future<(TuyaAdapter, SecretStore)> make({String? withKey = key}) async {
    final secrets = SecretStore(MemorySecretBackend(), Redactor());
    return (TuyaAdapter(sockets, secrets, timeout: timeout), secrets);
  }

  Future<TuyaAdapter> adapterFor(SimInfo s, {String k = key}) async {
    final (a, secrets) = await make();
    await secrets.set(s.id, SecretName.localKey, k);
    return a;
  }

  adapterContractTest('Tuya 3.3', () async {
    final sim = await SimProcess.start('tuya:key=$key');
    final s = sim['tuya'];
    return ContractHarness(
      adapter: await adapterFor(s),
      device: tuyaDevice(s),
      stopDevice: sim.stop,
      tearDown: sim.stop,
      expectedTimeout: timeout,
      countdownSupported: true,
    );
  });

  adapterContractTest('Tuya 3.4', () async {
    final sim = await SimProcess.start('tuya:key=$key:version=3.4');
    final s = sim['tuya'];
    expect(s.protocol, 'tuya-3.4');
    return ContractHarness(
      adapter: await adapterFor(s),
      device: tuyaDevice(s),
      stopDevice: sim.stop,
      tearDown: sim.stop,
      expectedTimeout: timeout,
      countdownSupported: true,
    );
  });

  adapterContractTest('Tuya 3.5', () async {
    final sim = await SimProcess.start('tuya:key=$key:version=3.5');
    final s = sim['tuya'];
    expect(s.protocol, 'tuya-3.5');
    return ContractHarness(
      adapter: await adapterFor(s),
      device: tuyaDevice(s),
      stopDevice: sim.stop,
      tearDown: sim.stop,
      expectedTimeout: timeout,
      countdownSupported: true,
    );
  });

  group('Tuya adapter vs simulator', () {
    late SimProcess sim;
    late TuyaAdapter a;
    tearDown(() async {
      await a.disposeAll();
      await sim.stop();
    });

    test('no local key → auth error, never a throw', () async {
      sim = await SimProcess.start('tuya');
      (a, _) = await make();
      final r = await a.getState(tuyaDevice(sim['tuya']));
      expect(r.errorOrNull?.kind, DeviceErrorKind.auth);
    });

    test('wrong key → error, no throw', () async {
      sim = await SimProcess.start('tuya:key=$key');
      a = await adapterFor(sim['tuya'], k: 'fedcba9876543210');
      expect((await a.getState(tuyaDevice(sim['tuya']))).isErr, isTrue);
    });

    test('device22 is detected and queried with CONTROL_NEW', () async {
      sim = await SimProcess.start('tuya:key=$key:device22=1');
      final s = sim['tuya'];
      expect(s.id.length, 22);
      a = await adapterFor(s);
      final d = tuyaDevice(s);
      final r = await a.getState(d);
      expect(r.valueOrNull?.on, isFalse, reason: '$r');
      expect(a.isDevice22(d), isTrue);
      expect(await a.setPower(d, true), isA<Ok<void>>());
      expect((await a.getState(d)).valueOrNull?.on, isTrue);
    });

    test('3.4: wrong key → auth error from the session handshake', () async {
      sim = await SimProcess.start('tuya:key=$key:version=3.4');
      a = await adapterFor(sim['tuya'], k: 'fedcba9876543210');
      final r = await a.getState(tuyaDevice(sim['tuya']));
      expect(r.errorOrNull?.kind, DeviceErrorKind.auth, reason: '$r');
    });

    test('3.4: STATUS pushes arrive over the session', () async {
      sim = await SimProcess.start('tuya:key=$key:version=3.4');
      a = await adapterFor(sim['tuya']);
      final d = tuyaDevice(sim['tuya']);
      final pushes = <bool?>[];
      final sub = a.watch(d)!.listen((st) => pushes.add(st.on));
      expect(await a.setPower(d, true), isA<Ok<void>>());
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await sub.cancel();
      expect(pushes, contains(true));
    });

    test('3.5: wrong key → auth error', () async {
      sim = await SimProcess.start('tuya:key=$key:version=3.5');
      a = await adapterFor(sim['tuya'], k: 'fedcba9876543210');
      final r = await a.getState(tuyaDevice(sim['tuya']));
      expect(r.errorOrNull?.kind, DeviceErrorKind.auth, reason: '$r');
    });

    test('3.5: replies matched by command (device seqno differs)', () async {
      sim = await SimProcess.start('tuya:key=$key:version=3.5');
      a = await adapterFor(sim['tuya']);
      final d = tuyaDevice(sim['tuya']);
      for (var i = 0; i < 3; i++) {
        expect(await a.setPower(d, i.isEven), isA<Ok<void>>());
        expect((await a.getState(d)).valueOrNull?.on, i.isEven);
      }
    });

    test('bulb type B: brightness and colour temperature round-trip', () async {
      sim = await SimProcess.start('tuya:key=$key:profile=bulb');
      a = await adapterFor(sim['tuya']);
      final d = tuyaDevice(sim['tuya'], dpMap: TuyaDp.bulb);
      expect(await a.setBrightness(d, 50), isA<Ok<void>>());
      expect(await a.setColorTemp(d, TuyaDp.kelvinMax), isA<Ok<void>>());
      final dps = (await a.queryDps(d)).valueOrNull!;
      expect(dps['22'], 500, reason: 'int(1000 * 50 // 100)');
      expect(dps['23'], 1000);
      expect(dps['21'], 'white');
      final st = (await a.getState(d)).valueOrNull!;
      expect(st.on, isTrue);
      expect(st.brightness, 50);
      expect(st.colorTemp, TuyaDp.kelvinMax);
    });

    test('bulb type A detected without a stored dpMap', () async {
      sim = await SimProcess.start('tuya:key=$key:profile=bulba');
      a = await adapterFor(sim['tuya']);
      final dps = (await a.queryDps(tuyaDevice(sim['tuya']))).valueOrNull!;
      final map = TuyaDp.detect(dps);
      expect(map[TuyaDp.brightness], 3);
      final d = tuyaDevice(sim['tuya'], dpMap: map);
      expect(await a.setBrightness(d, 50), isA<Ok<void>>());
      expect((await a.queryDps(d)).valueOrNull!['3'], 127);
    });

    test('multi-gang: gangs share one session, switch independently', () async {
      sim = await SimProcess.start('tuya:key=$key:gang=3');
      final s = sim['tuya'];
      a = await adapterFor(s);
      Device gang(int n) => tuyaDevice(s).copyWith(
        id: TuyaAdapter.gangDeviceId(s.id, n),
        dpMap: TuyaDp.gang(n),
        meta: n == 1 ? const {} : {'tuyaId': s.id, 'gang': n},
      );
      expect(await a.setPower(gang(2), true), isA<Ok<void>>());
      expect((await a.getState(gang(2))).valueOrNull?.on, isTrue);
      expect((await a.getState(gang(1))).valueOrNull?.on, isFalse);
      expect((await a.getState(gang(3))).valueOrNull?.on, isFalse);
      // gang 2's own countdown (DP 8) flips only gang 2
      expect(
        await a.setCountdown(gang(2), const Duration(seconds: 1), false),
        isA<Ok<CountdownHandle>>(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      expect((await a.getState(gang(2))).valueOrNull?.on, isFalse);
    });

    test('protocol 3.1', () async {
      sim = await SimProcess.start('tuya:key=$key:version=3.1');
      final s = sim['tuya'];
      expect(s.protocol, 'tuya-3.1');
      a = await adapterFor(s);
      final d = tuyaDevice(s);
      expect(await a.setPower(d, true), isA<Ok<void>>());
      expect((await a.getState(d)).valueOrNull?.on, isTrue);
    });

    test('bulb profile detected from DPs when no dpMap is stored', () async {
      sim = await SimProcess.start('tuya:key=$key:profile=bulb');
      a = await adapterFor(sim['tuya']);
      final d = tuyaDevice(sim['tuya'], dpMap: TuyaDp.bulb);
      expect(await a.setPower(d, true), isA<Ok<void>>());
      final dps = (await a.queryDps(d)).valueOrNull!;
      expect(TuyaDp.detect(dps), TuyaDp.bulb);
      expect((await a.getState(d)).valueOrNull?.on, isTrue);
    });

    test('reconnects after the device restarts', () async {
      final port = await freePort();
      sim = await SimProcess.start('tuya:key=$key:port=$port');
      final s = sim['tuya'];
      a = await adapterFor(s);
      final d = tuyaDevice(s);
      expect(await a.setPower(d, true), isA<Ok<void>>());
      await sim.stop();
      expect((await a.getState(d)).isErr, isTrue);
      sim = await SimProcess.start('tuya:key=$key:port=$port:id=${s.id}');
      final r = await a.getState(d);
      expect(r.valueOrNull?.on, isFalse, reason: 'fresh sim starts off: $r');
    });

    test(
      'watch receives STATUS pushes (control and countdown expiry)',
      () async {
        sim = await SimProcess.start('tuya:key=$key');
        a = await adapterFor(sim['tuya']);
        final d = tuyaDevice(sim['tuya']);
        final states = <bool?>[];
        final sub = a.watch(d)!.listen((s) => states.add(s.on));
        expect(await a.setPower(d, true), isA<Ok<void>>());
        expect(
          await a.setCountdown(d, const Duration(seconds: 1), false),
          isA<Ok<Object>>(),
        );
        await Future<void>.delayed(const Duration(milliseconds: 1800));
        await sub.cancel();
        expect(states, containsAllInOrder([true, false]));
      },
    );

    test(
      'countdown: refuses when already in target state; get + cancel',
      () async {
        sim = await SimProcess.start('tuya:key=$key');
        a = await adapterFor(sim['tuya']);
        final d = tuyaDevice(sim['tuya']);
        expect(
          (await a.setCountdown(
            d,
            const Duration(seconds: 30),
            false,
          )).errorOrNull?.kind,
          DeviceErrorKind.protocol,
          reason: 'device is off; an off-countdown would flip it on',
        );
        expect(a.canCountdownTo(d, false, currentOn: false), isFalse);
        await a.setPower(d, true);
        expect(
          await a.setCountdown(d, const Duration(seconds: 30), false),
          isA<Ok<Object>>(),
        );
        final left = (await a.getCountdown(d, null)).valueOrNull;
        expect(left!.inSeconds, inInclusiveRange(28, 30));
        expect(await a.cancelCountdown(d, null), isA<Ok<void>>());
        expect((await a.getCountdown(d, null)).valueOrNull, isNull);
        expect((await a.getState(d)).valueOrNull?.on, isTrue);
      },
    );
  });
}
