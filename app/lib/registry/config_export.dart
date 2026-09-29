import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../core/models.dart';
import 'repositories.dart';
import 'secret_store.dart';

class ConfigException implements Exception {
  ConfigException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Encrypted backup of rooms, devices, aliases, settings and (only if asked) secrets
/// (T5.7). Envelope: PBKDF2-HMAC-SHA256 → AES-256-GCM, all parameters stored in clear.
class ConfigExporter {
  ConfigExporter(
    this._devices,
    this._rooms,
    this._settings,
    this._secrets, {
    this.iterations = 150000,
    Random? random,
  }) : _random = random ?? Random.secure();

  final DeviceRepository _devices;
  final RoomRepository _rooms;
  final SettingsRepository _settings;
  final SecretStore _secrets;
  final int iterations;
  final Random _random;

  static const format = 'offline-home-config';
  static const settingKeys = ['voice.language', 'voice.tts', 'poll.seconds'];

  Future<Uint8List> export(
    String passphrase, {
    bool includeSecrets = false,
  }) async {
    if (passphrase.length < 6) {
      throw ConfigException('Use a passphrase of at least 6 characters.');
    }
    final devices = await _devices.all();
    final secrets = <String, Map<String, String>>{};
    if (includeSecrets) {
      for (final d in [...devices.map((d) => d.id), 'tplink']) {
        for (final n in SecretName.values) {
          final v = await _secrets.get(d, n);
          if (v != null) (secrets[d] ??= {})[n.key] = v;
        }
      }
    }
    final settings = <String, String>{};
    for (final k in settingKeys) {
      final v = await _settings.get(k);
      if (v != null) settings[k] = v;
    }
    final body = {
      'version': 1,
      'rooms': [for (final r in await _rooms.all()) r.toJson()],
      'devices': [for (final d in devices) d.toJson()],
      'settings': settings,
      if (includeSecrets) 'secrets': secrets,
    };
    final salt = _bytes(16);
    final nonce = _bytes(12);
    final key = _derive(passphrase, salt);
    final data = _gcm(true, key, nonce, utf8.encode(jsonEncode(body)));
    return utf8.encode(
      jsonEncode({
        'format': format,
        'v': 1,
        'kdf': {
          'alg': 'pbkdf2-sha256',
          'iter': iterations,
          'salt': base64.encode(salt),
        },
        'cipher': {'alg': 'aes-256-gcm', 'nonce': base64.encode(nonce)},
        'data': base64.encode(data),
      }),
    );
  }

  /// Restores a backup. Returns how many devices were imported.
  Future<int> import(List<int> file, String passphrase) async {
    final Map<String, Object?> env;
    try {
      env = jsonDecode(utf8.decode(file)) as Map<String, Object?>;
    } on Object {
      throw ConfigException('Not an Offline Home config file.');
    }
    if (env['format'] != format) {
      throw ConfigException('Not an Offline Home config file.');
    }
    final kdf = env['kdf']! as Map<String, Object?>;
    final cipher = env['cipher']! as Map<String, Object?>;
    final key = _derive(
      passphrase,
      base64.decode(kdf['salt']! as String),
      iter: (kdf['iter']! as num).toInt(),
    );
    final Map<String, Object?> body;
    try {
      final plain = _gcm(
        false,
        key,
        base64.decode(cipher['nonce']! as String),
        base64.decode(env['data']! as String),
      );
      body = jsonDecode(utf8.decode(plain)) as Map<String, Object?>;
    } on InvalidCipherTextException {
      throw ConfigException('Wrong passphrase (or the file is damaged).');
    }
    for (final r in body['rooms']! as List<Object?>) {
      await _rooms.upsert(Room.fromJson(r! as Map<String, dynamic>));
    }
    final devices = body['devices']! as List<Object?>;
    for (final d in devices) {
      await _devices.upsert(Device.fromJson(d! as Map<String, dynamic>));
    }
    (body['settings'] as Map<String, Object?>? ?? const {}).forEach(
      (k, v) => _settings.set(k, '$v'),
    );
    final secrets = body['secrets'] as Map<String, Object?>? ?? const {};
    final names = {for (final n in SecretName.values) n.key: n};
    for (final e in secrets.entries) {
      for (final s in (e.value! as Map<String, Object?>).entries) {
        final n = names[s.key];
        if (n != null) await _secrets.set(e.key, n, '${s.value}');
      }
    }
    return devices.length;
  }

  Uint8List _bytes(int n) =>
      Uint8List.fromList(List.generate(n, (_) => _random.nextInt(256)));

  Uint8List _derive(String pass, List<int> salt, {int? iter}) {
    final kdf = PBKDF2KeyDerivator(
      HMac(SHA256Digest(), 64),
    )..init(Pbkdf2Parameters(Uint8List.fromList(salt), iter ?? iterations, 32));
    return kdf.process(Uint8List.fromList(utf8.encode(pass)));
  }

  static Uint8List _gcm(
    bool encrypt,
    Uint8List key,
    List<int> nonce,
    List<int> data,
  ) {
    final c = GCMBlockCipher(AESEngine())
      ..init(
        encrypt,
        AEADParameters(
          KeyParameter(key),
          128,
          Uint8List.fromList(nonce),
          Uint8List(0),
        ),
      );
    return c.process(Uint8List.fromList(data));
  }
}
