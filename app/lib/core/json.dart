import 'package:json_annotation/json_annotation.dart';

/// Durations are stored as whole seconds in JSON and SQLite.
class DurationSecondsConverter implements JsonConverter<Duration, int> {
  const DurationSecondsConverter();
  @override
  Duration fromJson(int json) => Duration(seconds: json);
  @override
  int toJson(Duration object) => object.inSeconds;
}

/// DateTimes are stored as UTC ISO-8601 strings.
class UtcDateTimeConverter implements JsonConverter<DateTime, String> {
  const UtcDateTimeConverter();
  @override
  DateTime fromJson(String json) => DateTime.parse(json).toUtc();
  @override
  String toJson(DateTime object) => object.toUtc().toIso8601String();
}
