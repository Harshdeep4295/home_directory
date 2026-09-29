import '../core/log.dart';
import '../core/models.dart';
import '../registry/repositories.dart';
import '../registry/secret_store.dart';
import 'evidence.dart';
import 'fingerprinter.dart';

/// Where host evidence comes from (the real CandidateCollector, or a fake in tests).
abstract interface class EvidenceSource {
  Future<Map<String, HostEvidence>> collect({Duration window});
}

/// One found device, related to the registry.
class ScanResult {
  const ScanResult(this.candidate, {this.device, this.movedFrom});

  final Candidate candidate;

  /// The registry device it matched (already updated with the new IP), if any.
  final Device? device;

  /// Previous IP when the device moved (DHCP change).
  final String? movedFrom;

  bool get isNew => device == null;
}

class ScanReport {
  const ScanReport(this.results, this.notSeen);

  final List<ScanResult> results;

  /// Registry devices no probe heard from (possibly offline or moved off-subnet).
  final List<Device> notSeen;
}

/// Runs a scan, fingerprints hosts and merges them with the registry (PSEUDOCODE §4, §7).
class DiscoveryService {
  DiscoveryService(
    this._source,
    this._devices,
    this._secrets, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final EvidenceSource _source;
  final DeviceRepository _devices;
  final SecretStore _secrets;
  final DateTime Function() _now;

  static const _tag = 'discovery';

  /// The pseudo device id under which the TP-Link account is stored.
  static const tplinkAccountId = 'tplink';

  Future<ScanReport> scan({
    Duration window = const Duration(seconds: 6),
  }) async {
    final ids = await _secrets.deviceIdsWithSecrets();
    final known = KnownSecrets(
      deviceIds: ids,
      tplinkAccount: ids.contains(tplinkAccountId),
    );
    final evidence = await _source.collect(window: window);
    final results = <ScanResult>[];
    final seen = <String>{};
    for (final e in evidence.values) {
      final c = Fingerprinter.identify(e, known: known);
      if (c == null) continue;
      final r = await merge(c);
      if (r.device != null) seen.add(r.device!.id);
      results.add(r);
    }
    final notSeen = (await _devices.all()).where((d) => !seen.contains(d.id));
    log.i(
      _tag,
      '${results.length} found, ${results.where((r) => r.isNew).length} new, '
      '${results.where((r) => r.movedFrom != null).length} moved',
    );
    return ScanReport(results, notSeen.toList());
  }

  /// Matches [c] to a registry device by deviceId → MAC → IP (IP only for the same
  /// brand, so a DHCP shuffle cannot swap two devices). Updates IP / lastSeen /
  /// protocol version of a match and keeps every user setting.
  Future<ScanResult> merge(Candidate c) async {
    // A Hue bridge is not a device itself; its lights are (meta.hueBridge).
    if (c.brand == Brand.hue && c.deviceId != null) {
      final lights = (await _devices.all())
          .where((d) => d.meta['hueBridge'] == c.deviceId)
          .toList();
      if (lights.isNotEmpty) {
        final moved = lights.first.ip != c.ip ? lights.first.ip : null;
        for (final l in lights) {
          await _devices.upsert(
            l.copyWith(
              ip: c.ip,
              port: c.port ?? l.port,
              lastSeen: _now().toUtc(),
            ),
          );
        }
        return ScanResult(c, device: lights.first, movedFrom: moved);
      }
    }
    final existing = await _match(c);
    if (existing == null) return ScanResult(c);
    final moved = existing.ip != c.ip ? existing.ip : null;
    final updated = existing.copyWith(
      ip: c.ip,
      mac: existing.mac ?? c.mac,
      port: c.port ?? existing.port,
      protocol: _betterProtocol(existing.protocol, c.protocol),
      lastSeen: _now().toUtc(),
    );
    await _devices.upsert(updated);
    if (moved != null) log.i(_tag, '${existing.id} moved $moved → ${c.ip}');
    // Gangs 2..N of a multi-gang Tuya switch share the host (meta.tuyaId).
    for (final sib in await _devices.all()) {
      if (sib.meta['tuyaId'] == existing.id &&
          (sib.ip != updated.ip || sib.protocol != updated.protocol)) {
        await _devices.upsert(
          sib.copyWith(
            ip: updated.ip,
            protocol: updated.protocol,
            lastSeen: updated.lastSeen,
          ),
        );
      }
    }
    return ScanResult(c, device: updated, movedFrom: moved);
  }

  Future<Device?> _match(Candidate c) async {
    if (c.deviceId != null) {
      final d = await _devices.byId(c.deviceId!);
      if (d != null) return d;
    }
    if (c.mac != null) {
      final d = await _devices.byMac(c.mac!);
      if (d != null) return d;
    }
    final d = await _devices.byIp(c.ip);
    return d != null && d.brand == c.brand ? d : null;
  }

  /// Keep a known version (`tuya-3.3`) over an unversioned re-discovery (`tuya`).
  static String _betterProtocol(String old, String found) =>
      found.contains('-') || !old.startsWith(found) ? found : old;

  /// Adds a new candidate to the registry (onboarding "add device").
  Future<Device> add(
    Candidate c, {
    String? name,
    String? roomId,
    List<String> aliases = const [],
    Map<String, Object?> meta = const {},
  }) async {
    final id = c.deviceId ?? c.mac ?? 'ip:${c.ip}';
    final d = Device(
      id: id,
      brand: c.brand,
      protocol: c.protocol,
      ip: c.ip,
      mac: c.mac,
      port: c.port,
      name: name ?? c.name ?? defaultName(c.brand, id),
      roomId: roomId,
      aliases: aliases,
      capabilities: {
        ...defaultCapabilities(c.brand),
        if ('${meta['espEntity']}'.startsWith('light/')) Capability.brightness,
      },
      meta: meta,
      lastSeen: _now().toUtc(),
    );
    await _devices.upsert(d);
    return d;
  }

  /// `<Brand> <last 4 of id>` (PSEUDOCODE §4).
  static String defaultName(Brand b, String id) {
    final brand = switch (b) {
      Brand.wiz => 'WiZ',
      Brand.tuya => 'Tuya',
      Brand.esphome => 'ESPHome',
      Brand.unknown => 'Device',
      _ => b.name[0].toUpperCase() + b.name.substring(1),
    };
    final tail = id.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    return '$brand ${tail.length > 4 ? tail.substring(tail.length - 4) : tail}';
  }

  /// Until an adapter refines them, assume power; Tuya plugs have a countdown DP.
  static Set<Capability> defaultCapabilities(Brand b) => switch (b) {
    Brand.tuya => {Capability.power, Capability.nativeCountdown},
    _ => {Capability.power},
  };
}
