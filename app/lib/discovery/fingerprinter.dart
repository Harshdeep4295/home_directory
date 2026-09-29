import 'dart:convert';
import 'dart:typed_data';

import '../adapters/hue/hue_adapter.dart';
import '../adapters/kasa/kasa_xor.dart';
import '../adapters/tuya/tuya_codec.dart';
import '../core/models.dart';
import '../net/lan_socket_factory.dart';
import 'evidence.dart';

/// What discovery already knows about stored credentials (so badges can say "Ready").
class KnownSecrets {
  const KnownSecrets({this.deviceIds = const {}, this.tplinkAccount = false});

  /// Device ids (Tuya gwId, Hue bridge id, Sonoff id, Shelly mac) that have a secret.
  final Set<String> deviceIds;

  /// A TP-Link account is stored (Tapo / KLAP).
  final bool tplinkAccount;

  bool has(String? id) => id != null && deviceIds.contains(id);
}

/// Decides brand + protocol for a host from its evidence (PSEUDOCODE §7.2, first match
/// wins). Pure and synchronous.
abstract final class Fingerprinter {
  static Candidate? identify(
    HostEvidence e, {
    KnownSecrets known = const KnownSecrets(),
  }) =>
      _tuyaBeacon(e, known) ??
      _wiz(e) ??
      _hue(e, known) ??
      _shelly(e, known) ??
      _sonoff(e, known) ??
      _esphome(e) ??
      _kasaLegacy(e) ??
      _klap(e, known) ??
      _yeelight(e) ??
      _tasmota(e) ??
      _tuyaPort(e, known) ??
      _unknown(e);

  static Map<String, Object?>? _json(List<int> bytes) {
    try {
      final j = jsonDecode(utf8.decode(bytes, allowMalformed: true));
      return j is Map<String, Object?> ? j : null;
    } on FormatException {
      return null;
    }
  }

  static Map<String, Object?>? _httpJson(HttpReply? r) =>
      r == null || r.status != 200 ? null : _json(r.body);

  static String? _normMac(Object? mac) =>
      mac is String ? mac.replaceAll(RegExp('[:-]'), '').toLowerCase() : null;

  static Candidate? _tuyaBeacon(HostEvidence e, KnownSecrets known) {
    for (final raw in e.udp[UdpProbe.tuyaBeacon] ?? const <Uint8List>[]) {
      final b = decodeTuyaBeacon(raw);
      final id = b?['gwId'] as String?;
      if (b == null || id == null) continue;
      final version = b['version'] as String?;
      return Candidate(
        ip: e.ip,
        brand: Brand.tuya,
        protocol: version == null ? 'tuya' : 'tuya-$version',
        version: version,
        deviceId: id,
        needsKey: !known.has(id),
        evidence: [
          'udp tuya beacon v${version ?? '?'}',
          if (b['productKey'] case final String pk) 'productKey $pk',
        ],
      );
    }
    return null;
  }

  static Candidate? _wiz(HostEvidence e) {
    for (final raw in e.udp[UdpProbe.wiz] ?? const <Uint8List>[]) {
      final result = _json(raw)?['result'];
      final mac = result is Map ? result['mac'] : null;
      if (mac is! String) continue;
      return Candidate(
        ip: e.ip,
        mac: mac.toLowerCase(),
        brand: Brand.wiz,
        protocol: 'wiz',
        deviceId: mac.toLowerCase(),
        evidence: const ['udp 38899 reply'],
      );
    }
    return null;
  }

  static Candidate? _hue(HostEvidence e, KnownSecrets known) {
    final cfg = _httpJson(e.http['/api/config']);
    final rec = e.mdnsOf('_hue._tcp');
    if (rec == null && cfg?['bridgeid'] == null) return null;
    final raw = cfg?['bridgeid'] as String? ?? rec?.attributes['bridgeid'];
    final id = raw == null ? null : HueAdapter.normalizeBridgeId(raw);
    return Candidate(
      ip: e.ip,
      brand: Brand.hue,
      protocol: 'hue',
      deviceId: id,
      name: cfg?['name'] as String? ?? rec?.name ?? 'Hue Bridge',
      needsKey: !known.has(id),
      evidence: [
        if (rec != null) 'mdns _hue._tcp',
        if (cfg != null) 'http /api/config',
      ],
    );
  }

