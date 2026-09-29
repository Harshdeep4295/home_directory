import '../core/intent.dart';
import '../core/models.dart';
import 'fuzzy.dart';
import 'lexicon.dart';
import 'normaliser.dart';

class ScoredDevice {
  const ScoredDevice(this.device, this.score);
  final Device device;
  final double score;
  @override
  String toString() => '${device.name}:${score.toStringAsFixed(2)}';
}

/// Resolution result. [devices] are the targets; when [ambiguous] the UI shows [choices]
/// as chips (PLAN §7 confirmation rules).
class Resolution {
  const Resolution(
    this.devices, {
    this.choices = const [],
    this.ambiguous = false,
  });
  final List<Device> devices;
  final List<ScoredDevice> choices;
  final bool ambiguous;
  bool get isEmpty => devices.isEmpty && choices.isEmpty;
}

/// Maps a [TargetSpan] onto registry devices (PSEUDOCODE §11.6): rooms, nouns, all /
/// except, fuzzy + phonetic name matching over names and aliases.
class TargetResolver {
  TargetResolver(this._lex);

  final Lexicon _lex;

  static const minScore = 0.6;
  static const confidentScore = 0.8;
  static const tieMargin = 0.05;
  static const roomScore = 0.85;

  Resolution resolve(
    TargetSpan span, {
    required List<Device> devices,
    List<Room> rooms = const [],
  }) {
    var words = [...span.words];
    // A device literally named by the whole phrase wins ("bedroom light" → the device
    // "Bedroom Light", not every light in the bedroom).
    if (!span.all && words.isNotEmpty) {
      final exact = devices
          .where((d) => score(words.join(' '), d) >= 1.0)
          .toList();
      if (exact.length == 1) return Resolution(exact);
    }
    final room = _matchRoom(words, rooms);
    if (room != null) {
      words = words.where((w) => !_tokens(room.name).contains(w)).toList();
    }
    final scope = room == null
        ? devices
        : devices.where((d) => d.roomId == room.id).toList();
    final nouns = words.where(_lex.nouns.containsKey).toSet();

    // "sab batti band karo", "bedroom ki lights", "bedroom band karo"
    if (span.all ||
        (room != null && (words.isEmpty || words.every(nouns.contains)))) {
      var pool = nouns.isEmpty
          ? scope
          : scope.where((d) => nouns.any((n) => _isA(d, n))).toList();
      if (span.except.isNotEmpty) {
        final excluded = _resolveExcept(span.except, devices, rooms);
        pool = pool.where((d) => !excluded.contains(d.id)).toList();
      }
      return Resolution(pool);
    }

    if (words.isEmpty) return const Resolution([]);
    final phrase = words.join(' ');
    final scored = [for (final d in scope) ScoredDevice(d, score(phrase, d))]
      ..sort((a, b) => b.score.compareTo(a.score));
    if (scored.isEmpty || scored.first.score < minScore) {
      return const Resolution([]);
    }
    final best = scored.first;
    final close = scored
        .where((s) => s.score >= minScore && best.score - s.score <= tieMargin)
        .toList();
    if (best.score < confidentScore || close.length > 1) {
      return Resolution(
        const [],
        choices: scored.where((s) => s.score >= minScore).take(3).toList(),
        ambiguous: true,
      );
    }
    return Resolution([best.device]);
  }

  /// Best similarity of [phrase] to the device's name or any alias.
  double score(String phrase, Device d) {
    final names = [d.name, ...d.aliases];
    var best = 0.0;
    for (final n in names) {
      final s = _similarity(phrase, n);
      if (s > best) best = s;
    }
    return best;
  }

  double _similarity(String phrase, String name) {
    final p = _tokens(phrase);
    final n = _tokens(name);
    if (p.isEmpty || n.isEmpty) return 0;
    final pj = p.join(' ');
    final nj = n.join(' ');
    // A generic alias ("batti") equal to a generic word ("light") is a category hit, not
    // a name: it must not beat other lights.
    final generic =
        p.every(_lex.nouns.containsKey) && n.every(_lex.nouns.containsKey);
    if (pj == nj) return generic ? 0.95 : 1;
    // every spoken word appears in the name ("geyser" ⊂ "bathroom geyser")
    if (p.every(n.contains)) return 0.95;
    // per-token best Jaro-Winkler, averaged over spoken tokens
    var tokenScore = 0.0;
    for (final t in p) {
      var m = 0.0;
      for (final u in n) {
        final s = Fuzzy.jaroWinkler(t, u);
        if (s > m) m = s;
      }
      tokenScore += m;
    }
    tokenScore /= p.length;
    final whole = Fuzzy.jaroWinkler(pj, nj);
    final phonetic =
        Fuzzy.phoneticKey(pj) == Fuzzy.phoneticKey(nj) ||
            p.every(
              (t) => n.any((u) => Fuzzy.phoneticKey(t) == Fuzzy.phoneticKey(u)),
            )
        ? 1.0
        : 0.0;
    final jw = tokenScore > whole ? tokenScore : whole;
    return 0.6 * jw + 0.4 * phonetic;
  }

  /// Normalised, noun-canonicalised tokens ("Bedroom Batti" → [bedroom, light]).
  List<String> _tokens(String s) {
    final t = Normaliser.normalise(s).tokens;
    final out = <String>[];
    for (var i = 0; i < t.length;) {
      final noun = _lex.nounAt(t, i);
      if (noun != null) {
        out.add(noun.$1);
        i += noun.$2;
      } else {
        out.add(t[i++]);
      }
    }
    return out;
  }

  /// Is device [d] a [noun] (light, fan, geyser …) by name, alias or kind?
  bool _isA(Device d, String noun) {
    if ([d.name, ...d.aliases].any((n) => _tokens(n).contains(noun))) {
      return true;
    }
    if (noun == 'light') {
      // Bulbs report brightness; WiZ/Hue/Yeelight lights unless named otherwise.
      return d.capabilities.contains(Capability.brightness) ||
          const {Brand.hue, Brand.yeelight}.contains(d.brand);
    }
    return false;
  }

  Room? _matchRoom(List<String> words, List<Room> rooms) {
    Room? best;
    var bestScore = roomScore;
    for (final r in rooms) {
      final rt = _tokens(r.name);
      if (rt.isEmpty) continue;
      if (rt.every(words.contains)) return r;
      for (final w in words) {
        final s = Fuzzy.jaroWinkler(w, rt.join(' '));
        if (s >= bestScore) {
          best = r;
          bestScore = s;
        }
      }
    }
    return best;
  }

  /// Ids excluded by "except X": X may be a room or device(s).
  Set<String> _resolveExcept(
    List<String> except,
    List<Device> devices,
    List<Room> rooms,
  ) {
    final room = _matchRoom(except, rooms);
    if (room != null) {
      return {
        for (final d in devices)
          if (d.roomId == room.id) d.id,
      };
    }
    final phrase = except.join(' ');
    return {
      for (final d in devices)
        if (score(phrase, d) >= confidentScore) d.id,
    };
  }
}
