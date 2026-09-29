import '../core/intent.dart';
import 'lexicon.dart';
import 'normaliser.dart';
import 'time_parser.dart';

/// Rule grammar from normalised text to [Intent] (PSEUDOCODE §11.5).
class IntentParser {
  IntentParser(this._lex) : _time = TimeParser(_lex);

  final Lexicon _lex;
  final TimeParser _time;

  /// Marker text of [UnknownIntent] when an action was understood but no device named.
  static const whichDevice = 'which device?';

  /// Leftover verb words that are not targets ("turn the fan off" → "turn").
  static const _verbResidue = {
    'turn',
    'switch',
    'karo',
    'kar',
    'do',
    'please',
    'set',
    'make',
    'put',
    'kardo',
    'dena',
    'de',
    'hai',
    'kya',
    'raha',
    'rahi',
    'rahe',
    'it',
    'is',
    'are',
    'was',
    'will',
    'be',
    'to',
    'of',
    'and',
    'aur',
    'status',
    'check',
    'timer',
    'what',
    'whats',
  };

  static const _cancelVerbs = {
    'cancel',
    'remove',
    'delete',
    'clear',
    'hatao',
    'hata',
    'khatam',
  };

  /// Hindi postpositional "except" phrases: the excluded words come BEFORE them.
  static const _postpositionalExcept = {'alawa', 'siwa', 'chhod', 'chhodkar'};

  Intent parse(String text, {DateTime? now}) {
    final t = Normaliser.normalise(text).tokens;
    if (t.isEmpty) return Intent.unknown(text);
    final used = List<bool>.filled(t.length, false);

    // 1. cancel timer: a cancel phrase, or "timer" plus a cancel verb anywhere
    //    ("cancel the geyser timer", "geyser ka timer hatao").
    final cancel = _findPhrase(t, _lex.actions[ActionKind.cancel]!);
    final timerAt = t.indexOf('timer');
    final cancelVerbAt = t.indexWhere(_cancelVerbs.contains);
    if (cancel != null || (timerAt >= 0 && cancelVerbAt >= 0)) {
      if (cancel != null) {
        _mark(used, cancel.$1, cancel.$2);
      }
      if (timerAt >= 0) {
        used[timerAt] = true;
      }
      if (cancelVerbAt >= 0) {
        used[cancelVerbAt] = true;
      }
      return _withTargets(text, t, used, Intent.cancelTimer);
    }

    // 2. status question
    final status = _findPhrase(t, _lex.actions[ActionKind.status]!);
    final isQuestion =
        t.first == 'is' ||
        t.first == 'status' ||
        t.first == 'check' ||
        t.last == 'kya';
    if (isQuestion || (status != null && status.$2 - status.$1 > 1)) {
      if (status != null) {
        _mark(used, status.$1, status.$2);
      }
      // drop trailing on/off words of the question ("is the geyser on")
      for (var i = 0; i < t.length; i++) {
        if (const {'on', 'off', 'chalu', 'band'}.contains(t[i])) used[i] = true;
      }
      return _withTargets(text, t, used, Intent.status);
    }

    // 3. action: on/off beat toggle when both appear ("switch the fan on")
    PowerAction? action;
    for (final kind in [ActionKind.on, ActionKind.off, ActionKind.toggle]) {
      final m = _findPhrase(t, _lex.actions[kind]!);
      if (m != null) {
        action = Lexicon.powerActionOf(kind);
        _mark(used, m.$1, m.$2);
        break;
      }
    }
    if (action == null) return Intent.unknown(text);

    // 4. duration / clock and their relation words
    final free = [for (var i = 0; i < t.length; i++) used[i] ? '' : t[i]];
    final d = _time.parseDuration(free);
    final c = d == null ? _time.parseClock(free, now ?? DateTime.now()) : null;
    Relation? rel;
    if (d != null) {
      _mark(used, d.start, d.end);
      rel = _relationAround(t, used, d.start, d.end, const [
        Relation.forDuration,
        Relation.after,
      ]);
    } else if (c != null) {
      _mark(used, c.start, c.end);
      rel = _relationAround(t, used, c.start, c.end, const [
        Relation.until,
        Relation.at,
      ]);
    }

    final a = action;
    return _withTargets(text, t, used, (s) {
      if (d != null) {
        return rel == Relation.after
            ? Intent.powerAfter(a, d.value, s)
            : Intent.powerFor(a, d.value, s);
      }
      if (c != null) {
        return rel == Relation.until
            ? Intent.powerUntil(a, c.value, s)
            : Intent.powerAt(a, c.value, s);
      }
      return Intent.power(a, s);
    });
  }

