import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/intent.dart';
import 'package:offline_home/voice/lexicon.dart';
import 'package:offline_home/voice/normaliser.dart';
import 'package:offline_home/voice/time_parser.dart';

void main() {
  final lex = Lexicon.fromYaml([
    for (final p in Lexicon.assetPaths) File(p).readAsStringSync(),
  ]);
  final tp = TimeParser(lex);
  final at8pm = DateTime(2026, 9, 29, 20, 0);
  final at9am = DateTime(2026, 9, 29, 9, 0);

  List<String> t(String s) => Normaliser.normalise(s).tokens;
  Duration? dur(String s) => tp.parseDuration(t(s))?.value;
  ClockTime? clock(String s, [DateTime? now]) =>
      tp.parseClock(t(s), now ?? at8pm)?.value;

  group('durations', () {
    final cases = {
      '20 minutes': const Duration(minutes: 20),
      'adha ghanta': const Duration(minutes: 30),
      'dedh ghante': const Duration(minutes: 90),
      'dhai ghante': const Duration(minutes: 150),
      'for 1 hour 15': const Duration(minutes: 75),
      'for 1 hour 15 minutes': const Duration(minutes: 75),
      '2 ghante 30 minute': const Duration(minutes: 150),
      'in 5 min': const Duration(minutes: 5),
      '5 minute baad': const Duration(minutes: 5),
      'half an hour': const Duration(minutes: 30),
      'an hour': const Duration(hours: 1),
      'do minute': const Duration(minutes: 2),
      'bees minit ke liye': const Duration(minutes: 20),
      '90 seconds': const Duration(seconds: 90),
    };
    cases.forEach((input, want) => test(input, () => expect(dur(input), want)));

    test('no duration', () {
      expect(dur('turn on the geyser'), isNull);
      expect(dur('11 baje'), isNull);
    });

    test('span covers the duration tokens', () {
      final s = tp.parseDuration(t('geyser 20 minute ke liye chalu karo'))!;
      expect([s.start, s.end], [1, 3]);
    });
  });

  group('clock times (now = 20:00 unless noted)', () {
    final cases = <String, ClockTime>{
      '11 pm': const ClockTime(23),
      '11:30 pm': const ClockTime(23, 30),
      'raat 11 baje': const ClockTime(23),
      'subah 6 baje': const ClockTime(6),
      '11:30': const ClockTime(23, 30), // next future occurrence
      '11 baje': const ClockTime(23),
      'at 11': const ClockTime(23),
      'saadhe das baje': const ClockTime(22, 30),
      'sava nau baje': const ClockTime(21, 15),
      'paune gyarah baje': const ClockTime(22, 45),
      'raat 1 baje': const ClockTime(1),
      'raat 12 baje': const ClockTime(0),
      'dopahar 2 baje': const ClockTime(14),
      'shaam 7 baje': const ClockTime(19),
      '6 am': const ClockTime(6),
      '12 pm': const ClockTime(12),
      '12 am': const ClockTime(0),
      '23:15': const ClockTime(23, 15),
      '7 baje subah': const ClockTime(7),
    };
    cases.forEach(
      (input, want) => test(input, () => expect(clock(input), want)),
    );

    test('bare hour resolves to the next occurrence from now', () {
      expect(clock('11 baje', at9am), const ClockTime(11));
      expect(
        clock('8 baje', at8pm),
        const ClockTime(8),
        reason: '20:00 now → 08:00 next',
      );
      expect(clock('9 baje', at8pm), const ClockTime(21));
    });

    test('ambiguous / invalid', () {
      expect(clock('subah 12 baje'), isNull);
      expect(clock('25:00'), isNull);
      expect(clock('turn on geyser for 20 minutes'), isNull);
    });

    test('span includes daypart and baje', () {
      final s = tp.parseClock(t('ac band karo raat 11 baje'), at8pm)!;
      expect([s.start, s.end], [3, 6]);
    });
  });
}
