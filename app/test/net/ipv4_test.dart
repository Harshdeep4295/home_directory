import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/net/ipv4.dart';

void main() {
  test('parse / format round-trip and rejects junk', () {
    expect(formatIpv4(parseIpv4('192.168.1.37')!), '192.168.1.37');
    for (final bad in ['', '1.2.3', '1.2.3.256', 'a.b.c.d', '1.2.3.4.5']) {
      expect(parseIpv4(bad), isNull, reason: bad);
    }
  });

  test('subnetBroadcast', () {
    expect(subnetBroadcast('192.168.1.37', 24), '192.168.1.255');
    expect(subnetBroadcast('10.0.5.9', 22), '10.0.7.255');
    expect(subnetBroadcast('10.0.5.9', 32), '10.0.5.9');
    expect(subnetBroadcast('garbage', 24), '255.255.255.255');
  });

  test('subnetHosts excludes network, broadcast and self; caps at /22', () {
    final hosts = subnetHosts('192.168.1.37', 24);
    expect(hosts, hasLength(253));
    expect(hosts.first, '192.168.1.1');
    expect(hosts.last, '192.168.1.254');
    expect(hosts, isNot(contains('192.168.1.37')));
    expect(subnetHosts('10.1.2.3', 16), hasLength(1021)); // narrowed to /22
  });
}
