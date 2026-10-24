import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/log.dart';
import '../../core/result.dart';
import '../../net/ipv4.dart';
import '../../net/lan_socket_factory.dart';
import '../../registry/config_export.dart';

const _tag = 'share';

/// What the setup QR carries (PSEUDOCODE §15): `ohsetup:1?h=<ip>&p=<port>&k=<token>`.
/// The token is a one-time 256-bit key (base64url); it encrypts the config and its
/// hash names the download path.
class SetupQr {
  const SetupQr(this.host, this.port, this.token);
  final String host;
  final int port;
  final String token;

  static const scheme = 'ohsetup';

  String encode() => '$scheme:1?h=$host&p=$port&k=$token';

  /// Null unless it is a version-1 setup QR pointing at a private LAN address.
  static SetupQr? parse(
    String text, {
    bool Function(String host) allowHost = isPrivateIpv4,
  }) {
    final t = text.trim();
    if (!t.startsWith('$scheme:1?')) return null;
    final q = Uri.splitQueryString(t.substring('$scheme:1?'.length));
    final h = q['h'];
    final p = int.tryParse(q['p'] ?? '');
    final k = q['k'];
    if (h == null || !allowHost(h)) return null;
    if (p == null || p < 1 || p > 65535) return null;
    if (k == null || k.length < 43) return null;
    return SetupQr(h, p, k);
  }

  /// `/setup/<first 16 hex of sha256(token)>`: the server never sees the key in the URL.
  String get path => pathFor(token);

  static String pathFor(String token) =>
      '/setup/${sha256.convert(utf8.encode(token)).toString().substring(0, 16)}';
}

enum ShareEnd { sent, cancelled, expired }

/// One running share: show [qr], wait for [done].
class SetupOffer {
  SetupOffer._(this.qr, this._server, this._timer);
  final SetupQr qr;
  final HttpServer _server;
  final Timer _timer;
  final _done = Completer<ShareEnd>();

  Future<ShareEnd> get done => _done.future;

  void cancel() => _finish(ShareEnd.cancelled);

  void _finish(ShareEnd end) {
    if (_done.isCompleted) return;
    _timer.cancel();
    unawaited(_server.close(force: true));
    _done.complete(end);
    log.i(_tag, 'share ${end.name}');
  }
}

/// Serves this phone's encrypted setup once over the LAN (T10.4).
class SetupSender {
  SetupSender(
    this._lan,
    this._exporter, {
    this.expireAfter = const Duration(minutes: 5),
    this.allowHost = isPrivateIpv4,
    Random? random,
  }) : _random = random ?? Random.secure();

  final LanSocketFactory _lan;
  final ConfigExporter _exporter;
  final Duration expireAfter;

  /// Private LAN addresses only; tests allow loopback.
  final bool Function(String host) allowHost;
  final Random _random;

  /// [ip] is this phone's Wi-Fi address; it must be private.
  Future<Result<SetupOffer>> start(String? ip) async {
    if (ip == null || !allowHost(ip)) {
      return Err(
        DeviceError.unsupported(
          'Connect to your home Wi-Fi to share the setup.',
        ),
      );
    }
    final token = base64Url
        .encode(
          Uint8List.fromList(List.generate(32, (_) => _random.nextInt(256))),
        )
        .replaceAll('=', '');
    final body = await _exporter.export(token, includeSecrets: true);
    final bound = await _lan.httpServer(ip);
    final HttpServer server;
    switch (bound) {
      case Err(:final error):
        return Err(error);
      case Ok(:final value):
        server = value;
    }
    late final SetupOffer offer;
    final timer = Timer(expireAfter, () => offer._finish(ShareEnd.expired));
    offer = SetupOffer._(SetupQr(ip, server.port, token), server, timer);
    final path = SetupQr.pathFor(token);
    server.listen((req) async {
      final ok =
          req.method == 'GET' &&
          req.uri.path == path &&
          !offer._done.isCompleted;
      final res = req.response;
      if (!ok) {
        res.statusCode = HttpStatus.notFound;
        await res.close();
        return;
      }
      res
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..contentLength = body.length
        ..add(body);
      await res.close();
      offer._finish(ShareEnd.sent);
    }, onError: (Object e) => log.w(_tag, 'server error', e));
    log.i(_tag, 'sharing on $ip:${server.port}');
    return Ok(offer);
  }
}

/// Fetches and imports a setup from a [SetupQr] (T10.4). Returns the device count.
class SetupReceiver {
  SetupReceiver(this._lan, this._exporter, {this.allowHost = isPrivateIpv4});
  final LanSocketFactory _lan;
  final ConfigExporter _exporter;

  /// Private LAN addresses only; tests allow loopback.
  final bool Function(String host) allowHost;

  Future<Result<int>> receive(String qrText) async {
    final qr = SetupQr.parse(qrText, allowHost: allowHost);
    if (qr == null) {
      return Err(
        DeviceError.unsupported('This is not an Offline Home setup code.'),
      );
    }
    final r = await _lan.http(
      'GET',
      Uri(scheme: 'http', host: qr.host, port: qr.port, path: qr.path),
      timeout: const Duration(seconds: 5),
    );
    switch (r) {
      case Err(:final error):
        return Err(error);
      case Ok(value: final reply) when reply.status != 200:
        return Err(
          DeviceError.protocol(
            'The code has expired or was already used. Share again.',
          ),
        );
      case Ok(value: final reply):
        try {
          return Ok(await _exporter.import(reply.body, qr.token));
        } on ConfigException catch (e) {
          return Err(DeviceError.protocol(e.message));
        }
    }
  }
}
