import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/result.dart';
import '../net/digest_auth.dart';
import '../net/lan_socket_factory.dart';

/// One RTSP response (RFC 2326 §7).
class RtspResponse {
  const RtspResponse(this.status, this.headers, this.body);
  final int status;

  /// Lower-cased header names.
  final Map<String, String> headers;
  final String body;
}

/// Which of the candidate paths stream with the given credentials.
class StreamProbe {
  const StreamProbe(this.working, {this.authFailed = false});
  final List<String> working;

  /// The camera rejected the credentials (wrong code/password).
  final bool authFailed;
}

/// Just enough RTSP to check credentials and stream paths: OPTIONS and DESCRIBE with
/// Digest/Basic auth on one connection. Playback itself is done by the video player.
class RtspClient {
  RtspClient(this._sockets, {this.timeout = const Duration(seconds: 3)});

  final LanSocketFactory _sockets;
  final Duration timeout;

  /// Paths tried in order. Hikvision: `/Streaming/Channels/<channel><01 main|02 sub>`
  /// (Hikvision RTSP URL format, used by NVRs and IP cameras); EZVIZ consumer cameras:
  /// `/h264/ch1/main/av_stream` and `/h264/ch1/sub/av_stream`.
  // VERIFY: EZVIZ paths on the owner's model (some firmware only serves /H.264).
  static const mainPaths = [
    '/Streaming/Channels/101',
    '/h264/ch1/main/av_stream',
    '/H.264',
  ];
  static const subPaths = [
    '/Streaming/Channels/102',
    '/h264/ch1/sub/av_stream',
  ];

  /// DESCRIBE each of [paths] (stops at the first auth failure).
  Future<Result<StreamProbe>> probe(
    String host,
    int port,
    String user,
    String password,
    List<String> paths, {
    bool firstOnly = false,
  }) async {
    final conn = await _sockets.tcp(host, port, timeout: timeout);
    if (conn case Err(:final error)) return Err(error);
    final s = (conn as Ok<Socket>).value;
    final reader = _Reader(s);
    var cseq = 0;
    DigestAuth? auth;
    final working = <String>[];
    try {
      for (final path in paths) {
        final url = 'rtsp://$host:$port$path';
        Future<RtspResponse> describe() async {
          final a = auth?.header('DESCRIBE', url);
          s.add(
            ascii.encode(
              'DESCRIBE $url RTSP/1.0\r\nCSeq: ${++cseq}\r\n'
              'Accept: application/sdp\r\nUser-Agent: OfflineHome\r\n'
              '${a == null ? '' : 'Authorization: $a\r\n'}'
              '\r\n',
            ),
          );
          return reader.response().timeout(timeout);
        }

        var r = await describe();
        if (r.status == 401) {
          final challenge = r.headers['www-authenticate'];
          final next = challenge == null
              ? null
              : DigestAuth.fromChallenge(challenge, user, password);
          if (next == null) {
            return Err(DeviceError.protocol('rtsp: no usable challenge'));
          }
          auth = next;
          r = await describe();
          if (r.status == 401) {
            return const Ok(StreamProbe([], authFailed: true));
          }
        }
        if (r.status == 200) {
          working.add(path);
          if (firstOnly) break;
        }
      }
      return Ok(StreamProbe(working));
    } on TimeoutException {
      return Err(DeviceError.timeout('rtsp: no reply'));
    } on Object catch (e) {
      return Err(DeviceError.protocol('rtsp: $e'));
    } finally {
      await reader.cancel();
      s.destroy();
    }
  }
}

/// Reads RTSP responses (header block + Content-Length body) from a socket.
class _Reader {
  _Reader(Socket s) {
    _sub = s.listen(
      (d) {
        _buf.addAll(d);
        _pump();
      },
      onError: _fail,
      onDone: () => _fail(const SocketException('closed')),
    );
  }

  late final StreamSubscription<Uint8List> _sub;
  final _buf = <int>[];
  Completer<RtspResponse>? _waiting;
  Object? _closed;

  Future<RtspResponse> response() {
    final c = _waiting = Completer<RtspResponse>();
    _pump();
    if (_closed != null && !c.isCompleted) c.completeError(_closed!);
    return c.future;
  }

  void _fail(Object e) {
    _closed = e;
    final c = _waiting;
    if (c != null && !c.isCompleted) c.completeError(e);
  }

  void _pump() {
    final c = _waiting;
    if (c == null || c.isCompleted) return;
    final text = latin1.decode(_buf);
    final end = text.indexOf('\r\n\r\n');
    if (end < 0) return;
    final lines = text.substring(0, end).split('\r\n');
    final headers = <String, String>{};
    for (final l in lines.skip(1)) {
      final i = l.indexOf(':');
      if (i > 0) {
        headers[l.substring(0, i).trim().toLowerCase()] = l
            .substring(i + 1)
            .trim();
      }
    }
    final len = int.tryParse(headers['content-length'] ?? '') ?? 0;
    if (_buf.length < end + 4 + len) return;
    final body = text.substring(end + 4, end + 4 + len);
    _buf.removeRange(0, end + 4 + len);
    final status = int.tryParse(
      lines.first.split(' ').elementAtOrNull(1) ?? '',
    );
    c.complete(RtspResponse(status ?? 0, headers, body));
  }

  Future<void> cancel() => _sub.cancel();
}
