import '../core/models.dart';

/// User-facing wording for where a timer runs (CLAUDE.md rule 4: always say which tier).
abstract final class TierCopy {
  /// Short badge for tiles and the Timers screen.
  static String badge(TimerTier tier, Brand brand) => switch (tier) {
    TimerTier.native => brand == Brand.hue ? 'Bridge' : 'Plug',
    TimerTier.phone => 'Phone',
  };

  /// Suffix for voice/toast feedback: "Geyser on. Off at 9:40 (plug timer)."
  static String feedbackSuffix(TimerTier tier, {required bool isIOS}) =>
      switch (tier) {
        TimerTier.native => '(plug timer)',
        TimerTier.phone when isIOS => '(phone timer — keep the app open)',
        TimerTier.phone => '(phone timer)',
      };

  /// Shown when a timer lands on the phone tier on iPhone (PLAN §8, D4).
  static const iosPhoneWarning =
      'This device has no built-in timer, and an iPhone cannot switch devices in the '
      'background. Keep Offline Home open on your home Wi-Fi until the timer ends; you '
      'will get a notification at the time to open it.';

  /// Shown when Android could not get exact-alarm permission.
  static const androidInexactWarning =
      'Exact alarms are off for Offline Home, so this timer may run a few minutes late. '
      'Allow "Alarms & reminders" in settings to fix it.';
}
