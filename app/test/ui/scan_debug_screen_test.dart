import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/adapters/fake_adapter.dart';
import 'package:offline_home/app/services.dart';
import 'package:offline_home/core/log.dart';
import 'package:offline_home/discovery/discovery_service.dart';
import 'package:offline_home/discovery/evidence.dart';
import 'package:offline_home/net/network_monitor.dart';
import 'package:offline_home/registry/database.dart';
import 'package:offline_home/registry/repositories.dart';
import 'package:offline_home/registry/secret_store.dart';
import 'package:offline_home/ui/debug/scan_debug_screen.dart';

import '../support/fake_platform.dart';

class OneWizSource implements EvidenceSource {
  @override
  Future<Map<String, HostEvidence>> collect({
    Duration window = Duration.zero,
  }) async => {
    '192.168.1.31': HostEvidence('192.168.1.31')
      ..addUdp(
        UdpProbe.wiz,
        Uint8List.fromList(
          utf8.encode(
            '{"method":"registration","result":{"mac":"a8bb5006033d"}}',
          ),
        ),
      ),
  };
}

void main() {
  testWidgets('scan → add → toggle', (tester) async {
    final platform = FakePlatformBridge();
    final db = AppDatabase.memory();
    final secrets = SecretStore(MemorySecretBackend(), Redactor());
    final fake = FakeAdapter(protocols: {'wiz'});
    final services = AppServices(
      platform: platform,
      db: db,
      secrets: secrets,
      adapters: AdapterRegistry([fake]),
      discovery: DiscoveryService(
        OneWizSource(),
        DeviceRepository(db),
        secrets,
      ),
      network: NetworkMonitor(platform),
    );

    await tester.pumpWidget(
      MaterialApp(home: ScanDebugScreen(services: services)),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Scan'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Ready'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Add'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('WiZ 033d'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('WiZ 033d'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('turned on'), findsOneWidget);
    expect(fake.power['a8bb5006033d'], isTrue);

    // T3.6: long-press → timer; the fake has a native countdown → plug tier.
    await tester.longPress(find.text('WiZ 033d'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Off after 1 minute'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('(plug timer)'), findsOneWidget);

    await fake.disposeAll(); // cancels the fake's pending countdown timer
    await tester.runAsync(db.close);
    await platform.dispose();
  });
}
