// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Device {

/// Stable id: vendor device id, else MAC, else `ip:<ip>`.
 String get id; Brand get brand;/// Protocol id including version, e.g. `tuya-3.3`, `wiz`, `klap-smart`.
 String get protocol; String get ip; String? get mac; int? get port; String get name; String? get roomId; List<String> get aliases; Set<Capability> get capabilities; Duration? get nativeCountdownMax;/// Tuya data-point map, e.g. `{"switch": 1, "countdown": 9}`.
 Map<String, int>? get dpMap; Duration? get defaultAutoOff;/// Adapter-specific extras: model, firmware, Shelly gen, Hue light id, ...
 Map<String, Object?> get meta; DateTime get lastSeen;
/// Create a copy of Device
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCopyWith<Device> get copyWith => _$DeviceCopyWithImpl<Device>(this as Device, _$identity);

  /// Serializes this Device to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Device;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Device&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.brand, _this.brand) || other.brand == _this.brand)&&(identical(other.protocol, _this.protocol) || other.protocol == _this.protocol)&&(identical(other.ip, _this.ip) || other.ip == _this.ip)&&(identical(other.mac, _this.mac) || other.mac == _this.mac)&&(identical(other.port, _this.port) || other.port == _this.port)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.roomId, _this.roomId) || other.roomId == _this.roomId)&&const DeepCollectionEquality().equals(other.aliases, _this.aliases)&&const DeepCollectionEquality().equals(other.capabilities, _this.capabilities)&&(identical(other.nativeCountdownMax, _this.nativeCountdownMax) || other.nativeCountdownMax == _this.nativeCountdownMax)&&const DeepCollectionEquality().equals(other.dpMap, _this.dpMap)&&(identical(other.defaultAutoOff, _this.defaultAutoOff) || other.defaultAutoOff == _this.defaultAutoOff)&&const DeepCollectionEquality().equals(other.meta, _this.meta)&&(identical(other.lastSeen, _this.lastSeen) || other.lastSeen == _this.lastSeen));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Device;
  return Object.hash(runtimeType,_this.id,_this.brand,_this.protocol,_this.ip,_this.mac,_this.port,_this.name,_this.roomId,const DeepCollectionEquality().hash(_this.aliases),const DeepCollectionEquality().hash(_this.capabilities),_this.nativeCountdownMax,const DeepCollectionEquality().hash(_this.dpMap),_this.defaultAutoOff,const DeepCollectionEquality().hash(_this.meta),_this.lastSeen);
}

@override
String toString() {
  final _this = this as Device;
  return 'Device(id: ${_this.id}, brand: ${_this.brand}, protocol: ${_this.protocol}, ip: ${_this.ip}, mac: ${_this.mac}, port: ${_this.port}, name: ${_this.name}, roomId: ${_this.roomId}, aliases: ${_this.aliases}, capabilities: ${_this.capabilities}, nativeCountdownMax: ${_this.nativeCountdownMax}, dpMap: ${_this.dpMap}, defaultAutoOff: ${_this.defaultAutoOff}, meta: ${_this.meta}, lastSeen: ${_this.lastSeen})';
}


}

