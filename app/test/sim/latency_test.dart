@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/adapters/shelly/shelly_adapter.dart';
import 'package:offline_home/adapters/tuya/tuya_adapter.dart';
import 'package:offline_home/adapters/wiz/wiz_adapter.dart';
import 'package:offline_home/core/log.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/perf.dart';
import 'package:offline_home/engine/command_engine.dart';
import 'package:offline_home/net/lan_socket_factory.dart';
import 'package:offline_home/registry/database.dart';
import 'package:offline_home/registry/repositories.dart';
import 'package:offline_home/registry/secret_store.dart';

import '../support/fake_platform.dart';
import '../support/sim_process.dart';

/// T8.2: tap → device p95 < 500 ms. On loopback this bounds our own overhead (framing,
/// crypto, engine queue); real Wi-Fi numbers come from the in-app Diagnostics tile.
void main() {
  test('tap → device p95 under budget for WiZ, Tuya 3.3/3.4, Shelly', () async {
    final sim = await SimProcess.start(
      'wiz,tuya:key=0123456789abcdef,tuya:key=0123456789abcdef:version=3.4,shelly:gen=2',
    );
    addTearDown(sim.stop);
    final sockets = LanSocketFactory(FakePlatformBridge());
    final secrets = SecretStore(MemorySecretBackend(), Redactor());
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final registry = AdapterRegistry([
      WizAdapter(sockets),
      TuyaAdapter(sockets, secrets),
      ShellyAdapter(sockets, secrets),
    ]);
    addTearDown(registry.disposeAll);
    final engine = CommandEngine(registry, StateCacheRepository(db));
    final devices = <Device>[];
    for (final name in ['wiz', 'tuya', 'tuya-2', 'shelly']) {
      final s = sim[name];
      if (s.kind == 'tuya') {
        await secrets.set(s.id, SecretName.localKey, '0123456789abcdef');
      }
      final d = Device(
        id: s.id,
        brand: Brand.unknown,
        protocol: s.protocol,
        ip: s.host,
        port: s.port,
        name: name,
        lastSeen: DateTime.now(),
      );
      await DeviceRepository(db).upsert(d);
      devices.add(d);
    }
    for (final d in devices) {
      final family = d.protocol.split('-').first;
      final before = Perf.latency.count(family);
      for (var i = 0; i < 20; i++) {
        expect((await engine.powerOne(d, i.isEven)).isOk, isTrue);
      }
      expect(Perf.latency.count(family) - before, greaterThanOrEqualTo(20));
      final p95 = Perf.latency.percentile(family, 0.95)!;
      expect(p95, lessThan(Perf.tapBudget), reason: '${d.protocol} p95 $p95');
    }
    await engine.dispose();
  });
}
