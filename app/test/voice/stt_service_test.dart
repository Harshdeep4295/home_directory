import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/voice/stt_service.dart';

class FakeEngine implements SpeechEngine {
  FakeEngine({this.ok = true, this.script = const []});
  final bool ok;
  final List<SttEvent> script;
  Map<String, Object?>? lastListen;
  int inits = 0;

  @override
  Future<bool> initialize(void Function(SttError) onError) async {
    inits++;
    return ok;
  }

  @override
  Future<List<String>> localeIds() async => ['en_IN', 'hi_IN', 'en_US'];

  @override
  Future<void> listen({
    required String localeId,
    required List<String> contextualPhrases,
    required Duration listenFor,
    required Duration pauseFor,
    required void Function(SttEvent) onEvent,
  }) async {
    lastListen = {
      'locale': localeId,
      'ctx': contextualPhrases,
      'pause': pauseFor,
    };
    for (final e in script) {
      onEvent(e);
    }
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}

void main() {
  test('partials then final; stream closes after final', () async {
    final engine = FakeEngine(
      script: const [
        SttPartial('geyser'),
        SttPartial('geyser on'),
        SttFinal(['geyser on for 20 minutes', 'geezer on for 20 minutes']),
      ],
    );
    final events = await SttService(engine)
        .listen(localeId: 'en_IN', contextual: ['Geyser'])
        .toList();
    expect(events.whereType<SttPartial>().map((e) => e.text), [
      'geyser',
      'geyser on',
    ]);
    expect((events.last as SttFinal).text, 'geyser on for 20 minutes');
    expect(engine.lastListen, {
      'locale': 'en_IN',
      'ctx': ['Geyser'],
      'pause': const Duration(milliseconds: 1200),
    });
  });

  test('unavailable recogniser → permission error', () async {
    final events = await SttService(FakeEngine(ok: false))
        .listen(localeId: 'en_IN')
        .toList();
    expect((events.single as SttError).kind, SttErrorKind.permission);
  });

  test('capabilities: locales and initialise once', () async {
    final engine = FakeEngine();
    final s = SttService(engine);
    final caps = await s.capabilities();
    expect(caps.available, isTrue);
    expect(caps.supports('hi_in'), isTrue);
    expect(caps.supports('ta_IN'), isFalse);
    await s.capabilities();
    expect(engine.inits, 1);
  });

  test('platform error mapping', () {
    expect(
      PlatformSpeechEngine.mapPlatformError('error_language_unavailable').kind,
      SttErrorKind.modelMissing,
    );
    expect(
      PlatformSpeechEngine.mapPlatformError('error_no_match').kind,
      SttErrorKind.noMatch,
    );
    expect(
      PlatformSpeechEngine.mapPlatformError('error_insufficient_permissions')
          .kind,
      SttErrorKind.permission,
    );
    expect(
      PlatformSpeechEngine.mapPlatformError('error_busy').kind,
      SttErrorKind.other,
    );
  });
}