  /// Shelly GET /shelly: Gen1 has "type", Gen2+ has "gen" >= 2 (Shelly API docs).
  static Candidate? _shelly(HostEvidence e, KnownSecrets known) {
    final j = _httpJson(e.http['/shelly']);
    final rec = e.mdnsOf('_shelly._tcp');
    final isShelly = j != null && (j.containsKey('type') || j['gen'] is num);
    if (!isShelly && rec == null) return null;
    final gen =
        (j?['gen'] as num?)?.toInt() ??
        (rec?.attributes['gen'] != null
            ? int.tryParse(rec!.attributes['gen']!) ?? 1
            : 1);
    final mac = _normMac(j?['mac']);
    final auth = j?['auth'] == true || j?['auth_en'] == true;
    return Candidate(
      ip: e.ip,
      mac: mac,
      brand: Brand.shelly,
      protocol: gen >= 2 ? 'shelly-gen2' : 'shelly-gen1',
      version: '$gen',
      deviceId: mac,
      name: (j?['name'] ?? j?['type'] ?? j?['model'] ?? rec?.name) as String?,
      needsKey: auth && !known.has(mac),
      evidence: [
        if (j != null) 'http /shelly gen $gen',
        if (rec != null) 'mdns _shelly._tcp',
      ],
    );
  }

  /// eWeLink LAN mDNS TXT: id, type, encrypt (AlexxIT/SonoffLAN).
  static Candidate? _sonoff(HostEvidence e, KnownSecrets known) {
    final rec = e.mdnsOf('_ewelink._tcp');
    if (rec == null) return null;
    final id = rec.attributes['id'];
    final encrypted = rec.attributes['encrypt'] == 'true';
    return Candidate(
      ip: e.ip,
      port: rec.port,
      brand: Brand.sonoff,
      protocol: 'sonoff',
      deviceId: id,
      name: rec.name,
      needsKey: encrypted && !known.has(id),
      evidence: [
        'mdns _ewelink._tcp',
        if (rec.attributes['type'] case final String t) 'type $t',
        if (encrypted) 'encrypted',
      ],
    );
  }

  static Candidate? _esphome(HostEvidence e) {
    final rec = e.mdnsOf('_esphomelib._tcp');
    if (rec == null) return null;
    final mac = _normMac(rec.attributes['mac']);
    return Candidate(
      ip: e.ip,
      mac: mac,
      brand: Brand.esphome,
      protocol: 'esphome',
      deviceId: mac ?? rec.name,
      name: rec.attributes['friendly_name'] ?? rec.name,
      evidence: const ['mdns _esphomelib._tcp'],
    );
  }

  /// python-kasa discover._get_discovery_json_legacy: XOR-decrypted {"system":{"get_sysinfo"}}.
  static Candidate? _kasaLegacy(HostEvidence e) {
    for (final raw in e.udp[UdpProbe.kasa] ?? const <Uint8List>[]) {
      final sys = _json(KasaXor.decrypt(raw))?['system'];
      final info = sys is Map ? sys['get_sysinfo'] : null;
      if (info is! Map) continue;
      final mac = _normMac(info['mac'] ?? info['mic_mac']);
      return Candidate(
        ip: e.ip,
        mac: mac,
        brand: Brand.kasa,
        protocol: 'kasa',
        deviceId: (info['deviceId'] as String?) ?? mac,
        name: info['alias'] as String?,
        evidence: [
          'udp 9999 sysinfo',
          if (info['model'] case final String m) 'model $m',
          if (info['mic_type'] ?? info['type'] case final String t) t,
        ],
      );
    }
    return null;
  }

