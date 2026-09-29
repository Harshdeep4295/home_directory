@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/kasa/kasa_adapter.dart';
import 'package:offline_home/adapters/kasa/tapo_adapter.dart';
import 'package:offline_home/core/log.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/net/lan_socket_factory.dart';
import 'package:offline_home/registry/secret_store.dart';

import '../support/adapter_contract.dart';
import '../support/fake_platform.dart';
import '../support/sim_process.dart';

Device klapDevice(SimInfo s) => Device(
  id: s.id,
  brand: s.protocol == 'klap-smart' ? Brand.tapo : Brand.kasa,
  protocol: s.protocol,
  ip: s.host,
  port: s.port,
  name: 'Lamp',
  lastSeen: DateTime.now(),
);

void main() {
  final sockets = LanSocketFactory(FakePlatformBridge());
  const timeout = Duration(milliseconds: 800);

  Future<SecretStore> account({String pw = 'hunter2'}) async {
    final s = SecretStore(MemorySecretBackend(), Redactor());
    await s.set(KasaAdapter.accountId, SecretName.email, 'user@example.com');
    await s.set(KasaAdapter.accountId, SecretName.password, pw);
    return s;
  }

  adapterContractTest('Tapo plug (SMART.KLAP)', () async {
    final sim = await SimProcess.start('klap:family=smart');
    return ContractHarness(
      adapter: TapoAdapter(sockets, await account(), timeout: timeout),
      device: klapDevice(sim['klap']),
      stopDevice: sim.stop,
      tearDown: sim.stop,
      expectedTimeout: timeout,
    );
  });

  adapterContractTest('Kasa over KLAP (IOT.KLAP)', () async {
    final sim = await SimProcess.start('klap:family=iot');
    return ContractHarness(
      adapter: KasaAdapter(sockets, secrets: await account(), timeout: timeout),
      device: klapDevice(sim['klap']),
      stopDevice: sim.stop,
      tearDown: sim.stop,
      expectedTimeout: timeout,
      countdownSupported: true,
    );
  });

  group('KLAP devices vs simulator', () {
    late SimProcess sim;
    tearDown(() async => sim.stop());

    test('Tapo bulb brightness + colour temperature', () async {
      sim = await SimProcess.start('klap:family=smart:type=bulb');
      final a = TapoAdapter(sockets, await account(), timeout: timeout);
      final d = klapDevice(sim['klap']);
      expect(await a.setPower(d, true), isA<Ok<void>>());
      expect(await a.setBrightness(d, 30), isA<Ok<void>>());
      expect(await a.setColorTemp(d, 4000), isA<Ok<void>>());
      final st = (await a.getState(d)).valueOrNull!;
      expect((st.on, st.brightness, st.colorTemp), (true, 30, 4000));
    });

    test('wrong TP-Link password → auth error', () async {
      sim = await SimProcess.start('klap:family=smart');
      final a = TapoAdapter(
        sockets,
        await account(pw: 'nope'),
        timeout: timeout,
      );
      final r = await a.getState(klapDevice(sim['klap']));
      expect(r.errorOrNull?.kind, DeviceErrorKind.auth);
    });

    test('adapters split klap-iot / klap-smart / kasa', () async {
      sim = await SimProcess.start('klap:family=smart');
      final k = KasaAdapter(sockets);
      final t = TapoAdapter(sockets, await account());
      final d = klapDevice(sim['klap']);
      expect(t.handles(d), isTrue);
      expect(k.handles(d), isFalse);
      expect(k.handles(d.copyWith(protocol: 'klap-iot')), isTrue);
      expect(t.handles(d.copyWith(protocol: 'klap-iot')), isFalse);
      expect(t.nativeCountdownMax(d), isNull, reason: 'phone tier');
    });
  });
}
