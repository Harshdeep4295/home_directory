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

  /// `cameras` is the camera list (CameraService, T9.4; places since T10.1).
  static const settingKeys = [
    'voice.language',
    'voice.tts',
    'poll.seconds',
    'cameras',
  ];

  /// Settings key holding the camera list (CameraService).
  static const camerasKey = 'cameras';

  /// [only]: device and camera ids to include (T10.6); null = everything. A partial
  /// export carries just those devices and cameras, the rooms they use and the secrets
  /// they need, and leaves the phone-wide settings (voice, polling) out.
  Future<Uint8List> export(
    String passphrase, {
    bool includeSecrets = false,
    Set<String>? only,
  }) async {
    if (passphrase.length < 6) {
      throw ConfigException('Use a passphrase of at least 6 characters.');
    }
    bool picked(String id) => only == null || only.contains(id);
    final devices = [
      for (final d in await _devices.all())
        if (picked(d.id)) d,
    ];
    final cameras = [
      for (final c in _cameraList(await _settings.get(camerasKey)))
        if (picked('${c['id']}')) c,
    ];
    final secrets = <String, Map<String, String>>{};
    if (includeSecrets) {
      final stored = await _secrets.deviceIdsWithSecrets();
      // Every id with a stored secret that the chosen items use: their own id, a
      // parent they point to in meta (Tuya gang → tuyaId, Hue light → bridge), the
      // TP-Link account for Kasa/Tapo, and cameras (T10.1, T10.6).
      final ids = only == null
          ? {...devices.map((d) => d.id), 'tplink', ...stored}
          : {
              for (final d in devices) ...[
                d.id,
                for (final v in d.meta.values)
                  if (v is String && stored.contains(v)) v,
                if (d.brand == Brand.kasa || d.brand == Brand.tapo) 'tplink',
              ],
              for (final c in cameras) '${c['id']}',
            };
      for (final d in ids) {
        for (final n in SecretName.values) {
          final v = await _secrets.get(d, n);
          if (v != null) (secrets[d] ??= {})[n.key] = v;
        }
      }
    }
    final settings = <String, String>{};
    for (final k in settingKeys) {
      if (k == camerasKey || (only != null)) continue;
      final v = await _settings.get(k);
      if (v != null) settings[k] = v;
    }
    final roomIds = {
      for (final d in devices) ?d.roomId,
      for (final c in cameras) ?(c['roomId'] as String?),
    };
    final body = {
      'version': 1,
      'rooms': [
        for (final r in await _rooms.all())
          if (only == null || roomIds.contains(r.id)) r.toJson(),
      ],
      'devices': [for (final d in devices) d.toJson()],
      'cameras': cameras,
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
    final settings = {...?body['settings'] as Map<String, Object?>?};
    // Cameras merge by id so a partial share does not drop the receiver's own
    // cameras. Older files carry them as the `cameras` setting.
    final cams = [
      ...?body['cameras'] as List<Object?>?,
      ..._cameraList(settings.remove(camerasKey) as String?),
    ];
    for (final e in settings.entries) {
      await _settings.set(e.key, '${e.value}');
    }
    if (cams.isNotEmpty) {
      final merged = {
        for (final c in _cameraList(await _settings.get(camerasKey)))
          '${c['id']}': c,
        for (final c in cams) '${(c! as Map)['id']}': c,
      };
      await _settings.set(camerasKey, jsonEncode(merged.values.toList()));
    }
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

  static List<Map<String, Object?>> _cameraList(String? raw) {
    if (raw == null) return const [];
    try {
      return [
        for (final c in jsonDecode(raw) as List<Object?>)
          (c! as Map).cast<String, Object?>(),
      ];
    } on Object {
      return const [];
    }
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
