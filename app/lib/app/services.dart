import 'dart:io';

import '../adapters/device_adapter.dart';
import '../adapters/tuya/tuya_adapter.dart';
import '../adapters/wiz/wiz_adapter.dart';
import '../core/log.dart';
import '../discovery/collectors.dart';
import '../discovery/discovery_service.dart';
import '../discovery/mdns_browser.dart';
import '../net/android_platform_bridge.dart';
import '../net/ios_platform_bridge.dart';
import '../net/lan_socket_factory.dart';
import '../net/network_monitor.dart';
import '../net/platform_bridge.dart';
import '../registry/database.dart';
import '../registry/repositories.dart';
import '../registry/secret_store.dart';

/// Object graph of the app (PSEUDOCODE §1 bootstrap). Riverpod providers wrap it in T5.1.
class AppServices {
  AppServices({
    required this.platform,
    required this.db,
    required this.secrets,
    required this.adapters,
    required this.discovery,
    required this.network,
  }) : devices = DeviceRepository(db),
       rooms = RoomRepository(db),
       timers = TimerRepository(db),
       stateCache = StateCacheRepository(db),
       settings = SettingsRepository(db);

  final PlatformBridge platform;
  final AppDatabase db;
  final SecretStore secrets;
  final AdapterRegistry adapters;
  final DiscoveryService discovery;
  final NetworkMonitor network;
  final DeviceRepository devices;
  final RoomRepository rooms;
  final TimerRepository timers;
  final StateCacheRepository stateCache;
  final SettingsRepository settings;

  static PlatformBridge platformForHost() => Platform.isAndroid
      ? AndroidPlatformBridge()
      : Platform.isIOS
      ? IosPlatformBridge()
      : DefaultPlatformBridge();

  /// Production wiring.
  static Future<AppServices> create() async {
    final redactor = Redactor();
    log = Logger(redactor: redactor, sinks: [ConsoleSink(), MemorySink()]);
    final platform = platformForHost();
    await platform.init();
    final secrets = SecretStore(SecureStorageBackend(), redactor);
    await secrets.warmUp();
    final db = AppDatabase.open();
    final sockets = LanSocketFactory(platform);
    final adapters = AdapterRegistry([
      WizAdapter(sockets),
      TuyaAdapter(sockets, secrets),
    ]);
    final network = NetworkMonitor(platform);
    await network.start();
    return AppServices(
      platform: platform,
      db: db,
      secrets: secrets,
      adapters: adapters,
      discovery: DiscoveryService(
        CandidateCollector(sockets, platform, BonsoirMdnsBrowser()),
        DeviceRepository(db),
        secrets,
      ),
      network: network,
    );
  }

  Future<void> dispose() async {
    await adapters.disposeAll();
    await network.dispose();
    await db.close();
  }
}
