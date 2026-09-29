import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/models.dart';
import 'database.dart';

/// Devices + their aliases. Aliases are stored in their own table (with language) and
/// denormalised into [Device.aliases] on read.
class DeviceRepository {
  DeviceRepository(this._db);
  final AppDatabase _db;

  Future<List<Device>> all() async => _withAliases(
    await (_db.select(
      _db.devices,
    )..orderBy([(d) => OrderingTerm.asc(d.name)])).get(),
  );

  Stream<List<Device>> watchAll() => (_db.select(
    _db.devices,
  )..orderBy([(d) => OrderingTerm.asc(d.name)])).watch().asyncMap(_withAliases);

  Future<Device?> byId(String id) => _one(_db.devices.id.equals(id));
  Future<Device?> byMac(String mac) =>
      _one(_db.devices.mac.lower().equals(mac.toLowerCase()));
  Future<Device?> byIp(String ip) => _one(_db.devices.ip.equals(ip));

  Future<List<Device>> inRoom(String roomId) async => _withAliases(
    await (_db.select(
      _db.devices,
    )..where((d) => d.roomId.equals(roomId))).get(),
  );

  /// Inserts or replaces the device and syncs the alias table to [Device.aliases]:
  /// new aliases are added as English, removed ones deleted, existing rows (and their
  /// language) kept. Use [addAlias] to add an alias with a specific language.
  Future<void> upsert(Device d) => _db.transaction(() async {
    await _db.into(_db.devices).insertOnConflictUpdate(_toRow(d));
    final existing = await aliasesOf(d.id);
    final have = existing.map((a) => a.alias).toSet();
    for (final alias in d.aliases.where((a) => !have.contains(a))) {
      await addAlias(Alias(id: '${d.id}#$alias', deviceId: d.id, alias: alias));
    }
    for (final a in existing) {
      if (!d.aliases.contains(a.alias)) await removeAlias(a.id);
    }
  });

  Future<void> delete(String id) =>
      (_db.delete(_db.devices)..where((d) => d.id.equals(id))).go();

  Future<List<Alias>> aliasesOf(String deviceId) async => (await (_db.select(
    _db.aliases,
  )..where((a) => a.deviceId.equals(deviceId))).get()).map(_alias).toList();

  Future<void> addAlias(Alias a) => _db
      .into(_db.aliases)
      .insertOnConflictUpdate(
        AliasesCompanion.insert(
          id: a.id,
          deviceId: a.deviceId,
          alias: a.alias,
          lang: a.lang,
        ),
      );

  Future<void> removeAlias(String aliasId) =>
      (_db.delete(_db.aliases)..where((a) => a.id.equals(aliasId))).go();

  Future<Device?> _one(Expression<bool> where) async {
    final row = await (_db.select(
      _db.devices,
    )..where((_) => where)).getSingleOrNull();
    return row == null ? null : (await _withAliases([row])).single;
  }

  Future<List<Device>> _withAliases(List<DeviceRow> rows) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r.id).toList();
    final aliasRows = await (_db.select(
      _db.aliases,
    )..where((a) => a.deviceId.isIn(ids))).get();
    final byDevice = <String, List<String>>{};
    for (final a in aliasRows) {
      (byDevice[a.deviceId] ??= []).add(a.alias);
    }
    return [for (final r in rows) _fromRow(r, byDevice[r.id] ?? const [])];
  }

  static Alias _alias(AliasRow r) =>
      Alias(id: r.id, deviceId: r.deviceId, alias: r.alias, lang: r.lang);

  static DevicesCompanion _toRow(Device d) => DevicesCompanion.insert(
    id: d.id,
    brand: d.brand,
    protocol: d.protocol,
    ip: d.ip,
    mac: Value(d.mac),
    port: Value(d.port),
    name: d.name,
    roomId: Value(d.roomId),
    capabilitiesJson: jsonEncode(
      d.capabilities.map((c) => c.name).toList()..sort(),
    ),
    dpMapJson: Value(d.dpMap == null ? null : jsonEncode(d.dpMap)),
    nativeCountdownMaxS: Value(d.nativeCountdownMax?.inSeconds),
    defaultAutoOffS: Value(d.defaultAutoOff?.inSeconds),
    metaJson: Value(jsonEncode(d.meta)),
    lastSeen: d.lastSeen.toUtc(),
  );

  static Device _fromRow(DeviceRow r, List<String> aliases) {
    final caps = Capability.values.asNameMap();
    return Device(
      id: r.id,
      brand: r.brand,
      protocol: r.protocol,
      ip: r.ip,
      mac: r.mac,
      port: r.port,
      name: r.name,
      roomId: r.roomId,
      aliases: aliases,
      capabilities: {
        for (final n in (jsonDecode(r.capabilitiesJson) as List<Object?>))
          ?caps[n],
      },
      nativeCountdownMax: r.nativeCountdownMaxS == null
          ? null
          : Duration(seconds: r.nativeCountdownMaxS!),
      dpMap: r.dpMapJson == null
          ? null
          : (jsonDecode(r.dpMapJson!) as Map<String, Object?>).map(
              (k, v) => MapEntry(k, (v! as num).toInt()),
            ),
      defaultAutoOff: r.defaultAutoOffS == null
          ? null
          : Duration(seconds: r.defaultAutoOffS!),
      meta: jsonDecode(r.metaJson) as Map<String, Object?>,
      lastSeen: r.lastSeen.toUtc(),
    );
  }
}

