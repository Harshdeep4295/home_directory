import 'package:flutter/services.dart';

import 'android_platform_bridge.dart' show netInfoFromMap;
import 'platform_bridge.dart';

enum LocalNetworkPermission { granted, denied, unknown }

/// Dart side of the Swift LocalNetworkPlugin (ios/Runner/AppDelegate.swift).
class IosPlatformBridge implements PlatformBridge {
  IosPlatformBridge({
    this._methods = const MethodChannel('offline_home/local_network'),
    this._events = const EventChannel('offline_home/local_network/events'),
  });

  final MethodChannel _methods;
  final EventChannel _events;

  /// Shows the system Local Network prompt on first use and reports the outcome.
  /// Can take until the user answers the prompt (the plugin gives up after 60 s).
  Future<LocalNetworkPermission> requestLocalNetworkPermission() async {
    final s = await _methods.invokeMethod<String>('requestPermission');
    return LocalNetworkPermission.values.asNameMap()[s] ??
        LocalNetworkPermission.unknown;
  }

  @override
  Future<void> init() async {}

  @override
  Future<NetInfo> netInfo() async {
    final m = await _methods.invokeMapMethod<String, Object?>('netInfo');
    return m == null ? NetInfo.unknown : netInfoFromMap(m);
  }

  @override
  late final Stream<NetInfo> changes = _events.receiveBroadcastStream().map(
    (e) => netInfoFromMap((e as Map<Object?, Object?>).cast()),
  );

  /// Free Apple ID signing has no multicast entitlement (PLAN D3).
  @override
  bool get canBroadcast => false;

  @override
  Future<void> acquireMulticastLock() async {}

  @override
  Future<void> releaseMulticastLock() async {}
}
