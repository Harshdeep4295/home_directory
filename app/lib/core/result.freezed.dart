// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceError {

 DeviceErrorKind get kind; String get message;
/// Create a copy of DeviceError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceErrorCopyWith<DeviceError> get copyWith => _$DeviceErrorCopyWithImpl<DeviceError>(this as DeviceError, _$identity);

  /// Serializes this DeviceError to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeviceError;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceError&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.message, _this.message) || other.message == _this.message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeviceError;
  return Object.hash(runtimeType,_this.kind,_this.message);
}

@override
String toString() {
  final _this = this as DeviceError;
  return 'DeviceError(kind: ${_this.kind}, message: ${_this.message})';
}


}

/// @nodoc
abstract mixin class $DeviceErrorCopyWith<$Res>  {
  factory $DeviceErrorCopyWith(DeviceError value, $Res Function(DeviceError) _then) = _$DeviceErrorCopyWithImpl;
@useResult
$Res call({
 DeviceErrorKind kind, String message
});




}
/// @nodoc
class _$DeviceErrorCopyWithImpl<$Res>
    implements $DeviceErrorCopyWith<$Res> {
  _$DeviceErrorCopyWithImpl(this._self, this._then);

  final DeviceError _self;
  final $Res Function(DeviceError) _then;

/// Create a copy of DeviceError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? message = null,}) {
  return _then(DeviceError(
null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as DeviceErrorKind,null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceError].
extension DeviceErrorPatterns on DeviceError {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceError value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceError() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceError value)  $default,){
final _that = this;
switch (_that) {
case _DeviceError():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceError value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceError() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DeviceErrorKind kind,  String message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceError() when $default != null:
return $default(_that.kind,_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DeviceErrorKind kind,  String message)  $default,) {final _that = this;
switch (_that) {
case _DeviceError():
return $default(_that.kind,_that.message);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DeviceErrorKind kind,  String message)?  $default,) {final _that = this;
switch (_that) {
case _DeviceError() when $default != null:
return $default(_that.kind,_that.message);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceError implements DeviceError {
  const _DeviceError(this.kind, [this.message = '']);
  factory _DeviceError.fromJson(Map<String, dynamic> json) => _$DeviceErrorFromJson(json);

@override final  DeviceErrorKind kind;
@override@JsonKey() final  String message;

/// Create a copy of DeviceError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceErrorCopyWith<_DeviceError> get copyWith => __$DeviceErrorCopyWithImpl<_DeviceError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceErrorToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceError&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,kind,message);
}

@override
String toString() {
    return 'DeviceError(kind: $kind, message: $message)';
}


}

/// @nodoc
abstract mixin class _$DeviceErrorCopyWith<$Res> implements $DeviceErrorCopyWith<$Res> {
  factory _$DeviceErrorCopyWith(_DeviceError value, $Res Function(_DeviceError) _then) = __$DeviceErrorCopyWithImpl;
@override @useResult
$Res call({
 DeviceErrorKind kind, String message
});




}
/// @nodoc
class __$DeviceErrorCopyWithImpl<$Res>
    implements _$DeviceErrorCopyWith<$Res> {
  __$DeviceErrorCopyWithImpl(this._self, this._then);

  final _DeviceError _self;
  final $Res Function(_DeviceError) _then;

/// Create a copy of DeviceError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? message = null,}) {
  return _then(_DeviceError(
null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as DeviceErrorKind,null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