  /// Longest phrase occurrence; (start, end) or null.
  (int, int)? _findPhrase(List<String> t, List<Phrase> phrases) {
    for (final p in phrases) {
      for (var i = 0; i + p.length <= t.length; i++) {
        if (Lexicon.matchAt(t, i, p)) return (i, i + p.length);
      }
    }
    return null;
  }

  static void _mark(List<bool> used, int start, int end) {
    for (var i = start; i < end; i++) {
      used[i] = true;
    }
  }

  /// Relation words touching [start, end): "for 20 minute", "20 minute ke liye",
  /// "10 minute baad", "11 baje tak". Only adjacent words count (ambiguity rule: "in",
  /// "mein", "tak" elsewhere belong to the target).
  Relation? _relationAround(
    List<String> t,
    List<bool> used,
    int start,
    int end,
    List<Relation> allowed,
  ) {
    for (final r in allowed) {
      for (final p in _lex.relations[r]!) {
        // before the span
        final b = start - p.length;
        if (b >= 0 && Lexicon.matchAt(t, b, p)) {
          _mark(used, b, start);
          return r;
        }
        // after the span
        if (Lexicon.matchAt(t, end, p)) {
          _mark(used, end, end + p.length);
          return r;
        }
      }
    }
    // "baje" inside the clock span already means "at"
    return null;
  }

  Intent _withTargets(
    String text,
    List<String> t,
    List<bool> used,
    Intent Function(TargetSpan) build,
  ) {
    final rest = <String>[];
    for (var i = 0; i < t.length; i++) {
      if (!used[i]) rest.add(t[i]);
    }
    final span = _targetSpan(rest);
    if (!span.all && span.words.isEmpty) {
      return const Intent.unknown(whichDevice);
    }
    return build(span);
  }

  TargetSpan _targetSpan(List<String> tokens) {
    var all = false;
    final words = <String>[];
    final except = <String>[];
    var i = 0;
    var exceptMode = false;
    while (i < tokens.length) {
      final quant = _matchAny(tokens, i, _lex.all);
      if (quant > 0) {
        all = true;
        i += quant;
        continue;
      }
      final ex = _matchAny(tokens, i, _lex.except);
      if (ex > 0) {
        final phrase = tokens.sublist(i, i + ex);
        if (phrase.any(_postpositionalExcept.contains)) {
          // "bedroom ke alawa": the word just before is the exception.
          if (words.isNotEmpty) except.add(words.removeLast());
        } else {
          exceptMode = true; // "except bedroom"
        }
        i += ex;
        continue;
      }
      final noun = _lex.nounAt(tokens, i);
      String word;
      int len;
      if (noun != null) {
        final spoken = tokens.sublist(i, i + noun.$2).join(' ');
        if (_isPlural(spoken)) all = true;
        word = noun.$1;
        len = noun.$2;
      } else {
        word = tokens[i];
        len = 1;
      }
      i += len;
      if (_lex.particles.contains(word) || _verbResidue.contains(word)) {
        continue;
      }
      if (_lex.relations.values.any(
            (ps) => ps.any((p) => p.length == 1 && p.first == word),
          ) &&
          !exceptMode) {
        // A relation word not attached to a time ("lights in bedroom") carries no
        // target meaning; the room word after it is kept.
        continue;
      }
      (exceptMode ? except : words).add(word);
    }
    return TargetSpan(words: words, all: all, except: except);
  }

  static const _plurals = {
    'lights',
    'bulbs',
    'lamps',
    'fans',
    'battiyan',
    'pankhe',
    'lightein',
    'lighten',
    'plugs',
    'sockets',
  };

  static bool _isPlural(String spoken) => _plurals.contains(spoken);

  static int _matchAny(List<String> t, int i, List<Phrase> phrases) {
    for (final p in phrases) {
      if (Lexicon.matchAt(t, i, p)) return p.length;
    }
    return 0;
  }
}
