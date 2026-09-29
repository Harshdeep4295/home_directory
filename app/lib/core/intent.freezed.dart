// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'intent.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClockTime {

 int get hour; int get minute;
/// Create a copy of ClockTime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClockTimeCopyWith<ClockTime> get copyWith => _$ClockTimeCopyWithImpl<ClockTime>(this as ClockTime, _$identity);

  /// Serializes this ClockTime to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ClockTime;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClockTime&&(identical(other.hour, _this.hour) || other.hour == _this.hour)&&(identical(other.minute, _this.minute) || other.minute == _this.minute));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ClockTime;
  return Object.hash(runtimeType,_this.hour,_this.minute);
}

@override
String toString() {
  final _this = this as ClockTime;
  return 'ClockTime(hour: ${_this.hour}, minute: ${_this.minute})';
}


}

/// @nodoc
abstract mixin class $ClockTimeCopyWith<$Res>  {
  factory $ClockTimeCopyWith(ClockTime value, $Res Function(ClockTime) _then) = _$ClockTimeCopyWithImpl;
@useResult
$Res call({
 int hour, int minute
});




}
/// @nodoc
class _$ClockTimeCopyWithImpl<$Res>
    implements $ClockTimeCopyWith<$Res> {
  _$ClockTimeCopyWithImpl(this._self, this._then);

  final ClockTime _self;
  final $Res Function(ClockTime) _then;

/// Create a copy of ClockTime
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hour = null,Object? minute = null,}) {
  return _then(ClockTime(
null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ClockTime].
extension ClockTimePatterns on ClockTime {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClockTime value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClockTime() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClockTime value)  $default,){
final _that = this;
switch (_that) {
case _ClockTime():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClockTime value)?  $default,){
final _that = this;
switch (_that) {
case _ClockTime() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int hour,  int minute)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClockTime() when $default != null:
return $default(_that.hour,_that.minute);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int hour,  int minute)  $default,) {final _that = this;
switch (_that) {
case _ClockTime():
return $default(_that.hour,_that.minute);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int hour,  int minute)?  $default,) {final _that = this;
switch (_that) {
case _ClockTime() when $default != null:
return $default(_that.hour,_that.minute);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClockTime implements ClockTime {
  const _ClockTime(this.hour, [this.minute = 0]): assert(hour >= 0 && hour < 24, 'hour out of range'),assert(minute >= 0 && minute < 60, 'minute out of range');
  factory _ClockTime.fromJson(Map<String, dynamic> json) => _$ClockTimeFromJson(json);

@override final  int hour;
@override@JsonKey() final  int minute;

/// Create a copy of ClockTime
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClockTimeCopyWith<_ClockTime> get copyWith => __$ClockTimeCopyWithImpl<_ClockTime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClockTimeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClockTime&&(identical(other.hour, hour) || other.hour == hour)&&(identical(other.minute, minute) || other.minute == minute));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,hour,minute);
}

@override
String toString() {
    return 'ClockTime(hour: $hour, minute: $minute)';
}


}