/// @nodoc
abstract mixin class $DeviceCopyWith<$Res>  {
  factory $DeviceCopyWith(Device value, $Res Function(Device) _then) = _$DeviceCopyWithImpl;
@useResult
$Res call({
 String id, Brand brand, String protocol, String ip, String? mac, int? port, String name, String? roomId, List<String> aliases, Set<Capability> capabilities, Duration? nativeCountdownMax, Map<String, int>? dpMap, Duration? defaultAutoOff, Map<String, Object?> meta, DateTime lastSeen
});




}
/// @nodoc
class _$DeviceCopyWithImpl<$Res>
    implements $DeviceCopyWith<$Res> {
  _$DeviceCopyWithImpl(this._self, this._then);

  final Device _self;
  final $Res Function(Device) _then;

/// Create a copy of Device
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? brand = null,Object? protocol = null,Object? ip = null,Object? mac = freezed,Object? port = freezed,Object? name = null,Object? roomId = freezed,Object? aliases = null,Object? capabilities = null,Object? nativeCountdownMax = freezed,Object? dpMap = freezed,Object? defaultAutoOff = freezed,Object? meta = null,Object? lastSeen = null,}) {
  return _then(Device(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,brand: null == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as Brand,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,mac: freezed == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String?,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,roomId: freezed == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String?,aliases: null == aliases ? _self.aliases : aliases // ignore: cast_nullable_to_non_nullable
as List<String>,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as Set<Capability>,nativeCountdownMax: freezed == nativeCountdownMax ? _self.nativeCountdownMax : nativeCountdownMax // ignore: cast_nullable_to_non_nullable
as Duration?,dpMap: freezed == dpMap ? _self.dpMap : dpMap // ignore: cast_nullable_to_non_nullable
as Map<String, int>?,defaultAutoOff: freezed == defaultAutoOff ? _self.defaultAutoOff : defaultAutoOff // ignore: cast_nullable_to_non_nullable
as Duration?,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,lastSeen: null == lastSeen ? _self.lastSeen : lastSeen // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Device].
extension DevicePatterns on Device {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Device value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Device() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Device value)  $default,){
final _that = this;
switch (_that) {
case _Device():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Device value)?  $default,){
final _that = this;
switch (_that) {
case _Device() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  Brand brand,  String protocol,  String ip,  String? mac,  int? port,  String name,  String? roomId,  List<String> aliases,  Set<Capability> capabilities,  Duration? nativeCountdownMax,  Map<String, int>? dpMap,  Duration? defaultAutoOff,  Map<String, Object?> meta,  DateTime lastSeen)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Device() when $default != null:
return $default(_that.id,_that.brand,_that.protocol,_that.ip,_that.mac,_that.port,_that.name,_that.roomId,_that.aliases,_that.capabilities,_that.nativeCountdownMax,_that.dpMap,_that.defaultAutoOff,_that.meta,_that.lastSeen);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  Brand brand,  String protocol,  String ip,  String? mac,  int? port,  String name,  String? roomId,  List<String> aliases,  Set<Capability> capabilities,  Duration? nativeCountdownMax,  Map<String, int>? dpMap,  Duration? defaultAutoOff,  Map<String, Object?> meta,  DateTime lastSeen)  $default,) {final _that = this;
switch (_that) {
case _Device():
return $default(_that.id,_that.brand,_that.protocol,_that.ip,_that.mac,_that.port,_that.name,_that.roomId,_that.aliases,_that.capabilities,_that.nativeCountdownMax,_that.dpMap,_that.defaultAutoOff,_that.meta,_that.lastSeen);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  Brand brand,  String protocol,  String ip,  String? mac,  int? port,  String name,  String? roomId,  List<String> aliases,  Set<Capability> capabilities,  Duration? nativeCountdownMax,  Map<String, int>? dpMap,  Duration? defaultAutoOff,  Map<String, Object?> meta,  DateTime lastSeen)?  $default,) {final _that = this;
switch (_that) {
case _Device() when $default != null:
return $default(_that.id,_that.brand,_that.protocol,_that.ip,_that.mac,_that.port,_that.name,_that.roomId,_that.aliases,_that.capabilities,_that.nativeCountdownMax,_that.dpMap,_that.defaultAutoOff,_that.meta,_that.lastSeen);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@DurationSecondsConverter()
@UtcDateTimeConverter()
class _Device implements Device {
  const _Device({required this.id, required this.brand, required this.protocol, required this.ip, this.mac, this.port, required this.name, this.roomId,  List<String> aliases = const <String>[],  Set<Capability> capabilities = const <Capability>{Capability.power}, this.nativeCountdownMax,  Map<String, int>? dpMap, this.defaultAutoOff,  Map<String, Object?> meta = const <String, Object?>{}, required this.lastSeen}): _aliases = aliases,_capabilities = capabilities,_dpMap = dpMap,_meta = meta;
  factory _Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);

/// Stable id: vendor device id, else MAC, else `ip:<ip>`.
@override final  String id;
@override final  Brand brand;
/// Protocol id including version, e.g. `tuya-3.3`, `wiz`, `klap-smart`.
@override final  String protocol;
@override final  String ip;
@override final  String? mac;
@override final  int? port;
@override final  String name;
@override final  String? roomId;
 final  List<String> _aliases;
@override@JsonKey() List<String> get aliases {
  if (_aliases is EqualUnmodifiableListView) return _aliases;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_aliases);
}

 final  Set<Capability> _capabilities;
@override@JsonKey() Set<Capability> get capabilities {
  if (_capabilities is EqualUnmodifiableSetView) return _capabilities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_capabilities);
}

@override final  Duration? nativeCountdownMax;
/// Tuya data-point map, e.g. `{"switch": 1, "countdown": 9}`.
 final  Map<String, int>? _dpMap;
/// Tuya data-point map, e.g. `{"switch": 1, "countdown": 9}`.
@override Map<String, int>? get dpMap {
  final value = _dpMap;
  if (value == null) return null;
  if (_dpMap is EqualUnmodifiableMapView) return _dpMap;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  Duration? defaultAutoOff;
/// Adapter-specific extras: model, firmware, Shelly gen, Hue light id, ...
 final  Map<String, Object?> _meta;
/// Adapter-specific extras: model, firmware, Shelly gen, Hue light id, ...
@override@JsonKey() Map<String, Object?> get meta {
  if (_meta is EqualUnmodifiableMapView) return _meta;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_meta);
}

@override final  DateTime lastSeen;

/// Create a copy of Device
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCopyWith<_Device> get copyWith => __$DeviceCopyWithImpl<_Device>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Device&&(identical(other.id, id) || other.id == id)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.port, port) || other.port == port)&&(identical(other.name, name) || other.name == name)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&const DeepCollectionEquality().equals(other.aliases, _aliases)&&const DeepCollectionEquality().equals(other.capabilities, _capabilities)&&(identical(other.nativeCountdownMax, nativeCountdownMax) || other.nativeCountdownMax == nativeCountdownMax)&&const DeepCollectionEquality().equals(other.dpMap, _dpMap)&&(identical(other.defaultAutoOff, defaultAutoOff) || other.defaultAutoOff == defaultAutoOff)&&const DeepCollectionEquality().equals(other.meta, _meta)&&(identical(other.lastSeen, lastSeen) || other.lastSeen == lastSeen));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,brand,protocol,ip,mac,port,name,roomId,const DeepCollectionEquality().hash(_aliases),const DeepCollectionEquality().hash(_capabilities),nativeCountdownMax,const DeepCollectionEquality().hash(_dpMap),defaultAutoOff,const DeepCollectionEquality().hash(_meta),lastSeen);
}

