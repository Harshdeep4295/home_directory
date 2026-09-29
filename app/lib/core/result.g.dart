// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceError _$DeviceErrorFromJson(Map<String, dynamic> json) => _DeviceError(
  $enumDecode(_$DeviceErrorKindEnumMap, json['kind']),
  json['message'] as String? ?? '',
);

Map<String, dynamic> _$DeviceErrorToJson(_DeviceError instance) =>
    <String, dynamic>{
      'kind': _$DeviceErrorKindEnumMap[instance.kind]!,
      'message': instance.message,
    };

const _$DeviceErrorKindEnumMap = {
  DeviceErrorKind.timeout: 'timeout',
  DeviceErrorKind.refused: 'refused',
  DeviceErrorKind.auth: 'auth',
  DeviceErrorKind.protocol: 'protocol',
  DeviceErrorKind.unsupported: 'unsupported',
  DeviceErrorKind.offline: 'offline',
};
