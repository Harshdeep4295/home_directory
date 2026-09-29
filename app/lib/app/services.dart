import 'dart:io';

import '../adapters/device_adapter.dart';
import '../adapters/hue/hue_adapter.dart';
import '../adapters/kasa/kasa_adapter.dart';
import '../adapters/kasa/tapo_adapter.dart';
import '../adapters/shelly/shelly_adapter.dart';
import '../adapters/tuya/tuya_adapter.dart';
import '../adapters/wiz/wiz_adapter.dart';
import '../adapters/yeelight/yeelight_adapter.dart';
import '../core/log.dart';
import '../discovery/collectors.dart';
import '../discovery/discovery_service.dart';
import '../discovery/mdns_browser.dart';
import '../engine/command_engine.dart';
import '../engine/state_poller.dart';
import '../net/android_platform_bridge.dart';
import '../net/ios_platform_bridge.dart';
import '../net/lan_socket_factory.dart';
import '../net/network_monitor.dart';
import '../net/platform_bridge.dart';
import '../registry/config_export.dart';
import '../registry/database.dart';
import '../registry/repositories.dart';
import '../registry/secret_store.dart';
import '../timers/android_alarm_scheduler.dart';
import '../timers/ios_phone_timers.dart';
import '../timers/phone_tier_ticker.dart';
import '../timers/timer_service.dart';
import '../voice/intent_parser.dart';
import '../voice/lexicon.dart';
import '../voice/stt_service.dart';
import '../voice/target_resolver.dart';
import '../voice/tts.dart';
import '../voice/voice_controller.dart';
import 'app_settings.dart';

/// Object graph of the app (PSEUDOCODE §1 bootstrap). Riverpod providers wrap it in T5.1.
class AppServices {
  AppServices({
    required this.platform,
    required this.db,
    required this.secrets,
    required this.adapters,
    required this.discovery,
    required this.network,
    PhoneAlarmScheduler? phoneAlarms,
  }) : phoneAlarms = phoneAlarms,
       devices = DeviceRepository(db),
       rooms = RoomRepository(db),
       timers = TimerRepository(db),
       stateCache = StateCacheRepository(db),
       settings = SettingsRepository(db) {
    engine = CommandEngine(adapters, stateCache);
    poller = StatePoller(engine, adapters);
    timerService = TimerService(
      engine,
      adapters,
      devices,
      timers,
      phoneAlarms ?? (this.phoneAlarms = _phoneAlarmsForHost()),
    );
    phoneTicker = PhoneTierTicker(timers, timerService);
  }

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
  late final CommandEngine engine;
  late final StatePoller poller;
  late final TimerService timerService;

  /// Phone-tier backend (exact alarms / notifications); null until built.
  PhoneAlarmScheduler? phoneAlarms;

  /// Runs due phone-tier jobs while the app is open. Started on foreground on iOS
  /// (T3.5); Android relies on exact alarms instead.
  late final PhoneTierTicker phoneTicker;

  /// Set by [create] once the lexicon assets are loaded (null in widget tests).
  VoiceController? voice;
  SttService? stt;

  /// Recent log lines for Settings → Diagnostics (redacted).
  MemorySink logSink = MemorySink();

  late final AppSettings appSettings = AppSettings(settings);
  late final ConfigExporter configExporter = ConfigExporter(
    devices,
    rooms,
    settings,
    secrets,
  );

  /// Pushes stored settings into the running services.
  Future<void> applySettings() async {
    poller.interval = Duration(seconds: await appSettings.pollSeconds());
    final v = voice;
    if (v != null) {
      v
        ..localeId = (await appSettings.language()).localeId
        ..speakFeedback = await appSettings.tts();
    }
  }

  /// Android: exact alarms (T3.4). iOS: notification at fire time + [phoneTicker] (T3.5).
  PhoneAlarmScheduler _phoneAlarmsForHost() {
    if (Platform.isAndroid) return AndroidPhoneAlarmScheduler();
    if (Platform.isIOS) {
      return IosPhoneTimers(PluginLocalNotifier(), _describeJob);
    }
    return NoopPhoneAlarms();
  }

  Future<String> _describeJob(String jobId) async {
    final j = await timers.byId(jobId);
    final d = j == null ? null : await devices.byId(j.deviceId);
    if (j == null || d == null) return 'timer';
    return '${d.name} ${j.endOn ? 'on' : 'off'}';
  }

  static PlatformBridge platformForHost() => Platform.isAndroid
      ? AndroidPlatformBridge()
      : Platform.isIOS
      ? IosPlatformBridge()
      : DefaultPlatformBridge();

  /// Production wiring.
  static Future<AppServices> create() async {
    final redactor = Redactor();
    final logSink = MemorySink();
    log = Logger(redactor: redactor, sinks: [ConsoleSink(), logSink]);
    final platform = platformForHost();
    await platform.init();
    final secrets = SecretStore(SecureStorageBackend(), redactor);
    await secrets.warmUp();
    final db = AppDatabase.open();
    final sockets = LanSocketFactory(platform);
    final adapters = AdapterRegistry([
      WizAdapter(sockets),
      TuyaAdapter(sockets, secrets),
      ShellyAdapter(sockets, secrets),
      KasaAdapter(sockets, secrets: secrets),
      TapoAdapter(sockets, secrets),
      HueAdapter(sockets, secrets),
      YeelightAdapter(sockets),
    ]);
    final network = NetworkMonitor(platform);
    await network.start();
    final services = AppServices(
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
    services.logSink = logSink;
    await services.engine.warmUp();
    final lexicon = await Lexicon.loadAssets();
    final stt = SttService(PlatformSpeechEngine());
    services
      ..stt = stt
      ..voice = VoiceController(
        stt: stt,
        parser: IntentParser(lexicon),
        resolver: TargetResolver(lexicon),
        engine: services.engine,
        timers: services.timerService,
        devices: services.devices,
        rooms: services.rooms,
        tts: PlatformTts(),
        isIOS: Platform.isIOS,
      );
    await services.applySettings();
    return services;
  }

  Future<void> dispose() async {
    await voice?.dispose();
    phoneTicker.stop();
    await poller.dispose();
    await engine.dispose();
    await adapters.disposeAll();
    await network.dispose();
    await db.close();
  }
}

/// Phone tier without a platform backend: the job is stored, reconcile() handles it.
class NoopPhoneAlarms implements PhoneAlarmScheduler {
  @override
  Future<void> schedule(String jobId, DateTime fireAt) async {}
  @override
  Future<void> cancel(String jobId) async {}
}
