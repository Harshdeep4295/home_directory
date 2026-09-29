import 'dart:async';

import 'platform_bridge.dart';

enum NetBanner {
  /// Wi-Fi up and internet present (or unknown): nothing to show.
  none,

  /// Wi-Fi up, internet down: informational "Internet down · Local mode".
  localMode,

  /// No Wi-Fi: blocking "Connect to home Wi-Fi".
  noWifi,
}

NetBanner bannerFor(NetInfo n) => !n.wifi
    ? NetBanner.noWifi
    : n.internet == false
    ? NetBanner.localMode
    : NetBanner.none;

/// Single source of network state for the app (PSEUDOCODE §3.4). Seeds from
/// [PlatformBridge.netInfo], follows [PlatformBridge.changes], drops duplicates.
class NetworkMonitor {
  NetworkMonitor(this._platform);

  final PlatformBridge _platform;
  final _states = StreamController<NetInfo>.broadcast();
  StreamSubscription<NetInfo>? _sub;
  NetInfo _current = NetInfo.unknown;
  bool _started = false;

  NetInfo get current => _current;

  /// Every distinct state, starting after [start].
  Stream<NetInfo> get states => _states.stream;

  /// Fires when the Wi-Fi network itself changes (joined, left, new IP/subnet): the cue to
  /// re-run discovery quickly. Internet-only changes do not fire.
  Stream<NetInfo> get wifiChanges {
    var last = _current;
    return states.where((n) {
      final changed =
          n.wifi != last.wifi || n.ip != last.ip || n.prefix != last.prefix;
      last = n;
      return changed;
    });
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _sub = _platform.changes.listen(_update, onError: (Object _) {});
    _update(await _platform.netInfo());
  }

  void _update(NetInfo next) {
    if (next == _current) return;
    _current = next;
    _states.add(next);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _states.close();
  }
}