/// @nodoc
abstract mixin class _$ClockTimeCopyWith<$Res> implements $ClockTimeCopyWith<$Res> {
  factory _$ClockTimeCopyWith(_ClockTime value, $Res Function(_ClockTime) _then) = __$ClockTimeCopyWithImpl;
@override @useResult
$Res call({
 int hour, int minute
});




}
/// @nodoc
class __$ClockTimeCopyWithImpl<$Res>
    implements _$ClockTimeCopyWith<$Res> {
  __$ClockTimeCopyWithImpl(this._self, this._then);

  final _ClockTime _self;
  final $Res Function(_ClockTime) _then;

/// Create a copy of ClockTime
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hour = null,Object? minute = null,}) {
  return _then(_ClockTime(
null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TargetSpan {

 List<String> get words; bool get all; String? get room; List<String> get except;
/// Create a copy of TargetSpan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TargetSpanCopyWith<TargetSpan> get copyWith => _$TargetSpanCopyWithImpl<TargetSpan>(this as TargetSpan, _$identity);

  /// Serializes this TargetSpan to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TargetSpan;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TargetSpan&&const DeepCollectionEquality().equals(other.words, _this.words)&&(identical(other.all, _this.all) || other.all == _this.all)&&(identical(other.room, _this.room) || other.room == _this.room)&&const DeepCollectionEquality().equals(other.except, _this.except));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TargetSpan;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.words),_this.all,_this.room,const DeepCollectionEquality().hash(_this.except));
}

@override
String toString() {
  final _this = this as TargetSpan;
  return 'TargetSpan(words: ${_this.words}, all: ${_this.all}, room: ${_this.room}, except: ${_this.except})';
}


}

/// @nodoc
abstract mixin class $TargetSpanCopyWith<$Res>  {
  factory $TargetSpanCopyWith(TargetSpan value, $Res Function(TargetSpan) _then) = _$TargetSpanCopyWithImpl;
@useResult
$Res call({
 List<String> words, bool all, String? room, List<String> except
});




}
/// @nodoc
class _$TargetSpanCopyWithImpl<$Res>
    implements $TargetSpanCopyWith<$Res> {
  _$TargetSpanCopyWithImpl(this._self, this._then);

  final TargetSpan _self;
  final $Res Function(TargetSpan) _then;

/// Create a copy of TargetSpan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? words = null,Object? all = null,Object? room = freezed,Object? except = null,}) {
  return _then(TargetSpan(
words: null == words ? _self.words : words // ignore: cast_nullable_to_non_nullable
as List<String>,all: null == all ? _self.all : all // ignore: cast_nullable_to_non_nullable
as bool,room: freezed == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as String?,except: null == except ? _self.except : except // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [TargetSpan].
extension TargetSpanPatterns on TargetSpan {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TargetSpan value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TargetSpan() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TargetSpan value)  $default,){
final _that = this;
switch (_that) {
case _TargetSpan():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TargetSpan value)?  $default,){
final _that = this;
switch (_that) {
case _TargetSpan() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> words,  bool all,  String? room,  List<String> except)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TargetSpan() when $default != null:
return $default(_that.words,_that.all,_that.room,_that.except);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> words,  bool all,  String? room,  List<String> except)  $default,) {final _that = this;
switch (_that) {
case _TargetSpan():
return $default(_that.words,_that.all,_that.room,_that.except);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> words,  bool all,  String? room,  List<String> except)?  $default,) {final _that = this;
switch (_that) {
case _TargetSpan() when $default != null:
return $default(_that.words,_that.all,_that.room,_that.except);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TargetSpan implements TargetSpan {
  const _TargetSpan({ List<String> words = const <String>[], this.all = false, this.room,  List<String> except = const <String>[]}): _words = words,_except = except;
  factory _TargetSpan.fromJson(Map<String, dynamic> json) => _$TargetSpanFromJson(json);

 final  List<String> _words;
@override@JsonKey() List<String> get words {
  if (_words is EqualUnmodifiableListView) return _words;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_words);
}

@override@JsonKey() final  bool all;
@override final  String? room;
 final  List<String> _except;
@override@JsonKey() List<String> get except {
  if (_except is EqualUnmodifiableListView) return _except;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_except);
}


/// Create a copy of TargetSpan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TargetSpanCopyWith<_TargetSpan> get copyWith => __$TargetSpanCopyWithImpl<_TargetSpan>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TargetSpanToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TargetSpan&&const DeepCollectionEquality().equals(other.words, _words)&&(identical(other.all, all) || other.all == all)&&(identical(other.room, room) || other.room == room)&&const DeepCollectionEquality().equals(other.except, _except));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_words),all,room,const DeepCollectionEquality().hash(_except));
}

@override
String toString() {
    return 'TargetSpan(words: $words, all: $all, room: $room, except: $except)';
}


}

/// @nodoc
abstract mixin class _$TargetSpanCopyWith<$Res> implements $TargetSpanCopyWith<$Res> {
  factory _$TargetSpanCopyWith(_TargetSpan value, $Res Function(_TargetSpan) _then) = __$TargetSpanCopyWithImpl;
@override @useResult
$Res call({
 List<String> words, bool all, String? room, List<String> except
});




}
/// @nodoc
class __$TargetSpanCopyWithImpl<$Res>
    implements _$TargetSpanCopyWith<$Res> {
  __$TargetSpanCopyWithImpl(this._self, this._then);

  final _TargetSpan _self;
  final $Res Function(_TargetSpan) _then;

/// Create a copy of TargetSpan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? words = null,Object? all = null,Object? room = freezed,Object? except = null,}) {
  return _then(_TargetSpan(
words: null == words ? _self._words : words // ignore: cast_nullable_to_non_nullable
as List<String>,all: null == all ? _self.all : all // ignore: cast_nullable_to_non_nullable
as bool,room: freezed == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as String?,except: null == except ? _self._except : except // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

Intent _$IntentFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'power':
          return PowerIntent.fromJson(
            json
          );
                case 'powerFor':
          return PowerForIntent.fromJson(
            json
          );
                case 'powerAfter':
          return PowerAfterIntent.fromJson(
            json
          );
                case 'powerAt':
          return PowerAtIntent.fromJson(
            json
          );
                case 'powerUntil':
          return PowerUntilIntent.fromJson(
            json
          );
                case 'cancelTimer':
          return CancelTimerIntent.fromJson(
            json
          );
                case 'status':
          return StatusIntent.fromJson(
            json
          );
                case 'unknown':
          return UnknownIntent.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'Intent',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$Intent {



  /// Serializes this Intent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Intent);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'Intent()';
}


}

/// @nodoc
class $IntentCopyWith<$Res>  {
$IntentCopyWith(Intent _, $Res Function(Intent) __);
}


/// Adds pattern-matching-related methods to [Intent].
extension IntentPatterns on Intent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PowerIntent value)?  power,TResult Function( PowerForIntent value)?  powerFor,TResult Function( PowerAfterIntent value)?  powerAfter,TResult Function( PowerAtIntent value)?  powerAt,TResult Function( PowerUntilIntent value)?  powerUntil,TResult Function( CancelTimerIntent value)?  cancelTimer,TResult Function( StatusIntent value)?  status,TResult Function( UnknownIntent value)?  unknown,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PowerIntent() when power != null:
return power(_that);case PowerForIntent() when powerFor != null:
return powerFor(_that);case PowerAfterIntent() when powerAfter != null:
return powerAfter(_that);case PowerAtIntent() when powerAt != null:
return powerAt(_that);case PowerUntilIntent() when powerUntil != null:
return powerUntil(_that);case CancelTimerIntent() when cancelTimer != null:
return cancelTimer(_that);case StatusIntent() when status != null:
return status(_that);case UnknownIntent() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PowerIntent value)  power,required TResult Function( PowerForIntent value)  powerFor,required TResult Function( PowerAfterIntent value)  powerAfter,required TResult Function( PowerAtIntent value)  powerAt,required TResult Function( PowerUntilIntent value)  powerUntil,required TResult Function( CancelTimerIntent value)  cancelTimer,required TResult Function( StatusIntent value)  status,required TResult Function( UnknownIntent value)  unknown,}){
final _that = this;
switch (_that) {
case PowerIntent():
return power(_that);case PowerForIntent():
return powerFor(_that);case PowerAfterIntent():
return powerAfter(_that);case PowerAtIntent():
return powerAt(_that);case PowerUntilIntent():
return powerUntil(_that);case CancelTimerIntent():
return cancelTimer(_that);case StatusIntent():
return status(_that);case UnknownIntent():
return unknown(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PowerIntent value)?  power,TResult? Function( PowerForIntent value)?  powerFor,TResult? Function( PowerAfterIntent value)?  powerAfter,TResult? Function( PowerAtIntent value)?  powerAt,TResult? Function( PowerUntilIntent value)?  powerUntil,TResult? Function( CancelTimerIntent value)?  cancelTimer,TResult? Function( StatusIntent value)?  status,TResult? Function( UnknownIntent value)?  unknown,}){
final _that = this;
switch (_that) {
case PowerIntent() when power != null:
return power(_that);case PowerForIntent() when powerFor != null:
return powerFor(_that);case PowerAfterIntent() when powerAfter != null:
return powerAfter(_that);case PowerAtIntent() when powerAt != null:
return powerAt(_that);case PowerUntilIntent() when powerUntil != null:
return powerUntil(_that);case CancelTimerIntent() when cancelTimer != null:
return cancelTimer(_that);case StatusIntent() when status != null:
return status(_that);case UnknownIntent() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( PowerAction action,  TargetSpan targets)?  power,TResult Function( PowerAction action,  Duration duration,  TargetSpan targets)?  powerFor,TResult Function( PowerAction action,  Duration duration,  TargetSpan targets)?  powerAfter,TResult Function( PowerAction action,  ClockTime clock,  TargetSpan targets)?  powerAt,TResult Function( PowerAction action,  ClockTime clock,  TargetSpan targets)?  powerUntil,TResult Function( TargetSpan targets)?  cancelTimer,TResult Function( TargetSpan targets)?  status,TResult Function( String text)?  unknown,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PowerIntent() when power != null:
return power(_that.action,_that.targets);case PowerForIntent() when powerFor != null:
return powerFor(_that.action,_that.duration,_that.targets);case PowerAfterIntent() when powerAfter != null:
return powerAfter(_that.action,_that.duration,_that.targets);case PowerAtIntent() when powerAt != null:
return powerAt(_that.action,_that.clock,_that.targets);case PowerUntilIntent() when powerUntil != null:
return powerUntil(_that.action,_that.clock,_that.targets);case CancelTimerIntent() when cancelTimer != null:
return cancelTimer(_that.targets);case StatusIntent() when status != null:
return status(_that.targets);case UnknownIntent() when unknown != null:
return unknown(_that.text);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( PowerAction action,  TargetSpan targets)  power,required TResult Function( PowerAction action,  Duration duration,  TargetSpan targets)  powerFor,required TResult Function( PowerAction action,  Duration duration,  TargetSpan targets)  powerAfter,required TResult Function( PowerAction action,  ClockTime clock,  TargetSpan targets)  powerAt,required TResult Function( PowerAction action,  ClockTime clock,  TargetSpan targets)  powerUntil,required TResult Function( TargetSpan targets)  cancelTimer,required TResult Function( TargetSpan targets)  status,required TResult Function( String text)  unknown,}) {final _that = this;
switch (_that) {
case PowerIntent():
return power(_that.action,_that.targets);case PowerForIntent():
return powerFor(_that.action,_that.duration,_that.targets);case PowerAfterIntent():
return powerAfter(_that.action,_that.duration,_that.targets);case PowerAtIntent():
return powerAt(_that.action,_that.clock,_that.targets);case PowerUntilIntent():
return powerUntil(_that.action,_that.clock,_that.targets);case CancelTimerIntent():
return cancelTimer(_that.targets);case StatusIntent():
return status(_that.targets);case UnknownIntent():
return unknown(_that.text);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( PowerAction action,  TargetSpan targets)?  power,TResult? Function( PowerAction action,  Duration duration,  TargetSpan targets)?  powerFor,TResult? Function( PowerAction action,  Duration duration,  TargetSpan targets)?  powerAfter,TResult? Function( PowerAction action,  ClockTime clock,  TargetSpan targets)?  powerAt,TResult? Function( PowerAction action,  ClockTime clock,  TargetSpan targets)?  powerUntil,TResult? Function( TargetSpan targets)?  cancelTimer,TResult? Function( TargetSpan targets)?  status,TResult? Function( String text)?  unknown,}) {final _that = this;
switch (_that) {
case PowerIntent() when power != null:
return power(_that.action,_that.targets);case PowerForIntent() when powerFor != null:
return powerFor(_that.action,_that.duration,_that.targets);case PowerAfterIntent() when powerAfter != null:
return powerAfter(_that.action,_that.duration,_that.targets);case PowerAtIntent() when powerAt != null:
return powerAt(_that.action,_that.clock,_that.targets);case PowerUntilIntent() when powerUntil != null:
return powerUntil(_that.action,_that.clock,_that.targets);case CancelTimerIntent() when cancelTimer != null:
return cancelTimer(_that.targets);case StatusIntent() when status != null:
return status(_that.targets);case UnknownIntent() when unknown != null:
return unknown(_that.text);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class PowerIntent implements Intent {
  const PowerIntent(this.action, this.targets, { String? $type}): $type = $type ?? 'power';
  factory PowerIntent.fromJson(Map<String, dynamic> json) => _$PowerIntentFromJson(json);

 final  PowerAction action;
 final  TargetSpan targets;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PowerIntentCopyWith<PowerIntent> get copyWith => _$PowerIntentCopyWithImpl<PowerIntent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PowerIntentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PowerIntent&&(identical(other.action, action) || other.action == action)&&(identical(other.targets, targets) || other.targets == targets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,action,targets);
}

@override
String toString() {
    return 'Intent.power(action: $action, targets: $targets)';
}


}

/// @nodoc
abstract mixin class $PowerIntentCopyWith<$Res> implements $IntentCopyWith<$Res> {
  factory $PowerIntentCopyWith(PowerIntent value, $Res Function(PowerIntent) _then) = _$PowerIntentCopyWithImpl;
@useResult
$Res call({
 PowerAction action, TargetSpan targets
});


$TargetSpanCopyWith<$Res> get targets;

}
/// @nodoc
class _$PowerIntentCopyWithImpl<$Res>
    implements $PowerIntentCopyWith<$Res> {
  _$PowerIntentCopyWithImpl(this._self, this._then);

  final PowerIntent _self;
  final $Res Function(PowerIntent) _then;

/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? action = null,Object? targets = null,}) {
  return _then(PowerIntent(
null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as PowerAction,null == targets ? _self.targets : targets // ignore: cast_nullable_to_non_nullable
as TargetSpan,
  ));
}

