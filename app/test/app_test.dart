import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/main.dart';

import 'support/fake_platform.dart';

void main() {
  testWidgets('app shows the network debug screen with platform state', (
    tester,
  ) async {
    final platform = FakePlatformBridge();
    await tester.pumpWidget(OfflineHomeApp(platform: platform));
    await tester.pumpAndSettle();
    expect(find.text('Network debug'), findsOneWidget);
    expect(find.textContaining('IP: 127.0.0.1/8'), findsOneWidget);
    expect(find.textContaining('local mode'), findsOneWidget);
    await platform.dispose();
  });
}
