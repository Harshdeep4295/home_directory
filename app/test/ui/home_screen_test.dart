import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/intent.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/ui/screens/home_screen.dart';
import 'package:offline_home/ui/widgets/device_tile.dart';

import '../support/test_services.dart';

/// The status text ("On", "Off", "Offline") inside the tile showing [name].
Finder statusOf(String name, String status) => find.descendant(
  of: find.widgetWithText(DeviceTile, name),
  matching: find.text(status),
);

void main() {
  testWidgets('rooms, tile states, offline, timer chip, tap toggles', (
    tester,
  ) async {
    final geyser = testDevice('geyser', 'Geyser', room: 'bath');
    final lamp = testDevice(
      'lamp',
      'Bedroom Lamp',
      room: 'bed',
      brand: Brand.wiz,
      caps: {Capability.power, Capability.brightness},
    );
    final fan = testDevice('fan', 'Fan');
    final t = await TestServices.inTester(
      tester,
      devices: [geyser, lamp, fan],
      rooms: const [
        Room(id: 'bed', name: 'Bedroom', sort: 1),
        Room(id: 'bath', name: 'Bathroom', sort: 2),
      ],
    );
    await tester.runAsync(() async {
      await t.services.engine.powerOne(lamp, true);
      await t.services.engine.remember(
        'fan',
        DeviceState(online: false, at: DateTime.now()),
      );
      await t.services.timerService.powerFor(
        [geyser],
        PowerAction.on,
        const Duration(minutes: 18, seconds: 30),
      );
    });
    Device? opened;
    await tester.pumpWidget(
      t.wrap(MaterialApp(home: HomeScreen(onOpenDevice: (d) => opened = d))),
    );
    await TestServices.settle(tester);

    expect(find.text('Bedroom'), findsOneWidget);
    expect(find.text('Bathroom'), findsOneWidget);
    expect(find.text(HomeScreen.otherRoom), findsOneWidget);
    expect(statusOf('Bedroom Lamp', 'On'), findsOneWidget);
    expect(statusOf('Fan', 'Offline'), findsOneWidget);
    expect(find.textContaining('off in 18m · Plug'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Bedroom Lamp'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(t.fake.power['lamp'], isFalse);
    expect(statusOf('Bedroom Lamp', 'Off'), findsOneWidget);

    await tester.longPress(find.text('Geyser'));
    expect(opened?.id, 'geyser');
    await t.tearDown(tester);
  });

  testWidgets('empty state offers Add devices', (tester) async {
    final t = await TestServices.inTester(tester);
    var added = false;
    await tester.pumpWidget(
      t.wrap(MaterialApp(home: HomeScreen(onAddDevices: () => added = true))),
    );
    await TestServices.settle(tester);
    await tester.tap(find.text('Add devices'));
    expect(added, isTrue);
    await t.tearDown(tester);
  });

  test('remainingText', () {
    expect(remainingText(const Duration(hours: 1, minutes: 5)), '1h 5m');
    expect(remainingText(const Duration(hours: 2)), '2h');
    expect(remainingText(const Duration(minutes: 18, seconds: 20)), '18m');
    expect(remainingText(const Duration(seconds: 40)), '40s');
    expect(remainingText(Duration.zero), 'now');
  });

  testWidgets('T8.2: 100 devices render within the cold-start budget', (
    tester,
  ) async {
    final t = await TestServices.inTester(
      tester,
      devices: [for (var i = 0; i < 100; i++) testDevice('d$i', 'Device $i')],
    );
    final sw = Stopwatch()..start();
    await tester.pumpWidget(t.wrap(const MaterialApp(home: HomeScreen())));
    await TestServices.settle(tester);
    sw.stop();
    expect(find.byType(DeviceTile), findsWidgets);
    expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    await t.tearDown(tester);
  });
}
