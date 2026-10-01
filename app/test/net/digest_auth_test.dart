import 'package:flutter_test/flutter_test.dart';
import 'package:offline_home/net/digest_auth.dart';

void main() {
  test('RFC 2617 §3.5 example (qop=auth)', () {
    final a = DigestAuth.fromChallenge(
      'Digest realm="testrealm@host.com", qop="auth,auth-int", '
          'nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", '
          'opaque="5ccc069c403ebaf9f0171e9517f40e41"',
      'Mufasa',
      'Circle Of Life',
    )!;
    final h = a.header('GET', '/dir/index.html', cnonce: '0a4f113b');
    expect(h, contains('response="6629fae49393a05397450978507c4ef1"'));
    expect(h, contains('nc=00000001'));
    expect(h, contains('opaque="5ccc069c403ebaf9f0171e9517f40e41"'));
  });

  test('no qop: response = md5(ha1:nonce:ha2) (RFC 2069 compatible)', () {
    // Expected value computed with python hashlib (see noQopVector).
    final a = DigestAuth.fromChallenge(
      'Digest realm="r", nonce="n"',
      'admin',
      'pw',
    )!;
    expect(
      a.header('DESCRIBE', 'rtsp://h/p'),
      contains('response="$noQopVector"'),
    );
  });

  test('Basic and unknown schemes', () {
    expect(
      DigestAuth.fromChallenge(
        'Basic realm="x"',
        'admin',
        'ABCDEF',
      )!.header('DESCRIBE', '/'),
      'Basic YWRtaW46QUJDREVG',
    );
    expect(DigestAuth.fromChallenge('Bearer x', 'a', 'b'), isNull);
  });
}

const noQopVector = '7d00bd9a772dce8203c608538def0add';
