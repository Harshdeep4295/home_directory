import 'package:drift/drift.dart';

import '../core/models.dart';

/// Registry schema (PSEUDOCODE §4). Secrets are NOT stored here: they live in SecretStore.

@DataClassName('RoomRow')
class Rooms extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get sort => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DeviceRow')
@TableIndex(name: 'devices_mac', columns: {#mac})
@TableIndex(name: 'devices_ip', columns: {#ip})
class Devices extends Table {
  TextColumn get id => text()();
  TextColumn get brand => textEnum<Brand>()();
  TextColumn get protocol => text()();
  TextColumn get ip => text()();
  TextColumn get mac => text().nullable()();
  IntColumn get port => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get roomId =>
      text().nullable().references(Rooms, #id, onDelete: KeyAction.setNull)();

  /// JSON list of [Capability] names.
  TextColumn get capabilitiesJson => text()();

  /// JSON object, Tuya only.
  TextColumn get dpMapJson => text().nullable()();
  IntColumn get nativeCountdownMaxS => integer().nullable()();
  IntColumn get defaultAutoOffS => integer().nullable()();
  TextColumn get metaJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get lastSeen => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AliasRow')
class Aliases extends Table {
  TextColumn get id => text()();
  TextColumn get deviceId =>
      text().references(Devices, #id, onDelete: KeyAction.cascade)();
  TextColumn get alias => text()();
  TextColumn get lang => textEnum<AliasLang>()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TimerJobRow')
@TableIndex(name: 'timer_jobs_status', columns: {#status})
class TimerJobs extends Table {
  TextColumn get id => text()();
  TextColumn get deviceId =>
      text().references(Devices, #id, onDelete: KeyAction.cascade)();
  BoolColumn get endOn => boolean()();
  DateTimeColumn get fireAt => dateTime()();
  TextColumn get tier => textEnum<TimerTier>()();
  TextColumn get status => textEnum<TimerStatus>()();
  TextColumn get metaJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('StateCacheRow')
class DeviceStateCache extends Table {
  TextColumn get deviceId =>
      text().references(Devices, #id, onDelete: KeyAction.cascade)();

  /// [DeviceState] JSON.
  TextColumn get stateJson => text()();
  DateTimeColumn get at => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {deviceId};
}

@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
