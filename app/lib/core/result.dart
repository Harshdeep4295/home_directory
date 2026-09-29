import 'package:freezed_annotation/freezed_annotation.dart';

part 'result.freezed.dart';
part 'result.g.dart';

/// Why a device operation failed. Adapters map every failure to one of these kinds.
enum DeviceErrorKind { timeout, refused, auth, protocol, unsupported, offline }

@freezed
abstract class DeviceError with _$DeviceError {
  const factory DeviceError(
    DeviceErrorKind kind, [
    @Default('') String message,
  ]) = _DeviceError;

  factory DeviceError.timeout([String message = '']) =>
      DeviceError(DeviceErrorKind.timeout, message);
  factory DeviceError.refused([String message = '']) =>
      DeviceError(DeviceErrorKind.refused, message);
  factory DeviceError.auth([String message = '']) =>
      DeviceError(DeviceErrorKind.auth, message);
  factory DeviceError.protocol([String message = '']) =>
      DeviceError(DeviceErrorKind.protocol, message);
  factory DeviceError.unsupported([String message = '']) =>
      DeviceError(DeviceErrorKind.unsupported, message);
  factory DeviceError.offline([String message = '']) =>
      DeviceError(DeviceErrorKind.offline, message);

  factory DeviceError.fromJson(Map<String, dynamic> json) =>
      _$DeviceErrorFromJson(json);
}

/// Outcome of a device operation. Adapters return this instead of throwing.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// The value, or null on error.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// The error, or null on success.
  DeviceError? get errorOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final error) => error,
  };

  Result<R> map<R>(R Function(T value) f) => switch (this) {
    Ok<T>(:final value) => Ok(f(value)),
    Err<T>(:final error) => Err(error),
  };

  Future<Result<R>> then<R>(Future<Result<R>> Function(T value) f) async =>
      switch (this) {
        Ok<T>(:final value) => f(value),
        Err<T>(:final error) => Err(error),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;
  @override
  int get hashCode => Object.hash(Ok, value);
  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.error);
  final DeviceError error;

  @override
  bool operator ==(Object other) => other is Err<T> && other.error == error;
  @override
  int get hashCode => Object.hash(Err, error);
  @override
  String toString() => 'Err(${error.kind.name}: ${error.message})';
}

/// `Ok(null)` for operations that return nothing.
const Result<void> ok = Ok<void>(null);
