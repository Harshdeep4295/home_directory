@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/tasmota/tasmota_adapter.dart';
import 'package:offline_home/core/log.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/net/lan_socket_factory.dart';
import 'package:offline_home/registry/secret_store.dart';

import '../support/adapter_contract.dart';
import '../support/fake_platform.dart';
import '../support/sim_process.dart';

Device tasmota(SimInfo s, {int? relay}) => Device(
  id: s.id,
  brand: Brand.tasmota,
  protocol: 'tasmota',
  ip: s.host,
  port: s.port,
  name: 'Fan',
  meta: {'relay': ?relay},
  lastSeen: DateTime.now(),
);

void main() {
  final sockets = LanSocketFactory(FakePlatformBridge());
  const timeout = Duration(milliseconds: 800);

  Future<TasmotaAdapter> adapter(SimInfo s, {String? password}) async {
    final secrets = SecretStore(MemorySecretBackend(), Redactor());
    if (password != null) {
      await secrets.set(s.id, SecretName.password, password);
    }
    return TasmotaAdapter(sockets, secrets, timeout: timeout);
  }

  for (final spec in [
    ('Tasmota', 'tasmota', null),
    ('Tasmota + password', 'tasmota:password=pw', 'pw'),
  ]) {
    adapterContractTest(spec.$1, () async {
      final sim = await SimProcess.start(spec.$2);
      return ContractHarness(
        adapter: await adapter(sim['tasmota'], password: spec.$3),
        device: tasmota(sim['tasmota']),
        stopDevice: sim.stop,
        tearDown: sim.stop,
        expectedTimeout: timeout,
        combinedPowerForOnly: true,
      );
    });
  }

  test('PulseTime encoding (Tasmota docs)', () {
    expect(TasmotaAdapter.pulseValue(const Duration(milliseconds: 500)), 5);
    expect(TasmotaAdapter.pulseValue(const Duration(seconds: 11)), 110);
    expect(TasmotaAdapter.pulseValue(const Duration(seconds: 12)), 112);
    expect(TasmotaAdapter.pulseValue(const Duration(minutes: 20)), 1300);
    expect(TasmotaAdapter.pulseDuration(1300), const Duration(minutes: 20));
    expect(TasmotaAdapter.pulseDuration(7), const Duration(milliseconds: 700));
  });

  group('Tasmota vs simulator', () {
    late SimProcess sim;
    tearDown(() async => sim.stop());

    test('a finished pulse is cleared so the next ON stays on', () async {
      sim = await SimProcess.start('tasmota');
      final a = await adapter(sim['tasmota']);
      final d = tasmota(sim['tasmota']);
      await a.powerFor(d, true, const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(
        (await a.getState(d)).valueOrNull?.on,
        isFalse,
      ); // clears PulseTime
      expect(await a.setPower(d, true), isA<Ok<void>>());
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect((await a.getState(d)).valueOrNull?.on, isTrue);
    });

    test('relay 2 and pulse-only countdown rules', () async {
      sim = await SimProcess.start('tasmota:relays=2');
      final a = await adapter(sim['tasmota']);
      final r2 = tasmota(sim['tasmota'], relay: 2);
      expect(await a.setPower(r2, true), isA<Ok<void>>());
      expect((await a.getState(r2)).valueOrNull?.on, isTrue);
      expect(
        (await a.getState(tasmota(sim['tasmota'], relay: 1))).valueOrNull?.on,
        isFalse,
      );
      expect(a.canCountdownTo(r2, false, currentOn: true), isFalse);
      expect(
        (await a.powerFor(
          r2,
          false,
          const Duration(minutes: 1),
        )).errorOrNull?.kind,
        DeviceErrorKind.unsupported,
      );
    });
  });
}
