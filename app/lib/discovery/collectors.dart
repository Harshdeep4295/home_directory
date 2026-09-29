import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../adapters/kasa/kasa_xor.dart';
import '../adapters/tuya/tuya_codec.dart';
import '../adapters/wiz/wiz_adapter.dart';
import '../core/log.dart';
import '../core/result.dart';
import '../net/ipv4.dart';
import '../net/lan_socket_factory.dart';
import '../net/platform_bridge.dart';
import 'discovery_service.dart';
import 'evidence.dart';
import 'mdns_browser.dart';

/// Real ports by default; tests map them onto simulator ports.
class DiscoveryPorts {
  const DiscoveryPorts({
    this.wiz = WizAdapter.port,
    this.wizBind = WizAdapter.port,
    this.kasa = KasaXor.discoveryPort,
    this.klap = KlapDiscovery.port,
    this.yeelight = 1982,
    this.tuyaBeacons = tuyaBeaconPorts,
    this.tcp = const {
      ScanPort.tuya: ScanPort.tuya,
      ScanPort.kasa: ScanPort.kasa,
      ScanPort.http: ScanPort.http,
      ScanPort.sonoffDiy: ScanPort.sonoffDiy,
      ScanPort.yeelight: ScanPort.yeelight,
      ScanPort.esphomeApi: ScanPort.esphomeApi,
    },
  });

  final int wiz;

  /// Local port for the WiZ registration broadcast (pywizlight discovery binds 38899).
  final int wizBind;
  final int kasa;
  final int klap;

  /// python-yeelight ssdp_discover.py: M-SEARCH to 239.255.255.250:1982.
  final int yeelight;
  final List<int> tuyaBeacons;

  /// logical ScanPort → actual port to connect to.
  final Map<int, int> tcp;
}

/// python-yeelight ssdp_discover.send_discovery_packet message.
const yeelightSearch =
    'M-SEARCH * HTTP/1.1\r\n'
    'HOST: 239.255.255.250:1982\r\n'
    'MAN: "ssdp:discover"\r\n'
    'ST: wifi_bulb';

/// Runs every discovery probe in parallel and groups what it hears by IP (PSEUDOCODE §7.1).
class CandidateCollector implements EvidenceSource {
  CandidateCollector(
    this._sockets,
    this._platform,
    this._mdns, {
    this.ports = const DiscoveryPorts(),
    this.concurrency = 64,
    this.tcpTimeout = const Duration(milliseconds: 300),
    this.unicastTimeout = const Duration(milliseconds: 400),
    this.httpTimeout = const Duration(milliseconds: 1200),
    this.hosts,
    this.broadcastAddress,
  });

  final LanSocketFactory _sockets;
  final PlatformBridge _platform;
  final MdnsBrowser _mdns;
  final DiscoveryPorts ports;
  final int concurrency;
  final Duration tcpTimeout;
  final Duration unicastTimeout;
  final Duration httpTimeout;

  /// Hosts to scan; default: the Wi-Fi subnet (max /22).
  final List<String>? hosts;

  /// Broadcast target; default: the subnet broadcast address.
  final String? broadcastAddress;

  static const _tag = 'discovery';

  @override
  Future<Map<String, HostEvidence>> collect({
    Duration window = const Duration(seconds: 6),
  }) async {
    final targets = hosts ?? await _subnetHosts();
    final ev = <String, HostEvidence>{};
    HostEvidence at(String ip) => ev.putIfAbsent(ip, () => HostEvidence(ip));
    final udpWindow = window * 0.5;

    await Future.wait([
      _mdnsAll(window * (2 / 3), at),
      _listenTuya(window, at),
      _probe(
        UdpProbe.wiz,
        ports.wiz,
        utf8.encode(WizAdapter.registerMessage),
        targets,
        udpWindow,
        at,
        bindPort: ports.wizBind,
      ),
      _probe(
        UdpProbe.kasa,
        ports.kasa,
        KasaXor.encrypt(utf8.encode(KasaXor.discoveryQuery)),
        targets,
        udpWindow,
        at,
      ),
      _probe(
        UdpProbe.klap,
        ports.klap,
        KlapDiscovery.query,
        targets,
        udpWindow,
        at,
      ),
      _yeelight(udpWindow, at),
      _tcpScan(targets, at),
    ]);
    await _httpProbes(
      ev.values.where((e) => e.openPorts.contains(ScanPort.http)),
    );
    log.i(_tag, 'collected ${ev.length} hosts from ${targets.length} targets');
    return ev;
  }

  Future<List<String>> _subnetHosts() async {
    final n = await _platform.netInfo();
    if (n.ip == null) return const [];
    return subnetHosts(n.ip!, n.prefix ?? 24);
  }

  Future<void> _mdnsAll(
    Duration window,
    HostEvidence Function(String) at,
  ) async {
    try {
      for (final (ip, rec) in await _mdns.browse(mdnsServiceTypes, window)) {
        at(ip).mdns.add(rec);
      }
    } on Object catch (e) {
      log.w(_tag, 'mDNS failed', e);
    }
  }

