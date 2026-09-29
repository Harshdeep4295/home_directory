import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/device_adapter.dart';
import 'package:offline_home/adapters/fake_adapter.dart';
import 'package:offline_home/core/log.dart';
import 'package:offline_home/core/models.dart';
import 'package:offline_home/core/result.dart';
import 'package:offline_home/engine/command_engine.dart';
import 'package:offline_home/onboarding/manual_key.dart';
import 'package:offline_home/registry/database.dart';
import 'package:offline_home/registry/repositories.dart';
import 'package:offline_home/registry/secret_store.dart';

/// Answers only when the stored key equals [goodKey], like a Tuya device would.
class KeyedFake extends FakeAdapter {
  KeyedFake(this.secrets) : super(protocols: {'tuya-3.3'});
  final SecretStore secrets;
  static const goodKey = 'G00dKeyG00dKey!!';
  final disposed = <String>[];

  @override
  Future<Result<DeviceState>> getState(Device d) async =>
      await secrets.get(d.id, SecretName.localKey) == goodKey
      ? super.getState(d)
      : Err(DeviceError.auth('bad key'));

  @override
  Future<void> dispose(Device d) async => disposed.add(d.id);
}

void main() {
  late AppDatabase db;
  late SecretStore secrets;
  late KeyedFake fake;
  late CommandEngine engine;
  final plug = Device(
    id: 'bfplug',
    brand: Brand.tuya,
    protocol: 'tuya-3.3',
    ip: '192.168.1.40',
    name: 'Plug',
    lastSeen: DateTime.utc(2026),
  );

  setUp(() async {
    db = AppDatabase.memory();
    await DeviceRepository(db).upsert(plug);
    secrets = SecretStore(MemorySecretBackend(), Redactor());
    fake = KeyedFake(secrets);
    engine = CommandEngine(
      AdapterRegistry([fake]),
      StateCacheRepository(db),
      backoff: const [],
    );
  });
  tearDown(() async {
    await engine.dispose();
    await db.close();
  });

  Future<ManualKeyResult> enter(String key, [Device? d]) => enterLocalKey(
    d: d ?? plug,
    key: key,
    secrets: secrets,
    adapters: AdapterRegistry([fake]),
    engine: engine,
  );

  test('validation: exactly 16 printable characters', () async {
    expect(isValidLocalKey(KeyedFake.goodKey), isTrue);
    expect(isValidLocalKey('short'), isFalse);
    expect(isValidLocalKey('has space in it!'), isFalse);
    expect(await enter('short'), ManualKeyResult.invalid);
    expect(await secrets.has('bfplug', SecretName.localKey), isFalse);
  });

  test('good key: stored, session reset, verified', () async {
    expect(await enter('  ${KeyedFake.goodKey} '), ManualKeyResult.ok);
    expect(await secrets.get('bfplug', SecretName.localKey), KeyedFake.goodKey);
    expect(fake.disposed, ['bfplug']);
  });

  test('rejected key rolls back to the previous one (or none)', () async {
    expect(await enter('WrongKeyWrongKey'), ManualKeyResult.rejected);
    expect(await secrets.has('bfplug', SecretName.localKey), isFalse);

    await secrets.set('bfplug', SecretName.localKey, KeyedFake.goodKey);
    expect(await enter('WrongKeyWrongKey'), ManualKeyResult.rejected);
    expect(await secrets.get('bfplug', SecretName.localKey), KeyedFake.goodKey);
  });

  test('unreachable or no IP yet: saved, unverified', () async {
    fake.offline.add('bfplug');
    expect(await enter(KeyedFake.goodKey), ManualKeyResult.unverified);
    expect(await secrets.has('bfplug', SecretName.localKey), isTrue);
    expect(
      await enter(KeyedFake.goodKey, plug.copyWith(ip: '')),
      ManualKeyResult.unverified,
    );
  });
}
