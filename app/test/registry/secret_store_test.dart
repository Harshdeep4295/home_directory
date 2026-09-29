import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/core/log.dart';
import 'package:offline_home/registry/secret_store.dart';

void main() {
  late MemorySecretBackend backend;
  late Redactor redactor;
  late SecretStore store;
  late MemorySink sink;
  late Logger logger;

  setUp(() {
    backend = MemorySecretBackend();
    redactor = Redactor();
    store = SecretStore(backend, redactor);
    sink = MemorySink();
    logger = Logger(redactor: redactor, sinks: [sink]);
  });

  test('set / get / has / delete with namespaced keys', () async {
    await store.set('bf01', SecretName.localKey, '0123456789abcdef');
    expect(backend.values, {'secret/bf01/local_key': '0123456789abcdef'});
    expect(await store.get('bf01', SecretName.localKey), '0123456789abcdef');
    expect(await store.has('bf01', SecretName.localKey), isTrue);
    expect(await store.get('bf01', SecretName.hueUser), isNull);

    await store.delete('bf01', SecretName.localKey);
    expect(await store.has('bf01', SecretName.localKey), isFalse);
  });

  test('deleteDevice removes only that device', () async {
    await store.set('a', SecretName.localKey, 'aaaaaaaaaaaaaaaa');
    await store.set('a', SecretName.password, 'pw-aaaa');
    await store.set('ab', SecretName.localKey, 'bbbbbbbbbbbbbbbb');
    await store.deleteDevice('a');
    expect(backend.values.keys, ['secret/ab/local_key']);
  });

  test(
    'values written through SecretStore never appear in logs (T1.2 accept)',
    () async {
      const key = 'Zq9!localKey#123';
      await store.set('bf01', SecretName.localKey, key);
      logger
        ..d('tuya', 'using key $key')
        ..e('tuya', 'decrypt failed', FormatException('bad key $key'));
      expect(
        sink.records.map((r) => r.toString()).join(),
        isNot(contains(key)),
      );
    },
  );

  test('values read through SecretStore are redacted too', () async {
    backend.values['secret/hub/hue_user'] = 'hue-user-abcdef';
    final u = await store.get('hub', SecretName.hueUser);
    logger.i('hue', 'GET /api/$u/lights');
    expect(
      sink.records.single.message,
      'GET /api/${Redactor.placeholder}/lights',
    );
  });

  test('warmUp registers pre-existing secrets before any read', () async {
    backend.values['secret/tplink/password'] = 'tp-link-pass';
    backend.values['other/unrelated'] = 'not-a-secret';
    await store.warmUp();
    logger.i('klap', 'login tp-link-pass not-a-secret');
    expect(
      sink.records.single.message,
      'login ${Redactor.placeholder} not-a-secret',
    );
  });
}
