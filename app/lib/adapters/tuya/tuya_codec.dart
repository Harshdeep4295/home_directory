import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:pointycastle/export.dart';

/// Tuya LAN protocol 3.1 / 3.3 / 3.4 framing and crypto.
/// Ported from tinytuya 1.20.0: core/header.py, core/command_types.py,
/// core/message_helper.py (pack_message / unpack_message), core/XenonDevice.py
/// (_encode_message, _decode_payload, generate_payload, payload_dict),
/// core/crypto_helper.py, core/udp_helper.py.
/// Byte-exact vectors: test/adapters/tuya/vectors_3x.json, vectors_34.json
/// (sim/tools/gen_tuya_vectors.py).

/// tinytuya core/command_types.py
abstract final class TuyaCmd {
  static const sessKeyNegStart = 0x03;
  static const sessKeyNegResp = 0x04;
  static const sessKeyNegFinish = 0x05;
  static const control = 0x07;
  static const status = 0x08;
  static const heartBeat = 0x09;
  static const dpQuery = 0x0a;
  static const controlNew = 0x0d;
  static const dpQueryNew = 0x10;
  static const updateDps = 0x12;
  static const udpNew = 0x13;
  static const lanExtStream = 0x40;
}

/// tinytuya core/header.py
abstract final class TuyaHeader {
  static const prefix55aa = 0x000055AA;
  static const suffix55aa = 0x0000AA55;
  static const headerLen = 16; // ">4I": prefix, seqno, cmd, length
  static const retcodeLen = 4;
  static const endLen = 8; // ">2I": crc, suffix
  static const endLenHmac =
      36; // MESSAGE_END_FMT_HMAC ">32sI": hmac-sha256, suffix

  /// PROTOCOL_3x_HEADER = 12 * b"\x00", prefixed by the version bytes.
  static Uint8List versionHeader(String version) =>
      Uint8List.fromList([...ascii.encode(version), ...List.filled(12, 0)]);

  /// NO_PROTOCOL_HEADER_CMDS
  static const noVersionHeaderCmds = {
    TuyaCmd.dpQuery,
    TuyaCmd.dpQueryNew,
    TuyaCmd.updateDps,
    TuyaCmd.heartBeat,
    TuyaCmd.sessKeyNegStart,
    TuyaCmd.sessKeyNegResp,
    TuyaCmd.sessKeyNegFinish,
    TuyaCmd.lanExtStream,
  };
}

class TuyaFrame {
  const TuyaFrame({
    required this.seq,
    required this.cmd,
    required this.payload,
    this.retcode,
    this.crcOk = true,
  });

  final int seq;
  final int cmd;
  final int? retcode;
  final Uint8List payload;
  final bool crcOk;

  @override
  String toString() =>
      'TuyaFrame(seq: $seq, cmd: 0x${cmd.toRadixString(16)}, '
      'retcode: $retcode, ${payload.length} B, crcOk: $crcOk)';
}

class TuyaDecodeException implements Exception {
  TuyaDecodeException(this.message);
  final String message;
  @override
  String toString() => 'TuyaDecodeException: $message';
}

/// pack_message() for 55AA frames: CRC32 trailer (3.1–3.3) or, with [hmacKey], an
/// HMAC-SHA256 trailer (3.4). Client→device frames carry no return code; device→client
/// frames put one before the payload ([retcode]).
Uint8List encodeFrame55aa(
  int seq,
  int cmd,
  List<int> payload, {
  int? retcode,
  Uint8List? hmacKey,
}) {
  final body = BytesBuilder(copy: false);
  final rc = retcode == null ? 0 : TuyaHeader.retcodeLen;
  final endLen = hmacKey == null ? TuyaHeader.endLen : TuyaHeader.endLenHmac;
  final head = ByteData(TuyaHeader.headerLen)
    ..setUint32(0, TuyaHeader.prefix55aa)
    ..setUint32(4, seq)
    ..setUint32(8, cmd)
    ..setUint32(12, rc + payload.length + endLen);
  body.add(head.buffer.asUint8List());
  if (retcode != null) {
    body.add((ByteData(4)..setUint32(0, retcode)).buffer.asUint8List());
  }
  body.add(payload);
  final sofar = body.toBytes();
  final check = hmacKey == null
      ? (ByteData(4)..setUint32(0, crc32(sofar))).buffer.asUint8List()
      : hmacSha256(hmacKey, sofar);
  final suffix = ByteData(4)..setUint32(0, TuyaHeader.suffix55aa);
  return Uint8List.fromList([
    ...sofar,
    ...check,
    ...suffix.buffer.asUint8List(),
  ]);
}

