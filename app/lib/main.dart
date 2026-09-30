import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/services.dart';
import 'core/perf.dart';
import 'timers/alarm_runner.dart';
import 'ui/app.dart';
import 'ui/providers.dart';

Future<void> main() async {
  Perf.markAppStart();
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.create();
  runApp(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const OfflineHomeApp(),
    ),
  );
}

/// Background entry point started by TimerForegroundService.kt when a phone-tier timer
/// alarm fires (T3.4b/c). Runs the queued jobs, then lets the service stop.
@pragma('vm:entry-point')
Future<void> timerAlarmMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.create();
  try {
    await drainAlarms(MethodChannelAlarmRunnerHost(), services.timerService);
  } finally {
    await services.dispose();
  }
}