@override
String toString() {
    return 'Device(id: $id, brand: $brand, protocol: $protocol, ip: $ip, mac: $mac, port: $port, name: $name, roomId: $roomId, aliases: $aliases, capabilities: $capabilities, nativeCountdownMax: $nativeCountdownMax, dpMap: $dpMap, defaultAutoOff: $defaultAutoOff, meta: $meta, lastSeen: $lastSeen)';
}


}

/// @nodoc
abstract mixin class _$DeviceCopyWith<$Res> implements $DeviceCopyWith<$Res> {
  factory _$DeviceCopyWith(_Device value, $Res Function(_Device) _then) = __$DeviceCopyWithImpl;
@override @useResult
$Res call({
 String id, Brand brand, String protocol, String ip, String? mac, int? port, String name, String? roomId, List<String> aliases, Set<Capability> capabilities, Duration? nativeCountdownMax, Map<String, int>? dpMap, Duration? defaultAutoOff, Map<String, Object?> meta, DateTime lastSeen
});




}
/// @nodoc
class __$DeviceCopyWithImpl<$Res>
    implements _$DeviceCopyWith<$Res> {
  __$DeviceCopyWithImpl(this._self, this._then);

  final _Device _self;
  final $Res Function(_Device) _then;

/// Create a copy of Device
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? brand = null,Object? protocol = null,Object? ip = null,Object? mac = freezed,Object? port = freezed,Object? name = null,Object? roomId = freezed,Object? aliases = null,Object? capabilities = null,Object? nativeCountdownMax = freezed,Object? dpMap = freezed,Object? defaultAutoOff = freezed,Object? meta = null,Object? lastSeen = null,}) {
  return _then(_Device(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,brand: null == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as Brand,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,mac: freezed == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String?,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,roomId: freezed == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String?,aliases: null == aliases ? _self._aliases : aliases // ignore: cast_nullable_to_non_nullable
as List<String>,capabilities: null == capabilities ? _self._capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as Set<Capability>,nativeCountdownMax: freezed == nativeCountdownMax ? _self.nativeCountdownMax : nativeCountdownMax // ignore: cast_nullable_to_non_nullable
as Duration?,dpMap: freezed == dpMap ? _self._dpMap : dpMap // ignore: cast_nullable_to_non_nullable
as Map<String, int>?,defaultAutoOff: freezed == defaultAutoOff ? _self.defaultAutoOff : defaultAutoOff // ignore: cast_nullable_to_non_nullable
as Duration?,meta: null == meta ? _self._meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,lastSeen: null == lastSeen ? _self.lastSeen : lastSeen // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$DeviceState {

 bool? get on; int? get brightness; int? get colorTemp; Duration? get countdownLeft; bool get online;/// The device answered but refused our key / password (T8.1).
 bool get keyRejected; DateTime get at;
/// Create a copy of DeviceState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceStateCopyWith<DeviceState> get copyWith => _$DeviceStateCopyWithImpl<DeviceState>(this as DeviceState, _$identity);

  /// Serializes this DeviceState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeviceState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceState&&(identical(other.on, _this.on) || other.on == _this.on)&&(identical(other.brightness, _this.brightness) || other.brightness == _this.brightness)&&(identical(other.colorTemp, _this.colorTemp) || other.colorTemp == _this.colorTemp)&&(identical(other.countdownLeft, _this.countdownLeft) || other.countdownLeft == _this.countdownLeft)&&(identical(other.online, _this.online) || other.online == _this.online)&&(identical(other.keyRejected, _this.keyRejected) || other.keyRejected == _this.keyRejected)&&(identical(other.at, _this.at) || other.at == _this.at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeviceState;
  return Object.hash(runtimeType,_this.on,_this.brightness,_this.colorTemp,_this.countdownLeft,_this.online,_this.keyRejected,_this.at);
}

@override
String toString() {
  final _this = this as DeviceState;
  return 'DeviceState(on: ${_this.on}, brightness: ${_this.brightness}, colorTemp: ${_this.colorTemp}, countdownLeft: ${_this.countdownLeft}, online: ${_this.online}, keyRejected: ${_this.keyRejected}, at: ${_this.at})';
}


}

/// @nodoc
abstract mixin class $DeviceStateCopyWith<$Res>  {
  factory $DeviceStateCopyWith(DeviceState value, $Res Function(DeviceState) _then) = _$DeviceStateCopyWithImpl;
@useResult
$Res call({
 bool? on, int? brightness, int? colorTemp, Duration? countdownLeft, bool online, bool keyRejected, DateTime at
});




}
/// @nodoc
class _$DeviceStateCopyWithImpl<$Res>
    implements $DeviceStateCopyWith<$Res> {
  _$DeviceStateCopyWithImpl(this._self, this._then);

  final DeviceState _self;
  final $Res Function(DeviceState) _then;

/// Create a copy of DeviceState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? on = freezed,Object? brightness = freezed,Object? colorTemp = freezed,Object? countdownLeft = freezed,Object? online = null,Object? keyRejected = null,Object? at = null,}) {
  return _then(DeviceState(
on: freezed == on ? _self.on : on // ignore: cast_nullable_to_non_nullable
as bool?,brightness: freezed == brightness ? _self.brightness : brightness // ignore: cast_nullable_to_non_nullable
as int?,colorTemp: freezed == colorTemp ? _self.colorTemp : colorTemp // ignore: cast_nullable_to_non_nullable
as int?,countdownLeft: freezed == countdownLeft ? _self.countdownLeft : countdownLeft // ignore: cast_nullable_to_non_nullable
as Duration?,online: null == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as bool,keyRejected: null == keyRejected ? _self.keyRejected : keyRejected // ignore: cast_nullable_to_non_nullable
as bool,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceState].
extension DeviceStatePatterns on DeviceState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceState value)  $default,){
final _that = this;
switch (_that) {
case _DeviceState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceState value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool? on,  int? brightness,  int? colorTemp,  Duration? countdownLeft,  bool online,  bool keyRejected,  DateTime at)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceState() when $default != null:
return $default(_that.on,_that.brightness,_that.colorTemp,_that.countdownLeft,_that.online,_that.keyRejected,_that.at);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool? on,  int? brightness,  int? colorTemp,  Duration? countdownLeft,  bool online,  bool keyRejected,  DateTime at)  $default,) {final _that = this;
switch (_that) {
case _DeviceState():
return $default(_that.on,_that.brightness,_that.colorTemp,_that.countdownLeft,_that.online,_that.keyRejected,_that.at);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool? on,  int? brightness,  int? colorTemp,  Duration? countdownLeft,  bool online,  bool keyRejected,  DateTime at)?  $default,) {final _that = this;
switch (_that) {
case _DeviceState() when $default != null:
return $default(_that.on,_that.brightness,_that.colorTemp,_that.countdownLeft,_that.online,_that.keyRejected,_that.at);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@DurationSecondsConverter()
@UtcDateTimeConverter()
class _DeviceState implements DeviceState {
  const _DeviceState({this.on, this.brightness, this.colorTemp, this.countdownLeft, this.online = true, this.keyRejected = false, required this.at});
  factory _DeviceState.fromJson(Map<String, dynamic> json) => _$DeviceStateFromJson(json);

@override final  bool? on;
@override final  int? brightness;
@override final  int? colorTemp;
@override final  Duration? countdownLeft;
@override@JsonKey() final  bool online;
/// The device answered but refused our key / password (T8.1).
@override@JsonKey() final  bool keyRejected;
@override final  DateTime at;

/// Create a copy of DeviceState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceStateCopyWith<_DeviceState> get copyWith => __$DeviceStateCopyWithImpl<_DeviceState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceStateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceState&&(identical(other.on, on) || other.on == on)&&(identical(other.brightness, brightness) || other.brightness == brightness)&&(identical(other.colorTemp, colorTemp) || other.colorTemp == colorTemp)&&(identical(other.countdownLeft, countdownLeft) || other.countdownLeft == countdownLeft)&&(identical(other.online, online) || other.online == online)&&(identical(other.keyRejected, keyRejected) || other.keyRejected == keyRejected)&&(identical(other.at, at) || other.at == at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,on,brightness,colorTemp,countdownLeft,online,keyRejected,at);
}

@override
String toString() {
    return 'DeviceState(on: $on, brightness: $brightness, colorTemp: $colorTemp, countdownLeft: $countdownLeft, online: $online, keyRejected: $keyRejected, at: $at)';
}


}

/// @nodoc
abstract mixin class _$DeviceStateCopyWith<$Res> implements $DeviceStateCopyWith<$Res> {
  factory _$DeviceStateCopyWith(_DeviceState value, $Res Function(_DeviceState) _then) = __$DeviceStateCopyWithImpl;
@override @useResult
$Res call({
 bool? on, int? brightness, int? colorTemp, Duration? countdownLeft, bool online, bool keyRejected, DateTime at
});




}
/// @nodoc
class __$DeviceStateCopyWithImpl<$Res>
    implements _$DeviceStateCopyWith<$Res> {
  __$DeviceStateCopyWithImpl(this._self, this._then);

  final _DeviceState _self;
  final $Res Function(_DeviceState) _then;

/// Create a copy of DeviceState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? on = freezed,Object? brightness = freezed,Object? colorTemp = freezed,Object? countdownLeft = freezed,Object? online = null,Object? keyRejected = null,Object? at = null,}) {
  return _then(_DeviceState(
on: freezed == on ? _self.on : on // ignore: cast_nullable_to_non_nullable
as bool?,brightness: freezed == brightness ? _self.brightness : brightness // ignore: cast_nullable_to_non_nullable
as int?,colorTemp: freezed == colorTemp ? _self.colorTemp : colorTemp // ignore: cast_nullable_to_non_nullable
as int?,countdownLeft: freezed == countdownLeft ? _self.countdownLeft : countdownLeft // ignore: cast_nullable_to_non_nullable
as Duration?,online: null == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as bool,keyRejected: null == keyRejected ? _self.keyRejected : keyRejected // ignore: cast_nullable_to_non_nullable
as bool,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$Room {

 String get id; String get name; int get sort;
/// Create a copy of Room
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomCopyWith<Room> get copyWith => _$RoomCopyWithImpl<Room>(this as Room, _$identity);

  /// Serializes this Room to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Room;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Room&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.sort, _this.sort) || other.sort == _this.sort));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Room;
  return Object.hash(runtimeType,_this.id,_this.name,_this.sort);
}

@override
String toString() {
  final _this = this as Room;
  return 'Room(id: ${_this.id}, name: ${_this.name}, sort: ${_this.sort})';
}


}

/// @nodoc
abstract mixin class $RoomCopyWith<$Res>  {
  factory $RoomCopyWith(Room value, $Res Function(Room) _then) = _$RoomCopyWithImpl;
@useResult
$Res call({
 String id, String name, int sort
});




}
/// @nodoc
class _$RoomCopyWithImpl<$Res>
    implements $RoomCopyWith<$Res> {
  _$RoomCopyWithImpl(this._self, this._then);

  final Room _self;
  final $Res Function(Room) _then;

/// Create a copy of Room
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? sort = null,}) {
  return _then(Room(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Room].
extension RoomPatterns on Room {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Room value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Room() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Room value)  $default,){
final _that = this;
switch (_that) {
case _Room():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Room value)?  $default,){
final _that = this;
switch (_that) {
case _Room() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int sort)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Room() when $default != null:
return $default(_that.id,_that.name,_that.sort);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int sort)  $default,) {final _that = this;
switch (_that) {
case _Room():
return $default(_that.id,_that.name,_that.sort);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int sort)?  $default,) {final _that = this;
switch (_that) {
case _Room() when $default != null:
return $default(_that.id,_that.name,_that.sort);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Room implements Room {
  const _Room({required this.id, required this.name, this.sort = 0});
  factory _Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  int sort;

/// Create a copy of Room
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomCopyWith<_Room> get copyWith => __$RoomCopyWithImpl<_Room>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Room&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sort, sort) || other.sort == sort));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,sort);
}