Uint8List hmacSha256(List<int> key, List<int> data) =>
    Uint8List.fromList(hash.Hmac(hash.sha256, key).convert(data).bytes);

/// Incremental 55AA frame parser for a TCP stream. Feed bytes with [add]; complete frames
/// are returned. [hasRetcode]: true on the client side (device replies carry a return
/// code, tinytuya unpack_message no_retcode=False), false when parsing client frames.
class TuyaFrameDecoder {
  TuyaFrameDecoder({this.hasRetcode = true, this.hmacKey});

  final bool hasRetcode;

  /// 3.4: frames end in HMAC-SHA256 with this key (the local key during session
  /// negotiation, then the session key). Null: CRC32.
  Uint8List? hmacKey;

  /// tinytuya message_helper MAX_PAYLOAD_LENGTH guards against desynced streams.
  static const maxPayload = 64 * 1024;

  final _buf = BytesBuilder(copy: true);

  List<TuyaFrame> add(List<int> bytes) {
    _buf.add(bytes);
    var data = _buf.takeBytes();
    final out = <TuyaFrame>[];
    while (true) {
      // Resync: skip to the next prefix.
      final start = _indexOfPrefix(data);
      if (start < 0) {
        data = data.length > 3 ? data.sublist(data.length - 3) : data;
        break;
      }
      if (start > 0) data = data.sublist(start);
      if (data.length < TuyaHeader.headerLen) break;
      final h = ByteData.sublistView(data);
      final len = h.getUint32(12);
      if (len > maxPayload) {
        data = data.sublist(4); // corrupt: drop this prefix and resync
        continue;
      }
      final total = TuyaHeader.headerLen + len;
      if (data.length < total) break;
      out.add(_parse(Uint8List.sublistView(data, 0, total)));
      data = data.sublist(total);
    }
    _buf.add(data);
    return out;
  }

  TuyaFrame _parse(Uint8List f) {
    final h = ByteData.sublistView(f);
    final seq = h.getUint32(4);
    final cmd = h.getUint32(8);
    final len = h.getUint32(12);
    final key = hmacKey;
    final endLen = key == null ? TuyaHeader.endLen : TuyaHeader.endLenHmac;
    final rcLen = hasRetcode ? TuyaHeader.retcodeLen : 0;
    if (len < rcLen + endLen) {
      throw TuyaDecodeException('frame too short ($len)');
    }
    final end = f.length - endLen;
    final bool ok;
    if (key == null) {
      ok = h.getUint32(end) == crc32(f.sublist(0, end));
    } else {
      final want = hmacSha256(key, f.sublist(0, end));
      final got = f.sublist(end, end + 32);
      var same = true;
      for (var i = 0; i < 32; i++) {
        if (want[i] != got[i]) same = false;
      }
      ok = same;
    }
    final retcode = hasRetcode ? h.getUint32(TuyaHeader.headerLen) : null;
    return TuyaFrame(
      seq: seq,
      cmd: cmd,
      retcode: retcode,
      payload: Uint8List.fromList(f.sublist(TuyaHeader.headerLen + rcLen, end)),
      crcOk: ok,
    );
  }

