import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/main.dart';

void main() {
  testWidgets('placeholder app renders its title', (tester) async {
    await tester.pumpWidget(const OfflineHomeApp());
    expect(find.text('Offline Home'), findsOneWidget);
  });
}