class RoomRepository {
  RoomRepository(this._db);
  final AppDatabase _db;

  SimpleSelectStatement<$RoomsTable, RoomRow> _ordered() =>
      _db.select(_db.rooms)..orderBy([
        (r) => OrderingTerm.asc(r.sort),
        (r) => OrderingTerm.asc(r.name),
      ]);

  Future<List<Room>> all() async =>
      (await _ordered().get()).map(_room).toList();
  Stream<List<Room>> watchAll() =>
      _ordered().watch().map((rows) => rows.map(_room).toList());

  Future<void> upsert(Room r) => _db
      .into(_db.rooms)
      .insertOnConflictUpdate(
        RoomsCompanion.insert(id: r.id, name: r.name, sort: Value(r.sort)),
      );

  /// Devices in the room keep existing with no room (FK ON DELETE SET NULL).
  Future<void> delete(String id) =>
      (_db.delete(_db.rooms)..where((r) => r.id.equals(id))).go();

  static Room _room(RoomRow r) => Room(id: r.id, name: r.name, sort: r.sort);
}

class TimerRepository {
  TimerRepository(this._db);
  final AppDatabase _db;

  Future<void> upsert(TimerJob j) => _db
      .into(_db.timerJobs)
      .insertOnConflictUpdate(
        TimerJobsCompanion.insert(
          id: j.id,
          deviceId: j.deviceId,
          endOn: j.endOn,
          fireAt: j.fireAt.toUtc(),
          tier: j.tier,
          status: j.status,
          metaJson: Value(jsonEncode(j.meta)),
          createdAt: j.createdAt.toUtc(),
        ),
      );

  Future<TimerJob?> byId(String id) async {
    final r = await (_db.select(
      _db.timerJobs,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return r == null ? null : _job(r);
  }

  SimpleSelectStatement<$TimerJobsTable, TimerJobRow> _active() =>
      _db.select(_db.timerJobs)
        ..where((t) => t.status.equalsValue(TimerStatus.active))
        ..orderBy([(t) => OrderingTerm.asc(t.fireAt)]);

  Future<List<TimerJob>> active() async =>
      (await _active().get()).map(_job).toList();
  Stream<List<TimerJob>> watchActive() =>
      _active().watch().map((rows) => rows.map(_job).toList());

  Future<TimerJob?> activeFor(String deviceId) async {
    final r = await (_active()..where((t) => t.deviceId.equals(deviceId)))
        .get();
    return r.isEmpty ? null : _job(r.first);
  }

  Future<void> setStatus(String id, TimerStatus status) =>
      (_db.update(_db.timerJobs)..where((t) => t.id.equals(id))).write(
        TimerJobsCompanion(status: Value(status)),
      );

  static TimerJob _job(TimerJobRow r) => TimerJob(
    id: r.id,
    deviceId: r.deviceId,
    endOn: r.endOn,
    fireAt: r.fireAt.toUtc(),
    tier: r.tier,
    status: r.status,
    meta: (jsonDecode(r.metaJson) as Map<String, Object?>).map(
      (k, v) => MapEntry(k, v.toString()),
    ),
    createdAt: r.createdAt.toUtc(),
  );
}

class StateCacheRepository {
  StateCacheRepository(this._db);
  final AppDatabase _db;

  Future<void> put(String deviceId, DeviceState s) => _db
      .into(_db.deviceStateCache)
      .insertOnConflictUpdate(
        DeviceStateCacheCompanion.insert(
          deviceId: deviceId,
          stateJson: jsonEncode(s.toJson()),
          at: s.at.toUtc(),
        ),
      );

  Future<DeviceState?> get(String deviceId) async {
    final r = await (_db.select(
      _db.deviceStateCache,
    )..where((c) => c.deviceId.equals(deviceId))).getSingleOrNull();
    return r == null ? null : _state(r);
  }

  Future<Map<String, DeviceState>> all() async => {
    for (final r in await _db.select(_db.deviceStateCache).get())
      r.deviceId: _state(r),
  };

  static DeviceState _state(StateCacheRow r) =>
      DeviceState.fromJson(jsonDecode(r.stateJson) as Map<String, dynamic>);
}

class SettingsRepository {
  SettingsRepository(this._db);
  final AppDatabase _db;

  Future<String?> get(String key) async => (await (_db.select(
    _db.settings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> set(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> remove(String key) =>
      (_db.delete(_db.settings)..where((s) => s.key.equals(key))).go();

  Future<bool> getBool(String key, {bool orElse = false}) async =>
      switch (await get(key)) {
        'true' => true,
        'false' => false,
        _ => orElse,
      };

  Future<void> setBool(String key, bool value) => set(key, '$value');
}
