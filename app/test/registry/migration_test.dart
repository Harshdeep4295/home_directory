import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/registry/database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'generated_migrations/schema_v2.dart' as v2;

/// Schema dumps live in drift_schemas/app. After bumping schemaVersion:
///   dart run drift_dev make-migrations
/// and add a step test here for vN-1 → vN.
void main() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('fresh database matches the v1 schema dump', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 1);
    await db.close();
  });

  test('v1 → v2 adds the place column; existing devices become Home', () async {
    final schema = await verifier.schemaAt(1);
    final old = v1.DatabaseAtV1(schema.newConnection());
    await old.customStatement(
      'INSERT INTO devices (id, brand, protocol, ip, name, capabilities_json, '
      "meta_json, last_seen) VALUES ('d1', 'wiz', 'wiz', '10.0.0.2', 'Lamp', "
      "'[\"power\"]', '{}', '2026-10-24T00:00:00.000Z')",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);
    await db.close();

    final after = v2.DatabaseAtV2(schema.newConnection());
    final row = await after
        .customSelect("SELECT place FROM devices WHERE id = 'd1'")
        .getSingle();
    expect(row.read<String>('place'), 'Home');
    await after.close();
  });
}
