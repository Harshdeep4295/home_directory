import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/ui/screens/voice_sheet.dart';

import '../support/test_services.dart';

void main() {
  Future<void> typeCommand(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.runAsync(() async {
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pump();
  }

  testWidgets('typed command → result with undo; ambiguous → chips', (
    tester,
  ) async {
    final t = await TestServices.inTester(
      tester,
      devices: [
        testDevice('geyser', 'Geyser'),
        testDevice('hl', 'Hall Light'),
        testDevice('kl', 'Kitchen Light'),
      ],
    );
    await tester.pumpWidget(
      t.wrap(
        MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showVoiceSheet(context, ref, listen: false),
                  child: const Text('mic'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mic'));
    await tester.pumpAndSettle();
    expect(find.text('Tap to speak'), findsOneWidget);

    await typeCommand(tester, 'geyser on karo');
    expect(find.text('Geyser on.'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(t.fake.power['geyser'], isTrue);
    expect(t.tts.spoken.last, 'Geyser on.');

    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
    expect(find.text('Undone.'), findsOneWidget);

    await typeCommand(tester, 'light on');
    expect(find.text('Which one?'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ActionChip, 'Kitchen Light'));
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
    expect(t.fake.power['kl'], isTrue);
    expect(t.fake.power['hl'], isNull);

    await t.tearDown(tester);
  });
}
