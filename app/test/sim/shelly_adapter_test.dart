@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/adapters/shelly/shelly_adapter.dart';
import 'package:offline_home/core/log.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/net/lan_socket_factory.dart';
import 'package:offline_home/registry/secret_store.dart';

import '../support/adapter_contract.dart';
import '../support/fake_platform.dart';
import '../support/sim_process.dart';

Device shellyDevice(SimInfo s) => Device(
  id: s.id,
  brand: Brand.shelly,
  protocol: s.protocol,
  ip: s.host,
  port: s.port,
  name: 'Porch',
  capabilities: {Capability.power, Capability.nativeCountdown},
  lastSeen: DateTime.now(),
);

void main() {
  final sockets = LanSocketFactory(FakePlatformBridge());
  const timeout = Duration(milliseconds: 800);

  Future<ShellyAdapter> adapterFor(SimInfo s, {String? password}) async {
    final secrets = SecretStore(MemorySecretBackend(), Redactor());
    if (password != null) {
      await secrets.set(s.id, SecretName.password, password);
    }
    return ShellyAdapter(sockets, secrets, timeout: timeout);
  }

  for (final spec in [
    ('Shelly Gen1', 'shelly:gen=1', null),
    ('Shelly Gen2', 'shelly:gen=2', null),
    ('Shelly Gen2 + auth', 'shelly:gen=2:password=pw', 'pw'),
    ('Shelly Gen1 + auth', 'shelly:gen=1:password=pw', 'pw'),
  ]) {
    adapterContractTest(spec.$1, () async {
      final sim = await SimProcess.start(spec.$2);
      final s = sim['shelly'];
      return ContractHarness(
        adapter: await adapterFor(s, password: spec.$3),
        device: shellyDevice(s),
        stopDevice: sim.stop,
        tearDown: sim.stop,
        expectedTimeout: timeout,
        countdownSupported: true,
      );
    });
  }

  group('Shelly adapter vs simulator', () {
    late SimProcess sim;
    late ShellyAdapter a;
    tearDown(() async {
      await a.disposeAll();
      await sim.stop();
    });

    for (final gen in [1, 2]) {
      test('gen$gen: combined powerFor turns on now, off after', () async {
        sim = await SimProcess.start('shelly:gen=$gen');
        a = await adapterFor(sim['shelly']);
        final d = shellyDevice(sim['shelly']);
        expect(a.supportsCombinedPowerFor(d), isTrue);
        expect(
          await a.powerFor(d, true, const Duration(seconds: 1)),
          isA<Ok<CountdownHandle>>(),
        );
        final st = (await a.getState(d)).valueOrNull!;
        expect(st.on, isTrue);
        expect(st.countdownLeft, isNotNull);
        await Future<void>.delayed(const Duration(milliseconds: 1400));
        expect((await a.getState(d)).valueOrNull?.on, isFalse);
      });

      test('gen$gen: password missing / wrong → auth error', () async {
        sim = await SimProcess.start('shelly:gen=$gen:password=pw');
        a = await adapterFor(sim['shelly']);
        final d = shellyDevice(sim['shelly']);
        expect((await a.getState(d)).errorOrNull?.kind, DeviceErrorKind.auth);
        a = await adapterFor(sim['shelly'], password: 'nope');
        expect((await a.getState(d)).errorOrNull?.kind, DeviceErrorKind.auth);
      });

      test('gen$gen: cancelCountdown keeps the state', () async {
        sim = await SimProcess.start('shelly:gen=$gen');
        a = await adapterFor(sim['shelly']);
        final d = shellyDevice(sim['shelly']);
        await a.powerFor(d, true, const Duration(seconds: 1));
        expect(await a.cancelCountdown(d, null), isA<Ok<void>>());
        await Future<void>.delayed(const Duration(milliseconds: 1300));
        final st = (await a.getState(d)).valueOrNull!;
        expect(st.on, isTrue);
        expect(st.countdownLeft, isNull);
      });
    }
  });
}
