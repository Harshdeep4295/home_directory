import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/discovery/camera_probes.dart';

void main() {
  test('SADP inquiry is byte-exact with hiktools fromdict', () {
    // python: str(sadp.fromdict({'Uuid':'ABC','MAC':'ff-ff-ff-ff-ff-ff','Types':'inquiry'}))
    expect(
      utf8.decode(CameraProbes.sadpInquiry('abc')),
      "<?xml version='1.0' encoding='us-ascii'?>\n"
      '<Probe><Uuid>ABC</Uuid><MAC>ff-ff-ff-ff-ff-ff</MAC><Types>inquiry</Types></Probe>',
    );
  });

  test('ONVIF probe carries the WS-Discovery Probe action and NVT type', () {
    final xml = utf8.decode(CameraProbes.onvifProbe('1234'));
    expect(
      CameraProbes.xmlText(xml, 'Action'),
      'http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe',
    );
    expect(CameraProbes.xmlText(xml, 'MessageID'), 'urn:uuid:1234');
    expect(CameraProbes.xmlText(xml, 'Types'), 'dn:NetworkVideoTransmitter');
  });

  test('OnvifMatch reads scopes regardless of namespace prefix', () {
    const reply =
        '<SOAP-ENV:Envelope><SOAP-ENV:Body><wsdd:ProbeMatches><wsdd:ProbeMatch>'
        '<wsdd:Types>tdn:NetworkVideoTransmitter tds:Device</wsdd:Types>'
        '<wsdd:Scopes>onvif://www.onvif.org/name/HIKVISION%20CAM '
        'onvif://www.onvif.org/hardware/DS-2CD2043G2-I</wsdd:Scopes>'
        '<wsdd:XAddrs>http://192.168.1.64/onvif/device_service '
        'http://[fe80::1]/onvif/device_service</wsdd:XAddrs>'
        '</wsdd:ProbeMatch></wsdd:ProbeMatches></SOAP-ENV:Body></SOAP-ENV:Envelope>';
    final m = OnvifMatch.parse(utf8.encode(reply))!;
    expect(m.isVideo, isTrue);
    expect(m.vendor, 'HIKVISION CAM');
    expect(m.model, 'DS-2CD2043G2-I');
    expect(m.ip, '192.168.1.64');
  });

  test('SadpReply ignores non-inquiry XML', () {
    expect(
      SadpReply.parse(utf8.encode('<Probe><Types>getcode</Types></Probe>')),
      isNull,
    );
    expect(SadpReply.parse(utf8.encode('not xml')), isNull);
  });

  test('uuid4 has the v4 shape', () {
    expect(
      CameraProbes.uuid4(),
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });
}
