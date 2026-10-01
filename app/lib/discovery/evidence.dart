import 'dart:typed_data';

import '../net/lan_socket_factory.dart';

/// Which discovery probe produced a UDP reply (logical, independent of the port used).
enum UdpProbe { wiz, kasa, klap, yeelight, tuyaBeacon, onvif, sadp }

/// Well-known TCP ports the scan looks for (logical; tests may map them elsewhere).
abstract final class ScanPort {
  static const tuya = 6668;
  static const kasa = 9999;
  static const http = 80;
  static const sonoffDiy = 8081;
  static const yeelight = 55443;
  static const esphomeApi = 6053;

  /// RFC 2326 §3.2 RTSP: cameras and video recorders (T9.1 categories).
  static const rtsp = 554;
  static const all = [tuya, kasa, http, sonoffDiy, yeelight, esphomeApi, rtsp];
}

/// One mDNS service instance.
class MdnsRecord {
  const MdnsRecord({
    required this.type,
    required this.name,
    required this.port,
    this.attributes = const {},
  });

  /// e.g. `_hue._tcp`
  final String type;
  final String name;
  final int port;
  final Map<String, String> attributes;

  @override
  String toString() => 'MdnsRecord($type, $name:$port, $attributes)';
}

/// Everything discovery learned about one IP (input to the Fingerprinter).
class HostEvidence {
  HostEvidence(this.ip);

  final String ip;
  final Set<int> openPorts = {};
  final List<MdnsRecord> mdns = [];
  final Map<UdpProbe, List<Uint8List>> udp = {};

  /// HTTP probe results keyed by path (`/shelly`, `/cm?cmnd=Status%200`, `/`).
  final Map<String, HttpReply> http = {};

  /// `Server` header of an RTSP OPTIONS reply (hosts with [ScanPort.rtsp] open).
  String? rtspServer;

  bool hasMdns(String type) => mdns.any((r) => r.type == type);

  MdnsRecord? mdnsOf(String type) {
    for (final r in mdns) {
      if (r.type == type) return r;
    }
    return null;
  }

  void addUdp(UdpProbe p, Uint8List data) => (udp[p] ??= []).add(data);

  @override
  String toString() =>
      'HostEvidence($ip, ports: $openPorts, mdns: ${mdns.map((m) => m.type)}, '
      'udp: ${udp.keys.map((k) => k.name)}, http: ${http.keys})';
}
