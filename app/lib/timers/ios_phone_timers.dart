import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'timer_service.dart';

/// Schedules/cancels one local notification per phone-tier job.
abstract interface class LocalNotifier {
  Future<void> schedule(int id, DateTime at, String title, String body);
  Future<void> cancel(int id);
}

/// iOS phone tier (T3.5): iOS cannot run our code at a set time, so the job runs from
/// [PhoneTierTicker] while the app is open, and a local notification at fire time asks
/// the user to open the app. Nothing leaves the device.
class IosPhoneTimers implements PhoneAlarmScheduler {
  IosPhoneTimers(this._notifier, this._describe);

  final LocalNotifier _notifier;

  /// e.g. "Geyser off" for a job id (reads the stored job + device name).
  final Future<String> Function(String jobId) _describe;

  /// Stable notification id for a job id.
  static int idFor(String jobId) => jobId.hashCode & 0x7fffffff;

  @override
  Future<void> schedule(String jobId, DateTime fireAt) async {
    final what = await _describe(jobId);
    await _notifier.schedule(
      idFor(jobId),
      fireAt,
      'Timer due: $what',
      'Open Offline Home to run it (iPhone cannot switch devices in the background).',
    );
  }

  @override
  Future<void> cancel(String jobId) => _notifier.cancel(idFor(jobId));
}

/// flutter_local_notifications-backed notifier. Permission is requested during
/// onboarding (T5.8); without it the notification is simply not shown.
class PluginLocalNotifier implements LocalNotifier {
  PluginLocalNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  @override
  Future<void> schedule(int id, DateTime at, String title, String body) async {
    await _init();
    await _plugin.zonedSchedule(
      id: id,
      // An absolute instant: UTC avoids needing the timezone database.
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        android: AndroidNotificationDetails('timers', 'Timers'),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _init();
    await _plugin.cancel(id: id);
  }
}
