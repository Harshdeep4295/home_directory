import 'dart:io';

/// Wi-Fi facts the platform plugin reports. PSEUDOCODE §3.
class NetInfo {
  const NetInfo({
    required this.wifi,
    required this.internet,
    this.ip,
    this.prefix,
    this.ssid,
  });

  final bool wifi;
  final bool internet;
  final String? ip;
  final int? prefix;
  final String? ssid;

  static const unknown = NetInfo(wifi: false, internet: false);

  @override
  bool operator ==(Object other) =>
      other is NetInfo &&
      other.wifi == wifi &&
      other.internet == internet &&
      other.ip == ip &&
      other.prefix == prefix &&
      other.ssid == ssid;

  @override
  int get hashCode => Object.hash(wifi, internet, ip, prefix, ssid);

  @override
  String toString() =>
      'NetInfo(wifi: $wifi, internet: $internet, ip: $ip/$prefix, ssid: $ssid)';
}

/// The thin native layer (CLAUDE.md rule 7): Android LanBindingPlugin (T1.4),
/// iOS LocalNetworkPlugin (T1.5). Everything else is Dart.
abstract interface class PlatformBridge {
  /// Android: bind the process to the Wi-Fi network even when it has no internet.
  Future<void> init();

  Future<NetInfo> netInfo();

  /// Emits whenever Wi-Fi or internet availability changes.
  Stream<NetInfo> get changes;

  /// False on iOS without the multicast entitlement (free Apple ID, PLAN D3).
  bool get canBroadcast;

  /// Android MulticastLock; no-op elsewhere.
  Future<void> acquireMulticastLock();
  Future<void> releaseMulticastLock();
}

/// Used in tests and before a native plugin exists: no binding, broadcast allowed except
/// on iOS, net info from the first non-loopback IPv4 interface (assumes /24).
class DefaultPlatformBridge implements PlatformBridge {
  @override
  Future<void> init() async {}

  @override
  Future<NetInfo> netInfo() async {
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final i in ifaces) {
        for (final a in i.addresses) {
          if (!a.isLoopback) {
            return NetInfo(
              wifi: true,
              internet: false,
              ip: a.address,
              prefix: 24,
            );
          }
        }
      }
    } on SocketException {
      // fall through
    }
    return NetInfo.unknown;
  }

  @override
  Stream<NetInfo> get changes => const Stream.empty();

  @override
  bool get canBroadcast => !Platform.isIOS;

  @override
  Future<void> acquireMulticastLock() async {}

  @override
  Future<void> releaseMulticastLock() async {}
}
