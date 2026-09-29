/// Turns a raw STT transcript (English, Hinglish in Latin script, or Devanagari) into
/// clean tokens for the IntentParser (PSEUDOCODE §11.2, incl. the ambiguity rules).
///
/// Pipeline: lowercase → Devanagari → Latin → punctuation → phrase variants → verb+"do"
/// → article numbers ("an hour") → fillers → number words → fractions.
library;

class Normalised {
  const Normalised(this.tokens);
  final List<String> tokens;
  String get text => tokens.join(' ');
  @override
  String toString() => text;
}

abstract final class Normaliser {
  static Normalised normalise(String input) {
    var s = input.toLowerCase().trim();
    s = transliterateDevanagari(s);
    s = _punctuation(s);
    var t = _split(s);
    t = _phrases(t);
    t = _ofOff(t);
    t = _verbDo(t);
    t = _articleNumbers(t);
    t = t.where((w) => !fillers.contains(w)).toList();
    t = _numbers(t);
    t = _fractions(t);
    return Normalised(t);
  }

  // ------------------------------------------------------------------ Devanagari

  /// Whole-word table first (common command words), then a letter-level fallback.
  static const devanagariWords = {
    'बंद': 'band',
    'बन्द': 'band',
    'चालू': 'chalu',
    'चालु': 'chalu',
    'करो': 'karo',
    'कर': 'kar',
    'कीजिए': 'kijiye',
    'दो': 'do',
    'लाइट': 'light',
    'बत्ती': 'batti',
    'बत्तियां': 'battiyan',
    'बत्तियाँ': 'battiyan',
    'पंखा': 'pankha',
    'पंखे': 'pankhe',
    'गीज़र': 'geyser',
    'गीजर': 'geyser',
    'एसी': 'ac',
    'टीवी': 'tv',
    'मिनट': 'minute',
    'घंटा': 'ghanta',
    'घंटे': 'ghante',
    'सेकंड': 'second',
    'बजे': 'baje',
    'के': 'ke',
    'का': 'ka',
    'की': 'ki',
    'लिए': 'liye',
    'बाद': 'baad',
    'में': 'mein',
    'तक': 'tak',
    'सब': 'sab',
    'सारी': 'saari',
    'सारे': 'saare',
    'सभी': 'sabhi',
    'अलावा': 'alawa',
    'छोड़': 'chhod',
    'छोड़कर': 'chhodkar',
    'टाइमर': 'timer',
    'हटाओ': 'hatao',
    'रात': 'raat',
    'सुबह': 'subah',
    'शाम': 'shaam',
    'दोपहर': 'dopahar',
    'जलाओ': 'jalao',
    'बुझाओ': 'bujhao',
    'चलाओ': 'chalao',
    'रोको': 'roko',
    'है': 'hai',
    'क्या': 'kya',
    'आधा': 'aadha',
    'आधे': 'aadhe',
    'डेढ़': 'dedh',
    'ढाई': 'dhai',
    'सवा': 'sava',
    'साढ़े': 'saadhe',
    'पौने': 'paune',
    'बेडरूम': 'bedroom',
    'किचन': 'kitchen',
    'हॉल': 'hall',
    'कमरा': 'kamra',
    'कमरे': 'kamre',
    'एक': 'ek',
    'तीन': 'teen',
    'चार': 'char',
    'पांच': 'paanch',
    'पाँच': 'paanch',
    'छह': 'chhe',
    'सात': 'saat',
    'आठ': 'aath',
    'नौ': 'nau',
    'दस': 'das',
    'ग्यारह': 'gyarah',
    'बारह': 'barah',
    'पंद्रह': 'pandrah',
    'बीस': 'bees',
    'पच्चीस': 'pachchees',
    'तीस': 'tees',
    'चालीस': 'chalees',
    'पैंतालीस': 'paintalees',
    'पचास': 'pachaas',
    'साठ': 'saath',
    'सौ': 'sau',
    'ऑन': 'on',
    'ऑफ': 'off',
    'ऑफ़': 'off',
    'प्लीज़': 'please',
    'ज़रा': 'zara',
  };

