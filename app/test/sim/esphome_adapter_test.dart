@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/esphome/esphome_adapter.dart';
import 'package:offline_home/core/log.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/net/lan_socket_factory.dart';
import 'package:offline_home/registry/secret_store.dart';

import '../support/adapter_contract.dart';
import '../support/fake_platform.dart';
import '../support/sim_process.dart';

Device esp(SimInfo s, {String entity = 'switch/relay'}) => Device(
  id: s.id,
  brand: Brand.esphome,
  protocol: 'esphome',
  ip: s.host,
  port: s.port,
  name: 'Garage',
  meta: {'espEntity': entity},
  lastSeen: DateTime.now(),
);

void main() {
  final sockets = LanSocketFactory(FakePlatformBridge());
  const timeout = Duration(milliseconds: 800);

  Future<EspHomeAdapter> adapter(SimInfo s, {String? password}) async {
    final secrets = SecretStore(MemorySecretBackend(), Redactor());
    if (password != null) {
      await secrets.set(s.id, SecretName.password, password);
    }
    return EspHomeAdapter(sockets, secrets, timeout: timeout);
  }

  for (final spec in [
    ('ESPHome switch', 'esphome', null, 'switch/relay'),
    (
      'ESPHome light + auth',
      'esphome:light=lamp:password=pw',
      'pw',
      'light/lamp',
    ),
  ]) {
    adapterContractTest(spec.$1, () async {
      final sim = await SimProcess.start(spec.$2);
      return ContractHarness(
        adapter: await adapter(sim['esphome'], password: spec.$3),
        device: esp(sim['esphome'], entity: spec.$4),
        stopDevice: sim.stop,
        tearDown: sim.stop,
        expectedTimeout: timeout,
      );
    });
  }

  group('ESPHome vs simulator', () {
    late SimProcess sim;
    tearDown(() async => sim.stop());

    test('light brightness round-trip', () async {
      sim = await SimProcess.start('esphome:light=lamp');
      final a = await adapter(sim['esphome']);
      final d = esp(sim['esphome'], entity: 'light/lamp');
      expect(await a.setBrightness(d, 50), isA<Ok<void>>());
      final st = (await a.getState(d)).valueOrNull!;
      expect((st.on, st.brightness), (true, 50));
    });

    test('unknown entity → unsupported; missing password → auth', () async {
      sim = await SimProcess.start('esphome:password=pw');
      final a = await adapter(sim['esphome']);
      expect(
        (await a.getState(esp(sim['esphome']))).errorOrNull?.kind,
        DeviceErrorKind.auth,
      );
      final b = await adapter(sim['esphome'], password: 'pw');
      expect(
        (await b.getState(esp(sim['esphome'], entity: 'switch/nope')))
            .errorOrNull
            ?.kind,
        DeviceErrorKind.unsupported,
      );
    });
  });
}
