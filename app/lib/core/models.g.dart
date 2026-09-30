// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Device _$DeviceFromJson(Map<String, dynamic> json) => _Device(
  id: json['id'] as String,
  brand: $enumDecode(_$BrandEnumMap, json['brand']),
  protocol: json['protocol'] as String,
  ip: json['ip'] as String,
  mac: json['mac'] as String?,
  port: (json['port'] as num?)?.toInt(),
  name: json['name'] as String,
  roomId: json['roomId'] as String?,
  aliases:
      (json['aliases'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  capabilities:
      (json['capabilities'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$CapabilityEnumMap, e))
          .toSet() ??
      const <Capability>{Capability.power},
  nativeCountdownMax: _$JsonConverterFromJson<int, Duration>(
    json['nativeCountdownMax'],
    const DurationSecondsConverter().fromJson,
  ),
  dpMap: (json['dpMap'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, (e as num).toInt()),
  ),
  defaultAutoOff: _$JsonConverterFromJson<int, Duration>(
    json['defaultAutoOff'],
    const DurationSecondsConverter().fromJson,
  ),
  meta: json['meta'] as Map<String, dynamic>? ?? const <String, Object?>{},
  lastSeen: const UtcDateTimeConverter().fromJson(json['lastSeen'] as String),
);

Map<String, dynamic> _$DeviceToJson(_Device instance) => <String, dynamic>{
  'id': instance.id,
  'brand': _$BrandEnumMap[instance.brand]!,
  'protocol': instance.protocol,
  'ip': instance.ip,
  'mac': ?instance.mac,
  'port': ?instance.port,
  'name': instance.name,
  'roomId': ?instance.roomId,
  'aliases': instance.aliases,
  'capabilities': instance.capabilities
      .map((e) => _$CapabilityEnumMap[e]!)
      .toList(),
  'nativeCountdownMax': ?_$JsonConverterToJson<int, Duration>(
    instance.nativeCountdownMax,
    const DurationSecondsConverter().toJson,
  ),
  'dpMap': ?instance.dpMap,
  'defaultAutoOff': ?_$JsonConverterToJson<int, Duration>(
    instance.defaultAutoOff,
    const DurationSecondsConverter().toJson,
  ),
  'meta': instance.meta,
  'lastSeen': const UtcDateTimeConverter().toJson(instance.lastSeen),
};

const _$BrandEnumMap = {
  Brand.wiz: 'wiz',
  Brand.tuya: 'tuya',
  Brand.shelly: 'shelly',
  Brand.kasa: 'kasa',
  Brand.tapo: 'tapo',
  Brand.hue: 'hue',
  Brand.yeelight: 'yeelight',
  Brand.sonoff: 'sonoff',
  Brand.tasmota: 'tasmota',
  Brand.esphome: 'esphome',
  Brand.unknown: 'unknown',
};

const _$CapabilityEnumMap = {
  Capability.power: 'power',
  Capability.brightness: 'brightness',
  Capability.colorTemp: 'colorTemp',
  Capability.rgb: 'rgb',
  Capability.nativeCountdown: 'nativeCountdown',
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

_DeviceState _$DeviceStateFromJson(Map<String, dynamic> json) => _DeviceState(
  on: json['on'] as bool?,
  brightness: (json['brightness'] as num?)?.toInt(),
  colorTemp: (json['colorTemp'] as num?)?.toInt(),
  countdownLeft: _$JsonConverterFromJson<int, Duration>(
    json['countdownLeft'],
    const DurationSecondsConverter().fromJson,
  ),
  online: json['online'] as bool? ?? true,
  keyRejected: json['keyRejected'] as bool? ?? false,
  at: const UtcDateTimeConverter().fromJson(json['at'] as String),
);

Map<String, dynamic> _$DeviceStateToJson(_DeviceState instance) =>
    <String, dynamic>{
      'on': ?instance.on,
      'brightness': ?instance.brightness,
      'colorTemp': ?instance.colorTemp,
      'countdownLeft': ?_$JsonConverterToJson<int, Duration>(
        instance.countdownLeft,
        const DurationSecondsConverter().toJson,
      ),
      'online': instance.online,
      'keyRejected': instance.keyRejected,
      'at': const UtcDateTimeConverter().toJson(instance.at),
    };

_Room _$RoomFromJson(Map<String, dynamic> json) => _Room(
  id: json['id'] as String,
  name: json['name'] as String,
  sort: (json['sort'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$RoomToJson(_Room instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'sort': instance.sort,
};

_Alias _$AliasFromJson(Map<String, dynamic> json) => _Alias(
  id: json['id'] as String,
  deviceId: json['deviceId'] as String,
  alias: json['alias'] as String,
  lang: $enumDecodeNullable(_$AliasLangEnumMap, json['lang']) ?? AliasLang.en,
);

Map<String, dynamic> _$AliasToJson(_Alias instance) => <String, dynamic>{
  'id': instance.id,
  'deviceId': instance.deviceId,
  'alias': instance.alias,
  'lang': _$AliasLangEnumMap[instance.lang]!,
};

const _$AliasLangEnumMap = {AliasLang.en: 'en', AliasLang.hi: 'hi'};

_TimerJob _$TimerJobFromJson(Map<String, dynamic> json) => _TimerJob(
  id: json['id'] as String,
  deviceId: json['deviceId'] as String,
  endOn: json['endOn'] as bool,
  fireAt: const UtcDateTimeConverter().fromJson(json['fireAt'] as String),
  tier: $enumDecode(_$TimerTierEnumMap, json['tier']),
  status:
      $enumDecodeNullable(_$TimerStatusEnumMap, json['status']) ??
      TimerStatus.active,
  meta:
      (json['meta'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
  createdAt: const UtcDateTimeConverter().fromJson(json['createdAt'] as String),
);

Map<String, dynamic> _$TimerJobToJson(_TimerJob instance) => <String, dynamic>{
  'id': instance.id,
  'deviceId': instance.deviceId,
  'endOn': instance.endOn,
  'fireAt': const UtcDateTimeConverter().toJson(instance.fireAt),
  'tier': _$TimerTierEnumMap[instance.tier]!,
  'status': _$TimerStatusEnumMap[instance.status]!,
  'meta': instance.meta,
  'createdAt': const UtcDateTimeConverter().toJson(instance.createdAt),
};

const _$TimerTierEnumMap = {
  TimerTier.native: 'native',
  TimerTier.phone: 'phone',
};

const _$TimerStatusEnumMap = {
  TimerStatus.active: 'active',
  TimerStatus.done: 'done',
  TimerStatus.cancelled: 'cancelled',
  TimerStatus.failed: 'failed',
};

_Candidate _$CandidateFromJson(Map<String, dynamic> json) => _Candidate(
  ip: json['ip'] as String,
  mac: json['mac'] as String?,
  port: (json['port'] as num?)?.toInt(),
  brand: $enumDecode(_$BrandEnumMap, json['brand']),
  protocol: json['protocol'] as String,
  version: json['version'] as String?,
  deviceId: json['deviceId'] as String?,
  name: json['name'] as String?,
  needsKey: json['needsKey'] as bool? ?? false,
  evidence:
      (json['evidence'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
);

Map<String, dynamic> _$CandidateToJson(_Candidate instance) =>
    <String, dynamic>{
      'ip': instance.ip,
      'mac': ?instance.mac,
      'port': ?instance.port,
      'brand': _$BrandEnumMap[instance.brand]!,
      'protocol': instance.protocol,
      'version': ?instance.version,
      'deviceId': ?instance.deviceId,
      'name': ?instance.name,
      'needsKey': instance.needsKey,
      'evidence': instance.evidence,
    };
