import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/onboarding/manual_key.dart';
import 'package:offline_home/registry/secret_store.dart';
import 'package:offline_home/ui/alias_suggestions.dart';
import 'package:offline_home/ui/screens/device_detail_screen.dart';
import 'package:offline_home/ui/widgets/device_tile.dart';

import '../support/test_services.dart';

void main() {
  Future<TestServices> open(WidgetTester tester, List<Device> devices) async {
    final t = await TestServices.inTester(
      tester,
      devices: devices,
      rooms: const [
        Room(id: 'bath', name: 'Bathroom'),
        Room(id: 'bed', name: 'Bedroom'),
      ],
    );
    await tester.pumpWidget(
      t.wrap(MaterialApp(home: DeviceDetailScreen(deviceId: devices.first.id))),
    );
    await TestServices.settle(tester);
    return t;
  }

  Future<void> tapAndWait(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.runAsync(() async {
      await tester.tap(f);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
  }

  testWidgets('power switch, timer preset shows tier, cancel', (tester) async {
    final t = await open(tester, [
      testDevice('geyser', 'Geyser', room: 'bath'),
    ]);
    expect(find.text('Brightness'), findsNothing, reason: 'plug has no dimmer');

    await tapAndWait(tester, find.byType(Switch));
    expect(t.fake.power['geyser'], isTrue);

    await tapAndWait(tester, find.text('On for 30 min'));
    await TestServices.settle(tester);
    expect(find.textContaining('(plug timer)'), findsOneWidget);
    expect(find.text('Plug timer'), findsOneWidget);

    await tapAndWait(tester, find.text('Cancel'));
    await TestServices.settle(tester);
    expect(find.text('Plug timer'), findsNothing);
    await t.tearDown(tester);
  });

  testWidgets('dimmable light shows sliders', (tester) async {
    final lamp = testDevice(
      'lamp',
      'Lamp',
      brand: Brand.wiz,
      caps: {Capability.power, Capability.brightness, Capability.colorTemp},
    );
    final t = await open(tester, [lamp]);
    expect(find.text('Brightness'), findsOneWidget);
    expect(find.text('Colour temperature'), findsOneWidget);
    await t.tearDown(tester);
  });

  testWidgets('auto-off, room and alias suggestion persist', (tester) async {
    final t = await open(tester, [testDevice('fan', 'Bedroom Fan')]);

    await tester.ensureVisible(find.text('Never'));
    await tester.tap(find.text('Never'));
    await tester.pumpAndSettle();
    await tapAndWait(tester, find.text('after 30 min').last);

    await tester.ensureVisible(find.text('No room'));
    await tester.tap(find.text('No room'));
    await tester.pumpAndSettle();
    await tapAndWait(tester, find.text('Bedroom').last);

    await tapAndWait(tester, find.widgetWithText(ActionChip, 'pankha'));

    final d = (await tester.runAsync(() => t.services.devices.byId('fan')))!;
    expect(d.defaultAutoOff, const Duration(minutes: 30));
    expect(d.roomId, 'bed');
    expect(d.aliases, ['pankha']);
    await t.tearDown(tester);
  });

  testWidgets('remove device asks, then deletes', (tester) async {
    final t = await open(tester, [testDevice('tv', 'TV')]);
    await tester.scrollUntilVisible(
      find.text('Remove device'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Remove device'));
    await tester.pumpAndSettle();
    await tapAndWait(tester, find.widgetWithText(FilledButton, 'Remove'));
    expect(await tester.runAsync(() => t.services.devices.byId('tv')), isNull);
    await t.tearDown(tester);
  });

  test('alias suggestions', () {
    expect(aliasSuggestions('Bedroom Light'), ['batti', 'light']);
    expect(aliasSuggestions('Fan'), ['pankha']);
    expect(aliasSuggestions('Geyser'), ['garam pani']);
    expect(aliasSuggestions('Sofa'), isEmpty);
  });

  testWidgets('Tuya: enter local key → verified, shown as stored', (
    tester,
  ) async {
    final t = await TestServices.inTester(
      tester,
      devices: [testDevice('plug', 'Plug')],
    );
    await tester.pumpWidget(
      t.wrap(const MaterialApp(home: DeviceDetailScreen(deviceId: 'plug'))),
    );
    await TestServices.settle(tester);
    await tester.scrollUntilVisible(
      find.text('Enter local key'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enter local key'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'G00dKeyG00dKey!!');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await TestServices.settle(tester);
    expect(find.text(ManualKeyResult.ok.message), findsOneWidget);
    expect(
      await tester.runAsync(
        () => t.services.secrets.get('plug', SecretName.localKey),
      ),
      'G00dKeyG00dKey!!',
    );
    await t.tearDown(tester);
  });

  testWidgets('key rejected: tile says so, detail explains the fix', (
    tester,
  ) async {
    final t = await TestServices.inTester(
      tester,
      devices: [testDevice('plug', 'Plug')],
    );
    await tester.runAsync(
      () => t.services.engine.remember(
        'plug',
        DeviceState(on: false, keyRejected: true, at: DateTime.now()),
      ),
    );
    await tester.pumpWidget(
      t.wrap(
        MaterialApp(
          home: Scaffold(
            body: DeviceTile(
              device: testDevice('plug', 'Plug'),
              state: DeviceState(keyRejected: true, at: DateTime.now()),
              now: DateTime.now(),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Key rejected'), findsOneWidget);
    await tester.pumpWidget(
      t.wrap(const MaterialApp(home: DeviceDetailScreen(deviceId: 'plug'))),
    );
    await TestServices.settle(tester);
    await TestServices.settle(tester, ms: 100);
    expect(find.text('Key rejected'), findsOneWidget);
    expect(find.text('Import devices.json'), findsOneWidget);
    expect(find.text('Enter local key'), findsWidgets);
    await t.tearDown(tester);
  });
}