/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TargetSpanCopyWith<$Res> get targets {
  
  return $TargetSpanCopyWith<$Res>(_self.targets, (value) {
    return _then(_self.copyWith(targets: value));
  });
}
}

/// @nodoc
@JsonSerializable()
@DurationSecondsConverter()
class PowerForIntent implements Intent {
  const PowerForIntent(this.action, this.duration, this.targets, { String? $type}): $type = $type ?? 'powerFor';
  factory PowerForIntent.fromJson(Map<String, dynamic> json) => _$PowerForIntentFromJson(json);

 final  PowerAction action;
 final  Duration duration;
 final  TargetSpan targets;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PowerForIntentCopyWith<PowerForIntent> get copyWith => _$PowerForIntentCopyWithImpl<PowerForIntent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PowerForIntentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PowerForIntent&&(identical(other.action, action) || other.action == action)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.targets, targets) || other.targets == targets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,action,duration,targets);
}

@override
String toString() {
    return 'Intent.powerFor(action: $action, duration: $duration, targets: $targets)';
}


}

/// @nodoc
abstract mixin class $PowerForIntentCopyWith<$Res> implements $IntentCopyWith<$Res> {
  factory $PowerForIntentCopyWith(PowerForIntent value, $Res Function(PowerForIntent) _then) = _$PowerForIntentCopyWithImpl;
@useResult
$Res call({
 PowerAction action, Duration duration, TargetSpan targets
});


$TargetSpanCopyWith<$Res> get targets;

}
/// @nodoc
class _$PowerForIntentCopyWithImpl<$Res>
    implements $PowerForIntentCopyWith<$Res> {
  _$PowerForIntentCopyWithImpl(this._self, this._then);

  final PowerForIntent _self;
  final $Res Function(PowerForIntent) _then;

/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? action = null,Object? duration = null,Object? targets = null,}) {
  return _then(PowerForIntent(
null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as PowerAction,null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,null == targets ? _self.targets : targets // ignore: cast_nullable_to_non_nullable
as TargetSpan,
  ));
}

