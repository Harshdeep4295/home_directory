import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/net/ios_platform_bridge.dart';
import 'package:offline_home/ui/debug/net_debug_screen.dart';

void main() {
  const methods = MethodChannel('offline_home/local_network');
  const events = EventChannel('offline_home/local_network/events');

  Future<void> pumpWithPermission(
    WidgetTester tester,
    String permission,
  ) async {
    final m = tester.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(methods, (call) async {
      return switch (call.method) {
        'requestPermission' => permission,
        'netInfo' => {'wifi': true, 'ip': '192.168.1.40', 'prefix': 24},
        _ => null,
      };
    });
    m.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    addTearDown(() {
      m.setMockMethodCallHandler(methods, null);
      m.setMockStreamHandler(events, null);
    });
    await tester.pumpWidget(
      MaterialApp(home: NetDebugScreen(platform: IosPlatformBridge())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('iOS denied → guidance shown', (tester) async {
    await pumpWithPermission(tester, 'denied');
    expect(
      find.textContaining('Local Network permission: denied'),
      findsOneWidget,
    );
    expect(find.text(localNetworkDeniedHelp), findsOneWidget);
    expect(find.textContaining('Internet on Wi-Fi: unknown'), findsOneWidget);
  });

  testWidgets('iOS granted → no guidance', (tester) async {
    await pumpWithPermission(tester, 'granted');
    expect(
      find.textContaining('Local Network permission: granted'),
      findsOneWidget,
    );
    expect(find.text(localNetworkDeniedHelp), findsNothing);
  });
}