  static int _indexOfPrefix(Uint8List d) {
    for (var i = 0; i + 3 < d.length; i++) {
      if (d[i] == 0 && d[i + 1] == 0 && d[i + 2] == 0x55 && d[i + 3] == 0xAA) {
        return i;
      }
    }
    return -1;
  }
}

// ---------------------------------------------------------------- crypto

Uint8List _ecb(Uint8List key, Uint8List data, bool encrypt) {
  final cipher = ECBBlockCipher(AESEngine())..init(encrypt, KeyParameter(key));
  final out = Uint8List(data.length);
  for (var off = 0; off < data.length; off += 16) {
    cipher.processBlock(data, off, out, off);
  }
  return out;
}

/// crypto_helper._pad: PKCS#7 to 16 bytes.
Uint8List pkcs7Pad(List<int> data) {
  final n = 16 - data.length % 16;
  return Uint8List.fromList([...data, ...List.filled(n, n)]);
}

/// crypto_helper._unpad (without padding verification, like tinytuya's default).
Uint8List pkcs7Unpad(Uint8List data) {
  if (data.isEmpty) throw TuyaDecodeException('empty ciphertext');
  final n = data.last;
  if (n < 1 || n > 16 || n > data.length) {
    throw TuyaDecodeException('invalid padding length byte');
  }
  return Uint8List.sublistView(data, 0, data.length - n);
}

Uint8List aesEcbEncrypt(Uint8List key, List<int> plain) =>
    _ecb(key, pkcs7Pad(plain), true);

/// AES-ECB without padding (input must be a multiple of 16 bytes).
Uint8List aesEcbEncryptRaw(Uint8List key, List<int> plain) =>
    _ecb(key, Uint8List.fromList(plain), true);

Uint8List aesEcbDecrypt(Uint8List key, List<int> cipherText) {
  if (cipherText.length % 16 != 0) {
    throw TuyaDecodeException('invalid length: ${cipherText.length}');
  }
  return pkcs7Unpad(_ecb(key, Uint8List.fromList(cipherText), false));
}

int crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >>> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
  }
  return c;
}, growable: false);

// ---------------------------------------------------------------- payloads

/// Builds the JSON bodies tinytuya's generate_payload() sends ("default", "device22" and
/// "v3.4" payload_dict entries). Versions < 3.4 send `t` as a string; 3.4 as an int.
class TuyaPayloads {
  TuyaPayloads(this.devId, {this.device22 = false, this.version = '3.3'});

  final String devId;
  final bool device22;
  final String version;

  bool get _v34 => version == '3.4' || version == '3.5';

  String _t(DateTime now) => '${now.millisecondsSinceEpoch ~/ 1000}';

  /// DP_QUERY; device22 devices are queried with CONTROL_NEW and an explicit DP list;
  /// 3.4 uses DP_QUERY_NEW with an empty object.
  (int, String) dpQuery(DateTime now, {Iterable<int> dps = const [1]}) {
    if (device22) {
      return (
        TuyaCmd.controlNew,
        jsonEncode({
          'devId': devId,
          'uid': devId,
          't': _t(now),
          'dps': {for (final dp in dps) '$dp': null},
        }),
      );
    }
    if (_v34) return (TuyaCmd.dpQueryNew, '{}');
    return (
      TuyaCmd.dpQuery,
      jsonEncode({'gwId': devId, 'devId': devId, 'uid': devId, 't': _t(now)}),
    );
  }

  /// CONTROL; 3.4: CONTROL_NEW `{"protocol":5,"t":int,"data":{"dps":{...}}}`.
  (int, String) control(DateTime now, Map<int, Object?> dps) {
    final d = {for (final e in dps.entries) '${e.key}': e.value};
    if (_v34) {
      return (
        TuyaCmd.controlNew,
        jsonEncode({
          'protocol': 5,
          't': now.millisecondsSinceEpoch ~/ 1000,
          'data': {'dps': d},
        }),
      );
    }
    return (
      TuyaCmd.control,
      jsonEncode({'devId': devId, 'uid': devId, 't': _t(now), 'dps': d}),
    );
  }