@override
String toString() {
    return 'Room(id: $id, name: $name, sort: $sort)';
}


}

/// @nodoc
abstract mixin class _$RoomCopyWith<$Res> implements $RoomCopyWith<$Res> {
  factory _$RoomCopyWith(_Room value, $Res Function(_Room) _then) = __$RoomCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int sort
});




}
/// @nodoc
class __$RoomCopyWithImpl<$Res>
    implements _$RoomCopyWith<$Res> {
  __$RoomCopyWithImpl(this._self, this._then);

  final _Room _self;
  final $Res Function(_Room) _then;

/// Create a copy of Room
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? sort = null,}) {
  return _then(_Room(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$Alias {

 String get id; String get deviceId; String get alias; AliasLang get lang;
/// Create a copy of Alias
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AliasCopyWith<Alias> get copyWith => _$AliasCopyWithImpl<Alias>(this as Alias, _$identity);

  /// Serializes this Alias to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Alias;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Alias&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.deviceId, _this.deviceId) || other.deviceId == _this.deviceId)&&(identical(other.alias, _this.alias) || other.alias == _this.alias)&&(identical(other.lang, _this.lang) || other.lang == _this.lang));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Alias;
  return Object.hash(runtimeType,_this.id,_this.deviceId,_this.alias,_this.lang);
}

@override
String toString() {
  final _this = this as Alias;
  return 'Alias(id: ${_this.id}, deviceId: ${_this.deviceId}, alias: ${_this.alias}, lang: ${_this.lang})';
}


}

/// @nodoc
abstract mixin class $AliasCopyWith<$Res>  {
  factory $AliasCopyWith(Alias value, $Res Function(Alias) _then) = _$AliasCopyWithImpl;
@useResult
$Res call({
 String id, String deviceId, String alias, AliasLang lang
});




}
/// @nodoc
class _$AliasCopyWithImpl<$Res>
    implements $AliasCopyWith<$Res> {
  _$AliasCopyWithImpl(this._self, this._then);

  final Alias _self;
  final $Res Function(Alias) _then;

/// Create a copy of Alias
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? deviceId = null,Object? alias = null,Object? lang = null,}) {
  return _then(Alias(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,alias: null == alias ? _self.alias : alias // ignore: cast_nullable_to_non_nullable
as String,lang: null == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as AliasLang,
  ));
}

}


