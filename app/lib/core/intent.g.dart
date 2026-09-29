// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'intent.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClockTime _$ClockTimeFromJson(Map<String, dynamic> json) => _ClockTime(
  (json['hour'] as num).toInt(),
  (json['minute'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ClockTimeToJson(_ClockTime instance) =>
    <String, dynamic>{'hour': instance.hour, 'minute': instance.minute};

_TargetSpan _$TargetSpanFromJson(Map<String, dynamic> json) => _TargetSpan(
  words:
      (json['words'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  all: json['all'] as bool? ?? false,
  room: json['room'] as String?,
  except:
      (json['except'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
);

Map<String, dynamic> _$TargetSpanToJson(_TargetSpan instance) =>
    <String, dynamic>{
      'words': instance.words,
      'all': instance.all,
      'room': ?instance.room,
      'except': instance.except,
    };

PowerIntent _$PowerIntentFromJson(Map<String, dynamic> json) => PowerIntent(
  $enumDecode(_$PowerActionEnumMap, json['action']),
  TargetSpan.fromJson(json['targets'] as Map<String, dynamic>),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PowerIntentToJson(PowerIntent instance) =>
    <String, dynamic>{
      'action': _$PowerActionEnumMap[instance.action]!,
      'targets': instance.targets.toJson(),
      'type': instance.$type,
    };

const _$PowerActionEnumMap = {
  PowerAction.on: 'on',
  PowerAction.off: 'off',
  PowerAction.toggle: 'toggle',
};

PowerForIntent _$PowerForIntentFromJson(Map<String, dynamic> json) =>
    PowerForIntent(
      $enumDecode(_$PowerActionEnumMap, json['action']),
      const DurationSecondsConverter().fromJson(
        (json['duration'] as num).toInt(),
      ),
      TargetSpan.fromJson(json['targets'] as Map<String, dynamic>),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$PowerForIntentToJson(PowerForIntent instance) =>
    <String, dynamic>{
      'action': _$PowerActionEnumMap[instance.action]!,
      'duration': const DurationSecondsConverter().toJson(instance.duration),
      'targets': instance.targets.toJson(),
      'type': instance.$type,
    };

PowerAfterIntent _$PowerAfterIntentFromJson(Map<String, dynamic> json) =>
    PowerAfterIntent(
      $enumDecode(_$PowerActionEnumMap, json['action']),
      const DurationSecondsConverter().fromJson(
        (json['duration'] as num).toInt(),
      ),
      TargetSpan.fromJson(json['targets'] as Map<String, dynamic>),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$PowerAfterIntentToJson(PowerAfterIntent instance) =>
    <String, dynamic>{
      'action': _$PowerActionEnumMap[instance.action]!,
      'duration': const DurationSecondsConverter().toJson(instance.duration),
      'targets': instance.targets.toJson(),
      'type': instance.$type,
    };

PowerAtIntent _$PowerAtIntentFromJson(Map<String, dynamic> json) =>
    PowerAtIntent(
      $enumDecode(_$PowerActionEnumMap, json['action']),
      ClockTime.fromJson(json['clock'] as Map<String, dynamic>),
      TargetSpan.fromJson(json['targets'] as Map<String, dynamic>),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$PowerAtIntentToJson(PowerAtIntent instance) =>
    <String, dynamic>{
      'action': _$PowerActionEnumMap[instance.action]!,
      'clock': instance.clock.toJson(),
      'targets': instance.targets.toJson(),
      'type': instance.$type,
    };

PowerUntilIntent _$PowerUntilIntentFromJson(Map<String, dynamic> json) =>
    PowerUntilIntent(
      $enumDecode(_$PowerActionEnumMap, json['action']),
      ClockTime.fromJson(json['clock'] as Map<String, dynamic>),
      TargetSpan.fromJson(json['targets'] as Map<String, dynamic>),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$PowerUntilIntentToJson(PowerUntilIntent instance) =>
    <String, dynamic>{
      'action': _$PowerActionEnumMap[instance.action]!,
      'clock': instance.clock.toJson(),
      'targets': instance.targets.toJson(),
      'type': instance.$type,
    };

CancelTimerIntent _$CancelTimerIntentFromJson(Map<String, dynamic> json) =>
    CancelTimerIntent(
      TargetSpan.fromJson(json['targets'] as Map<String, dynamic>),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$CancelTimerIntentToJson(CancelTimerIntent instance) =>
    <String, dynamic>{
      'targets': instance.targets.toJson(),
      'type': instance.$type,
    };

StatusIntent _$StatusIntentFromJson(Map<String, dynamic> json) => StatusIntent(
  TargetSpan.fromJson(json['targets'] as Map<String, dynamic>),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$StatusIntentToJson(StatusIntent instance) =>
    <String, dynamic>{
      'targets': instance.targets.toJson(),
      'type': instance.$type,
    };

UnknownIntent _$UnknownIntentFromJson(Map<String, dynamic> json) =>
    UnknownIntent(json['text'] as String, $type: json['type'] as String?);

Map<String, dynamic> _$UnknownIntentToJson(UnknownIntent instance) =>
    <String, dynamic>{'text': instance.text, 'type': instance.$type};
