import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../timers/tier_copy.dart';

/// "off in 18m" / "on in 1h 5m" / "off in 40s".
String remainingText(Duration d) {
  if (d.isNegative || d == Duration.zero) return 'now';
  if (d.inHours > 0) {
    final m = d.inMinutes % 60;
    return m == 0 ? '${d.inHours}h' : '${d.inHours}h ${m}m';
  }
  if (d.inMinutes > 0) return '${d.inMinutes}m';
  return '${d.inSeconds}s';
}

IconData iconFor(Device d) {
  final n = [d.name, ...d.aliases].join(' ').toLowerCase();
  if (n.contains('geyser') || n.contains('heater')) {
    return Icons.hot_tub_outlined;
  }
  if (n.contains('fan') || n.contains('pankha')) {
    return Icons.mode_fan_off_outlined;
  }
  if (RegExp(r'\bac\b|air con').hasMatch(n)) return Icons.ac_unit;
  if (n.contains('tv')) return Icons.tv;
  if (d.capabilities.contains(Capability.brightness) ||
      n.contains('light') ||
      n.contains('lamp') ||
      n.contains('batti')) {
    return Icons.lightbulb_outline;
  }
  return Icons.power_outlined;
}

/// Home-screen tile (PSEUDOCODE §13): name, on/off, offline grey, timer chip.
class DeviceTile extends StatelessWidget {
  const DeviceTile({
    super.key,
    required this.device,
    required this.state,
    this.timer,
    required this.now,
    this.onTap,
    this.onLongPress,
  });

  final Device device;
  final DeviceState? state;
  final TimerJob? timer;
  final DateTime now;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final offline = state?.online == false;
    final on = !offline && state?.on == true;
    final bg = offline
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
        : on
        ? scheme.primaryContainer
        : scheme.surfaceContainerHigh;
    final fg = offline
        ? scheme.onSurface.withValues(alpha: 0.45)
        : on
        ? scheme.onPrimaryContainer
        : scheme.onSurface;
    final status = offline
        ? 'Offline'
        : state?.on == null
        ? '—'
        : on
        ? 'On'
        : 'Off';
    return Semantics(
      button: true,
      label: '${device.name}, $status',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(iconFor(device), color: fg),
                    const Spacer(),
                    Text(
                      status,
                      style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  device.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: fg),
                ),
                if (timer case final t?)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.timer_outlined, size: 16),
                      label: Text(
                        '${t.endOn ? 'on' : 'off'} in ${remainingText(t.fireAt.difference(now))} · '
                        '${TierCopy.badge(t.tier, device.brand)}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
