import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/registry/secret_store.dart';
import 'package:offline_home/ui/file_access.dart';
import 'package:offline_home/ui/screens/devices_json_import_screen.dart';

import '../support/test_services.dart';

class FakeFileAccess implements FileAccess {
  FakeFileAccess(this.bytes);
  final Uint8List? bytes;
  @override
  Future<(String, Uint8List)?> pick({List<String>? extensions}) async =>
      bytes == null ? null : ('devices.json', bytes!);
  @override
  Future<String?> save(
    String name,
    Uint8List bytes, {
    String mimeType = 'application/json',
  }) async => null;
}

void main() {
  Future<TestServices> pump(WidgetTester tester, List<int> file) async {
    final t = await TestServices.inTester(tester);
    await tester.pumpWidget(
      t.wrap(
        const MaterialApp(home: DevicesJsonImportScreen()),
        overrides: [
          fileAccessProvider.overrideWithValue(
            FakeFileAccess(Uint8List.fromList(file)),
          ),
        ],
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Choose devices.json'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await TestServices.settle(tester);
    await TestServices.settle(tester, ms: 200); // ImportResults: scan + status
    return t;
  }

  testWidgets('imports, verifies reachable devices, lists skipped ones', (
    tester,
  ) async {
    final t = await pump(
      tester,
      File('test/onboarding/fixtures/sample_devices.json').readAsBytesSync(),
    );
    expect(find.text('2 of 4 keys imported'), findsOneWidget);
    expect(find.text('Added · Key works'), findsOneWidget); // has an IP
    expect(find.text('Added · Not found on this Wi-Fi yet'), findsOneWidget);
    expect(find.text('Gateway sub-device: not supported yet'), findsOneWidget);
    expect(find.text('No local key in the file'), findsOneWidget);
    expect(
      await tester.runAsync(
        () =>
            t.services.secrets.has('bf0123456789abcdefgh', SecretName.localKey),
      ),
      isTrue,
    );
    await t.tearDown(tester);
  });

  testWidgets('bad file shows an error', (tester) async {
    final t = await pump(tester, 'hello'.codeUnits);
    expect(find.textContaining('Not valid JSON'), findsOneWidget);
    await t.tearDown(tester);
  });

  testWidgets('guide opens from the import screen', (tester) async {
    final t = await TestServices.inTester(tester);
    await tester.pumpWidget(
      t.wrap(const MaterialApp(home: DevicesJsonImportScreen())),
    );
    await tester.tap(find.text('How do I get keys?'));
    await tester.pumpAndSettle();
    expect(find.text('Getting Tuya keys'), findsOneWidget);
    expect(find.text('1. Create a Tuya IoT project'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('6. Re-link Alexa (optional)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tearDown(tester);
  });
}
