import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/discovery/evidence.dart';
import 'package:offline_home/net/lan_socket_factory.dart';
import 'package:offline_home/registry/secret_store.dart';
import 'package:offline_home/ui/screens/add_devices_screen.dart';

import '../support/test_services.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  testWidgets(
    'scan shows badges; add WiZ with new room + alias; Tuya key then add',
    (tester) async {
      final t = await TestServices.inTester(tester);
      t.evidence.next = {
        '192.168.1.31': HostEvidence('192.168.1.31')
          ..addUdp(
            UdpProbe.wiz,
            b('{"method":"registration","result":{"mac":"a8bb5006033d"}}'),
          ),
        '192.168.1.30': HostEvidence('192.168.1.30')
          ..addUdp(
            UdpProbe.tuyaBeacon,
            b(
              '{"ip":"192.168.1.30","gwId":"bf0123456789abcdefgh","version":"3.3"}',
            ),
          ),
        '192.168.1.33': HostEvidence('192.168.1.33')
          ..openPorts.add(ScanPort.http)
          ..http['/shelly'] = HttpReply(
            200,
            const {},
            b('{"type":"SHSW-1","mac":"AABBCCDDEEFF"}'),
          ),
      };
      await tester.pumpWidget(
        t.wrap(const MaterialApp(home: AddDevicesScreen())),
      );
      await TestServices.settle(tester, ms: 100);

      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Needs key'), findsOneWidget);
      expect(find.text('Not supported yet'), findsOneWidget);

      // WiZ: name, new room, alias
      await tester.tap(find.text('WiZ 033d'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name (what you will say)'),
        'Bedroom Light',
      );
      await tester.pump();
      await tester.tap(find.text('New room…'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Room name'),
        'Bedroom',
      );
      await tester.tap(find.widgetWithText(FilterChip, 'batti'));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Add device'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      final wiz = (await tester.runAsync(
        () => t.services.devices.byId('a8bb5006033d'),
      ))!;
      expect(wiz.name, 'Bedroom Light');
      expect(wiz.aliases, ['batti']);
      final rooms = (await tester.runAsync(t.services.rooms.all))!;
      expect(rooms.single.name, 'Bedroom');
      expect(wiz.roomId, rooms.single.id);
      expect(
        find.text('WiZ 033d'),
        findsNothing,
        reason: 'added devices leave the list',
      );

      // Tuya: paste key → name → add
      await tester.tap(find.text('Tuya efgh'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '0123456789abcdef');
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Add device'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(
          () => t.services.secrets.get(
            'bf0123456789abcdefgh',
            SecretName.localKey,
          ),
        ),
        '0123456789abcdef',
      );
      expect(
        await tester.runAsync(
          () => t.services.devices.byId('bf0123456789abcdefgh'),
        ),
        isNotNull,
      );

      // Not supported yet → explanation, nothing added
      await tester.tap(find.text('Not supported yet'));
      await tester.pumpAndSettle();
      expect(find.textContaining('adapter is not built yet'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await t.tearDown(tester);
    },
  );
}
