@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/kasa/kasa_adapter.dart';
import 'package:offline_home/adapters/tuya/tuya_adapter.dart';
import 'package:offline_home/adapters/yeelight/yeelight_adapter.dart';
import 'package:offline_home/core/log.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/net/lan_socket_factory.dart';
import 'package:offline_home/registry/secret_store.dart';

import '../support/fake_platform.dart';
import '../support/sim_process.dart';

/// T7.12: what the add-devices flow learns right after adding a device.
void main() {
  final sockets = LanSocketFactory(FakePlatformBridge());
  const timeout = Duration(milliseconds: 800);
  late SimProcess sim;
  tearDown(() async => sim.stop());

  Device added(SimInfo s, Brand b, String protocol) => Device(
    id: s.id,
    brand: b,
    protocol: protocol,
    ip: s.host,
    port: s.port,
    name: 'New',
    capabilities: {Capability.power},
    lastSeen: DateTime.now(),
  );

  test('Tuya bulb added from a scan gets its DP profile and sliders', () async {
    sim = await SimProcess.start('tuya:key=0123456789abcdef:profile=bulb');
    final s = sim['tuya'];
    final secrets = SecretStore(MemorySecretBackend(), Redactor());
    await secrets.set(s.id, SecretName.localKey, '0123456789abcdef');
    final a = TuyaAdapter(sockets, secrets, timeout: timeout);
    final out = await a.onboard(added(s, Brand.tuya, s.protocol));
    expect(out.single.dpMap, TuyaDp.bulb);
    expect(
      out.single.capabilities,
      containsAll([Capability.brightness, Capability.colorTemp]),
    );
    await a.disposeAll();
  });

  test('Kasa strip becomes the strip + one device per outlet', () async {
    sim = await SimProcess.start('kasa:type=strip:children=3');
    final s = sim['kasa'];
    final out = await KasaAdapter(
      sockets,
      timeout: timeout,
    ).onboard(added(s, Brand.kasa, 'kasa'));
    expect(out, hasLength(4));
    expect(out[2].id, '${s.id}#${s.id}01');
    expect(out[2].meta['childId'], '${s.id}01');
    expect(out[2].name, 'Outlet 2');
  });

  test('Kasa bulb gets light capabilities', () async {
    sim = await SimProcess.start('kasa:type=bulb');
    final out = await KasaAdapter(
      sockets,
      timeout: timeout,
    ).onboard(added(sim['kasa'], Brand.kasa, 'kasa'));
    expect(
      out.single.capabilities,
      containsAll([Capability.brightness, Capability.colorTemp]),
    );
  });

  test('default hook: Yeelight reports brightness + colour temp', () async {
    sim = await SimProcess.start('yeelight');
    final out = await YeelightAdapter(
      sockets,
      timeout: timeout,
    ).onboard(added(sim['yeelight'], Brand.yeelight, 'yeelight'));
    expect(
      out.single.capabilities,
      containsAll([Capability.brightness, Capability.colorTemp]),
    );
  });

  test('offline device: onboard keeps the device as is', () async {
    sim = await SimProcess.start('yeelight');
    final d = added(sim['yeelight'], Brand.yeelight, 'yeelight');
    await sim.stop();
    final out = await YeelightAdapter(sockets, timeout: timeout).onboard(d);
    expect(out.single, d);
  });
}
