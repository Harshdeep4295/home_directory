import 'dart:async';

import 'package:flutter/services.dart';
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

  /// No recogniser on this device at all (and no bundled fallback).
  unavailable,
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
    try {
      _ready = await _engine.initialize((e) => _current?.add(e));
    } on Object catch (e) {
      log.w('stt', 'no recogniser', e);
      _ready = false;
    }
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
            SttErrorKind.unavailable,
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
  Future<bool> initialize(void Function(SttError) onError) async {
    try {
      return await _stt.initialize(
        onError: (SpeechRecognitionError e) {
          final err = mapPlatformError(e.errorMsg);
          log.w('stt', 'error ${e.errorMsg} (permanent: ${e.permanent})');
          (_onEvent ?? onError)(err);
        },
      );
    } on PlatformException catch (e) {
      // e.g. recognizerNotAvailable on Android without a speech service.
      log.w('stt', 'platform recogniser unavailable: ${e.code}');
      return false;
    }
  }

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

/// Uses the phone's own on-device recogniser, else the bundled one (Android: Vosk).
class FallbackSpeechEngine implements SpeechEngine {
  FallbackSpeechEngine(this.primary, this.fallback);
  final SpeechEngine primary;
  final SpeechEngine fallback;
  SpeechEngine? _active;

  /// Which engine is in use, for diagnostics ("platform" / "bundled").
  String get activeName => _active == null
      ? 'none'
      : identical(_active, primary)
      ? 'platform'
      : 'bundled';

  static Future<bool> _try(
    SpeechEngine e,
    void Function(SttError) onError,
  ) async {
    try {
      return await e.initialize(onError);
    } on Object catch (err) {
      log.w('stt', 'engine init failed', err);
      return false;
    }
  }

  @override
  Future<bool> initialize(void Function(SttError) onError) async {
    if (await _try(primary, onError)) {
      _active = primary;
    } else if (await _try(fallback, onError)) {
      _active = fallback;
      log.i('stt', 'using the bundled offline recogniser');
    } else {
      _active = null;
    }
    return _active != null;
  }

  @override
  Future<List<String>> localeIds() async => await _active?.localeIds() ?? [];

  @override
  Future<void> listen({
    required String localeId,
    required List<String> contextualPhrases,
    required Duration listenFor,
    required Duration pauseFor,
    required void Function(SttEvent) onEvent,
  }) async {
    final e = _active;
    if (e == null) {
      onEvent(const SttError(SttErrorKind.unavailable, 'no recogniser'));
      return;
    }
    await e.listen(
      localeId: localeId,
      contextualPhrases: contextualPhrases,
      listenFor: listenFor,
      pauseFor: pauseFor,
      onEvent: onEvent,
    );
  }

  @override
  Future<void> stop() async => _active?.stop();

  @override
  Future<void> cancel() async => _active?.cancel();
}

/// Bundled offline recogniser: Vosk with the small Indian-English model, through the
/// app's own Android bridge (VoskPlugin.kt). Audio never leaves the device.
class VoskSpeechEngine implements SpeechEngine {
  VoskSpeechEngine({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('offline_home/vosk'),
      _events = events ?? const EventChannel('offline_home/vosk/events');

  final MethodChannel _methods;
  final EventChannel _events;
  StreamSubscription<Object?>? _sub;

  @override
  Future<bool> initialize(void Function(SttError) onError) async {
    try {
      return await _methods.invokeMethod<bool>('available') ?? false;
    } on MissingPluginException {
      return false; // iOS, tests
    } on PlatformException {
      return false;
    }
  }

  /// One model: Indian English (also used for Hinglish, PLAN §7).
  @override
  Future<List<String>> localeIds() async => const ['en_IN'];

  @override
  Future<void> listen({
    required String localeId,
    required List<String> contextualPhrases,
    required Duration listenFor,
    required Duration pauseFor,
    required void Function(SttEvent) onEvent,
  }) async {
    await _sub?.cancel();
    var last = '';
    var done = false;
    void finish(SttEvent e) {
      if (done) return;
      done = true;
      onEvent(e);
      unawaited(_sub?.cancel());
      _sub = null;
    }

    _sub = _events.receiveBroadcastStream().listen((raw) {
      final m = (raw as Map).cast<String, Object?>();
      if (m['partial'] case final String p when p.isNotEmpty) {
        last = p;
        if (!done) onEvent(SttPartial(p));
      } else if (m['final'] case final String f) {
        final text = f.isNotEmpty ? f : last;
        finish(
          text.isEmpty
              ? const SttError(SttErrorKind.noMatch, 'nothing heard')
              : SttFinal([text]),
        );
      } else if (m.containsKey('timeout')) {
        finish(
          last.isEmpty
              ? const SttError(SttErrorKind.noMatch, 'timeout')
              : SttFinal([last]),
        );
      } else if (m['error'] case final String err) {
        finish(SttError(SttErrorKind.other, err));
      }
    });
    final ok = await _methods.invokeMethod<bool>('start', {
      'timeoutMs': listenFor.inMilliseconds,
    });
    if (ok != true) {
      finish(const SttError(SttErrorKind.unavailable, 'offline model missing'));
    }
  }

  @override
  Future<void> stop() => _methods.invokeMethod<void>('stop');

  @override
  Future<void> cancel() async {
    await _methods.invokeMethod<void>('cancel');
    await _sub?.cancel();
    _sub = null;
  }
}
