import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/voice/stt_service.dart';

import 'stt_service_test.dart' show FakeEngine;

class ThrowingEngine extends FakeEngine {
  @override
  Future<bool> initialize(void Function(SttError) onError) async =>
      throw PlatformException(code: 'recognizerNotAvailable');
}

/// Fakes VoskPlugin.kt: [available], and on `start` plays [script] as events.
class FakeVosk {
  FakeVosk(this.script, {this.available = true});
  final List<Map<String, Object?>> script;
  final bool available;
  final calls = <String>[];
  // Lives for the test process; nothing to clean up.
  // ignore: close_sinks
  final _events = StreamController<Object?>.broadcast();
  static const methods = MethodChannel('offline_home/vosk');
  static const events = EventChannel('offline_home/vosk/events');

  void install(TestDefaultBinaryMessenger m) {
    m.setMockMethodCallHandler(methods, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'available':
          return available;
        case 'start':
          scheduleMicrotask(() => script.forEach(_events.add));
          return true;
      }
      return null;
    });
    m.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (args, sink) => _events.stream.listen(sink.success),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('no platform recogniser → bundled Vosk is used', () async {
    final vosk = FakeVosk([
      {'partial': 'fan'},
      {'partial': 'fan on'},
      {'final': 'fan on'},
    ])..install(m);
    final engine = FallbackSpeechEngine(ThrowingEngine(), VoskSpeechEngine());
    final events = await SttService(engine).listen(localeId: 'en_IN').toList();
    expect(engine.activeName, 'bundled');
    expect(events.whereType<SttPartial>().map((e) => e.text), [
      'fan',
      'fan on',
    ]);
    expect((events.last as SttFinal).text, 'fan on');
    expect(vosk.calls, ['available', 'start']);
  });

  test('platform recogniser present → Vosk is not touched', () async {
    final vosk = FakeVosk(const [])..install(m);
    final engine = FallbackSpeechEngine(
      FakeEngine(
        script: const [
          SttFinal(['geyser on']),
        ],
      ),
      VoskSpeechEngine(),
    );
    final events = await SttService(engine).listen(localeId: 'en_IN').toList();
    expect(engine.activeName, 'platform');
    expect((events.single as SttFinal).text, 'geyser on');
    expect(vosk.calls, isEmpty);
  });

  test('Vosk timeout keeps the last partial; silence is no-match', () async {
    FakeVosk([
      {'partial': 'hall light off'},
      {'timeout': true},
    ]).install(m);
    var events = await SttService(VoskSpeechEngine())
        .listen(localeId: 'en_IN')
        .toList();
    expect((events.last as SttFinal).text, 'hall light off');

    FakeVosk([
      {'timeout': true},
    ]).install(m);
    events = await SttService(VoskSpeechEngine())
        .listen(localeId: 'en_IN')
        .toList();
    expect((events.last as SttError).kind, SttErrorKind.noMatch);
  });

  test('neither engine → clear "unavailable" error, no throw', () async {
    FakeVosk(const [], available: false).install(m);
    final engine = FallbackSpeechEngine(ThrowingEngine(), VoskSpeechEngine());
    final events = await SttService(engine).listen(localeId: 'en_IN').toList();
    expect((events.single as SttError).kind, SttErrorKind.unavailable);
  });
}
