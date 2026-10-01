import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cameras/camera.dart';
import '../../core/intent.dart';
import '../../core/models.dart';
import '../../core/perf.dart';
import '../providers.dart';
import '../widgets/camera_tile.dart';
import '../widgets/device_tile.dart';

/// Rooms → device tiles; tap toggles, long-press opens the detail screen (T5.2).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    this.onOpenDevice,
    this.onAddDevices,
    this.onMic,
    this.onOpenCamera,
  });

  final void Function(Device)? onOpenDevice;
  final void Function(Camera)? onOpenCamera;
  final VoidCallback? onAddDevices;
  final VoidCallback? onMic;

  static const otherRoom = 'Other';

  /// Tile tap: toggle, then apply the device's default auto-off if it came on.
  static Future<void> toggle(WidgetRef ref, Device d) async {
    final s = ref.read(servicesProvider);
    final r = await s.engine.power([d], PowerAction.toggle);
    if (r.single.result.isOk && s.engine.cached(d.id)?.on == true) {
      await s.timerService.applyAutoOff([d]);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider).value ?? const <Device>[];
    final rooms = ref.watch(roomsProvider).value ?? const <Room>[];
    final states = ref.watch(deviceStatesProvider).value ?? const {};
    final timers = {
      for (final j in ref.watch(timersProvider).value ?? const <TimerJob>[])
        j.deviceId: j,
    };
    final now = ref.watch(clockProvider)();
    final cameras = ref.watch(camerasProvider).value ?? const <Camera>[];

    Widget body;
    if (devices.isEmpty && cameras.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.devices_other, size: 48),
            const SizedBox(height: 12),
            const Text('No devices yet'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAddDevices,
              icon: const Icon(Icons.add),
              label: const Text('Add devices'),
            ),
          ],
        ),
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Perf.markDeviceListShown(),
      );
      final sections = <(String, List<Device>)>[
        for (final r in rooms)
          (r.name, devices.where((d) => d.roomId == r.id).toList()),
        (
          otherRoom,
          devices
              .where(
                (d) => d.roomId == null || !rooms.any((r) => r.id == d.roomId),
              )
              .toList(),
        ),
      ].where((s) => s.$2.isNotEmpty).toList();
      body = CustomScrollView(
        slivers: [
          if (cameras.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Cameras',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 132,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: cameras.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => SizedBox(
                    width: 220,
                    child: CameraTile(
                      key: ValueKey('camera-${cameras[i].id}'),
                      camera: cameras[i],
                      onTap: onOpenCamera == null
                          ? null
                          : () => onOpenCamera!(cameras[i]),
                    ),
                  ),
                ),
              ),
            ),
          ],
          for (final (name, list) in sections) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisExtent: 132,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final d = list[i];
                  return DeviceTile(
                    device: d,
                    state: states[d.id],
                    timer: timers[d.id],
                    now: now,
                    // A rejected key cannot toggle: open the device to fix it.
                    onTap:
                        states[d.id]?.keyRejected == true &&
                            onOpenDevice != null
                        ? () => onOpenDevice!(d)
                        : () => unawaited(toggle(ref, d)),
                    onLongPress: onOpenDevice == null
                        ? null
                        : () => onOpenDevice!(d),
                  );
                },
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      );
    }
    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton.large(
        tooltip: 'Voice command',
        onPressed: onMic,
        child: const Icon(Icons.mic),
      ),
    );
  }
}
