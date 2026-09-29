import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

import '../core/intent.dart';

/// Normalised phrases split into tokens.
typedef Phrase = List<String>;

enum ActionKind { on, off, toggle, cancel, status }

enum Relation { forDuration, until, after, at }

enum Meridiem { am, pm }

/// Voice vocabulary loaded from assets/voice/lexicon_{en,hi}.yaml (PSEUDOCODE §11.3).
class Lexicon {
  Lexicon({
    required this.actions,
    required this.relations,
    required this.dayparts,
    required this.nouns,
    required this.all,
    required this.except,
    required this.units,
    required this.particles,
  });

  final Map<ActionKind, List<Phrase>> actions;
  final Map<Relation, List<Phrase>> relations;
  final Map<String, Meridiem> dayparts;

  /// canonical noun → phrases (light → [batti, lights, bulb …]).
  final Map<String, List<Phrase>> nouns;
  final List<Phrase> all;
  final List<Phrase> except;

  /// canonical unit (minute/hour/second) → words.
  final Map<String, List<String>> units;
  final Set<String> particles;

  static const assetPaths = [
    'assets/voice/lexicon_en.yaml',
    'assets/voice/lexicon_hi.yaml',
  ];

  static Future<Lexicon> loadAssets() async =>
      fromYaml([for (final p in assetPaths) await rootBundle.loadString(p)]);

  static PowerAction? powerActionOf(ActionKind k) => switch (k) {
    ActionKind.on => PowerAction.on,
    ActionKind.off => PowerAction.off,
    ActionKind.toggle => PowerAction.toggle,
    _ => null,
  };

  /// Merges several YAML documents (English + Hindi).
  static Lexicon fromYaml(List<String> docs) {
    final actions = <ActionKind, List<Phrase>>{
      for (final k in ActionKind.values) k: [],
    };
    final relations = <Relation, List<Phrase>>{
      for (final r in Relation.values) r: [],
    };
    final dayparts = <String, Meridiem>{};
    final nouns = <String, List<Phrase>>{};
    final all = <Phrase>[];
    final except = <Phrase>[];
    final units = <String, List<String>>{};
    final particles = <String>{};

    Phrase tok(Object? s) =>
        '$s'.split(' ').where((w) => w.isNotEmpty).toList();
    List<Phrase> list(Object? l) =>
        l is YamlList ? [for (final s in l) tok(s)] : const [];

    for (final doc in docs) {
      final y = loadYaml(doc) as YamlMap;
      final a = y['actions'] as YamlMap? ?? YamlMap();
      for (final k in ActionKind.values) {
        actions[k]!.addAll(list(a[k.name]));
      }
      final r = y['relations'] as YamlMap? ?? YamlMap();
      relations[Relation.forDuration]!.addAll(list(r['for']));
      relations[Relation.until]!.addAll(list(r['until']));
      relations[Relation.after]!.addAll(list(r['after']));
      relations[Relation.at]!.addAll(list(r['at']));
      final d = y['dayparts'] as YamlMap? ?? YamlMap();
      d.forEach((k, v) => dayparts['$k'] = Meridiem.values.byName('$v'));
      final n = y['nouns'] as YamlMap? ?? YamlMap();
      n.forEach((k, v) => (nouns['$k'] ??= []).addAll(list(v)));
      final q = y['quantifiers'] as YamlMap? ?? YamlMap();
      all.addAll(list(q['all']));
      except.addAll(list(q['except']));
      final u = y['units'] as YamlMap? ?? YamlMap();
      u.forEach(
        (k, v) =>
            (units['$k'] ??= []).addAll([for (final w in v as YamlList) '$w']),
      );
      particles.addAll([
        for (final p in y['particles'] as YamlList? ?? YamlList()) '$p',
      ]);
    }
    int byLength(Phrase a, Phrase b) => b.length.compareTo(a.length);
    for (final l in [
      ...actions.values,
      ...relations.values,
      ...nouns.values,
      all,
      except,
    ]) {
      l.sort(byLength); // longest match first
    }
    return Lexicon(
      actions: actions,
      relations: relations,
      dayparts: dayparts,
      nouns: nouns,
      all: all,
      except: except,
      units: units,
      particles: particles,
    );
  }

  /// Canonical unit for a word (`ghanta` → hour), or null.
  String? unitOf(String word) {
    for (final e in units.entries) {
      if (e.value.contains(word)) return e.key;
    }
    return null;
  }

  /// Canonical noun for a token sequence starting at [i], with its length.
  (String, int)? nounAt(List<String> t, int i) {
    (String, int)? best;
    nouns.forEach((canon, phrases) {
      for (final p in phrases) {
        if (matchAt(t, i, p) && (best == null || p.length > best!.$2)) {
          best = (canon, p.length);
        }
      }
    });
    return best;
  }

  static bool matchAt(List<String> t, int i, Phrase p) {
    if (p.isEmpty || i + p.length > t.length) return false;
    for (var k = 0; k < p.length; k++) {
      if (t[i + k] != p[k]) return false;
    }
    return true;
  }
}
