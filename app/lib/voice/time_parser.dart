import '../core/intent.dart';
import 'lexicon.dart';

/// A parsed span of tokens: [start, end).
class Span<T> {
  const Span(this.value, this.start, this.end);
  final T value;
  final int start;
  final int end;
  @override
  String toString() => 'Span($value, $start..$end)';
}

/// Durations and clock times from normalised tokens (PSEUDOCODE §11.4).
class TimeParser {
  TimeParser(this._lex);

  final Lexicon _lex;

  static double? _num(String? s) => s == null ? null : double.tryParse(s);

  /// First duration in [t]: `n unit`, `h hour m (minute)?`, fractions ("1.5 ghanta").
  Span<Duration>? parseDuration(List<String> t) {
    for (var i = 0; i < t.length; i++) {
      final n = _num(t[i]);
      if (n == null || i + 1 >= t.length) continue;
      final unit = _lex.unitOf(t[i + 1]);
      if (unit == null) continue;
      var d = _dur(n, unit);
      var end = i + 2;
      // "<h> hour <m> minute" or "<h> hour <m>" (for 1 hour 15)
      if (unit == 'hour' && end < t.length) {
        final m = _num(t[end]);
        if (m != null && m < 60 && m == m.roundToDouble()) {
          final hasMinuteWord =
              end + 1 < t.length && _lex.unitOf(t[end + 1]) == 'minute';
          final nextIsOtherUnit =
              end + 1 < t.length &&
              _lex.unitOf(t[end + 1]) != null &&
              !hasMinuteWord;
          if (!nextIsOtherUnit) {
            d += Duration(minutes: m.toInt());
            end += hasMinuteWord ? 2 : 1;
          }
        }
      }
      if (d > Duration.zero) return Span(d, i, end);
    }
    return null;
  }

  static Duration _dur(double n, String unit) => switch (unit) {
    'hour' => Duration(seconds: (n * 3600).round()),
    'minute' => Duration(seconds: (n * 60).round()),
    _ => Duration(seconds: n.round()),
  };

  static final _hhmm = RegExp(r'^(\d{1,2}):(\d{2})$');

  /// First clock time in [t]; [now] resolves 12-hour times without a daypart to the next
  /// future occurrence. Returns null for ambiguous/invalid ones ("subah 12").
  Span<ClockTime>? parseClock(List<String> t, DateTime now) {
    for (var i = 0; i < t.length; i++) {
      int? hour;
      var minute = 0;
      var end = i + 1;
      final m = _hhmm.firstMatch(t[i]);
      final n = _num(t[i]);
      final next = i + 1 < t.length ? t[i + 1] : null;
      final prev = i > 0 ? t[i - 1] : null;
      final nextIsBaje = next == 'baje';
      final nextIsMeridiem = next == 'am' || next == 'pm';
      final prevIsAt = prev == 'at';
      if (m != null) {
        hour = int.parse(m[1]!);
        minute = int.parse(m[2]!);
      } else if (n != null && (nextIsBaje || nextIsMeridiem || prevIsAt)) {
        // "10.5 baje" (saadhe das) → 10:30; "9.25" → 9:15; "10.75" → 10:45.
        final whole = n.floor();
        final frac = n - whole;
        if (frac != 0 && frac != 0.25 && frac != 0.5 && frac != 0.75) continue;
        hour = whole;
        minute = (frac * 60).round();
      } else {
        continue;
      }
      if (nextIsBaje) end = i + 2;
      if (hour > 23 || minute > 59) continue;

      // Meridiem: "11 pm", "11:30 pm", or a daypart before/after ("raat 11 baje").
      Meridiem? mer;
      String? daypart;
      if (end < t.length && (t[end] == 'am' || t[end] == 'pm')) {
        mer = t[end] == 'am' ? Meridiem.am : Meridiem.pm;
        end++;
      }
      if (mer == null && prev != null && _lex.dayparts.containsKey(prev)) {
        daypart = prev;
      } else if (mer == null &&
          end < t.length &&
          _lex.dayparts.containsKey(t[end])) {
        daypart = t[end];
        end++;
      } else if (mer == null &&
          end + 1 < t.length &&
          (t[end] == 'in' || t[end] == 'at') &&
          _lex.dayparts.containsKey(t[end + 1])) {
        // "6:30 in the morning", "11 at night"
        daypart = t[end + 1];
        end += 2;
      }
      final start = daypart != null && prev == daypart
          ? i - 1
          : (prevIsAt ? i - 1 : i);
      final resolved = _resolve(hour, minute, mer, daypart, now);
      if (resolved == null) return null;
      return Span(resolved, start, end);
    }
    return null;
  }

  ClockTime? _resolve(
    int h,
    int m,
    Meridiem? mer,
    String? daypart,
    DateTime now,
  ) {
    if (h > 12 || (h == 0)) return ClockTime(h % 24, m); // already 24-hour
    if (mer != null) {
      final hh = mer == Meridiem.am ? h % 12 : (h % 12) + 12;
      return ClockTime(hh, m);
    }
    if (daypart != null) {
      switch (daypart) {
        case 'raat' || 'night' || 'tonight':
          if (h == 12) return ClockTime(0, m); // raat 12 baje = midnight
          if (h <= 4) return ClockTime(h, m); // raat 1–4 → early morning
          return ClockTime(h + 12, m);
        case 'subah' || 'morning':
          if (h == 12) return null; // ambiguous: ask
          return ClockTime(h, m);
        case 'dopahar' || 'afternoon':
          return ClockTime(h == 12 ? 12 : (h < 5 ? h + 12 : h), m);
        default:
          final pm = _lex.dayparts[daypart] == Meridiem.pm;
          return ClockTime(pm ? (h % 12) + 12 : h % 12, m);
      }
    }
    // No daypart: the next future occurrence within 12 hours.
    final a = ClockTime(h % 12, m);
    final b = ClockTime((h % 12) + 12, m);
    Duration until(ClockTime c) {
      var d = DateTime(
        now.year,
        now.month,
        now.day,
        c.hour,
        c.minute,
      ).difference(now);
      if (d <= Duration.zero) d += const Duration(days: 1);
      return d;
    }

    return until(a) <= until(b) ? a : b;
  }
}