  /// python-kasa discover._get_discovery_json + DiscoveryResult (device_type, mac, ...).
  static Candidate? _klap(HostEvidence e, KnownSecrets known) {
    for (final raw in e.udp[UdpProbe.klap] ?? const <Uint8List>[]) {
      final r = KlapDiscovery.parseReply(raw)?['result'];
      if (r is! Map) continue;
      final type = r['device_type'] as String? ?? '';
      final scheme = r['mgt_encrypt_schm'];
      final encrypt = scheme is Map ? scheme['encrypt_type'] as String? : null;
      final https = scheme is Map && scheme['is_support_https'] == true;
      final httpPort = scheme is Map ? scheme['http_port'] as num? : null;
      final mac = _normMac(r['mac']);
      // kasa/device_factory.py: "<IOT|SMART>.<encrypt_type>[.HTTPS]" picks the stack.
      final family = type.split('.').first;
      final protocol = switch ((family, encrypt, https)) {
        ('IOT', 'KLAP', false) => 'klap-iot',
        ('SMART', 'KLAP', false) => 'klap-smart',
        // SMART.KLAP.HTTPS, SMART.AES (Tapo cameras/hubs) — no adapter yet.
        _ =>
          'tplink-${family.toLowerCase()}-${(encrypt ?? '?').toLowerCase()}${https ? '-https' : ''}',
      };
      return Candidate(
        ip: e.ip,
        mac: mac,
        port: httpPort?.toInt(),
        brand: type.contains('TAPO') ? Brand.tapo : Brand.kasa,
        protocol: protocol,
        deviceId: (r['device_id'] as String?) ?? mac,
        name: r['device_model'] as String?,
        needsKey: !known.tplinkAccount,
        evidence: ['udp 20002 $type', if (encrypt != null) 'encrypt $encrypt'],
      );
    }
    return null;
  }

  /// python-yeelight ssdp_discover.parse_capabilities: "id: 0x…", "model: …".
  static Candidate? _yeelight(HostEvidence e) {
    for (final raw in e.udp[UdpProbe.yeelight] ?? const <Uint8List>[]) {
      final text = utf8.decode(raw, allowMalformed: true);
      final headers = {
        for (final line in text.split('\r\n'))
          if (line.indexOf(':') case final i when i > 0)
            line.substring(0, i).trim().toLowerCase(): line
                .substring(i + 1)
                .trim(),
      };
      final id = headers['id'];
      if (id == null) continue;
      return Candidate(
        ip: e.ip,
        brand: Brand.yeelight,
        protocol: 'yeelight',
        deviceId: id,
        name: headers['name']?.isNotEmpty ?? false
            ? headers['name']
            : 'Yeelight ${headers['model'] ?? ''}'.trim(),
        evidence: ['ssdp wifi_bulb model ${headers['model'] ?? '?'}'],
      );
    }
    if (e.openPorts.contains(ScanPort.yeelight)) {
      return Candidate(
        ip: e.ip,
        brand: Brand.yeelight,
        protocol: 'yeelight',
        evidence: const ['tcp 55443 open'],
      );
    }
    return null;
  }

  /// Tasmota GET /cm?cmnd=Status%200 → {"Status": {...}, "StatusNET": {"Mac": ...}}.
  static Candidate? _tasmota(HostEvidence e) {
    final j = _httpJson(e.http['/cm?cmnd=Status%200']);
    final status = j?['Status'];
    if (status is! Map) return null;
    final net = j?['StatusNET'];
    final mac = _normMac(net is Map ? net['Mac'] : null);
    final names = status['FriendlyName'];
    return Candidate(
      ip: e.ip,
      mac: mac,
      brand: Brand.tasmota,
      protocol: 'tasmota',
      deviceId: mac,
      name:
          (status['DeviceName'] as String?) ??
          (names is List && names.isNotEmpty ? names.first as String? : null),
      evidence: const ['http /cm Status 0'],
    );
  }

  static Candidate? _tuyaPort(HostEvidence e, KnownSecrets known) {
    if (!e.openPorts.contains(ScanPort.tuya)) return null;
    return Candidate(
      ip: e.ip,
      brand: Brand.tuya,
      protocol: 'tuya',
      needsKey: true,
      evidence: const ['tcp 6668 open (no beacon: version unknown)'],
    );
  }

  static Candidate? _unknown(HostEvidence e) {
    if (!e.openPorts.contains(ScanPort.http) && e.mdns.isEmpty) return null;
    final server = e.http['/']?.headers['server'];
    return Candidate(
      ip: e.ip,
      brand: Brand.unknown,
      protocol: 'unknown',
      name: e.mdns.isNotEmpty ? e.mdns.first.name : null,
      evidence: [
        if (e.openPorts.isNotEmpty) 'open ${e.openPorts.join(',')}',
        for (final m in e.mdns) 'mdns ${m.type}',
        if (server != null) 'server $server',
      ],
    );
  }
}
