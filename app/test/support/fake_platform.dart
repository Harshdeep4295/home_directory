import 'dart:async';

import 'package:offline_home/net/platform_bridge.dart';

class FakePlatformBridge implements PlatformBridge {
  FakePlatformBridge({
    this.info = const NetInfo(
      wifi: true,
      internet: false,
      ip: '127.0.0.1',
      prefix: 8,
    ),
    this.canBroadcast = true,
  });

  NetInfo info;
  @override
  bool canBroadcast;
  int locksHeld = 0;
  int lockAcquisitions = 0;
  final _changes = StreamController<NetInfo>.broadcast();

  void emit(NetInfo next) {
    info = next;
    _changes.add(next);
  }

  @override
  Future<void> init() async {}

  @override
  Future<NetInfo> netInfo() async => info;

  @override
  Stream<NetInfo> get changes => _changes.stream;

  @override
  Future<void> acquireMulticastLock() async {
    locksHeld++;
    lockAcquisitions++;
  }

  @override
  Future<void> releaseMulticastLock() async => locksHeld--;

  Future<void> dispose() => _changes.close();
}
