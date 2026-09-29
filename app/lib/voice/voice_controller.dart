import 'dart:async';

import '../core/intent.dart';
import '../core/models.dart';
import '../core/result.dart';
import '../engine/command_engine.dart';
import '../registry/repositories.dart';
import '../timers/tier_copy.dart';
import '../timers/timer_service.dart';
import 'intent_parser.dart';
import 'stt_service.dart';
import 'target_resolver.dart';
import 'tts.dart';

/// UI-facing state of the voice sheet (PSEUDOCODE §13 voiceStateProvider).
sealed class VoiceState {
  const VoiceState();
}

final class VoiceIdle extends VoiceState {
  const VoiceIdle();
}

final class VoiceListening extends VoiceState {
  const VoiceListening(this.partial);
  final String partial;
}

/// Waiting for the user to pick devices (ambiguous) or approve a big command.
final class VoiceConfirming extends VoiceState {
  const VoiceConfirming(this.transcript, this.question, this.options);
  final String transcript;
  final String question;
  final List<Device> options;
}

final class VoiceResult extends VoiceState {
  const VoiceResult(
    this.transcript,
    this.message, {
    this.ok = true,
    this.canUndo = false,
  });
  final String transcript;
  final String message;
  final bool ok;
  final bool canUndo;
}

/// Orchestrates one voice command (PSEUDOCODE §0.2, §11.7): listen → parse → resolve →
/// confirm → execute → speak + toast with 5 s undo.
class VoiceController {
  VoiceController({
    required this.stt,
    required this.parser,
    required this.resolver,
    required this.engine,
    required this.timers,
    required this.devices,
    required this.rooms,
    required this.tts,
    this.isIOS = false,
    this.localeId = 'en_IN',
    this.speakFeedback = true,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SttService stt;
  final IntentParser parser;
  final TargetResolver resolver;
  final CommandEngine engine;
  final TimerService timers;
  final DeviceRepository devices;
  final RoomRepository rooms;
  final Tts tts;
  final bool isIOS;
  String localeId;
  bool speakFeedback;
  final DateTime Function() _now;

  /// PLAN §7: "all" commands touching more than this many devices need a confirmation.
  static const confirmAbove = 5;
  static const undoWindow = Duration(seconds: 5);

  final _states = StreamController<VoiceState>.broadcast();
  VoiceState _state = const VoiceIdle();
  Intent? _pending;
  String _pendingTranscript = '';
  Future<void> Function()? _undo;
  Timer? _undoTimer;

  Stream<VoiceState> get states => _states.stream;
  VoiceState get state => _state;

  void _set(VoiceState s) {
    _state = s;
    if (!_states.isClosed) _states.add(s);
  }

  /// Device names, aliases and rooms, passed to the recogniser as hints.
  Future<List<String>> contextualPhrases() async => [
    for (final d in await devices.all()) ...[d.name, ...d.aliases],
    for (final r in await rooms.all()) r.name,
  ];

  /// Push-to-talk pressed.
  Future<void> start() async {
    _set(const VoiceListening(''));
    final hints = await contextualPhrases();
    await for (final e in stt.listen(localeId: localeId, contextual: hints)) {
      switch (e) {
        case SttPartial(:final text):
          _set(VoiceListening(text));
        case SttFinal(:final text):
          await handleText(text);
        case SttError(:final kind, :final message):
          await _finish('', switch (kind) {
            SttErrorKind.modelMissing => 'The offline speech model is missing. Download it once in settings.',
            SttErrorKind.noMatch => "Sorry, I didn't catch that.",
            SttErrorKind.permission =>
              'Microphone or speech permission is off.',
            SttErrorKind.other => 'Speech recognition failed ($message).',
          }, ok: false);
      }
    }
  }

  /// Push-to-talk released early.
  Future<void> stopListening() => stt.stop();

  /// Parses and runs [text] (also used by typed commands and tests).
  Future<void> handleText(String text) async {
    final intent = parser.parse(text, now: _now());
    if (intent is UnknownIntent) {
      return _finish(
        text,
        intent.text == IntentParser.whichDevice
            ? 'Which device?'
            : "Sorry, I didn't get that.",
        ok: false,
      );
    }
    final span = _targetsOf(intent)!;
    final all = await devices.all();
    final r = resolver.resolve(span, devices: all, rooms: await rooms.all());
    if (r.ambiguous) {
      _pending = intent;
      _pendingTranscript = text;
      _set(
        VoiceConfirming(
          text,
          'Which one?',
          r.choices.map((c) => c.device).toList(),
        ),
      );
      return;
    }
    if (r.devices.isEmpty) {
      return _finish(
        text,
        "I couldn't find ${span.words.join(' ')}.",
        ok: false,
      );
    }
    if (span.all && r.devices.length > confirmAbove) {
      _pending = intent;
      _pendingTranscript = text;
      _set(
        VoiceConfirming(
          text,
          '${_verb(intent)} ${r.devices.length} devices?',
          r.devices,
        ),
      );
      return;
    }
    await _execute(text, intent, r.devices);
  }

  /// User picked / approved devices on the confirmation sheet.
  Future<void> confirm(List<Device> chosen) async {
    final intent = _pending;
    _pending = null;
    if (intent == null || chosen.isEmpty) {
      _set(const VoiceIdle());
      return;
    }
    await _execute(_pendingTranscript, intent, chosen);
  }

  void cancelConfirmation() {
    _pending = null;
    _set(const VoiceIdle());
  }

  /// Reverts the last command if still within [undoWindow].
  Future<bool> undo() async {
    final u = _undo;
    if (u == null) return false;
    _undo = null;
    _undoTimer?.cancel();
    await u();
    _set(const VoiceResult('', 'Undone.'));
    return true;
  }

  Future<void> _execute(
    String text,
    Intent intent,
    List<Device> targets,
  ) async {
    final before = {for (final d in targets) d.id: engine.cached(d.id)?.on};
    switch (intent) {
      case PowerIntent(:final action):
        final res = Aggregate(await engine.power(targets, action));
        if (action == PowerAction.on) await timers.applyAutoOff(res.ok);
        _armUndo(() async {
          await timers.cancel(targets);
          await _restore(targets, before);
        });
        return _finish(
          text,
          _powerMessage(targets, res, action),
          ok: res.allOk,
          undo: true,
        );
      case PowerForIntent(:final action, :final duration):
        final out = await timers.powerFor(targets, action, duration);
        _armUndo(() async {
          await timers.cancel(targets);
          await _restore(targets, before);
        });
        return _finish(
          text,
          _timerMessage(out, set: action),
          ok: _allOk(out),
          undo: true,
        );
      case PowerUntilIntent(:final action, :final clock):
        final out = await timers.powerUntil(targets, action, clock);
        _armUndo(() async {
          await timers.cancel(targets);
          await _restore(targets, before);
        });
        return _finish(
          text,
          _timerMessage(out, set: action),
          ok: _allOk(out),
          undo: true,
        );
      case PowerAfterIntent(:final action, :final duration):
        final out = await timers.powerAfter(targets, action, duration);
        _armUndo(() => timers.cancel(targets));
        return _finish(text, _timerMessage(out), ok: _allOk(out), undo: true);
      case PowerAtIntent(:final action, :final clock):
        final out = await timers.powerAt(targets, action, clock);
        _armUndo(() => timers.cancel(targets));
        return _finish(text, _timerMessage(out), ok: _allOk(out), undo: true);
      case CancelTimerIntent():
        await timers.cancel(targets);
        return _finish(text, '${_names(targets)} timer cancelled.');
      case StatusIntent():
        final res = await engine.status(targets);
        final msg = res
            .map(
              (r) => switch (r.result) {
                Ok(:final value) =>
                  '${r.device.name} is ${value.on == true
                      ? 'on'
                      : value.on == false
                      ? 'off'
                      : 'unknown'}',
                Err() => '${r.device.name} is not responding',
              },
            )
            .join('. ');
        return _finish(text, '$msg.');
      case UnknownIntent():
        return _finish(text, "Sorry, I didn't get that.", ok: false);
    }
  }

  Future<void> _restore(List<Device> targets, Map<String, bool?> before) async {
    for (final d in targets) {
      final was = before[d.id];
      if (was != null) await engine.powerOne(d, was);
    }
  }

  void _armUndo(Future<void> Function() fn) {
    _undoTimer?.cancel();
    _undo = fn;
    _undoTimer = Timer(undoWindow, () => _undo = null);
  }

  Future<void> _finish(
    String transcript,
    String message, {
    bool ok = true,
    bool undo = false,
  }) async {
    _set(
      VoiceResult(transcript, message, ok: ok, canUndo: undo && _undo != null),
    );
    if (speakFeedback) await tts.speak(message);
  }

  // ------------------------------------------------------------------ wording

  static TargetSpan? _targetsOf(Intent i) => switch (i) {
    PowerIntent(:final targets) ||
    PowerForIntent(:final targets) ||
    PowerAfterIntent(:final targets) ||
    PowerAtIntent(:final targets) ||
    PowerUntilIntent(:final targets) ||
    CancelTimerIntent(:final targets) ||
    StatusIntent(:final targets) => targets,
    UnknownIntent() => null,
  };

  static String _verb(Intent i) => switch (i) {
    PowerIntent(action: PowerAction.off) => 'Turn off',
    PowerIntent(action: PowerAction.on) => 'Turn on',
    _ => 'Change',
  };

  static String _names(List<Device> ds) => ds.length == 1
      ? ds.single.name
      : ds.length <= 3
      ? '${ds.take(ds.length - 1).map((d) => d.name).join(', ')} and ${ds.last.name}'
      : '${ds.length} devices';

  String _powerMessage(List<Device> ds, Aggregate<void> res, PowerAction a) {
    final word = switch (a) {
      PowerAction.on => 'on',
      PowerAction.off => 'off',
      PowerAction.toggle => 'switched',
    };
    final parts = <String>[
      if (res.ok.isNotEmpty) '${_names(res.ok)} $word.',
      for (final (d, e) in res.failed)
        e.kind == DeviceErrorKind.auth
            ? '${d.name}: key rejected.'
            : '${d.name} is not responding.',
    ];
    return parts.join(' ');
  }

  static bool _allOk(List<TimerOutcome> out) => out.every((o) => o.result.isOk);

  String _hhmm(DateTime t) {
    final l = t.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    return '$h:${l.minute.toString().padLeft(2, '0')}${l.hour < 12 ? ' am' : ' pm'}';
  }

  /// "Geyser on. Off at 9:40 pm (plug timer)." / "Fan off at 10:05 pm (phone timer)."
  String _timerMessage(List<TimerOutcome> out, {PowerAction? set}) {
    final parts = <String>[];
    for (final o in out) {
      switch (o.result) {
        case Ok(value: final j):
          final end = j.endOn ? 'on' : 'off';
          final suffix = TierCopy.feedbackSuffix(j.tier, isIOS: isIOS);
          parts.add(
            set == null
                ? '${o.device.name} $end at ${_hhmm(j.fireAt)} $suffix.'
                : '${o.device.name} ${set == PowerAction.off ? 'off' : 'on'}. '
                      '${end[0].toUpperCase()}${end.substring(1)} at ${_hhmm(j.fireAt)} $suffix.',
          );
        case Err(:final error):
          parts.add(
            error.kind == DeviceErrorKind.auth
                ? '${o.device.name}: key rejected.'
                : '${o.device.name} is not responding.',
          );
      }
    }
    return parts.join(' ');
  }

  Future<void> dispose() async {
    _undoTimer?.cancel();
    await _states.close();
  }
}
