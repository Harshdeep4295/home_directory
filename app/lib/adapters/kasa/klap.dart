import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:pointycastle/export.dart';

import '../../core/result.dart';
import '../../net/lan_socket_factory.dart';

/// TP-Link KLAP transport (Tapo and newer Kasa). Ported from python-kasa 0.10.2
/// kasa/transports/klaptransport.py (KlapTransport, KlapTransportV2,
/// KlapEncryptionSession) and kasa/credentials.py (DEFAULT_CREDENTIALS).
/// Byte-exact vectors: test/adapters/kasa/klap_vectors.json
/// (sim/tools/gen_klap_vectors.py).
///
/// handshake1: POST /app/handshake1 with a 16-byte local seed → remote seed (16) +
///   server hash (32); the device sets the TP_SESSIONID cookie.
/// handshake2: POST /app/handshake2 with the v1/v2 seed hash.
/// request:    POST /app/request?seq=N, body = sha256(sig + seq + ct) + AES-CBC ct.
enum KlapVersion {
  /// IOT.KLAP devices (KlapTransport): md5 hashes.
  v1,

  /// SMART.KLAP devices (KlapTransportV2): sha1/sha256 hashes.
  v2,
}

Uint8List _sha256(List<int> b) =>
    Uint8List.fromList(hash.sha256.convert(b).bytes);
Uint8List _sha1(List<int> b) => Uint8List.fromList(hash.sha1.convert(b).bytes);
Uint8List _md5(List<int> b) => Uint8List.fromList(hash.md5.convert(b).bytes);

abstract final class KlapHashes {
  /// generate_auth_hash: v1 md5(md5(user) + md5(pw)); v2 sha256(sha1(user) + sha1(pw)).
  static Uint8List authHash(KlapVersion v, String user, String password) =>
      switch (v) {
        KlapVersion.v1 => _md5([
          ..._md5(utf8.encode(user)),
          ..._md5(utf8.encode(password)),
        ]),
        KlapVersion.v2 => _sha256([
          ..._sha1(utf8.encode(user)),
          ..._sha1(utf8.encode(password)),
        ]),
      };

  /// handshake1_seed_auth_hash: v1 sha256(local + auth); v2 sha256(local + remote + auth).
  static Uint8List handshake1(
    KlapVersion v,
    List<int> local,
    List<int> remote,
    List<int> auth,
  ) => switch (v) {
    KlapVersion.v1 => _sha256([...local, ...auth]),
    KlapVersion.v2 => _sha256([...local, ...remote, ...auth]),
  };

  /// handshake2_seed_auth_hash: v1 sha256(remote + auth); v2 sha256(remote + local + auth).
  static Uint8List handshake2(
    KlapVersion v,
    List<int> local,
    List<int> remote,
    List<int> auth,
  ) => switch (v) {
    KlapVersion.v1 => _sha256([...remote, ...auth]),
    KlapVersion.v2 => _sha256([...remote, ...local, ...auth]),
  };

  /// kasa/credentials.py DEFAULT_CREDENTIALS (base64 user, base64 password): devices
  /// that were set up with the app sometimes answer with these instead of the account.
  static const defaultCredentials = {
    'KASA': ('a2FzYUB0cC1saW5rLm5ldA==', 'a2FzYVNldHVw'),
    'KASACAMERA': ('YWRtaW4=', 'MjEyMzJmMjk3YTU3YTVhNzQzODk0YTBlNGE4MDFmYzM='),
    'TAPO': ('dGVzdEB0cC1saW5rLm5ldA==', 'dGVzdA=='),
    'TAPOCAMERA': ('YWRtaW4=', 'YWRtaW4='),
  };

  /// The auth hashes perform_handshake1 accepts, in its order: the user's, the
  /// defaults, then blank credentials.
  static List<Uint8List> candidates(
    KlapVersion v,
    String? user,
    String? password,
  ) => [
    if (user != null && password != null) authHash(v, user, password),
    for (final (u, p) in defaultCredentials.values)
      authHash(v, utf8.decode(base64.decode(u)), utf8.decode(base64.decode(p))),
    authHash(v, '', ''),
  ];
}

