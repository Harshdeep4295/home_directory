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

  testWidgets('Tapo (KLAP): asks for the TP-Link account once, then adds', (
    tester,
  ) async {
    final t = await TestServices.inTester(tester);
    t.evidence.next = {
      '192.168.1.38': HostEvidence('192.168.1.38')
        ..addUdp(
          UdpProbe.klap,
          Uint8List.fromList([
            ...List.filled(16, 0),
            ...b(
              '{"result":{"device_id":"abc123","device_type":"SMART.TAPOPLUG","device_model":"P100(EU)","mac":"AA-BB-CC-DD-EE-FF","mgt_encrypt_schm":{"is_support_https":false,"encrypt_type":"KLAP","http_port":80}},"error_code":0}',
            ),
          ]),
        ),
    };
    await tester.pumpWidget(
      t.wrap(const MaterialApp(home: AddDevicesScreen())),
    );
    await TestServices.settle(tester, ms: 100);
    expect(find.text('Needs key'), findsOneWidget);

    await tester.tap(find.text('P100(EU)'));
    await tester.pumpAndSettle();
    expect(find.text('TP-Link account e-mail'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'me@example.com');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Secret1');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await TestServices.settle(tester);
    expect(
      await tester.runAsync(
        () => t.services.secrets.get('tplink', SecretName.email),
      ),
      'me@example.com',
    );
    await t.tearDown(tester);
  });

  testWidgets('devices are grouped by category with camera details', (
    tester,
  ) async {
    final t = await TestServices.inTester(tester);
    t.evidence.next = {
      '192.168.1.31': HostEvidence('192.168.1.31')
        ..addUdp(
          UdpProbe.wiz,
          b('{"method":"registration","result":{"mac":"a8bb5006033d"}}'),
        ),
      '192.168.1.40': HostEvidence('192.168.1.40')
        ..addUdp(
          UdpProbe.sadp,
          b(
            '<ProbeMatch><Types>inquiry</Types><DeviceDescription>CS-C6N</DeviceDescription>'
            '<MAC>c0-56-e3-12-34-56</MAC></ProbeMatch>',
          ),
        ),
      '192.168.1.50': HostEvidence('192.168.1.50')
        ..mdns.add(
          const MdnsRecord(
            type: '_googlecast._tcp',
            name: 'x',
            port: 8009,
            attributes: {'md': 'Chromecast', 'fn': 'Living room TV'},
          ),
        ),
    };
    await tester.pumpWidget(
      t.wrap(const MaterialApp(home: AddDevicesScreen())),
    );
    await TestServices.settle(tester, ms: 100);

    expect(find.text('Lights & plugs (1)'), findsOneWidget);
    expect(find.text('Cameras (1)'), findsOneWidget);
    expect(find.text('TV & media (1)'), findsOneWidget);
    expect(find.text('Hikvision CS-C6N'), findsOneWidget);
    expect(find.text('CS-C6N · 192.168.1.40'), findsOneWidget);
    expect(find.text('Living room TV'), findsOneWidget);
    // Sections follow the category order: lights first, then cameras, then TV.
    final y = [
      'Lights & plugs (1)',
      'Cameras (1)',
      'TV & media (1)',
    ].map((s) => tester.getTopLeft(find.text(s)).dy).toList();
    expect(y, orderedEquals([...y]..sort()));

    expect(find.text('Needs password'), findsOneWidget);
    await tester.tap(find.text('Hikvision CS-C6N'));
    await tester.pumpAndSettle();
    expect(find.text('Add camera'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'admin'), findsOneWidget);
    final add = find.widgetWithText(FilledButton, 'Check and add');
    expect(
      tester.widget<FilledButton>(add).onPressed,
      isNull,
      reason: 'needs the code first',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Verification code / password'),
      'ABCDEF',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(add).onPressed, isNotNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Add camera'), findsNothing);
    await t.tearDown(tester);
  });
}
