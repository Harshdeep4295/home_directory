@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/adapters/kasa/kasa_adapter.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/net/lan_socket_factory.dart';

import '../support/adapter_contract.dart';
import '../support/fake_platform.dart';
import '../support/sim_process.dart';

Device kasaDevice(SimInfo s, {Map<String, Object?> meta = const {}}) => Device(
  id: s.id,
  brand: Brand.kasa,
  protocol: 'kasa',
  ip: s.host,
  port: s.port,
  name: 'Kettle',
  capabilities: {Capability.power, Capability.nativeCountdown},
  meta: meta,
  lastSeen: DateTime.now(),
);

void main() {
  final sockets = LanSocketFactory(FakePlatformBridge());
  const timeout = Duration(milliseconds: 800);
  KasaAdapter adapter() => KasaAdapter(sockets, timeout: timeout);

  for (final spec in [
    ('Kasa plug', 'kasa'),
    ('Kasa plug (countdown module)', 'kasa:countdown_module=countdown'),
    ('Kasa bulb', 'kasa:type=bulb'),
  ]) {
    adapterContractTest(spec.$1, () async {
      final sim = await SimProcess.start(spec.$2);
      return ContractHarness(
        adapter: adapter(),
        device: kasaDevice(sim['kasa']),
        stopDevice: sim.stop,
        tearDown: sim.stop,
        expectedTimeout: timeout,
        countdownSupported: true,
      );
    });
  }

  test('does not claim KLAP / AES devices', () {
    final a = adapter();
    final d = Device(
      id: 'x',
      brand: Brand.tapo,
      protocol: 'klap-smart',
      ip: '1.2.3.4',
      name: 'x',
      lastSeen: DateTime.now(),
    );
    expect(a.handles(d), isFalse);
    expect(a.handles(d.copyWith(protocol: 'kasa')), isTrue);
  });

  group('Kasa adapter vs simulator', () {
    late SimProcess sim;
    tearDown(() async => sim.stop());

    test('countdown can end ON (rules carry an action)', () async {
      sim = await SimProcess.start('kasa');
      final a = adapter();
      final d = kasaDevice(sim['kasa']);
      expect(a.canCountdownTo(d, true, currentOn: true), isTrue);
      expect(
        await a.setCountdown(d, const Duration(seconds: 1), true),
        isA<Ok<CountdownHandle>>(),
      );
      expect((await a.getState(d)).valueOrNull?.countdownLeft, isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      final st = (await a.getState(d)).valueOrNull!;
      expect(st.on, isTrue);
      expect(st.countdownLeft, isNull);
    });

    test('strip outlet addressed by context child_ids', () async {
      sim = await SimProcess.start('kasa:type=strip:children=3');
      final s = sim['kasa'];
      final a = adapter();
      final outlet2 = kasaDevice(s, meta: {'childId': '${s.id}01'});
      final outlet1 = kasaDevice(s, meta: {'childId': '${s.id}00'});
      expect(await a.setPower(outlet2, true), isA<Ok<void>>());
      expect((await a.getState(outlet2)).valueOrNull?.on, isTrue);
      expect((await a.getState(outlet1)).valueOrNull?.on, isFalse);
    });

    test('bulb brightness and colour temperature', () async {
      sim = await SimProcess.start('kasa:type=bulb');
      final a = adapter();
      final d = kasaDevice(sim['kasa']);
      expect(await a.setBrightness(d, 40), isA<Ok<void>>());
      expect(await a.setColorTemp(d, 4000), isA<Ok<void>>());
      final st = (await a.getState(d)).valueOrNull!;
      expect(st.on, isTrue);
      expect(st.brightness, 40);
      expect(st.colorTemp, 4000);
    });

    test('plug refuses brightness', () async {
      sim = await SimProcess.start('kasa');
      final r = await adapter().setBrightness(kasaDevice(sim['kasa']), 50);
      expect(r.errorOrNull?.kind, DeviceErrorKind.unsupported);
    });
  });
}
