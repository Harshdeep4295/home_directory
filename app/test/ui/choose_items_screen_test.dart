import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/ui/screens/choose_items_screen.dart';

import '../support/test_services.dart';

void main() {
  testWidgets('everything by default; places and single devices toggle', (
    tester,
  ) async {
    final t = await TestServices.inTester(
      tester,
      devices: [
        testDevice('geyser', 'Geyser').copyWith(place: 'Guglanas Home'),
        testDevice('fan', 'Fan').copyWith(place: 'Guglanas Home'),
        testDevice('pump', 'Pump').copyWith(place: 'Village'),
      ],
    );
    ItemChoice? got;
    await tester.pumpWidget(
      t.wrap(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => got = await chooseItems(
                context,
                title: 'Share what?',
                action: 'Share',
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(seconds: 1));
    await TestServices.settle(tester, ms: 100);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Share everything'), findsOne);

    // Only one place.
    await tester.tap(find.byKey(const ValueKey('choose-all')));
    await tester.pump();
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNull,
      reason: 'nothing chosen',
    );
    await tester.tap(find.byKey(const ValueKey('choose-place-Village')));
    await tester.pump();
    // Plus one device from the other place.
    await tester.tap(find.byKey(const ValueKey('choose-fan')));
    await tester.pump();
    expect(find.text('Share 2'), findsOne);
    await tester.tap(find.text('Share 2'));
    await tester.pumpAndSettle();
    expect(got?.only, {'pump', 'fan'});

    await tester.tap(find.text('go'));
    await tester.pump(const Duration(seconds: 1));
    await TestServices.settle(tester, ms: 100);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Share everything'));
    await tester.pumpAndSettle();
    expect(got?.only, isNull, reason: 'everything = full setup');
    await t.tearDown(tester);
  });
}
