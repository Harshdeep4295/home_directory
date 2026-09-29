import 'package:flutter/services.dart';

import '../core/log.dart';
import 'timer_service.dart';

/// Protocol with TimerForegroundService (`offline_home/alarm_runner`, T3.4b/c):
/// "next" → job id or null, "finished"(id), "done".
abstract interface class AlarmRunnerHost {
  Future<String?> next();
  Future<void> finished(String jobId);
  Future<void> done();
}

class MethodChannelAlarmRunnerHost implements AlarmRunnerHost {
  MethodChannelAlarmRunnerHost([
    this._channel = const MethodChannel('offline_home/alarm_runner'),
  ]);

  final MethodChannel _channel;

  @override
  Future<String?> next() => _channel.invokeMethod<String>('next');
  @override
  Future<void> finished(String jobId) =>
      _channel.invokeMethod<void>('finished', jobId);
  @override
  Future<void> done() => _channel.invokeMethod<void>('done');
}

/// Runs every queued phone-tier job, then tells the host it may stop. Never throws: a
/// failing job is marked failed by [TimerService.onAlarm] and the next one still runs.
Future<int> drainAlarms(AlarmRunnerHost host, TimerService timers) async {
  var ran = 0;
  try {
    for (var id = await host.next(); id != null; id = await host.next()) {
      try {
        await timers.onAlarm(id);
      } on Object catch (e, st) {
        log.e('alarm', 'job $id crashed', e, st);
      }
      await host.finished(id);
      ran++;
    }
  } finally {
    await host.done();
  }
  return ran;
}
