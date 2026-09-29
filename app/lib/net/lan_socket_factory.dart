import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/result.dart';
import 'ipv4.dart';
import 'platform_bridge.dart';

/// One UDP reply.
class UdpReply {
  const UdpReply(this.address, this.port, this.data);
  final String address;
  final int port;
  final Uint8List data;

  String get text => utf8.decode(data, allowMalformed: true);
}

/// A completed HTTP exchange.
class HttpReply {
  const HttpReply(this.status, this.headers, this.body);
  final int status;

  /// Lower-cased header names; multiple values joined with ", ".
  final Map<String, String> headers;
  final Uint8List body;

  String get text => utf8.decode(body, allowMalformed: true);
  Object? get json => jsonDecode(text);
}

/// All LAN sockets are created here (CLAUDE.md conventions). On Android the plugin binds
/// the whole process to the Wi-Fi network, so plain dart:io sockets go over Wi-Fi even
/// when mobile data has internet. Every method returns a [Result] and never throws.
class LanSocketFactory {
  LanSocketFactory(this.platform);

  final PlatformBridge platform;

  static const defaultTimeout = Duration(milliseconds: 1500);
  static const defaultHttpTimeout = Duration(milliseconds: 2000);

  /// Connects a TCP socket with TCP_NODELAY set.
  Future<Result<Socket>> tcp(
    String host,
    int port, {
    Duration timeout = defaultTimeout,
  }) async {
    try {
      // Ownership passes to the caller, who closes it.
      // ignore: close_sinks
      final s = await Socket.connect(
        host,
        port,
        timeout: timeout,
      ).timeout(timeout + const Duration(milliseconds: 100));
      s.setOption(SocketOption.tcpNoDelay, true);
      return Ok(s);
    } on TimeoutException {
      return Err(DeviceError.timeout('tcp $host:$port'));
    } on SocketException catch (e) {
      return Err(mapSocketError(e, 'tcp $host:$port'));
    }
  }

  /// Binds a UDP socket on all interfaces.
  Future<Result<RawDatagramSocket>> udp({
    int bindPort = 0,
    bool broadcast = false,
  }) async {
    try {
      final s = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        bindPort,
        reuseAddress: true,
      );
      s.broadcastEnabled = broadcast;
      return Ok(s);
    } on SocketException catch (e) {
      return Err(mapSocketError(e, 'udp bind $bindPort'));
    }
  }

  /// Sends [payload] to host:port and waits for replies.
  ///
  /// [expectMany] false: returns the first reply, or `Err(timeout)`.
  /// [expectMany] true: collects every reply until [timeout]; an empty list is `Ok`.
  Future<Result<List<UdpReply>>> udpRequest(
    String host,
    int port,
    List<int> payload, {
    Duration timeout = defaultTimeout,
    bool expectMany = false,
  }) async {
    final address = InternetAddress.tryParse(host);
    if (address == null) {
      return Err(DeviceError.protocol('udp: not an IP address: $host'));
    }
    return _udpExchange(
      address,
      port,
      payload,
      timeout: timeout,
      expectMany: expectMany,
      broadcast: false,
    );
  }

  /// Broadcasts [payload] on the Wi-Fi subnet and collects replies for [window].
  /// `Err(unsupported)` where the platform cannot broadcast (iOS, PLAN §5).
  Future<Result<List<UdpReply>>> broadcast(
    int port,
    List<int> payload, {
    Duration window = const Duration(seconds: 2),
    String? broadcastAddress,
  }) async {
    if (!platform.canBroadcast) {
      return Err(DeviceError.unsupported('broadcast not available'));
    }
    var target = broadcastAddress;
    if (target == null) {
      final net = await platform.netInfo();
      target = (net.ip != null && net.prefix != null)
          ? subnetBroadcast(net.ip!, net.prefix!)
          : '255.255.255.255';
    }
    await platform.acquireMulticastLock();
    try {
      return await _udpExchange(
        InternetAddress(target),
        port,
        payload,
        timeout: window,
        expectMany: true,
        broadcast: true,
      );
    } finally {
      await platform.releaseMulticastLock();
    }
  }

  Future<Result<List<UdpReply>>> _udpExchange(
    InternetAddress address,
    int port,
    List<int> payload, {
    required Duration timeout,
    required bool expectMany,
    required bool broadcast,
  }) async {
    final bound = await udp(broadcast: broadcast);
    if (bound case Err(:final error)) return Err(error);
    final socket = (bound as Ok<RawDatagramSocket>).value;
    final replies = <UdpReply>[];
    final done = Completer<void>();
    final timer = Timer(timeout, () {
      if (!done.isCompleted) done.complete();
    });
    final sub = socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket.receive();
        if (dg == null) return;
        replies.add(UdpReply(dg.address.address, dg.port, dg.data));
        if (!expectMany && !done.isCompleted) done.complete();
      },
      onError: (Object _) {
        if (!done.isCompleted) done.complete();
      },
    );
    try {
      final sent = socket.send(payload, address, port);
      if (sent <= 0) {
        return Err(
          DeviceError.offline('udp send to ${address.address} failed'),
        );
      }
      await done.future;
    } on SocketException catch (e) {
      return Err(mapSocketError(e, 'udp ${address.address}:$port'));
    } finally {
      timer.cancel();
      await sub.cancel();
      socket.close();
    }
    if (!expectMany && replies.isEmpty) {
      return Err(DeviceError.timeout('udp ${address.address}:$port'));
    }
    return Ok(replies);
  }

  /// A plain HTTP request. Never uses a proxy: LAN traffic must stay on the LAN.
  Future<Result<HttpReply>> http(
    String method,
    Uri url, {
    List<int>? body,
    Map<String, String>? headers,
    Duration timeout = defaultHttpTimeout,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..findProxy = ((_) => 'DIRECT')
      ..autoUncompress = true;
    try {
      return await _http(client, method, url, body, headers).timeout(timeout);
    } on TimeoutException {
      return Err(DeviceError.timeout('http $method $url'));
    } on SocketException catch (e) {
      return Err(mapSocketError(e, 'http $method $url'));
    } on HttpException catch (e) {
      return Err(DeviceError.protocol('http $method $url: ${e.message}'));
    } finally {
      client.close(force: true);
    }
  }

  Future<Result<HttpReply>> _http(
    HttpClient client,
    String method,
    Uri url,
    List<int>? body,
    Map<String, String>? headers,
  ) async {
    final req = await client.openUrl(method, url);
    headers?.forEach(req.headers.set);
    if (body != null) {
      req.contentLength = body.length;
      req.add(body);
    }
    final res = await req.close();
    final bytes = BytesBuilder(copy: false);
    await res.forEach(bytes.add);
    final hdrs = <String, String>{};
    res.headers.forEach((name, values) => hdrs[name] = values.join(', '));
    return Ok(HttpReply(res.statusCode, hdrs, bytes.takeBytes()));
  }
}

// errno values: Linux / Android first, then Darwin (iOS, macOS).
const _refused = {111, 61};
const _timedOut = {110, 60};

DeviceError mapSocketError(SocketException e, String what) {
  final code = e.osError?.errorCode;
  final msg = '$what: ${e.osError?.message ?? e.message}';
  if (code != null && _refused.contains(code)) return DeviceError.refused(msg);
  if ((code != null && _timedOut.contains(code)) ||
      e.message.toLowerCase().contains('timed out')) {
    return DeviceError.timeout(msg);
  }
  return DeviceError.offline(msg);
}
