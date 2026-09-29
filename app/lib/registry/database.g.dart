// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RoomsTable extends Rooms with TableInfo<$RoomsTable, RoomRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoomsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<int> sort = GeneratedColumn<int>(
    'sort',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, sort];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rooms';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoomRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoomRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoomRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort'],
      )!,
    );
  }

  @override
  $RoomsTable createAlias(String alias) {
    return $RoomsTable(attachedDatabase, alias);
  }
}

class RoomRow extends DataClass implements Insertable<RoomRow> {
  final String id;
  final String name;
  final int sort;
  const RoomRow({required this.id, required this.name, required this.sort});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['sort'] = Variable<int>(sort);
    return map;
  }

  RoomsCompanion toCompanion(bool nullToAbsent) {
    return RoomsCompanion(id: Value(id), name: Value(name), sort: Value(sort));
  }

  factory RoomRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoomRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sort: serializer.fromJson<int>(json['sort']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sort': serializer.toJson<int>(sort),
    };
  }

  RoomRow copyWith({String? id, String? name, int? sort}) => RoomRow(
    id: id ?? this.id,
    name: name ?? this.name,
    sort: sort ?? this.sort,
  );
  RoomRow copyWithCompanion(RoomsCompanion data) {
    return RoomRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sort: data.sort.present ? data.sort.value : this.sort,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoomRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sort: $sort')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sort);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoomRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.sort == this.sort);
}

class RoomsCompanion extends UpdateCompanion<RoomRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> sort;
  final Value<int> rowid;
  const RoomsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sort = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoomsCompanion.insert({
    required String id,
    required String name,
    this.sort = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<RoomRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? sort,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sort != null) 'sort': sort,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoomsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? sort,
    Value<int>? rowid,
  }) {
    return RoomsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sort: sort ?? this.sort,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sort.present) {
      map['sort'] = Variable<int>(sort.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoomsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sort: $sort, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DevicesTable extends Devices with TableInfo<$DevicesTable, DeviceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Brand, String> brand =
      GeneratedColumn<String>(
        'brand',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Brand>($DevicesTable.$converterbrand);
  static const VerificationMeta _protocolMeta = const VerificationMeta(
    'protocol',
  );
  @override
  late final GeneratedColumn<String> protocol = GeneratedColumn<String>(
    'protocol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ipMeta = const VerificationMeta('ip');
  @override
  late final GeneratedColumn<String> ip = GeneratedColumn<String>(
    'ip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _macMeta = const VerificationMeta('mac');
  @override
  late final GeneratedColumn<String> mac = GeneratedColumn<String>(
    'mac',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  @override
  late final GeneratedColumn<String> roomId = GeneratedColumn<String>(
    'room_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES rooms (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _capabilitiesJsonMeta = const VerificationMeta(
    'capabilitiesJson',
  );
  @override
  late final GeneratedColumn<String> capabilitiesJson = GeneratedColumn<String>(
    'capabilities_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dpMapJsonMeta = const VerificationMeta(
    'dpMapJson',
  );
  @override
  late final GeneratedColumn<String> dpMapJson = GeneratedColumn<String>(
    'dp_map_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nativeCountdownMaxSMeta =
      const VerificationMeta('nativeCountdownMaxS');
  @override
  late final GeneratedColumn<int> nativeCountdownMaxS = GeneratedColumn<int>(
    'native_countdown_max_s',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultAutoOffSMeta = const VerificationMeta(
    'defaultAutoOffS',
  );
  @override
  late final GeneratedColumn<int> defaultAutoOffS = GeneratedColumn<int>(
    'default_auto_off_s',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metaJsonMeta = const VerificationMeta(
    'metaJson',
  );
  @override
  late final GeneratedColumn<String> metaJson = GeneratedColumn<String>(
    'meta_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
    'last_seen',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    brand,
    protocol,
    ip,
    mac,
    port,
    name,
    roomId,
    capabilitiesJson,
    dpMapJson,
    nativeCountdownMaxS,
    defaultAutoOffS,
    metaJson,
    lastSeen,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('protocol')) {
      context.handle(
        _protocolMeta,
        protocol.isAcceptableOrUnknown(data['protocol']!, _protocolMeta),
      );
    } else if (isInserting) {
      context.missing(_protocolMeta);
    }
    if (data.containsKey('ip')) {
      context.handle(_ipMeta, ip.isAcceptableOrUnknown(data['ip']!, _ipMeta));
    } else if (isInserting) {
      context.missing(_ipMeta);
    }
    if (data.containsKey('mac')) {
      context.handle(
        _macMeta,
        mac.isAcceptableOrUnknown(data['mac']!, _macMeta),
      );
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('room_id')) {
      context.handle(
        _roomIdMeta,
        roomId.isAcceptableOrUnknown(data['room_id']!, _roomIdMeta),
      );
    }
    if (data.containsKey('capabilities_json')) {
      context.handle(
        _capabilitiesJsonMeta,
        capabilitiesJson.isAcceptableOrUnknown(
          data['capabilities_json']!,
          _capabilitiesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capabilitiesJsonMeta);
    }
    if (data.containsKey('dp_map_json')) {
      context.handle(
        _dpMapJsonMeta,
        dpMapJson.isAcceptableOrUnknown(data['dp_map_json']!, _dpMapJsonMeta),
      );
    }
    if (data.containsKey('native_countdown_max_s')) {
      context.handle(
        _nativeCountdownMaxSMeta,
        nativeCountdownMaxS.isAcceptableOrUnknown(
          data['native_countdown_max_s']!,
          _nativeCountdownMaxSMeta,
        ),
      );
    }
    if (data.containsKey('default_auto_off_s')) {
      context.handle(
        _defaultAutoOffSMeta,
        defaultAutoOffS.isAcceptableOrUnknown(
          data['default_auto_off_s']!,
          _defaultAutoOffSMeta,
        ),
      );
    }
    if (data.containsKey('meta_json')) {
      context.handle(
        _metaJsonMeta,
        metaJson.isAcceptableOrUnknown(data['meta_json']!, _metaJsonMeta),
      );
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_lastSeenMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeviceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      brand: $DevicesTable.$converterbrand.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}brand'],
        )!,
      ),
      protocol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}protocol'],
      )!,
      ip: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ip'],
      )!,
      mac: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mac'],
      ),
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      roomId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_id'],
      ),
      capabilitiesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities_json'],
      )!,
      dpMapJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dp_map_json'],
      ),
      nativeCountdownMaxS: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}native_countdown_max_s'],
      ),
      defaultAutoOffS: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_auto_off_s'],
      ),
      metaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta_json'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen'],
      )!,
    );
  }

  @override
  $DevicesTable createAlias(String alias) {
    return $DevicesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Brand, String, String> $converterbrand =
      const EnumNameConverter<Brand>(Brand.values);
}

class DeviceRow extends DataClass implements Insertable<DeviceRow> {
  final String id;
  final Brand brand;
  final String protocol;
  final String ip;
  final String? mac;
  final int? port;
  final String name;
  final String? roomId;

  /// JSON list of [Capability] names.
  final String capabilitiesJson;

  /// JSON object, Tuya only.
  final String? dpMapJson;
  final int? nativeCountdownMaxS;
  final int? defaultAutoOffS;
  final String metaJson;
  final DateTime lastSeen;
  const DeviceRow({
    required this.id,
    required this.brand,
    required this.protocol,
    required this.ip,
    this.mac,
    this.port,
    required this.name,
    this.roomId,
    required this.capabilitiesJson,
    this.dpMapJson,
    this.nativeCountdownMaxS,
    this.defaultAutoOffS,
    required this.metaJson,
    required this.lastSeen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['brand'] = Variable<String>(
        $DevicesTable.$converterbrand.toSql(brand),
      );
    }
    map['protocol'] = Variable<String>(protocol);
    map['ip'] = Variable<String>(ip);
    if (!nullToAbsent || mac != null) {
      map['mac'] = Variable<String>(mac);
    }
    if (!nullToAbsent || port != null) {
      map['port'] = Variable<int>(port);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || roomId != null) {
      map['room_id'] = Variable<String>(roomId);
    }
    map['capabilities_json'] = Variable<String>(capabilitiesJson);
    if (!nullToAbsent || dpMapJson != null) {
      map['dp_map_json'] = Variable<String>(dpMapJson);
    }
    if (!nullToAbsent || nativeCountdownMaxS != null) {
      map['native_countdown_max_s'] = Variable<int>(nativeCountdownMaxS);
    }
    if (!nullToAbsent || defaultAutoOffS != null) {
      map['default_auto_off_s'] = Variable<int>(defaultAutoOffS);
    }
    map['meta_json'] = Variable<String>(metaJson);
    map['last_seen'] = Variable<DateTime>(lastSeen);
    return map;
  }

