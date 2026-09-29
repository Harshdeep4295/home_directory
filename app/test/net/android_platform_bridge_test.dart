import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/net/android_platform_bridge.dart';
import 'package:offline_home/net/platform_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('offline_home/lan');
  const events = EventChannel('offline_home/lan/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'netInfo' => {
          'wifi': true,
          'internet': false,
          'ip': '192.168.1.37',
          'prefix': 24,
          'ssid': null,
        },
        _ => null,
      };
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(methods, null));

  test('init / multicast lock call through to the plugin', () async {
    final b = AndroidPlatformBridge();
    await b.init();
    await b.acquireMulticastLock();
    await b.releaseMulticastLock();
    expect(calls, ['init', 'acquireMulticastLock', 'releaseMulticastLock']);
    expect(b.canBroadcast, isTrue);
  });

  test('netInfo parses the plugin map', () async {
    final info = await AndroidPlatformBridge().netInfo();
    expect(
      info,
      const NetInfo(
        wifi: true,
        internet: false,
        ip: '192.168.1.37',
        prefix: 24,
      ),
    );
  });

  test('changes stream decodes events', () async {
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (args, sink) {
          sink.success({
            'wifi': true,
            'internet': true,
            'ip': '10.0.0.2',
            'prefix': 24,
          });
          sink.success({'wifi': false, 'internet': false});
          sink.endOfStream();
        },
      ),
    );
    final got = await AndroidPlatformBridge().changes.toList();
    expect(got.map((n) => (n.wifi, n.internet, n.ip)), [
      (true, true, '10.0.0.2'),
      (false, false, null),
    ]);
  });
}
