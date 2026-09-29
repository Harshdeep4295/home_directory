import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/models.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Rooms, Devices, Aliases, TimerJobs, DeviceStateCache, Settings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The on-device database file, opened on a background isolate.
  factory AppDatabase.open() => AppDatabase(
    LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      return NativeDatabase.createInBackground(
        File(p.join(dir.path, 'offline_home.sqlite')),
      );
    }),
  );

  /// In-memory database for tests.
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // The timer foreground service opens the same file from a second engine (T3.4);
      // WAL lets both read while one writes.
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );
}
