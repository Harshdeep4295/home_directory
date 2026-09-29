import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/kasa/kasa_xor.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/discovery/evidence.dart';
import 'package:offline_home/discovery/fingerprinter.dart';
import 'package:offline_home/net/lan_socket_factory.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));
Uint8List hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
]);
HttpReply ok(String body) => HttpReply(200, const {}, b(body));

/// Recorded / reference replies. Source noted per fixture; "SIM" = produced by our simulator
/// or generator because no real recording exists yet (replace with HARDWARE_LOG recordings).
final tuyaVectors = jsonDecode(
  File('test/adapters/tuya/vectors_3x.json').readAsStringSync(),
) as Map<String, Object?>;

typedef Case = ({
  String name,
  HostEvidence Function() evidence,
  Brand brand,
  String protocol,
  String? deviceId,
  bool needsKey,
});

void main() {
  final cases = <Case>[
    (
      name: 'Tuya beacon 3.3 (SIM: tinytuya-generated 6667 frame)',
      evidence: () => HostEvidence('192.168.1.30')
        ..addUdp(
          UdpProbe.tuyaBeacon,
          hex((tuyaVectors['beacon']! as Map)['frame6667']! as String),
        )
        ..openPorts.add(ScanPort.tuya),
      brand: Brand.tuya,
      protocol: 'tuya-3.3',
      deviceId: '01234567890123456789',
      needsKey: true,
    ),
    (
      name: 'WiZ registration reply (pywizlight tests/fake_bulb.py)',
      evidence: () => HostEvidence('192.168.1.31')
        ..addUdp(
          UdpProbe.wiz,
          b(
            '{"method":"registration","env":"pro","result":{"mac":"a8bb5006033d","success":true}}',
          ),
        )
        ..openPorts.add(ScanPort.http),
      brand: Brand.wiz,
      protocol: 'wiz',
      deviceId: 'a8bb5006033d',
      needsKey: false,
    ),
    (
      name: 'Hue bridge via mDNS + /api/config (Hue API v1 docs sample)',
      evidence: () => HostEvidence('192.168.1.32')
        ..mdns.add(
          const MdnsRecord(
            type: '_hue._tcp',
            name: 'Philips Hue - 1A2B3C',
            port: 443,
            attributes: {'bridgeid': '001788FFFE1A2B3C'},
          ),
        )
        ..http['/api/config'] = ok(
          '{"name":"Philips hue","bridgeid":"001788FFFE1A2B3C","modelid":"BSB002"}',
        ),
      brand: Brand.hue,
      protocol: 'hue',
      deviceId: '001788fffe1a2b3c',
      needsKey: true,
    ),
    (
      name: 'Shelly Gen1 /shelly (Shelly Gen1 API docs sample)',
      evidence: () => HostEvidence('192.168.1.33')
        ..openPorts.add(ScanPort.http)
        ..http['/shelly'] = ok(
          '{"type":"SHSW-1","mac":"AABBCCDDEEFF","auth":false,"fw":"20230913-112003/v1.14.0-gcb84623","num_outputs":1}',
        ),
      brand: Brand.shelly,
      protocol: 'shelly-gen1',
      deviceId: 'aabbccddeeff',
      needsKey: false,
    ),
    (
      name: 'Shelly Gen2 /shelly with auth (Shelly Gen2 API docs sample)',
      evidence: () => HostEvidence('192.168.1.34')
        ..openPorts.add(ScanPort.http)
        ..http['/shelly'] = ok(
          '{"name":null,"id":"shellyplus1-a8032ab12345","mac":"A8032AB12345","model":"SNSW-001X16EU","gen":2,"fw_id":"20231107-164738/1.0.8-g","ver":"1.0.8","app":"Plus1","auth_en":true,"auth_domain":"shellyplus1-a8032ab12345"}',
        ),
      brand: Brand.shelly,
      protocol: 'shelly-gen2',
      deviceId: 'a8032ab12345',
      needsKey: true,
    ),
    (
      name: 'Sonoff eWeLink LAN, encrypted (SonoffLAN TXT fields; SIM)',
      evidence: () => HostEvidence('192.168.1.35')
        ..mdns.add(
          const MdnsRecord(
            type: '_ewelink._tcp',
            name: 'eWeLink_1000abcdef',
            port: 8081,
            attributes: {
              'id': '1000abcdef',
              'type': 'plug',
              'encrypt': 'true',
              'txtvers': '1',
            },
          ),
        ),
      brand: Brand.sonoff,
      protocol: 'sonoff',
      deviceId: '1000abcdef',
      needsKey: true,
    ),
    (
      name: 'ESPHome mDNS (ESPHome native API TXT; SIM)',
      evidence: () => HostEvidence('192.168.1.36')
        ..mdns.add(
          const MdnsRecord(
            type: '_esphomelib._tcp',
            name: 'kitchen-plug',
            port: 6053,
            attributes: {
              'mac': 'aabbcc112233',
              'friendly_name': 'Kitchen Plug',
            },
          ),
        ),
      brand: Brand.esphome,
      protocol: 'esphome',
      deviceId: 'aabbcc112233',
      needsKey: false,
    ),
    (
      name: 'Kasa legacy XOR sysinfo (python-kasa sysinfo fields; SIM)',
      evidence: () => HostEvidence('192.168.1.37')
        ..addUdp(
          UdpProbe.kasa,
          KasaXor.encrypt(
            b(
              '{"system":{"get_sysinfo":{"alias":"Lamp","mac":"50:C7:BF:00:11:22","model":"HS100(US)","deviceId":"8006ABC","mic_type":"IOT.SMARTPLUGSWITCH","relay_state":0}}}',
            ),
          ),
        ),
      brand: Brand.kasa,
      protocol: 'kasa',
      deviceId: '8006ABC',
      needsKey: false,
    ),
    (
      name: 'Tapo KLAP 20002 (python-kasa DiscoveryResult fields; SIM)',
      evidence: () => HostEvidence('192.168.1.38')
        ..addUdp(
          UdpProbe.klap,
          Uint8List.fromList([
            ...List.filled(16, 0),
            ...b(
              '{"result":{"device_id":"abc123","device_type":"SMART.TAPOPLUG","device_model":"P100(EU)","ip":"192.168.1.38","mac":"AA-BB-CC-DD-EE-FF","mgt_encrypt_schm":{"is_support_https":false,"encrypt_type":"KLAP","http_port":80}},"error_code":0}',
            ),
          ]),
        ),
      brand: Brand.tapo,
      protocol: 'klap-smart',
      deviceId: 'abc123',
      needsKey: true,
    ),
    (
      name: 'Kasa KP125M IOT.KLAP 20002 (python-kasa DiscoveryResult fields; SIM)',
      evidence: () => HostEvidence('192.168.1.39')
        ..addUdp(
          UdpProbe.klap,
          Uint8List.fromList([
            ...List.filled(16, 0),
            ...b(
              '{"result":{"device_id":"iot456","device_type":"IOT.SMARTPLUGSWITCH","device_model":"KP125M(US)","ip":"192.168.1.39","mac":"AA-BB-CC-DD-EE-00","mgt_encrypt_schm":{"is_support_https":false,"encrypt_type":"KLAP","http_port":80}},"error_code":0}',
            ),
          ]),
        ),
      brand: Brand.kasa,
      protocol: 'klap-iot',
      deviceId: 'iot456',
      needsKey: true,
    ),
    (
      name: 'Tapo hub SMART.AES over HTTPS → not supported (SIM)',
      evidence: () => HostEvidence('192.168.1.40')
        ..addUdp(
          UdpProbe.klap,
          Uint8List.fromList([
            ...List.filled(16, 0),
            ...b(
              '{"result":{"device_id":"hub1","device_type":"SMART.TAPOHUB","device_model":"H200","ip":"192.168.1.40","mac":"AA-BB-CC-DD-EE-01","mgt_encrypt_schm":{"is_support_https":true,"encrypt_type":"AES","http_port":443}},"error_code":0}',
            ),
          ]),
        ),
      brand: Brand.tapo,
      protocol: 'tplink-smart-aes-https',
      deviceId: 'hub1',
      needsKey: true,
    ),
    (
      name: 'Yeelight SSDP (python-yeelight ssdp_discover.py docstring)',
      evidence: () => HostEvidence('10.0.7.184')
        ..addUdp(
          UdpProbe.yeelight,
          b(
            'HTTP/1.1 200 OK\r\nCache-Control: max-age=3600\r\nLocation: yeelight://10.0.7.184:55443\r\nServer: POSIX UPnP/1.0 YGLC/1\r\nid: 0x00000000037073d2\r\nmodel: color\r\nfw_ver: 76\r\n',
          ),
        ),
      brand: Brand.yeelight,
      protocol: 'yeelight',
      deviceId: '0x00000000037073d2',
      needsKey: false,
    ),
    (
      name: 'Tasmota Status 0 (Tasmota commands docs sample)',
      evidence: () => HostEvidence('192.168.1.40')
        ..openPorts.add(ScanPort.http)
        ..http['/cm?cmnd=Status%200'] = ok(
          '{"Status":{"Module":1,"DeviceName":"Heater","FriendlyName":["Heater"],"Power":0},"StatusNET":{"Hostname":"tasmota-1234","IPAddress":"192.168.1.40","Mac":"DC:4F:22:00:12:34"}}',
        ),
      brand: Brand.tasmota,
      protocol: 'tasmota',
      deviceId: 'dc4f22001234',
      needsKey: false,
    ),
    (
      name: 'Tuya by open port only (no beacon, e.g. iOS)',
      evidence: () =>
          HostEvidence('192.168.1.41')..openPorts.add(ScanPort.tuya),
      brand: Brand.tuya,
      protocol: 'tuya',
      deviceId: null,
      needsKey: true,
    ),
    (
      name: 'Unknown web device',
      evidence: () => HostEvidence('192.168.1.42')
        ..openPorts.add(ScanPort.http)
        ..http['/'] = HttpReply(200, const {'server': 'lighttpd'}, b('<html>')),
      brand: Brand.unknown,
      protocol: 'unknown',
      deviceId: null,
      needsKey: false,
    ),
  ];

  for (final c in cases) {
    test(c.name, () {
      final cand = Fingerprinter.identify(c.evidence())!;
      expect(cand.brand, c.brand);
      expect(cand.protocol, c.protocol);
      expect(cand.deviceId, c.deviceId);
      expect(cand.needsKey, c.needsKey);
      expect(cand.evidence, isNotEmpty);
    });
  }

  test('nothing interesting → null', () {
    expect(
      Fingerprinter.identify(
        HostEvidence('1.2.3.4')..openPorts.add(ScanPort.sonoffDiy),
      ),
      isNull,
    );
    expect(Fingerprinter.identify(HostEvidence('1.2.3.4')), isNull);
  });

  test('stored secrets turn "needs key" into ready', () {
    final tuya = cases.first.evidence();
    expect(
      Fingerprinter.identify(
        tuya,
        known: const KnownSecrets(deviceIds: {'01234567890123456789'}),
      )!.needsKey,
      isFalse,
    );
    final tapo = cases.firstWhere((c) => c.brand == Brand.tapo).evidence();
    expect(
      Fingerprinter.identify(
        tapo,
        known: const KnownSecrets(tplinkAccount: true),
      )!.needsKey,
      isFalse,
    );
  });

  test('first match wins: beacon beats open port; WiZ beats generic HTTP', () {
    final both = cases.first.evidence();
    expect(Fingerprinter.identify(both)!.protocol, 'tuya-3.3');
    final wiz = cases[1].evidence();
    expect(Fingerprinter.identify(wiz)!.brand, Brand.wiz);
  });
}
