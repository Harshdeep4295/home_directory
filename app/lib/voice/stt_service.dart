import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/log.dart';

/// What the phone's recogniser can do (shown on the speech-model onboarding screen).
class SttCapabilities {
  const SttCapabilities({required this.available, required this.locales});

  /// Recogniser present and permission granted.
  final bool available;

  /// Locale ids reported by the platform (e.g. `en_IN`, `hi_IN`). Whether each has an
  /// on-device model is only known when a listen fails (VERIFY on both phones, T4.9).
  final List<String> locales;

  bool supports(String localeId) =>
      locales.any((l) => l.toLowerCase() == localeId.toLowerCase());
}

sealed class SttEvent {
  const SttEvent();
}

final class SttPartial extends SttEvent {
  const SttPartial(this.text);
  final String text;
}

/// Final transcript, best first.
final class SttFinal extends SttEvent {
  const SttFinal(this.alternatives);
  final List<String> alternatives;
  String get text => alternatives.isEmpty ? '' : alternatives.first;
}

enum SttErrorKind {
  /// The on-device model for this language is missing (needs a one-time download).
  modelMissing,
  noMatch,
  permission,
  other,
}

final class SttError extends SttEvent {
  const SttError(this.kind, this.message);
  final SttErrorKind kind;
  final String message;
}

/// Minimal recogniser contract, so a Vosk engine can be plugged in later if a phone has
/// no platform on-device model (T4.1 note).
abstract interface class SpeechEngine {
  Future<bool> initialize(void Function(SttError) onError);
  Future<List<String>> localeIds();

  /// Starts listening. Implementations MUST recognise on-device only (CLAUDE.md rule 6).
  Future<void> listen({
    required String localeId,
    required List<String> contextualPhrases,
    required Duration listenFor,
    required Duration pauseFor,
    required void Function(SttEvent) onEvent,
  });
  Future<void> stop();
  Future<void> cancel();
}

/// Push-to-talk speech recognition (PSEUDOCODE §11.1). Audio never leaves the device.
class SttService {
  SttService(this._engine);

  final SpeechEngine _engine;
  bool _ready = false;
  StreamController<SttEvent>? _current;

  static const listenFor = Duration(seconds: 8);
  static const pauseFor = Duration(milliseconds: 1200);

  Future<SttCapabilities> capabilities() async {
    final ok = await _init();
    return SttCapabilities(
      available: ok,
      locales: ok ? await _engine.localeIds() : const [],
    );
  }

  Future<bool> _init() async {
    if (_ready) return true;
    _ready = await _engine.initialize((e) => _current?.add(e));
    return _ready;
  }

  /// Listens once. Emits partials, then one [SttFinal] or [SttError], then closes.
  Stream<SttEvent> listen({
    required String localeId,
    List<String> contextual = const [],
  }) {
    final ctl = StreamController<SttEvent>();
    _current = ctl;
    () async {
      if (!await _init()) {
        ctl.add(
          const SttError(
            SttErrorKind.permission,
            'speech recognition unavailable',
          ),
        );
        await ctl.close();
        return;
      }
      await _engine.listen(
        localeId: localeId,
        contextualPhrases: contextual,
        listenFor: listenFor,
        pauseFor: pauseFor,
        onEvent: (e) {
          if (ctl.isClosed) return;
          ctl.add(e);
          if (e is SttFinal || e is SttError) unawaited(ctl.close());
        },
      );
    }();
    return ctl.stream;
  }

  Future<void> stop() => _engine.stop();
  Future<void> cancel() => _engine.cancel();
}

/// speech_to_text 7.x with `onDevice: true` (Android SpeechRecognizer
/// EXTRA_PREFER_OFFLINE / iOS requiresOnDeviceRecognition).
class PlatformSpeechEngine implements SpeechEngine {
  PlatformSpeechEngine([SpeechToText? stt]) : _stt = stt ?? SpeechToText();

  final SpeechToText _stt;
  void Function(SttEvent)? _onEvent;

  @override
  Future<bool> initialize(void Function(SttError) onError) => _stt.initialize(
    onError: (SpeechRecognitionError e) {
      final err = mapPlatformError(e.errorMsg);
      log.w('stt', 'error ${e.errorMsg} (permanent: ${e.permanent})');
      (_onEvent ?? onError)(err);
    },
  );

  @override
  Future<List<String>> localeIds() async =>
      (await _stt.locales()).map((l) => l.localeId).toList();

  @override
  Future<void> listen({
    required String localeId,
    required List<String> contextualPhrases,
    required Duration listenFor,
    required Duration pauseFor,
    required void Function(SttEvent) onEvent,
  }) async {
    _onEvent = onEvent;
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) {
        if (r.finalResult) {
          onEvent(
            SttFinal([
              for (final a in r.alternates)
                if (a.recognizedWords.isNotEmpty) a.recognizedWords,
            ]),
          );
        } else {
          onEvent(SttPartial(r.recognizedWords));
        }
      },
      listenOptions: SpeechListenOptions(
        onDevice: true, // rule 6: never cloud
        partialResults: true,
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: localeId,
        listenMode: ListenMode.confirmation,
        contextualPhrases: contextualPhrases,
      ),
    );
  }

  @override
  Future<void> stop() => _stt.stop();

  @override
  Future<void> cancel() => _stt.cancel();

  /// Platform error strings → kinds. Android: SpeechRecognizer ERROR_* names as reported
  /// by speech_to_text; iOS: kAFAssistantErrorDomain codes. VERIFY the exact strings for
  /// "on-device model missing" on both phones (T4.1 hardware note).
  static SttError mapPlatformError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('language_not_supported') ||
        m.contains('language_unavailable') ||
        m.contains('server') ||
        m.contains('network') ||
        m.contains('1101')) {
      return SttError(SttErrorKind.modelMissing, msg);
    }
    if (m.contains('no_match') || m.contains('speech_timeout')) {
      return SttError(SttErrorKind.noMatch, msg);
    }
    if (m.contains('permission') || m.contains('insufficient')) {
      return SttError(SttErrorKind.permission, msg);
    }
    return SttError(SttErrorKind.other, msg);
  }
}
