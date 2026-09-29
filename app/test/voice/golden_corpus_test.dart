import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/intent.dart';
import 'package:offline_home/voice/intent_parser.dart';
import 'package:offline_home/voice/lexicon.dart';
import 'package:yaml/yaml.dart';

/// Golden corpus (T4.7): ≥ 150 utterances, ≥ 95 % must parse exactly as expected.
void main() {
  final lex = Lexicon.fromYaml([
    for (final p in Lexicon.assetPaths) File(p).readAsStringSync(),
  ]);
  final parser = IntentParser(lex);
  final files =
      Directory('test/voice/corpus')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yaml'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final cases = <(String file, String say, String expect, String now)>[];
  for (final f in files) {
    for (final c in loadYaml(f.readAsStringSync()) as YamlList) {
      final l = c as YamlList;
      final opts = l.length > 2 ? l[2] as YamlMap : YamlMap();
      cases.add((
        f.uri.pathSegments.last,
        '${l[0]}',
        '${l[1]}',
        '${opts['now'] ?? '20:00'}',
      ));
    }
  }

  test('corpus size and language mix', () {
    expect(cases.length, greaterThanOrEqualTo(150));
    final hi = cases.where((c) => c.$1 == 'hi.yaml').length;
    expect(hi / cases.length, greaterThanOrEqualTo(0.35));
  });

  test('≥ 95 % of the corpus parses exactly', () {
    final failures = <String>[];
    for (final (file, say, want, now) in cases) {
      final hm = now.split(':').map(int.parse).toList();
      final got = parser.parse(say, now: DateTime(2026, 9, 29, hm[0], hm[1]));
      final g = describe(got);
      if (g != want) {
        failures.add('$file: "$say"\n    want: $want\n    got:  $g');
      }
    }
    final rate = 1 - failures.length / cases.length;
    debugPrint(
      'corpus: ${cases.length - failures.length}/${cases.length} = ${(rate * 100).toStringAsFixed(1)} %',
    );
    for (final f in failures) {
      debugPrint('FAIL $f');
    }
    expect(rate, greaterThanOrEqualTo(0.95), reason: failures.join('\n'));
  });
}

String _dur(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return [if (h > 0) '${h}h', if (m > 0) '${m}m', if (s > 0) '${s}s'].join();
}

String _clock(ClockTime c) =>
    '${c.hour.toString().padLeft(2, '0')}:${c.minute.toString().padLeft(2, '0')}';

String _targets(TargetSpan t) {
  final flags = [
    if (t.all) 'all',
    if (t.except.isNotEmpty) 'except=${t.except.join(' ')}',
  ].join(' ');
  final words = t.words.isEmpty ? '' : ' ${t.words.join(' ')}';
  return flags.isEmpty ? '|$words' : '|$words | $flags';
}

/// Renders an intent in the corpus notation.
String describe(Intent i) => switch (i) {
  PowerIntent(:final action, :final targets) =>
    'power ${action.name} ${_targets(targets)}',
  PowerForIntent(:final action, :final duration, :final targets) =>
    'powerFor ${action.name} ${_dur(duration)} ${_targets(targets)}',
  PowerAfterIntent(:final action, :final duration, :final targets) =>
    'powerAfter ${action.name} ${_dur(duration)} ${_targets(targets)}',
  PowerAtIntent(:final action, :final clock, :final targets) =>
    'powerAt ${action.name} ${_clock(clock)} ${_targets(targets)}',
  PowerUntilIntent(:final action, :final clock, :final targets) =>
    'powerUntil ${action.name} ${_clock(clock)} ${_targets(targets)}',
  CancelTimerIntent(:final targets) => 'cancelTimer ${_targets(targets)}',
  StatusIntent(:final targets) => 'status ${_targets(targets)}',
  UnknownIntent() => 'unknown',
};