/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TargetSpanCopyWith<$Res> get targets {
  
  return $TargetSpanCopyWith<$Res>(_self.targets, (value) {
    return _then(_self.copyWith(targets: value));
  });
}
}

/// @nodoc
@JsonSerializable()
@DurationSecondsConverter()
class PowerAfterIntent implements Intent {
  const PowerAfterIntent(this.action, this.duration, this.targets, { String? $type}): $type = $type ?? 'powerAfter';
  factory PowerAfterIntent.fromJson(Map<String, dynamic> json) => _$PowerAfterIntentFromJson(json);

 final  PowerAction action;
 final  Duration duration;
 final  TargetSpan targets;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PowerAfterIntentCopyWith<PowerAfterIntent> get copyWith => _$PowerAfterIntentCopyWithImpl<PowerAfterIntent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PowerAfterIntentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PowerAfterIntent&&(identical(other.action, action) || other.action == action)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.targets, targets) || other.targets == targets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,action,duration,targets);
}

@override
String toString() {
    return 'Intent.powerAfter(action: $action, duration: $duration, targets: $targets)';
}


}

/// @nodoc
abstract mixin class $PowerAfterIntentCopyWith<$Res> implements $IntentCopyWith<$Res> {
  factory $PowerAfterIntentCopyWith(PowerAfterIntent value, $Res Function(PowerAfterIntent) _then) = _$PowerAfterIntentCopyWithImpl;
@useResult
$Res call({
 PowerAction action, Duration duration, TargetSpan targets
});


$TargetSpanCopyWith<$Res> get targets;

}
/// @nodoc
class _$PowerAfterIntentCopyWithImpl<$Res>
    implements $PowerAfterIntentCopyWith<$Res> {
  _$PowerAfterIntentCopyWithImpl(this._self, this._then);

  final PowerAfterIntent _self;
  final $Res Function(PowerAfterIntent) _then;

/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? action = null,Object? duration = null,Object? targets = null,}) {
  return _then(PowerAfterIntent(
null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as PowerAction,null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,null == targets ? _self.targets : targets // ignore: cast_nullable_to_non_nullable
as TargetSpan,
  ));
}

