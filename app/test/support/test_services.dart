import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/adapters/fake_adapter.dart';
import 'package:offline_home/app/services.dart';
import 'package:offline_home/core/log.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/discovery/discovery_service.dart';
import 'package:offline_home/discovery/evidence.dart';
import 'package:offline_home/net/network_monitor.dart';
import 'package:offline_home/net/platform_bridge.dart';
import 'package:offline_home/registry/database.dart';
import 'package:offline_home/registry/repositories.dart';
import 'package:offline_home/registry/secret_store.dart';
import 'package:offline_home/ui/providers.dart';
import 'package:offline_home/voice/intent_parser.dart';
import 'package:offline_home/voice/lexicon.dart';
import 'package:offline_home/voice/stt_service.dart';
import 'package:offline_home/voice/target_resolver.dart';
import 'package:offline_home/voice/tts.dart';
import 'package:offline_home/voice/voice_controller.dart';

import 'fake_platform.dart';

class StaticEvidence implements EvidenceSource {
  Map<String, HostEvidence> next = {};
  @override
  Future<Map<String, HostEvidence>> collect({
    Duration window = Duration.zero,
  }) async => next;
}

class NoSpeech implements SpeechEngine {
  @override
  Future<bool> initialize(void Function(SttError) onError) async => true;
  @override
  Future<List<String>> localeIds() async => ['en_IN'];
  @override
  Future<void> listen({
    required String localeId,
    required List<String> contextualPhrases,
    required Duration listenFor,
    required Duration pauseFor,
    required void Function(SttEvent) onEvent,
  }) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}

/// A full AppServices wired to fakes (in-memory DB, FakeAdapter answering every
/// protocol used in tests, fake platform, no speech).
class TestServices {
  TestServices._(
    this.services,
    this.fake,
    this.platform,
    this.evidence,
    this.tts,
  );

  final AppServices services;
  final FakeAdapter fake;
  final FakePlatformBridge platform;
  final StaticEvidence evidence;
  final SilentTts tts;

  static Future<TestServices> create({
    List<Device> devices = const [],
    List<Room> rooms = const [],
    NetInfo net = const NetInfo(
      wifi: true,
      internet: true,
      ip: '192.168.1.5',
      prefix: 24,
    ),
  }) async {
    final platform = FakePlatformBridge(info: net);
    final db = AppDatabase.memory();
    final secrets = SecretStore(MemorySecretBackend(), Redactor());
    final fake = FakeAdapter(protocols: {'fake', 'wiz', 'tuya', 'tuya-3.3'});
    final evidence = StaticEvidence();
    final network = NetworkMonitor(platform);
    await network.start();
    final s = AppServices(
      platform: platform,
      db: db,
      secrets: secrets,
      adapters: AdapterRegistry([fake]),
      discovery: DiscoveryService(evidence, DeviceRepository(db), secrets),
      network: network,
      phoneAlarms: NoopPhoneAlarms(),
    );
    for (final r in rooms) {
      await s.rooms.upsert(r);
    }
    for (final d in devices) {
      await s.devices.upsert(d);
    }
    final lex = Lexicon.fromYaml([
      for (final p in Lexicon.assetPaths) File(p).readAsStringSync(),
    ]);
    final tts = SilentTts();
    s
      ..stt = SttService(NoSpeech())
      ..voice = VoiceController(
        stt: s.stt!,
        parser: IntentParser(lex),
        resolver: TargetResolver(lex),
        engine: s.engine,
        timers: s.timerService,
        devices: s.devices,
        rooms: s.rooms,
        tts: tts,
      );
    return TestServices._(s, fake, platform, evidence, tts);
  }

  Widget wrap(Widget child) => ProviderScope(
    overrides: [servicesProvider.overrideWithValue(services)],
    child: child,
  );

  /// Unmounts the tree, lets provider/stream cancellations run in the fake-async zone,
  /// then disposes services for real. Without the pumps, drift's close() waits forever
  /// for stream queries whose cancellation is queued in the fake zone.
  Future<void> tearDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(dispose);
  }

  /// Creates services outside the fake-async zone (drift needs real async).
  static Future<TestServices> inTester(
    WidgetTester tester, {
    List<Device> devices = const [],
    List<Room> rooms = const [],
    NetInfo net = const NetInfo(
      wifi: true,
      internet: true,
      ip: '192.168.1.5',
      prefix: 24,
    ),
  }) async => (await tester.runAsync(
    () => create(devices: devices, rooms: rooms, net: net),
  ))!;

  /// Lets real async work (DB queries) finish, then rebuilds.
  static Future<void> settle(WidgetTester tester, {int ms = 50}) async {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: ms)),
    );
    await tester.pump();
  }

  Future<void> dispose() async {
    await fake.disposeAll();
    await services.dispose();
    await platform.dispose();
  }
}

Device testDevice(
  String id,
  String name, {
  String? room,
  Brand brand = Brand.tuya,
  String protocol = 'fake',
  Set<Capability>? caps,
}) => Device(
  id: id,
  brand: brand,
  protocol: protocol,
  ip: '192.168.1.${10 + id.hashCode % 200}',
  name: name,
  roomId: room,
  capabilities: caps ?? {Capability.power, Capability.nativeCountdown},
  nativeCountdownMax: const Duration(hours: 24),
  lastSeen: DateTime.utc(2026),
);
