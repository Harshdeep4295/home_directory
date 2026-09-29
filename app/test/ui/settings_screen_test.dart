import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/app/app_settings.dart';
import 'package:offline_home/ui/screens/settings_screen.dart';

import '../support/test_services.dart';

void main() {
  testWidgets('language and TTS persist and apply to the voice controller', (
    tester,
  ) async {
    final t = await TestServices.inTester(tester);
    await tester.pumpWidget(
      t.wrap(const MaterialApp(home: Scaffold(body: SettingsScreen()))),
    );
    await TestServices.settle(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text(VoiceLanguage.hindi.label));
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Spoken feedback'));
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();

    expect(
      await tester.runAsync(t.services.appSettings.language),
      VoiceLanguage.hindi,
    );
    expect(t.services.voice!.localeId, 'hi_IN');
    expect(t.services.voice!.speakFeedback, isFalse);
    await t.tearDown(tester);
  });
}
