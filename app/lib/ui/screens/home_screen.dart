import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_settings.dart';
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

  /// The place Home shows: the stored filter if that place still exists and there is
  /// more than one place, else all (PSEUDOCODE §15).
  static String effectivePlace(String selected, List<String> places) =>
      places.length > 1 && places.any((p) => Places.same(p, selected))
      ? places.firstWhere((p) => Places.same(p, selected))
      : AppSettings.allPlaces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allDevices = ref.watch(devicesProvider).value ?? const <Device>[];
    final allCameras = ref.watch(camerasProvider).value ?? const <Camera>[];
    final places = ref.watch(placesProvider);
    final place = effectivePlace(ref.watch(homePlaceProvider), places);
    bool shown(String p) =>
        place == AppSettings.allPlaces || Places.same(p, place);
    final devices = [
      for (final d in allDevices)
        if (shown(d.place)) d,
    ];
    final cameras = [
      for (final c in allCameras)
        if (shown(c.place)) c,
    ];
    final rooms = ref.watch(roomsProvider).value ?? const <Room>[];
    final states = ref.watch(deviceStatesProvider).value ?? const {};
    final timers = {
      for (final j in ref.watch(timersProvider).value ?? const <TimerJob>[])
        j.deviceId: j,
    };
    final now = ref.watch(clockProvider)();
    // Every device of the chosen place is unreachable: most likely the phone is on
    // another Wi-Fi (LAN control only).
    final unreachable =
        place != AppSettings.allPlaces &&
        devices.isNotEmpty &&
        devices.every((d) => states[d.id]?.online == false);

    Widget body;
    if (allDevices.isEmpty && allCameras.isEmpty) {
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
          if (places.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView(
                  key: const ValueKey('place-filter'),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final p in [AppSettings.allPlaces, ...places])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: ValueKey('home-place-$p'),
                          label: Text(p),
                          selected: p == place,
                          onSelected: (_) => unawaited(
                            ref.read(homePlaceProvider.notifier).select(p),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (unreachable)
            SliverToBoxAdapter(
              child: Card(
                key: const ValueKey('place-unreachable'),
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.wifi_off),
                  title: Text("Can't reach $place from this Wi-Fi"),
                  subtitle: const Text(
                    'Devices are controlled over the local network only. '
                    'Connect to the Wi-Fi at this place.',
                  ),
                ),
              ),
            ),
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