  static const _consonants = {
    'क': 'k',
    'ख': 'kh',
    'ग': 'g',
    'घ': 'gh',
    'च': 'ch',
    'छ': 'chh',
    'ज': 'j',
    'झ': 'jh',
    'ट': 't',
    'ठ': 'th',
    'ड': 'd',
    'ढ': 'dh',
    'ण': 'n',
    'त': 't',
    'थ': 'th',
    'द': 'd',
    'ध': 'dh',
    'न': 'n',
    'प': 'p',
    'फ': 'ph',
    'ब': 'b',
    'भ': 'bh',
    'म': 'm',
    'य': 'y',
    'र': 'r',
    'ल': 'l',
    'व': 'v',
    'श': 'sh',
    'ष': 'sh',
    'स': 's',
    'ह': 'h',
    'ज़': 'z',
    'फ़': 'f',
    'ड़': 'd',
    'ढ़': 'dh',
  };
  static const _vowels = {
    'अ': 'a',
    'आ': 'aa',
    'इ': 'i',
    'ई': 'ee',
    'उ': 'u',
    'ऊ': 'oo',
    'ए': 'e',
    'ऐ': 'ai',
    'ओ': 'o',
    'औ': 'au',
    'ऑ': 'o',
  };
  static const _signs = {
    'ा': 'aa',
    'ि': 'i',
    'ी': 'ee',
    'ु': 'u',
    'ू': 'oo',
    'े': 'e',
    'ै': 'ai',
    'ो': 'o',
    'ौ': 'au',
    'ॉ': 'o',
    'ं': 'n',
    'ँ': 'n',
    '्': '',
    '़': '',
  };
  static const _digits = '०१२३४५६७८९';

  static String transliterateDevanagari(String s) {
    if (!RegExp('[ऀ-ॿ]').hasMatch(s)) return s;
    return s
        .split(RegExp(r'(\s+)'))
        .map((w) {
          final bare = w.replaceAll(RegExp(r'[।,.?!]'), '');
          final known = devanagariWords[bare];
          if (known != null) return known;
          return _letters(w);
        })
        .join(' ');
  }

  static String _letters(String w) {
    final out = StringBuffer();
    final chars = w.runes.map(String.fromCharCode).toList();
    for (var i = 0; i < chars.length; i++) {
      var c = chars[i];
      // nukta forms
      if (i + 1 < chars.length && chars[i + 1] == '़') c = '$c़';
      final digit = _digits.indexOf(c);
      if (digit >= 0) {
        out.write(digit);
      } else if (_consonants[c] case final cons?) {
        out.write(cons);
        final next = i + 1 < chars.length ? chars[i + 1] : null;
        final nextIsSign =
            next != null &&
            _signs.containsKey(next) &&
            next != 'ं' &&
            next != 'ँ';
        final atEnd = next == null || !RegExp('[ऀ-ॿ]').hasMatch(next);
        // inherent 'a' except before a vowel sign or at word end (schwa deletion)
        if (!nextIsSign && !atEnd) out.write('a');
      } else if (_vowels[c] case final v?) {
        out.write(v);
      } else if (_signs[c] case final sign?) {
        out.write(sign);
      } else if (c != '़') {
        out.write(c);
      }
    }
    return out.toString();
  }

  // ------------------------------------------------------------------ cleanup

  static String _punctuation(String s) {
    s = s.replaceAll(RegExp(r'\ba\.?\s?c\.?(?=\s|$)'), 'ac');
    // keep ':' only inside clock times like 11:30
    s = s.replaceAllMapped(
      RegExp(r'(\d{1,2}):(\d{2})'),
      (m) => '${m[1]}§${m[2]}',
    );
    s = s.replaceAll(RegExp(r"[^\w\s§.']|_"), ' ');
    s = s.replaceAll(
      RegExp(r'(?<!\d)\.|\.(?!\d)'),
      ' ',
    ); // dots except decimals
    s = s.replaceAll("'", '');
    return s.replaceAll('§', ':');
  }