  DevicesCompanion toCompanion(bool nullToAbsent) {
    return DevicesCompanion(
      id: Value(id),
      brand: Value(brand),
      protocol: Value(protocol),
      ip: Value(ip),
      mac: mac == null && nullToAbsent ? const Value.absent() : Value(mac),
      port: port == null && nullToAbsent ? const Value.absent() : Value(port),
      name: Value(name),
      roomId: roomId == null && nullToAbsent
          ? const Value.absent()
          : Value(roomId),
      capabilitiesJson: Value(capabilitiesJson),
      dpMapJson: dpMapJson == null && nullToAbsent
          ? const Value.absent()
          : Value(dpMapJson),
      nativeCountdownMaxS: nativeCountdownMaxS == null && nullToAbsent
          ? const Value.absent()
          : Value(nativeCountdownMaxS),
      defaultAutoOffS: defaultAutoOffS == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultAutoOffS),
      metaJson: Value(metaJson),
      lastSeen: Value(lastSeen),
    );
  }

  factory DeviceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceRow(
      id: serializer.fromJson<String>(json['id']),
      brand: $DevicesTable.$converterbrand.fromJson(
        serializer.fromJson<String>(json['brand']),
      ),
      protocol: serializer.fromJson<String>(json['protocol']),
      ip: serializer.fromJson<String>(json['ip']),
      mac: serializer.fromJson<String?>(json['mac']),
      port: serializer.fromJson<int?>(json['port']),
      name: serializer.fromJson<String>(json['name']),
      roomId: serializer.fromJson<String?>(json['roomId']),
      capabilitiesJson: serializer.fromJson<String>(json['capabilitiesJson']),
      dpMapJson: serializer.fromJson<String?>(json['dpMapJson']),
      nativeCountdownMaxS: serializer.fromJson<int?>(
        json['nativeCountdownMaxS'],
      ),
      defaultAutoOffS: serializer.fromJson<int?>(json['defaultAutoOffS']),
      metaJson: serializer.fromJson<String>(json['metaJson']),
      lastSeen: serializer.fromJson<DateTime>(json['lastSeen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'brand': serializer.toJson<String>(
        $DevicesTable.$converterbrand.toJson(brand),
      ),
      'protocol': serializer.toJson<String>(protocol),
      'ip': serializer.toJson<String>(ip),
      'mac': serializer.toJson<String?>(mac),
      'port': serializer.toJson<int?>(port),
      'name': serializer.toJson<String>(name),
      'roomId': serializer.toJson<String?>(roomId),
      'capabilitiesJson': serializer.toJson<String>(capabilitiesJson),
      'dpMapJson': serializer.toJson<String?>(dpMapJson),
      'nativeCountdownMaxS': serializer.toJson<int?>(nativeCountdownMaxS),
      'defaultAutoOffS': serializer.toJson<int?>(defaultAutoOffS),
      'metaJson': serializer.toJson<String>(metaJson),
      'lastSeen': serializer.toJson<DateTime>(lastSeen),
    };
  }

  DeviceRow copyWith({
    String? id,
    Brand? brand,
    String? protocol,
    String? ip,
    Value<String?> mac = const Value.absent(),
    Value<int?> port = const Value.absent(),
    String? name,
    Value<String?> roomId = const Value.absent(),
    String? capabilitiesJson,
    Value<String?> dpMapJson = const Value.absent(),
    Value<int?> nativeCountdownMaxS = const Value.absent(),
    Value<int?> defaultAutoOffS = const Value.absent(),
    String? metaJson,
    DateTime? lastSeen,
  }) => DeviceRow(
    id: id ?? this.id,
    brand: brand ?? this.brand,
    protocol: protocol ?? this.protocol,
    ip: ip ?? this.ip,
    mac: mac.present ? mac.value : this.mac,
    port: port.present ? port.value : this.port,
    name: name ?? this.name,
    roomId: roomId.present ? roomId.value : this.roomId,
    capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
    dpMapJson: dpMapJson.present ? dpMapJson.value : this.dpMapJson,
    nativeCountdownMaxS: nativeCountdownMaxS.present
        ? nativeCountdownMaxS.value
        : this.nativeCountdownMaxS,
    defaultAutoOffS: defaultAutoOffS.present
        ? defaultAutoOffS.value
        : this.defaultAutoOffS,
    metaJson: metaJson ?? this.metaJson,
    lastSeen: lastSeen ?? this.lastSeen,
  );
  DeviceRow copyWithCompanion(DevicesCompanion data) {
    return DeviceRow(
      id: data.id.present ? data.id.value : this.id,
      brand: data.brand.present ? data.brand.value : this.brand,
      protocol: data.protocol.present ? data.protocol.value : this.protocol,
      ip: data.ip.present ? data.ip.value : this.ip,
      mac: data.mac.present ? data.mac.value : this.mac,
      port: data.port.present ? data.port.value : this.port,
      name: data.name.present ? data.name.value : this.name,
      roomId: data.roomId.present ? data.roomId.value : this.roomId,
      capabilitiesJson: data.capabilitiesJson.present
          ? data.capabilitiesJson.value
          : this.capabilitiesJson,
      dpMapJson: data.dpMapJson.present ? data.dpMapJson.value : this.dpMapJson,
      nativeCountdownMaxS: data.nativeCountdownMaxS.present
          ? data.nativeCountdownMaxS.value
          : this.nativeCountdownMaxS,
      defaultAutoOffS: data.defaultAutoOffS.present
          ? data.defaultAutoOffS.value
          : this.defaultAutoOffS,
      metaJson: data.metaJson.present ? data.metaJson.value : this.metaJson,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceRow(')
          ..write('id: $id, ')
          ..write('brand: $brand, ')
          ..write('protocol: $protocol, ')
          ..write('ip: $ip, ')
          ..write('mac: $mac, ')
          ..write('port: $port, ')
          ..write('name: $name, ')
          ..write('roomId: $roomId, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('dpMapJson: $dpMapJson, ')
          ..write('nativeCountdownMaxS: $nativeCountdownMaxS, ')
          ..write('defaultAutoOffS: $defaultAutoOffS, ')
          ..write('metaJson: $metaJson, ')
          ..write('lastSeen: $lastSeen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    brand,
    protocol,
    ip,
    mac,
    port,
    name,
    roomId,
    capabilitiesJson,
    dpMapJson,
    nativeCountdownMaxS,
    defaultAutoOffS,
    metaJson,
    lastSeen,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceRow &&
          other.id == this.id &&
          other.brand == this.brand &&
          other.protocol == this.protocol &&
          other.ip == this.ip &&
          other.mac == this.mac &&
          other.port == this.port &&
          other.name == this.name &&
          other.roomId == this.roomId &&
          other.capabilitiesJson == this.capabilitiesJson &&
          other.dpMapJson == this.dpMapJson &&
          other.nativeCountdownMaxS == this.nativeCountdownMaxS &&
          other.defaultAutoOffS == this.defaultAutoOffS &&
          other.metaJson == this.metaJson &&
          other.lastSeen == this.lastSeen);
}

class DevicesCompanion extends UpdateCompanion<DeviceRow> {
  final Value<String> id;
  final Value<Brand> brand;
  final Value<String> protocol;
  final Value<String> ip;
  final Value<String?> mac;
  final Value<int?> port;
  final Value<String> name;
  final Value<String?> roomId;
  final Value<String> capabilitiesJson;
  final Value<String?> dpMapJson;
  final Value<int?> nativeCountdownMaxS;
  final Value<int?> defaultAutoOffS;
  final Value<String> metaJson;
  final Value<DateTime> lastSeen;
  final Value<int> rowid;
  const DevicesCompanion({
    this.id = const Value.absent(),
    this.brand = const Value.absent(),
    this.protocol = const Value.absent(),
    this.ip = const Value.absent(),
    this.mac = const Value.absent(),
    this.port = const Value.absent(),
    this.name = const Value.absent(),
    this.roomId = const Value.absent(),
    this.capabilitiesJson = const Value.absent(),
    this.dpMapJson = const Value.absent(),
    this.nativeCountdownMaxS = const Value.absent(),
    this.defaultAutoOffS = const Value.absent(),
    this.metaJson = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DevicesCompanion.insert({
    required String id,
    required Brand brand,
    required String protocol,
    required String ip,
    this.mac = const Value.absent(),
    this.port = const Value.absent(),
    required String name,
    this.roomId = const Value.absent(),
    required String capabilitiesJson,
    this.dpMapJson = const Value.absent(),
    this.nativeCountdownMaxS = const Value.absent(),
    this.defaultAutoOffS = const Value.absent(),
    this.metaJson = const Value.absent(),
    required DateTime lastSeen,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       brand = Value(brand),
       protocol = Value(protocol),
       ip = Value(ip),
       name = Value(name),
       capabilitiesJson = Value(capabilitiesJson),
       lastSeen = Value(lastSeen);
  static Insertable<DeviceRow> custom({
    Expression<String>? id,
    Expression<String>? brand,
    Expression<String>? protocol,
    Expression<String>? ip,
    Expression<String>? mac,
    Expression<int>? port,
    Expression<String>? name,
    Expression<String>? roomId,
    Expression<String>? capabilitiesJson,
    Expression<String>? dpMapJson,
    Expression<int>? nativeCountdownMaxS,
    Expression<int>? defaultAutoOffS,
    Expression<String>? metaJson,
    Expression<DateTime>? lastSeen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (brand != null) 'brand': brand,
      if (protocol != null) 'protocol': protocol,
      if (ip != null) 'ip': ip,
      if (mac != null) 'mac': mac,
      if (port != null) 'port': port,
      if (name != null) 'name': name,
      if (roomId != null) 'room_id': roomId,
      if (capabilitiesJson != null) 'capabilities_json': capabilitiesJson,
      if (dpMapJson != null) 'dp_map_json': dpMapJson,
      if (nativeCountdownMaxS != null)
        'native_countdown_max_s': nativeCountdownMaxS,
      if (defaultAutoOffS != null) 'default_auto_off_s': defaultAutoOffS,
      if (metaJson != null) 'meta_json': metaJson,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DevicesCompanion copyWith({
    Value<String>? id,
    Value<Brand>? brand,
    Value<String>? protocol,
    Value<String>? ip,
    Value<String?>? mac,
    Value<int?>? port,
    Value<String>? name,
    Value<String?>? roomId,
    Value<String>? capabilitiesJson,
    Value<String?>? dpMapJson,
    Value<int?>? nativeCountdownMaxS,
    Value<int?>? defaultAutoOffS,
    Value<String>? metaJson,
    Value<DateTime>? lastSeen,
    Value<int>? rowid,
  }) {
    return DevicesCompanion(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      protocol: protocol ?? this.protocol,
      ip: ip ?? this.ip,
      mac: mac ?? this.mac,
      port: port ?? this.port,
      name: name ?? this.name,
      roomId: roomId ?? this.roomId,
      capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
      dpMapJson: dpMapJson ?? this.dpMapJson,
      nativeCountdownMaxS: nativeCountdownMaxS ?? this.nativeCountdownMaxS,
      defaultAutoOffS: defaultAutoOffS ?? this.defaultAutoOffS,
      metaJson: metaJson ?? this.metaJson,
      lastSeen: lastSeen ?? this.lastSeen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(
        $DevicesTable.$converterbrand.toSql(brand.value),
      );
    }
    if (protocol.present) {
      map['protocol'] = Variable<String>(protocol.value);
    }
    if (ip.present) {
      map['ip'] = Variable<String>(ip.value);
    }
    if (mac.present) {
      map['mac'] = Variable<String>(mac.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (capabilitiesJson.present) {
      map['capabilities_json'] = Variable<String>(capabilitiesJson.value);
    }
    if (dpMapJson.present) {
      map['dp_map_json'] = Variable<String>(dpMapJson.value);
    }
    if (nativeCountdownMaxS.present) {
      map['native_countdown_max_s'] = Variable<int>(nativeCountdownMaxS.value);
    }
    if (defaultAutoOffS.present) {
      map['default_auto_off_s'] = Variable<int>(defaultAutoOffS.value);
    }
    if (metaJson.present) {
      map['meta_json'] = Variable<String>(metaJson.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DevicesCompanion(')
          ..write('id: $id, ')
          ..write('brand: $brand, ')
          ..write('protocol: $protocol, ')
          ..write('ip: $ip, ')
          ..write('mac: $mac, ')
          ..write('port: $port, ')
          ..write('name: $name, ')
          ..write('roomId: $roomId, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('dpMapJson: $dpMapJson, ')
          ..write('nativeCountdownMaxS: $nativeCountdownMaxS, ')
          ..write('defaultAutoOffS: $defaultAutoOffS, ')
          ..write('metaJson: $metaJson, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AliasesTable extends Aliases with TableInfo<$AliasesTable, AliasRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AliasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES devices (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
    'alias',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AliasLang, String> lang =
      GeneratedColumn<String>(
        'lang',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AliasLang>($AliasesTable.$converterlang);
  @override
  List<GeneratedColumn> get $columns => [id, deviceId, alias, lang];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'aliases';
  @override
  VerificationContext validateIntegrity(
    Insertable<AliasRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('alias')) {
      context.handle(
        _aliasMeta,
        alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta),
      );
    } else if (isInserting) {
      context.missing(_aliasMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AliasRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AliasRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      alias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias'],
      )!,
      lang: $AliasesTable.$converterlang.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}lang'],
        )!,
      ),
    );
  }

  @override
  $AliasesTable createAlias(String alias) {
    return $AliasesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AliasLang, String, String> $converterlang =
      const EnumNameConverter<AliasLang>(AliasLang.values);
}

class AliasRow extends DataClass implements Insertable<AliasRow> {
  final String id;
  final String deviceId;
  final String alias;
  final AliasLang lang;
  const AliasRow({
    required this.id,
    required this.deviceId,
    required this.alias,
    required this.lang,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['alias'] = Variable<String>(alias);
    {
      map['lang'] = Variable<String>($AliasesTable.$converterlang.toSql(lang));
    }
    return map;
  }

  AliasesCompanion toCompanion(bool nullToAbsent) {
    return AliasesCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      alias: Value(alias),
      lang: Value(lang),
    );
  }

  factory AliasRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AliasRow(
      id: serializer.fromJson<String>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      alias: serializer.fromJson<String>(json['alias']),
      lang: $AliasesTable.$converterlang.fromJson(
        serializer.fromJson<String>(json['lang']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'alias': serializer.toJson<String>(alias),
      'lang': serializer.toJson<String>(
        $AliasesTable.$converterlang.toJson(lang),
      ),
    };
  }

  AliasRow copyWith({
    String? id,
    String? deviceId,
    String? alias,
    AliasLang? lang,
  }) => AliasRow(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    alias: alias ?? this.alias,
    lang: lang ?? this.lang,
  );
  AliasRow copyWithCompanion(AliasesCompanion data) {
    return AliasRow(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      alias: data.alias.present ? data.alias.value : this.alias,
      lang: data.lang.present ? data.lang.value : this.lang,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AliasRow(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('alias: $alias, ')
          ..write('lang: $lang')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, deviceId, alias, lang);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AliasRow &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.alias == this.alias &&
          other.lang == this.lang);
}

class AliasesCompanion extends UpdateCompanion<AliasRow> {
  final Value<String> id;
  final Value<String> deviceId;
  final Value<String> alias;
  final Value<AliasLang> lang;
  final Value<int> rowid;
  const AliasesCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.alias = const Value.absent(),
    this.lang = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AliasesCompanion.insert({
    required String id,
    required String deviceId,
    required String alias,
    required AliasLang lang,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deviceId = Value(deviceId),
       alias = Value(alias),
       lang = Value(lang);
  static Insertable<AliasRow> custom({
    Expression<String>? id,
    Expression<String>? deviceId,
    Expression<String>? alias,
    Expression<String>? lang,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (alias != null) 'alias': alias,
      if (lang != null) 'lang': lang,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AliasesCompanion copyWith({
    Value<String>? id,
    Value<String>? deviceId,
    Value<String>? alias,
    Value<AliasLang>? lang,
    Value<int>? rowid,
  }) {
    return AliasesCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      alias: alias ?? this.alias,
      lang: lang ?? this.lang,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (lang.present) {
      map['lang'] = Variable<String>(
        $AliasesTable.$converterlang.toSql(lang.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AliasesCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('alias: $alias, ')
          ..write('lang: $lang, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimerJobsTable extends TimerJobs
    with TableInfo<$TimerJobsTable, TimerJobRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimerJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES devices (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _endOnMeta = const VerificationMeta('endOn');
  @override
  late final GeneratedColumn<bool> endOn = GeneratedColumn<bool>(
    'end_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("end_on" IN (0, 1))',
    ),
  );
  static const VerificationMeta _fireAtMeta = const VerificationMeta('fireAt');
  @override
  late final GeneratedColumn<DateTime> fireAt = GeneratedColumn<DateTime>(
    'fire_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TimerTier, String> tier =
      GeneratedColumn<String>(
        'tier',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TimerTier>($TimerJobsTable.$convertertier);
  @override
  late final GeneratedColumnWithTypeConverter<TimerStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TimerStatus>($TimerJobsTable.$converterstatus);
  static const VerificationMeta _metaJsonMeta = const VerificationMeta(
    'metaJson',
  );
  @override
  late final GeneratedColumn<String> metaJson = GeneratedColumn<String>(
    'meta_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceId,
    endOn,
    fireAt,
    tier,
    status,
    metaJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'timer_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimerJobRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('end_on')) {
      context.handle(
        _endOnMeta,
        endOn.isAcceptableOrUnknown(data['end_on']!, _endOnMeta),
      );
    } else if (isInserting) {
      context.missing(_endOnMeta);
    }
    if (data.containsKey('fire_at')) {
      context.handle(
        _fireAtMeta,
        fireAt.isAcceptableOrUnknown(data['fire_at']!, _fireAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fireAtMeta);
    }
    if (data.containsKey('meta_json')) {
      context.handle(
        _metaJsonMeta,
        metaJson.isAcceptableOrUnknown(data['meta_json']!, _metaJsonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimerJobRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimerJobRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      endOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}end_on'],
      )!,
      fireAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fire_at'],
      )!,
      tier: $TimerJobsTable.$convertertier.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tier'],
        )!,
      ),
      status: $TimerJobsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      metaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TimerJobsTable createAlias(String alias) {
    return $TimerJobsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TimerTier, String, String> $convertertier =
      const EnumNameConverter<TimerTier>(TimerTier.values);
  static JsonTypeConverter2<TimerStatus, String, String> $converterstatus =
      const EnumNameConverter<TimerStatus>(TimerStatus.values);
}

class TimerJobRow extends DataClass implements Insertable<TimerJobRow> {
  final String id;
  final String deviceId;
  final bool endOn;
  final DateTime fireAt;
  final TimerTier tier;
  final TimerStatus status;
  final String metaJson;
  final DateTime createdAt;
  const TimerJobRow({
    required this.id,
    required this.deviceId,
    required this.endOn,
    required this.fireAt,
    required this.tier,
    required this.status,
    required this.metaJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['end_on'] = Variable<bool>(endOn);
    map['fire_at'] = Variable<DateTime>(fireAt);
    {
      map['tier'] = Variable<String>(
        $TimerJobsTable.$convertertier.toSql(tier),
      );
    }
    {
      map['status'] = Variable<String>(
        $TimerJobsTable.$converterstatus.toSql(status),
      );
    }
    map['meta_json'] = Variable<String>(metaJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TimerJobsCompanion toCompanion(bool nullToAbsent) {
    return TimerJobsCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      endOn: Value(endOn),
      fireAt: Value(fireAt),
      tier: Value(tier),
      status: Value(status),
      metaJson: Value(metaJson),
      createdAt: Value(createdAt),
    );
  }

  factory TimerJobRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimerJobRow(
      id: serializer.fromJson<String>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      endOn: serializer.fromJson<bool>(json['endOn']),
      fireAt: serializer.fromJson<DateTime>(json['fireAt']),
      tier: $TimerJobsTable.$convertertier.fromJson(
        serializer.fromJson<String>(json['tier']),
      ),
      status: $TimerJobsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      metaJson: serializer.fromJson<String>(json['metaJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'endOn': serializer.toJson<bool>(endOn),
      'fireAt': serializer.toJson<DateTime>(fireAt),
      'tier': serializer.toJson<String>(
        $TimerJobsTable.$convertertier.toJson(tier),
      ),
      'status': serializer.toJson<String>(
        $TimerJobsTable.$converterstatus.toJson(status),
      ),
      'metaJson': serializer.toJson<String>(metaJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TimerJobRow copyWith({
    String? id,
    String? deviceId,
    bool? endOn,
    DateTime? fireAt,
    TimerTier? tier,
    TimerStatus? status,
    String? metaJson,
    DateTime? createdAt,
  }) => TimerJobRow(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    endOn: endOn ?? this.endOn,
    fireAt: fireAt ?? this.fireAt,
    tier: tier ?? this.tier,
    status: status ?? this.status,
    metaJson: metaJson ?? this.metaJson,
    createdAt: createdAt ?? this.createdAt,
  );
  TimerJobRow copyWithCompanion(TimerJobsCompanion data) {
    return TimerJobRow(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      endOn: data.endOn.present ? data.endOn.value : this.endOn,
      fireAt: data.fireAt.present ? data.fireAt.value : this.fireAt,
      tier: data.tier.present ? data.tier.value : this.tier,
      status: data.status.present ? data.status.value : this.status,
      metaJson: data.metaJson.present ? data.metaJson.value : this.metaJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimerJobRow(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('endOn: $endOn, ')
          ..write('fireAt: $fireAt, ')
          ..write('tier: $tier, ')
          ..write('status: $status, ')
          ..write('metaJson: $metaJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    endOn,
    fireAt,
    tier,
    status,
    metaJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimerJobRow &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.endOn == this.endOn &&
          other.fireAt == this.fireAt &&
          other.tier == this.tier &&
          other.status == this.status &&
          other.metaJson == this.metaJson &&
          other.createdAt == this.createdAt);
}

class TimerJobsCompanion extends UpdateCompanion<TimerJobRow> {
  final Value<String> id;
  final Value<String> deviceId;
  final Value<bool> endOn;
  final Value<DateTime> fireAt;
  final Value<TimerTier> tier;
  final Value<TimerStatus> status;
  final Value<String> metaJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TimerJobsCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.endOn = const Value.absent(),
    this.fireAt = const Value.absent(),
    this.tier = const Value.absent(),
    this.status = const Value.absent(),
    this.metaJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimerJobsCompanion.insert({
    required String id,
    required String deviceId,
    required bool endOn,
    required DateTime fireAt,
    required TimerTier tier,
    required TimerStatus status,
    this.metaJson = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deviceId = Value(deviceId),
       endOn = Value(endOn),
       fireAt = Value(fireAt),
       tier = Value(tier),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<TimerJobRow> custom({
    Expression<String>? id,
    Expression<String>? deviceId,
    Expression<bool>? endOn,
    Expression<DateTime>? fireAt,
    Expression<String>? tier,
    Expression<String>? status,
    Expression<String>? metaJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (endOn != null) 'end_on': endOn,
      if (fireAt != null) 'fire_at': fireAt,
      if (tier != null) 'tier': tier,
      if (status != null) 'status': status,
      if (metaJson != null) 'meta_json': metaJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimerJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? deviceId,
    Value<bool>? endOn,
    Value<DateTime>? fireAt,
    Value<TimerTier>? tier,
    Value<TimerStatus>? status,
    Value<String>? metaJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TimerJobsCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      endOn: endOn ?? this.endOn,
      fireAt: fireAt ?? this.fireAt,
      tier: tier ?? this.tier,
      status: status ?? this.status,
      metaJson: metaJson ?? this.metaJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (endOn.present) {
      map['end_on'] = Variable<bool>(endOn.value);
    }
    if (fireAt.present) {
      map['fire_at'] = Variable<DateTime>(fireAt.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(
        $TimerJobsTable.$convertertier.toSql(tier.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $TimerJobsTable.$converterstatus.toSql(status.value),
      );
    }
    if (metaJson.present) {
      map['meta_json'] = Variable<String>(metaJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimerJobsCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('endOn: $endOn, ')
          ..write('fireAt: $fireAt, ')
          ..write('tier: $tier, ')
          ..write('status: $status, ')
          ..write('metaJson: $metaJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeviceStateCacheTable extends DeviceStateCache
    with TableInfo<$DeviceStateCacheTable, StateCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceStateCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES devices (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _stateJsonMeta = const VerificationMeta(
    'stateJson',
  );
  @override
  late final GeneratedColumn<String> stateJson = GeneratedColumn<String>(
    'state_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [deviceId, stateJson, at];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_state_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<StateCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('state_json')) {
      context.handle(
        _stateJsonMeta,
        stateJson.isAcceptableOrUnknown(data['state_json']!, _stateJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_stateJsonMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  StateCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StateCacheRow(
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      stateJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_json'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
    );
  }

  @override
  $DeviceStateCacheTable createAlias(String alias) {
    return $DeviceStateCacheTable(attachedDatabase, alias);
  }
}

class StateCacheRow extends DataClass implements Insertable<StateCacheRow> {
  final String deviceId;

  /// [DeviceState] JSON.
  final String stateJson;
  final DateTime at;
  const StateCacheRow({
    required this.deviceId,
    required this.stateJson,
    required this.at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['state_json'] = Variable<String>(stateJson);
    map['at'] = Variable<DateTime>(at);
    return map;
  }

  DeviceStateCacheCompanion toCompanion(bool nullToAbsent) {
    return DeviceStateCacheCompanion(
      deviceId: Value(deviceId),
      stateJson: Value(stateJson),
      at: Value(at),
    );
  }

  factory StateCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StateCacheRow(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      stateJson: serializer.fromJson<String>(json['stateJson']),
      at: serializer.fromJson<DateTime>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'stateJson': serializer.toJson<String>(stateJson),
      'at': serializer.toJson<DateTime>(at),
    };
  }

  StateCacheRow copyWith({String? deviceId, String? stateJson, DateTime? at}) =>
      StateCacheRow(
        deviceId: deviceId ?? this.deviceId,
        stateJson: stateJson ?? this.stateJson,
        at: at ?? this.at,
      );
  StateCacheRow copyWithCompanion(DeviceStateCacheCompanion data) {
    return StateCacheRow(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      stateJson: data.stateJson.present ? data.stateJson.value : this.stateJson,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StateCacheRow(')
          ..write('deviceId: $deviceId, ')
          ..write('stateJson: $stateJson, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(deviceId, stateJson, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StateCacheRow &&
          other.deviceId == this.deviceId &&
          other.stateJson == this.stateJson &&
          other.at == this.at);
}

class DeviceStateCacheCompanion extends UpdateCompanion<StateCacheRow> {
  final Value<String> deviceId;
  final Value<String> stateJson;
  final Value<DateTime> at;
  final Value<int> rowid;
  const DeviceStateCacheCompanion({
    this.deviceId = const Value.absent(),
    this.stateJson = const Value.absent(),
    this.at = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceStateCacheCompanion.insert({
    required String deviceId,
    required String stateJson,
    required DateTime at,
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId),
       stateJson = Value(stateJson),
       at = Value(at);
  static Insertable<StateCacheRow> custom({
    Expression<String>? deviceId,
    Expression<String>? stateJson,
    Expression<DateTime>? at,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (stateJson != null) 'state_json': stateJson,
      if (at != null) 'at': at,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceStateCacheCompanion copyWith({
    Value<String>? deviceId,
    Value<String>? stateJson,
    Value<DateTime>? at,
    Value<int>? rowid,
  }) {
    return DeviceStateCacheCompanion(
      deviceId: deviceId ?? this.deviceId,
      stateJson: stateJson ?? this.stateJson,
      at: at ?? this.at,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (stateJson.present) {
      map['state_json'] = Variable<String>(stateJson.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceStateCacheCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('stateJson: $stateJson, ')
          ..write('at: $at, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RoomsTable rooms = $RoomsTable(this);
  late final $DevicesTable devices = $DevicesTable(this);
  late final $AliasesTable aliases = $AliasesTable(this);
  late final $TimerJobsTable timerJobs = $TimerJobsTable(this);
  late final $DeviceStateCacheTable deviceStateCache = $DeviceStateCacheTable(
    this,
  );
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index devicesMac = Index(
    'devices_mac',
    'CREATE INDEX devices_mac ON devices (mac)',
  );
  late final Index devicesIp = Index(
    'devices_ip',
    'CREATE INDEX devices_ip ON devices (ip)',
  );
  late final Index timerJobsStatus = Index(
    'timer_jobs_status',
    'CREATE INDEX timer_jobs_status ON timer_jobs (status)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    rooms,
    devices,
    aliases,
    timerJobs,
    deviceStateCache,
    settings,
    devicesMac,
    devicesIp,
    timerJobsStatus,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'rooms',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('devices', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'devices',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('aliases', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'devices',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('timer_jobs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'devices',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('device_state_cache', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$RoomsTableCreateCompanionBuilder = RoomsCompanion Function({
  required String id,
  required String name,
  Value<int> sort,
  Value<int> rowid,
});
typedef $$RoomsTableUpdateCompanionBuilder = RoomsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> sort,
  Value<int> rowid,
});

final class $$RoomsTableReferences
    extends BaseReferences<_$AppDatabase, $RoomsTable, RoomRow> {
  $$RoomsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DevicesTable, List<DeviceRow>> _devicesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.devices,
    aliasName: 'rooms__id__devices__room_id',
  );

  $$DevicesTableProcessedTableManager get devicesRefs {
    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.roomId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_devicesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RoomsTableFilterComposer extends Composer<_$AppDatabase, $RoomsTable> {
  $$RoomsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> devicesRefs(
    Expression<bool> Function($$DevicesTableFilterComposer f) f,
  ) {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.roomId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoomsTableOrderingComposer
    extends Composer<_$AppDatabase, $RoomsTable> {
  $$RoomsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoomsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoomsTable> {
  $$RoomsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  Expression<T> devicesRefs<T extends Object>(
    Expression<T> Function($$DevicesTableAnnotationComposer a) f,
  ) {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.roomId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoomsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoomsTable,
          RoomRow,
          $$RoomsTableFilterComposer,
          $$RoomsTableOrderingComposer,
          $$RoomsTableAnnotationComposer,
          $$RoomsTableCreateCompanionBuilder,
          $$RoomsTableUpdateCompanionBuilder,
          (RoomRow, $$RoomsTableReferences),
          RoomRow,
          PrefetchHooks Function({bool devicesRefs})
        > {
  $$RoomsTableTableManager(_$AppDatabase db, $RoomsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoomsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoomsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoomsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> sort = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => RoomsCompanion(id: id, name: name, sort: sort, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> sort = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoomsCompanion.insert(
                id: id,
                name: name,
                sort: sort,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RoomsTable, RoomRow>(table),
                  $$RoomsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({devicesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (devicesRefs) db.devices],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (devicesRefs)
                    await $_getPrefetchedData<RoomRow, $RoomsTable, DeviceRow>(
                      currentTable: table,
                      referencedTable: $$RoomsTableReferences._devicesRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$RoomsTableReferences(db, table, p0).devicesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.roomId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RoomsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoomsTable,
      RoomRow,
      $$RoomsTableFilterComposer,
      $$RoomsTableOrderingComposer,
      $$RoomsTableAnnotationComposer,
      $$RoomsTableCreateCompanionBuilder,
      $$RoomsTableUpdateCompanionBuilder,
      (RoomRow, $$RoomsTableReferences),
      RoomRow,
      PrefetchHooks Function({bool devicesRefs})
    >;
typedef $$DevicesTableCreateCompanionBuilder = DevicesCompanion Function({
  required String id,
  required Brand brand,
  required String protocol,
  required String ip,
  Value<String?> mac,
  Value<int?> port,
  required String name,
  Value<String?> roomId,
  required String capabilitiesJson,
  Value<String?> dpMapJson,
  Value<int?> nativeCountdownMaxS,
  Value<int?> defaultAutoOffS,
  Value<String> metaJson,
  required DateTime lastSeen,
  Value<int> rowid,
});
typedef $$DevicesTableUpdateCompanionBuilder = DevicesCompanion Function({
  Value<String> id,
  Value<Brand> brand,
  Value<String> protocol,
  Value<String> ip,
  Value<String?> mac,
  Value<int?> port,
  Value<String> name,
  Value<String?> roomId,
  Value<String> capabilitiesJson,
  Value<String?> dpMapJson,
  Value<int?> nativeCountdownMaxS,
  Value<int?> defaultAutoOffS,
  Value<String> metaJson,
  Value<DateTime> lastSeen,
  Value<int> rowid,
});

final class $$DevicesTableReferences
    extends BaseReferences<_$AppDatabase, $DevicesTable, DeviceRow> {
  $$DevicesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RoomsTable _roomIdTable(_$AppDatabase db) =>
      db.rooms.createAlias('devices__room_id__rooms__id');

  $$RoomsTableProcessedTableManager? get roomId {
    final $_column = $_itemColumn<String>('room_id');
    if ($_column == null) return null;
    final manager = $$RoomsTableTableManager(
      $_db,
      $_db.rooms,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_roomIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AliasesTable, List<AliasRow>> _aliasesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.aliases,
    aliasName: 'devices__id__aliases__device_id',
  );

  $$AliasesTableProcessedTableManager get aliasesRefs {
    final manager = $$AliasesTableTableManager(
      $_db,
      $_db.aliases,
    ).filter((f) => f.deviceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_aliasesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TimerJobsTable, List<TimerJobRow>>
  _timerJobsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.timerJobs,
    aliasName: 'devices__id__timer_jobs__device_id',
  );

  $$TimerJobsTableProcessedTableManager get timerJobsRefs {
    final manager = $$TimerJobsTableTableManager(
      $_db,
      $_db.timerJobs,
    ).filter((f) => f.deviceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_timerJobsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DeviceStateCacheTable, List<StateCacheRow>>
  _deviceStateCacheRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.deviceStateCache,
    aliasName: 'devices__id__device_state_cache__device_id',
  );

  $$DeviceStateCacheTableProcessedTableManager get deviceStateCacheRefs {
    final manager = $$DeviceStateCacheTableTableManager(
      $_db,
      $_db.deviceStateCache,
    ).filter((f) => f.deviceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _deviceStateCacheRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DevicesTableFilterComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Brand, Brand, String> get brand =>
      $composableBuilder(
        column: $table.brand,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get protocol => $composableBuilder(
    column: $table.protocol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ip => $composableBuilder(
    column: $table.ip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mac => $composableBuilder(
    column: $table.mac,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dpMapJson => $composableBuilder(
    column: $table.dpMapJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nativeCountdownMaxS => $composableBuilder(
    column: $table.nativeCountdownMaxS,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultAutoOffS => $composableBuilder(
    column: $table.defaultAutoOffS,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  $$RoomsTableFilterComposer get roomId {
    final $$RoomsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roomId,
      referencedTable: $db.rooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoomsTableFilterComposer(
            $db: $db,
            $table: $db.rooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> aliasesRefs(
    Expression<bool> Function($$AliasesTableFilterComposer f) f,
  ) {
    final $$AliasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aliases,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AliasesTableFilterComposer(
            $db: $db,
            $table: $db.aliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> timerJobsRefs(
    Expression<bool> Function($$TimerJobsTableFilterComposer f) f,
  ) {
    final $$TimerJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timerJobs,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimerJobsTableFilterComposer(
            $db: $db,
            $table: $db.timerJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> deviceStateCacheRefs(
    Expression<bool> Function($$DeviceStateCacheTableFilterComposer f) f,
  ) {
    final $$DeviceStateCacheTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deviceStateCache,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeviceStateCacheTableFilterComposer(
            $db: $db,
            $table: $db.deviceStateCache,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get protocol => $composableBuilder(
    column: $table.protocol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ip => $composableBuilder(
    column: $table.ip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mac => $composableBuilder(
    column: $table.mac,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dpMapJson => $composableBuilder(
    column: $table.dpMapJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nativeCountdownMaxS => $composableBuilder(
    column: $table.nativeCountdownMaxS,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultAutoOffS => $composableBuilder(
    column: $table.defaultAutoOffS,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  $$RoomsTableOrderingComposer get roomId {
    final $$RoomsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roomId,
      referencedTable: $db.rooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoomsTableOrderingComposer(
            $db: $db,
            $table: $db.rooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Brand, String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get protocol =>
      $composableBuilder(column: $table.protocol, builder: (column) => column);

  GeneratedColumn<String> get ip =>
      $composableBuilder(column: $table.ip, builder: (column) => column);

  GeneratedColumn<String> get mac =>
      $composableBuilder(column: $table.mac, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dpMapJson =>
      $composableBuilder(column: $table.dpMapJson, builder: (column) => column);

  GeneratedColumn<int> get nativeCountdownMaxS => $composableBuilder(
    column: $table.nativeCountdownMaxS,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultAutoOffS => $composableBuilder(
    column: $table.defaultAutoOffS,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metaJson =>
      $composableBuilder(column: $table.metaJson, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  $$RoomsTableAnnotationComposer get roomId {
    final $$RoomsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roomId,
      referencedTable: $db.rooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoomsTableAnnotationComposer(
            $db: $db,
            $table: $db.rooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> aliasesRefs<T extends Object>(
    Expression<T> Function($$AliasesTableAnnotationComposer a) f,
  ) {
    final $$AliasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aliases,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AliasesTableAnnotationComposer(
            $db: $db,
            $table: $db.aliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> timerJobsRefs<T extends Object>(
    Expression<T> Function($$TimerJobsTableAnnotationComposer a) f,
  ) {
    final $$TimerJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timerJobs,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimerJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.timerJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> deviceStateCacheRefs<T extends Object>(
    Expression<T> Function($$DeviceStateCacheTableAnnotationComposer a) f,
  ) {
    final $$DeviceStateCacheTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deviceStateCache,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeviceStateCacheTableAnnotationComposer(
            $db: $db,
            $table: $db.deviceStateCache,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DevicesTable,
          DeviceRow,
          $$DevicesTableFilterComposer,
          $$DevicesTableOrderingComposer,
          $$DevicesTableAnnotationComposer,
          $$DevicesTableCreateCompanionBuilder,
          $$DevicesTableUpdateCompanionBuilder,
          (DeviceRow, $$DevicesTableReferences),
          DeviceRow,
          PrefetchHooks Function({
            bool roomId,
            bool aliasesRefs,
            bool timerJobsRefs,
            bool deviceStateCacheRefs,
          })
        > {
  $$DevicesTableTableManager(_$AppDatabase db, $DevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<Brand> brand = const Value.absent(),
                Value<String> protocol = const Value.absent(),
                Value<String> ip = const Value.absent(),
                Value<String?> mac = const Value.absent(),
                Value<int?> port = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> roomId = const Value.absent(),
                Value<String> capabilitiesJson = const Value.absent(),
                Value<String?> dpMapJson = const Value.absent(),
                Value<int?> nativeCountdownMaxS = const Value.absent(),
                Value<int?> defaultAutoOffS = const Value.absent(),
                Value<String> metaJson = const Value.absent(),
                Value<DateTime> lastSeen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion(
                id: id,
                brand: brand,
                protocol: protocol,
                ip: ip,
                mac: mac,
                port: port,
                name: name,
                roomId: roomId,
                capabilitiesJson: capabilitiesJson,
                dpMapJson: dpMapJson,
                nativeCountdownMaxS: nativeCountdownMaxS,
                defaultAutoOffS: defaultAutoOffS,
                metaJson: metaJson,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required Brand brand,
                required String protocol,
                required String ip,
                Value<String?> mac = const Value.absent(),
                Value<int?> port = const Value.absent(),
                required String name,
                Value<String?> roomId = const Value.absent(),
                required String capabilitiesJson,
                Value<String?> dpMapJson = const Value.absent(),
                Value<int?> nativeCountdownMaxS = const Value.absent(),
                Value<int?> defaultAutoOffS = const Value.absent(),
                Value<String> metaJson = const Value.absent(),
                required DateTime lastSeen,
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion.insert(
                id: id,
                brand: brand,
                protocol: protocol,
                ip: ip,
                mac: mac,
                port: port,
                name: name,
                roomId: roomId,
                capabilitiesJson: capabilitiesJson,
                dpMapJson: dpMapJson,
                nativeCountdownMaxS: nativeCountdownMaxS,
                defaultAutoOffS: defaultAutoOffS,
                metaJson: metaJson,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DevicesTable, DeviceRow>(table),
                  $$DevicesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                roomId = false,
                aliasesRefs = false,
                timerJobsRefs = false,
                deviceStateCacheRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (aliasesRefs) db.aliases,
                    if (timerJobsRefs) db.timerJobs,
                    if (deviceStateCacheRefs) db.deviceStateCache,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (roomId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.roomId,
                            referencedTable: $$DevicesTableReferences
                                ._roomIdTable(db),
                            referencedColumn: $$DevicesTableReferences
                                ._roomIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (aliasesRefs)
                        await $_getPrefetchedData<
                          DeviceRow,
                          $DevicesTable,
                          AliasRow
                        >(
                          currentTable: table,
                          referencedTable: $$DevicesTableReferences
                              ._aliasesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DevicesTableReferences(
                                db,
                                table,
                                p0,
                              ).aliasesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.deviceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (timerJobsRefs)
                        await $_getPrefetchedData<
                          DeviceRow,
                          $DevicesTable,
                          TimerJobRow
                        >(
                          currentTable: table,
                          referencedTable: $$DevicesTableReferences
                              ._timerJobsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DevicesTableReferences(
                                db,
                                table,
                                p0,
                              ).timerJobsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.deviceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (deviceStateCacheRefs)
                        await $_getPrefetchedData<
                          DeviceRow,
                          $DevicesTable,
                          StateCacheRow
                        >(
                          currentTable: table,
                          referencedTable: $$DevicesTableReferences
                              ._deviceStateCacheRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DevicesTableReferences(
                                db,
                                table,
                                p0,
                              ).deviceStateCacheRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.deviceId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DevicesTable,
      DeviceRow,
      $$DevicesTableFilterComposer,
      $$DevicesTableOrderingComposer,
      $$DevicesTableAnnotationComposer,
      $$DevicesTableCreateCompanionBuilder,
      $$DevicesTableUpdateCompanionBuilder,
      (DeviceRow, $$DevicesTableReferences),
      DeviceRow,
      PrefetchHooks Function({
        bool roomId,
        bool aliasesRefs,
        bool timerJobsRefs,
        bool deviceStateCacheRefs,
      })
    >;
typedef $$AliasesTableCreateCompanionBuilder = AliasesCompanion Function({
  required String id,
  required String deviceId,
  required String alias,
  required AliasLang lang,
  Value<int> rowid,
});
typedef $$AliasesTableUpdateCompanionBuilder = AliasesCompanion Function({
  Value<String> id,
  Value<String> deviceId,
  Value<String> alias,
  Value<AliasLang> lang,
  Value<int> rowid,
});

final class $$AliasesTableReferences
    extends BaseReferences<_$AppDatabase, $AliasesTable, AliasRow> {
  $$AliasesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DevicesTable _deviceIdTable(_$AppDatabase db) =>
      db.devices.createAlias('aliases__device_id__devices__id');

  $$DevicesTableProcessedTableManager get deviceId {
    final $_column = $_itemColumn<String>('device_id')!;

    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deviceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AliasesTableFilterComposer
    extends Composer<_$AppDatabase, $AliasesTable> {
  $$AliasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AliasLang, AliasLang, String> get lang =>
      $composableBuilder(
        column: $table.lang,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$DevicesTableFilterComposer get deviceId {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AliasesTableOrderingComposer
    extends Composer<_$AppDatabase, $AliasesTable> {
  $$AliasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnOrderings(column),
  );

  $$DevicesTableOrderingComposer get deviceId {
    final $$DevicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableOrderingComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AliasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AliasesTable> {
  $$AliasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AliasLang, String> get lang =>
      $composableBuilder(column: $table.lang, builder: (column) => column);

  $$DevicesTableAnnotationComposer get deviceId {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AliasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AliasesTable,
          AliasRow,
          $$AliasesTableFilterComposer,
          $$AliasesTableOrderingComposer,
          $$AliasesTableAnnotationComposer,
          $$AliasesTableCreateCompanionBuilder,
          $$AliasesTableUpdateCompanionBuilder,
          (AliasRow, $$AliasesTableReferences),
          AliasRow,
          PrefetchHooks Function({bool deviceId})
        > {
  $$AliasesTableTableManager(_$AppDatabase db, $AliasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AliasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AliasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AliasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> alias = const Value.absent(),
                Value<AliasLang> lang = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AliasesCompanion(
                id: id,
                deviceId: deviceId,
                alias: alias,
                lang: lang,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deviceId,
                required String alias,
                required AliasLang lang,
                Value<int> rowid = const Value.absent(),
              }) => AliasesCompanion.insert(
                id: id,
                deviceId: deviceId,
                alias: alias,
                lang: lang,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AliasesTable, AliasRow>(table),
                  $$AliasesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({deviceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (deviceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.deviceId,
                        referencedTable: $$AliasesTableReferences
                            ._deviceIdTable(db),
                        referencedColumn: $$AliasesTableReferences
                            ._deviceIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AliasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AliasesTable,
      AliasRow,
      $$AliasesTableFilterComposer,
      $$AliasesTableOrderingComposer,
      $$AliasesTableAnnotationComposer,
      $$AliasesTableCreateCompanionBuilder,
      $$AliasesTableUpdateCompanionBuilder,
      (AliasRow, $$AliasesTableReferences),
      AliasRow,
      PrefetchHooks Function({bool deviceId})
    >;
typedef $$TimerJobsTableCreateCompanionBuilder = TimerJobsCompanion Function({
  required String id,
  required String deviceId,
  required bool endOn,
  required DateTime fireAt,
  required TimerTier tier,
  required TimerStatus status,
  Value<String> metaJson,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$TimerJobsTableUpdateCompanionBuilder = TimerJobsCompanion Function({
  Value<String> id,
  Value<String> deviceId,
  Value<bool> endOn,
  Value<DateTime> fireAt,
  Value<TimerTier> tier,
  Value<TimerStatus> status,
  Value<String> metaJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$TimerJobsTableReferences
    extends BaseReferences<_$AppDatabase, $TimerJobsTable, TimerJobRow> {
  $$TimerJobsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DevicesTable _deviceIdTable(_$AppDatabase db) =>
      db.devices.createAlias('timer_jobs__device_id__devices__id');

  $$DevicesTableProcessedTableManager get deviceId {
    final $_column = $_itemColumn<String>('device_id')!;

    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deviceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TimerJobsTableFilterComposer
    extends Composer<_$AppDatabase, $TimerJobsTable> {
  $$TimerJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get endOn => $composableBuilder(
    column: $table.endOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fireAt => $composableBuilder(
    column: $table.fireAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TimerTier, TimerTier, String> get tier =>
      $composableBuilder(
        column: $table.tier,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<TimerStatus, TimerStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DevicesTableFilterComposer get deviceId {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimerJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $TimerJobsTable> {
  $$TimerJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get endOn => $composableBuilder(
    column: $table.endOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fireAt => $composableBuilder(
    column: $table.fireAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DevicesTableOrderingComposer get deviceId {
    final $$DevicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableOrderingComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimerJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TimerJobsTable> {
  $$TimerJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get endOn =>
      $composableBuilder(column: $table.endOn, builder: (column) => column);

  GeneratedColumn<DateTime> get fireAt =>
      $composableBuilder(column: $table.fireAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TimerTier, String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TimerStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get metaJson =>
      $composableBuilder(column: $table.metaJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$DevicesTableAnnotationComposer get deviceId {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimerJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TimerJobsTable,
          TimerJobRow,
          $$TimerJobsTableFilterComposer,
          $$TimerJobsTableOrderingComposer,
          $$TimerJobsTableAnnotationComposer,
          $$TimerJobsTableCreateCompanionBuilder,
          $$TimerJobsTableUpdateCompanionBuilder,
          (TimerJobRow, $$TimerJobsTableReferences),
          TimerJobRow,
          PrefetchHooks Function({bool deviceId})
        > {
  $$TimerJobsTableTableManager(_$AppDatabase db, $TimerJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimerJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimerJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimerJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<bool> endOn = const Value.absent(),
                Value<DateTime> fireAt = const Value.absent(),
                Value<TimerTier> tier = const Value.absent(),
                Value<TimerStatus> status = const Value.absent(),
                Value<String> metaJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimerJobsCompanion(
                id: id,
                deviceId: deviceId,
                endOn: endOn,
                fireAt: fireAt,
                tier: tier,
                status: status,
                metaJson: metaJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deviceId,
                required bool endOn,
                required DateTime fireAt,
                required TimerTier tier,
                required TimerStatus status,
                Value<String> metaJson = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TimerJobsCompanion.insert(
                id: id,
                deviceId: deviceId,
                endOn: endOn,
                fireAt: fireAt,
                tier: tier,
                status: status,
                metaJson: metaJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TimerJobsTable, TimerJobRow>(table),
                  $$TimerJobsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({deviceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (deviceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.deviceId,
                        referencedTable: $$TimerJobsTableReferences
                            ._deviceIdTable(db),
                        referencedColumn: $$TimerJobsTableReferences
                            ._deviceIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TimerJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TimerJobsTable,
      TimerJobRow,
      $$TimerJobsTableFilterComposer,
      $$TimerJobsTableOrderingComposer,
      $$TimerJobsTableAnnotationComposer,
      $$TimerJobsTableCreateCompanionBuilder,
      $$TimerJobsTableUpdateCompanionBuilder,
      (TimerJobRow, $$TimerJobsTableReferences),
      TimerJobRow,
      PrefetchHooks Function({bool deviceId})
    >;
typedef $$DeviceStateCacheTableCreateCompanionBuilder =
    DeviceStateCacheCompanion Function({
      required String deviceId,
      required String stateJson,
      required DateTime at,
      Value<int> rowid,
    });
typedef $$DeviceStateCacheTableUpdateCompanionBuilder =
    DeviceStateCacheCompanion Function({
      Value<String> deviceId,
      Value<String> stateJson,
      Value<DateTime> at,
      Value<int> rowid,
    });

final class $$DeviceStateCacheTableReferences
    extends
        BaseReferences<_$AppDatabase, $DeviceStateCacheTable, StateCacheRow> {
  $$DeviceStateCacheTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DevicesTable _deviceIdTable(_$AppDatabase db) =>
      db.devices.createAlias('device_state_cache__device_id__devices__id');

  $$DevicesTableProcessedTableManager get deviceId {
    final $_column = $_itemColumn<String>('device_id')!;

    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deviceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DeviceStateCacheTableFilterComposer
    extends Composer<_$AppDatabase, $DeviceStateCacheTable> {
  $$DeviceStateCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get stateJson => $composableBuilder(
    column: $table.stateJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  $$DevicesTableFilterComposer get deviceId {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeviceStateCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $DeviceStateCacheTable> {
  $$DeviceStateCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get stateJson => $composableBuilder(
    column: $table.stateJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  $$DevicesTableOrderingComposer get deviceId {
    final $$DevicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableOrderingComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeviceStateCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeviceStateCacheTable> {
  $$DeviceStateCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get stateJson =>
      $composableBuilder(column: $table.stateJson, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  $$DevicesTableAnnotationComposer get deviceId {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeviceStateCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeviceStateCacheTable,
          StateCacheRow,
          $$DeviceStateCacheTableFilterComposer,
          $$DeviceStateCacheTableOrderingComposer,
          $$DeviceStateCacheTableAnnotationComposer,
          $$DeviceStateCacheTableCreateCompanionBuilder,
          $$DeviceStateCacheTableUpdateCompanionBuilder,
          (StateCacheRow, $$DeviceStateCacheTableReferences),
          StateCacheRow,
          PrefetchHooks Function({bool deviceId})
        > {
  $$DeviceStateCacheTableTableManager(
    _$AppDatabase db,
    $DeviceStateCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceStateCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceStateCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceStateCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<String> stateJson = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeviceStateCacheCompanion(
                deviceId: deviceId,
                stateJson: stateJson,
                at: at,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                required String stateJson,
                required DateTime at,
                Value<int> rowid = const Value.absent(),
              }) => DeviceStateCacheCompanion.insert(
                deviceId: deviceId,
                stateJson: stateJson,
                at: at,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DeviceStateCacheTable, StateCacheRow>(table),
                  $$DeviceStateCacheTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({deviceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (deviceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.deviceId,
                        referencedTable: $$DeviceStateCacheTableReferences
                            ._deviceIdTable(db),
                        referencedColumn: $$DeviceStateCacheTableReferences
                            ._deviceIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DeviceStateCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeviceStateCacheTable,
      StateCacheRow,
      $$DeviceStateCacheTableFilterComposer,
      $$DeviceStateCacheTableOrderingComposer,
      $$DeviceStateCacheTableAnnotationComposer,
      $$DeviceStateCacheTableCreateCompanionBuilder,
      $$DeviceStateCacheTableUpdateCompanionBuilder,
      (StateCacheRow, $$DeviceStateCacheTableReferences),
      StateCacheRow,
      PrefetchHooks Function({bool deviceId})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RoomsTableTableManager get rooms =>
      $$RoomsTableTableManager(_db, _db.rooms);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db, _db.devices);
  $$AliasesTableTableManager get aliases =>
      $$AliasesTableTableManager(_db, _db.aliases);
  $$TimerJobsTableTableManager get timerJobs =>
      $$TimerJobsTableTableManager(_db, _db.timerJobs);
  $$DeviceStateCacheTableTableManager get deviceStateCache =>
      $$DeviceStateCacheTableTableManager(_db, _db.deviceStateCache);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
