@Tags(['sim'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/tuya/tuya_codec.dart';
import 'package:offline_home/discovery/collectors.dart';
import 'package:offline_home/discovery/evidence.dart';
import 'package:offline_home/discovery/mdns_browser.dart';
import 'package:offline_home/net/lan_socket_factory.dart';

import '../support/fake_platform.dart';
import '../support/sim_process.dart';

class FakeMdns implements MdnsBrowser {
  FakeMdns(this.records);
  final List<(String, MdnsRecord)> records;
  List<String>? browsedTypes;

  @override
  Future<List<(String, MdnsRecord)>> browse(
    List<String> types,
    Duration window,
  ) async {
    browsedTypes = types;
    return records;
  }
}

Future<int> freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final p = s.port;
  await s.close();
  return p;
}

void main() {
  late SimProcess sim;
  late HttpServer shelly;
  late int beaconPort;
  late int closedPort;

  setUp(() async {
    beaconPort = await freePort();
    closedPort = await freePort();
    sim = await SimProcess.start('wiz,tuya:beacon_port=$beaconPort');
    shelly = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    shelly.listen((req) async {
      if (req.uri.path == '/shelly') {
        req.response.write('{"type":"SHSW-1","mac":"AABBCCDDEEFF","gen":1}');
      } else {
        req.response.statusCode = 404;
      }
      await req.response.close();
    });
  });
  tearDown(() async {
    await sim.stop();
    await shelly.close(force: true);
  });

  CandidateCollector collector(FakePlatformBridge platform, MdnsBrowser mdns) =>
      CandidateCollector(
        LanSocketFactory(platform),
        platform,
        mdns,
        hosts: const ['127.0.0.1'],
        broadcastAddress: '127.0.0.1',
        ports: DiscoveryPorts(
          wiz: sim['wiz'].port,
          wizBind: 0,
          kasa: closedPort,
          klap: closedPort,
          yeelight: closedPort,
          tuyaBeacons: [beaconPort],
          tuyaApp: closedPort,
          tcp: {
            ScanPort.tuya: sim['tuya'].port,
            ScanPort.http: shelly.port,
            ScanPort.kasa: closedPort,
          },
        ),
      );

  test(
    'collects WiZ reply, Tuya beacon, open ports, HTTP and mDNS for one host',
    () async {
      final platform = FakePlatformBridge();
      final mdns = FakeMdns([
        (
          '127.0.0.1',
          const MdnsRecord(type: '_http._tcp', name: 'thing', port: 80),
        ),
        (
          '10.0.0.9',
          const MdnsRecord(type: '_hue._tcp', name: 'Hue Bridge', port: 443),
        ),
      ]);
      final ev = await collector(
        platform,
        mdns,
      ).collect(window: const Duration(milliseconds: 1600));

      final local = ev['127.0.0.1']!;
      expect(local.udp[UdpProbe.wiz], isNotEmpty);
      expect(
        String.fromCharCodes(local.udp[UdpProbe.wiz]!.first),
        contains(sim['wiz'].id),
      );
      final beacon = decodeTuyaBeacon(local.udp[UdpProbe.tuyaBeacon]!.first)!;
      expect(beacon['gwId'], sim['tuya'].id);
      expect(local.openPorts, containsAll([ScanPort.tuya, ScanPort.http]));
      expect(local.openPorts, isNot(contains(ScanPort.kasa)));
      expect(local.http['/shelly']!.json, containsPair('type', 'SHSW-1'));
      expect(local.hasMdns('_http._tcp'), isTrue);
      expect(ev['10.0.0.9']!.hasMdns('_hue._tcp'), isTrue);
      expect(mdns.browsedTypes, mdnsServiceTypes);
      expect(platform.locksHeld, 0, reason: 'multicast lock released');
      await platform.dispose();
    },
  );

  test('iOS (no broadcast): unicast fallback still finds WiZ', () async {
    final platform = FakePlatformBridge(canBroadcast: false);
    final ev = await collector(
      platform,
      FakeMdns(const []),
    ).collect(window: const Duration(milliseconds: 1200));
    expect(ev['127.0.0.1']!.udp[UdpProbe.wiz], isNotEmpty);
    expect(ev['127.0.0.1']!.udp.containsKey(UdpProbe.yeelight), isFalse);
    await platform.dispose();
  });
}
