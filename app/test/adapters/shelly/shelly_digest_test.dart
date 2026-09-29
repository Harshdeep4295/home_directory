import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/shelly/shelly_adapter.dart';

/// Vectors from aioshelly's own AuthData: sim/tools/gen_shelly_vectors.py.
void main() {
  final v = jsonDecode(
    File('test/adapters/shelly/digest_vectors.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final cnonce = base64.encode([for (var i = 0; i < 16; i++) i]);

  for (final c in (v['cases']! as List).cast<Map<String, Object?>>()) {
    test('digest auth matches aioshelly for ${c['realm']}', () {
      final d = ShellyDigest(
        c['realm']! as String,
        'admin',
        c['password']! as String,
      )..updateChallenge((c['challenge']! as Map).cast<String, Object?>());
      final want = (c['auth']! as List).cast<Map<String, Object?>>();
      expect(d.next(cnonce), want[0]);
      expect(d.next(cnonce), want[1], reason: 'nc increments per call');
    });
  }

  test('non SHA-256 challenge is refused', () {
    expect(
      () => ShellyDigest(
        'r',
        'admin',
        'pw',
      ).updateChallenge({'algorithm': 'MD5', 'nonce': 1}),
      throwsFormatException,
    );
  });
}
