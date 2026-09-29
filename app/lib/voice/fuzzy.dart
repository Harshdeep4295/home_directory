import 'dart:math' as math;

/// String similarity helpers for voice target matching (PSEUDOCODE §11.6).
abstract final class Fuzzy {
  /// Jaro-Winkler similarity in [0, 1] (prefix scale 0.1, max prefix 4).
  static double jaroWinkler(String a, String b) {
    if (a == b) return a.isEmpty ? 0 : 1;
    if (a.isEmpty || b.isEmpty) return 0;
    final range = math.max(0, math.max(a.length, b.length) ~/ 2 - 1);
    final aM = List<bool>.filled(a.length, false);
    final bM = List<bool>.filled(b.length, false);
    var matches = 0;
    for (var i = 0; i < a.length; i++) {
      final lo = math.max(0, i - range);
      final hi = math.min(b.length - 1, i + range);
      for (var j = lo; j <= hi; j++) {
        if (!bM[j] && a[i] == b[j]) {
          aM[i] = bM[j] = true;
          matches++;
          break;
        }
      }
    }
    if (matches == 0) return 0;
    var k = 0;
    var transpositions = 0;
    for (var i = 0; i < a.length; i++) {
      if (!aM[i]) continue;
      while (!bM[k]) {
        k++;
      }
      if (a[i] != b[k]) transpositions++;
      k++;
    }
    final m = matches.toDouble();
    final jaro =
        (m / a.length + m / b.length + (m - transpositions / 2) / m) / 3;
    var prefix = 0;
    while (prefix < 4 &&
        prefix < a.length &&
        prefix < b.length &&
        a[prefix] == b[prefix]) {
      prefix++;
    }
    return jaro + prefix * 0.1 * (1 - jaro);
  }

  /// Phonetic key tuned for Hinglish device names as heard by an en-IN recogniser
  /// ("geezer"/"gizer"/"geyser", "pankha"/"punkha", "batti"/"bati"). Used instead of
  /// Double Metaphone (PLAN §7 deviation, see TASKS T4.6): Metaphone's English rules
  /// mangle Hindi aspirates and vowels.
  static String phoneticKey(String s) {
    var w = s.toLowerCase().replaceAll(RegExp('[^a-z ]'), '');
    const rules = [
      ('ph', 'f'),
      ('bh', 'b'),
      ('kh', 'k'),
      ('gh', 'g'),
      ('th', 't'),
      ('dh', 'd'),
      ('jh', 'j'),
      ('chh', 'c'),
      ('ch', 'c'),
      ('sh', 's'),
      ('ck', 'k'),
      ('q', 'k'),
      ('x', 'ks'),
      ('z', 'j'),
      ('w', 'v'),
      ('y', 'i'),
      ('c', 'k'),
    ];
    for (final (from, to) in rules) {
      w = w.replaceAll(from, to);
    }
    final out = StringBuffer();
    for (final word in w.split(' ').where((x) => x.isNotEmpty)) {
      if (out.isNotEmpty) out.write(' ');
      String? last;
      for (var i = 0; i < word.length; i++) {
        final ch = word[i];
        final vowel = 'aeiou'.contains(ch);
        if (vowel && i > 0) continue; // keep only a leading vowel
        if (ch == last) continue; // collapse doubles (batti → bati)
        if (ch == 'h' && i > 0) continue; // silent/aspirate h
        out.write(ch);
        last = ch;
      }
    }
    return out.toString();
  }
}
