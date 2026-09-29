import 'package:flutter/services.dart';

import '../core/log.dart';
import 'timer_service.dart';

/// Dart side of the Kotlin AlarmsPlugin (T3.4a): exact alarms that start
/// TimerForegroundService, which runs [TimerService.onAlarm] in a background engine.
class AndroidPhoneAlarmScheduler implements PhoneAlarmScheduler {
  AndroidPhoneAlarmScheduler([
    this._channel = const MethodChannel('offline_home/alarms'),
  ]);

  final MethodChannel _channel;

  /// False when the user has not allowed exact alarms (Android 12+): timers still fire,
  /// but the OS may delay them. The UI should explain and offer [openExactAlarmSettings].
  bool lastScheduleWasExact = true;

  @override
  Future<void> schedule(String jobId, DateTime fireAt) async {
    final exact = await _channel.invokeMethod<bool>('schedule', {
      'jobId': jobId,
      'fireAtMs': fireAt.millisecondsSinceEpoch,
    });
    lastScheduleWasExact = exact ?? false;
    if (!lastScheduleWasExact) {
      log.w('timers', 'exact alarms not allowed; $jobId may fire late');
    }
  }

  @override
  Future<void> cancel(String jobId) =>
      _channel.invokeMethod<void>('cancel', {'jobId': jobId});

  Future<bool> canScheduleExact() async =>
      await _channel.invokeMethod<bool>('canScheduleExact') ?? false;

  Future<void> openExactAlarmSettings() =>
      _channel.invokeMethod<void>('openExactAlarmSettings');
}
