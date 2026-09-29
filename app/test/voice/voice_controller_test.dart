import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/adapters/fake_adapter.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/engine/command_engine.dart';
import 'package:offline_home/registry/database.dart';
import 'package:offline_home/registry/repositories.dart';
import 'package:offline_home/timers/timer_service.dart';
import 'package:offline_home/voice/intent_parser.dart';
import 'package:offline_home/voice/lexicon.dart';
import 'package:offline_home/voice/stt_service.dart';
import 'package:offline_home/voice/target_resolver.dart';
import 'package:offline_home/voice/tts.dart';
import 'package:offline_home/voice/voice_controller.dart';

class ScriptedEngine implements SpeechEngine {
  List<SttEvent> next = const [];
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
  }) async {
    for (final e in next) {
      onEvent(e);
    }
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}

class NoPhone implements PhoneAlarmScheduler {
  @override
  Future<void> schedule(String jobId, DateTime fireAt) async {}
  @override
  Future<void> cancel(String jobId) async {}
}

void main() {
  late AppDatabase db;
  late FakeAdapter fake;
  late CommandEngine engine;
  late SilentTts tts;
  late ScriptedEngine stt;
  late VoiceController vc;
  final now = DateTime(2026, 9, 29, 21, 20);
  final lex = Lexicon.fromYaml([
    for (final p in Lexicon.assetPaths) File(p).readAsStringSync(),
  ]);

  Device dev(String id, String name, {String? room}) => Device(
    id: id,
    brand: Brand.tuya,
    protocol: 'fake',
    ip: '1',
    name: name,
    roomId: room,
    lastSeen: DateTime.utc(2026),
  );

  setUp(() async {
    db = AppDatabase.memory();
    fake = FakeAdapter(now: () => now);
    final reg = AdapterRegistry([fake]);
    engine = CommandEngine(reg, StateCacheRepository(db), backoff: const []);
    final devices = DeviceRepository(db);
    final rooms = RoomRepository(db);
    await rooms.upsert(const Room(id: 'bed', name: 'Bedroom'));
    for (final d in [
      dev('geyser', 'Geyser'),
      dev('bl', 'Bedroom Light', room: 'bed'),
      dev('hl', 'Hall Light'),
      dev('kl', 'Kitchen Light'),
      dev('fan', 'Fan'),
    ]) {
      await devices.upsert(d);
    }
    tts = SilentTts();
    stt = ScriptedEngine();
    vc = VoiceController(
      stt: SttService(stt),
      parser: IntentParser(lex),
      resolver: TargetResolver(lex),
      engine: engine,
      timers: TimerService(
        engine,
        reg,
        devices,
        TimerRepository(db),
        NoPhone(),
        now: () => now,
      ),
      devices: devices,
      rooms: rooms,
      tts: tts,
      now: () => now,
    );
  });
  tearDown(() async {
    await vc.dispose();
    await fake.disposeAll();
    await engine.dispose();
    await db.close();
  });

  VoiceResult result() => vc.state as VoiceResult;

  test('listen → partials → power command → spoken feedback', () async {
    stt.next = const [
      SttPartial('geyser'),
      SttFinal(['geyser on karo']),
    ];
    final seen = <VoiceState>[];
    final sub = vc.states.listen(seen.add);
    await vc.start();
    await sub.cancel();
    expect(
      seen.whereType<VoiceListening>().map((s) => s.partial),
      containsAll(['', 'geyser']),
    );
    expect(fake.power['geyser'], isTrue);
    expect(result().message, 'Geyser on.');
    expect(tts.spoken.last, 'Geyser on.');
  });

  test('timer feedback names end time and tier', () async {
    await vc.handleText('geyser 20 minute ke liye chalu karo');
    expect(result().message, 'Geyser on. Off at 9:40 pm (plug timer).');
    expect(result().canUndo, isTrue);
  });

  test('ambiguous target → chips; confirm runs on the chosen device', () async {
    await vc.handleText('light on');
    final c = vc.state as VoiceConfirming;
    expect(c.options.map((d) => d.id), containsAll(['bl', 'hl', 'kl']));
    await vc.confirm([c.options.firstWhere((d) => d.id == 'hl')]);
    expect(fake.power['hl'], isTrue);
    expect(fake.power['bl'], isNull);
  });

  test('"all" with more than 5 devices asks first', () async {
    for (var i = 0; i < 3; i++) {
      await DeviceRepository(db).upsert(dev('x$i', 'Extra Light $i'));
    }
    await vc.handleText('sab batti band karo');
    final c = vc.state as VoiceConfirming;
    expect(c.question, 'Turn off 6 devices?');
    vc.cancelConfirmation();
    expect(vc.state, isA<VoiceIdle>());
    expect(fake.calls.where((c) => c.startsWith('setPower')), isEmpty);
  });

  test('undo within 5 s restores previous state', () async {
    await engine.powerOne(dev('fan', 'Fan'), true);
    await vc.handleText('fan band karo');
    expect(fake.power['fan'], isFalse);
    expect(await vc.undo(), isTrue);
    expect(fake.power['fan'], isTrue);
    expect(await vc.undo(), isFalse, reason: 'only once');
  });

  test('status, cancel, unknown, not found, offline', () async {
    await engine.powerOne(dev('geyser', 'Geyser'), true);
    await vc.handleText('is the geyser on');
    expect(result().message, 'Geyser is on.');

    await vc.handleText('geyser ka timer hatao');
    expect(result().message, 'Geyser timer cancelled.');

    await vc.handleText('what is the weather');
    expect(result().ok, isFalse);

    await vc.handleText('turn on');
    expect(result().message, 'Which device?');

    await vc.handleText('microwave on');
    expect(result().message, "I couldn't find microwave.");

    fake.offline.add('fan');
    await vc.handleText('fan on');
    expect(result().message, 'Fan is not responding.');
    expect(result().ok, isFalse);
  });

  test('speech model missing → guidance', () async {
    stt.next = const [
      SttError(SttErrorKind.modelMissing, 'error_language_unavailable'),
    ];
    await vc.start();
    expect(result().message, contains('offline speech model'));
  });

  test('contextual phrases include names and rooms', () async {
    expect(
      await vc.contextualPhrases(),
      containsAll(['Geyser', 'Bedroom Light', 'Bedroom']),
    );
  });
}
