import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../timers/tier_copy.dart';
import '../providers.dart';
import '../widgets/device_tile.dart';

/// Active timers with remaining time and tier; reconciles with devices on open (T5.4).
class TimersScreen extends ConsumerStatefulWidget {
  const TimersScreen({super.key, this.isIOS});

  /// Override for tests; defaults to the host platform.
  final bool? isIOS;

  @override
  ConsumerState<TimersScreen> createState() => _TimersScreenState();
}

class _TimersScreenState extends ConsumerState<TimersScreen> {
  bool get _ios => widget.isIOS ?? Platform.isIOS;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(servicesProvider).timerService.reconcile());
  }

  @override
  Widget build(BuildContext context) {
    final jobs = [...ref.watch(timersProvider).value ?? const <TimerJob>[]]
      ..sort((a, b) => a.fireAt.compareTo(b.fireAt));
    final devices = {
      for (final d in ref.watch(devicesProvider).value ?? const <Device>[])
        d.id: d,
    };
    final now = ref.watch(clockProvider)();
    final phoneOnIOS = _ios && jobs.any((j) => j.tier == TimerTier.phone);

    if (jobs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off_outlined, size: 48),
            SizedBox(height: 12),
            Text('No timers running'),
            SizedBox(height: 4),
            Text('Say "geyser on for 20 minutes" or use a device\'s page.'),
          ],
        ),
      );
    }
    return ListView(
      children: [
        if (phoneOnIOS)
          const Card(
            margin: EdgeInsets.all(12),
            child: ListTile(
              leading: Icon(Icons.warning_amber),
              title: Text('Keep the app open for phone timers'),
              subtitle: Text(TierCopy.iosPhoneWarning),
            ),
          ),
        for (final j in jobs)
          _TimerRow(job: j, device: devices[j.deviceId], now: now),
      ],
    );
  }
}

class _TimerRow extends ConsumerWidget {
  const _TimerRow({required this.job, required this.device, required this.now});
  final TimerJob job;
  final Device? device;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = device;
    final name = d?.name ?? job.deviceId;
    final left = job.fireAt.difference(now);
    final at = TimeOfDay.fromDateTime(job.fireAt.toLocal()).format(context);
    return ListTile(
      leading: Icon(d == null ? Icons.help_outline : iconFor(d)),
      title: Text(
        '$name ${job.endOn ? 'on' : 'off'} in ${remainingText(left)}',
      ),
      subtitle: Text('at $at'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(TierCopy.badge(job.tier, d?.brand ?? Brand.unknown)),
          ),
          IconButton(
            tooltip: 'Cancel timer',
            icon: const Icon(Icons.close),
            onPressed: d == null
                ? null
                : () => ref.read(servicesProvider).timerService.cancel([d]),
          ),
        ],
      ),
    );
  }
}