/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TargetSpanCopyWith<$Res> get targets {
  
  return $TargetSpanCopyWith<$Res>(_self.targets, (value) {
    return _then(_self.copyWith(targets: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class PowerAtIntent implements Intent {
  const PowerAtIntent(this.action, this.clock, this.targets, { String? $type}): $type = $type ?? 'powerAt';
  factory PowerAtIntent.fromJson(Map<String, dynamic> json) => _$PowerAtIntentFromJson(json);

 final  PowerAction action;
 final  ClockTime clock;
 final  TargetSpan targets;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PowerAtIntentCopyWith<PowerAtIntent> get copyWith => _$PowerAtIntentCopyWithImpl<PowerAtIntent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PowerAtIntentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PowerAtIntent&&(identical(other.action, action) || other.action == action)&&(identical(other.clock, clock) || other.clock == clock)&&(identical(other.targets, targets) || other.targets == targets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,action,clock,targets);
}

@override
String toString() {
    return 'Intent.powerAt(action: $action, clock: $clock, targets: $targets)';
}


}

/// @nodoc
abstract mixin class $PowerAtIntentCopyWith<$Res> implements $IntentCopyWith<$Res> {
  factory $PowerAtIntentCopyWith(PowerAtIntent value, $Res Function(PowerAtIntent) _then) = _$PowerAtIntentCopyWithImpl;
@useResult
$Res call({
 PowerAction action, ClockTime clock, TargetSpan targets
});


$ClockTimeCopyWith<$Res> get clock;$TargetSpanCopyWith<$Res> get targets;

}
/// @nodoc
class _$PowerAtIntentCopyWithImpl<$Res>
    implements $PowerAtIntentCopyWith<$Res> {
  _$PowerAtIntentCopyWithImpl(this._self, this._then);

  final PowerAtIntent _self;
  final $Res Function(PowerAtIntent) _then;

/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? action = null,Object? clock = null,Object? targets = null,}) {
  return _then(PowerAtIntent(
null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as PowerAction,null == clock ? _self.clock : clock // ignore: cast_nullable_to_non_nullable
as ClockTime,null == targets ? _self.targets : targets // ignore: cast_nullable_to_non_nullable
as TargetSpan,
  ));
}

/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClockTimeCopyWith<$Res> get clock {
  
  return $ClockTimeCopyWith<$Res>(_self.clock, (value) {
    return _then(_self.copyWith(clock: value));
  });
}/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TargetSpanCopyWith<$Res> get targets {
  
  return $TargetSpanCopyWith<$Res>(_self.targets, (value) {
    return _then(_self.copyWith(targets: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class PowerUntilIntent implements Intent {
  const PowerUntilIntent(this.action, this.clock, this.targets, { String? $type}): $type = $type ?? 'powerUntil';
  factory PowerUntilIntent.fromJson(Map<String, dynamic> json) => _$PowerUntilIntentFromJson(json);

 final  PowerAction action;
 final  ClockTime clock;
 final  TargetSpan targets;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PowerUntilIntentCopyWith<PowerUntilIntent> get copyWith => _$PowerUntilIntentCopyWithImpl<PowerUntilIntent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PowerUntilIntentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PowerUntilIntent&&(identical(other.action, action) || other.action == action)&&(identical(other.clock, clock) || other.clock == clock)&&(identical(other.targets, targets) || other.targets == targets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,action,clock,targets);
}

@override
String toString() {
    return 'Intent.powerUntil(action: $action, clock: $clock, targets: $targets)';
}


}

/// @nodoc
abstract mixin class $PowerUntilIntentCopyWith<$Res> implements $IntentCopyWith<$Res> {
  factory $PowerUntilIntentCopyWith(PowerUntilIntent value, $Res Function(PowerUntilIntent) _then) = _$PowerUntilIntentCopyWithImpl;
@useResult
$Res call({
 PowerAction action, ClockTime clock, TargetSpan targets
});


$ClockTimeCopyWith<$Res> get clock;$TargetSpanCopyWith<$Res> get targets;

}
/// @nodoc
class _$PowerUntilIntentCopyWithImpl<$Res>
    implements $PowerUntilIntentCopyWith<$Res> {
  _$PowerUntilIntentCopyWithImpl(this._self, this._then);

  final PowerUntilIntent _self;
  final $Res Function(PowerUntilIntent) _then;

/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? action = null,Object? clock = null,Object? targets = null,}) {
  return _then(PowerUntilIntent(
null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as PowerAction,null == clock ? _self.clock : clock // ignore: cast_nullable_to_non_nullable
as ClockTime,null == targets ? _self.targets : targets // ignore: cast_nullable_to_non_nullable
as TargetSpan,
  ));
}

/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClockTimeCopyWith<$Res> get clock {
  
  return $ClockTimeCopyWith<$Res>(_self.clock, (value) {
    return _then(_self.copyWith(clock: value));
  });
}/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TargetSpanCopyWith<$Res> get targets {
  
  return $TargetSpanCopyWith<$Res>(_self.targets, (value) {
    return _then(_self.copyWith(targets: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class CancelTimerIntent implements Intent {
  const CancelTimerIntent(this.targets, { String? $type}): $type = $type ?? 'cancelTimer';
  factory CancelTimerIntent.fromJson(Map<String, dynamic> json) => _$CancelTimerIntentFromJson(json);

 final  TargetSpan targets;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CancelTimerIntentCopyWith<CancelTimerIntent> get copyWith => _$CancelTimerIntentCopyWithImpl<CancelTimerIntent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CancelTimerIntentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CancelTimerIntent&&(identical(other.targets, targets) || other.targets == targets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,targets);
}

@override
String toString() {
    return 'Intent.cancelTimer(targets: $targets)';
}


}

/// @nodoc
abstract mixin class $CancelTimerIntentCopyWith<$Res> implements $IntentCopyWith<$Res> {
  factory $CancelTimerIntentCopyWith(CancelTimerIntent value, $Res Function(CancelTimerIntent) _then) = _$CancelTimerIntentCopyWithImpl;
@useResult
$Res call({
 TargetSpan targets
});


$TargetSpanCopyWith<$Res> get targets;

}
/// @nodoc
class _$CancelTimerIntentCopyWithImpl<$Res>
    implements $CancelTimerIntentCopyWith<$Res> {
  _$CancelTimerIntentCopyWithImpl(this._self, this._then);

  final CancelTimerIntent _self;
  final $Res Function(CancelTimerIntent) _then;

/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? targets = null,}) {
  return _then(CancelTimerIntent(
null == targets ? _self.targets : targets // ignore: cast_nullable_to_non_nullable
as TargetSpan,
  ));
}

/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TargetSpanCopyWith<$Res> get targets {
  
  return $TargetSpanCopyWith<$Res>(_self.targets, (value) {
    return _then(_self.copyWith(targets: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class StatusIntent implements Intent {
  const StatusIntent(this.targets, { String? $type}): $type = $type ?? 'status';
  factory StatusIntent.fromJson(Map<String, dynamic> json) => _$StatusIntentFromJson(json);

 final  TargetSpan targets;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StatusIntentCopyWith<StatusIntent> get copyWith => _$StatusIntentCopyWithImpl<StatusIntent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StatusIntentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is StatusIntent&&(identical(other.targets, targets) || other.targets == targets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,targets);
}

@override
String toString() {
    return 'Intent.status(targets: $targets)';
}


}

/// @nodoc
abstract mixin class $StatusIntentCopyWith<$Res> implements $IntentCopyWith<$Res> {
  factory $StatusIntentCopyWith(StatusIntent value, $Res Function(StatusIntent) _then) = _$StatusIntentCopyWithImpl;
@useResult
$Res call({
 TargetSpan targets
});


$TargetSpanCopyWith<$Res> get targets;

}
/// @nodoc
class _$StatusIntentCopyWithImpl<$Res>
    implements $StatusIntentCopyWith<$Res> {
  _$StatusIntentCopyWithImpl(this._self, this._then);

  final StatusIntent _self;
  final $Res Function(StatusIntent) _then;

/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? targets = null,}) {
  return _then(StatusIntent(
null == targets ? _self.targets : targets // ignore: cast_nullable_to_non_nullable
as TargetSpan,
  ));
}

/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TargetSpanCopyWith<$Res> get targets {
  
  return $TargetSpanCopyWith<$Res>(_self.targets, (value) {
    return _then(_self.copyWith(targets: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class UnknownIntent implements Intent {
  const UnknownIntent(this.text, { String? $type}): $type = $type ?? 'unknown';
  factory UnknownIntent.fromJson(Map<String, dynamic> json) => _$UnknownIntentFromJson(json);

 final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnknownIntentCopyWith<UnknownIntent> get copyWith => _$UnknownIntentCopyWithImpl<UnknownIntent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UnknownIntentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UnknownIntent&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,text);
}

@override
String toString() {
    return 'Intent.unknown(text: $text)';
}


}

/// @nodoc
abstract mixin class $UnknownIntentCopyWith<$Res> implements $IntentCopyWith<$Res> {
  factory $UnknownIntentCopyWith(UnknownIntent value, $Res Function(UnknownIntent) _then) = _$UnknownIntentCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$UnknownIntentCopyWithImpl<$Res>
    implements $UnknownIntentCopyWith<$Res> {
  _$UnknownIntentCopyWithImpl(this._self, this._then);

  final UnknownIntent _self;
  final $Res Function(UnknownIntent) _then;

/// Create a copy of Intent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(UnknownIntent(
null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
