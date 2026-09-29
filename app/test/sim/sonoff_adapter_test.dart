@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/sonoff/sonoff_adapter.dart';
import 'package:offline_home/core/log.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/net/lan_socket_factory.dart';
import 'package:offline_home/registry/secret_store.dart';

import '../support/adapter_contract.dart';
import '../support/fake_platform.dart';
import '../support/sim_process.dart';

const key = '0123456789abcdef0123456789abcdef';

Device sonoff(SimInfo s, {int? outlet}) => Device(
  id: s.id,
  brand: Brand.sonoff,
  protocol: 'sonoff',
  ip: s.host,
  port: s.port,
  name: 'Pump',
  meta: {'outlet': ?outlet},
  lastSeen: DateTime.now(),
);

void main() {
  final sockets = LanSocketFactory(FakePlatformBridge());
  const timeout = Duration(milliseconds: 800);

  Future<SonoffAdapter> adapter(SimInfo s, {String? devicekey}) async {
    final secrets = SecretStore(MemorySecretBackend(), Redactor());
    if (devicekey != null) {
      await secrets.set(s.id, SecretName.deviceKey, devicekey);
    }
    return SonoffAdapter(sockets, secrets, timeout: timeout);
  }

  for (final spec in [
    ('Sonoff DIY', 'sonoff', null),
    ('Sonoff encrypted', 'sonoff:devicekey=$key', key),
  ]) {
    adapterContractTest(spec.$1, () async {
      final sim = await SimProcess.start(spec.$2);
      return ContractHarness(
        adapter: await adapter(sim['sonoff'], devicekey: spec.$3),
        device: sonoff(sim['sonoff']),
        stopDevice: sim.stop,
        tearDown: sim.stop,
        expectedTimeout: timeout,
      );
    });
  }

  group('Sonoff vs simulator', () {
    late SimProcess sim;
    tearDown(() async => sim.stop());

    test('multi-channel outlets switch independently', () async {
      sim = await SimProcess.start('sonoff:outlets=4');
      final a = await adapter(sim['sonoff']);
      final ch2 = sonoff(sim['sonoff'], outlet: 2);
      final ch0 = sonoff(sim['sonoff'], outlet: 0);
      expect(await a.setPower(ch2, true), isA<Ok<void>>());
      expect((await a.getState(ch2)).valueOrNull?.on, isTrue);
      expect((await a.getState(ch0)).valueOrNull?.on, isFalse);
    });

    test('wrong devicekey → auth error', () async {
      sim = await SimProcess.start('sonoff:devicekey=$key');
      final a = await adapter(
        sim['sonoff'],
        devicekey: 'ffffffffffffffffffffffffffffffff',
      );
      final r = await a.setPower(sonoff(sim['sonoff']), true);
      expect(r.errorOrNull?.kind, DeviceErrorKind.auth);
    });
  });
}