/// Adds pattern-matching-related methods to [Alias].
extension AliasPatterns on Alias {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Alias value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Alias() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Alias value)  $default,){
final _that = this;
switch (_that) {
case _Alias():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Alias value)?  $default,){
final _that = this;
switch (_that) {
case _Alias() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String deviceId,  String alias,  AliasLang lang)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Alias() when $default != null:
return $default(_that.id,_that.deviceId,_that.alias,_that.lang);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String deviceId,  String alias,  AliasLang lang)  $default,) {final _that = this;
switch (_that) {
case _Alias():
return $default(_that.id,_that.deviceId,_that.alias,_that.lang);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String deviceId,  String alias,  AliasLang lang)?  $default,) {final _that = this;
switch (_that) {
case _Alias() when $default != null:
return $default(_that.id,_that.deviceId,_that.alias,_that.lang);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Alias implements Alias {
  const _Alias({required this.id, required this.deviceId, required this.alias, this.lang = AliasLang.en});
  factory _Alias.fromJson(Map<String, dynamic> json) => _$AliasFromJson(json);

@override final  String id;
@override final  String deviceId;
@override final  String alias;
@override@JsonKey() final  AliasLang lang;

/// Create a copy of Alias
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AliasCopyWith<_Alias> get copyWith => __$AliasCopyWithImpl<_Alias>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AliasToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Alias&&(identical(other.id, id) || other.id == id)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.alias, alias) || other.alias == alias)&&(identical(other.lang, lang) || other.lang == lang));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,deviceId,alias,lang);
}