/// KlapEncryptionSession: key/iv/seq/sig derived from both seeds and the auth hash.
class KlapSession {
  KlapSession(List<int> local, List<int> remote, List<int> auth)
    : key = _sha256([...ascii.encode('lsk'), ...local, ...remote, ...auth])
          .sublist(0, 16),
      sig = _sha256([...ascii.encode('ldk'), ...local, ...remote, ...auth])
          .sublist(0, 28) {
    final full = _sha256([...ascii.encode('iv'), ...local, ...remote, ...auth]);
    iv = full.sublist(0, 12);
    seq = ByteData.sublistView(full, 28).getInt32(0);
  }

  final Uint8List key;
  final Uint8List sig;
  late final Uint8List iv;

  /// Signed 32-bit sequence (PACK_SIGNED_LONG); the last 4 bytes of the CBC IV.
  late int seq;

  Uint8List _ivFor(int s) => Uint8List.fromList([
    ...iv,
    ...(ByteData(4)..setInt32(0, s)).buffer.asUint8List(),
  ]);

  static int _wrap(int s) => (s + 0x80000000) % 0x100000000 - 0x80000000;

  /// encrypt(): bump seq, AES-CBC(PKCS7), prefix sha256(sig + seq + ct).
  (Uint8List, int) encrypt(List<int> plain) {
    seq = _wrap(seq + 1);
    final ct = _cbc(true, key, _ivFor(seq), _pad(plain));
    final s = (ByteData(4)..setInt32(0, seq)).buffer.asUint8List();
    return (
      Uint8List.fromList([
        ..._sha256([...sig, ...s, ...ct]),
        ...ct,
      ]),
      seq,
    );
  }

  /// decrypt(): responses use the IV of the last request; the 32-byte signature is
  /// skipped (python-kasa does not check it either).
  String decrypt(List<int> msg) {
    if (msg.length < 48 || (msg.length - 32) % 16 != 0) {
      throw const FormatException('klap: bad response length');
    }
    final plain = _cbc(false, key, _ivFor(seq), msg.sublist(32));
    final n = plain.last;
    if (n < 1 || n > 16) throw const FormatException('klap: bad padding');
    return utf8.decode(plain.sublist(0, plain.length - n));
  }

  static Uint8List _pad(List<int> d) {
    final n = 16 - d.length % 16;
    return Uint8List.fromList([...d, ...List.filled(n, n)]);
  }

  static Uint8List _cbc(bool enc, Uint8List key, Uint8List iv, List<int> data) {
    final c = CBCBlockCipher(AESEngine())
      ..init(enc, ParametersWithIV(KeyParameter(key), iv));
    final input = Uint8List.fromList(data);
    final out = Uint8List(input.length);
    for (var o = 0; o < input.length; o += 16) {
      c.processBlock(input, o, out, o);
    }
    return out;
  }
}

/// One device's KLAP connection: handshake on demand, re-handshake on 403 / expiry.
class KlapTransport {
  KlapTransport(
    this._sockets, {
    required this.host,
    this.port = 80,
    required this.version,
    this.username,
    this.password,
    this.timeout = LanSocketFactory.defaultTimeout,
    Random? random,
    DateTime Function()? now,
  }) : _random = random ?? Random.secure(),
       _now = now ?? DateTime.now;

  /// python-kasa: SESSION_COOKIE_NAME / TIMEOUT_COOKIE_NAME, ONE_DAY_SECONDS default,
  /// SESSION_EXPIRE_BUFFER_SECONDS = 20 min.
  static const sessionCookie = 'TP_SESSIONID';
  static const timeoutCookie = 'TIMEOUT';
  static const _expireBuffer = Duration(minutes: 20);

  final LanSocketFactory _sockets;
  final String host;
  final int port;
  final KlapVersion version;
  final String? username;
  final String? password;
  final Duration timeout;
  final Random _random;
  final DateTime Function() _now;

  KlapSession? _session;
  String? _cookie;
  DateTime? _expires;

