import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/voice/lexicon.dart';

Lexicon loadLexicon() => Lexicon.fromYaml([
  for (final p in Lexicon.assetPaths) File(p).readAsStringSync(),
]);

void main() {
  final lex = loadLexicon();

  test('actions merged from EN + HI, longest phrase first', () {
    final off = lex.actions[ActionKind.off]!;
    expect(
      off,
      containsAll([
        ['band', 'karo'],
        ['turn', 'off'],
        ['bujhao'],
      ]),
    );
    expect(off.first.length, greaterThanOrEqualTo(off.last.length));
    expect(
      lex.actions[ActionKind.cancel],
      anyElement(equals(['timer', 'hatao'])),
    );
  });

  test('relations, dayparts, units', () {
    expect(
      lex.relations[Relation.forDuration],
      containsAll([
        ['for'],
        ['ke', 'liye'],
      ]),
    );
    expect(lex.relations[Relation.at], anyElement(equals(['baje'])));
    expect(lex.dayparts['raat'], Meridiem.pm);
    expect(lex.dayparts['subah'], Meridiem.am);
    expect(lex.unitOf('ghanta'), 'hour');
    expect(lex.unitOf('minute'), 'minute');
    expect(lex.unitOf('geyser'), isNull);
  });

  test('nouns: Hinglish seeds map to canonical nouns', () {
    expect(lex.nounAt(['batti'], 0), ('light', 1));
    expect(lex.nounAt(['pankha'], 0), ('fan', 1));
    expect(lex.nounAt(['water', 'heater', 'on'], 0), ('geyser', 2));
    expect(lex.nounAt(['sofa'], 0), isNull);
  });

  test('quantifiers and particles', () {
    expect(
      lex.all,
      containsAll([
        ['sab'],
        ['all'],
        ['saari'],
      ]),
    );
    expect(
      lex.except,
      containsAll([
        ['ke', 'alawa'],
        ['except'],
        ['chhod', 'ke'],
      ]),
    );
    expect(lex.particles, containsAll(['ka', 'ki', 'ke']));
  });
}
