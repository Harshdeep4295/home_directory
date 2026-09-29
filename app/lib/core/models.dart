import 'package:freezed_annotation/freezed_annotation.dart';

import 'json.dart';

part 'models.freezed.dart';
part 'models.g.dart';

/// Device families the app can talk to. PSEUDOCODE §2.
enum Brand {
  wiz,
  tuya,
  shelly,
  kasa,
  tapo,
  hue,
  yeelight,
  sonoff,
  tasmota,
  esphome,
  unknown,
}

enum Capability { power, brightness, colorTemp, rgb, nativeCountdown }

enum TimerTier { native, phone }

enum TimerStatus { active, done, cancelled, failed }

enum AliasLang { en, hi }

/// A controllable device in the registry.
@freezed
abstract class Device with _$Device {
  @DurationSecondsConverter()
  @UtcDateTimeConverter()
  const factory Device({
    /// Stable id: vendor device id, else MAC, else `ip:<ip>`.
    required String id,
    required Brand brand,

    /// Protocol id including version, e.g. `tuya-3.3`, `wiz`, `kasa-klap`.
    required String protocol,
    required String ip,
    String? mac,
    int? port,
    required String name,
    String? roomId,
    @Default(<String>[]) List<String> aliases,
    @Default(<Capability>{Capability.power}) Set<Capability> capabilities,
    Duration? nativeCountdownMax,

    /// Tuya data-point map, e.g. `{"switch": 1, "countdown": 9}`.
    Map<String, int>? dpMap,
    Duration? defaultAutoOff,

    /// Adapter-specific extras: model, firmware, Shelly gen, Hue light id, ...
    @Default(<String, Object?>{}) Map<String, Object?> meta,
    required DateTime lastSeen,
  }) = _Device;

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
}

/// Last known state of a device.
@freezed
abstract class DeviceState with _$DeviceState {
  @DurationSecondsConverter()
  @UtcDateTimeConverter()
  const factory DeviceState({
    bool? on,
    int? brightness,
    int? colorTemp,
    Duration? countdownLeft,
    @Default(true) bool online,
    required DateTime at,
  }) = _DeviceState;

  factory DeviceState.fromJson(Map<String, dynamic> json) =>
      _$DeviceStateFromJson(json);
}

@freezed
abstract class Room with _$Room {
  const factory Room({
    required String id,
    required String name,
    @Default(0) int sort,
  }) = _Room;

  factory Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);
}

@freezed
abstract class Alias with _$Alias {
  const factory Alias({
    required String id,
    required String deviceId,
    required String alias,
    @Default(AliasLang.en) AliasLang lang,
  }) = _Alias;

  factory Alias.fromJson(Map<String, dynamic> json) => _$AliasFromJson(json);
}

/// A scheduled power change. One active job per device.
@freezed
abstract class TimerJob with _$TimerJob {
  @UtcDateTimeConverter()
  const factory TimerJob({
    required String id,
    required String deviceId,

    /// The power state the device ends in when the timer fires.
    required bool endOn,
    required DateTime fireAt,
    required TimerTier tier,
    @Default(TimerStatus.active) TimerStatus status,

    /// Adapter countdown handle (e.g. Hue scheduleId). PSEUDOCODE §5.
    @Default(<String, String>{}) Map<String, String> meta,
    required DateTime createdAt,
  }) = _TimerJob;

  factory TimerJob.fromJson(Map<String, dynamic> json) =>
      _$TimerJobFromJson(json);
}

/// Something discovery found on the LAN, before it is in the registry.
@freezed
abstract class Candidate with _$Candidate {
  const factory Candidate({
    required String ip,
    String? mac,
    int? port,
    required Brand brand,
    required String protocol,
    String? version,
    String? deviceId,
    String? name,
    @Default(false) bool needsKey,

    /// Human-readable reasons for the identification, for diagnostics.
    @Default(<String>[]) List<String> evidence,
  }) = _Candidate;

  factory Candidate.fromJson(Map<String, dynamic> json) =>
      _$CandidateFromJson(json);
}
