@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/kasa/klap.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/net/lan_socket_factory.dart';

import '../support/fake_platform.dart';
import '../support/sim_process.dart';

void main() {
  final sockets = LanSocketFactory(FakePlatformBridge());
  late SimProcess sim;
  tearDown(() async => sim.stop());

  KlapTransport transport(
    SimInfo s,
    KlapVersion v, {
    String? user = 'user@example.com',
    String? pw = 'hunter2',
  }) => KlapTransport(
    sockets,
    host: s.host,
    port: s.port,
    version: v,
    username: user,
    password: pw,
    timeout: const Duration(milliseconds: 800),
  );

  test('SMART.KLAP (v2): get / set device info', () async {
    sim = await SimProcess.start('klap:family=smart');
    final t = transport(sim['klap'], KlapVersion.v2);
    final r = await t.send({'method': 'get_device_info'});
    expect(
      (r.valueOrNull!['result'] as Map)['device_on'],
      isFalse,
      reason: '$r',
    );
    final s = await t.send({
      'method': 'set_device_info',
      'params': {'device_on': true},
    });
    expect(s.valueOrNull?['error_code'], 0);
    final r2 = await t.send({'method': 'get_device_info'});
    expect((r2.valueOrNull!['result'] as Map)['device_on'], isTrue);
  });

  test('IOT.KLAP (v1): legacy JSON over KLAP', () async {
    sim = await SimProcess.start('klap:family=iot');
    final t = transport(sim['klap'], KlapVersion.v1);
    final r = await t.send({
      'system': {
        'set_relay_state': {'state': 1},
      },
    });
    expect(
      ((r.valueOrNull!['system'] as Map)['set_relay_state'] as Map)['err_code'],
      0,
    );
  });

  test('falls back to python-kasa default credentials', () async {
    sim = await SimProcess.start('klap:family=smart:creds=TAPO');
    final t = transport(sim['klap'], KlapVersion.v2, user: 'x', pw: 'y');
    expect((await t.send({'method': 'get_device_info'})).isOk, isTrue);
  });

  test('wrong account → auth error', () async {
    sim = await SimProcess.start('klap:family=smart');
    final t = transport(sim['klap'], KlapVersion.v2, pw: 'wrong');
    final r = await t.send({'method': 'get_device_info'});
    expect(r.errorOrNull?.kind, DeviceErrorKind.auth);
  });

  test(
    'lost session (403) → new handshake, same transport keeps working',
    () async {
      sim = await SimProcess.start('klap:family=smart');
      final s = sim['klap'];
      final t = transport(s, KlapVersion.v2);
      expect((await t.send({'method': 'get_device_info'})).isOk, isTrue);
      await sim.stop();
      sim = await SimProcess.start(
        'klap:family=smart:port=${s.port}:id=${s.id}',
      );
      expect((await t.send({'method': 'get_device_info'})).isOk, isTrue);
    },
  );
}
