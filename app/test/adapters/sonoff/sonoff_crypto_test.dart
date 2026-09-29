import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/sonoff/sonoff_adapter.dart';

/// Vectors from AlexxIT/SonoffLAN's own encrypt(): sim/tools/gen_sonoff_vectors.py.
void main() {
  final v = jsonDecode(
    File('test/adapters/sonoff/crypto_vectors.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final ivHex = v['iv']! as String;
  final iv = Uint8List.fromList([
    for (var i = 0; i < ivHex.length; i += 2)
      int.parse(ivHex.substring(i, i + 2), radix: 16),
  ]);

  for (final c in (v['cases']! as List).cast<Map<String, Object?>>()) {
    test('encrypt/decrypt match SonoffLAN for ${c['plain']}', () {
      final key = c['devicekey']! as String;
      final req = c['request']! as Map<String, Object?>;
      final (data, ivB64) = SonoffAdapter.encrypt(
        (c['plain']! as Map).cast<String, Object?>(),
        key,
        iv,
      );
      expect(data, req['data']);
      expect(ivB64, req['iv']);
      expect(jsonDecode(SonoffAdapter.decrypt(data, ivB64, key)), c['plain']);
    });
  }
}
