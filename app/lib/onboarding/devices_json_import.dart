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
    this.ranges = const {},
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

  /// DP id → (min, max) for Integer DPs whose mapping `values` carry a range.
  final Map<int, (int, int)> ranges;

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
  const ImportOutcome(this.entry, this.status, [this.devices = const []]);
  final DevicesJsonEntry entry;
  final ImportStatus status;

  /// App devices created/updated: one, or one per gang of a multi-gang switch.
  final List<Device> devices;
  Device? get device => devices.firstOrNull;
}

class DevicesJsonFormatException implements Exception {
  const DevicesJsonFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Mapping codes that fill our DP roles (TuyaDp). Codes are Tuya standard instruction
/// codes as they appear in tinytuya mappings (Cloud._build_mapping of
/// /v1.1/devices/{id}/specifications); first match wins.
const _roleCodes = {
  TuyaDp.switch_: [
    'switch_1',
    'switch',
    'switch_led',
    'switch_led_1',
    'led_switch',
  ],
  TuyaDp.countdown: ['countdown_1', 'countdown', 'countdown_led'],
  TuyaDp.mode: ['work_mode'],
  TuyaDp.brightness: ['bright_value_v2', 'bright_value', 'bright_value_1'],
  TuyaDp.colorTemp: ['temp_value_v2', 'temp_value', 'temp_value_1'],
};

/// Derives a [Device.dpMap] from a wizard mapping; null if no switch code is present
/// (the adapter then falls back to its detected default profile). Brightness /
/// colour-temperature ranges come from the mapping's `values` min/max, else from
/// tinytuya BulbDevice.DEFAULT_DPSET (`_v2` codes: type B 10..1000, others: type A
/// 25..255).
Map<String, int>? dpMapFromMapping(
  Map<int, String> mapping, {
  Map<int, (int, int)> ranges = const {},
}) {
  final byCode = {for (final e in mapping.entries) e.value: e.key};
  final out = <String, int>{};
  String? brightCode;
  for (final MapEntry(key: role, value: codes) in _roleCodes.entries) {
    for (final c in codes) {
      if (byCode[c] case final dp?) {
        out[role] = dp;
        if (role == TuyaDp.brightness) brightCode = c;
        break;
      }
    }
  }
  if (!out.containsKey(TuyaDp.switch_)) return null;
  final rangeDp = out[TuyaDp.brightness] ?? out[TuyaDp.colorTemp];
  if (rangeDp != null) {
    final code = brightCode ?? mapping[rangeDp]!;
    final (min, max) =
        ranges[rangeDp] ?? (code.endsWith('_v2') ? (10, 1000) : (25, 255));
    out[TuyaDp.valueMin] = min;
    out[TuyaDp.valueMax] = max;
  }
  return out;
}

/// Multi-gang switches: one dpMap per `switch_N` (N ≥ 1) with its `countdown_N`, when the
/// mapping has at least two of them; otherwise empty.
List<(int, Map<String, int>)> gangMapsFromMapping(Map<int, String> mapping) {
  final byCode = {for (final e in mapping.entries) e.value: e.key};
  final gangs = <int>[];
  for (final c in byCode.keys) {
    final m = RegExp(r'^switch_(\d+)$').firstMatch(c);
    if (m != null) gangs.add(int.parse(m.group(1)!));
  }
  if (gangs.length < 2) return const [];
  gangs.sort();
  return [
    for (final n in gangs)
      (
        n,
        {
          TuyaDp.switch_: byCode['switch_$n']!,
          TuyaDp.countdown: ?byCode['countdown_$n'],
        },
      ),
  ];
}

/// `values` of an Integer DP: a map (devices.json) or JSON text (cloud specifications).
(int, int)? rangeOf(Object? values) {
  var v = values;
  if (v is String && v.startsWith('{')) {
    try {
      v = jsonDecode(v);
    } on FormatException {
      return null;
    }
  }
  if (v is Map && v['min'] is num && v['max'] is num) {
    return ((v['min'] as num).toInt(), (v['max'] as num).toInt());
  }
  return null;
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
    final ranges = <int, (int, int)>{};
    if (item['mapping'] case final Map<Object?, Object?> m) {
      for (final MapEntry(:key, :value) in m.entries) {
        final dp = int.tryParse('$key');
        if (dp != null && value is Map && value['code'] is String) {
          mapping[dp] = value['code'] as String;
          if (rangeOf(value['values']) case final r?) ranges[dp] = r;
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
        ranges: ranges,
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
  Future<List<ImportOutcome>> importText(String text) =>
      importEntries(parseDevicesJson(text));

  /// Same as [importText] for entries from another source (Tuya cloud import).
  Future<List<ImportOutcome>> importEntries(
    List<DevicesJsonEntry> entries,
  ) async {
    final out = <ImportOutcome>[];
    for (final e in entries) {
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

    final protocol = e.version != null ? 'tuya-${e.version}' : null;
    final gangs = gangMapsFromMapping(e.mapping);
    final plan = gangs.isEmpty
        ? [(1, dpMapFromMapping(e.mapping, ranges: e.ranges))]
        : gangs;
    final existing = await _devices.byId(e.id);
    final devices = <Device>[];
    for (final (n, dpMap) in plan) {
      final id = TuyaAdapter.gangDeviceId(e.id, n);
      final old = await _devices.byId(id);
      final meta = n == 1 ? null : {'tuyaId': e.id, 'gang': n};
      final Device d;
      if (old != null) {
        d = old.copyWith(
          ip: old.ip.isEmpty ? (e.ip ?? '') : old.ip,
          mac: old.mac ?? e.mac,
          protocol: protocol ?? old.protocol,
          dpMap: old.dpMap ?? dpMap,
          capabilities: old.dpMap == null && dpMap != null
              ? TuyaDp.capabilities(dpMap)
              : old.capabilities,
          meta: meta == null ? old.meta : {...old.meta, ...meta},
        );
      } else {
        d = Device(
          id: id,
          brand: Brand.tuya,
          protocol: protocol ?? 'tuya',
          ip: e.ip ?? '',
          mac: e.mac,
          name: gangs.isEmpty ? e.name : '${e.name} $n',
          dpMap: dpMap,
          capabilities: dpMap == null
              ? const {Capability.power, Capability.nativeCountdown}
              : TuyaDp.capabilities(dpMap),
          meta: meta ?? const {},
          lastSeen: _now().toUtc(),
        );
      }
      await _devices.upsert(d);
      devices.add(d);
    }
    // One key for all gangs, stored under the Tuya id (TuyaAdapter.tuyaIdOf).
    await _secrets.set(e.id, SecretName.localKey, e.key);
    return ImportOutcome(
      e,
      existing == null ? ImportStatus.added : ImportStatus.updated,
      devices,
    );
  }
}