  /// Tuya devices broadcast beacons on 6666/6667 every few seconds (tinytuya scanner).
  /// On iOS without the multicast entitlement this may hear nothing (PLAN §5 VERIFY).
  Future<void> _listenTuya(
    Duration window,
    HostEvidence Function(String) at,
  ) async {
    final sockets = <RawDatagramSocket>[];
    final subs = <StreamSubscription<RawSocketEvent>>[];
    for (final port in ports.tuyaBeacons) {
      final r = await _sockets.udp(bindPort: port, broadcast: true);
      if (r case Ok(value: final s)) {
        sockets.add(s);
        subs.add(
          s.listen((e) {
            if (e != RawSocketEvent.read) return;
            final dg = s.receive();
            if (dg == null) return;
            final beacon = decodeTuyaBeacon(dg.data);
            final ip = beacon?['ip'] as String? ?? dg.address.address;
            if (beacon != null) at(ip).addUdp(UdpProbe.tuyaBeacon, dg.data);
          }),
        );
      } else {
        log.w(_tag, 'cannot listen on UDP $port: ${r.errorOrNull}');
      }
    }
    if (sockets.isEmpty) return;
    await _platform.acquireMulticastLock();
    try {
      await Future<void>.delayed(window);
    } finally {
      await _platform.releaseMulticastLock();
      for (final s in subs) {
        await s.cancel();
      }
      for (final s in sockets) {
        s.close();
      }
    }
  }

  /// Broadcast where possible; otherwise (iOS) the same datagram to every host.
  Future<void> _probe(
    UdpProbe probe,
    int port,
    List<int> payload,
    List<String> targets,
    Duration window,
    HostEvidence Function(String) at, {
    int bindPort = 0,
  }) async {
    if (_platform.canBroadcast) {
      final r = await _sockets.broadcast(
        port,
        payload,
        window: window,
        broadcastAddress: broadcastAddress,
        bindPort: bindPort,
      );
      for (final reply in r.valueOrNull ?? const <UdpReply>[]) {
        at(reply.address).addUdp(probe, reply.data);
      }
      // Some hosts (and loopback tests) do not answer broadcasts; fall through to unicast
      // only when the caller gave an explicit host list.
      if (hosts == null || (r.valueOrNull?.isNotEmpty ?? false)) return;
    }
    await pooled(targets, concurrency, (h) async {
      final r = await _sockets.udpRequest(
        h,
        port,
        payload,
        timeout: unicastTimeout,
      );
      for (final reply in r.valueOrNull ?? const <UdpReply>[]) {
        at(h).addUdp(probe, reply.data);
      }
    });
  }

  /// SSDP multicast; skipped where multicast is unavailable (iOS → TCP 55443 scan only).
  Future<void> _yeelight(
    Duration window,
    HostEvidence Function(String) at,
  ) async {
    if (!_platform.canBroadcast) return;
    final r = await _sockets.broadcast(
      ports.yeelight,
      ascii.encode(yeelightSearch),
      window: window,
      broadcastAddress: broadcastAddress ?? '239.255.255.250',
    );
    for (final reply in r.valueOrNull ?? const <UdpReply>[]) {
      final loc = RegExp(r'yeelight://([\d.]+):\d+')
          .firstMatch(reply.text)
          ?.group(1);
      at(loc ?? reply.address).addUdp(UdpProbe.yeelight, reply.data);
    }
  }

  Future<void> _tcpScan(
    List<String> targets,
    HostEvidence Function(String) at,
  ) async {
    final jobs = [
      for (final h in targets)
        for (final e in ports.tcp.entries) (h, e.key, e.value),
    ];
    await pooled(jobs, concurrency, (j) async {
      final (host, logical, actual) = j;
      final r = await _sockets.tcp(host, actual, timeout: tcpTimeout);
      if (r case Ok(value: final s)) {
        s.destroy();
        at(host).openPorts.add(logical);
      }
    });
  }

  /// PSEUDOCODE §5: GET /shelly, /cm?cmnd=Status 0, / on hosts with port 80 open, plus
  /// the unauthenticated Hue bridge /api/config (Hue API v1).
  static const httpPaths = [
    '/shelly',
    '/cm?cmnd=Status%200',
    '/api/config',
    '/',
  ];

  Future<void> _httpProbes(Iterable<HostEvidence> hosts) =>
      pooled(hosts.toList(), 16, (e) async {
        final port = ports.tcp[ScanPort.http] ?? 80;
        for (final path in httpPaths) {
          final r = await _sockets.http(
            'GET',
            Uri.parse('http://${e.ip}:$port$path'),
            timeout: httpTimeout,
          );
          if (r case Ok(:final value)) e.http[path] = value;
        }
      });
}

/// Runs [task] over [items] with at most [concurrency] in flight.
Future<void> pooled<T>(
  List<T> items,
  int concurrency,
  Future<void> Function(T) task,
) async {
  var next = 0;
  Future<void> worker() async {
    while (next < items.length) {
      final item = items[next++];
      await task(item);
    }
  }

  await Future.wait([
    for (var i = 0; i < concurrency && i < items.length; i++) worker(),
  ]);
}
