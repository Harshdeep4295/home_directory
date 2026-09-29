import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/intent.dart';
import 'package:offline_home/voice/intent_parser.dart';
import 'package:offline_home/voice/lexicon.dart';

void main() {
  final lex = Lexicon.fromYaml([
    for (final p in Lexicon.assetPaths) File(p).readAsStringSync(),
  ]);
  final parser = IntentParser(lex);
  final now = DateTime(2026, 9, 29, 20, 0);
  Intent p(String s) => parser.parse(s, now: now);

  const geyser = TargetSpan(words: ['geyser']);
  const ac = TargetSpan(words: ['ac']);
  const fan = TargetSpan(words: ['fan']);
  const lightsExceptBedroom = TargetSpan(
    words: ['light'],
    all: true,
    except: ['bedroom'],
  );

  // PSEUDOCODE §11.5 examples (must all be in the golden corpus too).
  final spec = <String, Intent>{
    'turn on geyser for 20 minutes': const Intent.powerFor(
      PowerAction.on,
      Duration(minutes: 20),
      geyser,
    ),
    'geyser 20 minute ke liye chalu karo': const Intent.powerFor(
      PowerAction.on,
      Duration(minutes: 20),
      geyser,
    ),
    'AC band karo 11 baje': const Intent.powerAt(
      PowerAction.off,
      ClockTime(23),
      ac,
    ),
    'AC 11 baje tak chalao': const Intent.powerUntil(
      PowerAction.on,
      ClockTime(23),
      ac,
    ),
    'turn off all lights except bedroom': const Intent.power(
      PowerAction.off,
      lightsExceptBedroom,
    ),
    'sab batti band karo bedroom ke alawa': const Intent.power(
      PowerAction.off,
      lightsExceptBedroom,
    ),
    '10 minute baad fan band kar do': const Intent.powerAfter(
      PowerAction.off,
      Duration(minutes: 10),
      fan,
    ),
    'is the geyser on': const Intent.status(geyser),
    'geyser ka timer hatao': const Intent.cancelTimer(geyser),
  };
  spec.forEach(
    (input, want) => test('spec: $input', () => expect(p(input), want)),
  );

  final more = <String, Intent>{
    'turn the fan off': const Intent.power(PowerAction.off, fan),
    'switch the fan on': const Intent.power(PowerAction.on, fan),
    'toggle the fan': const Intent.power(PowerAction.toggle, fan),
    'fan off in 5 minutes': const Intent.powerAfter(
      PowerAction.off,
      Duration(minutes: 5),
      fan,
    ),
    'geyser on 20 minute': const Intent.powerFor(
      PowerAction.on,
      Duration(minutes: 20),
      geyser,
    ),
    'turn off the ac at 11 pm': const Intent.powerAt(
      PowerAction.off,
      ClockTime(23),
      ac,
    ),
    'ac on until 6 am': const Intent.powerUntil(
      PowerAction.on,
      ClockTime(6),
      ac,
    ),
    'geyser chalu hai kya': const Intent.status(geyser),
    'cancel the geyser timer': const Intent.cancelTimer(geyser),
    'bedroom ki lights band karo': const Intent.power(
      PowerAction.off,
      TargetSpan(words: ['bedroom', 'light'], all: true),
    ),
    'sab band karo': const Intent.power(PowerAction.off, TargetSpan(all: true)),
    'pankha dedh ghante ke liye chalao': const Intent.powerFor(
      PowerAction.on,
      Duration(minutes: 90),
      fan,
    ),
    'raat 11 baje ac band kar dena': const Intent.powerAt(
      PowerAction.off,
      ClockTime(23),
      ac,
    ),
    'गीज़र 20 मिनट के लिए चालू करो': const Intent.powerFor(
      PowerAction.on,
      Duration(minutes: 20),
      geyser,
    ),
    'kitchen light jala do': const Intent.power(
      PowerAction.on,
      TargetSpan(words: ['kitchen', 'light']),
    ),
  };
  more.forEach((input, want) => test(input, () => expect(p(input), want)));

  test('no action → unknown; action without target → which device', () {
    expect(p('hello there'), isA<UnknownIntent>());
    expect(p('turn on'), const Intent.unknown(IntentParser.whichDevice));
    expect(p(''), isA<UnknownIntent>());
  });
}
