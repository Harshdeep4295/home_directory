import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/registry/database.dart';

import 'generated_migrations/schema.dart';

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
}