  (int, String) heartBeat() =>
      (TuyaCmd.heartBeat, jsonEncode({'gwId': devId, 'devId': devId}));
}

// ---------------------------------------------------------------- codec

/// Result of decoding a device payload.
sealed class TuyaDecoded {
  const TuyaDecoded();
}

/// A JSON object (status / query reply).
final class TuyaJson extends TuyaDecoded {
  const TuyaJson(this.json);
  final Map<String, Object?> json;
}

/// Empty payload (plain ACK).
final class TuyaEmpty extends TuyaDecoded {
  const TuyaEmpty();
}

/// Device answered "data unvalid": it is a device22 type (XenonDevice._decode_payload).
final class TuyaDevice22 extends TuyaDecoded {
  const TuyaDevice22();
}

/// Plain-text, non-JSON reply (e.g. "json obj data unvalid" variants, errors).
final class TuyaText extends TuyaDecoded {
  const TuyaText(this.text);
  final String text;
}

/// Per-device payload crypto. [frameKey] is the HMAC key frames are checked with (3.4),
/// null for CRC32 framing.
abstract interface class TuyaCodec {
  String get version;
  Uint8List? get frameKey;
  Uint8List encode(int seq, int cmd, String json);
  TuyaDecoded decode(Uint8List payload, {bool device22 = false});

  factory TuyaCodec.forVersion(String version, String localKey) =>
      version == '3.4' ? TuyaCodec34(localKey) : TuyaCodec3x(version, localKey);
}

/// Encrypts/decrypts payloads for one device (protocol 3.1 or 3.3).
class TuyaCodec3x implements TuyaCodec {
  TuyaCodec3x(this.version, String localKey)
    : key = Uint8List.fromList(utf8.encode(localKey)) {
    if (key.length != 16) {
      throw ArgumentError('Tuya local key must be 16 bytes');
    }
    if (version != '3.1' && version != '3.3') {
      throw ArgumentError('TuyaCodec3x handles 3.1 and 3.3, not $version');
    }
  }

  @override
  final String version;
  final Uint8List key;

  @override
  Uint8List? get frameKey => null;

  /// XenonDevice._encode_message for version < 3.4.
  @override
  Uint8List encode(int seq, int cmd, String json) {
    var payload = Uint8List.fromList(utf8.encode(json));
    if (version == '3.3') {
      payload = aesEcbEncrypt(key, payload);
      if (!TuyaHeader.noVersionHeaderCmds.contains(cmd)) {
        payload = Uint8List.fromList([
          ...TuyaHeader.versionHeader('3.3'),
          ...payload,
        ]);
      }
    } else if (cmd == TuyaCmd.control) {
      // 3.1: base64(AES-ECB(json)), signed with md5("data=<b64>||lpv=3.1||<key>")[8:24].
      final b64 = ascii.encode(base64.encode(aesEcbEncrypt(key, payload)));
      final sig = hash.md5
          .convert([
            ...ascii.encode('data='),
            ...b64,
            ...ascii.encode('||lpv=3.1||'),
            ...key,
          ])
          .toString()
          .substring(8, 24);
      payload = Uint8List.fromList([
        ...ascii.encode('3.1'),
        ...ascii.encode(sig),
        ...b64,
      ]);
    }
    return encodeFrame55aa(seq, cmd, payload);
  }

