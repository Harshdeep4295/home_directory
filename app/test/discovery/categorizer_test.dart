import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/discovery/categorizer.dart';
import 'package:offline_home/discovery/evidence.dart';
import 'package:offline_home/discovery/fingerprinter.dart';
import 'package:offline_home/discovery/mdns_browser.dart';
import 'package:offline_home/net/lan_socket_factory.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

/// Reply produced by sim/ohsim/devices/camera.py SadpSim (fields per hiktools DiscoveryPacket).
const sadpReply =
    "<?xml version='1.0' encoding='utf-8'?>\n<ProbeMatch><Uuid>X</Uuid><Types>inquiry</Types>"
    '<DeviceType>138210</DeviceType><DeviceDescription>CS-C6N-A0-1C2WFR</DeviceDescription>'
    '<DeviceSN>CS-C6N-A0-1C2WFR20210101CCRRF12345678</DeviceSN><CommandPort>8000</CommandPort>'
    '<HttpPort>80</HttpPort><MAC>c0-56-e3-12-34-56</MAC><Ipv4Address>192.168.1.40</Ipv4Address>'
    '<Activated>true</Activated></ProbeMatch>';

/// ONVIF ProbeMatch as OnvifSim sends it (scopes per the ONVIF Core spec).
const onvifReply =
    '<env:Envelope><env:Body><d:ProbeMatches><d:ProbeMatch>'
    '<d:Types>dn:NetworkVideoTransmitter</d:Types>'
    '<d:Scopes>onvif://www.onvif.org/type/video_encoder onvif://www.onvif.org/name/HIKVISION '
    'onvif://www.onvif.org/hardware/DS-2CD1043G0-I</d:Scopes>'
    '<d:XAddrs>http://192.168.1.41/onvif/device_service</d:XAddrs>'
    '</d:ProbeMatch></d:ProbeMatches></env:Body></env:Envelope>';

Candidate? id(HostEvidence e) => Fingerprinter.identify(e);

void main() {
  test('SADP reply → Hikvision camera with model and MAC', () {
    final c = id(
      HostEvidence('192.168.1.40')..addUdp(UdpProbe.sadp, b(sadpReply)),
    )!;
    expect(c.brand, Brand.unknown);
    expect(c.category, DeviceCategory.camera);
    expect(c.model, 'CS-C6N-A0-1C2WFR');
    expect(c.mac, 'c056e3123456');
    expect(c.name, 'Hikvision CS-C6N-A0-1C2WFR');
    final cam = Categorizer.camera(
      HostEvidence('192.168.1.40')..addUdp(UdpProbe.sadp, b(sadpReply)),
    )!;
    expect(cam.hikvision, isTrue);
    expect(cam.activated, isTrue);
  });

  test('ONVIF video device → camera named by its scopes', () {
    final c = id(
      HostEvidence('192.168.1.41')..addUdp(UdpProbe.onvif, b(onvifReply)),
    )!;
    expect(c.category, DeviceCategory.camera);
    expect(c.name, 'HIKVISION DS-2CD1043G0-I');
    expect(
      Categorizer.camera(
        HostEvidence('x')..addUdp(UdpProbe.onvif, b(onvifReply)),
      )!.hikvision,
      isTrue,
    );
  });

  test(
    'RTSP port alone → camera; Hikvision web server name → Hikvision camera',
    () {
      expect(
        id(HostEvidence('192.168.1.42')..openPorts.add(ScanPort.rtsp))!
            .category,
        DeviceCategory.camera,
      );
      final e = HostEvidence('192.168.1.43')
        ..openPorts.add(ScanPort.http)
        ..http['/'] = HttpReply(200, const {'server': 'App-webs/'}, b(''));
      final c = id(e)!;
      expect(c.category, DeviceCategory.camera);
      expect(Categorizer.camera(e)!.hikvision, isTrue);
    },
  );

  test(
    'Cast: audio models are speakers, others TV (pychromecast CAST_TYPES)',
    () {
      HostEvidence cast(String md) => HostEvidence('192.168.1.50')
        ..mdns.add(
          MdnsRecord(
            type: '_googlecast._tcp',
            name: 'x',
            port: 8009,
            attributes: {'md': md, 'fn': 'Living room'},
          ),
        );
      final mini = id(cast('Google Nest Mini'))!;
      expect(mini.category, DeviceCategory.speaker);
      expect(mini.name, 'Living room');
      expect(id(cast('Chromecast'))!.category, DeviceCategory.tv);
    },
  );

  test('mDNS types map to TV, printer and computer', () {
    Candidate one(String type) => id(
      HostEvidence('192.168.1.60')
        ..mdns.add(MdnsRecord(type: type, name: 'Thing', port: 1)),
    )!;
    expect(one('_amzn-wplay._tcp').category, DeviceCategory.tv);
    expect(one('_ipp._tcp').category, DeviceCategory.printer);
    expect(one('_companion-link._tcp').category, DeviceCategory.computer);
    expect(one('_http._tcp').category, DeviceCategory.other);
  });

  test('router guess: .1 with a web page → Network', () {
    final c = id(HostEvidence('192.168.1.1')..openPorts.add(ScanPort.http))!;
    expect(c.category, DeviceCategory.network);
  });

  test('supported devices are lights & plugs', () {
    final wiz = id(
      HostEvidence('192.168.1.31')
        ..addUdp(
          UdpProbe.wiz,
          b(
            '{"method":"registration","result":{"mac":"a8bb5006033d","success":true}}',
          ),
        )
        ..openPorts.add(ScanPort.rtsp),
    )!;
    expect(wiz.brand, Brand.wiz);
    expect(Categorizer.of(wiz), DeviceCategory.lightsPlugs);
  });

  test('iOS NSBonjourServices lists every browsed mDNS type', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    for (final t in mdnsServiceTypes) {
      expect(plist, contains('<string>$t</string>'), reason: t);
    }
  });
}
