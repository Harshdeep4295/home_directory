import 'dart:convert';

import 'package:crypto/crypto.dart';

/// HTTP/RTSP authentication for one challenge (RFC 2617 / RFC 7616 MD5): Digest with or
/// without `qop=auth`, or Basic. RTSP uses the same scheme (RFC 2326 §D.2).
class DigestAuth {
  DigestAuth._(this.scheme, this.params, this.username, this._password);

  /// Parses a `WWW-Authenticate` header; null when it is neither Digest nor Basic.
  static DigestAuth? fromChallenge(
    String header,
    String username,
    String password,
  ) {
    final h = header.trim();
    final space = h.indexOf(' ');
    final scheme = (space < 0 ? h : h.substring(0, space)).toLowerCase();
    if (scheme != 'digest' && scheme != 'basic') return null;
    final params = <String, String>{
      for (final m in RegExp(
        r'(\w+)\s*=\s*(?:"([^"]*)"|([^\s,]+))',
      ).allMatches(space < 0 ? '' : h.substring(space + 1)))
        m.group(1)!.toLowerCase(): m.group(2) ?? m.group(3)!,
    };
    return DigestAuth._(scheme, params, username, password);
  }

  final String scheme;
  final Map<String, String> params;
  final String username;
  final String _password;
  int _nc = 0;

  String get realm => params['realm'] ?? '';

  /// `Authorization` header value for [method] on [uri]; [cnonce] fixed only in tests.
  String header(String method, String uri, {String? cnonce}) {
    if (scheme == 'basic') {
      return 'Basic ${base64.encode(utf8.encode('$username:$_password'))}';
    }
    final nonce = params['nonce'] ?? '';
    final ha1 = _md5('$username:$realm:$_password');
    final ha2 = _md5('$method:$uri');
    final qop = (params['qop'] ?? '')
        .split(',')
        .map((s) => s.trim())
        .contains('auth');
    final out = <String, String>{
      'username': '"$username"',
      'realm': '"$realm"',
      'nonce': '"$nonce"',
      'uri': '"$uri"',
    };
    if (qop) {
      final nc = (++_nc).toRadixString(16).padLeft(8, '0');
      final cn = cnonce ?? _md5('${DateTime.now().microsecondsSinceEpoch}');
      out['response'] = '"${_md5('$ha1:$nonce:$nc:$cn:auth:$ha2')}"';
      out['qop'] = 'auth';
      out['nc'] = nc;
      out['cnonce'] = '"$cn"';
    } else {
      out['response'] = '"${_md5('$ha1:$nonce:$ha2')}"';
    }
    if (params['opaque'] case final String o) out['opaque'] = '"$o"';
    out['algorithm'] = 'MD5';
    return 'Digest ${out.entries.map((e) => '${e.key}=${e.value}').join(', ')}';
  }

  static String _md5(String s) => md5.convert(utf8.encode(s)).toString();
}
