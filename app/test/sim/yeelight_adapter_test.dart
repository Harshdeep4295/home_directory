@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/yeelight/yeelight_adapter.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/net/lan_socket_factory.dart';

import '../support/adapter_contract.dart';
import '../support/fake_platform.dart';
import '../support/sim_process.dart';

Device yeelight(SimInfo s) => Device(
  id: s.id,
  brand: Brand.yeelight,
  protocol: 'yeelight',
  ip: s.host,
  port: s.port,
  name: 'Desk lamp',
  capabilities: {
    Capability.power,
    Capability.brightness,
    Capability.colorTemp,
    Capability.nativeCountdown,
  },
  lastSeen: DateTime.now(),
);

void main() {
  final sockets = LanSocketFactory(FakePlatformBridge());
  const timeout = Duration(milliseconds: 800);
  YeelightAdapter adapter() => YeelightAdapter(sockets, timeout: timeout);

  // minute=1: the sim counts cron "minutes" as seconds so the suite stays fast.
  adapterContractTest('Yeelight', () async {
    final sim = await SimProcess.start('yeelight:minute=1');
    return ContractHarness(
      adapter: adapter(),
      device: yeelight(sim['yeelight']),
      stopDevice: sim.stop,
      tearDown: sim.stop,
      expectedTimeout: timeout,
      countdownSupported: true,
    );
  });

  group('Yeelight vs simulator', () {
    late SimProcess sim;
    tearDown(() async => sim.stop());

    test('brightness / colour temp; props notifications are skipped', () async {
      sim = await SimProcess.start('yeelight');
      final a = adapter();
      final d = yeelight(sim['yeelight']);
      expect(await a.setPower(d, true), isA<Ok<void>>());
      expect(await a.setBrightness(d, 35), isA<Ok<void>>());
      expect(await a.setColorTemp(d, 2700), isA<Ok<void>>());
      final st = (await a.getState(d)).valueOrNull!;
      expect((st.on, st.brightness, st.colorTemp), (true, 35, 2700));
    });

    test('cron timer is off-only; remaining time reported', () async {
      sim = await SimProcess.start('yeelight:minute=1');
      final a = adapter();
      final d = yeelight(sim['yeelight']);
      expect(a.canCountdownTo(d, true, currentOn: false), isFalse);
      expect(a.canCountdownTo(d, false, currentOn: true), isTrue);
      expect(
        (await a.setCountdown(
          d,
          const Duration(minutes: 2),
          true,
        )).errorOrNull?.kind,
        DeviceErrorKind.unsupported,
      );
      await a.setPower(d, true);
      await a.setCountdown(d, const Duration(minutes: 2), false);
      expect(
        (await a.getCountdown(d, null)).valueOrNull,
        const Duration(minutes: 2),
      );
      expect(await a.cancelCountdown(d, null), isA<Ok<void>>());
      expect((await a.getCountdown(d, null)).valueOrNull, isNull);
    });
  });
}
