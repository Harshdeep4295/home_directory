import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/adapters/kasa/klap.dart';

/// Vectors from python-kasa itself: sim/tools/gen_klap_vectors.py.
Uint8List hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
]);
String toHex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  final v = jsonDecode(
    File('test/adapters/kasa/klap_vectors.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final local = hex(v['localSeed']! as String);
  final remote = hex(v['remoteSeed']! as String);

  test('default credentials table matches python-kasa', () {
    final want = (v['defaultCredentials']! as Map).map(
      (k, x) => MapEntry(k, ((x as List)[0], x[1])),
    );
    expect(KlapHashes.defaultCredentials, want);
  });

  for (final version in KlapVersion.values) {
    final c = (v['versions']! as Map)[version.name] as Map<String, Object?>;
    group('KLAP ${version.name}', () {
      final auth = KlapHashes.authHash(
        version,
        c['username']! as String,
        c['password']! as String,
      );

      test('auth / handshake hashes', () {
        expect(toHex(auth), c['authHash']);
        expect(toHex(KlapHashes.authHash(version, '', '')), c['blankAuthHash']);
        final defaults = (c['defaultAuthHashes']! as Map).values.toList();
        final cands = KlapHashes.candidates(
          version,
          'u',
          'p',
        ).map(toHex).toList();
        expect(cands.sublist(1, 5), defaults);
        expect(cands.last, c['blankAuthHash']);
        expect(
          toHex(KlapHashes.handshake1(version, local, remote, auth)),
          c['handshake1'],
        );
        expect(
          toHex(KlapHashes.handshake2(version, local, remote, auth)),
          c['handshake2'],
        );
      });

      test('session derivation + encrypt/decrypt byte-exact', () {
        final s = KlapSession(local, remote, auth);
        expect(toHex(s.key), c['sessionKey']);
        expect(toHex(s.iv), c['iv']);
        expect(toHex(s.sig), c['sig']);
        expect(s.seq, c['initialSeq']);
        for (final m in (c['messages']! as List).cast<Map<String, Object?>>()) {
          final (payload, seq) = s.encrypt(utf8.encode(m['plain']! as String));
          expect(seq, m['seq']);
          expect(toHex(payload), m['payload']);
          // the device answers with the same seq/IV; decrypt our own request back
          expect(s.decrypt(payload), m['plain']);
        }
      });
    });
  }
}