  static List<String> _split(String s) =>
      s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  /// Spelling variants (single words) and multi-word phrases → canonical form.
  static const wordVariants = {
    'bandh': 'band',
    'bundh': 'band',
    'bund': 'band',
    'bnd': 'band',
    'chaalu': 'chalu',
    'chaloo': 'chalu',
    'challu': 'chalu',
    'chalo': 'chalu',
    'kardo': 'karo',
    'krdo': 'karo',
    'kro': 'karo',
    'kardijiye': 'karo',
    'kijiye': 'karo',
    'minit': 'minute',
    'mint': 'minute',
    'minat': 'minute',
    'minutes': 'minute',
    'min': 'minute',
    'mins': 'minute',
    'mnt': 'minute',
    'ghante': 'ghanta',
    'ghanton': 'ghanta',
    'ghanta': 'ghanta',
    'ghnta': 'ghanta',
    'hours': 'hour',
    'hrs': 'hour',
    'hr': 'hour',
    'seconds': 'second',
    'sec': 'second',
    'secs': 'second',
    'sekand': 'second',
    'geezer': 'geyser',
    'gizer': 'geyser',
    'geysor': 'geyser',
    'gyser': 'geyser',
    'geyzer': 'geyser',
    'gijar': 'geyser',
    'geesar': 'geyser',
    'batti': 'batti',
    'bati': 'batti',
    'batiyan': 'battiyan',
    'battiya': 'battiyan',
    'lite': 'light',
    'lites': 'lights',
    'pankhaa': 'pankha',
    'fen': 'fan',
    'bajey': 'baje',
    'baaje': 'baje',
    'bje': 'baje',
    'lie': 'liye',
    'liyae': 'liye',
    'baad': 'baad',
    'bad': 'baad',
    'mai': 'mein',
    'me': 'mein',
    'main': 'mein',
    'aadhe': 'aadha',
    'adha': 'aadha',
    'adhe': 'aadha',
    'derh': 'dedh',
    'dhaai': 'dhai',
    'arhai': 'dhai',
    'dhaiee': 'dhai',
    'sadhe': 'saadhe',
    'saade': 'saadhe',
    'sawa': 'sava',
    'pone': 'paune',
    'paone': 'paune',
    'swich': 'switch',
    'turnoff': 'turn off',
    'turnon': 'turn on',
    'switchoff': 'switch off',
    'switchon': 'switch on',
    'tv': 'tv',
    'a/c': 'ac',
    'aircon': 'ac',
  };

  static const phraseVariants = [
    (['kar', 'do'], ['karo']),
    (['kar', 'dijiye'], ['karo']),
    (['kar', 'dena'], ['karo']),
    (['kar', 'de'], ['karo']),
    (['a', 'c'], ['ac']),
    (['water', 'heater'], ['geyser']),
    (['half', 'an', 'hour'], ['0.5', 'hour']),
    (['half', 'hour'], ['0.5', 'hour']),
    (['quarter', 'hour'], ['0.25', 'hour']),
    (['quarter', 'of', 'an', 'hour'], ['0.25', 'hour']),
  ];

  static List<String> _phrases(List<String> t) {
    final words = [for (final w in t) ...(wordVariants[w] ?? w).split(' ')];
    final out = <String>[];
    var i = 0;
    outer:
    while (i < words.length) {
      for (final (from, to) in phraseVariants) {
        if (i + from.length <= words.length) {
          var match = true;
          for (var k = 0; k < from.length; k++) {
            if (words[i + k] != from[k]) {
              match = false;
              break;
            }
          }
          if (match) {
            out.addAll(to);
            i += from.length;
            continue outer;
          }
        }
      }
      out.add(words[i++]);
    }
    return out;
  }

  /// Recognisers often write "of" for "off": "turn of the fan", "fan of in 5 mins".
  /// "of" becomes "off" after turn/switch/power/shut, at the end of the command, or
  /// before a time relation; "status of the geyser" is left alone.
  static List<String> _ofOff(List<String> t) => [
    for (var i = 0; i < t.length; i++)
      t[i] == 'of' &&
              ((i > 0 &&
                      const {
                        'turn',
                        'switch',
                        'power',
                        'shut',
                      }.contains(t[i - 1])) ||
                  i == t.length - 1 ||
                  const {'in', 'after', 'at', 'for'}.contains(t[i + 1]))
          ? 'off'
          : t[i],
  ];

  /// Verb stems that take "do" as an auxiliary ("jala do" = light it).
  static const verbStems = {
    'jala': 'jalao',
    'bujha': 'bujhao',
    'chala': 'chalao',
    'rok': 'roko',
    'hata': 'hatao',
    'laga': 'lagao',
    'band': 'band',
    'chalu': 'chalu',
    'on': 'on',
    'off': 'off',
    'bata': 'batao',
    'de': 'de',
    'khol': 'kholo',
  };

  static const units = {'minute', 'ghanta', 'hour', 'second', 'baje'};

  /// `<stem> do` → merged verb; "do" stays the number 2 only before a unit.
  static List<String> _verbDo(List<String> t) {
    final out = <String>[];
    for (var i = 0; i < t.length; i++) {
      final w = t[i];
      final next = i + 1 < t.length ? t[i + 1] : null;
      if (w == 'do' && out.isNotEmpty && !units.contains(next)) {
        final prev = out.last;
        if (verbStems.containsKey(prev)) {
          out[out.length - 1] = verbStems[prev]!;
          continue;
        }
      }
      out.add(w);
    }
    return out;
  }

