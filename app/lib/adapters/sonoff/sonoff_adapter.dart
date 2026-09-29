import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:pointycastle/export.dart';

import '../../core/models.dart';
import '../../core/result.dart';
import '../../net/lan_socket_factory.dart';
import '../../registry/secret_store.dart';
import '../device_adapter.dart';

/// Sonoff / eWeLink devices in LAN mode (DIY and encrypted), HTTP on 8081.
/// Ported from AlexxIT/SonoffLAN custom_components/sonoff/core/ewelink/local.py:
/// XRegistryLocal.send (`POST /zeroconf/<command>` with {"sequence","deviceid",
/// "selfApikey":"123","data"}), encrypt()/decrypt() (AES-CBC, key md5(devicekey), random
/// 16-byte IV, PKCS7, base64, compact JSON), _handler3 (mDNS TXT id/type/encrypt).
/// Byte-exact vectors: test/adapters/sonoff/crypto_vectors.json
/// (sim/tools/gen_sonoff_vectors.py).
///
/// State is read with the DIY `info` command. VERIFY for eWeLink-firmware devices, which
/// normally publish state only in their mDNS TXT record. No native countdown in the
/// reference → phone-tier timers.
class SonoffAdapter extends DeviceAdapter {
  SonoffAdapter(
    this._sockets,
    this._secrets, {
    this.timeout = LanSocketFactory.defaultTimeout,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  /// local.py: `host += ":8081"  # default port`.
  static const port = 8081;
  static const _tag = 'sonoff';

  final LanSocketFactory _sockets;
  final SecretStore _secrets;
  final Duration timeout;
  final DateTime Function() _now;
  final Random _random;

  @override
  Brand get brand => Brand.sonoff;

  @override
  Set<String> get protocols => {'sonoff'};

  @override
  Future<Candidate?> probe(ProbeContext ctx) async => null; // mDNS _ewelink._tcp

  static int? outletOf(Device d) => (d.meta['outlet'] as num?)?.toInt();

  // ------------------------------------------------------------------ crypto

  /// encrypt(): returns (base64 data, base64 iv).
  static (String, String) encrypt(
    Map<String, Object?> data,
    String devicekey,
    Uint8List iv,
  ) {
    final key = Uint8List.fromList(
      hash.md5.convert(utf8.encode(devicekey)).bytes,
    );
    final plain = utf8.encode(jsonEncode(data));
    final n = 16 - plain.length % 16;
    final padded = Uint8List.fromList([...plain, ...List.filled(n, n)]);
    return (base64.encode(_cbc(true, key, iv, padded)), base64.encode(iv));
  }

  /// decrypt() (+ its trailing \x02 fix for issue #1160).
  static String decrypt(String dataB64, String ivB64, String devicekey) {
    final key = Uint8List.fromList(
      hash.md5.convert(utf8.encode(devicekey)).bytes,
    );
    final ct = base64.decode(dataB64);
    if (ct.isEmpty || ct.length % 16 != 0) {
      throw const FormatException('sonoff: bad ciphertext length');
    }
    final p = _cbc(false, key, base64.decode(ivB64), ct);
    final n = p.last;
    if (n < 1 || n > 16) throw const FormatException('sonoff: bad padding');
    return utf8
        .decode(p.sublist(0, p.length - n))
        .replaceAll(RegExp('\x02+\$'), '');
  }

  static Uint8List _cbc(bool enc, Uint8List key, Uint8List iv, Uint8List data) {
    final c = CBCBlockCipher(AESEngine())
      ..init(enc, ParametersWithIV(KeyParameter(key), iv));
    final out = Uint8List(data.length);
    for (var o = 0; o < data.length; o += 16) {
      c.processBlock(data, o, out, o);
    }
    return out;
  }

  // ------------------------------------------------------------------ transport

  /// send(): returns the reply's (decrypted) `data` map, or {} when there is none.
  Future<Result<Map<String, Object?>>> send(
    Device d,
    String command,
    Map<String, Object?> data,
  ) async {
    final key = await _secrets.get(d.id, SecretName.deviceKey);
    final payload = <String, Object?>{
      'sequence': '${_now().millisecondsSinceEpoch}',
      'deviceid': d.id,
      'selfApikey': '123',
      'data': data,
    };
    if (key != null) {
      final iv = Uint8List.fromList(
        List.generate(16, (_) => _random.nextInt(256)),
      );
      final (ct, ivB64) = encrypt(data, key, iv);
      payload
        ..['encrypt'] = true
        ..['data'] = ct
        ..['iv'] = ivB64;
    }
    final r = await _sockets.http(
      'POST',
      Uri(
        scheme: 'http',
        host: d.ip,
        port: d.port ?? port,
        path: '/zeroconf/$command',
      ),
      body: utf8.encode(jsonEncode(payload)),
      headers: {'Content-Type': 'application/json', 'Connection': 'close'},
      timeout: timeout,
    );
    if (r case Err(:final error)) return Err(error);
    final res = (r as Ok<HttpReply>).value;
    Object? j;
    try {
      j = res.json;
    } on FormatException {
      return Err(DeviceError.unsupported('sonoff: $command not supported'));
    }
    if (j is! Map) return Err(DeviceError.protocol('sonoff: bad reply'));
    final err = j['error'];
    if (err != 0) {
      // A wrong devicekey makes the device fail to parse our data.
      return Err(
        key != null && (err == 400 || err == 403)
            ? DeviceError.auth(
                'sonoff: device rejected the request (error $err); wrong devicekey?',
              )
            : DeviceError.protocol('sonoff: $command error $err'),
      );
    }
    final body = j['data'];
    if (body is Map) return Ok(body.cast<String, Object?>());
    if (body is String && j['iv'] is String && key != null) {
      try {
        final m = jsonDecode(decrypt(body, j['iv'] as String, key));
        if (m is Map) return Ok(m.cast<String, Object?>());
      } on FormatException {
        return Err(
          DeviceError.auth('sonoff: cannot decrypt reply; wrong devicekey?'),
        );
      }
    }
    return const Ok({});
  }

  @override
  Future<Result<DeviceState>> getState(
    Device d,
  ) => guarded(_tag, 'getState', () async {
    final r = await send(d, 'info', const {});
    if (r case Err(:final error)) return Err(error);
    final p = (r as Ok<Map<String, Object?>>).value;
    final outlet = outletOf(d);
    String? sw;
    if (outlet == null) {
      sw = p['switch'] as String?;
    }
    if (sw == null && p['switches'] is List) {
      final list = (p['switches']! as List).whereType<Map<Object?, Object?>>();
      sw =
          list.firstWhere(
                (s) => s['outlet'] == (outlet ?? 0),
                orElse: () => const {},
              )['switch']
              as String?;
    }
    if (sw == null) {
      return Err(DeviceError.unsupported('sonoff: no switch state in info'));
    }
    return Ok(DeviceState(on: sw == 'on', at: _now()));
  });

  @override
  Future<Result<void>> setPower(Device d, bool on) =>
      guarded(_tag, 'setPower', () async {
        final state = on ? 'on' : 'off';
        final outlet = outletOf(d);
        final r = outlet == null
            ? await send(d, 'switch', {'switch': state})
            : await send(d, 'switches', {
                'switches': [
                  {'switch': state, 'outlet': outlet},
                ],
              });
        return r.map((_) {});
      });
}
