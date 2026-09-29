import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/net/platform_bridge.dart';
import 'package:offline_home/ui/app.dart';
import 'package:offline_home/ui/widgets/net_banner.dart';

import 'support/test_services.dart';

void main() {
  testWidgets('shell: three tabs and the local-mode banner', (tester) async {
    final t = await TestServices.inTester(
      tester,
      net: const NetInfo(
        wifi: true,
        internet: false,
        ip: '192.168.1.5',
        prefix: 24,
      ),
    );
    await tester.pumpWidget(t.wrap(const OfflineHomeApp()));
    await TestServices.settle(tester); // onboarded check → shell
    await TestServices.settle(tester); // network state → banner
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['Home', 'Timers', 'Settings']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text(NetBannerView.localModeText), findsOneWidget);
    await tester.tap(find.text('Timers').last);
    await tester.pump();
    await t.tearDown(tester);
  });
}