@override
String toString() {
    return 'Alias(id: $id, deviceId: $deviceId, alias: $alias, lang: $lang)';
}


}

/// @nodoc
abstract mixin class _$AliasCopyWith<$Res> implements $AliasCopyWith<$Res> {
  factory _$AliasCopyWith(_Alias value, $Res Function(_Alias) _then) = __$AliasCopyWithImpl;
@override @useResult
$Res call({
 String id, String deviceId, String alias, AliasLang lang
});




}
/// @nodoc
class __$AliasCopyWithImpl<$Res>
    implements _$AliasCopyWith<$Res> {
  __$AliasCopyWithImpl(this._self, this._then);

  final _Alias _self;
  final $Res Function(_Alias) _then;

/// Create a copy of Alias
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? deviceId = null,Object? alias = null,Object? lang = null,}) {
  return _then(_Alias(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,alias: null == alias ? _self.alias : alias // ignore: cast_nullable_to_non_nullable
as String,lang: null == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as AliasLang,
  ));
}


}


/// @nodoc
mixin _$TimerJob {

 String get id; String get deviceId;/// The power state the device ends in when the timer fires.
 bool get endOn; DateTime get fireAt; TimerTier get tier; TimerStatus get status;/// Adapter countdown handle (e.g. Hue scheduleId). PSEUDOCODE §5.
 Map<String, String> get meta; DateTime get createdAt;
/// Create a copy of TimerJob
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimerJobCopyWith<TimerJob> get copyWith => _$TimerJobCopyWithImpl<TimerJob>(this as TimerJob, _$identity);

  /// Serializes this TimerJob to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TimerJob;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimerJob&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.deviceId, _this.deviceId) || other.deviceId == _this.deviceId)&&(identical(other.endOn, _this.endOn) || other.endOn == _this.endOn)&&(identical(other.fireAt, _this.fireAt) || other.fireAt == _this.fireAt)&&(identical(other.tier, _this.tier) || other.tier == _this.tier)&&(identical(other.status, _this.status) || other.status == _this.status)&&const DeepCollectionEquality().equals(other.meta, _this.meta)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TimerJob;
  return Object.hash(runtimeType,_this.id,_this.deviceId,_this.endOn,_this.fireAt,_this.tier,_this.status,const DeepCollectionEquality().hash(_this.meta),_this.createdAt);
}

