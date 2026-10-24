import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/net/lan_socket_factory.dart';
import 'package:offline_home/net/platform_bridge.dart';
import 'package:offline_home/onboarding/share_setup/share_setup.dart';
import 'package:offline_home/registry/config_export.dart';
import 'package:offline_home/ui/screens/share_setup_screen.dart';

import '../support/fake_platform.dart';
import '../support/test_services.dart';

bool loopback(String h) => h == '127.0.0.1';

void main() {
  // The widget-test binding fakes HttpClient (every request → 400); these tests talk
  // to a real loopback server.
  setUp(() => HttpOverrides.global = null);

  testWidgets('share: QR shown on Wi-Fi; no Wi-Fi explains', (tester) async {
    final t = await TestServices.inTester(
      tester,
      devices: [testDevice('geyser', 'Geyser')],
      net: const NetInfo(wifi: true, ip: '127.0.0.1', prefix: 8),
    );
    t.services.shareHostCheck = loopback;
    await tester.pumpWidget(
      t.wrap(const MaterialApp(home: ShareSetupScreen())),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('setup-qr')), findsOne);
    expect(find.textContaining('works once and for 5'), findsOne);
    await t.tearDown(tester);

    final off = await TestServices.inTester(
      tester,
      net: const NetInfo(wifi: false),
    );
    await tester.pumpWidget(
      off.wrap(const MaterialApp(home: ShareSetupScreen())),
    );
    await TestServices.settle(tester);
    expect(find.textContaining('Connect to your home Wi-Fi'), findsOne);
    await off.tearDown(tester);
  });

  testWidgets('receive: bad code explains; good code imports', (tester) async {
    final t = await TestServices.inTester(tester);
    t.services.shareHostCheck = loopback;
    void Function(String)? scan;
    await tester.pumpWidget(
      t.wrap(
        const MaterialApp(home: ReceiveSetupScreen()),
        overrides: [
          qrScannerProvider.overrideWithValue((onCode) {
            scan = onCode;
            return const SizedBox(key: ValueKey('fake-scanner'));
          }),
        ],
      ),
    );
    await tester.pump();
    scan!('https://example.com');
    await TestServices.settle(tester);
    expect(find.text('This is not an Offline Home setup code.'), findsOne);

    final src = (await tester.runAsync(
      () => TestServices.create(devices: [testDevice('geyser', 'Geyser')]),
    ))!;
    final sender = SetupSender(
      LanSocketFactory(FakePlatformBridge()),
      ConfigExporter(
        src.services.devices,
        src.services.rooms,
        src.services.settings,
        src.services.secrets,
        iterations: 1000,
      ),
      allowHost: loopback,
    );
    final offer = (await tester.runAsync(() => sender.start('127.0.0.1')))!
        .valueOrNull!;
    await tester.runAsync(() async {
      scan!(offer.qr.encode());
      final end = await offer.done.timeout(
        const Duration(seconds: 5),
        onTimeout: () => ShareEnd.expired,
      );
      expect(end, ShareEnd.sent);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    expect(find.textContaining('Received 1 devices'), findsOne);
    expect(
      await tester.runAsync(() => t.services.devices.byId('geyser')),
      isNotNull,
    );
    await tester.runAsync(src.dispose);
    await t.tearDown(tester);
  });
}
