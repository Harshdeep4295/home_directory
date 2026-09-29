import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/ui/home_widget_sync.dart';
import 'package:offline_home/ui/providers.dart';
import 'package:offline_home/ui/screens/device_detail_screen.dart';
import 'package:offline_home/ui/screens/shell.dart';

import '../support/test_services.dart';

class RecordingBridge implements HomeWidgetBridge {
  final published = <Map<String, Object>>[];
  // ignore: close_sinks — closed at the end of the test that uses it.
  final clickCtl = StreamController<Uri?>.broadcast();
  Uri? initial;

  @override
  Future<void> publish(Map<String, Object> data) async => published.add(data);
  @override
  Future<Uri?> initialUri() async => initial;
  @override
  Stream<Uri?> get clicks => clickCtl.stream;
}

void main() {
  group('pure helpers', () {
    final a = withFavourite(testDevice('a', 'Zebra lamp'), true);
    final b = withFavourite(testDevice('b', 'Anchor fan'), true);
    final c = testDevice('c', 'Not a fav');

    test('favourite flag round-trips through meta', () {
      expect(isFavourite(a), isTrue);
      expect(isFavourite(withFavourite(a, false)), isFalse);
      expect(withFavourite(a, false).meta.containsKey(favouriteMetaKey), false);
    });

    test('widgetData fills 4 slots, favourites by name, blanks the rest', () {
      final data = widgetData(
        [a, b, c],
        {'a': DeviceState(on: true, at: DateTime(2026))},
      );
      expect(data['fav0_id'], 'b');
      expect(data['fav0_on'], false);
      expect(data['fav1_name'], 'Zebra lamp');
      expect(data['fav1_on'], true);
      expect(data['fav2_id'], '');
      expect(data['fav3_id'], '');
      expect(data.length, 12);
    });

    test('at most 4 favourites', () {
      final many = [
        for (var i = 0; i < 6; i++)
          withFavourite(testDevice('d$i', 'Dev $i'), true),
      ];
      expect(widgetFavourites(many).map((d) => d.id), ['d0', 'd1', 'd2', 'd3']);
    });

    test('parseWidgetUri', () {
      expect(
        parseWidgetUri(Uri.parse('offlinehome://voice')),
        isA<OpenVoice>(),
      );
      final t = parseWidgetUri(Uri.parse('offlinehome://toggle/abc%20d'));
      expect((t! as ToggleDevice).deviceId, 'abc d');
      expect(parseWidgetUri(Uri.parse('offlinehome://toggle')), isNull);
      expect(parseWidgetUri(Uri.parse('https://voice')), isNull);
      expect(parseWidgetUri(null), isNull);
    });
  });

  testWidgets('shell publishes favourites and a widget tap toggles', (
    tester,
  ) async {
    final geyser = withFavourite(testDevice('geyser', 'Geyser'), true);
    final t = await TestServices.inTester(tester, devices: [geyser]);
    final bridge = RecordingBridge();
    await tester.pumpWidget(
      t.wrap(
        const MaterialApp(home: Shell()),
        overrides: [homeWidgetBridgeProvider.overrideWithValue(bridge)],
      ),
    );
    await TestServices.settle(tester);
    expect(bridge.published.last['fav0_id'], 'geyser');
    expect(bridge.published.last['fav0_on'], false);

    bridge.clickCtl.add(Uri.parse('offlinehome://toggle/geyser'));
    await TestServices.settle(tester);
    await TestServices.settle(tester);
    expect(t.fake.power['geyser'], isTrue);
    expect(bridge.published.last['fav0_on'], true);
    await bridge.clickCtl.close();
    await t.tearDown(tester);
  });

  testWidgets('detail screen star marks a favourite', (tester) async {
    final t = await TestServices.inTester(
      tester,
      devices: [testDevice('fan', 'Fan')],
    );
    await tester.pumpWidget(
      t.wrap(const MaterialApp(home: DeviceDetailScreen(deviceId: 'fan'))),
    );
    await TestServices.settle(tester);
    await tester.tap(find.byTooltip('Add to home-screen widget'));
    await TestServices.settle(tester);
    await TestServices.settle(tester);
    final d = await tester.runAsync(() => t.services.devices.byId('fan'));
    expect(isFavourite(d!), isTrue);
    expect(find.byTooltip('Remove from widget'), findsOneWidget);
    await t.tearDown(tester);
  });
}