  /// XenonDevice._decode_payload for version < 3.4.
  @override
  TuyaDecoded decode(Uint8List payload, {bool device22 = false}) {
    if (payload.isEmpty) return const TuyaEmpty();
    Uint8List plain;
    if (_startsWith(payload, '3.1')) {
      // 3.1 encrypted: "3.1" + 16 hex md5 chars + base64 ciphertext.
      plain = aesEcbDecrypt(
        key,
        base64.decode(ascii.decode(payload.sublist(3 + 16))),
      );
    } else if (version == '3.3') {
      var body = payload;
      if (_startsWith(body, '3.3') || (device22 && (body.length & 0x0F) != 0)) {
        body = Uint8List.sublistView(body, 15);
      }
      plain = aesEcbDecrypt(key, body);
    } else if (payload.first == 0x7B) {
      plain = payload; // 3.1 plaintext JSON
    } else {
      throw TuyaDecodeException('unexpected 3.1 payload');
    }
    final text = utf8.decode(plain, allowMalformed: true);
    if (version == '3.3' && text.contains('data unvalid')) {
      return const TuyaDevice22();
    }
    if (text.isEmpty) return const TuyaEmpty();
    try {
      final json = jsonDecode(text);
      if (json is Map<String, Object?>) return TuyaJson(json);
    } on FormatException {
      // fall through
    }
    return TuyaText(text);
  }

  static bool _startsWith(Uint8List b, String s) {
    final p = ascii.encode(s);
    if (b.length < p.length) return false;
    for (var i = 0; i < p.length; i++) {
      if (b[i] != p[i]) return false;
    }
    return true;
  }
}

/// Protocol 3.4: session key negotiation, then AES-ECB(session key) over the whole
/// payload (version header inside), HMAC-SHA256(session key) frame trailer.
/// Ported from tinytuya 1.20.0 core/XenonDevice.py (_negotiate_session_key_generate_step_1,
/// _step_3, _finalize, _encode_message, _decode_payload) and message_helper.py.
class TuyaCodec34 implements TuyaCodec {
  TuyaCodec34(String localKey)
    : realKey = Uint8List.fromList(utf8.encode(localKey)) {
    if (realKey.length != 16) {
      throw ArgumentError('Tuya local key must be 16 bytes');
    }
  }

  final Uint8List realKey;
  Uint8List? _session;
  Uint8List? _localNonce;

  @override
  String get version => '3.4';

  bool get hasSession => _session != null;

  /// Frames are HMAC'd with the local key until the session key exists.
  @override
  Uint8List get frameKey => _session ?? realKey;

  /// Step 1: SESS_KEY_NEG_START carrying our 16-byte nonce (fresh random per session,
  /// as tinytuya does).
  Uint8List negotiateStart(int seq, Uint8List localNonce) {
    _session = null;
    _localNonce = localNonce;
    return encodeFrame55aa(
      seq,
      TuyaCmd.sessKeyNegStart,
      aesEcbEncrypt(realKey, localNonce),
      hmacKey: realKey,
    );
  }

  /// Steps 2+3: checks the device's SESS_KEY_NEG_RESP (remote nonce + HMAC of our nonce),
  /// derives the session key and returns the SESS_KEY_NEG_FINISH frame. Throws
  /// [TuyaDecodeException] if the device does not prove it knows the local key.
  Uint8List negotiateFinish(int seq, TuyaFrame resp) {
    final local = _localNonce;
    if (local == null) throw StateError('negotiateStart first');
    if (resp.cmd != TuyaCmd.sessKeyNegResp) {
      throw TuyaDecodeException('negotiation: unexpected cmd ${resp.cmd}');
    }
    if (!resp.crcOk) throw TuyaDecodeException('negotiation: bad HMAC');
    final plain = aesEcbDecrypt(realKey, resp.payload);
    if (plain.length < 48) throw TuyaDecodeException('negotiation: too short');
    final remote = Uint8List.sublistView(plain, 0, 16);
    final check = hmacSha256(realKey, local);
    for (var i = 0; i < 32; i++) {
      if (plain[16 + i] != check[i]) {
        throw TuyaDecodeException('negotiation: HMAC check failed');
      }
    }
    final finish = encodeFrame55aa(
      seq,
      TuyaCmd.sessKeyNegFinish,
      aesEcbEncrypt(realKey, hmacSha256(realKey, remote)),
      hmacKey: realKey,
    );
    // _finalize: session = AES-ECB(localKey, localNonce XOR remoteNonce), no padding.
    _session = aesEcbEncryptRaw(realKey, [
      for (var i = 0; i < 16; i++) local[i] ^ remote[i],
    ]);
    return finish;
  }

