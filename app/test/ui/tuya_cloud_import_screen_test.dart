import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/onboarding/cloud_import/tuya_cloud.dart';
import 'package:offline_home/registry/secret_store.dart';
import 'package:offline_home/ui/screens/tuya_cloud_import_screen.dart';

import '../onboarding/cloud_import/tuya_cloud_test.dart' show ReplayHttp;
import '../support/test_services.dart';

void main() {
  Future<TestServices> pump(WidgetTester tester, CloudHttp http) async {
    final t = await TestServices.inTester(tester);
    await tester.pumpWidget(
      t.wrap(
        const MaterialApp(home: TuyaCloudImportScreen()),
        overrides: [tuyaCloudHttpProvider.overrideWithValue(http)],
      ),
    );
    await TestServices.settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Access ID'), 'myid');
    await tester.enterText(
      find.widgetWithText(TextField, 'Access Secret'),
      'mysecret',
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Fetch keys'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await TestServices.settle(tester);
    await TestServices.settle(tester, ms: 200);
    return t;
  }

  testWidgets('fetch → keys imported and credentials remembered', (
    tester,
  ) async {
    final t = await pump(
      tester,
      ReplayHttp({
        '/v1.0/token': ['{"success":true,"result":{"access_token":"tok"}}'],
        '/v1.0/iot-01/associated-users/devices': [
          '{"success":true,"result":{"has_more":false,"devices":[{"id":"bfplug00000000000001","name":"Geyser","local_key":"k3yK3YkeyKEY0001"}]}}',
        ],
      }),
    );
    expect(find.text('1 of 1 keys imported'), findsOneWidget);
    expect(find.textContaining('Added · '), findsOneWidget);
    final secrets = t.services.secrets;
    expect(
      await tester.runAsync(
        () => secrets.get('bfplug00000000000001', SecretName.localKey),
      ),
      'k3yK3YkeyKEY0001',
    );
    expect(
      await tester.runAsync(
        () => secrets.get(tuyaCloudSecretId, SecretName.password),
      ),
      'mysecret',
    );
    await t.tearDown(tester);
  });

  testWidgets('wrong credentials show a clear error', (tester) async {
    final t = await pump(
      tester,
      ReplayHttp({
        '/v1.0/token': ['{"success":false,"code":1004,"msg":"sign invalid"}'],
      }),
    );
    expect(find.textContaining('rejected the credentials'), findsOneWidget);
    await t.tearDown(tester);
  });
}