@override
String toString() {
  final _this = this as TimerJob;
  return 'TimerJob(id: ${_this.id}, deviceId: ${_this.deviceId}, endOn: ${_this.endOn}, fireAt: ${_this.fireAt}, tier: ${_this.tier}, status: ${_this.status}, meta: ${_this.meta}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $TimerJobCopyWith<$Res>  {
  factory $TimerJobCopyWith(TimerJob value, $Res Function(TimerJob) _then) = _$TimerJobCopyWithImpl;
@useResult
$Res call({
 String id, String deviceId, bool endOn, DateTime fireAt, TimerTier tier, TimerStatus status, Map<String, String> meta, DateTime createdAt
});




}
/// @nodoc
class _$TimerJobCopyWithImpl<$Res>
    implements $TimerJobCopyWith<$Res> {
  _$TimerJobCopyWithImpl(this._self, this._then);

  final TimerJob _self;
  final $Res Function(TimerJob) _then;

/// Create a copy of TimerJob
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? deviceId = null,Object? endOn = null,Object? fireAt = null,Object? tier = null,Object? status = null,Object? meta = null,Object? createdAt = null,}) {
  return _then(TimerJob(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,endOn: null == endOn ? _self.endOn : endOn // ignore: cast_nullable_to_non_nullable
as bool,fireAt: null == fireAt ? _self.fireAt : fireAt // ignore: cast_nullable_to_non_nullable
as DateTime,tier: null == tier ? _self.tier : tier // ignore: cast_nullable_to_non_nullable
as TimerTier,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TimerStatus,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [TimerJob].
extension TimerJobPatterns on TimerJob {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TimerJob value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TimerJob() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TimerJob value)  $default,){
final _that = this;
switch (_that) {
case _TimerJob():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TimerJob value)?  $default,){
final _that = this;
switch (_that) {
case _TimerJob() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String deviceId,  bool endOn,  DateTime fireAt,  TimerTier tier,  TimerStatus status,  Map<String, String> meta,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TimerJob() when $default != null:
return $default(_that.id,_that.deviceId,_that.endOn,_that.fireAt,_that.tier,_that.status,_that.meta,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String deviceId,  bool endOn,  DateTime fireAt,  TimerTier tier,  TimerStatus status,  Map<String, String> meta,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _TimerJob():
return $default(_that.id,_that.deviceId,_that.endOn,_that.fireAt,_that.tier,_that.status,_that.meta,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String deviceId,  bool endOn,  DateTime fireAt,  TimerTier tier,  TimerStatus status,  Map<String, String> meta,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _TimerJob() when $default != null:
return $default(_that.id,_that.deviceId,_that.endOn,_that.fireAt,_that.tier,_that.status,_that.meta,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@UtcDateTimeConverter()
class _TimerJob implements TimerJob {
  const _TimerJob({required this.id, required this.deviceId, required this.endOn, required this.fireAt, required this.tier, this.status = TimerStatus.active,  Map<String, String> meta = const <String, String>{}, required this.createdAt}): _meta = meta;
  factory _TimerJob.fromJson(Map<String, dynamic> json) => _$TimerJobFromJson(json);

@override final  String id;
@override final  String deviceId;
/// The power state the device ends in when the timer fires.
@override final  bool endOn;
@override final  DateTime fireAt;
@override final  TimerTier tier;
@override@JsonKey() final  TimerStatus status;
/// Adapter countdown handle (e.g. Hue scheduleId). PSEUDOCODE §5.
 final  Map<String, String> _meta;
/// Adapter countdown handle (e.g. Hue scheduleId). PSEUDOCODE §5.
@override@JsonKey() Map<String, String> get meta {
  if (_meta is EqualUnmodifiableMapView) return _meta;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_meta);
}

@override final  DateTime createdAt;

/// Create a copy of TimerJob
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TimerJobCopyWith<_TimerJob> get copyWith => __$TimerJobCopyWithImpl<_TimerJob>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TimerJobToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TimerJob&&(identical(other.id, id) || other.id == id)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.endOn, endOn) || other.endOn == endOn)&&(identical(other.fireAt, fireAt) || other.fireAt == fireAt)&&(identical(other.tier, tier) || other.tier == tier)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.meta, _meta)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,deviceId,endOn,fireAt,tier,status,const DeepCollectionEquality().hash(_meta),createdAt);
}

@override
String toString() {
    return 'TimerJob(id: $id, deviceId: $deviceId, endOn: $endOn, fireAt: $fireAt, tier: $tier, status: $status, meta: $meta, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$TimerJobCopyWith<$Res> implements $TimerJobCopyWith<$Res> {
  factory _$TimerJobCopyWith(_TimerJob value, $Res Function(_TimerJob) _then) = __$TimerJobCopyWithImpl;
@override @useResult
$Res call({
 String id, String deviceId, bool endOn, DateTime fireAt, TimerTier tier, TimerStatus status, Map<String, String> meta, DateTime createdAt
});




}
/// @nodoc
class __$TimerJobCopyWithImpl<$Res>
    implements _$TimerJobCopyWith<$Res> {
  __$TimerJobCopyWithImpl(this._self, this._then);

  final _TimerJob _self;
  final $Res Function(_TimerJob) _then;

/// Create a copy of TimerJob
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? deviceId = null,Object? endOn = null,Object? fireAt = null,Object? tier = null,Object? status = null,Object? meta = null,Object? createdAt = null,}) {
  return _then(_TimerJob(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,endOn: null == endOn ? _self.endOn : endOn // ignore: cast_nullable_to_non_nullable
as bool,fireAt: null == fireAt ? _self.fireAt : fireAt // ignore: cast_nullable_to_non_nullable
as DateTime,tier: null == tier ? _self.tier : tier // ignore: cast_nullable_to_non_nullable
as TimerTier,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TimerStatus,meta: null == meta ? _self._meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$Candidate {

 String get ip; String? get mac; int? get port; Brand get brand; String get protocol; String? get version; String? get deviceId; String? get name; bool get needsKey;/// Human-readable reasons for the identification, for diagnostics.
 List<String> get evidence;
/// Create a copy of Candidate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CandidateCopyWith<Candidate> get copyWith => _$CandidateCopyWithImpl<Candidate>(this as Candidate, _$identity);

  /// Serializes this Candidate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Candidate;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Candidate&&(identical(other.ip, _this.ip) || other.ip == _this.ip)&&(identical(other.mac, _this.mac) || other.mac == _this.mac)&&(identical(other.port, _this.port) || other.port == _this.port)&&(identical(other.brand, _this.brand) || other.brand == _this.brand)&&(identical(other.protocol, _this.protocol) || other.protocol == _this.protocol)&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.deviceId, _this.deviceId) || other.deviceId == _this.deviceId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.needsKey, _this.needsKey) || other.needsKey == _this.needsKey)&&const DeepCollectionEquality().equals(other.evidence, _this.evidence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Candidate;
  return Object.hash(runtimeType,_this.ip,_this.mac,_this.port,_this.brand,_this.protocol,_this.version,_this.deviceId,_this.name,_this.needsKey,const DeepCollectionEquality().hash(_this.evidence));
}

@override
String toString() {
  final _this = this as Candidate;
  return 'Candidate(ip: ${_this.ip}, mac: ${_this.mac}, port: ${_this.port}, brand: ${_this.brand}, protocol: ${_this.protocol}, version: ${_this.version}, deviceId: ${_this.deviceId}, name: ${_this.name}, needsKey: ${_this.needsKey}, evidence: ${_this.evidence})';
}


}

/// @nodoc
abstract mixin class $CandidateCopyWith<$Res>  {
  factory $CandidateCopyWith(Candidate value, $Res Function(Candidate) _then) = _$CandidateCopyWithImpl;
@useResult
$Res call({
 String ip, String? mac, int? port, Brand brand, String protocol, String? version, String? deviceId, String? name, bool needsKey, List<String> evidence
});




}
/// @nodoc
class _$CandidateCopyWithImpl<$Res>
    implements $CandidateCopyWith<$Res> {
  _$CandidateCopyWithImpl(this._self, this._then);

  final Candidate _self;
  final $Res Function(Candidate) _then;

/// Create a copy of Candidate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ip = null,Object? mac = freezed,Object? port = freezed,Object? brand = null,Object? protocol = null,Object? version = freezed,Object? deviceId = freezed,Object? name = freezed,Object? needsKey = null,Object? evidence = null,}) {
  return _then(Candidate(
ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,mac: freezed == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String?,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int?,brand: null == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as Brand,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as String,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,needsKey: null == needsKey ? _self.needsKey : needsKey // ignore: cast_nullable_to_non_nullable
as bool,evidence: null == evidence ? _self.evidence : evidence // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Candidate].
extension CandidatePatterns on Candidate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Candidate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Candidate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Candidate value)  $default,){
final _that = this;
switch (_that) {
case _Candidate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Candidate value)?  $default,){
final _that = this;
switch (_that) {
case _Candidate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ip,  String? mac,  int? port,  Brand brand,  String protocol,  String? version,  String? deviceId,  String? name,  bool needsKey,  List<String> evidence)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Candidate() when $default != null:
return $default(_that.ip,_that.mac,_that.port,_that.brand,_that.protocol,_that.version,_that.deviceId,_that.name,_that.needsKey,_that.evidence);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ip,  String? mac,  int? port,  Brand brand,  String protocol,  String? version,  String? deviceId,  String? name,  bool needsKey,  List<String> evidence)  $default,) {final _that = this;
switch (_that) {
case _Candidate():
return $default(_that.ip,_that.mac,_that.port,_that.brand,_that.protocol,_that.version,_that.deviceId,_that.name,_that.needsKey,_that.evidence);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ip,  String? mac,  int? port,  Brand brand,  String protocol,  String? version,  String? deviceId,  String? name,  bool needsKey,  List<String> evidence)?  $default,) {final _that = this;
switch (_that) {
case _Candidate() when $default != null:
return $default(_that.ip,_that.mac,_that.port,_that.brand,_that.protocol,_that.version,_that.deviceId,_that.name,_that.needsKey,_that.evidence);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Candidate implements Candidate {
  const _Candidate({required this.ip, this.mac, this.port, required this.brand, required this.protocol, this.version, this.deviceId, this.name, this.needsKey = false,  List<String> evidence = const <String>[]}): _evidence = evidence;
  factory _Candidate.fromJson(Map<String, dynamic> json) => _$CandidateFromJson(json);

@override final  String ip;
@override final  String? mac;
@override final  int? port;
@override final  Brand brand;
@override final  String protocol;
@override final  String? version;
@override final  String? deviceId;
@override final  String? name;
@override@JsonKey() final  bool needsKey;
/// Human-readable reasons for the identification, for diagnostics.
 final  List<String> _evidence;
/// Human-readable reasons for the identification, for diagnostics.
@override@JsonKey() List<String> get evidence {
  if (_evidence is EqualUnmodifiableListView) return _evidence;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_evidence);
}


/// Create a copy of Candidate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CandidateCopyWith<_Candidate> get copyWith => __$CandidateCopyWithImpl<_Candidate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CandidateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Candidate&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.mac, mac) || other.mac == mac)&&(identical(other.port, port) || other.port == port)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.version, version) || other.version == version)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.needsKey, needsKey) || other.needsKey == needsKey)&&const DeepCollectionEquality().equals(other.evidence, _evidence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,ip,mac,port,brand,protocol,version,deviceId,name,needsKey,const DeepCollectionEquality().hash(_evidence));
}

@override
String toString() {
    return 'Candidate(ip: $ip, mac: $mac, port: $port, brand: $brand, protocol: $protocol, version: $version, deviceId: $deviceId, name: $name, needsKey: $needsKey, evidence: $evidence)';
}


}

/// @nodoc
abstract mixin class _$CandidateCopyWith<$Res> implements $CandidateCopyWith<$Res> {
  factory _$CandidateCopyWith(_Candidate value, $Res Function(_Candidate) _then) = __$CandidateCopyWithImpl;
@override @useResult
$Res call({
 String ip, String? mac, int? port, Brand brand, String protocol, String? version, String? deviceId, String? name, bool needsKey, List<String> evidence
});




}
/// @nodoc
class __$CandidateCopyWithImpl<$Res>
    implements _$CandidateCopyWith<$Res> {
  __$CandidateCopyWithImpl(this._self, this._then);

  final _Candidate _self;
  final $Res Function(_Candidate) _then;

/// Create a copy of Candidate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ip = null,Object? mac = freezed,Object? port = freezed,Object? brand = null,Object? protocol = null,Object? version = freezed,Object? deviceId = freezed,Object? name = freezed,Object? needsKey = null,Object? evidence = null,}) {
  return _then(_Candidate(
ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,mac: freezed == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as String?,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int?,brand: null == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as Brand,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as String,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,needsKey: null == needsKey ? _self.needsKey : needsKey // ignore: cast_nullable_to_non_nullable
as bool,evidence: null == evidence ? _self._evidence : evidence // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
