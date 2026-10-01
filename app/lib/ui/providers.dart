import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../cameras/camera.dart';
import '../cameras/camera_player.dart';
import '../core/models.dart';
import '../net/platform_bridge.dart';
import '../voice/voice_controller.dart';
import 'home_widget_sync.dart';

/// UI state (PSEUDOCODE §13). [servicesProvider] is overridden in main().
final servicesProvider = Provider<AppServices>(
  (ref) =>
      throw UnimplementedError('override servicesProvider in ProviderScope'),
);

final devicesProvider = StreamProvider<List<Device>>(
  (ref) => ref.watch(servicesProvider).devices.watchAll(),
);

final roomsProvider = StreamProvider<List<Room>>(
  (ref) => ref.watch(servicesProvider).rooms.watchAll(),
);

/// Last known state per device id: seeded from the engine cache, then every change.
final deviceStatesProvider = StreamProvider<Map<String, DeviceState>>((ref) {
  final s = ref.watch(servicesProvider);
  final ctl = StreamController<Map<String, DeviceState>>();
  final map = <String, DeviceState>{};
  () async {
    for (final d in await s.devices.all()) {
      final c = s.engine.cached(d.id);
      if (c != null) map[d.id] = c;
    }
    if (!ctl.isClosed) ctl.add(Map.of(map));
  }();
  final sub = s.engine.stateChanges.listen((e) {
    map[e.$1] = e.$2;
    if (!ctl.isClosed) ctl.add(Map.of(map));
  });
  ref.onDispose(() {
    unawaited(sub.cancel());
    unawaited(ctl.close());
  });
  return ctl.stream;
});

final netStateProvider = StreamProvider<NetInfo>((ref) async* {
  final m = ref.watch(servicesProvider).network;
  yield m.current;
  yield* m.states;
});

/// Active timers, refreshed every second so remaining time counts down.
final timersProvider = StreamProvider<List<TimerJob>>((ref) {
  final repo = ref.watch(servicesProvider).timers;
  final ctl = StreamController<List<TimerJob>>();
  var latest = const <TimerJob>[];
  final sub = repo.watchActive().listen((j) {
    latest = j;
    ctl.add(j);
  });
  final tick = Timer.periodic(const Duration(seconds: 1), (_) {
    if (!ctl.isClosed) ctl.add(latest);
  });
  ref.onDispose(() {
    tick.cancel();
    unawaited(sub.cancel());
    unawaited(ctl.close());
  });
  return ctl.stream;
});

final voiceStateProvider = StreamProvider<VoiceState>((ref) async* {
  final v = ref.watch(servicesProvider).voice;
  if (v == null) return;
  yield v.state;
  yield* v.states;
});

/// Wall clock for UI countdowns (overridable in tests).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Home-screen widget bridge (T5.9); a no-op off Android and in tests.
final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>(
  (ref) => HomeWidgetBridge.forPlatform(),
);

/// Cameras (T9.5): the stored list, then every change.
final camerasProvider = StreamProvider<List<Camera>>((ref) async* {
  final c = ref.watch(servicesProvider).cameras;
  yield await c.all();
  yield* c.changes;
});

/// Video player for cameras (a fake in widget tests).
final cameraPlayerFactoryProvider = Provider<CameraPlayerFactory>(
  (ref) => MediaKitCameraPlayer.new,
);
