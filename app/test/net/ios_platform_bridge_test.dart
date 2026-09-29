import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/net/ios_platform_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('offline_home/local_network');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(methods, null));

  void answer(Object? permission) {
    messenger.setMockMethodCallHandler(methods, (call) async {
      return switch (call.method) {
        'requestPermission' => permission,
        'netInfo' => {'wifi': true, 'ip': '192.168.1.40', 'prefix': 24},
        _ => null,
      };
    });
  }

  test('permission results map to the enum, junk → unknown', () async {
    for (final (raw, want) in [
      ('granted', LocalNetworkPermission.granted),
      ('denied', LocalNetworkPermission.denied),
      ('unknown', LocalNetworkPermission.unknown),
      ('weird', LocalNetworkPermission.unknown),
      (null, LocalNetworkPermission.unknown),
    ]) {
      answer(raw);
      expect(await IosPlatformBridge().requestLocalNetworkPermission(), want);
    }
  });

  test('netInfo: internet is unknown on iOS; no broadcast', () async {
    answer('granted');
    final b = IosPlatformBridge();
    final info = await b.netInfo();
    expect(info.wifi, isTrue);
    expect(info.ip, '192.168.1.40');
    expect(info.internet, isNull);
    expect(b.canBroadcast, isFalse);
  });
}
