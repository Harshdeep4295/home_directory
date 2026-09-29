import 'dart:async';

import '../adapters/device_adapter.dart';
import '../core/intent.dart';
import '../core/log.dart';
import '../core/models.dart';
import '../core/result.dart';
import '../engine/command_engine.dart';
import '../registry/repositories.dart';

/// Phone-tier timer backend: Android exact alarms (T3.4), iOS notification + foreground
/// ticker (T3.5). Tests use a fake.
abstract interface class PhoneAlarmScheduler {
  Future<void> schedule(String jobId, DateTime fireAt);
  Future<void> cancel(String jobId);
}

/// What happened for one device.
class TimerOutcome {
  const TimerOutcome(this.device, this.result);
  final Device device;

  /// The scheduled job (its [TimerJob.tier] says where it runs), or why it failed.
  final Result<TimerJob> result;
}

/// Device-native timers first, phone fallback (CLAUDE.md rule 4; PSEUDOCODE §10).
class TimerService {
  TimerService(
    this._engine,
    this._adapters,
    this._devices,
    this._timers,
    this._phone, {
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? _defaultId;

  final CommandEngine _engine;
  final AdapterRegistry _adapters;
  final DeviceRepository _devices;
  final TimerRepository _timers;
  final PhoneAlarmScheduler _phone;
  final DateTime Function() _now;
  final String Function() _newId;

  static const _tag = 'timers';
  static int _seq = 0;
  static String _defaultId() =>
      't${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_seq++}';

  /// Tolerances for [reconcile].
  static const overdueGrace = Duration(minutes: 1);
  static const externalCancelMargin = Duration(seconds: 30);
  static const driftTolerance = Duration(minutes: 1);

  // ------------------------------------------------------------------ public API

  /// "on for 20 min": set [action] now, flip back after [d].
  Future<List<TimerOutcome>> powerFor(
    List<Device> targets,
    PowerAction action,
    Duration d,
  ) => Future.wait([for (final dev in targets) _powerForOne(dev, action, d)]);

  /// "off after 10 min" / "on in 5 min": apply [action] after [d], leave state now.
  Future<List<TimerOutcome>> powerAfter(
    List<Device> targets,
    PowerAction action,
    Duration d,
  ) => Future.wait([
    for (final dev in targets)
      _schedule(
        dev,
        _engine.desiredFor(dev, action),
        d,
        currentOn: _engine.cached(dev.id)?.on,
      ).then((r) => TimerOutcome(dev, r)),
  ]);

  /// "AC band karo 11 baje" → powerAfter(until next 23:00).
  Future<List<TimerOutcome>> powerAt(
    List<Device> targets,
    PowerAction action,
    ClockTime at,
  ) => powerAfter(targets, action, untilNext(at, _now()));

  /// "AC 11 baje tak chalao" → powerFor(until next 23:00).
  Future<List<TimerOutcome>> powerUntil(
    List<Device> targets,
    PowerAction action,
    ClockTime at,
  ) => powerFor(targets, action, untilNext(at, _now()));

  /// PLAN D6: devices with a default auto-off get an off-timer whenever they are
  /// switched on and have no timer yet. Returns the jobs created.
  Future<List<TimerOutcome>> applyAutoOff(List<Device> turnedOn) async {
    final out = <TimerOutcome>[];
    for (final d in turnedOn) {
      final auto = d.defaultAutoOff;
      if (auto == null || await _timers.activeFor(d.id) != null) continue;
      out.addAll(await powerAfter([d], PowerAction.off, auto));
    }
    return out;
  }

  /// Where a timer ending in [endState] after [d] would run.
  TimerTier chooseTier(
    Device dev,
    Duration d,
    bool endState, {
    bool? currentOn,
  }) {
    final a = _adapters.adapterFor(dev);
    final max = a?.nativeCountdownMax(dev);
    if (a != null &&
        max != null &&
        d <= max &&
        a.canCountdownTo(dev, endState, currentOn: currentOn)) {
      return TimerTier.native;
    }
    return TimerTier.phone;
  }

  /// Cancels the active timer of each target on whichever tier it runs.
  Future<void> cancel(List<Device> targets) async {
    for (final dev in targets) {
      final job = await _timers.activeFor(dev.id);
      if (job != null) await _cancelJob(dev, job, TimerStatus.cancelled);
    }
  }

  /// Brings stored jobs in line with reality (app start, Timers screen open).
  Future<void> reconcile() async {
    final now = _now();
    for (final job in await _timers.active()) {
      final dev = await _devices.byId(job.deviceId);
      if (dev == null) {
        await _timers.setStatus(job.id, TimerStatus.cancelled);
        continue;
      }
      if (job.fireAt.isBefore(now.subtract(overdueGrace))) {
        final st = (await _engine.status([dev])).single.result.valueOrNull;
        final reached = st?.on == null || st!.on == job.endOn;
        // A phone-tier job that never ran is NOT executed late (a geyser switching on
        // hours later is worse than a missed timer); it is marked failed.
        await _timers.setStatus(
          job.id,
          reached || job.tier == TimerTier.native
              ? TimerStatus.done
              : TimerStatus.failed,
        );
        continue;
      }
      if (job.tier != TimerTier.native) continue;
      final left = await _engine.run(dev, (a) => a.getCountdown(dev, job.meta));
      if (left case Ok(:final value)) {
        final expected = job.fireAt.difference(now);
        if (value == null || value == Duration.zero) {
          if (expected > externalCancelMargin) {
            log.i(_tag, '${dev.id}: countdown gone on device → cancelled');
            await _timers.setStatus(job.id, TimerStatus.cancelled);
          }
        } else if ((value - expected).abs() > driftTolerance) {
          await _timers.upsert(job.copyWith(fireAt: now.add(value)));
        }
      }
    }
  }

  /// Phone-tier alarm fired (Android background isolate / iOS foreground ticker).
  Future<Result<void>> onAlarm(String jobId) async {
    final job = await _timers.byId(jobId);
    if (job == null || job.status != TimerStatus.active) return ok;
    final dev = await _devices.byId(job.deviceId);
    if (dev == null) {
      await _timers.setStatus(job.id, TimerStatus.failed);
      return Err(DeviceError.offline('device ${job.deviceId} removed'));
    }
    final r = await _engine.powerOne(dev, job.endOn);
    await _timers.setStatus(
      job.id,
      r.isOk ? TimerStatus.done : TimerStatus.failed,
    );
    if (r case Err(:final error)) {
      log.w(_tag, 'alarm ${job.id} for ${dev.id} failed: ${error.kind.name}');
    }
    return r;
  }

  /// Next occurrence of [at] strictly after [now] (today, else tomorrow).
  static Duration untilNext(ClockTime at, DateTime now) {
    var t = DateTime(now.year, now.month, now.day, at.hour, at.minute);
    if (!t.isAfter(now)) {
      t = DateTime(now.year, now.month, now.day + 1, at.hour, at.minute);
    }
    return t.difference(now);
  }

  // ------------------------------------------------------------------ internals

  Future<TimerOutcome> _powerForOne(
    Device dev,
    PowerAction action,
    Duration d,
  ) async {
    final target = _engine.desiredFor(dev, action);
    final a = _adapters.adapterFor(dev);
    final max = a?.nativeCountdownMax(dev);
    if (a != null &&
        a.supportsCombinedPowerFor(dev) &&
        max != null &&
        d <= max) {
      await _cancelExisting(dev);
      final r = await _engine.run(dev, (a) => a.powerFor(dev, target, d));
      if (r case Ok(value: final handle)) {
        await _engine.remember(
          dev.id,
          (_engine.cached(dev.id) ?? DeviceState(at: _now())).copyWith(
            on: target,
            at: _now(),
          ),
        );
        return TimerOutcome(
          dev,
          Ok(await _record(dev, !target, d, TimerTier.native, handle)),
        );
      }
      // fall through to the two-step path
    }
    final set = await _engine.powerOne(dev, target);
    if (set case Err(:final error)) return TimerOutcome(dev, Err(error));
    return TimerOutcome(
      dev,
      await _schedule(dev, !target, d, currentOn: target),
    );
  }

  Future<Result<TimerJob>> _schedule(
    Device dev,
    bool endOn,
    Duration d, {
    bool? currentOn,
  }) async {
    await _cancelExisting(dev);
    var tier = chooseTier(dev, d, endOn, currentOn: currentOn);
    var handle = const <String, String>{};
    if (tier == TimerTier.native) {
      final r = await _engine.run(dev, (a) => a.setCountdown(dev, d, endOn));
      switch (r) {
        case Ok(:final value):
          handle = value;
        case Err(:final error):
          log.w(
            _tag,
            '${dev.id}: native countdown failed (${error.kind.name}) → phone tier',
          );
          tier = TimerTier.phone;
      }
    }
    return Ok(await _record(dev, endOn, d, tier, handle));
  }

  Future<TimerJob> _record(
    Device dev,
    bool endOn,
    Duration d,
    TimerTier tier,
    CountdownHandle handle,
  ) async {
    final now = _now();
    final job = TimerJob(
      id: _newId(),
      deviceId: dev.id,
      endOn: endOn,
      fireAt: now.add(d),
      tier: tier,
      meta: handle,
      createdAt: now,
    );
    // Store first: phone schedulers may read the job (iOS notification text).
    await _timers.upsert(job);
    if (tier == TimerTier.phone) await _phone.schedule(job.id, job.fireAt);
    log.i(
      _tag,
      '${dev.id}: ${endOn ? 'on' : 'off'} in ${d.inSeconds}s (${tier.name})',
    );
    return job;
  }

  /// One active timer per device (PSEUDOCODE §10).
  Future<void> _cancelExisting(Device dev) async {
    final job = await _timers.activeFor(dev.id);
    if (job != null) await _cancelJob(dev, job, TimerStatus.cancelled);
  }

  Future<void> _cancelJob(Device dev, TimerJob job, TimerStatus status) async {
    if (job.tier == TimerTier.native) {
      await _engine.run(dev, (a) => a.cancelCountdown(dev, job.meta));
    } else {
      await _phone.cancel(job.id);
    }
    await _timers.setStatus(job.id, status);
  }
}
