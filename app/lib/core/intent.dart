import 'package:freezed_annotation/freezed_annotation.dart';

import 'json.dart';

part 'intent.freezed.dart';
part 'intent.g.dart';

enum PowerAction { on, off, toggle }

/// A wall-clock time without a date ("11 baje" → 23:00 after daypart resolution).
@freezed
abstract class ClockTime with _$ClockTime {
  @Assert('hour >= 0 && hour < 24', 'hour out of range')
  @Assert('minute >= 0 && minute < 60', 'minute out of range')
  const factory ClockTime(int hour, [@Default(0) int minute]) = _ClockTime;

  factory ClockTime.fromJson(Map<String, dynamic> json) =>
      _$ClockTimeFromJson(json);
}

/// What the user referred to, before resolution against the registry. PSEUDOCODE §2.
@freezed
abstract class TargetSpan with _$TargetSpan {
  const factory TargetSpan({
    @Default(<String>[]) List<String> words,
    @Default(false) bool all,
    String? room,
    @Default(<String>[]) List<String> except,
  }) = _TargetSpan;

  factory TargetSpan.fromJson(Map<String, dynamic> json) =>
      _$TargetSpanFromJson(json);
}

/// Parsed voice command. PSEUDOCODE §11.5.
@Freezed(unionKey: 'type')
sealed class Intent with _$Intent {
  const factory Intent.power(PowerAction action, TargetSpan targets) =
      PowerIntent;

  /// Set [action] now; flip back after [duration].
  @DurationSecondsConverter()
  const factory Intent.powerFor(
    PowerAction action,
    Duration duration,
    TargetSpan targets,
  ) = PowerForIntent;

  /// Apply [action] after [duration].
  @DurationSecondsConverter()
  const factory Intent.powerAfter(
    PowerAction action,
    Duration duration,
    TargetSpan targets,
  ) = PowerAfterIntent;

  /// Apply [action] at [clock].
  const factory Intent.powerAt(
    PowerAction action,
    ClockTime clock,
    TargetSpan targets,
  ) = PowerAtIntent;

  /// Set [action] now; flip back at [clock].
  const factory Intent.powerUntil(
    PowerAction action,
    ClockTime clock,
    TargetSpan targets,
  ) = PowerUntilIntent;

  const factory Intent.cancelTimer(TargetSpan targets) = CancelTimerIntent;

  const factory Intent.status(TargetSpan targets) = StatusIntent;

  const factory Intent.unknown(String text) = UnknownIntent;

  factory Intent.fromJson(Map<String, dynamic> json) => _$IntentFromJson(json);
}