  /// "an hour" / "a minute" → "1 hour" (before the articles are dropped as fillers).
  static List<String> _articleNumbers(List<String> t) {
    final out = <String>[];
    for (var i = 0; i < t.length; i++) {
      final next = i + 1 < t.length ? t[i + 1] : null;
      if ((t[i] == 'a' || t[i] == 'an') && units.contains(next)) {
        out.add('1');
      } else {
        out.add(t[i]);
      }
    }
    return out;
  }

  static const fillers = {
    'please',
    'pls',
    'plz',
    'zara',
    'na',
    'yaar',
    'ji',
    'jaldi',
    'hey',
    'ok',
    'okay',
    'the',
    'a',
    'an',
    'bhai',
    'bhaiya',
    'bhi',
    'kindly',
    'just',
    'can',
    'you',
    'could',
    'would',
    'will',
    'my',
  };

  // ------------------------------------------------------------------ numbers

  static const _en = {
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
  };
  static const _enTens = {
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
  };

  /// Hindi number words (Latin spellings seen in STT output). "do" and "saath" are
  /// handled with context below.
  static const hindiNumbers = {
    'ek': 1,
    'teen': 3,
    'char': 4,
    'chaar': 4,
    'paanch': 5,
    'panch': 5,
    'chhe': 6,
    'chhah': 6,
    'che': 6,
    'saat': 7,
    'aath': 8,
    'nau': 9,
    'das': 10,
    'gyarah': 11,
    'gyara': 11,
    'barah': 12,
    'bara': 12,
    'terah': 13,
    'chaudah': 14,
    'chaudha': 14,
    'pandrah': 15,
    'pandra': 15,
    'solah': 16,
    'sola': 16,
    'satrah': 17,
    'atharah': 18,
    'athara': 18,
    'unnis': 19,
    'bees': 20,
    'ikkees': 21,
    'bais': 22,
    'teis': 23,
    'chaubees': 24,
    'pachchees': 25,
    'pachees': 25,
    'chhabbees': 26,
    'sattaees': 27,
    'atthaees': 28,
    'untees': 29,
    'tees': 30,
    'paintees': 35,
    'chalees': 40,
    'chaalis': 40,
    'chalis': 40,
    'paintalees': 45,
    'paintalis': 45,
    'pachaas': 50,
    'pachas': 50,
    'sattar': 70,
    'assi': 80,
    'nabbe': 90,
    'sau': 100,
  };

  static List<String> _numbers(List<String> t) {
    final out = <String>[];
    for (var i = 0; i < t.length; i++) {
      final w = t[i];
      final next = i + 1 < t.length ? t[i + 1] : null;
      final nextIsUnit = units.contains(next);
      if (w == 'do') {
        // 2 before a unit or after a relation word ("baad do"?), else a verb leftover.
        if (nextIsUnit) out.add('2');
        continue;
      }
      if (w == 'saath') {
        // "saath minute" → 60; otherwise it means "with" and is dropped.
        if (nextIsUnit) out.add('60');
        continue;
      }
      if (w == 'hundred' && out.isNotEmpty && int.tryParse(out.last) != null) {
        out[out.length - 1] = '${int.parse(out.last) * 100}';
        continue;
      }
      final tens = _enTens[w];
      if (tens != null) {
        final unit = next == null ? null : _en[next];
        if (unit != null && unit < 10) {
          out.add('${tens + unit}');
          i++;
        } else {
          out.add('$tens');
        }
        continue;
      }
      final n = _en[w] ?? hindiNumbers[w] ?? (w == 'hundred' ? 100 : null);
      out.add(n == null ? w : '$n');
    }
    return out;
  }

  static const _fractionWords = {'aadha': 0.5, 'dedh': 1.5, 'dhai': 2.5};
  static const _modifiers = {'sava': 0.25, 'saadhe': 0.5, 'paune': -0.25};

  static String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  static List<String> _fractions(List<String> t) {
    final out = <String>[];
    for (var i = 0; i < t.length; i++) {
      final w = t[i];
      final frac = _fractionWords[w];
      if (frac != null) {
        out.add(_fmt(frac));
        continue;
      }
      final mod = _modifiers[w];
      final next = i + 1 < t.length ? double.tryParse(t[i + 1]) : null;
      if (mod != null && next != null) {
        out.add(_fmt(next + mod));
        i++;
        continue;
      }
      if (w == 'half' || w == 'aadha') {
        out.add('0.5');
        continue;
      }
      out.add(w);
    }
    return out;
  }
}
