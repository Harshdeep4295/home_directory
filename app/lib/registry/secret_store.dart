import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/log.dart';

/// Names of per-device secrets (PSEUDOCODE §4).
enum SecretName {
  /// Tuya local key.
  localKey('local_key'),

  /// TP-Link (Tapo/KLAP) account e-mail, stored under the pseudo device id "tplink".
  email('email'),
  password('password'),
  username('username'),

  /// Hue bridge username (API key), keyed by bridge id.
  hueUser('hue_user'),

  /// Sonoff/eWeLink device key for encrypted LAN mode.
  deviceKey('devicekey');

  const SecretName(this.key);
  final String key;
}

/// Raw key/value storage behind [SecretStore].
abstract interface class SecretBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<Map<String, String>> readAll();
}

/// Keychain (iOS) / Keystore-backed storage (Android).
class SecureStorageBackend implements SecretBackend {
  SecureStorageBackend([FlutterSecureStorage? storage])
    : _s =
          storage ??
          const FlutterSecureStorage(
            // Readable by background timers after the first unlock; never synced to iCloud.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _s;

  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
  @override
  Future<Map<String, String>> readAll() => _s.readAll();
}

/// In-memory backend for tests.
class MemorySecretBackend implements SecretBackend {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
}

/// The only place secrets are stored (CLAUDE.md rule 5). Keys are
/// `secret/<deviceId>/<name>`. Every value read or written is registered with the
/// logger's [Redactor], so it can never appear in log output.
class SecretStore {
  SecretStore(this._backend, this.redactor);

  final SecretBackend _backend;
  final Redactor redactor;

  static const _prefix = 'secret/';

  static String keyFor(String deviceId, SecretName name) =>
      '$_prefix$deviceId/${name.key}';

  /// Registers every stored secret with the redactor. Call once at startup, before any
  /// adapter logs.
  Future<void> warmUp() async {
    for (final e in (await _backend.readAll()).entries) {
      if (e.key.startsWith(_prefix)) redactor.register(e.value);
    }
  }

  Future<String?> get(String deviceId, SecretName name) async {
    final v = await _backend.read(keyFor(deviceId, name));
    if (v != null) redactor.register(v);
    return v;
  }

  Future<bool> has(String deviceId, SecretName name) async =>
      (await _backend.read(keyFor(deviceId, name))) != null;

  Future<void> set(String deviceId, SecretName name, String value) async {
    redactor.register(value);
    await _backend.write(keyFor(deviceId, name), value);
  }

  Future<void> delete(String deviceId, SecretName name) =>
      _backend.delete(keyFor(deviceId, name));

  /// Ids that have at least one secret (discovery uses this for "Ready" badges).
  Future<Set<String>> deviceIdsWithSecrets() async => {
    for (final k in (await _backend.readAll()).keys)
      if (k.startsWith(_prefix) && k.indexOf('/', _prefix.length) > 0)
        k.substring(_prefix.length, k.indexOf('/', _prefix.length)),
  };

  /// Removes every secret of a device (when the device is deleted).
  Future<void> deleteDevice(String deviceId) async {
    final prefix = '$_prefix$deviceId/';
    for (final k in (await _backend.readAll()).keys) {
      if (k.startsWith(prefix)) await _backend.delete(k);
    }
  }
}
