import 'package:flutter/services.dart';

import 'platform_bridge.dart';

/// Dart side of the Kotlin LanBindingPlugin (android/.../LanBindingPlugin.kt).
class AndroidPlatformBridge implements PlatformBridge {
  AndroidPlatformBridge({
    this._methods = const MethodChannel('offline_home/lan'),
    this._events = const EventChannel('offline_home/lan/events'),
  });

  final MethodChannel _methods;
  final EventChannel _events;

  @override
  Future<void> init() => _methods.invokeMethod<void>('init');

  @override
  Future<NetInfo> netInfo() async {
    final m = await _methods.invokeMapMethod<String, Object?>('netInfo');
    return m == null ? NetInfo.unknown : netInfoFromMap(m);
  }

  @override
  late final Stream<NetInfo> changes = _events.receiveBroadcastStream().map(
    (e) => netInfoFromMap((e as Map<Object?, Object?>).cast()),
  );

  @override
  bool get canBroadcast => true;

  @override
  Future<void> acquireMulticastLock() =>
      _methods.invokeMethod<void>('acquireMulticastLock');

  @override
  Future<void> releaseMulticastLock() =>
      _methods.invokeMethod<void>('releaseMulticastLock');
}

NetInfo netInfoFromMap(Map<String, Object?> m) => NetInfo(
  wifi: m['wifi'] == true,
  internet: m['internet'] as bool?,
  ip: m['ip'] as String?,
  prefix: (m['prefix'] as num?)?.toInt(),
  ssid: m['ssid'] as String?,
);
