import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:pointycastle/export.dart';

/// Tuya LAN protocol 3.1 / 3.3 framing and crypto.
/// Ported from tinytuya 1.20.0: core/header.py, core/command_types.py,
/// core/message_helper.py (pack_message / unpack_message), core/XenonDevice.py
/// (_encode_message, _decode_payload, generate_payload, payload_dict),
/// core/crypto_helper.py, core/udp_helper.py.
/// Byte-exact vectors: test/adapters/tuya/vectors_3x.json (sim/tools/gen_tuya_vectors.py).

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

/// pack_message() for 55AA frames without HMAC (3.1–3.3). Client→device frames carry no
/// return code; device→client frames put one before the payload ([retcode]).
Uint8List encodeFrame55aa(int seq, int cmd, List<int> payload, {int? retcode}) {
  final body = BytesBuilder(copy: false);
  final rc = retcode == null ? 0 : TuyaHeader.retcodeLen;
  final head = ByteData(TuyaHeader.headerLen)
    ..setUint32(0, TuyaHeader.prefix55aa)
    ..setUint32(4, seq)
    ..setUint32(8, cmd)
    ..setUint32(12, rc + payload.length + TuyaHeader.endLen);
  body.add(head.buffer.asUint8List());
  if (retcode != null) {
    body.add((ByteData(4)..setUint32(0, retcode)).buffer.asUint8List());
  }
  body.add(payload);
  final sofar = body.toBytes();
  final end = ByteData(TuyaHeader.endLen)
    ..setUint32(0, crc32(sofar))
    ..setUint32(4, TuyaHeader.suffix55aa);
  return Uint8List.fromList([...sofar, ...end.buffer.asUint8List()]);
}

/// Incremental 55AA frame parser for a TCP stream. Feed bytes with [add]; complete frames
/// are returned. [hasRetcode]: true on the client side (device replies carry a return
/// code, tinytuya unpack_message no_retcode=False), false when parsing client frames.
class TuyaFrameDecoder {
  TuyaFrameDecoder({this.hasRetcode = true});

  final bool hasRetcode;

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
    final rcLen = hasRetcode ? TuyaHeader.retcodeLen : 0;
    if (len < rcLen + TuyaHeader.endLen) {
      throw TuyaDecodeException('frame too short ($len)');
    }
    final end = f.length - TuyaHeader.endLen;
    final crc = h.getUint32(end);
    final retcode = hasRetcode ? h.getUint32(TuyaHeader.headerLen) : null;
    return TuyaFrame(
      seq: seq,
      cmd: cmd,
      retcode: retcode,
      payload: Uint8List.fromList(f.sublist(TuyaHeader.headerLen + rcLen, end)),
      crcOk: crc == crc32(f.sublist(0, end)),
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

/// Builds the JSON bodies tinytuya's generate_payload() sends ("default" and
/// "device22" payload_dict entries; versions < 3.4 send `t` as a string).
class TuyaPayloads {
  TuyaPayloads(this.devId, {this.device22 = false});

  final String devId;
  final bool device22;

  String _t(DateTime now) => '${now.millisecondsSinceEpoch ~/ 1000}';

  /// DP_QUERY; device22 devices are queried with CONTROL_NEW and an explicit DP list.
  (int, String) dpQuery(DateTime now, {Iterable<int> dps = const [1]}) =>
      device22
      ? (
          TuyaCmd.controlNew,
          jsonEncode({
            'devId': devId,
            'uid': devId,
            't': _t(now),
            'dps': {for (final dp in dps) '$dp': null},
          }),
        )
      : (
          TuyaCmd.dpQuery,
          jsonEncode({
            'gwId': devId,
            'devId': devId,
            'uid': devId,
            't': _t(now),
          }),
        );

  (int, String) control(DateTime now, Map<int, Object?> dps) => (
    TuyaCmd.control,
    jsonEncode({
      'devId': devId,
      'uid': devId,
      't': _t(now),
      'dps': {for (final e in dps.entries) '${e.key}': e.value},
    }),
  );

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

/// Encrypts/decrypts payloads for one device (protocol 3.1 or 3.3).
class TuyaCodec3x {
  TuyaCodec3x(this.version, String localKey)
    : key = Uint8List.fromList(utf8.encode(localKey)) {
    if (key.length != 16) {
      throw ArgumentError('Tuya local key must be 16 bytes');
    }
    if (version != '3.1' && version != '3.3') {
      throw ArgumentError('TuyaCodec3x handles 3.1 and 3.3, not $version');
    }
  }

  final String version;
  final Uint8List key;

  /// XenonDevice._encode_message for version < 3.4.
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
