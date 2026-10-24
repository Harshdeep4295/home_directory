import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/cameras/camera.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/net/ipv4.dart';
import 'package:offline_home/net/lan_socket_factory.dart';
import 'package:offline_home/onboarding/share_setup/share_setup.dart';
import 'package:offline_home/registry/config_export.dart';
import 'package:offline_home/registry/secret_store.dart';

import '../support/fake_platform.dart';
import '../support/test_services.dart';

bool loopback(String h) => h == '127.0.0.1';

ConfigExporter exporterOf(TestServices t) => ConfigExporter(
  t.services.devices,
  t.services.rooms,
  t.services.settings,
  t.services.secrets,
  iterations: 1000,
);

void main() {
  final lan = LanSocketFactory(FakePlatformBridge());

  test('QR: round trip; only private LAN hosts; bad codes rejected', () {
    final k = 'A' * 43;
    final qr = SetupQr('192.168.1.28', 40123, k);
    final back = SetupQr.parse(qr.encode())!;
    expect((back.host, back.port, back.token), ('192.168.1.28', 40123, k));
    expect(back.path, matches(RegExp(r'^/setup/[0-9a-f]{16}$')));
    expect(back.path, isNot(contains(k)));
    for (final bad in [
      'ohsetup:1?h=8.8.8.8&p=1&k=$k',
      'ohsetup:1?h=example.com&p=1&k=$k',
      'ohsetup:1?h=192.168.1.2&p=0&k=$k',
      'ohsetup:1?h=192.168.1.2&p=80&k=short',
      'ohsetup:2?h=192.168.1.2&p=80&k=$k',
      'https://evil.example/?h=192.168.1.2',
    ]) {
      expect(SetupQr.parse(bad), isNull, reason: bad);
    }
    expect(isPrivateIpv4('10.0.0.1'), isTrue);
    expect(isPrivateIpv4('172.31.255.1'), isTrue);
    expect(isPrivateIpv4('172.32.0.1'), isFalse);
    expect(isPrivateIpv4('192.169.0.1'), isFalse);
  });

  test(
    'share → receive copies devices, places, cameras and keys once',
    () async {
      final src = await TestServices.create(
        devices: [testDevice('geyser', 'Geyser').copyWith(place: 'Village')],
      );
      await src.services.secrets.set(
        'geyser',
        SecretName.localKey,
        '0123456789abcdef',
      );
      await src.services.cameras.put(
        const Camera(
          id: 'cam1',
          name: 'Door',
          ip: '192.168.1.7',
          mainPath: '/main',
          place: 'Village',
        ),
      );
      await src.services.secrets.set('cam1', SecretName.password, 'ABCDEF');

      final sender = SetupSender(lan, exporterOf(src), allowHost: loopback);
      final offer = (await sender.start('127.0.0.1')).valueOrNull!;
      expect(offer.qr.token.length, 43, reason: '256-bit key, base64url');

      final dst = await TestServices.create();
      final receiver = SetupReceiver(lan, exporterOf(dst), allowHost: loopback);
      final r = await receiver.receive(offer.qr.encode());
      expect(r.valueOrNull, 1);
      expect(await offer.done, ShareEnd.sent);
      expect((await dst.services.devices.byId('geyser'))!.place, 'Village');
      expect(
        await dst.services.secrets.get('geyser', SecretName.localKey),
        '0123456789abcdef',
      );
      expect((await dst.services.cameras.all()).single.place, 'Village');
      expect(
        await dst.services.secrets.get('cam1', SecretName.password),
        'ABCDEF',
      );

      // One transfer only: the server is gone.
      final again = await receiver.receive(offer.qr.encode());
      expect(again.isOk, isFalse);
      await src.dispose();
      await dst.dispose();
    },
  );

  test('wrong key or path gets nothing; cancel and expiry close it', () async {
    final src = await TestServices.create(
      devices: [testDevice('geyser', 'Geyser')],
    );
    final sender = SetupSender(lan, exporterOf(src), allowHost: loopback);
    final offer = (await sender.start('127.0.0.1')).valueOrNull!;
    final dst = await TestServices.create();
    final receiver = SetupReceiver(lan, exporterOf(dst), allowHost: loopback);
    final wrong = SetupQr('127.0.0.1', offer.qr.port, 'B' * 43).encode();
    final r = await receiver.receive(wrong);
    expect(r.errorOrNull?.kind, DeviceErrorKind.protocol);
    expect(await dst.services.devices.all(), isEmpty);
    offer.cancel();
    expect(await offer.done, ShareEnd.cancelled);
    expect((await receiver.receive(offer.qr.encode())).isOk, isFalse);

    final short = SetupSender(
      lan,
      exporterOf(src),
      allowHost: loopback,
      expireAfter: const Duration(milliseconds: 50),
    );
    final o2 = (await short.start('127.0.0.1')).valueOrNull!;
    expect(await o2.done, ShareEnd.expired);
    await src.dispose();
    await dst.dispose();
  });

  test('no private Wi-Fi address → clear error, nothing served', () async {
    final src = await TestServices.create();
    final sender = SetupSender(lan, exporterOf(src));
    for (final ip in [null, '127.0.0.1', '100.64.0.1']) {
      final r = await sender.start(ip);
      expect(r.errorOrNull?.message, contains('Wi-Fi'), reason: '$ip');
    }
    await src.dispose();
  });
}
