import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/intent.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/timers/tier_copy.dart';
import 'package:offline_home/ui/screens/timers_screen.dart';

import '../support/test_services.dart';

void main() {
  testWidgets('lists timers by fire time with tier, cancels, iOS warning', (
    tester,
  ) async {
    final geyser = testDevice('geyser', 'Geyser');
    final lamp = testDevice(
      'lamp',
      'Lamp',
      brand: Brand.wiz,
      protocol: 'wiz',
    ).copyWith(nativeCountdownMax: null);
    final t = await TestServices.inTester(tester, devices: [geyser, lamp]);
    // 30 h exceeds the fake's 24 h native max → phone tier.
    await tester.runAsync(() async {
      await t.services.timerService.powerFor(
        [geyser],
        PowerAction.on,
        const Duration(minutes: 20),
      );
      await t.services.timerService.powerFor(
        [lamp],
        PowerAction.on,
        const Duration(hours: 30),
      );
    });
    await tester.pumpWidget(
      t.wrap(
        const MaterialApp(home: Scaffold(body: TimersScreen(isIOS: true))),
      ),
    );
    await TestServices.settle(tester);

    expect(find.textContaining('Geyser off in'), findsOneWidget);
    expect(find.textContaining('Lamp off in 29h 59m'), findsOneWidget);
    expect(find.text('Plug'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text(TierCopy.iosPhoneWarning), findsOneWidget);
    final first = tester.getTopLeft(find.textContaining('Geyser off in')).dy;
    final second = tester.getTopLeft(find.textContaining('Lamp off in')).dy;
    expect(first, lessThan(second), reason: 'soonest first');

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Cancel timer').first);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await TestServices.settle(tester);
    expect(find.textContaining('Geyser off in'), findsNothing);
    await t.tearDown(tester);
  });

  testWidgets('empty state', (tester) async {
    final t = await TestServices.inTester(tester);
    await tester.pumpWidget(
      t.wrap(
        const MaterialApp(home: Scaffold(body: TimersScreen(isIOS: false))),
      ),
    );
    await TestServices.settle(tester);
    expect(find.text('No timers running'), findsOneWidget);
    await t.tearDown(tester);
  });
}
