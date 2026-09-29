@Tags(['sim'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/adapters/wiz/wiz_adapter.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/net/lan_socket_factory.dart';

import '../support/adapter_contract.dart';
import '../support/fake_platform.dart';
import '../support/sim_process.dart';

Device wizDevice(SimInfo s, {Set<Capability>? caps}) => Device(
  id: s.id,
  brand: Brand.wiz,
  protocol: 'wiz',
  ip: s.host,
  port: s.port,
  name: 'WiZ',
  capabilities:
      caps ?? {Capability.power, Capability.brightness, Capability.colorTemp},
  lastSeen: DateTime.now(),
);

void main() {
  final sockets = LanSocketFactory(FakePlatformBridge());
  const timeout = Duration(milliseconds: 600);
  WizAdapter adapter() => WizAdapter(
    sockets,
    timeout: timeout,
    resendAfter: const Duration(milliseconds: 250),
  );

  adapterContractTest('WiZ', () async {
    final sim = await SimProcess.start('wiz');
    return ContractHarness(
      adapter: adapter(),
      device: wizDevice(sim['wiz']),
      stopDevice: sim.stop,
      tearDown: sim.stop,
      expectedTimeout: timeout,
    );
  });

  group('WiZ adapter vs simulator', () {
    late SimProcess sim;
    tearDown(() => sim.stop());

    test('probe identifies WiZ with module-based capabilities', () async {
      sim = await SimProcess.start('wiz:module=ESP01_SHTW1C_31:fw=1.21.0');
      final s = sim['wiz'];
      // probe uses the standard port, so exercise the same path with the sim's port.
      final r = await adapter().request(s.host, 'getPilot', port: s.port);
      final cfg = (await adapter().request(
        s.host,
        'getSystemConfig',
        port: s.port,
      )).valueOrNull;
      final c = WizAdapter.candidateFrom(
        s.host,
        r.valueOrNull!['mac']! as String,
        cfg,
      );
      expect(c.brand, Brand.wiz);
      expect(c.deviceId, s.id);
      expect(c.evidence, containsAll(['module ESP01_SHTW1C_31', 'fw 1.21.0']));
      expect(
        WizAdapter.capabilitiesForModule('ESP01_SHTW1C_31'),
        contains(Capability.colorTemp),
      );
    });

    test('brightness and colour temperature round-trip', () async {
      sim = await SimProcess.start('wiz');
      final d = wizDevice(sim['wiz']);
      final a = adapter();
      expect(await a.setBrightness(d, 40), isA<Ok<void>>());
      expect(await a.setColorTemp(d, 4000), isA<Ok<void>>());
      final s = (await a.getState(d)).valueOrNull!;
      expect(s.brightness, 40);
      expect(s.colorTemp, 4000);
    });

    test('resends once when the first datagram is dropped', () async {
      sim = await SimProcess.start('wiz:drop=1');
      final r = await adapter().getState(wizDevice(sim['wiz']));
      expect(r.isOk, isTrue, reason: '$r');
    });

    test('no native countdown → phone tier', () async {
      sim = await SimProcess.start('wiz');
      final d = wizDevice(sim['wiz']);
      expect(adapter().nativeCountdownMax(d), isNull);
      expect(adapter().canCountdownTo(d, false, currentOn: true), isFalse);
    });
  });

  group('WiZ pure logic', () {
    test('capabilitiesForModule follows pywizlight BulbType.from_data', () {
      expect(WizAdapter.capabilitiesForModule('ESP10_SOCKET_06'), {
        Capability.power,
      });
      expect(
        WizAdapter.capabilitiesForModule('ESP01_SHRGB_03'),
        containsAll([Capability.rgb, Capability.colorTemp]),
      );
      expect(WizAdapter.capabilitiesForModule('ESP01_SHDW1C_31'), {
        Capability.power,
        Capability.brightness,
      });
      expect(
        WizAdapter.capabilitiesForModule(null),
        contains(Capability.brightness),
      );
    });

    test('parseReply handles errors, mismatches and junk', () {
      expect(
        WizAdapter.parseReply(
          'getPilot',
          '{"method":"getPilot","error":{"code":-32601}}',
        ).errorOrNull?.kind,
        DeviceErrorKind.unsupported,
      );
      expect(
        WizAdapter.parseReply('getPilot', 'nope').errorOrNull?.kind,
        DeviceErrorKind.protocol,
      );
      expect(
        WizAdapter.parseReply(
          'getPilot',
          '{"method":"setPilot","result":{}}',
        ).errorOrNull?.kind,
        DeviceErrorKind.protocol,
      );
      expect(
        WizAdapter.parseReply(
          'getPilot',
          '{"method":"getPilot","result":{"state":true}}',
        ).valueOrNull,
        {'state': true},
      );
    });

    test('unsupported features on a plug', () async {
      final plug = Device(
        id: 'p',
        brand: Brand.wiz,
        protocol: 'wiz',
        ip: '127.0.0.1',
        name: 'plug',
        lastSeen: DateTime.now(),
      );
      final a = adapter();
      expect(
        (await a.setBrightness(plug, 10)).errorOrNull?.kind,
        DeviceErrorKind.unsupported,
      );
      expect(a.handles(plug), isTrue);
      expect(a, isA<DeviceAdapter>());
    });
  });
}
