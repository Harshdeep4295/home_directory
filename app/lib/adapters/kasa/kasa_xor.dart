import 'dart:convert';
import 'dart:typed_data';

/// TP-Link Kasa legacy "autokey" XOR cipher.
/// Ported from python-kasa 0.10.2 kasa/transports/xortransport.py (XorEncryption,
/// INITIALIZATION_VECTOR = 171). TCP frames are prefixed with a big-endian length;
/// UDP discovery datagrams are not (discover.py sends encrypted_req[4:]).
abstract final class KasaXor {
  static const initializationVector = 171;

  /// python-kasa discover.py: DISCOVERY_PORT = 9999, DISCOVERY_QUERY.
  static const discoveryPort = 9999;
  static const discoveryQuery = '{"system":{"get_sysinfo":{}}}';

  static Uint8List encrypt(List<int> plain) {
    var key = initializationVector;
    final out = Uint8List(plain.length);
    for (var i = 0; i < plain.length; i++) {
      key ^= plain[i];
      out[i] = key;
    }
    return out;
  }

  static Uint8List decrypt(List<int> cipher) {
    var key = initializationVector;
    final out = Uint8List(cipher.length);
    for (var i = 0; i < cipher.length; i++) {
      out[i] = key ^ cipher[i];
      key = cipher[i];
    }
    return out;
  }

  /// Length-prefixed frame for TCP 9999.
  static Uint8List frame(String json) {
    final body = encrypt(utf8.encode(json));
    return Uint8List.fromList([
      ...(ByteData(4)..setUint32(0, body.length)).buffer.asUint8List(),
      ...body,
    ]);
  }
}

/// python-kasa discover.py: DISCOVERY_PORT_2 = 20002 and the static
/// DISCOVERY_QUERY_2 = unhexlify("020000010000000000000000463cb5d3"). Replies carry a
/// 16-byte header followed by JSON (_get_discovery_json). Newer python-kasa also sends an
/// RSA-keyed query; VERIFY that Tapo devices at home answer the static one (T7.6).
abstract final class KlapDiscovery {
  static const port = 20002;
  static final query = Uint8List.fromList([
    0x02, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, //
    0x00, 0x00, 0x00, 0x00, 0x46, 0x3c, 0xb5, 0xd3,
  ]);

  /// JSON body of a 20002 reply, or null.
  static Map<String, Object?>? parseReply(List<int> data) {
    if (data.length <= 16) return null;
    try {
      final j = jsonDecode(utf8.decode(data.sublist(16)));
      return j is Map<String, Object?> ? j : null;
    } on FormatException {
      return null;
    }
  }
}