  /// Test hook: the negotiated key (vectors compare it with tinytuya's).
  Uint8List? get sessionKey => _session;

  @override
  Uint8List encode(int seq, int cmd, String json) {
    final key = _session;
    if (key == null) throw StateError('tuya 3.4: no session key yet');
    var payload = Uint8List.fromList(utf8.encode(json));
    if (!TuyaHeader.noVersionHeaderCmds.contains(cmd)) {
      payload = Uint8List.fromList([
        ...TuyaHeader.versionHeader('3.4'),
        ...payload,
      ]);
    }
    return encodeFrame55aa(seq, cmd, aesEcbEncrypt(key, payload), hmacKey: key);
  }

  @override
  TuyaDecoded decode(Uint8List payload, {bool device22 = false}) {
    if (payload.isEmpty) return const TuyaEmpty();
    final key = _session;
    if (key == null) throw StateError('tuya 3.4: no session key yet');
    var plain = aesEcbDecrypt(key, payload);
    final header = ascii.encode('3.4');
    var hasHeader = plain.length >= 15;
    for (var i = 0; hasHeader && i < 3; i++) {
      if (plain[i] != header[i]) hasHeader = false;
    }
    if (hasHeader || (device22 && (plain.length & 0x0F) != 0)) {
      plain = Uint8List.sublistView(plain, 15);
    }
    return _decodeJson(utf8.decode(plain, allowMalformed: true), v34: true);
  }
}

/// Shared tail of _decode_payload: device22 detection, JSON parse, and the 3.4
/// `{"data":{"dps":...}}` → `dps` hoist.
TuyaDecoded _decodeJson(String text, {required bool v34}) {
  if (text.contains('data unvalid')) return const TuyaDevice22();
  if (text.isEmpty) return const TuyaEmpty();
  try {
    final json = jsonDecode(text);
    if (json is Map<String, Object?>) {
      if (v34 && !json.containsKey('dps')) {
        if (json['data'] case {'dps': final Object dps}) {
          return TuyaJson({...json, 'dps': dps});
        }
      }
      return TuyaJson(json);
    }
  } on FormatException {
    // fall through
  }
  return TuyaText(text);
}

// ---------------------------------------------------------------- UDP beacons

/// udp_helper.udpkey = md5(b"yGAdlopoPVldABfn").digest()
final Uint8List tuyaUdpKey = Uint8List.fromList(
  hash.md5.convert(ascii.encode('yGAdlopoPVldABfn')).bytes,
);

/// Tuya UDP discovery ports (tinytuya scanner: 6666 plaintext, 6667 encrypted; 7000 is
/// the 3.5 port, handled with 3.5 support).
const tuyaBeaconPorts = [6666, 6667];

/// udp_helper.decrypt_udp for 55AA and raw beacons (6699 beacons need 3.5 support).
/// Returns the beacon JSON (ip, gwId, version, productKey, ...) or null.
Map<String, Object?>? decodeTuyaBeacon(Uint8List msg) {
  try {
    Uint8List payload = msg;
    if (msg.length >= 4 &&
        ByteData.sublistView(msg).getUint32(0) == TuyaHeader.prefix55aa) {
      final frames = TuyaFrameDecoder().add(msg);
      if (frames.isEmpty) return null;
      payload = frames.first.payload;
    }
    final text =
        payload.isNotEmpty && payload.first == 0x7B && payload.last == 0x7D
        ? utf8.decode(payload)
        : utf8.decode(aesEcbDecrypt(tuyaUdpKey, payload));
    final json = jsonDecode(text);
    return json is Map<String, Object?> ? json : null;
  } on Object {
    return null;
  }
}
