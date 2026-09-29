import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../net/ios_platform_bridge.dart';
import '../net/platform_bridge.dart';
import '../timers/android_alarm_scheduler.dart';
import '../timers/timer_service.dart';
import '../voice/stt_service.dart';

enum PermissionKind { localNetwork, microphone, notifications, exactAlarms }

enum PermissionStatus { granted, denied, unknown, notNeeded }

/// First-run permission checks (T5.8, PLAN §9 step 1). Each request shows the system
/// prompt where the platform has one.
abstract interface class PermissionsService {
  List<PermissionKind> get needed;
  Future<PermissionStatus> request(PermissionKind kind);
}

class PlatformPermissions implements PermissionsService {
  PlatformPermissions(this._platform, this._stt, this._alarms);

  final PlatformBridge _platform;
  final SttService? _stt;
  final PhoneAlarmScheduler _alarms;
  final _notifications = FlutterLocalNotificationsPlugin();

  @override
  List<PermissionKind> get needed => [
    if (Platform.isIOS) PermissionKind.localNetwork,
    PermissionKind.microphone,
    PermissionKind.notifications,
    if (Platform.isAndroid) PermissionKind.exactAlarms,
  ];

  @override
  Future<PermissionStatus> request(PermissionKind kind) async {
    switch (kind) {
      case PermissionKind.localNetwork:
        final p = _platform;
        if (p is! IosPlatformBridge) return PermissionStatus.notNeeded;
        return switch (await p.requestLocalNetworkPermission()) {
          LocalNetworkPermission.granted => PermissionStatus.granted,
          LocalNetworkPermission.denied => PermissionStatus.denied,
          LocalNetworkPermission.unknown => PermissionStatus.unknown,
        };
      case PermissionKind.microphone:
        // speech_to_text's initialize() asks for microphone + speech recognition.
        final caps = await _stt?.capabilities();
        return caps?.available == true
            ? PermissionStatus.granted
            : PermissionStatus.denied;
      case PermissionKind.notifications:
        bool? ok;
        if (Platform.isIOS) {
          ok = await _notifications
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true);
        } else if (Platform.isAndroid) {
          ok = await _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission();
        }
        return ok == null
            ? PermissionStatus.unknown
            : ok
            ? PermissionStatus.granted
            : PermissionStatus.denied;
      case PermissionKind.exactAlarms:
        final a = _alarms;
        if (a is! AndroidPhoneAlarmScheduler) return PermissionStatus.notNeeded;
        if (await a.canScheduleExact()) return PermissionStatus.granted;
        await a.openExactAlarmSettings();
        return await a.canScheduleExact()
            ? PermissionStatus.granted
            : PermissionStatus.denied;
    }
  }
}
