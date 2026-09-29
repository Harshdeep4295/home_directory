import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/kasa/kasa_xor.dart';

String hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  // Generated with python-kasa 0.10.2: XorEncryption.encrypt('{"system":{"get_sysinfo":{}}}')
  const vector =
      '0000001dd0f281f88bff9af7d5ef94b6d1b4c09fec95e68fe187e8caf08bf68bf6';

  test('XOR frame matches python-kasa byte for byte', () {
    expect(hex(KasaXor.frame(KasaXor.discoveryQuery)), vector);
    expect(
      hex(KasaXor.encrypt(utf8.encode(KasaXor.discoveryQuery))),
      vector.substring(8),
    );
  });

  test('decrypt inverts encrypt', () {
    final enc = KasaXor.encrypt(
      utf8.encode('{"system":{"set_relay_state":{"state":1}}}'),
    );
    expect(
      utf8.decode(KasaXor.decrypt(enc)),
      '{"system":{"set_relay_state":{"state":1}}}',
    );
  });

  test('KLAP discovery query and reply parsing', () {
    expect(hex(KlapDiscovery.query), '020000010000000000000000463cb5d3');
    final reply = [
      ...List.filled(16, 0),
      ...utf8.encode('{"result":{"device_type":"SMART.TAPOPLUG"}}'),
    ];
    expect(KlapDiscovery.parseReply(reply), {
      'result': {'device_type': 'SMART.TAPOPLUG'},
    });
    expect(KlapDiscovery.parseReply([1, 2, 3]), isNull);
  });
}
