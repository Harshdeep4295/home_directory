import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/onboarding/permissions.dart';
import 'package:offline_home/ui/app.dart';
import 'package:offline_home/ui/providers.dart';
import 'package:offline_home/ui/screens/first_run.dart';

import '../support/test_services.dart';

class FakePermissions implements PermissionsService {
  final List<PermissionKind> asked = [];
  @override
  List<PermissionKind> get needed => PermissionKind.values;
  @override
  Future<PermissionStatus> request(PermissionKind kind) async {
    asked.add(kind);
    return kind == PermissionKind.notifications
        ? PermissionStatus.denied
        : PermissionStatus.granted;
  }
}

void main() {
  testWidgets(
    'first run: permissions → speech → devices → Done shows the shell',
    (tester) async {
      final t = await TestServices.inTester(tester, onboarded: false);
      final perms = FakePermissions();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            servicesProvider.overrideWithValue(t.services),
            permissionsProvider.overrideWithValue(perms),
          ],
          child: const OfflineHomeApp(),
        ),
      );
      await TestServices.settle(tester, ms: 100);
      expect(find.text('Offline Home'), findsOneWidget);
      expect(find.textContaining('Not affiliated'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() async {
          await tester.tap(find.text('Allow').first);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();
        if (find.text('Allow').evaluate().isEmpty) break;
      }
      expect(perms.asked, containsAll(PermissionKind.values));
      expect(
        find.text('Try again'),
        findsOneWidget,
        reason: 'notifications denied',
      );

      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Check'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(find.textContaining('en_IN'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text('Scan for devices'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Done'));
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await TestServices.settle(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(await tester.runAsync(t.services.appSettings.onboarded), isTrue);
      await t.tearDown(tester);
    },
  );
}
