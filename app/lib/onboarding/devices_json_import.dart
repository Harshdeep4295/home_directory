import 'dart:convert';

import '../adapters/tuya/tuya_adapter.dart';
import '../core/log.dart';
import '../core/models.dart';
import '../registry/repositories.dart';
import '../registry/secret_store.dart';

/// Imports the `devices.json` written by `python -m tinytuya wizard` (T6.1, PSEUDOCODE
/// §12.1). Pure file parsing, no network: the wizard already did the cloud part on the
/// user's computer. The file is never stored; keys go straight to [SecretStore].
///
/// Format, from tinytuya 1.20.0 Cloud.py getdevices(): a JSON list of
/// `{name, id, key, mac, ip?, version?, category?, product_name?, sub?, gateway_id?,
///   mapping?: {"1": {code, type, values}, …}}` (mapping built by _build_mapping()).
class DevicesJsonEntry {
  const DevicesJsonEntry({
    required this.id,
    required this.name,
    required this.key,
    this.ip,
    this.mac,
    this.version,
    this.mapping = const {},
    this.subDevice = false,
  });

  final String id;
  final String name;
  final String key;
  final String? ip;
  final String? mac;
  final String? version;

  /// DP id → code (e.g. `1 → switch_1`, `9 → countdown_1`).
  final Map<int, String> mapping;

  /// Zigbee/BLE child of a gateway: not reachable directly on the LAN.
  final bool subDevice;
}

enum ImportStatus {
  added('Added'),
  updated('Key updated'),
  noKey('No local key in the file'),
  subDevice('Gateway sub-device: not supported yet'),
  badKey('Key is not 16 characters');

  const ImportStatus(this.label);
  final String label;

  bool get stored => this == added || this == updated;
}

class ImportOutcome {
  const ImportOutcome(this.entry, this.status, [this.device]);
  final DevicesJsonEntry entry;
  final ImportStatus status;
  final Device? device;
}

class DevicesJsonFormatException implements Exception {
  const DevicesJsonFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Mapping codes that fill our DP roles (TuyaDp). Codes are Tuya standard instruction
/// codes as seen in tinytuya mappings; first match wins.
const _roleCodes = {
  TuyaDp.switch_: [
    'switch_1',
    'switch',
    'switch_led',
    'switch_led_1',
    'led_switch',
  ],
  TuyaDp.countdown: ['countdown_1', 'countdown', 'countdown_led'],
};

/// Derives a [Device.dpMap] from a wizard mapping; null if no switch code is present
/// (the adapter then falls back to its detected default profile).
Map<String, int>? dpMapFromMapping(Map<int, String> mapping) {
  final byCode = {for (final e in mapping.entries) e.value: e.key};
  final out = <String, int>{};
  for (final MapEntry(key: role, value: codes) in _roleCodes.entries) {
    for (final c in codes) {
      if (byCode[c] case final dp?) {
        out[role] = dp;
        break;
      }
    }
  }
  return out.containsKey(TuyaDp.switch_) ? out : null;
}

List<DevicesJsonEntry> parseDevicesJson(String text) {
  final Object? root;
  try {
    root = jsonDecode(text);
  } on FormatException catch (e) {
    throw DevicesJsonFormatException('Not valid JSON: ${e.message}');
  }
  if (root is! List) {
    throw const DevicesJsonFormatException(
      'Expected a list of devices (tinytuya devices.json).',
    );
  }
  final out = <DevicesJsonEntry>[];
  for (final item in root) {
    if (item is! Map) continue;
    final id = item['id'];
    if (id is! String || id.isEmpty) continue;
    String? str(String k) {
      final v = item[k];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final mapping = <int, String>{};
    if (item['mapping'] case final Map<Object?, Object?> m) {
      for (final MapEntry(:key, :value) in m.entries) {
        final dp = int.tryParse('$key');
        if (dp != null && value is Map && value['code'] is String) {
          mapping[dp] = value['code'] as String;
        }
      }
    }
    final version = switch (item['version']) {
      final String v when v.isNotEmpty => v,
      final num v => v.toStringAsFixed(1),
      _ => null,
    };
    out.add(
      DevicesJsonEntry(
        id: id,
        name: str('name') ?? id,
        key: str('key') ?? '',
        ip: str('ip'),
        mac: str('mac'),
        version: version,
        mapping: mapping,
        subDevice: item['sub'] == true || str('gateway_id') != null,
      ),
    );
  }
  return out;
}

class DevicesJsonImporter {
  DevicesJsonImporter(this._devices, this._secrets, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DeviceRepository _devices;
  final SecretStore _secrets;
  final DateTime Function() _now;
  static const _tag = 'import';

  /// Parses [text] and stores every usable key. Existing devices (matched by id) keep
  /// their name, room and aliases; unknown ids become placeholders that the next scan
  /// fills with the current IP.
  Future<List<ImportOutcome>> importText(String text) async {
    final out = <ImportOutcome>[];
    for (final e in parseDevicesJson(text)) {
      out.add(await _importOne(e));
    }
    log.i(
      _tag,
      '${out.where((o) => o.status.stored).length}/${out.length} keys imported',
    );
    return out;
  }

  Future<ImportOutcome> _importOne(DevicesJsonEntry e) async {
    if (e.subDevice) return ImportOutcome(e, ImportStatus.subDevice);
    if (e.key.isEmpty) return ImportOutcome(e, ImportStatus.noKey);
    if (e.key.length != 16) return ImportOutcome(e, ImportStatus.badKey);

    final existing = await _devices.byId(e.id);
    final dpMap = dpMapFromMapping(e.mapping);
    final protocol = e.version != null ? 'tuya-${e.version}' : null;
    final Device d;
    if (existing != null) {
      d = existing.copyWith(
        ip: existing.ip.isEmpty ? (e.ip ?? '') : existing.ip,
        mac: existing.mac ?? e.mac,
        protocol: protocol ?? existing.protocol,
        dpMap: existing.dpMap ?? dpMap,
      );
    } else {
      d = Device(
        id: e.id,
        brand: Brand.tuya,
        protocol: protocol ?? 'tuya',
        ip: e.ip ?? '',
        mac: e.mac,
        name: e.name,
        dpMap: dpMap,
        lastSeen: _now().toUtc(),
      );
    }
    await _secrets.set(e.id, SecretName.localKey, e.key);
    await _devices.upsert(d);
    return ImportOutcome(
      e,
      existing == null ? ImportStatus.added : ImportStatus.updated,
      d,
    );
  }
}