  Uri _url(String path, [Map<String, String>? q]) => Uri(
    scheme: 'http',
    host: host,
    port: port,
    path: '/app/$path',
    queryParameters: q,
  );

  Map<String, String> get _cookieHeader =>
      _cookie == null ? const {} : {'Cookie': '$sessionCookie=$_cookie'};

  static String? _cookieValue(Map<String, String> headers, String name) =>
      RegExp('$name=([^;,\\s]+)')
          .firstMatch(headers['set-cookie'] ?? '')
          ?.group(1);

  /// perform_handshake: handshake1, pick the matching auth hash, handshake2.
  Future<Result<void>> handshake() async {
    _session = null;
    _cookie = null;
    final local = Uint8List.fromList(
      List.generate(16, (_) => _random.nextInt(256)),
    );
    final r1 = await _sockets.http(
      'POST',
      _url('handshake1'),
      body: local,
      timeout: timeout,
    );
    if (r1 case Err(:final error)) return Err(error);
    final res1 = (r1 as Ok<HttpReply>).value;
    if (res1.status != 200) {
      return Err(DeviceError.protocol('klap: handshake1 HTTP ${res1.status}'));
    }
    if (res1.body.length != 48) {
      return Err(DeviceError.protocol('klap: unexpected handshake1 reply'));
    }
    final remote = res1.body.sublist(0, 16);
    final server = res1.body.sublist(16);
    Uint8List? auth;
    for (final cand in KlapHashes.candidates(version, username, password)) {
      if (_eq(KlapHashes.handshake1(version, local, remote, cand), server)) {
        auth = cand;
        break;
      }
    }
    if (auth == null) {
      return Err(
        DeviceError.auth(
          'klap: device did not accept the TP-Link account (e-mail and password are case-sensitive)',
        ),
      );
    }
    _cookie = _cookieValue(res1.headers, sessionCookie);
    final ttl =
        int.tryParse(_cookieValue(res1.headers, timeoutCookie) ?? '') ?? 86400;
    final r2 = await _sockets.http(
      'POST',
      _url('handshake2'),
      body: KlapHashes.handshake2(version, local, remote, auth),
      headers: _cookieHeader,
      timeout: timeout,
    );
    if (r2 case Err(:final error)) return Err(error);
    if ((r2 as Ok<HttpReply>).value.status != 200) {
      return Err(DeviceError.auth('klap: handshake2 HTTP ${r2.value.status}'));
    }
    _session = KlapSession(local, remote, auth);
    _expires = _now().add(Duration(seconds: ttl) - _expireBuffer);
    return const Ok(null);
  }

  static bool _eq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var d = 0;
    for (var i = 0; i < a.length; i++) {
      d |= a[i] ^ b[i];
    }
    return d == 0;
  }

  /// send(): encrypted request, JSON reply. A 403 forces a new handshake (retried once).
  Future<Result<Map<String, Object?>>> send(
    Map<String, Object?> request,
  ) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (_session == null || _expires == null || _now().isAfter(_expires!)) {
        final h = await handshake();
        if (h case Err(:final error)) return Err(error);
      }
      final session = _session!;
      final (body, seq) = session.encrypt(utf8.encode(jsonEncode(request)));
      final r = await _sockets.http(
        'POST',
        _url('request', {'seq': '$seq'}),
        body: body,
        headers: _cookieHeader,
        timeout: timeout,
      );
      if (r case Err(:final error)) return Err(error);
      final res = (r as Ok<HttpReply>).value;
      if (res.status == 403 && attempt == 0) {
        _session = null;
        continue;
      }
      if (res.status != 200) {
        return Err(DeviceError.protocol('klap: request HTTP ${res.status}'));
      }
      try {
        final json = jsonDecode(session.decrypt(res.body));
        if (json is Map<String, Object?>) return Ok(json);
        return Err(DeviceError.protocol('klap: reply is not an object'));
      } on FormatException catch (e) {
        return Err(DeviceError.protocol('klap: ${e.message}'));
      }
    }
    return Err(DeviceError.protocol('klap: session rejected'));
  }

  void reset() => _session = null;
}
